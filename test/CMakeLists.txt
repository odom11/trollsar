cmake_minimum_required(VERSION 3.17)
set(CMAKE_CXX_STANDARD 20)
find_package(Boost COMPONENTS unit_test_framework REQUIRED)

#add_executable(footest footest.cpp)
#target_link_libraries(footest ${Boost_LIBRARIES})
#add_test(NAME test/footest COMMAND footest)

add_executable(simpleAddTest simpleAddTest.cpp ../src/arithmetic/simpleAdd.cpp)
#target_link_libraries(simpleAddTest ${Boost_LIBRARIES})
target_link_libraries(simpleAddTest PRIVATE
    CONAN_PKG::boost)

add_test(NAME test/simpleAddTest COMMAND simpleAddTest)

add_executable(simpleAddCatch2Test simpleAddCatch2Test.cpp ../src/arithmetic/simpleAdd.cpp)
target_link_libraries(simpleAddCatch2Test PRIVATE 
    CONAN_PKG::catch2
)


add_test(
    NAME catch2Test
    COMMAND simpleAddCatch2Test
)
