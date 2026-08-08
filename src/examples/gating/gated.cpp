// src/examples/gating/gated.cpp                                     -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// Compiled twice by the backtick.is-gated test, never linked: once with the
// prototype's flag, where it must succeed, and once with -fno-backtick, where
// it must fail. Keep it self-contained -- it is compiled outside the build
// graph, so it gets no include directories.

// 7ed5d37b-5384-4b83-98d8-756c5f5a88a3
constexpr int add(int a, int b) { return a + b; }

static_assert((2 `add` 3) == 5);
// 7ed5d37b-5384-4b83-98d8-756c5f5a88a3 end
