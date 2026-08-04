# Handoff — U21 postfix feasibility probe

- **Status:** DONE (probe gate met; a written finding exists and reaches a
  recommendation)
- **Branch / commit:** **no code landed on any named branch.**
  `unicode-operators-experiment` is unchanged at `06735e8df66d`;
  `unicode-operators-upstream` is unchanged at `44299aae010d`. A throwaway
  prototype was built, measured and reverted; it is preserved on scratch
  branch **`unicode-postfix-probe-scratch` @ `c929b9ee000d`** (1 file, +68,
  title `[unicode][PROBE-DO-NOT-MERGE]`) in the experiment worktree, checked
  out nowhere. Plan-repo commit is `ops:`-prefixed.
- **Date / agent:** 2026-08-04

## The two-sentence version

Postfix **is** implementable without whitespace sensitivity or backtracking —
a greedy-infix rule cost **68 lines in one file, one `NextToken()` call**, and
it parses the witness expressions — so U5's "postfix is ambiguous" premise is
too strong. But it costs four things the design had not priced, the largest of
which lands on *every* user of the feature and not just on postfix users, and
the rule turns out to be a **pure extension** of the v1 grammar, so v1 can
decline postfix for free and should.

## What changed

**Nothing in the LLVM tree, on either named branch.** The measurement was made
with a prototype in `clang/lib/Parse/ParseExpr.cpp` — a file-static
`userOperatorTerminatesOperand(tok::TokenKind)` plus one
`case tok::user_operator:` in `Parser::ParsePostfixExpressionSuffix` — built
(`ninja -C build-unicode clang` → `EXIT=0`, 16 edges), run on the witnesses,
committed to the scratch branch, and then reverted by checking the worktree
back out to `unicode-operators-experiment` and rebuilding (`EXIT=0`, 6 edges).

**In this repo:**
- `docs/unicode-operators.md` — new **§13.1 "Postfix operators — the price,
  measured (U21)"**, written to drop into the paper; a new U§13 bullet
  pointing at it; and **U5's rationale in the decisions log amended** from
  "declining postfix eliminates the ambiguity" to "postfix is a pure
  extension we can decline for free", with the four prices.
- `ops/unicode-operators/clang/DEVIATIONS.md` — **DEV-U23**.
- `ops/unicode-operators/clang/REPLAY.md` — new closing section
  "U21 — probe only, nothing landed" (**not** a row in the classification
  table; the U-rows were left alone as U20 instructed).
- `ops/unicode-operators/clang/PLAN.md` — U21 ticked, Status row appended.
- this handoff.

## Verification evidence

**Tree state, which is the gate for a probe:**

```
cd /home/sdowney/src/llvm/unicode
git status --porcelain          -> (empty)
git log --oneline -1            -> 06735e8df66d [unicode] U18: clang-format
llvm-lit -s clang/test/{Parser,SemaCXX,AST,CodeGenCXX,Lexer}/unicode-operator*
                                -> 15 discovered / 15 passed / 0 failed
```

No `check-clang` was required or run: no compiler file changed on any named
branch. `unicode-operators-upstream` was never checked out.

**§1 of the step file, claim by claim.** Paths are on the experiment branch.

| # | Claim | Verdict | Evidence |
|---|-------|---------|----------|
| 1 | `operator++` disambiguates by position only, which is free *because `++` has no infix form* | **Confirmed** | Prefix is `ParseExpr.cpp:1202` (`ParseCastExpression`); postfix is `ParseExpr.cpp:2197` (`ParsePostfixExpressionSuffix`) — two different functions, reached from two different grammar positions, with no lookahead in either. Nothing tests what follows. |
| 2 | The `int` dummy convention cannot be reused, because U2 admits `operator⊞(T, int)` as infix | **Confirmed** | The `++` rule is `SemaDeclCXX.cpp:17134-17143` (`CheckOverloadedOperatorDeclaration`, [over.inc]p1, last param must be `int`). `CheckUserOperatorDeclaration` at `SemaDeclCXX.cpp:17148` deliberately does not inherit it and says so at `:17182-17187`. |
| 3 | The tag disambiguates declarations, the ambiguity is at the use site, U3 forbids consulting declarations — so the tag may be inert for parsing | **Confirmed, and resolved** | Greedy-infix decides fixity from one token of lookahead with no lookup, so U3 survives; the tag does its work in Sema, exactly as `std::strong_ordering` does for `<=>`. |
| 4 | Witness `a ⊕ * b`, `a ⊕ - b`, `a ⊕ & b`; "resolving it needs lookahead over an arbitrary-length operand" | **Refuted in both halves** | (a) One token suffices — see the prototype. (b) The witness set is **not** "prefix-unary ∩ infix-binary". It is every token that can begin a cast-expression, which also contains `++ -- ( [` and — decisively — **`&&`** (`ParseExpr.cpp:1375`, GNU address-of-label, ungated in all modes) and `^` (`:1689`, blocks). |

**The prototype's measured parses** (`⊖`, `⊙` unary; `⊞`, `⊗` binary):

```cpp
a ⊖;          // postfix, resolves                            OK
(void)(a ⊖);  // postfix                                      OK
(a ⊖) ⊙;      // chained postfix through parens               OK
a ⊖ / a;      // postfix, then binary /                       OK (error is about /)
a ⊞ b;        // infix, unchanged                             OK
a ⊖ ⊙;        // -> "expected expression" at the ';'
a ⊖ (b);      // -> infix; "requires 1 argument, but 2 were provided"
a ⊖ * b;      // -> infix; "indirection requires pointer operand"
a ⊖ && b;     // -> infix; "use of undeclared label 'b'"
```

**The regression the design had not priced.** With the prototype in place,
`llvm-lit` over the Unicode tests goes 12/12 → 9/12, and **all four changed
cases are the same shape**: a missing right operand stops being a parse error.

```
Parser/unicode-operator-infix.cpp:122      a ⊞ ;
  expected: "expected expression"
  actual:   "no matching function for call to 'operator⊞'"
            + note "requires 2 arguments, but 1 was provided"
Parser/unicode-operator-prefix.cpp:228,231 a⊖;  /  a ⊖ ;   (same)
Parser/unicode-operator-precedence.cpp:322 (... ⊞ N) fold
  expected: "expected expression"
  actual:   "no matching function" + "expected ')'"
            + "expression contains unexpanded parameter pack 'N'"
```

**Every one of the four was an `expected-error` case.** No well-formed
program changed meaning — which is the forward-compatibility result below.

**The Itanium finding, measured against two compilers.** The ABI distinguishes
prefix from postfix in the `<expression>` production by a trailing `_`
(`llvm/include/llvm/Demangle/ItaniumDemangle.h:5177`, implemented by the
demangler at `:5223-5229`). Clang's mangler does not emit it —
`ItaniumMangle.cpp:5600-5606` mangles any `UnaryOperator` as
`mangleOperatorName(getOverloadedOperator(opcode), /*Arity=*/1)`, and
`:2808` gives `pp` for `OO_PlusPlus` regardless of pre/post:

```cpp
struct A { int operator++(); double operator++(int); };
template <class T> void f(decltype(++T{})) {}
template <class T> void f(decltype(T{}++)) {}
```
```
clang (build-unicode): error: definition with same mangled name
                       '_Z1fI1AEvDTpptlT_EE' as another definition
g++ 15.2.0:            _Z1fI1AEvPDTpp_tlT_EE   and   _Z1fI1AEvPDTpptlT_EE
```

A live cross-vendor divergence, independent of this feature, found by the
probe. For user operators the analogous production is
`cl on v<arity><source-name> <args> E` — measured on a real dependent
expression as `_Z1gI1AEvDTclonv18op_u2296tlT_EEE` for prefix `⊖T{}` — which a
postfix use would reproduce exactly, and which has no `_` slot.

## Deviations from the plan / design

**DEV-U23**, three corrections plus one unbudgeted cost. Summarised above and
in the ledger; the two that change what the paper says:

1. **U5's premise is too strong.** "Declining postfix eliminates the
   prefix/postfix ambiguity" implies the ambiguity is why. It is resolvable,
   in 68 lines. The honest reason is price, and the price is now itemised.
2. **U20's forward-note (2) is right about the collision and wrong about its
   inevitability.** Prefix and postfix do share an arity, so `v1op_uXXXX` is
   ambiguous *if* postfix is modelled as a fixity bit. Model it the way
   `operator++(int)` does — synthesize the `std::postfix` tag as a real first
   argument, `SemaOverload.cpp:15267-15275`'s `IntegerLiteral 0` trick
   generalized — and the postfix call becomes 2-ary, mangles distinctly, and
   overload-resolves with no new mechanism. U20's forward-note (1) stands
   unchanged: `UserOperatorExpr` would still need a fixity field, because with
   the tag synthesized `NumOperands` is 2 for both infix and postfix.

## Discoveries affecting later work

- **Postfix-ness has no representation in Clang at all.** There is no
  `isPostfix()` on `CXXOperatorCallExpr` and no "can this token begin an
  expression" predicate anywhere in the tree (both greps come back empty).
  Every consumer re-derives fixity from `OO_PlusPlus`/`OO_MinusMinus` plus an
  argument count: `ExprCXX.cpp:694` (`getSourceRangeImpl`),
  `StmtPrinter.cpp:2163` (`VisitCXXOperatorCallExpr`),
  `TreeTransform.h:18256` (`isPostIncDec`), and 54 mentions across 24 files
  in total. **The fourth consecutive "sibling, not widening" result** after
  U08, U13 and U16 — and the first where the closed concept is not merely
  closed but *absent*.
- **`ParseCastExpression`'s dispatch is a pure token-kind switch** — 135 case
  labels, `default:` at `ParseExpr.cpp:1736-1738` setting `NotCastExpr` with
  no lookahead. So "can this token begin a cast-expression" *is* a one-token
  test in principle. But several of those labels branch on `LangOpts` inside
  the case (`tok::caretcaret` on `Reflection` at `:1364`, `tok::l_square` on
  `CPlusPlus`/`ObjC` at `:1711`), so a predicate derived from the compiler
  would make **fixity depend on the dialect**. A hand-curated normative token
  list is the only specifiable form, and it is a maintenance liability: `^^`
  entered the switch during this project.
- **`isNotExpressionStart()` is not the predicate anyone wants.** It is
  negative, and its fallback arm calls `isKnownToBeDeclarationSpecifier()`
  (`Parser.h:4371`), which calls `isCXXDeclarationSpecifier` — i.e. tentative
  parsing with unbounded lookahead. U20's forward note pointed at these
  thirty lines and the answer is in them: do not build the rule on it.
- **The insertion point is `ParsePostfixExpressionSuffix`**
  (`ParseExpr.cpp:1805`), not `ParseRHSOfBinaryExpression`. That is where
  `++`/`--` already live, it runs before any precedence is considered, and its
  `default: return LHS;` currently swallows `tok::user_operator`. Note the
  neighbouring `AllowSuffix == false` recovery at `:1751-1784`
  (`err_postfix_after_unary_requires_parens`) — a postfix user operator would
  have to join that switch too.
- **The library price, for the routing argument.** `std::strong_ordering`'s
  compiler-known machinery is `ComparisonCategories.{h,cpp}` = **452 lines**,
  `Sema::CheckComparisonCategoryType` (`SemaDeclCXX.cpp:12233`, ~90 lines with
  its own `InvalidSTLDiagnoser`), and **26 files** that know the name. That is
  what "compiler-known tag type" costs one implementation.

## Recommendation

**Decline postfix for v1; keep it as a v2 candidate alongside combining
marks.** Not because it cannot be done — the prototype does it — but because:

- greedy-infix **only ever reinterprets programs v1 rejects**. It fires when a
  user operator is followed by a token that cannot begin a cast-expression,
  and v1 requires a cast-expression there. Structural, and measured: the only
  behaviour that changed was diagnostics on already-ill-formed code. So
  declining costs nothing later, and **fixity stays user-declarable in both
  v1 and v2**, which is the constraint the whole question exists to protect;
- it costs the missing-right-operand diagnostic for *every* user of the
  feature, measured as four negative tests, two of them fold cascades;
- the token list is normative, hand-curated, and dialect-sensitive, which
  reopens U9's invariant that a parse depends on nothing but the expression;
- it reopens U8/ABI with a cross-vendor mangling change (or forces the
  synthesized-tag model, which is the better design but is still new);
- and a compiler-known `std::postfix` adds **LEWG** to a paper already routed
  to SG16, EWG/CWG and the ABI group — which D13's own bundling rule says
  keeps it out of v1.

## Does DEV-04's argument transfer?

Asked by the step file; the answer is **partly, and the split is the useful
part**.

- **It transfers to the operand-collision warts.** `a ⊖ * b` is
  token-identical to a use whose infix reading is already blessed — it is the
  same greedy-operand preference D2/§4 adopted for `-a ⊞ -b` == `⊞(-a, -b)`.
  A diagnostic would have to fire on the blessed construct, which is exactly
  DEV-04's contradiction. Parentheses are the answer, as they are for D3.
- **It does not transfer to the chained-postfix wart.** `a ⊖ ⊙` is not a
  silently-different parse between two well-formed readings; it is a hard
  error. DEV-04's "cannot be diagnosed" does not apply — the parser knows it
  has just taken a user operator as infix and hit a non-operand, so a
  "did you mean `(a ⊖) ⊙`?" note is available. That makes it QoI, which is a
  *better* position than DEV-04's, and the paper should say so.
- **It has nothing to say about the third category.** Dialect-dependent
  fixity (`^^`, `[`, `^`, `@`) is not two readings of one token sequence; it
  is one reading that changes with a compiler flag. DEV-04's frame does not
  reach it, and it is the strongest objection to the rule.

## Closing the plan (U21 is the last step)

**What the plan established.** Twenty-two steps, U00–U21, on a design that was
entirely *Proposed* when it started:

- **It is implementable, and the cost is now a number.** 15 upstream commits,
  **109 files, +7073/−18** on pristine trunk (compiler proper: 77 files,
  +1940/−18), gating at clean-`main` baseline **+72 discovered / +72 passed /
  0 failed** (U20). Flag-off is byte-identical to upstream — diagnostics,
  `-E` and `-emit-llvm` — measured, not argued.
- **It is separable from backtick, executed rather than audited.**
  `git diff upstream/main..unicode-operators-upstream | grep -i backtick`
  returns nothing; the entire coupling is one precedence level, and 98.5 % of
  hunks survived onto clean `main` (U19/U20, DEV-U21/U22).
- **The character-set question is closed and frozen**: 1381 code points, 32
  ranges, 256 bytes, pinned to Unicode 17.0, with U1 ∩ XID = ∅ measured
  against UCD 17.0 (U02), and UCN/`\N{...}` spellings forming operator tokens
  (U04, reversing the original no-UCN rule).
- **The recurring implementation result** is that every closed operator
  concept in Clang costs a *parallel* mechanism, never a widened one — U08's
  declaration checker, U13's overload builder, U16's AST node, and now U21's
  absent fixity. That is the sentence the implementation section should open
  with, and it is also why the relaxations provably cannot leak into
  `operator+`.
- **Parsing was the easy part, as U§6 predicted**, and U18 showed the
  formatter is not merely cheaper than backtick's but better behaved.

**What remains open for the paper author.**

- **U8 is still `Proposed — open (ABI)`**, now with two reasons rather than
  one: U20's (the replay branch makes the prototype scheme look settled) and
  U21's (a first-class `<operator-name>` production needs room for a fixity
  marker `v <digit> <source-name>` does not have). The Clang/GCC `pp`/`pp_`
  divergence is worth reporting upstream on its own merits.
- **Open deviations to reconcile into `docs/unicode-operators.md`:**
  DEV-U15 through DEV-U23. U21 wrote its own §13.1 and amended U5, so DEV-U23
  is partly reconciled already; the rest are not.
- **U§6 still owes a sixth worked example** (`⊖a ⊞ 2 * ⊖b`) and **U§13 still
  owes the fold decision** — unchanged since U19.
- **The replay branch is not pushed anywhere.** It exists only in
  `/home/sdowney/src/llvm/unicode-upstream`. It is the paper's
  implementation-cost number; push it before that worktree is reused.
- **Still uncovered on both branches:** the `lldb` switch arm is
  compile-unverified, and `clang/lib/CIR/`'s `CXXRewrittenBinaryOperator` site
  set is untouched.
- **Housekeeping:** `unicode-postfix-probe-scratch` @ `c929b9ee000d` can be
  deleted at any time; it loses only the reproduction of §13.1's measurements.
  `build-unicode-upstream` likewise.

**There is no next step.** The plan is complete.
