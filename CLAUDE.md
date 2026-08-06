# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## What this repository is

This repo holds **only the design, plan, and operational record** for adding an
infix backtick operator (and a backtick keyword-escape) to C++ — a WG21
proposal prototyped in two real compilers. It contains **no compiler source**.
The actual implementation lives in two external git worktrees (see below); this
repo was split out of the Clang worktree (`[backtick] move planning docs & ops
into standalone repo`). **This repo is the authoritative copy** of the `docs/`
and `ops/` trees — the duplicate copies in the LLVM worktree are being removed,
so make all design-doc / plan / handoff / deviation edits here.

The thesis being tested: `x `op` y` is sugar for `op(x, y)`, desugared in the
front end so overload resolution, ADL, templates, constexpr, and codegen are
all inherited rather than reimplemented. See `docs/backtick-operator-design.md`.

**Current state:** all three implementation tracks are fully checked off —
Clang backtick S00–S12, GCC backtick G01–G10, and Clang Unicode U00–U21
(`ops/unicode-operators/clang/PLAN.md`; the second feature is implemented,
not merely planned). Treat that step machinery as a completed record unless a
*new* step is added to a `PLAN.md`.

**Live work is in `ops/backlog/PLAN.md`** — steps BL01–BL07, nothing checked.
That track works `ops/BACKLOG.md`, the ledger of every defect the three
tracks found and left standing (`B01`–`B36`). **That is where an
implementation agent picks up work.** Two maintenance merges are also
outstanding, M1 and M2 in `ops/unicode-operators/clang/PLAN.md` Phase G.

The remaining non-defect work is paper writing (see
`docs/infix-backtick-operator.org`, `docs/unicode-infix-operators.org`,
`papers/`), reconciling open DEVIATIONS rows back into the design docs, and
the open *design* decisions indexed in `ops/BACKLOG.md` §6 — which need an
author's decision, not an implementer's.

Maintenance rebases (R-prefixed rows in the `ops/PLAN.md` Status log) are not
plan steps and do not follow `ops/AGENT_PROTOCOL.md`; they still get a handoff
and a Status-log row so base-commit changes are not lost.

## Layout

- `docs/backtick-operator-design.md` — the canonical design + decisions log
  (D1–D16), precedence rationale (§4), the same-delimiter parsing problem (§5),
  per-compiler implementation plans (§6 Clang, §7 clang-format, §8 GCC), and
  post-implementation clarifications (§17). This is the source of truth the
  paper is written from; deviations get reconciled back into it.
- `docs/infix-backtick-operator.org` (+ `.meta`) — the actual WG21 proposal /
  blog post prose, org-mode source with a Nikola `.meta` sidecar. This is the
  reader-facing deliverable the design doc feeds; the `.org` is the paper, the
  design doc is its rationale/worklog. Prefer the `voice` skill when drafting or
  editing this prose.
- `ops/PLAN.md` — master operational checklist (Clang phases A–C, then GCC).
- `ops/gcc/PLAN.md` — the GCC sub-plan (G01–G10).
- `ops/BACKLOG.md` — every defect the three tracks found and left standing
  (`B01`–`B36`), with a `Closed by` column pointing at the step that closes
  each one. Open *design* questions are not in it; §6 indexes those.
- `ops/backlog/PLAN.md` — the defect-fix track (BL01–BL07), which schedules
  and gates that backlog. The only plan with unchecked steps.
- `ops/AGENT_PROTOCOL.md` — the one-step-per-agent execution loop. **Read it
  before doing any plan step.**
- `ops/steps/NN-*.md`, `ops/gcc/steps/GNN-*.md` — one self-contained spec per
  step (the "Do" and the verification gate).
- `ops/handoffs/`, `ops/gcc/handoffs/` — one handoff per completed step. The
  previous step's handoff (its "Forward notes" / "Discoveries") **overrides the
  step file where they conflict** and carries the real symbol names, paths, and
  build/test invocations the next agent needs.
- `ops/DEVIATIONS.md`, `ops/gcc/DEVIATIONS.md` — ledger of every place build
  reality contradicted the design (DEV-NN / DEV-GNN), including cross-compiler
  divergences, with reconciliation status.

## The implementation worktrees (where the code actually is)

The Clang track is maintained on **two parallel branches** — one on the LLVM 23
release branch, one on trunk. They carry a byte-identical feature diff and
differ only in their final clang-format-conformance commit; see
`ops/handoffs/13-rebase-release-23x.handoff.md` and
`ops/handoffs/14-rebase-trunk.handoff.md`.

| Track | Branch | Base | Source worktree | Build dir |
|-------|--------|------|-----------------|-----------|
| Clang | `backtick-23` | `upstream/release/23.x` (llvmorg-23.1.0-rc2) | `~/src/llvm/backtick` | `~/src/llvm/build-backtick` |
| Clang | `backtick-trunk` | `upstream/main` | `~/src/llvm/backtick-trunk` | `~/src/llvm/build-backtick-trunk` |
| GCC   | `backtick` | GCC trunk `c9ee2c5ab6c` | `~/bld/gcc/gcc-backtick` | `~/bld/gcc/gcc-backtick-build` |

Clang tests for both branches: `clang/test/**/backtick-*.cpp`,
`clang/test/Driver/fbacktick.c`, `clang/unittests/Format/`.
GCC tests: `gcc/testsuite/g++.dg/backtick/*.C`.

Note the worktree directory `~/src/llvm/backtick` holds branch **`backtick-23`**,
not a branch named `backtick` — the directory name predates the split and was
kept so `~/src/llvm/build-backtick` stays valid. There is no branch named plain
`backtick` on any LLVM remote; it was deleted when the two lines were split.

**A change to the Clang implementation must be applied to both branches.** Do the
work on one, verify its gate, then cherry-pick and re-verify on the other — the
two bases drift independently, so a clean cherry-pick is not proof of a passing
gate (see the clang-format trap in `ops/handoffs/13-rebase-release-23x.handoff.md`).

The Clang worktrees may still carry stale copies of these `docs/` and `ops/`
trees pending their removal; ignore them and treat this repo as authoritative.
The maintainer's pristine main build is `~/src/llvm/build-main` (`~/src/llvm/main`)
— do **not** disturb it; all feature work happens in the backtick worktrees/builds.

## Build & test

Clang (dev build has assertions on; flag is `-fbacktick`). Substitute
`build-backtick-trunk` / `backtick-trunk` for the trunk branch:
```bash
ninja -C ~/src/llvm/build-backtick clang                 # build
ninja -C ~/src/llvm/build-backtick check-clang           # full regression gate
~/src/llvm/build-backtick/bin/llvm-lit -v \
    ~/src/llvm/backtick/clang/test/Parser/backtick-infix.cpp   # one test
```

Two gotchas that make a failed gate look green — both cost real time already:

- **`ninja … | tail` reports `tail`'s exit code, not ninja's.** Redirect and
  check explicitly: `ninja check-clang > gate.log 2>&1; echo "EXIT=$?"`.
- **`check-clang` self-formats `clang/lib/Format/` *and*
  `clang/unittests/Format/`**, with the **in-tree** `clang-format`, and aborts
  at ~step 81/970 before any lit test runs if the edits there don't match the
  current LLVM style. A conflict-free rebase does not imply a passing gate.
  (Glob corrected by U18; the original wording named only `lib/`.)

**Known failures, and nothing else is acceptable.** The full accounting lives
in `ops/backlog/PLAN.md`'s gate facts; the short form:

- **8 `DirectoryWatcherTest.*` cases**, on *every* branch including untouched
  binaries, when the machine's inotify watch budget is exhausted. Not ours.
  Gate around them with
  `GTEST_FILTER='-DirectoryWatcherTest.*' "$B"/bin/llvm-lit -s "$B"/tools/clang/test`.
  The real fix needs root and is tracked as `ops/BACKLOG.md` B31.
- **`Clang :: Format/dump-config-objc-stdin.m` on `backtick-23` only** — a
  stray `Language: Cpp` config at `/home/sdowney/src/.clang-format` (dated
  2018, outside any repo) picked up by clang-format walking up the directory
  tree. It fails identically on the pristine `build-main` binary. It **passes**
  on every trunk-based branch, so do not budget it on `backtick-trunk` or the
  Unicode branches — and do not "fix" it by touching that file (B33).

`Analysis/scan-build/cxx-name.test` and `Driver/hip-gz-options.hip` used to
fail here too, from a `CLANG_EXECUTABLE_VERSION` of `23-backtick`/`24-backtick`.
BL01 reverted that on 2026-08-05; both pass now and the suffixed binaries are
gone. If you see them fail again, check the build dir's cache before anything
else (B32).

GCC (dev build is `--disable-bootstrap --enable-languages=c,c++`):
```bash
cd ~/bld/gcc/gcc-backtick-build && make -j18 all-gcc      # build cc1plus
# quick syntax check — use cc1plus directly; xg++ fails (no liblto_plugin.so / cc1 in dev build):
~/bld/gcc/gcc-backtick-build/gcc/cc1plus -fbacktick -std=c++23 -fsyntax-only file.cc
# regression gate (dejagnu), one dir or one file:
make -C gcc check-c++ RUNTESTFLAGS="dg.exp=g++.dg/backtick/*.C"
```

## Working conventions

- **One step per agent, no improvising on process.** Follow `ops/AGENT_PROTOCOL.md`
  exactly: orient → load context (step file + prior handoff + named design
  sections) → execute the "Do" → run the gate → only then tick the box, append a
  Status-log row, commit, and write the next handoff (after reading the next
  step's file). Never start the next step.
- **No green, no check.** A step's checkbox in `PLAN.md` is ticked only after its
  verification gate passes (`check-clang` must stay green for Clang steps). If it
  can't pass: leave it unchecked, write a `BLOCKED` handoff, stop.
- **Everything gated behind the flag.** All new behavior sits behind `-fbacktick`
  (Clang `LangOptions` `Backtick`; GCC `flag_backtick` / `OPT_fbacktick`). A
  default build (flag off) must behave exactly as upstream. Keep diffs minimal —
  touch only what the step names.
- **Commit messages** (in *this* repo and the worktrees): `[backtick] SNN: <title>`
  for Clang-track work, `[backtick][gcc] GNN: <title>` for GCC-track, `docs: …`
  for design-doc edits, `ops: …` for plan/ledger bookkeeping.
- **Feedback loop.** When build reality contradicts the design doc, append a row
  to the relevant `DEVIATIONS.md` and reference it in the handoff; the design-doc
  author reconciles it into §3 / the affected section. Record cross-compiler
  divergences in `ops/gcc/DEVIATIONS.md` — they are exactly what CWG/EWG ask about.

## Design facts worth knowing before editing

- **Precedence (D2/§4):** highest-precedence *binary* operator — tighter than
  `*`, looser than unary/prefix; operands are cast-expressions, so `-a `f` -b` ==
  `f(-a, -b)` (symmetric). The slot is an assignment-expression (D4).
- **Same-delimiter problem (§5):** open and close are the same token. Suppress
  the operator interpretation inside the slot — Clang `BacktickIsOperator`
  (modeled on `GreaterThanIsOperator`), GCC `backtick_is_operator_p` (modeled on
  `greater_than_is_operator_p`).
- **Nesting vs. chaining (D3/§17.1):** "bare nesting" is *token-identical* to a
  left-associative D1 chain and therefore correctly accepted, not diagnosed, by
  both compilers (DEV-04 / DEV-G04). To nest, parenthesize the slot.
- **Keyword-escape (D10/§12):** the same backtick token, disambiguated purely by
  grammatical position (operand/declarator position → escaped identifier;
  post-operand position → infix operator). Yields an ordinary identifier;
  lookup/mangling/ABI unchanged.
- **ADL is normative (§17.4):** the slot must get the same ADL as the plain call.
  Clang carries it as an `UnresolvedLookupExpr`; GCC resolves a bare-name slot
  via explicit `perform_koenig_lookup` (the DEV-G05 defect, fixed in G10).
