# Open decisions — the questions that need the author

Five questions that the implementation has **measured** and that no
implementer can settle. Each has a page below with the same five parts: the
question, what was measured, the options, the cost of each, and a
recommendation. Four of them have implementation consequences, so they gate
[implement-decisions](../ops/completion/steps/implement-decisions.md); all
five gate what the two papers may claim.

This file is written by
[decision-brief](../ops/completion/steps/decision-brief.md). **The answers get
recorded here**, dated, with the author's reason wherever it differs from the
recommendation — that record is what
[reconcile-declaring-using](../ops/completion/steps/reconcile-declaring-using.md)
and [unicode-paper](../ops/completion/steps/unicode-paper.md) cite.

Three further open items are deliberately **not** here: the ABI and mangling
question is [mangling-abi](../ops/completion/steps/mangling-abi.md)'s, the
member/non-member operand sequencing question
([operand-sequencing](../ops/unicode-operators/clang/DEVIATIONS.md#operand-sequencing))
is a CWG question with no implementation consequence and is written up by
[reconcile-declaring-using](../ops/completion/steps/reconcile-declaring-using.md),
and U§6's missing sixth worked example is a two-line doc sync owned by
[reconcile-remainder](../ops/completion/steps/reconcile-remainder.md).

## Summary — answer these five

| # | Question | Recommendation | Implementation consequence |
|---|---|---|---|
| 1 | [prefix-arity-selection](#prefix-arity-selection) — may a defaulted trailing parameter make an infix-declared operator usable in prefix position? | **Keep [over.oper]p8 waived.** Document that arity selects the form at the *declaration* and position selects it at the *use*, and that the two are independent. | **none** (doc only) |
| 2 | [over-oper-restrictions](#over-oper-restrictions) — may a user operator be a static member function? | **Keep rejecting it**, and state the reason the prototype could not: a static member names neither of the two spellings the desugaring equivalence is defined over. | **none** (doc only) |
| 3 | [fold-over-user-infix](#fold-over-user-infix) — may a user-introduced infix operator be a fold operator? | **No, for both features, in v1.** State it as a decision with its price, not as an omission. | **none** (already the behaviour; a one-line guard to keep) |
| 4 | [postfix-operators](#postfix-operators) — are postfix user operators declined permanently, or declined for v1? | **Declined for v1, not foreclosed.** Carry U§13.1's four prices and the forward-compatibility result into the paper. | **none** (doc only) |
| 5 | [dependent-template-operator-id](#dependent-template-operator-id) — `t.template operator⊞<int>(0)` on a dependent object expression is rejected; fix it or reword the word "anywhere"? | **Reword now; report upstream separately.** The reword is one clause; the fix is upstream's and is not this proposal's to make. | **none** here (the upstream report is [upstream-triage](../ops/completion/steps/upstream-triage.md)-shaped work) |

Every recommendation above is "change no code". That is a result rather than
a convenience, and it is worth reading as one: four of these five were logged
as open because the design document did not *argue* for what the prototype
does, not because the prototype does the wrong thing. The work they generate
is in the design doc and the papers. Question 5 is the exception in kind — it
is the only one where a claim in the design is false as written.

If you disagree with any of them, the page below says what the disagreement
costs and which branches it touches, so
[implement-decisions](../ops/completion/steps/implement-decisions.md) can be
scoped from this document alone.

**Branch vocabulary**, used throughout: the Unicode feature lives on
`unicode-operators-experiment` (`~/src/llvm/unicode`) and
`unicode-operators-upstream` (`~/src/llvm/unicode-upstream`); the backtick
feature lives on `backtick-trunk` (`~/src/llvm/backtick-trunk`) and
`backtick-23` (`~/src/llvm/backtick`), and in GCC on `backtick`
(`~/bld/gcc/gcc-backtick`). A change to a Clang feature must land on **both**
of that feature's branches.

---

## prefix-arity-selection

Ledger entry:
[prefix-arity-selection](../ops/unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection).
Decided jointly with [over-oper-restrictions](#over-oper-restrictions) — they
are the same waiver seen from two sides, and answering them apart produces an
incoherent rule.

### The question

If a user declares `constexpr int operator⊟(int a, int b = 1)`, may `⊟5` —
one operand, prefix position — call it?

### What was measured

From
[prefix-arity-selection](../ops/unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection),
found by `U12`:

> **"Arity selects the form" is true of declarations but not of uses, and
> [over-oper-restrictions](../ops/unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions)(b)
> is why.** [over.oper]p8 forbids default arguments on operator functions
> precisely so that declared parameter count fixes fixity;
> [over-oper-restrictions](../ops/unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions)(b)
> waived it for user operators, and `CheckUserOperatorDeclaration` checks only
> arity. Measured: with `constexpr int operator⊟(int a, int b = 1)` and
> nothing else, `⊟5` is **accepted** and calls it, == 36 — a two-parameter
> operator used in prefix position. Add a genuine prefix overload and `⊠5` is
> `call to 'operator⊠' is ambiguous`, the ordinary ambiguity for `f(x)` given
> `f(int)` and `f(int, int = 1)`.

Two further measurements from the same row matter to the answer. First, the
row is explicit that this must not be fixed in the parser:

> This is not a leak and it should not be "fixed" in the parser:
> [candidate-assembly](unicode-operators.md#candidate-assembly)/§17.4 require
> the operator form to find exactly what the explicit call `operator⊟(5)`
> finds, so filtering candidates by declared arity would break the equivalence
> that is the whole desugaring claim.

Second — and this is the reason it is a question rather than a footnote —

> Note the waiver was arrived at by *omission* rather than by argument.

The waiver is visible in the prototype as a comment and nothing else
(`SemaDeclCXX.cpp`, `Sema::CheckUserOperatorDeclaration`, the closing
paragraph): *"variadic parameter lists and default arguments are all allowed
here precisely because nothing rejects them for an ordinary function. Only
arity is special."*

### The options

**(a) Keep [over.oper]p8 waived.** A user operator may have default
arguments. A defaulted trailing parameter therefore makes an infix-declared
operator usable in prefix position, and the design says so explicitly:
declared arity selects the *form* at the point of declaration; grammatical
position selects it at the point of *use*; the two are independent, and a
declaration whose parameter list is satisfiable at both arities is usable at
both. Ambiguity between such a declaration and a genuine prefix overload is
the ordinary ambiguity of `f(int)` against `f(int, int = 1)`, with the
ordinary diagnostic.

**(b) Reinstate [over.oper]p8 for user operators.** A user operator may not
have default arguments, and [unary-forms](unicode-operators.md#unary-forms)'s "arity selects the form" becomes
literally true of uses as well as declarations. Costs one diagnostic at
declaration time; the existing `err_operator_overload_default_arg` is reusable
verbatim.

There is no third option that keeps defaults and forbids the cross-fixity
use: filtering candidates by declared arity at the use site is the thing the
ledger row rules out, because it breaks the
[candidate-assembly](unicode-operators.md#candidate-assembly) equivalence
between `⊟5` and `operator⊟(5)` that the whole desugaring thesis rests on.

### The cost of each

**(a) Keep it waived.**
*Implementation:* **none.** It is what is built.
*Paper:* U§7 "Declaring" gains a paragraph that states the waiver and its
consequence explicitly, and [unary-forms](unicode-operators.md#unary-forms)'s
second sentence is split into its two independent claims. The paper has to be
willing to say in the room that `⊟5` calling a two-parameter operator is
intended. Expect the question; the answer is one line, and it is the same
answer the feature gives to everything else — *it is just the call*.

**(b) Reinstate p8.**
*Implementation:* **Sema**, and small. One `if` in
`Sema::CheckUserOperatorDeclaration` (`clang/lib/Sema/SemaDeclCXX.cpp`), reusing `diag::err_operator_overload_default_arg`, plus a
negative test. Both Unicode branches — `unicode-operators-experiment` and
`unicode-operators-upstream` — and neither backtick branch nor GCC, since
backtick has no declaration form of its own. Perhaps 20 lines including the
test, per branch, plus a `REPLAY.md` row.
*Paper:* U§7 "Declaring" gains a shorter paragraph — "p8 is kept, so arity
fixes the form" — and the derivation in
[over-oper-restrictions](#over-oper-restrictions) grows an exception it does
not otherwise need. That is the real cost: it is one more special rule to
defend, in a design whose selling point is that it has almost none.

### Recommendation

**Keep p8 waived (a).** The generalization
[over-oper-restrictions](#over-oper-restrictions) recommends —
*[over.oper]'s restrictions exist to protect a token whose parse, arity and
fixity the grammar already fixed, and a user operator inherits only what its
own declared forms need* — produces this answer by derivation, and a rule
derived is worth more in EWG than a rule asserted. Reinstating p8 would be
defending, with a new diagnostic, the claim that a defaulted parameter should
mean something different for `operator⊟` than for `f`; the feature's entire
argument is that it should not. The cross-fixity use is not a hole: it is
`operator⊟(5)` spelled `⊟5`, which is exactly what the design promises, and
the ambiguity case already produces the right error for the right reason. What
this was missing was never the diagnostic — it was the sentence saying the
behaviour is intended, which is why the ledger records that the waiver came by
omission.

**Branches touched by the recommendation: none.** Option (b) would touch
`unicode-operators-experiment` and `unicode-operators-upstream`, and no
backtick branch and no GCC branch under either option.

---

## over-oper-restrictions

Ledger entry:
[over-oper-restrictions](../ops/unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions).
Decided jointly with [prefix-arity-selection](#prefix-arity-selection).

### The question

May a user operator be declared as a **static member function** —
`struct S { static S operator⊞(S, S); };` — so that `a ⊞ b` finds it, on the
C++23 `static operator()` precedent?

### What was measured

From
[over-oper-restrictions](../ops/unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions),
found by `U08`, measured against `Sema::CheckOverloadedOperatorDeclaration`:

> [over.oper] imposes five restrictions on an operator function, and a user
> operator inherits exactly *one* of them. … (a) **class-or-enum parameter** —
> waived, as [operator-function-id](unicode-operators.md#operator-function-id)
> says; (b) **no default arguments** ([over.oper]p8,
> `err_operator_overload_default_arg`) — must also be waived, and the design
> never says so; (c) **not variadic** (`err_operator_overload_variadic`) —
> likewise waived; (d) **the arity table** (`OperatorUses[Op]` from
> `OperatorKinds.def`) — has no entry to consult, so the prefix/infix rule has
> to be written out; (e) **not a static member**
> (`err_operator_overload_static`) — *kept*, and this one is a judgement U08
> had to make with no guidance from the design.

The judgement and its stated basis:

> [unary-forms](unicode-operators.md#unary-forms)'s arity rule is stated as
> "two parameters, or one as a member", which presupposes an implicit object
> parameter, and a static member function has none, so it can name neither
> form.

**That basis does not survive inspection, which is why this is on the list.**
The arity rule as implemented counts operands, not parameters:
`CheckUserOperatorDeclaration` computes
`NumOperands = NumDeclaredParams + (HasImplicitObjectParam ? 1 : 0)` and
accepts 1 or 2. A static member declared `static S operator⊞(S, S)` has
`NumOperands == 2` and would be accepted by the arity rule alone; it is
rejected only by the explicit `MD->isStatic()` guard three lines above, which
runs first. So the restriction is a **choice**, not a consequence, and the
comment in the prototype records the reasoning that was available at the time
rather than a derivation.

The C++23 precedent is real and someone will raise it: `static operator()`
and `static operator[]` were admitted precisely because the implicit object
parameter was pure overhead for a stateless callable.

### The options

**(a) Keep rejecting static member user operators**, and replace the stated
reason with one that holds: the desugaring equivalence
([candidate-assembly](unicode-operators.md#candidate-assembly), §17.4) is
defined over exactly two spellings — `operator⊞(x, y)` for the non-member form
and `x.operator⊞(y)` for the member form. A static member names neither.
`x.operator⊞(y)` on a static member is legal C++ — the object expression is
evaluated and discarded — but it passes **one** argument to a two-parameter
function, so it does not mean `⊞(x, y)`. There is no spelling of the explicit
call that the infix form would be equivalent to, and the equivalence is the
whole design.

**(b) Admit them as a second infix declaration form.** `a ⊞ b` may find a
static member of `a`'s class, with `a` passed as an ordinary first argument.
This requires a rule saying what the equivalent explicit call *is* (the
honest answer is `S::operator⊞(a, b)`, a third spelling), and requires the
member half of candidate assembly to collect static members and pass the left
operand as argument one.

**(c) Admit them only in the prefix form.** Not a serious option — a static
member with one parameter is a free function with extra syntax, and it
inherits none of the class-scoping motivation that made `static operator()`
worth having.

### The cost of each

**(a) Keep rejecting.**
*Implementation:* **none.** Three lines of `CheckUserOperatorDeclaration`
already do it, reusing `err_operator_overload_static`, so the diagnostic is
the same one every non-call overloaded operator gets.
*Paper:* U§7 "Declaring" is rewritten to enumerate the five [over.oper]
restrictions and say which survive — which is
[over-oper-restrictions](../ops/unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions)'s
own recommended doc change and is owed regardless of the answer — and the
static-member choice becomes a **decision entry** in U§2 with the
two-spellings reason, written by
[reconcile-declaring-using](../ops/completion/steps/reconcile-declaring-using.md).
Suggested slug for that entry: `static-member-operators`, named for the
question so it survives the answer reversing.

**(b) Admit them.**
*Implementation:* **Sema**, and not small. Delete the `isStatic()` guard
(3 lines), then extend the member half of candidate assembly — the part `U13`
built, and the *only* half of the using story that is implementation work at
all, the non-member half being inherited — to collect static members from the
left operand's class and pass the object argument as an ordinary first
argument. New tests for member/static overlap, ambiguity with a non-member,
and the `x.operator⊞(y)` spelling that now does something different from the
infix form. Both Unicode branches, plus a `REPLAY.md` row on each. Neither
backtick branch (no declaration form) and not GCC.
*Paper:* a third equivalence spelling in
[candidate-assembly](unicode-operators.md#candidate-assembly), and a new
question for the room — whether `a ⊞ b` finding a static member of `a`'s class
is name lookup anyone wants, given that a hidden friend already does the job
with no new rule. This is the cost that dominates: it is new design surface in
the one part of the design that is currently pure inheritance.

### Recommendation

**Keep rejecting (a), with the reason restated.** The restriction is worth
keeping not because a static member "has no implicit object parameter" — the
arity rule would have accepted it — but because the feature's whole claim is
that `x ⊞ y` *is* one of two explicit calls, and a static member is neither of
them. Admitting it would mean inventing a third equivalence for a form that a
hidden friend already serves without any new rule, and it would put new design
surface into candidate assembly, which is the one place this design currently
gets everything for free. Say so, in one paragraph, and record it as a
decision so that the `static operator()` question is answered before it is
asked. If EWG wants it, it is a pure addition later — the same shape of answer
as [postfix-operators](#postfix-operators).

**Branches touched by the recommendation: none.** Option (b) would touch
`unicode-operators-experiment` and `unicode-operators-upstream`, and no
backtick branch and no GCC branch under either option.

---

## fold-over-user-infix

No ledger entry of its own — it is a design-doc question, recorded in
[infix-parse-cost](../ops/unicode-operators/clang/DEVIATIONS.md#infix-parse-cost)
part (3) and by `U11`, `U12`, `U15`, `U18`, `U19` and `U21`, every one of
which reports that "the design owes the fold decision". It belongs in U§13 and
is not there yet. Slug named for the question, so it survives either answer.

**Answer it once for both features.** This is what makes it a decision rather
than a defect: `prec::UserInfix` is a single shared precedence level, and both
backtick and Unicode sit on it, so the answer is the same for `(... ⊞ N)` and
`` (... `f` N) `` or it is incoherent. It goes in both papers or neither.

### The question

May a user-introduced infix operator be the operator of a fold expression —
is `(... ⊞ N)` well-formed, and is `` (... `f` N) ``?

### What was measured

From
[infix-parse-cost](../ops/unicode-operators/clang/DEVIATIONS.md#infix-parse-cost),
found by `U11`:

> One thing U§6 does not mention and the implementation decides by
> inheritance: a user operator is **not** a fold operator. `(... ⊞ N)` is
> `expected expression`, character-identical to backtick's
> `` (... `f` N) ``, because `Parser::isFoldOperator` excludes the shared
> level.

The exclusion is one clause of one predicate — `ParseExpr.cpp`:

```cpp
bool Parser::isFoldOperator(prec::Level Level) const {
  return Level > prec::Unknown && Level != prec::Conditional &&
         Level != prec::Spaceship && Level != prec::UserInfix;
}
```

Two facts about that line decide the cost.

**It fails silently if dropped.**
[feature-coupling](../ops/unicode-operators/clang/DEVIATIONS.md#feature-coupling)
records it as one of the three constructs that couple the two features, and
`REPLAY.md`'s `U11` row calls it *"the single likeliest replay mistake in the
step"*: on clean `main` the line reads `Level != prec::Spaceship;` and the
standalone equivalent is to **add** `&& Level != prec::UserInfix`, not to
rename anything. Omitting it admits user operators as fold operators by
accident.

**Admitting them deliberately is not a one-line change either.** `CXXFoldExpr`
stores its operator as a `BinaryOperatorKind` bitfield
(`CXXFoldExprBits.Opcode`, read by `getOperator()`), and 32 files under
`clang/lib` and `clang/include` name `CXXFoldExpr` — serialization both ways,
`StmtProfile`, `ASTImporter`, `ItaniumMangle`, `StmtPrinter`,
`ComputeDependence`, `TreeTransform`, `ExprConstant`, the static analyzer.
A user operator has no `BinaryOperatorKind`. For backtick the node is worse
than a widened enum: the slot is an arbitrary *expression*, and `CXXFoldExpr`
has three fixed sub-expression slots (`Callee`, `LHS`, `RHS`) with no room for
a fourth.

### The options

**(a) Exclude user-introduced infix operators from fold expressions in v1,
and say so.** `(... ⊞ N)` and `` (... `f` N) `` are ill-formed, with the
`expected expression` diagnostic they produce today. The papers state it as a
decision with a reason, and note that admitting it later changes only
ill-formed programs.

**(b) Admit them.** `CXXFoldExpr` grows a representation for a user operator —
minimally an operator-kind discriminator plus a `DeclarationName` for the
Unicode form, and a fourth sub-expression slot for the backtick slot — and
every consumer of `getOperator()` learns about it.

**(c) Split the answer** — admit Unicode operators, exclude backtick. Recorded
only to be rejected: it makes the shared precedence level mean two different
things, and the one-level argument
([user-infix-precedence](unicode-operators.md#user-infix-precedence),
[precedence-level](backtick-operator-design.md#precedence-level)) is the
design decision both papers most want banked.

### The cost of each

**(a) Exclude.**
*Implementation:* **none** — it is what all four Clang branches do. What it
buys is a *guard*: the one clause must survive every replay and every rebase,
on `backtick-trunk`, `backtick-23`, `unicode-operators-experiment` and
`unicode-operators-upstream`. Worth a test that pins it, if one is not
already pinned; `clang/test/Parser/unicode-operator-precedence.cpp` section 9
("not a fold operator") and its backtick twin are that test.
*Paper:* one U§13 bullet and one sentence in the backtick paper. Both should
say the exclusion is deliberate, since a reader who tries it gets
`expected expression`, which reads like an oversight.

**(b) Admit.**
*Implementation:* **large.** `CXXFoldExpr` is an AST node with two
serialization paths, a profile, an importer, a mangling and a printer, and the
change touches all four Clang branches plus GCC's `backtick` if backtick
parity is wanted — GCC has no Unicode implementation, so an admitted backtick
fold would be a fresh GCC parser and tree change with no Clang code to
transliterate. This is the largest single item in this document and the only
one that is not measured, because nobody built it.
*Paper:* a fold-expression section, a new question about what
`(... ⊞ N)` means for a left-fold over an operator with no identity, and an
answer for the empty-pack case that the existing table of fold identities does
not cover.

### Recommendation

**Exclude, for both features, in v1 (a) — and state it as a decision.** The
cost asymmetry is nearly total: excluding costs one clause that already
exists, admitting costs an AST node change across 32 files for a construct
nobody has asked for. And the forward compatibility is the same shape as
[postfix-operators](#postfix-operators)'s, which makes it easy to say in the
room: every program a later revision would newly accept is a program v1
rejects with `expected expression`, so admitting folds later takes nothing
back. What v1 must not do is leave it unstated — six separate handoffs
recorded "the design owes the fold decision", the exclusion is invisible in
the design doc, and the diagnostic a user gets does not mention folds. One
U§13 bullet, one backtick-paper sentence, and the guard clause noted as
load-bearing where the replay documentation can see it.

**Branches touched by the recommendation: none** — but the guard clause it
preserves lives on all four Clang branches (`backtick-trunk`, `backtick-23`,
`unicode-operators-experiment`, `unicode-operators-upstream`) and must survive
every rebase and replay on each. Option (b) would touch all four **and** GCC
`backtick`.

---

## postfix-operators

Ledger entry:
[postfix-operators](../ops/unicode-operators/clang/DEVIATIONS.md#postfix-operators).
Priced by `U21`
([handoff](../ops/unicode-operators/clang/handoffs/U21-postfix-probe.handoff.md))
and written up in U§13.1. **Its mangling clause is not this question's** — it
belongs to [mangling-abi](../ops/completion/steps/mangling-abi.md).

### The question

[unary-forms](unicode-operators.md#unary-forms) declines postfix operators. Is
that decline **permanent**, or is it a v1 scope decision that v2 may revisit —
and which of those do the papers say?

### What was measured

U21 built the candidate rule and threw it away. From
[postfix-operators](../ops/unicode-operators/clang/DEVIATIONS.md#postfix-operators):

> **The ambiguity is resolvable without whitespace sensitivity.** A one-token
> greedy-infix rule — after a complete operand, a user operator followed by a
> token that can begin a cast-expression is infix, else postfix — was
> prototyped in `Parser::ParsePostfixExpressionSuffix` in **68 lines, one
> file**, with one `NextToken()` call, no backtracking and no declaration
> lookup … So [unary-forms](unicode-operators.md#unary-forms)'s premise is too
> strong: the correct statement is not "postfix is ambiguous" but "postfix is
> affordable and we are declining to spend it".

And the result that decides the *shape* of the decline:

> greedy-infix fires only where a user operator is followed by a token that
> cannot begin a cast-expression, and v1 requires a cast-expression there — so
> every program the rule reinterprets is a program v1 rejects. Structurally,
> and measured: nothing well-formed changed, only diagnostics on already-ill-formed
> code.

The four prices, all measured, are in U§13.1 and are **not** re-derived here
per this step's instructions: the paren-forcing token set is larger than
predicted and includes `&&` (a cast-expression starter in every language mode
because of the GNU address-of-label extension, so `a ⊖ && b` misparses); the
chained-postfix case `a ⊖ ⊗` is a hard error with an unhelpful message; the
rule **costs the missing-right-operand diagnostic for every user of the
feature**, measured as four existing negative tests changing behaviour, two of
them fold cascades; and a compiler-known `std::postfix` tag type makes the
feature library-affects-language, whose precedent `operator<=>` /
`std::strong_ordering` costs Clang 452 lines of dedicated AST support across
26 files, adding **LEWG** to a routing already covering SG16, EWG/CWG and the
ABI group.

The third of those is the one to weigh: it is paid by users who never declare
a postfix operator.

### The options

**(a) Decline for v1, explicitly not foreclosed.** The papers say postfix is
implementable, cheap in parser code, and a *pure extension* of the v1 grammar
— and that v1 declines it because the diagnostic cost falls on everyone and
the tag type changes the paper's committee routing. U§13.1 stays as the
priced record.

**(b) Decline permanently.** The papers say postfix is out of scope for this
design, without the forward-compatibility argument, and U§13.1 is cut down or
dropped.

**(c) Take it in v1.** Greedy-infix, the `std::postfix` tag type, a fixity bit
on `UserOperatorExpr`, and LEWG.

### The cost of each

**(a) Decline for v1.**
*Implementation:* **none.** The probe is discarded; no branch carries it.
*Paper:* U§13.1 is already written and already says this — the work is to make
[unary-forms](unicode-operators.md#unary-forms)'s rationale agree with it
(done in this repo) and to keep the section in the paper rather than
compressing it to a bullet. It is one of the strongest sections either paper
has, because it is a *measurement* of a road not taken.

**(b) Decline permanently.**
*Implementation:* **none.**
*Paper:* strictly worse for no saving. "We couldn't" invites someone to show
that you could — and U21 already showed it, in 68 lines, so the paper would be
contradicted by its own repository.

**(c) Take it.**
*Implementation:* **parser and Sema, plus ABI and library.** 68 lines of
parser is the smallest part. Add: a fixity bit on `UserOperatorExpr` (arity no
longer recovers fixity); the synthesized `std::postfix` first argument
generalizing `CreateOverloadedUnaryOp`'s `IntegerLiteral 0` trick; a
compiler-known library type with `Sema` validation on the
`ComparisonCategories` model; four negative tests rewritten; and the mangling
question reopened — which is
[mangling-abi](../ops/completion/steps/mangling-abi.md)'s and where the
`pp_`/`pp` cross-vendor divergence lives. Both Unicode branches.
*Paper:* LEWG joins the routing, and
[library-scope](backtick-operator-design.md#library-scope)'s own bundling rule
— bundle what shares a design surface within one committee, split what crosses
committees — says on its own terms that this does not belong in v1.

### Recommendation

**Decline for v1, explicitly not foreclosed (a).** This is U§13.1's own
recommendation and the measurement supports it without qualification: the
decline costs nothing later, because greedy-infix only ever reinterprets
programs v1 rejects, so v2 can add postfix without taking anything back —
including the property the question exists to protect, that fixity stays
user-declarable
([user-declared-fixity](unicode-operators.md#user-declared-fixity)). Say it in
those terms rather than in the old "postfix is ambiguous" terms, because the
two invite opposite responses in the room: *we couldn't* invites a fix, and
*we chose not to, here is the price, and here is why it stays possible* does
not. The one thing to decide beyond the recommendation is how much room the
paper gives it — the honest answer is a full subsection, because a priced
negative result is rarer and more persuasive than another feature.

**Branches touched by the recommendation: none.** Option (c) would touch
`unicode-operators-experiment` and `unicode-operators-upstream`, and would
reopen [mangling-abi](../ops/completion/steps/mangling-abi.md).

---

## dependent-template-operator-id

Backlog entry:
[dependent-template-operator-id](../ops/BACKLOG.md#dependent-template-operator-id)
(P3). Measured in
[operator-id-anywhere](../ops/unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere)
by `U10`, cause diagnosed by `U07`. Not one of the seven §6 items, but the
same shape — a question only the author can answer, because both answers are
defensible and one of them is "the design sentence was too strong".

### The question

U§7.1 says the operator-function-id names the overload set **"anywhere an
unqualified-id does"**. One position falsifies it:
`t.template operator⊞<int>(0)`, on a *dependent* object expression. Fix Clang,
or reword the design?

### What was measured

From
[operator-id-anywhere](../ops/unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere):

> **Both claims hold, and the ADL one holds unusually strongly — measured, not
> assumed.** Every position in U10's sweep works with *zero* production
> changes: constant evaluation, overload ranking, qualified/member/arrow/class-qualified
> calls, address-taking …, templates, SFINAE, `requires`, dependent calls. …
> **The exception is one word: "anywhere".** A *dependent* object expression
> with the `template` disambiguator — `t.template operator⊞<int>(0)` — is
> rejected with `'operator⊞' following the 'template' keyword cannot refer to
> a dependent template`.

And the control, which is what turns this from a defect into a decision:

> U10 pins it, **and pins the control**: the *identical* construct on a
> **literal operator** (`t.template operator""_lit<int>(0)`) produces the
> character-identical diagnostic, while `t.template operator+<int>(0)`
> compiles. So the limitation is not the new name kind's — it is the
> limitation of *every* operator-function-id that is not one of the fixed
> `OverloadedOperatorKind`s, inherited unchanged.

The cause, from `U07`: `DependentTemplateStorage` is keyed by an
`IdentifierInfo *` or an `OverloadedOperatorKind`, and a user operator is
neither. User-defined literal operators have had the identical limitation
since C++11.

### The options

**(a) Reword U§7.1.** Replace "anywhere an unqualified-id does" with the
qualified form the ledger recommends: *anywhere an unqualified-id does, with
one inherited exception — as a dependent template name after the `template`
keyword, where Clang's `DependentTemplateStorage` can hold an identifier or a
built-in operator kind and nothing else, a limitation user-defined literal
operators have had since C++11.*

**(b) Fix it upstream** — widen `DependentTemplateStorage` to carry a
`DeclarationName` — and keep the word "anywhere".

**(c) Both, in that order.** Reword now, and report the limitation upstream
against the **literal-operator** reproducer, which needs nothing from this
proposal to be a valid bug.

### The cost of each

**(a) Reword.**
*Implementation:* **none.**
*Paper:* one clause, in U§7.1's fourth point. It costs a sentence and removes
the one statement in the design an implementer can falsify — which is worth
more than the sentence, because U§7.1's fourth point is load-bearing: it is
the argument that a bare-identifier `⊞` would buy nothing, and hence the
support for
[operator-identifier-disjointness](unicode-operators.md#operator-identifier-disjointness).
A reader who tries the one construct that fails and finds the design
overclaiming is a reader who then doubts the rest of the sweep, all of which
holds.

**(b) Fix upstream.**
*Implementation:* **large, and upstream's.** `DependentTemplateStorage` is a
`clang/AST` data structure with `ASTContext` uniquing, serialization, and
`TreeTransform` consumers; widening its key from
`llvm::PointerUnion<IdentifierInfo *, OverloadedOperatorKind>` to a
`DeclarationName` touches every consumer and changes AST-file compatibility.
It is not gated behind `-funicode-operators` and cannot be — it fixes the
literal-operator case too, which is the point.
*Paper:* the "anywhere" claim survives intact, at the cost of a proposal that
depends on an unmerged upstream refactor to be true as written. That is the
wrong dependency for a paper: the reword is true today either way.

**(c) Both.**
*Implementation:* an issue report, no code. The reproducer is the
literal-operator control, which involves no user operator at all and therefore
no unmerged branch — the strongest possible form of an upstream report.
*Paper:* the reword, plus (optionally, once the issue has a number) one
footnote citing it. The same argument that placed
[upstream-reports](../ops/completion/steps/upstream-reports.md) first in the
plan applies: a paper that can cite the issue number is stronger, and issues
take calendar time.

### Recommendation

**Both, reword first (c).** The reword is the paper-truth fix and it is owed
regardless — the sentence is false as written, and it is one of the sentences
the design most relies on. The upstream report is cheap, is not this
proposal's to fix, and is best filed against the literal-operator reproducer
precisely *because* it needs nothing from this feature: it demonstrates that
the limitation is C++11's and not the new name kind's, which is exactly the
claim the paper wants to make. Do **not** gate the paper on the fix landing.
Where this lands: the reword is
[reconcile-declaring-using](../ops/completion/steps/reconcile-declaring-using.md)'s
(U§7.1 is its destination section), and the report is
[upstream-triage](../ops/completion/steps/upstream-triage.md)-shaped work —
which means this backlog row's `Closed by` is a *pair* of steps, not one, and
neither of them is [implement-decisions](../ops/completion/steps/implement-decisions.md).

**Branches touched by the recommendation: none.** Option (b) touches no branch
of this project either — it is a change to upstream LLVM's `clang/AST`, outside
`-funicode-operators` by necessity, and would be carried by LLVM rather than by
any of the five feature branches here.

---

## Answers

**Answered 2026-09-06 by the design author. All five recommendations accepted
as written.** No recommendation was overridden and no reason diverges from the
brief, so each entry below records the option chosen and the doc work it
generates rather than restating an argument the pages above already carry.
Every one of the five is *decided*; none of the five is yet *written*, and the
distinction is the point — the ledger rows below stay `OPEN` until their
destination section says the new thing.

**Consequence for the plan: nothing turned into code.** All five answers are
"keep what is built and argue for it", so
[implement-decisions](../ops/completion/steps/implement-decisions.md) has an
empty scope and is marked not-applicable in `ops/completion/PLAN.md` rather
than left looking unstarted, per its own step file. The work these answers
generate is documentary and belongs to
[reconcile-declaring-using](../ops/completion/steps/reconcile-declaring-using.md),
[reconcile-remainder](../ops/completion/steps/reconcile-remainder.md) and
[upstream-triage](../ops/completion/steps/upstream-triage.md).

### 2026-09-06 — prefix-arity-selection: option (a)

**Keep [over.oper]p8 waived.** A user operator may have default arguments, and
a defaulted trailing parameter therefore makes an infix-declared operator
usable in prefix position — intended, not a hole, because `⊟5` *is*
`operator⊟(5)` and that is what the desugaring promises.

*Doc work owed:* U§7 "Declaring" states the waiver and its consequence
explicitly, and [unary-forms](unicode-operators.md#unary-forms)'s second
sentence splits into the two independent claims — **arity selects the form at
the point of declaration, grammatical position selects it at the point of
use** — with the note that the second needs no help from the first, which is
what makes the Swift trap avoidable. Owner:
[reconcile-declaring-using](../ops/completion/steps/reconcile-declaring-using.md).

### 2026-09-06 — over-oper-restrictions: option (a)

**Keep rejecting static member user operators — on the reason that holds.**
Not "a static member has no implicit object parameter, so it can name neither
form": the arity rule counts operands and would have accepted a two-parameter
static member, so that reason does not survive inspection. The reason is that
the desugaring equivalence is defined over exactly two spellings,
`operator⊞(x, y)` and `x.operator⊞(y)`, and a static member names neither.

*Doc work owed:* U§7 "Declaring" enumerates the five [over.oper] restrictions
and says which survive, and the static-member choice becomes a **new decision
entry** in `docs/unicode-operators.md` §2 — suggested slug
`static-member-operators`, named for the question — so that the C++23
`static operator()` question is answered before it is asked. Owner:
[reconcile-declaring-using](../ops/completion/steps/reconcile-declaring-using.md).

### 2026-09-06 — fold-over-user-infix: option (a)

**Excluded in v1, for both features, and stated as deliberate.** `(... ⊞ N)`
and `` (... `f` N) `` are ill-formed. What must not happen is what happens
today: a reader who tries it gets `expected expression` and no document
anywhere says the exclusion was chosen.

*Doc work owed:* a U§13 bullet (the section has no fold entry to amend — it
must be added) and one sentence in the backtick paper, both saying the
exclusion is deliberate and that admitting folds later changes only
ill-formed programs. Owner:
[reconcile-remainder](../ops/completion/steps/reconcile-remainder.md), which
owns U§13.

*And a standing guard, which is not doc work:* `Level != prec::UserInfix` in
`Parser::isFoldOperator` must survive every rebase and replay on all four
Clang branches, and it fails **silently** — a replay onto clean `main` must
*add* the clause, not rename one. Recorded in `ops/completion/PLAN.md`'s gate
facts and in the Unicode track's `REPLAY.md`, where a rebase or replay agent
will actually read it.

### 2026-09-06 — postfix-operators: option (a)

**Declined for v1, explicitly not foreclosed**, and argued in the *affordable
and declined* terms rather than the old *ambiguous* terms: greedy-infix only
ever reinterprets programs v1 rejects, so v2 can take postfix without v1
taking anything back — including the property the question exists to protect,
that fixity stays user-declarable
([user-declared-fixity](unicode-operators.md#user-declared-fixity)).

*Doc work owed:* keep U§13.1 as a full subsection in the paper rather than
compressing it to a bullet, and make sure
[unary-forms](unicode-operators.md#unary-forms)'s rationale agrees with it.
Owner: [reconcile-remainder](../ops/completion/steps/reconcile-remainder.md)
for U§13, [unicode-paper](../ops/completion/steps/unicode-paper.md) for the
paper's treatment. **The mangling clause of the
[postfix-operators](../ops/unicode-operators/clang/DEVIATIONS.md#postfix-operators)
row is not covered by this answer** — it stays
[mangling-abi](../ops/completion/steps/mangling-abi.md)'s.

### 2026-09-06 — dependent-template-operator-id: option (c)

**Both, reword first.** U§7.1's "anywhere" is qualified now; the upstream
report is filed separately and the paper is not gated on the fix landing. The
report goes against the **literal-operator** reproducer
(`t.template operator""_lit<int>(0)`), which involves no user operator and no
unmerged branch — which is precisely what demonstrates that the limitation is
C++11's and not the new name kind's.

*Doc work owed:* the U§7.1 reword —
[reconcile-declaring-using](../ops/completion/steps/reconcile-declaring-using.md)'s,
U§7.1 being its destination section. *Report owed:*
[upstream-triage](../ops/completion/steps/upstream-triage.md). The backlog row
[dependent-template-operator-id](../ops/BACKLOG.md#dependent-template-operator-id)
therefore closes as a **pair** of steps, and neither is implement-decisions;
`ops/completion/PLAN.md`'s Coverage table is corrected to say so.

## Where each answer was recorded

Per the convention that a ruling appends to its question's own Log rather than
getting a document of its own:

| Answer | Decision-log `Log.` entries appended | Ledger `Status:` marked |
|---|---|---|
| prefix-arity-selection | [unary-forms](unicode-operators.md#unary-forms) | [prefix-arity-selection](../ops/unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection) |
| over-oper-restrictions | [operator-function-id](unicode-operators.md#operator-function-id), [unary-forms](unicode-operators.md#unary-forms) | [over-oper-restrictions](../ops/unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions) |
| fold-over-user-infix | [user-infix-precedence](unicode-operators.md#user-infix-precedence), [precedence-level](backtick-operator-design.md#precedence-level) | [infix-parse-cost](../ops/unicode-operators/clang/DEVIATIONS.md#infix-parse-cost) (part 3 only) |
| postfix-operators | [unary-forms](unicode-operators.md#unary-forms) | [postfix-operators](../ops/unicode-operators/clang/DEVIATIONS.md#postfix-operators) (substance; mangling clause untouched) |
| dependent-template-operator-id | [operator-identifier-disjointness](unicode-operators.md#operator-identifier-disjointness) | [operator-id-anywhere](../ops/unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere), and the backlog row [dependent-template-operator-id](../ops/BACKLOG.md#dependent-template-operator-id) |

Every ledger row above stays **`OPEN`** with a dated **DECIDED** note naming
the step that owes the writing. A row goes `RECONCILED` when its destination
section says the new thing — deciding is not reconciling, and marking it
otherwise would report work that has not happened.
