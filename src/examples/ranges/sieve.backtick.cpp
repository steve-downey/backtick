// src/examples/ranges/sieve.backtick.cpp                            -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// sieve.pipe.cpp with the presentation spelled infix. Every stage here is an
// adaptor with one argument beyond the range, so every stage has a direct
// infix spelling and nothing needs the `pipe` helper.
//
// The backtick binds tighter than every other binary operator, so a stage
// still does not need parentheses even when its argument is an expression.

#include <array>
#include <print>
#include <ranges>
#include <string>

namespace views = std::views;

namespace {
constexpr int limit = 200;

constexpr auto eratosthenes = [] {
    std::array<bool, limit> prime{};
    prime.fill(true);
    prime[0] = prime[1] = false;
    for (int n = 2; n * n < limit; ++n) {
        if (prime[n]) {
            for (int m = n * n; m < limit; m += n) {
                prime[m] = false;
            }
        }
    }
    return prime;
}();
} // namespace

// 57844e66-5063-40f0-89c2-ad326c73dc65
int main() {
    auto primes = views::iota(2, limit) `views::filter` [](int n) { return eratosthenes[n]; }
    `views::transform` [](int n) { return std::to_string(n); } `views::join_with` ' ';

    std::println("{}", std::ranges::to<std::string>(primes));
}
// 57844e66-5063-40f0-89c2-ad326c73dc65 end
