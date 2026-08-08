// src/smd/infix/pipe.test.cpp                                       -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#include <smd/infix/pipe.hpp>

#include <smd/infix/pipe.hpp> // test 2nd include OK

#include <catch2/catch_test_macros.hpp>

#include <ranges>
#include <type_traits>
#include <vector>

using smd::infix::pipe;

namespace {
constexpr auto inc = [](int n) { return n + 1; };
constexpr auto dbl = [](int n) { return n * 2; };
constexpr auto neg = [](int n) { return -n; };
} // namespace

TEST_CASE("pipe: header is idempotent") {
    // Bootstrap: passes if the file compiles and links.
    REQUIRE(true);
}

// 9ee4a0e9-9a15-4ad0-a023-6f3b37f44883
TEST_CASE("pipe: x `pipe` f is f(x)") {
    CHECK((3 `pipe` inc) == 4);
    CHECK(pipe(3, inc) == 4);
}

TEST_CASE("pipe: chains left to right") {
    // Left-associative, so this is neg(dbl(inc(3))), read in writing order.
    CHECK((3 `pipe` inc `pipe` dbl `pipe` neg) == -8);
}
// 9ee4a0e9-9a15-4ad0-a023-6f3b37f44883 end

// 4bf5ca2a-824d-41ab-8094-74e687a9bedb
// The backtick is desugared in the front end, so constant evaluation is
// inherited from the call rather than reimplemented for the operator.
static_assert((3 `pipe` inc) == 4);
static_assert((3 `pipe` inc `pipe` dbl `pipe` neg) == -8);
// 4bf5ca2a-824d-41ab-8094-74e687a9bedb end

TEST_CASE("pipe: returns decltype(auto), so identity preserves the reference") {
    constexpr auto id = [](auto&& x) -> decltype(auto) { return std::forward<decltype(x)>(x); };

    int n = 7;
    static_assert(std::is_same_v<decltype(n `pipe` id), int&>);
    CHECK(&(n `pipe` id) == &n);
}

// 2aa709be-aa72-4d1c-8406-f4d7a49ebcf2
TEST_CASE("pipe: carries a niladic range adaptor") {
    namespace views = std::views;

    std::vector<std::vector<int>> nested{{1, 2}, {3}, {4, 5}};

    // views::join takes no argument beyond the range, so it has no infix
    // spelling of its own; pipe supplies the missing second operand.
    auto flat = nested `pipe` views::join;

    CHECK(std::ranges::equal(flat, std::vector{1, 2, 3, 4, 5}));
}
// 2aa709be-aa72-4d1c-8406-f4d7a49ebcf2 end
