#define CATCH_CONFIG_MAIN
#include <catch2/catch.hpp>

int simpleAdd(int a, int b);

TEST_CASE( "addition is computed", "[simpleAdd]") {
    REQUIRE( simpleAdd(3,0) == 3);
    //REQUIRE( simpleAdd(2,1) == 3);
}

SCENARIO("BDD test addition of two numbers", "[bdd]")
{
    GIVEN("two positive numbers") {
        WHEN("the first number is 1") {
            int first = 1;
            AND_WHEN("the second number is 2") {
                int second = 2;
                THEN("the result is 3") {
                    REQUIRE(simpleAdd(first, second) == 3);
                }
            }
        }
    }
}
