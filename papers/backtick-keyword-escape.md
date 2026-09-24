---
title: "A Keyword Escape for C++"
subtitle: "Backticks around a name, so that a new keyword breaks nothing"
document: DxxxxR0
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
references:
  - id: P4307R0
    citation-label: P4307R0
    title: "An Infix Operator and a Keyword Escape for C++"
    author:
      - family: Downey
        given: Steve
    issued: { year: 2026 }
    URL: https://wg21.link/p4307r0
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

C++ has no way to use a keyword as a name, so every keyword the committee adds
breaks every program that used the word as one. The committee knows this, and
works around it every time: C++20 shipped `co_await`, `co_yield`, and
`co_return` because `await` and `yield` were taken, and made `module` and
`import` context-sensitive, at real specification and implementation cost,
because breaking existing code was not acceptable. The languages designed
since have built in an escape for this case: Swift's `` `class` ``, Kotlin's
backtick identifiers, F#'s double-backtick names, Rust's `r#` raw
identifiers. We propose the same hatch.

A backtick pair in name position escapes a word and yields a plain
identifier, so lookup, mangling, linkage, and ABI are untouched;
`` void `new`(); `` declares an ordinary function named `new`. The word need
not be a keyword, which makes the hatch prospective rather than merely
remedial: `` `foobar` `` is the same identifier as `foobar`, so a name can be
escaped before the committee takes it, in code that still has to compile
today. Future keywords stop being breaking changes, and stop needing
`co_`-style circumlocution to avoid becoming one.

The escape was first proposed in P4307R0 [@P4307R0], together with an infix
operator spelled with the same character, `` x `f` y ``. The two are now
proposed separately. They occupy mutually exclusive grammatical positions, so
either can be adopted without the other and in either order; this paper
states the one constraint that keeps it that way. Both are implemented,
gated behind an opt-in `-fbacktick` flag, in two independent compilers,
public forks of Clang and GCC, with tests. This is a pure core-language
proposal targeting C++29.

# Revision history

## R0

- Initial revision. The keyword escape is split out of P4307R0, where it was
  proposed together with the infix operator. Its design and wording are
  unchanged from that paper.
- Relative to P4307R0's treatment of the escape, implementation experience
  now describes all three cross-compiler divergences the escape sweeps found
  (P4307R0 announced three and described two), the escape-position sweep is
  linked in the public implementation record, and the GCC printing gap is
  described once, under Printing.

# Before / After

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
changes: same name, same mangling, same ABI. The more important use is prospective.
A committee choosing a future keyword no longer has to weigh breaking every
use of a good name against mangling the keyword into `co_`-style
circumlocution or context-sensitivity.

That depends on the escape wrapping any identifier, including the words
that are not keywords yet. Suppose the escape is standardized in one revision
and the committee
takes `requires` in the next. If only a keyword could be escaped, the After
column would be ill-formed in the first revision, where `requires` is still an
ordinary name, and mandatory in the second. A header that must compile as both
would need two spellings and a macro to choose between them, and no name could
be escaped until after it had broken. A precaution that cannot be taken until
after the damage is a repair. Because any identifier may be escaped, the After
column declares the same function in both revisions, and code can be escaped
in advance, on purpose, before the committee has chosen anything.

This is the rule regular expressions already use. A backslash before a
metacharacter means that character, and a backslash before a character that
was never a metacharacter is just that character, which is why a generator can
escape unconditionally instead of consulting a table and why a person can
future-proof a pattern by escaping on sight. The backtick escape is the same
construct one level up. It suppresses syntax when the word is syntax, and when
the word is not syntax it is the word.

# The proposal

In any position where the grammar expects a name (a *declarator-id*, a class,
enumeration or namespace name, a template parameter's name, a label, an
operand, after `.`, `->`, or `::`), a backtick pair wrapping a word spelled as
an identifier denotes an ordinary identifier whose spelling is that word.
Keywords are the case the feature is named for, and the rule is not
restricted to them: `` `foobar` `` and `foobar` are the same identifier, so a
declaration may use one spelling and its uses the other. It is purely a
source-level construct; the resulting identifier participates in lookup,
mangling, and linkage exactly as if the word had never been a keyword.

The escape is gated during the proposal period behind a compiler flag; a
standardized form drops the gate. Flag off, every existing valid program is
untouched: backtick remains, as today, a character with no meaning outside
literals.

# Prior art

The escape is standard equipment in the languages designed since: C#'s
`@`-verbatim identifiers (2000), F#'s double-backtick names (2005), Nim's
backtick stropping (2008), Kotlin's backtick identifiers (2011), Swift's ``
`class` `` (2014), and Rust's [`r#` raw
identifiers](https://doc.rust-lang.org/edition-guide/rust-2018/module-system/raw-identifiers.html)
(2018). Every one of them is younger than C++'s first standard. Rust's
motivation is on the record: `r#` was introduced so the 2018 edition could
take `try`, `async`, and `await` as keywords while 2015-edition code kept
compiling and kept calling functions with those names. Editions plus raw
identifiers are how Rust made keyword adoption routine, and its grammar is
the shape of the one proposed here; §"The escape yields an ordinary
identifier" makes that case.

The comparison that bears on C++ is C. Same problem, same era, a different
answer: the reserved spelling. `_Bool` in C99, then `_Alignas`,
`_Static_assert` and `_Thread_local` in C11, each shipped with a header macro
supplying the name anyone would actually write, and each promoted to a plain
keyword in C23 once the macro had carried the migration. Choose a spelling no
program could have used, and let a macro hold the good name until the good
name is safe. `co_await` is that move without the macro.

Python is nearer still, is taking keywords now, and has no escape either. It
has 35 reserved words and no way to spell one as a name, so when the language
wanted `match` it did what C++ did with `module`: `match`, `case` and `_` are
*soft keywords* in 3.10, reserved only inside the `match` statement, as `type`
is in 3.12. Context-sensitive grammar, arrived at independently. Everywhere
else the workaround is institutional, and PEP 8 writes it down: "it is
generally better to append a single trailing underscore rather than use an
abbreviation or spelling corruption. Thus `class_` is better than `clss`."

Three answers to a keyword collision are in use: break the code, mangle the
keyword, or make the grammar context-sensitive. C++ has used the second and
the third, and so has C. The fourth needs a spare token, which is why the
languages that have one are the ones designed with a token to spend. C++ has
one left.

# Design choices and decisions

The decisions that shape the design are argued here, one to a section, so
that EWG can poll any one of them on its own.

## The escape yields an ordinary identifier

The keyword escape does all of its work in the parser and none anywhere
else. `` `new` `` in a name position produces an ordinary identifier whose
spelling is `new`; lookup, overload resolution, mangling, and linkage
proceed as if the word had never been a keyword. There is no lexer
identifier-synthesis, no new name category, no ABI surface. The escape gives
C++ what Swift, Kotlin, F#, and Rust got from theirs: the
committee can claim a good word as a keyword without breaking the programs
that already use it, and a program that must interoperate with one of those
languages, or with its own past, can name the entity it needs to name.

The word between the backticks does not have to be a keyword. Anything
spelled as an identifier may stand there, and what comes out is that
identifier and nothing more specific. `` `foobar` `` **is** `foobar`: the same
entity, found by the same lookup, with the same linkage and the same mangling,
and a program may write the name either way in either place. Every other rule
about identifiers then applies to the result unchanged. A reserved name stays
reserved, so `` `__foo` `` buys nothing that `__foo` does not already cost.
An object-like macro name is still replaced, because the escape is a phase 7
construct and phase 4 has never heard of it. A function-like macro name is
not, for the preprocessor's own reason: it is replaced only when the next
token is `(`, and here the next token is the closing backtick. Both forks
behave this way. The backticks neither shield a name from the preprocessor
nor expose one to it.

The alternative is to restrict the content to words that actually are
keywords, so that `` `foo` `` is ill-formed rather than a noisy spelling of
`foo`. We reject it, for the reason the motivating example gives: an escape
that only accepts words that are already keywords cannot be written until the
standard that takes the word has shipped, so it can repair a break and can
never prevent one. The restricted rule has two more consequences. A tool that
generates C++ would have to carry the keyword list, per dialect, and would be
wrong on the day the list changes, which is the day it was supposed to help. And the
backticks would acquire a meaning of their own: a reader would have to know
whether the word is a keyword in this dialect before knowing whether the line
is well-formed. Under the rule proposed here the backticks say only "this is a
name", which is true whatever the word is, and the question never has to be
asked.

The alternative representations, `and`, `bitor` and their nine siblings, are
escapable under the same rule and are meant to be. In C++ they are tokens and
not macros: identifier-shaped words the language has claimed, which is the
category the escape exists to release, and suppressing that is what an
escape is for. Nothing makes them exceptional, so nothing should except them,
and excluding them would put a list back where the value of the rule is that
there is no list. They also show the printing rule doing its job unaided: an
entity named `and` prints as `` `and` ``, because a bare `and` lexes as `&&`
and would not re-parse, while `` `foobar` `` prints bare because `foobar`
does. One predicate answers both.

Rust's raw identifiers, cited above as prior art for the hatch, are prior art
for this rule as well: the production is `r#` followed by an identifier or a
keyword rather than by a keyword list, and the reference is explicit that the
prefix "is not included as part of the actual
identifier" ([the Rust
reference](https://doc.rust-lang.org/reference/identifiers.html)), which is
both halves of what is proposed here, in the language that installed its hatch
most recently and for this reason.

EWG can take the restricted rule instead. It is one clause in a parser
predicate, and in the wording below one sentence of [lex.name]. What it costs
is that the escape becomes unwritable in the dialect where it
does the most good, the one before the keyword lands. Both forks implement
the unrestricted rule,
and the implementation section below says what the change cost.

One consequence is user-visible, and it is settled here. The escape is part of
the name's *spelling* and not of its identity, so a printer holding the
compilation's language options puts the backticks back: a pretty-printed
declaration comes out as `` void `new`(); ``, since `void new();` is not a
program and a printer that emitted it would have lost the source, and a
diagnostic names the entity `` `new` `` for the same reason, that text copied
out of a diagnostic should be text the reader can paste back. The AST dump
keeps the bare word where it names the declaration, which is evidence that the
name really is an ordinary identifier and the backticks are how it is written.
Since the escape keeps no record of how a name was written, an implementation
has to decide *which printing surfaces name an entity*, and put the backticks
back only there; §"Printing: which surfaces name an entity" gives what that
took in both compilers, and where GCC still prints a name bare.

The cost is bounded added context-sensitivity: tentative
declaration-versus-expression parsing must recognize escapes, and tooling
must distinguish an escape from any other use of the character. Both
implementations do.

## It is parsed, not lexed

The escape is three tokens, a backtick, an identifier and a backtick, and the
parser is what makes them one name. The obvious alternative is to have the
lexer do it, recognizing `` `word` `` as a single identifier token, which is
how several of the languages above implement their escapes. It would be
simpler in isolation, and it is rejected here, for one reason: it would
spend the whole character on this feature.

A lexer that turns `` `f` `` into an identifier token turns
`` x `f` y `` into three adjacent identifiers, and the infix operator of
P4307R0 [@P4307R0], `` x `f` y `` meaning `f(x, y)`, could then never be
written. The parser-level escape leaves that position alone. Backtick stays a
single punctuator, the escape claims it only where the grammar wants a name,
and the post-operand position, where a binary operator would go, is left
unused whatever becomes of the operator. The two readings never compete,
because the grammar never wants a name and an operator at the same point.

## One token, two positions

C++ expression grammar strictly alternates between wanting an operand and
wanting an operator. The escape lives exclusively in operand and name
positions; an infix operator spelled with the same character would live
exclusively in the post-operand position. The positions are mutually
exclusive, so one lexical token can serve both uses with no lookahead and no
ambiguity, the same strategy the language already uses to give `*`, `&`, and
`<` their multiple readings. The two forks implement both, under one flag:

```cpp
int `new`(int, int);  // declarator-id  -> escaped identifier "new"
`new`(a, b);         // primary        -> call to the function named "new"
obj.`delete`();      // after '.'      -> member named "delete"
x `f` y;             // post-operand   -> infix: f(x, y), P4307R0
x `(`new`)` y;       // escaped callee -> (`new`)(x, y), parenthesized slot
```

One seam exists, and the last line shows it. An escape *inside* the
operator's slot must be parenthesized, because the slot's closing rule takes
the first unnested backtick as its end: `` x ``new`` y `` is an empty slot
followed by stray tokens, and both compilers reject it. The rule is in the
operator's wording and needs nothing from this paper; it is noted here so
that a reader of either paper finds it.

There might seem to be a second, independent signal: that an escape wraps a
keyword, which is never a valid callee expression, and a slot wraps an
expression, which is never a bare keyword. Since the escape wraps any
identifier, that signal does not exist, and the design does not rest on it.
Read as an escape and read as a slot, `` `f` `` names the same thing, `f`;
the two readings differ only over whether `f` is an operand or a callee, and
that is precisely what the position states. Position alone suffices, as it
does for `*`, `&`, and `<`.

## One spelling, and the token is free

Backtick is the sole proposed spelling, and it is free: it has no meaning in
C++ source today outside string literals, character literals, and raw-string
delimiters, all of which are handled in translation phase 3 before
punctuator recognition, and are therefore unaffected. A stray backtick in
program text is ill-formed in every current compiler (`` stray '`' in program
``, in GCC's words). Only three printable ASCII characters are unclaimed at
all: the backtick, the dollar sign, and the commercial at. And the other two
are compromised: the dollar is an identifier character under the default-on
`-fdollars-in-identifiers` in both GCC and Clang, which rules it out as an
escape delimiter outright, and `@` is the Objective-C sigil in a lexer Clang
shares between the languages. A prefix form in the style of Rust's `r#`
needs a character to spend just the same, and a prefix that the lexer
recognizes is the lexer-level escape the previous sections reject. Backtick
is the entire remaining inventory, and it is also the character most of the
prior art chose. P4307R0's appendix carries the wider analysis of
alternative spellings for the operator; none of it bears differently on the
escape.

# Fitting the grammar

The keyword escape is a new *identifier* alternative in name positions:

```bnf
escaped-identifier:
    ` identifier `
```

yielding an identifier token whose spelling is the word between the backticks.
The *identifier* in that production is the lexical one, the production in
[lex.name], which every keyword matches; [lex.key] is what makes a keyword out
of one of those matches, and inside an escape it does not apply. So the escape
admits any word spelled as an identifier, and what it yields is an ordinary
identifier. It may appear wherever the grammar uses *identifier* as a
terminal, and nowhere else: a
*declarator-id*, a *class-head-name*, an *enum-name*, an enumerator, a
*namespace-name*, a template parameter's name, a *mem-initializer*, a label,
a *primary-expression*, an *id-expression* after `.`, `->` or `::`.

Because the escape yields an ordinary identifier, nothing downstream of the
parser changes: no new lookup rules, no mangling scheme, no ABI surface.
`` void `new`(); `` links as a function named `new`.

# Implementation experience

The escape is implemented, gated behind an opt-in `-fbacktick` flag, in two
independent compilers, with tests, and each compiler's full regression gate
stays green with the flag off and on. The same forks implement P4307R0's
infix operator under the same flag. This section is what building the escape
changed in the design and what building it got wrong.

**What the implementation changed.** Two things in this paper are there
because the compilers demanded them.

- *The escape reaches every position the grammar writes an identifier in,
  except a module name.* The first prototypes took it wherever their parsers happened to route the
  token and refused it everywhere else. The position list in the wording is
  what four sweeps of one program per position found. The sweep, with a
  fifth group that varies the word instead, is ninety-eight programs, published
  as [`probes/escape-positions.sh`](https://github.com/steve-downey/backtick/blob/main/probes/escape-positions.sh).
- *The escape is spelling and not identity, and printers put it back.* A
  pretty-printed declaration and a diagnostic name the entity `` `new` ``; the
  AST dump keeps the bare word. Each compiler had to decide which of its
  printing surfaces name an entity, and each got the line wrong once.

**What went wrong.** Three defects, all found after the prototypes were
finished, none of them a design question, and all fixed:

1. *Coverage.* Four sweeps found four sets of gaps: declaration positions,
   use positions, qualified names, and keywords that are also type names (GCC
   rejected `` int `int` = 0; `` for two months).
2. *Printing.* Each new escape position printed the bare keyword until it was
   routed through the routine that restores the backticks.
3. *A parser loop.* Clang's implicit-`int` recovery re-entered on an
   unresolvable qualified escape and consumed nothing. A coverage sweep can
   not find that; running the error cases under a timeout did.

**Still open.** Module names. Neither compiler accepts
`` export module acme.`class`.util; `` or `` import `std`; ``, and the
wording as written does not require them to. Module and import declarations
are recognized during preprocessing, before the escape exists, and only when
`module` or `import` is followed by one of a short list of tokens; a backtick
is not on it. That matters more here than anywhere else. A module name is a
dotted sequence of identifiers, a keyword cannot be one of them, and a module
whose name contains a word the committee later takes breaks every importer.
Closing the gap needs a backtick added to that list and the escape admitted
in each component of a module name, in [cpp.module]{.sref} and
[cpp.import]{.sref}, and a matching change in both compilers. It has one
consequence for the infix operator of P4307R0: a line beginning
`` module `f` y; `` becomes a module directive. C++20 made the same trade for
`module x;`, it breaks no existing code, and the workaround is the escape
itself, `` `module` `f` y ``. A revision of this paper will carry the wording.

Apart from module names, the two compilers accept and reject exactly the
same escapes. One GCC diagnostic does still print an escaped declaration name
beside a bare type name, a printing gap described under Printing.

## The forks

Both forks are public:

- **Clang**, two branches carrying the same feature diff, one on the LLVM 23
  release branch ([steve-downey/llvm-project @
  backtick-23](https://github.com/steve-downey/llvm-project/tree/backtick-23))
  and one on trunk ([@
  backtick-trunk](https://github.com/steve-downey/llvm-project/tree/backtick-trunk)):
  the backtick punctuator, the escape as a parser helper called from each
  name position, the printing policy that restores the backticks, the driver
  flag, and clang-format support. Tests live under `clang/test/` (the
  `backtick-*` files), plus `Driver/` and the Format unit tests, and the full
  `check-clang` regression gate stays green with the flag off and on.
- **GCC** ([steve-downey/gcc @
  backtick](https://github.com/steve-downey/gcc/tree/backtick)): `libcpp`
  token (replacing today's `` stray '`' in program `` diagnostic), one arm in
  the routine that reads an identifier, and the same flag. Tests live under
  `gcc/testsuite/g++.dg/backtick/`, with a module pair under
  `g++.dg/modules/` checking that an escaped name streams through a compiled
  module interface and mangles as the ordinary module-attached name it is.

## Escape coverage: four sweeps

The escape works in both compilers in every name position the wording admits,
and the wording's position list is the product of that work rather than its
source. The positions that *declare* a name: declarator-ids (variables,
functions, class members, `typedef` names, parameters, a `friend`
declaration's name, the qualified name in an out-of-class member definition),
a *class-head-name*, an *enum-name* scoped or unscoped, an enumerator, a
*namespace-name*, a type, non-type or template template parameter's name, an
*alias-declaration*'s name, an alias template's, a concept's, a
*mem-initializer*, a label, and expression positions including after `.`.
Declaring a name is only half of a hatch, so the positions that *use* one are
prototyped too: a type-specifier, a base-specifier, a nested-name-specifier, a
*template-name* being specialized, a using-directive, a type-constraint, and a
constructor's name. And a qualified name may be escaped at either end or at
both: `` N::`union` g; ``, `` using X = N::`union`; ``, `` sizeof(N::`union`)
``, `` typename T::`union` ``, `` `module`::inner::f() ``. The rest of this
subsection is how that list was reached: four sweeps, what fixing what they
found cost, the parser loop the fix shipped, and the three cross-compiler
divergences met on the way, each of which closed as a gap in one compiler.

That coverage is recent, and how it was arrived at is a fair warning about
what "implemented" means for a grammar extension. Both prototypes were
finished, and both were then found to take the escape in whichever positions
their parser happened to route through the routine the escape had been written
into, and to refuse it wherever a bare identifier token was read somewhere
else. That is why a concept's name worked and `` struct `union` { }; `` did
not, in either compiler. Nobody had drawn
the boundary; it fell out of two independent parsers, differently in each.
Neither test suite contained a negative test for any of it, so nothing was
failing and nothing would have failed.

It was found by writing one program per position and compiling them. That has
now been done four times, and it has found something on all four. The first
sweep covered the positions that *declare* a name; the second, written after
somebody noticed that a type nothing can name is no use, covered the
positions that *use* one. The third covered qualified names, and found that
Clang read the final component of a qualified name as an unqualified-id only
when it named an object or a function, so `` N::`new` `` had worked from the
first day and `` N::`union` `` had never worked at all. The fourth changed the
keyword. Every program anyone had written used `new`, `class`, `union` or
`try`, which are pure keywords; `int` is not, and GCC rejected `` int `int` =
0; `` in the first and best-tested position in the table, and had done for two
months. Seventy-nine programs now, in four groups, and the whole sweep runs in
about two seconds. It is the script linked in the summary above, and it should
have been checked in three sweeps ago.

There is a fifth thing those seventy-nine programs never vary, and it is not a
position. Every one of them escapes a keyword, because the prototypes' rule
first required one. The fifth sweep changes the word: nineteen programs that
escape an ordinary identifier, an alternative token, and a word that is a
keyword only in a later standard, in the positions the first four covered.
Before the change both compilers rejected all of them. After it, both accept
all nineteen, under `-std=c++17` and under `-std=c++20` alike, and
`` bool `requires`(int); ``, which each compiler had taken only in the dialect
where `requires` is a keyword, is now the same declaration in both.

The change was a single predicate on each side: Clang asked
`IdentifierInfo::isKeyword` in the two routines that recognise and consume an
escape, and GCC asked for a keyword token in its escape arm and in the
lookahead that steps over one. Nothing else in either parser moved, and the
reason is the identity rule itself. Neither compiler records that a name was
escaped, so neither can print one differently, and a name whose spelling is
not a keyword prints bare, which is what the rule says it should do. One
printer did need a line. GCC decided whether to escape a name in a diagnostic
by asking whether it was a keyword, and an alternative token is not one there:
cpplib turns `and` into `&&` before the parser sees it. So GCC named a
variable declared as `` `and` `` with a bare `and`, which does not re-parse.
It now asks the preprocessor's question as well, and both compilers print
`` `and` `` escaped and `` `foobar` `` bare.

What it cost to fix is small, though not the number first estimated. The
escape parse becomes a helper called from each name
position — twenty call sites in Clang, one arm plus its guards in GCC — and
then three things nobody had estimated. A parser that decides what it is looking
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
next backtracking parse resumes on. GCC has none of that work, because it does
not cache and re-annotate. More than half the work was in those three, and none of
them appears in the grammar.

The loop came from that last change. Clang's recovery for a
qualified name it cannot resolve is
to try implicit `int`; that does not apply to an escape and consumes nothing,
so `` namespace N { int x; } N::`union` g; `` re-entered the same case with
the same tokens indefinitely. The code it replaced had been avoiding that by
accident, by giving up as soon as it saw a backtick. Neither test suite
covered a malformed or unresolvable escape in a qualified position (neither
covered a qualified escape at all), and a diagnostic-matching test would not
have caught it in any case, since a test that never terminates does not fail.
What caught it was running the error cases under a timeout, which is a
different question from the one a coverage sweep asks and needs its own
harness.

Three cross-compiler divergences were found on the way, and every one of them
turned out to be a gap in one compiler, with a single cause behind however
many programs it showed up in. The first was three name positions, an
*alias-declaration*'s name, an alias template's and a concept's, which Clang
accepted and GCC rejected, because GCC read all three through a routine that
takes only a bare identifier token; the escape now reaches them in GCC too.
The other two ran in opposite directions. GCC rejected an
escape whose keyword is a *type* keyword, because `int` and `char` and their
siblings are bound at global scope to the builtin type in GCC's name table, so
the name the escape yields was already taken. That looks like a representation
the design would have to pick a side on. However, in C++ a declaration can be
named by a keyword only if it was escaped, since `int` is a keyword token
everywhere else and the declarator check rejects a bare reserved word; a
collision with that binding is therefore never a redeclaration, and the fix is
to say so, at the three places GCC consults it. `` int `int` = 0; `` compiles,
`int` still names the builtin in the same translation unit, and `` g(int,
`int`) `` mangles as `_Z1gi3int` in both compilers: the ABI claim above,
demonstrated on the hardest name the feature has.

The third ran the opposite way, with GCC briefly the wider
implementation: it took `` N::`union` ``
where Clang did not. One arm in the routine that reads an identifier reaches
every name position GCC has, a qualified type among them. Clang reads a
qualified type name somewhere else entirely, and in three somewhere-elses: the
declaration-specifier path, the *typename-specifier* path, and the tentative
parse that decides whether a statement is a declaration at all. Twelve
programs, four arms, and then a fifth to put back a constructor definition the
first four had broken: `` `union`::`union`() { } `` had been working by
accident, on the strength of the old code giving up early. No design question
anywhere in it.

## Printing: which surfaces name an entity

Both compilers restore the backticks wherever an entity is *named*, in a
pretty-printed declaration and in a diagnostic, and keep the bare word in the
AST dump; the design section argues why.

The escape yields the ordinary interned identifier and keeps no record of how
it was written, so neither compiler can ask a name whether it was escaped.
Each has to decide instead which printing surfaces name an entity, and put the
backticks back only there. Clang draws that line by the kind of argument a
diagnostic was given, across six sites. GCC draws it in the one routine that
prints the name of a declaration, plus a guard on the parser's own error
printer, which hands a raw keyword token to that routine as though it were a
name. Both got the line wrong once before getting it right, and the symptom
was the same both times: a program containing no backtick at all had its
diagnostics change under the flag. Every new name position the sweeps opened
was a new printing surface as well, and each printed the bare keyword, which
is source that does not re-parse, until it was routed through the one routine
that puts the backticks back.

One gap is left in a diagnostic, and it is GCC's. GCC's routine is *the name of a
declaration*. A class or enum **type** is printed somewhere else, so a program
that declares `` struct `union` { }; `` and then misuses it is told that
*'struct union' has no member named '`new`'*: one sentence, two names, one of
them escaped and the other not, because the two halves arrive from two
printers. Clang escapes both. No program is accepted or rejected differently;
what fails is the thing the decision exists to deliver, which is that text
copied out of a diagnostic can be pasted back. Clang has the mirror image of
the split in its AST dump, which shows a declaration's name bare and the same
name inside a *type* escaped. Neither split is visible to a program. Deciding
which surfaces name an entity is the whole of the escape's printing work, and
a compiler can get it right in one place and wrong in another without anything
failing.

# The design, in one place

Everything argued above reduces to the following, and the wording that
follows says no more than this. Every item is decided, and every item is
implemented in both compilers, except the module-name gap noted below.

- `` `kw` ``, wherever the grammar uses *identifier* as a terminal, is an
  ordinary identifier spelled `kw`. Lookup, overload resolution, mangling,
  linkage and ABI are untouched; `` void `new`(); `` links as a function
  named `new`.
- Any word spelled as an identifier may be escaped, not only a keyword:
  `` `foobar` `` is `foobar`, and every other identifier rule applies to the
  result unchanged.
- The escape is spelling and not identity. A printer that names the entity
  restores the backticks; the AST dump keeps the bare word.
- The positions are enumerated in the grammar section and swept in both
  compilers: every declaring position, every using position, and either or
  both ends of a qualified name. Module names are not yet reached; the
  implementation section says what that needs.
- The escape is parsed, not lexed. Backtick stays one punctuator, and the
  escape claims it only in name and operand positions, which leaves the
  post-operand position to P4307R0's infix operator, whether or not that is
  adopted.
- Gated behind an opt-in flag for the proposal period. Flag off, every
  existing program is untouched, byte for byte.

**Separately pollable.** One question: whether the escape is restricted to
words that are keywords, so that `` `foo` `` is ill-formed rather than a
second spelling of `foo`. The proposal is the unrestricted rule, for the
reason §"The escape yields an ordinary identifier" gives — a restricted escape cannot be written until the
standard that takes the word has shipped, so it can repair a break and can
never prevent one. Both implementations support either answer, so EWG can
still poll it.

# Wording

The following wording is pro forma. It is intended to make the grammar change
concrete; it is not offered as final CWG wording. Wording is relative to the
current working draft.

*Drafting note, for whichever of this paper and P4307R0's infix operator is
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

## [lex.name]

Add to [lex.name]{.sref}, after the paragraphs defining *identifier*:

::: add
> ```
> escaped-identifier:
>     ` identifier `
> ```
>
> [x]{.pnum} An *escaped-identifier* may appear wherever the grammar uses
> *identifier*. The token between the `` ` `` tokens is treated as an
> *identifier* even if it would otherwise be a keyword or alternative token.
> The `` ` `` tokens are not part of the identifier. An
> *escaped-identifier* and an unescaped *identifier* with the same spelling
> are the same identifier.
>
> [x+1]{.pnum} [Example:
> ```cpp
> void `new`();          // declares a function named new
> `new`();               // and calls it
> int `count` = 0;
> ++count;               // names the same object
> ```
> — end example]
:::

Annex A ([gram]{.sref}) is updated mechanically to match.
