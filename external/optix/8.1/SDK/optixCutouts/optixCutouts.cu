/*

 * SPDX-FileCopyrightText: Copyright (c) 2019 - 2024  NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: BSD-3-Clause
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 * list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#include "optixCutouts.h"

#include <cuda/random.h>
#include <sutil/vec_math.h>
#include <cuda/helpers.h>

extern "C" {
__constant__ Params params;
}


//------------------------------------------------------------------------------
//
//
//
//------------------------------------------------------------------------------

struct RadiancePRD
{
    // TODO: move some state directly into payload registers?
    float3       emitted;
    float3       radiance;
    float3       attenuation;
    float3       origin;
    float3       direction;
    unsigned int seed;
    int          countEmitted;
    int          done;
    int          pad;
};


struct Onb
{
    __forceinline__ __device__ Onb( const float3& normal )
    {
        m_normal = normal;

        if( fabs( m_normal.x ) > fabs( m_normal.z ) )
        {
            m_binormal.x = -m_normal.y;
            m_binormal.y = m_normal.x;
            m_binormal.z = 0;
        }
        else
        {
            m_binormal.x = 0;
            m_binormal.y = -m_normal.z;
            m_binormal.z = m_normal.y;
        }

        m_binormal = normalize( m_binormal );
        m_tangent  = cross( m_binormal, m_normal );
    }

    __forceinline__ __device__ void inverse_transform( float3& p ) const
    {
        p = p.x * m_tangent + p.y * m_binormal + p.z * m_normal;
    }

    float3 m_tangent;
    float3 m_binormal;
    float3 m_normal;
};


//------------------------------------------------------------------------------
//
//
//
//------------------------------------------------------------------------------

static __forceinline__ __device__ void* unpackPointer( unsigned int i0, unsigned int i1 )
{
    const unsigned long long uptr = static_cast<unsigned long long>( i0 ) << 32 | i1;
    void*           ptr = reinterpret_cast<void*>( uptr );
    return ptr;
}


static __forceinline__ __device__ void  packPointer( void* ptr, unsigned int& i0, unsigned int& i1 )
{
    const unsigned long long uptr = reinterpret_cast<unsigned long long>( ptr );
    i0 = uptr >> 32;
    i1 = uptr & 0x00000000ffffffff;
}


static __forceinline__ __device__ RadiancePRD* getPRD()
{
    const unsigned int u0 = optixGetPayload_0();
    const unsigned int u1 = optixGetPayload_1();
    return reinterpret_cast<RadiancePRD*>( unpackPointer( u0, u1 ) );
}


static __forceinline__ __device__ void setPayloadOcclusion( bool occluded )
{
    optixSetPayload_0( static_cast<unsigned int>( occluded ) );
}


static __forceinline__ __device__ void cosine_sample_hemisphere( const float u1, const float u2, float3& p )
{
    // Uniformly sample disk.
    const float r   = sqrtf( u1 );
    const float phi = 2.0f * M_PIf * u2;
    p.x             = r * cosf( phi );
    p.y             = r * sinf( phi );

    // Project up to hemisphere.
    p.z = sqrtf( fmaxf( 0.0f, 1.0f - p.x * p.x - p.y * p.y ) );
}


static __forceinline__ __device__ void traceRadiance(
        OptixTraversableHandle handle,
        float3                 ray_origin,
        float3                 ray_direction,
        float                  tmin,
        float                  tmax,
        RadiancePRD*           prd
        )
{
    unsigned int u0, u1;
    packPointer( prd, u0, u1 );
    optixTrace(
            handle,
            ray_origin,
            ray_direction,
            tmin,
            tmax,
            0.0f,                     // rayTime
            OptixVisibilityMask( 1 ),
            OPTIX_RAY_FLAG_NONE,
            0,                        // SBT offset
            RAY_TYPE_COUNT,           // SBT stride
            0,                        // missSBTIndex
            u0, u1 );
}


static __forceinline__ __device__ bool traceOcclusion(
        OptixTraversableHandle handle,
        float3                 ray_origin,
        float3                 ray_direction,
        float                  tmin,
        float                  tmax
        )
{
    unsigned int occluded = 1u;
    optixTrace(
            handle,
            ray_origin,
            ray_direction,
            tmin,
            tmax,
            0.0f,                    // rayTime
            OptixVisibilityMask( 1 ),
            OPTIX_RAY_FLAG_TERMINATE_ON_FIRST_HIT | OPTIX_RAY_FLAG_DISABLE_CLOSESTHIT,
            0,                       // SBT offset
            RAY_TYPE_COUNT,          // SBT stride
            1,                       // missSBTIndex
            occluded );
    return occluded;
}


//------------------------------------------------------------------------------
//
//
//
//------------------------------------------------------------------------------

extern "C" __global__ void __raygen__rg()
{
    const int    w   = params.width;
    const int    h   = params.height;
    const float3 eye = params.eye;
    const float3 U   = params.U;
    const float3 V   = params.V;
    const float3 W   = params.W;
    const uint3  idx = optixGetLaunchIndex();
    const int    subframe_index = params.subframe_index;

    unsigned int seed = tea<4>( idx.y*w + idx.x, subframe_index );

    float3 result = make_float3( 0.0f );
    int i = params.samples_per_launch;
    do
    {
        // The center of each pixel is at fraction (0.5,0.5)
        const float2 subpixel_jitter = make_float2( rnd( seed ), rnd( seed ) );

        const float2 d = 2.0f * make_float2(
                ( static_cast<float>( idx.x ) + subpixel_jitter.x ) / static_cast<float>( w ),
                ( static_cast<float>( idx.y ) + subpixel_jitter.y ) / static_cast<float>( h )
                ) - 1.0f;
        float3 ray_direction = normalize(d.x*U + d.y*V + W);
        float3 ray_origin    = eye;

        RadiancePRD prd;
        prd.emitted      = make_float3(0.f);
        prd.radiance     = make_float3(0.f);
        prd.attenuation  = make_float3(1.f);
        prd.countEmitted = true;
        prd.done         = false;
        prd.seed         = seed;

        int depth = 0;
        for( ;; )
        {
            traceRadiance(
                    params.handle,
                    ray_origin,
                    ray_direction,
                    0.01f,  // tmin       // TODO: smarter offset
                    1e16f,  // tmax
                    &prd );

            result += prd.emitted;
            result += prd.radiance * prd.attenuation;

            if( prd.done || depth >= 10 )
                break;

            // russian roulette in linear color space
            const float rr = rnd( prd.seed );
            float lumAttenuation = luminance( prd.attenuation );
            if( lumAttenuation > rr )
                prd.attenuation /= min(1.f, lumAttenuation);
            else
                break;

            ray_origin    = prd.origin;
            ray_direction = prd.direction;

            ++depth;
        }
    }
    while( --i );

    const uint3        launch_index = optixGetLaunchIndex();
    const unsigned int image_index  = launch_index.y * params.width + launch_index.x;
    float3             accum_color  = result / static_cast<float>( params.samples_per_launch );

    if( subframe_index > 0 )
    {
        const float                 a = 1.0f / static_cast<float>( subframe_index+1 );
        const float3 accum_color_prev = make_float3( params.accum_buffer[ image_index ]);
        accum_color = lerp( accum_color_prev, accum_color, a );
    }
    params.accum_buffer[ image_index ] = make_float4( accum_color, 1.0f);
    params.frame_buffer[ image_index ] = make_color ( accum_color );
}


extern "C" __global__ void __miss__radiance()
{
    MissData* rt_data  = reinterpret_cast<MissData*>( optixGetSbtDataPointer() );
    RadiancePRD* prd = getPRD();

    prd->radiance = make_float3( rt_data->r, rt_data->g, rt_data->b );
    prd->done     = true;
}


extern "C" __global__ void __anyhit__ah_checkerboard()
{
    const unsigned int   hit_kind = optixGetHitKind();
    CutoutsHitGroupData* rt_data  = (CutoutsHitGroupData*)optixGetSbtDataPointer();
    const int            prim_idx = optixGetPrimitiveIndex();

    // The texture coordinates are defined per-vertex for built-in triangles,
    // and are derived from the surface normal for our custom sphere geometry.
    float2 texcoord;
    int ignore = 0;
    if( optixIsTriangleHit() )
    {
        const int    vert_idx_offset = prim_idx*3;
        const float2 barycentrics    = optixGetTriangleBarycentrics();

        const float2 t0 = rt_data->tex_coords[ vert_idx_offset+0 ];
        const float2 t1 = rt_data->tex_coords[ vert_idx_offset+1 ];
        const float2 t2 = rt_data->tex_coords[ vert_idx_offset+2 ];

        texcoord = t0 * ( 1.0f - barycentrics.x - barycentrics.y ) + t1 * barycentrics.x + t2 * barycentrics.y;
    }
    else
    {
        // assume sphere, could use a custom hit kind to identify the sphere type
        const float3 normal = make_float3( __uint_as_float( optixGetAttribute_0() ),
                                           __uint_as_float( optixGetAttribute_1() ),
                                           __uint_as_float( optixGetAttribute_2() ) );

        // TODO: Pass UV scale in SBT?
        const float uv_scale = 16.0f;
        const float u = uv_scale * ( 0.5f + atan2f( normal.z, normal.x ) * 0.5f * M_1_PIf );
        const float v = uv_scale * ( 0.5f - asinf( normal.y ) * M_1_PIf );
        texcoord = make_float2( u, v );
    }
    ignore = ( static_cast<int>( texcoord.x ) + static_cast<int>( texcoord.y ) ) & 1;

    if( ignore )
    {
        optixIgnoreIntersection();
    }
}

extern "C" __global__ void __anyhit__ah_circle()
{
    CutoutsHitGroupData* rt_data  = (CutoutsHitGroupData*)optixGetSbtDataPointer();
    const int            prim_idx = optixGetPrimitiveIndex();

    // The texture coordinates are defined per-vertex for built-in triangles
    float2 texcoord;
    int    ignore = 0;

    const int    vert_idx_offset = prim_idx * 3;
    const float2 barycentrics    = optixGetTriangleBarycentrics();

    const float2 t0 = rt_data->tex_coords[vert_idx_offset + 0];
    const float2 t1 = rt_data->tex_coords[vert_idx_offset + 1];
    const float2 t2 = rt_data->tex_coords[vert_idx_offset + 2];

    texcoord = t0 * ( 1.0f - barycentrics.x - barycentrics.y ) + t1 * barycentrics.x + t2 * barycentrics.y;
    // circular cutout
    ignore = ( texcoord.x * texcoord.x + texcoord.y * texcoord.y ) < ( CIRCLE_RADIUS * CIRCLE_RADIUS );

    if( ignore )
    {
        optixIgnoreIntersection();
    }
}



extern "C" __global__ void __miss__occlusion()
{
    setPayloadOcclusion( false );
}


extern "C" __global__ void __closesthit__radiance()
{
    CutoutsHitGroupData* rt_data = (CutoutsHitGroupData*)optixGetSbtDataPointer();
    RadiancePRD*         prd     = getPRD();

    const int          prim_idx        = optixGetPrimitiveIndex();
    const float3       ray_dir         = optixGetWorldRayDirection();
    const int          vert_idx_offset = prim_idx*3;
    const unsigned int hit_kind        = optixGetHitKind();

    float3 N;    
    if( optixIsTriangleHit() )
    {
        const float3 v0  = make_float3( rt_data->vertices[vert_idx_offset + 0] );
        const float3 v1  = make_float3( rt_data->vertices[vert_idx_offset + 1] );
        const float3 v2  = make_float3( rt_data->vertices[vert_idx_offset + 2] );
        const float3 N_0 = normalize( cross( v1 - v0, v2 - v0 ) );

        N = faceforward( N_0, -ray_dir, N_0 );
    }
    else
    {
        N = make_float3(__uint_as_float( optixGetAttribute_0() ),
                        __uint_as_float( optixGetAttribute_1() ),
                        __uint_as_float( optixGetAttribute_2() ));
    }

    prd->emitted = ( prd->countEmitted ) ? rt_data->emission_color : make_float3( 0.0f );

    const float3 P = optixGetWorldRayOrigin() + optixGetRayTmax() * ray_dir;

    unsigned int seed = prd->seed;

    {
        const float z1 = rnd(seed);
        const float z2 = rnd(seed);

        float3 w_in;
        cosine_sample_hemisphere( z1, z2, w_in );
        Onb onb( N );
        onb.inverse_transform( w_in );
        prd->direction = w_in;
        prd->origin    = P;

        prd->attenuation *= rt_data->diffuse_color;
        prd->countEmitted = false;
    }

    const float z1 = rnd(seed);
    const float z2 = rnd(seed);
    prd->seed = seed;

    ParallelogramLight light     = params.light;
    const float3       light_pos = light.corner + light.v1 * z1 + light.v2 * z2;

    // Calculate properties of light sample (for area based pdf)
    const float  Ldist = length(light_pos - P );
    const float3 L     = normalize(light_pos - P );
    const float  nDl   = dot( N, L );
    const float  LnDl  = -dot( light.normal, L );

    float weight = 0.0f;
    if( nDl > 0.0f && LnDl > 0.0f )
    {
        const bool occluded = traceOcclusion(
            params.handle,
            P,
            L,
            0.01f,         // tmin
            Ldist - 0.01f  // tmax
            );

        if( !occluded )
        {
            const float A = length(cross(light.v1, light.v2));
            weight = nDl * LnDl * A / (M_PIf * Ldist * Ldist);
        }
    }

    prd->radiance += light.emission * weight;
}
