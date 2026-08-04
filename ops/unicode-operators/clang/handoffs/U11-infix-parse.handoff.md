# Handoff — U11 Infix parse at the shared user-infix level

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `02b0b96cf2e5`
  (parent `e035e4db8e18`, U10)
- **Date / agent:** 2026-08-04

Phase C opens and expression syntax exists for the first time.
**5 production files, +96/−8**, of which the parser's share is *one*
`case` in the precedence table and *one* 14-line dispatch arm. U§6's claim
that parsing is the easy part is now a measurement rather than a hope.

The step's three hard constraints were all met and are all checkable from
the diff: one precedence level (a rename, not an addition), the callee is
never resolved at parse time, and the Sema body is a stub that says so in
capitals.

## The three answers the step asked for

### 1. The `prec::Level` enumerator: `prec::UserInfix`, value **16**

`prec::Backtick = 16` was renamed to `prec::UserInfix = 16` —
same value, same slot, one comment widened to
`// x `f` y, x <user-operator> y`. There is exactly **one** level; there
is no second enumerator anywhere in the tree. Two call sites carried the
old name (`OperatorPrecedence.cpp`'s `case tok::backtick:` and
`Parser::isFoldOperator`) and both were renamed in place.

`getBinOpPrecedence` gained a fifth parameter,
`bool UnicodeOperatorsEnabled = false`, alongside the existing
`bool BacktickIsOperator = true`, and the new arm is:

```cpp
  case tok::user_operator:
    return UnicodeOperatorsEnabled ? prec::UserInfix : prec::Unknown;
```

The parser passes `getLangOpts().UnicodeOperators` at its three
`ParseRHSOfBinaryExpression` call sites. The gate is belt-and-braces —
U03's lexer only ever produces `tok::user_operator` when the flag is on —
but the level is now gated at the place it is *defined*, which is where a
reader looks. The parameter defaults **false**, so `clang/lib/Format`'s two
callers and `SemaConcept.cpp`'s one behave exactly as upstream; U18 will
have to opt in deliberately.

**REPLAY classification is split three ways and the row spells it out.**
Summary, because U19/U20 turn on it:

- `prec::UserInfix` itself and `isFoldOperator`'s exclusion of it are
  **`shared if landed`**. The enumerator exists today only because the
  backtick diff is present; on clean `main` the last enumerator is
  `PointerToMember = 15` and the standalone equivalent is the identical
  one line `UserInfix = 16` after it. **Same name, same value, same
  position under every fate** — which is precisely what U§12's "EWG banks
  one level once, for both features" argument needs. Backtick first → this
  step is a one-word rename plus a `case`; backtick never → this step
  introduces the enumerator itself; both → one enumerator, two `case` arms.
- The `case tok::user_operator:` arm, the `UnicodeOperatorsEnabled`
  parameter, the parser dispatch arm, `ActOnUserOperator` and the test are
  **`upstream replay`**.
- The two *renamed backtick lines* are **not replayed at all** — they have
  no clean-`main` counterpart.

### 2. The Sema action signature, and how identity is passed

`clang/include/clang/Sema/Sema.h`, immediately after
`ActOnBacktickOperator`:

```cpp
  ExprResult ActOnUserOperator(Scope *S, SourceLocation OpLoc,
                               uint32_t CodePoint, MultiExprArg Operands);
```

**One action for both forms.** Arity is `Operands.size()`: 2 today
(infix), 1 when U12 lands (prefix). U12 does not need a second entry
point and U13 does not need to write the same candidate assembly twice —
this was chosen for U12/U13's benefit, not U11's.

`MultiExprArg`, not `ArrayRef<Expr *>`: `BuildCallExpr` takes
`MultiExprArg` (= `MutableArrayRef<Expr *>`) and an `ArrayRef` will not
convert. That cost one build cycle; do not "tidy" it back.

Identity is the **Unicode scalar value and nothing else**. The parser
computes it from the token:

```cpp
        uint32_t CodePoint = Lexer::getUserOperatorCodePoint(
            OpToken, PP.getSourceManager(), getLangOpts());
        LHS = Actions.ActOnUserOperator(getCurScope(), OpToken.getLocation(),
                                        CodePoint, Args);
```

— the same call `ParseUnqualifiedIdOperator` uses for the declaration
side, which is why U04's UCN and `\N{...}` spellings will need **zero**
work here: every spelling collapses to the same `uint32_t` before it
reaches Sema. Sema never sees a token, a spelling, or a `FunctionDecl`.
`#include "clang/Lex/Lexer.h"` was added to `ParseExpr.cpp` for this.

### 3. Does the stub reach `Sema::LookupOperatorName`? **Yes — deliberately, and it is the second piece of evidence for `IDNS_NonMemberOperator`.**

This is the question the U10 handoff left open ("the `IDNS_NonMemberOperator`
path still has exactly one piece of evidence — U08's gtest"). It now has a
front-end one. `Sema::ActOnUserOperator` builds

```cpp
  LookupResult Operators(*this, NameInfo, LookupOperatorName);
  LookupName(Operators, S);
```

modelled line-for-line on `Sema::LookupOverloadedOperatorName`
(`SemaLookup.cpp:3370`), so every `x ⊞ y` in the new test file goes
through `LookupOperatorName` → `Decl::IDNS_NonMemberOperator` → U08's
`setNonMemberOperator` fix. If U08's fix were reverted, **every**
assertion in `clang/test/Parser/unicode-operator-infix.cpp` would fail,
not just the gtest. U08's 30-second bisection advice is still right, but
it is no longer the only signal.

## The stub, and exactly what it does and does not do

`clang/lib/Sema/SemaExpr.cpp`, immediately after `ActOnBacktickOperator`.
45 lines, of which 20 are a comment block beginning
`// *** U11 STUB -- U13 replaces this body. ***`. The whole of the code:

```cpp
  DeclarationNameInfo NameInfo(
      Context.DeclarationNames.getCXXUserOperatorName(CodePoint), OpLoc);
  NameInfo.setCXXUserOperatorNameLoc(OpLoc);
  LookupResult Operators(*this, NameInfo, LookupOperatorName);
  LookupName(Operators, S);
  UnresolvedSet<8> Fns;
  Fns.append(Operators.begin(), Operators.end());
  ExprResult Fn = CreateUnresolvedLookupExpr(/*NamingClass=*/nullptr,
                                             NestedNameSpecifierLoc(), NameInfo,
                                             Fns, /*PerformADL=*/true);
  return BuildCallExpr(S, Fn.get(), OpLoc, Operands,
                       Operands.back()->getEndLoc());
```

**It does not resolve the callee.** The callee reaching `BuildCallExpr` is
an `UnresolvedLookupExpr` with `PerformADL=true`, which is the whole
anti-DEV-G05 property: nothing picks a `FunctionDecl` before overload
resolution sees the arguments, so a non-viable ordinary-lookup candidate
cannot mask an ADL one. U10's warning ("a stub that quietly resolves is
DEV-G05 arriving one step early") was heeded literally.

**What it therefore gets for free — measured today, not predicted.** All
of these compile and constant-evaluate through the *infix* path with the
stub as written:

| Shape | Result |
|---|---|
| pure ADL — operator only in the operand's namespace | `Adl::A{0} ⊘ Adl::A{0}` == 41 |
| **hidden friend** — reachable by ADL and nothing else | `Adl::Hidden{} ⊛ Adl::Hidden{}` == 45 |
| **augmentation** — a visible, non-viable enclosing-scope candidate does not stop ADL | `Adl3::C{} ⊝ Adl3::C{}` == 48 with a global `operator⊝(Local, Local)` in scope |
| dependent operands, ADL **at instantiation** | `infix(Dep::E{}, Dep::E{})` == 61 |
| `requires(T a, T b) { a ⋀ b; }` | true for `Dep::E`, **false for `int`** |

That is U10's ADL table reproduced on the path U10 could not reach. It is
also, incidentally, the no-built-in-candidates evidence: `1 ⊕ 2` with no
`operator⊕` anywhere is `use of undeclared 'operator⊕'`, not an arithmetic
fallback.

**What it does not do, and U13 must add** — all three are named in the
comment block in the source:

1. **member candidates.** `Mem{1} ⊞ Mem{2}` for a member
   `constexpr int operator⊞(Mem) const` says
   `use of undeclared 'operator⊞'`, because `IDNS_NonMemberOperator` is
   by construction non-member. **This is the single largest gap and it is
   the whole of U13's real work**; the non-member half is already there.
2. the explicit statement that there are **no** built-in candidates (U6).
   True today only by omission — nothing calls
   `AddBuiltinOperatorCandidates` — which is the right behavior arrived at
   for the wrong reason. U13 should make it a stated decision with a test.
3. a dedicated AST node (U16). Today the result is a bare `CallExpr`, so
   the operator token is recoverable only from the callee's
   `DeclarationName`.

## How much of `ParseRHSOfBinaryExpression` was already generalized

**The ratio the step asked for: essentially all of it. One `else if`.**

The backtick work had already done the generalizing, and it had done it
*for a level*, not *for a token* — which is why nothing needed widening:

| Behavior | Who provides it | Widening needed |
|---|---|---|
| the precedence loop, min-prec recursion | upstream, unchanged since forever | none |
| RHS is a **cast-expression** (not an assignment-expression) | upstream: `NextTokPrec <= prec::Conditional` selects `ParseAssignmentExpression`, and 16 is not ≤ 3 | none |
| **left-associativity** | upstream: `isRightAssoc` is `Conditional \|\| Assignment` | none |
| **braced-init-list rejection (D9)** | upstream `RHSIsInitList` + `err_init_list_bin_op`, keyed on `PP.getSpelling(OpToken)` | none — and the diagnostic prints the **glyph**: `initializer list cannot be used on the right hand side of operator '⊞'` |
| `PreferredType.enterBinary(… OpToken.getKind())` | tolerant of any token kind (backtick already passes through it) | none |
| `ConsumeToken()` on the operator | `tok::user_operator` is not "special" | none |
| the AST-building dispatch | **new: 14 lines** | the only hunk |

So the honest statement for the paper is that the *second* user-infix
operator cost one dispatch arm, because the first one paid for the level.
On clean `main` (no backtick) the cost would be larger by exactly the
enumerator and the `isFoldOperator` clause — two lines — and no more; the
loop itself is upstream's and needs nothing.

**One inherited behavior that is a decision, not an accident:**
`Parser::isFoldOperator` excludes `prec::UserInfix`, so `(... ⊞ N)` is
**not** a fold expression. Measured: `error: expected expression` at the
`...`, character-identical to backtick's `(... `f` N)`. Recorded as part
of DEV-U11; it is a U§13 open question, not a defect.

## What changed

Five production files, **+96 / −8**, plus one new test.

| File | Change |
|------|--------|
| `clang/include/clang/Basic/OperatorPrecedence.h` | +11/−2: `Backtick` → `UserInfix`; new `UnicodeOperatorsEnabled` parameter + doc comment |
| `clang/lib/Basic/OperatorPrecedence.cpp` | +13/−2: renamed return, new `case tok::user_operator:` with its rationale comment |
| `clang/lib/Parse/ParseExpr.cpp` | +26/−4: `#include "clang/Lex/Lexer.h"`; `isFoldOperator` rename; 3 call sites gain `getLangOpts().UnicodeOperators`; the 14-line dispatch arm |
| `clang/include/clang/Sema/Sema.h` | +9: `ActOnUserOperator` declaration |
| `clang/lib/Sema/SemaExpr.cpp` | +45: the stub |
| `clang/test/Parser/unicode-operator-infix.cpp` | new, 153 lines, **6 RUN lines** |

**In this repo:** `PLAN.md` (U11 ticked, Status row), `REPLAY.md` U11 row
(the three-way split), `DEVIATIONS.md` **DEV-U11**, this handoff.

## The test file, and why it asserts values rather than AST text

`clang/test/Parser/unicode-operator-infix.cpp`. Six RUN lines:

```
-funicode-operators -fsyntax-only -verify                     # backtick OFF
-funicode-operators -fbacktick -DBACKTICK -fsyntax-only -verify
-funicode-operators -ast-dump | FileCheck
-funicode-operators -fbacktick -DBACKTICK -ast-dump | FileCheck --check-prefixes=CHECK,BT
-funicode-operators -DERRORS -fsyntax-only -verify=err
-DOFF -fsyntax-only -verify=off                               # flag off
```

The two operators are `constexpr int operator⊞(int a, int b) { return 2*a + b; }`
and `operator⊗` returning `3*a + b` — neither commutative nor associative,
so **every grouping in the file has a distinct value and a wrong parse is a
wrong number**, checked by `static_assert` at compile time. Each assertion
carries a comment giving the value the *other* grouping would produce. AST
dumps are there too (the step names them) but they are the weaker evidence.

Covered: the operator parses; left-associativity for one operator
(`1 ⊞ 2 ⊞ 3 == 11`, right-assoc would be 9) and across two at the same
level (`1 ⊞ 2 ⊗ 3 == 15`, right-assoc 11); tighter than `*`
(`2 * 3 ⊞ 4 == 20`, looser would be 16), than `+`, than `==`, than `?:`;
looser than unary with both operands symmetric (`-1 ⊞ -2 == -4`,
`-1 ⊞ 2 == 0`, `!0 ⊞ 1`, `+1 ⊞ +2`, `sizeof(int) ⊞ 0`); explicit
cast-expression operands `(int)1.9 ⊞ (int)2.9`; parenthesised regrouping;
the assignment slot, compound assignment, initializer lists, call
arguments, a non-type template argument, and a dependent template.

**Composability, both directions, which the step insisted on:** RUN lines
1, 3, 5 have `-fbacktick` **off** and carry every assertion above — that is
the "backtick off, Unicode on, still the same level" direction, and it is
free rather than an extra section. RUN lines 2 and 4 add `-fbacktick` and
enable the `#ifdef BACKTICK` block: `1 ⊞ 2 `f` 3 == 23` (right-assoc would
be 15), `1 `f` 2 ⊞ 3 == 17`, `1 ⊞ 2 `f` 3 ⊞ 4 == 50` (a four-term chain
alternating the two spellings), `2 * 3 `f` 4 ⊞ 5 == 86` (the mixed chain
binding tighter than `*`), and an `ast_mixed` dump showing
`BacktickInfixExpr` → `CallExpr f` → `CallExpr operator⊞`.

`-DERRORS` pins three exact texts, all measured:

```
initializer list cannot be used on the right hand side of operator '⊞'   // a ⊞ {1,2}
use of undeclared 'operator⊠'                                            // never declared
expected expression                                                      // a ⊞ ;
```

`-DOFF` pins the unchanged off-flag behavior:
`unexpected character '⊞' U+229E` followed by
`expected ';' after return statement`.

**Structural note for anyone editing it:** the `BT-` directives must stay
**physically last** in the file. `--check-prefixes=CHECK,BT` merges both
prefixes' directives in *file* order and matches them against the dump in
*dump* order; the `#ifdef BACKTICK` block is last in the translation unit,
so its checks must be last in the file.

## Verification evidence

**Build:** `ninja -C /home/sdowney/src/llvm/build-unicode clang` →
`EXIT=0`, 160 edges, **zero** `warning:` lines. The pre-existing
backtick-track `-Wswitch` gap on `BacktickInfixExprClass`
(`StaticAnalyzer/Core/ExprEngine.cpp:1688`) did **not** resurface: U11
touches `Sema.h` and `OperatorPrecedence.h`, neither of which pulls in the
static analyzer's `ExprEngine.cpp`. Still not ours, still not fixed here.

**Targeted lit:** the new file passed on its **first** `llvm-lit` run after
the three `-DERRORS` texts and the two `-DOFF` texts were *measured*
against the built binary rather than guessed. Then all of
`clang/test/Parser` (437 tests, which includes the eight `backtick-*.cpp`
files that the `prec::Backtick` rename could have broken) plus every
unicode-track test and `Driver/fbacktick.c`: **435 passed, 1 unsupported,
1 XFAIL, 0 failed**, 0.96 s.

**Full gate:** `ninja -C $B check-clang` → 54144 discovered / 48250 passed
/ 27 XFAIL / 5853 unsupported / 6 skipped / **8 failed**, 208.2 s test
time.

All 8 are the known `DirectoryWatcherTest.*` cases with
`No space left on device : inotify_add_watch()` — `PLAN.md`'s fifth gate
fact, measured again at gate time: **65,382 of 65,536**
`fs.inotify.max_user_watches` held machine-wide, the identical figure U06
through U10 all recorded. Filtered re-run:

```bash
ulimit -c 0
GTEST_FILTER='-DirectoryWatcherTest.*' $B/bin/llvm-lit -s $B/tools/clang/test
```
→ `EXIT=0`, **54136 discovered / 48250 passed / 0 failed** / 27 XFAIL /
5853 unsupported / 6 skipped; zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines.
190.4 s.

Arithmetic closes exactly: 54136 = U10's 54135 **+1**, 48250 = 48249 **+1**
— the one new lit test and nothing else. **No existing test changed
behavior**, which is the claim that matters for a step that renamed a
precedence enumerator the backtick feature depends on.

## Deviations from the plan / design

**DEV-U11** (`DEVIATIONS.md`), three parts, and the second is the one for
the paper:

1. U§6's "parsing is the *easy* part" becomes a number: one precedence-table
   `case` plus one 14-line dispatch arm, with **no widening** of the
   binary-expression loop.
2. U§7's "Using" sentence describes one unit of work and is really two of
   very different cost. **The non-member half — including full ADL — is
   inherited by writing nothing**; the member half is the entire remaining
   job. That split is the strongest available form of §17.4's normative-ADL
   argument: ADL is what you get by *not* writing code, and DEV-G05 is what
   you get by writing it.
3. A user operator is **not** a fold operator, inherited from backtick's
   `isFoldOperator` exclusion. Not stated anywhere in the design; belongs
   in U§13 as an open question.

No step file instruction was deviated from. Nothing needed a prior-step
fix.

## Discoveries affecting later steps

- **The `CallExpr`'s source range begins at the *operator*, not at the left
  operand.** `-ast-dump` on `a ⊞ b` gives `CallExpr <col:40, col:44>` while
  the first argument's `DeclRefExpr` is at `col:38` — i.e. the node's
  begin-loc is *after* its own first child's. `BuildCallExpr` takes the
  range from the callee, and the synthesized callee sits at the operator.
  **Backtick has the identical artifact** (`BacktickInfixExpr <col:54,
  col:55>` for `a `f` b`), so it is shared, not new — but it will produce
  wrong squiggles under any diagnostic that highlights the whole
  expression, and it is U16's to fix when the real AST node arrives.
- **`BuildCallExpr` takes `MultiExprArg`, not `ArrayRef<Expr *>`.** The
  conversion does not exist; `ArrayRef` costs a build cycle.
- **`use of undeclared 'operator⊠'`** — U07's `DiagnoseEmptyLookup` change
  fires through the *infix* path too, unmodified. A use of an undeclared
  operator is a lookup error and names the operator; U3's "never a lexing
  error" claim now holds for real syntax, not only for explicit calls.
- **The undeclared-operator caret points at the operator token** (`OpLoc`),
  which is the natural place; contrast U10's note that the explicit-call
  form underlines only the `operator` keyword.
- **`getBinOpPrecedence`'s new parameter defaults `false`.** `clang/lib/Format`
  (`FormatToken.h:875`, `TokenAnnotator.cpp:730`) and `SemaConcept.cpp:141`
  therefore see `prec::Unknown` for `tok::user_operator`. That is correct
  today and is U18's decision to revisit, not a bug to discover there.

## Forward notes for U12 — prefix parse in operand position

Written after reading `steps/U12-prefix-parse.md`.

- **Your Sema action already exists and already takes your arity.**
  `Sema::ActOnUserOperator(S, OpLoc, CodePoint, Operands)` is written for
  1 *or* 2 operands and asserts exactly that. From
  `Parser::ParseCastExpression` you need no new Sema entry point and no new
  declaration in `Sema.h` — build `Expr *Args[] = {Operand}` and call it.
  If you find yourself adding `ActOnUserPrefixOperator`, stop: U13 would
  then have to write candidate assembly twice.
- **The code point comes from the same one call**:
  `Lexer::getUserOperatorCodePoint(Tok, PP.getSourceManager(), getLangOpts())`,
  and you must capture it (and the location) **before** `ConsumeToken()`.
- **Position-based disambiguation should need no tiebreak, and here is
  why, concretely.** `getBinOpPrecedence` is consulted only from
  `ParseRHSOfBinaryExpression`, which runs only after an operand has been
  parsed; `ParseCastExpression` runs only in operand position. The two
  functions never both look at the same token. The step file is right that
  needing a tiebreak means something upstream is wrong — and the specific
  thing to check first would be whether `ParseCastExpression` is being
  reached with the operator already consumed.
- **The one wrinkle U08 flagged and nobody has resolved:** default
  arguments. `int operator⊟(int a, int b = 1)` is a *2-operand declaration*
  that is also 1-argument-viable. U08's recommendation stands — select the
  form by declared arity, not by call viability — but U11's stub selects
  nothing at all (it hands both operands to `BuildCallExpr` and lets
  ordinary overload resolution decide), so **as of today `⊟x` would find
  the 2-parameter function via its default argument.** That is a decision
  someone has to make on purpose. It is arguably U13's rather than yours,
  but you will be the first to be able to write the test; write it even if
  you leave the behavior alone, and say which way it went.
- **Glyph budget.** U11 used ⊞ U+229E and ⊗ U+2297 in the test file (both
  long since taken) and ⊠ U+22A0 for the undeclared case. Nothing new was
  consumed. U10's list of what is still free inside `{0x2266, 0x22C4}`
  stands unchanged: U+22A6, U+22A7, U+22AE–U+22BF, U+22C2–U+22C4.
- **Keep the `-fbacktick` RUN line.** Settled convention since U07, and
  REPLAY drops exactly that line on `main`.
- **`(... ⊖ N)` is not a fold expression** (see DEV-U11). If your test file
  wanders near fold syntax, that is the answer.

## Forward notes for U13 — Sema: candidate assembly, ADL, no built-ins

Written after reading `steps/U13-overload-build.md`.

- **Read the stub's comment block first.** It is 20 lines in
  `clang/lib/Sema/SemaExpr.cpp` immediately after `ActOnBacktickOperator`
  and it names your three jobs in order. The step file's item 1 is mostly
  already true; items 2 and 4 are stated-but-unenforced; the member half is
  the real work.
- **Your pure-ADL test will pass before you write anything, and that is a
  problem for the step file's methodology, not for you.** The step says
  "write the pure-ADL test first and watch it fail for the right reason".
  It will **not** fail: pure ADL, hidden friends, augmentation of a
  non-viable ordinary set, and instantiation-time ADL all already work
  through the infix path (measured, table above). The test that *does* fail
  today, and the one you should write first, is the **member** one:
  `struct Mem { int v; constexpr int operator⊞(Mem o) const { return v + o.v; } };`
  → `Mem{1} ⊞ Mem{2}` gives `use of undeclared 'operator⊞'`. Watch **that**
  fail, and watch the ADL cases keep passing while you change things —
  regressing them is the DEV-G05 failure mode and the stub currently
  avoids it by construction.
- **`SemaCXX/unicode-operator-call.cpp` §4 is laid out to be mirrored line
  for line**, as U10's handoff promised: every `operator⊘(a, b)` there has
  an infix twin `a ⊘ b`. That file is your acceptance criterion; the
  equivalence assertion the step asks for (§17.4: the infix form and the
  explicit call select the *same* overload) is cheapest as a pair of
  `static_assert`s over a tag-returning overload set, one of each form.
- **Reusing `CreateOverloadedBinOp` directly looks unlikely** and the step
  file asks you to record why. The obstacle to check first is that it is
  driven by `OverloadedOperatorKind Op` and calls
  `AddBuiltinOperatorCandidates` / `OverloadedOperatorKind`-keyed helpers
  throughout — the same shape U08 hit with `CheckOverloadedOperatorDeclaration`
  (whose first line is `assert(FnDecl->isOverloadedOperator())`). U08's
  answer was a *sibling* function sharing no code, and it made the
  "no existing operator's rules move" claim structural rather than merely
  tested. Consider the same shape here, and if you fork, say what forced it
  — that is a finding about how closed `OverloadedOperatorKind` really is,
  and it belongs in DEVIATIONS and in the paper.
- **Member candidates: what you actually need.** `LookupOperatorName` /
  `IDNS_NonMemberOperator` will never return a member. The member half is
  `LookupQualifiedName` into the left operand's `CXXRecordDecl` with the
  same `getCXXUserOperatorName(CodePoint)` name, then
  `AddMethodCandidate` — `CreateOverloadedBinOp`'s member arm is the model.
  Remember U08's arity formula (handoff §3): declared params **plus one**
  for an `isImplicitObjectMemberFunction()`, with the `dyn_cast<CXXMethodDecl>`
  because the predicate is on `CXXMethodDecl`, not `FunctionDecl`.
- **No built-in candidates is true today only by omission.** Nothing calls
  `AddBuiltinOperatorCandidates`, so `1 ⊕ 2` with no `operator⊕` in scope
  is `use of undeclared 'operator⊕'` and there is no arithmetic fallback.
  Make it a decision with a comment and a test rather than leaving it as an
  accident — it is U6 and it is one of the things EWG will ask about.
- **Do not regress the source range further.** It is already wrong (see
  Discoveries); U16 fixes it properly with a real AST node. If you find
  yourself passing `Operands.back()->getEndLoc()` around, that is my
  `RParenLoc` argument to `BuildCallExpr` and it is the *end* that is
  right; the begin-loc is the broken half.
- **The U11 stub is the thing you delete.** Do not preserve its shape out
  of politeness. The only two things in it worth keeping are the code-point
  identity (never a spelling) and the unresolved callee.

## Open risks / TODOs

- **U04 is still unchecked with all of Phase B and the first Phase C step
  done.** U10's risk stands verbatim: the "all three spellings behave
  identically" claim has no evidence, and U11 adds a second file that will
  need the same two-line UCN addition when U04 lands (a `-DUCN` case in
  `unicode-operator-infix.cpp` asserting `a \N{SQUARED PLUS} b` groups
  identically). If U04 slips past U13 the paper cannot assert
  spelling-independence.
- **The member form does not work at all yet.** That is by design and it is
  U13's, but it means `x ⊞ y` today is *less* capable than
  `operator⊞(x, y)`, which is the reverse of the eventual claim. Nobody
  should quote U11's results as "infix works".
- **Fold expressions** (DEV-U11 part 3) are an unstated design decision
  inherited from backtick. Needs a U-number or a sentence in U§13.
- **Default arguments and form selection** (U08's open item) is now
  *reachable*: as of U11 the stub would let `⊟x` find a 2-parameter
  operator through its default argument. Still nothing tests it. U12/U13.
- **DEV-U07** (the `ShouldParseIf<cplusplus.KeyPath>` C-mode question,
  paired with `-fbacktick`) is still measured-but-unacted; owner U04/U05.
- **`SemaCodeComplete.cpp:1061`** remains the one-line completion-priority
  grouping every step since U06 has left alone. Still flagged for U16 —
  and U11 makes it slightly more urgent, since completion after an infix
  operator is now a reachable state.
- The `-Wswitch` `BacktickInfixExprClass` gap in
  `StaticAnalyzer/Core/ExprEngine.cpp:1688` is unchanged, still a
  backtick-track issue, still not to be fixed on this branch. U13 or U16
  will resurface it the moment they touch a widely-included header.
