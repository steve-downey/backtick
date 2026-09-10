# Handoff — decision-brief — Four open questions, and the "anywhere" claim

- **Status:** **GREEN (gate passed, and the step is complete).** It stood
  BLOCKED on the author from 2026-09-05; the author answered on 2026-09-06 —
  **all five recommendations accepted as written, none overridden** — and the
  answers are recorded, so the box is ticked.
- **Branch / commit:** `unicode-operators` in *this* repo only —
  `71780ad` (the brief) and a follow-up carrying the answers, this handoff and
  the plan bookkeeping. No feature branch touched, no compiler built, nothing
  landed in any LLVM or GCC worktree — correct for this step, which the step
  file marks "desk work — no build, no branch".
- **Date / agent:** brief 2026-09-05; answers recorded 2026-09-06

## The answers (2026-09-06) — all five recommendations accepted

| Question | Answer | What it generates |
|---|---|---|
| [prefix-arity-selection](../../../docs/open-decisions.md#prefix-arity-selection) | (a) — [over.oper]p8 stays **waived**; the cross-fixity use is intended | U§7 "Declaring" paragraph; split [unary-forms](../../../docs/unicode-operators.md#unary-forms)'s second sentence into declaration-arity and use-position |
| [over-oper-restrictions](../../../docs/open-decisions.md#over-oper-restrictions) | (a) — static members stay **rejected**, on the two-spellings reason, *not* the "no implicit object parameter" one | U§7 "Declaring" enumerates all five [over.oper] restrictions; **a new decision entry** is owed, suggested slug `static-member-operators` |
| [fold-over-user-infix](../../../docs/open-decisions.md#fold-over-user-infix) | (a) — **excluded in v1, for both features**, stated as deliberate | a U§13 bullet (the section has none to amend) + one backtick-paper sentence; **and a standing silent guard** |
| [postfix-operators](../../../docs/open-decisions.md#postfix-operators) | (a) — **declined for v1, not foreclosed**, in *affordable and declined* terms | keep U§13.1 as a full subsection; make [unary-forms](../../../docs/unicode-operators.md#unary-forms)'s rationale agree |
| [dependent-template-operator-id](../../../docs/open-decisions.md#dependent-template-operator-id) | (c) — **reword first, report separately**, paper not gated on the fix | the U§7.1 clause; one upstream report against the **literal-operator** reproducer |

**Nothing turned into code**, which is why
[implement-decisions](../steps/implement-decisions.md) is now marked
**not-applicable** in the plan rather than left looking unstarted — per its own
step file's "If the answer was 'no change'" clause, which says to mark it with
a one-line reason and *not* tick it. All the work these answers generate is
documentary and belongs to reconcile-declaring-using (U§7, U§7.1),
reconcile-remainder (U§13, U§13.1) and upstream-triage (the report).

**Where each answer was recorded**, per the convention that a ruling appends to
its question's own Log rather than getting a document of its own:

- **`docs/open-decisions.md`** — five dated subsections plus a
  "Where each answer was recorded" table.
- **`docs/unicode-operators.md` §2** — `Log.` entries on
  [unary-forms](../../../docs/unicode-operators.md#unary-forms) (which carries
  **three** of the five answers: the p8 waiver, the static-member reason, and
  the postfix reframing),
  [operator-function-id](../../../docs/unicode-operators.md#operator-function-id),
  [user-infix-precedence](../../../docs/unicode-operators.md#user-infix-precedence)
  and
  [operator-identifier-disjointness](../../../docs/unicode-operators.md#operator-identifier-disjointness).
- **`docs/backtick-operator-design.md` §3** — a `Log.` entry on
  [precedence-level](../../../docs/backtick-operator-design.md#precedence-level),
  because the fold answer is *one answer for both features*.
- **`ops/unicode-operators/clang/DEVIATIONS.md`** — five rows marked
  **`OPEN — DECIDED 2026-09-06`**:
  [prefix-arity-selection](../../unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection),
  [over-oper-restrictions](../../unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions),
  [infix-parse-cost](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost)
  (part 3 only), [postfix-operators](../../unicode-operators/clang/DEVIATIONS.md#postfix-operators)
  (substance only) and
  [operator-id-anywhere](../../unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere).
- **`ops/BACKLOG.md`** —
  [dependent-template-operator-id](../../BACKLOG.md#dependent-template-operator-id)'s
  `Closed by` records that it closes as a **pair** of steps.

**No row was marked `RECONCILED`, and that is deliberate.** Deciding is not
reconciling. A row goes `RECONCILED` when its destination section says the new
thing; every one of these five names its destination section and its owning
step and stays `OPEN` until that step writes it. Marking them otherwise would
report work that has not happened — the exact failure the plan's docs-step gate
exists to catch.

**Two scope lines held.** The U§7.1 reword was *not* written here (it is
reconcile-declaring-using's) and the upstream issue was *not* drafted here (it
is upstream-triage's). The recommended new decision entry
`static-member-operators` was likewise recorded as owed rather than written,
for the same reason.

**The fold guard was put where it will be read**, since the answer leaves a
standing obligation and not just a sentence:
`Level != prec::UserInfix` in `Parser::isFoldOperator` must survive every
rebase and replay on all four Clang branches, and it fails **silently**. It is
now a bullet in `ops/completion/PLAN.md`'s **Gate facts** (the live plan, read
before every step) *and* a dated standing warning at the top of
`ops/unicode-operators/clang/REPLAY.md`, above the per-step rows, where a
replay agent looks first. Both say the same operative thing: on clean `main`
the predicate ends at `prec::Spaceship`, so a replay must **add** the clause,
not rename one, and the negative tests that pin it
(`clang/test/Parser/unicode-operator-precedence.cpp` section 9 and its backtick
twin) must come across with it.

## What changed

**New file — [`docs/open-decisions.md`](../../../docs/open-decisions.md).**
Five pages, each headed by its slug so the slug is a Markdown anchor, each
with exactly the five parts the step file names: **The question / What was
measured / The options / The cost of each / Recommendation**. A summary table
at the top carries question, recommendation and implementation consequence, so
the author can answer all five from the table and read the pages only where
they disagree. Every recommendation ends with an explicit **Branches touched
by the recommendation** line, and every option that would touch a branch names
which.

| Page (slug) | Question | Recommendation | Consequence |
|---|---|---|---|
| [prefix-arity-selection](../../../docs/open-decisions.md#prefix-arity-selection) | May a defaulted trailing parameter make an infix-declared operator prefix-usable? | Keep [over.oper]p8 waived; document that declaration-arity and use-position are independent | **none** |
| [over-oper-restrictions](../../../docs/open-decisions.md#over-oper-restrictions) | May a user operator be a static member function? | Keep rejecting it, with a reason that holds | **none** |
| [fold-over-user-infix](../../../docs/open-decisions.md#fold-over-user-infix) | May a user-introduced infix operator be a fold operator? | No, for both features, in v1 — stated as a decision | **none** |
| [postfix-operators](../../../docs/open-decisions.md#postfix-operators) | Is the postfix decline permanent, or v1-scoped? | Declined for v1, explicitly not foreclosed | **none** |
| [dependent-template-operator-id](../../../docs/open-decisions.md#dependent-template-operator-id) | Fix Clang, or reword U§7.1's "anywhere"? | Reword now; report upstream separately; do not gate the paper on the fix | **none** here |

**Two new slugs**, both named for the question rather than the answer, so they
survive either ruling:

- **`fold-over-user-infix`** — the U§13 fold question, which had no slug at all
  (the prior handoff flagged this) because it is a design-doc question rather
  than a ledger row. It now has an anchor to link to.
- **`dependent-template-operator-id`** — **reused**, not new. The prior
  handoff expected a fresh slug for the "anywhere" re-triage, but the existing
  backlog row
  ([dependent-template-operator-id](../../BACKLOG.md#dependent-template-operator-id))
  already names exactly this question, and the same handoff's stronger rule —
  *"reuse the ledger slug where there is one … so the ledger entry and the
  brief share a name and the brief can be linked to by the same word"* —
  applies. Anchors are per-file, so the two coexist. Neither slug goes in
  [`ops/SLUGS.md`](../../SLUGS.md): that file maps *retired numbers*, and
  neither of these ever had one.

**`ops/BACKLOG.md` §6 rewritten** (the step's fourth gate bullet). It no longer
restates the questions. It is now a list of links into
`docs/open-decisions.md`, one per page, each carrying a link to its ledger row
as well; then the two §6 items that are *not* in the brief with the step that
answers each ([operand-sequencing](../../unicode-operators/clang/DEVIATIONS.md#operand-sequencing)
→ reconcile-declaring-using,
[operator-mangling](../../../docs/unicode-operators.md#operator-mangling) /
[msvc-mangling](../../unicode-operators/clang/DEVIATIONS.md#msvc-mangling) →
mangling-abi); then U§6's worked example, which is a doc sync rather than a
decision → reconcile-remainder. Kept as *links*, per the prior handoff's
warning.

**`ops/BACKLOG.md`'s
[dependent-template-operator-id](../../BACKLOG.md#dependent-template-operator-id)
row** — its `Closed by` field says what actually happened: re-triaged as a
decision by this step, pointing at the brief page, and **still open** until the
author answers. It also records the consequence of the recommendation, which
matters for whoever closes it: on the recommendation this row closes as a
**pair** of steps — the U§7.1 reword is reconcile-declaring-using's and the
upstream report is upstream-triage-shaped work — and neither of them is
implement-decisions. The plan's Coverage table currently assigns the row to
decision-brief alone.

**Nothing else was touched.** In particular no ledger `Status:` was flipped and
no decision-log `Log.` line was appended: those record *rulings*, and there are
none yet.

## Verification evidence

No build and no feature branch, which is what the step file requires.

**Gate bullet 1 — no build, nothing on a feature branch.** `git status` in the
LLVM and GCC worktrees untouched; this agent ran no `ninja` and no `make`.

**Gate bullet 2 — every page has all five parts, no "TBD", no "either is fine".**

```
$ grep -c '^### The question$'      docs/open-decisions.md   -> 5
$ grep -c '^### What was measured$' docs/open-decisions.md   -> 5
$ grep -c '^### The options$'       docs/open-decisions.md   -> 5
$ grep -c '^### The cost of each$'  docs/open-decisions.md   -> 5
$ grep -c '^### Recommendation$'    docs/open-decisions.md   -> 5
$ grep -niE 'TBD|either is fine|either way is|no strong (view|opinion)' docs/open-decisions.md
                                                             -> (no output)
```

Each recommendation names one option by letter and gives its reason in one
paragraph. None of the five is a non-answer.

**Gate bullet 3 — each page names the branches its recommendation would
touch.**

```
$ grep -c '^\*\*Branches touched by the recommendation' docs/open-decisions.md -> 5
```

All five recommendations are "none", which is itself the scoping answer
implement-decisions needs; each line then names the branches the *rejected*
option would have touched, so a reversal is scoped from this document alone
without re-deriving anything.

**Gate bullet 4 — `ops/BACKLOG.md` §6 points at the brief instead of restating
the questions.** Verified by reading: §6 now contains no restatement of any
question, only links.

**Link integrity, repo-wide** — the check the prior handoff recommends
re-running after any ledger edit (walk `](…)`, resolve the path, slugify the
target file's headings, compare), over every tracked `.md` outside
`papers/wg21/`:

```
total local links 1107   broken 0
```

(The one hit the checker reports is `[slug](path)` inside an inline code span
in `slug-the-ledgers.handoff.md` — the prior handoff's own illustration of the
backticked-link failure mode, not a link.) Within the new file alone: **61
links, 0 broken, 0 links inside inline code spans, 0 inside fenced blocks.**

**Source fidelity.** Every "What was measured" section quotes its ledger row
verbatim rather than paraphrasing, per the step file. The postfix page uses
U§13.1's existing numbers (68 lines / one file, four negative tests, 452 lines
across 26 files for the `operator<=>` precedent) and re-derives nothing, also
per the step file.

## Deviations from the plan / design

None that contradict the design; this step touches no compiler and takes no
position that is not marked as a recommendation. Four judgement calls:

1. **The checkbox was left unticked and the handoff BLOCKED on 2026-09-05**,
   although the step file's four gate bullets all passed, because the step
   file's own "After the author answers" section makes recording the answers
   part of this step and `ops/AGENT_PROTOCOL.md` pairs a BLOCKED handoff with
   an unticked box. Ticking then would have erased the only signal that answers
   were outstanding, at the exact moment the plan's critical path depended on
   it. **Resolved 2026-09-06**: the answers landed, the recording is done, and
   the box is ticked by a resumption of *this* step rather than a new one —
   which is what the plan's ground rule and `handoffs/README.md` describe when
   they say a `Decide` step ending BLOCKED on the author has succeeded.
2. **`dependent-template-operator-id` reuses the existing backlog slug**
   rather than taking a new one, contrary to the prior handoff's expectation
   but in line with its stated preference for reusing a ledger slug where one
   exists. Explained above.
3. **A sixth question is *not* raised, though the material invites it.**
   [over-oper-restrictions](../../unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions)
   also waives (c), the not-variadic rule, by the same omission that waived
   (b). It is folded into the two pages as part of the derivation rather than
   given a page: no measurement contradicts it, and no use of the feature
   turns on it. If the author reinstates [over.oper]p8, the variadic rule
   should be reconsidered in the same edit, because the same argument covers
   both.
4. **The `Answers` section at the foot of the brief is a live instruction, not
   filler.** It says where an answer goes (the page, the decision entry's
   `Log.` field, the ledger `Status:`) so the recording is not reinvented.

## Discoveries affecting later steps

- **The stated reason for rejecting static member user operators does not
  survive inspection, and this is new.** The prototype's comment says a static
  member "has no implicit object parameter … so it can name neither form", but
  the arity rule as implemented counts *operands*:
  `NumOperands = NumDeclaredParams + (HasImplicitObjectParam ? 1 : 0)`, so
  `static S operator⊞(S, S)` has `NumOperands == 2` and the arity rule alone
  would accept it. It is rejected only by the explicit `MD->isStatic()` guard
  three lines earlier, which runs first. **The restriction is a choice, not a
  consequence** — which is what makes it a real decision and not a doc fix, and
  it is why the brief supplies a different reason (the desugaring equivalence
  is defined over exactly two spellings, `operator⊞(x, y)` and
  `x.operator⊞(y)`, and a static member names neither;
  `x.operator⊞(y)` on a static member *is* legal C++ but passes one argument
  to a two-parameter function, so it does not mean `⊞(x, y)`).
  reconcile-declaring-using needs this: writing U§7 "Declaring" with the old
  reason would put a falsifiable sentence in the paper.
- **Admitting fold operators is an AST-node change, not a parser change.**
  `CXXFoldExpr` stores its operator as a `BinaryOperatorKind` bitfield
  (`CXXFoldExprBits.Opcode`, read by `getOperator()` at
  `clang/include/clang/AST/ExprCXX.h:5076`), and **32 files** under
  `clang/lib` + `clang/include` name `CXXFoldExpr` — both serialization paths,
  `StmtProfile`, `ASTImporter`, `ItaniumMangle`, `StmtPrinter`,
  `ComputeDependence`, `TreeTransform`, `ExprConstant`, the static analyzer. A
  user operator has no `BinaryOperatorKind`. For **backtick** it is worse than
  a widened enum: the slot is an arbitrary *expression*, and `CXXFoldExpr` has
  three fixed sub-expression slots (`Callee`, `LHS`, `RHS`, `enum SubExpr {
  Callee, LHS, RHS, Count }`) with no room for a fourth. implement-decisions'
  step file budgets U§13-folds as "a parser change over the user-infix level …
  four branches"; that is the *cheap* half, and only if the answer is to keep
  excluding. If the answer ever reverses, it is not one step.
- **The fold exclusion's current form**, for whoever has to preserve it —
  `clang/lib/Parse/ParseExpr.cpp`, `Parser::isFoldOperator`:

  ```cpp
  return Level > prec::Unknown && Level != prec::Conditional &&
         Level != prec::Spaceship && Level != prec::UserInfix;
  ```

  On clean `main` the last clause does not exist, so a replay must **add** it,
  not rename it — `REPLAY.md`'s `U11` row calls this "the single likeliest
  replay mistake in the step", and it fails *silently*, admitting user
  operators as fold operators with no diagnostic anywhere.
- **Six separate handoffs (`U05`, `U11`, `U15`, `U18`, `U19`, `U21`) each
  record that "the design owes the fold decision"**, and U§13 still carries no
  fold bullet. That is the largest unwritten item the brief found: the
  behaviour is decided, tested and stable, and the design document is silent
  on it.
- **U§13 has no fold entry to edit** — the fold question must be *added* to
  U§13, not amended there.
  [infix-parse-cost](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost)'s
  recommended doc change already says so ("or as a U§13 open question if fold
  support is wanted").

## Forward notes for the NEXT step (written after reading its step file)

**Superseded 2026-09-06 — the answers arrived, and implement-decisions is
empty rather than blocked.** It is marked not-applicable in the plan, with the
reason on the checklist line; do not tick it and do not go looking for
something to build in it. Its own step file directs exactly this. Everything
below this paragraph was written while the step was still blocked and still
holds *as the list of what is available*, minus the reason for the wait.

`gcc-resync` has since landed (`a0a1073`), so strike it from the list below.

**What an agent can pick up instead, right now**, all unblocked and none of
them dependent on this:

- **upstream-reports** (dep: none) — the plan wants it early because issue
  numbers take calendar time and mangling-abi wants one.
- **upstream-triage** (dep: none).
- **null-return-suppression** (dep: none).
- ~~**gcc-resync**~~ — **landed 2026-09-06**, `a0a1073`; see
  [gcc-resync](gcc-resync.handoff.md).
- **evidence-debt** (dep: none).

**The answers arrived and are recorded** in that order — brief, then `Log.`
fields, then ledger `Status:` — and the brief's own `Answers` section now
carries a table saying which entry and which row each one landed in. Read that
table rather than re-deriving the mapping.

**Every recommendation was accepted, so implement-decisions is empty** and has
been marked not-applicable, per its own step file: *"Do not tick this box on an
empty step — mark it not-applicable in the plan with a one-line reason, and let
reconcile-declaring-using carry the documentation."* Four of the five answers
are "keep what is built and argue for it"; the fifth is a doc reword plus an
upstream report.

**The documentation work these answers generate lands in three known places**,
so reconcile-declaring-using can pre-read them:

- U§7 "Declaring" — the five [over.oper] restrictions enumerated with which
  survive, the default-argument waiver stated outright, and the static-member
  choice with the two-spellings reason. A new decision entry in
  `docs/unicode-operators.md` §2 is recommended for the static-member choice;
  suggested slug **`static-member-operators`**, named for the question.
- [unary-forms](../../../docs/unicode-operators.md#unary-forms) — its second
  sentence split into its two independent claims (arity selects the form at
  the declaration; position selects it at the use), and one plain sentence
  saying what a postfix attempt actually produces (`expected expression`,
  character-identical to `a +;` — the design currently implies a diagnostic
  that does not exist).
- U§7.1's fourth point — the "anywhere" clause, and U§13 — a fold bullet.

## Open risks / TODOs

- **Cleared 2026-09-06** — this step was the critical path and it is no longer
  blocking anything. reconcile-declaring-using and unicode-paper are unblocked
  as far as this step is concerned; implement-decisions is empty.
- **The `static-member-operators` decision entry is owed and is easy to lose.**
  It is the only *new* document the answers call for, it lives in
  `docs/unicode-operators.md` §2, and it has no ledger row to remind anyone —
  it exists only in the answer to
  [over-oper-restrictions](../../../docs/open-decisions.md#over-oper-restrictions)
  and in that row's `Status:`. reconcile-declaring-using owns it. Name it for
  the question, not the answer, so it survives EWG reversing it.
- **The reason recorded against the static-member rejection has changed, and
  the old reason is still in the prototype's comment.** `SemaDeclCXX.cpp`'s
  `CheckUserOperatorDeclaration` still says a static member "has no implicit
  object parameter … so it can name neither form", which the inspection above
  shows is not what the code does. Nobody owns fixing that comment — it is a
  one-line edit on both Unicode branches and it is *not* worth a step of its
  own, but whichever step next touches that function should correct it, or the
  code will keep asserting a reason the design has abandoned.
- **The plan's Coverage table says decision-brief closes
  [dependent-template-operator-id](../../BACKLOG.md#dependent-template-operator-id).**
  On the recommendation it does not: it closes as a pair
  (reconcile-declaring-using for the reword, upstream-triage-shaped work for
  the report). Whoever accepts the recommendation should fix that row rather
  than leave the table implying a single owner. Recorded in the row's
  `Closed by` field so it is visible where it will be read.
- **`ops/completion/PLAN.md`'s Coverage table also lists this step against
  only that one backlog row**, which understates it: the step's real output is
  five decisions, four of which have no `BNN` row at all because they were
  never defects. Not worth an edit on its own; worth knowing when reading the
  table as a completeness check.
- **`docs/open-decisions.md` is not linked from `CLAUDE.md`'s Layout
  section.** Neither is `docs/unicode-operators.md`, which the plan's
  Housekeeping note already flags for "whichever step first edits that file".
  This step edited neither of those two files, so it did not take the note;
  the next step that edits `docs/unicode-operators.md` should add **both**.
- **Nothing verifies links in CI** — unchanged from the prior handoff, and now
  with 1107 local links in the repo. The check remains four lines of Python
  and is worth a Makefile target.
