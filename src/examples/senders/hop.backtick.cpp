// src/examples/senders/hop.backtick.cpp                             -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// hop.pipe.cpp with the calls spelled infix.
//
// This one goes further than replacing a pipe. starts_on(sched, sndr) takes
// its scheduler first and has no one-argument closure form, so there is no
// `sndr | starts_on(sched)` to write. An infix operator does not care which
// argument is the subject, so the chain stays a chain.
//
// Left associativity puts the stages in the right order without parentheses:
// this is then(continues_on(then(starts_on(...), mark), b), mark).

#include "thread_context.hpp"

#include <smd/infix/pipe.hpp>

#include <beman/execution/execution.hpp>

#include <print>
#include <string>
#include <thread>
#include <tuple>
#include <utility>

namespace ex = beman::execution;
using smd::infix::pipe;

// df720525-1992-407d-b375-908af9ec77ca
int main() {
    examples::thread_context a{"A"};
    examples::thread_context b{"B"};

    auto here = [&a, &b] {
        auto id = std::this_thread::get_id();
        return id == a.id()   ? a.name()
               : id == b.id() ? b.name()
                              : std::string{"main"};
    };
    auto mark = [&here](std::string trail) {
        return trail.empty() ? here() : trail + " " + here();
    };

    auto hop = a.scheduler() `ex::starts_on` ex::just(std::string{}) `ex::then`
               mark `ex::continues_on` b.scheduler() `ex::then` mark;

    auto [trail] = (std::move(hop) `pipe` ex::sync_wait).value();
    std::println("{}", trail);
}
// df720525-1992-407d-b375-908af9ec77ca end
