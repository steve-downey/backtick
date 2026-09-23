// src/examples/senders/chain.backtick.cpp                           -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// chain.pipe.cpp with the calls spelled infix. It is the same story as the
// range adaptors: then(sndr, fn) is already the primary overload, and
// operator| is there because there was no way to write it between its
// arguments.
//
// sync_wait takes nothing beyond the sender, so it keeps the `pipe` helper,
// and when_all is variadic, so it stays a call. Neither is a defect in the
// operator -- a backtick operator is exactly binary, and those are not.

#include <smd/infix/pipe.hpp>

#include <beman/execution/execution.hpp>

#include <print>
#include <string>
#include <tuple>
#include <utility>

namespace ex = beman::execution;
using smd::infix::pipe;

namespace {
constexpr auto inc = [](int n) { return n + 1; };
constexpr auto dbl = [](int n) { return n * 2; };
constexpr auto describe = [](int n) { return "n = " + std::to_string(n); };
} // namespace

// a2c278fa-1f76-4548-972a-885c7d276169
int main() {
    auto chain = ex::just(3) `ex::then` inc `ex::then` dbl `ex::then` describe;

    auto [text] = (std::move(chain) `pipe` ex::sync_wait).value();
    std::println("{}", text);

    // when_all is variadic, so it stays a call in both spellings.
    auto both =
        ex::when_all(ex::just(2) `ex::then` dbl, ex::just(5) `ex::then` inc);

    auto [a, b] = (std::move(both) `pipe` ex::sync_wait).value();
    std::println("{} {}", a, b);
}
// a2c278fa-1f76-4548-972a-885c7d276169 end
