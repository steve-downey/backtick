# Handoff — R24 rebase onto trunk (second maintenance branch)

- **Status:** DONE (gate passed)
- **Branch / commit:** `backtick-trunk` @ `bd6f4d5fa102`
- **Date / agent:** 2026-07-29
- **Not a plan step.** Companion to `13-rebase-release-23x.handoff.md`. Read that
  one first — it explains the rebase mechanics and the clang-format trap, which
  are not repeated here.

## What changed

The Clang track now exists as **two parallel branches**, replacing the single
`backtick` branch:

| Branch | Base | Version | Worktree | Build dir |
|--------|------|---------|----------|-----------|
| `backtick-23` | `upstream/release/23.x` @ `561093d94eb7` | 23.1.0-rc2 | `~/src/llvm/backtick` | `~/src/llvm/build-backtick` |
| `backtick-trunk` | `upstream/main` @ `bb33de72920a` | 24.0.0git | `~/src/llvm/backtick-trunk` | `~/src/llvm/build-backtick-trunk` |

The branch formerly called `backtick` was renamed to `backtick-23`; the plain
name was deleted from both of Steve's remotes so nothing is ambiguous. There is
no branch named `backtick` on any LLVM remote.

`backtick-trunk` was rebased from the **pre-fix** tag `backtick-pre-23-rebase`
(`8b3e32b81aed`, base `a815e6f267c1`), not from `backtick-23`, so the two lines
are siblings rather than one derived from the other. They diverge only in their
final commit — each branch carries its own clang-format-conformance fix naming
the base it was verified against (`60f3e013b5b3` on `backtick-23`,
`bd6f4d5fa102` here). Those two commits are textually identical.

## Verification evidence

```
# Rebase (44 commits, 6035 commits of upstream drift)
git rebase --onto upstream/main a815e6f267c1 backtick-trunk
→ 1 conflict (see below), rest clean

# Feature-diff equivalence, clang/ only
(a815e6f267c1..8b3e32b81aed) vs (upstream/main..backtick-trunk)
→ 973 added/removed content lines BYTE-IDENTICAL
  (also identical to backtick-23's — the same diff on all three)

# check-clang
NINJA_EXIT=0
Total Discovered: 54106
  Passed           : 48220
  Unsupported      :  5853
  Expectedly Failed:    27
  Skipped          :      6
  Failed           :      0
Testing Time: 363.87s
```

Note **0 failures** — cleaner than `backtick-23`, which still shows the env-only
`Format/dump-config-objc-stdin.m` failure. That test passes on trunk, so
upstream appears to have changed how clang-format handles an unusable config
file found by walking up the directory tree. The stray
`/home/sdowney/src/.clang-format` is still there; only trunk's tolerance of it
changed.

## Deviations from the plan / design

None. No design decision (D1–D16) was revisited; the feature diff is unchanged.

## Discoveries affecting later steps

### The one conflict, and why it was benign

`clang/unittests/Format/TokenAnnotatorTest.cpp`, replaying S10. Upstream added
`TEST_F(TokenAnnotatorTest, CSharpUtf8StringLiterals)` at exactly the point S10
appends `TEST_F(TokenAnnotatorTest, BacktickTokenTypes)`, and the two blocks
shared a trailing `}`. Pure adjacent insertion — resolved by keeping both tests
and restoring the brace. That the feature diff still came out byte-identical
afterwards is the proof the resolution lost nothing.

`rerere` recorded the resolution, so a repeat of this rebase will replay it.

### Both branches need the same clang-format fix

The four non-conforming spots (3 in `TokenAnnotator.cpp`, 1 in `Format.cpp`) are
identical on both bases. Expected, since `release/23.x` branched from trunk after
the brace-style change, but now confirmed rather than assumed. **Check format
conformance before running the gate**, not after — it aborts at ~step 81/970,
before any lit test runs.

### Crash notifications during the gate are upstream XFAILs, not us

`check-clang` makes clang abort twice, producing KDE DrKonqi crash popups and
`coredumpctl` entries. Both are upstream tests marked expected-to-crash, counted
in `Expectedly Failed`, so the gate stays green:

- `clang/test/Analysis/reinterpret-cast-pointer-to-member.cpp` — `// XFAIL: asserts`
- `clang/test/CodeGen/xfail-alloc-align-fn-pointers.cpp` — `// XFAIL: *`,
  upstream comment "FIXME: These should not crash!"

Neither invocation passes `-fbacktick`; neither file, nor
`clang/lib/StaticAnalyzer/`, is modified by either branch. They read as
project-related only because the binary path contains `backtick-trunk`.

Suppressed via `systemctl --user mask drkonqi-coredump-launcher.socket` (undo
with `unmask`). `systemd-coredump` has no per-executable filter and DrKonqi has
no blacklist, so this silences all crash popups for the user, not just these.
`ulimit -c 0` around a gate run avoids writing the multi-MB cores but does not
stop the notification.

## Open risks / TODOs

- **Every Clang change must now land twice.** Do the work on one branch, verify
  its gate, then cherry-pick and **re-verify** on the other. The bases drift
  independently, so a clean cherry-pick is not evidence of a passing gate — the
  clang-format abort is the standing counterexample.
- The GCC track is still pinned at trunk `c9ee2c5ab6c` and was not touched. The
  two implementations now sit on different vintages of their compilers; re-sync
  before any fresh cross-compiler divergence testing.
- `backtick-pre-23-rebase` (`8b3e32b81aed`) is the common ancestor of both
  branches — the state both were rebased from, and the only ref reaching the 44
  pre-rebase commits. Pushed to `origin` and `ceridwen`, so it survives a local
  disk loss. Do not delete it from the remotes until you are sure neither line
  needs redoing; without it that history is unreachable and eligible for GC.
- Carried forward from S10: `err_backtick_nested_requires_parens` remains dead
  code, and the D8 slot-interior SplitPenalty bump is still unimplemented.
