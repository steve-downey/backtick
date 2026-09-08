# Handoff — escape-name-sweep-forward-port — the escape in a qualified type name, carried to the Unicode branch

- **Status:** **DONE (gate passed).**
- **Branch / commits:**
  - `unicode-operators-experiment` (`~/src/llvm/unicode`) — **`5fd79178d2a7`**, the merge commit
  - `unicode-operators-upstream` — **deliberately untouched**, still `8c2a90f56b00`
  - `unicode-operators` (this repo) — the `ops:` commit carrying this file, the
    [`REPLAY.md`](../../unicode-operators/clang/REPLAY.md) section, the Baselines
    note and the Status-log rows
- **Date:** 2026-09-08.
- **Not a plan step.** Like `M1`, `M2`,
  [unicode-branch-maintenance](unicode-branch-maintenance.handoff.md),
  [escape-positions-forward-port](escape-positions-forward-port.handoff.md) and
  the R-prefixed rebases it gets a handoff, a Status-log row in
  [`ops/completion/PLAN.md`](../PLAN.md) and in
  [`ops/unicode-operators/clang/PLAN.md`](../../unicode-operators/clang/PLAN.md),
  and a `REPLAY.md` section. It does not follow `ops/AGENT_PROTOCOL.md`'s step
  loop, adds no feature, and **ticks no checkbox**.

---

## The merge

`git merge --no-ff bd8790f9d0ef` — the explicit commit, not the branch name, as
[M1's handoff](../../unicode-operators/clang/handoffs/M1-forward-port.handoff.md)
insists and the three merges since have repeated. The merge base was exactly
`14f6373ccc7d`, the last merge's target, so the one commit it brought was
exactly the one that had accumulated:

| Commit | What | Why it was deferred |
|---|---|---|
| `bd8790f9d0ef` | [escape-name-sweep](escape-name-sweep.handoff.md) — the escape reaches a qualified type name and a type keyword | landed on the backtick branches alone |

`git merge` reported *"Automatic merge went well"* over the seven files, and
there were **no conflicts**.

## The predicted conflict did not happen, and the prediction rested on one word

The brief predicted a conflict in **`isCXXDeclarationSpecifier`'s switch**,
resolved *keep both, backtick after Unicode*. It did not occur, and the reason
is worth keeping because it is a misreading that this branch's records invite.

[escape-positions-forward-port](escape-positions-forward-port.handoff.md) wrote
that *"`isCXXDeclarationSpecifier`'s `tok::backtick` predicate and the Unicode
arm both in `ParseTentative.cpp`"* were read in the merged tree. That sentence
says the two live in the same **file**. It does not say they live in the same
**function**, and they do not:

| Side | Function | Line |
|---|---|---|
| Unicode | `Parser::TryParseOperatorId` — `case tok::user_operator:` | 831 |
| backtick | `Parser::isCXXDeclarationSpecifier` — the `tok::backtick` arm | 1093 |

**Two hundred and sixty lines and two functions apart.**
`isCXXDeclarationSpecifier` carries **no Unicode arm at all**; the Unicode
feature's only `ParseTentative.cpp` change is the *operator-function-id* arm in
`TryParseOperatorId`, which the escape work never approaches. So *keep both,
backtick after Unicode* had nothing to resolve.

The other shared file, `ParseExprCXX.cpp`, is the same story at smaller scale:
the incoming hunk is in `ParseOptionalCXXScopeSpecifier` at line 396, and this
branch's nearest hunk in that same function is at line 292 — a hundred lines
above, and about a different thing (`ParseUnqualifiedIdOperator` and friends
account for the rest).

**The generalization that has now held twice**: the two features share
`tok::user_operator`/`tok::backtick`'s precedence level, `ParseExpr.cpp` and
clang-format — the three constructs [`REPLAY.md`](../../unicode-operators/clang/REPLAY.md)
§1 names as the entire coupling — and nothing else. The escape's work is in
name *parsing* and name *printing*; the Unicode feature's is in
*operator-function-id* parsing and `DeclarationName`. A prediction of a
conflict should be checked with `git diff --numstat <old-tip> <old-head> --
<file>` **before** it is written down, which costs one command.

## An auto-merge is not evidence, so it was measured four ways

M1's lesson, and the last merge's discipline. Every check has to agree:

- **The merge delta is exactly the incoming commit.** `git diff --shortstat
  e09b559d631c 5fd79178d2a7` → **7 files, +268/−14**, and `git diff
  --shortstat 14f6373ccc7d bd8790f9d0ef` → **7 files, +268/−14**. Identical.
  Git applied the commit whole and added nothing.
- **None of the 14 deleted lines is Unicode text.** `git diff e09b559d631c
  5fd79178d2a7 | grep '^-[^-]' | grep -Ec 'user_operator|UserOperator|UserInfix|unicode|⊞'`
  → **0**.
- **The feature diff against the new backtick tip did not move.**
  `git diff --shortstat bd8790f9d0ef..5fd79178d2a7` → **121 files, +7701/−57**,
  and **221 hunks at `-U0`** — identical to the last two merges' reading. The
  backtick side advanced by a commit and the Unicode side is unchanged to the
  line.
- **Five of the seven merged files are byte-identical to `backtick-trunk`.**
  `git diff bd8790f9d0ef HEAD -- <file>` is empty for `Parser.h`,
  `ParseDecl.cpp`, `Parser.cpp` and both test files. The two that differ,
  `ParseExprCXX.cpp` and `ParseTentative.cpp`, are exactly the two carrying
  Unicode arms, and every changed line in them is Unicode work
  (`NoteIdentifierProfileExclusion`, the U05 and U16 comments, the
  `TryParseOperatorId` arm, and brace rebalancing around them).

### One correction, so the next merge does not chase it

**The recorded "221 hunks" is a `-U0` count, and the handoff prose does not say
so.** [escape-positions-forward-port](escape-positions-forward-port.handoff.md)
writes *"221 hunks"* in running text; at git's default `-U3` the same diff
reads **207**. Both readings are stable and both reproduce on the previous
merge's own commits, so nothing moved — but ten minutes went into establishing
that. `REPLAY.md` has the command right (`git diff -U0 … | grep -c '^@@'`); the
handoff prose is where the unit went missing. The full ladder, measured on
`14f6373ccc7d..e09b559d631c`: **U0 221, U1 213, U2 208, U3 207, U5 204.**
**Quote the flag with the number.**

## The contamination scan finds nothing new

[`REPLAY.md`](../../unicode-operators/clang/REPLAY.md) §1's `awk` recipe over
`bd8790f9d0ef..5fd79178d2a7` hits the **same** six production files it always
has — `OperatorPrecedence.h`, `OperatorPrecedence.cpp`, `ParseExpr.cpp`,
`Format/Format.cpp`, `Format/FormatToken.h`, `Format/TokenAnnotator.cpp` —
plus `SemaOverload.cpp`'s doc-comment cross-reference,
`BugReporterVisitors.cpp`, the four comment-only entries (`Options.td`,
`test/Lexer/backtick-c-mode.c`, `CIRGenExprScalar.cpp`, `Analysis/CFG.cpp`)
and the test files. **No new production file.**

## The fold guard survived, and it was proven a fourth time

`Parser::isFoldOperator` still reads

```cpp
  return Level > prec::Unknown && Level != prec::Conditional &&
         Level != prec::Spaceship && Level != prec::UserInfix;
```

— `prec::UserInfix`, this pair of branches' spelling, **not** the
`prec::Backtick` the backtick branches use. That matters here more than usual:
the incoming commit rewrites five parser arms and the escape's annotation
machinery, and `ParseExpr.cpp` is one of the three files where the two features
genuinely touch.

**Verified by deleting the clause and rebuilding**, per the standing warning at
the top of [`REPLAY.md`](../../unicode-operators/clang/REPLAY.md): it fails
silently. Without it, `clang/test/Parser/unicode-operator-precedence.cpp` fails
**on line 322 only** — the right fold `(N ⊞ ...)`, line 322 being
`template <int... N> constexpr int rfold() { return (N ⊞ ...); }`:

```
error: 'err-error' diagnostics expected but not seen:
  Line 322 (directive at :323): expected expression
error: 'err-error' diagnostics seen but not expected:
  Line 322: expected ')'
  Line 322: expression contains unexpanded parameter pack 'N'
error: 'err-note' diagnostics seen but not expected:
  Line 322: to match this '('
4 errors generated.
```

**Four stanzas, exactly as the last handoff corrected it to be** — the
`err-note` line included, and `4 errors generated.` as the tail. The left fold
on line 320 errors for an unrelated reason and does not pin the guard; only the
right fold does, which is now the fourth independent confirmation of that.
The clause was restored with `git checkout --`, `clang` rebuilt (`EXIT=0`), the
file passes, and `git status` is clean at `5fd79178d2a7`.

## The probes, which are in the repo now and were the cheap check

[`ops/probes/`](../../probes/) landed with
[escape-name-sweep](escape-name-sweep.handoff.md) itself, so this is the first
forward-port that could run them instead of rewriting them. All three were run
with `CLANG=~/src/llvm/build-unicode/bin/clang++`; GCC's readings come from the
untouched `gcc-backtick-build` and are a control.

| Probe | Result on this branch |
|---|---|
| `escape-positions.sh` | **79/79 clang, 79/79 gcc** — A 23/23, B 16/16, C **25/25**, D 15/15 |
| `escape-errors.sh` | **`EXIT=0`** — 23 programs × 2 compilers, all **diagnose and stop**, nothing hung, nothing accepted |
| `flag-off-parity.sh` | **`EXIT=0`** — every cell IDENTICAL (details below) |

**Category C is the whole point of the merge and it reads 25/25.** Before
`escape-name-sweep`, Clang took **13** of those 25 — that is the divergence
[escape-positions-forward-port](escape-positions-forward-port.handoff.md)
opened as [`escape-in-qualified-type-name`](../../DEVIATIONS.md#escape-in-qualified-type-name)
and this commit closes. The reading here is byte-for-byte
`escape-name-sweep`'s "after" column on `backtick-trunk`, which is the control
that matters: **the backtick feature behaves on this branch exactly as on the
branch it was gated on.**

`escape-errors.sh` is the one worth singling out. `undeclared-qual-type` — the
program that **hung Clang indefinitely** before the fourth arm's correction, and
which a `-verify` test would never have caught because a test that does not
terminate does not fail — diagnoses here with *a type specifier is required for
all declarations*, under `timeout`. The loop fix came across intact.

## Flag-off parity, measured byte-identically

`ops/probes/flag-off-parity.sh`, two programs containing **no backtick** — one
well-formed, one ill-formed — over every construct whose lookahead or lookup the
escape work moved:

```
                              flag on vs flag off      flag off vs pristine
clang  -fsyntax-only ok        IDENTICAL (0 lines)      IDENTICAL
clang  -fsyntax-only bad       IDENTICAL (50 lines)     IDENTICAL
clang  -ast-print              IDENTICAL (85 lines)     IDENTICAL
clang  -ast-dump               IDENTICAL (331 lines)    IDENTICAL
cc1plus -fsyntax-only ok       IDENTICAL (0 lines)      IDENTICAL
cc1plus -fsyntax-only bad      IDENTICAL (60 lines)     IDENTICAL
cc1plus generated assembly     IDENTICAL (282 lines)    differs in 2 lines
```

Every cell matches [escape-name-sweep](escape-name-sweep.handoff.md)'s reading
on `backtick-trunk` exactly. The two assembly lines are the `.ident` build-date
string and nothing else, already measured there. `-ast-dump` is compared with
`0x[0-9a-f]+` normalized; that is allocation addresses.

`~/src/llvm/build-main` is this branch's **exact** upstream base —
`git merge-base HEAD main` == `main` == `a815e6f267c1` — which is what makes the
third column a control rather than a coincidence.

## Both features work

**27 targeted lit tests, 26 passed, 1 unsupported, 0.48 s.** The nine Unicode
files (`Parser/unicode-operator-{precedence,infix,prefix,decl}.cpp`,
`AST/unicode-operator-print.cpp`,
`SemaCXX/unicode-operator-{semantics,adl,call,decl}.cpp`,
`Analysis/unicode-operator-analysis.cpp`,
`CodeCompletion/unicode-operator-priority.cpp`) and every backtick file,
including both that this merge extended
(`Parser/backtick-escape-positions.cpp`, `Parser/backtick-escape-diagnostics.cpp`).
The one unsupported is `CIR/CodeGen/backtick-infix.cpp`, which needs a CIR-enabled
build and is unsupported on this build configuration, not a regression.

## Gate — GREEN, unfiltered, `EXIT=0`

```
ninja -C ~/src/llvm/build-unicode check-clang > gate.log 2>&1 ; echo "GATE_EXIT=$?"

GATE_EXIT=0
Testing Time: 213.49s

Total Discovered Tests: 54190
  Skipped          :     6 (0.01%)
  Unsupported      :  5855 (10.80%)
  Passed           : 48302 (89.13%)
  Expectedly Failed:    27 (0.05%)
  Failed           :     0
```

### It took four runs, and the three that failed are the machine

**`inotify-watch-budget` is back at its worst recorded level and cost three gate
runs.** `cloud-drive-dae` was measured holding **523,732 of 524,288** watches —
556 free for the whole machine — essentially identical to the 523,730
[unicode-branch-maintenance](unicode-branch-maintenance.handoff.md) recorded.
The three failed runs, in order:

| Run | Failed | Which |
|---|---|---|
| 1 | 4 | `DeleteFile`, `InitialScanAsync`, `InitialScanSync`, `InvalidatedWatcher` |
| 2 | 2 | `AddFiles`, `ModifyFile` |
| 3 | 2 | `InitialScanSync`, `InvalidatedWatcher` |
| 4 | **0** | — |

**Confirmed environmental three separate ways, and not filtered or budgeted at
any point:**

- **By signature.** Every failure is
  `No space left on device : inotify_add_watch()`, which is the kernel refusing
  a watch because the per-user limit is reached. That is exhaustion by
  definition, not the bare timeout that would be a flake.
- **By control.** The pristine `~/src/llvm/build-main` binary, run standalone
  with `--gtest_filter='DirectoryWatcherTest.*'` at hoard 524,095, **failed all
  eight** — a binary containing none of this work, on the same machine, at the
  same moment. Minutes later at 524,090 the same binary passed 8/8. The suite
  sits exactly on the knife edge: eight watches are available to a serial run
  and not to a 20-worker gate.
- **By variance.** Three runs, three *different* failing subsets. A real defect
  fails the same test every time.

**Across all four runs, the number of non-`DirectoryWatcherTest` failures is
zero.** Discovered was 54190 in every run — the baseline — so nothing was
skipped or lost; only the count in *passed* moved, by exactly the number of
watch failures.

The fourth run is the record, and it is a clean unfiltered pass, not a rerun of
a subset.

**Exactly the Baselines row, delta 0**, which is what
[escape-name-sweep](escape-name-sweep.handoff.md) predicted and why: its
thirty-odd new cases went into `Parser/backtick-escape-positions.cpp` and
`Parser/backtick-escape-diagnostics.cpp`, both of which this branch already had,
and **lit discovers files, not cases**. A merge that changes five parser arms
and moves no number is the expected reading, not a suspicious one.

Measured with `ulimit -c 0`, output redirected and the exit code captured
explicitly — `ninja … | tail` reports `tail`'s status.

Builds: the merge build `EXIT=0`, **34 targets**, **zero `warning:` lines**; the
two fold-guard builds `EXIT=0` likewise. The small target count is correct — the
merge touches `Parser.h` and four `lib/Parse` files, and nothing downstream of
them rebuilds beyond `clang` itself.

## Formatting — clean, for the first time in four merges

`git-clang-format --diff --commit e09b559d631c` with the **in-tree**
`clang-format` reports **"clang-format did not modify any files"**. The three
previous merges each carried one inherited region; this one carries none,
because the inherited hit
(`dyn_cast<CXXParenListInitExpr>` in `BacktickInfixExpr::getOperand`) is in
`clang/lib/AST/Expr.cpp`, which this merge does not touch, so it is outside the
diff being checked. **It has not been fixed and is still there on the branch**;
it is simply not this merge's to report.

`check-clang`'s self-format glob was re-read out of
`clang/lib/Format/CMakeLists.txt` rather than quoted — `clang/lib/Format/**`,
`include/clang/Format/*.h`, `tools/clang-format/*.cpp`,
`unittests/Format/*.{cpp,h}` — and **this merge touches no file in it**, so the
abort at ~81/970 was never in play.

## Discoveries affecting later work

- **`backtick-trunk` and `unicode-operators-experiment` have no outstanding
  forward-port.** Everything on the backtick branches is landed here. The next
  one is created only by a backtick-track change that lands on the backtick
  branches alone.
- **`unicode-operators-upstream` must still never receive the merge.**
  Unchanged from M1, M2, unicode-branch-maintenance and
  escape-positions-forward-port, and restated because it is the whole hazard:
  that branch is `upstream/main` plus Unicode only.
- **The four tooling anchors are untouched.** The merge's seven files are
  `Parser.h`, `ParseDecl.cpp`, `ParseExprCXX.cpp`, `ParseTentative.cpp`,
  `Parser.cpp` and two `clang/test/Parser/` files — none of
  `ASTMatchers.h`, `ASTMatchersInternal.cpp`, `CXCursor.cpp` or
  `ASTMatchFinder.cpp`, so
  [unicode-branch-maintenance](unicode-branch-maintenance.handoff.md)'s
  *copy the arm, never the region* hazard was not in play. The warning stands
  for the next merge that does reach them.
- **`isCXXDeclarationSpecifier` carries no Unicode arm**, recorded above, so a
  future backtick change there merges clean. The Unicode arm in
  `ParseTentative.cpp` is `TryParseOperatorId`'s, and that is the only one.
- **Check a predicted conflict before recording it.** Two merges running, the
  prediction has been wrong, and both times one command would have settled it:
  `git diff --numstat <backtick-tip-at-last-merge> <unicode-head> -- <file>`
  says whether this branch has touched the file at all. It is cheaper than the
  paragraph explaining the prediction afterwards.
- **Quote the `-U` flag with a hunk count**, above. 221 is `-U0`; 207 is the
  default.
- **`ops/probes/` is the right shape and paid off immediately.** The three
  scripts reproduced `escape-name-sweep`'s entire evidence table on a different
  branch's binary in under a minute, which is what turned "the merge probably
  carried the fix" into a measurement. Run them with `bash`, not `zsh`.
- **Nothing is pushed.** `unicode-operators-experiment` is ahead of every remote
  by this merge and this repo by this commit. All four branches track
  `ceridwen`, **not** `origin`, and both remotes were in sync at the last push,
  so a push needs both. Pushing is the maintainer's call.

## Open risks / TODOs

- **[`escape-type-name-spelling`](../../gcc/DEVIATIONS.md#escape-type-name-spelling)
  is open, measured and unowned**, opened by
  [escape-name-sweep](escape-name-sweep.handoff.md). It is a **diagnostic**
  divergence, not an acceptance one, and it is GCC's; it was deliberately out of
  scope here and is untouched.
- **Section 9's comment in `unicode-operator-precedence.cpp` is still stale.**
  Line 314 calls the fold behaviour *"pinned here, not endorsed -- U§13 lists it
  as open"*, but [fold-over-user-infix](../../../docs/open-decisions.md#fold-over-user-infix)
  was answered on 2026-09-06. M2, unicode-branch-maintenance and
  escape-positions-forward-port each recorded it and each left it; so does this.
  It is a comment on all four branches and costs four gates, which is exactly
  why nobody has done it — it wants a step of its own that fixes all four at
  once.
- **The inherited `ASTMatchersNodeTest.cpp` formatting region** and the
  `BacktickInfixExpr::getOperand` one are still there, and still
  `backtick-trunk`'s to fix if anyone wants them fixed. Fixing either on one
  branch alone would create drift.
- **[`inotify-watch-budget`](../../BACKLOG.md#inotify-watch-budget) cost three
  gate runs**, and is at its worst recorded level. See the section above; the
  root fix needs root and is the maintainer's.
