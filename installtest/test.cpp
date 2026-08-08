// testinstall/test.cpp                                               -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#include <iostream>
#include <smd/infix/infix.hpp>

int main() {
    std::cout << "infix: |" << infix::infix() << '|' << '\n';
    return 0;
}
