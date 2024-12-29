cmake_minimum_required(VERSION 3.18)
project(trollsar)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED true)



set(OPTIX_VERSION "8.1")
# add optix to module path
set(OptiX_INSTALL_DIR ${CMAKE_SOURCE_DIR}/external/optix/${OPTIX_VERSION}/)
set(CMAKE_MODULE_PATH ${OptiX_INSTALL_DIR}/SDK/CMake)
find_package(OptiX REQUIRED)

include_directories(
        ${CUDA_INCLUDE_DIRS}
        ${OptiX_INCLUDE}
        ${OptiX_INSTALL_DIR}/SDK/sutil
        ${OptiX_INSTALL_DIR}/SDK/support
        include/
)




file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/conan_files)

execute_process(
    COMMAND ${CMAKE_COMMAND} -E env conan install ${CMAKE_SOURCE_DIR} --build=missing -s build_type=Debug -of ${CMAKE_BINARY_DIR}/conan_files
    COMMAND_ERROR_IS_FATAL ANY
)


find_package(CUDA 11.0 REQUIRED)
find_package(Catch2 REQUIRED HINTS ${CMAKE_BINARY_DIR}/conan_files)

add_subdirectory(external/optix/${OPTIX_VERSION}/SDK)
add_subdirectory(src)


option(ENABLE_COVERAGE "enable coverage" OFF)
if (ENABLE_COVERAGE) 
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} --coverage -fprofile-arcs -ftest-coverage")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} --coverage -fprofile-arcs -ftest-coverage")
    SET(GCC_COVERAGE_LINK_FLAGS    "-lgcov")
    SET(CMAKE_EXE_LINKER_FLAGS  "${CMAKE_EXE_LINKER_FLAGS} ${GCC_COVERAGE_LINK_FLAGS}")
    add_custom_target(init
        COMMAND ${CMAKE_MAKE_PROGRAM} clean
        COMMAND rm -f ${OBJECT_DIR}/*.gcno
        COMMAND rm -f ${OBJECT_DIR}/*.gcda
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )
# TODO: make this compiler dependent
endif()

enable_testing()
add_subdirectory("test")
