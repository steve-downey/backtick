# Handoff — U16 AST node and `-ast-print` fidelity

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `f4fec96f7c41`
  (parent `27dc597998dc`, U13)
- **Date / agent:** 2026-08-04

**31 production files, +437/−22**, plus one new test and a rewrite of one
existing test section. The step was scoped as cosmetic and was not: the
printer is ~17 lines and the rest of the step is the node's obligations and
its `TreeTransform`.

## The node

**`UserOperatorExpr`**, declared in `clang/include/clang/AST/ExprCXX.h`
immediately after `CXXRewrittenBinaryOperator`, defined out of line in
`clang/lib/AST/ExprCXX.cpp`. It stores exactly four things:

```cpp
Stmt *SemanticForm;      // the call the use desugars to
uint32_t CodePoint;      // the operator's whole identity
unsigned NumOperands;    // 2 infix, 1 prefix
SourceLocation OpLoc;
```

`children()` is the single `SemanticForm` edge. The operands *as written*
are **not** stored; `getOperand(I)` recovers them from the semantic form —
`CXXMemberCallExpr` → `getImplicitObjectArgument()` then `getArg(I-1)`,
plain `CallExpr` → `getArg(I)`. That is
`CXXRewrittenBinaryOperator::getDecomposedForm`'s technique and it was
chosen for a specific reason: storing the operands separately would make
each of them reachable *twice* from the node, which duplicates them across
serialization (the reader would materialize two copies) and double-counts
them in every profiler and visitor that walks `children()`. One edge is what
makes the wrapper transparent.

`getBeginLoc`/`getEndLoc`/`getSourceRange` are computed from the operands,
not inherited.

## The three answers the step asked for

### 1. `CXXOperatorCallExpr` could **not** be reused — three for three

U13's forward note predicted this and it held. The blocker is one field:
`CXXOperatorCallExprBits.OperatorKind`, an `OverloadedOperatorKind` of which
`OO_None` is a **valid value**, not an absent one. Every consumer switches
on `getOperator()`, and the switches are generated from
`OperatorKinds.def`, so there is no arm to add:
`TreeTransform::TransformCXXOperatorCallExpr` opens with that switch and
its `case OO_None:` is `llvm_unreachable("not an overloaded operator?")`;
`StmtPrinter`, `getSourceRange`/`getBeginLoc`/`getEndLoc`,
`isInfixBinaryOp`/`isAssignmentOp`, and CodeGen's
`EmitCXXOperatorMemberCallExpr` dispatch all read it too.

This is the **third consecutive** instance of the same shape, and the
pattern is now worth stating as a result rather than as three anecdotes:

| Step | Upstream thing keyed on a closed kind | What it cost |
|---|---|---|
| U08 | `CheckOverloadedOperatorDeclaration` | a sibling, 54 lines |
| U13 | `CreateOverloadedBinOp` / `CreateOverloadedUnaryOp` | a sibling, ~190 lines |
| U16 | `CXXOperatorCallExpr` | a sibling node, ~135 lines + 28 dispatch sites |

Every place C++ keys operator behaviour off a closed kind, opening it costs
a **parallel** implementation, never a widened one — which is also why the
relaxation provably cannot leak into `operator+`.

The right upstream *model* is not `CXXOperatorCallExpr` at all but
**`CXXRewrittenBinaryOperator`**, which exists for the same reason this node
does: record that an expression was *written* one way and *means* another,
so instantiation can redo the resolution rather than replay its result. Its
site list transplants one for one, including the decomposition trick.

### 2. A transparent wrapper was **not** sufficient, and the shortfall is a language consequence

The backtick track's `BacktickInfixExpr` is genuinely transparent: its
`TreeTransform` transforms the inner call, and that is correct there,
because a backtick slot is an ordinary expression whose meaning *is* the
call. Do the same here and DEV-U12 part 3 reproduces exactly — the rebuilt
expression is an ordinary call, so instantiation runs [over.match.call]
rather than [over.match.oper], ADL survives (a property of the call) and
member candidates are lost (a property of the operator syntax).

So the node is transparent to *evaluation* and opaque to *transformation*:

- `TransformUserOperatorExpr` (`TreeTransform.h`) transforms
  `E->getOperand(I)` — the operands as written — and calls
  `RebuildUserOperatorExpr` → `Sema::CreateOverloadedUserOp`. It never
  transforms the semantic form.
- It recovers the **phase-1** unqualified lookup set from the semantic
  form's callee, exactly as `TransformCXXOperatorCallExpr` does: an
  `UnresolvedLookupExpr` callee goes through
  `TransformOverloadExprDecls(ULE, ULE->requiresADL(), R)` and is rebuilt
  with `R.asUnresolvedSet()` and `ULE->requiresADL()`; an already-resolved
  `DeclRefExpr` callee is carried forward as a one-element set with ADL
  **off** (it already beat everything ADL could add); a `MemberExpr` callee
  needs no set at all, because the qualified lookup on the now-known left
  operand's type finds it again.
- There is **no** `AlwaysRebuild()` early-out. That matches
  `TransformCXXOperatorCallExpr`, which also always rebuilds; it is
  `TransformCXXRewrittenBinaryOperator` that early-outs, and it pays for
  that with an explicit `MarkDeclarationsReferencedInExpr` call.

### 3. Spelling: the glyph, always — decided and documented

No spelling is stored. `printOperator()` re-encodes the code point as UTF-8
via `llvm::ConvertCodePointToUTF8`, the same one line `DeclarationName::print`
uses. So a use spelled `⊞` or `\N{SQUARED PLUS}` will print, dump and
diagnose as `⊞`. This is the right answer *because* U11 made the three
spellings one token: the code point is the identity, and a printer that
reproduced the spelling would be inventing an identity the language does not
have. **It is untestable today** — U04 has not landed, so no UCN spelling
lexes — and the test file says so in a comment. **U04 should add the two RUN
lines that assert it**, and they are cheap: the same source spelled three
ways must produce byte-identical `-ast-print` output.

## `CreateOverloadedUserOp` changed signature — replay this, not U13's

```cpp
ExprResult Sema::CreateOverloadedUserOp(Scope *S, SourceLocation OpLoc,
                                        uint32_t CodePoint,
                                        const UnresolvedSetImpl &Fns,
                                        MultiExprArg Operands,
                                        bool PerformADL = true);
```

The unqualified lookup moved *out* of it and into `Sema::ActOnUserOperator`
(`SemaExpr.cpp`), because it is the one part that needs a `Scope` — and
because the rebuild path must re-use the **recorded** phase-1 set rather
than look the name up again in a scope it has not got. Everything else in
U13's function is unchanged except that its four success returns now go
through a `Wrap` lambda. Two-phase lookup is the reason for the split; do
not "simplify" it back.

## Verification evidence

**Build:** `ninja -C /home/sdowney/src/llvm/build-unicode clang` → `EXIT=0`,
772 edges cold. **One** `warning:` line in the log, and reading the log
rather than trusting the exit code is how it was found: the first build
reported

```
ExprEngine.cpp:1688:11: warning: enumeration values 'UserOperatorExprClass'
and 'BacktickInfixExprClass' not handled in switch [-Wswitch]
```

— i.e. the pre-existing backtick gap and U16's, in one message. U16's is
closed (grouped with `CXXRewrittenBinaryOperatorClass`, the same treatment
upstream gives its own wrapper of this shape); backtick's is left alone, so
the warning now names only `BacktickInfixExprClass`. `LLVM_ENABLE_WERROR` is
`OFF` in this build, so the exit code was 0 both times.

**Both `FIXME(U16)` shapes pass.** `SemaCXX/unicode-operator-adl.cpp` §5's
`expected-error`/`expected-note` directives are gone and the section now
asserts `dependent_member(Mem{1}, Mem{2}) == 12`, `MemberCombinable<Mem>`,
`!MemberCombinable<int>` — plus a new `dependent_ranked` that pins
member-vs-non-member ranking in **one** set at instantiation, both ways
round (`MN{} ⊘ 0` → 54, non-member; `MN{} ⊘ 0L` → 53, member). That last
one is the observable that distinguishes this from a member-first fallback,
and U13 could only assert it for non-dependent operands.

**Codegen transparency.** Pre-U16 IR was captured from the U13 binary
*before* any edit, for a 21-line input covering non-member, member, chained,
parenthesized, scalar, `constexpr` in a `static_assert`, an array bound, a
template instantiation and a returned reference used as an lvalue:

```
clang -cc1 -triple x86_64-linux-gnu -std=c++23 -funicode-operators \
      -emit-llvm -O0 -disable-llvm-passes
```
→ the two `.ll` files differ in **one line**, the `llvm.ident` git hash. The
wrapper does not reach codegen.

**New test:** `clang/test/AST/unicode-operator-print.cpp` (201 lines, 7 RUN
lines) — `-ast-print`, then FileCheck the printed file; re-parse the printed
file and print again and `diff -u` the two; `-verify` the source and
`-fsyntax-only` the *printed* source (so the printed form is not merely
stable but correct); `-fbacktick` and diff against the non-backtick print
(U7); and an `-ast-dump` prefix. Covers infix, chained, parenthesized, mixed
operators, `2 * a ⊞ b` and `-a ⊞ -b` (the precedence and symmetric-prefix
shapes, which print back with no added parentheses because the printed token
sequence is the source token sequence), cast/postfix/conditional operands,
the member form including a temporary object argument, dependent non-member
and dependent **member** templates and their instantiations, ADL at
instantiation, one-set ranking, two concepts, and uses nested inside calls,
conditions and an assignment. **No prefix cases** — U12 has not landed;
the file says so.

**Full gate:** `ninja -C $B check-clang` → 54146 discovered / 48252 passed /
27 XFAIL / 5853 unsupported / 6 skipped / **8 failed**, 200.1 s. All 8 are
the known `DirectoryWatcherTest.*` inotify cases; **65,382 of 65,536**
watches held machine-wide at gate time, the identical figure U06–U13 all
recorded. Filtered re-run:

```bash
ulimit -c 0
GTEST_FILTER='-DirectoryWatcherTest.*' $B/bin/llvm-lit -s $B/tools/clang/test
```
→ `EXIT=0`, **54138 discovered / 48252 passed / 0 failed** / 27 XFAIL /
5853 unsupported / 6 skipped; zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines.
174.8 s.

Arithmetic closes exactly: 54138 = U13's 54137 **+1**, 48252 = 48251 **+1**
— the one new lit test. Nothing else changed behaviour, which for a step
that inserts a node into every user-operator expression and rewrites its
instantiation path is the claim that matters.

## The list — every dispatch over `Stmt::StmtClass` the node forced

**28 sites in 20 files.** This is a *different* fan-out from U06's 33
`DeclarationName::NameKind` sites, on a different axis; the two lists share
no entry. U17 owns what remains (below).

How each was found matters more than the count, because it is the number
U§8 should quote about what a new AST node actually costs:

**Forced by a *link* error — 6.** Six headers declare one visitor per node
with a `#define STMT(Node, Base) … Visit##Node(Node *);` block over
`StmtNodes.inc` and dispatch to it from a generated switch, so an omitted
definition does not compile-error at the declaration, it fails at link.

| # | File | Method |
|---|------|--------|
| 1 | `clang/lib/AST/StmtPrinter.cpp` | `VisitUserOperatorExpr` — **the feature** |
| 2 | `clang/lib/AST/StmtProfile.cpp` | `VisitUserOperatorExpr` — `VisitExpr` + `ID.AddInteger(getCodePoint())` |
| 3 | `clang/lib/Serialization/ASTWriterStmt.cpp` | `VisitUserOperatorExpr` |
| 4 | `clang/lib/Serialization/ASTReaderStmt.cpp` | `VisitUserOperatorExpr` |
| 5 | `clang/lib/Sema/TreeTransform.h` | `TransformUserOperatorExpr` — **the load-bearing one** |
| 6 | `clang/include/clang/AST/RecursiveASTVisitor.h` | `DEF_TRAVERSE_STMT(UserOperatorExpr, {})` |

**Forced by an exhaustive switch that ends in `llvm_unreachable` — 8.**

| # | File | Function |
|---|------|----------|
| 7 | `clang/lib/AST/ExprClassification.cpp` | `ClassifyInternal` |
| 8 | `clang/lib/AST/ExprConstant.cpp` | `CheckICE` |
| 9 | `clang/lib/AST/ItaniumMangle.cpp` | `mangleExpression` (`goto recurse` on the semantic form) |
| 10 | `clang/lib/AST/Expr.cpp` | `isUnusedResultAWarning` |
| 11 | `clang/lib/AST/Expr.cpp` | `isConstantInitializer` |
| 12 | `clang/lib/AST/Expr.cpp` | `HasSideEffects` (fallthrough list, beside `ParenExprClass`) |
| 13 | `clang/lib/Sema/SemaExceptionSpec.cpp` | `Sema::canThrow` |
| 14 | `clang/lib/CodeGen/CGExpr.cpp` | `CodeGenFunction::EmitLValue` |

**Found only by `-Wswitch`, i.e. only by reading the build log — 1.**

| # | File | Function |
|---|------|----------|
| 15 | `clang/lib/StaticAnalyzer/Core/ExprEngine.cpp:1688` | `ExprEngine::Visit` |

**Forced by nothing; silently wrong if omitted — 13.**

| # | File | Site |
|---|------|------|
| 16 | `clang/lib/AST/ExprConstant.cpp` | `ExprEvaluatorBase::VisitUserOperatorExpr` |
| 17 | `clang/lib/AST/ByteCode/Compiler.{h,cpp}` | `Compiler<Emitter>::VisitUserOperatorExpr` |
| 18 | `clang/lib/CodeGen/CGExprScalar.cpp` | `ScalarExprEmitter::VisitUserOperatorExpr` |
| 19 | `clang/lib/CodeGen/CGExprComplex.cpp` | `ComplexExprEmitter::VisitUserOperatorExpr` |
| 20 | `clang/lib/CodeGen/CGExprAgg.cpp` | `AggExprEmitter::VisitUserOperatorExpr` |
| 21 | `clang/lib/CodeGen/CGExprConstant.cpp` | `ConstExprEmitter::VisitUserOperatorExpr` |
| 22 | `clang/lib/CodeGen/CGExpr.cpp` | `LValueBaseVisitor::VisitUserOperatorExpr` |
| 23 | `clang/lib/CodeGen/CGExpr.cpp` | `StructFieldAccess::VisitUserOperatorExpr` |
| 24 | `clang/lib/CodeGen/CGExpr.cpp` | `setObjCGCLValueClass`'s `dyn_cast` chain |
| 25 | `clang/lib/Serialization/ASTReaderStmt.cpp` | the `EXPR_USER_OPERATOR` allocation arm (fails at *runtime*, not link) |
| 26 | `clang/include/clang/AST/ASTNodeTraverser.h` | the `TK_IgnoreUnlessSpelledInSource` `isa<>` exclusion |
| 27 | `clang/include/clang/AST/ASTNodeTraverser.h` | `VisitUserOperatorExpr` — visits the operands in as-written mode |
| 28 | `clang/lib/AST/TextNodeDumper.cpp` (+ `.h`) | `VisitUserOperatorExpr` — the `-ast-dump` label |

Non-dispatch sites, for completeness: `StmtNodes.td` (the `def`),
`ExprCXX.h` (the class), `ExprCXX.cpp` (`getOperand`, `printOperator`),
`ComputeDependence.{h,cpp}`, `ASTBitCodes.h` (`EXPR_USER_OPERATOR`),
`Sema.h` + `SemaOverload.cpp` + `SemaExpr.cpp` (the build site),
`TreeTransform.h`'s `RebuildUserOperatorExpr`.

**U06's TableGen trap did not recur.** `StmtNodes.td` generates macro lists,
not a switch, so nothing was hidden in a generated `.inc` — which is worth
recording precisely because U06 warned to expect it again.

## Deviations from the plan / design

**DEV-U13** (`DEVIATIONS.md`) — the fourth Clang bullet DEV-U12 asked for,
with the `CXXOperatorCallExpr` verdict, the three-for-three sibling pattern,
the "transparent wrapper is not enough" finding, and the 28-site accounting
broken down by *how the toolchain found it* (6 link / 8 unreachable / 1
warning / 13 silence). That last breakdown is the one U§8 should quote: the
toolchain forces half of a new node's obligations, warns about one more, and
is silent about the rest.

Two smaller departures from the step file:

- The step file's item 1 said "a transparent expression node … forwarding
  type/value-category/dependence to the inner call". It does forward all
  three — but it must *not* forward transformation, and the step file did
  not know that. U13's forward notes did, and were followed.
- The step file's REPLAY instruction asked whether the wrapper class is
  shared with backtick's. It is a **sibling, not shared**, and could not
  have been shared: see the REPLAY row.

## Discoveries affecting later steps

- **The `requires`-note bug U13 recorded is fixed and is now a printer
  regression test.** `because 'operator⋁(a, b)' would be invalid` is now
  `because 'a ⋁ b' would be invalid: use of undeclared 'operator⋁'`. No
  existing test asserted the old text (`SemaCXX/unicode-operator-call.cpp:291`
  quotes an *explicitly written* call, so it is unaffected), which is why
  nothing needed updating; but any new `requires`-note over an infix use now
  quotes the infix form.
- **The caret asymmetry U13 recorded is *not* fixed, and cannot be by this
  node.** A non-member lookup failure still carets only the operator and a
  member overload failure still underlines the whole expression — because
  both diagnostics are emitted *before* any node is built. The node fixes
  the range of well-formed expressions only, and it does: a
  `UserOperatorExpr` for `a ⊞ b` spans `<col:31, col:37>` while its inner
  `CallExpr` still spans `<col:33, col:37>`. Making the *diagnostics* agree
  would mean passing the full `SourceRange` into the two builders — a
  separate, small change, owner unassigned.
- **`-ast-print` cannot round-trip an `auto`-returning function template**,
  and it is a pre-existing printer limitation with nothing to do with user
  operators: the instantiation prints with the *deduced* return type
  (`template<> constexpr int f<int>(...)`), which does not match an `auto`
  primary on re-parse. The new test writes its template return types out
  and says why. Anyone else writing an `-ast-print` round-trip test will hit
  this within five minutes.
- **`-ast-print` renders `requires(T a, T b)` with a space** —
  `requires (T a, T b)` — so a FileCheck line copied from source will fail.
- **A stale `clang-extdef-mapping` fails `Analysis/func-mapping-test.cpp`
  with `unable to load precompiled file` after any `ASTBitCodes.h` change**,
  and `Analysis/checker-plugins.c` fails the same way. `ninja clang` does
  not rebuild them; `ninja check-clang` does. Both were green in the gate.
  If you run targeted lit after touching serialization, expect those two and
  do not chase them.
- **`llvm::format_hex_no_prefix` needs `llvm/Support/Format.h`**, which
  `TextNodeDumper.cpp` did not include.

## Forward notes for U17 — serialization, import, `TreeTransform`, visitors

Written after reading `steps/U17-serialization.md`.

- **Item 4 (`TreeTransform` for the expression) is done, and is U16's.** Do
  not re-do it; it is the reason U16 existed. What U17 *should* do is test
  it beyond what the AST test does — a class template with a member user
  operator, a partial specialization, a lambda inside a template, a
  `constexpr` instantiation. `TransformUserOperatorExpr` is at
  `TreeTransform.h`, immediately after `TransformCXXRewrittenBinaryOperator`.
- **The expression half of item 2 is done too**, and its shape is
  `EXPR_USER_OPERATOR` in `ASTBitCodes.h` (after `EXPR_BACKTICK_INFIX`),
  `ASTStmtWriter::VisitUserOperatorExpr` writing semantic form / code point /
  arity / `OpLoc`, `ASTStmtReader::VisitUserOperatorExpr` reading them back
  into the private fields (`ASTStmtReader` is a `friend`), and the
  allocation arm. It was done here **because the linker forced it**, not by
  scope creep: `ASTStmtWriter`/`ASTStmtReader` declare a visitor per node
  from `StmtNodes.inc`. **It has no test.** U17's PCH and modules round trip
  is exactly the missing evidence, and it is the first thing to write.
- **The `DeclarationName` half of item 2 is untouched and is the real
  work** — U06's deferred sites **29–33**, the five `DeclarationNameKey`
  sites in `ASTWriter.cpp`/`ASTReader.cpp` that must move together or module
  lookup silently misses. U06's handoff spells out the intended encoding.
  Sites **27/28** are U09's and are already filled.
- **`ASTImporter` (item 3) is untouched and is yours**, deliberately: it is
  not forced (its `VisitStmt` returns an error for unhandled nodes), so
  nothing here would have caught a mistake in it. Model on
  `ASTNodeImporter::VisitCXXRewrittenBinaryOperator`
  (`ASTImporter.cpp:8307`), which is four lines: import the semantic form,
  construct the node. For `UserOperatorExpr` also carry the code point,
  arity and `OpLoc`. Add the declaration next to
  `VisitCXXRewrittenBinaryOperator` at `ASTImporter.cpp:659`. The
  `DeclarationName` side is already done (U06 sites 13/14 — the code point
  is context-independent, so nothing needs importing).
- **`StmtProfile` (item 5) is done and profiles the code point**, so two
  uses of *different* operators cannot collide even when their semantic
  forms match. `ODRHash` for the *name* is U06 site 10 and is done;
  `ODRHash` for the *statement* goes through `ODRStmtVisitor`, which has no
  per-node requirement and currently falls back to `VisitStmt` — so a
  user-operator use hashes by class and children, i.e. by its **semantic
  form**, and two different operators resolving to the same function would
  hash equal. That is almost certainly harmless (the semantic forms name
  different functions in every reachable case) but it is unproven, and U17's
  ODR item is the place to prove or fix it.
- **`RecursiveASTVisitor` (item 6) is done**;
  `DEF_TRAVERSE_STMT(UserOperatorExpr, {})` traverses `children()`, i.e. the
  semantic form. What is **not** done and is a genuine U17 item: the
  **ASTMatchers** side. `CXXRewrittenBinaryOperator` has entries at
  `ASTMatchFinder.cpp:263` (`TraverseCXXRewrittenBinaryOperator`) and `:530`,
  a `VariadicDynCastAllOfMatcher` in `ASTMatchersInternal.cpp:934`, and
  `getOpName` overloads in `ASTMatchersInternal.h:2262/2305`. None of that
  exists for `UserOperatorExpr`, nothing forces it, and clang-tidy checks
  that match on operators will not see user operators. Decide explicitly
  whether that is in scope; if it is not, say so in the handoff, because
  U18 (clang-format) and any tooling claim in the paper depend on the
  answer.
- `clang/lib/CIR/` has a `CXXRewrittenBinaryOperator` site set
  (`CIRGenFunction.cpp`, `CIRGenExprScalar.cpp`, `CIRGenExprAggregate.cpp`,
  `CIRGenExprComplex.cpp`). **CIR is not enabled in `build-unicode`**, so
  none of it is compiled and none of it was touched. Note it rather than
  discover it.
- **`SemaCodeComplete.cpp:1061`** is still the one-line completion-priority
  grouping every step since U06 has left alone. Still unclaimed.

## Forward notes for U14 — semantics sweep

Written after reading `steps/U14-semantics-tests.md`.

- **Item 4 is unblocked. That was the point of running U16 first.**
  Dependent operands with a member operator, two-phase lookup, and a concept
  constrained on `a ⊞ b` all work now. The two shapes are already asserted
  in `SemaCXX/unicode-operator-adl.cpp` §5 and in
  `AST/unicode-operator-print.cpp` §3 — read both before writing, and
  extend rather than restate. What **neither** covers and U14 should: a
  **class template** with a member user operator (`template <class T> struct
  Box { int operator⊕(Box) const; };`), a partial specialization, and a
  member operator found through a dependent base.
- **The one thing to test that only exists because of U16**: that a
  *non-dependent* user-operator use inside a template still resolves to the
  same overload after instantiation. `TransformUserOperatorExpr` always
  rebuilds — there is no `AlwaysRebuild` early-out — so every such use is
  re-resolved with `Fns` = {the already-chosen function} and ADL **off**. If
  that is ever wrong, it will show as a template picking a different
  overload than the same code outside a template, and the tag-returning
  idiom catches it in one line.
- Items 1, 2, 5, 6, 7, 9 are untouched by U13 and U16 and are entirely
  yours: `noexcept(a ⊞ b)`, evaluation order (D15 — assert only what
  [expr.call] guarantees), returned references used as lvalues,
  explicit-conversion operands, `consteval`, a throwing operator, and the
  CodeGen siblings. `Sema::canThrow` and `ExprClassification` both forward
  through the node, so `noexcept` and value category are *inherited*, which
  is exactly the claim U14 exists to evidence — but neither is tested.
- Item 3's `static_assert(5 ⊞ 7 == 12)` is asserted in U13's file §1 and
  several constant-evaluation shapes are in the new AST test. **Note that
  constant evaluation goes through the node twice**, once in
  `ExprConstant.cpp`'s `ExprEvaluatorBase` and once in the bytecode
  interpreter (`ByteCode/Compiler.cpp`); both delegate to the semantic form,
  and only the first is exercised by anything today. A
  `-fexperimental-new-constant-interpreter` RUN line on a `constexpr` case
  is a one-line test of the second and nobody has written it.
- Item 8 (prefix equivalents) still needs U12, which has still not landed.
  Scope to infix and say so, exactly as U13 did.
- **`-ast-print` is now a cheap oracle for U14 too.** If a semantics case
  behaves oddly, `-ast-print` will show you what the compiler thinks was
  written; before U16 it showed the desugaring and was useless for that.
- Keep using the tag-returning-overload-set idiom
  (`template <int N> struct Tag { static constexpr int value = N; };`); U13,
  U15 and now U16's `dependent_ranked` all use it.

## Open risks / TODOs

- **The `-Wswitch` `BacktickInfixExprClass` gap in
  `StaticAnalyzer/Core/ExprEngine.cpp:1688` is still open** and still not to
  be fixed on this branch. U16 closed its own half of that message; the
  warning now names one enumerator instead of two. Anyone rebuilding will
  see it and should leave it.
- **Neither `UserOperatorExpr` nor `BacktickInfixExpr` (nor, upstream,
  `CXXRewrittenBinaryOperator`) is in the static analyzer's
  `ignoreTransparentExprs` (`StaticAnalyzer/Core/Environment.cpp:37`)**, so
  the analyzer loses the value of a user-operator expression. U16 gave the
  node the same treatment upstream gives its own analogue, which is
  conservative and consistent, but "upstream has the same hole for its own
  wrapper" is a *finding*, not a fix. Owner unassigned; it is a one-line
  addition if wanted.
- **ASTMatchers / clang-tidy do not know the node.** See U17's notes; this
  is the largest unclaimed surface the node created.
- **The UCN-spelling claim still has no evidence at all** (U04), and U16 has
  now added a *fourth* file that will want it — and the first one where the
  claim is directly observable, since `-ast-print` of a UCN-spelled source
  is a one-command test of "all three spellings are the same operator". U04
  remains the oldest unpaid debt in the plan.
- **U12 has still not landed**, so `UserOperatorExpr`'s prefix form
  (`NumOperands == 1`) is constructed correctly by every path and reachable
  by none. `getOperand(0)`, `getBeginLoc()` (which returns `OpLoc` for the
  prefix form) and the printer's prefix arm are all **untested**. The first
  thing U12 should do after its parser arm works is `-ast-print` a prefix
  use; it is three lines and it exercises all of that.
- **DEV-U07** (the `ShouldParseIf<cplusplus.KeyPath>` C-mode question,
  paired with `-fbacktick`) is still measured-but-unacted; owner U04/U05.
