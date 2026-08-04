# U11 — Infix parse at the user-infix level

**Goal.** `a ⊞ b` parses as a binary operator at the shared user-infix
precedence level — tighter than `*`, looser than unary, left-associative,
operands are cast-expressions — and reaches Sema as an unresolved call.

**Depends on:** U08.
**Design refs:** U4 (the backtick level, D2 Option A, verbatim); U§6
(grammar); backtick design §4 (the precedence rationale, already litigated).

## Do
1. In `Parser::getBinOpPrecedence` (`clang/lib/Parse/ParseExpr.cpp`), give
   `tok::user_operator` the **same** `prec::Level` the backtick track
   introduced, gated on `LangOpts.UnicodeOperators`. Do not add a second
   level. If the level is currently named for backtick, rename it to
   `UserInfix` in this step and note the rename in REPLAY — U12 in the
   paper (U§12) turns on that name being shared.
2. In `ParseRHSOfBinaryExpression`, add the `tok::user_operator` case
   alongside `tok::backtick`. There is **no** suppression flag, no
   delimiter matching, no `BacktickIsOperator` analogue — the same-delimiter
   problem does not arise (U§3).
3. Build the action call: hand Sema the operator's code-point identity, the
   LHS, the RHS, and the operator location. Keep the callee **unresolved**
   at this point — U13 does candidate assembly, and resolving here is
   precisely the DEV-G05 mistake.
4. Left-associativity falls out of the precedence machinery; do not
   special-case it. Operands as cast-expressions likewise: the level's
   position in the table already enforces it.
5. Minimal Sema for now: a stub that builds *something* type-correct so the
   parse tests can run. U13 replaces the body.

## Build
`ninja -C ~/src/llvm/build-unicode clang`

## Verify (gate)
- `clang/test/Parser/unicode-operator-infix.cpp` with `-ast-dump`:
  `a ⊞ b`, `a ⊞ b ⊗ c` (left-assoc), `a * b ⊞ c` (⊞ binds tighter),
  `-a ⊞ -b` (symmetric — both operands are cast-expressions).
- **Composability with backtick** (U7/U4): with both flags on,
  `a ⊞ b `f` c` groups left across the mixed chain. With `-fbacktick`
  *off* and `-funicode-operators` on, `a ⊞ b` still parses at the same
  level. Both directions matter; the shared level is a design claim.
- `a ⊞ {1,2}` is rejected (no braced-init-list operands — D9 carried).
- Without the flag, unchanged.
- `check-clang` green.

## Done when
The infix form parses at the shared level with correct grouping under every
flag combination, callee still unresolved.

## Capture in handoff
The `prec::Level` enumerator name (after any rename), the exact Sema action
signature, and how operator identity is passed. U12 and U13 both start
here. Also note how much of `ParseRHSOfBinaryExpression` was already
generalized by the backtick work versus needed widening — that ratio is a
REPLAY input.

## REPLAY ledger
The likeliest place in the whole plan to record `backtick dependency` or
`shared if landed`. Be precise: which lines exist only because the backtick
diff is present, and what the clean-`main` equivalent would be.
