# M1 — Forward-port the backtick defect fixes (maintenance, not a plan step)

**Goal.** Carry the two backtick defect fixes onto the Unicode work as a
**merge commit**, so the Unicode experiment branch stops shipping a known
crash — without rebasing, and without contaminating the clean replay
branch.

**Depends on:** the fixes being green on `backtick-trunk` and `backtick-23`
(`ops/handoffs/15-defect-fixes.handoff.md`).
**Not a plan step.** Like the R-prefixed rebases, this gets a Status-log
row and a handoff; it does not follow the step loop and adds no feature.

## Why merge and not rebase
Twenty-two handoffs record gate numbers measured at specific commits, and
`REPLAY.md` classifies 204 hunks against `backtick-trunk..unicode-operators-experiment`.
A rebase rewrites those commits and invalidates both. A merge leaves every
historical commit byte-identical, and — because `backtick-trunk` is a true
ancestor of `unicode-operators-experiment` — **the feature diff against the
new `backtick-trunk` tip is unchanged**, so U19's audit and U20's replay
stay valid as written. That is the property being bought.

## The hazard, and the decision
**`unicode-operators-upstream` must NOT receive this merge.** It is branched
from pristine `upstream/main` and contains no backtick code at all; U20's
result is precisely that `git diff upstream/main..HEAD | grep -i backtick`
returns nothing. Merging `backtick-trunk` into it would drag the entire
45-commit backtick diff onto the branch and destroy the plan's headline
result. It also needs no fix: both defects are in `BacktickInfixExpr`,
which does not exist there.

So this is a **one-branch** forward-port, not two. Say so in the handoff,
because "both branches" is the natural reading of the request and the
asymmetry is the whole point.

`backtick-23` has no Unicode descendant, so its fixes need no forward-port.

## Do
1. Confirm the fixes are green on `backtick-trunk` and note its new tip.
2. In `/home/sdowney/src/llvm/unicode` on `unicode-operators-experiment`:
   ```bash
   git merge --no-ff backtick-trunk        # a real merge commit, always
   ```
   Message: `[unicode] merge backtick-trunk: pick up the -ast-print crash
   and ExprEngine fixes`. No `Co-Authored-By` trailer.
3. **Expect conflicts, in two known places.** `ExprEngine.cpp`: U16 added
   the `UserOperatorExprClass` case to the same switch the backtick fix
   adds `BacktickInfixExprClass` to. `StmtPrinter.cpp`: both nodes print
   nearby. Resolve so **both** cases are present — a resolution that drops
   either one silently reintroduces a fixed defect. Check `CFG.cpp` too if
   the backtick fix touched it.
4. Re-verify the acceptance signal: the build must now be **warning-free**.
   Every step from U08 onward reported "two pre-existing backtick `-Wswitch`
   gaps"; after this merge there should be none. Grep the build log — do
   not trust the exit code, `LLVM_ENABLE_WERROR` is OFF.
5. Check whether `UserOperatorExpr` has an analogue of the crash. U15's
   §11a asserted it does not ("a node that is the operator survives Sema
   re-wrapping its result; a node that hides a call does not"), but the fix
   may have found other readers of `BacktickInfixExpr::Inner` that assume
   `CallExpr`. Run the class-typed-result repro shape against a user
   operator on **both** Unicode branches. **If it crashes, that is a new
   defect** — it needs its own fix on the experiment branch *and* on
   `unicode-operators-upstream`, and it is not part of this merge.

## Verify (gate)
- `check-clang` on `/home/sdowney/src/llvm/build-unicode`, green by the
  usual rule (zero failures; the `DirectoryWatcherTest` inotify eight come
  and go — filter and re-run per PLAN.md).
- New count should be the post-U18 baseline (54171 discovered / 48285
  passed / 0 failed, filtered) **plus** the backtick fixes' new tests, and
  nothing else. Any other delta is a merge resolution error.
- Zero build warnings.
- `git diff backtick-trunk..unicode-operators-experiment --stat` still
  matches U19's 110 files / 204 hunks. If it does not, the merge resolved
  something it should not have.
- `unicode-operators-upstream` unchanged at `44299aae010d`, and
  `git diff upstream/main..unicode-operators-upstream | grep -i backtick`
  still returns nothing.

## Done when
The experiment branch carries the fixes via a merge commit, gates green,
builds warning-free, and its feature diff is unchanged.

## Capture in handoff
The merge commit, the conflicts and how each was resolved, the new gate
numbers as the branch's current baseline (noting that the per-step numbers
in U00–U21's handoffs remain valid at their own commits), the
`UserOperatorExpr` crash-analogue result, and an explicit statement that
`unicode-operators-upstream` was deliberately not merged and why.

## Bookkeeping
Status-log row prefixed `M1` in `ops/unicode-operators/clang/PLAN.md`,
handoff at `ops/unicode-operators/clang/handoffs/M1-forward-port.handoff.md`,
`ops:` commit in the plan repo. Add a `REPLAY.md` note that the merge
brings backtick-track commits which are never replayed and do not change
any existing row.
