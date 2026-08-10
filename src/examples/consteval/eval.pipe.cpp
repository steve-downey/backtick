// src/examples/consteval/eval.pipe.cpp                              -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// A pipeline that runs to completion during constant evaluation, sized from
// the command line. This pair is not here to be read as an idiom -- the other
// examples are that. It is here to be measured: what a spelling costs the
// constant evaluator, and whether the two costs grow at the same rate.
//
// Compile it at another size with -DSMD_EVAL_N=400. The static_assert holds
// at every size because it checks the pipeline against a hand-written loop
// over the same sieve rather than against a literal, so the sweep needs no
// table of expected answers.

#include <array>
#include <print>
#include <ranges>

// The size knob. A macro because the harness sets it from the command line;
// nothing else in this project needs one.
#ifndef SMD_EVAL_N
#define SMD_EVAL_N 200
#endif

namespace views = std::views;

namespace {
constexpr int limit = SMD_EVAL_N;

// The sieve is a classical loop, evaluated once and identical in both
// spellings, so it contributes the same fixed cost to each and leaves the
// pipeline as what the measurement is actually comparing. It also makes the
// predicate an array lookup rather than a trial division, which keeps the
// per-element cost dominated by the range machinery.
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

constexpr auto is_prime = [](int n) { return eratosthenes[n]; };
constexpr auto square = [](int n) { return static_cast<long long>(n) * n; };

struct totals {
    int count;
    long long sum;
    bool operator==(const totals &) const = default;
};

// The last stage takes the range and nothing else, so in the infix spelling
// it is the one that needs the `pipe` helper. Here it is a call, and the
// chain has to be turned inside out to make it one.
constexpr auto tally = [](auto &&squares) {
    totals t{};
    for (long long s : squares) {
        ++t.count;
        t.sum += s;
    }
    return t;
};

// The oracle. A plain loop over the same sieve, computing the same two
// numbers without a single view.
constexpr totals by_hand() {
    totals t{};
    for (int n = 2; n < limit; ++n) {
        if (eratosthenes[n]) {
            ++t.count;
            t.sum += static_cast<long long>(n) * n;
        }
    }
    return t;
}
} // namespace

// b988da81-da87-4389-95bc-ecf59972f6cd
constexpr totals result = tally(
    views::iota(2, limit) | views::filter(is_prime) | views::transform(square));

static_assert(result == by_hand());

int main() {
    std::println("n = {}: {} primes, sum of squares {}", limit, result.count,
                 result.sum);
}
// b988da81-da87-4389-95bc-ecf59972f6cd end
