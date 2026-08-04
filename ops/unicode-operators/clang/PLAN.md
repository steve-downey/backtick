# Unicode User-Defined Operators — Clang plan

The third implementation track. Where the backtick plans *tested* a design
that was already settled, this one tests a design that is entirely
**Proposed** (`docs/unicode-operators.md`, decisions U1–U12) — so the
deviation ledger matters more here, not less: every step is expected to
feed `docs/unicode-operators.md`, and several steps exist mainly to find
out whether a U-decision survives contact with Clang.

The narrative rationale (why this branch base, what the risk is) is
`ops/unicode-operators/clang-experiment-plan.md`. This file is the
operational document: it is what an agent reads.

## How to use this plan
1. Read `ops/AGENT_PROTOCOL.md` — it defines exactly how to execute one
   step. Substitute for this track:
   - plan → this file;
   - step files → `ops/unicode-operators/clang/steps/UNN-*.md`;
   - handoffs → `ops/unicode-operators/clang/handoffs/UNN-<slug>.handoff.md`;
   - deviations → `ops/unicode-operators/clang/DEVIATIONS.md` (DEV-UNN);
   - design doc → `docs/unicode-operators.md` (U§ sections, U1–U12),
     with `docs/backtick-operator-design.md` for anything §-numbered.
2. Find an unchecked step below whose dependencies are **all** checked.
   Dependencies are a DAG, not a line — where several steps qualify, take
   the lowest-numbered one unless the user directed otherwise.
3. Execute only that step. Then stop.

## Ground rules
- **One step per agent.** Never start the next step.
- **No green, no check.** A step's box is ticked only after its
  verification gate passes. If it can't pass, leave it unchecked, write a
  BLOCKED handoff, stop.
- **Gated and regression-free.** All new behavior sits behind
  `-funicode-operators` (`LangOptions` `UnicodeOperators`). A default
  build must behave exactly as upstream, *including* lexing every U1 code
  point exactly as today. `check-clang` must stay green.
- **Composable with `-fbacktick`, not dependent on it.** The two flags are
  independent (U7). Every step must work with backtick off, and the shared
  user-infix precedence level must parse identically under either, both,
  or neither flag.
- **Minimal diffs.** Touch only what the step names.
- **One commit per step**, message `[unicode] UNN: <title>`.
- **Two ledgers, not one.** Besides `DEVIATIONS.md`, every step appends to
  `REPLAY.md` classifying what it touched as `backtick dependency` /
  `upstream replay` / `shared if landed`. U19/U20 consume that ledger; a
  step that skips it costs the replay agent a rediscovery.

## Build & test (**pinned by U00, 2026-08-03 — these are measured, not intended**)
The experiment starts from the backtick trunk branch, which already carries
the user-infix precedence level, the `ParseRHSOfBinaryExpression` shape, the
AST-wrapper pattern, and the clang-format lessons. It gets **its own
worktree and build dir** so `backtick-trunk` and its build stay usable:
```bash
WT=/home/sdowney/src/llvm/unicode         # worktree, branch unicode-operators-experiment
B=/home/sdowney/src/llvm/build-unicode    # its own build dir
ninja -C "$B" clang                       # build   (~3299 edges, ~12 min cold)
ninja -C "$B" check-clang > gate.log 2>&1; echo "EXIT=$?"   # full gate (~12 min)
"$B"/bin/llvm-lit -sv "$WT"/clang/test/... # fast targeted gate (seconds)
```
Base: branch `unicode-operators-experiment` @ `bd6f4d5fa102` (= `backtick-trunk`
tip), 45 commits above `upstream/main` @ `bb33de72920a`. CMake line and the
full baseline are in `handoffs/U00-baseline.handoff.md`.

**Baseline gate shape on this base — green is ZERO failures:**
```
Total Discovered Tests: 54106
  Passed: 48220   Unsupported: 5853   Expectedly Failed: 27   Skipped: 6
  Failed: 0
```
Any non-zero `Failed` is a regression. Compare against *these* numbers.

Four gate facts, three inherited from the backtick track and all of which
have cost real time already:
- **`ninja … | tail` reports `tail`'s exit code.** Redirect and check `$?`.
- **`check-clang` self-formats `clang/lib/Format/`** and aborts at ~step
  81/970 — before any lit test runs — if the edits there don't match
  current LLVM style. Relevant to U18.
- The `Clang :: Format/dump-config-objc-stdin.m` failure caused by the stray
  2018 `/home/sdowney/src/.clang-format` is a **`backtick-23`-only** artifact.
  It **passes** on this trunk base (confirmed by U00, as by
  `ops/handoffs/14-rebase-trunk.handoff.md`). Do not budget a known failure
  for it; do not "fix" the stray file either.
- `check-clang` deliberately crashes clang twice on upstream XFAIL tests
  (`Analysis/reinterpret-cast-pointer-to-member.cpp`,
  `CodeGen/xfail-alloc-align-fn-pointers.cpp`), producing coredump/DrKonqi
  noise. Counted in `Expectedly Failed`; not ours. `ulimit -c 0` around the
  gate avoids writing the cores.

## Checklist

### Phase A — Base, flag, lexing
- [x] **U00** Experiment worktree, branch, baseline gate — `steps/U00-baseline.md`
- [ ] **U01** Flag `-funicode-operators` — `steps/U01-feature-flag.md` (dep: U00)
- [ ] **U02** Frozen U1 range table + exclusion table (generated) — `steps/U02-charset-tables.md` (dep: U00)
- [ ] **U03** Lexer: `tok::user_operator` from UTF-8 glyphs — `steps/U03-lexer-token.md` (dep: U01, U02)
- [ ] **U04** Lexer: UCN and `\N{...}` spellings (U11) — `steps/U04-lexer-ucn.md` (dep: U03)
- [ ] **U05** Exclusion diagnostics with reasons — `steps/U05-exclusion-diagnostics.md` (dep: U03)

### Phase B — The name (the hard part: open the operator-name table)
- [ ] **U06** `DeclarationName` kind for user operators — `steps/U06-declaration-name.md` (dep: U03)
- [ ] **U07** Parse `operator⊞` as an *operator-function-id* — `steps/U07-operator-function-id.md` (dep: U06)
- [ ] **U08** Sema declaration rules + arity (U2, U5) — `steps/U08-decl-rules.md` (dep: U07)
- [ ] **U09** Itanium mangling, vendor-extended form (U8) — `steps/U09-mangling.md` (dep: U07)
- [ ] **U10** Explicit-call sweep — `steps/U10-explicit-call-tests.md` (dep: U08, U09)

### Phase C — Expressions
- [ ] **U11** Infix parse at the user-infix level (U4) — `steps/U11-infix-parse.md` (dep: U08)
- [ ] **U12** Prefix parse in operand position (U5) — `steps/U12-prefix-parse.md` (dep: U11)
- [ ] **U13** Sema: candidate assembly + ADL, no built-ins (U6) — `steps/U13-overload-build.md` (dep: U11)
- [ ] **U14** Semantics sweep — `steps/U14-semantics-tests.md` (dep: U13, U12)
- [ ] **U15** Precedence/associativity sweep — `steps/U15-precedence-tests.md` (dep: U13, U12)

### Phase D — AST, serialization, tooling
- [ ] **U16** AST node + `-ast-print` fidelity — `steps/U16-ast-print.md` (dep: U13)
- [ ] **U17** Serialization, import, `TreeTransform`, visitors — `steps/U17-serialization.md` (dep: U16)
- [ ] **U18** clang-format — `steps/U18-clang-format.md` (dep: U04)

### Phase E — Upstream replay
- [ ] **U19** Replay-ledger audit — `steps/U19-replay-audit.md` (dep: U14, U15, U17, U18)
- [ ] **U20** Clean-`main` replay branch + gate — `steps/U20-upstream-replay.md` (dep: U19)

The fan-out points, so an agent can see where the plan widens: U01‖U02 after
U00; U04‖U05‖U06 after U03; U08‖U09 after U07; U12‖U13 after U11;
U14‖U15‖U16 after U13. Nothing in Phase B needs Phase A's UCN or diagnostic
work, and nothing in Phase C needs Phase B's mangling to be *good* — only to
exist.

## Status log (each agent appends one row)
| Step | Date | Branch | Commit | Gate result | Handoff |
|------|------|--------|--------|-------------|---------|
| U00 | 2026-08-03 | `unicode-operators-experiment` | `bd6f4d5fa102` (base, no source change) | `check-clang` GREEN — 54106 discovered / 48220 passed / **0 failed** / 27 XFAIL / 5853 unsupported / 6 skipped; 204s test time, 723s wall | `handoffs/U00-baseline.handoff.md` |
