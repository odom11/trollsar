#define BOOST_TEST_DYN_LINK
#define BOOST_TEST_MODULE "bartest"

#include <boost/test/unit_test.hpp>
#include <boost/assert.hpp>

int simpleAdd(int a, int b);

BOOST_AUTO_TEST_SUITE(bartestsuite)
    BOOST_AUTO_TEST_CASE(testZero) {
        BOOST_CHECK_EQUAL(3, simpleAdd(3, 0));
    }
    BOOST_AUTO_TEST_CASE(testNonZero) {
        BOOST_CHECK_EQUAL(3, simpleAdd(2, 1));
    }
BOOST_AUTO_TEST_SUITE_END()
