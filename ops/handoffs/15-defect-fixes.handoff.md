# Handoff — F23/F24 two defect fixes on both Clang branches

- **Status:** DONE (both gates passed)
- **Branch / commit:**
  - `backtick-trunk` @ `439ceb5237dc` (defect 1), `169e45c7916f` (defect 2)
  - `backtick-23` @ `4aa89d354389` (defect 1), `c280d8101f56` (defect 2)
- **Date / agent:** 2026-08-04
- **Not a plan step.** S00–S12 and G01–G10 were already fully checked off.
  Like the R-prefixed maintenance rebases, this is recorded so the change is
  not lost; it does not follow `ops/AGENT_PROTOCOL.md`'s step loop.

Two pre-existing defects, both in the phase-2 AST wrapper's fallout, both
fixed on both branches. New ledger rows **DEV-06** and **DEV-07**.

## Defect 1 — `-ast-print` crashed: `Inner` is not always a `CallExpr`

### Root cause

`BacktickInfixExpr::Inner` was declared `Stmt *Inner; // Always a CallExpr`
and `StmtPrinter::VisitBacktickInfixExpr` `cast<CallExpr>`'d it. The comment
was a wish. `Sema::ActOnBacktickOperator` wraps **whatever `BuildCallExpr`
returned**, and that is not always the call:

| Shape | What `Inner` actually is |
|---|---|
| class-typed prvalue result with a non-trivial destructor | `CXXBindTemporaryExpr` → `CallExpr` (`MaybeBindToTemporary`) |
| ObjC retainable result under ARC | consuming `ImplicitCastExpr` → `CallExpr` (same function) |
| builtin with custom type checking | **no call at all** — `` a `__builtin_shufflevector` b `` is a `ShuffleVectorExpr`; `__builtin_convertvector` / `__builtin_astype` are the same shape |

Reproduced on the untouched binaries of **both** branches before any edit:

```cpp
struct S { ~S(); };
S f(int, int);
void h() { (void)(1 `f` 2); }
```
```
clang -cc1 -std=c++23 -fbacktick -ast-print repro.cpp
→ Casting.h:572: Assertion `isa<To>(Val) && "cast<Ty>() argument of
  incompatible type!"' failed.   [To = clang::CallExpr, From = clang::Expr]
```

Same assertion also fires from `debug.DumpCFG`, which pretty-prints CFG
elements — so the crash was not confined to `-ast-print`.

### Fix — the accessor was wrong, not the invariant

The node's job is to carry the **semantic form**, whatever Sema made of it.
So:

- `clang/include/clang/AST/Expr.h` — the `// Always a CallExpr` comment is
  replaced by a doc comment naming all three shapes and pointing at the new
  accessor; added `CallExpr *getCallExpr()` (+ const overload).
- `clang/lib/AST/Expr.cpp` — `BacktickInfixExpr::getCallExpr()` is
  `dyn_cast<CallExpr>(getSubExpr()->IgnoreImplicit())`. Defined out of line
  because `CallExpr` is not complete at the class's point in `Expr.h`.
  `IgnoreImplicit()` strips exactly the nodes Sema interposes and stops at
  the call; this is `UserOperatorExpr::getOperand`'s technique on the Unicode
  branch, which hit the same problem from the other direction.
- `clang/lib/AST/StmtPrinter.cpp` — uses `getCallExpr()` and, when it is null
  (or the call somehow has fewer than two arguments), prints the semantic
  form instead. That is still valid source with the same meaning, just
  desugared: `` (void)(a `__builtin_shufflevector` b) `` prints as
  `(void)(__builtin_shufflevector(a, b))` and re-parses.

**`StmtPrinter` was the only `cast<CallExpr>` of `Inner`** — every other one
of the 22 S11 sites goes through `getSubExpr()` generically and was already
correct. Verified by grepping all 40-odd `BacktickInfixExpr` references
outside `clang/test`.

### Test

`clang/test/Parser/backtick-ast-print.cpp` gains four cases and keeps its
two RUN lines (print + FileCheck, then re-parse the printed output):
class-typed result discarded, the same result lifetime-extended through a
`MaterializeTemporaryExpr`, and a member function in the slot
(`CXXMemberCallExpr`, whose class-typed result binds the same way).

**The keyword-escape form is not applicable and the test says so.** An
escaped name cannot occupy the operator slot — `` 1 ``new`` 2 `` and
`` 1 `` `new` `` 2 `` are both diagnosed *expected expression between
backticks* — so the escape can never produce a `BacktickInfixExpr`.

## Defect 2 — the static analyzer did not know the node

### Root cause, and it is worse than the warning

The reported symptom was one `-Wswitch` line
(`ExprEngine.cpp: enumeration value 'BacktickInfixExprClass' not handled`),
harmless because `LLVM_ENABLE_WERROR` is OFF. The behaviour behind it is not
harmless: with no case the switch falls out without adding a successor
node, so **every path reaching a backtick expression was dropped and the
whole enclosing function went unanalyzed**. Measured on the pre-fix binary:

```cpp
int *identity(int *p, int) { return p; }
void t() { int *p = 0; int *q = p `identity` 0; *q = 1; }   // no report
void u() { int *p = 0; int *q = identity(p, 0); *q = 1; }   // reported
```

and a `clang_analyzer_eval` immediately *after* a backtick expression in the
same function produced no diagnostic at all.

### Fix — five sites, each following an existing transparent-wrapper precedent

The node is genuinely transparent, so the target is: the analyzer sees for
`` x `f` y `` exactly what it sees for `f(x, y)`.

| File | Site | Precedent followed | What was broken |
|---|---|---|---|
| `clang/lib/Analysis/CFG.cpp` | `CFGBuilder::Visit` | `VisitConstantExpr` | wrapper was a CFG element of its own |
| `clang/lib/Analysis/CFG.cpp` | `findConstructionContexts` | `ParenExprClass` arm | context chain broke at the wrapper: a lifetime-extended temporary was modelled as an ordinary one (`(CXXRecordTypedCall, [B1.6])` instead of `[B1.8]`) |
| `clang/lib/Analysis/CFG.cpp` | `VisitForTemporaries` | `ParenExprClass` / `ConstantExprClass` `goto tryAgain` | the `default:` arm drops `ExternallyDestructed` to false, so the CFG emitted a temporary-object destructor **and** the implicit end-of-scope one — a double destroy |
| `clang/lib/Analysis/LiveVariables.cpp` | `LookThroughExpr` | `FullExpr`, `OpaqueValueExpr` | liveness keyed on the wrapper while the binding keyed on the call, so the value was reaped as dead the instant it was bound and **every backtick result read back as unknown** |
| `clang/lib/StaticAnalyzer/Core/Environment.cpp` | `ignoreTransparentExprs` | `ConstantExpr`, `ExprWithCleanups` | a read of the wrapper did not resolve to the call's binding |
| `clang/lib/StaticAnalyzer/Core/ExprEngine.cpp` | `Visit` | `ConstantExprClass` / `ExprWithCleanupsClass` (`Dst.insert(Pred)`, *"handled due to fully linearised CFG"*) | the `-Wswitch` gap; path dropped |

`LiveVariables` was **not** on the original list and is the one that would
have been missed: with the other four in place the analyzer ran but every
backtick result was `UNKNOWN`, which looks like conservative modelling
rather than a bug. It was found by comparing `clang_analyzer_eval` output
against the plain call, not by any diagnostic.

### Why not the `CXXRewrittenBinaryOperator` grouping the Unicode track used

U16 grouped `UserOperatorExprClass` with `CXXRewrittenBinaryOperatorClass`,
which runs pre/post-stmt checkers and binds nothing, and its handoff records
that upstream's own wrapper has the value-loss hole. That is the right
answer *there* — `UserOperatorExpr` is opaque to transformation and stores
its own operands. `BacktickInfixExpr` stores nothing and means exactly its
subexpression, so `ConstantExpr` / `ExprWithCleanups` is the closer
precedent and it is the one that is *complete*: those two are also in
`ignoreTransparentExprs`, so no value is lost.

### Test

`clang/test/Analysis/backtick-infix.cpp`, two RUN lines:

1. `-analyzer-checker=core,debug.ExprInspection -verify` — value-flow parity
   with the plain call, a null dereference still reported *through* a
   backtick call (the load-bearing assertion: before the fix there was no
   report), and a class-typed result read back correctly through a
   lifetime-extended reference.
2. `-analyzer-checker=debug.DumpCFG -analyzer-config cfg-temporary-dtors=true`
   piped to FileCheck — pins the element list: the construction context
   reaches the materialization, the element after `(BindTemporary)` is the
   implicit cast (i.e. the wrapper is *not* an element), `CHECK-NOT:
   (Temporary object destructor)`, and exactly one `~Res() (Implicit
   destructor)`.

Evidence the CFG is now identical to the desugared one: `diff` of
`debug.DumpCFG` output for `const S &r = 1 `f` 2;` against
`const S &r = f(1, 2);` differs in **two lines**, both of which are the
printed source spelling of an expression. Before the fix it differed in
element count, construction-context target, and destructor count.

## Verification evidence

### `backtick-trunk`

```
ninja -C ~/src/llvm/build-backtick-trunk clang        → EXIT=0, 0 warnings
  (the same build before defect 2's fix: exactly 1 warning,
   ExprEngine.cpp:1688 -Wswitch BacktickInfixExprClass)
ninja -C ~/src/llvm/build-backtick-trunk check-clang  → EXIT=1
  Total 54107 / Passed 48212 / XFAIL 27 / Unsupported 5852 / Skipped 6
  Failed 10
GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test
  Total 54099 / Passed 48212 / Failed 2
```

### `backtick-23`

```
git cherry-pick 439ceb5237dc 169e45c7916f  → both applied clean, no conflicts
ninja -C ~/src/llvm/build-backtick clang              → EXIT=0, 0 warnings
llvm-lit Analysis/backtick-infix.cpp Parser/backtick-ast-print.cpp
                                                      → 2/2 PASS, unadjusted
ninja -C ~/src/llvm/build-backtick check-clang        → EXIT=1
  Total 54341 / Passed 48490 / XFAIL 27 / Unsupported 5807 / Skipped 6
  Failed 11
GTEST_FILTER='-DirectoryWatcherTest.*' llvm-lit -s tools/clang/test
  Total 54333 / Passed 48490 / Failed 3
```

### Accounting for every failure

| Failure | Branch | Verdict |
|---|---|---|
| `DirectoryWatcherTest.*` (8) | both | known machine artifact. 65382 of 65536 inotify watches held machine-wide at gate time; gone under `GTEST_FILTER` |
| `Format/dump-config-objc-stdin.m` | `backtick-23` only | the documented env-only known-fail: stray 2018 `Language: Cpp` at `/home/sdowney/src/.clang-format`. Left alone |
| `Analysis/scan-build/cxx-name.test` | both | **new since R23/R24, and not ours** |
| `Driver/hip-gz-options.hip` | both | same |

The last two are worth spelling out because CLAUDE.md says trunk's green is
*zero* failures. Both tests assert on the **basename of the driver binary**.
`CLANG_EXECUTABLE_VERSION` was set to `24-backtick` / `23-backtick` in both
build dirs on **2026-08-02**, after R24's gate, so `clang-24-backtick` no
longer matches `clang(-[0-9]+)?(\.exe)?` and `CLANG_CXX` becomes
`clang-24-backtick++` instead of `clang++`. Proof, run on both branches: the
*stale pre-edit* binaries (`bin/clang-24` from Jul 29, `bin/clang-23` from
Jul 28 — both built before any of this work) pass both tests; the
identically-sourced but differently-named `clang-24-backtick` /
`clang-23-backtick` fail both. Neither test compiles a backtick construct.

### Test-count arithmetic

| | trunk before (R24) | trunk after | 23 before (R23) | 23 after |
|---|---|---|---|---|
| Total | 54106 | 54107 | 54340 | 54341 |
| Passed | 48220 | 48212 | 48498 | 48490 |
| Failed | 0 | 10 | 1 | 11 |
| Unsupported | 5853 | 5852 | 5808 | 5807 |

Total is **+1 on both**: the one new lit test. Passed is −8 on both:
+1 (new test) −8 (`DirectoryWatcherTest`) −2 (the renamed-binary pair) +1
(one test moved unsupported→passed). That last ±1 shows on *both* branches
identically and tracks the `Unsupported` −1, so it is environment drift
since July, not source.

## Deviations from the plan / design

Two new rows in `ops/DEVIATIONS.md`:

- **DEV-06** — §6.4 / §11 phase 2 say the wrapper wraps "the desugared
  `CallExpr`". It wraps a *semantic form*. Reword; and note that
  `-ast-print` round-trip is best-effort, not unconditional — a builtin
  rewrite has no callee left to spell.
- **DEV-07** — §11 phase 2 calls the wrapper "purely additive". It is not:
  five Analysis/StaticAnalyzer sites, **none of which the toolchain forces**
  (one warns, four are silent), and getting them wrong silently disables the
  static analyzer for any function containing the construct rather than
  failing a build. This is the backtick counterpart of the Unicode track's
  "6 link / 8 unreachable / 1 warning / 13 silence" accounting (DEV-U13) and
  belongs in the same implementation-experience paragraph.

## Discoveries affecting later work

- **`getCallExpr()` is the accessor to use from now on.** Anything that
  wants the call — a future diagnostic, clang-tidy matcher, or the paper's
  worked examples — must handle its null return.
- **The keyword-escape form has its own `-ast-print` fidelity gap**, found
  in passing and *not* fixed here because it is a different node and a
  different defect: `` void `new`(); `` prints as `void new();` and
  `` `new`(1, 2) `` prints as `new(1, 2)`, neither of which re-parses. The
  escape yields an ordinary identifier (D10) and the printer has no way to
  know the name needed escaping. Fixing it means teaching
  `DeclarationName`/identifier printing to re-add backticks around a name
  that is a keyword when `LangOpts.Backtick` is on. Nobody owns this.
  `clang/test/Parser/backtick-escape.cpp` does not currently exercise
  `-ast-print`, which is why it was never caught.
- **§17.3's type-name-in-the-slot claim (D16) is not implemented in Clang.**
  `` 1 `P` 2 `` for a class `P` is rejected with *'P' does not refer to a
  value*, because the slot is parsed as an expression and a bare type-name
  is not one there. The design doc blesses this shape as a consequence; the
  implementation does not deliver it. Not touched here — it is a Sema/parse
  question, not a printer or analyzer one — but it is a claim the paper
  currently makes without evidence and someone should either implement it,
  scope it to `` `std::pair` ``-style templates, or soften §17.3.
- **The wrapper's source range still does not span its operands.**
  `-ast-dump` shows `BacktickInfixExpr <col:22, col:23>` — the inner call's
  range, i.e. just the callee between the backticks — while the expression
  as written starts at the left operand. `getBeginLoc`/`getEndLoc` forward
  to `Inner`, and `CallExpr`'s range starts at the callee. The Unicode track
  hit and fixed the same thing by computing the range from the operands
  (U16). Cheap to fix here now that `getCallExpr()` exists; nobody owns it.
- **`clang-format` was untouched**, so the R23 clang-format trap did not
  arise. If a future fix does touch `clang/lib/Format/` or
  `clang/unittests/Format/*.cpp`, format them before trusting the gate.

## Open risks / TODOs

- Nothing is pushed on either branch; both are ahead of every remote.
- The GCC track has **neither** defect fixed and cannot have the first one:
  GCC's phase-2 wrapper was never built (S11's discovery note). The
  analyzer half has no GCC analogue either. No cross-compiler divergence row
  is warranted — there is nothing to diverge from.
- `ASTMatchers` / clang-tidy still do not know `BacktickInfixExpr`, the same
  gap U17 recorded for `UserOperatorExpr`. Unclaimed.
- `err_backtick_nested_requires_parens` remains dead code and the D8
  slot-interior SplitPenalty bump remains unimplemented, both carried
  forward from S10/R23.
