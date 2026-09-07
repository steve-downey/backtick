# BL02 — `B01`: implement D16, a type-name in the operator slot

**Goal.** `` x `T` y `` means `T(x, y)` — functional-style construction, CTAD
applying — so that §17.3, D16 and the paper stop claiming a feature the
implementation does not deliver.

**Depends on:** BL01 (so the gate is readable).
**Closes:** `B01`.
**Design refs:** `docs/backtick-operator-design.md` D16 (`:60`) and §17.3
(`:1004-1019`); `papers/backtick-infix-and-keyword-escape.md:541-553` (the prose), `:911-914` (the
grammar) and `:940` (the `r7` example). Read
`ops/handoffs/15-defect-fixes.handoff.md:252-259`, which is where this defect
was found, and `:53-59`, which describes `getCallExpr()`.

## The defect, measured

On `~/src/llvm/build-backtick-trunk/bin/clang -cc1 -std=c++23 -fbacktick
-fsyntax-only`, **three** distinct failures, not one:

| Slot | Diagnostic |
|---|---|
| bare class `` 1 `P` 2 `` | `'P' does not refer to a value` |
| class template `` 1 `pr` 2 `` — *the paper's own example* | `use of class template 'pr' requires template arguments` |
| qualified `` 1 `N::P` 2 `` | `expected '(' for function-style cast or type construction` |
| builtin `` 1 `int` 2 `` | same |

Two causes:

1. The slot is parsed by `ParseExpression()` inside the
   `BacktickIsOperatorScope` at `clang/lib/Parse/ParseExpr.cpp:466-492`.
   `ParseCastExpression`'s identifier arm only attempts the type annotation
   when the **next** token is one of `::`, `<`, `(`, `{`, `:`
   (`ParseExpr.cpp:1003-1005`). A closing backtick is not in that set, so `P`
   reaches `ActOnIdExpression`, lookup finds a `TypeDecl`, and Sema emits
   `err_ref_non_value` (`DiagnosticSemaKinds.td:8295`).
2. `N::P` and `int` **do** become type specifiers, and then die at
   `ParseExpr.cpp:1459-1461`, because `ParseCXXTypeConstructExpression`
   (`ParseExprCXX.cpp:1784`) requires the argument list to follow the type
   immediately.

## Do

Work on `backtick-trunk` first; cherry-pick to `backtick-23` and re-gate
independently.

1. **Parser, slot entry.** When inside the slot — `BacktickIsOperator ==
   false` and `LangOpts.Backtick` — add `tok::backtick` to the
   annotate-trigger set at `ParseExpr.cpp:1003-1005`, so a bare type-name
   becomes `annot_typename` instead of an id-expression. Keep the condition
   tight: this must not change annotation behaviour anywhere else.
2. **Parser, type-without-parens.** Add an arm so that a
   *simple-type-specifier* or *typename-specifier* immediately followed by
   the closing backtick yields a "the slot is a type" result rather than
   `err_expected_lparen_after_type`.
3. **Parser plumbing.** `BacktickOp` (`ParseExpr.cpp:401`) is an
   `ExprResult`. It needs a discriminated alternative carrying a
   `ParsedType`/`TypeResult`, threaded to the `ActOnBacktickOperator` call at
   `:587`.
4. **Class templates — do not let this fall out of scope.** `std::pair` is a
   *template*-name, not a type-name, and it is the paper's headline example.
   It needs the deduced-class-template placeholder path, i.e. a **second**
   annotate case.
5. **Sema.** Add an `ActOnBacktickOperator` overload taking a `ParsedType`
   and routing to the existing
   `Sema::ActOnCXXTypeConstructExpr(TypeRep, LParenLoc, Exprs, RParenLoc,
   /*ListInitialization=*/false)` (`Sema.h:8598-8602`, called from
   `ParseExprCXX.cpp:1799` and `:1840`) with the two operands as the argument
   list. That is the entry `T(x, y)` already uses, so CTAD,
   `CXXTemporaryObjectExpr`, and `CXXUnresolvedConstructExpr` for dependent
   types all come free. Wrap the result in `BacktickInfixExpr` as today
   (`SemaExpr.cpp:6763-6771`).

   **No AST-node change is needed.** F23 already made the wrapper tolerate a
   non-`CallExpr` inner — read the comment at
   `clang/include/clang/AST/Expr.h:2242-2250`.
6. **Printer — mandatory, not optional.** `StmtPrinter.cpp:1632`
   reconstructs the surface form from `getCallExpr()`, which is
   `dyn_cast<CallExpr>(getSubExpr()->IgnoreImplicit())`. A
   `CXXTemporaryObjectExpr` is not a `CallExpr`, so `getCallExpr()` returns
   null and the printer falls back to the semantic form: `` 1 `P` 2 `` would
   print `P(1, 2)`. **Implementing D16 without touching the printer therefore
   *adds* a `-ast-print` round-trip hole** — exactly the DEV-06 shape F23
   just closed. Extend the printer to recover and print the type slot.
7. **The grammar contradiction — the part `BACKLOG.md` misses.** The proposed
   wording at `papers/backtick-infix-and-keyword-escape.md:911-914` is
   `backtick-operator: assignment-expression`. `std::pair` is not an
   assignment-expression under any reading, so the `r7` line in the normative
   example at `:940` contradicts `[expr.backtick]`'s own grammar. **Change
   the production** — e.g.
   `assignment-expression | simple-type-specifier | typename-specifier` — and
   check the surrounding prose still reads correctly. Paper work is in scope
   for this step; the point of the step is that the paper becomes true.

## Build

`ninja -C ~/src/llvm/build-backtick-trunk clang`

## Verify (gate)

- New cases in `clang/test/Parser/backtick-infix.cpp`: bare class, qualified
  type, builtin type, class template with CTAD, and a dependent/template
  context. Assert the resulting node and type, not just that it compiles.
- New cases in `clang/test/Parser/backtick-ast-print.cpp` proving the
  **backtick** form round-trips — the second RUN line, which re-parses the
  printed output, is the real assertion. `P(1, 2)` printing is a failure, not
  a pass.
- §17.3's own claim: confirm no most-vexing-parse declaration reading can
  arise. The slot result is an expression by construction; write the test
  that would catch it if that ever stopped being true.
- `check-clang` green on `backtick-trunk`, then cherry-pick and re-run
  independently on `backtick-23`.

## Capture in handoff

The real cost, in the units the other tracks report: files touched,
production lines added, and how many of the six work items above turned out
to be needed. DEV-U04/U05/U12/U13 all measure their steps this way and the
paper quotes those numbers.

Append a row to `ops/DEVIATIONS.md` recording the shape: **D16 was blessed as
a consequence and turned out to need two parser arms, a Sema overload, a
printer change, and a grammar production.** That is a finding the paper's
implementation-experience section wants — "consequences" of a design are not
free.

Add a row to `ops/gcc/DEVIATIONS.md`: GCC does not implement D16 either, and
now there is a Clang side to compare against. Implementing it in GCC is *not*
in this step.

## If it goes badly

D16 and §17.3 were written in `3910c53` on 2026-06-28 — the day *after* S11,
the last Clang backtick implementation step. No plan step S00–S12 or G01–G10
mentions D16; grepping `D16` across `ops/` returns only `BACKLOG.md`, the
F23/F24 handoff, and two rebase handoffs saying no decision was revisited. It
was blessed as a consequence after the implementation closed and has never
been exercised.

The maintainer chose to implement rather than cut, so **implement**. But if
the parser arms turn out materially worse than they look, the fallback is
three deletions rather than a rediscovery: `docs/backtick-operator-design.md`
§17.3 (`:1004-1019`) and the D16 row (`:60`); `papers/backtick-infix-and-keyword-escape.md:541-553`;
and the `r7` line at `:940`. Write a BLOCKED handoff making the case; do not
take the fallback unilaterally.
