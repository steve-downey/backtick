# U15 — Precedence and associativity sweep

**Goal.** Pin the grammar decisions with tests: one level for all
user-introduced infix, left-associative, operands are cast-expressions,
prefix binds tighter than any binary — including mixed chains with
backtick. Tests only.

**Depends on:** U13, U12.
**Design refs:** U4; U9 (no user-declared precedence, ever — this sweep is
the evidence that a single fixed level suffices); U§6's worked examples;
backtick §4.

## Do
Write `clang/test/Parser/unicode-operator-precedence.cpp`, checking the
parse with `-ast-dump` (or a tag-returning overload set, which reads better
in diffs) for at least:
1. `a ⊞ b ⊞ c` → `operator⊞(operator⊞(a,b), c)` — left-associative.
2. `a ⊞ b ⊗ c` → `operator⊗(operator⊞(a,b), c)` — one level, no
   inter-operator precedence.
3. `a * b ⊞ c` → `a * operator⊞(b,c)`; `a ⊞ b * c` → `operator⊞(a,b) * c`
   — tighter than `*`.
4. `-a ⊞ -b` → `operator⊞(-a, -b)` — symmetric, both operands
   cast-expressions (the §4 property U4 inherits).
5. `⊖a ⊞ b` and `a ⊞ ⊖b` — prefix binds tighter.
6. `a ⊞ b == c`, `a ⊞ b, c`, `x = a ⊞ b` — relation to lower levels.
7. `*p ⊞ *q`, `a.m ⊞ b.m`, `f(a) ⊞ g(b)`, `(T)x ⊞ y` — postfix and cast
   operands.
8. **Mixed chains, both flags on:** `a ⊞ b `f` c` and `a `f` b ⊞ c` both
   group left across the shared level. This is U4's load-bearing claim and
   the reason the level is named *user-infix* rather than *backtick*.
9. The same expressions with `-fbacktick` off (Unicode only) parse
   identically apart from the backtick terms — no flag-dependent
   precedence.
10. Parenthesized regrouping works as expected everywhere above.

## Build
No source change expected.

## Verify (gate)
- All tests pass; `check-clang` green.
- A failure here is a U11/U12 bug — file BLOCKED against the owner.

## Done when
Every grouping in U§6's table is asserted by a test, under every relevant
flag combination.

## Capture in handoff
Any expression whose grouping surprised you, and whether the mixed-chain
cases required anything beyond the shared level. The paper (U§12) argues
EWG can bank "one level, left-assoc, desugar-to-call" once for both
features; this test file is that argument's evidence, so note how directly
it can be quoted.

## REPLAY ledger
`upstream replay` for the pure-Unicode cases; the mixed-chain cases are
`shared if landed` — they cannot run on clean `main` without backtick.
Mark them so U20 knows to split the test file.
