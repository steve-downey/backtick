# BL04 — `B15`: build ClangIR and close the unknown

**Goal.** Establish, by compiling it, whether the ClangIR code generator
needs to know about `UserOperatorExpr` — and if it does, tell it.

**Depends on:** BL01.
**Closes:** `B15`, and its backtick twin `B36`.
**Refs:** `ops/unicode-operators/clang/handoffs/U16-ast-print.handoff.md:390-394`
(the site list, and "note it rather than discover it");
`U17-serialization.handoff.md:375-380`; `U19-replay-audit.handoff.md:131-133`
— which sharpens it from "unbuilt" to "**a genuine hole in
`UserOperatorExpr`'s obligations**".

## What is already known

`clang/lib/CIR/` has never been compiled on any branch here: all four build
dirs are `LLVM_ENABLE_PROJECTS=clang;clang-tools-extra`, with no
`CLANG_ENABLE_CIR` entry and no MLIR. Six consecutive steps flagged it
unchanged.

**The four sites exist and three are one-liners.** `UserOperatorExpr` has
`getSemanticForm()`, so they are literal copy-paste from the
`CXXRewrittenBinaryOperator` arms already there:

| Site | Existing line |
|---|---|
| `CIRGenExprScalar.cpp:585-587` | `return Visit(e->getSemanticForm());` |
| `CIRGenExprAggregate.cpp:440-442` | `Visit(e->getSemanticForm());` |
| `CIRGenExprComplex.cpp:275-277` | `return Visit(e->getSemanticForm());` |
| `CIRGenFunction.cpp:1187-1190` | `errorNYI(…, "emitLValue: CXXRewrittenBinaryOperator")` |

**The blast radius is bounded**, which `BACKLOG.md` does not say: the
fallbacks are `errorNYI` (`CIRGenExprScalar.cpp:138-142`,
`CIRGenFunction.cpp:1156-1159`), not crashes and not silent wrong code. The
realistic outcome of a CIR build meeting a `UserOperatorExpr` is a hard NYI
diagnostic naming the node. That lowers the risk but not the obligation —
the step exists to *establish* it, because "unknown" was the defect.

## Do

1. **Configure a scratch build dir.** Do **not** reconfigure
   `build-unicode`; its numbers are U20's baseline and every U-row's
   arithmetic. `clang/CMakeLists.txt:193-201` `FATAL_ERROR`s without MLIR, so
   both settings are required:

   ```bash
   cmake -G Ninja -S ~/src/llvm/unicode/llvm -B ~/src/llvm/build-cir-scratch \
     -DLLVM_ENABLE_PROJECTS='clang;clang-tools-extra;mlir' \
     -DCLANG_ENABLE_CIR=ON \
     -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=ON \
     -DLLVM_TARGETS_TO_BUILD=host
   ```

   This pulls MLIR in. **The build is the cost of this step, not the patch** —
   budget for it and background it with an `EXIT=` marker per the plan's
   waiting recipe.

   If BL07 has already made an lldb scratch dir, or is about to, add `lldb`
   to this configure and do both in one build.

2. **Probe the four shapes** with `-fclangir -emit-cir`, matching the four
   site kinds: scalar result, aggregate (class-typed) result, complex-typed
   result, and an l-value-returning operator. Expected pre-fix output:

   ```
   error: ClangIR code gen Not Yet Implemented: scalar expression kind: UserOperatorExpr
   ```

3. **If confirmed, add the four hunks** mirroring the
   `CXXRewrittenBinaryOperator` lines, plus a `clang/test/CIR/CodeGen/` test.
   Add the prefix form as well as infix.

4. **Do the same for `BacktickInfixExpr`** using `getSubExpr()`. The gap is
   symmetric and the scratch build is already standing;
   `~/src/llvm/backtick-trunk` is a second worktree to point a configure at.
   This closes `B36`.

5. **If it genuinely needs nothing** — say so in the handoff, with the probe
   output as evidence, and close `B15`. A measured "no case needed" closes
   the row; "unknown" was the defect.

## Verify (gate)

- The CIR build completes.
- The four probes emit CIR rather than `Not Yet Implemented: … UserOperatorExpr`.
- The scratch build's own `check-clang` is green — note that enabling CIR
  **un-`Unsupported`s** the whole `clang/test/CIR/` suite
  (`clang/test/CIR/lit.local.cfg` gates on `config.root.clang_enable_cir`), so
  its discovered count jumps by the size of that suite.
- The four production build dirs are untouched. Confirm and say so.

## REPLAY ledger

`upstream replay` if hunks land for `UserOperatorExpr`; the
`BacktickInfixExpr` half is a `backtick dependency` and belongs to the
backtick track.

## Capture in handoff

**The test-count delta from enabling CIR**, explicitly, and the fact that it
happened in a scratch dir. Otherwise the next agent's subtraction against the
`ops/backlog/PLAN.md` baselines looks like a regression.

Also record whether the CIR arms were needed at all. Either answer is a
result; U19 called this "a genuine hole in `UserOperatorExpr`'s obligations",
and the paper's site-count claims (DEV-U13's 28 dispatch sites over
`StmtClass`) should be corrected if CIR adds four more.
