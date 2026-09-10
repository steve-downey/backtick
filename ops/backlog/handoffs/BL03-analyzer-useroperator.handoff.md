# Handoff — BL03 `B14`: fix the static analyzer for `UserOperatorExpr`

- **Status:** DONE (both gates passed)
- **Branch / commit:**
  - `unicode-operators-experiment` @ `be2670c2513f`
  - `unicode-operators-upstream` @ `6428404d98a5`
- **Date / agent:** 2026-08-09
- **Closes:** `B14`. **Opens:** `B37`.
- **Ran immediately after M1** in the same session, as the plan directs.

## What changed

Six arms, four production files, +47/−5; one new test, +122.

| File / site | Change | Precedent |
|---|---|---|
| `Analysis/CFG.cpp` `findConstructionContexts` | propagate the layer to `getSemanticForm()` | `ParenExprClass` |
| `Analysis/CFG.cpp` `CFGBuilder::Visit` | `return Visit(...->getSemanticForm(), asc, ExternallyDestructed)` | `VisitConstantExpr` |
| `Analysis/CFG.cpp` `VisitForTemporaries` | `E = ...->getSemanticForm(); goto tryAgain;` | `ParenExpr` / `ConstantExpr` |
| `Analysis/LiveVariables.cpp` `LookThroughExpr` | `dyn_cast` arm to `getSemanticForm()` | `FullExpr`, `OpaqueValueExpr` |
| `StaticAnalyzer/Core/Environment.cpp` `ignoreTransparentExprs` | `case` to `getSemanticForm()` | `ConstantExpr`, `ExprWithCleanups` |
| `StaticAnalyzer/Core/ExprEngine.cpp` `Visit` | **moved** out of the `CXXRewrittenBinaryOperator` group into the `Dst.insert(Pred)` group | `ConstantExpr` / `ExprWithCleanups` |

New `clang/test/Analysis/unicode-operator-analysis.cpp`, two RUN lines.

## Which arms had to differ from F24's, and why — the step's question

**Mechanically, all six.** None of F24's hunks compiles verbatim: there is no
`getSubExpr()` on `UserOperatorExpr`, only `getSemanticForm()`
(`ExprCXX.h:442-443`). That is a rename, though, not an argument.

**Substantively, one: `ExprEngine`.** Five arms are F24's reasoning applied
unchanged, because the premise F24 relies on holds here too. The step warned
that it might not — `UserOperatorExpr` is deliberately **not** transparent to
transformation (`TransformUserOperatorExpr`, `TreeTransform.h:14234-14259`,
recovers the operands as written and re-runs `Sema::CreateOverloadedUserOp`;
DEV-U13). The audit's answer:

> **The analyzer's sense of "transparent" and `TreeTransform`'s are different
> properties, and only the first one is at issue.** `TreeTransform` runs on an
> uninstantiated AST and cares what was *written*. The CFG is built from an
> already-instantiated AST and cares what the expression *is worth*. Value-wise
> the node **is** its semantic form: the constructor copies type, value kind
> and object kind from it (`ExprCXX.h:427-428`), and that form is its only
> child, so no operand is reachable twice. Every one of the six sites asks a
> value question. So the node is fully transparent *to the analyzer*, and the
> `ConstantExpr` / `ParenExpr` precedents F24 chose are the right ones here as
> well.

That is the paper-relevant finding: **a wrapper node's obligation to the
analyzer is generic, and does not depend on whether the node is transparent to
transformation.** The two backtick and Unicode wrappers differ sharply in the
latter and not at all in the former.

The `ExprEngine` arm is the exception, and it is the coupling the step
predicted. U16 grouped `UserOperatorExprClass` with
`CXXRewrittenBinaryOperatorClass`, which runs pre/post-stmt checkers and binds
nothing. That was self-consistent **only** while `CFG.cpp` had no case and the
wrapper genuinely was a modelled CFG element. Fixing `CFG.cpp` falsifies the
premise, so the arm moved in the same commit — exactly as the step said it must.

## The six-arm audit — every arm reverted individually

The gate requires that each assertion fail when its arm is reverted. Rather
than spot-check, each of the six was reverted in turn, `clang` rebuilt, and
the test re-run. **Five fail, each with its own signature:**

| Arm reverted | lit | `TRUE` (7) | null-deref (3) | CFG symptom |
|---|---|---|---|---|
| `findConstructionContexts` | FAIL | 7 | 3 | `(CXXRecordTypedCall, **[B1.6]**)` — context stops at the `CXXBindTemporaryExpr` |
| `CFGBuilder::Visit` | FAIL | 7 | 3 | `(CXXRecordTypedCall, **[B1.9]**)` — numbering shifts; the wrapper is an element again |
| `VisitForTemporaries` | FAIL | 7 | 3 | extra `10: ~Res() (Temporary object destructor)` — **double destroy** |
| `LookThroughExpr` | FAIL | **4** | **1** | (CFG fine) — value reaped as dead on binding |
| `ignoreTransparentExprs` | FAIL | **3** | **1** | (CFG fine) — read does not resolve to the call's binding |
| `ExprEngine::Visit` | **PASS** | 7 | 3 | none |

`LiveVariables` is again the one that would have been missed by reading the
site list — it produces no diagnostic, only quieter results — and it is the
arm with the largest single effect. F24 said the same; it reproduces exactly.

### The `ExprEngine` arm is unreachable, and that is a measured claim

Since the test could not distinguish it, an `llvm_unreachable("REACHABILITY
PROBE…")` was compiled into the arm and the whole `clang/test/Analysis` tree
(1196 tests) plus all 33 `unicode-operator*` / `backtick*` tests were run
against it. **It never fired.** Once `CFG.cpp` looks through the node,
`ExprEngine::Visit` is never called on a `UserOperatorExpr` at all; the case
exists to satisfy `-Wswitch`.

It is still changed rather than left alone, because the old grouping *asserts*
something now false. Leaving it would be dead code that documents the wrong
model, and the next person to touch `CFG.cpp` would be misled by it.

The probe was removed and the tree verified byte-identical to its pre-audit
state (`diff` of `git diff` output before and after: no difference) before
committing.

## `B37` — a new defect, found the way F24 found `LiveVariables`

**Both wrapper nodes defeat the analyzer's null-return suppression.**

`suppress-null-return-paths` (default **on**) suppresses a null-dereference
report whose null came from an inlined callee's return. Its handler
(`BugReporterVisitors.cpp:2365`) opens with `if (!CallEvent::isCallStmt(E))
return {};`, and `E` is the tracked expression. For `p ⊘ 0` — or
`` p `identity` 0 `` — that expression is the **wrapper**, not the `CallExpr`,
so the handler bails and the report is emitted. Measured in one TU:

```
default (suppression on):   operator form REPORTS,  explicit call SILENT
suppress-null-return-paths=false:  both report
```

This is a parity break **in the noisy direction** — the operator form emits
false positives the explicit call is deliberately spared. It is *not* a BL03
regression: it is inherited from F24 and live on `backtick-trunk` and
`backtick-23` right now.

**The sharp part:** `clang/test/Analysis/backtick-infix.cpp`'s
`bugs_are_still_found` — which F24's handoff calls "the load-bearing
assertion" — **passes only because of this bug**. Its explicit-call
counterpart would not report. So the test asserts a divergence while claiming
to assert parity.

Recorded as `B37` (P2), unowned. The fix is a seventh site — peel both
wrappers before the `isCallStmt` test — but it changes an F24 test's premise,
so it wants its own step rather than a quiet edit here.

**BL03's test does not rest on it.** Its first RUN line passes
`-analyzer-config suppress-null-return-paths=false` on purpose, with a comment
saying why, so its three null-deref assertions test genuine parity: before the
fix 2 of 4 reported (the two explicit calls only), after the fix 4 of 4.

## Verification evidence

### `unicode-operators-experiment` @ `be2670c2513f`

```
ninja -C ~/src/llvm/build-unicode clang        → EXIT=0, ZERO warning: lines
ninja -C ~/src/llvm/build-unicode check-clang  → EXIT=0
  Total Discovered Tests: 54181
  Passed: 48295   Failed: 0   XFAIL: 27   Unsupported: 5853   Skipped: 6
```

Unfiltered, no `GTEST_FILTER`. Against U18's unfiltered 54179 / 48285 / **8**:
discovered **+2** (M1's test + BL03's), passed **+10** (those 2 + the 8
`DirectoryWatcherTest.*` cases that B31's root fix recovered), failed **8 → 0**.

### `unicode-operators-upstream` @ `6428404d98a5`

```
ninja -C ~/src/llvm/build-unicode-upstream clang        → EXIT=0, ZERO warning: lines
ninja -C ~/src/llvm/build-unicode-upstream check-clang  → EXIT=0
  Total Discovered Tests: 54240
  Passed: 48323   Failed: 0   XFAIL: 27   Unsupported: 5884   Skipped: 6
```

Against U20's unfiltered 54239 / 48314 / **8**: discovered **+1**, passed
**+9**, failed **8 → 0**. No existing test changed behaviour.
`git diff upstream/main..unicode-operators-upstream | grep -i backtick` still
returns nothing.

### Parity, measured before and after

```
                          before   after
infix    1 ⊞ 2            UNKNOWN  TRUE
explicit operator⊞(1,2)   TRUE     TRUE
prefix   ⊟ 5              UNKNOWN  TRUE
explicit operator⊟(5)     TRUE     TRUE
member   m ⊠ 5            (n/a)    TRUE   — explicit m.operator⊠(5) also TRUE
null-deref reports        2 of 4   4 of 4
CFG for a class result    differs in element count, construction-context
                          target and destructor count
                          → identical but for element 7's printed spelling
```

The step file's "FALSE *and* TRUE" symptom reproduces only with the default
`eagerly-assume=true`; with `eagerly-assume=false` the same defect presents as
`UNKNOWN`. Same root cause, different surface — worth knowing before matching
symptom text.

## Deviations from the step file

- **The step lists six sites; the audit found a seventh** (`B37`, above),
  deliberately not fixed here. The step's own instruction — diff against the
  plain call rather than trust the site list — is what surfaced it, for the
  second time in two tracks.
- **Two of the three "observed" defects in the step file presented
  differently.** The value-loss one is `UNKNOWN`, not a `FALSE`/`TRUE` split,
  under the test's config. The dropped-successor defect is absent, as the step
  says. No ledger row: the step file predicted the defects correctly, only the
  surface text differs.
- No `DEVIATIONS.md` row. Nothing here contradicts `docs/unicode-operators.md`;
  DEV-U13's account of `UserOperatorExpr`'s non-transparency is confirmed, and
  the handoff's finding is that it does not bear on the analyzer.

## Discoveries affecting later work

- **The analyzer is a value oracle, and it is cheap.** `clang_analyzer_eval`
  diffed against the explicit call found two defects across two tracks that no
  diagnostic reported. Any future wrapper node should be run through it before
  it is called done.
- **`clang/test/Analysis/` now has two files on the experiment branch** and one
  on the upstream branch. `unicode-operator-analysis.cpp` is byte-identical
  between them.
- **`func-mapping-test.cpp` fails after a bare `ninja clang`** — the stale
  `clang-extdef-mapping` cannot read a PCH written by the newer `clang`. It is
  a staleness artifact, not a regression; the full `check-clang` rebuilds the
  tool and it passes. Do not chase it.
- **The `-Wswitch` era is over on these branches.** M1 closed the last two
  backtick gaps. A non-empty `grep 'warning:'` on a Unicode build now means
  your change.

## Forward notes for the next step

The plan's remaining steps are independent of this one; nothing here blocks
them.

- **BL04 (`B15`, ClangIR)** is the natural next P1 and needs a **scratch**
  build dir with MLIR and `CLANG_ENABLE_CIR=ON` — never reconfigure one of the
  four named build dirs. Its four sites are already identified in `B15`, and
  three are copy-paste from the `CXXRewrittenBinaryOperator` arms because
  `getSemanticForm()` exists. **Note the coupling BL03 just demonstrated**:
  CIR's arms are value arms, so the same reasoning applies — the node is worth
  its semantic form — and `B36` is its backtick twin using `getSubExpr()`.
  BL07 also needs a scratch dir; combine the configures if they run near each
  other.
- **BL06** is the backtick batch and touches `backtick-trunk`/`backtick-23`,
  not these branches. **M2 forward-ports it here afterwards** — see the M1
  handoff for why M2's job is now smaller than its description.
- If anyone picks up **`B37`**, its fix lands on *four* branches (both backtick,
  both Unicode) and must revisit `backtick-infix.cpp`'s
  `bugs_are_still_found`, whose premise it changes.

## Open risks / TODOs

- Nothing is pushed on any branch; all four are ahead of every remote.
- `B37` is unowned.
- `UserOperatorExpr` is still absent from ClangIR (`B15`) and from the
  backtick side's ASTMatchers gap's twin (`B05`); neither is BL03's.
- The `ExprEngine` arm is unreachable dead code on both branches by
  construction. If anyone ever makes the CFG *stop* looking through the
  wrapper, that arm becomes live again and is then the correct behaviour —
  which is the reason to keep it rather than delete it.
