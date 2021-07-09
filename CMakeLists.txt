cmake_minimum_required(VERSION 3.18)
project(trollsar)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED true)

find_package(CUDA 11.0 REQUIRED)

set(OPTIX_VERSION "7.5")
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

include(${CMAKE_BINARY_DIR}/conanbuildinfo.cmake)
conan_basic_setup(TARGETS)

add_executable(trollsar.exe src/main.cpp src/view/initializeOptix.cpp src/arithmetic/simpleAdd.cpp)

target_link_libraries(trollsar.exe
        ${CUDA_LIBRARIES})


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
add_subdirectory("./test")
