# Handoff — U05 Exclusion diagnostics with reasons

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `a893a3fb5c66`
  (parent `6ffc374fa25a`, U04)
- **Date / agent:** 2026-08-04

**Phase A is complete.** The lexer is fully landed: flag, tables, glyph
token, UCN token, exclusion diagnostics. U18 and U21 are the only unchecked
steps left before U19.

## The two-sentence version

U§8's "keep the exclusion list as a second, tiny table with reasons" is
right, and the design does not notice that **the reasons have different
scopes**: two of the three name code points that could not be anything but
an operator and are diagnosable at the classification point, while the
third names code points that are *valid identifier characters in this
compiler* and whose message, emitted there, would be an error on every
legitimate use of one as a name. Emitting from the classification point
also **closes the glyph/UCN asymmetry** U04 measured (DEV-U18 part c),
because the message is emitted before `LexUnicodeIdentifierStart` — which
is where the asymmetry lived — and the recovery is to form `tok::unknown`
rather than to drop the character, which is the action that is legal for
both spellings.

## The D137051 conflict, and how it was resolved

U04's first forward note was correct and it was the substance of the step.
Re-measured today on the built binary, `-std=c++23`, flag **on**:

```
$ clang -cc1 -funicode-operators -fsyntax-only   # int ∂(int x); int u = ∂(1);
warning: mathematical notation character '∂' U+2202 in an identifier is a
         C++2d extension [-Wc++2d-extensions]
```

— a warning, no error. So the resolution is a **three-way split**, and it
is recorded as **DEV-U19**:

| Reason | Code points | Where the message is emitted | Why there |
|--------|-------------|------------------------------|-----------|
| `ConfusableWith` | 13 | `Lexer::LexExcludedOperator`, at both `LexTokenInternal` classification sites | Pattern_Syntax excludes them from XID by construction, so they are not identifier characters and never were; nothing but an operator could have been meant. Context-free. |
| `EmojiPresentation` | 12 | the same | the same |
| `IdentifierProfile` | 3 (∂ ∇ ∞) | `Parser::ParseUnqualifiedIdOperator`, as a **note**, on a conversion-function-id parse that has already failed | they *are* identifier characters here; the only context in which an operator was unambiguously meant is operator-name position, and even there `using ∞ = int; struct T { operator ∞(); };` is a real conversion function that must keep working |

Two measured facts about the third row that a reader will ask about, both
in DEV-U19 and both new:

- **`operator∂` — written without a space — is a single identifier.**
  `int operator∂(S, S);` declares an ordinary function *named* `operator∂`
  (confirmed by `-ast-dump`: `FunctionDecl … operator∂ 'int (S, S)'`), with
  only the extension warning. It never reaches the operator-name path at
  all. This is a second, independent argument for keeping the operator and
  identifier sets disjoint: the moment a U1 code point became an identifier
  character, `operator⊞` would stop being two tokens.
- **`operator ∂` — with a space — is a conversion-function-id.** It fails
  with `error: unknown type name '∂'`, which is where the note attaches.

The non-firing is asserted, as U04 asked: section 4 of the new test
declares and uses `∂`, `∇` and `∞` as ordinary names under **both** flag
states and expects only the `-Wc++2d-extensions` warnings. If the message
were emitted at the classification point, every one of those lines would be
an error. **That section is the composability claim of U10 / U§7.1 turned
into a regression test**, and it is the paper-grade result of this step.

## The UCN decision

**The exclusion diagnostic fires for UCN spellings too**, and this is the
step's other decision. DEV-U18 part (c) is now closed.

The argument U04 left for the other side — "a confusable-character
exclusion protects the *reader*, and no reader is confused by a UCN" —
is real but loses to two things. First, U11's whole claim is
that glyph and UCN are equivalent spellings of one entity; U04 spent a step
making that true for *included* code points, and an exclusion that caught
only the glyph would say the equivalence stops exactly where the security
property starts. Second, the UCN spelling is the one U§10 tells people to
use when their encoding or font cannot carry the glyph — so it is precisely
the spelling in which a reader *cannot* see that the code point behind
`\u2212` is not `-`, and the message is doing more work there, not less.

The mechanism is cheap because the shape U04 built made it cheap: both
spellings are classified at the same point, before
`LexUnicodeIdentifierStart`, so the diagnostic is emitted from the same
helper for both. The upstream rule that produced the asymmetry —
`LexUnicodeIdentifierStart` may only "drop the character" when it was
spelled as a literal character, because [lex.charset] forbids throwing away
a possible preprocessing token written as an explicit UCN — is **satisfied,
not worked around**: `LexExcludedOperator` diagnoses and then forms a
`tok::unknown` token. Forming a token is legal for both spellings, whereas
dropping is legal for only one. That is the whole trick, and it is worth a
sentence in the paper.

Measured, all four spellings of U+2212 now identical (the glyph, `\u2212`,
`\N{MINUS SIGN}`, and the glyph adjacent to an identifier):

```
error: '−' U+2212 is not a user-defined operator: it is confusable with '-'
error: expected ';' after top level declarator
```

## The exact diagnostic texts

```tablegen
// DiagnosticLexKinds.td
def err_unicode_operator_confusable : Error<
  "%0 is not a user-defined operator: it is confusable with '%1'">;
def err_unicode_operator_emoji_presentation : Error<
  "%0 is not a user-defined operator: characters with emoji presentation are "
  "excluded from the operator set">;

// DiagnosticParseKinds.td
def note_unicode_operator_identifier_profile : Note<
  "%0 is an identifier character (mathematical notation profile), not a "
  "user-defined operator">;
```

`%0` is `EscapeSingleCodepointForDiagnostic(CodePoint)` in all three, so the
rendering is U01's pinned `'⊞' U+229E` style and there is no second way to
print a code point in the tree. Rendered:

```
error: '−' U+2212 is not a user-defined operator: it is confusable with '-'
error: '⌚' U+231A is not a user-defined operator: characters with emoji
       presentation are excluded from the operator set
note: '∂' U+2202 is an identifier character (mathematical notation
      profile), not a user-defined operator
```

**The design's "did you mean `-`?" phrasing was deliberately not used**,
and no `FixItHint` is attached — see the next section.

## The U02 confusable spellings: two look wrong as *advice*

U02's handoff recorded the ASCII spellings as an unvalidated judgement call.
Having had to put them in a user-visible message, here is the verdict:

- **As confusability claims, all 13 are defensible**, including the three in
  question. `∙` U+2219 BULLET OPERATOR and `⋅` U+22C5 DOT OPERATOR really do
  render close enough to `.` in a monospace font to fool a reader, and `⇔`
  really is the glyph a reader would read as an implication/spaceship.
- **As intent guesses, ∙ → `.`, ⋅ → `.` and ⇔ → `<=>` are wrong.** Nobody
  writing `a ∙ b` meant `a . b`; that is a member access, not a product.
  The design's proposed wording ("did you mean `-`?") is right for U+2212
  and would be actively misleading for those three — and the step file
  forbids a per-entry switch, so one wording has to serve all 13.

So the message states the confusability and stops. **No `FixItHint` is
attached to any of them**, which is the load-bearing half: a fix-it can be
applied mechanically (`-Xclang -fixit`), and a mechanically applied
`∙` → `.` changes the meaning of the program silently — the precise failure
mode U§5's "rejected outright, never aliased" exists to prevent. Offering
the reader a replacement in prose and refusing to apply one for them is the
right side of that line. **The table itself was not changed**; if the paper
wants to revisit ∙ ⋅ ⇔ it should do so in U§5's derivation, not here.

## What changed

**Production: 5 files, +201/−2.**

| File | Change |
|------|--------|
| `clang/include/clang/Basic/DiagnosticLexKinds.td` | **+12.** `err_unicode_operator_confusable`, `err_unicode_operator_emoji_presentation`, after `ext_mathematical_notation` |
| `clang/include/clang/Basic/DiagnosticParseKinds.td` | **+10.** `note_unicode_operator_identifier_profile`, after `warn_cxx98_compat_literal_operator` |
| `clang/include/clang/Lex/Lexer.h` | **+48.** Public `static bool isUserOperatorIdentifierProfileExclusion(uint32_t)` (beside `getUserOperatorCodePoint`); private `bool isDiagnosableOperatorExclusion(uint32_t) const` and `bool LexExcludedOperator(Token &, uint32_t, const char *)` (beside `isUserOperatorCodePoint` / `LexUserOperator`) |
| `clang/lib/Lex/Lexer.cpp` | **+101.** The three definitions, plus four call sites: the two `LexTokenInternal` classification points (non-ASCII `default:` and `case '\\':`) and the two identifier-continuation early-outs |
| `clang/lib/Parse/ParseExprCXX.cpp` | **+30/−2.** `NoteIdentifierProfileExclusion` lambda in `ParseUnqualifiedIdOperator`, called at both failure exits of the conversion-function-id parse |

**Tests: 1 new file, 2 amended.**

| File | Change |
|------|--------|
| `clang/test/Lexer/unicode-operators-excluded.cpp` | **new**, 187 lines, 3 RUN lines. Two `-verify` runs over one source (`-verify=on,common` with the flag, `-verify=off,common` without) plus a `-dump-tokens` run with `--implicit-check-not='user_operator'` |
| `clang/test/Lexer/unicode-operators-ucn.cpp` | **+13/−11.** The EXCL block: the two new errors pinned, and the "U05 has to decide about this asymmetry" paragraph replaced by the decision |
| `clang/unittests/Lex/LexerTest.cpp` | **+31.** `UnicodeOperatorExcludedCodePointEndsAnIdentifier` |

**In this repo:** `PLAN.md` (U05 ticked, Status row), `REPLAY.md` U05 row,
`DEVIATIONS.md` **DEV-U19**, this handoff.

## How the implementation is shaped, in case it has to be redone

One predicate, one emitter, four call sites — deliberately the same shape
U04 left, so the two rules cannot drift:

```cpp
// the predicate: flag test + table lookup + the IdentifierProfile carve-out
bool Lexer::isDiagnosableOperatorExclusion(uint32_t CodePoint) const;

// the emitter: diagnose, then form tok::unknown; false = fall through to
// the unchanged upstream path (raw mode, PP directive, -E/-dump-tokens)
bool Lexer::LexExcludedOperator(Token &, uint32_t CodePoint, const char *);
```

and at both token-formation sites, immediately after the
`isUserOperatorCodePoint` line U03/U04 put there:

```cpp
if (LexExcludedOperator(Result, CodePoint, CurPtr))
  return true;
```

**The two identifier-continuation paths ask the predicate too**, and this is
the one place U05 went past what the step file named. Without it,
`a−b` reported only `character '−' U+2212 not allowed in an identifier` —
true, and silent about the one interesting fact — because the character was
absorbed into the identifier "for recovery purposes". Stopping the
identifier there is the exact mirror of what U03/U04 do for a U1 code point,
so **an excluded code point now tokenizes exactly like an included one; it
just has no meaning**. That symmetry is worth more than the two saved lines.

## Verification evidence

**Build:** `ninja -C /home/sdowney/src/llvm/build-unicode clang AllClangUnitTests`
→ `EXIT=0`, twice (a `DiagnosticLexKinds.td` + `Lexer.h` edit is a full
rebuild, ~9 min each). Two `warning:` lines, both the pre-existing backtick
`-Wswitch` on `BacktickInfixExprClass` (`ExprEngine.cpp:1688`,
`CXCursor.cpp:175`); zero others.

**Unittest:** `AllClangUnitTests --gtest_filter='LexerTest.*:UnicodeOperator*:UserOperator*:DeclarationName*'`
→ **65 tests, 65 passed** (42 `LexerTest` = 30 upstream + U03's 6 + U04's 5
+ U05's 1; 14 `UnicodeOperatorCharSetsTest`; 9 `UserOperatorNameTest`).

**Targeted lit** over `Lexer/`, `Preprocessor/`, `Parser/`, `SemaCXX/`,
`CodeGenCXX/`, `AST/`, `Driver/`, `PCH/`, `Modules/`, `Frontend/`, `Sema/`,
`Index/`: 8919 discovered / 8357 passed / 10 XFAIL / 550 unsupported / 2
failed — both `Index/Core/index-pch.{c,cpp}`, and **both are a stale-binary
artifact of building only `clang`**: the new `clang` writes a PCH that the
not-yet-rebuilt `c-index-test` cannot load. They pass in the full gate,
which builds every tool. **Do not chase them; build `c-index-test` or run
the full gate.**

**Full gate:** `ninja -C $B check-clang` → `EXIT=1`, 8 failed:

```
Total Discovered Tests: 54177
  Passed: 48283   Unsupported: 5853   Expectedly Failed: 27   Skipped: 6
  Failed: 8
```

**All 8 are `DirectoryWatcherTest.*`,** the inotify artifact again: 16
`inotify_add_watch()` messages in the log, machine holding **65,382 of
65,536** watches at gate time. Filtered re-run per PLAN.md:

```
GTEST_FILTER='-DirectoryWatcherTest.*' ./bin/llvm-lit -s ./tools/clang/test
→ EXIT=0
Total Discovered Tests: 54169
  Passed: 48283   Unsupported: 5853   Expectedly Failed: 27   Skipped: 6
  Failed: 0
```

zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines, 166.1 s.

**The arithmetic, like for like.** U04 filtered was 54167 / 48281. U05
filtered is **54169 / 48283** — exactly **+2 discovered / +2 passed**: the
new lit file and the new gtest case. **No existing test changed behaviour**
except `Lexer/unicode-operators-ucn.cpp`, whose EXCL block was *tightened*
(it previously passed with or without U05, since its assertions were the
absence of `operator−` and the presence of two parser errors — both still
true; it now also pins the two new lexer errors).

**The new test passed the flag-on run on the first try**, and needed two
additions for the flag-*off* run: off-flag `int c4 = a−b;` also reports
`use of undeclared identifier 'a−b'` (because upstream absorbs the character
into the identifier), and I had simply forgotten the off-flag
`unexpected character '⭐' U+2B50`. Both are recorded in the file as the
before-picture.

## Deviations from the plan / design

**DEV-U19** (`DEVIATIONS.md`), four parts: the reasons have different
scopes; `IdentifierProfile` cannot be emitted where the design puts it and
why; `operator∂` is one identifier; and the "did you mean X?" wording is
wrong for three table entries, so the message states confusability and
offers no fix-it. Full text is in the ledger.

**DEV-U18 part (c) is now decided** — the exclusion diagnostic fires for
UCN spellings. The ledger row is left as written (it is U04's measurement,
and it was correct); this handoff and the amended
`Lexer/unicode-operators-ucn.cpp` carry the decision.

Two smaller judgement calls a reviewer will ask about:

1. **The step file says "emit and continue with the existing error
   recovery"; the recovery changed.** Upstream *drops* a stray glyph;
   `LexExcludedOperator` forms `tok::unknown` instead. This was not
   cosmetic — dropping is legal only for the glyph spelling, so keeping it
   would have made the UCN half of the rule unimplementable at this point.
   The follow-on parser error is unchanged in every case in the test file
   (`expected ';' after top level declarator`), which is why the diff to the
   existing EXCL block is only the two new lines.
2. **The `IdentifierProfile` message is a `Note`, not an `Error`.** An error
   would have to be emitted *instead of* the conversion-function-id parse,
   which means deciding before parsing whether `∂` names a type — and it
   sometimes does. Attaching a note to a parse that already failed needs no
   such decision and cannot break a valid program. The cost is that it is
   invisible in `-fsyntax-only` output if the preceding error is suppressed;
   nothing suppresses `err_unknown_typename`.

## Discoveries affecting later steps

- **`getUserOperatorExclusion` / `getExclusionReason` now have real callers**
  — `Lexer::isDiagnosableOperatorExclusion` and
  `Lexer::isUserOperatorIdentifierProfileExclusion`, both in `Lexer.cpp`.
  U02's table is no longer test-only.
- **`UnicodeOperatorCharSets.h` is private to the Lex library**, so the
  Parser cannot include it. The one fact the Parser needs is exposed as the
  public static `Lexer::isUserOperatorIdentifierProfileExclusion(uint32_t)`.
  Anyone else who needs an exclusion fact outside `clang/lib/Lex/` should
  add a similarly narrow accessor rather than move the header.
- **`Lexer::getUserOperatorCodePoint(StringRef)` is the general
  one-code-point decoder**, not just an operator-token decoder — U05 calls
  it on an `IdentifierInfo`'s name to ask "is this identifier exactly one
  code point, and which?". It answers 0 for anything longer, which is
  exactly the guard needed. The name is now slightly narrower than the job.
- **An `IdentifierInfo`'s name is UTF-8 even when the source spelled it as a
  UCN** (`Preprocessor::LookUpIdentifierInfo` runs `expandUCNs` when
  `Token::HasUCN`), so `operator ∂` and `operator \u2202` reach the note
  through the same code path with no spelling handling.
- **`Preprocessor::LexTokensUntilEOF` stops at `tok::unknown`.** It breaks
  on `tok::unknown`, `tok::eof`, `tok::eod` and `tok::annot_repl_input_end`.
  So `CheckLex("a − b", {identifier, unknown, identifier})`
  fails with "expected 3, got 1" — not because the lexing is wrong but
  because the harness stopped. Assert on the *leading identifier's length*
  instead (1 byte, `a`, versus the 4 or 8 bytes an absorbed spelling would
  give). This cost a build cycle; it will cost the next agent one too.
- **Two RUN lines over one source, `-verify=on,common` / `-verify=off,common`,
  is the right idiom for a flag-state diff in a `-verify` test** — shared
  expectations are written once as `common-`, and the file reads as a diff
  rather than as two files. U15's "compile twice and diff" advice
  generalizes to `-verify` this way.
- **`Index/Core/index-pch.{c,cpp}` fail if you build only `clang`** and then
  run lit over `clang/test/Index` — stale `c-index-test` cannot load a PCH
  the new `clang` wrote. Not a regression; build the tools or run the gate.
- **Glyph budget unchanged.** U05 used only excluded code points and ⊞ ⊗ ⊖
  indirectly; nothing was spent. Free list still
  **U+22B0, U+22B1, U+22B3–U+22BF, U+22C2–U+22C4**.
- **Incremental build cost, updated:** a `DiagnosticLexKinds.td` or
  `Lexer.h` edit is a **~1300-edge, ~9-minute** rebuild of `clang` +
  `AllClangUnitTests`. A `LexerTest.cpp`-only edit is **2 edges**.

## Forward notes for U18 — clang-format

Written after reading `steps/U18-clang-format.md`. **U04's forward notes for
you are still correct in every particular** — the dead-hook diagnosis, the
`getFormattingLangOpts` one-liner, raw-mode lexing, UCN column widths,
position-not-lookahead fixity, the self-format trap, and the REPLAY advice.
Read them; these are additions from U05.

- **Nothing U05 did is visible to clang-format, and I checked rather than
  assumed.** `FormatTokenLexer` lexes raw, and `LexExcludedOperator` returns
  `false` in raw mode before it looks at anything, so the new diagnostics
  cannot fire in the format path however you enable the feature. Re-measured
  on the built binary after the change: `a ⊞ b`, `a⊞b`, `int operator⊞(int,int);`
  and `int x = 1 − 2;` all pass through `clang-format --style=LLVM`
  exactly as U04 recorded. Your before-picture is unchanged.
- **When you set `LangOpts.UnicodeOperators` in `getFormattingLangOpts`, you
  turn on the *whole* lexer hook, including the two identifier-continuation
  early-outs U05 added.** That is what you want — `a−b` will annotate as
  three tokens rather than one blob — but it is a behaviour change to
  formatting of source containing *excluded* code points, which no test
  covers today. Worth one `FormatTest` case: `a−b` (U+2212) should not be
  glued into one identifier-shaped token. It will be `tok::unknown`; decide
  whether clang-format spaces around an unknown token and pin whatever you
  decide, because it is currently unpinned in either direction.
- **`Lexer::isUserOperatorIdentifierProfileExclusion` is public and static**,
  if you ever need to ask about ∂ ∇ ∞ from `TokenAnnotator`. You almost
  certainly do not: they are ordinary identifier characters and clang-format
  already handles them as such. Do **not** add a special case for them.
- **The declaration form is where a UCN spelling is most likely**, as U04
  said, and U05 adds a reason to test the *note* case too:
  `operator ∂` (with a space) is a conversion-function-id, so a formatter
  that decides to join `operator` and its name must not join those two.
  There is no such rule to write — the tokens differ — but it is a cheap
  assertion that the formatter is keying on token kind.
- **REPLAY:** U05's own row is `upstream replay` with no exceptions, which
  makes yours the only remaining "likely mixed" row in the ledger. U19 will
  read it first.

## Forward notes for U19 — replay-ledger audit

Written after reading `steps/U19-replay-audit.md`.

- **Your dependency list is now U18 alone.** U14, U15 and U17 are checked;
  U05 completes Phase A. U21 is explicitly off the replay path (Phase F), so
  do not wait for it — but do say in your audit whether its probe changed
  any file, because if it did, its hunks need a class too.
- **The ledger's hunk-level discipline is real: read the rows, then re-derive
  the diff.** `git -C ~/src/llvm/unicode diff backtick-trunk..unicode-operators-experiment --stat`
  is the step file's command; note that the base to diff against is
  `backtick-trunk` @ `bd6f4d5fa102`, not `upstream/main`.
- **The `backtick dependency` / `shared if landed` population is small and
  already named.** As of U05 exactly three hunks in the whole diff are not
  `upstream replay`: (a) U04's `ShouldParseIf<cplusplus.KeyPath>` on
  `defm backtick`; (b) `clang/test/Lexer/backtick-c-mode.c`; (c) the
  `prec::UserInfix` level itself, which on this branch was introduced by the
  backtick work and on clean `main` must be introduced *by this stack* —
  see U11's row. Plus the `-fbacktick` RUN lines in the mixed test files
  U07/U09/U10/U15/U16 own. **That is the ratio your handoff is asked for**,
  and it is going to be lopsided in the interesting direction: the Unicode
  feature inherited a *design* from backtick and almost no *code*.
- **U05 is the first step whose production diff touches `clang/lib/Parse/`
  for a reason unrelated to parsing user operators** (a diagnostic note on
  an upstream failure path). When you order the upstream stack, the
  "diagnostics" commit is therefore not a pure Lex commit — it carries one
  `ParseExprCXX.cpp` hunk and one `DiagnosticParseKinds.td` entry, and it
  must land after the operator-function-id commit because both edit
  `ParseUnqualifiedIdOperator`. They are ~90 lines apart and independent.
- **A plausible Phase-A commit split for the upstream stack**, since you have
  to propose one and Phase A is now finished: (1) flag `-funicode-operators`
  (U01); (2) generated tables + their unittest (U02); (3) lexer token, glyph
  only (U03); (4) UCN spellings + the `getUserOperatorCodePoint`
  canonicalization (U04); (5) exclusion diagnostics (U05). Each is
  independently testable and each has its own test file. (4) and (5) both
  amend (3)'s functions, so they cannot be reordered.
- **State the gate number as the "before" for U20:** filtered
  `check-clang` on `a893a3fb5c66` is 54169 discovered / 48283 passed /
  0 failed, with the 8 `DirectoryWatcherTest.*` cases filtered out for the
  machine's inotify budget, not for anything this branch did.

## Open risks / TODOs

- **U18 is the only unchecked step on U19's dependency list**, and U21 is
  the only other unchecked step in the plan.
- **DEV-U19 is open for reconciliation** into U§8 paragraph 2 and U§5.
  The `IdentifierProfile` finding is the one the paper most needs: it is
  direct evidence for U10/U§7.1, because the disjointness of the operator
  and identifier sets is what makes the exclusion diagnostic implementable
  at all.
- **The U02 table's ASCII spellings for ∙ ⋅ (→ `.`) and ⇔ (→ `<=>`) are
  flagged, not changed.** If the paper agrees they are wrong, the fix
  belongs in the derivation and the generated header, and the diagnostic
  will follow automatically — that is why the message takes the string from
  the table.
- **DEV-U17 is still an open backtick bug** (the `BacktickInfixExpr::Inner`
  printer crash), still printing-only, still not this plan's to fix.
- **U§6 still owes a sixth worked example** (`⊖a ⊞ 2 * ⊖b`) and **U§13 still
  owes the fold decision.** Unchanged by U05.
- **DEV-U15's default-argument corner** and **DEV-U16's evaluation-order
  split** remain measured-but-undecided.
- **The `-Wswitch` `BacktickInfixExprClass` gap is still open in two files**
  (`StaticAnalyzer/Core/ExprEngine.cpp:1688`,
  `tools/libclang/CXCursor.cpp:175`) — U05's builds surfaced both again,
  because it touched headers. Not ours, not to be fixed on this branch.
- **`clang/lib/CIR/` is still untouched and uncompiled.**
- **The inotify/`DirectoryWatcherTest` artifact is still present** (65,382 of
  65,536 watches). Budget for the filtered re-run.
