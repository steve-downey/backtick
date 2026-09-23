// src/examples/ranges/sieve.pipe.cpp                                -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// The sieve of Eratosthenes, with the sieve itself done classically and the
// presentation done with ranges. sieve.backtick.cpp spells the presentation
// infix; the two must print the same thing.

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

// 867acdbd-8d3f-445a-aa3f-272d19c9fcf6
int main() {
    auto primes = views::iota(2, limit) |
                  views::filter([](int n) { return eratosthenes[n]; }) |
                  views::transform([](int n) { return std::to_string(n); }) |
                  views::join_with(' ');

    std::println("{}", std::ranges::to<std::string>(primes));
}
// 867acdbd-8d3f-445a-aa3f-272d19c9fcf6 end
