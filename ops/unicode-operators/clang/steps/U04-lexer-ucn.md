# U04 — Lexer: UCN and `\N{...}` spellings form operator tokens

**Goal.** `⊞`, `\U0000229E`, and `\N{SQUARED PLUS}` each form the same
`user_operator` token as a literal ⊞ — in expressions *and* in
`operator⊞`.

**Depends on:** U03. (Parallel with U05 and U06.)
**Design refs:** U11 (the decision, and the reversal of the earlier
no-UCN rule); U§8 second-to-last paragraph (why no phase-ordering wrinkle
arises).

## Do
1. Find where the lexer's existing UCN path produces a code point during
   phase-3 token formation (`Lexer::tryReadUCN` / `getCharAndSizeSlow`
   territory, plus the `\N{...}` named-UCN handling added for C++23).
2. Give that code point the same three-way classification U03 gave a
   literal one: XID → identifier constituent; U1 → `user_operator`;
   otherwise the existing ill-formed diagnostic. One classification helper,
   two callers — do not duplicate the table search.
3. Confirm the equivalence holds at token level, not just at parse level:
   `a⊞b` must produce the same three tokens as `a⊞b`.

## Build
`ninja -C ~/src/llvm/build-unicode clang`

## Verify (gate)
- Lit test extending `clang/test/Lexer/unicode-operators.cpp`: all four
  spellings (glyph, `\u`, `\U`, `\N{}`) `-dump-tokens` identically.
- `a⊞b` ≡ `a ⊞ b` at token level.
- A UCN naming a *non*-U1, non-XID code point still gets the existing
  diagnostic, unchanged.
- A UCN naming an excluded code point (e.g. `−`) behaves as U05
  specifies for the literal glyph — if U05 has not run yet, make sure the
  path is at least not silently accepted, and note the coupling.
- Without `-funicode-operators`, all four spellings behave exactly as
  upstream.
- `check-clang` green.

## Done when
Extended-character ≡ UCN equivalence holds for operator tokens in both
expression and declaration position.

## Capture in handoff
Whether the UCN path and the direct-UTF-8 path really converge on one
classification helper, or whether Clang forced two. That is the fact U18
(clang-format, which re-lexes) and the paper both need. If they diverged,
file a DEVIATION — U§8 asserts they converge.

## Pitfalls
`operator⊞` in *declaration* position runs through a different caller
than an expression does; U07 will parse it, but the token must already be
right here. Also: the "no normalization at lex time" rule (U§8) — do not
add any NFC processing on this path.

## REPLAY ledger
`upstream replay`.
