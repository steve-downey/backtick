# null-return-suppression — The analyzer's null-return suppression, on all four branches

**Goal.** Both wrapper nodes defeat the static analyzer's null-return
suppression, so the operator form reports false positives the identically
desugaring explicit call is spared. BL03 found it, measured it, and
deliberately did not fix it, because fixing it **changes the premise of a test
F24 wrote**.

**Depends on:** nothing. Independent of every other step.
**Closes:** [`null-return-suppression`](../../BACKLOG.md#null-return-suppression).
**Refs:** `ops/backlog/handoffs/BL03-analyzer-useroperator.handoff.md`;
`clang/lib/StaticAnalyzer/Core/BugReporterVisitors.cpp:2365`;
`clang/test/Analysis/backtick-infix.cpp`;
`clang/test/Analysis/unicode-operator-analysis.cpp`.

## What is known

`suppress-null-return-paths` (default **on**) suppresses a null-dereference
report whose null came from an inlined callee's return. The suppression is
gated on `CallEvent::isCallStmt(E)` in `BugReporterVisitors.cpp`'s handler,
and `E` is the *tracked expression*. For `` p `identity` 0 `` or `p ⊘ 0` that
is the **wrapper**, not the `CallExpr`, so the handler bails and the report is
emitted.

Measured post-BL03 in one TU: the operator form reports, the explicit call
does not; with `suppress-null-return-paths=false` both report. **This is a
parity break in the noisy direction.** It is *not* a BL03 regression — it is
inherited from F24 and is present on `backtick-trunk` and `backtick-23` too.

The fix is a **seventh site**: peel both wrappers before the `isCallStmt`
test, the same way BL03's six arms peel them everywhere else.

## The trap, stated plainly

**`clang/test/Analysis/backtick-infix.cpp`'s `bugs_are_still_found` passes
only because the suppression misses the wrapper.** Fix the suppression and
that assertion's premise is gone. This is why the row says it wants its own
step and why it was not folded into BL03.

So this step owes two things a normal fix does not:

1. **Decide what `bugs_are_still_found` was actually for**, then rewrite it to
   test that thing. It was written to show the analyzer still finds real bugs
   through the wrapper — which is a good thing to test and does not require
   the suppression to be broken. Set `suppress-null-return-paths=false`
   explicitly, as BL03's own test does deliberately, or choose a bug shape the
   suppression was never meant to catch.
2. **Say in the handoff what the old test was really asserting**, because a
   future reader will find a test whose premise changed and needs to know it
   was changed on purpose.

## Do

1. Fix on `unicode-operators-experiment` first — it carries **both** features,
   so one build shows both halves of the parity, exactly as BL04 used it.
2. Rewrite `backtick-infix.cpp`'s `bugs_are_still_found`.
3. Add parity assertions to both Analysis tests: with the suppression at its
   **default**, the operator form and the explicit call must now agree.
4. Propagate: the `UserOperatorExpr` half to `unicode-operators-upstream`, the
   `BacktickInfixExpr` half to `backtick-trunk` and `backtick-23`. Follow
   BL04's method — produce each single-node variant in the experiment tree,
   rebuild, confirm it passes its own test, and diff the added lines against
   the target worktree before committing.
5. Append a `REPLAY.md` row for the Unicode half.

## Verify (gate)

- `check-clang` green on all four branches against the plan's baselines.
- The parity assertion **fails before the fix and passes after**, at the
  default suppression setting. Demonstrate it.
- `bugs_are_still_found`, rewritten, still fails if you break the analyzer —
  a test that passes for a new reason is not automatically still a test.
