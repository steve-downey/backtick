// src/examples/hello.cpp                                            -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#include <smd/infix/pipe.hpp>

#include <print>
#include <string>

using smd::infix::pipe;

namespace {
std::string greet(std::string_view who) { return "Hello, " + std::string{who} + "!"; }
} // namespace

// 46634163-8eef-49f1-a93e-4e259981ed49
int main() { std::println("{}", "Steve" `pipe` greet); }
// 46634163-8eef-49f1-a93e-4e259981ed49 end
