# U14 — Semantics sweep

**Goal.** Prove the inheritance claim: because `x ⊞ y` *is* the call
`operator⊞(x, y)`, everything the language gives calls comes along —
overload resolution, conversions, value categories, templates, SFINAE,
constexpr, exceptions, evaluation order. Tests only.

**Depends on:** U13, U12.
**Design refs:** U§7 "Desugaring"; D6's inheritance list and D15
(evaluation order is the call's), both carried verbatim.

## Do
Write `clang/test/SemaCXX/unicode-operator-semantics.cpp` (plus CodeGen
siblings where a runtime property is at issue), covering:
1. Class-type operands, member and non-member forms, `const`/ref
   qualification, rvalue vs lvalue operands, returned references used as
   lvalues.
2. Implicit conversions on arguments; ambiguity when two overloads are
   equally good; explicit-conversion cases.
3. `constexpr` / `consteval` evaluation in a `static_assert`, including
   the fundamental-only case `static_assert(5 ⊞ 7 == 12)`.
4. Function templates, class-template members, dependent operands,
   two-phase lookup, SFINAE, `requires`-clauses, and a concept constrained
   on `a ⊞ b` being well-formed.
5. `noexcept(a ⊞ b)` reporting the callee's specification; a throwing
   operator propagating.
6. Evaluation order (D15): the call's rules, indeterminately sequenced
   arguments — assert what the standard actually guarantees for a call, no
   more. Do not assert left-to-right unless the call form guarantees it.
7. Deleted operator selected → the ordinary use-of-deleted diagnostic.
8. Prefix-form equivalents of the interesting cases above.
9. Both flags on, both off, and each alone, on a representative case.

## Build
No source change expected.

## Verify (gate)
- All tests pass; `check-clang` green.
- Any failure that needs a source fix belongs to U13 (or earlier): write a
  BLOCKED handoff naming the owner rather than patching Sema here.

## Done when
The sweep passes and the inheritance claim is evidenced rather than
asserted.

## Capture in handoff
Anything that did **not** simply fall out of being a call. The paper's
central claim is that nothing has to be reimplemented; a counterexample is
the most valuable thing this step can produce, and it goes to DEVIATIONS.

## REPLAY ledger
`upstream replay` (tests).
