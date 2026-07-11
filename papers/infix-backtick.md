---
title: "An Infix Operator and a Keyword Escape for C++"
subtitle: "Two jobs for the backtick, the last free token"
document: DxxxxR0
date: today
audience: EWG
author:
  - name: Steve Downey
    email: <sdowney@gmail.com>
toc: true
toc-depth: 2
header-includes:
  - |
    ```{=html}
    <style>
    /* the highlighter has no token for backtick and marks it as an
       error (red, bold); in this paper it is the subject matter */
    code span.er { color: inherit; font-weight: inherit; }
    </style>
    ```
---

# Abstract

We propose two uses for one character: the backtick, the last printable
ASCII character with no meaning in C++ source. One makes any callable a
binary operator; the other lets a keyword be escaped for use as an ordinary
identifier. Each is independently motivated, and each is defined by rewrite
into something the language already has. They are proposed together, with
equal standing, because they share the token — two independent claims on
one character, designed separately, end in contradiction.

**The infix operator.** C++ has two kinds of binary operation. A fixed set
— the ones with tokens — may be written between their operands: `a + b`,
`a < b`, `a | b`. Every other binary operation, which is to say every
operation with a *name*, is a prefix call: `gcd(m, n)`, `dot(u, v)`,
`intersects(a, b)`. The distinction is lexical accident, not design. We
propose to erase it at the call site. Put a callable between backticks and
it is a binary operator:

```cpp
a `plus` b              // plus(a, b)
a `std::min` b          // std::min(a, b)
u `dot` v               // dot(u, v)
a `f` b `g` c           // g(f(a, b), c)   — left-associative
```

`` x `f` y `` is *defined* to be `f(x, y)`, where the text between the
backticks is an arbitrary call-eligible expression. The construct is borrowed
from Haskell (`` `div` ``, `` `mod` ``, `` `elem` ``), and it desugars in the
front end to the ordinary call, before overload resolution runs. It therefore
inherits overload resolution, ADL, templates and SFINAE, `constexpr`
evaluation, conversions, value categories, and code generation, rather than
restating any of them. There is no new overloadable `` operator` ``, no
operator registry, no fixity declarations. The feature has essentially no
semantics of its own to get wrong.

**The keyword escape.** C++ has no way to use a keyword as a name, so every
keyword the committee adds breaks every program that used the word as one.
The committee knows this, and pays for it every time: C++20 shipped
`co_await`, `co_yield`, and `co_return` because `await` and `yield` were
taken, and made `module` and `import` context-sensitive — at real
specification and implementation cost — because breaking existing code was
not acceptable. Every language that kept evolving past 1.0 grew an escape
hatch instead: Swift's `` `class` ``, Kotlin's backtick identifiers, F#'s
double-backtick names, Rust's `r#` raw identifiers. We propose the same
hatch. A backtick pair in name position escapes a keyword — `` void
`new`(); `` declares an ordinary function named `new` — and yields a plain
identifier, so lookup, mangling, linkage, and ABI are untouched. Future
keywords stop being breaking changes, and stop needing `co_`-style
circumlocution to avoid becoming one.

The two uses never collide: they occupy mutually exclusive grammatical
positions, the same position-based disambiguation the language already
applies to `*`, `&`, and `<`. Both are implemented, gated behind an opt-in
`-fbacktick` flag, in two independent compilers — public forks of Clang and
GCC, with tests. This is a pure core-language proposal targeting C++29. No
library additions are proposed.

# Before / After

## The infix operator

::: cmptable

### Before
```cpp
if (approx_equal(dot(u, v), 0.0))
    reject(u, v);
```

### After
```cpp
if (u `dot` v `approx_equal` 0.0)
    reject(u, v);
```

---

```cpp
auto d = std::gcd(std::gcd(a, b), c);
```

```cpp
auto d = a `std::gcd` b `std::gcd` c;
```

---

```cpp
if (intersects(a, b) && !contains(a, b))
    handle_partial_overlap(a, b);
```

```cpp
if (a `intersects` b && !(a `contains` b))
    handle_partial_overlap(a, b);
```

---

```cpp
// evaluation inverts reading order:
// innermost call is the first stage
store(validate(parse(s)));
```

```cpp
// with a two-line pipe helper,
// stages read left to right
s `pipe` parse `pipe` validate `pipe` store;
```

:::

The prefix spelling nests where the infix spelling chains. `dot` then
`approx_equal` is the order the reader needs the operations in, and it is the
order the chain states them in; the call spelling states them inside-out. None
of the "after" column is new semantics — each right-hand side is defined as
the call on its left. The `pipe` helper in the last row is two lines of
ordinary user code (`pipe(x, f)` returns `f(x)`), shown as motivation. It is
not part of the proposal.

## The keyword escape

::: cmptable

### Before
```cpp
// C++17: fine.  C++20: ill-formed —
// 'requires' became a keyword.
bool requires(const License& l);

if (requires(user.license))
    admit(user);
```

### After
```cpp
// declares and calls an ordinary
// function whose name is "requires"
bool `requires`(const License& l);

if (`requires`(user.license))
    admit(user);
```

:::

Today the "before" column has no fix short of renaming the function and every
use of it, across every translation unit and every client. With the escape,
the declaration and its call sites take a backtick pair and nothing else
changes — same name, same mangling, same ABI. The deeper payoff is
prospective: a committee choosing a future keyword no longer has to weigh
breaking every use of a good name against mangling the keyword into
`co_`-style circumlocution or context-sensitivity. The escape hatch makes
clean keywords affordable.

# The proposal

Two features, one token, one paper.

**The infix operator.** `` x `f` y `` is sugar for `f(x, y)` — equivalently
`(f)(x, y)` — where the operator slot between the backticks is an arbitrary
expression parsed as an *assignment-expression*. The value, type, and
semantics are exactly those of the corresponding call. The operator is
left-associative and binds tighter than any other binary operator, looser
than the unary and postfix operators.

**The keyword escape.** In any position where the grammar expects a name — an
operand, a primary-expression, a *declarator-id*, after `.`, `->`, or `::` — a
backtick pair wrapping a keyword denotes an ordinary identifier whose
spelling is that keyword. It is purely a source-level construct; the
resulting identifier participates in lookup, mangling, and linkage exactly as
if the word had never been a keyword.

Both are gated during the proposal period behind a compiler flag; a
standardized form drops the gate. Under the flag off, every existing valid
program is untouched — backtick remains, as today, a character with no
meaning outside literals.

# Design choices and decisions

The implementation work was run against a numbered decisions log; the
decisions that shape the design are argued here. EWG poll outcomes can be
recorded against these numbers.

## It desugars to the call, and that is the whole design (D6)

The single most consequential decision is that the operator lowers to a call
expression in the front end, before overload resolution. It is not a macro,
not a token rewrite with its own rules, not a new expression category with
its own type rules. The compiler builds the same call node it would have
built for `f(x, y)`.

Everything else follows. If `f(x, y)` compiles, `` x `f` y `` compiles, with
the same result. If `f(x, y)` is ambiguous or ill-formed, so is the backtick
form, with the same diagnostic. ADL applies because ADL applies to the call.
Templates, SFINAE, and `constexpr` work because nothing new was added for
them to fail at. The specification burden on CWG is correspondingly small:
one grammar production and a definitional rewrite.

## Precedence: the highest binary operator, and why not higher (D2)

Backtick binds tighter than `*` and looser than the unary and prefix
operators. Both operands are *cast-expressions*, so prefix operators attach
symmetrically:

```cpp
-a `f` -b               // f(-a, -b)     — symmetric
a * b `f` c             // a * f(b, c)   — tighter than *
```

We considered the still-tighter alternative, binding above unary, so that
`` -x `f` y `` would read `-f(x, y)`. There is a real intuition behind it —
"the named operator is the tightest thing there is" — and it was rejected on
its own consequences: it makes backtick the only operator in the language
where a leading prefix operator floats *out* of its operand, so
`` -a `f` -b `` would mean `-f(a, -b)`. Asymmetric, and hard to teach.
Consistency with every other binary operator won. The sole cost is that
`` -x `f` y `` is `f(-x, y)` — which is the consistent reading anyway.

## Left-associative (D1)

```cpp
a `f` b `g` c           // g(f(a, b), c)
```

Chains group in reading order, like `-` and `/`. Nothing more to it.

## The operator slot is an assignment-expression (D4, D9)

Anything you could write as the callee of a call is admitted — a qualified
name, a member access, a lambda — excluding only a top-level comma. The
operands, being cast-expressions, exclude braced-init-lists; `` x `f` {1,2} ``
is not admitted in this proposal. The brace form is meaningful as a call
argument, and could be revisited, but a leading-brace left operand collides
with block syntax, and the workaround is to write the call. We took the
restriction.

## Bare nesting is chaining; real nesting takes parentheses (D3)

The open and close delimiter are the same token, so the slot can never
contain a bare backtick — the first interior backtick closes the slot. A
consequence worth stating plainly: what looks like nesting is
*token-identical* to a left-associative chain, and a chain is what it parses
as.

```cpp
x `f `g` h` y           // a chain:  h(f(x, g), y)
x `(f `g` h)` y         // nested:   (g(f, h))(x, y)
```

This cannot be diagnosed without contradicting left-associativity, and it
does not need to be. It is the same regrouping-changes-the-answer situation
as `a - b - c` versus `a - (b - c)`, which no compiler diagnoses either: the
grammar groups, parentheses override. The language defends against honest
mistakes, not against a type engineered to be simultaneously callable,
value-convertible, and asymmetric, deployed with the parentheses omitted on
purpose.

## Evaluation order is the call's (D15)

`` x `f` y `` adds no evaluation-order rule. Operand order is unspecified, as
in [expr.call]; since C++17 the callee — the slot, though written between its
operands — is sequenced before both of them. Source order is not evaluation
order for any other call in the language, and this is a call.

## A type name in the slot constructs (D16)

A *type-name* is call-eligible, so `` x `T` y `` is `T(x, y)` —
functional-style construction, CTAD applies:

```cpp
a `std::pair` b         // std::pair(a, b)
```

This is blessed as a consequence, not carved out as a special rule. The
result is always an expression (the slot is an assignment-expression, the
whole form is an expression by construction), so no most-vexing-parse
declaration reading can arise.

## The escape yields an ordinary identifier (D10)

The keyword escape does all of its work in the parser and none anywhere
else. `` `new` `` in a name position produces an ordinary identifier whose
spelling is `new`; lookup, overload resolution, mangling, and linkage
proceed as if the word had never been a keyword. There is no lexer
identifier-synthesis, no new name category, no ABI surface. What the escape
buys is exactly what Swift, Kotlin, F#, and Rust bought with theirs: the
committee can claim a good word as a keyword without breaking the programs
that already use it, and a program that must interoperate with one of those
languages, or with its own past, can name the entity it needs to name.

One question is deliberately left open for EWG: whether the escape is
restricted to words that actually are keywords, so that `` `foo` `` is
ill-formed rather than a noisy spelling of `foo`. The restriction buys
maximal disjointness between the two uses and forecloses nothing; the
disambiguation works without it, since it is by position, not by content.
We call EWG's attention to the choice; the implementations would support
either answer.

The cost is bounded added context-sensitivity: tentative
declaration-versus-expression parsing must recognize escapes, and tooling
must distinguish the two uses. Both implementations do.

## One spelling (D11)

Backtick is the sole proposed spelling; there is no digraph and no
alternative token. The objections to backtick — it is Markdown's inline-code
delimiter, and a dead key on some keyboard layouts — are real and minor, and
neither is a capability gap: CommonMark's multi-backtick spans already
express `` x `f` y `` in running prose, and fenced blocks (the dominant case)
are unaffected. That workaround renders correctly today on GitHub and on the
committee's own Mattermost server. Against that, a second spelling doubles
the teaching, formatting, pretty-printing, and tooling surface permanently,
and fragments the one-recognizable-form idiom the readability argument rests
on. Trigraphs were removed in C++17; digraphs are vestigial. We decline to
mint a new one.

The analysis of candidate alternative spellings — including the one pair,
`\< … \>`, that would actually be better-engineered, and why adopting it
would be choosing a different operator rather than aliasing this one — is
carried in an appendix, with the rebuttals stated, so the question can be
settled against the record in this paper rather than reopened in a future
one.

## Two uses, one paper; no library (D13, D14)

The infix operator and the keyword escape share one lexical token and one
committee, so they are proposed jointly — one "what does backtick mean"
discussion in EWG, not two, and no chance of two independent papers designing
the token into contradiction. The library layer is the opposite case:
pipeline and composition helpers (`pipe`, `mbind`, and friends) are each a
few lines of user code, would route the paper through LEWG as well, and the
operator needs none of them to function. The rule is: bundle what shares a
design surface within one committee; split what is separable across
committees. So the two language uses travel together, and any standard
helpers wait for a companion library paper once usage shows which, if any,
earn it.

# Anticipated objections

## "Define `*` on a type instead"

The objection: named binary operations do not need an infix spelling,
because C++ already has one — overload an operator on a type. Saturating
multiplication does not need `` a `mul_sat` b ``; it needs a
`Saturating<double>` whose `operator*` saturates.

Note first that the lift is not optional. Overloaded operators require a
class or enumeration operand, so `double * double` cannot be given new
meaning at all; to change what `*` does to two doubles, inventing a type is
the *only* move the language offers. The objection is not "there is a
lighter alternative" — it is "the heavyweight alternative already exists."
And the committee has already voted against it with its feet, on this exact
example: C++26's saturation arithmetic ([@P0543R3]) is `std::add_sat`,
`std::sub_sat`, `std::mul_sat`, `std::div_sat` — named free functions in
`<numeric>`, not a saturating wrapper type. So are `std::gcd`,
`std::midpoint`, and `std::lerp` before it. The library keeps choosing
names because the type encodes the wrong thing.

Types are not free in C++. Haskell writes `newtype Sat = Sat Double` — one
line, guaranteed zero representation cost — and even there the wrapping and
unwrapping is felt as ceremony. C++ has no `newtype`. A usable
`Saturating<T>` is a constructor set; a conversion policy, where `explicit`
is safe and noisy and implicit is quiet and dangerous; the rest of the
operator zoo, forwarded; and an interoperation debt everywhere the wrapper
meets existing code — `is_arithmetic` says no, `numeric_limits` wants a
specialization, and every function that takes a `double` now takes a
`.value()`. That is a real class to design, review, document, and maintain,
as a workaround for one function lacking an infix spelling.

And the type is the wrong scope. Wrapping a value makes *every* operation
saturating for as long as the wrapper is on, when the intent was one
multiplication in one expression. Saturating versus wrapping versus
trapping is a property of an operation, not of an object — which is also
why the wrapper cannot compose: `operator*` can mean only one thing per
type, so an expression that needs a saturating multiply and a wrapping add
has nowhere to stand. `` a `mul_sat` b `add_wrap` c `` says it directly, at
the site where each choice applies.

Last, the lift is noise in exactly the place the objection claims to remove
it. `Saturating{a} * b` reads worse than `` a `std::mul_sat` b ``, and it
misdirects: it marks the *data* as special when the *operation* is. The
reader must go find out what `Saturating` does to `*`; the named function
said it in the expression.

The wrapper type is what we write today because the call syntax reads
worse than the operator syntax. This proposal fixes the syntax instead.

# Fitting the grammar, without collision

## The token is free

Backtick has no meaning in C++ source today outside string literals,
character literals, and raw-string delimiters — all of which are handled in
translation phase 3 before punctuator recognition, and are therefore
unaffected. A stray backtick in program text is ill-formed in every current
compiler ("stray '`' in program", in GCC's words). Only three printable ASCII
characters are unclaimed at all: the backtick, the dollar sign, and the
commercial at. And the other two are compromised — the dollar is an
identifier character under the default-on `-fdollars-in-identifiers` in both
GCC and Clang, and `@` is the Objective-C sigil in a lexer Clang shares
between the languages. Backtick is the entire remaining inventory.

## The productions

```bnf
backtick-expression:
    cast-expression
    backtick-expression ` backtick-operator ` cast-expression

backtick-operator:
    assignment-expression
```

*backtick-expression* slots between *cast-expression* and *pm-expression*:
the pointer-to-member productions consume a *backtick-expression* where they
consumed a *cast-expression*, and everything above them is unchanged. In
implementation terms this is one new top level in each compiler's binary
operator precedence table. The left recursion gives left associativity; the
*cast-expression* operands give the symmetric prefix binding of D2.

The keyword escape is a new *identifier* alternative in name positions:

```bnf
escaped-identifier:
    ` keyword `
```

yielding an identifier token whose spelling is the keyword. It appears where
the grammar wants a name — *primary-expression*, *declarator-id*,
*id-expression* after `.`, `->`, `::` — and nowhere else.

## The same-delimiter problem

The open and close delimiter are the same token, so while parsing the
operator slot, a naive expression parser would take the closing backtick as
the start of a second, nested backtick operator. C++ has been here before:
`>` inside a template-argument list is a closer, not an operator, and
`vector<vector<int>>` is handled by a parser flag — Clang's
`GreaterThanIsOperator`, GCC's `greater_than_is_operator_p` — that turns the
operator meaning off in that context. We do exactly the same thing: a
`BacktickIsOperator` flag, false while parsing the slot, restored inside any
nested parentheses or brackets so that the parenthesized nesting of D3
works. Both implementations are modeled line-for-line on their compiler's
existing `>` machinery. This is the one genuinely novel parsing obligation
the operator carries, and it is a solved problem with fifteen years of
production precedent.

## Operator and escape never meet

C++ expression grammar strictly alternates between wanting an operand and
wanting an operator. The escape lives exclusively in operand positions; the
infix operator lives exclusively in the post-operand position. The positions
are mutually exclusive, so one lexical token serves both uses with no
lookahead and no ambiguity — the same strategy the language already uses to
give `*`, `&`, and `<` their multiple readings.

```cpp
void `new`();        // declarator-id  -> escaped identifier "new"
`new`(a, b);         // primary        -> call to the function named "new"
obj.`delete`();      // after '.'      -> member named "delete"
x `f` y;             // post-operand   -> infix: f(x, y)
x `(`new`)` y;       // escaped callee -> new(x, y), via D3's parentheses
```

The inner content reinforces the split — an escape wraps a single keyword,
which is never a valid callee expression; a slot wraps an expression, which
is never a bare keyword — but the design does not depend on the
reinforcement. Position alone suffices.

Because the escape yields an ordinary identifier, nothing downstream of the
parser changes: no new lookup rules, no mangling scheme, no ABI surface.
`` void `new`(); `` links as a function named `new`.
