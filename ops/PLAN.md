# Backtick Operator — Operational Plan (master)

This is the entry point. Read it fully before doing anything. The
architecture it implements is proven on paper in
`docs/backtick-operator-design.md`; this plan exists to *test* that it
holds in a real compiler. Every step is gated on passing builds and tests,
and every place reality contradicts the design is logged so the paper
author can fold it back in.

## How to use this plan
1. Read `ops/AGENT_PROTOCOL.md` — it defines exactly how to execute one step.
2. Find the first unchecked step below whose dependencies are all checked.
3. Execute only that step. Then stop.

## Ground rules
- **One step per agent.** Never start the next step.
- **No green, no check.** A step's box is ticked only after its
  verification gate passes. If it can't pass, leave it unchecked, write a
  BLOCKED handoff, stop.
- **Gated and regression-free.** All new behavior sits behind `-fbacktick`.
  A default build (flag off) must behave exactly as upstream. `check-clang`
  must stay green.
- **Minimal diffs.** Touch only what the step names.
- **One commit per step**, message `[backtick] SNN: <title>`.
- **Feedback loop.** If reality differs from `docs/backtick-operator-design.md`,
  append a row to `ops/DEVIATIONS.md` and note it in your handoff. The paper
  author reconciles deviations into the design's §3 decisions log.

## Build & test (S00 pins these; values below reflect the known-good setup)
The maintainer's main build lives at `/home/sdowney/src/llvm/build-main`
(source/git root `/home/sdowney/src/llvm/main`). It builds today. Feature
work happens in a **separate worktree + build dir** so the main build is
never disturbed — S00 creates them. The dev build trims runtimes/bootstrap
and turns assertions **on** for fast iteration and early invariant checks:
```bash
WT=/home/sdowney/src/llvm/backtick           # worktree (branch: backtick)
B=/home/sdowney/src/llvm/build-backtick        # its own build dir
ninja -C "$B" clang                           # build the compiler
ninja -C "$B" check-clang                     # full regression gate
"$B"/bin/llvm-lit -v clang/test/...           # fast targeted gate
```

## Checklist

### Phase A — Clang infix operator (MVP, desugar-only)
- [x] **S00** Baseline build + harness orientation — `ops/steps/00-baseline.md`
- [x] **S01** Feature flag `-fbacktick` — `ops/steps/01-feature-flag.md` (dep: S00)
- [x] **S02** Lexer: backtick punctuator token — `ops/steps/02-lexer-token.md` (dep: S01)
- [x] **S03** Parse + desugar to `CallExpr` — `ops/steps/03-infix-parse-sema.md` (dep: S02)
- [x] **S04** Diagnostics + nested-paren rule (D3) — `ops/steps/04-infix-diagnostics.md` (dep: S03)
- [x] **S05** Semantics test sweep — `ops/steps/05-infix-semantics-tests.md` (dep: S03)
- [x] **S06** Precedence/associativity test sweep — `ops/steps/06-infix-precedence-tests.md` (dep: S03)

### Phase B — Clang keyword-escaped identifiers (after infix)
- [x] **S07** Parser: keyword-escape, position-based — `ops/steps/07-escape-parse.md` (dep: S03)
- [x] **S08** Tentative-parse / decl-vs-expr integration — `ops/steps/08-escape-tentative.md` (dep: S07)
- [x] **S09** Escape test sweep + mangling check — `ops/steps/09-escape-tests.md` (dep: S08)

### Phase C — Tooling & source fidelity
- [x] **S10** clang-format (both uses) — `ops/steps/10-clang-format.md` (dep: S09)
- [x] **S11** AST wrapper for `-ast-print` fidelity — `ops/steps/11-ast-wrapper.md` (dep: S06)

### Phase D — Second implementation (GCC; full sub-plan in `ops/gcc/PLAN.md`)
- [x] **S12** GCC baseline & orientation — `ops/steps/12-gcc-bootstrap.md` (dep: A green)
  - then GCC steps **G01–G09** in `ops/gcc/PLAN.md`

## Status log (S00 + each agent appends one line)
| Step | Agent date | Branch | Commit | Gate result | Handoff |
|------|-----------|--------|--------|-------------|---------|
| S00  | 2026-06-14 | backtick | tip of `backtick` (base a815e6f267c1) | PASS (5 env-only known-fails) | ops/handoffs/00-baseline.handoff.md |
| S01  | 2026-06-14 | backtick | 6aec144f9244 | PASS (4 env-only known-fails, 52210 total, 46442 passed) | ops/handoffs/01-feature-flag.handoff.md |
| S02  | 2026-06-26 | backtick | 66bee2be5b15 | PASS (1 env-only known-fail, 52211 total, 46446 passed) | ops/handoffs/02-lexer-token.handoff.md |
| S03  | 2026-06-26 | backtick | ecceeff072ff | PASS (1 env-only known-fail, 52212 total, 46447 passed) | ops/handoffs/03-infix-parse-sema.handoff.md |
| S04  | 2026-06-26 | backtick | d9e633069702 | PASS (1 env-only known-fail, 52213 total, 46448 passed) | ops/handoffs/04-infix-diagnostics.handoff.md |
| S05  | 2026-06-26 | backtick | 08ea70ad08ed | PASS (1 env-only known-fail, 52214 total, 46449 passed) | ops/handoffs/05-infix-semantics-tests.handoff.md |
| S06  | 2026-06-27 | backtick | 0cfa70dd367c | PASS (1 env-only known-fail, 52215 total, 46450 passed) | ops/handoffs/06-infix-precedence-tests.handoff.md |
| S07  | 2026-06-27 | backtick | 0a9f8fc78fc2 | PASS (1 env-only known-fail, 52217 total, 46452 passed) | ops/handoffs/07-escape-parse.handoff.md |
| S08  | 2026-06-27 | backtick | 96ceb59a4cce | PASS (1 env-only known-fail, 52218 total, 46453 passed) | ops/handoffs/08-escape-tentative.handoff.md |
| S09  | 2026-06-27 | backtick | d84f91cbd5d4 | PASS (1 env-only known-fail, 52219 total, 46454 passed) | ops/handoffs/09-escape-tests.handoff.md |
| S10  | 2026-06-27 | backtick | f185e099e046 | PASS (1 env-only known-fail, 52223 total, 46450 passed, FormatTests 1270 all pass) | ops/handoffs/10-clang-format.handoff.md |
| S11  | 2026-06-27 | backtick | 4243342f5438 | PASS (1 env-only known-fail, 52224 total, 46459 passed) | ops/handoffs/11-ast-wrapper.handoff.md |
| S12  | 2026-06-27 | backtick | 3c7c36808000 | PASS — GCC 17.0.0 20260624 cc1plus built; g++.dg: 150598 pass, 9958 FAIL (6170 linker/libstdc++ absent, 3785 pre-existing trunk, 3 scan-tree-dump), 1001 xfail, 4213 unresolved, 1882 unsupported | ops/handoffs/12-gcc-bootstrap.handoff.md |
| R23  | 2026-07-28 | backtick-23 | 60f3e013b5b3 | PASS (1 env-only known-fail, 54340 total, 48498 passed) — maintenance rebase, not a plan step: base moved a815e6f267c1 (trunk 23.0.0git) → 561093d94eb7 (release/23.x, llvmorg-23.1.0-rc2); 44/44 commits replayed with no conflicts, feature diff byte-identical | ops/handoffs/13-rebase-release-23x.handoff.md |
| R24  | 2026-07-29 | backtick-trunk | bd6f4d5fa102 | PASS (0 failures, 54106 total, 48220 passed, 27 xfail) — maintenance rebase, not a plan step: second parallel branch on upstream/main @ bb33de72920a (24.0.0git); 44 commits replayed, 1 benign conflict in TokenAnnotatorTest.cpp, feature diff byte-identical to both prior states | ops/handoffs/14-rebase-trunk.handoff.md |
| F24  | 2026-08-04 | backtick-trunk | 439ceb5237dc, 169e45c7916f | PASS (54107 total, 48212 passed, 27 xfail; 10 failed = 8 known `DirectoryWatcherTest.*` inotify + 2 env-only, both proven name-driven by `CLANG_EXECUTABLE_VERSION=24-backtick`. Filtered rerun: 54099 total, 48212 passed, 2 failed) — two defect fixes, not plan steps: `-ast-print` crash on a non-`CallExpr` semantic form (DEV-06) and the static analyzer's five missing sites (DEV-07) | ops/handoffs/15-defect-fixes.handoff.md |
| F23  | 2026-08-04 | backtick-23 | 4aa89d354389, c280d8101f56 | PASS (54341 total, 48490 passed, 27 xfail; 11 failed = 8 known `DirectoryWatcherTest.*` inotify + the documented `Format/dump-config-objc-stdin.m` + the same 2 name-driven env-only. Filtered rerun: 54333 total, 48490 passed, 3 failed) — clean cherry-pick of F24's two commits, gate verified independently; both new lit tests passed unadjusted | ops/handoffs/15-defect-fixes.handoff.md |
