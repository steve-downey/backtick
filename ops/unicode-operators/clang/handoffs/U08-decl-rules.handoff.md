# Handoff — U08 Sema declaration rules and arity

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `07901af9f62d`
  (parent `35def05cdb7c`, U07)
- **Date / agent:** 2026-08-04

U07 made `operator⊞` a name; U08 decides which declarations of it are
well-formed. **6 production files, +115/−1** — smaller than U07's parse
work (+89/−5 over 8 files) and far smaller than U06's `DeclarationName`
work (+249 over 19), which is the cost ordering U§6 predicts.

The step also carried a defect U07 assigned in writing. It is fixed and
pinned by a test that provably fails without the fix; details in
"The IDNS_NonMemberOperator defect" below.

## The three answers the step asked for

### 1. The checker: `Sema::CheckUserOperatorDeclaration`, a *sibling*

`clang/lib/Sema/SemaDeclCXX.cpp`, inserted between
`CheckOverloadedOperatorDeclaration` and
`checkLiteralOperatorTemplateParameterList`; declared in
`clang/include/clang/Sema/Sema.h` immediately after
`CheckOverloadedOperatorDeclaration`.

**`CheckOverloadedOperatorDeclaration` was not extended, refactored, or
entered.** Its first line is `assert(FnDecl->isOverloadedOperator())` and
its body is driven by an `OverloadedOperatorKind` that a user operator
does not have — U07's forward note was right that routing through it is a
dead end. The new function shares no code with it. That is what makes the
step's hard constraint ("no existing operator's rules may move")
structural rather than merely tested: the shared checker's diff is
literally empty.

Call site, `clang/lib/Sema/SemaDecl.cpp`, a second `if` immediately before
the literal-operator one (upstream line 12615, now 12617):

```cpp
    if (NewFD->isUserOperator() && CheckUserOperatorDeclaration(NewFD)) {
      NewFD->setInvalidDecl();
      return Redeclaration;
    }
```

The rules, in the order they are checked:

| Case | Rule | Diagnostic |
|------|------|------------|
| static member | rejected — no implicit object parameter, so it can name neither form | existing `err_operator_overload_static` |
| operand count ≠ 1 and ≠ 2 | rejected | new `err_user_operator_must_be` |
| everything else | accepted | — |

"Operand count" is `getNumParams()` plus 1 if the function
`isImplicitObjectMemberFunction()`. That single formula gives all four
rules at once: free 1/2 params, implicit-object member 0/1 declared, and
— for free — the C++23 explicit-object member, where the object parameter
*is* a declared parameter so `int operator⊙(this S, S)` counts 2 and is
correctly the infix form.

`err_user_operator_must_be` (new, `DiagnosticSemaKinds.td`, after
`err_operator_overload_post_incdec_must_be_int`):

```
"user-defined operator %0 must have "
"%select{one parameter (prefix) or two parameters (infix)|"
"no parameters (prefix) or one parameter (infix)}1 "
"(has %2 parameter%s2)"
```

`%1` selects on "has an implicit object parameter", `%2` is the
**declared** parameter count (what the user wrote), so both wordings name
the two legal arities *for the form the user is actually writing*.

### 2. The class-or-enum bypass: scoped structurally, and commented

The step asked for a deliberate branch, not an accident. It is neither a
branch nor an accident — it is **unreachable by construction**, and the
comment says so and says why. Verbatim from `SemaDeclCXX.cpp`:

```cpp
  // U2: the [over.oper]p7 "at least one parameter whose type is a class, a
  // reference to a class, an enumeration, or a reference to an enumeration"
  // requirement is DELIBERATELY NOT APPLIED to user-defined operators, and
  // this comment is the whole of the mechanism.
  //
  // That rule exists to protect the built-in meaning of an existing operator
  // token: `int operator+(int, int)` would otherwise redefine `1 + 1`. A user
  // operator has no built-in meaning to protect and no built-in candidates
  // (U6), so `constexpr int operator⊞(int a, int b) { return a + b; }` is
  // legal and `5 ⊞ 7` finding it is the motivating case of the feature.
  //
  // The scoping is structural rather than conditional: the check lives inside
  // CheckOverloadedOperatorDeclaration, keyed off an OverloadedOperatorKind
  // that no user operator has, and is unreachable from here. Every existing
  // operator keeps it, unchanged and untouched.
```

The paper can quote that as-is. The argument it makes — *the restriction
protects a fixed token, so a name with no fixed meaning does not inherit
it* — generalizes, and DEV-U06 records that it generalizes to **four** of
[over.oper]'s five restrictions, not just this one (see Deviations).

### 3. The predicate U11 and U13 asked for

`clang/include/clang/AST/Decl.h`, immediately after
`FunctionDecl::getLiteralIdentifier()`; definition in
`clang/lib/AST/Decl.cpp` next to that function's:

```cpp
  uint32_t getUserOperatorCodePoint() const;   // 0 == not a user operator
  bool isUserOperator() const { return getUserOperatorCodePoint() != 0; }
```

`getUserOperatorCodePoint()` is one line —
`return getDeclName().getCXXUserOperatorCodePoint();` — because U06
already defined that accessor to return 0 for every other name kind.

**"Is this a user operator, and of which arity" in full:**

```cpp
  if (!FD->isUserOperator()) return;                       // not one
  uint32_t CP = FD->getUserOperatorCodePoint();            // which operator
  const auto *MD = dyn_cast<CXXMethodDecl>(FD);
  unsigned Operands = FD->getNumParams() +
      (MD && MD->isImplicitObjectMemberFunction() ? 1 : 0);
  //  Operands == 1 -> prefix, Operands == 2 -> infix.  Nothing else exists:
  //  U08 guarantees every valid FunctionDecl with a user-operator name has
  //  Operands in {1, 2} and is not static.
```

Note `isImplicitObjectMemberFunction()` is on **`CXXMethodDecl`**, not
`FunctionDecl` (`DeclCXX.h:2183`), hence the `dyn_cast`. Deliberately
*not* folded into `isOverloadedOperator()`: that predicate answers "which
`OverloadedOperatorKind`", and every site that must treat the two alike
now has to say so out loud. There are exactly two such sites today
(the checker call and `setNonMemberOperator`), and the header comment on
`isUserOperator()` names them.

## The IDNS_NonMemberOperator defect — fixed and pinned

`clang/lib/Sema/SemaDecl.cpp` in `ActOnFunctionDeclarator`, one condition:

```cpp
    if ((NewFD->isOverloadedOperator() || NewFD->isUserOperator()) &&
        !DC->isRecord() &&
        PrincipalDecl->isInIdentifierNamespace(Decl::IDNS_Ordinary))
      PrincipalDecl->setNonMemberOperator();
```

**Tested, not asserted:** new gtest
`clang/unittests/Sema/UserOperatorDeclTest.cpp`, one case
`UserOperatorDeclTest.NamespaceScopeOperatorIsVisibleToOperatorLookup`,
added to the `SemaTests` target (`clang/unittests/Sema/CMakeLists.txt`).
It parses `int operator⊞(int, int);` under
`-std=c++20 -funicode-operators` through a real `ASTFrontendAction`
(`CI.createSema` + `ParseAST`, the `SemaLookupTest.cpp` pattern) and then
checks **both ends** of the defect:

1. the cause — `FD->isInIdentifierNamespace(Decl::IDNS_NonMemberOperator)`;
2. the consequence — a `LookupResult` with `Sema::LookupOperatorName` and
   the `getCXXUserOperatorName(0x229E)` name, resolved by
   `LookupQualifiedName` against the TU, is **not** empty.

**Verified to catch the regression.** With the fix reverted to
`(NewFD->isOverloadedOperator() || false)` and only `SemaTests` rebuilt,
*both* assertions fail:

```
Value of: FD->isInIdentifierNamespace(Decl::IDNS_NonMemberOperator)
  Actual: false / Expected: true
Value of: R.empty()
  Actual: true  / Expected: false
    Sema::LookupOperatorName found no candidate for operator⊞
```

That is the whole point of testing the cause: without it the symptom
would first appear at U13 as a missing overload candidate at a *use*
site, several steps from the edit that caused it — which is GCC's DEV-G05
failure mode exactly (`ops/gcc/DEVIATIONS.md`). Running the check before
any infix syntax exists is what breaks that pattern.

Why a unit test rather than a lit test: `IDNS_NonMemberOperator` has
exactly one consumer in the whole tree
(`SemaLookup.cpp:238`, `Sema::LookupOperatorName`), nothing calls that
for user operators until U13, and no `-ast-dump` output carries the
identifier namespace. There is no lit-visible observable to write today.

## What changed

Six production files, **+115 / −1**, plus two new tests.

| File | Change |
|------|--------|
| `clang/include/clang/AST/Decl.h` | +19: `getUserOperatorCodePoint()` decl, `isUserOperator()` inline, after `getLiteralIdentifier()` |
| `clang/lib/AST/Decl.cpp` | +6: the definition |
| `clang/include/clang/Basic/DiagnosticSemaKinds.td` | +8: `err_user_operator_must_be` |
| `clang/include/clang/Sema/Sema.h` | +10: `CheckUserOperatorDeclaration` declaration |
| `clang/lib/Sema/SemaDeclCXX.cpp` | +54: `Sema::CheckUserOperatorDeclaration` |
| `clang/lib/Sema/SemaDecl.cpp` | +19/−1: the `setNonMemberOperator` condition + the checker call |
| `clang/test/SemaCXX/unicode-operator-decl.cpp` | new, 109 lines, 2 RUN lines |
| `clang/unittests/Sema/UserOperatorDeclTest.cpp` (+ 1 CMake line) | new, 98 lines |

`clang/test/Parser/unicode-operator-decl.cpp` **needed no change** — every
arity U07 wrote there is legal under these rules, including the two the
U07 handoff flagged as "deliberately wrong": `int operator⊗() const;` is a
member *prefix* form (0 declared + implicit object = 1) and
`S operator⊟(S) const` a member *infix* form (1 + 1 = 2). Both were
correct all along; the handoff's caution was the right instinct on the
wrong two lines.

**In this repo:** `PLAN.md` (U08 ticked, Status row), `REPLAY.md` U08 row
(`upstream replay`), `DEVIATIONS.md` **DEV-U06** and **DEV-U07**, this
handoff.

## Verification evidence

**Build:** `ninja -C /home/sdowney/src/llvm/build-unicode clang SemaTests`
→ `EXIT=0`, 1002 edges. Exactly **one** `warning:` line, and it is not
ours: `-Wswitch` on `BacktickInfixExprClass` in
`clang/lib/StaticAnalyzer/Core/ExprEngine.cpp:1688`, a pre-existing gap in
the backtick-track base. It surfaced now only because touching `Decl.h`
rebuilt `ExprEngine.cpp` for the first time on this branch — U07 reported
"zero warnings" from a build that did not recompile that file. **No
unicode-track file produces a warning**, which is still the evidence that
no exhaustive switch was missed.

**Targeted lit:** `SemaCXX/unicode-operator-decl.cpp`,
`Parser/unicode-operator-decl.cpp`, `Lexer/unicode-operators.cpp`,
`Driver/funicode-operators.c` → **4/4 pass**, first run, 0.06 s.

The new `-verify` test has two RUN lines (`-std=c++23
-funicode-operators`, then the same **plus `-fbacktick`** — the U7
composability ground rule) and covers:

- *accepted:* `constexpr int operator⊞(int a, int b)` with
  `static_assert(operator⊞(5, 7) == 12)` (U2's motivating case, no class
  or enum in sight); free prefix and free infix; member infix and member
  prefix; explicit-object member infix and prefix; a function template,
  its explicit specialization, and a prefix overload of it; `consteval`;
  `= delete`; **a variadic** `int operator⊝(int, ...)`; **a default
  argument** `int operator⊟(int a, int b = 1)`; and
  `int operator⊟(Vec, int)` as the "there is no postfix form to detect"
  case;
- *rejected:* free 0 params, free 3 params, free 4 params in a namespace,
  a member with 2 declared params, a `static` member, and a template with
  0 params — each with the exact message text pinned;
- *control:* `int operator+(int, int)` still gets
  "must have at least one parameter of class or enumeration type";
  `P operator*(P, P, P)` still gets "must be a unary or binary operator
  (has 3 parameters)"; `P operator&(P, P, ...)` still "cannot be
  variadic"; `P operator-(P a, P b = P())` still "cannot have a default
  argument"; `static P operator%(Q, Q)` still "cannot be a static member
  function". Those five are the proof that the U2 relaxation, the
  variadic allowance and the default-argument allowance were scoped to
  the new name kind.

**Unit test:** `SemaTests --gtest_filter='UserOperatorDeclTest.*'` →
1 passed; and 1 **failed** (both assertions) with the fix reverted, as
quoted above.

**Full gate:** `ninja -C $B check-clang` → 54140 discovered / 48246 passed
/ 27 XFAIL / 5853 unsupported / 6 skipped / **8 failed**, 215 s test time.

All 8 are the known `DirectoryWatcherTest.*` cases with
`No space left on device : inotify_add_watch()` — `PLAN.md`'s fifth gate
fact, measured again at gate time: **65,382 of 65,536**
`fs.inotify.max_user_watches` held machine-wide, the same figure U06 and
U07 measured. Filtered re-run:

```bash
ulimit -c 0
GTEST_FILTER='-DirectoryWatcherTest.*' $B/bin/llvm-lit -s $B/tools/clang/test
```
→ `EXIT=0`, **54132 discovered / 48246 passed / 0 failed** / 27 XFAIL /
5853 unsupported / 6 skipped; zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines.
171.8 s.

Arithmetic closes exactly: 54132 = U07's 54130 **+2**, 48246 = 48244
**+2** — the one new lit test and the one new gtest case, nothing else.
**No existing test changed behavior**, which is the claim that matters for
a step whose whole risk is that it perturbs `operator+`.

## Deviations from the plan / design

**DEV-U06** — U§7 "Declaring" says the declaring rules are "the existing
machinery" with the class-or-enum rule as the single named exception. That
frame is wrong in a way worth fixing in the paper: [over.oper] imposes
**five** restrictions and a user operator inherits exactly **one**
(arity). Class-or-enum, the no-default-arguments rule ([over.oper]p8) and
the no-variadic rule all have to be waived — the step file directs the
last two ("allow whatever the ordinary function rules allow") but the
design doc never says so — and the arity table itself
(`OperatorUses[Op]`, generated from `OperatorKinds.def`) has no row to
consult, so the rule had to be written out. The generalization DEV-U06
recommends for U§7: *[over.oper]'s restrictions protect a token whose
parse, arity and fixity the grammar already fixed; a user operator's only
fixed property is arity, so arity is the only rule it inherits.*

The one **judgement call with no design guidance**, also in DEV-U06:
**static member user operators are rejected**, reusing
`err_operator_overload_static`. U5's arity rule presupposes an implicit
object parameter ("two parameters, or one as a member"), and a static
member has none, so it names neither form. Restrictive now, relaxable
later. The C++23 `static operator()` precedent means someone in the room
*will* ask whether a static member should be admitted as a second infix
form — DEV-U06 asks for it in the decisions log as a sub-point of U5.

**DEV-U07** — the U01 open question, examined and answered with a
measurement rather than left open. See the next section.

## The C-mode flag question (U01's open item) — judgement

**Measured, not reasoned:** `-funicode-operators` is not merely *accepted*
in C mode, it is **no longer inert** there. On
`int f(int a, int b) { return a ⊞ b; }` compiled as C
(`clang -cc1 -x c -fsyntax-only`):

- **with** the flag: 1 error, `expected ';' after return statement`;
- **without** it: 2 errors, `unexpected character '⊞' U+229E` first.

U03's lexer hunk fires on `LangOpts.UnicodeOperators` alone, with no C++
test, so the flag suppresses the accurate diagnostic and leaves the
misleading one. It can never do anything useful in C: there is no
`operator` keyword, so no `operator⊞` can be declared and the token has no
production to appear in.

**Judgement: yes, it should gain `ShouldParseIf<cplusplus.KeyPath>` — and
so should `-fbacktick`, in the same change.** `defm reflection` in
`Options.td` is the in-tree precedent for exactly this, three lines above
`defm backtick`; neither flag has it. A feature whose grammar is C++-only
should not have a flag that changes C tokenization.

**U08 did not make the change**, deliberately, for three reasons: it is
outside a Sema-declaration-rules step's diff; it edits U01's driver test
(`clang/test/Driver/funicode-operators.c`, itself a `.c` file); and
changing only one of the two paired flags would create a divergence
between `-fbacktick` and `-funicode-operators` that is a worse surprise
than the current symmetry. The natural owner is **U04 or U05** — the
observable is a lexing difference, and those steps are already in
`Lexer.cpp`. Recorded as DEV-U07 with the measurement so the next agent
does not have to re-derive it.

## Discoveries affecting later steps

- **Nothing rejects a *use* yet, and nothing should.** U08 is
  declaration-side only. `operator⊞(1, 2, 3)` (wrong argument count at an
  explicit call) is ordinary overload resolution and already works.
- **A valid user-operator `FunctionDecl` now has a strong invariant**:
  operand count ∈ {1, 2}, never static. U11/U12/U13 may rely on it for
  well-formed declarations — but *not* for invalid ones, which are still
  in the AST with `setInvalidDecl()` set (upstream's shape for every
  operator; `CheckOverloadedOperatorDeclaration` behaves identically).
- **Default arguments and variadics are allowed, and that is a live
  wrinkle for U12/U13, not just a rule.** `int operator⊟(int a, int b = 1)`
  declares an infix operator by arity, but the call `operator⊟(x)` is also
  viable. Whether `⊟x` (prefix position) should therefore find it is a
  *form-selection* question U08 deliberately does not answer — form is
  selected by declared arity here, so `⊟x` should not find a 2-parameter
  function. If U12/U13 filter candidates by form, filter on
  `getNumParams()` + implicit object, **not** on "is this call viable".
- **`isImplicitObjectMemberFunction()` lives on `CXXMethodDecl`**
  (`DeclCXX.h:2183`), not on `FunctionDecl` — every arity computation
  needs the `dyn_cast<CXXMethodDecl>` first. Upstream's own version of the
  same formula (`SemaDeclCXX.cpp`, `CheckOverloadedOperatorDeclaration`)
  spells it `isa<CXXMethodDecl>(FnDecl) &&
  !FnDecl->hasCXXExplicitFunctionObjectParameter()`, which is equivalent
  *only because* it rejects static members earlier. Do not copy that form
  into a context that admits statics.
- **The `-Wswitch` warning budget is no longer zero on this branch** —
  see Verification. One pre-existing backtick-track warning
  (`BacktickInfixExprClass` in `ExprEngine.cpp:1688`) now appears in any
  build that recompiles the static analyzer. Grep for `unicode` or the
  file you touched rather than counting `warning:` lines.

## Forward notes for U10 — explicit-call sweep

U10 depends on U08 **and U09**, so it is not yet unblocked; these notes
are for whoever gets there.

- **U08 already wrote a small piece of your test 1.** `static_assert(
  operator⊞(5, 7) == 12)` over `constexpr int operator⊞(int a, int b)` is
  in `clang/test/SemaCXX/unicode-operator-decl.cpp`, and U07 has a
  `static_assert(operator⊞(2, 3) == 5)` in the Parser test. Keep those
  where they are (they are load-bearing for *their* steps) and write
  `unicode-operator-call.cpp` fresh.
- **Your item 4 negative case is already known to be a lookup
  diagnostic, not a syntax one.** U07 changed `SemaExpr.cpp:2644`
  (`Sema::DiagnoseEmptyLookup`) so an undeclared explicit call says
  `error: use of undeclared 'operator⊞'`, with the caret underlining
  `operator⊞` whole. That is the U3 claim you are being asked to verify;
  pin the exact string.
- **Your item 4 ADL case should work today and U08 is the reason.**
  Before this step, a namespace-scope `operator⊞` was not in
  `IDNS_NonMemberOperator`. That gap did not affect an *explicit call*
  (ADL filters on `IDNS_Ordinary`, `SemaLookup.cpp:3929`) but it did
  affect operator lookup. Both now work. When your handoff answers the
  step's question "does ADL on an explicit call already work for free" —
  the answer is expected to be yes, and the interesting follow-up for U13
  is that the *operator* path uses a different identifier namespace than
  the ADL path, so "explicit call works" is **not** evidence that
  `x ⊞ y` will.
- **Item 7, linkage across two TUs, is the one that can genuinely fail**,
  and it fails in U09's territory, not yours. Item 8 (UCN spellings) needs
  U04, which is still unchecked — check `PLAN.md` before writing those
  RUN lines.

## Forward notes for U11 — infix parse at the user-infix level

- **The predicate you asked for is `FunctionDecl::isUserOperator()` /
  `getUserOperatorCodePoint()`** (`Decl.h`, right after
  `getLiteralIdentifier()`). The full "which form" recipe is in section 3
  above — copy it rather than re-deriving, and note the `CXXMethodDecl`
  `dyn_cast`.
- **But you probably do not need a `FunctionDecl` at all.** U11's job (its
  own step file, item 3) is to keep the callee *unresolved*: build the
  `DeclarationName` with
  `Context.DeclarationNames.getCXXUserOperatorName(CodePoint)` and let
  U13 do candidate assembly. The code point comes straight off the token:
  `Lexer::getUserOperatorCodePoint(Tok, PP.getSourceManager(),
  getLangOpts())` — the same call U07 uses in
  `ParseUnqualifiedIdOperator` (`ParseExprCXX.cpp:2519`), and the reason
  U04's UCN spellings will need no work in your file either.
- **What U08 guarantees you**: any *valid* `operator⊞` in scope has one or
  two operands and is not static. So the infix form always has a
  well-defined arity-2 meaning and the prefix form an arity-1 one, with no
  third case to design around, and you do not need to re-check arity at
  the use site — U13's overload resolution will reject a 1-operand
  candidate for a 2-operand use by ordinary argument-count rules.
- **What U08 does *not* give you**: a diagnostic for postfix. There is
  none, by design (U5) — nothing about a declaration reveals that someone
  meant postfix. The postfix error surfaces at the *use* site, which is
  U12's, not yours.
- **The `setNonMemberOperator` fix is what makes U13's lookup find
  anything**, and its regression test (`SemaTests`,
  `UserOperatorDeclTest`) runs today without any infix syntax. If your
  first `x ⊞ y` finds no candidates, run that test first: if it passes,
  the problem is in your candidate assembly, not in the declaration's
  identifier namespace. That is a 30-second bisection you would otherwise
  spend an hour on.
- **`Sema::LookupOperatorName` is `SemaLookup.cpp:238`**, and
  `Decl::IDNS_NonMemberOperator` has exactly one consumer in the tree —
  that line. If U13 ever needs a *second* namespace, it does not exist.
- Glyphs used so far, across the Parser test, the SemaCXX test and the
  unit test: ⊞ U+229E, ⊕ U+2295, ⊖ U+2296, ⊗ U+2297, ⊘ U+2298, ⊙ U+2299,
  ⊚ U+229A, ⊛ U+229B, ⊜ U+229C, ⊝ U+229D, ⊟ U+229F, ⊠ U+22A0, ⊡ U+22A1,
  ⊢ U+22A2, ⋄ U+22C4. All inside U1's contiguous `{0x2266, 0x22C4}` range
  (`clang/lib/Lex/UnicodeOperatorCharSets.h:54`), so anything else in that
  range is free — ⊣ U+22A3, ⊤ U+22A4, ⊥ U+22A5, ⊨ U+22A8, ⋀–⋃ U+22C0+.

## Open risks / TODOs

- **The static-member decision is a design choice made by an
  implementation step** (DEV-U06). It is the only rule in U08 that the
  design doc does not supply, and it is exactly the kind of thing EWG will
  re-open given C++23's `static operator()`. Reconcile it into U5 or give
  it a U-number before the paper claims the rules are settled.
- **The C-mode flag question is answered but not acted on** (DEV-U07).
  Recommended owner U04/U05, paired with the same change to `-fbacktick`.
- **Default arguments + form selection** is an unexercised corner: a
  2-parameter user operator with a defaulted second parameter is
  simultaneously an infix operator by arity and a 1-argument-viable call.
  U08 allows it because ordinary function rules do. U12/U13 must decide
  whether `⊟x` finds it; the recommendation above is that it should not,
  because form is selected by declared arity. Nothing tests this yet.
- **`SemaCodeComplete.cpp:1061`** is still the one-line completion-priority
  grouping U06 and U07 both left alone. Still flagged for U16.
- The `-Wswitch` `BacktickInfixExprClass` gap in
  `StaticAnalyzer/Core/ExprEngine.cpp:1688` is a **backtick-track** issue
  visible from this branch. Not U08's to fix, and it must not be fixed
  here (it would end up in the unicode replay ledger for a backtick
  reason), but it is worth a note back to the backtick track.
