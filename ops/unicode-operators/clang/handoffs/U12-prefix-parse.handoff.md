# Handoff — U12 prefix parse in operand position

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `8a84ef99a79c`
  (parent `8ec6095c41fb`, U17)
- **Date / agent:** 2026-08-04

**One production file, +40 lines, all of it one `case` in one `switch`.**
No Sema file, no AST file, no serialization file, no mangling file, no
tooling file. The last unbuilt piece of the expression feature turned out
to be the cheapest step in Phase C, and *why* it was cheap is the finding
(DEV-U15 part 1), not an aside.

## The three answers the step asked for

### 1. Did position alone disambiguate prefix from infix? **Yes, with no tiebreak of any kind.**

Nothing was added that looks ahead, looks at whitespace, looks at a
declaration, or carries suppression state. There is no
`UserOperatorIsPrefix` boolean anywhere and there is nothing analogous to
`BacktickIsOperator` / `GreaterThanIsOperator`.

The structural reason, which is what the paper should say rather than
"it worked":

- `Parser::ParseCastExpression` is reached **only** in operand position.
- `getBinOpPrecedence` — the only place `tok::user_operator` gets a
  precedence — is consulted **only** from `ParseRHSOfBinaryExpression`,
  which runs only after a complete operand has been parsed.

The two functions never look at the same token, so the two productions
cannot both apply. U11's forward note predicted exactly this and it was
right; nothing had to be checked at runtime to make it true.

**The acceptance test passes:** `⊖a ⊖ b` with *both* `operator⊖(int)` and
`operator⊖(int, int)` declared and in scope is
`operator⊖(operator⊖(a), b)`. So does `1 ⊖ ⊖2`, `⊖1 ⊖ ⊖2`, and
`⊖⊖1 ⊖ ⊖⊖2`. The `-ast-dump` for `⊖a ⊖ b` shows an `infix '⊖' U+2296`
node whose first child subtree is a `prefix '⊖' U+2296` node — one code
point, two fixities, one expression, distinguishable in the AST.

### 2. The postfix diagnostic: `error: expected expression`

Measured, not paraphrased:

```
error: expected expression
    2 | int postfix(int a) { return a⊖; }
      |                               ^
```

Identical with a space (`a ⊖ ;`), identical in statement, argument and
return position, and **character-identical to U11's `a ⊞ ;` case and to
plain C++'s `a +;`**. Position makes `a⊖` an *infix* use whose right
operand is missing, and that is what is reported.

It does not mention fixity and cannot: by the time the error is raised the
parser has no way to know postfix was what the author meant. U08 declined
to diagnose at declaration time on the grounds that "a postfix *use* is
diagnosed at the use site" — the use site diagnoses *something*, but not
that. Comprehensible, but weaker than U5's prose implies. DEV-U15 part 3.

### 3. The default-argument corner: it works, and that is a design decision nobody has taken on purpose

The measurement U11 and U13 both deferred:

| Code | Result |
|---|---|
| `constexpr int operator⊟(int a, int b = 1);` then `⊟5` | **accepted**, == 36 — a *two*-parameter operator used in prefix position |
| the same, `2 ⊟ 3` | == 17, infix use unaffected |
| the same, `operator⊟(5)` | == 36 — the explicit call agrees |
| add `operator⊠(int)` beside `operator⊠(int, int = 1)`, then `⊠5` | `error: call to 'operator⊠' is ambiguous` + two `candidate function` notes |

So declared arity does **not** select the form at a use; call viability
does. Two independent earlier choices produce this: DEV-U06(b) waived
[over.oper]p8 (no default arguments on operator functions) — by omission,
not by argument — and `CreateOverloadedUserOp` hands the operand list to
ordinary overload resolution without filtering by declared arity.

**My judgement: leave the behaviour alone and fix the design text, and if
anything is to change it should be the declaration rule, not the use
rule.** The reason is U6/§17.4: the operator form must find exactly what
the explicit call finds, and `operator⊟(5)` finds that function. Filtering
candidates by declared arity inside `CreateOverloadedUserOp` would make
`⊟5` and `operator⊟(5)` select different overload sets, which is the one
equivalence the whole desugaring claim rests on. The honest alternative is
to *reinstate* [over.oper]p8 for user operators — one diagnostic in
`CheckUserOperatorDeclaration`, and then U5's "arity selects the form"
becomes literally true again with no cost to the desugaring. That is a
paper decision, not a Clang one; both options are written up in DEV-U15
part 2. It is now tested either way: `unicode-operator-prefix.cpp` §6 pins
the accepting behaviour and the `-DERRORS` block pins the ambiguity.

## What changed

**Production — one file, +40/−0.**

`clang/lib/Parse/ParseExpr.cpp`, a `case tok::user_operator:` inserted
immediately **before** `case tok::kw_co_await:` in `ParseCastExpression`,
modelled on the `tok::star`/`plus`/`minus` unary group:

```cpp
    assert(getLangOpts().UnicodeOperators &&
           "user-operator token without -funicode-operators");
    if (NotPrimaryExpression)
      *NotPrimaryExpression = true;
    uint32_t CodePoint = Lexer::getUserOperatorCodePoint(
        Tok, PP.getSourceManager(), getLangOpts());
    SourceLocation SavedLoc = ConsumeToken();
    PreferredType.enterUnary(Actions, Tok.getLocation(), SavedKind, SavedLoc);
    Res = ParseCastExpression(CastParseKind::AnyCastExpr);
    if (!Res.isInvalid()) {
      Expr *Arg = Res.get();
      Expr *Args[] = {Arg};
      Res = Actions.ActOnUserOperator(getCurScope(), SavedLoc, CodePoint, Args);
      if (Res.isInvalid())
        Res = Actions.CreateRecoveryExpr(SavedLoc, Arg->getEndLoc(), Arg);
    }
    return Res;
```

Half the 40 lines are the comment block, which states the no-tiebreak rule
as an instruction (*"Do not add one"*) rather than as an observation.

**Nothing else was touched, and that is the measurement.** U11's
`ActOnUserOperator(Scope*, SourceLocation, uint32_t, MultiExprArg)` took
arity 1 already; U13's `CreateOverloadedUserOp` assembles member,
non-member and ADL candidates for one or two operands alike (its `T1` is
`Operands[0]->getType()`, which is the sole operand in the prefix case —
correct per [over.match.oper] for unary operators); U16's
`UserOperatorExpr` stores `NumOperands`, and `getBeginLoc()` already
returned `OpLoc` for the prefix form; `StmtPrinter`'s prefix arm and
`TextNodeDumper`'s `"prefix"` label already existed. Every one of those
worked on the first run.

**Tests — 5 files, +173, plus one new file of 283 lines.**

| File | Change |
|------|--------|
| `clang/test/Parser/unicode-operator-prefix.cpp` | **new**, 283 lines, 6 RUN lines |
| `clang/test/AST/unicode-operator-print.cpp` | +79: a prefix section (§1a), a member prefix `operator⊖()` on `Mem`, `member_prefix`, `dependent_prefix`, and four new `DUMP` groups |
| `clang/test/PCH/unicode-operators.cpp` | +34: prefix `operator⊞(int)`→`Tag<7>`, prefix `operator⊕(int)`, member prefix `Mem::operator⊕()`→`Tag<8>`, `header_prefix`, `header_prefix_tmpl`, body §8, two `CHECK` pairs |
| `clang/test/Modules/unicode-operators.cppm` | +27: the same shape across a module boundary |
| `clang/test/Modules/unicode-operators-odr.cpp` | +33: `SamePrefixBody` (merges silently) and `DifferentFixity` (prefix vs infix body, diagnosed) |

**In this repo:** `PLAN.md` (U12 ticked, Status row), `REPLAY.md` U12 row,
`DEVIATIONS.md` **DEV-U15**, this handoff.

## The new test file

`clang/test/Parser/unicode-operator-prefix.cpp`, 6 RUN lines, the same
shape U11 established:

```
-funicode-operators -fsyntax-only -verify                      # backtick OFF
-funicode-operators -fbacktick -DBACKTICK -fsyntax-only -verify
-funicode-operators -ast-dump | FileCheck
-funicode-operators -fbacktick -DBACKTICK -ast-dump | FileCheck --check-prefixes=CHECK,BT
-funicode-operators -DERRORS -fsyntax-only -verify=err
-DOFF -fsyntax-only -verify=off                                # flag off
```

`⊖` is declared **both ways at the top of the file** — `operator⊖(int)`
returning `3a+1` and `operator⊖(int, int)` returning `100a+b` — and both
are visible for every assertion below. Values again, not AST text: nothing
here is commutative or associative, so a wrong parse is a wrong number
caught by `static_assert`.

Sections: (1) parses and stacks (`⊖1`, `⊖⊖1`, `⊖⊖⊖1`); (2) binds like the
other unary operators — tighter than the user-infix level
(`⊖1 ⊞ 2 == 10`, looser would be 13), tighter than `*` (`⊖2 * 3 == 21`,
looser would be 19), interleaved with `-`/`!`/`~`/`sizeof`, and operand-is-
a-cast-expression (`⊖(int)1.9`, `⊖arr[2]`, `⊖twice(3)`, `⊖fld.v`);
(3) **the acceptance test**, one code point both ways, five expressions;
(4) the ordinary slots (assignment, compound assignment, init-list,
argument, conditional, template argument); (5) member candidates, ADL, a
hidden friend, dependent operands, and a `requires`-expression;
(6) the default-argument corner; (7) `-ast-dump` shapes including
`ast_both` and the member form. `-DERRORS` pins five texts, all measured:

```
expected expression                       // a⊖;   and  a ⊖ ;   and  ⊖;   and  ⊖{1,2}
use of undeclared 'operator⊠'             // ⊠a
call to 'operator⊡' is ambiguous          // the default-argument ambiguity
```

`-DOFF` pins **one** diagnostic and not two:
`unexpected character '⊖' U+2296`, with no follow-on error — unlike U11's
infix `-DOFF` case, because after the bad character `a` is still a
complete expression.

**Structural note, same as U11's:** the `BT-` directives must stay
physically last; `--check-prefixes=CHECK,BT` merges them in file order.

## Verification evidence

**Build:** `ninja -C /home/sdowney/src/llvm/build-unicode clang` →
`EXIT=0`, **16 edges**, **zero** `warning:` lines. U12 touches one `.cpp`
and no header, so neither pre-existing backtick `-Wswitch` gap
(`StaticAnalyzer/Core/ExprEngine.cpp:1688`,
`tools/libclang/CXCursor.cpp:175`) was recompiled or resurfaced. The build
log was grepped rather than trusted to the exit code, per U17's warning.

**Targeted lit:** the new Parser file passed on its **first** run, with
every `-DERRORS` and `-DOFF` text measured against the built binary before
being written down. `AST/unicode-operator-print.cpp` needed one value fix
(`⊖a ⊞ 2 * ⊖b` is `(⊖a ⊞ 2) * ⊖b` == 70, not 22 — the user-infix level is
tighter than `*`, which is easy to forget when adding a *third* binding
strength to a line). `PCH/unicode-operators.cpp` needed the prefix
`operator⊞(int)` moved to sit with the other `⊞` overloads; see
Discoveries. Then `clang/test/{Parser,AST,PCH,Modules}` plus every
unicode- and backtick-track test elsewhere: **2161 discovered, 2136
passed, 22 unsupported, 3 XFAIL, 0 failed**, 11.4 s.

**Full gate:** `ninja -C $B check-clang` → `EXIT=0`

```
Total Discovered Tests: 54164
  Passed: 48278   Unsupported: 5853   Expectedly Failed: 27   Skipped: 6
  Failed: 0
```

194.2 s test time; zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines.

**This is the first unfiltered green gate since U03.** The 8
`DirectoryWatcherTest.*` cases that every step from U06 to U17 had to
filter out **all passed** — the machine's inotify budget had freed up — so
no `GTEST_FILTER` re-run was needed. Read the arithmetic carefully before
comparing against an earlier row:

- discovered 54164 = U17's 54163 **+1** (the one new lit test);
- passed 48278 = U17's 48269 **+9** = that one test **+ the 8 recovered
  `DirectoryWatcherTest` cases**.

So the like-for-like comparison is against U17's *filtered* numbers
(54155 / 48269 / 0), and against those U12 is +9 discovered / +9 passed:
1 new test + the 8 that are now discoverable-and-passing rather than
discoverable-and-failing. **No existing test changed behaviour.**

## Deviations from the plan / design

**DEV-U15** (`DEVIATIONS.md`), three parts, summarized in "the three
answers" above: (1) position alone sufficed and the cost was one `case`;
(2) "arity selects the form" holds for declarations but not for uses,
because DEV-U06(b) waived [over.oper]p8; (3) there is no postfix form and
also no postfix diagnostic.

**No step-file instruction was deviated from.** The step's item 2 was the
one at risk and it did not fire: no tiebreak was needed, so there is no
counterexample to U5 to report. Nothing needed a prior-step fix.

Two things done **beyond** the step file, both because U17's forward notes
asked for them explicitly:

- the prefix cases added to `PCH/unicode-operators.cpp`,
  `Modules/unicode-operators.cppm` and `Modules/unicode-operators-odr.cpp`
  — **the first executions ever of the `NumOperands == 1` serialization,
  import and ODR paths**, which U16 wrote and U17 could only read;
- the prefix section in `AST/unicode-operator-print.cpp`, including the
  `-ast-print` → re-parse → `-ast-print` diff, which now covers `⊖a`,
  `⊖⊖a`, `⊖a ⊖ b`, `⊖a ⊞ 2 * ⊖b`, `⊖(a ⊞ b)`, the member form and two
  template instantiations.

All of it passed on the first run bar the two value/ordering fixes noted
above. The prefix half of the node was correct as written.

## Discoveries affecting later steps

- **`-ast-print` round-trips the prefix form with no parenthesisation
  bugs.** `⊖⊖1`, `⊖(1 ⊞ 2)`, `⊖-1`, `-⊖1` and `⊖1 ⊖ 2` all print exactly
  as written and re-parse to the same tree (the reprint `diff -u` in
  `AST/unicode-operator-print.cpp` is the check).
- **The prefix source range is right where the infix one is wrong.**
  `⊖a` dumps as `UserOperatorExpr <col:32, col:35>` — begin at the
  operator, end at the operand — because `getBeginLoc()` returns `OpLoc`
  when `isPrefix()`. The infix begin-loc problem U11 recorded does not have
  a prefix analogue.
- **A new `Tag<N>` instantiation in `PCH/unicode-operators.cpp` can break
  the PCH diff by *ordering*.** Implicit class-template specializations
  print in different orders in the `-include` run and the `-include-pch`
  run. Adding `constexpr Tag<7> operator⊞(int)` after the `⊗`/`⨁`
  declarations produced a pure-reordering diff (`Tag<7>` printed after
  `Tag<5>` directly and after `Tag<3>` from the PCH); moving the
  declaration up beside the other `⊞` overloads made both orders agree.
  This is the same family as U17's "fields print last after a PCH" trap:
  **declare a new `Tag<N>` next to its siblings, not at the end.**
- **`StmtProfiler::VisitUserOperatorExpr` does not hash the arity** — only
  the code point — and does not need to: the semantic forms of a prefix and
  an infix use are a one-argument and a two-argument call, so they differ
  in their children. `DifferentFixity` in the ODR test is diagnosed. Said
  in the test's comment so nobody "fixes" the profiler.
- **`PreferredTypeBuilder::enterUnary` is tolerant of an unknown token
  kind**: `getPreferredTypeOfUnaryArg` switches on the kind with a
  `default:` returning `QualType()`, so passing `tok::user_operator`
  costs nothing and needs no new arm. Code completion after a prefix user
  operator simply offers no preferred type. (`SemaCodeComplete.cpp:1061`,
  the completion-priority grouping every step since U06 has left alone, is
  *still* unclaimed and is now reachable from one more position.)
- **`⊖{1, 2}` is `expected expression`, not the D9 braced-init-list
  diagnostic.** The infix path has a dedicated
  `err_init_list_bin_op` check keyed on `RHSIsInitList`; the prefix path
  has no equivalent because a `{...}` in operand position never becomes an
  operand at all. Different text, same rejection — worth knowing before
  someone tries to make them match.

## Forward notes for U14 — semantics sweep

Written after reading `steps/U14-semantics-tests.md`. U16's and U17's
forward notes for U14 are still accurate; these add to them.

- **Item 8 ("prefix-form equivalents") is now unblocked and is the only
  item U12 changes.** U13, U16 and U17 all scoped themselves to infix and
  said so; you are the first agent who does not have to. The prefix
  equivalents that are *not* already covered by
  `Parser/unicode-operator-prefix.cpp` §5 are the interesting ones:
  `noexcept(⊖a)`, a throwing prefix operator, a **deleted** prefix
  operator, a prefix operator returning a reference used as an lvalue
  (`(⊖a) = 7`), `consteval`, explicit-conversion operands, and the
  CodeGen sibling. Do not restate my grouping/ADL/member assertions — read
  that file first; it is a *parser* test and deliberately stops at
  "which function got called", not "what the language does to the call".
- **The `const`/ref-qualification half of item 1 has a prefix-only
  wrinkle**: a member prefix operator has *no* parameters, so its only
  operand is the implicit object argument. `&&`-qualified and
  `const`-qualified member prefix operators are the cheapest way to test
  value-category propagation through the operator syntax, and nothing
  tests them today.
- **Item 2's ambiguity case has a ready-made prefix instance** you may
  want to reuse or reference rather than reinvent: the default-argument
  ambiguity in `unicode-operator-prefix.cpp`'s `-DERRORS` block
  (`operator⊡(int)` vs `operator⊡(int, int = 1)`, `⊡5` →
  `call to 'operator⊡' is ambiguous`). It is a genuine
  [over.match.best] ambiguity reached through operator syntax.
- **The default-argument corner is now a *semantics* question, not a
  parsing one, and it is arguably yours to finish.** DEV-U15 part 2 lays
  out the two options; if the design doc takes the "reinstate
  [over.oper]p8" option, the fix is one diagnostic in
  `CheckUserOperatorDeclaration` (U08's function,
  `SemaDeclCXX.cpp:17148`) and my §6 flips from an accepting test to an
  error test. Do not make that call unilaterally — but do flag it, because
  U14 is the last step that can cheaply notice it.
- **Item 3's second constant evaluator is still unexercised**, unchanged
  from U17's note: `-fexperimental-new-constant-interpreter` on a
  `constexpr` user-operator case is a one-line RUN test of
  `ByteCode/Compiler.cpp`'s `VisitUserOperatorExpr`. Now applies to the
  prefix form too, which has *never* been through it.
- **Item 9 has a fourth worked example**: `unicode-operator-prefix.cpp`
  runs its whole body with `-fbacktick` off and again with it on, and the
  `#ifdef BACKTICK` block shows a prefix user operator as the operand of a
  backtick infix (`⊖2 `f` 3 == 38`). Diffs are still stronger than paired
  compilations; U16's and U17's diff RUN lines remain the model.
- **A member operator found through a *dependent base* is still not tested
  anywhere**, for either fixity. U17 flagged it; still true.

## Forward notes for U15 — precedence and associativity sweep

Written after reading `steps/U15-precedence-tests.md`.

- **Read `clang/test/Parser/unicode-operator-infix.cpp` (U11) and
  `clang/test/Parser/unicode-operator-prefix.cpp` (U12) before writing a
  line.** Between them, items 1–7 and 10 of your list are *already*
  asserted, most of them by value rather than by dump. Concretely: your
  items 1, 2, 3, 4, 6 (all three), 7 (cast and postfix operands) and 10
  are in the infix file; your **item 5 is the whole of my §2 and §3**;
  item 8's `a ⊞ b `f` c` / `a `f` b ⊞ c` pair is in the infix file's
  `#ifdef BACKTICK` block and item 9 is every non-`BACKTICK` RUN line in
  both files. **Your step is mostly a consolidation and a re-presentation,
  not a discovery** — and that is worth saying plainly in your handoff,
  because it is evidence for U§12's "one level, banked once" argument
  rather than a reason to skip the step.
- **What is genuinely missing and worth your file existing for:**
  `*p ⊞ *q` and `a.m ⊞ b.m` (item 7's pointer/member-access half — the
  infix file has `(int)x`, `f(a)` and `arr[i]` but not these);
  `a ⊞ b, c` (the comma-operator relation — the infix file tests the
  *argument* comma, which is a different thing); the `a ⊞ b ⊗ c ⊞ d`
  four-term two-operator chain; and a **three-way** mixed chain
  `⊖a ⊞ b `f` c` exercising prefix, Unicode infix and backtick infix in
  one expression, which nothing tests today.
- **The tag-returning overload set reads much better than `-ast-dump` for
  associativity**, and the step file offers you the choice. U13, U15's
  siblings, U16 and U17 all use it; `PCH/unicode-operators.cpp`'s `Tag<N>`
  idiom is the cleanest copy. A grouping claim becomes
  `static_assert(__is_same(decltype(a ⊞ b ⊗ c), Tag<4>))`, which survives
  AST-dump churn that a `CHECK-NEXT` ladder does not.
- **Values are stronger still, and both existing files use them**: make
  every operator non-commutative and non-associative and a wrong grouping
  becomes a wrong number. `2a+b`, `3a+b`, `100a+b` and `5a+b` are the four
  already in use; keep them so the numbers in the two files can be
  compared.
- **The one grouping most likely to surprise you** — it caught me — is
  that the user-infix level is tighter than `*`, so `⊖a ⊞ 2 * ⊖b` is
  `(⊖a ⊞ 2) * (⊖b)` and not `⊖a ⊞ (2 * ⊖b)`. Three binding strengths in
  one line (prefix > user-infix > `*`) is the shape that trips people up,
  and U§6's table does not have an example with all three. Add one.
- **`(... ⊖ N)` is not a fold expression** (DEV-U11 part 3), for the
  prefix spelling too — `isFoldOperator` excludes `prec::UserInfix`
  entirely. If your sweep wanders near fold syntax, that is the answer,
  and it is still an unstated design decision needing a U-number.
- **A failure in your sweep is a U11/U12 bug**, per your step file. For a
  *prefix* failure the first thing to check is whether
  `ParseCastExpression` is being reached with the operator already
  consumed — that is the only shape in which the no-tiebreak property
  could break, and it is what my comment block in `ParseExpr.cpp` warns
  against.
- **Glyph budget.** U12 used ⊖ U+2296, ⊞ U+229E, ⊕ U+2295, ⊘ U+2298,
  ⊗ U+2297, ⊟ U+229F, ⊠ U+22A0, ⊡ U+22A1 in the new Parser file and
  ⊖/⊕/Tag-carrying ⊞ in the four modified files. Nothing new was consumed
  from U10's free list, which stands unchanged: U+22A6, U+22A7,
  U+22AE–U+22BF, U+22C2–U+22C4.

## Open risks / TODOs

- **The default-argument corner is measured but undecided.** DEV-U15 part
  2 states both options and recommends the doc change; nobody has taken
  the decision. It is live design surface for the paper, and it is the one
  place where U5's headline sentence is not literally true.
- **The postfix diagnostic is the generic one.** If the paper wants to
  claim a good error for a postfix attempt, it will have to be built —
  and it cannot be built in the parser, because the information is gone by
  then. The realistic place would be a note attached to the
  missing-operand error when the token before `;` is a `tok::user_operator`
  with a one-parameter overload visible, which is exactly the kind of
  declaration-dependent parsing U3 forbids. Probably: say what it does.
- **U04 is still unchecked**, now with *all* of Phases B, C and D done
  except the sweeps. The "all three spellings behave identically" claim
  still has zero evidence, and U12 adds a fifth file that will want the
  same `-DUCN` addition (a prefix `\N{CIRCLED MINUS}a` case). It is the
  oldest unpaid debt in the plan and it is now blocking U18 as well.
- **DEV-U07** (`ShouldParseIf<cplusplus.KeyPath>` for both flags) is still
  measured-but-unacted; owner U04/U05.
- **The `-Wswitch` `BacktickInfixExprClass` gap remains open in two
  files**, untouched and not to be fixed on this branch.
- **`clang/lib/CIR/` is still untouched and uncompiled**; the prefix form
  makes no difference to that, since the node is the same node.
- **The inotify/`DirectoryWatcherTest` artifact did not fire this time.**
  Do not conclude it is gone — the budget was at 65,381 of 65,536 again
  when this handoff was written. Keep the filtered re-run in your pocket.
