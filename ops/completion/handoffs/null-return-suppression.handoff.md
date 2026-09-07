# Handoff — null-return-suppression — The analyzer's null-return suppression, on all four branches

- **Status:** **DONE (gate passed on all four branches).**
- **Branch / commit:**
  - `unicode-operators-experiment` — `1f0790897357` (`~/src/llvm/unicode`) — both arms
  - `unicode-operators-upstream` — `1622a37196c0` (`~/src/llvm/unicode-upstream`) — the `UserOperatorExpr` arm
  - `backtick-trunk` — `c1c6af4dd620` (`~/src/llvm/backtick-trunk`) — the `BacktickInfixExpr` arm
  - `backtick-23` — `ae8a7cf727c3` (`~/src/llvm/backtick`) — cherry-pick of `c1c6af4dd620`, gated independently
  - `unicode-operators` (this repo) — the `docs:` and `ops:` commits below
- **Date / agent:** 2026-09-06.
- **Closes:** [`null-return-suppression`](../../BACKLOG.md#null-return-suppression).

## The parity break was not what the row said it was

**The row's mechanism is wrong, and the wrong part is load-bearing.**
[`null-return-suppression`](../../BACKLOG.md#null-return-suppression) and
[BL03's handoff](../../backlog/handoffs/BL03-analyzer-useroperator.handoff.md)
both name `CallEvent::isCallStmt(E)` in `InlinedFunctionCallHandler`
(`BugReporterVisitors.cpp:2365`) as the gate, on the correct-sounding grounds
that `E` is the wrapper rather than the `CallExpr`. That was the first thing
tried here — peel both wrappers immediately before that test, rebuild, measure.
**Nothing changed.** The handler is never reached.

The real gate is three call frames earlier, and it is a *consequence of BL03's
own six arms*:

```
Tracker::track(const Expr *E, const ExplodedNode *N, TrackingOptions Opts) {
  const Expr *Inner = peelOffOuterExpr(E, N);
  const ExplodedNode *LVNode = findNodeForExpression(N, Inner);
  if (!LVNode)
    return {};                    // <-- the whole chain stops here
  for (ExpressionHandlerPtr &Handler : ExpressionHandlers) ...
```

`findNodeForExpression` walks the exploded graph looking for the node whose
`getStmtForDiagnostics()` **is** `Inner`. A wrapper is not a program-point
statement — *precisely because* `CFGBuilder::Visit` was taught to look through
it — so the lookup returns null and `Tracker::track` gives up before running a
single handler. Measured with a probe compiled into `Tracker::track`:

```
### backtick, p `identity` 0
PROBE track: E=DeclRefExpr       Inner=DeclRefExpr       LVNode=yes
PROBE track: E=BacktickInfixExpr Inner=BacktickInfixExpr LVNode=NULL
### explicit, identity(p, 0)
PROBE track: E=DeclRefExpr       Inner=DeclRefExpr       LVNode=yes
PROBE track: E=CallExpr          Inner=CallExpr          LVNode=yes
PROBE track: E=DeclRefExpr       Inner=DeclRefExpr       LVNode=yes
PROBE track: E=ImplicitCastExpr  Inner=DeclRefExpr       LVNode=yes
PROBE track: E=CXXNullPtrLiteralExpr ...                 LVNode=yes
```

**So the defect is bigger than the row records, in a second direction the row
does not mention.** Losing the tracking chain loses not only
`suppress-null-return-paths` but every note the tracker would have produced.
Measured with `-analyzer-output=text` on the pre-fix `backtick-trunk` binary,
suppression off so both forms report:

| | `p `identity` 0` | `identity(p, 0)` |
|---|---|---|
| path notes | **2** | **8** |

The wrapper's report was missing *"Passing null pointer value via 1st parameter
'p'"*, *"Calling 'identity'"*, *"Returning null pointer (loaded from 'p')"*,
*"Returning from 'identity'"* and *"'p' initialized to a null pointer value"*.
**The operator form was both noisier and less explained than the call it is
sugar for** — a false positive, delivered without the trail that would let a
user dismiss it.

## The fix

One arm per wrapper in `peelOffOuterExpr`
(`clang/lib/StaticAnalyzer/Core/BugReporterVisitors.cpp`), beside the
`FullExpr` and `OpaqueValueExpr` arms already there:

```cpp
  if (const auto *BIE = dyn_cast<BacktickInfixExpr>(Ex))
    return peelOffOuterExpr(BIE->getSubExpr(), N);
  if (const auto *UOE = dyn_cast<UserOperatorExpr>(Ex))
    return peelOffOuterExpr(UOE->getSemanticForm(), N);
```

**Why there and not at the `isCallStmt` test, stated because the next person to
read the row will ask.** Peeled at the top, the operator form and the call
become the **same expression** for everything downstream —
`findNodeForExpression`, every handler, the SVal lookup, the call-site identity
comparison — so every later answer agrees *by construction* rather than by a
separate fix at each site that asks a question. It also recurses, so the
class-typed shape (`CXXBindTemporaryExpr` between wrapper and call) is treated
exactly as the spelled call's is, whatever that turns out to be.

`peelOffOuterExpr` is a file-static in `BugReporterVisitors.cpp` and is used at
one other place (`:2042`, peeling a condition for
`TrackControlDependencyCondBRVisitor`); peeling the wrapper there is right for
the same reason. A default build never sees either node, so the arms are the
identity.

**The other two `isCallStmt` call sites were checked and are not at issue.**
`ExprEngine.cpp:1007` and `ExplodedGraph.cpp:140` both test a statement taken
*from the graph*, which is already the inner call.

## What `bugs_are_still_found` was really asserting

The step file asked for this in writing, so: **it was written to show that the
analyzer still finds real bugs through the wrapper.** That is a good thing to
assert, and it is what
[analysis-layer-sites](../../DEVIATIONS.md#analysis-layer-sites) was found by —
before `ExprEngine::Visit` had a case for the node the path was dropped without
a successor and the *whole enclosing function* went unanalyzed, so nothing at
all came out of it.

**But it made that point at the default configuration, and at the default
configuration the explicit call it claimed parity with reports nothing.** So it
passed *because* the wrapper defeated a suppression the call received. It read
as an assertion of parity and what it pinned was a divergence — and fixing the
divergence broke it. That is the whole reason this was a step and not a quiet
edit inside BL03.

Rewritten, it tests the thing it was always for, on the one setting where the
two forms are supposed to report alike, and the *absence* of the report at the
default setting became a second assertion rather than an unstated assumption.

## What changed

**Production — one file, +16/−0 (experiment; +13/−0 on each single-feature
branch).** `clang/lib/StaticAnalyzer/Core/BugReporterVisitors.cpp`,
`peelOffOuterExpr`. The experiment branch carries both arms under one lead
comment naming both features; the three single-feature branches carry one arm
and a single-feature rewrite of the comment. The `if` lines themselves are
byte-identical across branches (verified by `grep -A1` on each worktree).

**Tests — both Analysis files, restructured the same way.**
`clang/test/Analysis/backtick-infix.cpp` and
`clang/test/Analysis/unicode-operator-analysis.cpp` each gain a `-verify` RUN
line, so the `-verify` half runs **twice**:

| RUN | config | prefixes |
|---|---|---|
| 1 | `suppress-null-return-paths=false` | `-verify=expected,nosupp` |
| 2 | default (suppression **on**) | `-verify=expected` |
| 3 | `debug.DumpCFG` — unchanged | — |

A line carrying a `nosupp-warning` directive and **no** `expected-warning` one
therefore asserts both halves at once: the report is emitted with the
suppression off, and it is *not* emitted with it on. `bugs_are_still_found`
(and the Unicode file's `bugs_are_still_found_infix` / `_prefix` /
`_explicit`) are exactly that shape.

Each file also gains an **operand-dereference** pair: `*p `pick` 0` /
`pick(*p, 0)`, and `*p ⊞ 0` / `⊟ *p` / `operator⊞(*p, 0)`. The null is
dereferenced in an *operand*, so nothing about it came from a return and the
suppression was never meant to reach it — these carry `expected-warning` and
hold a bug-finding assertion live at the default configuration, where the
others are silent. That is the assertion the old test *meant* to make.

**No new test file on any branch**, so no baseline moves.

**This repo.** §17.6 of `docs/backtick-operator-design.md` (new), a third
2026-09-06 `Log.` entry on
[source-fidelity-node](../../../docs/backtick-operator-design.md#source-fidelity-node),
a new Clang bullet in `docs/unicode-operators.md` §8, dated Notes on the two
implementation-cost deviation rows, the backlog row's Correction and
`Closed by`, and a `REPLAY.md` section.

## Verification evidence

### The parity assertion fails before the fix and passes after — demonstrated

Run against the **pre-fix** binaries, using the new test files' own content:

```
$ ~/src/llvm/build-backtick-trunk/bin/clang -cc1 ... -verify=expected \
      clang/test/Analysis/backtick-infix.cpp          # RUN 2, default suppression
error: 'expected-warning' diagnostics seen but not expected:
  Line 51: Dereference of null pointer (loaded from variable 'q')

$ ~/src/llvm/build-unicode-upstream/bin/clang -cc1 ... -verify=expected \
      clang/test/Analysis/unicode-operator-analysis.cpp
error: 'expected-warning' diagnostics seen but not expected:
  Line 96:  Dereference of null pointer (loaded from variable 'q')   # p ⊘ 0
  Line 102: Dereference of null pointer (loaded from variable 'q')   # ⊙ p
```

Line 51 is `bugs_are_still_found`'s deref; 96 and 102 are the infix and prefix
Unicode ones. **The explicit-call line in each file is absent from the list** —
that is the divergence, in the output. RUN 1 (suppression off) passes on the
pre-fix binaries, correctly: it is not what changed. After the fix all RUN
lines pass on all four branches.

### The whole parity, measured in one TU carrying all four spellings

`identity(p, 0)`, `` p `identity` 0 ``, `p ⊘ 0`, `⊙ p`, on the experiment
branch which has both features:

| | pre-fix | post-fix |
|---|---|---|
| default suppression | 3 reports (the three operator forms) | **0 reports** |
| `suppress-null-return-paths=false` | 4 reports | **4 reports** |
| path notes, operator vs call, suppression off | 2 vs 8 | **8 vs 8**, identical |

### `bugs_are_still_found`, rewritten, is still a test

The gate asks for this explicitly. With
`LiveVariables::LookThroughExpr`'s `BacktickInfixExpr` arm reverted and clang
rebuilt:

```
RUN 1: error: diagnostics with 'warning' severity expected but not seen:
  Line 29 'expected-warning': TRUE
  Line 51 'nosupp-warning': Dereference of null pointer
       ... seen but not expected: Line 29: UNKNOWN
RUN 2: error: Line 29 TRUE expected but not seen; UNKNOWN seen
```

`bugs_are_still_found`'s own assertion fails. The arm was restored and the tree
verified byte-identical before committing.

Reverting `CFGBuilder::Visit`'s two arms instead fails the file too, but only
through the `debug.DumpCFG` CHECK — the `-verify` runs still pass. That
reproduces BL03's audit table exactly (its `CFGBuilder::Visit` row is "CFG
symptom, 7 TRUE / 3 null-deref intact") and is recorded so nobody reads a
`DumpCFG`-only failure as a value-modelling failure.

### Gates — all four, unfiltered, `ulimit -c 0`, exit code captured explicitly

| Branch | Discovered | Passed | Failed | XFAIL | Unsupported | Skipped | `EXIT` |
|---|---|---|---|---|---|---|---|
| baseline `unicode-operators-experiment` | 54183 | 48295 | 0 | 27 | 5855 | 6 | — |
| **after** | **54183** | **48295** | **0** | 27 | 5855 | 6 | **0** |
| baseline `unicode-operators-upstream` | 54241 | 48323 | 0 | 27 | 5885 | 6 | — |
| **after** | **54241** | **48323** | **0** | 27 | 5885 | 6 | **0** |
| baseline `backtick-trunk` (post clang-paper-truth) | 54109 | 48223 | 0 | 27 | 5853 | 6 | — |
| **after** | **54109** | **48223** | **0** | 27 | 5853 | 6 | **0** |
| baseline `backtick-23` (post clang-paper-truth) | 54343 | 48501 | 1 | 27 | 5808 | 6 | — |
| **after** | **54343** | **48501** | **1** | 27 | 5808 | 6 | **1** |

**Every row is exactly its baseline.** No branch's numbers move, and that is
the expected result rather than a coincidence: no test file was added or
removed on any branch, only amended. `backtick-23`'s single failure is
[stray-clang-format-config](../../BACKLOG.md#stray-clang-format-config),
expected there and nothing else, so its `EXIT=1` is the baseline too.

### Two environment readings, both confirmed and neither budgeted

1. **`backtick-trunk`'s first build failed outright**, before anything of this
   step's was compiled:

   ```
   error: PCH file '.../obj.clangAST.dir/cmake_pch.hxx.pch' uses an older
          format that is no longer supported
   ```

   The host `llvm-23` package was upgraded on 2026-09-05 (`clang++-23` is now
   23.1.1, symlink dated Sep 5 04:43) and both backtick build dirs still held
   PCHs written by the previous one. **This is
   [clang-paper-truth](clang-paper-truth.handoff.md)'s host-upgrade trap in its
   other form** — there it invalidated the PCH silently and ninja rebuilt all
   4044 targets; here ninja believed the PCH current and the compile failed.
   The fix is `find <build dir> -name cmake_pch.hxx.pch -delete`, then rebuild;
   2981 targets on trunk, 2968 on 23.x. **The two Unicode build dirs did not
   need it** — theirs were regenerated by their own full rebuilds earlier the
   same day.

2. **`backtick-23`'s first gate reported 4 failures and three were the
   machine.** `DirectoryWatcherTest.DeleteWatchedDir`, `ModifyFile` and
   `InitialScanAsync`, each with **`No space left on device :
   inotify_add_watch()`**. Confirmed exactly as the plan requires and **not**
   budgeted, **not** filtered:

   - `fs.inotify.max_user_watches` = **524288**, and **524092 were in use** —
     `523717` of them held by a single process, `cloud-drive-dae`. That is
     [`inotify-watch-budget`](../../BACKLOG.md#inotify-watch-budget) as the
     plan's gate facts describe it: the hoard tracks the tree size, and four
     freshly rebuilt LLVM trees is a lot of new tree.
   - All 8 cases pass on the pristine `~/src/llvm/build-main` binary and 3× on
     `backtick-23`'s own freshly built binary.
   - The re-run on the settled machine gave `Failed: 1` — the expected
     `stray-clang-format-config` alone — and those are the numbers above.

   **This is the third consecutive Clang step to see a `DirectoryWatcherTest`
   failure, and the first where the cause is watch exhaustion rather than a
   timing flake.** The error text is what tells them apart:
   `inotify_add_watch()` failing with `No space left on device` is the budget;
   an assertion timing out with the watcher constructed is the flake
   ([clang-paper-truth](clang-paper-truth.handoff.md) and
   [M2](M2-forward-port.handoff.md) both had the latter). Same response either
   way — confirm against `build-main`, re-run, never filter.

### What was checked, not only changed

- **Formatting.** `git-clang-format --diff` with each branch's **in-tree**
  `clang-format` reports *"clang-format did not modify any files"* on every
  branch. Nothing in `clang/lib/Format/` or `clang/unittests/Format/` was
  touched, so the self-format step at ~81/970 was never in play. (Note: `git
  clang-format` is not on this machine's `PATH` as a git subcommand — invoke
  `python3 clang/tools/clang-format/git-clang-format --binary <build>/bin/clang-format`.)
- **Zero `warning:` lines** in every branch's build log.
- **The fold guard is intact on all four branches**, checked by reading the
  predicate out of each worktree rather than by grepping one name:
  `Level != prec::Backtick` on `backtick-trunk` / `backtick-23`,
  `Level != prec::UserInfix` on the two Unicode branches. Nothing here goes
  near `ParseExpr.cpp`.
- **Link check, repo-wide.** 1740 local Markdown links. Excluding the vendored
  `papers/wg21/` tree (31 pre-existing breaks in upstream's own manual and
  tests), **4 broken, all four pre-existing** — the `<path>` / `…` placeholder
  examples inside handoff prose that
  [clang-paper-truth](clang-paper-truth.handoff.md) already recorded. Every
  link written here resolves. **One caveat for whoever re-runs it:** a checker
  that collapses runs of whitespace when slugifying will report the
  date-headed `docs/open-decisions.md` anchors as broken. GitHub does *not*
  collapse — `### 2026-09-06 — foo` is `#2026-09-06--foo`, two hyphens — and
  the repo's links are right. That is where clang-paper-truth's "8 broken,
  all pre-existing" came from.

## Rows closed, and where each landed

| Row | Destination |
|---|---|
| [null-return-suppression](../../BACKLOG.md#null-return-suppression) | `docs/backtick-operator-design.md` **§17.6**, the whole new subsection; [source-fidelity-node](../../../docs/backtick-operator-design.md#source-fidelity-node)'s **third 2026-09-06 `Log.` entry**; `docs/unicode-operators.md` **§8**, the new *"The static analyzer, which no site list contains"* bullet at the end of the **Clang** list |

The row also gains a **Correction** paragraph before its `Closed by`, because
its stated mechanism is wrong and a future reader following it would repeat the
half-hour this step spent on the `isCallStmt` test. Its **Where** cell now
names `peelOffOuterExpr` instead of `:2365`.

**Two deviation rows get dated Notes and keep their `Status`** — neither is
this step's to close:

- [analysis-layer-sites](../../DEVIATIONS.md#analysis-layer-sites)
  (backtick ledger, still `OPEN`, still
  [reconcile-remainder](../steps/reconcile-remainder.md)'s). Its count is
  **seven, not the five its Recommended-doc-change paragraph says or the six
  it lists**, and the seventh sits *below* the one warned-about site on its own
  scale: nothing forces it at all.
- [expression-node-cost](../../unicode-operators/clang/DEVIATIONS.md#expression-node-cost)
  (Unicode ledger, still `OPEN`, still
  [reconcile-implementation-cost](../steps/reconcile-implementation-cost.md)'s).
  Its "6 link / 8 unreachable / 1 warning / 13 silence" accounting is an axis
  of *dispatch*, and this obligation is off that axis: it is created by
  **meeting another obligation**. Worth saying in the paper, because the
  accounting is one of the paper's headline numbers and this is the one entry
  it structurally cannot see.

## Deviations from the step file

1. **"The fix is a seventh site: peel both wrappers before the `isCallStmt`
   test" is wrong.** It is a seventh site, and it is one line per wrapper, but
   it is in `peelOffOuterExpr` and not in `InlinedFunctionCallHandler`. See the
   first section. The step file inherited this from the row; the row inherited
   it from BL03's diagnosis, which was reasoned rather than measured.
2. **The step file's "Do" step 1 says to fix on the experiment branch first
   because it carries both features — followed, and it paid.** The single TU
   with all four spellings is what showed that the two wrappers fail
   identically, which is the finding §17.6 is built on.
3. **The parity assertion is by *absence*, not by a new positive directive.**
   The step file asks for "parity assertions … the operator form and the
   explicit call must now agree" at the default setting. Agreement there means
   *both silent*, so the assertion is a `-verify` run with no directive to
   match. The operand-dereference cases are the positive half, and they were
   not in the step file.

## Discoveries affecting later steps

- **`peelOffOuterExpr` now peels the wrappers, which changes what the tracker
  points at.** Anything that reads a note's *location* through the tracker gets
  the inner call's range, not the wrapper's — the operator slot, per §17.5.
  This is parity with the spelled call and is deliberate, but if a later step
  adds a test pinning a *note* location under `-analyzer-output=text`, that is
  the column it will see.
- **The `-verify=expected,nosupp` split is a pattern worth reusing.** Any
  future assertion about a *default-on* analyzer suppression wants two RUN
  lines, because a single run at either setting can pass for the wrong reason.
  Both Analysis files now demonstrate it.
- **Diffing the operator form against the spelled call, at more than one
  configuration, has now found three defects across two tracks** that no site
  list contained (F24's `LiveVariables`, BL03's seventh site, and this). It is
  cheap. §17.6's closing paragraph says so for the paper.
- **`~/src/llvm/build-unicode-upstream` needed a 1229-target rebuild** on first
  touch, exactly as [clang-paper-truth](clang-paper-truth.handoff.md) predicted
  for the two Unicode dirs, and `check-clang` then rebuilt ~1049 more for
  `AllClangUnitTests`. Budget it. All four build dirs are current now.

## Forward notes for the NEXT step — [evidence-debt](../steps/evidence-debt.md)

Read after reading its step file.

- **All four Clang build dirs are current and fully built** at the new commits,
  including both Unicode ones, which were stale before today. `AllClangUnitTests`
  is built in all four.
- **`~/src/llvm/build-cir-scratch` was not touched here**, so it is still where
  BL04 left it. Your step's [`lldb-hunk-verification`](../../BACKLOG.md#lldb-hunk-verification) wants `lldb` added to that
  configure — nothing in this step disturbed it.
- Your step adds test files. **The Baselines table is unchanged by this step**,
  so the numbers to do arithmetic against are still
  [clang-paper-truth](clang-paper-truth.handoff.md)'s: `backtick-trunk`
  54109/48223/0, `backtick-23` 54343/48501/1,
  `unicode-operators-experiment` 54183/48295/0,
  `unicode-operators-upstream` 54241/48323/0.
- Your step touches `clang/test/AST/` and `clang/test/CodeCompletion/`, not
  `clang/test/Analysis/`, so nothing here collides. If you *do* add an Analysis
  test, note the two-RUN-line pattern above before writing a single-run one.
- [`template-ast-print-test`](../../BACKLOG.md#template-ast-print-test) lands on the backtick branches, which means a forward-port
  to `unicode-operators-experiment` afterwards — this step touched all four, so
  there is no outstanding forward-port right now and you would be creating a
  new one.

## Open risks / TODOs

- **Nothing is pushed on any branch.** All five (four LLVM + this repo) are
  ahead of every remote, as they were before.
- **The Unicode-branch comment divergence from M2 is still open** and this step
  did not touch it: `unicode-operators-upstream` still carries the stale
  `CheckUserOperatorDeclaration` comment at `SemaDeclCXX.cpp:17209` that
  `de76585ae45d` fixed on the experiment branch. Deliberately out of scope
  here, same as it was for M2.
- **`keyword-escape-printing` is still unruled by the author** — unchanged by
  this step, restated because it now rides on three branches.
- **§17.6 is written into the backtick design doc and cross-referenced from the
  Unicode one, not duplicated.** If the two papers are ever split further apart
  than they are, that paragraph is shared material and
  [reconcile-implementation-cost](../steps/reconcile-implementation-cost.md)
  should decide whether U§8 wants its own full statement rather than a pointer.
