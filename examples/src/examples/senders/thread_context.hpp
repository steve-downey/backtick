// src/examples/senders/thread_context.hpp                           -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#ifndef INCLUDED_EXAMPLES_SENDERS_THREAD_CONTEXT
#define INCLUDED_EXAMPLES_SENDERS_THREAD_CONTEXT

// Scaffolding shared by the sender examples: a run_loop with a thread to
// drive it. It lives here so that a .pipe.cpp and its .backtick.cpp differ
// only in how they spell their calls -- which is the claim those pairs are
// there to check.

#include <beman/execution/execution.hpp>

#include <latch>
#include <string>
#include <thread>
#include <utility>

namespace examples {

class thread_context {
  public:
    explicit thread_context(std::string name)
        : d_name(std::move(name)), d_thread([this] {
              d_id = std::this_thread::get_id();
              d_ready.count_down();
              d_loop.run();
          }) {
        d_ready.wait();
    }

    ~thread_context() { d_loop.finish(); }

    thread_context(const thread_context &) = delete;
    thread_context &operator=(const thread_context &) = delete;

    auto scheduler() { return d_loop.get_scheduler(); }
    auto id() const -> std::thread::id { return d_id; }
    auto name() const -> const std::string & { return d_name; }

  private:
    std::string d_name;
    beman::execution::run_loop d_loop{};
    std::thread::id d_id{};
    std::latch d_ready{1};
    std::jthread d_thread;
};

} // namespace examples

#endif // INCLUDED_EXAMPLES_SENDERS_THREAD_CONTEXT
