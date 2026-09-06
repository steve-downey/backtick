# unicode-paper — The Unicode paper: a real number, and the blog version

**Goal.** The last step. `papers/dxxxxr0.md` is a complete 718-line draft that
**still has `DXXXXR0` as its document number** — it has never been submitted.
This step finishes it and gives it one.

**Depends on:** mangling-abi (the ABI section), implement-decisions (decided changes implemented),
reconcile-implementation-cost, reconcile-declaring-using, reconcile-remainder (the whole Unicode ledger reconciled). It is last because it
depends on nearly everything, which is the correct shape: the paper is what
all of it was for.
**Refs:** `papers/dxxxxr0.md`; `docs/unicode-operators.md`;
`docs/unicode-infix-operators.org` and its `.meta`; `docs/open-decisions.md`
with the author's answers.

**Use the `voice` skill**, formal register.

## Get it a number

`D4307` was assigned to the backtick paper; this one has never been. Until it
has, `papers/dxxxxr0.md`'s filename, its `document:` field and every
cross-reference to it in `docs/` and `ops/` say `DXXXX`. **Renaming is part of
this step** — grep for `dxxxxr0` and `DXXXX` across the whole repo, not just
`papers/`, because the design doc and several deviation rows point at it.

If the number cannot be obtained in this sitting, that is a **BLOCKED**
handoff on an administrative dependency, and the rest of the step can still be
done — just do not half-rename.

## What has changed under the paper

- **mangling-abi rewrote U§9.** The ABI question is answered: what is implemented, what
  the paper asks for, and what is unexamined. The paper's "What is not
  resolved" section shrinks accordingly, and must not still list a question
  mangling-abi answered.
- **reconcile-implementation-cost rewrote U§8.** This is the biggest change and the paper's strongest
  material: five Clang work items rather than three, 32 dispatch sites in 21
  files over `StmtClass` and 33 over `NameKind` on a disjoint axis, the
  four-category taxonomy of how a compiler does and does not tell you about
  your obligations, the four-for-four sibling pattern with [`matcher-operator-name`](../../BACKLOG.md#matcher-operator-name) as the first
  refusal, and the conclusion that **opening a closed operator table costs a
  parallel implementation, never a widened one — which is why the relaxation
  provably cannot leak into `operator+`.** The paper's "Implementation
  experience" section is where this goes and it will roughly double.
- **[`codegen-dispatch-sites`](../../unicode-operators/clang/DEVIATIONS.md#codegen-dispatch-sites)(c)**: every shape emits CIR **instruction-for-instruction
  identical** to the explicit call. That is the desugaring thesis checked at
  the last place it could have failed, and it belongs near the top of the
  implementation-experience argument, not in a footnote.
- **reconcile-declaring-using rewrote §7 / §7.1**, including removing the unqualified "anywhere".
- **decision-brief's answers.** Four questions that the paper currently lists as open are
  now decided. Move them out of "What is not resolved" and into the design,
  with the author's reasoning. What remains open should be a short list, and
  every item on it should be open *on purpose*.
- **reconcile-remainder's U§6 correction**: four independent measurements contradicted
  "parsing is the easy part". The paper should carry the corrected claim and
  the fact that it was corrected — a prototype that changed its author's mind
  about something is worth reporting.

## Do

1. Reconcile against `docs/unicode-operators.md`, which reconcile-implementation-cost–reconcile-remainder have just
   rewritten. Design doc is truth; paper is written from it.
2. Check every "we implemented" claim against the tree.
3. Confirm the **separable-fates** claim in the paper still matches reality —
   `git diff upstream/main..unicode-operators-upstream | grep -i backtick`
   returns nothing, and `U20`, `BL03` and `BL04` have each preserved it. If it
   ever stops being true, the paper's scope argument changes.
4. Rename to the assigned number, everywhere.
5. Build: `make -C papers`.
6. Then `docs/unicode-infix-operators.org`, informal register.

## Verify (gate)

- The paper renders, under its **real** number, with no `DXXXX` left anywhere
  in the repo (`grep -ri dxxxx` is the check).
- "What is not resolved" contains nothing decision-brief or mangling-abi answered.
- Every "we implemented" claim checked against the tree; say how many.
- The separable-fates grep is in the handoff, with its empty output.

## When this is done

Every plan in `ops/` is fully checked, both papers are finished, all three
deviation ledgers are empty of unreconciled rows, and every `BNN` row has a
`Closed by` cell. Say that in the handoff if it is true — and if it is not,
say which one is not, because that is the only thing left.
