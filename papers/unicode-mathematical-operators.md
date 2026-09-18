---
title: "Extending C++ with Unicode Mathematical Operators"
subtitle: "Declaring `operator⊞`, and what an implementation says about it"
document: D4345R0
date: today
audience: SG16, EWG
author:
  - name: Steve Downey
    email: <sdowney@gmail.com>
toc: true
toc-depth: 2
# Latin Modern Mono has none of the operator glyphs this paper is about, so
# every code block in the PDF rendered `operator` followed by nothing. This
# is not a style preference; without it the paper's subject matter is
# invisible in one of its two output formats.
monofont: "DejaVu Sans Mono"
---

# Abstract

We propose that a user be able to declare `operator⊞` and write `a ⊞ b`. That
is the whole feature: a frozen set of Unicode symbols that have never had
meaning in C++ becomes available as operator tokens, and an operator drawn
from that set
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
off current trunk, and every rule below is written from that prototype. Where
the build contradicted what the rule was going to be, the section states the
rule that survived and says what the build showed.

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

# The design

## `x ⊞ y` is the call

An operator drawn from the set is an ordinary name, and an expression written
with one is an ordinary call. `x ⊞ y` *is* `operator⊞(x, y)`; `⊖x` *is*
`operator⊖(x)`; the member forms are `x.operator⊞(y)` and `x.operator⊖()`.

The design rests on that *is* holding all the way down. Overload resolution,
argument-dependent lookup, templates and SFINAE, `constexpr` evaluation,
conversions, value categories and code generation are the call's, and this
proposal restates none of them. The feature has no evaluation-order rule of its
own, no conversion rule, no template rule, and no constant-evaluation rule.

What is left to specify is three things: which characters may name an operator,
where the token may appear, and how a declaration is checked. Everything else
in this paper is one of those three, or is what it costs a compiler to make the
*is* true.

## What this paper fixes

An *operator-function-id* may be `operator` followed by a **user-operator
token**: a single non-ASCII code point drawn from an enumerated set frozen by
this paper. Such a function is an ordinary free or member function.

- **One precedence level.** A user-operator token after a complete operand is a
  binary operator at the **user-infix level** (the highest binary level,
  tighter than `*`, looser than the unary operators), left-associative, with
  cast-expression operands. Every user-introduced infix operator binds at that
  one strength, and there is no table.
- **No fixity declarations, ever.** Precedence and associativity are fixed
  here. Only the *meaning* of `operator⊞` travels with the name, and that is
  ordinary lookup.
- **Position decides fixity at the use.** Operand position is prefix,
  post-operand is infix. No lookahead, no whitespace rule, no consultation of
  what is declared, and one code point can be both in one expression.
- **Arity decides the form at the declaration, and does not filter uses.** Two
  parameters, or one as a member, is infix; one parameter, or none as a member,
  is prefix. The same convention as `operator-`.
- **No built-in candidates.** There is no built-in meaning to protect, so
  nothing adds any. `p ⊞ n` on `int*` is a no-viable-overload error.
- **Candidates are assembled as for an existing overloaded operator**: member
  and non-member together in one set, with ADL.
- **No postfix form, and no fold operator.** Both are declined in this
  revision, and neither is foreclosed. Both are priced below.

## Three constraints the design holds itself to

**The operator set must be disjoint from identifier space, and provably so.**
A character that can name an entity must not also be able to name an operator.
The paper does not assert the partition; it measures it, per code point,
against a compiler's own tables.

**The enumeration is normative and frozen against a named Unicode version.**
The Unicode properties that derive the set are inputs to a derivation run once.
A set that grew on Unicode's schedule would admit characters no confusability
audit had ever seen.

**The relaxation must not reach the existing operators.** `operator+` and its
siblings are hedged about with restrictions that exist for good reasons, and a
user operator inherits almost none of them. That is only safe if the two are
implemented apart instead of by widening what already exists, so the paper
reports, site by site, which of those the prototype did.

## Relation to D4307

D4307 proposes an infix operator for *named* callables, `` x `f` y ``, and a
keyword escape for using a keyword as an identifier. It is a separate paper to
a separate audience, and the two are adoptable independently, in either order.

The two share exactly one thing: the user-infix level above. Neither feature
owns it, and where a decision here binds the shared level, as the fold-operator
exclusion does, this paper says so. The character set, the UCN and
identifier interplay, the *operator-function-id* and [over.oper]{.sref}
changes, the SG16 review and the ABI work are this paper's alone. Evidence that
the two are separable in a compiler, as well as on paper, is at the end.

# The token set

## Deriving it

UAX #31 (revision 43) defines **R3c, "User-Defined Operators"**: operator
syntax over the characters with the Pattern_Syntax property. That is
the normative hook, and C++23 already references UAX #31 normatively for
identifiers (P1949R7), so the citation is the same shape to the same document.

R3c does not hand us a usable set directly. Pattern_Syntax includes, of
course, the ASCII operator characters, every one of which is already a token,
a token prefix, or blocked by adjacency. The usable pool is Pattern_Syntax
minus ASCII.

A code point is a user-operator token if all of:

1. it has Pattern_Syntax;
2. it is outside ASCII;
3. it lies in the mathematical and arrow blocks (U+2190–21FF, U+2200–22FF,
   U+2300–23FF, U+27C0–27EF, U+27F0–27FF, U+2900–297F, U+2980–29FF,
   U+2A00–2AFF, U+2B00–2BFF);
4. its General_Category is Sm or So, which excludes the paired brackets
   (Ps/Pe) as delimiters worth leaving unspent;
5. it is not on the exclusion list below.

Applied once against UCD 17.0, that yields **1,381 code points in 32
contiguous ranges**. The lexer's table is 256 bytes and one binary search,
on the non-ASCII path both compilers already walk for extended identifiers.

The predicates are derivation inputs; the enumeration, once derived, depends on
nothing. The proposal ships it normatively, and it is frozen.

## Immutable is not closed

Pattern_Syntax is an immutable property by Unicode's stability policy: no code
point will ever gain or lose it. However, immutable is not the same as closed.
Of the 2,760 Pattern_Syntax code points, 2,681 carry assigned characters and
**79 are still unassigned**: reserved slots inside the immutable set. Unicode
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

The exclusion list is **28 code points in three reason classes**, and the
implementation found that the three classes are not alike.

**Identifier characters, 3.** TR31 §7.1's mathematical profile earmarks `∂`,
`∇` and `∞` as *identifier* characters, and its companion syntax profile
removes them from syntactic use. They name things; they do not combine things.

**Confusables with an existing token, 13.** Each is listed with the token it
apes: `−` U+2212 (`-`), `∕` U+2215 and ⁄ U+2044 (`/`), `∗` U+2217 (`*`),
`∣` U+2223 (`|`), `∶` U+2236 (`:`), `∙` U+2219 and `⋅` U+22C5 (`.`), `≤`
U+2264 and `⇐` U+21D0 (`<=`), `≥` U+2265 (`>=`), `⇒` U+21D2 (`=>`), and `⇔`
U+21D4 (`<=>`). These are rejected outright and never aliased. A character
that looks like `-` and is not `-` must fail to lex.

U+2044 FRACTION SLASH is the one entry that predicate 3 would have
excluded anyway, since it sits below U+2190. It is kept on the list so the list
carries the whole output of the confusability audit, and so a reader who writes
it gets told which token it apes instead of a stray-character error.

**Emoji presentation, 12.** The code points inside the blocks that TR31
§7.2's emoji profile carves out: U+231A, U+231B, U+23E9 through U+23EC,
U+23F0, U+23F3, U+2B1B, U+2B1C, U+2B50 and U+2B55 — watches, hourglasses,
media-control triangles, large squares, a star and a circle. They are named
by code point here because a document that prints them is at the mercy of
whichever font renders it, which is itself part of why they are out.

Nothing derives the ASCII token named beside each confusable; it is
**curated**. The generator takes no confusability data as input, and it should
not: the published tables answer "what does this look like", while the
diagnostic needs "which C++ token does this look like", and the two come
apart. `∙` and `⋅` *mean* multiplication and *look like* `.`, and it is the
look that endangers the reader; `⇔` is spelled `<=>`, a token this language
acquired in 2020. The principle is one line, and the paper states it outright,
having no derivation to claim: the spelling names the token a reader is most
likely to mistake the character for, not the operation the character denotes.
For the same reason the message says the character *is
confusable with* the token, never *did you mean*, and carries no fix-it: a
confusability claim is an assertion about reading, an intent guess is an
assertion about writing, and only the first is one a compiler is entitled to
make.

Keeping the exclusions in a table with their reasons lets the diagnostic say
why, instead of emitting a generic stray-character error. The
table alone is not enough, and the prototype is where that showed: the three
reasons need three different emission points.
Confusables and emoji were never identifier characters, so rejecting them at
token classification is safe. `∂` `∇` `∞` *are* valid identifier characters.
In Clang they are valid today, with no flag, because the math-identifier
extension (D137051, P3658R1) is on by default at every `-std=`. A diagnostic
for them at classification would fire on every legitimate use of `∂` as a
name. The implementation emits that one as a note, in the declarator parse,
after a conversion-function-id parse has already failed.

The rule generalizes past this feature, and a later proposal that adds
exclusions will need it: a reason is emittable at token classification if
and only if its code points can not also be identifier constituents.

One name did not survive the enumeration. "The middle-dot family" is not a UCD
family: inside the blocks it is exactly `∙` U+2219 and `⋅` U+22C5, because
U+00B7 MIDDLE DOT is **not** Pattern_Syntax (Unicode withheld it precisely for
its use *in* identifiers, in Catalan), so it was never a candidate.

## The operator set and the identifier set are disjoint

TR31 partitions syntax space from identifier space by construction. The
question is whether it holds against a real compiler, and it does, measured
per code point against the compiler's own tables and not against the UCD:
of the 1,381 members of the set, **zero** are XID_Start, zero XID_Continue,
zero in the math-identifier profile tables, and zero in the C++11–C++20
Annex E identifier whitelist. That is a unit test in the implementation, not
an argument in a document, and it iterates the whole set.

It came out stronger than it had to, by an accident of timing.
The set is derived against UCD 17.0; Clang's in-tree identifier
tables have already moved to Unicode 18.0. The partition survived the UCD
moving underneath it, which is the version-skew case a real
implementation faces: a compiler updates its XID tables on Unicode's schedule
while a frozen operator list does not move.

An implementer will meet one consequence of the partition. With the
math-identifier extension on, `operator∂` **without a space** is a single
identifier: `int operator∂(S, S);` declares a function *named* `operator∂`.
With a space, `operator ∂` is a conversion-function-id. Whitespace is
load-bearing in that corner, and only there.

## Spelling: the glyph and the UCN

A universal-character-name designating a user-operator code point (including
the C++23 named form) forms that operator token. `operator⊞`,
`operator\u229E` and `operator\N{SQUARED PLUS}` are the same declaration
(declare with one, define with another, use with a third, and the compiler
emits one symbol), and `a \N{CIRCLED TIMES} b` is `a ⊗ b`.

The absence of UCN punctuators today is an accident: every punctuator so far
has been in the basic character set. These are the first non-basic
tokens, and the extended-character-equals-UCN equivalence the language
maintains for identifiers is the escape hatch for source encodings, fonts and
review tools that can not carry the glyph. It must extend to them.

Calling that free by construction is the obvious reading, and it is half
right.
The lexer's existing UCN path already produces a code point that takes the same
classification as a literal one. Classification is free. Identity is not.
The first implementation classified UCN-spelled operators correctly and
derived the operator's identity by decoding the token's spelling as one UTF-8
scalar, which answers zero for a UCN. That value is the `DeclarationName`, the
mangled name, the printed form, and the on-disk lookup key, so
`operator\U0000229E` would have been a *different entity* from `operator⊞`,
mangling `op_u0000`, while a token dump looked perfectly correct. Every test
that would have caught it had to be a declaration-and-use cross-spelling
assertion; no token-level comparison can see it.

The equivalence the UCN rule claims is an equivalence of entities, and the rule
has to say so.

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
cast-expression operands. That is the *user-infix level*, and it is meant to
serve all user-introduced infix syntax: it is the same level D4307 introduces
for the backtick operator. Neither feature owns it.

Symmetry falls out of the operand grammar: `-a ⊞ -b` is `operator⊞(-a, -b)`.

```cpp
-a ⊞ -b            // operator⊞(-a, -b)
a * b ⊞ c          // a * operator⊞(b, c)
a ⊞ b ⊗ c          // operator⊗(operator⊞(a, b), c)
a ⊞ ⊖b             // operator⊞(a, operator⊖(b))
⊖a ⊞ 2 * ⊖b        // (operator⊖(a) ⊞ 2) * operator⊖(b)
```

Readers get the last line wrong, and it is the only example that shows all
three binding strengths at once.

What does not appear: a delimiter-suppression rule, a nesting rule, a slot
grammar. Each operator is one distinct token, so the ordinary
operator-precedence code handles it. In the implementation the entire infix
production is one `case` in the precedence table, one fourteen-line arm in
the binary-expression loop, and the flag threaded to the three places that
ask the token its precedence. Nothing in that loop is widened, and no
existing operator's arm is touched.

## Prefix, and how position decides

Arity selects the form at the declaration: two parameters (one as a member) is
infix, one parameter (none as a member) is prefix, the same convention as
`operator-`. Position selects it at the use: post-operand is infix, operand
position is prefix.

Position alone suffices, with no lookahead, no whitespace rule and no
consultation of what is declared. The structural reason makes the claim safe
rather than lucky: the cast-expression parse is reached only in
operand position, the binary-precedence lookup is consulted only after a
complete operand, and the two never examine the same token. The same code
point can be both, in one expression: with both overloads declared, `⊖a ⊖ b`
is `operator⊖(operator⊖(a), b)`, and so is `⊖⊖1 ⊖ ⊖⊖2`.

The prefix production cost one `case` in the cast-expression parse, about
forty lines, one file, and no change anywhere downstream. It shares the infix
form's single Sema entry point: arity is the number of operands handed to it.

## Postfix, and why not

No postfix form is proposed, and the reason is not the one usually given. The
question gets asked immediately.

`operator++` does not solve prefix-versus-postfix disambiguation. It *dodges*
it: prefix is parsed in the cast-expression parse, postfix in the
postfix-suffix parse, two grammar positions, zero lookahead, and it works only
because `++` has no infix form. A user operator can be declared infix and
postfix, and after a complete operand the parser would have to decide whether
it is holding a finished expression or one awaiting a right operand.

Nor is the `operator++(int)` dummy-parameter convention available. It is
unambiguous for `++` because no infix `++` exists to collide with; this
proposal admits `operator⊞(T, int)` as a legitimate *infix* declaration, so a
distinguished tag type would be forced. That tag would have to be known to the compiler,
which makes the feature library-affects-language, with `std::strong_ordering`
as the precedent and its 452 lines of dedicated AST support as the price.

However, a tag would disambiguate *declarations*, and the ambiguity is at the
*use*. Lexing and parsing are declaration-independent, so no declaration can
inform the parse.

There is a rule that works, and it was prototyped: after a complete operand, a
user operator followed by a token that can begin a cast-expression is infix,
otherwise postfix. One token of lookahead, no backtracking, no whitespace
sensitivity. It is 68 lines in one file. However, it costs three things, and
building it is how all three were found. The witness set is every
cast-expression starter,
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
exactly that position. Every program greedy-infix would reinterpret is one
this proposal rejects. Postfix can be added by a later paper without
changing the meaning of any program this one accepts.

## Fold expressions

A user operator is not a fold operator: `(... ⊞ N)` is ill-formed, and the
diagnostic is `expected expression`. That is a decision this proposal takes,
and it is stated here because nothing in the diagnostic would state it.
D4307's backtick operator gets the character-identical diagnostic at the same
level, so the decision covers both features and is taken once.

Excluding costs one clause in the predicate that already decides which
operators may be folded over. Admitting would cost a change to the
fold-expression node itself, which stores its operator as a fixed operator
kind and has nowhere to put a user operator. And admitting later takes nothing
back: every program a future revision would newly accept is one this proposal
rejects, the same forward-compatibility shape as the postfix answer above.

One note for an implementer, because the exclusion fails quietly: it adds a
clause to that predicate rather than modifying one already there.
Dropping it does not break a build or a test. It silently makes a user
operator foldable.

# Declaring, looking up, desugaring

## Arity is the only rule that carries over

[over.oper]{.sref} imposes five restrictions on an operator function. A user
operator inherits exactly one of them, and the reason generalizes past the
class-or-enum exception:

> [over.oper]{.sref}'s restrictions exist to protect a token whose parse,
> arity and fixity the grammar has already fixed. A user operator's only fixed property
> is arity, so arity is the only rule it inherits.

- **class-or-enum parameter**: does not apply. The rule protects a built-in
  meaning, and there is none. `constexpr int operator⊞(int, int)` is legal, and
  `5 ⊞ 7` finding it is the motivating case.
- **no default arguments**: does not apply.
- **not variadic**: does not apply, likewise.
- **the fixed arity table**: has no entry to consult, so the prefix/infix
  rule is written out.
- **not a static member**: kept, and kept as a *choice*, because the arity
  rule does not exclude it. That rule counts operands, so
  `static S operator⊞(S, S)` has two and would be accepted; an implementation
  must reject it deliberately. The reason is the desugaring: `x ⊞ y` is
  defined to mean exactly one of two spellings, `operator⊞(x, y)` or
  `x.operator⊞(y)`, and a static member names neither. On a static member,
  `x.operator⊞(y)` is legal C++ but discards the object expression and passes
  one argument to a two-parameter function. C++23 shipped
  `static operator()`, so this will be asked about; the answer is that a call
  operator's meaning is given by the standard, which can say what becomes of
  the object expression, while a user operator's meaning is *only* the
  equivalence, and there is nowhere else to say what a static form would do.
  Restrictive now, relaxable later by writing down a third spelling and the
  lookup that finds it.

Everything else is ordinary: templates, `constexpr`, `= delete`, member and
non-member, explicit object parameters.

Dropping [over.oper]{.sref}p8 has a visible consequence. Given only
`constexpr int operator⊟(int a, int b = 1)`, the prefix use `⊟5` is accepted
and calls it through the default argument, and adding a genuine prefix
overload makes `⊟5` ambiguous in the ordinary way. Filtering candidates by
declared arity would fix it. However, it would break the desugaring
equivalence below, on which the whole design rests: `⊟5` *is* `operator⊟(5)`,
and that is what the equivalence promises. So arity selects the form for
*declarations*, and does not filter *uses*. Reinstating [over.oper]{.sref}p8
for user operators is the conservative alternative, costs one diagnostic, and
is not what this paper asks for.

## One candidate set, and no built-in candidates

`x ⊞ y` assembles member candidates from the left operand's class and
non-member candidates from unqualified lookup and ADL, ranked together in one
set. Not three passes, and not member-first with a fallback: the observable is
that `MN{} ⊘ 0` selects the non-member and `MN{} ⊘ 0L` selects the member.

The normative requirement is that the operator form finds what the explicit
call finds. The implementation asserts it as type identity over a
tag-returning overload set, which is stronger than checking that both forms
compile:

```cpp
static_assert(__is_same(decltype(x ⊘ y), decltype(operator⊘(x, y))));
```

for every ADL shape, plus the member desugaring, plus both negative halves.

There are **no built-in candidates**, and the implementation of that rule is
that nothing calls the function which adds them. `1 ⊠ 2` with nothing declared
is an ordinary undeclared-name error. `p ⊞ n` on `int*` is a no-viable-overload
error, never pointer arithmetic. This is the difference from `operator+`.

The implementation separated ADL from member-candidate assembly, so the two can
be priced apart, and the non-member half costs nothing at all.
The callee is a name the compiler forms from the token and never an
expression the parser resolves, so a stub of a dozen lines (one operator-name
lookup, its result handed to the ordinary call builder as an *unresolved* set)
already yields hidden friends reachable by nothing else, augmentation of a
non-viable ordinary-lookup set, and ADL from the instantiation context. Member
candidates were the entire remaining job.

State it as a rule, because the backtick project got it wrong in both of its
compilers and in the same way: each resolved the name in the parser, and each
silently lost ADL. ADL is what you get by not writing code; losing it is what
you get by writing some.

## The expression node, and two-phase lookup

This is the strongest evidence in the paper for the claim that C++'s operator
tables are closed, and no reading of the grammar would have produced it.

Clang's `CXXOperatorCallExpr` exists to record that a call was *written* with
operator syntax, and `TreeTransform` reads the operator kind back off it to
re-run operator candidate assembly at instantiation. It stores an
`OverloadedOperatorKind`, in which `OO_None` is itself a valid operator kind,
so there is no spare state and it can not carry a user operator.

Leave the use as an ordinary call (which is what the desugaring says
it is) and the non-dependent case is correct in every shape tested. However,
when an operand is type-dependent, `TreeTransform` rebuilds the expression
through the ordinary call path: [over.match.call]{.sref}, not
[over.match.oper]{.sref}. ADL survives, because ADL is a property of the call.
Member candidates do not, because they are a property of the operator syntax.
So

```cpp
template <class T> constexpr auto f(T a, T b) { return a ⊕ b; }
```

failed for a member `operator⊕`, and `requires(T a, T b) { a ⊕ b; }` was
unsatisfied for that `T`. The desugaring was exact and the compiler still got
the wrong answer. Nothing short of a build would have found that.

The fix is a node, `UserOperatorExpr`, that stores the code point, the
arity and the operator location, recovers the operands as written from the
semantic form, and re-runs the operator resolution on transformed operands at
instantiation. The right upstream model is not `CXXOperatorCallExpr` but
`CXXRewrittenBinaryOperator`, which exists for the same reason: to record that
an expression was written one way and means another, so instantiation can redo
the resolution instead of replaying the result. With the node in, both shapes
above compile, and the concept is satisfied for a type whose only `⊕` is a
member.

The node holds its operands, and that is forced. Sema may re-wrap what it hands
back (a class-typed prvalue with a non-trivial destructor comes back inside a
temporary-binding node), so a node that *is* the operator survives that, and a
node that *hides* a built call does not.

The desugaring is therefore exact for a non-dependent use, and needs a node to
survive a dependent one.

# One level, and no fixity declarations

Of the rules fixed above this is the one most likely to be argued.

A declared precedence is a semantic property that must travel with the name
across headers, modules and translation units. Two translation units
disagreeing about `a ⊕ b ⊗ c` is an ODR factory, and the parse of an expression
comes to depend on which imports are visible: Haskell's fixity-import problem,
and Swift's `precedencegroup` conflicts. With fixity settled by the standard,
the *parse* of an expression depends on nothing but the expression. Only the
*meaning* of `operator⊞` travels, and that is ordinary lookup.

That answers the first alternative, a declared fixity: a lattice a reader has
to learn and a compiler has to consult. Under one level `a ⊞ b ⊗ c` groups
left, and there is no table.

There is a second alternative, and it is the one worth answering: fix the
precedence per code point in the standard, deriving it rather than letting
anyone declare it. Julia does this, in many classes mirroring mathematical
convention, and OCaml derives an operator's fixity from its first character.
It fails here twice over. Nothing in Unicode supports the derivation:
Pattern_Syntax partitions syntax from identifiers and asserts nothing about
meaning, blocks record allocation order, and the two distinctions a reader
would actually want sit on adjacent code points. `⊕` `⊖` `⊗` `⊘` `⊙` are
U+2295 through U+2299; `∩` and `∪` are U+2229 and U+222A. Any derivation
from ranges or shapes collapses exactly the pairs it would have to separate,
so a table would have to be curated code point by code point. And a
precedence is a meaning. This paper allocates notation and leaves semantics to
the declaration, where a table would have the committee assert that `⊗` is
multiplication-like: true in tensor algebra, false in a monoidal category
whose product is written `⊕`, and backwards in a tropical semiring, where `⊞`
is addition and `⊙` is multiplication. C++ has one precedent for a fixed
precedence over a user-chosen meaning. `operator<<` inherited shift
precedence, so `std::cout << a & b` is `(std::cout << a) & b`.

One level is not neutral, and it should not be sold as though it were.
`a ⊕ b ⊗ c` groups as `(a ⊕ b) ⊗ c`, and a reader coming from the tensor
literature expects the other. Fixed fixity does not avoid surprising that
reader. It makes the surprise uniform and learnable, and it leaves
disambiguation in parentheses, which is where mathematics leaves it. Whether
a chain mixing distinct operators deserves comment is then a question for a
lint rather than for the language, and clang-tidy already occupies that
ground for the built-in operators with a check that is off by default and
that excludes `&&` and `||` by name.

# Sequencing is decided by overload resolution

One consequence of the sequencing rules needs committee attention, because no
existing operator behaves this way.

A user operator introduces no evaluation-order rule of its own and inherits
[expr.call]{.sref} wholesale. That holds cleanly for the non-member form: the
operands are function arguments, indeterminately sequenced. For a **member**
operator, the left operand is the object expression, part of the
postfix-expression, and [expr.call]{.sref} sequences it before every argument.
So `x ⊞ y` sequences `x` before `y` when a member overload wins, and does not
when a non-member wins: **the sequencing of `x ⊞ y` is decided by overload
resolution.**

No existing C++ operator does this. [over.match.oper]{.sref}p2 gives an
overloaded built-in-spelled operator the built-in's sequencing regardless of
member-ness, and a user operator has no built-in to borrow from. The question
is this feature's alone: D4307 inherits [expr.call]{.sref} the same way, but a
backtick slot has no member form for the split to arise in. The implementation
measured the difference three ways (constant evaluation, `-Wunsequenced`, and
emitted IR), and this paper does not propose an answer. It calls CWG's
attention to the question.

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

The work was done as twenty-two gated steps, each with its own regression
gate, and every place the build contradicted the design sketch this paper is
written from was recorded in a ledger as it was found. That ledger has
twenty-four rows, and the rules stated above are what came out of it. The
corrections worth a reader's time are here.

## The desugaring survives to the back end

The design rests on one claim: `x ⊞ y` *is* the call, so everything the
call has is inherited and not reimplemented. That claim gets weaker the
further from the parser it is asserted, and the last place it could fail is
code generation. It does not fail there.

Every shape — scalar, aggregate, complex, l-value-returning, and prefix —
emits code instruction for instruction identical to the explicit call written
out by hand, including the store through the pointer an l-value-returning
operator returns. Checked in both of Clang's code generators, the shipping one
and ClangIR, by emitting a translation unit that writes each operation twice
and diffing the two function bodies. There is nothing left downstream to
check.

## Volume

The patch stack, replayed onto pristine trunk with no dependency on the
backtick work, re-measured against its own base commit on 2026-09-08:

| | files | lines |
|---|--:|--:|
| Compiler proper | 86 | +2035 / −18 |
| Tests | 34 | +5416 |
| **Total** | **120** | **+7451 / −18** |

Twenty commits, in groups that can be reviewed independently: the flag with
the character tables and the lexer; the precedence level alone, twenty-four
lines over three files; the `DeclarationName` work with declaration checking
and mangling; the parse and candidate assembly; the AST node; serialization
and matchers; clang-format; the static analyzer; and the second code
generator.

Two thousand lines of compiler for the whole feature. The largest single commit
is the expression node, 436 production lines across 31 files. After it come the
parse and candidate assembly, 276 lines across 4, and the `DeclarationName`
kind, 249 across 19: nearly the same size as each other, and one of them
touches five times as many files.

The regression gate is the full `check-clang` suite: 54,242 tests discovered,
48,324 run and passed, none failed. The feature's own tests turn the flag on;
everything else runs with it off, which is the shape that makes the gate mean
something. Two further checks pin the flag itself. On a translation unit that
never mentions the feature, the emitted IR is byte-identical with the flag on
and with it off. And in C mode the flag is inert: the diagnostic output is
*byte-identical*, which is a stronger assertion than harmlessness, and the
first attempt gave neither.

## Opening a closed table cost a parallel implementation, five times out of five

Every place C++ keys operator behaviour off a closed kind, opening it cost a
*parallel* implementation and never a widened one. Three of the five produced
a sibling:

- the declaration checker is a sibling of the overloaded-operator checker, 53
  lines sharing no code with it, called from a separate `if` beside it;
- the candidate assembler is a sibling of `CreateOverloadedBinOp`, and the
  split falls on a clean line: everything the existing one does that is keyed
  off an *operator kind* (member-candidate assembly, built-in candidates, the
  rewritten-candidate handling, the operator-call node) could not be reused,
  and everything keyed off a *name* was reused verbatim, including
  non-member candidates, ADL, best-viable selection and the call builders.
  Candidate assembly is the only genuinely new code;
- the expression node is a sibling of `CXXOperatorCallExpr`.

The fourth produced no sibling at all. The AST matcher `hasAnyOperatorName()`
could not be supported: it returns a string reference into a *static* spelling
table, and a user operator's spelling is a UTF-8 encoding computed into a
buffer, so a matcher over user operators has to be keyed on the code point
instead. The matcher that does exist says so in its own documentation. The
tables are closed enough that a public matcher API can not name your operator.

The fifth turns the count into a claim. Postfix-ness — see above — has no
representation in Clang to make a sibling of. There is no `isPostfix()` on the
operator-call node and no "can this token begin an expression" predicate
anywhere; both are re-derived at every consumer from an operator kind and an
argument count. A feature that wanted user postfix operators would not be
widening a closed table or writing a sibling beside one. It would be writing
down, for the first time, something the language has always had and never
stored.

Little of this is Clang's in particular. GCC keeps its operator identifiers in
a fixed-size table indexed by tree code, and the move there is the same one:
`cp_literal_operator_id` already synthesizes an identifier *outside* that
table for `operator""_suffix`. Two compilers, one shape.

This is the reassurance the proposal most needs to give, and it is structural.
Every site is parallel and no table the
existing operators are keyed on is ever widened, so the relaxation provably
can not leak into `operator+`. The shared checker was never touched; the new
kind is a new arm *beside* the old one everywhere it appears; and a program
that declares no user operator reaches none of them. That is a stronger claim
than "it is behind a flag".

## What the compiler does not tell you

Adding a name kind, a declarator-id kind and an expression node obliges 89
dispatch sites on three axes that share no site: 34 over the name kind, 12
over the declarator-id kind, and 43 over the expression node. The three
numbers matter less than the answer to a different question, asked of the
node's 43: which of them did the toolchain make you find?

| What forces the site | Sites | What omitting it costs |
|---|--:|---|
| A link error | 6 | The build fails. |
| An exhaustive `switch` ending in `llvm_unreachable` | 8 | Compiles; aborts the first time the node reaches it. |
| A `-Wswitch` warning, on a build whose `LLVM_ENABLE_WERROR` is off | 2 | Found only by reading the build log. |
| Nothing at all | **19** | Silently wrong. |
| Nothing at compile time, and only in a configuration nobody had built | 4 | Latent. |
| Nothing, and *absent* instead of wrong | 3 | The node is invisible to the matcher layer. |
| Nothing — and the site exists only because another obligation was met | 1 | See below. |

The toolchain forces about a third of a new node's obligations, warns about
two, is silent about nineteen, hides four behind a build configuration, and
has no opinion about three more. These figures were taken on 2026-09-06 from
the branch carrying this feature alone, and the categories sum to the total by
construction, which is a cheap invariant that this project did not have and
should have: an earlier count in the same notes circulated for weeks while
being short of its own inputs.

The configuration-latent row is the one a vendor prototyping a language
change is most likely to ship without. Those four are the second code
generator, which nothing about the language or the visitor design made
special. What made them latent was a CMake default, and every build directory
in the project had it. How many obligations a new expression node has is
bounded by the configuration of the tree you measure in.

Two things this axis can not see, and measurement found both
where review had not. The last row is an obligation created by *meeting*
another one: teaching the control-flow graph to look through the wrapper is
what removes the wrapper's program point, and removing its program point is
what makes the static analyzer's bug reporter fail to find it. Nothing forces
it — no link error, no unreachable, no warning, no failing test — and it sits
below even the warned-about sites. And whether the toolchain helps you at all
is a property of *how a site is spelled* and not of what it dispatches on: a
`switch` over a closed enum is checked, a chain of `==` tests against the same
enum is not, and the two are interchangeable at the moment of writing. Two of
the 34 name-kind sites and five of the 12 declarator-id sites are the
unchecked spelling. An implementer estimating this feature from the shape of
the enums will under-count by exactly the sites somebody once wrote as an
`if`.

The same shape recurred in testing. Four separate defects passed their tests
before being caught by something else: token-dump tests pass under a
preprocessor-only action that disables the identifier recovery path that was
broken; spacing and annotation tests pass while long-chain wrapping is wrong;
a UCN identity bug is invisible to any token-level comparison; serialization
code written because a linker demanded it had no test at all. The tests that
pass are the ones you thought to write.

## Where the cost estimate went wrong, in a predictable direction

The sketch this paper is written from said that parsing is the easy part of
this feature, easier even than backtick. The prototype contradicted that from
four directions.

The first half survives. The parse really is small, on both sides: the *using*
side is two `case`s in a precedence loop that already exists, and the
*declaring* side, which the sketch left out, is about ninety lines. The
second half does not survive. The parse is not where either feature's cost
lives.
Backtick's cost is in the parse and ends there; this feature's cost is in what
a parsed operator has to *become*: a **name**, in tables that are closed, and
an **expression node** that can not be transparent, because a user operator
has member candidates and a backtick slot does not. The comparison inverts as
soon as it leaves the parser.

The direction of the error is what generalizes. The parser estimate was right
and stayed right, so this was never a bad guess about parsing. It was a design
document measuring the part of a feature a design document can see. The
parse is visible from the grammar, so it gets estimated. The name tables and
the node are invisible until something is built, so they get omitted, and
their omission reads as a claim that they are small. Anyone reading an
implementation sketch for a language feature should expect that error, in that
direction.

## Mangling and ABI

This section says three things in order: what the prototype implements, what
this paper asks the Itanium ABI group for, and what Windows still owes an
answer to.

### What is implemented, and why it needs nothing

The Itanium vendor-extended operator production `v <digit> <source-name>`
exists for operators the grammar did not anticipate, and the prototype uses
it. The derivation rule:

> `op_u`, followed by the code point in **uppercase hexadecimal**, with no
> `U+` prefix, zero-padded to a **minimum of four digits** and widened as
> required above the BMP — five digits from U+10000, six from U+100000.

The arity digit is the declared arity, counting a member's implicit object
parameter. Injectivity comes from the hex. Padding never contributes any of it:
leading zeros are only ever added to reach four digits, and every code point
above U+FFFF already needs five.

```
int operator⊞(S, S)         _Zv28op_u229E1SS_       operator op_u229E(S, S)
int operator⊖(S)            _Zv18op_u22961S         operator op_u2296(S)
int T::operator⊞(T) const   _ZNK1Tv28op_u229EES_    T::operator op_u229E(T) const
template …operator⊠<int>    _Zv28op_u22A0IiEiT_S0_  int operator op_u22A0<int>(int, int)
int E::operator⊗(this E, E) _ZNH1Ev28op_u2297ES_S_  E::operator op_u2297(this E, E)
```

Two branches of the rule are unexercised by construction and will stay that
way while the token set is frozen: every member of the set lies in
U+2190–U+2BFF, so every derived name is exactly four hex digits, and neither
the padding branch nor the astral widening can be reached without changing the
set. The gap follows from the enumeration rather than from the tests, and it
is the first thing to exercise if a later revision admits anything above the BMP.

"Demangler-tolerated" undersells the result. Both `llvm-cxxfilt` **and GNU
binutils `c++filt` 2.46** — a different vendor's demangler, unmodified —
render every form above, character-identically, including nested-name,
const-qualified member, explicit-object member and template-id. Existing
toolchains need no change to inspect these symbols, which is the first
question an ABI reviewer asks.

The symbols are pure ASCII by construction, and that matters more than it
looks. `nm | c++filt` already loses *extended-identifier* function names
today, because the demangler's stdin path splits its input on non-ASCII bytes.
A scheme that put UTF-8 in the mangled name would inherit that defect. This
one does not.

### What this paper asks for

**A first-class `<operator-name>` production, keyed by code point and
carrying a fixity marker.** This is a request to the Itanium ABI group, not
proposed wording: the ABI is not WG21's to legislate, and the vendor-extended
form above is a working fallback that needs no ABI action at all. But three
things argue for asking.

The ABI's own prose scopes the vendor production more narrowly than the
prototype uses it. §5.1.3 reads: "Vendors who define builtin extended
operators (e.g. `__imag`) shall encode them as a `v` prefix followed by the
operand count as a single decimal digit". A user-declared operator is not a
vendor builtin. The prototype's encoding is well formed and demangles
everywhere. However, it is outside the stated purpose of the paragraph that
defines it.

Nothing fixes the derivation across vendors. A mangled name is a
linker-visible contract, and "whatever the prototype did" is not one.

And `v <digit>` keys on arity, which is not fixity. Prefix and postfix unary
operators share arity 1, in a table §5.1.3 introduces by saying "Unlike
Cfront, unary and binary operators using the same symbol have different
encodings", and which spends four codes keeping unary `+ - & *` apart from
their binary selves. Distinguishing forms of one symbol is a principle the ABI
already holds; the vendor production is the one place it has no room to. That
costs this proposal nothing, because it has no postfix form. However, it would
cost the next one everything: postfix is declined here and explicitly not
foreclosed, and adopting an arity-keyed encoding as *the* answer would
foreclose it without anyone having decided to.

The shape asked for is a small delta from the production the ABI already has —
same payload, same `<source-name>` encoding, same position in the table as
`li <source-name>` for literal-operator suffixes. Only the key changes, from
*which vendor invented this builtin* to *which code point, in which fixity*:

```
<operator-name> ::= uo <fixity> <source-name>    # user-defined operator
<fixity>        ::= i                            # infix
                ::= p                            # prefix
                ::= s                            # postfix (reserved; no spelling in this revision)
```

The letters are the ABI group's to pick, and this paper does not present
them as agreed. Three things about the shape are load-bearing and the
spelling is not. The fixity marker is the reason to ask. The name stays
the ASCII hex derivation instead of the operator's UTF-8 bytes, for the
`c++filt` reason above; pretty demangling is a demangler feature and should
not be bought with a mangling decision. And reserving `s` now lets a
later revision take postfix without a cross-vendor ABI change made under
pressure.

Fixity in mangling is easy to get wrong even where the ABI spells it out, and
it spells this one out twice: §5.1.3 gives `pp` and `mm` for the postfix forms
and §5.1.6 gives `pp_` and `mm_` for the prefix ones. GCC 15.2.0 emits all
four distinctly. Clang emits the postfix spelling for both fixities of both
operators, so two function templates distinguished only by `++T{}` versus
`T{}++` collide outright: *definition with same mangled name*. That is a
Clang defect and not this proposal's, and it is the corner where the
ABI *does* have room for fixity and an implementation still missed it.

### Windows

The Microsoft ABI has no such production. The implementation declined to
invent one: a Windows target accepts every declaration, because the name is
representable, and rejects the first definition with an honest
cannot-mangle-this-yet diagnostic, pinned by a test so it reads as a stated
position. Declining to invent an ABI is a defensible
answer; a silently invented scheme would, of course, have been binding on
Windows the day it shipped.

**The Itanium ABI reserves a production for operators it did not anticipate
and the Microsoft ABI does not, so a portable version of this feature needs a
Microsoft decision that Itanium does not need.** That is the whole of the
feature's ABI surface: one production on Itanium, one unanswered question on
Windows, nothing else.

## Formatting

clang-format required about forty lines across three files: no new token type,
no annotator state, no custom spacing rule, no custom break rule and no style
option. A user operator is annotated as a binary or unary operator by position,
with no delimiter pairing and no break-suppression rules, and the existing
overloaded-operator handling rewrites the annotation after `operator` with no
new rule, so `operator ⊞` canonicalizes to `operator⊞` under the same option
that governs `operator +`, and nothing was written to make that true. It also
honours `BreakBeforeBinaryOperators`, which a delimiter-pair syntax
structurally can not.

One touch point was not obvious: the formatter's own precedence query needs the
feature enabled, or the token answers "unknown", the expression parser builds
no structure for a chain, and long-chain wrapping is wrong while every spacing
and annotation test passes.

# What is not resolved

Four things are open, and each is open because somebody other than the author
has to answer it.

- **Microsoft mangling.** Unanswered, and unanswerable without the vendor.
- **The Itanium first-class production.** Asked for above, with a shape. The
  ABI group has not been asked yet and has said nothing; the vendor-extended
  form works meanwhile.
- **Member-versus-non-member sequencing.** Overload resolution deciding
  evaluation order is novel, and CWG should say what it wants. This paper
  takes the position that the selected call's rules are the right ones and
  does not propose to legislate it.
- **Combining-mark operator sequences, and the Latin-1 candidates** (`±` `×`
  `÷` `¬`), both out of the frozen set and both coherent
  extensions for a later revision. Either would be the first thing to reach
  the mangling rule's astral and padding branches.

Four more were open in earlier drafts and are not open now. **Default
arguments in prefix position**: the relaxation is kept, and the
consequence is documented above. **Static member user
operators**: rejected, and rejected on the desugaring reason and not on the
arity rule, which would have accepted them. **Fold expressions**:
excluded, one decision for both features, forward-compatible. **Postfix**:
declined for this revision and explicitly not foreclosed, with the price
measured. Each is argued in its own section; none of them
is a question this paper is putting to the room.

One limitation is this feature's own: `t.template operator⊞<int>(0)` on a
dependent object expression is rejected, because the implementation's
dependent-template representation holds
an identifier or a built-in operator kind and nothing else, and a new operator
name is neither. Every non-dependent spelling works, and so does a dependent
call without the `template` disambiguator. It is the same
closure-over-a-fixed-operator-table cost the name tables and candidate
assembly pay, reaching a third data structure, and closing it means admitting
a third alternative there. It is tempting to call it inherited, because the
identical construct on a user-defined literal operator gives a
character-identical diagnostic. However, that rejection is *correct*: a literal
operator can never be a class member, so no valid program contains the
construct. So the operator-function-id names the overload set where an
unqualified-id does, with that one exception, and the exception is new.

# Separability from D4307, in evidence

The two papers share one grammar production and nothing else, as the design
section said. They are separate papers because their routing differs, their
maturity differs, and their fates must stay separable. Unicode-allergy is real
in the room and must not be able to sink the backtick paper.

That separability has now been executed. The Unicode
work was prototyped on top of the backtick branch and then replayed onto
pristine trunk: **200 of 204 hunks survived unchanged, and 168 of 171
production hunks.** The audit that preceded the replay predicted 201 and 169,
so the executed number came in one hunk worse than the forecast and the
conclusion did not move. Decoupling cost one test file and none of the unit
tests, and the replayed branch mentions the backtick feature nowhere: not in
the code, in a test, or in a commit message. The check is a grep over the
branch's whole history against **its own base commit**, and the base has to be
spelled out: run against a moving `upstream/main` it stops being reproducible,
because upstream has backticks of its own in Markdown fences and in an
unrelated variable name, and they accumulate in the diff as the branch ages
without anything about the feature having changed. Pinned, the count is zero,
and three separate maintenance rebases since the replay have kept it there.

The entire coupling between the two features is three constructs: the shared
precedence enumerator, the fold-operator exclusion of that level, and one
file-static predicate in the formatter answering "does this token end an
operand". Only the first is a design decision; the other two are the code
artefacts of composing. Watch the exclusion: on clean trunk nothing is renamed
and the exclusion is a pure *addition*, so dropping it fails silently, and a
user operator simply becomes a fold operator with nothing to say so.

The shared level surfaced twice, independently: once in the parser, once in
the formatter, in two subsystems that do not know about each other and both of
which needed to ask "is this a user-introduced infix operator?". One
precedence level for all user-introduced infix syntax is a real design
primitive, and the two papers should settle it once, with both features in
view, whichever of them proceeds.

# Acknowledgments

The implementation was carried out as a gated, one-step-at-a-time experiment;
the deviation ledger it produced is the source for most of this paper's
corrections to its own design.

A defect found in passing and unrelated to this proposal: Clang mangles both
prefix and postfix `operator++` — and `operator--` — as `pp` and `mm`, where
the Itanium ABI (§5.1.3, §5.1.6) spells the prefix forms `pp_` and `mm_`. Two
overloads distinguished only by that mangle identically on Clang and distinctly
on GCC 15.2, so a five-line program is rejected by one compiler and accepted by
the other. It belongs to Clang; a report is written and this
revision cites no issue number, because none has been filed yet.
<!-- LLVM-ISSUE-PENDING -->

Every measurement in this paper was re-derived from a running compiler for
this revision, with nothing carried forward from a note. Several figures did
not survive that, and the corrected ones are what is printed above.
