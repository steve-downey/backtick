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

**Waiting for a build or gate without losing your step.** Both exceed the
10-minute per-call ceiling, so start them in the background — but a
background command finishing does **not** resume you, and ending your turn
ends your step. U03 lost a full cycle to exactly this. Have the background command write its own completion marker, then block on
the marker inside one call and repeat that call until it returns:
```bash
# background:
ulimit -c 0; ninja -C "$B" check-clang > gate.log 2>&1; echo "EXIT=$?" >> gate.log
# foreground, repeat until it prints the tail:
until grep -q '^EXIT=' gate.log; do sleep 30; done; tail -3 gate.log
```
Repeating a blocking poll several times is correct and expected. Ending
your turn to "wait for a notification" is not.

Do **not** poll with `pgrep -f "ninja -C $B"`: the poll loop's own command
line contains that string, so `pgrep` matches itself and the loop never
exits. U03 hit this and reported "ninja still running" long after it had
finished. Grep the log for the marker, never the process table.

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

Five gate facts, three inherited from the backtick track and all of which
have cost real time already:
- **`ninja … | tail` reports `tail`'s exit code.** Redirect and check `$?`.
- **`check-clang` self-formats the Format sources** and aborts at ~step
  81/970 — before any lit test runs — if the edits there don't match
  current LLVM style. Corrected by U18: the glob covers
  **`clang/unittests/Format/*.cpp` as well as `clang/lib/Format/`**, and it
  formats with the **in-tree** `clang-format`, not an upstream binary. So
  format your test edits too, with the binary you just built.
- The `Clang :: Format/dump-config-objc-stdin.m` failure caused by the stray
  2018 `/home/sdowney/src/.clang-format` is a **`backtick-23`-only** artifact.
  It **passes** on this trunk base (confirmed by U00, as by
  `ops/handoffs/14-rebase-trunk.handoff.md`). Do not budget a known failure
  for it; do not "fix" the stray file either.
- **`DirectoryWatcherTest.*` (8 cases) fails when the machine's inotify watch
  budget is exhausted**, with `No space left on device : inotify_add_watch()`.
  First hit at U03 (2026-08-04): a `cloud-drive-dae` process held 65,045 of
  65,536 `fs.inotify.max_user_watches`. It is **not** ours — the untouched
  `build-backtick-trunk` binary fails the identical 8. Check
  `for p in /proc/[0-9]*/fdinfo/*; do grep -c '^inotify' $p; done | paste -sd+ | bc`
  against `/proc/sys/fs/inotify/max_user_watches` before believing a
  DirectoryWatcher failure. To gate around it:
  `GTEST_FILTER='-DirectoryWatcherTest.*' $B/bin/llvm-lit -s $B/tools/clang/test`
  runs exactly the `check-clang` set minus those 8.
- `check-clang` deliberately crashes clang twice on upstream XFAIL tests
  (`Analysis/reinterpret-cast-pointer-to-member.cpp`,
  `CodeGen/xfail-alloc-align-fn-pointers.cpp`), producing coredump/DrKonqi
  noise. Counted in `Expectedly Failed`; not ours. `ulimit -c 0` around the
  gate avoids writing the cores.

## Checklist

### Phase A — Base, flag, lexing
- [x] **U00** Experiment worktree, branch, baseline gate — `steps/U00-baseline.md`
- [x] **U01** Flag `-funicode-operators` — `steps/U01-feature-flag.md` (dep: U00)
- [x] **U02** Frozen U1 range table + exclusion table (generated) — `steps/U02-charset-tables.md` (dep: U00)
- [x] **U03** Lexer: `tok::user_operator` from UTF-8 glyphs — `steps/U03-lexer-token.md` (dep: U01, U02)
- [x] **U04** Lexer: UCN and `\N{...}` spellings (U11) — `steps/U04-lexer-ucn.md` (dep: U03)
- [x] **U05** Exclusion diagnostics with reasons — `steps/U05-exclusion-diagnostics.md` (dep: U03)

### Phase B — The name (the hard part: open the operator-name table)
- [x] **U06** `DeclarationName` kind for user operators — `steps/U06-declaration-name.md` (dep: U03)
- [x] **U07** Parse `operator⊞` as an *operator-function-id* — `steps/U07-operator-function-id.md` (dep: U06)
- [x] **U08** Sema declaration rules + arity (U2, U5) — `steps/U08-decl-rules.md` (dep: U07)
- [x] **U09** Itanium mangling, vendor-extended form (U8) — `steps/U09-mangling.md` (dep: U07)
- [x] **U10** Explicit-call sweep — `steps/U10-explicit-call-tests.md` (dep: U08, U09)

### Phase C — Expressions
- [x] **U11** Infix parse at the user-infix level (U4) — `steps/U11-infix-parse.md` (dep: U08)
- [x] **U12** Prefix parse in operand position (U5) — `steps/U12-prefix-parse.md` (dep: U11)
- [x] **U13** Sema: candidate assembly + ADL, no built-ins (U6) — `steps/U13-overload-build.md` (dep: U11)
- [x] **U14** Semantics sweep — `steps/U14-semantics-tests.md` (dep: U13, U12, **U16**)
- [x] **U15** Precedence/associativity sweep — `steps/U15-precedence-tests.md` (dep: U13, U12)

### Phase D — AST, serialization, tooling
- [x] **U16** AST node + `-ast-print` fidelity — `steps/U16-ast-print.md` (dep: U13)
- [x] **U17** Serialization, import, `TreeTransform`, visitors — `steps/U17-serialization.md` (dep: U16)
- [x] **U18** clang-format — `steps/U18-clang-format.md` (dep: U04)

### Phase G — Maintenance (not plan steps; R/M-prefixed, like the rebases)
- [x] **M1** Forward-port the backtick defect fixes — `steps/M1-forward-port-backtick-fixes.md` (dep: `ops/handoffs/15-defect-fixes.handoff.md` green on `backtick-trunk`)
- [x] **M2** Forward-port the backlog track's backtick fixes — D16 (BL02) and the
  B03/B04/B06/B08/B35 batch (BL06) — same hazard as M1: the merge goes to
  `unicode-operators-experiment` **only** and must not reach
  `unicode-operators-upstream`. (dep: `ops/backlog/PLAN.md` BL02 and BL06 both
  green on `backtick-trunk`; M1)
  **M1 left M2 a cleaner job than this description assumes.** M1 merged the
  *commit* `169e45c7916f`, not the `backtick-trunk` branch name, precisely so
  BL02 would stay M2's. So M2's merge base is `169e45c7916f`, already an
  ancestor of the experiment branch, and merging `backtick-trunk` now brings
  exactly BL02 (+ BL06 when green) and nothing else. Check the tip before
  merging and prefer an explicit commit — `backtick-trunk` moves.
  **Done 2026-09-06**, merging `5f70443430b8`: three commits (BL02, BL04's
  backtick CIR arms, and clang-paper-truth, `BL06` having been split by purpose
  into the completion plan), eight conflicts, none semantic. See
  [M2-forward-port](../../completion/handoffs/M2-forward-port.handoff.md).
- [x] **unicode-branch-maintenance** Forward-port the completion track's queued
  backtick work — [clang-slot-adl](../../completion/steps/clang-slot-adl.md),
  [evidence-debt](../../completion/steps/evidence-debt.md) and
  [hygiene-parity](../../completion/steps/hygiene-parity.md), plus
  [null-return-suppression](../../completion/steps/null-return-suppression.md)'s
  backtick half — and carry M2's `CheckUserOperatorDeclaration` comment fix to
  `unicode-operators-upstream`. Same hazard as M1 and M2: **the merge goes to
  `unicode-operators-experiment` only.** The comment fix is the exception that
  proves it — it is Unicode-side text and belongs on both branches.
  **Done 2026-09-07**, merging `c0d69702b6d7`: four commits, seven conflicts,
  none semantic; both branches gate green. See
  [unicode-branch-maintenance](../../completion/handoffs/unicode-branch-maintenance.handoff.md).
  **Named by slug rather than `M3`** — the ordinals here are a legacy the
  completion plan already retired; see `~/.claude/CLAUDE.md`.

M1 should run **before** `ops/backlog/PLAN.md`'s BL03, which fixes the static
analyzer for `UserOperatorExpr`: M1 puts the `BacktickInfixExpr` arms in the
same switches, immediately beside where the new ones go. BL03's replay onto
`unicode-operators-upstream` carries only the `UserOperatorExpr` half.

### Phase F — Design probes (not on the replay path)
- [x] **U21** Postfix feasibility probe — `steps/U21-postfix-probe.md` (dep: U12, U13)

### Phase E — Upstream replay
- [x] **U19** Replay-ledger audit — `steps/U19-replay-audit.md` (dep: U14, U15, U17, U18)
- [x] **U20** Clean-`main` replay branch + gate — `steps/U20-upstream-replay.md` (dep: U19)

The fan-out points, so an agent can see where the plan widens: U01‖U02 after
U00; U04‖U05‖U06 after U03; U08‖U09 after U07; U12‖U13 after U11;
U15‖U16 after U13. Nothing in Phase B needs Phase A's UCN or diagnostic
work, and nothing in Phase C needs Phase B's mangling to be *good* — only to
exist.

**U14 gained a dependency on U16 (added 2026-08-04, after U13).** As
planned, U16 was cosmetic — a wrapper for `-ast-print` fidelity. U13
measured it as load-bearing instead: because `CXXOperatorCallExpr` is
welded to `OverloadedOperatorKind`, a user-operator use is a plain
`CallExpr`, and `TreeTransform` rebuilds it at instantiation through
`ActOnCallExpr` — [over.match.call], not [over.match.oper]. ADL survives
(a property of the call); **member candidates do not** (a property of the
operator syntax). So a member `operator⊕` is not found in a template, and
`requires { a ⊕ b; }` is unsatisfied. U14 item 4 tests exactly that, so
U14 cannot be honest until U16 lands. See DEV-U12 part 3.

## Status log (each agent appends one row)
| Step | Date | Branch | Commit | Gate result | Handoff |
|------|------|--------|--------|-------------|---------|
| U00 | 2026-08-03 | `unicode-operators-experiment` | `bd6f4d5fa102` (base, no source change) | `check-clang` GREEN — 54106 discovered / 48220 passed / **0 failed** / 27 XFAIL / 5853 unsupported / 6 skipped; 204s test time, 723s wall | `handoffs/U00-baseline.handoff.md` |
| U01 | 2026-08-03 | `unicode-operators-experiment` | `3014f97cfc31` | `check-clang` GREEN — 54107 discovered / 48221 passed / **0 failed** / 27 XFAIL / 5853 unsupported / 6 skipped; 206s test time. Exactly baseline **+1** discovered/+1 passed (the new `Driver/funicode-operators.c`) | `handoffs/U01-feature-flag.handoff.md` |
| U02 | 2026-08-03 | `unicode-operators-experiment` | `2389fe7be452` | `check-clang` GREEN — 54121 discovered / 48235 passed / **0 failed** / 27 XFAIL / 5853 unsupported / 6 skipped; 168s test time. Exactly U01 **+14** discovered/+14 passed (the 14 `UnicodeOperatorCharSetsTest` cases). Tables measured: **1381 code points / 32 ranges / 256 bytes**; U1@17.0 ∩ XID@18.0 = ∅ | `handoffs/U02-charset-tables.handoff.md` |
| U03 | 2026-08-04 | `unicode-operators-experiment` | `dacbe22ddeef` | `check-clang` GREEN — 54128 discovered / 48234 passed / 27 XFAIL / 5853 unsupported / 6 skipped, **0 failed among the 54120 tests that could run**; the 8 `DirectoryWatcherTest.*` cases were blocked by an exhausted machine-wide inotify budget (65,045/65,536 watches held by `cloud-drive-dae`) and fail identically on the untouched `build-backtick-trunk` binary — see the gate-facts bullet above. Discovered is exactly U02 **+7** (6 new `LexerTest.UnicodeOperator*` cases + `Lexer/unicode-operators.cpp`), all 7 passing; `GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test` → exit 0, 54120 discovered / 48234 passed / **0 failed**. 174s test time | `handoffs/U03-lexer-token.handoff.md` |
| U06 | 2026-08-04 | `unicode-operators-experiment` | `9e4042cc2c76` | `check-clang` GREEN — 54137 discovered / 48243 passed / 27 XFAIL / 5853 unsupported / 6 skipped, **0 failed among the 54129 tests that could run**; the same 8 `DirectoryWatcherTest.*` cases were blocked by the machine-wide inotify budget (65,382/65,536 watches held at gate time) — see the gate-facts bullet. Discovered is exactly U03 **+9** (the 9 new `UserOperatorNameTest.*` cases), all 9 passing; `GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test` → **exit 0**, 54129 discovered / 48243 passed / **0 failed**. 169s test time. Build warning-clean. | `handoffs/U06-declaration-name.handoff.md` |
| U07 | 2026-08-04 | `unicode-operators-experiment` | `35def05cdb7c` | `check-clang` GREEN — 54138 discovered / 48244 passed / 27 XFAIL / 5853 unsupported / 6 skipped, **0 failed among the 54130 tests that could run**; the same 8 `DirectoryWatcherTest.*` cases were blocked by the machine-wide inotify budget (65,382 of 65,536 watches held at gate time) — see the gate-facts bullet. Discovered is exactly U06 **+1** (the new `Parser/unicode-operator-decl.cpp`, 4 RUN lines), passing; `GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test` → **exit 0**, 54130 discovered / 48244 passed / **0 failed**, zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines. 208s test time (170s on the filtered re-run). Build warning-clean, 169 edges. | `handoffs/U07-operator-function-id.handoff.md` |
| U08 | 2026-08-04 | `unicode-operators-experiment` | `07901af9f62d` | `check-clang` GREEN — 54140 discovered / 48246 passed / 27 XFAIL / 5853 unsupported / 6 skipped, **0 failed among the 54132 tests that could run**; the same 8 `DirectoryWatcherTest.*` cases were blocked by the machine-wide inotify budget (65,382 of 65,536 watches held at gate time) — see the gate-facts bullet. Discovered is exactly U07 **+2** (new `SemaCXX/unicode-operator-decl.cpp` and the new `UserOperatorDeclTest` gtest case), both passing; `GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test` → **exit 0**, 54132 discovered / 48246 passed / **0 failed**, zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines. 215s test time (172s on the filtered re-run). Build exit 0, 1002 edges; the one `warning:` line is the pre-existing backtick-track `-Wswitch` on `BacktickInfixExprClass` in `StaticAnalyzer/Core/ExprEngine.cpp`, not U08's. | `handoffs/U08-decl-rules.handoff.md` |
| U09 | 2026-08-04 | `unicode-operators-experiment` | `77f6a10f9bb4` | `check-clang` GREEN — 54141 discovered / 48247 passed / 27 XFAIL / 5853 unsupported / 6 skipped, **0 failed among the 54133 tests that could run**; the same 8 `DirectoryWatcherTest.*` cases were blocked by the machine-wide inotify budget (65,382 of 65,536 watches held at gate time) — see the gate-facts bullet. Discovered is exactly U08 **+1** (the new `CodeGenCXX/unicode-operator-mangle.cpp`, 3 RUN lines), passing; `GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test` → **exit 0**, 54133 discovered / 48247 passed / **0 failed**, zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines. 165s test time (171s on the filtered re-run). Build exit 0, 17 edges, **zero** `warning:` lines — the pre-existing `BacktickInfixExprClass` `-Wswitch` gap did not resurface, because U09 touches no header. | `handoffs/U09-mangling.handoff.md` |
| U10 | 2026-08-04 | `unicode-operators-experiment` | `e035e4db8e18` | `check-clang` GREEN — 54143 discovered / 48249 passed / 27 XFAIL / 5853 unsupported / 6 skipped, **0 failed among the 54135 tests that could run**; the same 8 `DirectoryWatcherTest.*` cases were blocked by the machine-wide inotify budget (65,382 of 65,536 watches held at gate time) — see the gate-facts bullet. Discovered is exactly U09 **+2** (the two new lit tests, `SemaCXX/unicode-operator-call.cpp` and `CodeGenCXX/unicode-operator-call.cpp`), both passing; `GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test` → **exit 0**, 54135 discovered / 48249 passed / **0 failed**, zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines. 167.6 s test time (167.6 s on the filtered re-run). **No build at all** — U10 changed no production file, which is the step's result and not merely its cost. | `handoffs/U10-explicit-call-tests.handoff.md` |
| U11 | 2026-08-04 | `unicode-operators-experiment` | `02b0b96cf2e5` | `check-clang` GREEN — 54144 discovered / 48250 passed / 27 XFAIL / 5853 unsupported / 6 skipped, **0 failed among the 54136 tests that could run**; the same 8 `DirectoryWatcherTest.*` cases were blocked by the machine-wide inotify budget (65,382 of 65,536 watches held at gate time) — see the gate-facts bullet. Discovered is exactly U10 **+1** (the new `Parser/unicode-operator-infix.cpp`, 6 RUN lines), passing; `GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test` → **exit 0**, 54136 discovered / 48250 passed / **0 failed**, zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines. 208.2 s test time (190.4 s on the filtered re-run). Build exit 0, 160 edges, **zero** `warning:` lines — the pre-existing `BacktickInfixExprClass` `-Wswitch` gap did not resurface (no static-analyzer TU was recompiled). 5 production files, +96/−8. | `handoffs/U11-infix-parse.handoff.md` |
| U13 | 2026-08-04 | `unicode-operators-experiment` | `27dc597998dc` | `check-clang` GREEN — 54145 discovered / 48251 passed / 27 XFAIL / 5853 unsupported / 6 skipped, **0 failed among the 54137 tests that could run**; the same 8 `DirectoryWatcherTest.*` cases were blocked by the machine-wide inotify budget (65,382 of 65,536 watches held at gate time) — see the gate-facts bullet. Discovered is exactly U11 **+1** (the new `SemaCXX/unicode-operator-adl.cpp`, 3 RUN lines), passing; `GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test` → **exit 0**, 54137 discovered / 48251 passed / **0 failed**, zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines. 207.8 s test time (177.3 s on the filtered re-run). Build exit 0, **zero** `warning:` lines — the pre-existing `BacktickInfixExprClass` `-Wswitch` gap did not resurface. 3 production files, +207/−40. | `handoffs/U13-overload-build.handoff.md` |
| U16 | 2026-08-04 | `unicode-operators-experiment` | `f4fec96f7c41` | `check-clang` GREEN — 54146 discovered / 48252 passed / 27 XFAIL / 5853 unsupported / 6 skipped, **0 failed among the 54138 tests that could run**; the same 8 `DirectoryWatcherTest.*` cases were blocked by the machine-wide inotify budget (65,382 of 65,536 watches held at gate time) — see the gate-facts bullet. Discovered is exactly U13 **+1** (the new `AST/unicode-operator-print.cpp`, 7 RUN lines), passing; `GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test` → **exit 0**, 54138 discovered / 48252 passed / **0 failed**, zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines. 200.1 s test time (174.8 s on the filtered re-run). Build exit 0; the one `warning:` line is the pre-existing backtick-track `-Wswitch` on `BacktickInfixExprClass` in `StaticAnalyzer/Core/ExprEngine.cpp` — U16's own `UserOperatorExprClass` gap appeared there on the first build and was closed, leaving that switch missing only backtick's case. 31 production files, +437/−22. **The two `FIXME(U16)` shapes now pass**; `-emit-llvm` byte-identical to the pre-U16 binary. | `handoffs/U16-ast-print.handoff.md` |
| U17 | 2026-08-04 | `unicode-operators-experiment` | `8ec6095c41fb` | `check-clang` GREEN — 54163 discovered / 48269 passed / 27 XFAIL / 5853 unsupported / 6 skipped, **0 failed among the 54155 tests that could run**; the same 8 `DirectoryWatcherTest.*` cases were blocked by the machine-wide inotify budget (65,382 of 65,536 watches held at gate time) — see the gate-facts bullet. Discovered is exactly U16 **+17** (3 new lit tests — `PCH/unicode-operators.cpp`, `Modules/unicode-operators.cppm`, `Modules/unicode-operators-odr.cpp` — plus 14 new gtest cases: 12 `ImportUnicodeOperators` and 2 `ASTMatchersTestUnicodeOperators`), all 17 passing; `GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test` → **exit 0**, 54155 discovered / 48269 passed / **0 failed**, zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines. 173.9 s test time (174.3 s on the full run). Build exit 0; the one `warning:` line is the pre-existing backtick-track `-Wswitch` on `BacktickInfixExprClass`, which appeared in `libclang/CXCursor.cpp:175` naming **both** enumerators until U17 closed its own half. 9 production files, +88/−17; 15 files total, +658/−17. **U16's untested expression serialization worked on first run**; the five deferred `DeclarationNameKey` sites are filled and no `llvm_unreachable` naming U17 remains. | `handoffs/U17-serialization.handoff.md` |
| U12 | 2026-08-04 | `unicode-operators-experiment` | `8a84ef99a79c` | `check-clang` GREEN — and green *unfiltered* for the first time since U03: 54164 discovered / 48278 passed / 27 XFAIL / 5853 unsupported / 6 skipped / **0 failed**, `EXIT=0`, zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines, 194.2 s test time. **No filtered re-run was needed**: the 8 `DirectoryWatcherTest.*` cases every step since U06 has had to filter out all passed this time, the machine's inotify budget having freed up. Arithmetic against U17: discovered 54163 **+1** (the new `Parser/unicode-operator-prefix.cpp`, 6 RUN lines); passed 48269 **+9** = that one test **+** the 8 recovered `DirectoryWatcherTest` cases. Build exit 0, 16 edges, **zero** `warning:` lines — U12 touches one `.cpp` and no header, so neither pre-existing backtick `-Wswitch` gap resurfaced. **1 production file, +40/−0** (`clang/lib/Parse/ParseExpr.cpp`); 6 files total, +213/−0. | `handoffs/U12-prefix-parse.handoff.md` |
| U14 | 2026-08-04 | `unicode-operators-experiment` | `608ee6925c7a` | `check-clang` GREEN and **unfiltered** for the second run in a row: 54166 discovered / 48280 passed / 27 XFAIL / 5853 unsupported / 6 skipped / **0 failed**, `EXIT=0`, zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines, 171.2 s test time. The 8 `DirectoryWatcherTest.*` cases passed again, so no `GTEST_FILTER` re-run was needed. Discovered is exactly U12's 54164 **+2** (the two new tests, `SemaCXX/unicode-operator-semantics.cpp` with 6 RUN lines and `CodeGenCXX/unicode-operator-semantics.cpp` with 5), passed 48278 **+2**; no existing test changed behaviour. **No build of any production file — U14 changed none**, which is the step's result and not merely its cost (the 165 link edges the gate rebuilt were leftover non-clang tools, and the log has zero `warning:` lines). Targeted re-run over `clang/test/{SemaCXX,CodeGenCXX,Parser,AST,PCH,Modules}`: 4877 discovered / 4810 passed / **0 failed** / 9 XFAIL / 58 unsupported, 13.7 s. | `handoffs/U14-semantics-tests.handoff.md` |
| U15 | 2026-08-04 | `unicode-operators-experiment` | `c25fdda912be` | `check-clang` GREEN — 54167 discovered / 48273 passed / 27 XFAIL / 5853 unsupported / 6 skipped, **0 failed among the 54159 tests that could run**; the 8 `DirectoryWatcherTest.*` cases were blocked by the machine-wide inotify budget again (65,382 of 65,536 watches held at gate time), ending the two-run unfiltered streak U12/U14 had — see the gate-facts bullet. `GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test` → **exit 0**, 54159 discovered / 48273 passed / **0 failed**, zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines. Like for like against U14's filtered equivalent (54158 / 48272) that is exactly **+1** discovered / **+1** passed — the new `Parser/unicode-operator-precedence.cpp`, 9 RUN lines. 180.0 s test time (166.2 s on the filtered re-run). **No build of any production file — U15 changed none**, the third such step after U10 and U14; zero `warning:` lines in the gate log. | `handoffs/U15-precedence-tests.handoff.md` |
| U04 | 2026-08-04 | `unicode-operators-experiment` | `6ffc374fa25a` | `check-clang` GREEN — 54175 discovered / 48281 passed / 27 XFAIL / 5853 unsupported / 6 skipped, **0 failed among the 54167 tests that could run**; the 8 `DirectoryWatcherTest.*` cases were blocked by the machine-wide inotify budget again (65,382 of 65,536 watches held at gate time) — see the gate-facts bullet. `GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test` → **exit 0**, 54167 discovered / 48281 passed / **0 failed**, zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines. Against U15's filtered baseline (54159 / 48273) that is exactly **+8** discovered / **+8** passed — 3 new lit tests (`Lexer/unicode-operators-ucn.cpp`, `Lexer/unicode-operators-c-mode.c`, `Lexer/backtick-c-mode.c`) and 5 new `LexerTest.UnicodeOperator*UCN*` cases; no existing test changed behaviour. 172.6 s test time (163.8 s on the filtered re-run). Build exit 0 (709 edges — an `Options.td` + `Lexer.h` edit); the only two `warning:` lines are the pre-existing backtick-track `-Wswitch` on `BacktickInfixExprClass` in `StaticAnalyzer/Core/ExprEngine.cpp` and `tools/libclang/CXCursor.cpp`, neither U04's. **3 production files, +145/−10**; 12 files total. **Phase A is complete except U05.** | `handoffs/U04-lexer-ucn.handoff.md` |
| U05 | 2026-08-04 | `unicode-operators-experiment` | `a893a3fb5c66` | `check-clang` GREEN — 54177 discovered / 48283 passed / 27 XFAIL / 5853 unsupported / 6 skipped, **0 failed among the 54169 tests that could run**; the same 8 `DirectoryWatcherTest.*` cases were blocked by the machine-wide inotify budget (65,382 of 65,536 watches held at gate time) — see the gate-facts bullet. `GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test` → **exit 0**, 54169 discovered / 48283 passed / **0 failed**, zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines. Against U04's filtered baseline (54167 / 48281) that is exactly **+2** discovered / **+2** passed — the new `Lexer/unicode-operators-excluded.cpp` (3 RUN lines) and the new `LexerTest.UnicodeOperatorExcludedCodePointEndsAnIdentifier` case; **no existing test changed behaviour** except `Lexer/unicode-operators-ucn.cpp`, whose EXCL block was tightened because U05 decided the asymmetry it recorded. 166.1 s test time. Build exit 0 (a `DiagnosticLexKinds.td` + `Lexer.h` edit, so two full rebuilds); the only two `warning:` lines are the pre-existing backtick-track `-Wswitch` on `BacktickInfixExprClass` in `StaticAnalyzer/Core/ExprEngine.cpp` and `tools/libclang/CXCursor.cpp`, neither U05's. **5 production files, +201/−2**; 8 files total, +432/−13. **Phase A is complete.** | `handoffs/U05-exclusion-diagnostics.handoff.md` |
| U18 | 2026-08-04 | `unicode-operators-experiment` | `06735e8df66d` | `check-clang` GREEN — 54179 discovered / 48285 passed / 27 XFAIL / 5853 unsupported / 6 skipped, **0 failed among the 54171 tests that could run**; the same 8 `DirectoryWatcherTest.*` cases were blocked by the machine-wide inotify budget (65,382 of 65,536 watches held at gate time) — see the gate-facts bullet. `GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test` → **exit 0**, 54171 discovered / 48285 passed / **0 failed**, zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines. Against U05's filtered baseline (54169 / 48283) that is exactly **+2** discovered / **+2** passed — the two new gtest cases, `FormatTest.UnicodeOperatorFormatting` and `TokenAnnotatorTest.UnicodeOperatorTokenTypes`; **no existing test changed behaviour** (`FormatTests` 1273 → 1275, all passing). 160.9 s test time (160.6 s on the filtered re-run). Build exit 0, **zero** `warning:` lines. **The self-format trap was cleared**: 90 `Checking format of` steps ran and the gate reached lit — the upstream `clang-format -i` was applied to `TokenAnnotator.cpp` and `FormatTest.cpp` before gating (the glob covers `unittests/Format/` too, which the gate facts do not say). **3 production files, +32/−9**; 5 files total, +201/−10. | `handoffs/U18-clang-format.handoff.md` |
| U19 | 2026-08-04 | `unicode-operators-experiment` | **no source change** — audit only; branch stays at `06735e8df66d` (U18), working tree clean | **No `check-clang` requirement** (the step changes no compiler file). The "before" number carried forward for U20 is U18's: filtered `GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test` → **exit 0, 54171 discovered / 48285 passed / 0 failed** / 27 XFAIL / 5853 unsupported / 6 skipped; unfiltered `check-clang` 54179 / 48285 / 8 failed, all 8 `DirectoryWatcherTest.*` (machine inotify budget). Audit gates instead: **every one of the 110 files in `backtick-trunk..HEAD` carries a classification**, in both directions (no file lacks a ledger row; no ledger row names a file absent from the diff), and the proposed 15-commit upstream stack mentions backtick in **no** title, body or content. Measured: **204 hunks** (`-U0`) = 171 production + 33 test/doc; **171 verbatim `upstream replay` (83.8 %) / 27 mixed (13.2 %) / 3 `shared if landed` (1.5 %) / 3 `backtick dependency`, deleted (1.5 %)** — **98.5 % of hunks survive onto clean `main`**, and the entire backtick coupling is three constructs (`prec::UserInfix`, `isFoldOperator`'s exclusion, clang-format's `endsOperand`). Six ledger errors corrected, the largest being two undocumented `diff`-pair RUN lines (`AST/unicode-operator-print.cpp`, `PCH/unicode-operators.cpp`) and clang-format's real dependency on the precedence commit. **In this repo:** `REPLAY.md` §"U19 — the audit and the verdict" (8 sections), `DEVIATIONS.md` **DEV-U21**, this row, the handoff. | `handoffs/U19-replay-audit.handoff.md` |
| U20 | 2026-08-04 | **`unicode-operators-upstream`** (new: worktree `/home/sdowney/src/llvm/unicode-upstream`, build `/home/sdowney/src/llvm/build-unicode-upstream`) | `44299aae010d` — a **15-commit stack** on `upstream/main` @ **`d28193fa1ff6`**, 825 commits past the experiment base | `check-clang` GREEN on the replay branch — 54239 discovered / 48314 passed / 27 XFAIL / 5884 unsupported / 6 skipped, **0 failed among the 54231 tests that could run**; the same 8 `DirectoryWatcherTest.*` cases blocked by the machine inotify budget (65,382 of 65,536). `GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test` → **exit 0, 54231 / 48314 / 0 failed**. **A pristine-`main` baseline was measured first in the same build dir**: unfiltered 54167 / 48242 / 8 DW-failed, filtered **exit 0, 54159 / 48242 / 0**. The replay is therefore exactly **+72 discovered / +72 passed** — 20 lit files + 52 gtest cases, U19 §6's prediction to the test — with **no pre-existing test changing behaviour**. 90 `Checking format of` steps ran before lit (self-format trap cleared with the in-tree `clang-format -i`). **`git diff upstream/main..unicode-operators-upstream \| grep -i backtick` returns nothing.** **Flag-off ≡ upstream, measured:** a TU with U1 code points in every position gives byte-identical `-fsyntax-only` diagnostics and byte-identical `-E` output against a `clang` built from pristine `d28193fa1ff6` in the same build dir, and byte-identical `-emit-llvm` but for the `!llvm.ident` commit hash. **Cost, the number the paper quotes: 109 files, +7073/−18 — production 77 files, +1940/−18; tests 32 files, +5133; 200 hunks (168 production).** Against the experiment branch's 110 / +7341/−29 / 204 hunks: **200 of 204 hunks landed**, vs U19's predicted 201. **Nothing turned out to require the backtick diff.** | `handoffs/U20-upstream-replay.handoff.md` |
| U21 | 2026-08-04 | **no code landed** — `unicode-operators-experiment` stays at `06735e8df66d`, `unicode-operators-upstream` stays at `44299aae010d`; the throwaway prototype lives on scratch branch `unicode-postfix-probe-scratch` @ `c929b9ee000d` (1 file, +68), never merged | plan repo only | **Probe gate, not a feature gate.** No `check-clang` requirement: no compiler file changed on any named branch. The prototype *was* built and run (`ninja -C build-unicode clang` → `EXIT=0`, 16 edges) and then reverted; after restoring the branch and rebuilding (`EXIT=0`, 6 edges) the 15 Unicode lit tests are **15/15 passing** and `git status --porcelain` is empty, so the tree is exactly as U20 left it. Findings gate: every claim in the step file's §1 confirmed or refuted with file:line — (1) confirmed, `operator++` dodges the question because it has no infix form, and postfix-ness has **no representation** in Clang (re-derived from `OO_PlusPlus` + argument count at `ExprCXX.cpp` `getSourceRangeImpl`, `StmtPrinter.cpp` `VisitCXXOperatorCallExpr`, `TreeTransform.h` `isPostIncDec`, after `SemaOverload.cpp` `CreateOverloadedUnaryOp` synthesizes an `IntegerLiteral 0`); (2) confirmed, the `int` dummy is spent by U2 (`SemaDeclCXX.cpp` `CheckUserOperatorDeclaration` says so in a comment); (3) confirmed-and-resolved — greedy-infix keeps U3, the tag is inert for parsing and does its work in Sema; (4) **refuted as stated** — the witness set is not "prefix-unary ∩ infix-binary" but every cast-expression starter, which adds `++ -- ( [` and **`&&`**. **Ambiguity resolvable in 68 lines, one file, one token of lookahead, no backtracking.** Four costs measured: the `&&`/dialect-dependence problem; the `expected expression` → no-viable-overload regression that changes **4 existing negative tests**; the Itanium collision (Clang emits `pp` for both `++` forms where **GCC 15.2 emits `pp_`/`pp`** — a live cross-vendor defect found here); and LEWG joining the routing. **Decisive result: greedy-infix is a pure extension — it only reinterprets programs v1 rejects**, so v1 declines postfix for free. | `handoffs/U21-postfix-probe.handoff.md` |
| M1 | 2026-08-09 | `unicode-operators-experiment` | `760a11f0b444` — **merge commit**, `git merge --no-ff 169e45c7916f`; 9 files, +181/−5, **no conflicts and no hand edits** | **`check-clang` GREEN, unfiltered, `EXIT=0`** — 54181 discovered / 48295 passed / **0 failed** / 27 XFAIL / 5853 unsupported / 6 skipped, 390.6 s. (Run after BL03's commit; the two steps contribute +1 discovered test each.) Against U18's unfiltered 54179 / 48285 / **8 failed**: discovered **+2**, passed **+10** = those 2 **+8** recovered `DirectoryWatcherTest.*` cases (B31's root fix), failed **8 → 0**. **Build warning-free — the acceptance signal**: the two pre-existing backtick `-Wswitch` gaps every step since U08 reported are gone (grepped, not inferred; `WERROR` is OFF). **Feature diff unchanged, which is what the merge bought:** `git diff 169e45c7916f..760a11f0b444` = **110 files / 204 hunks / +7341/−29**, U19's audit figures exactly, so U19's classification and U20's replay stay valid. **Merged the commit, not the branch tip** — `backtick-trunk` has since gained BL02, which is M2's. **No conflicts arose** despite the step predicting two; both nodes' arms verified present in `ExprEngine.cpp` (`:1879` backtick, `:1924` user-operator) and `StmtPrinter.cpp` rather than assumed. **`UserOperatorExpr` has no analogue of the F23 crash** — infix, prefix, member and lifetime-extended shapes all clean under `-ast-print` *and* `debug.DumpCFG` on **both** Unicode branches, because `getOperand` already reaches operands via `getSemanticForm()->IgnoreImplicit()` and `dyn_cast`s rather than `cast`s. **`unicode-operators-upstream` deliberately NOT merged** and unchanged at `44299aae010d`; `git diff upstream/main..HEAD \| grep -i backtick` still returns nothing. | `handoffs/M1-forward-port.handoff.md` |
| M2 | 2026-09-06 | `unicode-operators-experiment` | `85734d71ce1c` — **merge commit**, `git merge --no-ff 5f70443430b8`; 23 files, **eight conflicts, none semantic** (`Options.td` and `test/Lexer/backtick-c-mode.c` already-applied → ours; `Sema.h` and `SemaExpr.cpp` both-sides-at-one-anchor → keep both; the four CIR files' shared lead comments → ours, the arms being textually identical). Plus `de76585ae45d`, a comment-only fix to `CheckUserOperatorDeclaration`'s static-member reason, which [over-oper-restrictions](../../../docs/open-decisions.md#over-oper-restrictions) rejected on 2026-09-06. `unicode-operators-upstream` **untouched**, still `783a9c1a5f6f`. | **`check-clang` GREEN, unfiltered, `EXIT=0`** — 54183 discovered / 48295 passed / **0 failed** / 27 XFAIL / 5855 unsupported / 6 skipped, 370.79 s; **exactly the Baselines row**, the merge adding no test file this branch lacked. Build `EXIT=0`, zero warnings. The fold guard was verified by **deleting** it and watching `Parser/unicode-operator-precedence.cpp` fail at line 322, then restoring it. | [M2-forward-port](../../completion/handoffs/M2-forward-port.handoff.md) |
| unicode-branch-maintenance | 2026-09-07 | `unicode-operators-experiment` | `7278a2985659` — **merge commit**, `git merge --no-ff c0d69702b6d7`; four commits (null-return-suppression's backtick half, evidence-debt's template `-ast-print` test, clang-slot-adl, hygiene-parity), 17 files, **+484/−14** with every deleted line backtick text. **Seven conflicts, none semantic** — four *keep both, backtick after Unicode* at anchors `U17` and hygiene-parity both chose (`ASTMatchers.h`, `ASTMatchersInternal.cpp`, `CXCursor.cpp`, `ASTMatchFinder.cpp`), two test blocks sharing a closing brace, one already-applied where this branch's `peelOffOuterExpr` comment names both features. Plus `8c2a90f56b00` on **`unicode-operators-upstream`**, M2's `CheckUserOperatorDeclaration` comment copied verbatim, which closes the divergence M2 left. The merge did **not** and must never reach that branch. | **`check-clang` GREEN on both, unfiltered, `EXIT=0`** — experiment **54189 / 48301 / 0** (baseline 54184/48296, so +5/+5 from 2 lit files and 3 gtest cases), upstream **54242 / 48324 / 0**, exactly its baseline. XFAIL 27, skipped 6 on both. Builds `EXIT=0`, zero warnings. The fold guard was verified by **deleting** `Level != prec::UserInfix` and watching `Parser/unicode-operator-precedence.cpp` fail on **line 322 only**, then restoring it — a second confirmation that only the right fold pins it. | [unicode-branch-maintenance](../../completion/handoffs/unicode-branch-maintenance.handoff.md) |
| escape-positions-forward-port | 2026-09-08 | `unicode-operators-experiment` | `e09b559d631c` — **merge commit**, `git merge --no-ff 14f6373ccc7d`; two commits ([settle-paper-rows](../../completion/steps/settle-paper-rows.md)'s fourth type-slot shape, [escape-name-positions](../../completion/steps/escape-name-positions.md)'s broad keyword escape), 20 files, **+437/−82**, **no conflict** — the delta is exactly the two commits' own totals and every deleted line is theirs. The printers were the predicted collision and were not one: this branch has no change in `DeclPrinter.cpp`, `TypePrinter.cpp` or `NestedNameSpecifier.cpp`, and its `StmtPrinter.cpp` arm is `VisitUserOperatorExpr`. `unicode-operators-upstream` **untouched**, still `8c2a90f56b00`, and must never receive this merge. | **`check-clang` GREEN, unfiltered, `EXIT=0`, first run** — **54190 / 48302 / 0**, XFAIL 27, unsupported 5855, skipped 6, 662.51 s: +1/+1 over the baseline from the one new lit file. Build `EXIT=0`, 750 targets, zero warnings. The fold guard was verified by **deleting** `Level != prec::UserInfix` and watching `Parser/unicode-operator-precedence.cpp` fail on **line 322 only**, then restoring it — a third confirmation that only the right fold pins it. Flag-off parity byte-identical against the pristine `build-main` binary in `-fsyntax-only`, `-ast-print` and `-ast-dump`. | [escape-positions-forward-port](../../completion/handoffs/escape-positions-forward-port.handoff.md) |
| escape-name-sweep-forward-port | 2026-09-08 | `unicode-operators-experiment` | `5fd79178d2a7` — **merge commit**, `git merge --no-ff bd8790f9d0ef`; one commit ([escape-name-sweep](../../completion/steps/escape-name-sweep.md)'s five parser arms for the escape in a qualified type name, plus `ConsumeBacktickEscape` reporting the escape's extent and dropping its unconditional `PP.EnterToken` for the `AnnotateScopeToken` idiom), 7 files, **+268/−14**, **no conflict** — the delta is exactly the incoming commit's own totals, every deleted line is its own, and **five of the seven files are byte-identical to `backtick-trunk`**. The predicted collision in `isCXXDeclarationSpecifier`'s switch could not have happened: **that function carries no Unicode arm**, this branch's only `ParseTentative.cpp` change being `TryParseOperatorId`'s, 260 lines away. `unicode-operators-upstream` **untouched**, still `8c2a90f56b00`, and must never receive this merge. | **`check-clang` GREEN, unfiltered, `EXIT=0`** — **54190 / 48302 / 0**, XFAIL 27, unsupported 5855, skipped 6, 213.49 s: exactly the Baselines row, delta 0. Build `EXIT=0`, 34 targets, zero warnings. The fold guard was verified by **deleting** `Level != prec::UserInfix` and watching `Parser/unicode-operator-precedence.cpp` fail on **line 322 only** in four stanzas, then restoring it — a fourth confirmation. Probes re-run on this branch's binary: **79/79 / 79/79** positions with the qualified category **25/25**, 23 × 2 error paths all diagnosing and stopping, flag-off parity byte-identical against pristine `build-main`. **Four gate runs were needed**, three lost to [`inotify-watch-budget`](../../BACKLOG.md#inotify-watch-budget) at 523,732 of 524,288 watches — confirmed by cause, by control and by a different failing subset each run, and neither filtered nor budgeted. | [escape-name-sweep-forward-port](../../completion/handoffs/escape-name-sweep-forward-port.handoff.md) |
| slot-callable-forward-port | 2026-09-08 | `unicode-operators-experiment` | `0041778f1d4e` — **merge commit**, `git merge --no-ff 28b685c86ea2`; one commit ([slot-callable-printing](../../completion/steps/slot-callable-printing.md)'s two arms for a slot whose value is a class-typed callable, whose call Sema keys as a `CXXOperatorCallExpr` with `OO_Call` and whose operands therefore sit at arguments 1 and 2), 5 files, **+131/−13**, **no conflict** — the delta is exactly the incoming commit's own totals, its 13 deleted lines are identical as a set to the commit's own and none is Unicode text, and **the three test files are byte-identical to `backtick-trunk`**. The predicted collision was the first plausible one — `StmtPrinter.cpp` carries `VisitUserOperatorExpr` here and `VisitBacktickInfixExpr` is what the commit edits — and was **settled by `git diff --numstat` before the merge rather than explained after it**: 640 lines and one function apart. `unicode-operators-upstream` **untouched**, still `8c2a90f56b00`, and must never receive this merge. | **`check-clang` GREEN, unfiltered, `EXIT=0`, first run** — **54190 / 48302 / 0**, XFAIL 27, unsupported 5855, skipped 6, 198.94 s: exactly the Baselines row, delta 0. Build `EXIT=0`, zero warnings. The fold guard was verified by **deleting** `Level != prec::UserInfix` and watching `Parser/unicode-operator-precedence.cpp` fail on **line 322 only** in four stanzas, then restoring it — a fifth confirmation. **`UserOperatorExpr::getOperand` needs no equivalent arm, proven with a program**: six shapes, including a Unicode operator whose operand is a class-typed callable and both features in one expression, print as written and the printed output re-parses clean. There is no `OverloadedOperatorKind` for ⊞, so the `OO_Call` re-keying that broke the backtick arm cannot arise. Probes re-run: **79/79 / 79/79** positions, 23 × 2 error paths diagnosing and stopping, flag-off parity byte-identical against pristine `build-main`. | [slot-callable-forward-port](../../completion/handoffs/slot-callable-forward-port.handoff.md) |
| escape-any-identifier-forward-port | 2026-09-17 | `unicode-operators-experiment` | `9b1a1b6c58d8` — **merge commit**, `git merge --no-ff ccc352392df4`; [escape-any-identifier](../../completion/steps/escape-any-identifier.md)'s two commits, 8 files, **+300/−27**, **no conflict** — predicted by `git diff --numstat` before the merge (one shared file, `DiagnosticParseKinds.td`, 570 lines apart). Delta exactly the incoming pair's; feature diff unchanged at 121 files / +7701−57 / 221 hunks at `-U0`. `unicode-operators-upstream` **untouched**, `8c2a90f56b00`. | **`check-clang` GREEN, `EXIT=0`** — **54192 / 48304 / 0**, XFAIL 27, unsupported 5855, skipped 6: Baselines plus the two new test files. Zero warnings. Probes 98/98 / 98/98, errors `EXIT=0`, parity clean. | [escape-any-identifier](../../completion/handoffs/escape-any-identifier.handoff.md) |
