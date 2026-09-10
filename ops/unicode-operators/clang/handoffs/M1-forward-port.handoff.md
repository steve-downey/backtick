# Handoff — M1 forward-port the backtick defect fixes

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `760a11f0b444` (merge commit).
  `unicode-operators-upstream` **deliberately untouched by M1**, still at `44299aae010d`.
- **Date / agent:** 2026-08-09
- **Not a plan step.** Like the R-prefixed rebases, this gets a Status-log row
  and a handoff; it does not follow `ops/AGENT_PROTOCOL.md`'s step loop and
  adds no feature.

## What changed

One merge commit, no hand edits:

```
git merge --no-ff 169e45c7916f
```

bringing `439ceb5237dc` (F23: `BacktickInfixExpr::Inner` is not always a
`CallExpr`) and `169e45c7916f` (F24: teach the static analyzer about
`BacktickInfixExpr`) onto the experiment branch. 9 files, +181/−5:
`AST/Expr.h`, `AST/Expr.cpp`, `AST/StmtPrinter.cpp`, `Analysis/CFG.cpp`,
`Analysis/LiveVariables.cpp`, `StaticAnalyzer/Core/Environment.cpp`,
`StaticAnalyzer/Core/ExprEngine.cpp`, and two tests
(`test/Analysis/backtick-infix.cpp` new, `test/Parser/backtick-ast-print.cpp`
extended).

## Deviation: the merge source is a commit, not the branch tip

The step file says `git merge --no-ff backtick-trunk`. **That is no longer the
right command.** `backtick-trunk` has advanced past F23/F24 — it now carries
`5a2b586463d9` (BL02, D16 type-name in the operator slot). Merging the tip
would have swallowed BL02, which is **M2's** job, and would have broken M1's
own gate arithmetic ("the backtick fixes' new tests, and nothing else").

So M1 merged the *commit* `169e45c7916f` — which was `backtick-trunk`'s tip
when the step was written. `git log bd6f4d5fa102..169e45c7916f` is exactly the
two fix commits, confirmed before merging.

**M2 inherits a smaller job than its description implies:** it now merges
`backtick-trunk` proper (or `5a2b586463d9` + whatever BL06 adds), and the
merge base is `169e45c7916f`, already an ancestor of the experiment branch.

## The expected conflicts did not happen

The step predicted conflicts in `ExprEngine.cpp` (U16 added
`UserOperatorExprClass` to the same switch) and `StmtPrinter.cpp` (both nodes
print nearby). **Git auto-merged all nine files with no conflict** — the two
nodes' arms are far enough apart in both files that the three-way merge never
saw overlapping hunks.

That makes the step's warning *more* important, not less: an auto-merge is not
evidence that both cases survived. Verified explicitly rather than assumed:

| File | `BacktickInfixExpr` | `UserOperatorExpr` |
|---|---|---|
| `ExprEngine.cpp` | `:1879` (`Dst.insert(Pred)` group) | `:1924` (`CXXRewrittenBinaryOperator` group) |
| `Environment.cpp` | `:56` | — (absent; BL03's job) |
| `CFG.cpp` | `:1652`, `:2382`, `:5208` | — (absent; BL03's job) |
| `LiveVariables.cpp` | `:185` | — (absent; BL03's job) |
| `StmtPrinter.cpp` | `:1632` | `:2233` |

`CFG.cpp` did need checking (the step said to) and the backtick fix does touch
it — three sites, all present.

## Verification evidence

**Build warning-free — the step's acceptance signal, and it is met.**

```
ninja -C ~/src/llvm/build-unicode clang   → EXIT=0, 749 edges, ZERO warning: lines
```

Every step from U08 onward reported "two pre-existing backtick `-Wswitch`
gaps" (`StaticAnalyzer/Core/ExprEngine.cpp`, `tools/libclang/CXCursor.cpp`).
Grepped the log rather than trusting the exit code — `LLVM_ENABLE_WERROR` is
OFF. Both are gone.

**`check-clang` on `build-unicode` — GREEN, unfiltered, `EXIT=0`:**

```
Total Discovered Tests: 54181
  Passed: 48295   Failed: 0   XFAIL: 27   Unsupported: 5853   Skipped: 6
```

(This gate ran after BL03's commit as well; the M1-only figures are not
separately measured. See the BL03 handoff for the arithmetic — the two steps
contribute +1 discovered test each.)

Arithmetic against U18's unfiltered 54179 / 48285 / **8 failed**:
discovered **+2** (`test/Analysis/backtick-infix.cpp` from M1,
`test/Analysis/unicode-operator-analysis.cpp` from BL03; `backtick-ast-print.cpp`
gained cases but is an existing file, and lit counts files);
passed **+10** = those two **+8**, the `DirectoryWatcherTest.*` cases that now
pass because B31's root fix raised `fs.inotify.max_user_watches` to 524288.
Failed **8 → 0**. No existing test changed behaviour.

**The feature diff is unchanged — the property the merge was bought for:**

```
git diff --stat 169e45c7916f..760a11f0b444   → 110 files changed, 7341 insertions(+), 29 deletions(-)
git diff -U0  169e45c7916f..760a11f0b444 | grep -c '^@@'   → 204
```

**110 files / 204 hunks / +7341/−29 — U19's audit figures to the character.**
U19's classification and U20's replay stay valid as written; no ledger row
needs revisiting.

**`unicode-operators-upstream` untouched:** still `44299aae010d`, and
`git diff upstream/main..unicode-operators-upstream | grep -i backtick`
returns nothing.

## `UserOperatorExpr` has no analogue of the F23 crash — confirmed

Step item 5. Ran the class-typed-result repro against user operators in all
three forms — infix, prefix, member — plus a lifetime-extended one, on **both**
Unicode branches, under `-ast-print` and under `debug.DumpCFG` (the other
caller that hit F23's assertion):

```cpp
struct S { int v; ~S(); };
S operator⊞(int, int);  S operator⊟(int);  struct M { S operator⊠(int); };
void h() { (void)(1 ⊞ 2); (void)(⊟ 2); M m; (void)(m ⊠ 2);
           const S &r = 1 ⊞ 2; (void)r; }
```

No crash, no assertion, correct round-trip on `build-unicode` and
`build-unicode-upstream` alike. **U15 §11a's assertion holds**, and the reason
is mechanical rather than lucky: `UserOperatorExpr::getOperand`
(`ExprCXX.cpp:135-155`) already reaches its operands through
`getSemanticForm()->IgnoreImplicit()` and `dyn_cast`s — never `cast`s — the
`CXXMemberCallExpr` / `CallExpr`, returning null on an unexpected shape. That
is precisely the technique F23 had to *adopt* for `getCallExpr()`. The two
tracks hit the same problem from opposite directions and the Unicode side
happened to be written correctly first.

**No new defect, so nothing to fix on `unicode-operators-upstream`.**

## Discoveries affecting later work

- **`backtick-trunk` is a moving target for M2.** Check its tip and merge an
  explicit commit, not the branch name, unless you have confirmed the tip is
  exactly what you want.
- **The two `-Wswitch` gaps are closed**, so "the pre-existing backtick
  `-Wswitch` warnings" is no longer a valid excuse for a non-empty warning
  grep on this branch. A warning now means *your* change.
- **`clang/test/Analysis/` exists on this branch now** — `backtick-infix.cpp`
  is the first file in it, and BL03 added the second.

## Forward notes for BL03 (written after reading its step file)

Superseded — BL03 ran immediately after M1 in the same session. See
`ops/backlog/handoffs/BL03-analyzer-useroperator.handoff.md`. The one thing M1
promised it and delivered: the `BacktickInfixExpr` arms are now in-tree at
`CFG.cpp:1652/2382/5208`, `LiveVariables.cpp:185`, `Environment.cpp:56`,
`ExprEngine.cpp:1879`, immediately beside where the `UserOperatorExpr` arms
go. It did make the work strictly easier, exactly as the step predicted.

## Open risks / TODOs

- Nothing is pushed; the branch is ahead of every remote.
- **M2 is still outstanding** and now means "merge BL02 (+ BL06 when green)".
  Same hazard, restated because it is the whole point of this step: the merge
  goes to `unicode-operators-experiment` **only**. `unicode-operators-upstream`
  is branched from pristine `upstream/main`, carries no backtick code, and
  U20's headline result is that `git diff upstream/main..HEAD | grep -i
  backtick` returns nothing. Merging `backtick-trunk` into it would drag all
  45+ backtick commits onto the branch and destroy that result.
- `backtick-23` has no Unicode descendant, so its fixes need no forward-port.
  Unchanged from the step file; restated because "both branches" is the
  natural but wrong reading in both directions.
