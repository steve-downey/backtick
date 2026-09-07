---
title: "Unicode User-Defined Operators for C++"
subtitle: "Declaring `operator⊞`, and what an implementation says about it"
document: DXXXXR0
date: today
audience: SG16, EWG
author:
  - name: Steve Downey
    email: <sdowney@gmail.com>
toc: true
toc-depth: 2
---

# Abstract

A user should be able to declare `operator⊞` and write `a ⊞ b`. That is the
whole feature: a frozen set of Unicode symbols that have never had meaning in
C++ becomes available as operator tokens, and an operator drawn from that set
is an ordinary overloadable function, found by ordinary lookup, called by
ordinary overload resolution.

```cpp
constexpr int operator⊞(int, int);      // an ordinary function declaration
static_assert(5 ⊞ 7 == 12);

Matrix operator⊗(Matrix const&, Matrix const&);
a ⊗ b ⊗ c                               // operator⊗(operator⊗(a, b), c)

Vec operator⊖(Vec const&);              // one parameter: unary prefix
⊖v                                      // operator⊖(v)
```

`x ⊞ y` means the call `operator⊞(x, y)`, resolved as an overloaded operator
is resolved today. There are no built-in candidates, because there is no
built-in meaning to protect. There are no fixity declarations: one precedence
level, left-associative, fixed by this paper.

The feature is implemented in Clang behind `-funicode-operators`, on a branch
off current trunk, and the implementation is the reason this paper exists in
this form. Several claims the design made on paper turned out to be wrong in
ways only a build could show, and they are reported here instead of quietly
corrected.

# Before / After

::: cmptable

### Before
```cpp
Matrix mul(Matrix const&, Matrix const&);
Matrix kron(Matrix const&, Matrix const&);

auto r = mul(kron(a, b), mul(c, d));
```

### After
```cpp
Matrix operator⊗(Matrix const&, Matrix const&);
Matrix operator⊠(Matrix const&, Matrix const&);

auto r = (a ⊠ b) ⊗ (c ⊗ d);
```

---

```cpp
Set union_(Set const&, Set const&);
Set inter(Set const&, Set const&);

auto s = union_(inter(x, y), z);
```

```cpp
Set operator∪(Set const&, Set const&);
Set operator∩(Set const&, Set const&);

auto s = (x ∩ y) ∪ z;
```

:::

The gain is not brevity. It is that the notation on the page is the notation
in the domain, for domains that have had one for a century and have had to
spell it `mul` in C++ because the language ran out of tokens.

# The proposal

An *operator-function-id* may be `operator` followed by a **user-operator
token**: a single non-ASCII code point drawn from an enumerated set frozen by
this paper (U§2). Such a function is an ordinary free or member function with
no class-or-enum parameter requirement.

A user-operator token appearing after a complete operand is a binary operator
at the **user-infix precedence level** (the highest binary level, tighter
than `*`, looser than the unary operators), left-associative, with
cast-expression operands. The same token in operand position is a unary
prefix operator.

`x ⊞ y` is `operator⊞(x, y)`; `⊖x` is `operator⊖(x)`; the member forms are
`x.operator⊞(y)` and `x.operator⊖()`. Candidates are assembled as for an
existing overloaded operator, with ADL, and with no built-in candidates.

Nothing else changes. The feature has no evaluation-order rule, no conversion
rule, no template rule, and no constant-evaluation rule of its own.

# The token set

## Deriving it

UAX #31 revision 43 added **R3c, "User-Defined Operators"**, which defines
operator syntax over the characters with the Pattern_Syntax property. That is
the normative hook, and C++23 already references UAX #31 normatively for
identifiers (P1949R7), so the citation is the same shape to the same document.

R3c does not hand us a usable set directly. Pattern_Syntax includes the ASCII
operator characters, every one of which is already a token, a token prefix, or
blocked by adjacency. The usable pool is Pattern_Syntax minus ASCII.

A code point is a user-operator token if all of:

1. it has Pattern_Syntax;
2. it is outside ASCII;
3. it lies in the mathematical and arrow blocks (U+2190–21FF, U+2200–22FF,
   U+2300–23FF, U+27C0–27EF, U+27F0–27FF, U+2900–297F, U+2980–29FF,
   U+2A00–2AFF, U+2B00–2BFF);
4. its General_Category is Sm or So, which excludes the paired brackets
   (Ps/Pe) as delimiters worth leaving unspent;
5. it is not on the exclusion list of U§2.

Applied once against UCD 17.0, that yields **1,381 code points in 32
contiguous ranges**. The lexer's table is 256 bytes and one binary search,
on the non-ASCII path both compilers already walk for extended identifiers.

The predicates are derivation inputs, not ongoing dependencies. The proposal
ships the resulting enumeration normatively, and the enumeration is frozen.

## Immutable is not closed

Pattern_Syntax is an immutable property by Unicode's stability policy: no code
point will ever gain or lose it. However, immutable is not the same as closed.
Of the 2,760 Pattern_Syntax code points, 2,681 carry assigned characters and
**79 are still unassigned** — reserved slots inside the immutable set. Unicode
has assigned **453** characters at Pattern_Syntax code points since the 4.1
freeze, in nearly every release, including one in 17.0 itself. Inside the
blocks above, 283 of those assignments landed, 279 of them Sm or So.

A predicate-defined operator set would therefore have grown by 279 operators
since 2005, and would grow again on Unicode's schedule rather than the
committee's.

Growth is lexically benign: a newly assigned code point was not a valid token
before, so an assignment can only make ill-formed programs well-formed.
However, it is not audit-benign: the confusability exclusion below can not be
evaluated for
characters that do not exist yet, so a predicate-defined set auto-admits
unvetted symbols. That asymmetry is why the enumeration is frozen and pinned
to a named Unicode version, and why adopting later additions must be a
deliberate act of a future revision.

## The exclusions, and why their reasons differ

Three kinds of character are excluded, and the implementation found that the
three kinds are not alike.

**Identifier characters.** TR31 §7.1's mathematical profile earmarks ∂, ∇ and
∞ as *identifier* characters, and its companion syntax profile removes them
from syntactic use. They name things; they do not combine things.

**Confusables with existing tokens.** U+2212 −, U+2215 ∕, U+2217 ∗, U+2223 ∣,
U+2236 ∶, U+2219 ∙, U+22C5 ⋅, U+2264 ≤, U+2265 ≥, and ⇐ ⇒ ⇔. These are
rejected outright and never aliased. A character that looks like `-` and is
not `-` must fail to lex.

**Emoji presentation.** Twelve code points inside the blocks (⌚ ⌛ ⏩ ⏪ ⏫ ⏬
⏰ ⏳ ⬛ ⬜ ⭐ ⭕), per TR31 §7.2's carve-out.

The design said to keep these in a table with reasons so the diagnostic can
say why, instead of a generic stray-character error. That is right,
and incomplete: **the three reasons need three different emission points.**
Confusables and emoji were never identifier characters, so rejecting them at
token classification is safe. ∂ ∇ ∞ *are* valid identifier characters. In
Clang they are valid today, with no flag, because the math-identifier
extension (D137051, P3658R1) is on by default at every `-std=`. A diagnostic
for them at classification would fire on every legitimate use of ∂ as a name.
The implementation emits that one as a note, in the declarator parse, after a
conversion-function-id parse has already failed.

Two smaller corrections the enumeration forced. "The middle-dot family" is not
a UCD family: inside the blocks it is exactly U+2219 and U+22C5, because
U+00B7 MIDDLE DOT is **not** Pattern_Syntax, because Unicode withheld it
precisely for its use in identifiers, in Catalan. And U+2044 ⁄ FRACTION SLASH,
named in the draft exclusion list, is outside the blocks and already fails
predicate 3.

## The operator set and the identifier set are disjoint

TR31 partitions syntax space from identifier space by construction. The
question is whether it holds against a real compiler, and it does, measured
per code point: of the 1,381 members of the set, **zero** are XID_Start, zero
XID_Continue, zero in the math-identifier profile tables, and zero in the
C++11–C++20 Annex E identifier whitelist.

That measurement is stronger than the design claimed, because of an accident
of timing. The set is derived against UCD 17.0; Clang's in-tree identifier
tables have already moved to Unicode 18.0. The partition survived the UCD
moving underneath it, which is exactly the version-skew case a real
implementation faces: a compiler updates its XID tables on Unicode's schedule
while a frozen operator list does not move.

One consequence of the partition is worth stating because an implementer will
meet it. With the math-identifier extension on, `operator∂` **without a
space** is a single identifier: `int operator∂(S, S);` declares a function
*named* `operator∂`. With a space, `operator ∂` is a conversion-function-id.
Whitespace is load-bearing in exactly that corner, and only there.

## Spelling: the glyph and the UCN

A universal-character-name designating a user-operator code point (including
the C++23 named form) forms that operator token. `operator⊞`,
`operator⊞` and `operator\N{SQUARED PLUS}` are the same declaration, and
`a \N{CIRCLED TIMES} b` is `a ⊗ b`.

The absence of UCN punctuators today is an accident: every punctuator so far
has been in the basic character set. These are the first non-basic
tokens, and the extended-character-equals-UCN equivalence the language
maintains for identifiers is the escape hatch for source encodings, fonts and
review tools that can not carry the glyph. It must extend to them.

The design called this "structurally free", on the grounds that the lexer's
existing UCN path already produces a code point that takes the same
classification as a literal one. Classification is free. **Identity is not.**
The first implementation classified UCN-spelled operators correctly and
derived the operator's identity by decoding the token's spelling as one UTF-8
scalar, which answers zero for a UCN. That value is the `DeclarationName`, the
mangled name, the printed form, and the on-disk lookup key — so
`operator\U0000229E` would have been a *different entity* from `operator⊞`,
mangling `op_u0000`, while a token dump looked perfectly correct. Every test
that would have caught it had to be a declaration-and-use cross-spelling
assertion; no token-level comparison can see it.

The equivalence the UCN rule claims is an equivalence of entities, and a paper that
says "structurally free" should say that.

# Fitting the grammar

## One level for all user-introduced infix

```
infix-expression:
    cast-expression
    infix-expression user-operator cast-expression

unary-expression:
    ...
    user-operator cast-expression
```

Binary user operators occupy one precedence level: the highest binary level,
tighter than `*` and looser than the unary operators, left-associative, with
cast-expression operands. It is the level the backtick proposal (D4307)
introduces, and it is shared: the *user-infix level*, for all
user-introduced infix syntax. Neither feature owns it.

Symmetry falls out of the operand grammar: `-a ⊞ -b` is `operator⊞(-a, -b)`.

```cpp
-a ⊞ -b            // operator⊞(-a, -b)
a * b ⊞ c          // a * operator⊞(b, c)
a ⊞ b ⊗ c          // operator⊗(operator⊞(a, b), c)
a ⊞ ⊖b             // operator⊞(a, operator⊖(b))
⊖a ⊞ 2 * ⊖b        // (operator⊖(a) ⊞ 2) * operator⊖(b)
```

The last line is the one readers get wrong, and it is the only example that
shows all three binding strengths at once. It is included for that reason.

What does not appear: a delimiter-suppression rule, a nesting rule, a slot
grammar. Each operator is one distinct token, so the ordinary
operator-precedence code handles it. In the implementation the entire infix
production is one `case` in the precedence table and one fourteen-line arm in
the binary-expression loop, with nothing in that loop widened.

## Prefix, and how position decides

Arity selects the form at the declaration: two parameters (one as a member) is
infix, one parameter (none as a member) is prefix, the same convention as
`operator-`. Position selects it at the use: post-operand is infix, operand
position is prefix.

Position alone suffices, with no lookahead, no whitespace rule and no
consultation of what is declared. The structural reason is worth stating
because it is what makes the claim safe rather than lucky: the cast-expression
parse is reached only in operand position, the binary-precedence lookup is
consulted only after a complete operand, and **the two never examine the same
token.** The same code point can be both, in one expression: with both
overloads declared, `⊖a ⊖ b` is `operator⊖(operator⊖(a), b)`, and so is
`⊖⊖1 ⊖ ⊖⊖2`.

The prefix production cost one `case` in the cast-expression parse, forty
lines, one file, and no change anywhere downstream.

## Postfix, and why not

No postfix form is proposed. The reason usually given (that prefix and
postfix are ambiguous) is not the reason, and the real one is worth setting
out, because the question gets asked immediately.

`operator++` does not solve prefix-versus-postfix disambiguation. It *dodges*
it: prefix is parsed in the cast-expression parse, postfix in the
postfix-suffix parse, two grammar positions, zero lookahead, and it works only
because `++` has no infix form. A user operator can be declared infix and
postfix, and after a complete operand the parser would have to decide whether
it is holding a finished expression or one awaiting a right operand.

Nor is the `operator++(int)` dummy-parameter convention available. It is
unambiguous for `++` because no infix `++` exists to collide with; U§4 admits
`operator⊞(T, int)` as a legitimate *infix* declaration, so a distinguished
tag type would be forced. That tag would have to be known to the compiler,
which makes the feature library-affects-language, with `std::strong_ordering`
as the precedent and its 452 lines of dedicated AST support as the price.

However, a tag would disambiguate *declarations*, and the ambiguity is at the
*use*. Lexing and parsing are declaration-independent, so no declaration can
inform the parse.

There is a rule that works, and it was prototyped: after a complete operand, a
user operator followed by a token that can begin a cast-expression is infix,
otherwise postfix. One token of lookahead, no backtracking, no whitespace
sensitivity. It is 68 lines in one file. However, it costs three things the
design had not priced. The witness set is every cast-expression starter,
which includes `(`, `[`, `++`, `--` and `&&`
(GNU address-of-label), so `a ⊖ && b` misparses as `⊖(a, &&b)`. It converts
every missing-right-operand typo into a valid postfix parse, so `a ⊞ ;` stops
diagnosing a missing expression and starts diagnosing a missing overload;
every user pays that, whether or not they write a postfix operator. Fixity
would also become dialect-dependent, since `^^` is gated on reflection, `[` on C++ and
Objective-C, `^` on blocks: a derived predicate varies by dialect, and a
curated list is a normative artifact needing re-audit whenever a token that
can begin an expression is added.

Declining postfix now costs nothing later, and the reason is structural.
Greedy-infix fires only where a user operator is followed by a token that can
not begin a cast-expression, and this proposal requires a cast-expression in
exactly that position. **Every program greedy-infix would reinterpret is one
this proposal rejects.** Postfix can be added by a later paper without
changing the meaning of any program this one accepts.

## Fold expressions

A user operator is not a fold operator: `(... ⊞ N)` is `expected expression`.
This is inherited from sharing the level, and the diagnostic is
character-identical to the backtick form's. Whether the user-infix level
should be admitted to `fold-operator` is an open question, and it should be
answered once for both features.

# Declaring, looking up, desugaring

## Arity is the only rule that carries over

[over.oper] imposes five restrictions on an operator function. A user operator
inherits exactly one of them, and the generalization is sharper than the
class-or-enum exception the design named:

> [over.oper]'s restrictions exist to protect a token whose parse, arity and
> fixity the grammar has already fixed. A user operator's only fixed property
> is arity, so arity is the only rule it inherits.

- **class-or-enum parameter**: waived. The rule protects a built-in meaning,
  and there is none. `constexpr int operator⊞(int, int)` is legal, and
  `5 ⊞ 7` finding it is the motivating case.
- **no default arguments**: waived, and the design never said so.
- **not variadic**: waived, likewise.
- **the fixed arity table**: has no entry to consult, so the prefix/infix
  rule is written out.
- **not a static member**: kept — and kept as a *choice*, which is worth
  saying plainly, because the arity rule does not exclude it. That rule counts
  operands, so `static S operator⊞(S, S)` has two and would be accepted; an
  implementation must reject it deliberately. The reason is the desugaring:
  `x ⊞ y` is defined to mean exactly one of two spellings, `operator⊞(x, y)`
  or `x.operator⊞(y)`, and a static member names neither — `x.operator⊞(y)`
  on a static member is legal C++ but discards the object expression and
  passes one argument to a two-parameter function. C++23 shipped
  `static operator()`, so this will be asked about; the answer is that a call
  operator's meaning is given by the standard, which can say what becomes of
  the object expression, while a user operator's meaning is *only* the
  equivalence, and there is nowhere else to say what a static form would do.
  Restrictive now, relaxable later by writing down a third spelling and the
  lookup that finds it.

Everything else is ordinary: templates, `constexpr`, `= delete`, member and
non-member, explicit object parameters.

Waiving the default-argument rule has a visible consequence. Given only
`constexpr int operator⊟(int a, int b = 1)`, the prefix use `⊟5` is accepted
and calls it through the default argument, and adding a genuine prefix
overload makes `⊟5` ambiguous in the ordinary way. Filtering candidates by
declared arity would fix it and would break the equivalence in U§7 below, on
which the whole desugaring rests. So arity selects the form for
*declarations*, and does not filter *uses*. Reinstating [over.oper]p8 for
user operators is the conservative alternative and costs one diagnostic.

## One candidate set, and no built-in candidates

`x ⊞ y` assembles member candidates from the left operand's class and
non-member candidates from unqualified lookup and ADL, ranked together in one
set. Not three passes, and not member-first with a fallback: the observable is
that `MN{} ⊘ 0` selects the non-member and `MN{} ⊘ 0L` selects the member.

The normative requirement is that the operator form finds what the explicit
call finds. The implementation asserts it as type identity over a
tag-returning overload set, and not by both forms compiling:

```cpp
static_assert(__is_same(decltype(x ⊘ y), decltype(operator⊘(x, y))));
```

for every ADL shape, plus the member desugaring, plus both negative halves.

There are **no built-in candidates**, and the implementation of that rule is
that nothing calls the function which adds them. `1 ⊠ 2` with nothing declared
is an ordinary undeclared-name error. `p ⊞ n` on `int*` is a no-viable-overload
error, never pointer arithmetic. This is the structural difference from
`operator+`, and it is a non-mechanism.

ADL deserves a sharper claim than the design made, because the implementation
separated it. On the non-member path ADL is what you get by **not** writing
code: a twenty-line stub that performs one operator-name lookup and hands an
unresolved callee to the ordinary call builder already yields pure ADL, hidden
friends reachable by nothing else, augmentation of a non-viable
ordinary-lookup set, and ADL at instantiation. Member candidates were the
entire remaining job. On the backtick project's GCC implementation, the
corresponding defect went the other way: resolving the name at parse time
silently lost ADL, and it had to be recorded as a defect and fixed. ADL is
what you get by not writing code; losing it is what you get by writing some.

## The expression node, and two-phase lookup

This is the finding the design did not have, and it is the strongest evidence
in the paper for the claim that C++'s operator tables are closed.

Clang's `CXXOperatorCallExpr` exists to record that a call was *written* with
operator syntax, and `TreeTransform` reads the operator kind back off it to
re-run operator candidate assembly at instantiation. It stores an
`OverloadedOperatorKind`, in which `OO_None` is a valid value of the enum and
not an absent state, so it can not carry a user operator.

Leave the use as an ordinary call (which is exactly what the desugaring
says it is) and the non-dependent case is correct in every shape tested.
However, when an operand is type-dependent, `TreeTransform` rebuilds the
expression through the ordinary call path: [over.match.call], not
[over.match.oper]. ADL survives, because ADL is a property of the call. Member
candidates do not, because they are a property of the operator syntax. So

```cpp
template <class T> constexpr auto f(T a, T b) { return a ⊕ b; }
```

fails for a member `operator⊕`, and `requires(T a, T b) { a ⊕ b; }` is
unsatisfied for that `T`.

The fix is a node, `UserOperatorExpr`, that stores the code point, the
arity and the operator location, recovers the operands as written from the
semantic form, and re-runs the operator resolution on transformed operands at
instantiation. The right upstream model is not `CXXOperatorCallExpr` but
`CXXRewrittenBinaryOperator`, which exists for the same reason: to record that
an expression was written one way and means another, so instantiation can redo
the resolution rather than replay the result.

The desugaring is therefore exact for a non-dependent use and needs a node to
survive a dependent one. That sentence belongs in the design, and was not in
it.

# Fixity, arity and precedence, in one place

These four questions arrive together and are usually confused with each other,
so they are separated here.

**Precedence is fixed by this paper, and there are no fixity declarations,
ever.** A declared precedence is a semantic property that must travel with the
name across headers, modules and translation units. Two translation units
disagreeing about `a ⊕ b ⊗ c` is an ODR factory, and the parse of an
expression comes to depend on which imports are visible: Haskell's
fixity-import problem, and Swift's `precedencegroup` conflicts. With fixed
fixity, the *parse* of an expression depends on nothing but the expression.
Only the *meaning* of `operator⊞` travels, and that is ordinary lookup.

**One level, and no table.** Every user-introduced infix operator binds at the
same strength, left-associatively. A reader learns one rule instead of a
lattice, and `a ⊞ b ⊗ c` groups left with no table to consult. This is the
decision most likely to be argued, and the alternative on offer is the one the
paragraph above rejects.

**Arity is declared and selects the form; it does not filter uses.** Two
parameters is infix, one is prefix, counting the implicit object parameter.
Because default arguments are waived, a two-parameter operator with a default
can also be called in prefix position, as above.

**Fixity at the use site is decided by grammatical position, and nothing
else.** No lookahead, no whitespace, no declaration lookup. Prefix and infix
uses of one code point coexist in one expression.

**Postfix is not proposed, and the exclusion is forward-compatible.** See
above: every program a postfix rule would reinterpret is a program this
proposal rejects, so the door stays open.

One consequence of the sequencing rules deserves committee attention, because
no existing operator behaves this way. The backtick design says the operator
introduces no evaluation-order rule and inherits [expr.call]
wholesale. That holds for the non-member form: the operands are function
arguments, indeterminately sequenced. For a **member** operator, the left
operand is the object expression, part of the postfix-expression, and
[expr.call] sequences it before every argument. So `x ⊞ y` sequences `x`
before `y` when a member overload wins, and does not when a non-member wins:
**the sequencing of `x ⊞ y` is decided by overload resolution.**

No existing C++ operator does this. [over.match.oper]p2 gives an overloaded
built-in-spelled operator the built-in's sequencing regardless of
member-ness, and a user operator has no built-in to borrow from. The
implementation measured the difference three ways (constant evaluation,
`-Wunsequenced`, and emitted IR), and this paper does not propose an answer.
It calls CWG's attention to the question.

# Implementation experience

## What was built

Clang, on a branch off trunk, behind `-funicode-operators`, default off. The
flag is independent of and composable with `-fbacktick`: a translation unit
may enable either, both, or neither, and the shared user-infix level parses
identically under every combination.

Everything in this paper compiled: the token set and its 256-byte table, the
UCN spellings, the exclusion diagnostics, `operator⊞` as a declarable and
manglable name, explicit calls, infix and prefix expressions with full ADL,
the AST node, serialization to PCH and modules, AST import, ODR hashing, an
AST matcher, and clang-format support.

The work was done as twenty-one gated steps, each with its own regression
gate, and every place the build contradicted the design was recorded in a
ledger as it was found. That ledger has twenty-three rows. The interesting
ones are in this paper.

## Volume

The patch stack, replayed onto pristine trunk with no dependency on the
backtick work:

| | files | lines |
|---|--:|--:|
| Compiler proper | 77 | +1940 / −18 |
| Tests | 32 | +5133 |
| **Total** | **109** | **+7073 / −18** |

Fifteen commits, in four groups that could be reviewed independently: the flag
with the character tables and the lexer; the precedence level alone, about
twenty lines; the `DeclarationName` work; and clang-format.

Under two thousand lines of compiler for the whole feature. The largest single
piece is the `DeclarationName` kind at roughly 250 lines across 19 files, and
the expression node at 437 lines across 31 files.

The regression gate, the full `check-clang` suite of 54,000 tests, is green
with the flag on and off, and the flag-off build is byte-identical in
behaviour to upstream on translation units containing these code points in
every position.

## The three-for-three result

Every place C++ keys operator behaviour off a closed kind, opening it cost a
*parallel* implementation and never a widened one:

- the declaration checker is a sibling of the overloaded-operator checker, 54
  lines sharing no code with it;
- the candidate assembler is a sibling of `CreateOverloadedBinOp`, of which
  exactly one six-line helper could not be reused, the one whose first line
  converts an operator kind into a name;
- the expression node is a sibling of `CXXOperatorCallExpr`.

There is a fourth, and it is the one that reads best: the AST matcher
`hasAnyOperatorName()` could not be supported at all, because it returns a
string reference into a static spelling table and a user operator's spelling
is computed. A matcher API that structurally can not name your operator says
more about how closed the tables are than any line count.

The upside of the sibling pattern is that "no existing operator's rules moved"
is *provable* rather than tested. The shared checker was never touched, and
the class-or-enum branch is unreachable from the new path; nothing skips it
conditionally.

## What the compiler does not tell you

Adding a name kind and an expression node obliges 67 dispatch sites across
three independent axes. How each was found is the number worth reporting:

| Found by | Sites |
|---|--:|
| Link error | 14 |
| `llvm_unreachable` in an exhaustive switch | 8 |
| `-Wswitch` warning only | 2 |
| A lit test | 1 |
| Nothing at all | **42** |

Two of those 67 were reachable only by reading a build log, on a build whose
`LLVM_ENABLE_WERROR` is off. One was generated by TableGen and is not
greppable as C++. The toolchain finds about a third of a new node's
obligations and is silent about the rest.

The same shape recurred in testing. Four separate defects passed their tests
before being caught by something else: token-dump tests pass under a
preprocessor-only action that disables the identifier recovery path that was
broken; spacing and annotation tests pass while long-chain wrapping is wrong;
a UCN identity bug is invisible to any token-level comparison; serialization
code written because a linker demanded it had no test at all. The tests that
pass are the ones you thought to write.

## Mangling and ABI

The Itanium vendor-extended operator production `v <digit> <source-name>`
exists for operators the grammar did not anticipate. The rule, stated so it
can be reviewed instead of inferred from an example: the source-name is
`"op_u"` followed by the code point in uppercase hexadecimal, no `U+` prefix,
zero-padded to a minimum of four digits and widened above the BMP, emitted as
an ordinary `<source-name>`. The arity digit is the declared arity, counting a
member's implicit object parameter.

```
int operator⊞(S, S)         _Zv28op_u229E1SS_       operator op_u229E(S, S)
int operator⊖(S)            _Zv18op_u22961S         operator op_u2296(S)
int T::operator⊞(T) const   _ZNK1Tv28op_u229EES_    T::operator op_u229E(T) const
template …operator⊠<int>    _Zv28op_u22A0IiEiT_S0_  int operator op_u22A0<int>(int, int)
```

"Demangler-tolerated" undersells the result. Both `llvm-cxxfilt` **and GNU
binutils `c++filt` 2.46** — a different vendor's demangler, unmodified —
render every form tested, including nested-name, const-qualified member,
explicit-object member and template-id. Existing toolchains need no change to
inspect these symbols.

The Microsoft ABI has no such production. The implementation declined to
invent one: a Windows target accepts every declaration, because the name is
representable, and rejects the first definition with an honest
cannot-mangle-this-yet diagnostic. The asymmetry is the finding. **The Itanium
ABI reserves a production for operators it did not anticipate and the
Microsoft ABI does not, so a portable version of this feature needs a
Microsoft decision that Itanium does not need.** That is the whole of the
feature's ABI surface: one production on Itanium, one open question on
Windows, nothing else.

A first-class `<operator-name>` keyed by code point remains the right answer
for a standardized feature, and needs the ABI group. It has one further
advantage found in passing: it has no arity digit to disagree about.

## Formatting

clang-format required 32 lines. A user operator is annotated as a binary or
unary operator by position, with no delimiter pairing and no break-suppression
rules, and the existing overloaded-operator handling rewrites the annotation
after `operator` with no new rule. It also honours `BreakBeforeBinaryOperators`,
which a delimiter-pair syntax structurally can not.

One touch point was not obvious: the formatter's own precedence query needs the
feature enabled, or the token answers "unknown", the expression parser builds
no structure for a chain, and long-chain wrapping is wrong while every spacing
and annotation test passes.

# What is not resolved

- **Microsoft mangling.** Unanswered, and unanswerable without the vendor.
- **The Itanium first-class production.** The vendor-extended form is a
  prototype answer; a standardized feature should have a real one.
- **Member-versus-non-member sequencing.** Overload resolution deciding
  evaluation order is novel, and CWG should say what it wants.
- **Default arguments in prefix position.** Keep the relaxation and document
  it, or reinstate [over.oper]p8 for user operators.
- **Fold expressions** over the user-infix level, for both features at once.
- **Postfix**, deferred with a measured account of what it would cost.
- **Static member user operators**, currently rejected.
- **Combining-mark operator sequences, and the Latin-1 candidates** (± × ÷ ¬),
  both deliberately out of the frozen set and both coherent extensions.

One limitation is this feature's own, and is reported rather than left to be
found: `t.template operator⊞<int>(0)` on a dependent object expression is
rejected, because the implementation's dependent-template representation holds
an identifier or a built-in operator kind and nothing else, and a new operator
name is neither. Every non-dependent spelling works, and so does a dependent
call without the `template` disambiguator. It is the same
closure-over-a-fixed-operator-table cost the name tables and candidate
assembly pay, reaching a third data structure, and closing it means admitting
a third alternative there. It is tempting to call it inherited, because the
identical construct on a user-defined literal operator gives a
character-identical diagnostic — but that rejection is *correct*: a literal
operator can never be a class member, so no valid program contains the
construct. So the operator-function-id names the overload set where an
unqualified-id does, with that one exception, and the exception is new.

# Relation to the backtick proposal

D4307 proposes an infix operator for *named* callables and a keyword escape.
This paper proposes operators drawn from *symbols*. They share one grammar
production's worth of design (the user-infix level, left-associative,
desugaring to a call) and nothing else. The character set, the UCN and
identifier interplay, the *operator-function-id* and [over.oper] changes, the
SG16 review and the ABI note are all disjoint from D4307.

They are separate papers because their routing differs, their maturity differs
and their fates must stay separable. Unicode-allergy is real in the room and
must not be able to sink the backtick paper.

That separability is now measured rather than asserted. The Unicode work was
prototyped on top of the backtick branch and then replayed onto pristine
trunk: **201 of 204 hunks survived unchanged, and 169 of 171 production
hunks.** The entire coupling between the two features is three constructs —
the shared precedence enumerator, the fold-operator exclusion of it, and one
predicate in the formatter. Decoupling cost one test file out of twenty-one
and none of the fifty-two unit tests.

The shared level surfaced twice, independently: once in the parser, once in
the formatter, in two subsystems that do not know about each other and both of
which needed to ask "is this a user-introduced infix operator?". One
precedence level for all user-introduced infix syntax is a real design
primitive, and the two papers should bank it once, with both features in
view, whichever of them proceeds.

# Acknowledgments

The implementation was carried out as a gated, one-step-at-a-time experiment;
the deviation ledger it produced is the source for most of this paper's
corrections to its own design.

A defect found in passing and unrelated to this proposal: Clang mangles both
prefix and postfix `operator++` — and `operator--` — as `pp` and `mm`, where
the Itanium ABI (§5.1.3, §5.1.6) spells the prefix forms `pp_` and `mm_`. Two
overloads distinguished only by that mangle identically on Clang and distinctly
on GCC 15.2. Reported upstream as llvm/llvm-project LLVM-ISSUE-PENDING.
