// testinstall/test.cpp                                               -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#include <iostream>
#include <smd/backticks/backticks.hpp>

int main() {
    std::cout << "backticks: |" << backticks::backticks() << '|' << '\n';
    return 0;
}
