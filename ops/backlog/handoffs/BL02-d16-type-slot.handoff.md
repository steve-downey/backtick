# Handoff — BL02 `B01`: implement D16, a type-name in the operator slot

- **Status:** DONE (gate passed)
- **Branch / commit:** `backtick-trunk` `5a2b586463d9`, `backtick-23`
  `554d470ca412` (cherry-pick, clean, re-gated independently). Byte-identical
  feature diff on both: 8 files, 267 insertions, 21 deletions.
- **Date / agent:** 2026-08-08
- **Closes:** `B01`.

## What changed

| File | Change |
|---|---|
| `clang/include/clang/Parse/Parser.h` | declared `TypeResult TryParseBacktickTypeSlot()` (private, next to `isFoldOperator`) |
| `clang/lib/Parse/ParseExpr.cpp` | the new ~70-line `Parser::TryParseBacktickTypeSlot()` (placed just before `ParseRHSOfBinaryExpression`); slot parse in `ParseRHSOfBinaryExpression` now tries it before `ParseExpression()`; a `ParsedType BacktickOpType` beside the existing `ExprResult BacktickOp`; the combine site picks the `ParsedType` overload when the type is set |
| `clang/include/clang/Sema/Sema.h` | second `ActOnBacktickOperator` overload: `(SourceLocation OpenLoc, ParsedType TypeRep, SourceLocation CloseLoc, Expr *LHS, Expr *RHS)` — no `Scope*`; the overloads are distinguished by the second parameter |
| `clang/lib/Sema/SemaExpr.cpp` | the overload's body: `ActOnCXXTypeConstructExpr(TypeRep, OpenLoc, {LHS, RHS}, CloseLoc, /*ListInitialization=*/false)`, result wrapped in `BacktickInfixExpr` exactly like the call path |
| `clang/lib/AST/StmtPrinter.cpp` | `VisitBacktickInfixExpr` restructured: call path unchanged, then two new recovery arms — `CXXTemporaryObjectExpr` (type printed via `getType().print(OS, Policy)`, which preserves typedef/qualifier sugar) and `CXXUnresolvedConstructExpr` (`getTypeAsWritten()`), each requiring ≥ 2 args — then the semantic-form fallback |
| `clang/test/Parser/backtick-infix.cpp` | 8 new D16 cases with `-ast-dump` FileCheck assertions on node *and* type: bare class, qualified, CTAD, template-id, typedef, dependent (`CXXUnresolvedConstructExpr`), function-hides-class, statement position |
| `clang/test/Parser/backtick-ast-print.cpp` | 4 new round-trip cases (bare, qualified, CTAD, dependent); the re-parse RUN line covers them |
| `clang/test/Parser/backtick-diagnostics.cpp` | `` a `int` b `` → `excess elements in scalar initializer` (semantic parity, not a parse error); failed CTAD → the spelled form's `no viable constructor or deduction guide` |

## How it actually works (differs from the step file's sketch — read this)

The step prescribed touching the general annotate-trigger set at
`ParseExpr.cpp:1003-1005` and adding a type-without-parens arm at
`:1459-1461`. **Neither general-parser site was touched.** Everything is
intercepted *slot-locally*, before `ParseExpression()` is ever called, in
`TryParseBacktickTypeSlot()`:

1. **Pre-annotation** for exactly the sequences the expression parser would
   annotate anyway (`kw_typename`, `kw_decltype`, `annot_cxxscope`,
   `::` not followed by `new`/`delete`, `identifier` followed by `::` or
   `<`) — so non-type slots parse byte-identically to before.
2. **Bare identifier followed by `` ` ``** → `Sema::getTypeName()` probe.
   Its `IsClassTemplateDeductionContext` default returns the
   deduced-template-specialization placeholder for class template names, so
   **CTAD needed no second annotate case** — the step's item 4 came free.
   A null result (function, variable, overload set) falls back to the
   expression path, which is how `struct stat` hidden by `int stat(int,int)`
   correctly resolves to the *call*.
3. **`annot_cxxscope` + identifier + `` ` ``** → `TentativeParsingAction`
   around `ParseOptionalCXXScopeSpecifier` + qualified `getTypeName` probe;
   reverts cleanly when the qualified name is not a type (annotation tokens
   survive the revert by design).
4. **`Token::isSimpleTypeSpecifier` + `` ` ``** (annot_typename, builtins,
   annot_decltype) → the functional cast's own machinery: `DeclSpec` →
   `ParseCXXSimpleTypeSpecifier` → `Declarator(FunctionalCast)` →
   `ActOnTypeName`, so the `TypeSourceInfo` carries real locations.

The "discriminated alternative" of step item 3 is just a `ParsedType`
sitting beside the `ExprResult`; the tri-state is `TypeResult`
(invalid = annotation error already diagnosed / usable = type slot /
unset = expression slot).

Of the step's six implementation items: 1 replaced (slot-local, tighter),
2 subsumed by the same routine, 3 simplified, 4 free, 5 exactly as written,
6 needed both printer arms. Item 7 (paper grammar) done — see below.

## Verification evidence

- **All four measured defect shapes fixed** and verified by hand against
  `build-backtick-trunk/bin/clang -cc1 -std=c++23 -fbacktick`: bare class,
  class template (the paper's `pr` example), qualified `N::P`, builtin
  `int` — the last now failing with **exactly** `int(1, 2)`'s
  `excess elements in scalar initializer`, which is the D16 contract
  (parser parity; Sema decides).
- Dependent slot: `BacktickInfixExpr 'T'` wrapping
  `CXXUnresolvedConstructExpr`; instantiates through the existing
  `TreeTransform` re-wrap untouched; prints `` a `T` b `` and the
  instantiation prints `` a `P` b ``.
- `-ast-print` round-trip: backtick form printed for all shapes (CTAD
  prints the *deduced* specialization ``5 `pp<int, int>` 6``, which
  re-parses as a template-id type slot — same meaning, not the written
  spelling; typedef sugar `` `I` `` and qualifiers `` `N::Q` `` are
  preserved); second RUN line re-parses everything.
- All 11 backtick lit tests pass on both branches.
- **`check-clang`, UNFILTERED, `backtick-trunk`:** 54107 discovered / 48222
  passed / **0 failed** / 27 XFAIL / 5852 unsupported / 6 skipped, `EXIT=0`
  — identical to BL01's baseline (new cases went into existing test files,
  so lit's file counts do not move).
- **`check-clang`, UNFILTERED, `backtick-23`:** 54341 discovered / 48500
  passed / **1 failed** / 27 XFAIL / 5807 unsupported / 6 skipped, `EXIT=1`
  — the single failure is `Clang :: Format/dump-config-objc-stdin.m`, the
  documented `backtick-23`-only B33 artifact. Identical to BL01's baseline.
  Verified independently after the cherry-pick, not inferred from it.

## Deviations from the plan / design

- **`ops/DEVIATIONS.md` DEV-08** — the load-bearing row: D16 was "blessed as
  a consequence" and turned out to cost two grammar productions plus a
  disambiguation paragraph, one parser routine, `ParsedType` threading, a
  Sema overload, and two printer arms. "Consequences" of a design are not
  free; the paper's implementation-experience section wants these numbers.
- **`ops/gcc/DEVIATIONS.md` DEV-G08** — GCC does not implement D16; the two
  compilers now accept different programs under the flag. Open divergence,
  deliberately not part of BL02.
- Mechanism deviation from the step file (slot-local interception instead
  of general-parser edits) recorded above; it is *why* the diff stays out
  of every non-backtick parse path.

## Paper edits (this repo, same step)

- `papers/d4307r0.md` `[expr.backtick]`: `backtick-operator` is now
  `assignment-expression | simple-type-specifier | typename-specifier`; new
  paragraph [2] defines the type interpretation via [expr.type.conv] and
  the lookup-based disambiguation (type wins iff lookup finds a type or
  class template — matching the implementation and the `stat` case);
  old [2]/[3] renumbered [3]/[4]. The `r7` CTAD example is now derivable
  from the grammar instead of contradicting it.
- The D16 prose section now states the grammar basis explicitly instead of
  "blessed as a consequence, not carved out as a special rule."
- `docs/backtick-operator-design.md` §17.3/D16 **not** edited — that is the
  design-doc author's reconciliation of DEV-08, per the feedback loop.

## Discoveries affecting later steps

- **`Sema::getTypeName` is the whole CTAD story.** Anyone adding a
  type-slot to another front end (GCC, DEV-G08) should look for the
  equivalent of its deduction-context placeholder rather than a separate
  template-name path.
- **Annotation tokens survive `TentativeParsingAction` revert** — that is
  what makes the qualified-name probe safe and cheap.
- A `Sema.h`/`Parser.h` touch rebuilds ~270 edges including all of
  `AllClangUnitTests` (~15 min wall with the gate); budget that, not BL01's
  2-edge experience.
- The gate numbers did not move because lit counts test *files*: extending
  existing tests is invisible in discovered/passed arithmetic. If you want
  the ledger to show growth, add files.

## Forward notes for the NEXT step (BL03 — `B14`, analyzer × `UserOperatorExpr`)

Written after reading `steps/BL03-analyzer-useroperator.md`.

- **BL02 touched nothing you depend on.** No analyzer, CFG, or
  `LiveVariables` change; the Unicode branches are untouched. Your F24
  reference commit is `169e45c7916f` on `backtick-trunk` (now one behind
  HEAD `5a2b586463d9`).
- **Run M1 first** (`ops/unicode-operators/clang/steps/M1-forward-port-backtick-fixes.md`,
  unchecked). Note for whoever specs **M2**: it forward-ports *BL02* + BL06,
  and both BL02 commits above are what M2 will carry — the D16 type slot
  will need `UserOperatorExpr`-side thinking on the Unicode branch too
  (does `x ⊞T⊞ y` mean construction? That is a *design* question, not a
  port; flag it rather than deciding it in M2).
- Your gate baseline on the Unicode side is **still U20's filtered figure**
  (54171 / 48285 / 0) — BL01's forward notes asked the first Unicode step
  to re-measure unfiltered; that is you (or BL04/BL07, whichever gates
  first).
- The backtick-branch baselines you might diff against are now:
  trunk 54107 / 48222 / 0 at `5a2b586463d9`; 23.x 54341 / 48500 / 1 at
  `554d470ca412`, the sole failure being `Format/dump-config-objc-stdin.m`
  (B33).
- BL03's step file warns the ExprEngine/CFG pairing must move together;
  nothing in BL02 changes that analysis.

## Open risks / TODOs

- **CTAD print form**: `-ast-print` emits the deduced specialization, not
  the written template-name. Semantically a faithful round-trip
  (documented in the test); if the paper ever claims *spelling*-exact
  round-trip, this is the counterexample. No AST change without a new
  design decision — the written `TypeSourceInfo` is replaced by Sema
  during deduction.
- `` x `auto` y `` is **not** admitted by the type arm — `auto` is a
  *placeholder-type-specifier*, not a *simple-type-specifier*, in both the
  standard grammar and `Token::isSimpleTypeSpecifier` (verified: it dies
  with the pre-existing `expected '(' for function-style cast` parse
  error, while `auto(1, 2)` errors semantically with "contains multiple
  expressions"). Since C++23's decay-copy `auto(x)` is single-argument
  only, no expressible program is lost; the proposed grammar likewise
  excludes it. If EWG ever asks, this is a deliberate consequence of
  writing the production as `simple-type-specifier`, not an oversight.
- B31 (inotify watch budget) remains open and root-only; both BL02 gates
  ran clean with the budget still nearly exhausted.
