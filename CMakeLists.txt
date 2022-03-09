cmake_minimum_required(VERSION 3.17)
project(trollsar)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED true)

find_package(CUDA 11.0 REQUIRED)

set(OPTIX_VERSION "7.4")
# add optix to module path
set(OptiX_INSTALL_DIR ${CMAKE_SOURCE_DIR}/optix/${OPTIX_VERSION}/)
set(CMAKE_MODULE_PATH ${OptiX_INSTALL_DIR}/SDK/CMake)
find_package(OptiX REQUIRED)

include_directories(
        ${CUDA_INCLUDE_DIRS}
        ${OptiX_INCLUDE}
        ${OptiX_INSTALL_DIR}/SDK/sutil
        ${OptiX_INSTALL_DIR}/SDK/support
        include/
)

add_executable(trollsar.exe src/main.cpp src/view/initializeOptix.cpp src/arithmetic/simpleAdd.cpp)

target_link_libraries(trollsar.exe
        ${CUDA_LIBRARIES})

enable_testing()
add_subdirectory("./test")
