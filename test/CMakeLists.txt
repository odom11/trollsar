cmake_minimum_required(VERSION 3.17)
set(CMAKE_CXX_STANDARD 20)

add_executable(simpleAddCatch2Test simpleAddCatch2Test.cpp ../src/arithmetic/simpleAdd.cpp)
target_link_libraries(simpleAddCatch2Test PRIVATE
        Catch2::Catch2WithMain
)

add_test(NAME simpleAddCatch2Test
        COMMAND simpleAddCatch2Test
        )
