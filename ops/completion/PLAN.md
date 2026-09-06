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

### Phase A — Naming (first, so nothing downstream is written twice)
- [x] 1. [slug-the-ledgers](steps/slug-the-ledgers.md) — retire the serial numbers in the two decision logs, the three deviation ledgers and the backlog in favour of slugs; [`ops/SLUGS.md`](../SLUGS.md) is the map (dep: none)

### Phase B — Upstream citizenship (no dependencies; early because issues take calendar time)
- [ ] 2. [upstream-reports](steps/upstream-reports.md) — file the three upstream defects (dep: none)
- [ ] 3. [upstream-triage](steps/upstream-triage.md) — report-or-WONTFIX the five annoyances (dep: none)

### Phase C — Decide (the author's, and the critical path for everything written)
- [ ] 4. [decision-brief](steps/decision-brief.md) — the four questions with implementation consequences, and the "anywhere" claim (dep: none)
- [ ] 5. [mangling-abi](steps/mangling-abi.md) — the ABI question, and U§9 with it (dep: upstream-reports, slug-the-ledgers)

### Phase D — Make the papers true
- [ ] 6. [clang-paper-truth](steps/clang-paper-truth.md) — the three Clang defects that falsify a claim (dep: decision-brief)
- [ ] 7. [null-return-suppression](steps/null-return-suppression.md) — the analyzer parity break, on all four branches (dep: none)
- [ ] 8. [implement-decisions](steps/implement-decisions.md) — build whatever decision-brief decided (dep: decision-brief; scope contingent)
- [ ] 9. [gcc-resync](steps/gcc-resync.md) — re-sync GCC to current trunk, then its four open defects (dep: none)

### Phase E — Discharge the evidence debt
- [ ] 10. [evidence-debt](steps/evidence-debt.md) — the unbuilt hunk, the unwritten test, the unregenerable table (dep: none; supersedes `BL07`)

### Phase F — Reconcile, one destination section per step
- [ ] 11. [reconcile-implementation-cost](steps/reconcile-implementation-cost.md) — U§8, the implementation-cost thesis (dep: evidence-debt, slug-the-ledgers)
- [ ] 12. [reconcile-declaring-using](steps/reconcile-declaring-using.md) — U§7 / §7.1, declaring, using, desugaring (dep: decision-brief, implement-decisions, slug-the-ledgers)
- [ ] 13. [reconcile-remainder](steps/reconcile-remainder.md) — U§5 / §10 / §6 / §12 / §13, and the backtick and GCC ledgers (dep: gcc-resync, slug-the-ledgers)

### Phase G — Hygiene (no paper consequence; any time after its branches settle)
- [ ] 14. [hygiene-parity](steps/hygiene-parity.md) — the tooling-parity gaps, the dead code, the formatting limit (dep: clang-paper-truth)

### Phase H — The papers
- [ ] 15. [backtick-paper](steps/backtick-paper.md) — D4307R0 and its blog version (dep: clang-paper-truth, reconcile-remainder, hygiene-parity)
- [ ] 16. [unicode-paper](steps/unicode-paper.md) — the Unicode paper, a real number, and its blog version (dep: mangling-abi, implement-decisions, reconcile-implementation-cost, reconcile-declaring-using, reconcile-remainder)

### Maintenance (not plan steps)
- **M2** — forward-port `BL02` + clang-paper-truth's backtick fixes to `unicode-operators-experiment`. Runs after **clang-paper-truth**. Note that BL04 already put CIR arms on `backtick-trunk` that the experiment branch has too; expect a trivial conflict in the shared lead comment, not a semantic one.
- **[inotify-watch-budget](../BACKLOG.md#inotify-watch-budget)** — needs root, and is the maintainer's. Not an agent step.
- **Housekeeping** — `CLAUDE.md`'s Layout section does not mention
  `docs/unicode-operators.md`, the 857-line Unicode design doc that is the
  exact counterpart of `backtick-operator-design.md`. Fix it in whichever step
  first edits that file.

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
Start there if only one agent is available. **gcc-resync is the most perishable** —
the GCC track is pinned at trunk `c9ee2c5ab6c` while Clang has moved twice,
and every week makes the re-sync worse. **upstream-triage and null-return-suppression are independent of
everything** and are the right work for a spare agent.

## Coverage — every open item has a home

31 open `BNN` rows (37 + [`clangir-lvalue-crash`](../BACKLOG.md#clangir-lvalue-crash), less the 7 closed by `BL01`–`BL04`):

| Step | Rows |
|---|---|
| upstream-reports | [`increment-decrement-mangling`](../BACKLOG.md#increment-decrement-mangling) [`unqualified-id-union-read`](../BACKLOG.md#unqualified-id-union-read) [`clangir-lvalue-crash`](../BACKLOG.md#clangir-lvalue-crash) |
| upstream-triage | [`inner-call-source-range`](../BACKLOG.md#inner-call-source-range) [`cxxfilt-stdin-nonascii`](../BACKLOG.md#cxxfilt-stdin-nonascii) [`auto-return-round-trip`](../BACKLOG.md#auto-return-round-trip) [`pch-ast-print-order`](../BACKLOG.md#pch-ast-print-order) [`operator-caret-range`](../BACKLOG.md#operator-caret-range) |
| decision-brief | [`dependent-template-operator-id`](../BACKLOG.md#dependent-template-operator-id) (fix-or-reword) |
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

## Status log (each agent appends one row per branch or per document)
| Step | Date | Branch / doc | Commit | Gate result | Handoff |
|------|------|--------------|--------|-------------|---------|
| slug-the-ledgers | 2026-09-05 | `docs/backtick-operator-design.md` §3, `docs/unicode-operators.md` §2 | no branch — this repo only. 16 + 12 decisions converted from table rows to slug-headed sections with the full **Question / Status / Decision / Why / Log** shape plus `Decided by`; `Formerly:` keeps the old number. Two `Decision` cells were topics rather than decisions (`D2`, `D8`) and were restated. | **PASS** — every entry is an anchor, and every link into these two logs resolves (1029 local links checked, 1007 anchored, 0 broken). | [slug-the-ledgers](handoffs/slug-the-ledgers.handoff.md) |
| slug-the-ledgers | 2026-09-05 | `ops/DEVIATIONS.md`, `ops/gcc/DEVIATIONS.md`, `ops/unicode-operators/clang/DEVIATIONS.md` | 9 + 7 + 24 rows converted to slug-headed sections. Every entry now carries a `**Status:**` field; the Unicode ledger's 24 are all `OPEN`, which is accurate — it has never marked a row. | **PASS** — 40 entries, 40 anchors, 0 collisions. | same |
| slug-the-ledgers | 2026-09-05 | `ops/BACKLOG.md`, `ops/SLUGS.md` (new) | 38 defect rows converted to slug-headed sections keeping `Severity` / `Item` / `Where` / `Closed by`. `ops/SLUGS.md` maps all **106** retired identifiers both directions and records what was deliberately *not* renamed. | **PASS** — 106 mappings, both directions, every one resolving to a live anchor. | same |
| slug-the-ledgers | 2026-09-05 | cross-reference sweep: both papers, `ops/completion/**`, `ops/backlog/steps/BL05`–`BL07`, `CLAUDE.md`, `ops/AGENT_PROTOCOL.md`, `ops/HANDOFF_TEMPLATE.md` | 792 bare mentions rewritten as links to anchors; 19 internal identifiers **removed** from `papers/d4307r0.md` / `papers/dxxxxr0.md` rather than renamed, per the public-text rule. Protocol and ground rules now require slugs for anything added later. | **PASS** — the three gate greps are clean over `docs/`, `papers/`, `ops/*.md`, `ops/completion/` except `ops/SLUGS.md` (the map) and `steps/slug-the-ledgers.md` (the step's own quotation of what it retired); papers cite no identifier at all. | same |
