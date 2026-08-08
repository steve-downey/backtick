// src/examples/ranges/triples.pipe.cpp                              -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// Pythagorean triples, after Eric Niebler's range-v3 example. This is the
// idiom as it is written today. triples.backtick.cpp is the same pipeline
// with the calls spelled infix; the two must print the same thing.

#include <print>
#include <ranges>
#include <tuple>

namespace views = std::views;

namespace {
constexpr auto is_pythagorean = [](auto t) {
    auto [x, y, z] = t;
    return x * x + y * y == z * z;
};
} // namespace

// 944390db-9ffa-492b-8e7e-3272533eaa84
int main() {
    auto triples = views::iota(1) | views::transform([](int z) {
                       return views::iota(1, z + 1) | views::transform([z](int x) {
                                  return views::iota(x, z + 1)
                                       | views::transform([x, z](int y) { return std::tuple{x, y, z}; });
                              })
                            | views::join;
                   })
                 | views::join | views::filter(is_pythagorean) | views::take(10);

    for (auto [x, y, z] : triples) {
        std::println("({}, {}, {})", x, y, z);
    }
}
// 944390db-9ffa-492b-8e7e-3272533eaa84 end
