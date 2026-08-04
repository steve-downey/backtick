# Handoff — U17 serialization, import, `TreeTransform`, visitors

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `8ec6095c41fb`
  (parent `f4fec96f7c41`, U16)
- **Date / agent:** 2026-08-04

**9 production files, +88/−17**; 15 files total, +658/−17, of which 421
lines are three new lit tests and 137 are new gtest cases. The step's own
code is small. Its value is that it is the first step to **execute** code
two earlier steps wrote blind.

## The opening question: did U16's untested serialization work?

**Yes, on the first run, with no change.** That is the honest answer and it
is worth recording as a process finding rather than a relief.

U16 shipped `ASTStmtWriter::VisitUserOperatorExpr`,
`ASTStmtReader::VisitUserOperatorExpr` and the `EXPR_USER_OPERATOR`
allocation arm because `ASTStmtWriter`/`ASTStmtReader` declare one visitor
per node from `StmtNodes.inc` and an omitted definition is a **link**
error. So the linker forced the code and nothing at all checked its
correctness. `clang/test/PCH/unicode-operators.cpp` — which `-ast-print`s a
TU built against a precompiled header and diffs it byte-for-byte against
`-ast-print` of the same source parsed whole — passed the moment it could
run. Same for the node in a C++20 module interface.

This is DEV-U13's "the toolchain forces half a new node's obligations and
is silent about the rest" in its sharpest form: here the toolchain forced
the *code* and was silent about whether the code was *right*. Recorded as
part of DEV-U14.

## The `DeclarationNameKey` group (U06 sites 29–33)

The five deferred sites are one decision and it is the obvious one:

| Site | File:line | What it is now |
|---|---|---|
| 29 | `ASTWriter.cpp:4190` | `EmitKeyDataLengthBase`: `KeyLen += 4;` |
| 30 | `ASTWriter.cpp:4229` | `EmitKeyBase`: `LE.write<uint32_t>(Name.getUserOperatorCodePoint());` |
| 31 | `ASTReader.cpp:1345` | `DeclarationNameKey(DeclarationName)`: `Data = Name.getCXXUserOperatorCodePoint();` |
| 32 | `ASTReader.cpp:1376` | `getHash`: `ID.AddInteger((uint32_t)Data);` |
| 33 | `ASTReader.cpp:1429` | `ReadKeyBase`: `Data = endian::readNext<uint32_t, little>(d);` |

plus one new accessor,
`serialization::DeclarationNameKey::getUserOperatorCodePoint()`
(`ASTBitCodes.h`, beside `getOperatorKind()`), because the writer needs to
get the payload back out of the key. `ASTBitCodes.h:2189`'s
`getIdentifier()` assert is **unchanged** — a user operator is not
identifier-keyed, exactly as U06 instructed.

Two things worth knowing beyond the mechanics:

- **The width is forced.** `CXXOperatorName`'s key is one byte because
  `OverloadedOperatorKind` has ~54 values. The U1 set spans
  U+2190..U+2BFF, so no user operator fits in a byte; `uint32` matches the
  `uint32_t CodePoint` the name already stores and matches what
  `ObjC*Selector` writes, so no new width appears in the format.
- **Nothing needs cross-module remapping, and that is a dividend of U06's
  identity choice.** The identifier- and selector-keyed kinds store a
  module-local ID that `ReadKeyBase` has to translate through
  `Reader.getLocalIdentifier` / `getLocalSelector`. A code point is
  context-independent, so the reader just reads it. U06 chose the raw code
  point over an `IdentifierInfo *` for three reasons; this is a fourth
  that only became visible here, and DEV-U14 recommends U§8 say so.

**No `llvm_unreachable` naming U17 remains anywhere in the tree** —
verified by `grep -rn U17 clang/lib clang/include clang/tools
clang-tools-extra` (the only remaining hits are the unrelated
`U17pass_object_size` mangling substring). U09's two are also gone.
`MicrosoftMangle.cpp`'s hole is a *diagnostic*, not an unreachable, and is
DEV-U09's deliberate outcome.

## `ASTImporter`

`ASTNodeImporter::VisitUserOperatorExpr` (`ASTImporter.cpp`, immediately
after `VisitCXXRewrittenBinaryOperator`), declaration beside it at `:660`.
Six lines: import the semantic form and the operator location, carry the
code point and the arity across unchanged. The `DeclarationName` half was
already done in U06 (sites 13/14).

Nothing forces this — `ASTNodeImporter`'s fallback returns an *error* for
an unhandled node rather than failing to link — so the three new unittests
are the only thing that would ever have caught its absence. All three pass
in all four `DefaultTestArrayForRunOptions` configurations.

**Note for the replay ledger and for anyone reading the two tracks side by
side:** `ASTImporter.cpp` *is* touched by the backtick track
(`VisitBacktickInfixExpr` at `:651`/`:8169`), so this is one of the few
U17 files with a backtick hunk in it. The new code is anchored on
upstream's `VisitCXXRewrittenBinaryOperator`, not on backtick's, so the
two are independent.

## `StmtProfile` / `ODRHash` — and a correction to U16's forward note

**U16's forward note on this was wrong and should not be relied on.** It
said `ODRHash` for the statement "goes through `ODRStmtVisitor`, which has
no per-node requirement and currently falls back to `VisitStmt`", so a use
would hash by its semantic form only. There is no `ODRStmtVisitor`.
`Stmt::ProcessODRHash` (`StmtProfile.cpp:3025`) constructs a
`StmtProfilerWithoutPointers`, which **is** a `StmtProfiler` — so
`StmtProfiler::VisitUserOperatorExpr`, which U16 itself wrote and which
does `ID.AddInteger(S->getCodePoint())`, is exactly the ODR statement
hash. The code point was already in it.

So both ODR obligations were already met and U17's job was to prove them:

- **the name** — `ODRHash::AddDeclarationNameInfo` (U06 site 10) adds the
  code point;
- **a use** — `StmtProfiler::VisitUserOperatorExpr` (U16) adds it too.

`clang/test/Modules/unicode-operators-odr.cpp` proves both directions.
`SameName` (identical member `operator⊞` in two modules) and `SameBody`
(identical method body using `a ⊞ b`) merge **silently**; `DifferentName`
(member `operator⊞` vs `operator⊗`) and `DifferentBody` (body using `⊞`
vs `⊗`) are both diagnosed, with the operator printed as its glyph in the
diagnostic:

```
'DifferentName::operator⊗' from module 'Second' is not present in
definition of 'DifferentName' in module 'First'
note: definition has no member 'operator⊗'
```

**One honest limitation.** A collision test that isolates the code point's
contribution to the *statement* hash cannot be written, because two
different operators can never resolve to the same function — the callee's
`DeclarationName` differs in every reachable case, so the statement hash
would differ even if the code point were not added. The code-point term is
belt-and-braces, correct by construction, and unfalsifiable by test. Said
plainly rather than claimed as evidence.

## ASTMatchers / clang-tidy — the scope call U16 asked for

**In scope, and done.** U16 flagged this as "the largest unclaimed surface
the node created" and asked for an explicit decision because U18 and the
paper's tooling claim depend on it. The answer is that the node is now
visible to matchers, clang-query and clang-tidy:

- `userOperatorExpr()` — declaration + doc comment in `ASTMatchers.h`, the
  `VariadicDynCastAllOfMatcher` in `ASTMatchersInternal.cpp`, and the
  `REGISTER_MATCHER` line in `Dynamic/Registry.cpp` (which is what
  clang-query and clang-tidy's dynamic matchers use).
- Two traversal sites in `ASTMatchFinder.cpp`, both modelled on
  `CXXRewrittenBinaryOperator`: `TraverseUserOperatorExpr` in the
  child visitor, and the `ASTNodeNotAsIsSourceScope` /
  `ASTNodeNotSpelledInSourceScope` pair in `MatchASTVisitor::TraverseStmt`.
  Without these, `TK_IgnoreUnlessSpelledInSource` walks the semantic form
  and a clang-tidy check sees a synthesized callee naming `operator⊞` as
  if it were spelled in the source. With them, the children as written are
  the operands.

**`hasAnyOperatorName()` deliberately does not extend to the node, and the
reason is the closed-table thesis in a fourth place.** `getOpName`
(`ASTMatchersInternal.h:2262/2305`) returns a `StringRef` into a *static*
spelling table — `OperatorKinds.def`, `BinaryOperator::getOpcodeStr` — and
a user operator's spelling is a UTF-8 encoding computed into a buffer, so
there is nothing to return a `StringRef` to. A matcher that selects a
particular user operator has to be keyed on the code point. The doc
comment says so. This is the first instance in the track where the right
answer to a closed table is a **refusal** rather than a sibling; DEV-U14
recommends putting it beside DEV-U13's three-for-three list.

**Two mechanical traps in this area.** (1) `clang/docs/LibASTMatchersReference.html`
is **generated** and `clang/test/AST/ast_matchers_updated.test` diffs it
against a fresh run of `clang/docs/tools/dump_ast_matchers.py`. Adding a
matcher without regenerating fails the gate. Regenerate with
`python3 clang/docs/tools/dump_ast_matchers.py clang/docs/LibASTMatchersReference.html`.
(2) That script writes with `open(..., "w")`, i.e. the locale's preferred
encoding, and the doc comment contains `⊞`. Verified to produce identical
output under `LC_ALL=C`, so it is safe here — but a non-ASCII doc comment
is a thing to check, not assume.

`clang-tidy` itself needed **no** change: no in-tree check switches on
`Stmt::StmtClass`, and the checks that match operators do so through
matchers, which now have an entry to use if they want one. No existing
check was taught about user operators; that would be a feature, not a
serialization obligation.

## The one site nothing else would have found

`clang/tools/libclang/CXCursor.cpp:175` — `MakeCXCursor`'s exhaustive
`switch (S->getStmtClass())`. The first U17 build reported

```
CXCursor.cpp:175:11: warning: enumeration values 'UserOperatorExprClass'
and 'BacktickInfixExprClass' not handled in switch [-Wswitch]
```

i.e. the same two-enumerator message U16 saw in `ExprEngine.cpp`, in a
*second* file. **U16 did not see this one**, because at that point `ninja
clang` had not relinked libclang; it surfaced here only because U17 touches
`ASTBitCodes.h` and `ASTMatchers.h`. `LLVM_ENABLE_WERROR` is `OFF`, so the
build exited 0 both times.

`UserOperatorExprClass` is now grouped with
`CXXRewrittenBinaryOperatorClass` in the `CXCursor_UnexposedExpr` arm.
The `BacktickInfixExprClass` half is **left alone** as instructed, so the
warning now names one enumerator instead of two — the same state
`ExprEngine.cpp:1688` is in.

**This moves DEV-U13's discovery-method table**: the "found only by
`-Wswitch`" category is **2**, not 1, and the silent category is 13. The
lesson stands and gets stronger — the exit code was 0 on a build that was
missing a dispatch arm, twice, in two different steps.

## The complete switch-site list (for U§8's cost account)

Two independent fan-outs, no shared entry, plus this step's residue.

**Axis 1 — `DeclarationName::NameKind`: 33 sites in 20 files** (DEV-U04).
All 33 are now filled. The seven U06 deferred: 27 and 28 by U09 (Itanium
`mangleOperatorName`; Microsoft, a diagnostic), 29–33 by U17.

**Axis 2 — `Stmt::StmtClass` dispatch for the node: 29 sites in 21 files**
(DEV-U13's 28 plus `CXCursor.cpp`). Revised discovery breakdown:

| How found | Count | Sites |
|---|---|---|
| Link error | 6 | `StmtPrinter`, `StmtProfile`, `ASTStmtWriter`, `ASTStmtReader`, `TreeTransform`, `RecursiveASTVisitor` |
| Exhaustive switch ending in `llvm_unreachable` | 8 | `ExprClassification`, `ExprConstant::CheckICE`, `ItaniumMangle::mangleExpression`, `Expr.cpp` ×3, `Sema::canThrow`, `CGExpr::EmitLValue` |
| `-Wswitch` only, on a `WERROR=OFF` build | **2** | `StaticAnalyzer/Core/ExprEngine.cpp:1688` (U16), `tools/libclang/CXCursor.cpp:175` (U17) |
| Nothing at all | 13 | four `CGExpr*` emitters, three more in `CGExpr.cpp`, `ExprConstant`'s evaluator, `ByteCode/Compiler`, the reader's allocation arm, two `ASTNodeTraverser` hooks, `TextNodeDumper` |

**Axis 3 — unforced tooling surface, new in U17: 5 sites in 5 files.**
`ASTImporter.cpp` (the importer; unforced, its fallback errors),
`ASTMatchFinder.cpp` (two traversal sites), `ASTMatchersInternal.cpp`,
`Registry.cpp`, `ASTMatchers.h` — plus the generated
`LibASTMatchersReference.html`, which *is* forced, by a lit test.

**Total for the paper: 67 dispatch/registration sites across the three
axes**, of which 14 are forced by a link error, 8 by an
`llvm_unreachable`, 2 by a warning nobody has to read, 1 by a lit test,
and **42 by nothing**.

## Total diff size, Phase B + D

The number U§8 predicts is "a real cost, but a worked precedent". Measured
on this branch (U06–U10 = Phase B, U16–U17 = Phase D; U18 not yet done):

| Step | All files | Insertions | Deletions | Production files | Production ins/del |
|---|---|---|---|---|---|
| U06 | 21 | 436 | 1 | 19 | +249/−1 |
| U07 | 9 | 186 | 5 | 8 | +89/−5 |
| U08 | 9 | 323 | 1 | 6 | +115/−1 |
| U09 | 3 | 191 | 11 | 2 | +71/−11 |
| U10 | 2 | 493 | 0 | **0** | — |
| U16 | 33 | 664 | 38 | 31 | +437/−22 |
| U17 | 15 | 658 | 17 | 9 | +88/−17 |
| **Total** | **92 touches / 76 unique** | **2951** | **73** | **75 touches / 62 unique** | **+1049/−57** |

So: **about 1,050 lines of production code across 62 unique files** buys
the whole name half and the whole AST/serialization half of the feature —
declaration, mangling, overload resolution, the expression node,
instantiation, PCH, modules, import, ODR and matchers. Nearly two-thirds
of the total diff (1,902 of 2,951 lines) is **tests**, and one whole step
(U10) added no production line at all. That ratio is itself the argument:
the feature is mostly evidence.

Phase C (U11 + U13) adds 8 more production files and +303/−48 if U§8 wants
the expression side too; U18 is not counted.

## Verification evidence

**Build:** `ninja -C /home/sdowney/src/llvm/build-unicode clang
AllClangUnitTests` → `EXIT=0`, 335 edges on the first pass (the
`ASTBitCodes.h` + `ASTMatchers.h` edits rebuild libclang, the matcher
library and the unittest binary), 4 edges on the follow-up `CXCursor.cpp`
build. **One** `warning:` line on the final build: the pre-existing
backtick `-Wswitch` on `BacktickInfixExprClass` in `CXCursor.cpp:175`.

**New tests.**

- `clang/test/PCH/unicode-operators.cpp` (191 lines, 10 RUN lines). The
  load-bearing line is not a FileCheck but a `diff -u`: `-ast-print` of
  the file compiled whole (`-include %s %s`) against `-ast-print` of the
  same file with its header half precompiled. Covers three `operator⊞`
  overloads, a second and a third operator, a member operator, an ADL
  namespace, a `UserOperatorExpr` in a variable initializer and in a
  function body, a dependent one in a template body, a concept, a class
  template with a **member** user operator, its **partial specialization**,
  and a use inside a **lambda inside a template** (the three
  `TreeTransform` shapes U16 asked U17 to add), all instantiated on the far
  side of the boundary, including for a type declared *after* the PCH was
  written. Also `-fbacktick` on both sides, diffed (U7).
- `clang/test/Modules/unicode-operators.cppm` (122 lines, 8 RUN lines). A
  C++20 named module interface plus an importer, in both the full and the
  **reduced** BMI, plus the negative: a module built with
  `-funicode-operators` loaded by a compilation without it is diagnosed
  (`LANGOPT(UnicodeOperators, …, NotCompatible, …)`), it does not silently
  half-work.
- `clang/test/Modules/unicode-operators-odr.cpp` (108 lines). Two
  implicit-module-map modules; same-vs-different for both the operator's
  *name* and the operator used in a member's *body*.
- `clang/unittests/AST/ASTImporterTest.cpp` (+78): `ImportUnicodeOperators`
  ×3 — the name (kind, code point, and that the imported name is the *same
  object* the target context would build for itself), the expression (code
  point, arity, valid `OpLoc`, a `CallExpr` semantic form), and that two
  distinct operators stay distinct. 4 parameter sets each = 12 cases.
- `clang/unittests/ASTMatchers/ASTMatchersNodeTest.cpp` (+59): 2 cases.
  `matchesConditionally` runs the static **and** the dynamic matcher and
  fails if they disagree, so these also gate the `Registry.cpp` entry.

**Full gate:** `ninja -C $B check-clang` → 54163 discovered / 48269 passed
/ 27 XFAIL / 5853 unsupported / 6 skipped / **8 failed**, 174.3 s. All 8
are the known `DirectoryWatcherTest.*` inotify cases; **65,382 of 65,536**
watches held machine-wide at gate time, the identical figure every step
since U06 has recorded. Filtered re-run:

```bash
ulimit -c 0
GTEST_FILTER='-DirectoryWatcherTest.*' $B/bin/llvm-lit -s $B/tools/clang/test
```
→ `EXIT=0`, **54155 discovered / 48269 passed / 0 failed** / 27 XFAIL /
5853 unsupported / 6 skipped; zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines.
173.9 s.

Arithmetic closes exactly: 54155 = U16's 54138 **+17**, 48269 = 48252
**+17** — three lit tests and fourteen gtest cases, nothing else. The
step's whole risk was "serialization breakage shows up as *unrelated* PCH
and module test failures"; the log was read line by line and there are
none.

`Analysis/func-mapping-test.cpp` and `Analysis/checker-plugins.c` — U16's
stale-`clang-extdef-mapping` trap after an `ASTBitCodes.h` change — both
**passed**, because `check-clang` rebuilds that tool. If you run targeted
lit after touching `ASTBitCodes.h`, expect them and do not chase them.

## Deviations from the plan / design

**DEV-U14** (`DEVIATIONS.md`): a fifth Clang bullet for U§8 —
*serialization, modules and tooling* — with the "one decision, five sites,
silent when wrong" shape of the `DeclarationNameKey` group; the
code-point-identity dividend (no cross-module remapping); the "the linker
forced the code and nothing checked it" finding; and the
`hasAnyOperatorName` refusal as a fourth instance of the closed-table
pattern.

Departures from the step file, both deliberate:

- **Item 4 (`TreeTransform`) was done by U16, not here.** U17 did what
  U16's handoff asked instead: the three shapes the AST test does not
  reach — class template with a member user operator, partial
  specialization, lambda inside a template — are now tested, and tested
  across a serialization boundary, which is strictly stronger than
  instantiating them in the TU that wrote them.
- **Item 6's "clang-tidy/static-analyzer switches if the build forces
  them" understates what was done.** Nothing forced the ASTMatchers work
  — that is exactly why it needed a decision — and it was taken in scope
  because U16 asked for an explicit answer that U18 and the paper depend
  on. See the section above.

## Discoveries affecting later steps

- **`-ast-print` after a PCH reorders a class's members**: a class whose
  fields are declared *before* its methods prints its fields **last** when
  deserialized. Pre-existing, nothing to do with user operators, and it
  will break any `-ast-print`/PCH diff test written the obvious way. The
  PCH test declares its data members after its member operators and says
  why in a comment. Anyone writing a PCH round-trip print test will lose
  ten minutes to this.
- **`-verify` and `-include %s %s` do not mix**: the file is processed
  twice, so a single `// expected-no-diagnostics` is seen twice and
  `-verify` objects. Use `-verify` on the plain and the `-include-pch`
  runs, and no `-verify` on the `-include` run.
- **Both `-fbacktick` and `-funicode-operators` are `NotCompatible`
  LangOpts** (`LangOptions.def:536-537`), so a PCH or module built with one
  set of flags cannot be loaded with another. That is upstream behaviour
  for a `LANGOPT`, it is correct, and it means every module RUN line must
  build its own `.pcm` with the flags it will read it with. It also makes
  a nice negative test, which the module test now has.
- **ODR diagnostics print the operator as its glyph**, e.g.
  `'DifferentName::operator⊗' from module 'Second' is not present …`, with
  no work — U06 site 10 plus `DeclarationName::print`.
- **`clang/lib/CIR/` is still untouched and still uncompiled.** CIR is off
  in `build-unicode`, and CIR has a `CXXRewrittenBinaryOperator` site set
  (`CIRGenFunction.cpp`, `CIRGenExprScalar.cpp`, `CIRGenExprAggregate.cpp`,
  `CIRGenExprComplex.cpp`). It is the one part of the node's obligations no
  build on this branch has ever checked. U19 should note it; U20 will meet
  it if it enables CIR.
- **`SemaCodeComplete.cpp:1061`** is still the one-line completion-priority
  grouping every step since U06 has left alone. Still unclaimed.

## Forward notes for U12 — prefix parse in operand position

Written after reading `steps/U12-prefix-parse.md`.

- **Everything downstream of the parser is already built and already
  handles arity 1.** `UserOperatorExpr` stores `NumOperands` and
  `getOperand(0)` / `getBeginLoc()` (which returns `OpLoc` for the prefix
  form) / the printer's prefix arm all exist. `Sema::CreateOverloadedUserOp`
  takes a `MultiExprArg`, so a one-element array is the whole Sema call.
  `TransformUserOperatorExpr` loops over `getNumOperands()`. As of U17 the
  prefix form also serializes, imports and ODR-hashes with no further
  work — the arity is written and read as an integer and the code point is
  the identity either way. **None of that has ever executed**, because
  nothing constructs a prefix node yet. Your step is the first to reach it.
- **The first thing to do after the parser arm works is `-ast-print` a
  prefix use**, three lines, which exercises `getOperand(0)`,
  `getBeginLoc()` and the printer's prefix arm in one command. U16 said
  this and it is still the cheapest coverage available.
- **Then add one prefix case to each of the three U17 test files** — a
  prefix use in a PCH'd function body, one in a module interface, and one
  in a `DifferentBody` ODR pair. Each is one line, and together they are
  the only thing that will ever execute the serialization and import paths
  for `NumOperands == 1`. `clang/test/PCH/unicode-operators.cpp` §7 and
  `clang/test/Modules/unicode-operators.cppm`'s tail are the places.
  **Do not skip this**: U17's evidence for the prefix form is a code
  reading, not a test run.
- **Do not add an `ASTMatchers` predicate for fixity.** `userOperatorExpr()`
  matches both forms; if U12 wants to distinguish them, the answer is
  `UserOperatorExpr::isPrefix()`, and adding a `hasFixity`-style matcher is
  a separate decision with a docs-regeneration cost (see the trap above).
- The step's item 2 — "nothing decides prefix-vs-infix by lookahead" — has
  a serialization corollary worth checking cheaply: the *node* records the
  arity explicitly rather than deriving it, so a prefix and an infix use of
  the same code point are distinguishable after a round trip. Assert it in
  one `static_assert` over two overloads returning distinct tags, in the
  PCH test, and the claim is evidenced rather than argued.
- Your gate needs `check-clang` green. The five gate facts in `PLAN.md`
  still hold; nothing U17 did changes the baseline shape. **Baseline for
  you: 54155 discovered / 48269 passed / 0 failed on the filtered re-run.**

## Forward notes for U14 — semantics sweep

Written after reading `steps/U14-semantics-tests.md`. U16's forward notes
for U14 are still accurate and still worth reading in full; these add to
them rather than repeat them, with one correction.

- **Correction to U16's note.** It said the statement `ODRHash` falls back
  to `VisitStmt` and that the code point is therefore not in it. That is
  wrong — `Stmt::ProcessODRHash` uses `StmtProfilerWithoutPointers`, a
  `StmtProfiler`, so U16's own `VisitUserOperatorExpr` **is** the ODR
  statement hash. If U14 was planning to prove or fix that, it is done and
  the evidence is `clang/test/Modules/unicode-operators-odr.cpp`.
- **Item 4 is doubly unblocked now.** U16 unblocked dependent operands with
  member operators; U17 has added the class template with a member user
  operator, its partial specialization, and a lambda inside a template —
  but all three live in `clang/test/PCH/unicode-operators.cpp`, where they
  are *incidental* to a serialization test. **Read that file before
  writing item 4** and put the non-serialization versions where they
  belong; do not restate what is already asserted, and do not assume a
  reader will find a template semantics claim in a PCH test. A member
  operator found through a **dependent base** is still not tested anywhere.
- **Item 9 ("both flags on, both off, each alone") now has three worked
  examples to copy**, all of them diffs rather than assertions:
  `PCH/unicode-operators.cpp` diffs a `-fbacktick` PCH print against a
  plain one, `Modules/unicode-operators.cppm` builds and reads a module
  both ways, and `AST/unicode-operator-print.cpp` (U16) diffs the printed
  form. A diff is a much stronger form of "the flags are independent" than
  two passing compilations, and it costs one extra RUN line.
- **Item 3's second constant evaluator is still unexercised.** U16 flagged
  it and nothing since has run it:
  `-fexperimental-new-constant-interpreter` on a `constexpr` user-operator
  case is a one-line RUN test of `ByteCode/Compiler.cpp`'s
  `VisitUserOperatorExpr`, which is in DEV-U13's "forced by nothing"
  category. Nobody has written it.
- **Item 8 (prefix equivalents) still needs U12**, which has still not
  landed. Scope to infix and say so, exactly as U13 and U16 did.
- Items 1, 2, 5, 6, 7 remain entirely yours and untouched by U16 or U17:
  `noexcept(a ⊞ b)`, evaluation order (D15 — assert only what [expr.call]
  guarantees), returned references used as lvalues, explicit-conversion
  operands, `consteval`, a throwing operator, deleted operators, and the
  CodeGen siblings.
- Keep the tag-returning-overload-set idiom; U13, U15, U16 and now U17's
  PCH and module tests all use it, and it is what makes "the same overload
  was selected" checkable by `__is_same` rather than by two compilations
  both succeeding.

## Open risks / TODOs

- **The `-Wswitch` `BacktickInfixExprClass` gap is now open in two files** —
  `StaticAnalyzer/Core/ExprEngine.cpp:1688` and
  `tools/libclang/CXCursor.cpp:175` — and is still not to be fixed on this
  branch. Both messages now name one enumerator instead of two. Anyone
  rebuilding will see them and should leave them.
- **A build that exits 0 has twice been missing a dispatch arm.**
  `LLVM_ENABLE_WERROR` is `OFF` in `build-unicode`. Grep the build log for
  `warning:` after every step that touches a shared AST header — and note
  that *which* files get rebuilt determines which warnings you see, so a
  small incremental build can hide one that a later step surfaces.
- **`clang/docs/LibASTMatchersReference.html` must be regenerated, not
  edited,** whenever `ASTMatchers.h`'s doc comments change, or
  `clang/test/AST/ast_matchers_updated.test` fails.
- **The UCN-spelling claim (U04) still has no evidence**, and U17 has added
  three more files that would want it — a PCH and a module are exactly
  where "all three spellings are the same operator" becomes an
  *interoperability* claim rather than a lexing one. U04 remains the
  oldest unpaid debt in the plan.
- **DEV-U07** (`ShouldParseIf<cplusplus.KeyPath>` for both flags) is still
  measured-but-unacted; owner U04/U05.
- **Neither `UserOperatorExpr` nor `BacktickInfixExpr` is in the static
  analyzer's `ignoreTransparentExprs`** (`Environment.cpp:37`), as U16
  recorded. Unchanged, still a finding rather than a bug, still unowned.
