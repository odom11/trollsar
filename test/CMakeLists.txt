cmake_minimum_required(VERSION 3.17)
set(CMAKE_CXX_STANDARD 20)
find_package(Boost COMPONENTS unit_test_framework REQUIRED)

add_executable(footest footest.cpp)
target_link_libraries(footest ${Boost_LIBRARIES})
add_test(NAME test/footest COMMAND footest)
