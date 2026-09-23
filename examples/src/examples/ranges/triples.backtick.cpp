// src/examples/ranges/triples.backtick.cpp                          -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// triples.pipe.cpp with the calls spelled infix. views::transform(r, f) and
// views::filter(r, pred) are already the primary overloads; operator| exists
// because there was no way to write those calls between their arguments.
// There is now, so the closures and the pipe both go away.
//
// views::join is the exception: it takes nothing beyond the range, and a
// backtick operator is exactly binary, so it keeps the `pipe` helper.

#include <smd/infix/pipe.hpp>

#include <print>
#include <ranges>
#include <tuple>

namespace views = std::views;
using smd::infix::pipe;

namespace {
constexpr auto is_pythagorean = [](auto t) {
    auto [x, y, z] = t;
    return x * x + y * y == z * z;
};
} // namespace

// 3b78b3dc-0ec5-4878-a244-73fde0656432
int main() {
    auto triples = views::iota(1) `views::transform` [](int z) {
        return views::iota(1, z + 1) `views::transform` [z](int x) {
            return views::iota(x, z + 1) `views::transform`
                [x, z](int y) { return std::tuple{x, y, z}; };
        } `pipe` views::join;
    } `pipe` views::join `views::filter` is_pythagorean `views::take` 10;

    for (auto [x, y, z] : triples) {
        std::println("({}, {}, {})", x, y, z);
    }
}
// 3b78b3dc-0ec5-4878-a244-73fde0656432 end
