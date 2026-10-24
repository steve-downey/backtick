---
title: "An Infix Operator for C++"
subtitle: "Any callable between backticks is a binary operator"
document: D4307R1
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

C++ has two kinds of binary operation. A fixed set —
the ones with tokens — may be written between their operands: `a + b`, `a <
b`, `a | b`. Every other binary operation, every operation with a *name*, is
a prefix call: `gcd(m, n)`, `dot(u, v)`, `intersects(a, b)`.
The distinction is a lexical accident. We propose to erase it at
the call site. Put a callable between backticks and it is a binary operator:

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

The operator is spelled with the backtick, the last printable ASCII character
the language can still usefully claim. P4307R0 also proposed a second use of
the same character, an escape that lets a keyword be used as an ordinary
identifier. The escape is now its own paper, DxxxxR0. The two occupy mutually
exclusive grammatical positions, the same position-based disambiguation the
language already applies to `*`, `&`, and `<`, so either can be adopted
without the other and in either order. Both are implemented, gated behind an
opt-in `-fbacktick` flag, in two independent compilers, public forks of Clang
and GCC, with tests. This is a pure core-language proposal targeting C++29. No
library additions are proposed.

# Revision history

## R1

- The keyword escape is split out into its own paper, DxxxxR0, at the request
  of reviewers who wanted to consider the two uses separately. Its design and
  wording are unchanged, and so are the operator's. This paper keeps the
  operator, the shared token, and a section on why the two never meet.
- Editorial tightening throughout. No change to the proposed design or wording.

## R0

- Initial revision.

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
reads in; the call spelling is inside-out. None of the "after" column is new
semantics; each right-hand side is defined as the call on its left. The `pipe`
helper in the last row is two lines of ordinary user code (`pipe(x, f)`
returns `f(x)`), shown as motivation. It is not part of the proposal.

# The proposal

`` x `f` y `` is sugar for `f(x, y)` (equivalently
`(f)(x, y)`), where the operator slot between the backticks is an arbitrary
expression parsed as an *assignment-expression*, or a type-name, which
constructs. The value, type, and semantics are exactly those of the
corresponding call. The operator is left-associative and binds tighter than
any other binary operator, looser than the unary and postfix operators.

The operator is gated during the proposal period behind a compiler flag; a
standardized form drops the gate. Flag off, every existing valid program is
untouched: backtick remains, as today, a character with no meaning outside
literals.

# Motivation, beyond readability

The Before/After tables carry the shallow case: binary operations read better
infix, and named operations stop being visually second-class to the dozen
built-in symbols. The deeper case rests on two properties the tables barely
use. The operator slot is an *arbitrary callable expression*, and the operator
chains left-associatively. Those two facts reach further than they first
appear. Everything in this section is the operator plus a few lines of
ordinary user code; none of it is proposed for the standard library (the paper
is language-only), and all of it was compiled and run under the built Clang.

## Short-circuiting returns to user code

C++ reserves non-strict evaluation to a fixed set of built-ins: `&&`, `||`
and `?:`. The comma operator is the near neighbor, and is not one of them: it
evaluates both of its operands, and what it fixes is the *sequencing*.
Overloading does not get non-strict evaluation back: an overloaded `operator&&`
evaluates both operands, which is the trap everyone has been bitten by, and
the reason the standing advice is: don't. Non-strict evaluation has been
closed to user code since C++98.

A backtick helper whose right operand is a *callable* reopens it, because the
helper decides whether (and when) that operand runs:

```cpp
// short-circuiting logical implication:  p => q  ≡  !p || q
inline constexpr auto implies =
    [](bool p, auto&& q) -> bool { return !p || q(); };

p `implies` [&]{ return expensive(); }   // runs only when p holds
```

The same shape gives lazy defaults (``opt `or_else` [&]{ return costly();
}``), guarded effects, and bespoke control operators. Any binary operation
that must not evaluate its right side unconditionally is in reach. Chaining
fallible steps is the zero-ceremony special case: the stages are already
functions, so no thunk is written and the short-circuit falls out:

```cpp
inline constexpr auto mbind =
    [](auto&& m, auto&& f)
    { return std::forward<decltype(m)>(m)
                 .and_then(std::forward<decltype(f)>(f)); };

parse(s) `mbind` validate `mbind` store;   // stops at the first error
```

The concession: a bare-*expression* right operand still
evaluates eagerly, because backtick desugars to a call and calls, of course,
evaluate their arguments. The thunk is what the generality costs. A dedicated
implication operator builds the laziness into the operator instead; Walter
Brown has proposed `operator=>`, with short-circuit
evaluation like `&&` and `||` [@P2971R3]. However, what it adds over the
backtick spelling is ergonomic: omitting the thunk in the common boolean case.
The capability is already there.

## One helper makes it a pipeline, and the ranges closures already fit

A two-line helper turns the operator into left-to-right value threading:

```cpp
inline constexpr auto pipe =
    [](auto&& x, auto&& f) -> decltype(auto)
    { return std::invoke(std::forward<decltype(f)>(f),
                         std::forward<decltype(x)>(x)); };

x `pipe` f `pipe` g `pipe` h        // h(g(f(x))) — data-flow order
```

This drives the *existing* range adaptor closures
unchanged. `views::filter(pred)` and `views::transform(fn)` are already unary
callables (`c | a` is *defined* as `a(c)`), so `pipe` feeds them directly:

```cpp
r `pipe` views::filter(pred) `pipe` views::transform(fn)
// identical result and laziness to:
r |  views::filter(pred) |  views::transform(fn)
```

Same closure objects, same lazy views, verified identical output on the
built compiler. The per-library `operator|` overloads exist only to choose
the `|` *syntax*; the closures themselves need nothing, so they work under
backtick for free.

## Stages with extra arguments: the honest gap

A free function that takes the threaded value first plus extra arguments
needs its trailing arguments fixed, with `std::bind_back` (C++23) or a
lambda, before it is a unary stage:

```cpp
r `pipe` std::bind_back(filter, pred) `pipe` std::bind_back(transform, fn)
// == transform(filter(r, pred), fn)
```

However, this is the case P2011's `|>` writes more directly, with the
arguments inline. Same outcome, more ceremony, and it is why backtick does not
make `|>` redundant. The boundary is drawn in the next section.

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

# Neither replaces the other: P2011's `|>`

The obvious neighbor is the pipeline-rewrite operator, `|>` [@P2011R1]. The
comparison below is against that 2020 design, which states the rewrite most
plainly; the discussion has since moved on to P2672R0 [@P2672R0], which
reopens the design space and puts several shapes of the operator in front of
EWG. Nothing here turns on which shape wins: the orthogonality is between a
symmetric binary infix operator and a directional rewrite that prepends the
left operand to a call, and every shape under discussion is the latter. Both
constructs bottom out in a call expression, and their two-argument cases
coincide (`` a `plus` b ``, `a |> plus(b)`, and `plus(a, b)` are the same
call). They are orthogonal and complementary, and neither subsumes the
other.

What each one is:

- **Backtick.** `` x `f` y `` desugars to `f(x, y)`: symmetric binary infix
  application of a callable. The callee sits between two operands, and the
  result is an ordinary overload-resolved call.
- **`|>`.** `x |> f(a, b)` is *rewritten* to `f(x, a, b)`: a syntactic rewrite
  that prepends the left operand to the call written on its right. There is no
  `operator|>`; it is not overloadable, by design, and the right-hand call has
  any arity.

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
| Overloadable    | yes; it *is* a call         | no, by design                     |
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
  becomes `a |> min(b)`, which reads as a pipeline stage. For `x op y`
  notation (predicates, arithmetic, metrics), backtick is the spelling.

And they compose: backtick supplies infix detail inside a stage, `|>`
threads the value between stages:

```cpp
r |> filter([](auto e){ return e `mod` 2 `eq` 0; }) |> sum()
//                             \____ eq(mod(e, 2), 0) ____/
```

This proposal declines the `|>` spelling for itself (see the
appendix) so that both can coexist in one program. Backtick says "this is a
binary operation"; `|>` says "thread this value through these stages."

# Prior art

The construct has shipped elsewhere, repeatedly. It is not invented here; the
design work in this paper is fitting it into C++'s grammar.

Haskell has spelled it this way since the first Haskell Report (1990): an
ordinary identifier enclosed in grave accents is an infix operator, and `` x
`div` y ``, `` x `mod` y ``, `` xs `elem` ys `` are everyday Haskell. The
descendants kept it. [PureScript](https://book.purescript.org/chapter3.html)
and [Idris](https://docs.idris-lang.org/en/latest/tutorial/typesfuns.html)
both apply any function infix with backticks, as do the Haskell-family
dialects. PureScript is the interesting case, and what it shows is descent
under pressure. Its backtick operators are left-associative at the highest
precedence and cannot be given a fixity at all, which is the Haskell default
and not an independent answer: Haskell 2010 §4.4.2 makes any operator lacking
a fixity declaration `infixl 9`, and the PureScript documentation says so in
as many words, that identifiers in backticks all have the same associativity
and precedence, like in Haskell. However, Haskell lets a fixity declaration
override that default for a backticked name and PureScript does not, and the
PureScript community has twice declined to add one, once as [an issue against
the compiler](https://github.com/purescript/purescript/issues/137) and again
as a standing change proposal on its Discourse. A fixed level, kept fixed
under two requests to make it adjustable, is the level this paper proposes.

Two languages adopted the construct and then removed it. [Elm dropped
backticks in 0.18](https://github.com/elm-lang/elm-platform/blob/master/upgrade-docs/0.18.md),
citing a single function, `andThen`, as pretty much the only one that used the
feature. [Unison likewise removed
it](https://github.com/unisonweb/unison/pull/2570). However, both are
pipeline-first functional languages, where the dominant backtick use was
monadic chaining, the use `|>` covers directly, so the feature was
carrying one use that already had a spelling. The motivating set here (`gcd`,
`dot`, `mul_sat`, `approx_equal`) is binary operations, not chains, and the
P2011 section of this paper keeps the pipeline and the infix operator as
different constructs so that neither has to absorb the other's uses. Elm
folding backtick *into* its pipe is evidence for that separation and not
against infix.

The demand for named infix also keeps surfacing under other spellings:
Kotlin's [`infix
fun`](https://kotlinlang.org/docs/functions.html#infix-notation), Scala's bare
method infix, R's `%op%` operators, Miranda's `$fn` (the direct ancestor of
the Haskell backtick), and Fortress's named operators. Languages keep
reinventing the feature and disagree only on its spelling, and backtick is
the spelling with the deepest working precedent.

# Design choices and decisions

The decisions that shape the design are argued here, one to a section, so
that EWG can poll any one of them on its own.

## It desugars to the call, and that is the whole design

The single most consequential decision is that the operator lowers to a call
expression in the front end, before overload resolution. It is not a macro, a
token rewrite with its own rules, or a new expression category with its own
type rules. The compiler builds the same call node it would have built for
`f(x, y)`.

Everything else follows. If `f(x, y)` compiles, `` x `f` y `` compiles, with
the same result. If `f(x, y)` is ambiguous or ill-formed, so is the backtick
form, with the same diagnostic. ADL applies because ADL applies to the call.
Templates, SFINAE, and `constexpr` work because nothing new was added for
them to fail at. The specification burden on CWG is correspondingly small:
one grammar production and a definitional rewrite.

## Precedence: the highest binary operator, and why not higher

Backtick binds tighter than `*` and looser than the unary and postfix
operators. Both operands are *cast-expressions*, so prefix operators attach
symmetrically:

```cpp
-a `f` -b               // f(-a, -b)     — symmetric
a * b `f` c             // a * f(b, c)   — tighter than *
```

We considered the still-tighter alternative, binding above unary, so that ``
-x `f` y `` would read `-f(x, y)`. There is a real intuition behind it ("the
named operator is the tightest thing there is"). However, it was rejected on
its own consequences: it makes backtick the only operator in the language
where a leading prefix operator floats *out* of its operand, so `` -a `f` -b
`` would mean `-f(a, -b)`. Asymmetric, and hard to teach. Consistency with
every other binary operator won. The sole cost is that `` -x `f` y `` is
`f(-x, y)`, which is the consistent reading anyway. PureScript sits at this
level too, inherited from Haskell along with the construct, and has kept it
there with no way to override it; the prior-art section has the history.

There are three answers to fixity, and this proposal takes the third. Haskell
**declares** it, one `infixl` per name, which makes the parse of an expression
depend on which imports are visible and lets two translation units disagree
about what the same tokens mean. A language of symbolic operators can instead
**derive** it, as OCaml does from an operator's first character. However, that
answer is available only to symbols. The slot here is an expression rather
than a spelling, so `` x `get_op(k)` y `` offers nothing to derive from, and a
rule keyed on bare names would make `` x `f` y `` and `` x `(f)` y `` group
differently. PureScript **fixes** it, and so does this proposal. A fixed level
makes the parse of an expression depend on nothing but the expression; only
the meaning of the slot travels, and that is ordinary lookup.

## Left-associative

```cpp
a `f` b `g` c           // g(f(a, b), c)
```

Chains group in reading order, like `-` and `/`.

## The operator slot is an assignment-expression

Anything you could write as the callee of a call is admitted — a qualified
name, a member access, a lambda — excluding only a top-level comma. The
operands, being cast-expressions, exclude braced-init-lists; `` x `f` {1,2} ``
is not admitted in this proposal. The brace form is meaningful as a call
argument, and could be revisited, but a leading-brace left operand collides
with block syntax, and the workaround is to write the call. We took the
restriction.

## Bare nesting is chaining; real nesting takes parentheses

The open and close delimiter are the same token, so the slot can never contain
a bare backtick; the first interior backtick closes the slot. What looks like
nesting is therefore *token-identical* to a left-associative chain, and that
is how it parses.

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
in [expr.call]{.sref}; since C++17 the callee (the slot, though written
between its operands) is sequenced before both of them. Source order is not
evaluation order for any other call in the language, and this is a call.

## A type name in the slot constructs

A *type-name* is call-eligible, so `` x `T` y `` is `T(x, y)`:
functional-style construction, and CTAD applies:

```cpp
a `std::pair` b         // std::pair(a, b)
```

The grammar says so explicitly: the *backtick-operator* production accepts a
*simple-type-specifier* or *typename-specifier* alongside
*assignment-expression*, and a slot that names a type takes the type
interpretation. (A bare type-name is not an *assignment-expression*, so
without those productions `` a `std::pair` b `` would be a grammar
contradiction.) The result is always an
expression, whichever production the slot takes, so no most-vexing-parse
declaration reading can arise.

## One spelling

Backtick is the sole proposed spelling; there is no digraph and no alternative
token. The objections to backtick (it is Markdown's inline-code delimiter, and
a dead key on some keyboard layouts) are real and minor, and neither is a
capability gap: CommonMark's multi-backtick spans already express `` x `f` y
`` in running prose, and fenced blocks, the dominant case, are unaffected.
That workaround renders correctly today on GitHub, on the committee's own
Mattermost server, and throughout the source of this very paper, which is
written in Markdown and is by now littered with inline renderings of the
single-backtick form. Against that, a second spelling doubles the teaching,
formatting, pretty-printing, and tooling surface permanently, and fragments
the one-recognizable-form spelling the readability argument rests on.
Trigraphs were removed in C++17; digraphs are vestigial. We decline to mint a
new one.

The analysis of candidate alternative spellings is carried in an appendix,
with the rebuttals stated, so the question can be settled against the record
in this paper. It includes the one pair,
`\< … \>`, that would actually be better-engineered, and why adopting it would
be choosing a different operator rather than aliasing this one.

## The escape travels separately; no library

P4307R0 proposed this operator and the keyword escape together, on the ground
that they share a token and a committee, and that two independent designs
for one character could contradict each other. They are now separate papers.
The contradiction the joint paper guarded against has one concrete form, an
escape recognized by the lexer, which would make `` `f` `` an identifier
token and leave `` x `f` y `` three identifiers in a row. DxxxxR0 rules that
out in its own design, for this paper's sake, so the token is shared on terms
both papers state. §"Operator and escape never meet" has the rest.

The library layer is separate for a different reason: pipeline and
composition helpers (`pipe`, `mbind`, and friends) are each a few lines of
user code, would route the paper through LEWG as well, and the operator needs
none of them to function. Any standard helpers wait for a companion library
paper once usage shows which, if any, deserve it.

# Anticipated objections

## "Define `*` on a type instead"

The objection: named binary operations do not need an infix spelling, because
C++ already has one, which is to overload an operator on a type. Saturating
multiplication does not need `` a `mul_sat` b ``; it needs a
`Saturating<double>` whose `operator*` saturates.

Note first that the lift is not optional. Overloaded operators require a class
or enumeration operand, so `double * double` cannot be given new meaning at
all; to change what `*` does to two doubles, inventing a type is the *only*
move the language offers. The objection is not "there is a lighter
alternative"; it is "the heavyweight alternative already exists." And the
committee has already decided this exact example, in the library: C++26's
saturation arithmetic ([@P0543R3]) is `std::add_sat`, `std::sub_sat`,
`std::mul_sat`, `std::div_sat`, named free functions in `<numeric>`. No
saturating wrapper type was shipped. As with `std::gcd`, `std::midpoint` and
`std::lerp` before it, the library keeps choosing names, because the type
encodes the wrong thing.

Types are not free in C++. Haskell writes `newtype Sat = Sat Double` — one
line, guaranteed zero representation cost — and even there the wrapping and
unwrapping is felt as ceremony. C++ has no `newtype`. A usable `Saturating<T>`
is a constructor set; a conversion policy, where `explicit` is safe and noisy
and implicit is quiet and dangerous; the rest of the operator zoo, forwarded;
and an interoperation debt everywhere the wrapper meets existing code:
`is_arithmetic` says no, `numeric_limits` wants a specialization, and every
function that takes a `double` now takes a `.value()`. The result is a real
class to design, review, document, and maintain, as a workaround for one function
lacking an infix spelling.

And the type is the wrong scope. Wrapping a value makes *every* operation
saturating for as long as the wrapper is on, when the intent was one
multiplication in one expression. Saturating versus wrapping versus trapping
is a property of an operation and not of an object. The wrapper cannot compose
for the same reason: `operator*` can mean only one thing per type, so an
expression that needs a saturating multiply and a wrapping add has nowhere to
stand. `` a `mul_sat` b `add_wrap` c `` says it directly, at the site where
each choice applies.

Last, the lift is noise in the place the objection claims to remove
it. `Saturating{a} * b` reads worse than `` a `std::mul_sat` b ``, and it
misdirects: it marks the *data* as special when the *operation* is. The
reader must go find out what `Saturating` does to `*`; the named function
said it in the expression.

The wrapper type is what we write today because the call syntax reads
worse than the operator syntax. This proposal fixes the syntax instead.

# Fitting the grammar, without collision

## The token is free

Backtick has no meaning in C++ source today outside string literals, character
literals, and raw-string delimiters, all of which are handled in translation
phase 3 before punctuator recognition, and are therefore unaffected. A stray
backtick in program text is ill-formed in every current compiler (`` stray '`'
in program ``, in GCC's words). Only three printable ASCII characters are
unclaimed at all: the backtick, the dollar sign, and the commercial at. And
the other two are compromised: the dollar is an identifier character under the
default-on `-fdollars-in-identifiers` in both GCC and Clang, and `@` is the
Objective-C sigil in a lexer Clang shares between the languages. Backtick is
the entire remaining inventory.

## The productions

```bnf
user-infix-expression:
    cast-expression
    user-infix-expression ` backtick-operator ` cast-expression

backtick-operator:
    assignment-expression
    simple-type-specifier
    typename-specifier
```

The second and third alternatives are the type slot, and the type reading
wins exactly when lookup finds a type or a class template. The rule does not
follow from the expression slot: a bare type-name is not an *assignment-expression*,
so a grammar with only the first alternative would contradict the section
above rather than imply it.

*user-infix-expression* slots between *cast-expression* and *pm-expression*:
the pointer-to-member productions consume a *user-infix-expression* where they
consumed a *cast-expression*, and everything above them is unchanged. In
implementation terms this is one new top level in each compiler's binary
operator precedence table. The left recursion gives left associativity; the
*cast-expression* operands give the symmetric prefix binding argued for above.

The new level is **not** a *fold-operator*: `` (... `f` N) `` is
ill-formed. Both implementations reject it, each with an ordinary parse error
that says nothing about why, which is the reason for stating the exclusion
here: nothing else would say it was chosen. Excluding costs one clause in the
predicate that already decides which operators may be folded over; admitting
would require a fold-expression node that can hold an arbitrary slot
expression, which today's cannot. Nothing is foreclosed; every program a later
revision would newly accept is one this proposal rejects.

## The same-delimiter problem

The open and close delimiter are the same token, so while parsing the operator
slot, a naive expression parser would take the closing backtick as the start
of a second, nested backtick operator. C++ has, of course, been here before:
`>` inside a template-argument list is a closer, not an operator, and
`vector<vector<int>>` is handled by a parser flag — Clang's
`GreaterThanIsOperator`, GCC's `greater_than_is_operator_p` — that turns the
operator meaning off in that context. We do the same thing: a
`BacktickIsOperator` flag, false while parsing the slot, restored inside any
nested parentheses or brackets so that parenthesized nesting works. Both
implementations are modeled line-for-line on their compiler's existing `>`
handling. This is the one genuinely novel parsing obligation the operator
carries, and it is a solved problem with fifteen years of production
precedent.

## Operator and escape never meet

This operator and DxxxxR0's keyword escape share the backtick and never
compete for it. The escape takes operand and name positions, where
`` `new` `` is an ordinary identifier spelled `new`; the operator takes the
post-operand position. Neither paper needs the other. There is one seam, an
escape inside the slot, and one requirement, that the escape be parsed
rather than lexed.

The two uses can share the token because C++ expression grammar strictly
alternates between wanting an operand and wanting an operator. The escape
lives exclusively in operand and name positions; the infix operator lives
exclusively in the post-operand position. The positions are mutually
exclusive, so one lexical token serves both uses with no lookahead and no
ambiguity, the same strategy the language already uses to give `*`, `&`, and
`<` their multiple readings. The forks implement both, under one flag:

```cpp
int `new`(int, int);  // declarator-id  -> escaped identifier "new", DxxxxR0
`new`(a, b);         // primary        -> call to the function named "new"
obj.`delete`();      // after '.'      -> member named "delete"
x `f` y;             // post-operand   -> infix: f(x, y)
x `(`new`)` y;       // escaped callee -> (`new`)(x, y), parenthesized slot
```

Without the escape, a backtick in operand position is simply ill-formed, as
it is today; without the operator, a backtick after an operand is. The seam
is the last line. An escape
*inside* the slot must be parenthesized, because the closing rule of
[expr.backtick] takes the first unnested backtick as the end of the slot:
`` x ``new`` y `` is an empty slot followed by stray tokens, and both
compilers reject it. That follows from this paper's wording as it stands and
needs nothing from the escape's.

The requirement: the escape must stay a parse of three tokens
rather than a lexer rule that makes `` `f` `` a single identifier token,
since that would read `` x `f` y `` as three identifiers in a row. DxxxxR0
states that constraint as part of its own design.

There might seem to be a second, independent signal here: that an escape
wraps a keyword, which is never a valid callee expression, and a slot wraps an
expression, which is never a bare keyword. The escape wraps any identifier,
so that signal does not exist, and the design does not rest on it. Read as an
escape and read as a slot, `` `f` `` names the same thing, `f`; the two
readings differ only over whether `f` is an operand or a callee, and that is
precisely what the position states. Position alone suffices, as it does for
`*`, `&`, and `<`.

# Implementation experience

The operator is implemented, gated behind an opt-in `-fbacktick` flag, in
two independent compilers, with tests, and each compiler's full regression
gate stays green with the flag off and on. The same forks implement
DxxxxR0's keyword escape under the same flag, and that paper carries the
escape's own implementation experience. This section is what building the
operator changed in the design and what building it got wrong. Both are summarized
here and expanded in the subsections that follow; a reader who writes
compilers for a living can take the summary and skip the rest.

**What the implementation changed.** Two things in this paper are there
because the compilers demanded them.

- *The slot reaches the call builder unresolved.* `` x `f` y `` must not have
  weaker lookup than `f(x, y)`. Neither compiler delivered that on its first
  attempt, both for the same reason, and ADL fidelity is now a normative rule
  of the design rather than an expected consequence of it.
- *The type-name slot is its own production.* A bare type-name is not an
  *assignment-expression*, so the grammar carries the two type productions
  rather than implying them. It was also the last place the two compilers
  differed.

**What went wrong.** Four defects, all found after the prototypes were
finished, none of them a design question, and all fixed:

1. *ADL.* Clang's slot had no ADL at all; GCC's had it for a bare name but not
   for a template-id, and inside a template had nothing else, losing the
   ordinary lookup. The shape that catches this, a visible and viable
   candidate beaten by one reachable only through ADL, was in neither test
   suite.
2. *Printing.* The operator printer lacked two arms: aggregate
   initialization, which failed silently by printing a different program, and
   class-typed callables, every lambda in the motivation section, which failed
   loudly with an inverted source range.
3. *The flag leaked.* Clang's flag reached C compilations; GCC's parser tested
   the flag without testing the token. One line each, found by comparing
   flag-on against flag-off output on a program that never mentions the
   feature.
4. *The transparent node.* Clang's source-fidelity wrapper had to be taught to
   the static analyzer and its bug reporter, the code generator, libclang, and
   the AST matchers, and every one of those sites is quiet when it is wrong.
   GCC desugars in the parser and needs none of it.

**What is left.** Nothing the two compilers disagree about: under the flag
they accept and reject the same programs. The type-name slot was the last
difference, and is described next.

## The forks

Both forks are public:

- **Clang**, two branches carrying the same feature diff, one on the LLVM 23
  release branch ([steve-downey/llvm-project @
  backtick-23](https://github.com/steve-downey/llvm-project/tree/backtick-23))
  and one on trunk ([@
  backtick-trunk](https://github.com/steve-downey/llvm-project/tree/backtick-trunk)):
  lexer token, the new binary precedence level, a parser branch modeled on the
  ternary operator (the closest existing delimited-middle operator), Sema
  desugaring to a `CallExpr`, the driver flag, a transparent AST wrapper so
  `-ast-print` round-trips the surface syntax, and clang-format support for
  both uses (canonical spacing, and a break policy that hard-forbids a break
  next to either backtick). A bare unqualified name in the slot reaches the
  call builder unresolved, as an `UnresolvedLookupExpr`, so ADL is the call's.
  Tests live under `clang/test/` (the `backtick-*` files in `Parser/`,
  `Lexer/`, `SemaCXX/`, `AST/`, `Analysis/` and `CIR/CodeGen/`, plus `Driver/`
  and the Format unit tests), and the full `check-clang` regression gate stays
  green with the flag off and on.
- **GCC** ([steve-downey/gcc @
  backtick](https://github.com/steve-downey/gcc/tree/backtick)): `libcpp`
  token (replacing today's `` stray '`' in program `` diagnostic), parser
  precedence level and slot handling, desugaring via `finish_call_expr`, the
  same flag, and ADL on the slot for both unqualified forms, a plain name and
  a template-id. Tests live under `gcc/testsuite/g++.dg/backtick/`.

The GCC branch was later rebased over three months of upstream trunk: 2158
commits, 177 of them touching the C++ front end, the front-end infrastructure
it shares with C, or the preprocessor. Every line the feature adds or removes
came across unchanged, with no conflict. Nothing the feature touches had moved
under it. For a design whose whole claim is *desugar and inherit*, that is the
number that matters: a diff of this shape has very little to catch on.

## The type-name slot

Both compilers implement the type-name slot, and both build a type slot as
the functional cast `T(x, y)`, which is where CTAD, temporaries and aggregate
initialization come back for free. Clang looks a bare name up as a type with
a deduction placeholder, a qualified one through a tentative parse, and a
builtin through the functional-cast path. GCC reuses the part of its
expression parser that recognizes `T(` as a functional cast, with the closing
backtick standing where the parenthesis stands there. Lookup inside that
parse is what makes the type reading win exactly when lookup finds a type or
a class template, so a function that hides a class of the same name leaves
the slot a call in both. GCC's arm came well after Clang's, and until it was
written `` 1 `Pt` 2 `` was rejected there and accepted by Clang.

## Printing the operator

Clang's `-ast-print` round-trips every shape the operator can take, with one
exception a reviewer will find: a slot naming a builtin whose call the
semantic layer rewrites into a node that is no longer a call
(`` a `__builtin_shufflevector` b ``) prints as the rewrite, because the
rewrite is not expressible in the syntax at all.

The printer failed twice before it got there, and both were found the same way, by
re-deriving this paper's claims against the compilers rather than reading them
off the implementation. How they were missed is the general point. The printer
and the source range both recover the operands from whatever the semantic
layer built, so every node that layer can hand back needs its own arm. A type
slot naming an aggregate does not construct through a constructor; it
initializes through parenthesized aggregate initialization and comes back as a
different node. A slot whose *value* is a class-typed callable (every lambda,
every function object, every helper the motivation section is
written on) is called through the object's own `operator()`, which the
semantic layer keys as an operator call: the slot lands at argument zero and
the operands shift one place along. Both arms were missing.

The two failed in opposite ways. The aggregate arm failed *silently*. It
printed the desugaring, which was well-formed, plausible, and not what was
written; in the deduced case it printed a cast applied to a comma expression,
a different program altogether. The callable arm failed *loudly*. It printed
text naming `operator()` as a free function, which does not compile, dropped
an operand, and reported a source range whose end preceded its beginning.
Neither was caught, because the round-trip test had no case of either shape.

**A round-trip claim is a claim about every node the semantic layer can build,
not about the nodes the printer was written against.** The second of the two
was found by asking that question. Both arms are written now, and the
exception above is all that is left.

## Argument-dependent lookup, which both implementations got wrong

ADL fidelity is normative in this design: `` x `f` y `` must not have quietly
weaker lookup than `f(x, y)`. Neither compiler delivered it on its first
attempt, and the two failures were the same failure: the name in the slot was
resolved before the call builder ever saw it. Both deliver it now, inside a
template as well as outside one.

GCC took two goes. Its first cut resolved a bare-name slot at parse time, so a
call depending on pure ADL — the callee visible in no enclosing scope, only in
an argument's namespace — failed there and compiled elsewhere. The fix routed
the slot through the same Koenig lookup a plain call performs, but recognized
only a bare name, so a slot carrying template arguments kept the old behavior
silently for another round.

Clang started further back: its slot was parsed with the ordinary expression
parser, which resolves the name before the call builder is reached, so the
slot had no ADL at all. A hidden friend in the slot was *use of undeclared
identifier*. And in the shape that matters, nothing was said at all: with an
ordinary-lookup candidate visible and viable, and a better candidate
reachable by ADL, `` u `pick` u `` bound the visible one while `pick(u, u)`
bound the ADL one, no diagnostic anywhere. The operator called a different
function from the call it is defined to be.

That defect produced the strongest evidence in this paper for the desugaring
thesis, and it is inside one compiler rather than between two. The Clang build
carrying the backtick operator also carried a second infix experiment
(user-defined operators spelled with Unicode symbols, a companion design not
proposed here) whose slot never becomes an expression: Sema performs its own
operator lookup and hands an unresolved set to candidate assembly. One build,
one machine, one author, one difference. The feature that reached the call
builder unresolved inherited ADL from its first commit, without anyone
deciding to inherit it; the feature that resolved its slot first had to be
repaired: the whole thesis, with the compiler and the author held constant.

The defect survived
the entire implementation because the one test that announced itself as the
ADL case used a *qualified* name in the slot, which correctly gets no ADL
either way; it passed whatever the slot did, and its heading was enough to
stop anyone writing the test that would have failed. The shape that catches
this is *augmentation*: an ordinary-lookup
candidate that is visible and viable, a better ADL candidate, and the choice
made observable in the result type. That is the only shape in which weaker
lookup on the slot produces no diagnostic at all, and no implementation should
be believed without it.

GCC needed a third go, for templates, and it was this section's own rule
failing on the other side. Inside a template, an unqualified slot naming
something argument-dependent lookup cannot reach, a function brought in by a
using-declaration for instance, was rejected by GCC and accepted by Clang.
GCC kept the bare name until instantiation and then had only ADL to run on
it, losing the ordinary lookup from the definition context that
[temp.dep.candidate]{.sref} requires. A variable failed the same way, and an
ADL-reachable name was accepted, so what was lost was ordinary lookup itself.
The plain call compiled all along: in one translation unit, `pipe(t, inc)` was
accepted where `` t `pipe` inc `` was not. The fix was to stop writing the
slot's lookup by hand. GCC now parses a bare-name slot as it parses the name
in a call, and builds the call under the same rules for when ADL applies, so
a dependent argument no longer changes what the slot finds. The same change
fixed a case no test had covered: outside a template, a variable in the slot
that shared its name with a function ADL could reach crashed the compiler,
because the slot asked for the ADL that a call naming a variable does not
do.

## What the AST node costs, and which compiler pays it

Clang builds a source-fidelity node, a transparent wrapper around the
desugared call, and that node is why `-ast-print` reproduces the
written syntax. GCC desugars in the parser and hands its semantic layer an
ordinary call. The two accept the same programs and generate the same code,
so they differ in kind and behave identically. The node's cost is its
transparency: a wrapper the rest of the compiler is meant not to notice is a
wrapper nothing will remind you to teach anything about, and the sites that
need teaching are quiet when they are wrong: six in the static analyzer's
modelling layers, a seventh in the bug reporter created by meeting the other
six, four arms in the code generator, the exhaustive statement-class
switches, the libclang cursor map, the AST matchers. Exactly one of the
analyzer's seven announces itself, and only as a warning in a build log.

The seventh came from teaching the control-flow graph to look through the
wrapper, which leaves the wrapper with no program point of its own, so
the bug reporter's tracking chain is abandoned before a single handler runs,
and with it the suppression, on by default, that keeps `core.NullDereference`
quiet about a null returned from an inlined callee. `` p `identity` 0 ``
reported a false positive that the identically-desugaring `identity(p, 0)` was
spared, and the report it did emit carried two path notes where the call's
carried eight. The operator form was noisier than the call it is sugar for,
and explained less. One arm in the reporter's peeling routine fixes both
symptoms at once, because peeled early the two forms are one expression for
everything downstream; the two reports now agree note for note.

Round-tripping the written syntax costs all of that. A front end that
desugars in the parser has none of the cost and none of the round trip.

## The gate fails quietly

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
grammar. Clang carried a diagnostic for the
bare form through most of the implementation and it never once fired; it was
deleted rather than made to fire, since making it fire needs the lookahead
that would have to reject legal chaining too.

The motivation section is implementation experience as well. Every pattern in
it (`pipe` threading, the range-adaptor closures,
the `bind_back` stages, `then` composition, the short-circuiting `implies` and
the `mbind` chain) was compiled and run against the built `-fbacktick` Clang,
C++23, `-Wall -Wextra` clean. The ranges comparison was verified to produce
identical results and identical laziness through `|` and through `` `pipe` ``,
on the same closure objects.


# The design, in one place

Everything argued above reduces to the following, and the wording that
follows says no more than this. Every item is decided, and every item is
implemented in both compilers.

- `` x `f` y `` is `f(x, y)`. It is desugared in the front end, before
  overload resolution, to the call node the compiler would have built for
  the call; overload resolution, ADL, templates, `constexpr`, conversions,
  value categories and code generation are the call's. ADL fidelity is
  normative: the slot reaches the call builder unresolved.
- The slot is an *assignment-expression*, or a *simple-type-specifier* or
  *typename-specifier*, in which case `` x `T` y `` is `T(x, y)` and CTAD
  applies. The type reading wins when lookup finds a type or a class
  template.
- Precedence is the highest binary level: tighter than `*`, looser than the
  unary and postfix operators. Operands are *cast-expressions*, so a prefix
  operator binds to its own operand and `` -a `f` -b `` is `f(-a, -b)`.
- Left-associative: `` a `f` b `g` c `` is `g(f(a, b), c)`. Fixity is fixed,
  not declared per name and not derived from a spelling.
- Bare nesting is chaining, because the token stream is the same. To nest,
  parenthesize the slot. Neither compiler diagnoses the bare form, and
  neither can without rejecting legal chains.
- Evaluation order is the call's: the slot is sequenced before both operands,
  the operands are unsequenced with respect to each other.
- Operands exclude braced-init-lists. The operator is not a *fold-operator*.
- One spelling. No digraph, no alternative token.

- One token, two grammatical positions, no lookahead: post-operand position
  is this operator, and operand and name position is left to DxxxxR0's
  keyword escape. Neither paper depends on the other.
- Gated behind an opt-in flag for the proposal period. Flag off, every
  existing program is untouched, byte for byte.
- No library. `pipe`, `then`, `mbind` and `implies` are motivation, each a
  few lines of user code, and any that deserve standardizing arrive in a
  later paper with usage behind them.

# Wording

The following wording is pro forma. It is intended to make the grammar change
concrete; it is not offered as final CWG wording. Wording is relative to the
current working draft.

*Drafting note, for whichever of this paper and DxxxxR0's keyword escape is
adopted second.* Both add `` ` `` to [lex.operators]{.sref}. The first one in
makes the edit, and the second drops it. Nothing else in either paper's
wording touches the other's.

## [lex.operators]

Modify the *operator-or-punctuator* grammar in [lex.operators]{.sref}
paragraph 1 by adding `` ` `` :

::: add
> ```
> operator-or-punctuator: one of
>        ...
>        ?     ::    .     .*    ->    ->*   ^^    ~     `
>        ...
> ```
:::

[The row shown is [lex.operators]'s third; only the trailing `` ` `` is
added.]{.note}

## [expr.mptr.oper]

Modify the grammar of [expr.mptr.oper]{.sref} paragraph 1:

> ```
> pm-expression:
>     @[cast-expression]{.rm} [user-infix-expression]{.add}@
>     pm-expression .* @[cast-expression]{.rm} [user-infix-expression]{.add}@
>     pm-expression ->* @[cast-expression]{.rm} [user-infix-expression]{.add}@
> ```

## [expr.backtick] (new subclause)

Insert a new subclause between [expr.cast]{.sref} and
[expr.mptr.oper]{.sref}:

::: add
> **Backtick operator   [expr.backtick]**
>
> ```
> user-infix-expression:
>     cast-expression
>     user-infix-expression ` backtick-operator ` cast-expression
>
> backtick-operator:
>     assignment-expression
>     simple-type-specifier
>     typename-specifier
> ```
>
> [1]{.pnum} An expression of the form
> `` E1 `O` E2 `` is identical (by definition) to `O(E1, E2)`
> ([expr.call]{.sref}).
>
> [2]{.pnum} If the *backtick-operator* is a *simple-type-specifier* or
> *typename-specifier* denoting a type `T` or a placeholder for a deduced
> class type, an expression of the form `` E1 `T` E2 `` is identical (by
> definition) to `T(E1, E2)` ([expr.type.conv]{.sref}). A
> *backtick-operator* whose tokens can be interpreted both as an
> *assignment-expression* and as a *simple-type-specifier* or
> *typename-specifier* is interpreted as a *simple-type-specifier* or
> *typename-specifier*.
>
> [3]{.pnum} When parsing a *backtick-operator*, the first non-nested
> `` ` ``^[A `` ` `` that appears within a matching pair of parentheses,
> brackets, or braces is nested.] is taken as the ending delimiter, rather
> than as the first delimiter of a nested *user-infix-expression*.
:::

Annex A ([gram]{.sref}) is updated mechanically to match.

# Appendix A: alternative spellings, and the lexical inventory

Backtick is the sole proposed spelling. This appendix carries the analysis
behind that decision: why alternatives get raised, the lexical filter any
candidate must pass, the candidates themselves, and the wider inventory of
what ASCII actually remains, so that if the spelling question is raised it can
be settled against this record in this paper instead of reopened in a future
one.

## A.1 Why alternatives get raised

Two reasons, both real, both minor. A single backtick is Markdown's
inline-code delimiter, so `` x `f` y `` in running prose fights the markup.
And backtick is a dead key or awkward on some non-US keyboard layouts; it was
one of the ISO-646-variant characters, alongside `# [ ] { } | ~ ^ \`.

The Markdown objection is on the record in WG21, made against this exact
character by seven authors. P3381R0 [@P3381R0] evaluated twelve
single-character spellings for the reflection operator, and four
multi-character ones, the backtick among them, and rejected it:

> The backtick has the advantage that it's pretty small, even smaller than
> `^`. But it has the disadvantage that backtick is used by Markdown
> everywhere inline code blocks, and not all Markdown implementations properly
> give you mechanisms to escape it. While not necessarily a show-stopper, we
> also just don't think it's good enough to reasonably pursue.

The objection is granted, and the reasoning is right for the operator it was
reasoning about. However, that operator is not this one. A reflection operator
is written once per reflection and sits inside dense expression text, where a
backtick operator is written where the name of an operation would go; the
CommonMark cost falls on different text, at a different density, and the
same span form handles it either way.

Neither is a capability gap. CommonMark's multi-backtick spans already delimit
code containing backticks (writing ``` `` x `f` y `` ``` renders as `` x `f` y
``), and fenced blocks, the dominant case for code, are unaffected entirely.
The span form renders correctly on GitHub and on Mattermost, the committee's
own chat server (author-verified). In the very forum where the operator would
most often be typed in running text, the friction is a solved problem. What an
alternative spelling offers is ergonomics for the minority case, inline prose.

There is also a self-test on the record: the source of this paper is pandoc
Markdown, and every `` x `f` y `` in its running prose is a multi-backtick
span in the source. The friction is real; each inline example costs the
doubled delimiters and a padding space. However, it is demonstrably
survivable: a Markdown paper *about* the backtick operator is the worst case
the objection can construct, and the one you are reading renders.

## A.2 The filter a candidate must pass

An alternative spelling is an additional token lexed by maximal munch, like
the existing digraphs. To be viable, the sequence must never appear
adjacent in a valid current program. Three traps, each of which has bitten
a real token before:

1. **Maximal-munch theft.** After a binary operator or `<`, a
   unary-capable character is already valid: `a < -b`, `a * *p`, `!!x`.
   Minting the two-character form silently changes meaning.
2. **The `::` neighborhood.** `a<:b` needed the `<::` carve-out in
   [lex.pptoken]{.sref} because `vector<::std::string>` broke. Any new
   `<`-prefixed token lives next to that scar.
3. **Universal-character-name munch.** `\uXXXX` can begin an identifier, so a
   candidate whose second character is `\` can split a UCN, a non-obvious
   break.

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

One candidate is different: `\< … \>` is lexically bulletproof *and*
asymmetric. Distinct open and close tokens would eliminate the same-delimiter
problem outright (no `BacktickIsOperator` flag) and with it the nesting rule,
since `x \<f \<g\> h\> y` parses unambiguously with no parentheses. That is,
on engineering grounds, a better-designed operator than the backtick.

However, adopting it would mean choosing a *different primary spelling*, a
different operator with a different feel and none of the Haskell lineage. It
would not be an alias. The
decision taken here is backtick as the single spelling. We considered the
better-engineered stranger and chose the familiar borrowed spelling, on
purpose.

## A.5 The rebuttals, pre-loaded

1. **It is ergonomics and not capability.** Inline prose works today via
   CommonMark spans (A.1); fenced blocks cover code.
2. **Two spellings is a permanent tax.** Teaching doubles; clang-format must
   pick a canonical form and normalize to it; `-ast-print` must choose; grep,
   linters, and tooling grow a second case, forever, for a cosmetic win.
3. **Direction of travel.** Trigraphs were removed in C++17; digraphs are
   vestigial and periodically floated for removal. A new alternative token
   invites "and will you deprecate this one too?"
4. **It fragments the spelling.** The readability case rests on one
   recognizable form; two camps undercut it.
5. **None reads better.** Backtick is the established infix-quote idiom. The
   alternatives carry foreign connotations: pipe, escape, banana.
6. **If the markup clash warranted a change, it would argue against the
   primary and not for a second spelling.** We weighed that and chose
   backtick-primary anyway. An alias is the worst of both worlds.
7. **"Add it later if needed" is not a cheap option.** A follow-up spelling
   costs its own paper, an EWG poll, CWG wording, and a ballot cycle, and
   risks shipping the operator first and bolting a second spelling on after.
   Deferral buys no option value. The question is settled here.

## A.6 The wider inventory: what ASCII actually remains

The same availability analysis generalizes, and it gets asked in the room. A
sequence `XY` is mintable only if `XY` is not a
token or token-prefix today *and* `Y` cannot validly follow `X` in a current
program. The second clause is the surprising one: after any binary operator or
`<`, the unary-capable characters `- + * & ~ !` are already legal, so `<-`,
`<+`, `<*`, `**`, `!!`, `~~` are all blocked; `a * *p` and `!!x` are the
cautionary cases. `<|` survives only because `|` is the one bar with no unary
form.

Free standalone characters: exactly three, as noted in the grammar section.
They are the backtick (claimed by this proposal) and `@` and `$`, compromised
by Objective-C and `-fdollars-in-identifiers` respectively. There is a fourth
character, `\`, which is free as a *token* and is not counted among the
three: it is the line-continuation marker and the universal-character-name
lead-in, so it is usable only with care.

Clean two-or-more-character sequences of note: `==>`, `<==`, `<==>`, `<|`,
`~>`, and `%%` are mintable today; `=>` and `|>` are lexically clean but
spoken for, by P2971's implication operator and P2011's pipeline respectively;
`<=>` is spaceship; and `^^` — available by the same analysis until recently —
was claimed by reflection [@P2996R13]. Reflection moved from a single `^` to
`^^` in P3381R0 [@P3381R0], after running this exercise, and that
paper's candidate table reaches this section's count independently: it calls
the backtick the third character recently added to the basic character set,
after `$` and `@`. The lesson from that precedent: doubling an operator with
no unary form is the reliable way to find clean real estate, and doubling one
that has a unary form never is.

## A.7 Why the demand for that inventory evaporates

This proposal is, in effect, a general infix-operator facility: any named
binary operation is `` x `op` y `` with no new punctuator. So the standing
demand for new operator tokens, which is what previously justified spending
scarce lexical real estate, largely evaporates. `` x `implies` y ``, `` x
`pow` y ``, `` x `dot` y `` all work today under the feature, and the table in
A.6 can stay unspent.

The residual cases where a dedicated punctuator is still worth minting are the
ones a desugar-to-call cannot express: non-strict evaluation with a
bare-expression right operand (Walter Brown's short-circuiting `=>`
implication [@P2971R3]; though the motivation section shows a thunk recovers
the capability, so the dedicated operator is an ergonomic win), custom
precedence or associativity outside the single backtick
level, and operations frequent enough that even `` `op` `` is too much
ceremony, a high bar. Everything else is a backtick call. The inventory above
is what remains technically possible; this proposal removes most of the
motivation to spend it.
