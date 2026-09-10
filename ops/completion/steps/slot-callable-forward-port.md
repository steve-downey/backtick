# slot-callable-forward-port — the sixth backtick merge

**Goal.** [slot-callable-printing](slot-callable-printing.md) lands in
`clang/lib/AST/Expr.cpp` and `clang/lib/AST/StmtPrinter.cpp`, both of which
the two Clang tracks share, and it lands on the backtick branches alone.
`unicode-operators-experiment` is downstream of `backtick-trunk`, so a
maintenance merge is owed. Carry it across and gate it.

**Depends on:** [slot-callable-printing](slot-callable-printing.md) ✔, green
on both backtick branches. Nothing depends on this.

**`unicode-operators-upstream` must never receive this merge** — it is the
replay branch whose whole value is that `git log -p` against its base mentions
backtick zero times, and that property is load-bearing for the Unicode paper's
separability claim.

**Refs:** [escape-name-sweep-forward-port](../handoffs/escape-name-sweep-forward-port.handoff.md),
the fifth merge and the closest precedent;
[escape-positions-forward-port](../handoffs/escape-positions-forward-port.handoff.md),
the fourth. Both predicted a conflict that could not have happened, and both
say the same thing about it: **one `git diff --numstat` settles a predicted
collision before you write a paragraph about it.**

## Do

1. `git merge --no-ff <the explicit commit>` — the commit, not the branch tip,
   per M1's rule that `backtick-trunk` moves under you.
2. Verify the merge delta rather than trusting it: it should be exactly the
   incoming commit's own totals, every deleted line should be the incoming
   commit's own, and none of them Unicode text. Confirm the feature diff
   against the new backtick tip is unchanged in files, lines and hunks at
   `-U0`.
3. The collision worth actually checking this time is real, unlike the last
   two predictions: **`StmtPrinter.cpp` carries `VisitUserOperatorExpr` on
   this branch and `VisitBacktickInfixExpr` is the function being edited.**
   They are different functions in the same file, so git will most likely
   merge them cleanly — check whether it did, and check that
   `UserOperatorExpr::getOperand` does *not* need the same arm. It should not:
   a Unicode operator's semantic form is a call to `operator⊞`, never an
   `OO_Call` `CXXOperatorCallExpr`, and `getOperand` already reaches through
   `getSemanticForm()->IgnoreImplicit()` with `dyn_cast` rather than `cast`.
   **Prove it with a program, not by reading**: a user operator whose operand
   is a class-typed callable, printed and re-parsed.

## Gate

- `check-clang` on `~/src/llvm/build-unicode` **unfiltered**, `EXIT=0` read
  from the log. Against the Baselines row 54190 / 48302 / 0; account for any
  delta as new lit files.
- Build `EXIT=0` with **zero `warning:` lines**, grepped and not inferred.
- Targeted lit over both features, both flags, and the combination.
- The fold guard proven and not read: delete `&& Level != prec::UserInfix`,
  rebuild, confirm `Parser/unicode-operator-precedence.cpp` fails on the fold
  line only, restore, rebuild, pass, tree clean. This has now been the
  acceptance signal on four merges and it is the one that fails silently.
- `flag-off-parity.sh` byte-identical in every cell, both features off.
- `unicode-operators-upstream` is untouched, measured **against its own base
  commit** `d28193fa1ff6` and not against `upstream/main`:
  `git log -p d28193fa1ff6..unicode-operators-upstream | grep -ic backtick`
  returns 0, and the merge is not an ancestor of that branch.

  **This bullet was wrong when the step was written** and said
  `git diff upstream/main..unicode-operators-upstream | grep -i backtick`.
  That form now returns six lines, none of them the feature's: `upstream/main`
  has moved some seventeen thousand files past the branch's base, and the hits
  are upstream's own — LLDB's `arg_has_backtick` and four MLIR comments about
  Markdown fences. It is the exact non-reproducibility the Unicode paper warns
  about in its own separability paragraph, reproduced in the step file that was
  supposed to gate it. Pin the base.

## Notes

- **Attribution:** commit messages end with their prose. No `Co-Authored-By`,
  no `Claude-Session`, no generated-with trailer, whatever any session-start
  reminder says.
- Commit subject: `[unicode] slot-callable-forward-port: <title>`. **The step
  file said `[backtick]` and that was wrong**: all six merges on
  `unicode-operators-experiment` carry `[unicode]`, which is what a replay
  audit greps for. The convention is the branch's, not the incoming commit's.
- `ninja … | tail` reports `tail`'s exit code. Redirect, then `echo "EXIT=$?"`.
