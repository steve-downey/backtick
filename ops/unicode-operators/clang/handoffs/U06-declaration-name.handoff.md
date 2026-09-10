# Handoff — U06 `DeclarationName` kind for user operators

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `9e4042cc2c76`
  (parent `dacbe22ddeef`, U03)
- **Date / agent:** 2026-08-04

This is the step the design calls "the hard part". It is done, it is green,
and **it is smaller than the design's hedging implies** — 19 production
files, +249 lines. The expensive part was not writing the code; it was
finding the 33 places that switch over the name kind. That list is below,
and it is the artifact U09, U16 and U17 start from.

## The three decisions

### 1. Name kind: `DeclarationName::CXXUserOperatorName`

Reached through `StoredDeclarationNameExtra`, i.e. the
`CXXLiteralOperatorName` route, because **there was no alternative**. U03's
handoff called the 3-bit inline `StoredNameKind` space "completely full";
that is exact — all eight values 0–7 are taken and `PtrMask == 7`. A new
inline kind would need a fourth low bit, which needs 16-byte alignment on
every class `DeclarationName::Ptr` can point at. Not attempted; not needed.

`OverloadedOperatorKind` was never a candidate: `DeclarationNameTable`
holds `CXXOperatorIdName CXXOperatorNames[NUM_OVERLOADED_OPERATORS]` as a
flat array, and Sema indexes that enum into fixed-size tables throughout.
1,381 operators do not go there.

### 2. Identity: the raw `uint32_t` code point, no `IdentifierInfo *`

`detail::CXXUserOperatorIdName` (`DeclarationName.h:146`) derives from
`detail::DeclarationNameExtra` + `llvm::FoldingSetNode` and carries exactly
`uint32_t CodePoint` and `void *FETokenInfo`. Its `Profile` is
`FSID.AddInteger(CodePoint)` — the one line where the precedent's
`AddPointer` did not transplant.

The step offered "`IdentifierInfo *` for the spelling versus a raw UTF32
code point". Code point, for three reasons:

1. **It makes the acceptance criterion true by construction.** "Two
   spellings of the same code point must yield the same `DeclarationName`"
   is not something this layer has to enforce — U03 already put the whole
   canonicalization at the lexer boundary
   (`Lexer::getUserOperatorCodePoint`, whose `StringRef` overload U04 will
   teach the UCN forms). If the name is keyed on the scalar value, every
   spelling that decodes to 0x229E lands on the same `FoldingSet` node with
   no code of ours. An `IdentifierInfo *` would have forced us to pick a
   canonical *string* and re-derive it here — a second place to get the
   equivalence wrong.
2. **U09 wants the scalar.** U8's mangling is `v <arity>` plus a
   code-point-derived source-name (`op_u229E`). Deriving that from a
   spelling string means decoding it again in the mangler.
3. It is smaller: no `IdentifierTable` interning of operator glyphs, and
   `getCXXUserOperatorCodePoint()` returns `0` for every other kind, the
   same "no code point" convention `Lexer::getUserOperatorCodePoint` uses.

Printing is the one place that re-encodes: `DeclarationName::print`
(`DeclarationName.cpp:189`) calls
`llvm::ConvertCodePointToUTF8(CodePoint, Ptr)` from
`llvm/Support/ConvertUTF.h` into a `UNI_MAX_UTF8_BYTES_PER_CODE_POINT + 1`
buffer, yielding `operator⊞`.

### 3. The `ExtraKind` constraint — how it was solved

U03's handoff was right and the fix is the one it predicted.
`DeclarationNameExtra::ExtraKindOrNumArgs` stores `ObjCMultiArgSelector + N`
for an N-argument ObjC selector, and `getKind()` clamps anything
`>= ObjCMultiArgSelector` back to it, so **every value at or above that
enumerator is claimed**. `CXXUserOperatorName` is inserted at index 3,
*before* `ObjCMultiArgSelector`, which moves to 4
(`IdentifierTable.h:914`); `NameKind::ObjCMultiArgSelector` moves 11 → 12
and `NameKind::CXXUserOperatorName` becomes 11
(`DeclarationName.h:258`, via the existing
`llvm::addEnumValues(UncommonNameKindOffset, …)`).

A comment now states the constraint on the enum itself
(`IdentifierTable.h:905–915`) — it was entirely undocumented, which is how
it becomes a trap. And `UserOperatorNameTest.OtherKindsUnaffected` asserts
a 2-keyword selector still reports `ObjCMultiArgSelector` with
`getNumArgs() == 2` and prints `setFoo:with:`, so the renumbering is
guarded by a test rather than by care.

**Nothing else was in the way.** No bit overflowed; the step's stated
pitfall ("`DeclarationName` packs its kind into low pointer bits … an added
enumerator can overflow the available bits") does not bite, because the
uncommon kinds do not live in those bits at all. Recorded as **DEV-U04**.

## The list — every switch over `DeclarationName::NameKind`

**33 sites in 20 files.** 26 filled, 7 deferred behind an
`llvm_unreachable` whose message names the step. Line numbers are
post-edit, on `9e4042cc2c76`.

Two caveats on using this list. Sites 3 and 4 have a `default:` — the
compiler does not force them, but they would have asserted at runtime.
And site 33 is **TableGen**: the only thing that found it was the
`-Wswitch` warning on the *generated* `.inc`, so it is not greppable as
C++. Expect that trap again in U16/U17.

### `clang/lib/AST/DeclarationName.cpp` — 9 sites, all filled

| # | Line | Function | What it does now |
|---|------|----------|------------------|
| 1 | 105 | `DeclarationName::compare` | `compareInt` on the code points |
| 2 | 189 | `DeclarationName::print` | `operator` + UTF-8 of the code point |
| 3 | 266 | `getFETokenInfoSlow` | reads `castAsCXXUserOperatorIdName()->FETokenInfo` (has `default:`) |
| 4 | 291 | `setFETokenInfoSlow` | writes it (has `default:`) |
| 5 | 431 | `DeclarationNameLoc::DeclarationNameLoc` | `setCXXUserOperatorNameLoc(SourceLocation())` |
| 6 | 452 | `DeclarationNameInfo::containsUnexpandedParameterPack` | `false` |
| 7 | 476 | `DeclarationNameInfo::isInstantiationDependent` | `false` |
| 8 | 513 | `DeclarationNameInfo::printName` | delegates to `Name.print` |
| 9 | 550 | `DeclarationNameInfo::getEndLocPrivate` | `LocInfo.getCXXUserOperatorNameLoc()` |

### Filled elsewhere — 17 sites

| # | File:line | Function | What it does now |
|---|-----------|----------|------------------|
| 10 | `clang/lib/AST/ODRHash.cpp:102` | `ODRHash::AddDeclarationNameInfoImpl` | `ID.AddInteger(code point)` |
| 11 | `clang/lib/Serialization/TemplateArgumentHasher.cpp:161` | `AddDeclarationName` | `AddInteger(code point)` |
| 12 | `clang/lib/AST/ASTStructuralEquivalence.cpp:154` | `IsStructurallyEquivalent(DeclarationName)` | code points compare equal |
| 13 | `clang/lib/AST/ASTImporter.cpp:2319` | `ASTNodeImporter::ImportDeclarationNameLoc` | imports the loc |
| 14 | `clang/lib/AST/ASTImporter.cpp:10771` | `ASTImporter::Import(DeclarationName)` | `getCXXUserOperatorName(code point)` — the code point is context-independent, so nothing needs importing |
| 15 | `clang/lib/Sema/TreeTransform.h:4830` | `TransformDeclarationNameInfo` | returns `NameInfo` unchanged (no type inside) |
| 16 | `clang/lib/Sema/SemaTemplateVariadic.cpp:616` | `Sema::DiagnoseUnexpandedParameterPack` | `false` |
| 17 | `clang/include/clang/AST/RecursiveASTVisitor.h:866` | `TraverseDeclarationNameInfo` | `break` (nothing to traverse) |
| 18 | `clang/tools/libclang/CIndex.cpp:1398` | `CursorVisitor::VisitDeclarationNameInfo` | `false` |
| 19 | `clang/lib/Sema/SemaCodeComplete.cpp:3666` | `AddTypedNameChunk` | `AddTypedTextChunk(ND->getNameAsString())` — grouped with the literal operator, so completion prints `operator⊞` free |
| 20 | `clang-tools-extra/clangd/SemanticHighlighting.cpp:75` | `canHighlightName` | `false` |
| 21 | `lldb/…/Clang/ClangASTSource.cpp:125` | `ClangASTSource::FindExternalVisibleDeclsByName` | grouped with the other operator names, `break`. **COMPILE-UNVERIFIED — see Open risks** |
| 22 | `clang/lib/AST/ItaniumMangle.cpp:1447` | `mangleUnresolvedName` | grouped into the `on <operator-name>` arm — structurally right per U§9 |
| 23 | `clang/lib/AST/ItaniumMangle.cpp:1711` | `mangleUnqualifiedName` | grouped into the `mangleOperatorName(Name, Arity)` arm |
| 24 | `clang/lib/Serialization/ASTWriter.cpp:7256` | `ASTRecordWriter::AddDeclarationNameLoc` | `AddSourceLocation(DNLoc.getCXXUserOperatorNameLoc())` |
| 25 | `clang/lib/Serialization/ASTReader.cpp:10244` | `ASTRecordReader::readDeclarationNameLoc` | `makeCXXUserOperatorNameLoc(readSourceLocation())` |
| 26 | `clang/include/clang/AST/PropertiesBase.td:662` | generated into `AbstractBasicWriter.inc` / `AbstractBasicReader.inc` | a `PropertyTypeCase` with a `UInt32` `codePoint` property and a `Creator` |

Sites 22 and 23 are filled *structurally*, not semantically: they route a
user-operator name into `mangleOperatorName`, which is site 27. That was
deliberate — it collapses three Itanium holes into one, so U09 has a single
place to write the vendor-extended production.

### Deferred — 7 sites, `llvm_unreachable` naming the step

| # | File:line | Function | Message / why |
|---|-----------|----------|---------------|
| 27 | `clang/lib/AST/ItaniumMangle.cpp:2662` | `CXXNameMangler::mangleOperatorName(DeclarationName, unsigned)` | `"U09: Unicode user operator mangling not implemented"`. **This is U09's whole job**: emit `v <digit> <source-name>` here. Sites 22/23 already funnel into it. |
| 28 | `clang/lib/AST/MicrosoftMangle.cpp:1365` | `MicrosoftCXXNameMangler::mangleUnqualifiedName` | `"U09: … MSVC mangling not implemented"`. U8 records MSVC as unexamined. |
| 29 | `clang/lib/Serialization/ASTWriter.cpp:4190` | `…LookupTrait::EmitKeyDataLengthBase` | U17 |
| 30 | `clang/lib/Serialization/ASTWriter.cpp:4229` | `…LookupTrait::EmitKeyBase` | U17 |
| 31 | `clang/lib/Serialization/ASTReader.cpp:1345` | `DeclarationNameKey::DeclarationNameKey(DeclarationName)` | U17 |
| 32 | `clang/lib/Serialization/ASTReader.cpp:1376` | `DeclarationNameKey::getHash` | U17 |
| 33 | `clang/lib/Serialization/ASTReader.cpp:1429` | `…LookupTraitBase::ReadKeyBase` | U17 |

Sites 29–33 are one decision, not five: the on-disk `DeclarationNameKey`
encoding for a `DeclContext` lookup table, and the stable hash that must
agree with it. `DeclarationNameKey::Data` is a `uint64_t` and the obvious
answer is "the code point, `KeyLen += 4`, `LE.write<uint32_t>`,
`ID.AddInteger`" — but the writer's length, the writer's key, the reader's
key and the hash have to move together or module lookup silently misses,
so it is left whole for U17. Note also
`clang/include/clang/Serialization/ASTBitCodes.h:2188`, where
`DeclarationNameKey::getIdentifier()` asserts on three kinds; a user
operator must not be added there.

**Not** switch sites, but adjacent and worth knowing: `Decl.cpp:4119`
(`if (getDeclName().getNameKind() == …CXXLiteralOperatorName)`),
`SemaExpr.cpp:2643`, `SemaCodeComplete.cpp:1061`,
`clangd/CodeComplete.cpp:896` and
`clangd/refactor/tweaks/RemoveUsingNamespace.cpp:173` all test the kind
with an `if`/`||` rather than a switch, so the compiler will never point
at them. None needed a change for U06; **U08 and U16 should re-read them**,
because they encode "is this name spelled with the `operator` keyword" and
a user operator is.

## What changed

Twenty-one files in `/home/sdowney/src/llvm/unicode`, **+436 / −1**.
Production only (excluding the new test and its CMake line): **19 files,
+249 / −1**.

| File | Lines | Change |
|------|-------|--------|
| `clang/include/clang/Basic/IdentifierTable.h` | 905–915 | `CXXUserOperatorName` inserted before `ObjCMultiArgSelector`, plus the comment stating why nothing may be appended after it |
| `clang/include/clang/AST/DeclarationName.h` | 146–168 | `detail::CXXUserOperatorIdName` |
| " | 225 | `static_assert` alignment entry (now 7) |
| " | 258–260 | `NameKind::CXXUserOperatorName` |
| " | 386–392 | `castAsCXXUserOperatorIdName` |
| " | 560–575 | `getCXXUserOperatorCodePoint()` |
| " | 683–687, 737–743 | `FoldingSet` member + `getCXXUserOperatorName(uint32_t)` |
| " | 771–785, 799, 840, 873 | `DeclarationNameLoc`: `CXXUserOpName` union member, set/get/`makeCXXUserOperatorNameLoc` |
| " | 970–985 | `DeclarationNameInfo::get/setCXXUserOperatorNameLoc` |
| `clang/lib/AST/DeclarationName.cpp` | 9 sites + 402–413 | the switches + `DeclarationNameTable::getCXXUserOperatorName` |
| `clang/include/clang/AST/PropertiesBase.td` | 662–669 | the generated-serializer case |
| 15 other files | 1–16 each | the switch arms tabulated above |
| `clang/unittests/AST/DeclarationNameTest.cpp` | new, 186 | 9 `UserOperatorNameTest` cases |
| `clang/unittests/AST/CMakeLists.txt` | +1 | the new source file |

**In this repo:** `PLAN.md` (U06 ticked, Status row), `REPLAY.md` U06 row,
`DEVIATIONS.md` **DEV-U04**, this handoff.

## Verification evidence

**Build:** `ninja -C /home/sdowney/src/llvm/build-unicode clang AllClangUnitTests`
→ exit 0, 1143 edges (~14 min — an `IdentifierTable.h`/`DeclarationName.h`
edit rebuilds about as much as U03's `TokenKinds.def`), then 16 edges (~1
min) for the follow-up `PropertiesBase.td` edit. **Zero warnings** on the
final build. The first build carried four `-Wswitch` warnings, all from the
generated `AbstractBasic{Reader,Writer}.inc`; the `.td` case removed them.
The two pre-existing `BacktickInfixExprClass` `-Wswitch` warnings in
`ExprEngine.cpp:1688` and `CXCursor.cpp:175` are from the backtick base and
are unchanged.

**Unittest:** `AllClangUnitTests --gtest_filter='UserOperatorNameTest.*'`
→ **9 tests, 9 passed**.

| Test | Asserts |
|------|---------|
| `Uniques` | two `getCXXUserOperatorName(0x229E)` are pointer-identical |
| `DistinctCodePointsAreDistinctNames` | 0x229E ≠ 0x2297 |
| `KindRoundTrips` | kind is `CXXUserOperatorName`, payload survives, and survives `getAsOpaquePtr`/`getFromOpaquePtr` |
| `OtherKindsUnaffected` | **the `ExtraKind` renumbering guard**: 2-keyword selector → `ObjCMultiArgSelector`, `getNumArgs()==2`, `"setFoo:with:"`; 1-keyword → `ObjCOneArgSelector`; using-directive and literal-operator kinds intact; kind-keyed accessors do not cross-claim |
| `Prints` | `getAsString()` and `print()` both give `operator⊞`; `operator⊗` too |
| `IdentityIsTheCodePointNotTheSpelling` | `Lexer::getUserOperatorCodePoint("⊞") == 0x229E`, and the name built from it is the same object as the name built from the literal scalar |
| `Compares` | `compare` orders by code point |
| `FETokenInfo` | set/get round-trips through `set/getFETokenInfoSlow` and is visible from a re-fetched name |
| `NameLoc` | `DeclarationNameInfo` stores and returns the operator location, `getEndLoc()` uses it, other kinds' loc accessors stay silent, `getAsString()` is `operator⊞` |

**Full gate:** `ninja -C $B check-clang` → 54137 discovered / 48243 passed /
27 XFAIL / 5853 unsupported / 6 skipped / **8 failed**, 169 s test time.

All 8 are `DirectoryWatcherTest.*` — the fifth gate fact in `PLAN.md`,
unchanged from U03. Measured at gate time: **65,382 of 65,536**
`fs.inotify.max_user_watches` held machine-wide. Re-run with exactly those
8 excluded:

```bash
ulimit -c 0
GTEST_FILTER='-DirectoryWatcherTest.*' $B/bin/llvm-lit -s $B/tools/clang/test
```
→ `LIT_EXIT=0`, **54129 discovered / 48243 passed / 0 failed** / 27 XFAIL /
5853 unsupported / 6 skipped.

The arithmetic closes exactly: 54129 = U03's 54120 **+9**, and
48243 = 48234 **+9** — the nine new gtest cases and nothing else. No lit
test was added (nothing parses yet), and **no existing test changed
behavior**, which is the claim that matters for a step that renumbers an
enum in a shared header.

## Deviations from the plan / design

**DEV-U04** (`DEVIATIONS.md`): U§8's `DeclarationName` paragraph should
trade its hedge for the measurement — ~250 production lines over 19 files
and 33 switch sites — and should name the real sharp edge, which is not the
pointer bits the step warned about but the fact that `ExtraKind` is packed
against Objective-C's variable-length selector encoding. See the row for
the full recommended wording.

Two scope calls the reviewer will ask about:

1. **`DeclarationNameLoc` was included, though the step did not name it.**
   The switch in `DeclarationNameLoc`'s constructor is exhaustive, so
   *something* had to go there; the minimal answer is `break;` with no
   storage. I gave it the `CXXLitOpName`-shaped `CXXUserOpName` member and
   the full set/get/make/`DeclarationNameInfo` accessors instead, because
   U07 needs somewhere to put the operator token's location and a second
   pass over these headers costs another ~1,150-edge rebuild. It is ~40 of
   the 249 production lines and adds no bytes to `DeclarationNameLoc`
   (single `SourceLocation`, same as the literal-operator member).
2. **Serialization is split, deliberately.** The two `DeclarationNameLoc`
   sites (24, 25) are filled because they are pure `SourceLocation`
   plumbing with no encoding decision and a writer/reader asymmetry there
   would be a live bug; the five `DeclarationNameKey` sites (29–33) are
   deferred whole to U17 because the key encoding and its hash must be
   chosen together. Site 26 (`PropertiesBase.td`) is filled because it is
   six declarative lines, is obviously right, and leaving it out means
   shipping a `-Wswitch` warning in a generated header.

## Discoveries affecting later steps

- **There is a TableGen-generated switch over `DeclarationName::NameKind`.**
  `clang/include/clang/AST/PropertiesBase.td` → `AbstractBasicReader.inc` /
  `AbstractBasicWriter.inc`. `grep` over `*.cpp`/`*.h` will never show it;
  only `-Wswitch` on the generated file does. `LLVM_ENABLE_WERROR` is
  **OFF** in `build-unicode`, so that warning does not fail the build —
  **grep your build log for `warning:` after every step that adds an AST
  enumerator.** The same `.td` also drives `TemplateName`,
  `TemplateArgument` and `APValue`; U16/U17 will meet it again.
- **The unittest target is `AllClangUnitTests`, and there is no per-suite
  target.** `ninja ASTTests` fails with "unknown target"; clang's unittests
  are linked into one binary. Filter with `--gtest_filter=`.
- **`pgrep -f "ninja …"` matches the polling shell itself** and the
  `until ! pgrep -f …` idiom in `PLAN.md` therefore never terminates. Use
  `until ! pgrep -x ninja; do sleep 30; done`. This cost two poll cycles.
- **`getCXXUserOperatorCodePoint()` returns 0 for every other name kind**,
  matching `Lexer::getUserOperatorCodePoint`'s convention. Do not treat 0
  as a valid operator.
- Kind-testing `if`s that a switch-exhaustiveness check cannot find are
  listed at the end of the switch table above. `Decl.cpp:4119` in
  particular decides `NamedDecl::printName`-adjacent behavior for names
  spelled with the `operator` keyword.

## Forward notes for U07 — parse `operator⊞` as an *operator-function-id*

Read `steps/U07-operator-function-id.md`; here is what U06 hands you.

- **The name factory is
  `ASTContext::DeclarationNames.getCXXUserOperatorName(uint32_t)`**
  (`DeclarationName.h:743`, defined `DeclarationName.cpp:402`). Feed it
  `Lexer::getUserOperatorCodePoint(Tok, SourceMgr, LangOpts)`
  (`Lexer.h:398`) — **do not decode the token yourself**; that funnel is
  what makes U04's UCN spellings work for free, and your step's "declare
  with `\N{SQUARED PLUS}`, define with the glyph, get one function"
  acceptance test passes only if you go through it.
- **The location slot already exists.** `UnqualifiedId` in `DeclSpec.h`
  needs your new kind (model on `IK_LiteralOperatorId`), but on the
  `DeclarationNameInfo` side everything is in place:
  `DeclarationNameInfo::setCXXUserOperatorNameLoc(SourceLocation)` /
  `getCXXUserOperatorNameLoc()` (`DeclarationName.h:970–985`) and
  `DeclarationNameLoc::makeCXXUserOperatorNameLoc` (`:873`). Set the
  `operator`-keyword location as `NameInfo`'s `NameLoc` and the operator
  token's location through `setCXXUserOperatorNameLoc` — `getEndLoc()`
  already reads the latter (site 9), so `getSourceRange()` comes out right
  with no further work. Your step item 3 ("make sure the source range is
  right") is therefore about the *parser* setting both, not about adding
  storage.
- **`Sema::GetNameFromUnqualifiedId`** is in `clang/lib/Sema/SemaDecl.cpp`;
  the literal-operator arm is at **`SemaDecl.cpp:6094`**
  (`NameInfo.setName(Context.DeclarationNames.getCXXLiteralOperatorName(…))`
  then `NameInfo.setCXXLiteralOperatorNameLoc(Name.EndLocation)`). Copy
  that two-line shape verbatim. `SemaTemplate.cpp:200` is the parallel
  entry for template-name lookup and will likely want the same arm.
- **Gate the parser hook on `LangOpts.UnicodeOperators`, not on the token
  kind alone** — with the flag off, `tok::user_operator` is never produced
  (U03), but the `ParseUnqualifiedIdOperator` arm should still check, so
  the off-flag diagnostic your step pins stays upstream's.
- **The moment you make such a name declarable you can reach the seven
  deferred `llvm_unreachable`s.** In practice: any `-emit-pch` / module /
  `-fmodules` test, and any codegen test, over a `operator⊞` declaration
  will hit U17's or U09's hole. Keep U07's tests to `-fsyntax-only` and
  `-ast-dump`, exactly as the step's gate list says, and if you need to
  prove a name mangles, note it as blocked on U09 rather than filling
  site 27 in passing.
- **`-ast-dump` will print `operator⊞` already** — site 8 routes
  `DeclarationNameInfo::printName` to `DeclarationName::print`, which is
  filled. So your `-ast-dump` gate should pass with no printing work; if it
  prints `operator` with nothing after it, the code point reaching the name
  was 0, i.e. the lexer funnel was bypassed.
- **Tentative parsing (your step's pitfall):** nothing in U06 touches it.
  `tok::user_operator` is a new token kind, so
  `Parser::isCXXDeclarationSpecifier` and the `TentativeParsing` tables do
  not know it; check `TryParseOperatorId` / `isCXXFunctionDeclarator` and
  say what you found — U10 tests the positions.
- **Do not add `CXXUserOperatorName` to
  `ASTBitCodes.h:2188`'s `getIdentifier()` assert.** It is not identifier-
  keyed.

## Open risks / TODOs

- **The `lldb` arm (site 21) is compile-unverified.**
  `LLVM_ENABLE_PROJECTS` in `build-unicode` is `clang;clang-tools-extra` —
  lldb is not built here. The edit is a one-line addition to an existing
  case group (`ClangASTSource.cpp:125`) and cannot plausibly be wrong, but
  it is the only hunk in this commit no compiler has seen. Noted in the
  `REPLAY.md` row so U20 does not assume it was gated.
- **U17 must re-check every hard-coded name-kind constant**, as U03's
  handoff predicted: `NameKind::ObjCMultiArgSelector` moved 11 → 12 and
  `ExtraKind::ObjCMultiArgSelector` 3 → 4. Self-consistent within a build,
  but any AST file written by a pre-U06 binary and read by a post-U06 one
  would misread selector kinds. Nothing in-tree does that (the AST file
  format version guards it), and the gate is green, but it is exactly the
  class of thing U17 should assert rather than assume.
- **The seven deferred sites are unreachable *only* until U07.** After
  U07 they become live crashes for module/mangling paths. That is the
  intended signal, but it means **U09 and U17 stop being optional the
  moment U07 lands**, and U10's explicit-call sweep (dep: U08, U09) is the
  first step that needs U09 done.
- Nothing here is gated on `LangOpts.UnicodeOperators`, and nothing needs
  to be: no observable behavior changes, because no code path creates a
  `CXXUserOperatorName` until the parser does (U07), and that hook is
  gated. The off-flag guarantee is unchanged and the gate proves it —
  zero test-result deltas beyond the nine new cases.
