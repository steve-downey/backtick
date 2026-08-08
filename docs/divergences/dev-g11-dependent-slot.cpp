// docs/divergences/dev-g11-dependent-slot.cpp                       -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// DEV-G11: an unqualified slot name in a dependent context.
//
// Not part of the build. It is here because the two prototypes disagree
// about it, and a divergence is worth more as a file someone can compile
// than as a paragraph. It was found while writing src/examples/senders/
// scan.backtick.cpp, whose async_inclusive_scan is a template.
//
//   $ clang++ -fbacktick -std=gnu++26 -fsyntax-only dev-g11-dependent-slot.cpp
//   (accepted, both the release/23.x and trunk tracks)
//
//   $ g++-17-backtick -fbacktick -std=gnu++23 -fsyntax-only dev-g11-dependent-slot.cpp
//   error: 'pipe' was not declared in this scope, and no declarations were
//   found by argument-dependent lookup at the point of instantiation
//
// The GCC prototype resolves a bare-name slot with perform_koenig_lookup
// (the G10 fix for DEV-G05). For a dependent call it re-runs that lookup at
// the point of instantiation and keeps only the ADL result, discarding the
// ordinary lookup from the point of definition. ADL finds nothing here: pipe
// is a variable rather than a function, and no argument's associated
// namespace is n. [temp.dep.candidate] says the candidate set is ordinary
// lookup at the point of definition *plus* ADL at the point of instantiation,
// so dropping the first half is a bug -- and since the slot is defined to
// desugar to a call, it should inherit the call's lookup unchanged.
//
// Writing the slot qualified works on both compilers, which is the
// workaround scan.backtick.cpp uses.

#include <functional>
#include <utility>

namespace n {
inline constexpr auto pipe = []<class X, class F>(X&& x, F&& f) -> decltype(auto) {
    return std::invoke(std::forward<F>(f), std::forward<X>(x));
};
}

using n::pipe;

constexpr auto inc = [](int v) { return v + 1; };

// Not a template: the slot is looked up here, and both compilers accept.
int plain() { return 1 `pipe` inc; }

// A template: same slot name, dependent operand. GCC rejects at instantiation.
template <class T>
auto dependent(T t) {
    return t `pipe` inc;
}

// Qualified: accepted by both, in a template or out of one.
template <class T>
auto dependent_qualified(T t) {
    return t `n::pipe` inc;
}

int main() { return plain() + dependent(1) + dependent_qualified(1) - 6; }
