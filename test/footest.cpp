#define BOOST_TEST_DYN_LINK
#define BOOST_TEST_MODULE "footest"

#include <boost/test/unit_test.hpp>
#include <boost/assert.hpp>

BOOST_AUTO_TEST_SUITE(footestsuite)
    BOOST_AUTO_TEST_CASE(spam) {
        BOOST_CHECK_EQUAL(3,3);
    }
BOOST_AUTO_TEST_SUITE_END()
