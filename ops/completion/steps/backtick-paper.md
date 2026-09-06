# backtick-paper — D4307R0, and the blog version

**Goal.** The backtick paper is a complete draft — 1128 lines, eleven
sections, wording included — written before four tracks of measurement landed.
This step makes it say what is now true and finishes it.

**Depends on:** clang-paper-truth (paper-truth defects fixed), reconcile-remainder (backtick ledger
reconciled, §17 updated), hygiene-parity (parity gaps closed so the paper does not have
to explain them).
**Closes:** nothing in `BACKLOG.md`. This is the deliverable.
**Refs:** `papers/d4307r0.md`; `docs/backtick-operator-design.md`;
`docs/infix-backtick-operator.org` and its `.meta`; `papers/Makefile`
(`include wg21/flat.mk`).

**Use the `voice` skill.** `CLAUDE.md` says to prefer it for this prose, and
this is the formal register — a WG21 paper, not the blog post.

## What has changed under the paper since it was drafted

Work through these rather than re-reading the whole thing cold:

- **`BL02` implemented [type-name-slot](../../../docs/backtick-operator-design.md#type-name-slot)** — a type-name in the operator slot. `D4307R0` is
  the nearer paper and [`type-slot-implementation`](../../BACKLOG.md#type-slot-implementation) existed precisely because the paper said
  something the implementation did not do. Check that §"Design choices and
  decisions" and the wording section now match the implementation, including
  the `-ast-print` round trip and the CTAD and dependent forms.
- **clang-paper-truth's three fixes** change three claims: the flag is now C++-only in fact
  as well as intent ([`c-mode-tokenization`](../../BACKLOG.md#c-mode-tokenization)), the keyword escape round-trips ([`keyword-escape-round-trip`](../../BACKLOG.md#keyword-escape-round-trip)), and the
  node's source range spans its operands ([`backtick-source-range`](../../BACKLOG.md#backtick-source-range)).
- **[`cir-backtick-arms`](../../DEVIATIONS.md#cir-backtick-arms) (reconcile-remainder)** gives §17 the back-end symmetry sentence: the two
  features diverge in the front end and converge in the back end, which is the
  design's own claim about where the sugar stops mattering.
- **upstream-reports's issue numbers.** Wherever the paper says a defect was found in
  Clang, cite it.
- **upstream-triage's WONTFIX reasons**, if [`inner-call-source-range`](../../BACKLOG.md#inner-call-source-range) or [`operator-caret-range`](../../BACKLOG.md#operator-caret-range) went that way — the paper
  should answer those questions rather than let a reviewer raise them.
- **[`gcc-wrapper-parity`](../../BACKLOG.md#gcc-wrapper-parity) from gcc-resync**: parts of the Clang work have **no GCC counterpart by
  construction**. A two-implementation paper has to say which parts, and why
  that is a fact about the compilers rather than a gap in the experiment.

## Do

1. Reconcile the paper against `docs/backtick-operator-design.md`, which reconcile-remainder
   has just brought up to date. **The design doc is the source of truth and
   the paper is written from it** — if they disagree, fix the paper, and if
   the design doc is the one that is wrong, fix it first and say so.
2. Check every claim of the form "we implemented X" against the tree. The
   tracks are done, so every such claim is checkable, and a WG21 audience will
   check them.
3. Build it: `make -C papers` (`wg21/flat.mk`). Confirm it renders.
4. Then `docs/infix-backtick-operator.org` — the **informal** register, the
   blog post. Same substance, different voice; use the `voice` skill's blog
   guidance, not its paper guidance. Update its `.meta` date if the content
   moved substantially.

## Verify (gate)

- No build of the compiler; no feature branch.
- The paper renders through `papers/Makefile`.
- **Every "we implemented" claim has been checked against the tree in this
  step**, and the handoff says how many were checked and whether any failed.
  That number is the gate.
- The `.org` and the paper do not contradict each other on any fact.
