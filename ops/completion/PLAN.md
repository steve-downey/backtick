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

Commit prefixes: `[backtick] CNN: …` / `[unicode] CNN: …` on the feature
branches, `docs: …` for design-doc and paper edits, `ops: CNN — …` for
bookkeeping here.

## What this plan absorbs

`ops/backlog/PLAN.md` is **superseded, not deleted.** Its BL01–BL04 are green
and their handoffs are the record. Its three unstarted steps have good step
files, and this plan reuses them rather than restating them:

| Old | New home |
|---|---|
| `BL05` (`B25`) | **C01** — executes `steps/BL05-upstream-mangling.md` unchanged |
| `BL06` (`B03 B04 B06 B08 B35`) | split by purpose: `B03 B04` → **C05**, `B08` → **C08**, `B06 B35` → **C12** |
| `BL07` (`B16 B17 B21`) | **C08**, whose step file supersedes `BL07`'s |
| `M2` | unchanged, still in `ops/unicode-operators/clang/PLAN.md` Phase G; runs after **C05** |

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

**The CIR scratch dir survives BL04 and is reusable.** C08 needs lldb; add
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

### Phase A — Upstream citizenship (no dependencies; first because issues take calendar time)
- [ ] **C01** File the upstream defects: `B25`, `B38`, `B26` — `steps/C01-upstream-file.md`
- [ ] **C02** Triage the upstream annoyances: `B24`, `B27`, `B28`, `B29`, `B30` — `steps/C02-upstream-triage.md` (dep: none)

### Phase B — Decide (the author's, and the critical path for everything written)
- [ ] **C03** Decision brief — `DEV-U15`, `DEV-U06`, folds (U§13), postfix (`DEV-U23`), and `B23`'s fix-or-reword — `steps/C03-decision-brief.md`
- [ ] **C04** The ABI question, and U§9 with it — `U8`, `DEV-U09`, `DEV-U08`, `B20` — `steps/C04-abi-decision.md` (dep: C01)

### Phase C — Make the papers true
- [ ] **C05** Clang paper-truth: `B03`, `B02`, `B04` — `steps/C05-clang-paper-truth.md` (dep: C03)
- [ ] **C06** `B37`: the analyzer's null-return suppression, on all four branches — `steps/C06-b37-suppression.md` (dep: none)
- [ ] **C07** Implement what C03 decided — `steps/C07-decided-changes.md` (dep: C03; scope contingent)
- [ ] **C08** GCC: re-sync (`B13`), then `B09`, `B10`, `B11`, `B12`, `DEV-G08` — `steps/C08-gcc-resync.md` (dep: none)

### Phase D — Discharge the evidence debt
- [ ] **C09** `B16`, `B17`, `B21`, `B08` — `steps/C09-evidence-debt.md` (dep: none; supersedes `BL07`)

### Phase E — Reconcile, one destination section per step
- [ ] **C10** U§8 — the implementation-cost thesis: `DEV-U04 U05 U07 U12 U13 U14 U17 U24`, and `B19` as its fourth instance — `steps/C10-reconcile-u8.md` (dep: C09)
- [ ] **C11** U§7 / §7.1 — declaring, using, desugaring: `DEV-U01 U02 U06 U10 U11 U15 U16` — `steps/C11-reconcile-u7.md` (dep: C03, C07)
- [ ] **C12** U§5 / §10 / §6 / §12 / §13, the backtick ledger and GCC's: `DEV-U03 U18 U19 U20 U21 U22`, `DEV-06 07 08 09`, `DEV-G08`, U§6's sixth example — `steps/C12-reconcile-rest.md` (dep: C08)

### Phase F — Hygiene (no paper consequence; any time after its branches settle)
- [ ] **C13** `B05`, `B06`, `B07`, `B35`, and record `B18`/`B22` — `steps/C13-hygiene.md` (dep: C05)

### Phase G — The papers
- [ ] **C14** D4307R0 and `infix-backtick-operator.org` — `steps/C14-paper-backtick.md` (dep: C05, C12, C13)
- [ ] **C15** The Unicode paper — a real document number, and `unicode-infix-operators.org` — `steps/C15-paper-unicode.md` (dep: C04, C07, C10, C11, C12)

### Maintenance (not plan steps)
- **M2** — forward-port `BL02` + C05's backtick fixes to `unicode-operators-experiment`. Runs after **C05**. Note that BL04 already put CIR arms on `backtick-trunk` that the experiment branch has too; expect a trivial conflict in the shared lead comment, not a semantic one.
- **B31** — needs root, and is the maintainer's. Not an agent step.
- **Housekeeping** — `CLAUDE.md`'s Layout section does not mention
  `docs/unicode-operators.md`, the 857-line Unicode design doc that is the
  exact counterpart of `backtick-operator-design.md`. Fix it in whichever step
  first edits that file.

## The critical path, and what is parallel

```
C01 ──> C04 ─────────────────────────────────┐
C03 ──> C07 ──> C11 ──┐                      │
   └──> C05 ──> C13 ──┴──> C14               ├──> C15
C08 ──> C12 ──────────┴──> C14               │
C09 ──> C10 ─────────────────────────────────┘
C02, C06  — independent of everything
```

**C03 is the one thing that blocks the most**, and it is desk work: seven
questions that are already measured, needing options and a recommendation.
Start there if only one agent is available. **C08 is the most perishable** —
the GCC track is pinned at trunk `c9ee2c5ab6c` while Clang has moved twice,
and every week makes the re-sync worse. **C02 and C06 are independent of
everything** and are the right work for a spare agent.

## Coverage — every open item has a home

31 open `BNN` rows (37 + `B38`, less the 7 closed by `BL01`–`BL04`):

| Step | Rows |
|---|---|
| C01 | `B25` `B26` `B38` |
| C02 | `B24` `B27` `B28` `B29` `B30` |
| C03 | `B23` (fix-or-reword) |
| C04 | `B20` |
| C05 | `B02` `B03` `B04` |
| C06 | `B37` |
| C08 | `B09` `B10` `B11` `B12` `B13` |
| C09 | `B08` `B16` `B17` `B21` |
| C10 | `B19` (recorded as designed, and as evidence) |
| C13 | `B05` `B06` `B07` `B35`, and `B18` `B22` recorded |
| — | `B31`, maintainer's, needs root |

29 open deviation rows, written out in full so a grep for one finds its step:

| Step | Rows |
|---|---|
| C04 | `DEV-U08` `DEV-U09` `DEV-U23` (mangling clause) |
| C10 | `DEV-U04` `DEV-U05` `DEV-U07` `DEV-U12` `DEV-U13` `DEV-U14` `DEV-U17` `DEV-U24` |
| C11 | `DEV-U01` `DEV-U02` `DEV-U06` `DEV-U10` `DEV-U11` `DEV-U15` `DEV-U16` |
| C12 | `DEV-U03` `DEV-U18` `DEV-U19` `DEV-U20` `DEV-U21` `DEV-U22`; `DEV-06` `DEV-07` `DEV-08` `DEV-09`; `DEV-G08` |

`DEV-U15` and `DEV-U16` are decided by C03 and *written* by C11 — a decision
and its documentation are different steps, and C07 owns only the ones that
turn into code. `DEV-U23` is split: its mangling clause is C04's, its postfix
substance is C03's.

7 design decisions: four in C03, the ABI in C04, U§6's example in C12, and
`DEV-U16` recorded in C11 as the CWG question it is.

## Status log (each agent appends one row per branch or per document)
| Step | Date | Branch / doc | Commit | Gate result | Handoff |
|------|------|--------------|--------|-------------|---------|
