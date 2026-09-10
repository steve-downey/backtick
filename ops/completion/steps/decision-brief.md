# decision-brief — Four open questions, and the "anywhere" claim

**Goal.** The seven items in `ops/BACKLOG.md` §6 have been "measured, with a
recommendation, needing an author's decision" since the tracks closed, and
have never been put in front of the author in one place. Four of them have
**implementation consequences**, so deciding them late means building twice
and writing twice. This step is the one thing that blocks the most.

**Depends on:** nothing. Desk work — no build, no branch.
**Closes:** [`dependent-template-operator-id`](../../BACKLOG.md#dependent-template-operator-id). Unblocks implement-decisions, reconcile-declaring-using, and (with mangling-abi) unicode-paper.
**Refs:** `ops/unicode-operators/clang/DEVIATIONS.md` rows [`over-oper-restrictions`](../../unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions),
[`prefix-arity-selection`](../../unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection), [`operand-sequencing`](../../unicode-operators/clang/DEVIATIONS.md#operand-sequencing), [`postfix-operators`](../../unicode-operators/clang/DEVIATIONS.md#postfix-operators); `docs/unicode-operators.md` §13 and §13.1;
`ops/unicode-operators/clang/handoffs/U21-postfix-probe.handoff.md`.

## Scope — four questions plus one re-triage

The three §6 items **not** here: the ABI question is mangling-abi (it is large enough
to be its own step and it wants upstream-reports's issue number), [`operand-sequencing`](../../unicode-operators/clang/DEVIATIONS.md#operand-sequencing) is a CWG
question with no implementation consequence and is recorded by reconcile-declaring-using, and
U§6's sixth worked example is a two-line doc sync done by reconcile-remainder.

1. **[`prefix-arity-selection`](../../unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection) — a prefix use finds a two-parameter operator through its
   default argument.** Keep and document, or reinstate [over.oper]p8. Note
   this one interacts with [`over-oper-restrictions`](../../unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions)(b); do not decide them apart.
2. **[`over-oper-restrictions`](../../unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions) — static member user operators**, currently rejected with no
   design guidance behind the rejection.
3. **U§13 — fold expressions over the user-infix level.** To be answered
   **once for both features**, which is what makes it worth a decision rather
   than a defect: the answer belongs in both papers or neither.
4. **[`postfix-operators`](../../unicode-operators/clang/DEVIATIONS.md#postfix-operators) / `U21` — postfix operators.** Already deferred *with a
   measured account* — U21 was a feasibility probe and its finding is the
   evidence. The decision is whether the deferral is permanent and what the
   papers say about it.
5. **[`dependent-template-operator-id`](../../BACKLOG.md#dependent-template-operator-id) — `t.template operator⊞<int>(0)` on a dependent object expression
   is rejected.** Not a §6 item, but the same shape: inherited, not
   introduced (`DependentTemplateStorage` holds an identifier or a built-in
   operator kind and nothing else, and user-defined literal operators have had
   the identical limitation since C++11), and it **falsifies the word
   "anywhere" in U§7.1**. So it is fix-upstream, or reword. That is a
   decision, not an implementation.

## Do

Produce `docs/open-decisions.md` — one page per question, each with exactly
these five parts and nothing else:

- **The question**, in one sentence, as a reader of the paper would ask it.
- **What was measured**, quoting the deviation row rather than paraphrasing.
- **The options**, at least two, each stated so that choosing it is a
  complete answer.
- **The cost of each**, split into *implementation* and *paper*. Say which
  branches an option touches and roughly what it costs; for postfix, U21
  already priced it — use its number, do not re-derive.
- **A recommendation**, with the reason. One paragraph. Recommend something.

Then, at the top, a table: question, recommendation, and the implementation
consequence of the recommendation (`none` / `Sema` / `parser` / `large`). The
author should be able to answer all five from that table and read the pages
only where they disagree.

## Verify (gate)

- No build. Nothing committed to a feature branch.
- Every one of the five has all five parts; **no page ends in "TBD"** and no
  recommendation is "either is fine".
- Each page names the branches its recommendation would touch, so implement-decisions can be
  scoped from this document alone.
- `ops/BACKLOG.md` §6 is rewritten to point at `docs/open-decisions.md`
  instead of restating the questions.

## After the author answers

Record the answers **in `docs/open-decisions.md` itself**, dated, with the
author's reason where it differs from the recommendation — that record is
what reconcile-declaring-using and unicode-paper cite. Then implement-decisions implements whatever was decided. If the
author has not answered when you finish, that is a **BLOCKED** handoff with
the brief attached, which is a successful step: the block is the point.
