# clang-slot-adl — Clang does no ADL on the backtick slot

**Goal.** [§17.4](../../../docs/backtick-operator-design.md#174-adl-is-normative-cross-compiler-note)
is **normative** — the slot gets the same argument-dependent lookup as the
call it desugars to — and its implementation-status paragraph reports the rule
as delivered by both compilers. Clang has never delivered it. Restore §17.4 as
written by fixing the Clang slot, and leave the evidence where
[backtick-paper](backtick-paper.md) will find it.

**Depends on:** nothing. Independent of every other step.
**Closes:** [`clang-slot-adl`](../../BACKLOG.md#clang-slot-adl); reconciles
[`clang-slot-adl`](../../DEVIATIONS.md#clang-slot-adl).
**Refs:** [`evidence-debt`](../handoffs/evidence-debt.handoff.md), which found
it; [`gcc-slot-adl`](../../gcc/DEVIATIONS.md#gcc-slot-adl) and
[`gcc-template-id-slot-adl`](../../gcc/DEVIATIONS.md#gcc-template-id-slot-adl),
which are this defect and its sequel on the other compiler;
[gcc-resync](gcc-resync.md), which fixed the second of those.

## Why this is in Phase D and not in hygiene

This is the one failure the desugaring thesis cannot absorb. With
`::pick(double, double)` visible and `ns::pick(U, U)` reachable by ADL,
`pick(u, u)` binds the ADL candidate and `` u `pick` u `` binds the other,
**with no diagnostic** — the operator form calls a different function from the
call it is defined to be sugar for. Both papers are written from §17.4 and
both inherit the false sentence.

## The decision, already taken

**Fix it, and carry it as a paper finding.** The author decided this; do not
re-open it, and do not take the reword option §17.4's status-correction block
offers.

The finding has two parts and both belong to [backtick-paper](backtick-paper.md),
not to this step:

- **A within-compiler control.** The **Unicode** feature, same build, same
  machine, is correct — its slot never becomes an expression, so it reaches
  candidate assembly unresolved. Two features, one compiler, one difference.
  That is stronger evidence for *inherit, don't reimplement* than the
  cross-compiler note §17.4 already draws, because it needs no second
  compiler.
- **The near-miss is instructive.** Nine steps missed this because the track's
  one "ADL" test used a **qualified** name — the single case that gets no ADL
  either way and therefore passes whatever the slot does.

Your job is the fix and the evidence. Leave the material in the design doc,
the ledger row and your handoff; write no paper prose.

## Do

### 1. The parser change, on `backtick-trunk` first

The cause is one line. `Parser::ParseRHSOfBinaryExpression` parses the slot
with `ParseExpression()` (`clang/lib/Parse/ParseExpr.cpp`), so a bare
identifier reaches `Sema::ActOnIdExpression` with `HasTrailingLParen = false`,
and `Sema::UseArgumentDependentLookup` returns false on its first line. The
name is resolved before `Sema::ActOnBacktickOperator` hands it to
`BuildCallExpr`.

The slot is a **callee**, and in the slot the closing backtick is the trailing
`(`. Give it its own parse, a sibling to the type-slot arm
`TryParseBacktickTypeSlot` that [`type-name-slot`](../../../docs/backtick-operator-design.md#type-name-slot)
already put there, so the shape stays local and the fall-through is explicit.

**Do both unqualified forms in one go.** GCC's first fix looked for a bare
identifier and left a template-id slot silently on the old path
([`gcc-template-id-slot-adl`](../../gcc/DEVIATIONS.md#gcc-template-id-slot-adl)),
which cost a second step and a second ledger row. §17.4 says ADL binds
"wherever the slot is an unqualified name, whether or not it carries template
arguments"; make that sentence true on the first pass.

**Everything else in the slot keeps parsing as an ordinary expression, and
that is correct** — a qualified name, a member access, a callable object, a
function pointer and a type-name slot all get no ADL in the equivalent call
either. The fix must not become unconditional ADL.

### 2. The test the track never had

New file, and it must not repeat the mistake that hid this: **no qualified
name may stand in for an ADL test.** Every shape written twice, once as a
spelled call and once as the operator, with the call as the control:

- a hidden friend;
- an ADL-only namespace member;
- **augmentation** — an ordinary-lookup candidate visible *and viable*, a
  better ADL candidate reachable, the choice made observable by a tag type so
  a wrong bind fails rather than compiling;
- the same with an overload *set* visible, so the slot cannot be right by
  accident;
- a template-id slot;
- two-phase lookup — the ADL candidate declared *after* the template that
  uses it;
- the negative controls of the paragraph above, each asserting a *binding*;
- a block-scope function declaration, which suppresses ADL
  ([basic.lookup.argdep]/3) and so must bind the ordinary candidate in both
  forms — the check that the slot did not simply gain unconditional ADL.

Also correct `clang/test/SemaCXX/backtick-semantics.cpp`. Its prolog claims to
cover ADL and its section 2 is headed as an ADL case; both are false and both
are why this went nine steps unseen.

### 3. Cherry-pick to `backtick-23` and gate it independently

A clean cherry-pick is not proof of a passing gate.

### 4. The documents

- Rewrite [§17.4](../../../docs/backtick-operator-design.md#174-adl-is-normative-cross-compiler-note)'s
  implementation-status paragraph so it is true, and **remove the dated
  status-correction block** [evidence-debt](../handoffs/evidence-debt.handoff.md)
  put above it — it exists only to stop the paragraph reaching a paper, and
  the paragraph is now safe. Say what the Clang fix is, in the same register
  as the GCC half beside it, and record the within-compiler control there,
  because that is what a paper is written from.
- Mark [`clang-slot-adl`](../../DEVIATIONS.md#clang-slot-adl) in the ledger,
  **naming the destination section and paragraph**.
- Fill [`clang-slot-adl`](../../BACKLOG.md#clang-slot-adl)'s `Closed by` cell.
- Add `clang-slot-adl` to [backtick-paper](backtick-paper.md)'s dependency
  list in the checklist, and note the finding in the plan's Coverage table.

## Verify (gate)

- **The new test fails on the pre-fix binary, on its own content.** Show it —
  this track's standard of proof, met by both recent Clang steps. The
  augmentation sections are the ones to point at: pre-fix they fail as a
  *wrong bind*, not as a compile error, which is the whole defect.
- `check-clang` green on **both** backtick branches against the Baselines in
  [`ops/completion/PLAN.md`](../PLAN.md), one Status-log row each. A new test
  file moves the counts; state the delta and update the Baselines.
- The negative controls pass **identically before and after**. A fix that
  turns ADL on everywhere would pass every positive section and is wrong.
- §17.4 contains no status-correction block and no false sentence; the ledger
  row names its destination paragraph.
