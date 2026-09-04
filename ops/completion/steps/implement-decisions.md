# implement-decisions — Implement what decision-brief decided

**Goal.** Turn decision-brief's answers into code. Scope is **contingent on the author's
decisions** and cannot be written in advance; what can be written in advance
is the shape of the work and the traps in it.

**Depends on:** decision-brief, answered. If decision-brief is BLOCKED awaiting the author, so is
this — do not guess a decision in order to have something to build.
**Closes:** whichever of `DEV-U15`, `DEV-U06`, U§13-folds and `DEV-U23` were
decided in the direction of a change. Rows decided in the direction of "keep
and document" are **not** this step's; they go to reconcile-declaring-using.

## Read first

`docs/open-decisions.md`, the version with the author's answers recorded and
dated. If it has no answers, stop.

## The four, and what each would cost if decided toward a change

- **`DEV-U15` (prefix use finds a two-parameter operator through its default
  argument).** "Reinstate [over.oper]p8" is a Sema change in the
  declaration-checking path — `CheckUserOperatorDeclaration`, U08's sibling of
  `CheckOverloadedOperatorDeclaration`. **Interacts with `DEV-U06`(b)**; if
  both were decided, implement them together or the second will undo the
  first's tests.
- **`DEV-U06` (static member user operators).** Currently rejected. Accepting
  them touches declaration checking and candidate assembly, and — from
  `DEV-U13`'s three-for-three pattern — expect a *sibling* of the existing
  rule rather than a widening of it.
- **U§13 folds.** A parser change over the user-infix level, and the decision
  was to be made **once for both features**, so a change lands on the backtick
  branches *and* the Unicode ones. Four branches. Budget accordingly.
- **`DEV-U23` postfix.** `U21` priced this as a feasibility probe and the
  price was the reason for deferral. If the author reversed that, this is not
  one step — come back and add a phase to the plan rather than trying to fit
  it here.

## Do

1. Scope the step from `docs/open-decisions.md` and **write the scope into the
   handoff before starting**, so a reader can tell what was decided from what
   was built.
2. Implement on the branch each change belongs to; where a change touches both
   features, follow BL04's propagation method — one build that carries both,
   single-feature variants verified by stripping, added lines diffed against
   the target worktree.
3. Append `REPLAY.md` rows for anything on the Unicode side.

## Verify (gate)

- `check-clang` green on every branch touched, against the plan's baselines.
- Every behaviour the decision changed has a test that **fails without the
  change**. Demonstrate it, in the BL03 manner.
- The deviation row for each implemented decision is marked and says which
  step implemented it.

## If the answer was "no change"

That is a complete and common outcome, and this step then does nothing but
say so. **Do not tick this box on an empty step** — mark it not-applicable in
the plan with a one-line reason, and let reconcile-declaring-using carry the documentation.
