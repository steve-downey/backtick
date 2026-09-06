# Handoff — decision-brief — Four open questions, and the "anywhere" claim

- **Status:** **BLOCKED — on the author, which is this step succeeding.** The
  step file's four gate bullets all pass; the brief exists and is complete.
  What is missing is the only thing an agent must not supply: the answers.
- **Branch / commit:** `unicode-operators` in *this* repo only. No feature
  branch touched, no compiler built, nothing landed in any LLVM or GCC
  worktree — correct for this step, which the step file marks "desk work — no
  build, no branch".
- **Date / agent:** 2026-09-05

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

1. **The checkbox is left unticked and the handoff is BLOCKED**, although the
   step file's four gate bullets all pass. The step file's own "After the
   author answers" section makes recording the answers *in
   `docs/open-decisions.md`* part of this step, and `ops/AGENT_PROTOCOL.md`
   pairs a BLOCKED handoff with an unticked box. Ticking now would erase the
   only signal that answers are outstanding, at the exact moment the plan's
   critical path depends on that signal. **The box ticks when the answers land
   in the file** — a resumption of *this* step, not a new one. The plan's
   ground rule and `handoffs/README.md` both say a `Decide` step ending
   BLOCKED on the author has succeeded, and this is that.
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

**The next step is not implement-decisions, and implement-decisions may not
start.** Its "Read first" is explicit: *"`docs/open-decisions.md`, the version
with the author's answers recorded and dated. If it has no answers, stop."* It
has no answers. Do not guess one to have something to build — that is the one
failure mode both the plan's ground rules and `handoffs/README.md` name.

**What an agent can pick up instead, right now**, all unblocked and none of
them dependent on this:

- **upstream-reports** (dep: none) — the plan wants it early because issue
  numbers take calendar time and mangling-abi wants one.
- **upstream-triage** (dep: none).
- **null-return-suppression** (dep: none).
- **gcc-resync** (dep: none) — the plan calls it the most perishable item in
  the whole track.
- **evidence-debt** (dep: none).

**When the answers do arrive**, the recording order is in the brief's
`Answers` section and is worth following exactly: the dated answer goes in
`docs/open-decisions.md`, *then* into the `Log.` field of the implicated entry
in `docs/unicode-operators.md` §2 (rulings and divergences append to the
question's own Log — they do not get a document or a number of their own),
*then* the implicated ledger row's `**Status:**` is marked. Only then does
implement-decisions have a scope.

**If every recommendation is accepted, implement-decisions is empty**, and its
own step file says what to do about that: *"Do not tick this box on an empty
step — mark it not-applicable in the plan with a one-line reason, and let
reconcile-declaring-using carry the documentation."* Expect that outcome; four
of the five recommendations are "keep what is built and argue for it", and the
fifth is a doc reword plus an upstream report.

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

- **This step is the critical path and it is now waiting on a human.** Every
  other Phase-C-and-later item that touches the Unicode paper is downstream of
  it: implement-decisions, reconcile-declaring-using, and unicode-paper. Five
  steps can proceed meanwhile (listed above), and after those the track has
  nothing left that does not want an answer.
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
