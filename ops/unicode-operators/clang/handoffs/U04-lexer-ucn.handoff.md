# Handoff — U04 Lexer: UCN and `\N{...}` spellings form operator tokens

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `6ffc374fa25a`
  (parent `c25fdda912be`, U15)
- **Date / agent:** 2026-08-04

The oldest unpaid debt in the plan is paid. **Phase A is complete except
U05**, U18 is unblocked, and the "all spellings behave identically" claim —
which had *zero* evidence in the tree an hour ago, as five separate handoffs
complained — is now asserted at the token level, at the declaration level, at
the call level, in the mangled symbol, and in the printed AST.

## The two-sentence version

U§8's convergence assertion holds and can be quantified: **one classification
point, four callers, and the UCN half of the token rule is two lines.** What
is *not* free — and what U§8's "structurally free" hides — is the
**identity**: `Lexer::getUserOperatorCodePoint` answered **0** for a
UCN-spelled token, so lexing the UCN without teaching that one function to
decode it would have made `operator\U0000229E` a different entity from
`operator⊞`, with a different mangled symbol, while `-dump-tokens` and the
step file's own gate looked perfectly correct. See **DEV-U18**.

## What changed

**Production: 3 files, +145/−10.**

| File | Change |
|------|--------|
| `clang/include/clang/Lex/Lexer.h` | **+26.** Two private declarations — `bool isUserOperatorCodePoint(uint32_t) const` and `bool LexUserOperator(Token &, const char *)` — after `tryConsumeIdentifierUTF8Char`; plus a paragraph in `getUserOperatorCodePoint`'s doc comment stating the equivalence it now implements |
| `clang/lib/Lex/Lexer.cpp` | **+107/−9.** File-static `decodeUCNSpelling` (before `getUserOperatorCodePoint`); the `Spelling.front() == '\\'` branch in `getUserOperatorCodePoint(StringRef)`; the two new `Lexer` member definitions (immediately above `LexUnicodeIdentifierStart`); the early return in `tryConsumeIdentifierUCN`; the hook in `LexTokenInternal`'s `case '\\':`; and the rewrite of U03's `default:` hook through the two new helpers |
| `clang/include/clang/Options/Options.td` | **+12/−4.** `ShouldParseIf<cplusplus.KeyPath>` on **both** `defm unicode_operators` and `defm backtick`, with the comment saying why they take it together (DEV-U07) |

**Tests: 3 new files, 6 amended.**

| File | Change |
|------|--------|
| `clang/test/Lexer/unicode-operators-ucn.cpp` | **new**, 3 RUN lines — the token-level half: five spellings, adjacency, two-in-a-row, literals, and the excluded-code-point-via-UCN case |
| `clang/test/Lexer/unicode-operators-c-mode.c` | **new**, 4 RUN lines — DEV-U07, stated as a *diff* between flag-on and flag-off C compilations |
| `clang/test/Lexer/backtick-c-mode.c` | **new**, 4 RUN lines — the `-fbacktick` half of the same; **a backtick-track file**, flagged in `REPLAY.md` |
| `clang/unittests/Lex/LexerTest.cpp` | **+118**, five cases: `UnicodeOperatorCodePointFromUCNSpelling`, `UnicodeOperatorUCNSpellingsAreOneOperator`, `UnicodeOperatorUCNAdjacency`, `UnicodeOperatorUCNRequiresTheFlag`, `UnicodeOperatorUCNOfExcludedCodePointIsNotAToken` |
| `clang/test/Parser/unicode-operator-decl.cpp` | U07's deferred acceptance test, verbatim as U07 specified it |
| `clang/test/SemaCXX/unicode-operator-call.cpp` | U10's item 8 — new section 9, four cases |
| `clang/test/CodeGenCXX/unicode-operator-mangle.cpp` | U09's one-line proof, plus `--implicit-check-not=op_u0000` on both CHECK RUN lines |
| `clang/test/AST/unicode-operator-print.cpp` | U16's two RUN lines — `-DSPELL_UCN` and a byte-identical `-ast-print` diff; new section 6 |
| `clang/test/Parser/unicode-operator-precedence.cpp` | U15's ask — a UCN redeclaration plus three UCN-spelled grouping assertions |

**In this repo:** `PLAN.md` (U04 ticked, Status row), `REPLAY.md` U04 row,
`DEVIATIONS.md` **DEV-U18** and **DEV-U07 marked resolved**, this handoff.

## The three questions the step file asked

### 1. Do the two decode paths really converge on one classification helper?

**Yes, and U§8 is right for the reason it gives.** There is exactly one
classification point:

```cpp
bool Lexer::isUserOperatorCodePoint(uint32_t CodePoint) const {
  return LangOpts.UnicodeOperators && isUserOperatorChar(CodePoint);
}
```

one flag test, one binary search over the 256-byte table, and **four**
callers:

1. `LexTokenInternal`'s non-ASCII `default:` case — the direct UTF-8 decode (U03);
2. `LexTokenInternal`'s `case '\\':` — the UCN decode, **new**;
3. `tryConsumeIdentifierUTF8Char` — stop the identifier, don't absorb (U03);
4. `tryConsumeIdentifierUCN` — the same, **new**.

Token *formation* is factored too (`LexUserOperator`: `MIOpt.ReadToken()` +
`FormTokenWithChars`), so 1 and 2 are two lines each and byte-identical to
each other. **No DEVIATION is owed on this point** — Clang did not force two
helpers, and the reason it did not is structural rather than lucky: by the
time control reaches `case '\\':`, `tryReadUCN` has already produced a
`uint32_t`, so there is nothing spelling-specific left to classify. That is
exactly U§8's "the lexer's existing UCN path already produces a code point
during phase-3 token formation", and it is true.

**This is the fact U18 and the paper both need**, so state it in those words:
*the UCN rule costs one call site because the lexer's UCN path and its UTF-8
path are already funnels onto the same code point.*

### 2. What did the code-point-identity hazard require?

U15's forward note was right, and it was the whole difficulty of the step.

`Lexer::getUserOperatorCodePoint(StringRef)` decoded the token's raw spelling
as one UTF-8 scalar and returned 0 for anything else — so `\U0000229E`
(ten ASCII bytes) answered **0**. That answer is the operator's identity
everywhere: `DeclarationName` (U06), the Itanium `op_u<HEX>` derivation
(U09), `-ast-print`/`-ast-dump` (U16), and the on-disk `DeclarationNameKey`
(U17). A UCN-spelled `operator\U0000229E` would have been a **different
entity** from `operator⊞`, mangling as `_Zv28op_u0000…`, and
**`-dump-tokens` would have been perfectly correct** — the step file's stated
gate ("all four spellings `-dump-tokens` identically") passes either way.

The fix is one canonicalization at that one function: a file-static
`decodeUCNSpelling(StringRef)` handling `\uXXXX`, `\UXXXXXXXX`, the C++23
delimited `\u{...}` and the C++23 named `\N{NAME}`. Three properties worth
knowing:

- **It is total.** It answers 0 on anything malformed rather than asserting.
  That matters because `getUserOperatorCodePoint` is a public `StringRef`
  API that U03's unittest already calls with garbage — so **`clang::expandUCNs`
  could not be reused**, despite U03's forward note suggesting it: that helper
  is assert-heavy by design, because the lexer has already validated its input.
  Eleven negative cases are pinned in `UnicodeOperatorCodePointFromUCNSpelling`.
- **Named UCNs match strict-then-loose**, in that order, which is exactly what
  `Lexer::tryReadNamedUCN` accepts (it diagnoses a loose match and then
  *recovers* to it). Using loose matching alone would have been almost right
  and occasionally wrong; using strict alone would have rejected spellings the
  lexer accepts.
- **No normalization** (U§8). The answer is the scalar value the spelling
  designates, never a mapped one.

**The consequence for how the rule is tested is the real lesson, and it is in
DEV-U18:** the equivalence U11 claims is an equivalence of *entities*, not of
tokens, and it is only visible at declaration/use level. Every assertion U04
added is of that shape — declare one way, define or call the other, and check
one entity — not a token comparison.

### 3. Do the two identifier-continuation paths behave?

Yes, and the trap U03 left was real. `tryConsumeIdentifierUCN` had the
identical "carry on as if the codepoint was valid for recovery purposes"
fall-through, so `a⊞b` would have been **one identifier** in any ordinary
compile. Two lines fix it, mirroring U03's.

**And the trap has teeth precisely because it is invisible to the obvious
test:** `-dump-tokens` runs with `Preprocessor::isPreprocessedOutput()` set,
which disables that recovery, so the lit test passes with or without the fix.
`LexerTest.UnicodeOperatorUCNAdjacency` (an ordinary `Preprocessor`) is the
assertion that means something; the lit file says so in a comment.

## The deferred tests, discharged

Five steps left instructions here. All five are now in the tree.

- **U07** — `Parser/unicode-operator-decl.cpp`. Exactly as specified:
  `constexpr int operator\N{SQUARED PLUS}(int, int);` declares,
  `constexpr int operator⊞(int a, int b) { return a + b; }` defines,
  `static_assert(operator⊞(2, 3) == 5)` unchanged. Plus the call spelled all
  four ways. Passed first try.
- **U09** — `CodeGenCXX/unicode-operator-mangle.cpp`. `int operator\N{SQUARED
  PLUS}(S, S);` redeclares the glyph-defined operator, `call_all` calls it
  through the UCN spelling, and the CHECK requires that call to target
  `@_Zv28op_u229E1SS_`. **The stronger half is `--implicit-check-not=op_u0000`
  on both CHECK RUN lines** — that is the specific guard against the hazard
  above, since a spelling that failed to decode would mangle as `op_u0000`.
  U09's prediction held exactly: **the mangler needed no change at all.**
- **U10** — `SemaCXX/unicode-operator-call.cpp` section 9, four cases:
  glyph-declared/UCN-called in all forms; UCN-declared, glyph-defined,
  glyph-called; a UCN and a glyph declaration overloading *each other* in one
  set; and a UCN operator-function-id in address-of position. The "NOT this
  file, because it cannot be" paragraph is deleted. One adjustment was needed:
  `&operator⊦` became ambiguous once section 9(c) added a second overload, so
  both pointers are target-typed — which is itself the point being made.
- **U15** — `Parser/unicode-operator-precedence.cpp`: a UCN redeclaration plus
  `1 ⊞ 2 == 4`, `1 \N{SQUARED PLUS} 2 ⊞ 3 == 11` (still
  left-associative) and `⊖ 1 ⊞ 2 == 10` (still prefix-tighter).
  The grammar level is a property of the token *kind*.
- **U16** — `AST/unicode-operator-print.cpp` section 6 and two RUN lines.
  `-DSPELL_UCN` respells section 6's operators through three macros and
  nothing else; the printed ASTs of the two compilations are **byte-identical**
  by `diff`. **Note the incidental result: a macro body may be a UCN-spelled
  operator token** (`#define OP_SQ \N{SQUARED PLUS}`), which works because the
  token is formed in phase 3, before macro replacement — so this also
  exercises `getUserOperatorCodePoint` on a macro-expansion token location.

## DEV-U07: the C-mode flag question

**I concurred and made the change.** Both `defm unicode_operators` and
`defm backtick` gained `ShouldParseIf<cplusplus.KeyPath>`, in one edit, for
the reason U08 gave for not splitting them: a divergence where one of the
paired flags is C++-only would be a worse surprise than the symmetry.

Measured after, in both directions:

```
$ clang -cc1 -x c -funicode-operators -fsyntax-only  # a ⊞ b
error: unexpected character '⊞' U+229E
error: expected ';' after return statement
$ clang -cc1 -x c -fsyntax-only                      # identical, byte for byte
```

and the same for `` a `g` b `` under `-fbacktick`. The driver still accepts
and forwards both flags in C mode — `Driver/{funicode-operators,fbacktick}.c`
are unchanged and pass — the flags simply have no effect once they arrive.
Both are pinned as a **diff** rather than as two expectations, because the
claim is equality and not a particular message.

**The `-fbacktick` half is a backtick-track edit** carried on this branch;
`REPLAY.md`'s U04 row names it and `clang/test/Lexer/backtick-c-mode.c` as the
two hunks U20 must drop. If the backtick track lands separately it owes itself
the identical one-line change.

DEV-U07 is marked **resolved** in the ledger.

## Verification evidence

**Build:** `ninja -C /home/sdowney/src/llvm/build-unicode clang AllClangUnitTests`
→ `EXIT=0`, **709 edges** (an `Options.td` + `Lexer.h` edit — cheaper than
U03's `TokenKinds.def` 1142). Two `warning:` lines, both the pre-existing
backtick `-Wswitch` on `BacktickInfixExprClass` (`ExprEngine.cpp:1688`,
`CXCursor.cpp:175`); zero others.

**Unittest:** `AllClangUnitTests --gtest_filter='LexerTest.*:UnicodeOperator*:UserOperator*:DeclarationName*'`
→ **64 tests, 64 passed** (41 `LexerTest` = 30 upstream + U03's 6 + U04's 5;
14 `UnicodeOperatorCharSetsTest`; 9 `UserOperatorNameTest`).

**Targeted lit** over `Lexer/`, `Preprocessor/`, `Parser/`, `SemaCXX/`,
`CodeGenCXX/`, `AST/`, `Driver/`, `PCH/`, `Modules/`, `Frontend/`:
7136 discovered / 6824 passed / 10 XFAIL / 302 unsupported / **0 failed**.

**Full gate:** `ninja -C $B check-clang` → `EXIT=1`, 8 failed:

```
Total Discovered Tests: 54175
  Passed: 48281   Unsupported: 5853   Expectedly Failed: 27   Skipped: 6
  Failed: 8
```

**All 8 are `DirectoryWatcherTest.*` and the inotify artifact is still here.**
16 `inotify_add_watch()` messages in the log; the machine held **65,382 of
65,536** watches at gate time. Filtered re-run per PLAN.md:

```
GTEST_FILTER='-DirectoryWatcherTest.*' ./bin/llvm-lit -s ./tools/clang/test
→ EXIT=0
Total Discovered Tests: 54167
  Passed: 48281   Unsupported: 5853   Expectedly Failed: 27   Skipped: 6
  Failed: 0
```

zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines, 163.8 s (172.6 s unfiltered).

**The arithmetic, like for like.** U15 filtered was 54159 / 48273. U04
filtered is 54167 / 48281 — exactly **+8 discovered / +8 passed**: three new
lit tests and five new gtest cases. **No existing test changed behaviour**,
which is the interesting number, because six existing test files were
*amended* and none of them needed a CHECK line relaxed.

**Process note, recorded because it cost a rebuild:** the full gate ran on a
tree that differed from the committed one by a **comment**. I rebuilt (7
edges, ~1 min) and re-ran the filtered set — which is precisely the
`check-clang` test content — on the exact committed tree; the numbers above
are from that run. Do not overlap edits with a running gate.

## Deviations from the plan / design

**DEV-U18** (`DEVIATIONS.md`), three parts: the convergence is real and
quantifiable; "structurally free" is wrong about the *identity*, and wrong in
a way that fails silently; and "else ill-formed" hides a spelling-dependent
diagnostic (see U05's notes below). Full text is in the ledger.

**DEV-U07** updated to resolved.

Two smaller judgement calls a reviewer will ask about:

1. **`Token::HasUCN` is set on UCN-spelled user-operator tokens, and I did not
   have to do it.** `tryReadNumericUCN`/`tryReadNamedUCN` set the flag on
   `Result` before `LexTokenInternal` forms the token, and `FormTokenWithChars`
   does not clear flags. Nothing reads it for this token kind (its one consumer
   is `Preprocessor::LookUpIdentifierInfo`, which only sees identifiers), but it
   is honest and free. U03's open question is closed: **nothing needs it, and it
   is there anyway.**
2. **`decodeUCNSpelling` also rejects surrogates and values above U+10FFFF**,
   which `tryReadUCN` already rejects before a token is formed. Redundant for
   any real token, deliberate for the `StringRef` API: a spelling this function
   accepts is always a scalar value.

## Discoveries affecting later steps

- **`clang::expandUCNs` is not reusable for an unvalidated spelling.** It is
  assert-heavy (`assert(Kind == 'u' || Kind == 'U' || Kind == 'N')`,
  `assert(Res && "could not find a codepoint that was previously found")`)
  because every caller has already been through the lexer. U03's forward note
  recommended it; do not.
- **`-dump-tokens` prints a UCN-spelled token's *source* spelling, escaped.**
  A `tok::user_operator` spelled `\U0000229E` dumps as
  `user_operator '\\U0000229E'`, not as the glyph and not as the code point.
  Off the flag it is `unknown '\\U0000229E'`. Both forms are pinned.
- **The math-identifier extension (D137051) is ON BY DEFAULT in every `-std=`
  mode in this build** — measured at `-std=c++20`, `c++23` and `c++2c`:
  `int ∂(int x);` compiles with a `-Wc++2d-extensions` *warning*, not an
  error. This is the answer U05's step file asks for and it has a sharp
  consequence for U05 — see below.
- **clang-format is still completely unaffected**, measured on the built
  binary: `a ⊞ b`, `a⊞b` and `int operator⊞(int,int);` all pass through
  `clang-format --style=LLVM` unchanged (only the ASCII `int,int` is
  reformatted). Both lexer hooks are dead there because `FormatTokenLexer`
  builds its own `LangOptions` and never sets `UnicodeOperators`. That is U18's
  starting point and its first decision.
- **A macro body can be a user-operator token, in any spelling.** Token
  formation is phase 3; macro replacement is phase 4. `#define OP \N{SQUARED
  PLUS}` then `a OP b` works, and `Lexer::getUserOperatorCodePoint(Tok, SM,
  LangOpts)` decodes correctly through the macro-expansion location. Exercised
  by `AST/unicode-operator-print.cpp`'s `-DSPELL_UCN` RUN line.
- **Glyph budget.** U04 used ⊞ ⊗ ⊖ (all previously used) and consumed **two**
  from U10's free list: **U+22A6 ⊦ ASSERTION** and **U+22A7 ⊧ MODELS**, both in
  `SemaCXX/unicode-operator-call.cpp` section 9. Remaining free list:
  **U+22B0, U+22B1, U+22B3–U+22BF, U+22C2–U+22C4.** If you need a *named* UCN,
  check the name first — `nameToCodepointStrict` is unforgiving and the names in
  these blocks are not guessable (U+22A6 is "ASSERTION", not anything with
  "TURNSTILE" in it).
- **Incremental build cost, for planning:** `Options.td` + `Lexer.h` together
  are 709 edges (~9 min). A `Lexer.cpp`-only edit is **7 edges (~1 min)**, as
  U03 measured.

## Forward notes for U05 — exclusion diagnostics with reasons

Written after reading `steps/U05-exclusion-diagnostics.md`. U15's notes for
you are still accurate; these are additions, and **the first one is a trap
that will silently break an unrelated feature if you miss it.**

- **Do NOT emit the `IdentifierProfile` message at the U03/U04 classification
  point.** Measured today: the D137051 math-identifier extension is **on by
  default at every `-std=`**, so `int ∂(int x);` compiles (with a
  `-Wc++2d-extensions` warning). Today `∂` U+2202 reaches the classification
  point, `isUserOperatorChar` says false, control falls through to
  `LexUnicodeIdentifierStart`, and it becomes an identifier. If you add the
  obvious `else if (getExclusionReason(CodePoint) != None)` there, you will
  **fire an error on every use of `∂`, `∇` and `∞` as identifiers** and break
  U10's composability claim in the act of testing it. The three
  `IdentifierProfile` code points are excluded *because* they are identifier
  characters; the message must fire only where an operator was plausibly meant,
  or not at all. The cleanest reading is that `IdentifierProfile` needs no
  diagnostic — the identifier path already does the right thing — and the step
  file's third bullet should be renegotiated rather than implemented.
  Whatever you decide, **assert the non-firing**: `int ∂(int); int u = ∂(1);`
  must still compile under `-funicode-operators`. This is the paper-grade
  result your step asks for and it is measured, not predicted.
- **There are now TWO classification sites for the token, not one, and they
  are already factored for you.** `Lexer::isUserOperatorCodePoint`
  (`Lexer.cpp`, just above `LexUnicodeIdentifierStart`; declared
  `Lexer.h`) is the single predicate; the two token-formation callers are
  `LexTokenInternal`'s `case '\\':` (UCN) and its non-ASCII `default:`
  (glyph), each now two lines:
  `if (isUserOperatorCodePoint(CodePoint)) return LexUserOperator(Result, CurPtr);`
  Add your `else if` at **both**, or — better, and what U03's handoff
  anticipated — add a third helper beside those two rather than duplicating a
  table lookup. `getUserOperatorExclusion()` / `getExclusionReason()` still
  have **zero** callers outside `UnicodeOperatorCharSetsTest.cpp`.
- **The two spellings do not get the same diagnostic today, and that is
  upstream's rule, not a bug you introduced.** Measured, flag on:
  - glyph `a − b` → `error: unexpected character '−' U+2212` **and**
    `error: expected ';' after top level declarator` (the character is dropped);
  - UCN `a − b` → **only** `error: expected ';' after top level
    declarator`; the token is a bare `tok::unknown` with no lexer diagnostic.

  The reason is in `LexUnicodeIdentifierStart`'s own comment: it may only "drop
  the character" when `!isASCII(*BufferPtr)`, i.e. when it was spelled as a
  literal character, because the standard forbids throwing away a possible
  preprocessing token written as an explicit UCN. **So if you want your
  exclusion messages to fire for UCN spellings you must emit them from the
  classification point, before that function is reached** — which the shape
  above gives you for free. Recorded as DEV-U18 part (c), and pinned in
  `clang/test/Lexer/unicode-operators-ucn.cpp`'s `EXCL` RUN line together with
  the non-aliasing assertion. There is a real argument for leaving the
  asymmetry alone — a confusable-character exclusion protects the *reader*, and
  no reader is confused by `−` — so decide it, don't inherit it.
- **The non-aliasing assertion already exists in three places** and you should
  extend rather than duplicate: `LexerTest.UnicodeOperatorExcludedCodePointIsNotAToken`
  (glyph, U03), `LexerTest.UnicodeOperatorUCNOfExcludedCodePointIsNotAToken`
  (UCN and `\N{MINUS SIGN}`, U04), and the `EXCL` RUN line above.
- **Your file will be `clang/test/Lexer/unicode-operators-excluded.cpp`**;
  `unicode-operators.cpp` (U03) and `unicode-operators-ucn.cpp` (U04) are
  taken, and both pin off-flag wording you must not change.
- **U15's notes remain correct** on the table's shape, `EscapeSingleCodepointForDiagnostic`,
  the `FixItHint::CreateReplacement` opportunity, and the "write the
  non-aliasing test first" advice. Nothing U04 did invalidates them.

## Forward notes for U18 — clang-format

Written after reading `steps/U18-clang-format.md`. **You are now unblocked,
and you are the last unchecked step on U19's dependency list.**

- **Baseline, measured on the built binary today, not inherited:**
  `clang-format --style=LLVM` leaves `int x = a ⊞ b;`, `int y = a⊞b;` and
  `int operator⊞(int,int);` → `int operator⊞(int, int);` — i.e. it reformats
  the ASCII and treats every user operator as an unknown blob. Nothing is
  *wrong* yet; nothing is right either. That is your before-picture and it is
  worth pinning in your handoff.
- **The reason both hooks are dead there is one line and it is your first
  decision.** `FormatTokenLexer` builds its own `LangOptions`
  (`clang/lib/Format/FormatTokenLexer.cpp`, and `getFormattingLangOpts` in
  `clang/lib/Format/Format.cpp`) and never sets `UnicodeOperators`; it also
  lexes **raw** (`Lex->LexFromRawLexer`), with no `Preprocessor`. Both facts
  are load-bearing:
  - Setting `LangOpts.UnicodeOperators` in `getFormattingLangOpts` is all that
    is needed to make `tok::user_operator` appear — the lexer hooks are
    `LangOpts`-gated and nothing else. Follow `ops/handoffs/10-clang-format.handoff.md`
    for how backtick was enabled rather than inventing a style option, as your
    step file says.
  - **Raw mode changes nothing about the token.** U03 chose "identity derived
    from the spelling, no payload field" specifically so that raw-mode lexing
    works, and `Lexer::getUserOperatorCodePoint(const Token &, const SourceManager &, const LangOptions &)`
    is a static function needing no `Preprocessor`. If you need the code point
    in `TokenAnnotator`, call it; do not re-decode.
- **UCN spellings need no work from you and you should assert that.** They
  produce the same `tok::user_operator` kind through the same helper; the only
  difference a formatter can see is that the token is 6, 8, 10 or ~16 columns
  wide instead of 1. **That is the one thing your step file's item 4
  (column-width accounting) should test explicitly**: `a ⊞ b` and
  `a \N{SQUARED PLUS} b` have the same token *count* and very different
  *widths*, so a long chain will wrap differently — correctly, but differently.
  Existing extended-identifier width handling should cover it; confirm, don't
  reimplement.
- **Position, not lookahead, decides fixity** — same as the parser (U5,
  DEV-U15). `TT_UnaryOperator` vs `TT_BinaryOperator` should fall out of
  `TokenAnnotator`'s existing "is the previous token an operand?" logic once
  the kind is recognized. There is no declaration lookup and no suppression
  flag anywhere in this feature; if you find yourself adding one, something
  upstream of you is wrong.
- **`operator⊞` must not be split**, and note that the *declaration* form is
  where a UCN spelling is most likely to appear in real code (it is the form
  U11 exists for). Test `operator\N{SQUARED PLUS}` in a declaration as well as
  the glyph.
- **The self-format trap is real and has bitten this project twice**
  (PLAN.md gate fact 2): `check-clang` self-formats `clang/lib/Format/` and
  aborts at ~step 81/970, before any lit test runs. Run the *upstream*
  `clang-format -i` over every file you touch in `clang/lib/Format/` before
  gating.
- **U15 left you a cheap idiom that generalizes:** compile the same input with
  and without the second flag and `diff` the outputs, rather than asserting two
  separate results. For you that is `clang-format` with and without
  `-fbacktick`-equivalent style state, and — better — the same source in glyph
  and UCN spellings, whose *formatted* outputs should differ only in the
  operator's spelling. That is a one-command proof that the formatter keyed on
  the token and not on the bytes.
- **REPLAY:** your step file says "likely mixed", and it will be. Anything you
  generalize out of backtick's `FormatTokenLexer`/`TokenAnnotator` code is
  `shared if landed`; a new `case tok::user_operator:` beside a
  `case tok::backtick:` is `upstream replay` with a re-anchoring note. U04's
  row shows the format: name the hunk, not the file.

## Open risks / TODOs

- **U05 is the only unchecked step in Phase A**, and the `IdentifierProfile`
  trap above is the one thing in this plan that can break a *passing* feature
  (math identifiers) while implementing a *new* one. It is worth doing before
  U18 for that reason alone.
- **DEV-U18 part (c) is undecided**: whether U05's exclusion messages must
  fire for UCN spellings. Measured and pinned; not decided.
- **DEV-U17 is still an open backtick bug** (the `BacktickInfixExpr::Inner`
  printer crash), still printing-only, still not this plan's to fix, and
  `-DPRINTING` in `Parser/unicode-operator-precedence.cpp` still exists only
  to route around it.
- **U§6 still owes a sixth worked example** (`⊖a ⊞ 2 * ⊖b`) and **U§13 still
  owes the fold decision.** Unchanged by U04.
- **DEV-U15's default-argument corner** and **DEV-U16's evaluation-order
  split** remain measured-but-undecided.
- **The `-Wswitch` `BacktickInfixExprClass` gap is still open in two files**
  (`StaticAnalyzer/Core/ExprEngine.cpp:1688`,
  `tools/libclang/CXCursor.cpp:175`) — U04's build surfaced both again,
  because it touched a header. Not ours, not to be fixed on this branch.
- **`clang/lib/CIR/` is still untouched and uncompiled.**
- **The inotify/`DirectoryWatcherTest` artifact is still present** (65,382 of
  65,536 watches). Budget for the filtered re-run.
- **U19 can start as soon as U18 lands.** U04's REPLAY row is written to be
  split mechanically: two hunks are backtick-only (the `defm backtick` guard
  and `Lexer/backtick-c-mode.c`) and everything else is pure Unicode.
