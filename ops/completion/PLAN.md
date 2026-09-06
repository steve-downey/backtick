# Completion — Operational Plan (the track that finishes the proposal)

Three implementation tracks are complete — Clang backtick `S00`–`S12`, GCC
backtick `G01`–`G10`, Clang Unicode `U00`–`U21` — and a fourth,
`ops/backlog/PLAN.md`, closed the four defects that most needed a compiler.
What is left is not more implementation. It is **making the two papers say
what the implementation actually established, and making every claim in them
checkable.**

This plan covers *all* of it: 31 open `BNN` rows, 29 unreconciled deviation
rows, 7 open design decisions, and the two papers themselves. Nothing in
`ops/` is outside it.

## Why this is not ordered by severity

`ops/BACKLOG.md` §7 orders the defects by how badly they hurt, and
`ops/backlog/PLAN.md` scheduled the top of that list. That was the right
order while the question was "which defect most damages the prototype". It is
the wrong order now, because the prototype is done and the remaining question
is different: **which of these changes a paper?**

So every item below is placed by what it does to a paper, and the phases are
four questions asked in order:

1. **What must be decided before anything can be written?** Seven questions
   are open, four of them with implementation consequences. Deciding them
   late means implementing twice and writing twice. This is the critical
   path and it was in no plan at all.
2. **What does a paper currently say that is false?** Paper-truth defects.
   [`type-slot-implementation`](../BACKLOG.md#type-slot-implementation) was the last one anybody had scheduled; there are more.
3. **What did the implementation learn that no paper says?** 29 deviation
   rows, of which the Unicode ledger's 24 have *never* been reconciled. This
   is the largest single body of remaining work and the most perishable —
   every row was written by an agent who is gone.
4. **What does a paper claim to have measured that was not measured?**
   Evidence debt: unbuilt hunks, untestable branches, tables that cannot be
   regenerated.

Two bodies of work gate nothing and can run at any time: **upstream
citizenship** (defects that are LLVM's, not ours) and **hygiene** (dead code,
cosmetics, parity gaps with no paper consequence). Upstream is placed *first*
anyway, because a paper that says "we found a Clang bug" is stronger when it
can cite the issue number, and issues take calendar time to be triaged.

## How to use this plan
1. Read `ops/AGENT_PROTOCOL.md`. Substitute for this track: plan → *this
   file*; step files → `ops/completion/steps/CNN-*.md`; handoffs →
   `ops/completion/handoffs/CNN-<slug>.handoff.md`; deviations → the ledger of
   whichever track the step touched.
2. Find the first unchecked step whose dependencies are all checked.
3. Execute only that step. Then stop.

## Ground rules

The four from `ops/backlog/PLAN.md` still hold — one step per agent, no green
no check, everything gated behind `-fbacktick` / `-funicode-operators`,
minimal diffs — plus four that are specific to this track:

- **A docs step has a gate too.** It is not `check-clang`; it is that every
  row the step claims to close is *marked* closed in its ledger, with the
  section and paragraph it landed in named. A reconciliation that cannot say
  where it went did not happen.
- **Mark the ledger, not just the doc.** Every deviation entry carries a
  `**Status:**` line: `OPEN` until a step reconciles it, then the
  `**RECONCILED**` / `**RESOLVED**` / `**FIXED**` marker `ops/DEVIATIONS.md`
  and `ops/gcc/DEVIATIONS.md` already use in their prose.
  `ops/unicode-operators/clang/DEVIATIONS.md` has never marked a row and its
  24 entries are all `OPEN`; it uses the same field and the same words.
- **Decisions are the author's.** A `Decide` step produces options, costs and
  a recommendation. It does not choose. It ends by asking, and the next step
  is blocked until it is answered — that is a legitimate BLOCKED handoff, not
  a failure.
- **Everything new is named, not numbered.** Steps, decisions, questions and
  defects get slugs — short kebab-case names for the question or the job,
  never for the answer, so a slug survives its own conclusion reversing. The
  ordinals in the checklist are reading order only; cross-reference by slug.
  See `~/.claude/CLAUDE.md`, "Name things for what they are, not what number
  they came in at", and [slug-the-ledgers](steps/slug-the-ledgers.md), which
  retired the numbers this repo used to have.

  This is now a rule for **anything a step adds**, not only for what that step
  renamed. A new decision, a new deviation row, a new backlog entry: give it a
  section headed by its slug in the ledger that owns it, so the slug is a
  Markdown anchor, and make every reference to it a **link** to that anchor —
  links can be followed, and a rename becomes a detectable break instead of a
  silent one. Add the pair to [`ops/SLUGS.md`](../SLUGS.md) only if you are
  retiring a number; a slug that never had one needs no row there.

Commit prefixes: `[backtick] <slug>: …` / `[unicode] <slug>: …` on the feature
branches, `docs: …` for design-doc and paper edits, `ops: <slug> — …` for
bookkeeping here.

## What this plan absorbs

`ops/backlog/PLAN.md` is **superseded, not deleted.** Its BL01–BL04 are green
and their handoffs are the record. Its three unstarted steps have good step
files, and this plan reuses them rather than restating them:

| Old | New home |
|---|---|
| `BL05` ([`increment-decrement-mangling`](../BACKLOG.md#increment-decrement-mangling)) | **upstream-reports** — executes `steps/BL05-upstream-mangling.md` unchanged |
| `BL06` ([c-mode-tokenization](../BACKLOG.md#c-mode-tokenization) [backtick-source-range](../BACKLOG.md#backtick-source-range) [dead-nesting-diagnostic](../BACKLOG.md#dead-nesting-diagnostic) [template-ast-print-test](../BACKLOG.md#template-ast-print-test) [libclang-cursor-arm](../BACKLOG.md#libclang-cursor-arm)) | split by purpose: [c-mode-tokenization](../BACKLOG.md#c-mode-tokenization) [backtick-source-range](../BACKLOG.md#backtick-source-range) → **clang-paper-truth**, [`template-ast-print-test`](../BACKLOG.md#template-ast-print-test) → **gcc-resync**, [dead-nesting-diagnostic](../BACKLOG.md#dead-nesting-diagnostic) [libclang-cursor-arm](../BACKLOG.md#libclang-cursor-arm) → **reconcile-remainder** |
| `BL07` ([lldb-hunk-verification](../BACKLOG.md#lldb-hunk-verification) [code-completion-priority](../BACKLOG.md#code-completion-priority) [ucd-input-manifest](../BACKLOG.md#ucd-input-manifest)) | **gcc-resync**, whose step file supersedes `BL07`'s |
| `M2` | unchanged, still in `ops/unicode-operators/clang/PLAN.md` Phase G; runs after **clang-paper-truth** |

`BL06`'s five rows are the clearest case of the old ordering: they were one
step because they sit on one branch, and they are five unrelated jobs — a
correctness bug that makes C accept C++ grammar, a source-range defect, dead
code, a missing test, and a `-Wswitch` warning. Batching by branch is a real
economy and this plan keeps it *within* a purpose, not across purposes.

## Branches, worktrees, build dirs

Unchanged from `ops/backlog/PLAN.md`, plus one:

| Track | Branch | Worktree | Build dir |
|---|---|---|---|
| backtick | `backtick-trunk` | `~/src/llvm/backtick-trunk` | `~/src/llvm/build-backtick-trunk` |
| backtick | `backtick-23` | `~/src/llvm/backtick` | `~/src/llvm/build-backtick` |
| unicode | `unicode-operators-experiment` | `~/src/llvm/unicode` | `~/src/llvm/build-unicode` |
| unicode | `unicode-operators-upstream` | `~/src/llvm/unicode-upstream` | `~/src/llvm/build-unicode-upstream` |
| GCC | `backtick` | `~/bld/gcc/gcc-backtick` | `~/bld/gcc/gcc-backtick-build` |
| *scratch* | — | `~/src/llvm/unicode` | `~/src/llvm/build-cir-scratch` (MLIR + CIR, **standing**) |

`~/src/llvm/main` / `~/src/llvm/build-main` is the maintainer's pristine pair.
Do not build in it. *Running* its binaries is fine and is how BL04 proved the
`DirectoryWatcherTest` failures were environmental.

**The CIR scratch dir survives BL04 and is reusable.** gcc-resync needs lldb; add
`lldb` to that configure rather than standing up a second tree.

## Gate facts

All of `ops/backlog/PLAN.md`'s "Gate facts" section still applies and is not
restated here — read it. Two updates:

- **[`inotify-watch-budget`](../BACKLOG.md#inotify-watch-budget) is reopened and is an environment condition, not a defect to fix.**
  `cloud-drive-dae` is the machine's continuous backup, so watching every file
  is its job and its hoard tracks the tree size; it grew from ~65k to 523,774
  of the raised 524288. 524288 is a better ceiling than the 65536 default, not
  a guarantee. The 8 `DirectoryWatcherTest.*` cases are the only thing in
  `check-clang` competing for free watches. **Never filter them, never budget
  them as expected failures** — and a gate whose *only* failures are those 8 is
  an environment reading. Confirm with the pristine `build-main` binary.
- **Enabling CIR moves the counts by more than the CIR directory**: +44
  discovered (`CIRUnitTests`), −888 unsupported, +932 passed, the last term
  including `Frontend/cir-not-built.c` going the other way. BL04's handoff has
  the full arithmetic.
- **`Parser::isFoldOperator`'s `Level != prec::UserInfix` clause is a standing
  guard on all four Clang branches, and losing it fails silently.** Dropping
  it admits a user-introduced infix operator as a fold operator — no
  diagnostic, no test failure unless the negative test is present, and a
  behaviour change to `(... ⊞ N)` and `` (... `f` N) ``, both of which are
  deliberately ill-formed
  ([fold-over-user-infix](../../docs/open-decisions.md#fold-over-user-infix),
  answered 2026-09-06). **A replay onto clean `main` must *add* the clause,
  not rename one** — on `main` the predicate ends at `prec::Spaceship`.
  Check it after every rebase and every replay, on `backtick-trunk`,
  `backtick-23`, `unicode-operators-experiment` and
  `unicode-operators-upstream`; `REPLAY.md`'s `U11` row calls it the single
  likeliest replay mistake in that step. The negative tests that pin it are
  `clang/test/Parser/unicode-operator-precedence.cpp` section 9 and its
  backtick twin — do not delete them as redundant.

## Baselines

`ops/backlog/PLAN.md`'s table, as BL04 updated it: `backtick-trunk`
54108/48222/**0**, `backtick-23` 54342/48500/**1** ([`stray-clang-format-config`](../BACKLOG.md#stray-clang-format-config)),
`unicode-operators-experiment` 54183/48295/**0**,
`unicode-operators-upstream` 54241/48323/**0**; XFAIL 27 and skipped 6
throughout. Steps that add a test update that table in *this* file's Status
log and leave the old plan's alone.

## Checklist

Each line carries an **ordinal and a slug**. The ordinal is reading order and
shifts whenever a step is inserted or split; **the slug is the identity, and
every cross-reference in this repo uses it.** Never write "step 7".

Three box states: `[ ]` unstarted, `[x]` green and gated, and **`[—]`
not-applicable** — a step whose scope turned out to be empty, with the reason
on the line. `[—]` is deliberately not `[ ]`: an agent looking for "the first
unchecked step whose dependencies are checked" must skip it rather than go
hunting for work in it, and it is deliberately not `[x]` either, because
nothing was done and no gate was run.

### Phase A — Naming (first, so nothing downstream is written twice)
- [x] 1. [slug-the-ledgers](steps/slug-the-ledgers.md) — retire the serial numbers in the two decision logs, the three deviation ledgers and the backlog in favour of slugs; [`ops/SLUGS.md`](../SLUGS.md) is the map (dep: none)

### Phase B — Upstream citizenship (no dependencies; early because issues take calendar time)
- [x] 2. [upstream-reports](steps/upstream-reports.md) — file the three upstream defects (dep: none) — **green as amended, 2026-09-06. The author decided the step drafts the reports and does not file them**, so its "three issue URLs" gate bullet was removed by the person who owns the plan rather than failed by the agent; everything else in the gate passed. The three reports are written out ready to post in [`upstream-drafts/`](upstream-drafts/README.md). **The three backlog rows stay open** — each `Closed by` says "drafted, pending the maintainer filing it" — and there is no issue number for anything to cite. Ticked so the next agent does not redo the confirmation work; do not read it as "the defects are reported".
- [x] 3. [upstream-triage](steps/upstream-triage.md) — report-or-WONTFIX the five annoyances (dep: none) — **green on its own gate, 2026-09-06, with the same amendment as upstream-reports: draft, do not file.** All five rows are triaged and have reasoned `Closed by` cells. **Two genuinely close** — [`inner-call-source-range`](../BACKLOG.md#inner-call-source-range) and [`operator-caret-range`](../BACKLOG.md#operator-caret-range), both WONTFIX with the reason recorded in the row *and* in a design doc, so the papers answer the question rather than being asked it. **Three stay open pending the maintainer filing them**: [`cxxfilt-stdin-nonascii`](../BACKLOG.md#cxxfilt-stdin-nonascii), [`auto-return-round-trip`](../BACKLOG.md#auto-return-round-trip), [`pch-ast-print-order`](../BACKLOG.md#pch-ast-print-order), drafted in [`upstream-drafts/`](upstream-drafts/README.md). **The sixth item this step was given — the report half of [`dependent-template-operator-id`](../BACKLOG.md#dependent-template-operator-id) — was NOT done and has no draft**, because the literal-operator reproducer it was to be filed against is *correctly* rejected and the report would be wrong; the question is reopened for the author in [`docs/open-decisions.md`](../../docs/open-decisions.md#2026-09-06--dependent-template-operator-id-the-report-half-is-reopened). Do not read this tick as "the six are reported".

### Phase C — Decide (the author's, and the critical path for everything written)
- [x] 4. [decision-brief](steps/decision-brief.md) — the four questions with implementation consequences, and the "anywhere" claim (dep: none) — brief at [`docs/open-decisions.md`](../../docs/open-decisions.md); **answered 2026-09-06, all five recommendations accepted, and the answers are recorded there.** Nothing turned into code: see implement-decisions below.
- [x] 5. [mangling-abi](steps/mangling-abi.md) — the ABI question, and U§9 with it (dep: upstream-reports ✔ *as amended*, slug-the-ledgers ✔) — **unblocked, but the thing it wanted upstream-reports for does not exist**: the `pp_`/`pp` report is drafted and unfiled, so there is no issue number to cite. Write around the placeholder token `LLVM-ISSUE-PENDING`; do not invent a number and do not wait for one. — **U§9 is written and two of its three parts are settled; the third is BLOCKED on the author, 2026-09-06.** [mangling-derivation-rule](../../docs/unicode-operators.md#mangling-derivation-rule) and [microsoft-abi-position](../../docs/unicode-operators.md#microsoft-abi-position) reconcile [`vendor-extended-mangling`](../unicode-operators/clang/DEVIATIONS.md#vendor-extended-mangling) and [`msvc-mangling`](../unicode-operators/clang/DEVIATIONS.md#msvc-mangling) and close [`astral-plane-mangling`](../BACKLOG.md#astral-plane-mangling); [`postfix-operators`](../unicode-operators/clang/DEVIATIONS.md#postfix-operators)'s mangling clause is taken. **Answered 2026-09-06 — the recommendation accepted as written**, so the box is ticked: [abi-production-request](../../docs/unicode-operators.md#abi-production-request) now records *(a) and (b) together, non-normatively* — the vendor form as the fallback that needs no ABI action, plus a first-class production asked for as a **request**, with `s` reserved so postfix stays takeable. Same shape as [decision-brief](steps/decision-brief.md): BLOCKED on the author from writing to answer, then green.

### Phase D — Make the papers true
- [ ] 6. [clang-paper-truth](steps/clang-paper-truth.md) — the three Clang defects that falsify a claim (dep: decision-brief)
- [ ] 7. [null-return-suppression](steps/null-return-suppression.md) — the analyzer parity break, on all four branches (dep: none)
- [—] 8. [implement-decisions](steps/implement-decisions.md) — build whatever decision-brief decided (dep: decision-brief; scope contingent) — **NOT APPLICABLE: decision-brief was answered 2026-09-06 and all five answers are "keep what is built and argue for it", so this step has an empty scope.** Not ticked, per its own step file's "If the answer was 'no change'"; the documentation those answers generate belongs to [reconcile-declaring-using](steps/reconcile-declaring-using.md), [reconcile-remainder](steps/reconcile-remainder.md) and [upstream-triage](steps/upstream-triage.md).
- [x] 9. [gcc-resync](steps/gcc-resync.md) — re-sync GCC to current trunk, then its four open defects (dep: none)

### Phase E — Discharge the evidence debt
- [ ] 10. [evidence-debt](steps/evidence-debt.md) — the unbuilt hunk, the unwritten test, the unregenerable table (dep: none; supersedes `BL07`)

### Phase F — Reconcile, one destination section per step
- [ ] 11. [reconcile-implementation-cost](steps/reconcile-implementation-cost.md) — U§8, the implementation-cost thesis (dep: evidence-debt, slug-the-ledgers)
- [ ] 12. [reconcile-declaring-using](steps/reconcile-declaring-using.md) — U§7 / §7.1, declaring, using, desugaring (dep: decision-brief ✔, implement-decisions **[—] n/a — satisfied**, slug-the-ledgers ✔) — **all dependencies met; this step is unblocked.** It now also owes the `static-member-operators` decision entry (see [`docs/open-decisions.md`](../../docs/open-decisions.md)).
- [ ] 13. [reconcile-remainder](steps/reconcile-remainder.md) — U§5 / §10 / §6 / §12 / §13, and the backtick and GCC ledgers (dep: gcc-resync, slug-the-ledgers)

### Phase G — Hygiene (no paper consequence; any time after its branches settle)
- [ ] 14. [hygiene-parity](steps/hygiene-parity.md) — the tooling-parity gaps, the dead code, the formatting limit (dep: clang-paper-truth)

### Phase H — The papers
- [ ] 15. [backtick-paper](steps/backtick-paper.md) — D4307R0 and its blog version (dep: clang-paper-truth, reconcile-remainder, hygiene-parity)
- [ ] 16. [unicode-paper](steps/unicode-paper.md) — the Unicode paper, a real number, and its blog version (dep: mangling-abi, implement-decisions **[—] n/a — satisfied**, reconcile-implementation-cost, reconcile-declaring-using, reconcile-remainder)

### Maintenance (not plan steps)
- **M2** — forward-port `BL02` + clang-paper-truth's backtick fixes to `unicode-operators-experiment`. Runs after **clang-paper-truth**. Note that BL04 already put CIR arms on `backtick-trunk` that the experiment branch has too; expect a trivial conflict in the shared lead comment, not a semantic one.
- **[inotify-watch-budget](../BACKLOG.md#inotify-watch-budget)** — needs root, and is the maintainer's. Not an agent step.
- **Housekeeping — done, 2026-09-06.** `CLAUDE.md`'s Layout section named
  neither `docs/unicode-operators.md` nor `docs/open-decisions.md`;
  [mangling-abi](steps/mangling-abi.md) added the second and extended the
  first's ABI clause, having declined to leave it to a fourth step.

## The critical path, and what is parallel

```
slug-the-ledgers ──> mangling-abi and every reconcile-*

upstream-reports ──> mangling-abi ──────────────────────────────┐
decision-brief ─┬─> implement-decisions ─> reconcile-declaring-using ─┐         │
                └─> clang-paper-truth ─> hygiene-parity ─┐           ├──> unicode-paper
gcc-resync ───────> reconcile-remainder ────────────────┼───────────┘
                                                        └──> backtick-paper
evidence-debt ────> reconcile-implementation-cost ──────────────────────┘

upstream-triage, null-return-suppression  — independent of everything
```

**slug-the-ledgers goes first** because every step after it edits documents
dense with `BNN` and `DEV-NN` references; renaming afterwards means touching
the same paragraphs twice, and the second pass is the one that gets skipped.
**decision-brief is the one thing that blocks the most**, and it is desk work: seven
questions that are already measured, needing options and a recommendation.
Start there if only one agent is available. **gcc-resync was the most perishable** and is
done — the branch is on trunk `4df5e1e9b152` (2026-09-06). **upstream-triage and null-return-suppression are independent of
everything** and are the right work for a spare agent.

## Coverage — every open item has a home

31 open `BNN` rows (37 + [`clangir-lvalue-crash`](../BACKLOG.md#clangir-lvalue-crash), less the 7 closed by `BL01`–`BL04`):

| Step | Rows |
|---|---|
| upstream-reports | [`increment-decrement-mangling`](../BACKLOG.md#increment-decrement-mangling) [`unqualified-id-union-read`](../BACKLOG.md#unqualified-id-union-read) [`clangir-lvalue-crash`](../BACKLOG.md#clangir-lvalue-crash) |
| upstream-triage | [`inner-call-source-range`](../BACKLOG.md#inner-call-source-range) [`cxxfilt-stdin-nonascii`](../BACKLOG.md#cxxfilt-stdin-nonascii) [`auto-return-round-trip`](../BACKLOG.md#auto-return-round-trip) [`pch-ast-print-order`](../BACKLOG.md#pch-ast-print-order) [`operator-caret-range`](../BACKLOG.md#operator-caret-range) |
| decision-brief | none, as it turns out — it *answers* [`dependent-template-operator-id`](../BACKLOG.md#dependent-template-operator-id) and closes none of it. Its real output is five decisions, four of which never had a `BNN` row because they were never defects. |
| reconcile-declaring-using | [`dependent-template-operator-id`](../BACKLOG.md#dependent-template-operator-id), U§7.1 reword half (decided (c) on 2026-09-06) |
| upstream-triage (2nd) | [`dependent-template-operator-id`](../BACKLOG.md#dependent-template-operator-id), upstream-report half — **not done, and back with the author.** The literal-operator reproducer it was to be filed against is correctly rejected (a literal operator can never be a class member, [over.literal]/1, and trunk says so at the site), so the report would be wrong and none was drafted. See [the reopening](../../docs/open-decisions.md#2026-09-06--dependent-template-operator-id-the-report-half-is-reopened); the reword half is unaffected and is still reconcile-declaring-using's |
| mangling-abi | [`astral-plane-mangling`](../BACKLOG.md#astral-plane-mangling) |
| clang-paper-truth | [`keyword-escape-round-trip`](../BACKLOG.md#keyword-escape-round-trip) [`c-mode-tokenization`](../BACKLOG.md#c-mode-tokenization) [`backtick-source-range`](../BACKLOG.md#backtick-source-range) |
| null-return-suppression | [`null-return-suppression`](../BACKLOG.md#null-return-suppression) |
| gcc-resync | [`template-id-slot-adl`](../BACKLOG.md#template-id-slot-adl) [`module-streaming-escapes`](../BACKLOG.md#module-streaming-escapes) [`grokdeclarator-guard-scope`](../BACKLOG.md#grokdeclarator-guard-scope) [`gcc-wrapper-parity`](../BACKLOG.md#gcc-wrapper-parity) [`gcc-trunk-pin`](../BACKLOG.md#gcc-trunk-pin) |
| evidence-debt | [`template-ast-print-test`](../BACKLOG.md#template-ast-print-test) [`lldb-hunk-verification`](../BACKLOG.md#lldb-hunk-verification) [`code-completion-priority`](../BACKLOG.md#code-completion-priority) [`ucd-input-manifest`](../BACKLOG.md#ucd-input-manifest) |
| reconcile-implementation-cost | [`matcher-operator-name`](../BACKLOG.md#matcher-operator-name) (recorded as designed, and as evidence) |
| hygiene-parity | [`backtick-ast-matchers`](../BACKLOG.md#backtick-ast-matchers) [`dead-nesting-diagnostic`](../BACKLOG.md#dead-nesting-diagnostic) [`slot-split-penalty`](../BACKLOG.md#slot-split-penalty) [`libclang-cursor-arm`](../BACKLOG.md#libclang-cursor-arm), and [`template-id-code-point`](../BACKLOG.md#template-id-code-point) [`confusable-spellings`](../BACKLOG.md#confusable-spellings) recorded |
| slug-the-ledgers | none directly — it renames every row above, and `ops/SLUGS.md` is the map |
| — | [`inotify-watch-budget`](../BACKLOG.md#inotify-watch-budget), maintainer's, needs root |

29 open deviation rows, written out in full so a grep for one finds its step:

| Step | Rows |
|---|---|
| mangling-abi | [`vendor-extended-mangling`](../unicode-operators/clang/DEVIATIONS.md#vendor-extended-mangling) [`msvc-mangling`](../unicode-operators/clang/DEVIATIONS.md#msvc-mangling) [`postfix-operators`](../unicode-operators/clang/DEVIATIONS.md#postfix-operators) (mangling clause) |
| reconcile-implementation-cost | [`declaration-name-plumbing`](../unicode-operators/clang/DEVIATIONS.md#declaration-name-plumbing) [`declaring-side-parse-cost`](../unicode-operators/clang/DEVIATIONS.md#declaring-side-parse-cost) [`flag-language-mode`](../unicode-operators/clang/DEVIATIONS.md#flag-language-mode) [`operator-candidate-assembly`](../unicode-operators/clang/DEVIATIONS.md#operator-candidate-assembly) [`expression-node-cost`](../unicode-operators/clang/DEVIATIONS.md#expression-node-cost) [`serialization-tooling-cost`](../unicode-operators/clang/DEVIATIONS.md#serialization-tooling-cost) [`ast-node-shape`](../unicode-operators/clang/DEVIATIONS.md#ast-node-shape) [`codegen-dispatch-sites`](../unicode-operators/clang/DEVIATIONS.md#codegen-dispatch-sites) |
| reconcile-declaring-using | [`ucd-version-drift`](../unicode-operators/clang/DEVIATIONS.md#ucd-version-drift) [`disjointness-evidence`](../unicode-operators/clang/DEVIATIONS.md#disjointness-evidence) [`over-oper-restrictions`](../unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions) [`operator-id-anywhere`](../unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere) [`infix-parse-cost`](../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost) [`prefix-arity-selection`](../unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection) [`operand-sequencing`](../unicode-operators/clang/DEVIATIONS.md#operand-sequencing) |
| reconcile-remainder | [`exclusion-list-derivation`](../unicode-operators/clang/DEVIATIONS.md#exclusion-list-derivation) [`ucn-operator-spellings`](../unicode-operators/clang/DEVIATIONS.md#ucn-operator-spellings) [`exclusion-diagnostics`](../unicode-operators/clang/DEVIATIONS.md#exclusion-diagnostics) [`clang-format-user-operators`](../unicode-operators/clang/DEVIATIONS.md#clang-format-user-operators) [`feature-coupling`](../unicode-operators/clang/DEVIATIONS.md#feature-coupling) [`replay-ordering`](../unicode-operators/clang/DEVIATIONS.md#replay-ordering); [`wrapper-inner-shape`](../DEVIATIONS.md#wrapper-inner-shape) [`analysis-layer-sites`](../DEVIATIONS.md#analysis-layer-sites) [`type-slot-cost`](../DEVIATIONS.md#type-slot-cost) [`cir-backtick-arms`](../DEVIATIONS.md#cir-backtick-arms); [`gcc-type-slot-parity`](../gcc/DEVIATIONS.md#gcc-type-slot-parity) |

[`prefix-arity-selection`](../unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection) and [`operand-sequencing`](../unicode-operators/clang/DEVIATIONS.md#operand-sequencing) are decided by decision-brief and *written* by reconcile-declaring-using — a decision
and its documentation are different steps, and implement-decisions owns only the ones that
turn into code. [`postfix-operators`](../unicode-operators/clang/DEVIATIONS.md#postfix-operators) is split: its mangling clause is mangling-abi's, its postfix
substance is decision-brief's.

7 design decisions: four in decision-brief, the ABI in mangling-abi, U§6's example in reconcile-remainder, and
[`operand-sequencing`](../unicode-operators/clang/DEVIATIONS.md#operand-sequencing) recorded in reconcile-declaring-using as the CWG question it is.

**decision-brief's four were answered on 2026-09-06** — with a fifth, the
"anywhere" re-triage — and all five accepted the recommendation, which was
"change no code" in every case. See [`docs/open-decisions.md`](../../docs/open-decisions.md).
The consequence for this plan is that **implement-decisions has an empty scope
and is marked not-applicable**, and the work moves to the reconcile steps:
U§7 "Declaring" and U§7.1 to reconcile-declaring-using (with a new decision
entry owed, suggested slug `static-member-operators`), U§13's missing fold
bullet and U§13.1's treatment to reconcile-remainder, and one upstream report
to upstream-triage.

## Status log (each agent appends one row per branch or per document)
| Step | Date | Branch / doc | Commit | Gate result | Handoff |
|------|------|--------------|--------|-------------|---------|
| slug-the-ledgers | 2026-09-05 | `docs/backtick-operator-design.md` §3, `docs/unicode-operators.md` §2 | no branch — this repo only. 16 + 12 decisions converted from table rows to slug-headed sections with the full **Question / Status / Decision / Why / Log** shape plus `Decided by`; `Formerly:` keeps the old number. Two `Decision` cells were topics rather than decisions (`D2`, `D8`) and were restated. | **PASS** — every entry is an anchor, and every link into these two logs resolves (1029 local links checked, 1007 anchored, 0 broken). | [slug-the-ledgers](handoffs/slug-the-ledgers.handoff.md) |
| slug-the-ledgers | 2026-09-05 | `ops/DEVIATIONS.md`, `ops/gcc/DEVIATIONS.md`, `ops/unicode-operators/clang/DEVIATIONS.md` | 9 + 7 + 24 rows converted to slug-headed sections. Every entry now carries a `**Status:**` field; the Unicode ledger's 24 are all `OPEN`, which is accurate — it has never marked a row. | **PASS** — 40 entries, 40 anchors, 0 collisions. | same |
| slug-the-ledgers | 2026-09-05 | `ops/BACKLOG.md`, `ops/SLUGS.md` (new) | 38 defect rows converted to slug-headed sections keeping `Severity` / `Item` / `Where` / `Closed by`. `ops/SLUGS.md` maps all **106** retired identifiers both directions and records what was deliberately *not* renamed. | **PASS** — 106 mappings, both directions, every one resolving to a live anchor. | same |
| slug-the-ledgers | 2026-09-05 | cross-reference sweep: both papers, `ops/completion/**`, `ops/backlog/steps/BL05`–`BL07`, `CLAUDE.md`, `ops/AGENT_PROTOCOL.md`, `ops/HANDOFF_TEMPLATE.md` | 792 bare mentions rewritten as links to anchors; 19 internal identifiers **removed** from `papers/d4307r0.md` / `papers/dxxxxr0.md` rather than renamed, per the public-text rule. Protocol and ground rules now require slugs for anything added later. | **PASS** — the three gate greps are clean over `docs/`, `papers/`, `ops/*.md`, `ops/completion/` except `ops/SLUGS.md` (the map) and `steps/slug-the-ledgers.md` (the step's own quotation of what it retired); papers cite no identifier at all. | same |
| decision-brief | 2026-09-05 | `docs/open-decisions.md` (new), `ops/BACKLOG.md` §6 and its [dependent-template-operator-id](../BACKLOG.md#dependent-template-operator-id) row | no branch — this repo only. Five decision pages, each headed by its slug, each with the five required parts and an explicit *Branches touched* line; a summary table of question / recommendation / implementation consequence. Two slugs added — `fold-over-user-infix` (new; U§13's fold question had none) and `dependent-template-operator-id` (reused from the backlog row, per the prior handoff's reuse rule). §6 rewritten as links into the brief. | **PASS on all four gate bullets** — 5×5 required sections present, no `TBD` and no non-answer, every recommendation names its branches (all five are "none"; each rejected option names what it would touch), §6 restates nothing. Links: 61 in the new file, 0 broken; 1107 repo-wide, 0 broken. **PASS, then BLOCKED on the author** — no answer at that point, so no box ticked, no ledger `Status:` flipped and no decision `Log.` line appended. Unblocked 2026-09-06; see the next row. | [decision-brief](handoffs/decision-brief.handoff.md) |
| gcc-resync | 2026-09-06 | `backtick` (GCC), the re-sync | **not a plan step** — a rebase, treated as the R-prefixed Clang ones were. `c9ee2c5ab6c` (Daily bump, 2026-06-24) → `4df5e1e9b152` (Daily bump, 2026-09-06); 2158 upstream commits absorbed, 177 of them touching `gcc/cp`, `gcc/c-family` or `libcpp`. Ten feature commits replayed conflict-free; branch tip `b842ac1ed64` → `b50102ca0f6`. Pre-rebase tag `backtick-pre-resync` kept locally. | **PASS, and neutral**: `dg.exp=g++.dg/backtick/*.C` **88 passes / 0 failures** before the rebase and **88 / 0** after it, `EXIT=0` both times — the number G10 recorded. The feature diff's `+`/`−` lines are **byte-identical** across the move (`diff <(git diff c9ee2c5ab6c..pre) <(git diff 4df5e1e9b152..post)` differs only in blob hashes, hunk offsets and context). Closes [gcc-trunk-pin](../BACKLOG.md#gcc-trunk-pin). | [gcc-resync](handoffs/gcc-resync.handoff.md) |
| gcc-resync | 2026-09-06 | `backtick` (GCC), `edce709e170` | ADL for a template-id operator slot: `cp_parser_backtick_template_id_slot` in `gcc/cp/parser.cc`, used at both handler sites, plus `g++.dg/backtick/infix-adl-template-id.C`. Closes [template-id-slot-adl](../BACKLOG.md#template-id-slot-adl); new ledger row [gcc-template-id-slot-adl](../gcc/DEVIATIONS.md#gcc-template-id-slot-adl). | **PASS**: 88 → **94 passes / 0 failures**, the 6 being the new test (1 compile + 5 scan-tree-dump). Verified failing first — on the pre-fix binary `` ax `g<int>` ay `` gave *"'g' was not declared in this scope"*, *"expected primary-expression before 'int'"* and *"expected '`' before 'int'"*; after, the dump reads `r_pure = ns::g<int> (…)` and `r_augment = ns2::h<int> (…)`. | same |
| gcc-resync | 2026-09-06 | `backtick` (GCC), `daf5fa6feb0` | Module streaming of keyword-escaped names, **verified not broken**: `g++.dg/modules/backtick-escape-1_a.C` / `_b.C`. No production change. Closes [module-streaming-escapes](../BACKLOG.md#module-streaming-escapes). | **PASS**: `modules.exp=backtick-escape-1*` → **15 passes / 0 failures** (5 checks × 3 std variants), including the CMI being produced and both mangled names appearing in the importer's assembly. | same |
| gcc-resync | 2026-09-06 | `backtick` (GCC), `12d3b5b0c07` | Three over-permissive `flag_backtick` guards narrowed: the escape is now carried on the `cp_declarator` and required by `grokdeclarator`, and both `case CPP_BACKTICK:` arms re-test the token because other cases fall through to them. 5 files. Closes [grokdeclarator-guard-scope](../BACKLOG.md#grokdeclarator-guard-scope); new ledger row [escape-arm-entry-token](../gcc/DEVIATIONS.md#escape-arm-entry-token). | **PASS**: 94 → **103 passes / 0 failures**, `EXIT=0`; the 9 are three new `dg-error` checks × 3 variants in `escape-diag.C`. `void new (int, int);` and a stray `^` now diagnose **character-identically with and without `-fbacktick`**, which they did not before. Wider sweep, all **0 unexpected failures**: `g++.dg/parse` 4905, `lookup` 3437, `template` 9874, `overload` 692, `init` 3632, `expr` 952. | same |
| gcc-resync | 2026-09-06 | `docs/backtick-operator-design.md` §17.3 / §17.4, `ops/gcc/DEVIATIONS.md`, `ops/BACKLOG.md`, `ops/gcc/PLAN.md`, `CLAUDE.md` | §17.4 rewritten (ADL binds wherever the slot is an unqualified name, with or without template arguments; both compilers now deliver it and agree). §17.3 gains a status paragraph naming the one place the two implementations accept different programs. Ledger: [gcc-type-slot-parity](../gcc/DEVIATIONS.md#gcc-type-slot-parity) **RECONCILED**, [gcc-slot-adl](../gcc/DEVIATIONS.md#gcc-slot-adl) corrected to **RESOLVED** (its prose already said G10 fixed it), and three new entries — [gcc-template-id-slot-adl](../gcc/DEVIATIONS.md#gcc-template-id-slot-adl), [escape-arm-entry-token](../gcc/DEVIATIONS.md#escape-arm-entry-token), [gcc-wrapper-parity](../gcc/DEVIATIONS.md#gcc-wrapper-parity). Five `Closed by` cells filled. | **PASS on the docs gate**: every row this step claims is marked in its ledger and names the section *and* paragraph it landed in; the GCC ledger has **no `Status: OPEN` row left**. | same |
| decision-brief | 2026-09-06 | `docs/open-decisions.md`; `docs/unicode-operators.md` §2 and `docs/backtick-operator-design.md` §3; `ops/unicode-operators/clang/DEVIATIONS.md`; `ops/BACKLOG.md`; `ops/unicode-operators/clang/REPLAY.md` | no branch — this repo only. **Answered by the design author: all five recommendations accepted as written, none overridden.** Recorded as five dated subsections in the brief plus a where-it-went table; `Log.` entries appended to 5 decision entries ([unary-forms](../../docs/unicode-operators.md#unary-forms) carries three of the five answers, plus [operator-function-id](../../docs/unicode-operators.md#operator-function-id), [user-infix-precedence](../../docs/unicode-operators.md#user-infix-precedence), [operator-identifier-disjointness](../../docs/unicode-operators.md#operator-identifier-disjointness), [precedence-level](../../docs/backtick-operator-design.md#precedence-level)); 5 ledger rows marked **OPEN — DECIDED** with the step that owes the writing. Nothing turned into code, so implement-decisions is marked **not-applicable**; the Coverage table splits [dependent-template-operator-id](../BACKLOG.md#dependent-template-operator-id) into its reword half and its report half; the silent fold guard is recorded in the gate facts and at the top of `REPLAY.md`. | **PASS** — box ticked. 5 answers recorded, 5 `Log.` entries appended, 5 ledger `Status:` fields marked, 1 backlog `Closed by` corrected. No `RECONCILED` marker set anywhere: **deciding is not reconciling**, and every row names its destination section and its owner. | [decision-brief](handoffs/decision-brief.handoff.md) |
| upstream-reports | 2026-09-06 | [`increment-decrement-mangling`](../BACKLOG.md#increment-decrement-mangling) → [draft](upstream-drafts/increment-decrement-mangling.md) | no branch — this repo only. Re-confirmed on two trunk builds (`a815e6f267c1`, `d28193fa1ff6`) for `++` **and** `--`, against `g++ 15.2.0`; both mangler sites (`mangleOperatorName`'s `OO_PlusPlus`/`OO_MinusMinus` arms, `mangleExpression`'s `UnaryOperatorClass` and `CXXOperatorCallExprClass` arms) read out of trunk `72417eb739e5` itself. ABI citation found: **§5.1.3** *Operator Encodings* and **§5.1.6** *Expressions*. `llvm-cxxfilt` round-trips all four spellings. **The reproducer on file does not reproduce** — it needs explicit instantiations. | **PASS on the amended gate** — confirmed on current trunk, 8 duplicate searches (no duplicate; #26427 and #25168 checked and rejected), report written out in full. The step's original "three issue URLs" bullet is **not met, by the author's decision** not to file. | [upstream-reports](handoffs/upstream-reports.handoff.md) |
| upstream-reports | 2026-09-06 | [`clangir-lvalue-crash`](../BACKLOG.md#clangir-lvalue-crash) → [draft](upstream-drafts/clangir-lvalue-crash.md) | no branch — this repo only. **Scope widened by the confirmation:** the `default:` arm is one of **21** arms in `emitLValue` that `errorNYI(...)` then `return LValue()`, and the enumerated ones are reachable from stock C++26. Reproduced with `PackIndexingExpr` in l-value position, no feature and no flag: `p...[0] = 1;` → BL04's exact `QualType::getCommonPtr` assertion; `return p...[0];` → segfault in `createStore` from `emitReturnStmt`. | **PASS on the amended gate** — the scratch CIR build (`6ee1358f7b47`, base `bb33de72920a`) differs from trunk `72417eb739e5` in `emitLValue` **only** by BL04's two feature arms, and `emitReturnStmt` is byte-identical, so the exercised path is today's trunk code. 7 duplicate searches; no duplicate, #202097 and #214443 recorded as same-shape prior art. No URL, by decision. | same |
| upstream-reports | 2026-09-06 | [`unqualified-id-union-read`](../BACKLOG.md#unqualified-id-union-read) → [draft](upstream-drafts/unqualified-id-union-read.md) | no branch — this repo only. **The cited line moved and the defect is not where the row said.** `ParseExprCXX.cpp:2297`'s block is correct on trunk (it kind-tests before reading `OperatorFunctionId`). The live read is the `OpKind` ternary at `ParseExprCXX.cpp:2374` (`ParseUnqualifiedIdTemplateId`), which excludes only `IK_Identifier` — plus a **second, unrecorded** copy at `ParseTemplate.cpp:1155` (`AnnotateTemplateIdToken`), unguarded. `Identifier` is the active member for `IK_LiteralOperatorId` (`DeclSpec.h`), and `OFI::Operator` is `OFI`'s first member. | **PASS on the amended gate** — confirmed by reading trunk `72417eb739e5`; still latent (`operator""_x<'1','2'>()` compiles clean on both builds). 4 duplicate searches: no duplicate, and **#20143** found — the same read at `Declarator::isStaticMember()`, now kind-guarded, which settles the fix shape. No URL, by decision. | same |
| upstream-reports | 2026-09-06 | `docs/unicode-operators.md` §9 and §13.1; `papers/dxxxxr0.md` Acknowledgments; [`postfix-operators`](../unicode-operators/clang/DEVIATIONS.md#postfix-operators) clause (c); `ops/BACKLOG.md` ×3 | The three places that carry the mangling defect as a private note now cite it — **with the placeholder token `LLVM-ISSUE-PENDING` where the issue number goes**, since there is none. §13.1's code block gains the missing explicit instantiations and the `--` twin; §9's closing gains the fixity-marker paragraph that [mangling-abi](steps/mangling-abi.md) needs; the paper gains `--`, the two ABI section numbers, and the placeholder. Clause (3) of [`postfix-operators`](../unicode-operators/clang/DEVIATIONS.md#postfix-operators)'s recommended doc changes was **not** touched: that is mangling-abi's. | **PASS on the docs gate** — every row this step touched is marked in its ledger and names the section *and* paragraph. `grep -rn LLVM-ISSUE-PENDING docs papers ops` finds every mention in one pass, four of them substitution points; no row is marked closed that is not. | same |
| upstream-triage | 2026-09-06 | [`inner-call-source-range`](../BACKLOG.md#inner-call-source-range), [`operator-caret-range`](../BACKLOG.md#operator-caret-range) → **WONTFIX, closed** | no branch — this repo only. Both reasons verified rather than accepted. The caret range was reproduced in **stock C++23 with no feature flag** on `a815e6f267c1` and `783a9c1a5f6f`: `operator+(a, a)` and `operator""_x(a)` each underline exactly 8 columns, character-identically to the glyph case. The source-range argument was checked against upstream's own precedent: for `p < q`, `CXXRewrittenBinaryOperator` is `<col:28, col:32>` and the `CXXOperatorCallExpr` it wraps is `<col:28, col:30>`. Design docs: new `docs/backtick-operator-design.md` **§17.5** plus a dated `Log.` entry on [source-fidelity-node](../../docs/backtick-operator-design.md#source-fidelity-node); `docs/unicode-operators.md` §7 "Desugaring" (last sentence) and a new §10 subsection [operator-name-caret-range](../../docs/unicode-operators.md#operator-name-caret-range). | **PASS** — both rows have a `Closed by` giving a reason a reader who has not read this plan would accept, and both reasons are in a design doc as well as the row. **Row corrected:** [`inner-call-source-range`](../BACKLOG.md#inner-call-source-range)'s re-grade was wrong about the cost — `CallExpr::setUsesMemberSyntax()` is public and recomputes the cached begin loc from arg 0, so no `CallExpr::Create` overload is needed; it is declined on meaning, not cost. | [upstream-triage](handoffs/upstream-triage.handoff.md) |
| upstream-triage | 2026-09-06 | [`cxxfilt-stdin-nonascii`](../BACKLOG.md#cxxfilt-stdin-nonascii), [`auto-return-round-trip`](../BACKLOG.md#auto-return-round-trip), [`pch-ast-print-order`](../BACKLOG.md#pch-ast-print-order) → **REPORT, drafted, rows stay open** | no branch — this repo only. Three drafts added to [`upstream-drafts/`](upstream-drafts/README.md) in the shape upstream-reports established; its README now tables all six and carries the seventh-report explanation. All three reproduced on `783a9c1a5f6f` (feature flags off) and confirmed to be trunk code: `llvm-cxxfilt.cpp` and `DeclBase.cpp` are **byte-identical** between that build's base `d28193fa1ff6` and trunk `72417eb739e5`, and `DeclPrinter::VisitFunctionDecl` extracted from both is identical. | **PASS on the amended gate** — 18 duplicate queries, no duplicate for any of the three. Findings carried into the drafts: **#24794** (open) is the *same two functions* as the PCH defect, its "expels decls" half fixed and the ordering half surviving, so that report is probably a comment on it; **#39337** is the request that introduced the cxxfilt splitter; **#12178 / #218420 / #147150** are the `-ast-print` family. **Two row corrections:** [`pch-ast-print-order`](../BACKLOG.md#pch-ast-print-order)'s obvious reproducer does **not** reproduce — the class must be *used* from the main file, not merely present in the PCH; and **#178767 is not [`cxxfilt-stdin-nonascii`](../BACKLOG.md#cxxfilt-stdin-nonascii)**, contrary to the prior handoff's forward note — that symbol fails on the argv path too. | same |
| upstream-triage | 2026-09-06 | [`dependent-template-operator-id`](../BACKLOG.md#dependent-template-operator-id) report half → **NOT DONE, returned to the author**; `docs/open-decisions.md`, [operator-id-anywhere](../unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere) | no branch — this repo only. **No draft written.** The literal-operator reproducer `t.template operator""_lit<int>(0)` is *correctly* rejected: [over.literal]/1 forbids a member literal operator, Clang rejects the member, static-member and member-template spellings and GCC agrees, and trunk `SemaTemplate.cpp` handles `IK_LiteralOperatorId` deliberately with the comment *"can never occur in a dependent scope (literal operators can only be declared at namespace scope)."* Filing it would report correct behaviour as a bug. Recorded as a dated entry in the brief's Answers, the summary-table row annotated, and the ledger row's false clause struck. | **Gate not applicable — this item is not one of the step's five, and it ends by asking rather than choosing.** The premise the 2026-09-06 answer rested on is falsified: literal operators share the *code path* but suffer no limitation from it, so the limitation is **exclusive to the new name kind**, and the clause "a limitation user-defined literal operators have had since C++11" must not enter U§7.1. The reword half is unblocked and unaffected. | same |
| mangling-abi | 2026-09-06 | `docs/unicode-operators.md` §9 (rewritten) and [operator-mangling](../../docs/unicode-operators.md#operator-mangling) | no branch — this repo only; nothing built, no feature branch touched. §9 is now three slug-headed subsections instead of five paragraphs: [mangling-derivation-rule](../../docs/unicode-operators.md#mangling-derivation-rule) (the derivation **rule** rather than the example, the injectivity argument, the unexercised padding/astral branches, the two-demangler measurement with four symbol forms, the retained math-identifier disjointness paragraph, and the inherited arity-digit wrinkle), [abi-production-request](../../docs/unicode-operators.md#abi-production-request) (the open decision, in decision-brief's five-part shape), and [microsoft-abi-position](../../docs/unicode-operators.md#microsoft-abi-position). One new ABI fact, read out of the ABI HTML rather than a handoff: **§5.1.3's prose scopes `v <digit> <source-name>` to "vendors who define builtin extended operators (e.g. `__imag`)"**, which a user-declared operator is not — the strongest argument in the section for asking for a first-class production. [operator-mangling](../../docs/unicode-operators.md#operator-mangling)'s Status/Decision/Why/Log updated to point at the three subsections. | **PASS on the docs gate, then BLOCKED on the author.** §9 answers all three of what is implemented / what is asked for / what is unexamined, and cites `LLVM-ISSUE-PENDING` (no issue number exists; upstream-reports drafted and did not file). The *asked for* answer is a **recommendation, not a choice** — three options with costs, per the plan's Decide ground rule — so the box stays unticked. 1191 local links checked repo-wide, **0 broken**. | [mangling-abi](handoffs/mangling-abi.handoff.md) |
| mangling-abi | 2026-09-06 | `ops/unicode-operators/clang/DEVIATIONS.md` ×3, `ops/BACKLOG.md`, `CLAUDE.md` | [`vendor-extended-mangling`](../unicode-operators/clang/DEVIATIONS.md#vendor-extended-mangling) → **RECONCILED**, naming the block quote, the *"Two branches … unexercised by construction"* paragraph, the *"'Demangler-tolerated' undersells the measurement"* paragraph and the closing arity-digit paragraph. [`msvc-mangling`](../unicode-operators/clang/DEVIATIONS.md#msvc-mangling) → **RECONCILED**, naming all three paragraphs of [microsoft-abi-position](../../docs/unicode-operators.md#microsoft-abi-position). [`postfix-operators`](../unicode-operators/clang/DEVIATIONS.md#postfix-operators) — clause (3) **taken and closed** into [abi-production-request](../../docs/unicode-operators.md#abi-production-request)'s third measured bullet and Recommendation point 1; clauses (1), (4), (5) stay open and stay reconcile-remainder's. [`astral-plane-mangling`](../BACKLOG.md#astral-plane-mangling) `Closed by` filled — recorded, not fixed, because it is a property of the frozen [token-set](../../docs/unicode-operators.md#token-set). Ledger header corrected: it no longer claims no row has ever been reconciled. `CLAUDE.md` Layout gains `docs/open-decisions.md` and an ABI clause for §9 — the plan's standing Housekeeping item, now done. | **PASS** — every row this step claims names the destination **section and paragraph**, and no row is marked closed that is not: the three upstream-report rows and the 22 other Unicode deviation rows are untouched and still `OPEN`. | same |
| mangling-abi | 2026-09-06 | `docs/unicode-operators.md` [abi-production-request](../../docs/unicode-operators.md#abi-production-request) and [operator-mangling](../../docs/unicode-operators.md#operator-mangling); `docs/open-decisions.md` | **Answered by the design author: the recommendation accepted as written** — *(a) and (b) together, non-normatively.* Recorded where the question lives, U§9, because for this question the answer **is** the section: `Status: open` becomes a dated answer paragraph saying the paper describes the vendor form as the fallback needing no ABI action, then asks for a first-class production **as a request rather than as proposed wording**, `s` reserved so postfix stays takeable and the letters left to the ABI group. [operator-mangling](../../docs/unicode-operators.md#operator-mangling)'s Status, Decided by and Log updated — the entry stays `Proposed` on the same terms as the rest of the log, i.e. it is polled with the paper, and no longer because anything in it is undecided. `docs/open-decisions.md` gains the dated answer, a where-it-was-recorded row, and a front-matter correction: the three questions whose *pages* live elsewhere still have their *answers* recorded there. | **PASS — box ticked.** All four gate bullets met and the answer is recorded in four places (U§9, the decision entry's Log, the brief's Answers, the where-recorded table). [`vendor-extended-mangling`](../unicode-operators/clang/DEVIATIONS.md#vendor-extended-mangling) gains the note that its closing argument is now the paper's position; [`astral-plane-mangling`](../BACKLOG.md#astral-plane-mangling)'s conditional resolves — the untested-branches paragraph **does** reach the paper, and [unicode-paper](steps/unicode-paper.md) carries it. | [mangling-abi](handoffs/mangling-abi.handoff.md) |
| mangling-abi | 2026-09-06 | `docs/open-decisions.md`; [`operator-id-anywhere`](../unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere); [`dependent-template-operator-id`](../BACKLOG.md#dependent-template-operator-id) | **Second answer, recorded only — none of the work it generates was done here.** [dependent-template-operator-id](../../docs/open-decisions.md#dependent-template-operator-id)'s reopened report half is settled as **option (a): reword only, no upstream report.** The gap is this feature's own — `DependentTemplateStorage` predates the new name kind, the same thesis as [`declaration-name-plumbing`](../unicode-operators/clang/DEVIATIONS.md#declaration-name-plumbing) and [`operator-candidate-assembly`](../unicode-operators/clang/DEVIATIONS.md#operator-candidate-assembly) — and the struck clause *"a limitation user-defined literal operators have had since C++11"* is false and must not enter U§7.1 or either paper. The summary-table row no longer reads as partly reopened; the ledger row drops its report obligation and points at the corrected wording; the backlog row's `Closed by` says it closes on the reword alone, owned by [reconcile-declaring-using](steps/reconcile-declaring-using.md), and its **Item** — which still asserted the false claim — carries a dated correction. | **PASS on the recording gate.** Nothing upstream is pending for this row and no draft is owed; [upstream-triage](steps/upstream-triage.md) is done with it. **The reword itself was not written** — it is [reconcile-declaring-using](steps/reconcile-declaring-using.md)'s, and the corrected justifying clause is now in three places it will look. | same |
