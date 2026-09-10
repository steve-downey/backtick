# U18 — clang-format

**Goal.** clang-format tokenizes user operators and spaces them like
binary/unary operators, in expressions and in `operator⊞` declarations.

**Depends on:** U04. (Independent of everything in Phases B–D — it works on
tokens, not on Sema, so it can run in parallel with the whole name track.)
**Design refs:** backtick §7 and `ops/handoffs/10-clang-format.handoff.md`
— clang-format re-lexes with its own `FormatTokenLexer` and does **not**
share the Sema/parse work; S10's handoff records how the backtick token was
threaded through and is the map for this step.

## Do
1. Teach `FormatTokenLexer` / `TokenAnnotator` to recognize the token.
   Note that clang-format is configured by `LangOptions` it constructs
   itself — the U01 flag is not automatically on; decide how the feature is
   enabled for formatting (S10's handoff records what backtick did) and
   follow that precedent rather than inventing a style option.
2. Spacing: binary use gets spaces on both sides; prefix use binds to its
   operand with no space. Existing `TT_UnaryOperator` / `TT_BinaryOperator`
   annotation should do the work once the token is classified — position
   determines which, exactly as in the parser (U5).
3. `operator⊞` in a declaration must not be split between `operator` and
   the glyph.
4. Column-width accounting: these are multi-byte UTF-8 characters of
   display width 1. clang-format already handles this for extended
   identifiers; confirm it, don't reimplement it.

## Build
`ninja -C ~/src/llvm/build-unicode clang-format FormatTests`

## Verify (gate)
- New cases in `clang/unittests/Format/FormatTest.cpp` (and
  `TokenAnnotatorTest.cpp` for the annotations): infix spacing, prefix
  binding, declaration, mixed backtick/Unicode chain, UCN spellings,
  line breaking at the operator, and a long chain wrapping.
- Idempotence: formatting formatted output is a no-op.
- `check-clang` green — **and mind the trap**: `check-clang` self-formats
  `clang/lib/Format/` and aborts at ~step 81/970 before any lit test runs
  if your edits there don't match current LLVM style. Run
  `clang-format -i` (with the *upstream* binary) on every file you touched
  in `clang/lib/Format/` before gating. This has bitten this project twice.

## Done when
Formatting is correct and stable for every use, and the self-format gate
passes.

## Capture in handoff
How the feature is enabled in the format path, and the annotation types
used. Note whether the backtick formatting code needed generalizing — if it
did, that is a `shared if landed` item.

## REPLAY ledger
Likely mixed. Be specific per file.
