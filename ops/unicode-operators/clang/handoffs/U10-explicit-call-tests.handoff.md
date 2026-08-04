# Handoff — U10 Explicit-call sweep

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `e035e4db8e18`
  (parent `77f6a10f9bb4`, U09)
- **Date / agent:** 2026-08-04

**The headline is the diff: zero production files, zero lines.** Two new
test files and nothing else. That is not a small step — it is the step's
*result*. U10 exists to be an honest gate, and a gate that has to patch the
thing it measures is worth nothing; every one of the step file's eight areas
that could be tested at all passed on the first compile of the first draft,
with the binary built by U09 and never rebuilt.

The one area that could not be tested is item 8 (UCN spellings), blocked on
U04, exactly as U08 and U09 predicted. It is not a defect and no workaround
was attempted; the two lines to add when U04 lands are spelled out below.

## What changed

Two new lit tests. **No production file was touched**, so there is no
"files touched" table worth the name.

| File | Content |
|------|---------|
| `clang/test/SemaCXX/unicode-operator-call.cpp` | new, 373 lines, 2 RUN lines (`-std=c++23 -funicode-operators`, then the same **plus `-fbacktick`**). The sweep proper. |
| `clang/test/CodeGenCXX/unicode-operator-call.cpp` | new, 120 lines, **7 RUN lines**. Call-side symbols and the two-TU linkage proof. `REQUIRES: x86-registered-target`. |

**In this repo:** `PLAN.md` (U10 ticked, Status row), `REPLAY.md` U10 row
(`upstream replay` (tests)), `DEVIATIONS.md` **DEV-U10**, this handoff.

## The eight areas, and what each one actually showed

All eight are in the step file's numbering. Seven passed unmodified; the
eighth is U04's.

1. **Fundamental-only call, end to end.** `constexpr int operator⊞(int,
   int)` called as `operator⊞(5, 7)`, `static_assert`ed, nested
   (`operator⊞(operator⊞(1,2), operator⊖(3))`), and at runtime.
   `decltype(operator⊞(1, 2))` is `int`. U2's motivating case works with no
   class or enum operand anywhere in the file.
2. **Overload sets and ranking.** Four `operator⊠` overloads (`int`,
   `double`, `Base`, `Derived`); exact match, float→double promotion, and
   derived-exact beating the base conversion all rank ordinarily. The
   ambiguity diagnostic is `call to 'operator⊠' is ambiguous` with two
   `candidate function` notes — readable, and it names the operator.
3. **Qualified and member calls.** `NS::operator⊞(q, q)`,
   `m.operator⊞(m)`, `p->operator⊞(m)`, `m.Mem::operator⊞(m)`,
   `m.operator⊖()` (member prefix), and an *unqualified* explicit call
   inside the class finding the member through the implicit object
   argument. All constant-evaluated.
4. **ADL — see the next section. This is the load-bearing result.**
   Negative cases: `no matching function for call to 'operator⊢'` with the
   ordinary `candidate function not viable: no known conversion…` note; the
   same for a wrong argument count (`requires 2 arguments, but 3 were
   provided`); `use of undeclared 'operator⊣'` for a name never declared,
   in both the 2-argument and 1-argument forms. **Every failure is a
   lookup or overload diagnostic. Not one is a lex or parse error, which
   is U3's claim and is now pinned by exact-text `-verify` directives.**
5. **Templates.** Function-template operator (deduced, explicit
   `operator⊤<int>`, and `double` deduction); a class template's member
   infix and member prefix operators; dependent non-member calls resolved
   by ADL at instantiation; a dependent *member* call; a dependent call
   inside `decltype` used as a trailing return type; SFINAE on the return
   type (an unusable `operator⋀` removes the candidate rather than
   erroring); a `requires`-expression concept
   (`requires(T a, T b) { operator⋀(a, b); }`, true for `Dep::E`, false for
   `Base`); and a constrained template whose unsatisfied-constraint
   diagnostic chains all the way down to
   `because 'operator⋀(a, b)' would be invalid: use of undeclared
   'operator⋀'`.
6. **Address-taking.** `&operator⊩`, bare `operator⊩` without `&`,
   `&operator⊪` for the prefix form, `decltype(&operator⊪)` ==
   `int (*)(Addr)`, `Holder<&operator⊩>` as a **non-type template
   argument**, passing it as a function argument both ways, target-typed
   selection out of a two-element overload set
   (`constexpr int (*)(int,int) = &operator⊫` picks the `int` one), and
   `&PM::operator⊬` as a **pointer to member** called through `(p.*pmf)(p)`.
   All `constexpr`-evaluated, so each one is checked twice.
7. **Linkage across two TUs — verified three ways.** See "The linkage
   recipe" below.
8. **UCN spellings — BLOCKED on U04, expected, not a defect.** See "What
   U04 owes this file".

Plus one area the step file does not name and which is worth having: the
**`template` disambiguator** corner, asserted rather than fixed. See
"The one place `operator⊞` is not an ordinary name".

## ADL on an explicit call — the answer U13 needs

**Yes, completely, for free, with no implementation work of any kind.**
The step file asks whether it "already works"; the honest answer is
stronger than that — *nothing in the compiler was changed and nothing had
to be*. Recorded here in the detail U13 needs, because U13 must reproduce
**this exact list** through the infix path.

Every one of these is a `static_assert` in
`clang/test/SemaCXX/unicode-operator-call.cpp`, section 4:

| ADL shape | Verified |
|---|---|
| operand is a class in another namespace | `operator⊘(Adl::A{}, Adl::A{}) == 41` |
| **prefix arity gets ADL too** | `operator⊙(Adl::A{}) == 42` |
| operand is an **enumeration** — the enum's namespace is associated | `operator⊘(Adl::e1, Adl::e1) == 43` |
| **hidden friend** — reachable by ADL and by *nothing else at all* | `operator⊛(Adl::Hidden{}, Adl::Hidden{}) == 45` |
| operand is a **pointer** — the pointee's namespace is associated | `operator⊚(&p, &p) == 44` |
| **class-template argument** contributes its namespace | `operator⊜(Wrap<Adl2::B>{}, Wrap<Adl2::B>{}) == 46` |
| **ADL augments a non-viable ordinary set** rather than being masked by it | an enclosing-scope `operator⊝(Local, Local)` is visible and not viable; `operator⊝(Adl3::C{}, Adl3::C{}) == 48` still finds the ADL candidate |
| ADL finds **no member operators** | `operator⊡(d, d)` → `use of undeclared 'operator⊡'` |
| ordinary lookup finding a **class member suppresses ADL**, as always | `Suppress::m` resolves to the member, not to `Adl::operator⊘` |
| dependent call, resolved by ADL **at instantiation** | `dependent_infix(Dep::E{}, Dep::E{}) == 61` |
| a using-declaration puts the name in ordinary lookup | `operator⊟(1, 2) == 49` |

**Two of those rows are the ones that matter and they should be quoted at
U13 rather than summarised.** The *hidden friend* row is the strongest
possible statement that lookup is not being short-circuited: nothing but
ADL can see `Adl::Hidden`'s `operator⊛`, and it is found. The
*augmentation* row is the precise shape GCC's **DEV-G05** lost on the
backtick track — an ordinary-lookup candidate exists, is not viable, and an
implementation that resolved the name early would stop there and report no
match. Clang does not, because the explicit call reaches `BuildCallExpr`
with the callee still an `UnresolvedLookupExpr`.

The codegen half proves the *right* function was chosen and not merely
"some" function: `int adl(N::A a) { return operator⊞(a, a); }` emits a call
to `@_ZN1Nv28op_u229EENS_1AES0_` — nested in `N` — while two enclosing-scope
`operator⊞` overloads exist and mangle as `@_Zv28op_u229E1SS_` /
`@_Zv28op_u229E1TS_`. A namespace-qualified symbol is proof of the
namespace the callee came from that no `-verify` line can give.

### The caveat U08 left, restated for U13 and still live

U08's forward note is unchanged by this step and should be read as U10's
conclusion too: **"explicit call works" is not evidence that `x ⊞ y` will.**
The explicit call goes through ordinary unqualified lookup, whose ADL path
filters on `IDNS_Ordinary` (`SemaLookup.cpp:3929`); the *operator* path
uses `Sema::LookupOperatorName` (`SemaLookup.cpp:238`) and
`Decl::IDNS_NonMemberOperator`, which has that one consumer in the whole
tree. U08's `setNonMemberOperator` fix is what makes the second path find
anything, and its regression test pins it. **Verified from the front end,
not only from that unit test, as this step was asked to do**: the
`UserOperatorDeclTest` gtest still passes in the full gate, *and* every ADL
row above resolves through a real `ASTFrontendAction` at
`-fsyntax-only` — but note carefully that those two facts are evidence about
**different lookup paths**. The front-end evidence here covers
`IDNS_Ordinary`; the only evidence for `IDNS_NonMemberOperator` remains the
unit test, and it stays the only evidence until U13 runs. If U13's first
`x ⊞ y` finds no candidates, run
`SemaTests --gtest_filter='UserOperatorDeclTest.*'` **first** — U08's
30-second bisection is still the right first move.

## The linkage recipe (item 7), verified three ways

U09's forward note was right and its "preferred, hermetic" option is what
the test uses. All three of these were run:

1. **`llvm-link` merge (in the test).** Compile each TU with
   `%clang_cc1 … -emit-llvm-bc`, then
   `llvm-link %t.use.bc %t.def.bc -S -o - | FileCheck --check-prefix=LINKED`.
   The declaring TU's `declare @_Zv28op_u229E1SS_` becomes a `define` after
   the merge. Pinned with `LINKED-DAG` for `call` and `define` plus a
   `LINKED-NOT` for any surviving `declare`. **Use `-DAG`, not plain
   `LINKED:`** — `llvm-link` emits the *use* module first, so the `call`
   precedes the `define` and an ordered pair fails.
2. **Object files (in the test).** `-emit-obj` each TU, then `llvm-nm`:
   `U _Zv28op_u229E1SS_` in one, `T _Zv28op_u229E1SS_` in the other. This
   is what forced `REQUIRES: x86-registered-target` onto the file.
3. **A real driver link and a real execution (not in the test, run by
   hand).** `clang a.o b.o -o prog` links clean and the program returns the
   value computed by the operator. Left out of the test deliberately: it
   drags in the host toolchain for evidence the first two already give
   hermetically.

`llvm-link` and `llvm-nm` are invoked **bare**, not as `%llvm-link` — they
are on `PATH` in the clang test config but are *not* in
`clang/test/lit.cfg.py`'s `tools` substitution list. `clang/test/InterfaceStubs/*.cpp`
is the in-tree precedent. U09's note on this was correct and saved the
rediscovery.

## The one place `operator⊞` is not an ordinary name

Asserted, not fixed, exactly as directed — and the **control** is the part
worth keeping:

```cpp
template <class T> int f(T t) { return t.template operator⊭<int>(0); }
// error: 'operator⊭' following the 'template' keyword cannot refer to a
//        dependent template
```

U07 found this and named the cause (`DependentTemplateStorage` is keyed by
`IdentifierInfo *` or `OverloadedOperatorKind`; a user operator is neither).
U10 adds the measurement that makes it a non-finding: the **identical**
construct on a **literal operator** —
`t.template operator""_lit<int>(0)` — produces the character-identical
diagnostic, while `t.template operator+<int>(0)` compiles fine. Both are in
the test file, side by side, with a comment saying why. So this is the
limitation of *every* operator-function-id outside the fixed
`OverloadedOperatorKind` set, inherited unchanged, not something the new
name kind introduced.

Non-dependent object expressions are fine in both spellings:
`TmplMem{}.operator⊭<int>(0)` and `TmplMem{}.template operator⊭<int>(0)`
both work.

This is the whole of **DEV-U10**: U§7.1 claims the operator-function-id
"names the overload set anywhere an unqualified-id does", and "anywhere" is
the one word in it that a compiler falsifies.

## Verification evidence

**Build: none.** No production file changed, so the U09 binary was used
unmodified. `git status` before the commit showed exactly two untracked
files and nothing else — that is itself the step's primary evidence.

**Targeted lit**, all seven unicode-track tests together:

```
SemaCXX/unicode-operator-call.cpp        SemaCXX/unicode-operator-decl.cpp
CodeGenCXX/unicode-operator-call.cpp     CodeGenCXX/unicode-operator-mangle.cpp
Parser/unicode-operator-decl.cpp         Lexer/unicode-operators.cpp
Driver/funicode-operators.c
```
→ **7/7 pass**, 0.17 s. Both new files passed on their first `llvm-lit`
run after the `-verify` line offsets were settled; no test content changed.

**Full gate:** `ninja -C $B check-clang` → 54143 discovered / 48249 passed /
27 XFAIL / 5853 unsupported / 6 skipped / **8 failed**, 167.6 s test time.

All 8 are the known `DirectoryWatcherTest.*` cases with
`No space left on device : inotify_add_watch()` — `PLAN.md`'s fifth gate
fact, measured again at gate time: **65,382 of 65,536**
`fs.inotify.max_user_watches` held machine-wide, the identical figure U06,
U07, U08 and U09 all recorded. Filtered re-run:

```bash
ulimit -c 0
GTEST_FILTER='-DirectoryWatcherTest.*' $B/bin/llvm-lit -s $B/tools/clang/test
```
→ `EXIT=0`, **54135 discovered / 48249 passed / 0 failed** / 27 XFAIL /
5853 unsupported / 6 skipped; zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines.
167.6 s.

Arithmetic closes exactly: 54135 = U09's 54133 **+2**, 48249 = 48247 **+2**
— the two new lit tests and nothing else.

The pre-existing backtick-track `-Wswitch` gap on `BacktickInfixExprClass`
(`StaticAnalyzer/Core/ExprEngine.cpp:1688`) did not appear, for the trivial
reason that nothing was compiled. It is still there and still not ours.

## Deviations from the plan / design

**DEV-U10** (`DEVIATIONS.md`) — two halves, and the second is the one for
the paper. (1) U§7.1's "names the overload set **anywhere** an
unqualified-id does" needs a one-clause qualifier for the dependent
`template`-name corner, which is inherited from the literal-operator
precedent rather than new. (2) U§7's "Using" paragraph should promote ADL
from an asserted requirement to a **measured result** — full ADL including
hidden friends and augmentation of a non-viable ordinary set, with *zero*
implementation work — because that is the strongest sentence the
implementation-experience section has for §17.4's normative rule, and the
GCC DEV-G05 contrast is right there to point at.

**Scope note a reviewer will ask about.** The test covers three things the
step file does not name: pointer-to-member address-taking, the ADL
suppression rules (members not found; a found member suppressing ADL), and
the `template`-keyword corner with its literal-operator control. The first
two are two lines each and are the difference between "ADL happens" and
"ADL happens *correctly*", which is what U13 has to reproduce. The third
was directed by the step's framing (assert current behavior) and its value
is entirely in the control line.

**Nothing needed a prior-step fix.** No `BLOCKED` handoff, no one-line
omission found, no Sema patched. Every case that failed to compile failed
because it was *written* to fail and is pinned with `-verify`.

## Discoveries affecting later steps

- **ADL on an explicit call is free and complete.** The full list is above;
  it is U13's acceptance criterion, not a summary.
- **A user operator cannot be a variable.** `int operator⊞ = 0;` gives
  `'operator⊞' cannot be the name of a variable or data member`. This
  matters because it removes the classic ADL-suppression-by-block-scope-
  non-function-declaration case from the design space entirely — there is
  no way to write it. Worth knowing before anyone tries to test it.
- **The `use of undeclared 'operator⊞'` caret underlines only the
  `operator` keyword** (8 columns), not the glyph. U08's handoff says it
  underlines the whole name; that is not quite right. It is also
  *upstream's* shape — `operator+` and `operator""_x` produce the identical
  8-column range from the same `Sema::DiagnoseEmptyLookup` path — so it is
  cosmetic and shared, not ours. By contrast
  `no matching function for call to 'operator⊞'` *does* underline all nine
  columns. Nobody needs to fix either; recorded so it is not rediscovered
  as a bug.
- **`-verify` line offsets in these files are fragile in a specific way.**
  The `expected-note@-N` directives point back at candidate declarations
  many lines above. Adding or removing a single line in a declaration group
  silently breaks them with a confusing "expected but not seen / seen but
  not expected" pair naming two adjacent line numbers. If you edit
  `unicode-operator-call.cpp`, re-run its `-verify` immediately rather than
  at the end.
- **`REQUIRES: x86-registered-target`** is on the CodeGen file only because
  of its two `-emit-obj` RUN lines. The `-emit-llvm` and `-emit-llvm-bc`
  lines would not need it. Anyone splitting the file should keep that in
  mind.

## What U04 owes this file (item 8, the only untested area)

Re-verified today against the current binary, not inherited:

```
$ clang -cc1 -std=c++23 -funicode-operators -fsyntax-only <<< 'int operator⊞(int,int);'
error: character '⊞' U+229E not allowed in an identifier
$ ... 'int operator\N{SQUARED PLUS}(int,int);'
error: character '⊞' U+229E not allowed in an identifier
```

Both spellings, both the same diagnostic, at the declaration *and* at a
call. So neither half of item 8 ("two representative cases with UCN
spellings, **mixing spellings between declaration and call**") can be
written yet.

**When U04 lands, this is the exact work — three additions, no redesign:**

1. In `clang/test/SemaCXX/unicode-operator-call.cpp`, delete the
   "NOT this file, because it cannot be" paragraph at the top and add two
   cases: (a) declare with the glyph, call with `⊞`; (b) declare with
   `\N{SQUARED PLUS}`, call with the glyph. Each is a `static_assert` over
   a `constexpr` operator, so both directions of the mix are checked by
   evaluation and not merely by acceptance.
2. In `clang/test/CodeGenCXX/unicode-operator-mangle.cpp`, U09's own
   forward note already specifies the one-line proof: a second declaration
   spelled `operator\N{SQUARED PLUS}` plus a `CHECK-NOT` for any *second*
   `op_u229E` symbol. That belongs in U09's file, not this one.
3. Nothing in the mangler changes — the derivation reads the
   `DeclarationName`'s code point and no spelling ever reaches it.

Also still open and still owned by U04 or U05: **DEV-U07**, the
`ShouldParseIf<cplusplus.KeyPath>` question for `-funicode-operators` *and*
`-fbacktick` together. U08 measured it and deliberately did not act.

## Forward notes for U11 — infix parse at the user-infix level

Written after reading `steps/U11-infix-parse.md`.

- **U10's whole output is your acceptance criterion for U13, and you should
  read it that way now rather than at U13.** U11 keeps the callee
  unresolved precisely so that the ADL table above survives into the infix
  form. The single sentence to keep in view: *an ordinary-lookup candidate
  that is not viable must not stop the ADL candidate from being found.*
  If your stub Sema in U11 item 5 resolves the name to make the parse tests
  type-check, **make it obviously a stub and say so in the handoff** — a
  stub that quietly resolves is DEV-G05 arriving one step early, and it
  will look like it works until U13's first hidden-friend test.
- **The two symmetric tests you can write cheaply.** For every ADL case in
  `SemaCXX/unicode-operator-call.cpp` §4 there is an infix twin
  (`a ⊘ b` for `operator⊘(a, b)`). Do not write them in U11 — U11 is parse,
  and the semantics gate is U13/U14 — but note that the file is
  deliberately laid out so U13 can mirror section 4 line for line. Point
  U13's author at it.
- **You do not need a `FunctionDecl` and you should not look one up.** U08's
  note stands: build the name with
  `Context.DeclarationNames.getCXXUserOperatorName(CodePoint)` and get the
  code point from the token via
  `Lexer::getUserOperatorCodePoint(Tok, PP.getSourceManager(), getLangOpts())`
  — the same call `ParseUnqualifiedIdOperator` uses at
  `ParseExprCXX.cpp:2519`. That is also why U04's UCN spellings will need no
  work in your file.
- **`isUserOperator()` / `getUserOperatorCodePoint()`** are on
  `FunctionDecl` in `Decl.h` right after `getLiteralIdentifier()`, if you do
  end up needing the predicate. The "which form" recipe (with the
  `dyn_cast<CXXMethodDecl>` for `isImplicitObjectMemberFunction()`) is in
  U08's handoff §3; copy it rather than re-deriving.
- **Do not re-test what these two files already cover.** Your test file is
  `clang/test/Parser/unicode-operator-infix.cpp` and it is about *grouping*:
  `a ⊞ b`, left-associativity, tighter than `*`, both operands as
  cast-expressions, the `-fbacktick`-on and `-fbacktick`-off mixed chains,
  and `a ⊞ {1,2}` rejected. Every question about *which function gets
  called* is already answered, in a file that will still be there.
- **Glyph budget.** U10 used, in addition to everything before it:
  ⊞ U+229E, ⊖ U+2296, ⊠ U+22A0, ⊘ U+2298, ⊙ U+2299, ⊚ U+229A, ⊛ U+229B,
  ⊜ U+229C, ⊝ U+229D, ⊟ U+229F, ⊡ U+22A1, ⊢ U+22A2, ⊣ U+22A3, ⊤ U+22A4,
  ⊥ U+22A5, ⊨ U+22A8, ⊩ U+22A9, ⊪ U+22AA, ⊫ U+22AB, ⊬ U+22AC, ⊭ U+22AD,
  ⋀ U+22C0, ⋁ U+22C1, ⊗ U+2297. **U+22A3, U+22A4, U+22A5, U+22A8–U+22AD are now
  taken**, three of which (⊣ ⊤ ⊥ ⊨) U08's and U09's handoffs listed as
  free. Still free inside U1's contiguous `{0x2266, 0x22C4}` range:
  U+22A6, U+22A7, U+22AE–U+22BF and U+22C2–U+22C4 —
  and the whole rest of U1 outside that range, of which
  `unicode-operator-mangle.cpp` uses only ← U+2190 and ⯿ U+2BFF.
- **A `-fbacktick` RUN line on every new test file is now the settled
  convention** (U07, U08, U09, U10 all have one). Keep it, and remember
  REPLAY: it is the one line U20 drops on clean `main`.

## Open risks / TODOs

- **Item 8 is genuinely untested, not merely deferred.** The step file's
  "all three spellings behave identically" claim has *no* evidence behind it
  today beyond the structural argument that no spelling reaches the
  mangler. U04 is the only thing between the prototype and that claim, and
  it is still unchecked with three Phase B steps now done. If U04 slips
  past U13, someone should notice that the paper cannot yet assert
  spelling-independence.
- **The `IDNS_NonMemberOperator` path still has exactly one piece of
  evidence** — U08's gtest. U10 could not add a second, because no
  front-end syntax reaches `Sema::LookupOperatorName` for a user operator
  until U11/U13. That is a real gap in coverage until U13, and it is the
  gap DEV-G05 lived in on the GCC track.
- **DEV-U10's "anywhere" wording** needs reconciling into `docs/unicode-operators.md`
  U§7.1 by the paper author; the recommended text is in the ledger row.
- **DEV-U07** (the `ShouldParseIf<cplusplus.KeyPath>` C-mode question) is
  still measured-but-unacted, still recommended for U04/U05, still paired
  with `-fbacktick`.
- **`SemaCodeComplete.cpp:1061`** remains the one-line completion-priority
  grouping U06–U09 all left alone. Still flagged for U16.
- The `-Wswitch` `BacktickInfixExprClass` gap in
  `StaticAnalyzer/Core/ExprEngine.cpp:1688` is unchanged, still a
  backtick-track issue, still not to be fixed on this branch.
