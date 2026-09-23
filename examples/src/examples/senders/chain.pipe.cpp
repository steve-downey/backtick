// src/examples/senders/chain.pipe.cpp                               -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// A sender chain in the P2300 idiom. chain.backtick.cpp is the same chain
// with the calls spelled infix; the two must print the same thing.

#include <beman/execution/execution.hpp>

#include <print>
#include <string>
#include <tuple>
#include <utility>

namespace ex = beman::execution;

namespace {
constexpr auto inc = [](int n) { return n + 1; };
constexpr auto dbl = [](int n) { return n * 2; };
constexpr auto describe = [](int n) { return "n = " + std::to_string(n); };
} // namespace

// a275388f-2852-428a-8172-164c9544779c
int main() {
    auto chain =
        ex::just(3) | ex::then(inc) | ex::then(dbl) | ex::then(describe);

    auto [text] = ex::sync_wait(std::move(chain)).value();
    std::println("{}", text);

    // when_all is variadic, so it stays a call in both spellings.
    auto both =
        ex::when_all(ex::just(2) | ex::then(dbl), ex::just(5) | ex::then(inc));

    auto [a, b] = ex::sync_wait(std::move(both)).value();
    std::println("{} {}", a, b);
}
// a275388f-2852-428a-8172-164c9544779c end
