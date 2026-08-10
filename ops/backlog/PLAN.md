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
- **`DirectoryWatcherTest.*` (8 cases)** used to fail *intermittently* when
  the machine ran out of **free** inotify watches — a `cloud-drive-dae`
  process holds ~65k. **`B31` CLOSED 2026-08-08:** the maintainer applied
  the root fix; `fs.inotify.max_user_watches` is now **524288** (8×
  headroom), verified with all 8 passing directly. They are ordinary tests:
  never budget them as expected failures, never filter them. If they ever
  fail again, check `sysctl fs.inotify.max_user_watches` first — a reimage
  or sysctl change reverting to 65536 re-arms the old failure mode:
  ```bash
  sysctl fs.inotify.max_user_watches   # expect 524288
  "$B"/tools/clang/unittests/AllClangUnitTests --gtest_filter='DirectoryWatcherTest.*'
  ```
  Note the binary: clang's unittests are consolidated into a single
  **`AllClangUnitTests`**; there is no `DirectoryWatcherTests` executable.
- **`Format/dump-config-objc-stdin.m`** fails on `backtick-23` **only**, from
  a stray 2018 `/home/sdowney/src/.clang-format` outside any repo. It passes
  on every trunk-based branch. Do not "fix" the file (`B33`).
- `check-clang` deliberately crashes clang twice on upstream XFAILs; `ulimit
  -c 0` around the gate avoids the cores.

### Baselines to do the arithmetic against

**Measured by BL01, 2026-08-05, `check-clang` run UNFILTERED.** Green is these
numbers; anything else is a regression.

| Branch | Discovered | Passed | Failed | XFAIL | Unsupported | Skipped |
|---|---|---|---|---|---|---|
| `backtick-trunk` | 54107 | 48222 | **0** | 27 | 5852 | 6 |
| `backtick-23` | 54341 | 48500 | **1** (`B33` only) | 27 | 5807 | 6 |
| `unicode-operators-experiment` | 54181 | 48295 | **0** | 27 | 5853 | 6 |
| `unicode-operators-upstream` | 54240 | 48323 | **0** | 27 | 5884 | 6 |

**Both Unicode rows were re-measured UNFILTERED by BL03/M1 on 2026-08-09**,
replacing U20's filtered figures (experiment 54171 / 48285; upstream 54231 /
48314) as this plan asked the first Unicode step to gate to do. They include
M1's merge (+1 test on the experiment branch only) and BL03 (+1 test on both).
All four branches in this table now gate at **zero failures except `B33` on
`backtick-23`**.

Against the pre-BL01 filtered figures (trunk 54099 / 48212 / 2; 23.x 54333 /
48490 / 3): discovered **+8** on each — the `DirectoryWatcherTest.*` cases,
which are no longer filtered out — and passed **+10**, being those 8 plus the
two `CLANG_EXECUTABLE_VERSION` tests `B32` fixed.

## Checklist

### Phase A — Make the gate trustworthy
- [x] **BL01** Environment: `B31`, `B32`, `B33`, `B34` — `steps/BL01-environment.md`

### Phase B — The paper-truth item
- [x] **BL02** `B01`: implement D16, type-name in the operator slot — `steps/BL02-d16-type-slot.md` (dep: BL01)

### Phase C — The two P1 unknowns (Unicode track)
- [x] **BL03** `B14`: fix the static analyzer for `UserOperatorExpr` — `steps/BL03-analyzer-useroperator.md` (dep: BL01, M1) — **also found `B37`**
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
| BL01 | 2026-08-05 | `backtick-trunk` | no source change — build-dir config only; branch stays at `169e45c7916f`, worktree clean | **PASS, and green UNFILTERED for the first time on this track**: 54107 discovered / 48222 passed / **0 failed** / 27 XFAIL / 5852 unsupported / 6 skipped, `EXIT=0`. Against the pre-BL01 *filtered* 54099 / 48212 / 2: discovered **+8** (the `DirectoryWatcherTest.*` cases, no longer filtered out), passed **+10** (those 8 plus the two `CLANG_EXECUTABLE_VERSION` tests), failed **2 → 0**. `CLANG_EXECUTABLE_VERSION` `24-backtick` → `24`; rebuild was 2 ninja edges (relink + symlink). `Analysis/scan-build/cxx-name.test` and `Driver/hip-gz-options.hip` verified failing before and passing after. | `handoffs/BL01-environment.handoff.md` |
| BL01 | 2026-08-05 | `backtick-23` | no source change — build-dir config only; branch stays at `c280d8101f56`, worktree clean | **PASS**: 54341 discovered / 48500 passed / **1 failed** / 27 XFAIL / 5807 unsupported / 6 skipped, `EXIT=1`. The single failure is `Clang :: Format/dump-config-objc-stdin.m` — the documented `backtick-23`-only `B33` artifact, and the *only* remaining failure on this branch. Against the pre-BL01 filtered 54333 / 48490 / 3: discovered **+8**, passed **+10**, failed **3 → 1**. `CLANG_EXECUTABLE_VERSION` `23-backtick` → `23`; same 2-edge rebuild; same two tests verified before/after. | `handoffs/BL01-environment.handoff.md` |
| BL02 | 2026-08-08 | `backtick-trunk` | `5a2b586463d9` — D16 type slot: `TryParseBacktickTypeSlot()` + `ParsedType` `ActOnBacktickOperator` overload → `ActOnCXXTypeConstructExpr`, two printer arms; 8 files, +267/−21; no AST change, no general-parser sites touched | **PASS, unfiltered, 0 failures**: 54107 discovered / 48222 passed / **0 failed** / 27 XFAIL / 5852 unsupported / 6 skipped, `EXIT=0` — identical to the BL01 baseline (new cases extend existing test files; lit counts files, so discovered/passed do not move). All four B01 defect shapes construct; `` 1 `int` 2 `` fails with exactly `int(1, 2)`'s diagnostic; `-ast-print` round-trips incl. CTAD and dependent forms. | `handoffs/BL02-d16-type-slot.handoff.md` |
| BL02 | 2026-08-08 | `backtick-23` | `554d470ca412` — clean cherry-pick of `5a2b586463d9`, byte-identical diff | **PASS**: 54341 discovered / 48500 passed / **1 failed** / 27 XFAIL / 5807 unsupported / 6 skipped, `EXIT=1`; the single failure is `Clang :: Format/dump-config-objc-stdin.m`, the documented `B33` artifact — identical to the BL01 baseline. Gate run independently after the pick, all 11 backtick lit tests green first. | `handoffs/BL02-d16-type-slot.handoff.md` |
| BL03 | 2026-08-09 | `unicode-operators-experiment` | `be2670c2513f` — 6 analyzer arms across 4 production files (+47/−5) + `clang/test/Analysis/unicode-operator-analysis.cpp` (+122), the branch's **second** Analysis test after M1 brought the first | **PASS — unfiltered, `EXIT=0`, 0 failures**: 54181 discovered / 48295 passed / **0 failed** / 27 XFAIL / 5853 unsupported / 6 skipped, 390.6 s. Against U18's unfiltered 54179 / 48285 / **8**: discovered **+2** (M1's `backtick-infix.cpp`, BL03's `unicode-operator-analysis.cpp`), passed **+10** = those 2 plus the 8 recovered `DirectoryWatcherTest.*`, failed **8 → 0**. Build warning-free. **Five of six arms proven load-bearing by reverting each in turn, rebuilding and re-running the test — each fails it, and each in its own signature**: `findConstructionContexts` → `(CXXRecordTypedCall, [B1.6])` not `[B1.8]`; `CFGBuilder::Visit` → `[B1.9]`, wrapper an element again; `VisitForTemporaries` → a second `~Res() (Temporary object destructor)`; `LiveVariables` → `TRUE` count 7 → 4; `Environment` → 7 → 3. **The sixth, `ExprEngine`, is unreachable** once the CFG looks through the node — proven with an `llvm_unreachable` probe that never fired across all 1196 `clang/test/Analysis` tests — and is changed anyway because the old `CXXRewrittenBinaryOperator` grouping asserts the wrapper is a modelled element, which the CFG change falsifies. Parity measured before/after: infix, prefix, member and explicit forms all `TRUE` (was `UNKNOWN` for the operator forms); null-deref 2/4 → 4/4. | `handoffs/BL03-analyzer-useroperator.handoff.md` |
| BL03 | 2026-08-09 | `unicode-operators-upstream` | `6428404d98a5` — the `UserOperatorExpr` half only, hand-applied against the *upstream* precedents rather than cherry-picked, since the backtick arms M1 put beside them on the experiment branch do not exist here; test file byte-identical | **PASS — unfiltered, `EXIT=0`, 0 failures**: 54240 discovered / 48323 passed / **0 failed** / 27 XFAIL / 5884 unsupported / 6 skipped, 339.6 s. Against U20's unfiltered 54239 / 48314 / **8**: discovered **+1** (the one new test), passed **+9** = that test plus the 8 recovered `DirectoryWatcherTest.*`, failed **8 → 0**; no existing test changed behaviour. Build warning-free. **U20's headline result survives:** `git diff upstream/main..unicode-operators-upstream \| grep -i backtick` still returns nothing, and the new test contains no backtick reference. The replayed test passed on first run on clean `main`. | `handoffs/BL03-analyzer-useroperator.handoff.md` |
