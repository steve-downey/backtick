# U05 — Exclusion diagnostics with reasons

**Goal.** An excluded code point in source produces a diagnostic that says
*why* it is excluded and what to write instead — not a generic stray
character error.

**Depends on:** U03. (Parallel with U04 and U06.)
**Design refs:** U§8 paragraph 2 ("keep the exclusion list as a second,
tiny table with reasons"); U§5 predicate 5; U§10 (the exclusions exist for
the reader's protection).

## Do
1. Add diagnostics in `clang/include/clang/Basic/DiagnosticLexKinds.td`
   keyed off `getExclusionReason()` from U02:
   - `ConfusableWith`: "U+2212 MINUS SIGN is not an operator; did you mean
     `-`?" — the ASCII token comes from the table, not from a switch.
   - `IdentifierProfile`: "'∂' is an identifier character (mathematical
     notation profile), not an operator".
   - `EmojiPresentation`: an emoji-presentation character is not an
     operator.
2. Emit them from the U03 classification point, under the flag only.
3. Recovery: emit and continue with the existing error recovery. Do **not**
   silently alias — a character that looks like `-` but isn't must fail to
   lex (U§5, "rejected outright, never aliased"). Assert the non-aliasing
   in a test; it is a security property, not a nicety.

## Build
`ninja -C ~/src/llvm/build-unicode clang`

## Verify (gate)
- `-verify` test `clang/test/Lexer/unicode-operators-excluded.cpp`: one
  case per reason kind, checking the specific wording.
- `int x = 1 − 2;` (U+2212) errors and does **not** compile as subtraction.
- `∂` in an expression reports the identifier-profile message. Note whether
  Clang's shipped math-identifier extension (D137051) is on in the test
  configuration — if it is, `∂` may already be a valid identifier and the
  message must not fire. That interaction is U10's composability claim
  (U§7.1); whatever you find, record it.
- Off-flag behavior for all of the above is upstream's, unchanged.
- `check-clang` green.

## Done when
Each exclusion reason produces its own message, and no excluded character
is ever accepted as an operator or aliased to an ASCII token.

## Capture in handoff
The diagnostic IDs, and the D137051 interaction as actually observed — the
design predicts the operator set and the extended-identifier set stay
disjoint even with the extension on ({∂ ∇ ∞} being the entire overlap, all
three ceded to the identifier side). Confirming or breaking that prediction
is a paper-grade result either way.

## REPLAY ledger
`upstream replay`.
