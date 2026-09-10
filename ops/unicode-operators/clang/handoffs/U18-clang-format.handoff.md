# Handoff — U18 clang-format

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `06735e8df66d`
  (parent `a893a3fb5c66`, U05)
- **Date / agent:** 2026-08-04

**Every implementation step in the plan is now landed.** U19 (the replay
audit) is unblocked and U21 (the postfix probe) is the only other unchecked
step. Nothing in Phases A–D remains.

## The two-sentence version

U§10's "strictly less work than backtick's formatting story" is right, and
the ratio is **32 added production lines and no new machinery** against
backtick's four `TT_` types, a state field, and two bespoke rule sets. What
U§10 hides is that there are **three** touch points, not one, and the third
— giving the token a *precedence* — is invisible to every spacing and
annotation test while silently breaking how a long chain wraps. See
**DEV-U20**.

## The before-picture, reproduced

U04 and U05 both recorded that clang-format was entirely unaffected by the
feature. Re-measured on the built binary before touching anything, and it
was still exactly true:

```
$ clang-format --style=LLVM         # input          -> output
int x = a ⊞ b;                      -> unchanged
int y = a⊞b;                        -> unchanged   (not respaced)
int a3 = a  ⊞  b;                   -> int a3 = a  ⊞ b;
int operator⊞(int,int);             -> int operator⊞(int, int);   (ASCII only)
int operator ⊞(int, int);           -> unchanged   (space kept)
int p2 = ⊖ a;                       -> unchanged   (space kept)
int p4 = -a ⊞ -b;                   -> int p4 = -a ⊞ - b;         (wrong)
```

Every user operator was an unknown blob. Note the last line: the built-in
unary minus *after* a user operator was already being mis-annotated as
binary, so this step fixed something that was visibly wrong and not merely
absent.

## How the feature is enabled in the format path

**Exactly as S10 did it, one line, no style option.** `getFormattingLangOpts()`
in `clang/lib/Format/Format.cpp` already had

```cpp
  if (Style.Language == FormatStyle::LK_Cpp ||
      Style.Language == FormatStyle::LK_ObjC) {
    LangOpts.Backtick = 1;
  }
```

and `LangOpts.UnicodeOperators = 1;` goes inside it. The language test, not
`LangOpts.CPlusPlus`, is load-bearing for the same reason S10 gave: JS, Java
and C# fall through to the same `default:` arm of that switch and also set
`CPlusPlus = 1`. The Unicode feature has no JS hazard of its own (U1 is
disjoint from every identifier set, and JS has no such operators), but the
guard is the right shape regardless and keeping the two flags adjacent is
worth more than the two saved characters.

That one line is sufficient to make `tok::user_operator` appear, in **both**
spellings, because U03/U04's lexer hooks are `LangOpts`-gated and nothing
else — U04's forward note was exactly right. Raw-mode lexing changes
nothing, as U03 designed for.

## The annotation types used

**`TT_BinaryOperator` and `TT_UnaryOperator`. No new `TokenType` was
introduced, and none was needed.** Four lines in
`AnnotatingParser::determineTokenType`, placed immediately after the
backtick block:

```cpp
    if (IsCpp && Current.is(tok::user_operator)) {
      Current.setType(endsOperand(Current.getPreviousNonComment())
                          ? TT_BinaryOperator
                          : TT_UnaryOperator);
      return;
    }
```

Everything the step file asked for then falls out of existing handling:

| Ask | What does it | Result |
|-----|--------------|--------|
| infix spacing | `spaceRequiredBefore`'s `Right.is(TT_BinaryOperator) \|\| Left.is(TT_BinaryOperator) → true` | `a⊞b` → `a ⊞ b` |
| prefix binding | `Left.is(TT_UnaryOperator) → false`; `Right.is(TT_UnaryOperator) → true` unless after `(`/`[`/`@` | `⊖ a` → `⊖a`; `(⊖a)` stays hugged |
| `operator⊞` not split | the existing `case tok::kw_operator:` loop rewrites a `TT_UnaryOperator` successor to `TT_OverloadedOperator`, then `Left.is(tok::kw_operator) → SpaceAfterOperatorKeyword` | `operator ⊞ (int,int)` → `operator⊞(int, int)` — **the same path `operator +` takes** |
| no break after `operator` | `canBreakBefore`: `Left.isOneOf(TT_TemplateCloser, TT_UnaryOperator, tok::kw_operator) → false` | glyph welded to the keyword |
| breaking / penalties | `TT_BinaryOperator` is already a break candidate; `splitPenalty` already handles it | wraps at the operator |

**`TT_OverloadedOperator` is the third annotation the feature produces**, and
it is produced by upstream code that this step did not touch.

## The one thing that was not free: precedence

`FormatToken::getPrecedence()` (`clang/lib/Format/FormatToken.h`) calls
`getBinOpPrecedence` with hard-coded arguments, so `tok::user_operator`
answered `prec::Unknown`. `ExpressionParser::getCurrentPrecedence` reads
exactly that value for a `TT_BinaryOperator`, so a chain of user operators
would have got **no fake-parenthesis structure at all** — and every spacing
test, every annotation test and the whole `operator⊞` story would still have
passed. The fix is to pass `/*UnicodeOperatorsEnabled=*/true`, on the same
principle as the `GreaterThanIsOperator=true` / `CPlusPlus11=true` already
there: the formatter takes the permissive view of every lexing question, and
the token only exists at all when `getFormattingLangOpts` lexed it.

**This is the paper-grade half of the step** (DEV-U20) and it is a concrete
argument for U9: the formatter needs *a* precedence for the token, and
because U9 chose one fixed level there is exactly one to give it. A design
with per-operator precedence would have needed the formatter to do
declaration lookup, which it cannot.

## Whether the backtick formatting code needed generalizing

**Yes, in one place, and it is a genuine sharing rather than a refactor for
its own sake.** S10 wrote the post-operand test inline in the backtick block.
The Unicode operator needs the same notion — it is the same U5 rule at the
same U§12 precedence level — so it is now a file-static in
`TokenAnnotator.cpp`'s anonymous namespace:

```cpp
static bool endsOperand(const FormatToken *Prev) {
  return Prev &&
         (Prev->Tok.isLiteral() ||
          Prev->isOneOf(tok::identifier, tok::r_paren, tok::r_square,
                        tok::r_brace, tok::kw_true, tok::kw_false,
                        tok::kw_nullptr, tok::kw_this, TT_BacktickEscapeClose));
}
```

**One enumerator did not survive the generalization, and finding out why is
the composability result of this step.** S10's inline list also contained
`TT_BacktickInfixClose`, and sharing it verbatim mis-formatted a real shape:

```
int x = a `f` ⊖b;   ->   int x = a `f` ⊖ b;    // wrong
```

An infix close does **not** end an operand — the right operand still follows
it — so a Unicode operator directly after one is *prefix*. A keyword-escape
close does end an operand (it closes an identifier), so `` `new` ⊞ b `` is
infix. The shared helper therefore keeps `TT_BacktickEscapeClose` and drops
`TT_BacktickInfixClose`; the backtick call site keeps its own extra case
verbatim, so **backtick behaviour is byte-for-byte unchanged** (all 1273
pre-existing `FormatTests` still pass):

```cpp
        if (endsOperand(Prev) || (Prev && Prev->is(TT_BacktickInfixClose))) {
```

That extra case is arguably a latent S10 bug — it can only be reached on
input with no valid parse, `` a `f` `g` b `` — but fixing it is not this
step's business and preserving it costs nothing.

`REPLAY.md` classes the helper **`shared if landed`** (it names a
backtick-track `TokenType`) and the backtick call-site rewrite a
**`backtick dependency`** (drop it entirely on clean `main`).

## What `operator∂` does — the U05 shape, measured

Nothing, and that is the right answer. `∂` U+2202 is an *identifier*
character in this compiler (D137051, on by default), so `operator∂` written
without a space is **one `tok::identifier`** — as U05 established — and
clang-format sees a single word after `operator`. It is spaced by the
ordinary `Left.is(tok::kw_operator)` rule and nothing in this step's code is
reached. `operator ∂` with a space is two tokens and stays two tokens, which
is what a conversion-function-id requires. **U05's advice was to add no
special case for ∂ ∇ ∞, and none was added**;
`Lexer::isUserOperatorIdentifierProfileExclusion` has no caller in
`clang/lib/Format/`.

Excluded code points that are *not* identifier characters behave the other
way and this needed checking, because U05 warned it was unpinned. Enabling
the flag in the format path **does** change the token stream — U+2212 now
stops an identifier (U05's continuation early-outs are `LangOpts`-gated, not
raw-mode-gated), so `a−b` is three tokens where it used to be one — but the
**output is byte-identical**, verified against the untouched
`build-backtick-trunk/bin/clang-format`:

```
int e1 = a  −  b;   ->   int e1 = a  − b;      (both binaries)
int e2 = a−b;       ->   int e2 = a−b;         (both binaries)
int e3 = a  ⌚  b;   ->   int e3 = a  ⌚ b;      (both binaries)
```

The reason is one line in `FormatTokenLexer::getNextToken`: every
`tok::unknown` gets `TT_ImplicitStringLiteral`, whose spacing rule is
`return Right.hasWhitespaceBefore()` — preserve what was written. So an
excluded code point is never respaced into something that *looks* like an
operator, which is U§5's non-aliasing property showing up in the formatter
for free. Pinned in both new tests.

## Column-width accounting: confirmed, not reimplemented

`FormatTokenLexer` computes every ordinary token's `ColumnWidth` with
`encoding::columnWidthWithTabs`, which already handles UTF-8. Measured and
asserted:

- `⊞` — `TokenText.size() == 3`, `ColumnWidth == 1`.
- `\N{SQUARED PLUS}` — `ColumnWidth == 16`; `\U0000229E` — `10`.

The sharp test is a line that is exactly at the limit:
`x = aaaa ⊞ bbbb;` is **16 columns** and fits a 16-column style; at 15 it
wraps. Had the glyph counted as three columns it would have been 18 and the
first case would have wrapped. A UCN-spelled chain therefore wraps
differently from the glyph-spelled one — correctly, and that is U04's
prediction confirmed rather than a problem.

## What changed

**Production: 3 files, +32/−9.**

| File | Change |
|------|--------|
| `clang/lib/Format/Format.cpp` | **+5.** `LangOpts.UnicodeOperators = 1;` + comment, in `getFormattingLangOpts()`'s existing `LK_Cpp \|\| LK_ObjC` block |
| `clang/lib/Format/FormatToken.h` | **+7/−1.** `getPrecedence()` passes `/*BacktickIsOperator=*/true, /*UnicodeOperatorsEnabled=*/true` |
| `clang/lib/Format/TokenAnnotator.cpp` | **+31/−9.** The file-static `endsOperand`; the backtick open-classification rewritten to call it; the `tok::user_operator` arm in `determineTokenType` |

**Tests: 2 files amended, 2 new cases.**

| File | Change |
|------|--------|
| `clang/unittests/Format/FormatTest.cpp` | **+69.** `TEST_F(FormatTest, UnicodeOperatorFormatting)` — infix spacing, chaining, mixing with `*`, prefix binding, prefix after `(`, built-in unary minus on both sides, declaration (free, member, template), UCN spellings in expression and declaration, four mixed backtick/Unicode cases, the 16-column width proof, two long-chain wraps (`BOS_None` and `BOS_All`), and the excluded-code-point non-change |
| `clang/unittests/Format/TokenAnnotatorTest.cpp` | **+85.** `TEST_F(TokenAnnotatorTest, UnicodeOperatorTokenTypes)` — the annotations and `SpacesRequiredBefore` for infix/prefix/adjacent, `TT_OverloadedOperator` + `CanBreakBefore == false` in a declaration, `ColumnWidth` for glyph and both UCN forms, the three mixed backtick cases, and the `tok::unknown` / `TT_ImplicitStringLiteral` shape for U+2212 |

Idempotence is covered structurally: `verifyFormat(Expected)` formats the
expected text and requires a fixed point, and `verifyFormat(Expected, Input)`
adds the messed-up-whitespace round trip. It was also checked by hand
(`clang-format` over its own output, `diff` clean) on the probe files.

**In this repo:** `PLAN.md` (U18 ticked, Status row), `REPLAY.md` U18 row,
`DEVIATIONS.md` **DEV-U20**, this handoff.

## Verification evidence

**Build:** `ninja -C /home/sdowney/src/llvm/build-unicode clang-format FormatTests`
→ `EXIT=0`, **zero** `warning:` lines. A `FormatToken.h` edit is 38 edges,
~2 min; a `TokenAnnotator.cpp`-only edit is 3; a `FormatTest.cpp`-only edit
is 3. This is the cheapest step in the plan to iterate on.

**Unittest:** `FormatTests` → **1275 tests, 1275 passed**. The pre-change
count was 1273, so that is exactly the two new cases and **no existing
`FormatTests` case changed behaviour** — including
`FormatTest.BacktickOperatorFormatting`, `FormatTest.BacktickOperatorJSNonRegression`,
`TokenAnnotatorTest.BacktickTokenTypes` and all of `FormatTestJS`.

**Self-format gate (the trap):** cleared deliberately, and it fired.
`clang-format -i` with the freshly built binary changed **two** of the five
touched files (`TokenAnnotator.cpp`'s `endsOperand`, and two long string
literals in `FormatTest.cpp`), after which all five diff clean. The gate log
shows **90** `Checking format of` steps and the run reached lit.

**Full gate:** `ninja -C $B check-clang` → `EXIT=1`, 8 failed:

```
Total Discovered Tests: 54179
  Passed: 48285   Unsupported: 5853   Expectedly Failed: 27   Skipped: 6
  Failed: 8
```

**All 8 are `DirectoryWatcherTest.*`,** the inotify artifact again: 16
`inotify_add_watch()` messages, machine holding **65,382 of 65,536** watches
at gate time. Filtered re-run per PLAN.md:

```
GTEST_FILTER='-DirectoryWatcherTest.*' ./bin/llvm-lit -s ./tools/clang/test
→ EXIT=0
Total Discovered Tests: 54171
  Passed: 48285   Unsupported: 5853   Expectedly Failed: 27   Skipped: 6
  Failed: 0
```

zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines, 160.6 s.

**The arithmetic, like for like.** U05 filtered was 54169 / 48283. U18
filtered is **54171 / 48285** — exactly **+2 discovered / +2 passed**, the
two new gtest cases. No lit test was added; clang-format's coverage lives in
`unittests/Format/` by upstream convention.

## Deviations from the plan / design

**DEV-U20** (`DEVIATIONS.md`): U§10's clang-format claim holds and is now
quantified, but it is three touch points and the third (precedence) fails
silently; the U§11 open question about what clang-format canonicalizes for
`operator ⊞` is answered (it closes the space, following `operator+`); and
the Unicode operator inherits `BreakBeforeBinaryOperators`, which backtick's
delimiter pair cannot. Full text in the ledger.

Two smaller judgement calls a reviewer will ask about:

1. **No style option was added**, as the step file directed and as backtick
   §7's "defer unless reviewers ask" says. There is nothing to configure:
   the spacing is whatever the style already says about binary and unary
   operators, so `SpaceBeforeAssignmentOperators`-style knobs and
   `BreakBeforeBinaryOperators` apply to `⊞` automatically and consistently
   with `+`. Adding an option would *remove* that consistency.
2. **`FormatToken::getPrecedence()` passes `UnicodeOperatorsEnabled=true`
   unconditionally**, not `Style.isCpp()`. The function has no `Style`, and
   the guard is redundant anyway: `tok::user_operator` can only exist in a
   token stream `getFormattingLangOpts` lexed with the flag on, i.e. C++ or
   Objective-C++. The same reasoning already justifies the hard-coded
   `GreaterThanIsOperator=true` beside it.

## Discoveries affecting later steps

- **The self-format glob covers `unittests/Format/` too**, not just
  `clang/lib/Format/`: `clang/lib/Format/CMakeLists.txt` globs `*.cpp`,
  `*.h`, `include/clang/Format/*.h`, `tools/clang-format/*.cpp` **and**
  `unittests/Format/*.{cpp,h}`. PLAN.md's gate fact 2 names only the library
  directory. Both of the files this step had to reformat were caught, one of
  them a test file. If a later step touches a `unittests/Format` file, run
  `clang-format -i` on it too.
- **The self-format check uses the *in-tree* `clang-format`**, not an
  upstream binary (`COMMAND clang-format ${file} | diff -u ${file} -`, with
  `DEPENDS clang-format`). So the binary you format with must be the one you
  just built — which for this step means the feature is checking its own
  source, harmlessly, since `clang/lib/Format/` contains no U1 code point
  outside a string literal.
- **`FormatTokenLexer` types every `tok::unknown` as
  `TT_ImplicitStringLiteral`** (`FormatTokenLexer.cpp`, right after
  `readRawToken`), which means "preserve the surrounding whitespace and never
  break here". That is why enabling the exclusion hook in the format path is
  output-invisible, and it is the general answer to "what does clang-format
  do with a token it does not understand".
- **The backtick binary at `~/src/llvm/build-backtick-trunk/bin/clang-format`
  is a usable before-picture oracle.** Running it is read-only and does not
  disturb that build dir; it is the cheapest way to prove "formatting of X is
  unchanged" rather than asserting it.
- **`FormatTests` iterates in seconds.** Full suite 6.4 s, and the build for
  a test-only edit is 3 edges. There is no reason to guess at an expected
  output in this area — run it.
- **Glyph budget unchanged.** U18 used ⊞ ⊖ ⊗ only, all previously spent.
  Free list still **U+22B0, U+22B1, U+22B3–U+22BF, U+22C2–U+22C4**.

## Forward notes for U19 — replay-ledger audit

Written after reading `steps/U19-replay-audit.md`. **Your dependency list is
now fully checked; U21 is the only unchecked step and it is off the replay
path.**

- **My row is the most finely split in the ledger, and it is the only row
  that carries all three classes at once.** `Format.cpp`, `FormatToken.h`
  and the `tok::user_operator` arm are `upstream replay`; `endsOperand` is
  `shared if landed`; the backtick open-classification rewrite is a
  `backtick dependency` with **no** clean-`main` counterpart — it is a
  refactor of backtick-track code and simply disappears. Read the row's
  third column: it names the exact anchor for each of the three replayed
  hunks, because two of the three currently sit *inside* backtick-created
  context (`Format.cpp`'s `LK_Cpp || LK_ObjC` block, which this patch must
  itself introduce on `main`; and the placement of the annotator arm after
  the backtick block).
- **Do not let the `FormatToken.h` hunk fall off the stack.** It is one line
  and it looks cosmetic. It is not: without it a long chain of user operators
  wraps wrongly and *every test still passes*. It also depends on U11's
  replayed `getBinOpPrecedence` signature, which on `main` will have no
  `BacktickIsOperator` parameter — so the call becomes a 4-argument call, not
  a 5-argument one. That is a re-anchoring your audit should state
  explicitly, since it is the only place where U11's signature choice reaches
  outside `clang/lib/Parse`.
- **On the ledger's accuracy, which your step file asks you to reconcile
  against the real diff:** the rows I read (U04, U05, U11, U12, U15) are
  accurate and hunk-level as advertised, and U04/U05's forward notes named
  the backtick-only hunks correctly. Two things to check rather than trust.
  (a) Several rows say "no hunk takes diff context from a backtick symbol" —
  true for those steps, **false for mine**, so the count of non-`upstream
  replay` items is now larger than U05's forward note predicted: U05 said
  "exactly three hunks in the whole diff", and U18 adds two more (the
  `endsOperand` enumerator and the backtick call-site rewrite) plus seven
  test cases. Re-derive that number; do not quote U05's. (b) `REPLAY.md` has
  **no row for U18's test-file split until now** — item 5 of your step file
  asks you to split mixed test files, and my row is written to be executed
  mechanically: it names the four `verifyFormat` lines and the three
  `annotate` blocks to hold back, by their source text.
- **The rows are in step-execution order, not numeric order** (…U12, U14,
  U15, U04, U05, U18), because Phase A was finished late. If you sort them
  numerically for the audit, say so, or a reader will think a row is missing.
- **The "before" number for U20:** filtered `check-clang` on `06735e8df66d`
  is **54171 discovered / 48285 passed / 0 failed**, with the 8
  `DirectoryWatcherTest.*` cases filtered out for the machine's inotify
  budget and nothing this branch did. Unfiltered it is 54179 / 48285 / 8.
- **For your commit-order item 4**, clang-format is genuinely last and
  genuinely independent: it depends only on the *token* existing, so in the
  upstream stack it can go up as its own PR right after the lexer commits
  (U03/U04) and does not need Phases B–D at all. That is a real reviewability
  win worth stating — `lib/Format` has different reviewers.
- **U21 has not run.** If it lands before you, it is a probe and its step
  file says it is off the replay path, but check whether it changed any file;
  if it did, its hunks need a class.

## Open risks / TODOs

- **U19 and U21 are the only unchecked steps.** Every implementation step is
  landed.
- **DEV-U20 is open for reconciliation** into U§10 and U§11. The precedence
  finding is the one the paper wants: it is a second, independent argument
  for U9's single fixed level, coming from a tool that cannot do lookup.
- **DEV-U19 (U05) and DEV-U18 (U04) remain open for reconciliation**;
  nothing in U18 changes them.
- **DEV-U15's default-argument corner** and **DEV-U16's evaluation-order
  split** remain measured-but-undecided. **DEV-U17 is still an open backtick
  printer bug**, not this plan's to fix.
- **U§6 still owes a sixth worked example** (`⊖a ⊞ 2 * ⊖b`) and **U§13 still
  owes the fold decision.** Unchanged by U18.
- **`TT_BacktickInfixClose` in S10's post-operand list is a latent backtick
  bug**, now documented above and in the code comment. It is unreachable on
  input with a valid parse. Not fixed; the backtick track owns it.
- **The `-Wswitch` `BacktickInfixExprClass` gap is still open in two files**
  (`StaticAnalyzer/Core/ExprEngine.cpp:1688`,
  `tools/libclang/CXCursor.cpp:175`). U18 touched no header outside
  `lib/Format`, so neither resurfaced — the gate log has **zero** `warning:`
  lines, the second such step after U09/U12.
- **`clang/lib/CIR/` is still untouched and uncompiled.**
- **The inotify/`DirectoryWatcherTest` artifact is still present** (65,382 of
  65,536 watches). Budget for the filtered re-run.
