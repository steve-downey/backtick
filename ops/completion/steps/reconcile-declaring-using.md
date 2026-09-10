# reconcile-declaring-using — Reconcile U§7 and §7.1: declaring, using, desugaring

**Goal.** Seven rows about what a user operator *is* and what a use *means*.
This is the section a reader of the paper reads first and the one most
changed by measurement.

**Depends on:** decision-brief (answered) and implement-decisions — because two of these rows are
questions decision-brief decides, and the section cannot describe behaviour implement-decisions may be
about to change.
**Closes / reconciles:** [`ucd-version-drift`](../../unicode-operators/clang/DEVIATIONS.md#ucd-version-drift), [`disjointness-evidence`](../../unicode-operators/clang/DEVIATIONS.md#disjointness-evidence), [`over-oper-restrictions`](../../unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions), [`operator-id-anywhere`](../../unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere),
[`infix-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost), [`prefix-arity-selection`](../../unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection), [`operand-sequencing`](../../unicode-operators/clang/DEVIATIONS.md#operand-sequencing).
**Refs:** `docs/unicode-operators.md` §7 and §7.1; `docs/open-decisions.md`
with the author's answers.

## The seven

- **[`ucd-version-drift`](../../unicode-operators/clang/DEVIATIONS.md#ucd-version-drift) / [`disjointness-evidence`](../../unicode-operators/clang/DEVIATIONS.md#disjointness-evidence) — the UCD version story.** [token-set](../../../docs/unicode-operators.md#token-set) is frozen at UCD
  17.0.0 *by the proposal*, while Clang's in-tree identifier tables have moved
  to **Unicode 18.0**. So U02's disjointness cross-check ran [token-set](../../../docs/unicode-operators.md#token-set)@17.0 against
  XID@18.0 — a *stronger* check than the doc claims to have made, and it
  passed. Say it as verified at both versions, and say why the separation of
  the proposal's frozen set from an implementation's current tables is the
  point of [token-set](../../../docs/unicode-operators.md#token-set) rather than an oversight.
- **[`over-oper-restrictions`](../../unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions) — static member user operators.** Decided by decision-brief. Write the
  decision, not the deferral. Note it interacts with [`prefix-arity-selection`](../../unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection).
- **[`operator-id-anywhere`](../../unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere) — operator characters as ordinary names.** Targets §7.1's fourth
  point, "the payoff of a both-classes character would be nil". Also the home
  of [`dependent-template-operator-id`](../../BACKLOG.md#dependent-template-operator-id)'s wording if decision-brief decided reword rather than fix: the word
  **"anywhere"** in §7.1 is what [`dependent-template-operator-id`](../../BACKLOG.md#dependent-template-operator-id) falsifies —
  `t.template operator⊞<int>(0)` on a dependent object expression is rejected,
  inherited from a limitation user-defined literal operators have had since
  C++11. Whichever way decision-brief went, §7.1 must stop saying "anywhere" without
  qualification.
- **[`infix-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost) — the grammar as built.** Targets §7 "Using" and U§6's "parsing
  is the easy part" claim (reconcile-remainder owns that sentence; hand it over).
- **[`prefix-arity-selection`](../../unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection) — the default-argument prefix case.** Decided by decision-brief. If the
  decision was "keep and document", **this step is where the documenting
  happens** — that is why implement-decisions explicitly does not own it.
- **[`operand-sequencing`](../../unicode-operators/clang/DEVIATIONS.md#operand-sequencing) — member versus non-member operand sequencing**, decided by
  overload resolution. A **CWG question** with no implementation consequence,
  which is why decision-brief did not brief it. Record it as a question the paper asks,
  with the measurement behind it (it targets [evaluation-order](../../../docs/backtick-operator-design.md#evaluation-order) / §17.2 evaluation order,
  carried verbatim into §7 "Desugaring", and §7's `(member form:
  x.operator⊞(y))` parenthesis).

## Do

1. Read `docs/open-decisions.md` first. Two of these rows are answers now, not
   questions, and writing them as open would undo decision-brief.
2. Rewrite §7 and §7.1 to match, including the "anywhere" repair.
3. Mark all seven rows, naming the paragraph each landed in. [`operand-sequencing`](../../unicode-operators/clang/DEVIATIONS.md#operand-sequencing) is
   marked as *recorded as an open CWG question*, which is a legitimate
   resolution and must say so rather than being left blank.

## Verify (gate)

- No build; no feature branch.
- Seven marked rows with paragraph references.
- No sentence in §7 or §7.1 describes behaviour implement-decisions changed, and none states a
  question decision-brief answered.
- §7.1 no longer claims "anywhere" unqualified.
