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
   `B01` was the last one anybody had scheduled; there are more.
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
minimal diffs — plus three that are specific to this track:

- **A docs step has a gate too.** It is not `check-clang`; it is that every
  row the step claims to close is *marked* closed in its ledger, with the
  section and paragraph it landed in named. A reconciliation that cannot say
  where it went did not happen.
- **Mark the ledger, not just the doc.** `ops/DEVIATIONS.md` and
  `ops/gcc/DEVIATIONS.md` use a `**RECONCILED**` / `**RESOLVED**` marker in
  the last column; `ops/unicode-operators/clang/DEVIATIONS.md` has never used
  one and must start. Same convention, same column.
- **Decisions are the author's.** A `Decide` step produces options, costs and
  a recommendation. It does not choose. It ends by asking, and the next step
  is blocked until it is answered — that is a legitimate BLOCKED handoff, not
  a failure.

- **Everything new is named, not numbered.** Steps, decisions, questions and
  defects get slugs — short kebab-case names for the question or the job,
  never for the answer, so a slug survives its own conclusion reversing. The
  ordinals in the checklist are reading order only; cross-reference by slug.
  See `~/.claude/CLAUDE.md`, "Name things for what they are, not what number
  they came in at", and `slug-the-ledgers`, which retires the numbers this
  repo already has.

Commit prefixes: `[backtick] <slug>: …` / `[unicode] <slug>: …` on the feature
branches, `docs: …` for design-doc and paper edits, `ops: <slug> — …` for
bookkeeping here.

## What this plan absorbs

`ops/backlog/PLAN.md` is **superseded, not deleted.** Its BL01–BL04 are green
and their handoffs are the record. Its three unstarted steps have good step
files, and this plan reuses them rather than restating them:

| Old | New home |
|---|---|
| `BL05` (`B25`) | **upstream-reports** — executes `steps/BL05-upstream-mangling.md` unchanged |
| `BL06` (`B03 B04 B06 B08 B35`) | split by purpose: `B03 B04` → **clang-paper-truth**, `B08` → **gcc-resync**, `B06 B35` → **reconcile-remainder** |
| `BL07` (`B16 B17 B21`) | **gcc-resync**, whose step file supersedes `BL07`'s |
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

- **`B31` is reopened and is an environment condition, not a defect to fix.**
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
54108/48222/**0**, `backtick-23` 54342/48500/**1** (`B33`),
`unicode-operators-experiment` 54183/48295/**0**,
`unicode-operators-upstream` 54241/48323/**0**; XFAIL 27 and skipped 6
throughout. Steps that add a test update that table in *this* file's Status
log and leave the old plan's alone.

## Checklist

Each line carries an **ordinal and a slug**. The ordinal is reading order and
shifts whenever a step is inserted or split; **the slug is the identity, and
every cross-reference in this repo uses it.** Never write "step 7".

### Phase A — Naming (first, so nothing downstream is written twice)
- [ ] 1. [slug-the-ledgers](steps/slug-the-ledgers.md) — retire `BNN`, `DEV-NN`, `D1`–`D16`, `U1`–`U11` in favour of slugs (dep: none)

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
- **B31** — needs root, and is the maintainer's. Not an agent step.
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

31 open `BNN` rows (37 + `B38`, less the 7 closed by `BL01`–`BL04`):

| Step | Rows |
|---|---|
| upstream-reports | `B25` `B26` `B38` |
| upstream-triage | `B24` `B27` `B28` `B29` `B30` |
| decision-brief | `B23` (fix-or-reword) |
| mangling-abi | `B20` |
| clang-paper-truth | `B02` `B03` `B04` |
| null-return-suppression | `B37` |
| gcc-resync | `B09` `B10` `B11` `B12` `B13` |
| evidence-debt | `B08` `B16` `B17` `B21` |
| reconcile-implementation-cost | `B19` (recorded as designed, and as evidence) |
| hygiene-parity | `B05` `B06` `B07` `B35`, and `B18` `B22` recorded |
| slug-the-ledgers | none directly — it renames every row above, and `ops/SLUGS.md` is the map |
| — | `B31`, maintainer's, needs root |

29 open deviation rows, written out in full so a grep for one finds its step:

| Step | Rows |
|---|---|
| mangling-abi | `DEV-U08` `DEV-U09` `DEV-U23` (mangling clause) |
| reconcile-implementation-cost | `DEV-U04` `DEV-U05` `DEV-U07` `DEV-U12` `DEV-U13` `DEV-U14` `DEV-U17` `DEV-U24` |
| reconcile-declaring-using | `DEV-U01` `DEV-U02` `DEV-U06` `DEV-U10` `DEV-U11` `DEV-U15` `DEV-U16` |
| reconcile-remainder | `DEV-U03` `DEV-U18` `DEV-U19` `DEV-U20` `DEV-U21` `DEV-U22`; `DEV-06` `DEV-07` `DEV-08` `DEV-09`; `DEV-G08` |

`DEV-U15` and `DEV-U16` are decided by decision-brief and *written* by reconcile-declaring-using — a decision
and its documentation are different steps, and implement-decisions owns only the ones that
turn into code. `DEV-U23` is split: its mangling clause is mangling-abi's, its postfix
substance is decision-brief's.

7 design decisions: four in decision-brief, the ABI in mangling-abi, U§6's example in reconcile-remainder, and
`DEV-U16` recorded in reconcile-declaring-using as the CWG question it is.

## Status log (each agent appends one row per branch or per document)
| Step | Date | Branch / doc | Commit | Gate result | Handoff |
|------|------|--------------|--------|-------------|---------|
