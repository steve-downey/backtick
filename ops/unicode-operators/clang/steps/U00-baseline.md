# U00 — Experiment worktree, branch, baseline gate

**Goal.** Stand up an isolated worktree + build dir for the Unicode
experiment, based on `backtick-trunk`, and prove it is green *before* any
Unicode change exists. Pin the exact values every later step will quote.

**Depends on:** —
**Design refs:** `docs/unicode-operators.md` U§3 (what transfers from
backtick), U§8 (implementation sketch);
`ops/unicode-operators/clang-experiment-plan.md` (branch strategy).

## Do
1. Create a worktree from the existing trunk backtick branch:
   ```bash
   cd /home/sdowney/src/llvm/main
   git worktree add -b unicode-operators-experiment \
       /home/sdowney/src/llvm/unicode backtick-trunk
   ```
   Do **not** disturb `~/src/llvm/main`, `~/src/llvm/build-main`,
   `~/src/llvm/backtick-trunk`, or `~/src/llvm/build-backtick-trunk`.
2. Configure a dev build dir `~/src/llvm/build-unicode` matching the
   backtick dev build (assertions **on**, runtimes/bootstrap trimmed). Copy
   the CMake invocation out of `ops/handoffs/00-baseline.handoff.md` rather
   than inventing one; record it verbatim in your handoff.
3. Build `clang` and run the full gate. Record the baseline pass/fail
   counts — every later step compares against *these* numbers, not against
   the backtick track's.
4. Confirm the base commit: `git -C ~/src/llvm/unicode log -1 --format=%H`
   and the upstream `main` commit `backtick-trunk` sits on. Both go in the
   handoff; U20 needs the second one.
5. Verify the inherited backtick feature still works in this worktree
   (`-fbacktick` on a one-liner from `clang/test/Parser/backtick-infix.cpp`)
   — the experiment leans on it and a broken base must be found now.
6. Create `ops/unicode-operators/clang/REPLAY.md` with its header row (see
   PLAN.md "two ledgers"), empty of rows.

## Build
`ninja -C ~/src/llvm/build-unicode clang`

## Verify (gate)
- `ninja -C ~/src/llvm/build-unicode check-clang > gate.log 2>&1; echo "EXIT=$?"`
  — green means **exactly one** failure, `Clang :: Format/dump-config-objc-stdin.m`
  (env-only; see PLAN.md). Any other failure is a real blocker.
- `-fbacktick` smoke test compiles.

## Done when
Worktree, branch, and build dir exist; the gate matches the known-good
shape; the baseline numbers and both base commits are recorded.

## Capture in handoff
The exact worktree/build paths, branch name, CMake line, base commit,
upstream-`main` commit under `backtick-trunk`, baseline test counts, and
the wall-clock cost of a full `check-clang` (later agents budget from it).

## Pitfalls
`~/src/llvm/backtick` holds branch **`backtick-23`**, not `backtick`; this
track wants **`backtick-trunk`** (`~/src/llvm/backtick-trunk`) as its base,
because upstream replay (U20) targets `main`. Branching from the release
branch would put the replay two rebases away from where it needs to be.
