# BL06 — backtick batch: `B03`, `B04`, `B06`, `B08`, `B35`

**Goal.** Five small backtick-track defects closed in one build and one gate.

**Depends on:** BL01.
**Closes:** `B03`, `B04`, `B06`, `B08`, `B35`.
**Refs:** DEV-U07 (`ops/unicode-operators/clang/DEVIATIONS.md:20`);
`ops/unicode-operators/clang/handoffs/U04-lexer-ucn.handoff.md:33`, `:173-198`,
`:309-311`; `ops/handoffs/15-defect-fixes.handoff.md:53-59`, `:260-266`,
`:280-282`; `ops/handoffs/11-ast-wrapper.handoff.md:127`; DEV-04, DEV-05.

**Batch them.** `B03` and `B04` both touch widely-included files —
`Options.td` alone is ~709 ninja edges and ~9 minutes, as U04 measured, and
`Expr.h` is a wide rebuild. One cycle instead of five is the point.

Work on `backtick-trunk`; cherry-pick to `backtick-23` and re-gate
independently. F23/F24 established that both apply clean
(`15-defect-fixes.handoff.md:175`), which is *not* proof of a passing gate.

## Do

### `B03` — `-fbacktick` lacks `ShouldParseIf<cplusplus.KeyPath>`

Append the guard to `defm backtick`, matching what the Unicode branch already
carries at `~/src/llvm/unicode/clang/include/clang/Options/Options.td:4072-4076`,
including its DEV-U07 comment block at `:4069-4071`:

```
  NegFlag<SetFalse>, BothFlags<[], [ClangOption, CC1Option]>>,
  ShouldParseIf<cplusplus.KeyPath>;
```

- `backtick-trunk`: `clang/include/clang/Options/Options.td:4066-4069`
- `backtick-23`: `clang/include/clang/Options/Options.td:4017-4020`

Note the path: `clang/include/clang/**Options**/Options.td`, not `Driver/`
(DEV-01, `ops/handoffs/00-baseline.handoff.md:33`).

Bring over `clang/test/Lexer/backtick-c-mode.c`, which **already exists on
the Unicode branch** — it was written there as a backtick-track file and
flagged in `REPLAY.md`'s U04 row precisely so it could be handed back. It
pins the behaviour as a *diff* of flag-on versus flag-off output rather than
as two expectations.

**This is worse than `BACKLOG.md` says.** DEV-U07 describes the symptom as
suppressing an accurate diagnostic. Measured:

```
$ printf 'int g(int,int);\nint f(int a,int b){ return a `g` b; }\n' \
    | clang-24-backtick -cc1 -fbacktick -fsyntax-only -x c -
exit=0        # C *accepts* the infix grammar
$ ... without -fbacktick:  error: expected ';' after return statement, exit=1
```

So the flag does not merely change C-mode tokenization — it makes a C
compilation accept `` a `g` b ``. (The keyword-escape half is already
rejected in C: the declarator path runs through `ParseUnqualifiedId`.) Say
this in the handoff and correct the `B03` row.

### `B04` — `BacktickInfixExpr`'s source range does not span its operands

`clang/include/clang/AST/Expr.h:2276-2281` forwards `getBeginLoc`/`getEndLoc`
to `Inner`, so the range is the desugared call's — and `BuildCallExpr` takes
a non-member call's range from its synthesized callee, i.e. the slot alone:

```
int x = 1 `add` 2;
  BacktickInfixExpr <col:12, col:15> 'int'   # callee .. closing backtick
    CallExpr <col:12, col:15> 'int'
      IntegerLiteral <col:9>  1              # left operand precedes the node's begin
      IntegerLiteral <col:17> 2              # right operand follows its end
```

Compute begin from `getCallExpr()->getArg(0)->getBeginLoc()` and end from the
last argument, **with a fallback to `Inner` when `getCallExpr()` is null** —
it is `dyn_cast<CallExpr>(getSubExpr()->IgnoreImplicit())`
(`Expr.h:2271-2274`, defined out of line at `clang/lib/AST/Expr.cpp:1609-1617`)
and returns null when a builtin with custom type checking rewrote the call
(`` a `__builtin_shufflevector` b `` → `ShuffleVectorExpr`). Add
`getSourceRange()` alongside.

~12 lines, header-only. No serialization change — the wrapper stores nothing
(DEV-05). **Model: `UserOperatorExpr::getBeginLoc` at
`~/src/llvm/unicode/clang/include/clang/AST/ExprCXX.h:471-491`**, whose doc
comment already diagnoses this exact root cause for the same reason.

**Tighten the assertion first, or the fix proves nothing.**
`clang/test/Parser/backtick-infix.cpp:20` reads
`// AST-NEXT: BacktickInfixExpr {{.*}} 'int'` — the wildcard swallows the
range, so the fix cannot fail it. Pin the literal `<col:9, col:17>`, and add
a `` `__builtin_shufflevector` `` case asserting the null-`getCallExpr()`
fallback does not crash.

Expect churn: the range change may move locations in other expected output.

### `B06` — delete the dead diagnostic

Remove `err_backtick_nested_requires_parens`,
`clang/include/clang/Basic/DiagnosticParseKinds.td:214-217`. Grep over all of
`clang/` finds exactly one hit: the definition. Carried unfired since S04,
nine times.

Deletion is **ledger-consistent, not merely convenient**: DEV-04 is
**RESOLVED** in the other direction — §17.1, bare nesting is token-identical
to blessed D1 chaining, so it cannot and should not be diagnosed, and "the
original 'parse error' wording was impossible". The diagnostic is unfireable
*as specified*, not merely unfired. Do not implement the D3 lookahead it was
written for.

### `B08` — `-ast-print` in a template context

Add a template case to `clang/test/Parser/backtick-ast-print.cpp` exercising
`TreeTransform<Derived>::TransformBacktickInfixExpr`
(`clang/lib/Sema/TreeTransform.h:13609-13616`) for round-trip. Nothing does
today: the two backtick tests that use templates run only `-fsyntax-only
-verify` / `-emit-llvm`. The case is written down at
`ops/handoffs/11-ast-wrapper.handoff.md:127`.

Two traps the Unicode track already paid for:

- `-ast-print` cannot round-trip an `auto`-returning function template
  (**B28**). Write `template<class F> int apply(F f, int a, int b) { return a `f` b; }`,
  with an explicit `int`.
- It renders `requires(T a, T b)` with a space.

**Also fix the false comment at `backtick-ast-print.cpp:44-47`**, which
claims the escape's `-ast-print` behaviour is covered by
`clang/test/Parser/backtick-escape.cpp`. That file's RUN lines are
`-ast-dump` and `-fsyntax-only` only. That sentence is exactly what let `B02`
hide for nine steps. Replace it with an accurate note pointing at `B02`.

### `B35` — libclang's `CXCursor.cpp`

`clang/tools/libclang/CXCursor.cpp`'s exhaustive `MakeCXCursor` switch has no
`BacktickInfixExprClass` arm, so a `-Wswitch` warning is still live on a
`LLVM_ENABLE_WERROR=OFF` build and libclang maps a backtick expression to
`CXCursor_NotImplemented`. F24 closed the sibling gap in `ExprEngine.cpp` but
not this one; U17 explicitly left the backtick half alone
(`U17-serialization.handoff.md:196-200`, `:472-476`).

One line next to `CXXRewrittenBinaryOperatorClass`.

## Build

`ninja -C ~/src/llvm/build-backtick-trunk clang`

## Verify (gate)

- `clang/test/Lexer/backtick-c-mode.c` passes — its diff RUN line is the
  assertion — and `clang/test/Driver/fbacktick.c` still passes unchanged (the
  driver still accepts and forwards the flag in C; U04 confirmed this at
  `:189-191`).
- `backtick-infix.cpp` pins the literal `<col:9, col:17>`, and the
  `` `__builtin_shufflevector` `` case does not crash.
- Grep finds no `err_backtick_nested_requires_parens` anywhere in `clang/`.
- `backtick-ast-print.cpp`'s **second** RUN line — re-parsing the printed
  output — passes for the template case.
- No `-Wswitch` on `CXCursor.cpp` in the build log.
- `check-clang` green on `backtick-trunk`, then independently on
  `backtick-23`.

## Not in this batch — `B24`

**`B24` is not cheap**, against `BACKLOG.md` §7's grouping. The inner
`CallExpr`'s begin loc comes from its callee (`Expr.h:3321-3338`), and trunk
now *caches* it in a trailing `SourceLocation`
(`CallExprBits.HasTrailingSourceLoc`, written by `updateTrailingSourceLoc()`
at `Expr.h:3348-3360`, called from `CallExpr::Create`, `Expr.cpp:1537`) with
no public setter. Fixing it means an upstream-shaped `CallExpr::Create`
overload or setter.

Re-triage it rather than batching it: either promote it to its own step, or
close it WONTFIX with the note that the node *as written* spans correctly and
a desugaring's semantic form carrying the callee's range is what `-ast-dump`
does for every other desugaring. Do not attempt it here.

`B02` and `B05` are also out of scope — each is its own sitting. `B02`
additionally needs a *decision*: `DeclarationName::print`
(`clang/lib/AST/DeclarationName.cpp:131-148`) is the diagnostic path as well
as the printing path, so re-escaping keyword names naively changes diagnostic
text everywhere.

## Capture in handoff

The measured C-mode behaviour for `B03` (it is a stronger claim than the
ledger records), the churn `B04` caused in other expected output, and
confirmation that `B24` was consciously excluded with the reason above — so
the next reader of §7 does not re-batch it.
