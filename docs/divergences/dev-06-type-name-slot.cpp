// docs/divergences/dev-06-type-name-slot.cpp                        -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// DEV-06 / DEV-G12: a type name in the operator slot (design D16, §17.3).
//
// Not part of the build. The design records D16 as Resolved, and the wording
// example in the paper carries it:
//
//     auto r7 = a `std::pair` b;  // std::pair(a, b): CTAD applies
//
// Neither prototype implements it. Every spelling below is rejected by both,
// while the control -- the same construction written as an ordinary call --
// compiles. Nothing here is scope- or constant-evaluation-dependent; it fails
// the same way at block scope, at namespace scope, and inside static_assert.
//
//   $ clang++ -fbacktick -std=gnu++26 -fsyntax-only dev-06-type-name-slot.cpp
//   error: 'Point' does not refer to a value
//   error: expected '(' for function-style cast or type construction
//   error: expected '(' for function-style cast or type construction
//   error: unexpected type name 'PI': expected expression
//
//   $ g++-17-backtick -fbacktick -std=gnu++23 -fsyntax-only dev-06-type-name-slot.cpp
//   error: no match for call to '(Point) (int, int)'
//   error: missing template arguments before '`' token
//   error: expected primary-expression before '`' token
//   error: no match for call to '(PI {aka std::pair<int, int>}) (int, int)'
//
// The two diagnostics say the compilers are doing different wrong things.
// Clang wants the slot to be a value and stops as soon as the name resolves
// to a type. GCC accepts the name and then treats it as an *object* of that
// type, looking for operator() -- which is why it complains about a call to
// '(Point) (int, int)' rather than about construction.
//
// D16 is not a special rule in the design; it is meant to fall out of "the
// slot is any callable expression, and a type name is callable". The
// prototypes show that it does not fall out on its own: functional-style
// construction is a distinct production, and neither parser reaches it from
// the slot. Either the wording says so explicitly and both parsers gain a
// case, or D16 comes out of the paper.

#include <utility>

struct Point {
    int x;
    int y;
};

using PI = std::pair<int, int>;

int plain_type() {
    auto p = 1 `Point` 2;
    return p.x;
}

int class_template_ctad() {
    auto p = 1 `std::pair` 2;
    return p.first;
}

int explicit_template_id() {
    auto p = 1 `std::pair<int, int>` 2;
    return p.first;
}

int alias() {
    auto p = 1 `PI` 2;
    return p.first;
}

// Control: the call the slot is supposed to desugar to. Accepted by both.
int control() {
    auto p = Point(1, 2);
    return p.x;
}

int main() { return plain_type() + class_template_ctad() + explicit_template_id() + alias() + control(); }
