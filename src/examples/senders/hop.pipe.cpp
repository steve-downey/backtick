// src/examples/senders/hop.pipe.cpp                                 -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// Moving work between execution contexts. Each stage reports the thread it
// actually ran on, so the printed trail is evidence rather than a caption.
// hop.backtick.cpp is the same chain with the calls spelled infix.

#include "thread_context.hpp"

#include <beman/execution/execution.hpp>

#include <print>
#include <string>
#include <thread>
#include <tuple>
#include <utility>

namespace ex = beman::execution;

// 6b073fbc-0529-4f69-8759-bf5583c7fe7d
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

    // starts_on takes the scheduler first and has no one-argument closure
    // form, so there is no `sndr | starts_on(sched)` to write: the pipeline
    // has to be broken open into a call and then resumed.
    auto hop = ex::starts_on(a.scheduler(), ex::just(std::string{})) |
               ex::then(mark) | ex::continues_on(b.scheduler()) |
               ex::then(mark);

    auto [trail] = ex::sync_wait(std::move(hop)).value();
    std::println("{}", trail);
}
// 6b073fbc-0529-4f69-8759-bf5583c7fe7d end
