// src/examples/consteval/eval.backtick.cpp                          -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// eval.pipe.cpp with the calls spelled infix. Everything above the pipeline
// is the same text in both files, so a difference in what the constant
// evaluator does is a difference the spelling made.
//
// The last stage takes nothing beyond the range, so it keeps the `pipe`
// helper -- and keeps the chain reading left to right, where the pipe
// spelling has to wrap it in a call.

#include <smd/infix/pipe.hpp>

#include <array>
#include <print>
#include <ranges>

// The size knob. A macro because the harness sets it from the command line;
// nothing else in this project needs one.
#ifndef SMD_EVAL_N
#define SMD_EVAL_N 200
#endif

namespace views = std::views;
using smd::infix::pipe;

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

// 27a66254-59b0-4027-9b39-b737122334bf
constexpr totals result = views::iota(2, limit) `views::filter`
    is_prime `views::transform` square `pipe` tally;

static_assert(result == by_hand());

int main() {
    std::println("n = {}: {} primes, sum of squares {}", limit, result.count,
                 result.sum);
}
// 27a66254-59b0-4027-9b39-b737122334bf end
