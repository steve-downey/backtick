# U03 — Lexer: `tok::user_operator` from UTF-8 glyphs

**Goal.** Under `-funicode-operators`, a U1 code point written directly as
UTF-8 lexes as a single new token carrying its code point. Off the flag,
byte-identical to upstream.

**Depends on:** U01, U02.
**Design refs:** U3 (lexing is declaration-independent); U§8 "Clang —
*Lexer*"; U1 (one code point = one token, no maximal-munch question).

## Do
1. Add the token kind to `clang/include/clang/Basic/TokenKinds.def`. It is
   not a `PUNCTUATOR` (those are spelled by a fixed string); it needs a kind
   whose spelling comes from the token's own text — model the declaration on
   how `tok::identifier`-family kinds are declared, and confirm the choice
   in the handoff.
2. In the non-ASCII slow path of `Lexer::LexTokenInternal` — the same place
   that decodes UTF-8 for extended identifiers, `LexUnicodeIdentifierStart`
   / `tryConsumeIdentifierUTF8Char` and friends — after decoding a code
   point, consult `isUserOperatorChar()` **before** the identifier
   classification, and mint the new token when `LangOpts.UnicodeOperators`
   is set. Order against XID is immaterial (U10 makes them disjoint) but
   pick one and state it.
3. Carry the code point on the token. The token's text is its source
   spelling; the *identity* the parser and Sema need is the scalar value.
   Prefer deriving identity from the spelling over adding a new payload
   field if that is workable — say which you did and why.
4. Nothing else: no parse, no operator-function-id, no diagnostics beyond
   what falls out. A U1 character in a string literal, character literal,
   comment, or raw-string body must stay part of it.

## Build
`ninja -C ~/src/llvm/build-unicode clang`

## Verify (gate)
- Lit test `clang/test/Lexer/unicode-operators.cpp` with `-dump-tokens`:
  ⊞ ⊗ ↦ each produce one `user_operator` token under the flag.
- `a⊞b` (no spaces) produces three tokens — identifier, operator,
  identifier. Adjacent-token splitting is the property that makes the
  feature usable without whitespace rules; test it explicitly.
- `⊞⊗` produces two tokens (no operator is a prefix of another — U1).
- Without the flag: every one of the above lexes exactly as upstream does
  today. Diff against `~/src/llvm/build-main/bin/clang -dump-tokens` if the
  expected diagnostic is not obvious.
- U1 characters inside `"…"`, `'…'`, `//`, `/* */`, and `R"(…)"` are
  untouched under both flag states.
- `check-clang` green.

## Done when
The token exists under the flag and nowhere else, with literals and
comments unaffected and adjacency working.

## Capture in handoff
The exact token kind name; how code-point identity is carried; the precise
function and line in `Lexer.cpp` where the hook landed; and what the
off-flag behavior is (which diagnostic, verbatim) — U05 must phrase its
diagnostics consistently with it, and U11/U12 need the token kind.

## Pitfalls
Gate the *classification*, not the decode. The UTF-8 decode already happens
upstream for identifiers; adding an ungated token kind would regress every
TU containing a math glyph in a place upstream diagnoses differently.
Watch for a second decode path — the preprocessor and the raw lexer are not
always the same route.

## REPLAY ledger
`upstream replay`, but note any helper you reused that arrived with
backtick.
