// backticks/backticks.test.cpp                                              -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#include <smd/backticks/backticks.hpp>

#include <smd/backticks/backticks.hpp> // test 2nd include OK

#include <catch2/catch_test_macros.hpp>

// 03013d1f-bcc1-4d3e-9701-3ed1a15c6370
TEST_CASE("backticks returns Steve", "backticks") {
    REQUIRE(backticks::backticks() == "Steve");
}
// 03013d1f-bcc1-4d3e-9701-3ed1a15c6370 end
