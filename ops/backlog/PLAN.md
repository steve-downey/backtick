# Backlog — Operational Plan (defect-fix track)

This plan works `ops/BACKLOG.md`. That file is a *record* — 36 rows of
defects the three implementation tracks found and left standing, with a
severity scale and a suggested order in prose, but nothing scheduled or
gated. This plan schedules and gates the part that matters now.

It is a fourth track alongside `ops/PLAN.md` (Clang backtick, S00–S12),
`ops/gcc/PLAN.md` (GCC backtick, G01–G10) and
`ops/unicode-operators/clang/PLAN.md` (Clang Unicode, U00–U21) — all three of
which are fully checked off. Unlike them it does not build a feature; every
step closes one or more `BNN` rows.

## How to use this plan
1. Read `ops/AGENT_PROTOCOL.md` — it defines exactly how to execute one step.
   Substitute for this track: plan → *this file*; step files →
   `ops/backlog/steps/BLNN-*.md`; handoffs →
   `ops/backlog/handoffs/BLNN-<slug>.handoff.md`; deviations → the ledger of
   whichever track the step touched (`ops/DEVIATIONS.md`,
   `ops/gcc/DEVIATIONS.md`, or `ops/unicode-operators/clang/DEVIATIONS.md`).
2. Find the first unchecked step below whose dependencies are all checked.
3. Execute only that step. Then stop.

## Ground rules
- **One step per agent.** Never start the next step.
- **No green, no check.** A step's box is ticked only after its verification
  gate passes. If it can't pass, leave it unchecked, write a BLOCKED handoff,
  stop.
- **Gated and regression-free.** Everything stays behind `-fbacktick` /
  `-funicode-operators`. A default build must behave exactly as upstream.
- **Minimal diffs.** Touch only what the step names.
- **Commit prefix follows the branch, not this plan:** `[backtick] BLNN: …`
  on `backtick-trunk`/`backtick-23`, `[unicode] BLNN: …` on the Unicode
  branches, `ops: BLNN — …` for bookkeeping in this repo.
- **Two Status rows per Clang step**, one per branch — a clean cherry-pick is
  not proof of a passing gate (the clang-format trap in
  `ops/handoffs/13-rebase-release-23x.handoff.md`).
- **Unicode steps also append a `REPLAY.md` row** and must land on
  `unicode-operators-upstream` as well as `unicode-operators-experiment`.
- **Close the loop in `ops/BACKLOG.md`.** Every step fills the `Closed by`
  cell of each `BNN` row it closes, with its step id. The backlog stops being
  write-only.

## Branches, worktrees, build dirs

| Track | Branch | Worktree | Build dir |
|-------|--------|----------|-----------|
| backtick | `backtick-trunk` | `~/src/llvm/backtick-trunk` | `~/src/llvm/build-backtick-trunk` |
| backtick | `backtick-23` | `~/src/llvm/backtick` | `~/src/llvm/build-backtick` |
| unicode | `unicode-operators-experiment` | `~/src/llvm/unicode` | `~/src/llvm/build-unicode` |
| unicode | `unicode-operators-upstream` | `~/src/llvm/unicode-upstream` | `~/src/llvm/build-unicode-upstream` |

`~/src/llvm/main` / `~/src/llvm/build-main` is the maintainer's pristine
build. Do **not** disturb it. Steps needing a differently-configured build
(BL04's CIR, BL07's lldb) create a **scratch** dir and say so in the handoff;
they never reconfigure one of the four above. The one exception is BL01,
whose whole job is to reconfigure two of them.

## Build & test

```bash
B=~/src/llvm/build-backtick-trunk           # or build-backtick / build-unicode / …
ninja -C "$B" clang
ulimit -c 0; ninja -C "$B" check-clang > gate.log 2>&1; echo "EXIT=$?" >> gate.log
until grep -q '^EXIT=' gate.log; do sleep 30; done; tail -3 gate.log
```

**Waiting without losing your step.** Build and gate both exceed the
10-minute per-call ceiling. Start them in the background writing their own
`EXIT=` marker, then block on the marker inside one call and repeat that call
until it returns. Repeating a blocking poll several times is correct and
expected; ending your turn to "wait for a notification" ends your step. U03
lost a full cycle to this.

Do **not** poll with `pgrep -f "ninja -C $B"` — the poll loop's own command
line contains that string, so `pgrep` matches itself and never exits. Grep
the log for the marker, never the process table.

### Gate facts — all inherited, all have cost someone real time

- **`ninja … | tail` reports `tail`'s exit code, not ninja's.** Redirect and
  check `$?` explicitly.
- **`check-clang` self-formats and aborts at ~step 81/970**, before any lit
  test runs, if edits don't match current LLVM style. The glob covers
  `clang/unittests/Format/*.cpp` as well as `clang/lib/Format/`, and it uses
  the **in-tree** `clang-format`. Format your test edits with the binary you
  just built.
- **`DirectoryWatcherTest.*` (8 cases)** fails when the machine's inotify
  budget is exhausted — a `cloud-drive-dae` process holds ~65,382 of 65,536.
  Not ours; the untouched binaries fail identically. Gate around it with
  `GTEST_FILTER='-DirectoryWatcherTest.*' "$B"/bin/llvm-lit -s "$B"/tools/clang/test`.
  **BL01/`B31` is the fix**, and it needs root.
- **`Format/dump-config-objc-stdin.m`** fails on `backtick-23` **only**, from
  a stray 2018 `/home/sdowney/src/.clang-format` outside any repo. It passes
  on every trunk-based branch. Do not "fix" the file (`B33`).
- **`Analysis/scan-build/cxx-name.test` and `Driver/hip-gz-options.hip`** fail
  on both backtick branches because `CLANG_EXECUTABLE_VERSION` was set to
  `23-backtick`/`24-backtick`. **BL01/`B32` is the fix.**
- `check-clang` deliberately crashes clang twice on upstream XFAILs; `ulimit
  -c 0` around the gate avoids the cores.

### Baselines to do the arithmetic against (filtered, pre-BL01)

| Branch | Discovered | Passed | Failed |
|---|---|---|---|
| `backtick-trunk` | 54099 | 48212 | 2 (`B32`) |
| `backtick-23` | 54333 | 48490 | 3 (`B32` ×2, `B33`) |
| `unicode-operators-experiment` | 54171 | 48285 | 0 |

**BL01 replaces these.** After it, record the new numbers here and subtract
against those.

## Checklist

### Phase A — Make the gate trustworthy
- [ ] **BL01** Environment: `B31`, `B32`, `B33`, `B34` — `steps/BL01-environment.md`

### Phase B — The paper-truth item
- [ ] **BL02** `B01`: implement D16, type-name in the operator slot — `steps/BL02-d16-type-slot.md` (dep: BL01)

### Phase C — The two P1 unknowns (Unicode track)
- [ ] **BL03** `B14`: fix the static analyzer for `UserOperatorExpr` — `steps/BL03-analyzer-useroperator.md` (dep: BL01, M1)
- [ ] **BL04** `B15`: build ClangIR and close the unknown — `steps/BL04-clangir.md` (dep: BL01)

### Phase D — Upstream
- [ ] **BL05** `B25`: report the `operator++`/`operator--` mangling defect — `steps/BL05-upstream-mangling.md` (dep: none)

### Phase E — The cheap batches
- [ ] **BL06** backtick batch: `B03`, `B04`, `B06`, `B08`, `B35` — `steps/BL06-backtick-batch.md` (dep: BL01)
- [ ] **BL07** Unicode batch: `B16`, `B17`, `B21` — `steps/BL07-unicode-batch.md` (dep: BL01)

### Phase F — Maintenance (not plan steps; M-prefixed, like the rebases)
- **M1** — forward-port F23/F24 to `unicode-operators-experiment`. Already
  specified at `ops/unicode-operators/clang/steps/M1-forward-port-backtick-fixes.md`
  and unchecked there. **Run it before BL03**: it puts the
  `BacktickInfixExpr` analyzer arms in-tree beside where the
  `UserOperatorExpr` arms go.
- **M2** — forward-port BL02 + BL06 to `unicode-operators-experiment` after
  both are green. Recorded in `ops/unicode-operators/clang/PLAN.md` Phase G.

BL05 depends on nothing and can run at any time. BL02, BL04, BL06 and BL07
are independent of each other once BL01 is green; BL03 additionally wants M1.
BL04 and BL07 both need a scratch build dir — combine their configures if
they run near each other.

## Status log (each agent appends one row per branch)
| Step | Date | Branch | Commit | Gate result | Handoff |
|------|------|--------|--------|-------------|---------|
