# U20 — Clean-`main` replay branch and gate

**Goal.** A branch off pristine upstream `main` carrying only the Unicode
feature — no backtick dependency, no backtick diff — passing the same gate
as the experiment branch. This is what an upstream PR would actually be.

**Depends on:** U19.
**Design refs:** `clang-experiment-plan.md` "Upstream Replay Assumptions";
U7; U12.

## Do
1. New worktree and build dir off upstream `main` (do not reuse the
   experiment's):
   ```bash
   git -C ~/src/llvm/main fetch upstream
   git -C ~/src/llvm/main worktree add -b unicode-operators-upstream \
       /home/sdowney/src/llvm/unicode-upstream upstream/main
   ```
   Record the base commit; the experiment's base (from U00) and this one
   will differ, and the drift is part of the result.
2. Apply U19's ordered commit list, one commit at a time, building between
   commits. Where U19 named a standalone equivalent (the `UserInfix`
   `prec::Level` above all), write it here — that is the point of the step.
3. Nothing named `backtick` may appear in the diff. Grep for it before
   gating; a stray mention in a comment is a finding worth reporting, not
   a typo.
4. Split the test files per U19: the mixed backtick/Unicode precedence
   cases stay on the experiment branch.

## Build
`ninja -C ~/src/llvm/build-unicode-upstream clang`

## Verify (gate)
- Full `check-clang` on the replay branch, green by the usual rule (exactly
  the one env-only known failure).
- Every Unicode test from the experiment branch that U19 classified as
  upstream-clean passes here, unmodified.
- `git diff upstream/main..unicode-operators-upstream | grep -i backtick`
  returns nothing.
- Build with the flag off and confirm the compiler is byte-identical in
  behavior to upstream on a representative TU containing U1 characters.

## Done when
The upstream-shaped patch stack builds and gates green on clean `main`,
carries no backtick dependency, and the two branches' feature diffs are
reconciled and explained.

## Capture in handoff
The final diff stat for the upstream stack (the number the paper quotes as
implementation cost), the commit list as landed, and anything that only
worked on the experiment branch — those are the honest caveats. If the
replay revealed that some behavior *required* the backtick diff after all,
that is a major finding: DEVIATIONS row, and it changes U12's argument that
the two papers can have separable fates.

## Pitfalls
`main` will have moved since U00. Expect unrelated churn in the files this
feature touches — resolve it as ordinary rebasing, but note any place where
upstream drift would have broken the design (e.g. a refactor of
`DeclarationName` or `UnicodeCharSets.h`). Those are exactly the
maintenance-cost questions a committee asks.

## REPLAY ledger
Close it out: mark every row resolved, and record what the ledger got
wrong. A ledger that predicted the replay perfectly is worth saying so;
one that didn't is worth saying louder.
