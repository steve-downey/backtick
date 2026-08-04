# Handoff — U07 Parse `operator⊞` as an *operator-function-id*

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `35def05cdb7c`
  (parent `9e4042cc2c76`, U06)
- **Date / agent:** 2026-08-04

U06 built the name; U07 makes it reachable from source. It is **8
production files, +89/−5** — small, and small in the way the design
predicts (parse cost < `DeclarationName` cost). Every peer site that
needed the new kind was found by `-Wswitch` except one, and that one is
`Parser::TryParseOperatorId` — the tentative-parsing peer change the step
file told you to check for. **It was needed.** Details below.

## The three answers the step asked for

### 1. `UnqualifiedId` kind: `UnqualifiedIdKind::IK_UserOperatorId`

`clang/include/clang/Sema/DeclSpec.h`:

- the enumerator, inserted **immediately after `IK_LiteralOperatorId`**
  (`DeclSpec.h:1075`). Inserting rather than appending is safe: this enum
  is ephemeral parse state, is never serialized, and no code compares its
  values ordinally — grep for `UnqualifiedIdKind` to confirm before you
  add another.
- a `uint32_t UserOperatorCodePoint;` member in the anonymous payload
  union (`DeclSpec.h:1129`). **Not an `IdentifierInfo *`** — same reason
  as U06: the scalar *is* the identity, and routing through it is what
  makes U04's UCN spellings work with no further code.
- `setUserOperatorId(uint32_t CodePoint, SourceLocation OpLoc,
  SourceLocation OpTokLoc)` (`DeclSpec.h:1245`), shaped on
  `setLiteralOperatorId`: `StartLocation = OpLoc` (the `operator`
  keyword), `EndLocation = OpTokLoc` (the operator token).

### 2. Parser hook: one arm in `ParseUnqualifiedIdOperator`

`clang/lib/Parse/ParseExprCXX.cpp`, **between the `if (Op != OO_None)`
block and the literal-operator-id parse** (line 2519). Verbatim:

```cpp
  if (getLangOpts().UnicodeOperators && Tok.is(tok::user_operator)) {
    uint32_t CodePoint = Lexer::getUserOperatorCodePoint(
        Tok, PP.getSourceManager(), getLangOpts());
    SourceLocation OpTokLoc = ConsumeToken();
    Result.setUserOperatorId(CodePoint, KeywordLoc, OpTokLoc);
    return false;
  }
```

`clang/Lex/Lexer.h` had to be added to the file's includes. The arm is
gated on `LangOpts.UnicodeOperators` as well as the token kind, per U06's
forward note, so the off-flag diagnostic stays upstream's by construction.

**Only one hook was needed for all the declaring positions.** Every
position the step names — free function, definition, member, `friend`,
qualified `int N::operator⊞(S, S)`, template, explicit specialization,
explicit instantiation, `= delete`, `constexpr`, address-of, explicit
call, using-declaration — funnels through `ParseUnqualifiedIdOperator`
via `ParseUnqualifiedId`, which is reached from `ParseDirectDeclarator`
(`ParseDecl.cpp:6782`, already lists `tok::kw_operator`) and from
`ParseCastExpression` (`ParseExpr.cpp:1521`). Neither needed a change.

### 3. `Sema::GetNameFromUnqualifiedId` — `SemaDecl.cpp:6099`

The arm, immediately after the literal-operator one:

```cpp
  case UnqualifiedIdKind::IK_UserOperatorId:
    NameInfo.setName(Context.DeclarationNames.getCXXUserOperatorName(
        Name.UserOperatorCodePoint));
    NameInfo.setCXXUserOperatorNameLoc(Name.EndLocation);
    return NameInfo;
```

`NameInfo.setLoc(Name.StartLocation)` at the top of the function already
put the `operator` keyword in `NameLoc`. **The source range is therefore
correct with no further work** — U06 filled
`DeclarationNameInfo::getEndLocPrivate` (its site 9) to read
`getCXXUserOperatorNameLoc()`, so `getSourceRange()` spans
`operator`…`⊞`. Measured, not assumed: in
`static_assert(operator⊞(2, 3) == 5);` the AST dump prints
`DeclRefExpr <col:15, col:23>` — col 15 is the `o` of `operator`, col 23
the `⊞` — and that exact string is a `CHECK:` line in the lit test, so
U16 cannot silently break it. The `-verify` caret for an undeclared use
underlines the whole name: `^~~~~~~~`.

## The nine peer sites

None of these are in the step file; all but the last were found by
`-Wswitch` on an exhaustive switch (the build is **warning-clean**, which
is the evidence that the list is complete for switches).

| # | File:line | Function | What it does now |
|---|-----------|----------|------------------|
| 1 | `ParseExprCXX.cpp:297` | `ParseOptionalCXXScopeSpecifier`, the `A::template operator…` check | accepts the new kind alongside operator- and literal-operator-ids |
| 2 | `ParseExprCXX.cpp:2265` | `ParseUnqualifiedIdTemplateId`, the `Id.getKind()` switch | grouped with `IK_Identifier`/`IK_OperatorFunctionId`/`IK_LiteralOperatorId`, so `operator⊞<T>` resolves as a template name |
| 3 | `ParseExprCXX.cpp:2297` | the `err_missing_dependent_template_keyword` diagnostic name-building | **had to be fixed, not just extended** — see below |
| 4 | `ParseExprCXX.cpp:2372–2392` | the `TemplateIdAnnotation` construction | new kind accepted; `TemplateII = nullptr`, `OpKind = OO_None` |
| 5 | `ParseExprCXX.cpp:2824` | `ParseUnqualifiedId`, the `<`-lookahead after an operator id | so `operator⊠<char>('a','b')` forms a template-id |
| 6 | `SemaTemplate.cpp:203` | `Sema::isTemplateName` | `getCXXUserOperatorName(Name.UserOperatorCodePoint)` |
| 7 | `SemaDecl.cpp:15684` | `CheckFunctionOrTemplateParamDeclarator` | grouped into `err_bad_parameter_name` |
| 8 | `SemaType.cpp:3191` | `GetDeclSpecTypeForDeclarator` | grouped with the kinds that *have* a return type |
| 9 | `SemaDeclCXX.cpp:12760`, `:18557` | `ActOnUsingDeclaration`, the friend-at-non-record check | grouped with the ordinary/operator kinds (`break`) |

Plus one non-switch `if`, from U06's "invisible sites" list:
**`SemaExpr.cpp:2644`** (`Sema::DiagnoseEmptyLookup`) now selects
`err_undeclared_use` rather than `err_undeclared_var_use`, so an
undeclared explicit call reads
`error: use of undeclared 'operator⊞'` instead of
`use of undeclared identifier`. U10 will want that wording.

**Site 3 is a latent upstream bug you must not copy.** The name-building
code read `Id.OperatorFunctionId.Operator` for *any* non-identifier kind
— including `IK_LiteralOperatorId`, whose active union member is
`Identifier`. For a `uint32_t` payload the mirror of that
(`Id.Identifier->getName()` on a code point) is a null-ish pointer
dereference. It is now kind-checked for the new kind and routes through
`Actions.GetNameFromUnqualifiedId(Id).getName().getAsString()`, which
re-encodes the code point. The literal-operator read was left exactly as
upstream has it — changing it is not this step's business, but **anything
that adds a union member to `UnqualifiedId` must audit
`ParseExprCXX.cpp:2294–2313` and `:2372–2392`.**

## Tentative parsing — the pitfall, and it fired

`Parser::TryParseOperatorId` (`ParseTentative.cpp:810`) handles
`operator new/delete`, the `OperatorKinds.def` punctuators, `()`, `[]`,
a literal-operator-id, **and otherwise assumes a conversion-type-id
follows**: it loops on `isCXXDeclarationSpecifier`, and with no
decl-specifier found returns `TPResult::Error`. A `tok::user_operator`
took exactly that path, so an ambiguous statement whose declarator-id is
a user operator was declared an error and re-parsed as an expression.

Fix, `ParseTentative.cpp:831`, before `case tok::l_square:`:

```cpp
  case tok::user_operator:
    if (getLangOpts().UnicodeOperators) {
      ConsumeToken();
      return TPResult::True;
    }
    break;
```

Reproducer, now in the lit test:

```cpp
struct S {};
void tentative() {
  S operator⊛(S, S);      // statement starts with a type-name → tentative parse
  S (operator⊝)(S, S);
}
```

Both are `FunctionDecl`s in the AST dump. `int operator⊗(A, A);` at block
scope does **not** exercise it (a statement starting with `int` is a
declaration without a trial parse), so a test that uses only fundamental
types will pass either way — use a class type.

The backtick track needed a peer change in the *same file* at its S08 for
an unrelated reason. Two for two; recorded as part of **DEV-U05** with the
recommendation that the paper carry it as a portable implementation note,
since GCC's `cp_parser_*` tentative machinery will face the same question.

`ParseTentative.cpp:2045` (`explicit(operator…`) already returns
`TPResult::Ambiguous` for `tok::kw_operator` and needs nothing.

## What changed

Eight production files, **+89 / −5**, plus one new lit test (81 lines).

| File | Lines | Change |
|------|-------|--------|
| `clang/include/clang/Sema/DeclSpec.h` | 1075, 1125–1129, 1245–1253 | the kind, the union member, `setUserOperatorId` |
| `clang/lib/Parse/ParseExprCXX.cpp` | +1 include, 297, 2265, 2297, 2375–2392, 2515–2525, 2824 | the hook + five template-id peer sites |
| `clang/lib/Parse/ParseTentative.cpp` | 831–839 | `TryParseOperatorId` |
| `clang/lib/Sema/SemaDecl.cpp` | 6099–6107, 15684 | `GetNameFromUnqualifiedId`, param-declarator check |
| `clang/lib/Sema/SemaTemplate.cpp` | 203–207 | `Sema::isTemplateName` |
| `clang/lib/Sema/SemaType.cpp` | 3191 | `GetDeclSpecTypeForDeclarator` |
| `clang/lib/Sema/SemaDeclCXX.cpp` | 12760, 18557 | using-declaration, friend |
| `clang/lib/Sema/SemaExpr.cpp` | 2644 | undeclared-use diagnostic selection |
| `clang/test/Parser/unicode-operator-decl.cpp` | new, 81 | 4 RUN lines |

**In this repo:** `PLAN.md` (U07 ticked, Status row), `REPLAY.md` U07 row,
`DEVIATIONS.md` **DEV-U05**, this handoff.

## Verification evidence

**Build:** `ninja -C /home/sdowney/src/llvm/build-unicode clang` →
`EXIT=0`, **169 edges**, ~4 min. **Zero `warning:` lines** — which is the
proof that no exhaustive switch over `UnqualifiedIdKind` was missed.
(`LLVM_ENABLE_WERROR` is OFF here, so grep the log; do not trust exit 0.)

**Lit:** `Parser/unicode-operator-decl.cpp` → PASS, all four RUN lines:

1. `-std=c++20 -funicode-operators -fsyntax-only -verify` —
   `expected-no-diagnostics` over free declaration+definition, address-of,
   explicit call, four member forms, `friend`, out-of-line member
   definition, qualified `int N::operator⊞(S, S)`, function template,
   explicit specialization, explicit instantiation, template-id call,
   using-declaration, tentative-parse block, `constexpr`+`noexcept`,
   `= delete` at namespace and class scope.
2. the same with **`-fbacktick` also on** — the U7 composability ground
   rule, and it costs one RUN line.
3. `-ast-dump | FileCheck` — five `CHECK:` lines including the
   source-range pin `DeclRefExpr {{.*}} <col:15, col:23> {{.*}}
   'operator⊞' 'int (int, int)'`.
4. flag **off**, `-verify=off` — one diagnostic,
   `error: character '⊞' U+229E not allowed in an identifier`, i.e.
   upstream's identifier-recovery path unchanged (U03's "adjacent" form;
   `operator` and `⊞` are adjacent, so the recovery absorbs the character
   into one identifier `operator⊞`).

The acceptance test for spelling-independent identity, as far as it can
be run today: `constexpr int operator⊞(int, int);` then
`constexpr int operator⊞(int a, int b) { return a + b; }` then
`static_assert(operator⊞(2, 3) == 5);`. That constant-evaluates only if
the two occurrences produced the *same* `DeclarationName` and merged into
one redeclaration chain — the AST dump confirms
`FunctionDecl … prev 0x…` and a single `Function` referenced from all
three uses.

**Full gate:** `ninja -C $B check-clang` → 54138 discovered / 48244
passed / 27 XFAIL / 5853 unsupported / 6 skipped / **8 failed**, 208 s
test time.

All 8 are `DirectoryWatcherTest.*` with
`No space left on device : inotify_add_watch()` — `PLAN.md`'s fifth gate
fact, measured again at gate time: **65,382 of 65,536**
`fs.inotify.max_user_watches` held machine-wide. Filtered re-run:

```bash
ulimit -c 0
GTEST_FILTER='-DirectoryWatcherTest.*' $B/bin/llvm-lit -s $B/tools/clang/test
```
→ `EXIT=0`, **54130 discovered / 48244 passed / 0 failed** / 27 XFAIL /
5853 unsupported / 6 skipped; zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines.

Arithmetic closes exactly: 54130 = U06's 54129 **+1**, 48244 = 48243
**+1** — the one new lit test and nothing else. **No existing test
changed behavior**, which is the claim that matters for a step that adds
an enumerator to a parser enum and touches six Sema files.

## Deviations from the plan / design

**DEV-U05** (`DEVIATIONS.md`): U§8's Clang *Parser* bullet describes only
expression parsing; the declaring side — where the feature actually
becomes a name — is unmeasured in the design and is now measured (8
files, +89/−5, one new `UnqualifiedId` kind, 9 peer sites). The row also
carries the tentative-parsing finding and the `TemplateIdAnnotation`
limitation, with recommended wording. It *supports* U§6's "parsing is the
easy part" rather than undercutting it.

Two scope calls a reviewer will ask about:

1. **Template-id support was included, though the step file says only
   "template; explicit specialization".** `template<> int operator⊠(int,
   int b)` needs no template-id (deduction handles it), but
   `operator⊠<char>('a','b')` does, and refusing it would have left five
   peer sites reachable-but-wrong rather than merely absent. Two of the
   five (`ParseExprCXX.cpp:2265`, `SemaTemplate.cpp:203`) are load-bearing;
   the other three are the diagnostic/annotation plumbing around them.
2. **`SemaCodeComplete.cpp:1061` was left alone.** It is a
   completion-*priority* `if` grouping `CXXOperatorName` /
   `CXXLiteralOperatorName` / `CXXConversionFunctionName` as "unlikely";
   a user operator arguably belongs there, but it changes no behavior a
   test can see and U06's list already flags it for U16. One line, when
   someone is in that file anyway.

## Discoveries affecting later steps

- **`FunctionDecl::isOverloadedOperator()` is `false` for a user
  operator**, because it is `getOverloadedOperator() != OO_None` and
  `Decl.cpp:4110` only answers for `CXXOperatorName`. Two live
  consequences: `Sema::CheckOverloadedOperatorDeclaration` **does not
  run** (which is why every arity parses today — U08's job), and
  `SemaDecl.cpp:10959`'s `PrincipalDecl->setNonMemberOperator()` **does
  not run**, so a namespace-scope `operator⊞` is *not* in
  `Decl::IDNS_NonMemberOperator`. `SemaLookup.cpp:238`
  (`LookupOperatorName`) looks in exactly that namespace. **U13 will find
  no candidates until someone sets it.** See the U08 notes.
- **There is no `FunctionDecl` predicate for "is this a user operator".**
  The natural place is beside `FunctionDecl::getLiteralIdentifier()`
  (`Decl.cpp:4118`), as
  `uint32_t FunctionDecl::getUserOperatorCodePoint() const` returning
  `getDeclName().getCXXUserOperatorCodePoint()` — which U06 already
  defined to return `0` for every other kind. U08 should add it; U09,
  U11 and U13 all want it.
- **`-ast-dump` prints `operator⊞` with no printing work**, exactly as
  U06 predicted. If you ever see `operator` with nothing after it, the
  code point reaching the name was 0, i.e. something bypassed
  `Lexer::getUserOperatorCodePoint`.
- **`operator⊞` as a *dependent* template name is diagnosed, not
  supported.** `T::template operator⊞<int>` gives
  `error: 'operator⊞' following the 'template' keyword cannot refer to a
  dependent template`, because `SemaTemplate.cpp:5162`'s switch has a
  `default:` and `DependentTemplateStorage` is keyed by `IdentifierInfo *`
  or `OverloadedOperatorKind`. Identical to the literal-operator case, so
  it is upstream's shape, not a regression — but if the paper ever claims
  "everywhere an operator-function-id may appear", this is the one corner
  where that is false. Fixing it means widening
  `DependentTemplateStorage`; nobody has needed to.
- The incremental build cost of this step's headers is **169 edges,
  ~4 min** — `DeclSpec.h` is Sema/Parse-internal and far cheaper than
  U03's `TokenKinds.def` (1142) or U06's `DeclarationName.h` (1143).

## Forward notes for U08 — Sema declaration rules and arity

- **Nothing rejects anything today.** `CheckOverloadedOperatorDeclaration`
  is called from `SemaDecl.cpp:12597` under `NewFD->isOverloadedOperator()`,
  which is false for you. So `int operator⊞();`,
  `int operator⊞(int,int,int);` and a two-parameter member all currently
  compile clean. That is deliberate (U07's scope discipline) and it is
  your entire starting point.
- **Do not route through `CheckOverloadedOperatorDeclaration`.** Its
  first line is `assert(FnDecl->isOverloadedOperator())` and its body is a
  `switch (Op)` over `OverloadedOperatorKind` — there is no `Op` for you.
  Add a sibling (`CheckUserOperatorDeclaration`) and a second `if` at
  `SemaDecl.cpp:12597`, on the new predicate. That also makes the step's
  "prove `int operator+(int,int)` still errors" gate trivially true: you
  never touched the shared checker. The class-or-enum check lives inside
  `CheckOverloadedOperatorDeclaration` at the `Op`-switch level
  (`SemaDeclCXX.cpp:16978`ff), so **it is not reachable from your path at
  all** — U2's relaxation is free. Say so in a comment anyway; the step
  asks for a deliberate branch, not an accident, and the paper will quote
  it.
- **Add the predicate first** (see Discoveries):
  `FunctionDecl::getUserOperatorCodePoint()` next to `getLiteralIdentifier()`
  at `Decl.cpp:4118`. U11/U13 will ask you for it, and "is this a user
  operator, and of which arity" is then
  `getUserOperatorCodePoint() != 0` plus `getNumParams()` +
  `isImplicitObjectMemberFunction()`.
- **Please fix `setNonMemberOperator` while you are in `SemaDecl.cpp`,
  or say loudly that you did not.** `SemaDecl.cpp:10959` reads
  `if (NewFD->isOverloadedOperator() && !DC->isRecord() && …)
  PrincipalDecl->setNonMemberOperator();`. Without the user-operator kind
  in that condition, namespace-scope user operators never get
  `IDNS_NonMemberOperator`, and `Sema::LookupOperatorName`
  (`SemaLookup.cpp:238`, `IDNS = Decl::IDNS_NonMemberOperator`) — the
  lookup U13's candidate assembly and ADL go through — will not see them.
  It is one condition, it belongs with the arity work, and if U13
  discovers it instead it will look like an ADL bug (cf. GCC's DEV-G05,
  which is precisely this class of mistake caught late).
- The `-verify` test the step wants is
  `clang/test/SemaCXX/unicode-operator-decl.cpp`; keep
  `clang/test/Parser/unicode-operator-decl.cpp` as-is. Note that the
  Parser test currently **declares deliberately wrong arities on purpose**
  (`int operator⊗() const;` as a member, i.e. a member prefix form; and a
  `S operator⊟(S) const`), so once your checker lands, re-run that file:
  if any of those become errors under your rules you must adjust the
  Parser test, and the fact that you had to is worth a sentence.
- Glyphs already used, so you can pick fresh ones: ⊞ U+229E, ⊗ U+2297,
  ⊟ U+229F, ⊕ U+2295, ⊠ U+22A0, ⊘ U+2298, ⊚ U+229A, ⊛ U+229B, ⊝ U+229D.
  All inside U1's `{0x2266, 0x22C4}` range.

## Forward notes for U09 — Itanium mangling

- **Where the code point lives on a parsed declaration — the exact
  chain.** `FunctionDecl *FD` → `FD->getDeclName()` →
  `DeclarationName::getCXXUserOperatorCodePoint()`
  (`DeclarationName.h:560`), returning the `uint32_t` and **`0` for every
  other name kind**. Inside the mangler you do not even need the decl:
  `CXXNameMangler::mangleOperatorName(DeclarationName Name, unsigned Arity)`
  receives the `DeclarationName` directly, so it is
  `Name.getCXXUserOperatorCodePoint()`. Nothing is stored on the
  `FunctionDecl` itself and nothing needs to be — U03's decision (identity
  is derived, not carried) survives all the way here.
- **Your hole is `ItaniumMangle.cpp:2662`**, the
  `llvm_unreachable("U09: Unicode user operator mangling not
  implemented")` in `mangleOperatorName(DeclarationName, unsigned)`.
  U06 already funnelled the other two Itanium sites (`:1447`
  `mangleUnresolvedName`, `:1711` `mangleUnqualifiedName`) into it, so
  this is genuinely the single place.
- **The `Arity` you are handed is wrong for you, and this is the step's
  stated pitfall in its concrete form.** At `ItaniumMangle.cpp:1698`,
  `case DeclarationName::CXXOperatorName:` computes
  `Arity = FD->getNumParams()` and adds 1 for an implicit object member
  function, then `[[fallthrough]]`s into the group
  `CXXConversionFunctionName | CXXLiteralOperatorName |
  CXXUserOperatorName` that calls `mangleOperatorName(Name, Arity)`.
  **A `CXXUserOperatorName` entering the switch directly skips that
  computation** and arrives with whatever the caller passed — commonly
  `UnknownArity`. Hoist the arity block above the fallthrough (guard it on
  the two operator kinds) or duplicate it; either way, **test the member
  infix case specifically**: one declared parameter, arity 2.
- **Copy `li` for the length prefix.** `ItaniumMangle.cpp:2653` is
  `case CXXLiteralOperatorName: Out << "li";
  mangleSourceName(Name.getCXXLiteralIdentifier()); return;` — note
  `return`, not `break`, and note it hands `mangleSourceName` an
  `IdentifierInfo *`. You have a `uint32_t`, so you want the
  `mangleSourceName(StringRef)` overload (or `Out << Name.size() << Name`)
  over a `SmallString` you format yourself. Format the hex **from the code
  point**, never from a spelling.
- **MSVC is already stubbed, at `MicrosoftMangle.cpp:1365`**, with
  `llvm_unreachable("U09: … MSVC mangling not implemented")`. The step
  asks for a clean diagnostic instead of a crash; the neighbouring
  literal-operator arm at `:1359` shows the house style for "MSVC cannot
  mangle this".
- **Your tests will be the first codegen tests on this branch.** Keep in
  mind U07 deliberately stayed on `-fsyntax-only`/`-ast-dump` so as not to
  reach your hole; the moment you emit IR you also make the *five* U17
  `DeclarationNameKey` holes reachable from any `-emit-pch`/`-fmodules`
  test. Stay on `-emit-llvm`.
- **The step's "all three spellings produce the same symbol" gate cannot
  be run yet** — U04 has not landed, so `⊞` and `\N{SQUARED PLUS}`
  do not lex as operator tokens. Test the glyph, assert in the handoff
  that the derivation is from the scalar (it is: you never see a
  spelling), and leave the three-spelling FileCheck for U04's agent or a
  follow-up. Do not implement U04's lexer work to make it testable.
- **On the D137051 disjointness gate:** the math-identifier extension is
  in this build (U02 measured
  `MathematicalNotationProfileIDStartRanges` in
  `clang/lib/Lex/UnicodeCharSets.h` and proved U1 disjoint from it), so
  `int ∂(int);` mangling as an ordinary `<source-name>` is testable
  without new machinery. Check which `-std=`/`LangOpts` enables it before
  writing the RUN line — `isAllowedIDChar`'s `IsExtension` out-parameter
  and `diagnoseMathematicalNotationInIdentifier` (`Lexer.cpp:1897`) are
  where it is decided.

## Open risks / TODOs

- **`setNonMemberOperator` is not set for user operators** (see the U08
  notes). It is the one known-wrong thing this step leaves behind, and it
  is invisible until U13 assembles candidates. Assigned to U08 in writing
  rather than left to be rediscovered.
- **`TemplateIdAnnotation` carries no code point** for `operator⊞<T>`
  (`TemplateII = nullptr`, `OpKind = OO_None`), the same gap upstream has
  for literal operators. Resolution goes through the `TemplateName`, so
  nothing is wrong today; **U16 should check what `-ast-print` does with
  a user-operator template-id** before assuming it round-trips.
- **The dependent-template corner** (`T::template operator⊞<int>`) is
  diagnosed rather than supported — see Discoveries. Deliberate; matches
  the literal-operator precedent.
- **`ParseExprCXX.cpp:2294–2313` and `:2372–2392` read a union member
  chosen by kind** and upstream gets it wrong for `IK_LiteralOperatorId`.
  U07 did not fix upstream's read, only guarded the new kind. Anyone
  adding a further `UnqualifiedId` payload must look there first.
- The one thing U07 could not test is the acceptance criterion the step
  file states in full: **declare with `\N{SQUARED PLUS}`, define with the
  glyph, get one function.** The identity path is scalar-based end to end
  (`Lexer::getUserOperatorCodePoint` → `UserOperatorCodePoint` →
  `getCXXUserOperatorName`), and U06's
  `UserOperatorNameTest.IdentityIsTheCodePointNotTheSpelling` proves the
  bottom half. **U04's agent: add exactly this to
  `clang/test/Parser/unicode-operator-decl.cpp`, next to the existing
  `static_assert(operator⊞(2, 3) == 5);`** —
  `constexpr int operator\N{SQUARED PLUS}(int, int);` as the declaration,
  the glyph on the definition, static_assert unchanged. If it fails,
  the bug is in the lexer's canonicalization, not here.
