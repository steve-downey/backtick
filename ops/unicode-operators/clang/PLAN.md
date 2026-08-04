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
- **`check-clang` self-formats `clang/lib/Format/`** and aborts at ~step
  81/970 — before any lit test runs — if the edits there don't match
  current LLVM style. Relevant to U18.
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
- [ ] **U04** Lexer: UCN and `\N{...}` spellings (U11) — `steps/U04-lexer-ucn.md` (dep: U03)
- [ ] **U05** Exclusion diagnostics with reasons — `steps/U05-exclusion-diagnostics.md` (dep: U03)

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
- [ ] **U18** clang-format — `steps/U18-clang-format.md` (dep: U04)

### Phase E — Upstream replay
- [ ] **U19** Replay-ledger audit — `steps/U19-replay-audit.md` (dep: U14, U15, U17, U18)
- [ ] **U20** Clean-`main` replay branch + gate — `steps/U20-upstream-replay.md` (dep: U19)

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
