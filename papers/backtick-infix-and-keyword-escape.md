---
title: "An Infix Operator and a Keyword Escape for C++"
subtitle: "Two jobs for the backtick, the last free token"
document: D4307R0
date: today
audience: EWG
author:
  - name: Steve Downey
    email: <sdowney@gmail.com>
toc: true
toc-depth: 2
# Latin Modern Mono carries none of the mathematical operators, and a
# missing glyph is only a warning: the PDF builds and silently drops it.
# This is a pandoc variable, so it reaches the LaTeX preamble without
# replacing it the way a header-includes key would.
monofont: "DejaVu Sans Mono"
---

```{=html}
<style>
/* The highlighter has no token for backtick and marks it as an error (red,
   bold); in this paper it is the subject matter.  This lives in the body and
   not in a header-includes: a header-includes key in the front matter
   replaces the wg21 LaTeX preamble, which is where \pnum is defined, and the
   PDF build then fails. */
code span.er { color: inherit; font-weight: inherit; }
</style>
```

# Abstract

We propose two uses for one character: the backtick, the last printable
ASCII character the language can still claim. One makes any callable a
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
`approx_equal` is the order the reader thinks in, and the order the chain
reads in; the call spelling is inside-out. None
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
expression parsed as an *assignment-expression*, or a type-name, which
constructs. The value, type, and semantics are exactly those of the
corresponding call. The operator is
left-associative and binds tighter than any other binary operator, looser
than the unary and postfix operators.

**The keyword escape.** In any position where the grammar expects a name — a
*declarator-id*, a class, enumeration or namespace name, a template
parameter's name, a label, an operand, after `.`, `->`, or `::` — a backtick
pair wrapping a keyword denotes an ordinary identifier whose spelling is that
keyword. It is purely a source-level construct; the resulting identifier
participates in lookup, mangling, and linkage exactly as if the word had
never been a keyword.

Both are gated during the proposal period behind a compiler flag; a
standardized form drops the gate. Flag off, every existing valid program is
untouched — backtick remains, as today, a character with no meaning outside
literals.

# Motivation, beyond readability

The Before/After tables carry the shallow case: binary operations read
better infix, and named operations stop being visually second-class to the
dozen built-in symbols. The deeper case rests on two properties the tables
barely use — the operator slot is an *arbitrary callable expression*, and
the operator chains left-associatively. Those two facts reach further than
they first appear. Everything in this section is the operator plus a few
lines of ordinary user code; none of it is proposed for the standard
library (the paper is language-only), and all of it was compiled and run
under the built Clang.

## Short-circuiting returns to user code

C++ reserves non-strict evaluation to a fixed set of built-ins — `&&`,
`||`, `?:`, `,`. Overloading does not get it back: an overloaded
`operator&&` evaluates both operands, which is the trap everyone has been
bitten by, and the reason the standing advice is: don't. This is a capability
boundary, not a style preference, and it has been closed since C++98.

A backtick helper whose right operand is a *callable* reopens it, because
the helper decides whether — and when — that operand runs:

```cpp
// short-circuiting logical implication:  p => q  ≡  !p || q
inline constexpr auto implies =
    [](bool p, auto&& q) -> bool { return !p || q(); };

p `implies` [&]{ return expensive(); }   // runs only when p holds
```

The same shape gives lazy defaults (``opt `or_else` [&]{ return costly(); }``),
guarded effects, and bespoke control operators — any binary operation that
must not evaluate its right side unconditionally. Chaining fallible steps
is the zero-ceremony special case: the stages are already functions, so no
thunk is written and the short-circuit falls out:

```cpp
inline constexpr auto mbind =
    [](auto&& m, auto&& f)
    { return std::forward<decltype(m)>(m)
                 .and_then(std::forward<decltype(f)>(f)); };

parse(s) `mbind` validate `mbind` store;   // stops at the first error
```

The concession, stated plainly: a bare-*expression* right operand still
evaluates eagerly, because backtick desugars to a call and calls evaluate
their arguments. The thunk is the price of generality. A dedicated
implication operator — Walter Brown has proposed `operator=>`, with
short-circuit evaluation like `&&` and `||` [@P2971R3] — pays that price
differently, by building the laziness into the operator; what it buys over
the backtick spelling is the ergonomics of omitting the thunk in the common
boolean case, not a capability user code otherwise lacks.

## One helper makes it a pipeline — and the ranges closures already fit

A two-line helper turns the operator into left-to-right value threading:

```cpp
inline constexpr auto pipe =
    [](auto&& x, auto&& f) -> decltype(auto)
    { return std::invoke(std::forward<decltype(f)>(f),
                         std::forward<decltype(x)>(x)); };

x `pipe` f `pipe` g `pipe` h        // h(g(f(x))) — data-flow order
```

The decisive case is that this drives the *existing* range adaptor closures
unchanged. `views::filter(pred)` and `views::transform(fn)` are already
unary callables — `c | a` is *defined* as `a(c)` — so `pipe` feeds them
directly:

```cpp
r `pipe` views::filter(pred) `pipe` views::transform(fn)
// identical result and laziness to:
r |  views::filter(pred) |  views::transform(fn)
```

Same closure objects, same lazy views, verified identical output on the
built compiler. The per-library `operator|` overloads exist only to choose
the `|` *syntax*; the closures themselves need nothing, so they work under
backtick for free.

## Stages with extra arguments — the honest gap

A free function that takes the threaded value first plus extra arguments
needs its trailing arguments fixed, with `std::bind_back` (C++23) or a
lambda, before it is a unary stage:

```cpp
r `pipe` std::bind_back(filter, pred) `pipe` std::bind_back(transform, fn)
// == transform(filter(r, pred), fn)
```

This is the case P2011's `|>` writes more directly, with the arguments
inline. Same outcome, more ceremony, and it is why backtick does
not make `|>` redundant. The boundary is drawn exactly in the next section.

## Reusable, point-free composition

Compose stages into a named pipeline once, apply it many times:

```cpp
inline constexpr auto then =
    [](auto f, auto g)
    { return [=](auto&&... a) -> decltype(auto)
        { return g(f(std::forward<decltype(a)>(a)...)); }; };

auto clean = trim `then` lower `then` dedup;   // a reusable callable
clean(s);
```

Left association gives left-to-right composition, mirroring a reusable
adaptor chain.

## Motivation, not a library proposal

None of `pipe`, `then`, `mbind`, or `implies` is proposed. Each is a few
lines of user code the operator makes worth writing; standardizing them
would add an LEWG track to an EWG/CWG paper and double the committee cost
for no enabling gain. Land the language feature, let usage show which
helpers deserve a place, and bring those in a companion library paper with
field experience behind them rather than ahead. The patterns are here so
the room can see the operator's reach before approving any of it.
Direction without commitment.

# Neither replaces the other: P2011's `|>`

The obvious neighbor is the pipeline-rewrite operator, `|>`
[@P2011R1]. Both constructs bottom out in a call expression, and their
two-argument cases coincide — `` a `plus` b ``, `a |> plus(b)`, and
`plus(a, b)` are the same call — so the relationship has to be stated
explicitly: they are orthogonal, complementary, and neither subsumes the
other.

What each one is:

- **Backtick** — `` x `f` y `` desugars to `f(x, y)`: symmetric binary
  infix application of a callable. The callee sits between two operands,
  and the result is an ordinary overload-resolved call.
- **`|>`** — `x |> f(a, b)` is *rewritten* to `f(x, a, b)`: a syntactic
  rewrite that prepends the left operand to the call written on its right.
  There is no `operator|>`; it is not overloadable, by design, and the
  right-hand call has any arity.

+-----------------+-----------------------------+-----------------------------------+
|                 | backtick `` x `f` y ``      | pipeline `x |> f(...)`            |
+=================+=============================+===================================+
| Shape           | symmetric binary infix      | directional prepend-the-argument  |
+-----------------+-----------------------------+-----------------------------------+
| Right-hand side | a single operand            | a call with its own arguments     |
+-----------------+-----------------------------+-----------------------------------+
| Resulting arity | exactly 2                   | any N                             |
+-----------------+-----------------------------+-----------------------------------+
| Mechanism       | desugar to a normal call    | pure syntactic rewrite            |
+-----------------+-----------------------------+-----------------------------------+
| Overloadable    | yes — it *is* a call        | no, by design                     |
+-----------------+-----------------------------+-----------------------------------+
| Precedence      | highest binary              | low                               |
+-----------------+-----------------------------+-----------------------------------+
| Native use      | operations: `` a `min` b `` | chains: `r |> filter(p) |> sum()` |
+-----------------+-----------------------------+-----------------------------------+

The overlap stops at two arguments. Beyond that, each can do what the other
cannot:

- Backtick cannot thread. `x |> f(a, b, c)` prepends `x` to an
  arbitrary-arity call; backtick's right-hand side is a single operand, not
  an argument list, so there is no backtick spelling of `f(x, a, b, c)`.
  Beyond two operands, only `|>` threads.
- `|>` cannot write an operation *between* its operands. `` a `min` b ``
  becomes `a |> min(b)`, which reads as a pipeline stage, not an operation.
  For `x op y` notation — predicates, arithmetic, metrics — backtick is the
  spelling.

And they compose: backtick supplies infix detail inside a stage, `|>`
threads the value between stages:

```cpp
r |> filter([](auto e){ return e `mod` 2 `eq` 0; }) |> sum()
//                             \____ eq(mod(e, 2), 0) ____/
```

This proposal deliberately declines the `|>` spelling for itself (see the
appendix) so that both can coexist in one program. Backtick says "this is a
binary operation"; `|>` says "thread this value through these stages."
Different sentences.

# Prior art

Both uses have shipped elsewhere, repeatedly. Neither is invented here; the
design work in this paper is fitting them into C++'s grammar, not
discovering them.

## Infix application of named callables

Haskell has spelled it this way since the first Haskell Report (1990): an
ordinary identifier enclosed in grave accents is an infix operator, and
`` x `div` y ``, `` x `mod` y ``, `` xs `elem` ys `` are everyday Haskell.
The descendants kept it —
[PureScript](https://book.purescript.org/chapter3.html) and
[Idris](https://docs.idris-lang.org/en/latest/tutorial/typesfuns.html) both
apply any function infix with backticks, as do the Haskell-family dialects.
PureScript is worth a sentence more: asked where backtick operators should
sit, it settled on *left-associative, highest precedence* — independently,
the same answer this paper reaches. Two language communities
starting from the same construct arrived at the same fixity.

Two languages adopted the construct and then removed it. That is part of
the record too.
[Elm dropped backticks in 0.18](https://github.com/elm-lang/elm-platform/blob/master/upgrade-docs/0.18.md),
citing that in practice a single function (`andThen`) accounted for the
use, that the form was redundant with Elm's `|>` pipeline, and that the
glyph is confusable with a quote in some fonts.
[Unison likewise removed it](https://github.com/unisonweb/unison/pull/2570).
But both are pipeline-first functional languages, where the dominant
backtick use was monadic chaining — exactly the use `|>` covers directly,
so the feature was carrying one use that already had a spelling. The
motivating set here — `gcd`, `dot`, `mul_sat`, `approx_equal` — is binary
operations, not chains, and the P2011 section of this paper keeps the
pipeline and the infix operator as different constructs so that
neither has to absorb the other's uses. Elm folding backtick *into* its
pipe is evidence for that separation, not against infix. The
font-confusability complaint is real, small, and filed where it belongs, in
Appendix A.1.

The demand for named infix also keeps surfacing under other spellings:
Kotlin's [`infix fun`](https://kotlinlang.org/docs/functions.html#infix-notation),
Scala's bare method infix, R's `%op%` operators, Miranda's `$fn` — the
direct ancestor of the Haskell backtick — and Fortress's named operators.
Languages keep reinventing the feature and disagree only on its spelling.
Backtick is the spelling with the deepest working precedent.

## Escaping keywords as identifiers

Every language that kept evolving past 1.0 installed an escape hatch:
Swift's `` `class` ``, Kotlin's backtick identifiers, F#'s double-backtick
names, C#'s `@`-verbatim identifiers, Nim's backtick stropping, and Rust's
[`r#` raw identifiers](https://doc.rust-lang.org/edition-guide/rust-2018/module-system/raw-identifiers.html)
— the last introduced specifically so the 2018 edition could take `try`,
`async`, and `await` as keywords while 2015-edition code kept compiling and
kept calling functions with those names. Editions plus raw identifiers are
how Rust made keyword adoption routine rather than traumatic. C++ is the
outlier: no escape, so every new keyword breaks real code, and the
committee's coping strategies are `co_`-circumlocution and
context-sensitive grammar. The hatch is standard equipment. C++ never
installed it.

# Design choices and decisions

The implementation work was run against a decisions log. The decisions that
shape the design are argued here, one to a section, so that EWG can poll any
one of them on its own.

## It desugars to the call, and that is the whole design

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

## Precedence: the highest binary operator, and why not higher

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
PureScript, which took the same construct from Haskell, independently
settled on the same fixity: backtick operators are left-associative, at
the highest precedence.

## Left-associative

```cpp
a `f` b `g` c           // g(f(a, b), c)
```

Chains group in reading order, like `-` and `/`. Nothing more to it.

## The operator slot is an assignment-expression

Anything you could write as the callee of a call is admitted — a qualified
name, a member access, a lambda — excluding only a top-level comma. The
operands, being cast-expressions, exclude braced-init-lists; `` x `f` {1,2} ``
is not admitted in this proposal. The brace form is meaningful as a call
argument, and could be revisited, but a leading-brace left operand collides
with block syntax, and the workaround is to write the call. We took the
restriction.

## Bare nesting is chaining; real nesting takes parentheses

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

## Evaluation order is the call's

`` x `f` y `` adds no evaluation-order rule. Operand order is unspecified, as
in [expr.call]; since C++17 the callee — the slot, though written between its
operands — is sequenced before both of them. Source order is not evaluation
order for any other call in the language, and this is a call.

## A type name in the slot constructs

A *type-name* is call-eligible, so `` x `T` y `` is `T(x, y)` —
functional-style construction, CTAD applies:

```cpp
a `std::pair` b         // std::pair(a, b)
```

The grammar says so explicitly: the *backtick-operator* production accepts
a *simple-type-specifier* or *typename-specifier* alongside
*assignment-expression*, and a slot that names a type takes the type
interpretation. (A bare type-name is not an *assignment-expression*, so
without those productions `` a `std::pair` b `` would be a grammar
contradiction, not a blessed consequence.) The result is always an
expression — whichever production the slot takes, the whole form is an
expression by construction — so no most-vexing-parse declaration reading
can arise.

## The escape yields an ordinary identifier

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

One consequence is user-visible and is therefore worth settling here. The
escape is part of the name's *spelling* and not of its identity, so a printer
holding the compilation's language options puts the backticks back: a
pretty-printed declaration comes out as `` void `new`(); ``, since `void
new();` is not a program and a printer that emitted it would have lost the
source, and a diagnostic names the entity `` `new` `` for the same reason —
text copied out of a diagnostic should be text the reader can paste back. The
AST dump is the one view that keeps the bare word, which is the evidence for
the paragraph above: the name really is an ordinary identifier, and the
backticks are how it is written. Both implementations do this, and what it
cost them is the part worth reporting, because it is the same in both. The
escape yields the ordinary interned identifier and keeps no record of how it
was written, so neither compiler can ask a name whether it was escaped; each
has to decide instead *which printing surfaces name an entity*, and put the
backticks back only there. Clang draws that line by the kind of argument a
diagnostic was given, across six sites. GCC draws it in the one routine that
prints the name of a declaration, plus a guard on the parser's own error
printer, which hands a raw keyword token to that routine as though it were a
name. Both got the line wrong once before getting it right, and the symptom
was the same both times: a program containing no backtick at all had its
diagnostics change under the flag.

One half of that is still wrong in GCC, and it is reported here rather than
smoothed over, because it is the clearest evidence for what the paragraph
above claims the cost is. GCC's routine is *the name of a declaration*. A
class or enum **type** is printed somewhere else, so a program that declares
`` struct `union` { }; `` and then misuses it is told that *'struct union' has
no member named '`new`'* — one sentence, two names, one of them escaped and
the other not, because the two halves arrive from two printers. Clang escapes
both. No program is accepted or rejected differently; what fails is the thing
the decision exists to deliver, which is that text copied out of a diagnostic
can be pasted back. Deciding which surfaces name an entity is the whole cost
of the feature's printing, and a compiler can pay it in one place and not
another without anything failing.

The cost is bounded added context-sensitivity: tentative
declaration-versus-expression parsing must recognize escapes, and tooling
must distinguish the two uses. Both implementations do.

## One spelling

Backtick is the sole proposed spelling; there is no digraph and no
alternative token. The objections to backtick — it is Markdown's inline-code
delimiter, and a dead key on some keyboard layouts — are real and minor, and
neither is a capability gap: CommonMark's multi-backtick spans already
express `` x `f` y `` in running prose, and fenced blocks (the dominant case)
are unaffected. That workaround renders correctly today on GitHub, on the
committee's own Mattermost server, and throughout the source of this very
paper — which is written in Markdown, and is by now littered with inline
renderings of the single-backtick form. Against that, a second spelling doubles
the teaching, formatting, pretty-printing, and tooling surface permanently,
and fragments the one-recognizable-form spelling the readability argument rests
on. Trigraphs were removed in C++17; digraphs are vestigial. We decline to
mint a new one.

The analysis of candidate alternative spellings — including the one pair,
`\< … \>`, that would actually be better-engineered, and why adopting it
would be choosing a different operator rather than aliasing this one — is
carried in an appendix, with the rebuttals stated, so the question can be
settled against the record in this paper rather than reopened in a future
one.

## Two uses, one paper; no library

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
deserve it.

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
And the committee has already decided this exact example, in the library:
C++26's saturation arithmetic ([@P0543R3]) is `std::add_sat`,
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
compiler (`` stray '`' in program ``, in GCC's words). Only three printable ASCII
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
    simple-type-specifier
    typename-specifier
```

The second and third alternatives are the type slot, and the type reading
wins exactly when lookup finds a type or a class template. That is a rule
and not a consequence: a bare type-name is not an *assignment-expression*,
so a grammar with only the first alternative would contradict the section
above rather than imply it.

*backtick-expression* slots between *cast-expression* and *pm-expression*:
the pointer-to-member productions consume a *backtick-expression* where they
consumed a *cast-expression*, and everything above them is unchanged. In
implementation terms this is one new top level in each compiler's binary
operator precedence table. The left recursion gives left associativity; the
*cast-expression* operands give the symmetric prefix binding argued for above.

The new level is deliberately **not** a *fold-operator*: `` (... `f` N) `` is
ill-formed. Both implementations reject it, each with an ordinary parse error
that says nothing about why, which is the reason for stating the exclusion
here: nothing else would say it was chosen.
Excluding costs one clause in the predicate that already decides which
operators may be folded over; admitting would require a fold-expression node
that can hold an arbitrary slot expression, which today's cannot. Nothing is
foreclosed — every program a later revision would newly accept is one this
proposal rejects.

The keyword escape is a new *identifier* alternative in name positions:

```bnf
escaped-identifier:
    ` keyword `
```

yielding an identifier token whose spelling is the keyword. It may appear
wherever the grammar uses *identifier* as a terminal, and nowhere else: a
*declarator-id*, a *class-head-name*, an *enum-name*, an enumerator, a
*namespace-name*, a template parameter's name, a *mem-initializer*, a label,
a *primary-expression*, an *id-expression* after `.`, `->` or `::`.

## The same-delimiter problem

The open and close delimiter are the same token, so while parsing the
operator slot, a naive expression parser would take the closing backtick as
the start of a second, nested backtick operator. C++ has been here before:
`>` inside a template-argument list is a closer, not an operator, and
`vector<vector<int>>` is handled by a parser flag — Clang's
`GreaterThanIsOperator`, GCC's `greater_than_is_operator_p` — that turns the
operator meaning off in that context. We do exactly the same thing: a
`BacktickIsOperator` flag, false while parsing the slot, restored inside any
nested parentheses or brackets so that parenthesized nesting
works. Both implementations are modeled line-for-line on their compiler's
existing `>` handling. This is the one genuinely novel parsing obligation
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
x `(`new`)` y;       // escaped callee -> new(x, y), parenthesized slot
```

The inner content reinforces the split — an escape wraps a single keyword,
which is never a valid callee expression; a slot wraps an expression, which
is never a bare keyword — but the design does not depend on the
reinforcement. Position alone suffices.

Because the escape yields an ordinary identifier, nothing downstream of the
parser changes: no new lookup rules, no mangling scheme, no ABI surface.
`` void `new`(); `` links as a function named `new`.

# Implementation experience

This is not a paper design with a hand-wave at implementability. The infix
operator and the keyword escape are both implemented, gated behind an opt-in
`-fbacktick` flag, in two independent compilers. Both forks are public:

- **Clang** — two branches carrying the same feature diff, one on the LLVM 23
  release branch
  ([steve-downey/llvm-project @ backtick-23](https://github.com/steve-downey/llvm-project/tree/backtick-23))
  and one on trunk
  ([@ backtick-trunk](https://github.com/steve-downey/llvm-project/tree/backtick-trunk)):
  lexer token, the new binary precedence level, a parser branch modeled on
  the ternary operator (the closest existing delimited-middle operator), Sema
  desugaring to a `CallExpr`, the driver flag, a transparent AST wrapper so
  `-ast-print` round-trips the surface syntax, and clang-format support for
  both uses (canonical spacing, and a break policy that hard-forbids a break
  next to either backtick). A bare unqualified name in the slot reaches the
  call builder unresolved, as an `UnresolvedLookupExpr`, so ADL is the
  call's. Tests live under `clang/test/` — the `backtick-*` files in
  `Parser/`, `Lexer/`, `SemaCXX/`, `AST/`, `Analysis/` and `CIR/CodeGen/`,
  plus `Driver/` and the Format unit tests — and the full `check-clang`
  regression gate stays green with the flag off and on.
- **GCC** ([steve-downey/gcc @ backtick](https://github.com/steve-downey/gcc/tree/backtick))
  — `libcpp` token (replacing today's `` stray '`' in program `` diagnostic),
  parser precedence level and slot handling, desugaring via
  `finish_call_expr`, the same flag, and ADL on the slot for both unqualified
  forms, a plain name and a template-id. Tests live under
  `gcc/testsuite/g++.dg/backtick/`, with a module pair under
  `g++.dg/modules/` checking that an escaped name streams through a compiled
  module interface and mangles as the ordinary module-attached name it is.

The GCC branch was later rebased over three months of upstream trunk — 2158
commits, 177 of them in the C++ front end and the preprocessor — and every
line the feature adds or removes came across unchanged, with no conflict.
Nothing the feature touches had moved under it. For a design whose whole
claim is *desugar and inherit*, that is the maintenance number worth
reporting: a diff of this shape has very little to catch on.

## What is implemented, and what is not

The escape works in both compilers in every name position the wording admits:
declarator-ids (variables, functions, class members, `typedef` names,
parameters, a `friend` declaration's name, the qualified name in an
out-of-class member definition), a *class-head-name*, an *enum-name* scoped or
unscoped, an enumerator, a *namespace-name*, a type, non-type or template
template parameter's name, an *alias-declaration*'s name, an alias template's,
a concept's, a *mem-initializer*, a label, and expression positions including
after `.`. Declaring a name is only half of a hatch, so the positions that
*use* one are prototyped too: a type-specifier, a base-specifier, a
nested-name-specifier, a *template-name* being specialized, a using-directive,
a type-constraint, and a constructor's name. And a qualified name may be
escaped at either end or at both — `` N::`union` g; ``,
`` using X = N::`union`; ``, `` sizeof(N::`union`) ``,
`` typename T::`union` ``, `` `module`::inner::f() ``.

That coverage is recent, and how it was arrived at is a fair warning about
what "implemented" means for a grammar extension. Both prototypes were
finished, and both were then found to take the escape in whichever positions
their parser happened to route through the routine the escape had been written
into, and to refuse it wherever a bare identifier token was read somewhere
else. That is why a concept's name worked and `` struct `union` { }; `` — the
example in the wording below — did not, in either compiler. Nobody had drawn
the boundary; it fell out of two independent parsers, differently in each.
Neither test suite contained a negative test for any of it, so nothing was
failing and nothing would have failed.

It was found by writing one program per position and compiling them. That has
now been done four times, and it has found something on all four. The first
sweep covered the positions that *declare* a name; the second, written after
somebody noticed that a type nothing can name is not a hatch, covered the
positions that *use* one. The third covered qualified names, and found that
Clang read the final component of a qualified name as an unqualified-id only
when it named an object or a function, so `` N::`new` `` had worked from the
first day and `` N::`union` `` had never worked at all. The fourth changed the
keyword. Every program anyone had written used `new`, `class`, `union` or
`try`, which are pure keywords; `int` is not, and GCC rejected
`` int `int` = 0; `` in the first and best-tested position in the table, and
had done for two months. Seventy-nine programs now, in four groups, and the
whole sweep runs in about ten seconds. It is checked into the repository,
which it should have been three sweeps ago.

What it cost to fix is the useful number, and it is small but not the number
first estimated. The escape parse becomes a helper called from each name
position — twenty call sites in Clang, one arm plus its guards in GCC — and
then three things nobody had priced. A parser that decides what it is looking
at from the token *after* a name has to step over three tokens where it
stepped over one, so every such lookahead is a call site too; a label is told
from an expression statement only by the `:` that follows it. A new name
position is a new *printing* surface: enumeration names, namespace names,
template parameter names, labels and nested-name-specifiers all printed the
bare keyword, which is source that does not re-parse, until they were routed
through the one routine that puts the backticks back. And a parser that caches
tokens for backtracking has a third cost the other two do not imply. Clang
collapses a resolved qualified type name into a single annotation token and
matches that token against the cached stream by source location; a name
written as an escape occupies three tokens, so the annotation has to begin on
the opening backtick and end on the closing one. Get either end wrong and the
cache is left holding a stray `` ` `` in front of the annotation, which the
next backtracking parse resumes on. GCC pays none of that, because it does not
cache and re-annotate. More than half the work was in those three, and none of
them appears in the grammar.

That last change also shipped an infinite loop, which is worth reporting for
what caught it. Clang's recovery for a qualified name it cannot resolve is to
try implicit `int`; that does not apply to an escape and consumes nothing, so
`` namespace N { int x; } N::`union` g; `` re-entered the same case with the
same tokens indefinitely. The code it replaced had been avoiding that by
accident, by giving up as soon as it saw a backtick. Neither test suite
covered a malformed or unresolvable escape in a qualified position — neither
covered a qualified escape at all — and a diagnostic-matching test would not
have caught it in any case, since a test that never terminates does not fail.
What caught it was running the error cases under a timeout, which is a
different question from the one a coverage sweep asks and needs its own
harness.

The type-name slot has single-compiler evidence, said here so a reviewer does
not have to discover it. Clang implements it: a bare name looked up
as a type with a deduction placeholder, a qualified one through a tentative
parse, a builtin through the functional-cast path, all three routed to the
`T(x, y)` build, which is where CTAD and temporaries come back for free. GCC
parses its slot as an expression, so `` 1 `Pt` 2 `` is rejected there.

That slot is now the whole list of programs the two compilers treat
differently under the flag. Nothing the keyword escape does is on it.

Three entries have come off that list, and every one of them left the same
way: it turned out to be a gap rather than a disagreement, with a single cause
behind however many programs it showed up in. The last two are worth reporting
because they ran in opposite directions. GCC rejected an escape whose keyword
is a *type* keyword, because `int` and `char` and their siblings are bound at
global scope to the builtin type in GCC's name table, so the name the escape
yields was
already taken. That looks like a representation the design would have to pick
a side on. However, in C++ a declaration can be named by a keyword only if it
was escaped, since `int` is a keyword token everywhere else and the declarator
check rejects a bare reserved word; a collision with that binding is therefore
never a redeclaration, and the fix is to say so, at the three places GCC
consults it. `` int `int` = 0; `` compiles, `int` still names the builtin in
the same translation unit, and `` g(int, `int`) `` mangles as `_Z1gi3int` in
both compilers. Which is the ABI claim above, demonstrated on the hardest name
the feature has.

And once, briefly, GCC was the wider implementation: it took `` N::`union` ``
where Clang did not. One arm in the routine that reads an identifier reaches
every name position GCC has, a qualified type among them. Clang reads a
qualified type name somewhere else entirely, and in three somewhere-elses: the
declaration-specifier path, the *typename-specifier* path, and the tentative
parse that decides whether a statement is a declaration at all. Twelve
programs, four arms, and then a fifth to put back a constructor definition the
first four had broken — `` `union`::`union`() { } `` had been working by
accident, on the strength of the old code giving up early. No design question
anywhere in it.

`-ast-print` round-trips the operator, with one exception a reviewer will
find: a slot naming a builtin whose call the semantic layer rewrites into a
node that is no longer a call — `` a `__builtin_shufflevector` b `` — prints
as the rewrite, which is not expressible in the syntax at all.

There was a second exception until this paper's claims were re-derived against
the compilers rather than read off the implementation, and how it was missed
is the general point. The printer and the source range both recover the
operands from whatever the semantic layer built, so each initialization form
it can produce for `T(x, y)` needs its own arm. A type slot naming an
aggregate does not construct through a constructor; it initializes through
parenthesized aggregate initialization and comes back as a different node.
That arm was missing, and a missing arm is silent — it prints the desugaring,
which is well-formed and plausible. In the deduced case it was not even
that: it printed a cast applied to a comma expression, a different program
altogether. The arm is written now. **A round-trip claim is a claim about
every node the semantic layer can build, not about the nodes the printer was
written against**, and it is worth testing that way, because nothing else will
report it.

## Argument-dependent lookup, which both implementations got wrong

ADL fidelity is normative in this design: `` x `f` y `` must not have quietly
weaker lookup than `f(x, y)`. Both compilers now deliver it and agree.
Neither did on its first attempt, and the two failures were the same failure
— the name in the slot was resolved before the call builder ever saw it.

GCC took two goes. Its first cut resolved a bare-name slot at parse time, so
a call depending on pure ADL — the callee visible in no enclosing scope, only
in an argument's namespace — failed there and compiled elsewhere. The fix
routed the slot through the same Koenig lookup a plain call performs, but
recognized only a bare name, so a slot carrying template arguments kept the
old behavior silently for another round.

Clang started further back: its slot was parsed with the ordinary expression
parser, which resolves the name before the call builder is reached, so the
slot had no ADL at all. A hidden friend in the slot was *use of undeclared
identifier*. And in the shape that matters, nothing was said at all: with an
ordinary-lookup candidate visible and viable, and a better candidate
reachable by ADL, `` u `pick` u `` bound the visible one while `pick(u, u)`
bound the ADL one, no diagnostic anywhere. The operator called a different
function from the call it is defined to be.

The sharpest evidence for the desugaring thesis fell out of that defect, and
it is inside one compiler rather than between two. The Clang build carrying
the backtick operator also carried a second infix experiment — user-defined
operators spelled with Unicode symbols, a companion design not proposed here
— whose slot never becomes an expression: Sema performs its own operator
lookup and hands an unresolved set to candidate assembly. One build, one
machine, one author, one difference. The feature that reached the call
builder unresolved inherited ADL from its first commit, without anyone
deciding to inherit it; the feature that resolved its slot first had to be
repaired. That is the whole thesis, with the compiler and the author held
constant.

The near-miss is worth as much to a reviewer as the fix. The defect survived
the entire implementation because the one test that announced itself as the
ADL case used a *qualified* name in the slot, which correctly gets no ADL
either way — so it passed whatever the slot did, and its heading was enough
to stop anyone writing the test that would have failed. The shape that
catches this is not "does it compile" but *augmentation*: an ordinary-lookup
candidate that is visible and viable, a better ADL candidate, and the choice
made observable in the result type. That is the only shape in which weaker
lookup on the slot produces no diagnostic at all, and it is the test to ask an
implementation for.

## What the AST node costs, and which compiler pays it

Clang builds a source-fidelity node, a transparent wrapper around the
desugared call, and that node is what makes `-ast-print` reproduce the
written syntax. GCC desugars in the parser and hands its semantic layer an
ordinary call. The two accept the same programs and generate the same code,
so this is a difference in kind and not in behavior. However, it has a price,
and a reviewer should attribute the price correctly.

The price is not the node. It is the transparency. A wrapper the rest of the
compiler is meant not to notice is a wrapper nothing will remind you to teach
anything about, and the sites that need teaching are quiet when they are
wrong: six in the static analyzer's modelling layers, a seventh in the bug
reporter created by meeting the other six, four arms in the code generator,
the exhaustive statement-class switches, the libclang cursor map, the AST
matchers. Exactly one of the analyzer's seven announces itself, and only as a
warning in a build log.

The seventh is the instructive one. Teaching the control-flow graph to look
through the wrapper leaves the wrapper with no program point of its own, so
the bug reporter's tracking chain is abandoned before a single handler runs
— and with it the suppression, on by default, that keeps `core.NullDereference`
quiet about a null returned from an inlined callee. `` p `identity` 0 ``
reported a false positive that the identically-desugaring `identity(p, 0)`
was spared, and the report it did emit carried two path notes where the
call's carried eight. The operator form was noisier than the call it is sugar
for, and explained less. One arm in the reporter's peeling routine fixes both
symptoms at once, because peeled early the two forms are one expression
for everything downstream; the two reports now agree note for note.

None of that is the cost of infix application. It is the cost of source
fidelity, and round-tripping the written syntax is what it buys. A front end
that desugars in the parser pays none of it, and gets none of it.

## The gate is the part that fails quietly

A prototype behind a flag has one obligation ahead of the feature itself:
with the flag off, nothing changes. Both implementations broke it in the same
shape, and neither break showed up in a diagnostic.

Clang's `-fbacktick` reached the language options in a C compilation, where
the C++ grammar it enables has no business being, so `` int f(int a, int b){
return a `g` b; } `` compiled as C. Nothing lost a diagnostic; an invalid
program was accepted. GCC's two backtick cases in the parser were
fall-through targets for other tokens and tested only the flag, not
the token, so with the flag on, a program containing no backtick could take a
different path and be diagnosed differently.

Both were one line. Both were found by comparing flag-on output against
flag-off output, and that is the check to ask an implementation for: the two
compilations must produce byte-identical output on a program that never
mentions the feature. Whether the flag produces the right diagnostic is a
different question, and a weaker one.

## What the parsers confirmed

Both implementations, built separately from the same design, accept the bare
"nested" form as a left-associative chain, because the token stream for the
two readings is identical. What the design predicted on paper, two unrelated
parser architectures reproduced. Nesting-is-chaining is a consequence of the
grammar, not an implementation accident. Clang carried a diagnostic for the
bare form through most of the implementation and it never once fired; it was
deleted rather than made to fire, since making it fire needs the lookahead
that would have to reject legal chaining too. A diagnostic that cannot fire is a claim
the grammar has already withdrawn.

The motivation section is implementation experience as well, not assertion.
Every pattern in it — `pipe` threading, the range-adaptor closures, the
`bind_back` stages, `then` composition, the short-circuiting `implies` and
the `mbind` chain — was compiled and run against the built `-fbacktick`
Clang, C++23, `-Wall -Wextra` clean. The ranges comparison was verified to
produce identical results and identical laziness through `|` and through
`` `pipe` ``, on the same closure objects.


# Wording

Wording is relative to the current working draft. Drafting notes, for CWG,
on choices the wording takes:

- No change to [lex.charset]{.sref} is needed: `` ` `` (U+0060) is already
  a member of the basic character set ([@P2558R2], adopted for C++26).
  Today it appears in no preprocessing token outside literals; a program
  containing a stray backtick is conditionally-supported with
  implementation-defined semantics under [lex.pptoken]{.sref}. Adding it to
  *operator-or-punctuator* makes it a token; no currently well-formed
  program changes meaning.
- The rewrite is specified with "identical (by definition) to", the
  [expr.sub]{.sref} device, so [expr.call]{.sref} supplies overload
  resolution, argument-dependent lookup, sequencing, and value category
  with no restatement.
- The same-delimiter parsing rule is modeled on [temp.names]{.sref}'s
  "first non-nested `>`".
- *escaped-identifier* is presented in [lex.name]{.sref} and restricted to
  keywords, the proposed default; if EWG prefers the unrestricted form,
  replace *keyword* with "*identifier* or *keyword*" in the grammar and
  strike nothing else. Alternative representations ([lex.digraph]{.sref}:
  `and`, `or`, …) are deliberately not escapable; they are operator
  spellings, not names.
- The escape is a phase-7 grammar construct composed of three preprocessing
  tokens. The preprocessor is unaffected: macro names cannot be escaped,
  and an escaped-identifier never arises in phases 3 through 6.
- One feature-test macro is proposed for the paper's two features, because
  they are one design. If they are ever polled separately, it splits
  into `__cpp_backtick_operator` and `__cpp_escaped_identifiers`. The value
  shown is this paper's date; the adopting meeting sets the final value.

## [lex.operators]

Modify the *operator-or-punctuator* grammar in [lex.operators]{.sref}
paragraph 1 by adding `` ` `` :

::: add
> ```
> operator-or-punctuator: one of
>        ...
>        ?     ::    .     .*    ->    ->*   `
>        ...
> ```
:::

[The row shown is [lex.operators]'s third; only the trailing `` ` `` is
added.]{.note}

## [lex.name]

Add to [lex.name]{.sref}, after the paragraphs defining *identifier*:

::: add
> ```
> escaped-identifier:
>     ` keyword `
> ```
>
> [x]{.pnum} An *escaped-identifier* may appear wherever the grammar uses
> *identifier* as a terminal. It behaves in all respects as an *identifier*
> whose value is the spelling of its *keyword*; the `` ` `` tokens are not
> part of that value.
>
> [x+1]{.pnum} The identifier so denoted is not interpreted as a keyword,
> and [lex.key]{.sref} does not apply to it.
> [Note: Two entities named by an *escaped-identifier* and by a
> lexically identical *identifier* are the same entity. The construct is
> purely a source-level spelling; name lookup and linkage are unaffected.
> — end note]
>
> [x+2]{.pnum} [Example:
> ```cpp
> void `new`();          // declares a function named new
> `new`();               // and calls it
> struct `union` { };    // a class named union
> obj.`delete`();        // member access
> ```
> — end example]
:::

## [expr.mptr.oper]

Modify the grammar of [expr.mptr.oper]{.sref} paragraph 1:

> ```
> pm-expression:
>     @[cast-expression]{.rm} [backtick-expression]{.add}@
>     pm-expression .* @[cast-expression]{.rm} [backtick-expression]{.add}@
>     pm-expression ->* @[cast-expression]{.rm} [backtick-expression]{.add}@
> ```

## [expr.backtick] (new subclause)

Insert a new subclause between [expr.cast]{.sref} and
[expr.mptr.oper]{.sref}:

::: add
> **Backtick operator   [expr.backtick]**
>
> ```
> backtick-expression:
>     cast-expression
>     backtick-expression ` backtick-operator ` cast-expression
>
> backtick-operator:
>     assignment-expression
>     simple-type-specifier
>     typename-specifier
> ```
>
> [1]{.pnum} The backtick operator applies a callable expression, the
> *backtick-operator*, to two operands. An expression of the form
> `` E1 `O` E2 `` is identical (by definition) to `O(E1, E2)`
> ([expr.call]{.sref}).
> [Note: Overload resolution, argument-dependent lookup, implicit
> conversions, value category, and sequencing are those of the function
> call. In particular, `O` is sequenced before `E1` and `E2`, and the
> evaluations of `E1` and `E2` are unsequenced with respect to each other.
> — end note]
> [Note: The backtick operator is not an overloadable operator
> ([over.oper]{.sref}). — end note]
>
> [2]{.pnum} If the *backtick-operator* is a *simple-type-specifier* or
> *typename-specifier* denoting a type `T` or a placeholder for a deduced
> class type, an expression of the form `` E1 `T` E2 `` is identical (by
> definition) to `T(E1, E2)` ([expr.type.conv]{.sref}). A
> *backtick-operator* whose tokens can be interpreted both as an
> *assignment-expression* and as a *simple-type-specifier* or
> *typename-specifier* is interpreted as a *simple-type-specifier* or
> *typename-specifier*.
> [Note: The interpretations coincide only when name lookup determines
> that the name denotes a type or a class template; a name that denotes a
> function, variable, or overload set is not a *simple-type-specifier*.
> Class template argument deduction applies exactly as it would for the
> equivalent explicit type conversion ([dcl.type.class.deduct]{.sref}).
> — end note]
>
> [3]{.pnum} When parsing a *backtick-operator*, the first non-nested
> `` ` ``^[A `` ` `` that appears within a matching pair of parentheses,
> brackets, or braces is nested.] is taken as the ending delimiter, rather
> than as the first delimiter of a nested *backtick-expression*.
>
> [4]{.pnum} [Example:
> ```cpp
> int  min(int, int);
> auto r1 = a `min` b;             // min(a, b)
> auto r2 = -a `min` -b;           // min(-a, -b): operands are cast-expressions
> auto r3 = a * b `min` c;         // a * min(b, c): binds tighter than *
> auto r4 = a `f` b `g` c;         // g(f(a, b), c): left-associative
> auto r5 = x `f `g` h` y;         // a chain: h(f(x, g), y)
> auto r6 = x `(f `g` h)` y;       // nested: (g(f, h))(x, y)
> auto r7 = a `std::pair` b;       // std::pair(a, b): CTAD applies
> ```
> — end example]
:::

## [cpp.predefined]

Add a row to [tab:cpp.predefined.ft] in [cpp.predefined]{.sref}:

::: add
> | Macro name | Value |
> |---|---|
> | `__cpp_backtick` | `202607L` |
:::

Annex A ([gram]{.sref}) is updated mechanically to match.

# Appendix A: alternative spellings, and the lexical inventory

Backtick is the sole proposed spelling. This appendix carries the
analysis behind that decision: why alternatives get raised, the lexical
filter any candidate must pass, the candidates themselves, and the wider
inventory of what ASCII actually remains — so that if the spelling question
is raised, it can be settled against this record in this paper, not
reopened in a future one.

## A.1 Why alternatives get raised

Two reasons, both real, both minor. A single backtick is Markdown's
inline-code delimiter, so `` x `f` y `` in running prose fights the markup.
And backtick is a dead key or awkward on some non-US keyboard layouts — it
was one of the ISO-646-variant characters, alongside `# [ ] { } | ~ ^ \`.

Neither is a capability gap. CommonMark's multi-backtick spans already
delimit code containing backticks — writing ``` `` x `f` y `` ``` renders
as `` x `f` y `` — and fenced blocks, the dominant case for code, are
unaffected entirely. The span form renders correctly on GitHub and on
Mattermost, the committee's own chat server (author-verified). In the very
forum where the operator would most often be typed in running text, the
friction is a solved problem. What an alternative spelling buys is
ergonomics for the minority case, inline prose. Nothing more.

There is also a self-test on the record: the source of this paper is pandoc
Markdown, and every `` x `f` y `` in its running prose is a multi-backtick
span in the source. The friction is real; each inline
example costs the doubled delimiters and a padding space. It is also,
demonstrably, survivable: a Markdown paper *about* the backtick operator is
the worst case the objection can construct, and the one you are reading
renders.

## A.2 The filter a candidate must pass

An alternative spelling is an additional token lexed by maximal munch, like
the existing digraphs. To be viable, the sequence must never appear
adjacent in a valid current program. Three traps, each of which has bitten
a real token before:

1. **Maximal-munch theft.** After a binary operator or `<`, a
   unary-capable character is already valid: `a < -b`, `a * *p`, `!!x`.
   Minting the two-character form silently changes meaning.
2. **The `::` neighborhood.** `a<:b` needed the `<::` carve-out in
   [lex.pptoken] because `vector<::std::string>` broke. Any new
   `<`-prefixed token lives next to that scar.
3. **Universal-character-name munch.** `\uXXXX` can begin an identifier,
   so a candidate whose second character is `\` can split a UCN — a
   non-obvious break.

## A.3 The candidates

| Spelling | Lexically clean? | Verdict |
|---|---|---|
| `\< … \>` | yes — `\` is no token today, and `\<` cannot start a UCN | front-runner, if ever forced (A.4) |
| `<\| … \|>` | yes | blocked socially: `\|>` is P2011's operator, and it reads as "pipe" |
| `<\ … \>` | no — UCN munch (trap 3) | inferior twin of `\< … \>`; reject |
| `(\| … \|)` | yes | heavy; Haskell "banana bracket" connotation; reads worse than backtick |
| `x \op\ y` | yes | visually too light; symmetric, so it keeps the same-delimiter rule |
| `$ … $`{.raw} | no — `$` is an identifier character under default-on `-fdollars-in-identifiers` | reject |
| `@ … @`{.raw} | clean in C++ | the Objective-C sigil, in a lexer Clang shares; reject |
| `<: :>` `<% %>` | — | already digraphs for brackets and braces |

## A.4 The front-runner is not an alias

One candidate deserves honesty: `\< … \>` is lexically bulletproof *and*
asymmetric. Distinct open and close tokens would eliminate the
same-delimiter problem outright — no `BacktickIsOperator` flag — and with
it the nesting rule, since `x \<f \<g\> h\> y` parses unambiguously with no
parentheses. That is, on engineering grounds, a better-designed operator
than the backtick.

It is therefore important to state plainly what adopting it would mean:
not adding an alias, but choosing a *different primary spelling* — a
different operator with a different feel and none of the Haskell lineage.
The decision taken here is backtick as the single spelling. We considered
the better-engineered stranger and chose the familiar borrowed spelling, on
purpose.

## A.5 The rebuttals, pre-loaded

1. **It is ergonomics, not capability.** Inline prose works today via
   CommonMark spans (A.1); fenced blocks cover code.
2. **Two spellings is a permanent tax.** Teaching doubles; clang-format
   must pick a canonical form and normalize to it; `-ast-print` must
   choose; grep, linters, and tooling grow a second case — forever, for a
   cosmetic win.
3. **Direction of travel.** Trigraphs were removed in C++17; digraphs are
   vestigial and periodically floated for removal. A new alternative token
   invites "and will you deprecate this one too?"
4. **It fragments the spelling.** The readability case rests on one
   recognizable form; two camps undercut it.
5. **None reads better.** Backtick is the established infix-quote idiom.
   The alternatives carry foreign connotations — pipe, escape, banana.
6. **If the markup clash warranted a change, it would argue against the
   primary, not for a second spelling.** We weighed that and chose
   backtick-primary anyway. An alias is the worst of both worlds.
7. **"Add it later if needed" is not a cheap option.** A follow-up spelling
   costs its own paper, an EWG poll, CWG wording, and a ballot cycle — and
   risks shipping the operator first and bolting a second spelling on
   after. Deferral buys no option value. The question is settled here.

## A.6 The wider inventory: what ASCII actually remains

The same availability analysis generalizes, and it is what gets asked in
the room, so it is recorded. A sequence `XY` is mintable only if `XY` is
not a token or token-prefix today *and* `Y` cannot validly follow `X` in a
current program. The second clause is the surprising one: after any binary
operator or `<`, the unary-capable characters `- + * & ~ !` are already
legal, so `<-`, `<+`, `<*`, `**`, `!!`, `~~` are all blocked — `a * *p`
and `!!x` are the cautionary cases. `<|` survives only because `|` is the
one bar with no unary form.

Free standalone characters: exactly three, as noted in the grammar section
— backtick (claimed by this proposal), `\` (free as a token but the
line-continuation and UCN lead-in, usable only with care), and `@`/`$`
(compromised by Objective-C and `-fdollars-in-identifiers` respectively).

Clean two-or-more-character sequences of note: `==>`, `<==`, `<==>`,
`<|`, `~>`, and `%%` are mintable today; `=>` and `|>` are lexically clean
but spoken for, by P2971's implication operator and P2011's pipeline
respectively; `<=>` is spaceship; and `^^` — available by the same analysis
until recently — was claimed by reflection [@P2996R5], which itself moved
from single `^` to `^^` after running exactly this exercise. The lesson
from that precedent: doubling an operator with no unary form is the
reliable way to find clean real estate, and doubling one that has a unary
form never is.

## A.7 Why the demand for that inventory evaporates

This proposal is, in effect, a general infix-operator facility: any named
binary operation is `` x `op` y `` with no new punctuator. So the standing
demand for new operator tokens — which is what previously justified
spending scarce lexical real estate — largely evaporates. `` x `implies` y ``,
`` x `pow` y ``, `` x `dot` y `` all work today under the feature, and the
table in A.6 can stay unspent.

The residual cases where a dedicated punctuator is still worth minting are
the ones a desugar-to-call cannot express: non-strict evaluation with a
bare-expression right operand (Walter Brown's short-circuiting `=>`
implication [@P2971R3] — though the motivation section shows a thunk
recovers the capability, leaving the dedicated operator an ergonomic win
rather than a necessary one), custom
precedence or associativity outside the single backtick level, and
operations frequent enough that even `` `op` `` is too much ceremony — a
high bar. Everything else is a backtick call. The inventory above is what
remains technically possible; this proposal removes most of the motivation
to spend it.
