# U12 — Prefix parse in operand position

**Goal.** `⊖a` parses as a prefix user operator, binding like the other
unary operators (tighter than any binary), disambiguated from the infix
form purely by grammatical position.

**Depends on:** U11. (Parallel with U13.)
**Design refs:** U5 (arity declares the form, position disambiguates uses,
no postfix); U§6 (the `unary-expression` production); D10 (the same
position-based strategy backtick used for escape-vs-infix).

## Do
1. In `Parser::ParseCastExpression`, add a `tok::user_operator` case in
   operand position: consume the operator, parse a cast-expression, and
   build the prefix action.
2. Nothing decides prefix-vs-infix by lookahead, whitespace, or
   declaration lookup. The expression grammar strictly alternates operand
   and operator positions, so the two productions cannot both apply — if
   you find yourself needing a tiebreak, something upstream is wrong and it
   is a DEVIATION worth writing up carefully (this is exactly the trap that
   forces Swift's whitespace sensitivity, and U5 claims C++ avoids it).
3. Same unresolved-callee discipline as U11.

## Build
`ninja -C ~/src/llvm/build-unicode clang`

## Verify (gate)
- `clang/test/Parser/unicode-operator-prefix.cpp` with `-ast-dump`:
  `⊖a`, `⊖⊖a` (stacked prefix), `a ⊞ ⊖b`, `⊖a ⊞ b`, `⊖a * b`
  (prefix binds tighter than `*`), `⊖(a ⊞ b)`.
- The same code point used both ways in one expression: `⊖a ⊖ b` —
  prefix then infix, given both `operator⊖` overloads. This is the
  acceptance test for position-based disambiguation.
- A postfix use `a⊖;` is an error (no postfix form, U5), and the error is
  comprehensible.
- Without the flag, unchanged.
- `check-clang` green.

## Done when
Prefix and infix uses of the same operator coexist in one expression with
no lookahead and no whitespace rule.

## Capture in handoff
Whether any position genuinely needed a tiebreak, and the diagnostic text
for a postfix attempt. U14/U15 consume both.

## REPLAY ledger
`upstream replay` — the prefix production is new, not inherited from
backtick.
