// src/examples/scorecard/scorecard.cpp                              -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// What converts to an infix spelling and what does not.
//
// The interesting question about the backtick is not whether `a `min` b`
// reads well -- it does, and one line of a paper can show that. It is which
// shapes of real library interface it reaches. This file answers that by
// compiling one instance of each shape, so the table it prints cannot drift
// away from what the compiler actually accepts. Every claim below is a
// static_assert or it is not made.
//
// It is a single program rather than a pipe/backtick pair: the claim here is
// about what compiles, not about two spellings agreeing at runtime.

#include <smd/infix/pipe.hpp>

#include <algorithm>
#include <array>
#include <functional>
#include <numeric>
#include <print>
#include <ranges>
#include <string_view>
#include <utility>

namespace views = std::views;
namespace ranges = std::ranges;
using smd::infix::pipe;

namespace {

constexpr std::array digits{1, 2, 3, 4, 5, 6};
constexpr auto even = [](int n) { return n % 2 == 0; };
constexpr auto twice = [](int n) { return n * 2; };

// ---------------------------------------------------------------------------
// 1. Adaptors that take one argument beyond the range: a direct infix
// spelling, and the closure and the pipe both go away.

static_assert(ranges::equal(digits `views::filter` even, std::array{2, 4, 6}));
static_assert(ranges::equal(digits `views::transform` twice,
                            std::array{2, 4, 6, 8, 10, 12}));
static_assert(ranges::equal(digits `views::take` 2, std::array{1, 2}));
static_assert(ranges::equal(digits `views::drop` 4, std::array{5, 6}));
static_assert(ranges::equal(digits `views::stride` 3, std::array{1, 4}));

// Left associative and higher precedence than every other binary operator,
// so a chain of them needs no parentheses.
static_assert(
    ranges::equal(digits `views::filter` even `views::transform` twice
                      `views::take` 2,
                  std::array{4, 8}));

// ---------------------------------------------------------------------------
// 2. Adaptors that take nothing beyond the range: no infix spelling, because
// a backtick operator is exactly binary and there is no second operand to
// write. The `pipe` helper supplies one.

constexpr std::array<std::array<int, 2>, 2> nested{{{1, 2}, {3, 4}}};

static_assert(ranges::equal(nested `pipe` views::join, std::array{1, 2, 3, 4}));
static_assert(
    ranges::equal(digits `pipe` views::reverse, std::array{6, 5, 4, 3, 2, 1}));

// ---------------------------------------------------------------------------
// 3. Three or more arguments: no infix spelling either, and this proposal
// does not invent one. Where a closure exists, `pipe` carries it; otherwise
// it stays a call, or std::bind_back makes one.

static_assert((digits `pipe` std::bind_back(ranges::fold_left, 0, std::plus{}))
              == 21);
static_assert(ranges::fold_left(digits, 0, std::plus{}) == 21);

// ---------------------------------------------------------------------------
// 4. Variadic: stays a call, in either spelling.

static_assert(ranges::equal(views::zip(std::array{1, 2}, std::array{3, 4})
                                `views::transform`
                            [](auto p) { return std::get<0>(p) + std::get<1>(p); },
                            std::array{4, 6}));

// ---------------------------------------------------------------------------
// 5. The reach the pipe never had. Range algorithms take the range first and
// have no closure form at all, so there is no `r | count(x)` to write today.
// They are binary, so they convert like any other binary call.

static_assert((digits `ranges::count` 3) == 1);
static_assert(digits `ranges::contains` 5);
static_assert(std::array{1, 2} `ranges::equal` std::array{1, 2});
static_assert((3 `std::min` 4) == 3);
static_assert((12 `std::gcd` 18) == 6);
static_assert((0 `std::midpoint` 10) == 5);

// ---------------------------------------------------------------------------
// 6. A type name in the slot. The design says this constructs, with CTAD
// (D16, §17.3), on the reasoning that a type name is callable. Neither
// prototype accepts it, in any spelling, so there is no static_assert here
// to make -- which is exactly why the table is generated from this file.
// See docs/divergences/dev-06-type-name-slot.cpp, recorded as DEV-06.
//
//     static_assert((1 `std::pair` 2.5).second == 2.5);  // rejected by both

// ---------------------------------------------------------------------------
// 7. Operands are cast-expressions, so a prefix operator binds to each of
// them symmetrically rather than to the whole call.

static_assert((-3 `std::min` -4) == -4);
static_assert((2 * 3 `std::min` 4) == 6); // 2 * min(3, 4), not min(2 * 3, 4)

// ---------------------------------------------------------------------------
// 8. The keyword escape: the same token, told apart by grammatical position.
// In operand or declarator position it yields an ordinary identifier.

bool `requires`(int n) { return n > 0; }

// ---------------------------------------------------------------------------

struct row {
    std::string_view shape;
    std::string_view infix;
    std::string_view example;
};

constexpr std::array scorecard{
    row{"algo(r, arg)", "yes, directly", "r `views::filter` pred"},
    row{"algo(r)", "no -- pipe helper", "r `pipe` views::join"},
    row{"algo(r, a, b)", "no -- bind_back or a call", "fold_left(r, 0, plus)"},
    row{"algo(a, b, c...)", "no -- variadic", "views::zip(a, b, c)"},
    row{"algo(r, arg), no closure", "yes, and | never could",
        "r `ranges::count` x"},
    row{"Type(a, b)", "designed yes, implemented no", "a `std::pair` b (DEV-06)"},
    row{"f(a, {1, 2})", "no -- operands are cast-expressions", "(D9)"},
};

} // namespace

// 1d233eaa-37b0-43c9-815c-699b3772aba3
int main() {
    std::println("{:<28}  {:<36}  {}", "shape", "infix?", "example");
    std::println("{:-<28}  {:-<36}  {:-<24}", "", "", "");
    for (const auto& [shape, infix, example] : scorecard) {
        std::println("{:<28}  {:<36}  {}", shape, infix, example);
    }
    std::println("");
    std::println("keyword escape: `requires`(1) == {}", `requires`(1));
}
// 1d233eaa-37b0-43c9-815c-699b3772aba3 end
