// installtest/test.cpp                                               -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

// Built by the *system* compiler, with no toolchain file and no -fbacktick.
// That is the point: smd::infix is an ordinary header-only library, and the
// only thing in this project that needs the extension is the example code
// that spells calls infix.

#include <smd/infix/pipe.hpp>

#include <iostream>

int main() {
    const auto twice = [](int n) { return n * 2; };
    std::cout << "pipe: |" << smd::infix::pipe(21, twice) << '|' << '\n';
    return 0;
}
