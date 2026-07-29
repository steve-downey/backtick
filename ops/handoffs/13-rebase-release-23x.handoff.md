# Handoff — R23 rebase onto `release/23.x`

- **Status:** DONE (gate passed)
- **Branch / commit:** `backtick` @ `60f3e013b5b3`
- **Date / agent:** 2026-07-28
- **Not a plan step.** The S00–S12 / G01–G10 checklists were already fully
  checked off when this ran. This is a maintenance rebase, recorded here so the
  base-commit change is not silently lost between the S00 baseline and whatever
  comes next.

## What changed

The LLVM base moved off trunk and onto the release branch:

| | Before | After |
|---|---|---|
| Base commit | `a815e6f267c1` | `561093d94eb7` |
| Base identity | trunk, 23.0.0git | `upstream/release/23.x`, llvmorg-23.1.0-rc2 |
| Reported version | `clang version 23.0.0git` | `clang version 23.1.0-rc2` |

Backup tag `backtick-pre-23-rebase` → `8b3e32b81aed` (pre-rebase tip) exists in
`~/src/llvm/backtick`; `git reset --hard backtick-pre-23-rebase` undoes the
whole thing. Nothing was pushed.

Source changes: one commit, `60f3e013b5b3`, reformatting four spots in
`clang/lib/Format/TokenAnnotator.cpp` (3) and `clang/lib/Format/Format.cpp` (1).
Whitespace and braces only — no semantic change to the backtick implementation.

## Verification evidence

```
# Rebase
git rebase --onto upstream/release/23.x a815e6f267c1 backtick
→ 44/44 commits replayed, ZERO conflicts

# Feature-diff equivalence (old base..old tip) vs (new base..new tip), clang/ only
→ differences confined to blob hashes and hunk offsets;
  973 added/removed content lines byte-identical

# Backtick lit tests
llvm-lit clang/test/{Parser,Lexer,SemaCXX,Driver}/backtick-*  + fbacktick.c
→ 12/12 passed

# check-clang (after the reformat commit)
Total Discovered: 54340
  Passed           : 48498
  Unsupported      :  5808
  Expectedly Failed:    27
  Skipped          :      6
  Failed           :      1  (env-only: Format/dump-config-objc-stdin.m)
Testing Time: 280.32s
```

`ninja` exits 1 on that single failure. It is the same env-only known-fail
recorded for S02–S11 — see "Environment gotcha" below.

## Deviations from the plan / design

None. No design decision (D1–D16) was revisited and no `DEVIATIONS.md` row is
warranted: the rebase produced a byte-identical feature diff, so the
implementation the design doc describes is unchanged.

## Discoveries affecting later steps

### A clean 3-way merge does not imply a passing gate

`git merge-tree --write-tree` reported every one of the 38 drifted files
auto-merging cleanly, and the rebase then ran without a single conflict — but
`check-clang` still failed, at step **81/970**, before running any lit test.
`clang/lib/Format/` self-formats as part of the gate, and LLVM's style tightened
between the old base and `release/23.x` to require braces around multi-line `if`
bodies.

**When rebasing this branch again:** after a conflict-free rebase, run
`clang-format` over the touched `clang/lib/Format/*` files before trusting the
gate. To confirm any non-conformance is yours rather than pre-existing upstream
churn, format the pristine upstream copy first:

```bash
git show upstream/<branch>:clang/lib/Format/TokenAnnotator.cpp > /tmp/up.cpp
clang-format --assume-filename=clang/lib/Format/TokenAnnotator.cpp < /tmp/up.cpp | diff -u /tmp/up.cpp -
```

Both files came back clean at `release/23.x`, which is what made whole-file
reformatting safe here.

### `ninja … | tail` masks the exit code

Two gate runs reported exit 0 while actually having failed — the pipeline's
status is `tail`'s, not `ninja`'s. Redirect and check explicitly instead:

```bash
ninja check-clang > gate.log 2>&1; echo "NINJA_EXIT=$?"; tail -40 gate.log
```

### Environment gotcha — the one remaining failure is not ours

`Clang :: Format/dump-config-objc-stdin.m` fails with
`Configuration file(s) do(es) not support Objective-C: /home/sdowney/src/.clang-format`.
A stray `Language: Cpp` config dated Jan 2018 sits at `/home/sdowney/src/.clang-format`,
outside any git repo; `clang-format` walks up the directory tree from the CWD and
finds it. Confirmed unrelated to `-fbacktick`: the pristine
`~/src/llvm/build-main/bin/clang-format` (no backtick changes, still at the old
base `a815e6f267c1`) fails identically. Leave that file alone — it is outside
the project and may matter to other trees.

### Why this rebase was easy, and when the next one won't be

The old base `a815e6f267c1` turned out to be an **ancestor** of the
`release/23.x` branch point (`fb423ba07c3f`), so this was a pure forward rebase
rather than a divergent one. There *was* real churn in the touched files —
`ASTImporter.cpp` shifted ~145 lines, `ByteCode/Compiler.cpp` ~230,
`TreeTransform.h` ~210 — it merged only because the backtick changes are
additive hooks in structurally stable places. A future rebase onto a branch that
has diverged from the current base will not be this quiet.

## Open risks / TODOs

- The GCC track is untouched and still pinned at trunk `c9ee2c5ab6c`
  (`~/bld/gcc/gcc-backtick`). The two implementations now sit on different
  vintages of their respective compilers. Harmless for the paper's claims, but
  worth re-syncing before any fresh cross-compiler divergence testing.
- Nothing is pushed. `backtick` in `~/src/llvm/backtick` is ahead of every
  remote and its history has been rewritten, so the first push will need
  `--force-with-lease`.
- Carried forward from S10: `err_backtick_nested_requires_parens` remains dead
  code, and the D8 slot-interior SplitPenalty bump is still unimplemented.
