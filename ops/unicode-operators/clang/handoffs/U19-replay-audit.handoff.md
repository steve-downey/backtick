# Handoff — U19 replay-ledger audit

- **Status:** DONE (gate satisfied — the step has no `check-clang` requirement)
- **Branch / commit:** LLVM worktree **unchanged**, still
  `unicode-operators-experiment` @ `06735e8df66d` (U18), working tree clean.
  Plan repo: `unicode-operators` @ `e9cb98f`.
- **Date / agent:** 2026-08-04

**U20 is the last step on the replay path.** U21 (postfix probe) is the only
other unchecked step and is off the path.

## The two-sentence version

Eighteen REPLAY rows reconcile against the real diff with **no gaps in
either direction**, and the ratio is the paper result: of **204 hunks**,
**201 (98.5 %) survive onto clean `main`** and the entire backtick coupling
of a 7,341-line feature is **three constructs** — `prec::UserInfix`,
`Parser::isFoldOperator`'s exclusion of it, and clang-format's `endsOperand`
helper. The audit corrected six instructions U20 would otherwise have
followed literally, the sharpest being two undocumented `diff`-*pair* RUN
lines that would have left a `diff` against a file never written.

## What changed

**No compiler file. Three files in this repo:**

| File | Change |
|------|--------|
| `ops/unicode-operators/clang/REPLAY.md` | New final section **"U19 — the audit and the verdict"**, 8 sub-sections: (1) the diff measured + both gap directions; (2) the hunk ratio; (3) eight audit findings; (4) the six standalone equivalents *as text to paste*; (5) the ordered 15-commit upstream stack + the independent-PR judgement; (6) mechanical test-file splits with line numbers; (7) the U09 ABI-open item, separated out; (8) the complete held-back list |
| `ops/unicode-operators/clang/DEVIATIONS.md` | **DEV-U21** — the experiment plan assumed one shared construct; there are three |
| `ops/unicode-operators/clang/PLAN.md` | U19 ticked, Status row |

## Verification evidence

**Gate:** the step requires none (no compiler change). The **"before" number
for U20**, carried from U18 and still current because nothing has touched a
source file since:

```
GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test  -> EXIT=0
  Total Discovered Tests: 54171   Passed: 48285   Failed: 0
  Expectedly Failed: 27   Unsupported: 5853   Skipped: 6
Unfiltered check-clang: 54179 / 48285 / 8 failed — all 8 DirectoryWatcherTest.*
```

**Audit gates, both met:**

1. *Every file in the diff carries a classification.* A basename sweep of
   all 110 diff paths against `REPLAY.md` reported six misses
   (`ByteCode/Compiler.{h,cpp}`, `CGExpr{Agg,Complex,Constant,Scalar}.cpp`);
   all six are present in U16's row under brace/prose abbreviations. **No
   real gap.**
2. *Every file named in a row is in the diff*, except three correctly absent:
   `clang/test/lit.cfg.py` (cited as unchanged), `docs/pattern-syntax-audit.py`
   (generator, lives in this repo), and one abbreviation.
3. *The proposed upstream stack mentions backtick nowhere* — not in a title,
   a body, or (after §4/§6) any content line.

**Measurements, all reproducible:**

```bash
# 204 hunks: 171 production + 33 test/doc
git -C ~/src/llvm/unicode diff -U0 backtick-trunk..unicode-operators-experiment |
  awk '/^\+\+\+ b\//{f=substr($0,7)} /^@@/{ if (f ~ /(\/test\/|\/unittests\/|docs\/)/) t++; else p++ }
       END{print p, t}'
```

## The ratio (capture-in-handoff item)

| Class | Production | Test/doc | Total | Share |
|-------|-----------:|---------:|------:|------:|
| `upstream replay`, verbatim | 156 | 15 | **171** | **83.8 %** |
| `upstream replay`, mixed hunk (strip named backtick lines) | 10 | 17 | **27** | **13.2 %** |
| `shared if landed` | 3 | 0 | **3** | **1.5 %** |
| `backtick dependency`, deleted | 2 | 1 | **3** | **1.5 %** |
| | **171** | **33** | **204** | |

- **201/204 (98.5 %)** of hunks survive onto clean `main`.
- **169/171 (98.8 %)** of *production* hunks do.
- Only **6 hunks (2.9 %)** need any judgement; the 27 mixed ones are
  deletions of named lines.
- Test-suite cost of decoupling: **one lit file** (`backtick-c-mode.c`) out
  of 21, and **zero** of 52 gtest cases.

**Correcting a number in circulation:** U05's forward note said "exactly
three hunks in the whole diff" are non-`upstream replay`. It is **six**
(3 `shared if landed` + 3 dropped) — U18 added two production hunks and one
test file after U05 was written, and `isFoldOperator` is `shared if landed`
rather than verbatim. U18's forward note predicted this correctly.

## Deviations from the plan / design

**DEV-U21.** `clang-experiment-plan.md`'s "Upstream Replay Assumptions" names
**one** shared construct (the precedence concept). There are **three**:

1. `prec::UserInfix` — the assumption's own item;
2. `Parser::isFoldOperator`'s `&& Level != prec::UserInfix` — on clean `main`
   an *addition*, not a rename, and **the one that fails silently**;
3. clang-format's file-static `endsOperand` in `TokenAnnotator.cpp`, which
   names the backtick `TokenType` `TT_BacktickEscapeClose`.

A fourth, softer coupling is not a hunk: `Sema::CreateOverloadedUserOp`'s doc
comment cites "the backtick design's Sec. 17.4", which upstream cannot
reference. Reword, don't delete (§4, last bullet).

Recommended doc changes are in the DEV-U21 row; the headline for U§12 is that
the separable-fates claim is now **quantified** and holds, and that the
sharing surfaced **twice independently** (parser and formatter), which is
evidence that "one level for all user-introduced infix syntax" is a real
design primitive rather than a convenience of this prototype.

## Discoveries affecting later steps

- **`upstream/main` has moved 582 commits** since the experiment's base: it
  is now `e7dd336e0f78` (2026-08-02) where `bb33de72920a` (2026-07-29) is
  what `backtick-trunk` forked from. **Every "on `main` it reads…" anchor in
  §4 was verified at `bb33de72920a` and nowhere else.**
- **`git merge-base backtick-trunk upstream/main` is still `bb33de72920a`**,
  so that commit remains a valid, reachable fallback base.
- **The one-line grep that finds all backtick contamination** is over
  *changed lines*, not context — see §1 of the audit. It has one blind spot:
  `Options.td`'s backtick edit adds `ShouldParseIf<cplusplus.KeyPath>`, which
  does not contain the word. Check that file by hand.
- **25 production hunks take backtick text as diff *context*** (22 files).
  Their content is backtick-free; they will fuzz on cherry-pick and must be
  re-anchored on the upstream neighbour. This is why the audit recommends
  applying the stack **by area from the cumulative diff**, not by
  cherry-picking the 18 commits.
- **`build-unicode` has `LLVM_ENABLE_PROJECTS=clang;clang-tools-extra`.** The
  lldb hunk (`ClangASTSource.cpp`, one switch arm) has never been compiled on
  this branch. `clang/lib/CIR/`'s `CXXRewrittenBinaryOperator` site set was
  never *touched* at all — that one is a genuine hole in `UserOperatorExpr`'s
  obligations, not merely an unbuilt line.

## Forward notes for U20 — clean-`main` replay branch and gate

Written after reading `steps/U20-upstream-replay.md`. **Read `REPLAY.md` §4,
§5 and §6 as your working document; they are written to be executed, not
interpreted.**

- **Base commit.** Your step file asks for a fresh `git fetch upstream` and a
  branch off current `upstream/main`, on the grounds that the drift is part
  of the result. **Follow it** — I amended §3 item 7 of the audit to say so.
  But my §4 anchor text was verified only at `bb33de72920a`, so if an anchor
  does not match, suspect 582 commits of drift before suspecting the ledger.
  `bb33de72920a` is still the merge-base and is your fallback if drift makes
  the replay unmeasurable rather than merely inconvenient.
- **Worktree hygiene.** Your step file says
  `git -C ~/src/llvm/main worktree add …`. Creating a worktree from that repo
  does not check anything out in `~/src/llvm/main` itself and does not touch
  `~/src/llvm/build-main` — but CLAUDE.md is firm that the pristine build must
  not be disturbed, so **do not switch that worktree's branch and do not
  build into `build-main`**. `~/src/llvm/unicode` shares the same object
  store; `git -C ~/src/llvm/unicode worktree add …` works identically and
  avoids the pristine tree entirely. Either is fine; say which you used.
- **Do not cherry-pick the 18 commits.** Two reasons, both measured. (1) 25
  production hunks take backtick lines as *context* and will fuzz. (2)
  **U13's Sema hunks must be replayed as amended by U16** —
  `CreateOverloadedUserOp` gained `const UnresolvedSetImpl &Fns` and
  `bool PerformADL`, and the phase-1 lookup moved into `ActOnUserOperator`;
  the intermediate form reintroduces DEV-U12. Taking the **cumulative** diff
  per area (as §5's commit table is organised) makes both problems vanish,
  because the cumulative diff already carries the amended form.
- **The single likeliest mistake in the whole step** is dropping
  `isFoldOperator`'s exclusion (§4.2). On `main` the line ends at
  `prec::Spaceship`, so it reads as an *addition* rather than the rename the
  branch shows; skip it and a user operator is silently admitted as a fold
  operator, which U11 measured as *rejected*. **Nothing else fails.** Test it
  explicitly: `(... ⊞ N)` must diagnose `expected expression`.
- **The second likeliest** is `FormatToken.h` (§4.4, last block). One line,
  looks cosmetic, and without it long chains of user operators wrap wrongly
  while **every clang-format test still passes**. It is also the only place
  U11's signature choice reaches outside `lib/Parse`.
- **Split U11 into two commits** — this is the audit's one structural
  recommendation (§3 item 6, §5 commit 6). A precedence-only commit
  (`OperatorPrecedence.{h,cpp}` + the four `ParseExpr.cpp` lines that consume
  it) makes **clang-format depend on lexer + precedence and on nothing else**,
  so `lib/Format` needs no Sema review. It also isolates "EWG banks one
  level" as a reviewable unit. U18's forward note claimed clang-format could
  go up right after the lexer commits; that is true only once this split is
  made.
- **Commit 5 must also be split.** U05 is the first step whose production
  diff reaches `lib/Parse`; its `ParseExprCXX.cpp` + `DiagnosticParseKinds.td`
  half belongs with commit 8 (operator-function-id), after the code it
  annotates. The two halves are ~90 lines apart and independent.
- **Test splits are line-exact in §6.** The four `diff`-*pair* traps are
  `AST/unicode-operator-print.cpp` (22+23), `PCH/unicode-operators.cpp`
  (34+35+36), `Parser/unicode-operator-precedence.cpp` (51+52) and
  `CodeGenCXX/unicode-operator-semantics.cpp` (17+18). **Two of those four
  were not documented as pairs before this audit** — U16's and U17's rows
  named them as single lines. Deleting only the producer leaves a `diff`
  against a file that is never written, and lit will fail in a way that looks
  like a real regression.
- **One RUN line you must *not* delete**: `SemaCXX/unicode-operator-semantics.cpp`
  line **29** (`-DOFF`, no `-fbacktick`). Its neighbour at 30 is the backtick
  one. Section 9's `#else` block keeps both `off-error` uses and needs 29.
- **`-DPRINTING` disappears entirely on `main`** (precedence file). It exists
  only to route around DEV-U17, a pre-existing *backtick* printer defect, and
  its `#ifndef PRINTING` guard lives inside section 10, which you are
  deleting.
- **Item 9 of the precedence file becomes vacuous, not untested.** Its
  evidence is an `-ast-print` diff between the two flag settings; with one
  flag there is nothing to compare. **Say so in the replayed file's header**
  rather than deleting three lines silently.
- **Section 11a of the precedence file replays** even though its comment
  discusses backtick — reword the comment, keep the test. It is the control
  showing `UserOperatorExpr` has no `CallExpr` invariant to break, and is
  worth having on `main` in its own right.
- **Your `grep -i backtick` gate will hit three legitimate residues** unless
  you handle them: the `SemaOverload.cpp` doc-comment cross-reference (§4,
  reword), the `prec::UserInfix` comment (§4.1 gives the `main` text), and
  the `getBinOpPrecedence` doc comment (§4.4). All three are prose. Your step
  file is right that a stray mention is a finding, not a typo — these three
  are findings I have already made; anything *else* is new.
- **Expected test delta.** 20 lit files (21 minus `backtick-c-mode.c`) and 52
  gtest cases, i.e. **+72 discovered** over clean `main`'s own baseline, from
  87 surviving RUN lines (119 minus 32). Establish `main`'s baseline *first*,
  on the same machine, before applying commit 1 — the branch's 54171 is not
  comparable, it includes 45 backtick commits' worth of tests.
- **Budget for the inotify artifact.** 8 `DirectoryWatcherTest.*` failures
  are a machine-wide condition (65,382 of 65,536 watches held by
  `cloud-drive-dae`), not yours; they will hit the new build dir too. Use the
  `GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test`
  re-run from PLAN.md.
- **Self-format trap applies to the new build too.** `check-clang` formats
  `clang/lib/Format/**` *and* `clang/unittests/Format/*.{cpp,h}` with the
  **in-tree** `clang-format`, and aborts before lit if they differ. You are
  touching four files under those globs; run `clang-format -i` on them with
  the binary you just built.
- **The mangling commit (10) is the one thing you cannot settle by executing
  it correctly.** §7 records it as a cross-vendor ABI question, not a replay
  question: `v <digit> <source-name>` with `op_u<UPPERCASE-HEX>`, arity
  including the implicit object parameter, and an honest `Error()` for MSVC.
  Land it (the stack does not build without *a* mangling) but mark it held
  back from any real submission, in the commit message and in your handoff.
- **Close the ledger out**, as your step file asks. The prediction to grade:
  §2 says 201 of 204 hunks land and 6 need judgement. If the replay matches,
  say so plainly — a ledger that predicted the replay is itself a result
  about whether this kind of prototype can be kept honest step by step. If it
  doesn't, say it louder, and open a DEVIATIONS row (DEV-U22 is free).

## Open risks / TODOs

- **U20 and U21 are the only unchecked steps.** Every implementation step is
  landed and now audited.
- **DEV-U21 (this step) is open for reconciliation** into the experiment
  plan's replay assumption and into U§12. It carries the 98.5 % figure.
- **DEV-U15/U16/U17/U18/U19/U20 remain open** for reconciliation; U19 changed
  none of them. **DEV-U17 is still an open backtick printer bug**, not this
  plan's to fix, and it is the reason `-DPRINTING` exists.
- **U8 remains `Proposed — open (ABI)`.** The prototype's `op_u<HEX>` scheme
  is a de facto ABI decision made by U09 and replayable verbatim, but not
  thereby right; the MSVC scheme is unexamined by design.
- **`clang/lib/CIR/` is still untouched and uncompiled**, and the lldb arm is
  still compile-unverified. Both are honest caveats for U20's handoff.
- **U§6 still owes a sixth worked example** (`⊖a ⊞ 2 * ⊖b`) and **U§13 still
  owes the fold decision.** Unchanged by U19 — though §4.2 is now the
  strongest available evidence for whichever way U§13 goes.
