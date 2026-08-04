# Handoff — U20 clean-`main` replay branch and gate

- **Status:** DONE (gate passed)
- **Branch / commit:** new branch **`unicode-operators-upstream`** @
  **`44299aae010d`**, a 15-commit stack on `upstream/main` @
  **`d28193fa1ff6`**. Worktree `/home/sdowney/src/llvm/unicode-upstream`
  (created from `/home/sdowney/src/llvm/unicode`, so the pristine
  `~/src/llvm/main` worktree and `~/src/llvm/build-main` were never touched).
  Build dir `/home/sdowney/src/llvm/build-unicode-upstream` — new, not the
  experiment's. The experiment branch is unchanged at `06735e8df66d`.
  Plan repo: `unicode-operators`.
- **Date / agent:** 2026-08-04

## The two-sentence version

The Unicode feature replays onto pristine trunk as **15 commits, 109 files,
+7073/−18** (the compiler proper: 77 files, +1940/−18), and
`git diff upstream/main..unicode-operators-upstream | grep -i backtick`
returns **nothing**. The gate is the clean-`main` baseline **+72 discovered
/ +72 passed / 0 failed** — U19's prediction to the test — and **no behaviour
turned out to require the backtick diff**, so U§12's separable-fates claim is
now an executed result rather than an audited one.

## What changed

**In the LLVM tree — a new branch, nothing on any existing one.** The stack,
in order, with §5's PR grouping:

| # | Commit | Title | Stat | PR |
|---|--------|-------|------|----|
| 1 | `e3073eda7a54` | `[clang] Add -funicode-operators` | 4 files, +24 | A |
| 2 | `efda48cd2d28` | `[clang][Lex] Frozen UAX#31 Pattern_Syntax operator tables` | 3, +422 | A |
| 3 | `a4bfb311624b` | `[clang][Lex] Lex tok::user_operator from UTF-8 glyphs` | 5, +271 | A |
| 4 | `b4a1b422f6f0` | `[clang][Lex] UCN and \N{...} spellings form operator tokens` | 6, +430/−7 | A |
| 5 | `9278d934ea08` | `[clang][Lex][Parse] Diagnose excluded code points with reasons` | 8, +432/−13 | A |
| 6 | `2f9cfdab0e1e` | `[clang][Basic] prec::UserInfix: one precedence level …` | 3, +24/−7 | B |
| 7 | `5d50da917b46` | `[clang][AST] DeclarationName kind for Unicode user-defined operators` | 21, +436/−1 | D |
| 8 | `5b1801ee6f2c` | `[clang][Parse] Parse operator<op> as an operator-function-id` | 9, +193/−5 | D |
| 9 | `cea7bf068095` | `[clang][Sema] Declaration rules and arity for user-defined operators` | 9, +322/−1 | D |
| 10 | `1ade09bef6ca` | `[clang][AST] Itanium mangling … (vendor-extended form)` | 3, +206/−11 | E (parked) |
| 11 | `1a560ede86b1` | `[clang] Explicit-call sweep for user-defined operators` | 2, +534 | D |
| 12 | `f7cf3934ee80` | `[clang][Parse][Sema] Infix and prefix uses; candidate assembly with ADL` | 6, +667 | F |
| 13 | `50896d6cf555` | `[clang][AST] UserOperatorExpr: operator syntax survives instantiation` | 36, +2268/−22 | F |
| 14 | `49c3bec0acce` | `[clang][Serialization][ASTMatchers] PCH, modules, import, matchers` | 15, +738/−17 | D |
| 15 | `44299aae010d` | `[clang][Format] Format Unicode user-defined operators` | 5, +173/−1 | C |

Commit 6 is U19's one structural recommendation, executed: **`lib/Format`
(commit 15) depends on commits 1–4 and 6 and on nothing else** — no
`DeclarationName`, no Sema, no AST node. Commit 10's message says in plain
text that its mangling is held back from any real submission (§7).

Commit titles follow §5's upstream shape (`[clang][Area] …`) rather than the
plan's `[unicode] <title>` convention. That is deliberate and is the one place
this step departs from the task's stated commit convention: the branch is meant
to read as an upstream PR series, and a `[unicode]` prefix is the one thing in
it no upstream reviewer could parse.

**In this repo:** `REPLAY.md` gained the final section **"U20 — the ledger,
executed and closed"**; `DEVIATIONS.md` gained **DEV-U22**; `PLAN.md` has U20
ticked with its Status row; this handoff.

## Verification evidence

**Baseline first, in the same fresh build dir, on pristine `d28193fa1ff6`:**

```
ninja -C build-unicode-upstream check-clang     -> 54167 / 48242 / 8 failed
                                                   (all 8 DirectoryWatcherTest)
GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test
                                                -> EXIT=0
   54159 discovered / 48242 passed / 0 failed / 27 XFAIL / 5884 unsup / 6 skipped
```

**Replay branch, same commands:**

```
ninja -C build-unicode-upstream check-clang     -> 54239 / 48314 / 8 failed
                                                   (the same 8)
GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test
                                                -> EXIT=0
   54231 discovered / 48314 passed / 0 failed / 27 XFAIL / 5884 unsup / 6 skipped
```

**Exactly +72 discovered and +72 passed**: 20 new lit files and 52 new gtest
cases, which is U19 §6's number. **No pre-existing test changed behaviour** —
`Unsupported`, `XFAIL` and `Skipped` are identical between the two runs. The 8
`DirectoryWatcherTest` failures are the machine inotify condition (65,382 of
65,536 watches held); they fail identically on the pristine binary.

The gate log has **90 `Checking format of` steps before lit**, so the
self-format trap was cleared — the in-tree `clang-format -i` was run over
`lib/Format/{Format.cpp,FormatToken.h,TokenAnnotator.cpp}` and
`unittests/Format/{FormatTest.cpp,TokenAnnotatorTest.cpp}` before committing.

**No backtick anywhere:**

```
git diff upstream/main..unicode-operators-upstream | grep -i backtick   -> no output
```

Run against the whole diff, not just changed lines, and checked at every one of
the 15 commits as it was made. `Options.td` (U19's blind spot for the
word-free `ShouldParseIf` edit) was checked by hand: only `defm
unicode_operators` is present and it carries the guard on its own.

**Every test U19 classified as upstream-clean passes unmodified.** Targeted
re-run over the whole affected surface after the final build:

```
llvm-lit -s clang/test/{Lexer,Parser,SemaCXX,CodeGenCXX,AST,PCH,Modules} \
            clang/test/Driver/funicode-operators.c
   5031 discovered / 4958 passed / 0 failed / 9 XFAIL / 64 unsupported
FormatTests --gtest_filter='*UnicodeOperator*'   -> 2 PASSED
```

**Flag off is upstream, measured not argued.** A TU with U1 code points in
every position a source file can put them (comment; narrow, `u` and `U`
strings; raw string; `char32_t` literal; the excluded code points `− ∂ ∇` in a
string; the two mathematical-notation identifier characters as identifiers; stray
infix and prefix uses; an `operator⊞` declaration) was compiled by the replay
`clang` with the flag off, and by a `clang` built from pristine `d28193fa1ff6`
in the same build dir:

- `-fsyntax-only` diagnostics — **byte-identical** (all 29 lines, including
  the two `-Wc++2d-extensions` mathematical-notation warnings and the
  `unexpected character '⊞' U+229E` recovery pair);
- `-E` output — **byte-identical**;
- `-emit-llvm` on the well-formed subset — **byte-identical except the
  `!llvm.ident` string**, which carries the commit hash.

(The TU and both output sets are in the session scratchpad; the comparison
required checking the worktree out at `upstream/main`, rebuilding `clang`,
capturing, then restoring the branch and rebuilding. Budget ~30 minutes for it
if it has to be redone.)

**The two behaviours the ledger said would fail silently were checked
directly.** `(... ⊞ N)` diagnoses `expected expression` (so
`isFoldOperator`'s `&& Level != prec::UserInfix` is present and working), and
`FormatTest.UnicodeOperatorFormatting`'s long-chain wrapping assertions pass
(so `FormatToken.h`'s fourth `getBinOpPrecedence` argument is present).

## Deviations from the plan / design

**DEV-U22**, three items, the first structural.

1. **`REPLAY.md` §5's commit 12 does not compile as specified.** It says
   commit 12 carries U13's `CreateOverloadedUserOp` "**as amended by U16**",
   and U19's forward notes say never to replay U13's own form. But U16's
   amendment *is* the `UserOperatorExpr` wrapper — `Wrap()` constructs the
   node — and the class does not exist until commit 13. Resolved by replaying
   **U13's form at commit 12 and U16's amendment together with the node at
   commit 13**, exactly as the experiment branch's own history did. The
   DEV-U12 shape does fail at commit 12 (measured:
   `Parser/unicode-operator-prefix.cpp`'s member-operator-in-a-template
   section) and passes from commit 13 on. The correct statement of the trap is
   "the stack must not *end* at U13's form".
2. **§5's split of commit 5 was unnecessary and mildly harmful.** U05's
   `ParseExprCXX.cpp` + `DiagnosticParseKinds.td` half was to be held back to
   commit 8. There is no such dependency — the identifier-profile note hangs
   off the *upstream* failure exits of the conversion-function-id parse, which
   exist unchanged on clean `main`. Held back, commit 5's own lit test
   `Lexer/unicode-operators-excluded.cpp` **fails at commit 5** (two `on-note`
   directives unseen). Kept whole in commit 5, which is therefore
   self-testing. This was found by running the test, not by reading.
3. **"Will fuzz on context" understated the cost.** `git apply -3` of U16's
   diff produced **hard conflicts with markers in 18 files / 23 hunks**, not
   fuzz. All were one stereotyped shape (ours empty; theirs = a backtick block
   followed by the user-operator block) and were resolved mechanically by
   keeping the user-operator half, but **three needed a hand fix afterwards**
   where the walk-back swallowed a shared continuation line
   (`Expr.cpp` ×2 — `isUnusedResultAWarning` and `isConstantInitializer` —
   and `ExprConstant.cpp`) and one where the `template <class Emitter>`
   belonging to the deleted backtick function left a duplicate
   (`ByteCode/Compiler.cpp`). **Verify a merge like this by diffing the result
   against the experiment file; do not trust the merge.**

Two smaller corrections: the surviving `// RUN` count is **86**, not §6's 87;
and the landed hunk count is **200**, not §2's predicted 201 (hunks that were
separate on the branch because a backtick line sat between them coalesce on
`main` — content, not coverage).

One method note that is not a deviation: U19's advice to **apply by area from
the cumulative diff rather than cherry-pick** was right, but the executed form
was per-*step* diffs applied with `git apply -3` in §5's regrouped order, which
is what lets a file touched by three steps (`Lexer.cpp` by U03/U04/U05) land in
three different commits. Files that are backtick-free *and* drift-free were
taken wholesale with `git checkout unicode-operators-experiment -- <file>`;
that is safe for exactly 60 of the 110 files and for no others.

## Discoveries affecting later steps

- **825 commits of upstream drift cost nothing.** They touched 25 of the 109
  files (+319/−144) and not one collided. The three surfaces the step file
  named as the maintenance-cost question: `DeclarationName.h` /
  `IdentifierTable.h` **untouched**; `UnicodeCharSets.h` **untouched**; the
  Format token machinery drifted but not in the three places this patch edits.
  `ASTReader.cpp`/`ASTWriter.cpp` drifted only in their OpenMP clause readers.
  **Every one of §4's six anchors still existed verbatim**, including
  `PointerToMember = 15` with no trailing comma.
- **The clean-`main` gate numbers to compare against next time** are
  `54159 / 48242 / 0` filtered at `d28193fa1ff6`. They are *not* comparable
  with the experiment branch's `54171 / 48285 / 0`, which includes 45 backtick
  commits' worth of tests.
- **A fresh build dir is a ~35-minute cold build** here (4353 edges, 16
  compile jobs / 4 link jobs), and `check-clang` is ~3 minutes of test time on
  top of an incremental build. Touching `LangOptions.def` invalidates the
  precompiled header of every clang library — **do not edit the worktree while
  a build is running**; it fails with `has been modified since the precompiled
  header was built` and costs the whole build.
- **The composability sections are vacuous upstream, not deleted.** Three
  places now say so explicitly rather than dropping the claim silently:
  `SemaCXX/unicode-operator-call.cpp` §8, `SemaCXX/unicode-operator-adl.cpp`
  §6, and item 9 of `Parser/unicode-operator-precedence.cpp`. Each says the
  claim needs a second feature sharing `prec::UserInfix` and is checked on the
  prototype branch that carries one. That phrasing is reusable in the paper.
- **Still uncovered on both branches:** the `lldb` switch arm is
  compile-unverified (this build dir is also `clang;clang-tools-extra`), and
  `clang/lib/CIR/`'s `CXXRewrittenBinaryOperator` site set is still untouched.

## Forward notes for the NEXT step — U21, postfix feasibility probe

Written after reading `steps/U21-postfix-probe.md`. U21 is **off the replay
path** and its step file says so; here is what that means concretely now that
the replay branch exists.

- **Work on the experiment branch, not the replay branch.** U21's tree is
  `/home/sdowney/src/llvm/unicode` (branch `unicode-operators-experiment` @
  `06735e8df66d`, working tree clean) with build dir
  `/home/sdowney/src/llvm/build-unicode`. **Nothing U21 does may reach
  `unicode-operators-upstream` or `/home/sdowney/src/llvm/unicode-upstream`** —
  that branch is now the paper's implementation-cost number and a stray commit
  changes it. If U21 prototypes, use a scratch branch off the experiment
  branch, and say which in the handoff. `build-unicode-upstream` can be left
  alone or deleted; it is reproducible from U00's CMake line with the source
  dir pointed at `unicode-upstream/llvm`.
- **Where the three things U21 measures actually live** (paths on the
  experiment branch; the replay branch has them in the same functions):
  - prefix parse — `clang/lib/Parse/ParseExpr.cpp`,
    `case tok::user_operator:` in `Parser::ParseCastExpression`, placed with
    the `tok::star`/`plus`/`minus` unary group and immediately before
    `case tok::kw_co_await:`. It captures the code point with
    `Lexer::getUserOperatorCodePoint` **before** `ConsumeToken()`.
  - infix dispatch — same file, the
    `else if (OpToken.is(tok::user_operator))` arm in
    `Parser::ParseRHSOfBinaryExpression`, between the `RHS.isInvalid()`
    recovery branch and `else if (TernaryMiddle.isInvalid())`.
  - Sema — `Sema::ActOnUserOperator` in `clang/lib/Sema/SemaExpr.cpp`
    (immediately before `Sema::ActOnCallExpr`) does the phase-1 lookup and
    forwards; `Sema::CreateOverloadedUserOp` in
    `clang/lib/Sema/SemaOverload.cpp` (immediately before
    `Sema::CreateOverloadedBinOp`) does candidate assembly and is
    **arity-generic** — it branches only on `Operands.size()`.
- **Three arity facts U21's §1 analysis needs and that the replay confirmed:**
  1. `UserOperatorExpr` stores `NumOperands` (1 or 2) and nothing else about
     fixity. **A postfix form is a third *fixity*, not a third arity**, so the
     node would need a new field — it is not free the way U16's arity-generic
     design made prefix free.
  2. The Itanium encoding U09 chose is `v <arity-digit> <source-name>`. A
     postfix unary and a prefix unary both have arity 1, so under the current
     scheme **they mangle identically** — `v1op_uXXXX` for both. That is an
     ODR/ABI collision, not merely an aesthetic problem, and it is a cost
     U21 must price alongside the parsing question. It is also an argument for
     §7's "a real proposal wants a first-class `<operator-name>` production":
     the vendor-extended production has one digit and it is already spent on
     arity.
  3. `CheckUserOperatorDeclaration` (`clang/lib/Sema/SemaDeclCXX.cpp`, between
     `CheckOverloadedOperatorDeclaration` and
     `checkLiteralOperatorTemplateParameterList`) is where the one-or-two
     operand rule is enforced and where a `std::postfix` tag would have to be
     recognised. It currently knows nothing about parameter *types* beyond the
     class-or-enum requirement.
- **For "is 'can this token begin a cast-expression' a one-token test?"**, the
  existing predicates to read first are `Parser::isNotExpressionStart()` and
  `Parser::isKnownToBeDeclarationSpecifier()` at the top of
  `clang/lib/Parse/ParseExpr.cpp` (just above `isFoldOperator`). Note that
  `isNotExpressionStart` is a *negative* test and its fallback arm calls
  `isKnownToBeDeclarationSpecifier()`, which **does** reach tentative parsing —
  that is precisely the question the step asks, and the answer is visible in
  those thirty lines.
- **`isFoldOperator` is now a three-way exclusion** (`Conditional`,
  `Spaceship`, `UserInfix`) on both branches. If U21's greedy-infix rule
  changes the level's membership in any set, that line is the one to look at,
  and it is the line the replay proved is invisible to every other test.
- **The paren-forcing set U21 must confirm** is exactly the tokens that are
  both prefix-unary and infix-binary. On the experiment branch that set
  includes **prefix user operators themselves**, which is why
  `Parser/unicode-operator-precedence.cpp` §11a exists; on the replay branch
  that file survives and is worth re-reading as the control.
- **Do not touch `REPLAY.md`'s U-rows.** They are closed. U21's row, per its
  own step file, says "probe only, nothing landed" — add it as a new row at
  the end of the U20 section, not in the classification table.

## Open risks / TODOs

- **U21 is the only unchecked step.** With U20 done, the replay path is
  complete and the plan's implementation work is finished.
- **DEV-U22 (this step) is open for reconciliation** into `REPLAY.md` §5 (drop
  the commit-5 split, restate the U13/U16 trap) and into the experiment plan's
  "Upstream Replay Assumptions", where it carries the executed form of the
  separable-fates result.
- **DEV-U15/U16/U17/U18/U19/U20/U21 remain open** for reconciliation into
  `docs/unicode-operators.md`; U20 changed none of them.
- **U8 is still `Proposed — open (ABI)`.** Commit 10 carries the prototype
  scheme onto a clean-`main` branch, which makes it easier to mistake for a
  settled encoding. The commit message says otherwise; the paper must too, and
  U21's finding (2) above adds a second reason to reopen it.
- **The replay branch is not pushed anywhere.** It exists only in
  `/home/sdowney/src/llvm/unicode-upstream`. If it matters for the paper, it
  should be pushed to `origin` before the worktree is reused.
- **U§6 still owes a sixth worked example** (`⊖a ⊞ 2 * ⊖b`) and **U§13 still
  owes the fold decision** — unchanged by U20.
