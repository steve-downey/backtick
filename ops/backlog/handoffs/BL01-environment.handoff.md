# Handoff — BL01 Environment: make the gate readable

- **Status:** DONE (gate passed)
- **Branch / commit:** No source change on any branch. `backtick-trunk` stays
  at `169e45c7916f`, `backtick-23` at `c280d8101f56`, both worktrees clean.
  The change is build-dir configuration plus bookkeeping in this repo.
- **Date / agent:** 2026-08-05
- **Closes:** `B32` (fixed), `B33` (documented, no action), `B34` (recorded,
  no action). **`B31` is NOT closed** — see below.

## What changed

| File / target | Change |
|---|---|
| `~/src/llvm/build-backtick-trunk` (CMake cache) | `CLANG_EXECUTABLE_VERSION` `24-backtick` → `24` |
| `~/src/llvm/build-backtick` (CMake cache) | `CLANG_EXECUTABLE_VERSION` `23-backtick` → `23` |
| both build dirs, `bin/` | `clang` symlink now → `clang-24` / `clang-23`; the orphaned `clang-24-backtick` / `clang-23-backtick` binaries **deleted** |
| `ops/gcc/PLAN.md` | new **Gate facts** section: the libstdc++ recipe (`B34`), the `cc1plus`-not-`xg++` fact, and the `c9ee2c5ab6c` pin (`B13`) |
| `CLAUDE.md` | known-failure section rewritten; self-format gotcha corrected to include `clang/unittests/Format/` and the in-tree binary |
| `ops/backlog/PLAN.md` | BL01 ticked; baselines replaced with measured unfiltered numbers; `DirectoryWatcherTest` gate fact corrected; two Status rows |
| `ops/BACKLOG.md` | `Closed by` cells for `B31`–`B34`, each saying what actually happened; `B31` re-graded |
| `ops/backlog/steps/BL06-backtick-batch.md` | its reproducer cited `clang-24-backtick`, which no longer exists — changed to `bin/clang` |

Rebuild was **2 ninja edges per build dir** (relink + symlink), as predicted.

## Verification evidence

**`B32`, before** — `llvm-lit` on the two named tests, `build-backtick-trunk`:
```
Failed Tests (2):
  Clang :: Analysis/scan-build/cxx-name.test
  Clang :: Driver/hip-gz-options.hip
```
The diff showed the cause directly: the test expects `clang-24`, the driver
reported `.../bin/clang-24-backtick`.

**`B32`, after** — both tests `PASS` on **both** build dirs.

**Full `check-clang`, run UNFILTERED on both branches** (`ulimit -c 0`,
redirected, `EXIT=` marker checked — not piped to `tail`):

| Branch | Discovered | Passed | Failed | XFAIL | Unsupported | Skipped | EXIT |
|---|---|---|---|---|---|---|---|
| `backtick-trunk` | 54107 | 48222 | **0** | 27 | 5852 | 6 | 0 |
| `backtick-23` | 54341 | 48500 | **1** | 27 | 5807 | 6 | 1 |

`backtick-23`'s single failure is `Clang :: Format/dump-config-objc-stdin.m`
— the documented `B33` artifact, and now the *only* failure on that branch.

**Arithmetic** against the pre-BL01 *filtered* baselines (trunk 54099 / 48212
/ 2; 23.x 54333 / 48490 / 3): discovered **+8** on each — the
`DirectoryWatcherTest.*` cases, which are no longer being filtered out — and
passed **+10**, being those 8 plus the two `CLANG_EXECUTABLE_VERSION` tests.
Failed 2 → 0 and 3 → 1. Every number is accounted for.

## Deviations from the plan / design

Three, all corrections to the step file's own assumptions.

1. **`B31` is mischaracterised in `BACKLOG.md`, and the correction matters.**
   The row says 8 cases "fail intermittently on every branch" because the
   budget "is exhausted". The budget *is* exhausted — measured during the
   gate at **65,381 / 65,536 in use, `cloud-drive-dae` holding 65,045** — and
   yet all 8 passed, run directly and as part of `check-clang`. The
   dependency is on **free** watches, not on the budget being near its cap:
   ~155 free is enough for 8 tests that each take a handful.

   Consequence for every later step: **do not budget these as expected
   failures.** A clean unfiltered run is achievable and is now the standard.
   That is why the new baselines are unfiltered.

2. **There is no `DirectoryWatcherTests` binary.** Clang's unittests are
   consolidated into a single `AllClangUnitTests`
   (`"$B"/tools/clang/unittests/AllClangUnitTests`). The
   `tools/clang/unittests/DirectoryWatcher/` directory contains only CMake
   leftovers. The correct direct invocation is
   `AllClangUnitTests --gtest_filter='DirectoryWatcherTest.*'`. Anyone
   following the old advice looking for a `DirectoryWatcherTests` executable
   will not find one.

3. **The orphaned suffixed binaries had to go.** Reverting
   `CLANG_EXECUTABLE_VERSION` leaves `clang-24-backtick` / `clang-23-backtick`
   as 160 MB files with no ninja rule — they would never be rebuilt and would
   silently go stale. Since the *original* B32 mis-diagnosis was caused by
   exactly this (stale pre-edit binaries passing while the live ones failed),
   leaving them would have re-armed the trap. Deleted. Checked first that
   nothing references them: the only hits were documentation and one line in
   `BL06`'s step file, which was corrected.

No `DEVIATIONS.md` row: nothing here contradicts a design document. These are
environment and ledger corrections, which is what this track is for.

## Discoveries affecting later work

- **The gate is now genuinely clean.** `backtick-trunk` is the first
  zero-failure unfiltered `check-clang` on this track. Any failure a later
  step sees on trunk is **its own**, with no known-failure excuse available.
  On `backtick-23` exactly one failure is expected, by name.
- **Use `"$B"/bin/clang`.** The suffixed names are gone. Reproducers in step
  files and handoffs that name `clang-24-backtick` are stale;
  `BL06`'s was fixed, but `ops/handoffs/15-defect-fixes.handoff.md` still
  mentions them and is a historical record — leave it.
- **A CMake-cache-only change is cheap.** `cmake -D… .` in the build dir plus
  `ninja clang` was ~16 s of configure and 2 edges. Worth knowing for BL04,
  which needs a much larger reconfigure and should use a *scratch* dir.
- **The Unicode baseline in `ops/backlog/PLAN.md` is still U20's filtered
  figure** (54171 / 48285 / 0) and was not re-measured here. The first
  Unicode step to gate — BL03, BL04 or BL07 — should replace it with an
  unfiltered number, the same way this step did for the backtick branches.

## Forward notes for the NEXT step (BL02 — `B01`, implement D16)

Written after reading `steps/BL02-d16-type-slot.md`.

- **Your gate target is 0 failures on `backtick-trunk`, unfiltered.** Not
  "0 plus 8 DirectoryWatcher". Compare against 54107 / 48222 / 0 / 27 / 5852 /
  6, and expect discovered and passed to rise by the number of tests you add.
  On `backtick-23` expect exactly 1 failure,
  `Clang :: Format/dump-config-objc-stdin.m`, and nothing else.
- **Reproduce with `~/src/llvm/build-backtick-trunk/bin/clang`.** The three
  D16 failure modes reproduce on stdin, no file needed:
  ```bash
  printf 'struct P { P(int,int); };\nP g(int a,int b){ return a `P` b; }\n' \
    | ~/src/llvm/build-backtick-trunk/bin/clang -cc1 -std=c++23 -fbacktick -fsyntax-only -x c++ -
  ```
- **`Options.td` is not in your path, but `Expr.h` and `ParseExpr.cpp` are.**
  BL01 measured the cheap end (2 edges); an `Expr.h` touch is a wide rebuild
  and `ParseExpr.cpp` is a single TU. If you end up not needing the AST
  header — and step 5 says you should not, because F23 already made the
  wrapper accept a non-`CallExpr` inner — your rebuild is small. If you find
  yourself editing `Expr.h`, stop and re-read `Expr.h:2242-2250` first.
- **Background the gate, block on the marker.** The pattern that worked:
  ```bash
  { ulimit -c 0; ninja -C "$B" check-clang > gate.log 2>&1; echo "EXIT=$?" >> gate.log; } &
  until grep -q '^EXIT=' gate.log; do sleep 30; done; tail -3 gate.log
  ```
  Each gate is ~3.5 min of testing plus build time — faster than the plan's
  ~12 min estimate now that both dirs are warm. Do **not** poll with `pgrep`.
- **Two Status rows, not one.** And verify the `backtick-23` gate
  independently after the cherry-pick; do not infer it from a clean pick.
- **Your step also edits the paper.** `papers/d4307r0.md:911-914` is the
  grammar production, `:940` the `r7` example, `:541-553` the prose. The
  grammar edit is the one most likely to be forgotten and is the reason the
  step exists — without it the paper contradicts itself whether or not the
  compiler works.

## Open risks / TODOs

- **`B31` is open and needs the maintainer.** Uncomment
  `/etc/sysctl.d/50-ubuntustudio.conf:6` and `sudo sysctl --system`. Until
  then the 8 `DirectoryWatcherTest.*` cases are a latent, load-dependent
  failure: they passed throughout BL01 with 155 watches free, and will fail
  again if `cloud-drive-dae` takes more. This is the one part of BL01 an
  agent cannot do.
- The pre-BL01 numbers quoted in `ops/handoffs/15-defect-fixes.handoff.md`
  (F23/F24) are now superseded for arithmetic purposes but remain correct as
  a record of that job. Not reconciled; no need.
- `ops/PLAN.md`'s own Status log still describes `backtick`-branch rows for
  S00–S12 with a branch name that no longer exists. Pre-existing, harmless,
  explained in `CLAUDE.md`. Left alone.
