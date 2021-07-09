//
// Created by ich on 11/1/21.
//

#include <iostream>

#include <Exception.h>
#include <optix.h>
#include <cuda_runtime.h>

void initializeOptix() {
    std::cout << "hello world" << std::endl;
    OptixDeviceContext context = nullptr;
    {
        CUDA_CHECK(cudaFree(0));
    }
}

