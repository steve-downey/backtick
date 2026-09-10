# backtick-paper — D4307R0, and the blog version

**Goal.** The backtick paper is a complete draft — 1128 lines, eleven
sections, wording included — written before four tracks of measurement landed.
This step makes it say what is now true and finishes it.

**Depends on:** clang-paper-truth (paper-truth defects fixed),
[clang-slot-adl](clang-slot-adl.md) (§17.4 restored, and a finding to write),
reconcile-remainder (backtick ledger
reconciled, §17 updated), hygiene-parity (parity gaps closed so the paper does not have
to explain them).
**Closes:** nothing in `BACKLOG.md`. This is the deliverable.
**Refs:** `papers/backtick-infix-and-keyword-escape.md`; `docs/backtick-operator-design.md`;
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
- **[clang-slot-adl](clang-slot-adl.md) leaves this step a finding, not a
  repair.** [§17.4](../../../docs/backtick-operator-design.md#174-adl-is-normative-cross-compiler-note)
  is normative and is now true again — but the four paragraphs under it are
  written for a paper to take and are the strongest implementation-experience
  material in the design doc. **The within-compiler control**: Clang carries
  both features of this proposal in one build, and the Unicode operator
  inherited ADL from the first commit while the backtick operator never had
  it, differing in exactly one thing — whether the slot reaches the call
  builder unresolved. That is a cleaner demonstration of *desugar early,
  inherit everything downstream* than any cross-compiler comparison, because
  it holds the compiler, the machine and the author constant. **And the
  near-miss belongs in the paper too**: the defect survived nine
  implementation steps because the one test that announced itself as the ADL
  case used a *qualified* name, which gets no ADL either way. The shape that
  catches it is augmentation — a visible viable candidate plus a better ADL
  one — because that is the only shape whose failure is silent. Say what a
  reviewer should ask for, not only what was built.
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
