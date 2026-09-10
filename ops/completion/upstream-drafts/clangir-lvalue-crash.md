# Draft upstream report — [`clangir-lvalue-crash`](../../BACKLOG.md#clangir-lvalue-crash)

**Status: DRAFTED, NOT FILED.** The author decided this step drafts the three
reports and does not post them. Nothing below has been sent to any issue
tracker.

- **Target:** `llvm/llvm-project`, new issue. Suggested labels: `ClangIR`,
  `crash`.
- **Confirmed against trunk:** `emitLValue` read out of **`72417eb739e5`**
  (2026-09-05, `upstream/main` as fetched 2026-09-06). Crash reproduced on
  `~/src/llvm/build-cir-scratch`, a `CLANG_ENABLE_CIR=ON` build of
  `6ee1358f7b47` (base `bb33de72920a`, 2026-07-28). That branch carries two
  local features; **the reproducers use neither, and neither flag is passed.**
  The path they take was checked byte-for-byte against today's trunk: the whole
  of `CIRGenFunction::emitLValue` is identical to `72417eb739e5` apart from two
  added `case` arms for local `Expr` classes a stock reproducer cannot name,
  and `CIRGenFunction::emitReturnStmt` in `CIRGenStmt.cpp` is identical. So the
  arms and the callers exercised below are today's trunk code.
- **Existing-issue search (2026-09-06), no duplicate found.** Queries against
  `repo:llvm/llvm-project` (`is:issue`, open and closed): `emitLValue CIR` (0),
  `"unsupported l-value class"` (0), `"errorNYI" crash LValue` (1 — #202097,
  see below), `in:title ClangIR crash NYI` (0),
  `CIR "Not Yet Implemented" assertion` (2 — #202097 and #125626),
  `label:ClangIR crash` (17, none at this site), `label:ClangIR errorNYI` (23,
  all feature-gap trackers), `"emitLValue"` (171, all `CodeGenFunction`).
  **Two closed issues are the same failure mode at other CIR sites** and belong
  in the report as prior art: **#202097** (`emitDeclRefLValue` reports NYI, then
  continues with `Address::invalid()` and asserts) and **#214443** (`__builtin_stdc_*`
  NYI, then crashes in `CastOp::fold`). Neither covers `emitLValue`, and the
  pattern surviving two site-by-site fixes is itself the argument for reporting
  the shape rather than one arm.
- **Do not propose the fix.** Whether the arms should diagnose-and-recover
  (with what `LValue`?) or `llvm_unreachable` is upstream's design call, and CIR
  is mid-bring-up. Report the shape and stop.

## What changed from the note on file

`ops/BACKLOG.md` records this as *the default arm* of `emitLValue`. Reading the
switch on current trunk, **the default arm is one instance of the pattern, not
the pattern**: 21 arms in that one function call `errorNYI(...)` and then
`return LValue()`, and the enumerated ones are reachable from stock C++ today.
That is what makes a reproducer possible without any downstream patch, and it
is how both reproducers below work.

---

## Title

`[CIR] emitLValue returns a default-constructed LValue after errorNYI, so every not-yet-implemented l-value class crashes instead of diagnosing`

## Body (paste below this line)

`CIRGenFunction::emitLValue` (`clang/lib/CIR/CodeGen/CIRGenFunction.cpp:1171`,
as of `72417eb739e5`) reports an unimplemented l-value class and then returns a
default-constructed `LValue`:

```cpp
  switch (e->getStmtClass()) {
  default:
    getCIRGenModule().errorNYI(e->getSourceRange(),
                               "emitLValue: unsupported l-value class");
    return LValue();
```

That `LValue` carries a null `QualType` and an invalid `Address`, and the
caller uses it. So the one path that is *meant* to be a clean "not yet
implemented" diagnostic aborts the compiler instead. This is not specific to
the `default:` arm — **21 arms of that single switch have the same
`errorNYI(...); return LValue();` shape**, including `StmtExpr`, `LambdaExpr`,
`ConstantExpr`, `VAArgExpr`, `CXXThisExpr`, `ArraySectionExpr`,
`MatrixSubscriptExpr`, `CoawaitExpr`, `CoyieldExpr` and `PackIndexingExpr` —
so the crash is reachable from ordinary C++ wherever CIR has not implemented an
l-value form yet, and any `Expr` class merely *absent* from the switch reaches
the identical shape through `default:`.

Reachable only in a `CLANG_ENABLE_CIR=ON` build, which is presumably why it has
not been hit.

### Reproducer 1 — assertion (`QualType::getCommonPtr`)

```cpp
// repro-assign.cpp
template <class... T> void assign(T &...p) { p...[0] = 1; }
int g;
void f() { assign(g); }
```

```console
$ clang++ -std=c++2c -fclangir -emit-cir -o /dev/null repro-assign.cpp
repro-assign.cpp:1:46: error: ClangIR code gen Not Yet Implemented: emitLValue: PackIndexingExpr
    1 | template <class... T> void assign(T &...p) { p...[0] = 1; }
      |                                              ^~~~~~~
clang++: clang/include/clang/AST/TypeBase.h:954: const ExtQualsTypeCommonBase *clang::QualType::getCommonPtr() const: Assertion `!isNull() && "Cannot retrieve a NULL type pointer"' failed.
...
#16 clang::CIRGen::CIRGenFunction::emitStoreOfScalar(mlir::Value, clang::CIRGen::LValue, bool)
#17 clang::CIRGen::CIRGenFunction::emitStoreThroughLValue(clang::CIRGen::RValue, clang::CIRGen::LValue, bool)
#18 clang::CIRGen::CIRGenFunction::emitBinaryOperatorLValue(clang::BinaryOperator const*)
#19 clang::CIRGen::CIRGenFunction::emitLValue(clang::Expr const*)
#20 clang::CIRGen::CIRGenFunction::emitIgnoredExpr(clang::Expr const*)
#21 clang::CIRGen::CIRGenFunction::emitStmt(clang::Stmt const*, bool, llvm::ArrayRef<clang::Attr const*>)
```

`emitBinaryOperatorLValue` asks `emitLValue` for the assignment's left operand,
gets the empty `LValue` back, and stores through it.

### Reproducer 2 — segfault, different caller, same arm

```cpp
// repro-return.cpp
template <class... T> int &first(T &...p) { return p...[0]; }
int g;
int f() { return first(g); }
```

```console
$ clang++ -std=c++2c -fclangir -emit-cir -o /dev/null repro-return.cpp
repro-return.cpp:1:52: error: ClangIR code gen Not Yet Implemented: emitLValue: PackIndexingExpr
    1 | template <class... T> int &first(T &...p) { return p...[0]; }
      |                                                    ^~~~~~~
PLEASE submit a bug report ...
 #5 cir::CIRBaseBuilderTy::createStore(...)
 #6 clang::CIRGen::CIRGenFunction::emitReturnStmt(clang::ReturnStmt const&)::$_0::operator()() const
 #7 clang::CIRGen::CIRGenFunction::emitReturnStmt(clang::ReturnStmt const&)
```

Same arm, different caller, different crash — which is the point: the failure
mode is decided by whoever consumes the empty `LValue`, not by the arm.

### Why the arm and not the node

Two entirely unrelated `Expr` classes, sharing no code and no flag, abort
identically at this switch. Besides `PackIndexingExpr` above, we hit it with
two locally-added expression wrapper classes falling through to `default:` and
got the same `QualType::getCommonPtr` assertion. Whatever the node is, the
empty `LValue` is what kills the compiler.

### Prior art

The same "report NYI, then continue with an invalid value" shape has been
reported and fixed twice already at other CIR sites — #202097
(`emitDeclRefLValue` continuing with `Address::invalid()`) and #214443
(crash in `CastOp::fold` after the NYI error). Fixing those did not reach
`emitLValue`, and per-site fixes will not, because there are 21 of them in this
one function plus everything that arrives at `default:`.

### Not proposing a fix

Whether an NYI l-value arm should return something recoverable (and what a
recoverable `LValue` would be), or should stop compilation, or should be
`llvm_unreachable`, is a design call for the CIR bring-up. Reporting the shape.
