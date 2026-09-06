# Infix Backtick Operator — Design, Implementation Plan & Decisions Log

Working document for a WG21 proposal. Tracks the syntax/semantics, the
Clang / clang-format / GCC implementation plans, and a running log of
design decisions and their rationale (the part EWG/CWG will scrutinise).

---

## 1. Proposal in one line

`x `op` y` is sugar for `op(x, y)` (equivalently `(op)(x, y)`), where the
text between the backticks is an arbitrary call-eligible expression. The
value and semantics are exactly those of the corresponding call.

Examples:

```cpp
a `plus` b              // plus(a, b)
a `std::min` b          // std::min(a, b)
m `at` k                // at(m, k)
a `f` b `g` c           // g(f(a, b), c)        // left-associative
```

---

## 2. Settled semantics

- **Associativity:** left. `a `f` b `g` c` == `g(f(a,b), c)`.
- **Precedence:** highest-precedence *binary* operator — tighter than `*`,
  looser than unary/prefix. Both operands are cast-expressions, so prefix
  operators attach symmetrically: `-x `f` -y` == `f(-x, -y)`.
- **Operator slot (between backticks):** an arbitrary expression, parsed
  as an *assignment-expression* (no top-level comma). Nested backticks in
  the operator slot must be parenthesised (see [nesting-vs-chaining](#nesting-vs-chaining)).
- **Desugaring:** a plain call expression, built in Sema/the front end so
  overload resolution, ADL, templates, SFINAE, constexpr, and codegen are
  all inherited rather than reimplemented.

---

## 3. Decisions log

Backtick is available because it has no current meaning in C++ source
outside string/character literals and raw-string delimiters, all of which
are lexed before the punctuator stage and are therefore unaffected.

Each decision is headed by its **slug** and is therefore a Markdown anchor;
every cross-reference links to it. `Formerly:` carries the serial number the
entry used to have, because the completed tracks' handoffs still say it and
are not rewritten. [`ops/SLUGS.md`](../ops/SLUGS.md) is the whole map.

### chaining-associativity

**Formerly:** `D1`.

**Question.** How does a chain — ``x `f` y `g` z`` — group?

**Status.** **Resolved**

**Decision.** Left-associative

**Why.** `(x `op` y) `op` z`; matches reading order; fewest surprises for chaining.

**Decided by.** The design author.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

### precedence-level

**Formerly:** `D2`.

**Question.** Where does the infix backtick sit in the precedence table, and how does it bind against unary prefix?

**Status.** **Resolved — Option A (§4)**

**Decision.** **Option A (§4)** — the highest-precedence *binary* operator: tighter than `*`, looser than unary prefix; operands are cast-expressions.

**Why.** Highest-precedence *binary* operator (looser than unary). `-x `f` -y` -> `f(-x, -y)` is symmetric, consistent with every other binary operator, and the most teachable; an implementor concurred. The rejected alternative (tighter than unary) made backtick the only operator floating a leading prefix out of its operand.

**Decided by.** The design author.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

**Log.** 2026-09-06 — [fold-over-user-infix](open-decisions.md#fold-over-user-infix) answered (a) by the design author, and it lands here as well as on the Unicode side because **the answer is one answer for both features**: they share this precedence level, so `` (... `f` N) `` and `(... ⊞ N)` are both ill-formed in v1, deliberately. The backtick paper owes one sentence saying so. Backtick has the harder version of the reopening cost, worth recording while it is known: `CXXFoldExpr` has three fixed sub-expression slots (`Callee`, `LHS`, `RHS`) and stores its operator as a `BinaryOperatorKind`, so admitting a *slot* — an arbitrary expression — would need a fourth slot, not merely a widened enum.

### nesting-vs-chaining

**Formerly:** `D3`.

**Question.** What does a backtick inside a backtick slot mean, and can the bare form be diagnosed?

**Status.** **Resolved — reframed (§17.1)**

**Decision.** Nesting requires parentheses; the bare form is a chain

**Why.** The slot's open/close are the same token, so the first interior backtick closes it: the slot can never hold a bare backtick, and "bare nesting" is *token-identical* to a [chaining-associativity](#chaining-associativity) left-assoc chain (`x `f `g` h` y` == `h(f(x,g),y)`). It therefore cannot be diagnosed without contradicting [chaining-associativity](#chaining-associativity). To nest, parenthesize — `x `(f `g` h)` y` == `(g(f,h))(x,y)`; without parens you get a chain — ordinary operator grouping, the same answer-changing-but-undiagnosed regroup as non-associative binary minus (`a-b-c` ≠ `a-(b-c)`). The original "produces a parse error" wording was impossible; this reclassifies [bare-nesting-detection](../ops/DEVIATIONS.md#bare-nesting-detection) / [gcc-bare-nesting-detection](../ops/gcc/DEVIATIONS.md#gcc-bare-nesting-detection) from deferred-enforcement to no-enforcement-needed.

**Decided by.** The design author.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

### slot-grammar

**Formerly:** `D4`.

**Question.** Which grammar production is the operator slot?

**Status.** **Resolved**

**Decision.** Operator slot = assignment-expression

**Why.** Excludes a top-level comma operator in the operator slot; operands and the operator slot all read as call arguments would.

**Decided by.** The design author.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

### feature-gating

**Formerly:** `D5`.

**Question.** Is the feature on by default, or behind a flag?

**Status.** **Resolved**

**Decision.** Gated behind a language flag

**Why.** Non-standard during proposal; keeps existing valid programs unchanged and makes the feature opt-in. (A standardized form drops the gate; the flag is the prototype vehicle.)

**Decided by.** The design author.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

**Log.** 2026-09-06 — the gate is **C++-only in the option table as well as in the grammar**, and it was not. `-fbacktick` carried no `ShouldParseIf<cplusplus.KeyPath>`, so it changed C *tokenization* — and the effect was not a lost diagnostic but an acceptance: `` int f(int a,int b){ return a `g` b; } `` compiled as C with the flag on exited 0 ([c-mode-tokenization](../ops/BACKLOG.md#c-mode-tokenization)). Fixed on both Clang branches by [clang-paper-truth](../ops/completion/steps/clang-paper-truth.md) and pinned by `clang/test/Lexer/backtick-c-mode.c`, whose assertion is the *rejection*: the flag-on and flag-off compilations must produce byte-identical output and both must fail. A test that checked only the diagnostic text would have passed with the bug present. The Unicode branch already carried the paired guard for both flags ([flag-language-mode](../ops/unicode-operators/clang/DEVIATIONS.md#flag-language-mode)); this is the backtick half of it.

### desugaring-target

**Formerly:** `D6`.

**Question.** What does ``x `f` y`` desugar to, and in which layer?

**Status.** **Resolved**

**Decision.** Desugar to a call expression for the MVP

**Why.** Inherits overload resolution / ADL / templates / constexpr / codegen with no new node. Enough for a working, testable compiler.

**Decided by.** The design author.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

### source-fidelity-node

**Formerly:** `D7`.

**Question.** Does the AST record that backtick syntax was written, and when is that node built?

**Status.** **Resolved**

**Decision.** Source-fidelity AST wrapper deferred to phase 2

**Why.** A thin transparent node (delegating type / value category / constexpr / codegen / instantiation to the wrapped call) is purely additive and lands after the MVP, once people are kicking the tires. Enables `-ast-print` to round-trip backtick syntax. Does not affect clang-format (token-based) or the GCC front end.

**Decided by.** The design author.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

**Log.** 2026-09-06 — the node's source range is now the *point* of it, and §17.5 says so. Triage of [inner-call-source-range](../ops/BACKLOG.md#inner-call-source-range) closed that row **WONTFIX**: the wrapper spans the written expression and the inner `CallExpr` begins at the operator, which is what Clang does for every desugaring — C++20's `CXXRewrittenBinaryOperator` spans `p < q` while the `CXXOperatorCallExpr` it wraps spans only `p <`. Two facts found while closing it, recorded because they are the ones a reader will check. First, it is *not* expensive to change: `CallExpr::setUsesMemberSyntax()` is public, clears the cached trailing `SourceLocation` and recomputes `getBeginLoc()` from argument 0, which is the wanted range. Second, it is declined anyway — that bit means "a call to an explicit-object member function written with member syntax", which these nodes are not, and it serializes into PCHs and modules for any later upstream consumer to read back. The range is right because the wrapper carries it, not because nothing cheaper was available.

**Log.** 2026-09-06 — and until this date the wrapper did **not** carry it. `BacktickInfixExpr` forwarded `getBeginLoc`/`getEndLoc` to the node it wraps, so its range was the operator slot alone — `` 1 `add` 2 `` gave `<col:16, col:19>`, beginning after the left operand and ending before the right ([backtick-source-range](../ops/BACKLOG.md#backtick-source-range)). The entry above, and §17.5 with it, described what the design intended rather than what the build did. Fixed on both Clang branches by [clang-paper-truth](../ops/completion/steps/clang-paper-truth.md), modelled on the Unicode feature's `UserOperatorExpr::getBeginLoc` so that a reader comparing the two features finds the same shape; the ranges are now pinned as literal columns rather than wildcards, so the claim cannot silently lapse again.

### format-break-policy

**Formerly:** `D8`.

**Question.** Where may clang-format break a backtick expression?

**Status.** **Resolved**

**Decision.** No break adjacent to either backtick (after the open, before the close); breaks allowed inside the operator slot but mildly disfavored by a small split-penalty bump.

**Why.** Hard-forbid breaks adjacent to the backticks (after open, before close); allow breaks inside the operator slot but mildly disfavor them with a small split-penalty bump — slightly stickier than a normal expression, not a no-break zone.

**Decided by.** The design author.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

### braced-init-operands

**Formerly:** `D9`.

**Question.** May an operand be a braced-init-list?

**Status.** **Resolved**

**Decision.** No braced-init-list operands

**Why.** Operands are cast-expressions (already implied by [precedence-level](#precedence-level)'s grammar), which excludes braced-init-lists; the slot is never a list (not callable). A brace operand `x `f` {1,2}` would mean `f(x, {1,2})` — meaningful as a call argument, *not* meaningless — but supporting it needs initializer-clause operand grammar, and a leading-brace LHS collides with block syntax. Excluded for the MVP; write the call directly. Revisitable.

**Decided by.** The design author.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

### keyword-escape-coexistence

**Formerly:** `D10`.

**Question.** Can one backtick token serve both the infix operator and a keyword escape, and what disambiguates them?

**Status.** **Resolved (mechanism); scope open (§10)**

**Decision.** Coexists with a backtick keyword-escape

**Why.** Backtick stays one punctuator (no lexer identifier synthesis); the parser disambiguates by position — operand / primary / declarator-id position is a keyword-escaped identifier, post-operand position is the infix operator. Positions are mutually exclusive (same strategy as `*`, `&`, `<`). The escape yields a normal identifier, so lookup / mangling / linkage / ABI are unchanged. Details and examples in §12.

**Decided by.** Undecided — recorded as proposed, with the alternatives in the section named under Status.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

### keyword-escape-printing

**Question.** When an entity's name is spelled with a keyword, what does a printer — and what does a diagnostic — call it?

**Status.** **Resolved**

**Decision.** The escape is part of the name's **spelling**, and every printer that is handed the compilation's `PrintingPolicy` puts it back: `-ast-print` emits `` void `new`(); ``, and a diagnostic names the entity `` `new` ``. `-ast-dump` is the one view that keeps the bare identifier `new`, because what it reports is the name's *identity*, which really is an ordinary identifier.

**Why.** The escape has to round-trip or [source-fidelity-node](#source-fidelity-node)'s round-trip claim is only half true: `void new();` is not a program, so a printer that emits it has lost the source. The site that decides this — `DeclarationName::print`'s `Identifier` arm — is the **diagnostic** path as well as the printing path, so the two answers cannot be separated without a second policy bit and a second predicate, and that split would have to be defended. It does not need defending, because there is one honest answer for both: under the flag the escape is the *only* spelling of that name, so a diagnostic that calls the entity `new` names it with a spelling no program can contain, and text copied out of the diagnostic is ill-formed. `-ast-dump` goes the other way for exactly the reason §12's ABI paragraph exists — the dump is the evidence that the name is an ordinary identifier, and that evidence is the bare word.

The switch is `PrintingPolicy::BacktickKeywordEscape`, initialised from `LangOptions::Backtick` the way `Bool`, `Restrict` and `Half` are initialised from their language facts, so a build without the flag prints byte-for-byte what it printed before. Nothing weaker is needed: a compilation without the escape cannot *have* an `Identifier` name whose spelling is a keyword.

**Decided by.** [clang-paper-truth](../ops/completion/steps/clang-paper-truth.md), whose step file required the diagnostic half to be decided deliberately rather than changed as a side effect of the round-trip fix. It is reversible: confining the escape to source-reproducing printers costs one more policy bit and an opt-in at every printer entry point, and nothing else depends on the answer. **Ratified by the author on 2026-09-06**, the reversal option having been offered and declined; see [the ratification](open-decisions.md#2026-09-06--keyword-escape-printing-ratified).

**Log.** 2026-09-06 — recorded when [keyword-escape-round-trip](../ops/BACKLOG.md#keyword-escape-round-trip) was fixed on both Clang branches. One site does the escaping (`DeclarationName::print`); five more had to be routed *to* it, because upstream reaches those names through paths that carry no policy — three declarator printers in `DeclPrinter` that hand the name to the *type* printer as a placeholder string, `StmtPrinter::VisitMemberExpr`, and the `ak_declarationname` diagnostic argument (its `ak_nameddecl` sibling already used the context's policy, which is how the two halves of the diagnostic surface were found disagreeing). One site is gated the other way, `TextNodeDumper::VisitMemberExpr`, so that `-ast-dump` is bare consistently. The costs are in [keyword-escape-printing](../ops/DEVIATIONS.md#keyword-escape-printing).

2026-09-06 — ratified by the author. The step that made the change recorded the decision itself, because the fix could not be made without taking one; the ratification settles that the diagnostic half was chosen rather than inherited from the printing half.

### alternative-spellings

**Formerly:** `D11`.

**Question.** Is backtick the sole spelling, or is an alternative or digraph offered alongside it?

**Status.** **Proposed — disfavored alternatives recorded (§13)**

**Decision.** Backtick is the sole spelling; no alternative/digraph spelling

**Why.** Markup friction (Markdown inline code) and keyboard ergonomics are real but minor: CommonMark's multi-backtick span already makes inline prose expressible and fenced blocks cover code samples (capability, not just ergonomics, is already there). A second spelling doubles teaching / clang-format / `-ast-print` / tooling surface, fragments the idiom, and swims against the trigraph-removed (C++17) / digraph-vestigial trend. If EWG ever forces one, an asymmetric self-delimiting pair (`\< … \>`) is the front-runner because it would *also* retire §5 and [nesting-vs-chaining](#nesting-vs-chaining) — but that is a different operator, not a backtick alias. Full analysis and rebuttals in §13.

**Decided by.** Undecided — recorded as proposed, with the alternatives in the section named under Status.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

### pipeline-operator-relation

**Formerly:** `D12`.

**Question.** How does this relate to P2011's `|>` — competitor or complement?

**Status.** **Resolved**

**Decision.** Orthogonal to P2011 `|>` (pipeline-rewrite, "pizza"); does not replace it

**Why.** Both bottom out in a call and the 2-arg case overlaps, but backtick is *symmetric binary infix* desugaring to an ordinary overload-resolved call, while `|>` is a *non-overloadable syntactic rewrite* prepending the left operand to an arbitrary-arity call. Different shape, arity, precedence, mechanism, and idiom; they compose rather than compete. Backtick also deliberately declines the `|>` spelling (§13.3 / §14.3) so both can coexist in one program. Full analysis in §15.

**Decided by.** The design author.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

### library-scope

**Formerly:** `D13`.

**Question.** Does the proposal carry standard-library additions?

**Status.** **Resolved**

**Decision.** Scope: pure core-language proposal; no standard-library additions

**Why.** Standardizing pipeline/composition helpers (`pipe`, `then`, `mbind`, …) would route the paper through LEWG as well as EWG/CWG — two tracks, the time-and-motion cost of [alternative-spellings](#alternative-spellings) rebuttal 7 doubled. The operator needs no library to function; the §16 helpers are each a few lines of ordinary user code. Keep this paper language-only (EWG/CWG), target C++29, and defer any standard helpers to a companion library paper once usage experience shows which earn it. §16 carries them as *motivation*, not proposal.

**Decided by.** The design author.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

### paper-bundling

**Formerly:** `D14`.

**Question.** Do the infix operator and the keyword escape travel in one paper or two?

**Status.** **Resolved**

**Decision.** Both backtick usages (infix operator + keyword-escape) proposed jointly, in one paper

**Why.** Same lexical token ([keyword-escape-coexistence](#keyword-escape-coexistence)), same committee (EWG/CWG). Joint proposal *conserves EWG attention* — one "what does backtick mean" discussion, not two — and prevents the two uses being designed into *contradiction* if pursued independently (punctuator vs. lexer-synthesized identifier; divergent disambiguation). Consistent with [library-scope](#library-scope), not contrary to it: the rule is **bundle what shares a design surface within one committee; split what is separable across committees** — so the two language uses bundle, the library layer ([library-scope](#library-scope)) splits off to LEWG. Resolves the §10 scope question.

**Decided by.** The design author.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

### evaluation-order

**Formerly:** `D15`.

**Question.** In what order are the operands and the slot evaluated?

**Status.** **Resolved (§17.2)**

**Decision.** Evaluation order is the call's; operand order unspecified

**Why.** `x `f` y` is defined as `f(x, y)` and adds *no* evaluation-order rule: operand order is **unspecified** (the same [expr.call] situation that defeated past LTR/RTL proposals), and since C++17 the callee/slot is sequenced *before* both operands. Source order `(x, slot, y)` is therefore not the evaluation order `(slot, then {x, y})`. Falls out of "it is just the call."

**Decided by.** The design author.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

### type-name-slot

**Formerly:** `D16`.

**Question.** What does a type-name in the operator slot mean?

**Status.** **Resolved (§17.3)**

**Decision.** A type-name in the slot yields construction

**Why.** The slot is any callable expression and a type-name is callable, so `x `T` y` == `T(x, y)` (functional-style construction; CTAD applies). Always an *expression* (slot is an assignment-expression, [slot-grammar](#slot-grammar); result is an expression by construction), so no most-vexing-parse declaration reading can arise, and no collision with the §12 escape (different grammatical position). Blessed as a consequence, not a special rule.

**Decided by.** The design author.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.


---

## 4. Precedence ([precedence-level](#precedence-level) — resolved: Option A)

Both options were left-associative and desugared to the same call; they
differed only in how a **prefix operator on an operand** binds. Option A
is adopted; Option B is recorded as the considered-and-rejected
alternative for the paper's design-rationale section.

### Option A — highest-precedence *binary* operator (ADOPTED)

Binds tighter than `*`, looser than unary/prefix. Operands are
cast-expressions, so both accept unary operands naturally.

```
backtick-expression:
    cast-expression
    backtick-expression ` operator-expression ` cast-expression

operator-expression:
    assignment-expression       // nested backticks parenthesised (nesting-vs-chaining)
```

Behaviour:

```cpp
-x `f` y     ->  f(-x, y)
-a `f` -b    ->  f(-a, -b)      // symmetric; matches every other binary op
a * b `f` c  ->  a * f(b, c)
```

Implementation: slots straight into `ParseRHSOfBinaryExpression`,
mirroring the ternary branch (the closest existing analog of a
delimited-middle operator). New top level in `prec::Level`.

### Option B — tighter than unary prefix (REJECTED)

```
unary-expression:
    backtick-expression
    unary-operator cast-expression
    ...

backtick-expression:
    postfix-expression
    backtick-expression ` operator-expression ` <unary-expression, backtick suppressed>
```

Behaviour:

```cpp
-x `f` y     ->  -f(x, y)       // the motivating case
-a `f` -b    ->  -f(a, -b)      // ASYMMETRIC: left '-' floats out, right '-' stays in
```

Implementation: hook `ParsePostfixExpressionSuffix` (must bind tighter
than the unary handling in `ParseCastExpression`); suppress the backtick
terminator flag while parsing the RHS operand so the RHS can still be
`-b`/`*p` while staying left-associative.

### Resolution

Option A adopted. Option B satisfied the "highest precedence" intuition in
isolation but made backtick the only operator where a leading prefix
operator floats out of its operand — `-a `f` -b` -> `-f(a, -b)` — which is
itself a surprise and harder to teach. Symmetry with every other binary
operator won out. The sole consequence of A is that `-x `f` y` is
`f(-x, y)`, which is the consistent reading anyway.

---

## 5. The same-delimiter parsing problem (applies to both compilers)

The open and close delimiter are the same token, so the operator slot's
expression parser would otherwise treat the closing backtick as the start
of *another* backtick operator. Resolve exactly as Clang/GCC already do
for `>` inside template-argument lists:

- **Clang:** model on `Parser::GreaterThanIsOperator` /
  `GreaterThanIsOperatorScope` and the `GreaterThanIsOperator` parameter
  of `getBinOpPrecedence`. Add a `BacktickIsOperator` flag: false while
  parsing the operator slot, restored to true inside nested parens/brackets
  so [nesting-vs-chaining](#nesting-vs-chaining)'s parenthesised nesting works.
- **GCC:** model on `parser->greater_than_is_operator_p`; add
  `backtick_is_operator_p`.

---

## 6. Clang implementation plan

1. **Lexer.** Add `PUNCTUATOR(backtick, "`")` to
   `clang/include/clang/Basic/TokenKinds.def`; add `case '`':` in the
   punctuator switch in `Lexer::LexTokenInternal`
   (`clang/lib/Lex/Lexer.cpp`). Only mint the token when [feature-gating](#feature-gating)'s flag is on.
2. **Precedence / level.** New top level in `prec::Level`
   (`OperatorPrecedence.h`); thread the `BacktickIsOperator` flag through
   `getBinOpPrecedence`.
3. **Parser** (`clang/lib/Parse/ParseExpr.cpp`). New `tok::backtick`
   branch in `ParseRHSOfBinaryExpression`, modeled on the `tok::question`
   ternary branch (the closest existing delimited-middle operator): on a
   sufficiently-high precedence backtick, consume open ``` ` ```; suppress
   the `BacktickIsOperator` flag; `ParseExpression` (assignment-expression)
   for the operator slot; expect close ``` ` ```; parse the RHS operand via
   `ParseCastExpression`; continue the left-associative loop.
4. **Sema** (`clang/lib/Sema/SemaExpr.cpp`). Small entry point forwarding
   to `BuildCallExpr` with callee = operator slot, args = {LHS, RHS}. The two
   backtick token locations need no dedicated fields — pass them as the call's
   open/close paren locations (the inner `CallExpr`'s LParen/RParen), which
   lets the phase-2 wrapper's pretty-printer reconstruct the syntax from
   structure (LHS, callee, RHS) rather than from stored locations
   ([backtick-source-locations](../ops/DEVIATIONS.md#backtick-source-locations)).
   They are **not** enough for the wrapper's own source range: the desugared
   call begins at its synthesized callee, so the wrapper computes its range
   from the operands it recovers from the semantic form (§17.5). Dedicated
   backtick-location storage is needed only if a diagnostic must point at an
   individual backtick token.
5. **Gating** ([feature-gating](#feature-gating)). A `LANGOPT` in `LangOptions.def` — use the current 5-arg
   form `LANGOPT(Name, Bits, Default, Compatibility, Description)`, e.g.
   `LANGOPT(Backtick, 1, 0, NotCompatible, "backtick operator")`; the old
   4-arg form no longer compiles ([langopt-macro-arity](../ops/DEVIATIONS.md#langopt-macro-arity)). The driver/`-cc1` flag lives in
   `clang/include/clang/Options/Options.td` — the file moved there from
   `.../Driver/Options.td` ([options-td-path](../ops/DEVIATIONS.md#options-td-path)). Add marshalling in `CompilerInvocation.cpp`, but
   note marshalling alone does **not** forward the flag into the `-cc1` argv:
   `Clang.cpp::ConstructJob()` needs an explicit
   `Args.addLastArg(CmdArgs, OPT_fbacktick, OPT_fno_backtick)` (as
   `-fsized-deallocation` / `-freflection` do) for driver-level visibility
   ([driver-flag-forwarding](../ops/DEVIATIONS.md#driver-flag-forwarding)). The
   option itself takes `ShouldParseIf<cplusplus.KeyPath>`, because the grammar
   it enables is C++-only: without the guard `-fbacktick` still changed C
   *tokenization*, and a C compilation with the flag on **accepted** the infix
   grammar ([feature-gating](#feature-gating)'s 2026-09-06 log entry).
6. **Diagnostics.** Empty operator slot (` `` `), unterminated backtick,
   [nesting-vs-chaining](#nesting-vs-chaining) ambiguity (bare nested backtick). Callee/arity/constexpr errors fall
   out of `BuildCallExpr`.
7. **Tests.** Lexer token kind; parser `-ast-dump` (shows the desugared
   call); precedence/associativity mixing with `*`, unary, `.`, `?:`; Sema
   (overloads, ADL, dependent operands); constexpr; CodeGen IR; a couple of
   preprocessor tests since backtick is now a real token in macro bodies.

---

## 7. clang-format plan

**Key conflict:** clang-format already lexes backtick for JavaScript
template literals. It reuses Clang's real lexer, so `tok::backtick` flows
in automatically once §6.1 lands — but the C++ handling must be guarded by
`Style.Language` / `LangOpts` so it never perturbs JS/TS template-string
logic, and the JS path must not misfire on C++.

Work items (`clang/lib/Format/`):

- **TokenAnnotator.cpp:** new `TT_` roles for the open/close backtick;
  recognise the matched pair in `annotate()`; set spacing in
  `spaceRequiredBefore` / `spaceRequiredBetween` (proposed canonical style:
  spaces outside the pair, hug the operator inside — `x `f` y`).
- **Break policy ([format-break-policy](#format-break-policy)):** hard-forbid a break after the open backtick and
  before the close backtick via `CanBreakBefore = false` in
  `canBreakBefore`. Inside the operator slot, breaks are allowed but mildly
  disfavored — a small additive bump to `SplitPenalty` on slot-interior
  tokens, so a long slot (e.g. a qualified name) is treated as an ordinary
  expression the formatter slightly prefers to keep intact, not a no-break
  zone.
- **Optional style option** (e.g. spacing-in-backtick-operators) — defer
  unless reviewers ask.
- **Tests** in `unittests/Format/`.

---

## 8. GCC implementation plan

Structurally parallel to Clang; decisions in §4–§6 port directly.

1. **libcpp tokeniser.** Add `CPP_BACKTICK` to the token-type list in
   `libcpp/include/cpplib.h`; add a case in `_cpp_lex_direct`
   (`libcpp/lex.cc`) replacing today's "stray '`' in program" diagnostic.
   Gate on the flag.
2. **C++ parser** (`gcc/cp/parser.cc`). Extend the precedence table used
   by `cp_parser_binary_expression` with a new highest binary level. Use
   `backtick_is_operator_p` (modeled on `greater_than_is_operator_p`) for
   the operator slot.
3. **Build the call** via `finish_call_expr`, inheriting overload
   resolution, ADL, template substitution (`pt.cc`), and constexpr
   (`constexpr.cc`).
4. **Gating** in `gcc/c-family/c.opt` plus the C++ lang hooks.
5. **Tests** in `gcc/testsuite/g++.dg/`.

GCC is the harder codebase (sparser docs, more idiosyncratic), but the
mapping above is 1:1 with the Clang plan, so settle the Clang design first
and port.

---

## 9. For the paper (Brazil)

- **Implementation experience** section carrying both Clang and GCC status
  — two independent implementations is strong evidence of implementability
  for EWG/CWG. A desugar-only Clang MVP (phase 1, §11) is sufficient on its
  own; the AST wrapper and a Compiler Explorer deployment strengthen the
  story but are not blocking for Brazil.
- Document **[precedence-level](#precedence-level)'s resolution** and the rejected alternative (the
  `-a `f` -b` asymmetry) in §4 as design rationale — show EWG the choice was
  deliberate.
- Document **[nesting-vs-chaining](#nesting-vs-chaining)** (parenthesised nesting) and **[slot-grammar](#slot-grammar)** (operator slot grammar)
  as deliberate restrictions with rationale.
- Carry this decisions log forward; record each EWG/CWG poll outcome
  against its decision ID.
- Carry the **anticipated-objections rebuttals** (§18) — wrapper-type
  alternative answered with P0543's own precedent — alongside §13.5's
  spelling rebuttals.
- Name the [precedence-level](#precedence-level) precedence level the **user-infix level**, not the backtick
  level, and carry a short **informative future-directions appendix**
  pointing at the Unicode operator sketch (`unicode-operators.md`, its [paper-separation](unicode-operators.md#paper-separation)):
  EWG then has its one operators-and-infix discussion with the whole
  landscape visible, banks the shared decisions (one level, left-assoc,
  desugar-to-call) once, and the follow-on paper inherits them as adopted
  precedent instead of reopening them. The appendix is informative and the
  papers' fates stay separate — Unicode-allergy must not be able to sink
  backtick.

---

## 10. Open questions

- **Scope — Resolved ([paper-bundling](#paper-bundling)): jointly, one paper.** The infix operator and the
  keyword-escape share one lexical token ([keyword-escape-coexistence](#keyword-escape-coexistence)), so they are co-designed in a
  single paper — to conserve EWG attention (one backtick discussion, not two)
  and to keep two independent designs from contradicting each other. The
  escape stays independently *motivated* (a future-keyword escape hatch; cf.
  Swift `` `class` ``, Rust `r#`) but is not independently *proposed*. Contrast
  [library-scope](#library-scope): the library layer *is* split off, because it is separable and crosses
  into LEWG — the rule is bundle-within-a-committee, split-across-committees.

---

## 11. Sequencing

- **Phase 1 — MVP (Clang).** Lexer, precedence level, parser hook, Sema
  desugar to a call ([desugaring-target](#desugaring-target)), gating flag, tests. Result: `x `op` y` compiles
  and runs identically to `op(x, y)`; `-ast-print` shows the desugared
  call. Enough for people to kick the tires and for the paper's
  implementation-experience section.
- **Phase 2 — source fidelity (Clang).** Thin transparent AST wrapper ([source-fidelity-node](#source-fidelity-node))
  so `-ast-print` round-trips backtick syntax. The wrapper's pretty-printer
  reconstructs the surface form from structure (LHS, callee, RHS); the
  backtick token locations it needs are already the inner `CallExpr`'s
  open/close paren locations, so no separate `SourceLocation` fields are
  required on the wrapper node ([backtick-source-locations](../ops/DEVIATIONS.md#backtick-source-locations)). Purely additive; lands once the MVP
  is stable.
- **Phase 3 — reach.** Compiler Explorer deployment once stable; GCC
  implementation in parallel for the second independent data point.

---

## 12. Coexistence with backtick keyword-escaped identifiers

A separate, independently-motivated use of backtick: escape a keyword so it
can name an entity — the hatch that lets a *future* keyword avoid breaking
existing code that used that word as an identifier. The two uses coexist;
this records why and how.

**Mechanism.** Backtick stays a single punctuator token ([desugaring-target](#desugaring-target)); neither use
synthesizes identifiers in the lexer. The parser disambiguates by
grammatical position, always one of two mutually-exclusive kinds:

- *Operand / primary-expression / declarator-id / after `.` `->` `::`* —
  the grammar wants a name or operand; a backtick opens a keyword-escaped
  identifier.
- *Post-operand* (`ParseRHSOfBinaryExpression`) — the grammar wants a
  binary operator; a backtick is the infix operator.

C++ expression parsing strictly alternates operand/operator, so the two
positions never coincide. Same position-based disambiguation C++ already
applies to `*`, `&`, and `<`.

```cpp
void `new`();        // declarator-id  -> escaped identifier "new"
`new`(a, b);         // primary        -> call to function "new"
obj.`delete`();      // after '.'      -> member named "delete"
x `f` y;             // post-operand   -> infix: f(x, y)
x `(`new`)` y;       // escaped callee -> new(x, y)   (uses nesting-vs-chaining parens)
```

**Reinforcement.** Inner content also differs — the escape wraps a single
keyword (not a valid callee expression), the infix slot wraps an
expression. Optionally restrict the escape to *actual keywords* for maximal
disjointness; position alone suffices without it.

**ABI.** The escape yields an ordinary identifier token whose spelling is
the keyword, so lookup, mangling, and linkage treat it as a normal
identifier — `void `new`();` links as a function named `new`. Purely
source-level; external names and ABI unchanged.

**Printing and diagnostics** ([keyword-escape-printing](#keyword-escape-printing)).
The escape is part of the name's *spelling*, not of its identity, and both
halves of that show up in tooling. `-ast-print` re-emits `` void `new`(); ``,
because `void new();` is not a program and a printer that emitted it would
have lost the source; a diagnostic names the entity `` `new` `` for the same
reason, since under the flag there is no other way to write it. `-ast-dump`
keeps showing the bare identifier `new` — which is the evidence for the ABI
paragraph above: the name really is ordinary, and the backticks are how you
say it.

**Costs.** Bounded added context-sensitivity: tentative
declaration-vs-expression parsing (`TryParseDeclarator` and friends) must
recognize escapes, and clang-format / tooling must distinguish the two
uses. The nested keyword-named-callee case reuses [nesting-vs-chaining](#nesting-vs-chaining)'s parenthesisation, so
needs no new rule.

**Prior art (escape hatch):** Swift `` `class` ``, Kotlin backtick
identifiers, F# double-backtick names, Rust `r#` raw identifiers.

---

## 13. Alternative spellings (considered, disfavored) — [alternative-spellings](#alternative-spellings)

Backtick is the proposed spelling and the strongly preferred one. This
section exists so the alternatives are *explored on the record* with the
rebuttals pre-loaded for EWG, not because any is recommended. The bar an
alternative must clear is high: it must be (a) lexically unambiguous, and
(b) worth doubling the spelling surface — and none clears (b).

### 13.1 Why anyone raises it

- **Markdown inline code.** A single backtick is Markdown's inline
  code-span delimiter, so `x `op` y` in *running prose* fights the markup.
  (Fenced blocks — the dominant case, code samples — are unaffected.)
- **Keyboard ergonomics.** Backtick is a dead-key or awkward on some
  non-US layouts (it was historically one of the ISO-646-variant
  characters, alongside `# [ ] { } | ~ ^ \`).

Both are real and both are *minor*. Critically, neither is a *capability*
gap: CommonMark lets a longer backtick run delimit a span containing
shorter runs (with one leading/trailing space stripped) [CommonMark
§ Code spans, spec.commonmark.org/0.31.2/#code-spans], so inline prose is
expressible today — just ugly:

```
`` a `plus` b ``     renders the code span:   a `plus` b
```

So any alternative spelling buys *ergonomics for the minority (inline prose)
case*, nothing more.

**Concrete evidence — the venue itself.** This is not merely a spec nicety: the
double-backtick span renders correctly in the tools where committee members
actually write inline prose. In particular **Mattermost, the WG21 chat server,
supports it** — posting `` x `f` y `` displays as `x `f` y` (author-verified) —
as does GitHub and any other CommonMark-based renderer. So in the very forum
where the operator would most often be typed in running text, the friction is
already a solved problem, which substantially weakens the motivation for an
alternative spelling at its strongest point.

### 13.2 The lexical filter

An alternative is an additional *alternative token* lexed by maximal munch
(like the existing digraphs), minted only under `-fbacktick` ([feature-gating](#feature-gating)). To be
unambiguous the two-character sequence must never appear adjacent in a valid
current program. Three traps a candidate must survive — each has bitten a
real digraph before:

1. **Maximal-munch theft of an existing operator** (the reason `<<` vs `<`
   is delicate).
2. **The `::` / `<:` neighborhood** — `a<:b` needed the `<::` carve-out
   ([lex.pptoken]/3.2) because `vector<::std::string>` broke. Any new
   `<`-prefixed token lives in this neighborhood.
3. **Universal-character-name munch.** `\uXXXX` is a UCN that can begin an
   identifier, so `a<éfoo` is valid today (`a < éfoo`). A candidate
   whose second character is `\` (e.g. `<\`) followed by `u`/`U` will munch
   the `<\` and split the UCN — a non-obvious break.

### 13.3 Candidates

| Spelling | Self-delim? | Lexically clean? | Verdict |
|----------|-------------|------------------|---------|
| `\< … \>` | yes | **yes** — `\` is never a token today; `\` first means it can't start a UCN (`\<`/`\>` ≠ `\u`), and not at EOL so no line-splice. No carve-out needed. | **Front-runner if forced.** Asymmetric → retires §5 and [nesting-vs-chaining](#nesting-vs-chaining). |
| `<| … |>` | yes | yes — `|`/`>` can't start a UCN; `<\|`-style theft N/A. One cosmetic edge: `&X::operator<|x` re-munches `operator<` (ill-formed today regardless). | **Blocked:** `|>` is P2011's pipeline-rewrite operator (Revzin); collides with a live proposal. Also reads as "pipe" (F#/OCaml/Elm). |
| `<\ … \>` | yes | **no** — `<\` munches the `<` of `a<éfoo` (UCN trap #3); needs a `<::`-style carve-out. | Inferior to `\< … \>` for no benefit; reject. |
| `(\| … \|)` (banana brackets) | yes | yes — `(|`/`|)` not valid adjacent today. | Heavy; Haskell-idiom connotation; reads worse than backtick. |
| single `\` (`x \op\ y`) | no | yes — stray `\` is ill-formed today. | Visually too light (confusable with escapes); symmetric, so keeps §5 + [nesting-vs-chaining](#nesting-vs-chaining). |
| `<: :>`, `<% %>` | — | — | **Taken** — already digraphs for `[ ] { }`. |
| `\|: … :\|` / `:\| …` | — | **no** — `\|:` munches `a\| ::b` (`| ::`, trap #2). | Reject. |
| `$ … $` | no | **no** — `$` is an identifier char under `-fdollars-in-identifiers` (on by default in Clang/GCC); `a$b` already lexes as one identifier. | Reject. |
| `@ … @` | no | clean in C++ but `@` is the Objective-C sigil (shared lexer) and reads as implementation-reserved. | Reject. |
| `??x` trigraph-style | — | — | Trigraphs removed in C++17; dead on arrival. |

### 13.4 The front-runner, if ever forced

`\< … \>` is the only alternative that is both lexically bulletproof and
asymmetric. The asymmetry is not incidental: distinct open/close tokens
would **eliminate the same-delimiter parsing problem (§5)** — no
`BacktickIsOperator` flag — and **eliminate [nesting-vs-chaining](#nesting-vs-chaining)**, since nesting becomes
unambiguous (`x \<f \<g\> h\> y` parses with no parentheses). That is a
genuinely *better-engineered* operator than the backtick.

It is therefore important to state plainly: adopting `\< … \>` would not be
a backtick *alias* — it would be choosing a *different primary spelling*.
The decision in [alternative-spellings](#alternative-spellings) is to keep backtick as the single spelling, not to ship
backtick *plus* an alias.

### 13.5 Rebuttals (pre-loaded for EWG)

Applicable to *any* alternative spelling:

1. **It's ergonomics, not capability.** Inline prose already works via
   CommonMark multi-backtick spans (§13.1); fenced blocks cover code. The
   gain is cosmetic and confined to running text.
2. **Two spellings is a permanent tax.** Teaching doubles; clang-format
   must pick and normalize a canonical; `-ast-print` must choose; grep /
   tooling / linters grow a second case — forever, for a cosmetic win.
3. **Direction of travel.** Trigraphs were *removed* in C++17 and digraphs
   are vestigial and periodically floated for removal. A *new* alternative
   token invites "and will you deprecate this one too?"
4. **It fragments the idiom.** The readability case for the operator rests
   on one recognizable form; two camps (backtick vs. digraph) undercuts it.
5. **None reads better than backtick.** Backtick is the established
   infix-quote idiom (Haskell). The alternatives carry foreign
   connotations: `<| |>`/`\< \>` say "pipe"/"escape," `(| |)` says
   "banana bracket."
6. **If the markup clash truly warranted a spelling change, it argues
   against the primary, not for a second.** We considered that and chose
   backtick-primary anyway, because fenced blocks dominate and the inline
   workaround exists. Adding an *alias* is the worst of both worlds.
7. **"Add it later if needed" is not a cheap option.** In committee time
   and motion, a follow-up alternate spelling costs almost as much process
   as deciding now — its own paper, an EWG design poll, CWG wording, and a
   ballot cycle. Deferral buys no real option value; it only splits the
   decision across two papers and risks shipping the operator first and
   bolting a second spelling on afterward (the worst sequencing). So the
   choice is made *here*, with conviction, not punted.

### 13.6 Conclusion

No alternative spelling is proposed, and the decision is taken *now* rather
than deferred — because (rebuttal 7) deferring it is nearly as much
committee work as settling it, so there is no option-value reason to leave
it open. Backtick is the sole spelling ([alternative-spellings](#alternative-spellings)). The analysis is recorded so
that, if EWG raises the Markdown/keyboard ergonomics, the answer is ready:
capability already exists, a second spelling is a standing tax against the
trend, and the only alternative worth considering (`\< … \>`) is not an
alias but a different operator we deliberately declined. If EWG nonetheless
wants to reopen the spelling, the place to do it is this paper — settling
the question against the recorded analysis — not a future one.

---

## 14. Reference: available ASCII lexical real estate

A digraph (an alias for an existing token, §13) and a brand-new operator
draw on the same pool: ASCII sequences that are *not already a token* and
*never appear adjacent in a valid current program*. This appendix inventories
that pool. It is reference material — most of it is moot for *this* proposal
(see §14.4), but it is exactly what gets asked in the room.

### 14.1 The availability rule

A two-character sequence `XY` is available iff:

1. `XY` is not a current token or digraph, **and**
2. after `X`, the character `Y` cannot begin a valid operand or continue a
   token — i.e. `Y` is not one of the unary-prefix operators
   `- + * & ~ !`, not `(`/`[`/identifier/literal start, and `XY` is not the
   prefix of a longer real token.

Clause 2 is the one that surprises people. Where `X` is a binary operator or
`<`, putting a unary-capable character after it is *already valid*:

```
a < -b      a < +b      a < *p      a < &x      a < ~b      a < !b
a * *p   (== a * (*p))  a + +b      a - -b      a & &x
```

So `<-`, `<+`, `<*`, `<&`, `<~`, `<!`, `**`, `!!`, `~~`, … are **blocked** —
adding any of them as a token silently changes the meaning of existing code
(`!!x`, the bool-cast idiom, and `a * *p` are the cautionary cases). `<|`
survives *only* because `|` is the one "bar" with no unary form. Plus the two
traps from §13.2: the `::` / `<:` neighborhood (`a | ::b`, `a<:b`) and UCN
munch (`a<éfoo`).

### 14.2 Free standalone characters

The only printable ASCII characters with no C++ token meaning at all:

| Char | Status |
|------|--------|
| `` ` `` | **Claimed by this proposal.** Otherwise free (literals/raw-string delimiters are lexed earlier). |
| `\` | Free as a token, but it *is* line-continuation (phase 2) and the UCN lead-in; usable only in combos that keep it off EOL and away from `u`/`U` (§13.2 trap 3). |
| `@` | Free in C++, but the Objective-C sigil (shared lexer) and reads as implementation-reserved. |
| `$` | An identifier character under `-fdollars-in-identifiers` (default-on in Clang/GCC): `a$b` already lexes as one identifier. Effectively unavailable. |

Every other printable ASCII char is a token or token-prefix.

### 14.3 Candidate multi-character sequences

Verdict for the sequences people actually ask about. "Available" = lexically
clean to mint under a flag; "blocked" = breaks valid code or already taken.

| Seq | Available? | Note |
|-----|-----------|------|
| `=>` | yes | `a = >b` is ill-formed today. Strong "arrow/lambda" connotation (C#, JS, Rust). **P2971 (Brown) proposes it as the implication operator** (§14.4). |
| `==>` | yes | `a == >b` ill-formed today. Arrow-like spelling for **logical implication** — though P2971 actually proposes single `=>` (§14.4). |
| `<==` | yes | Munches cleanly (`<=` then `=` is ill-formed today). Converse implication, if ever wanted. |
| `<==>` | yes | Biconditional / "iff", if ever wanted. |
| `<\|` | yes | Reverse-pipe; the only clean `<X`. |
| `\|>` | **blocked (social)** | Lexically clean, but it is P2011's pipeline-rewrite operator (Revzin). |
| `~>` | yes | `a ~> b` ill-formed today (`~` has no binary form). "leads-to" connotation. |
| `\< … \>`, `(\| … \|)` | yes | Asymmetric self-delimiting pairs — see §13.3. |
| `<-` `<+` `<*` `<&` `<~` `<!` | **blocked** | `a < -b`, `a < *p`, … already valid (14.1). |
| `**` | **blocked** | `a * *p` already valid. (So no `**` exponentiation.) |
| `!!` `~~` | **blocked** | `!!x`, `~~x` already valid (unary idioms). |
| `^^` | **blocked (taken)** | C++26 reflection operator (P2996). Was available (`a ^ ^b` ill-formed; `^` has no unary form) before P2996 claimed it — see §14.5. |
| `%%` | yes | `a % %b` ill-formed today (`%` has no unary form); doubling-a-no-unary-form operator, like `^^` before it was taken (§14.5). |
| `<=>` | **blocked (taken)** | Spaceship (landed). |
| `<\ … \>` | needs carve-out | UCN munch trap (§13.2); inferior to `\< … \>`. |
| `<: :>` `<% %>` `%:` | **blocked (taken)** | Existing digraphs. |

### 14.4 Why new operators are mostly off the table — and the one that isn't

This proposal is, in effect, a *general* infix-operator facility: any named
binary operation is `x `op` y` with no new punctuator. `x `implies` y`,
`x `pow` y`, `x `dot` y` all work today under the feature. So the standing
demand for new operator *punctuators* — which previously justified spending
scarce lexical real estate — largely evaporates. That is a point worth making
affirmatively in the paper: backtick is the reason the table above can stay
mostly unspent.

The residual cases where a *dedicated* operator still earns its keep are the
ones a desugar-to-call **cannot** express:

- **Non-strict / short-circuit evaluation.** A call evaluates all arguments.
  **Walter Brown's implication operator** (P2971R3, `operator=>`) is the
  canonical example: `p => q` ≡ `!p || q`, whose RHS is **not evaluated when
  `p` is false** (P2971 §7.3 proposes short-circuit evaluation; the paper
  also gives it low precedence, just below `||`, and right-associativity).
  `p `implies` q` desugared to `implies(p, q)` evaluates `q` unconditionally
  — observably different (side effects, cost, well-definedness) *when `q` is a
  bare expression*. **But** a helper taking the RHS as a *thunk*
  (`p `implies` [&]{ q }`) recovers the short-circuit (§16.5), and that is a
  general user-space capability the language otherwise reserves to `&&`/`||`
  (which overloading cannot restore). So the residual value of a dedicated
  `=>` is *ergonomic* — omitting the per-call thunk for the common boolean
  case — not a hard capability gap. It remains a reasonable candidate;
  P2971's `=>` is lexically available (14.3), as is the more arrow-like
  `==>`, mnemonic for `⟹` (the missing short-circuit sibling of `&&`/`||`).
- **Custom precedence/associativity** that the single backtick level (§4)
  cannot give.
- **Ultra-high-frequency** operations where `x `op` y` ceremony genuinely
  outweighs a glyph — a high bar.

Everything else: write it as a backtick call. The inventory in 14.1–14.3 is
therefore best read as *what remains technically possible*, with the
expectation that this proposal removes most of the *motivation* to spend it —
implication's lazy RHS being the notable exception.

This appendix is deliberately ASCII-only; the non-ASCII pool — Unicode
characters with syntactic (Pattern_Syntax) status that C++ has never claimed,
now with normative footing in UAX #31 R3c — is explored as a separate
follow-on sketch in `unicode-operators.md` (`x ⊞ y` ⇒ `operator⊞(x, y)`,
reusing this proposal's precedence, associativity, and desugaring decisions).

### 14.5 Prior art for this analysis

This exact "what ASCII is actually free" exercise has been run to a
conclusion in committee before, which is why the converse/biconditional rows
are kept above (14.3) even without a current proponent — the next person to
revisit operator real estate inherits the worked example rather than redoing
it. The clearest precedent is **P2996 reflection**: it began on a single `^`
and moved to the `^^` digraph (the "neko" / mountain operator) only after the
same availability analysis showed single `^` was too entangled — it is
bitwise-xor, and `^` is already the Clang/Objective-C blocks sigil. The
double form cleared the filter (`a ^ ^b` — `^` has no unary form — is
ill-formed today, so `^^` was unclaimed; cf. 14.1) and shipped. The lesson
carried into this appendix: doubling an operator with **no unary form** is
the reliable way to find clean real estate (`^^`, and likewise `%%` would be
available), whereas doubling one that *has* a unary form is blocked
(`**`, `!!`, `~~` — 14.3).

---

## 15. Relationship to the pipeline-rewrite operator (P2011, `|>`)

Barry Revzin's `|>` (the "pizza" operator, P2011) and backtick both ultimately
produce a call expression, and their degenerate 2-argument cases look alike,
so the relationship must be stated explicitly: **they are orthogonal,
complementary, and neither replaces the other.** Backtick deliberately leaves
`|>` unspelled (§13.3 / §14.3) precisely so the two can coexist in one
program.

### 15.1 What each one is

- **Backtick** — `x `f` y` desugars to `f(x, y)`. Symmetric *binary infix*
  application of a callable: the **callee sits between two operands**, and the
  result is an ordinary call, so overload resolution, ADL, templates, and
  function objects all apply ([desugaring-target](#desugaring-target)).
- **P2011 `|>`** — `x |> f(args...)` is *rewritten* to `f(x, args...)`. A
  **syntactic rewrite** that prepends the left operand as the first argument
  of the *call expression* written on the right. There is no `operator|>`; it
  is **not overloadable**, and the right-hand call may have **any arity**.

### 15.2 Side by side

| Aspect | backtick `` x `f` y `` | pipeline `x |> f(...)` |
|--------|------------------------|------------------------|
| Shape | symmetric binary infix | directional "prepend-arg" thread |
| Right-hand syntax | a single operand (a value) | a call expression with its own args |
| Operator slot | the callee, between the ticks | n/a — callee is on the right |
| Resulting call arity | exactly 2 | `1 + (RHS args)`, any N |
| Mechanism | desugar to a normal call | pure syntactic rewrite |
| Overloadable? | yes (it *is* a call) | no (by design) |
| Precedence | highest binary (tighter than `*`) | low (pipeline level) |
| Native idiom | binary *operations* — `a `min` b` | transformation *chains* — `r \|> filter(p) \|> sum()` |

### 15.3 Where they overlap — and why neither becomes redundant

The 2-argument case coincides: `a `plus` b`, `a |> plus(b)`, and `plus(a, b)`
all yield the same call, and both operators left-fold —
`a `f` b `g` c` and `a |> f(b) |> g(c)` both give `g(f(a, b), c)`. But the
overlap stops there:

- Backtick cannot express what `|>` does beyond binary. `x |> f(a, b, c)`
  threads `x` into an arbitrary-arity call; backtick's right-hand side is a
  single operand, not an argument list, so there is no backtick spelling of
  `f(x, a, b, c)`. **Beyond two operands, only `|>` threads.**
- `|>` cannot write a binary operation *symmetrically between* its operands.
  Its right-hand side is always a (partial) call and the left is always
  threaded in front, so `a `min` b` becomes `a |> min(b)` — which reads as a
  pipe *stage*, not an *operation*. **For "x op y" notation — predicates,
  arithmetic, comparisons — backtick is the spelling.**

### 15.4 Why backtick does not replace `|>`

Backtick is not a pipeline operator. It does not thread a value through a
sequence of N-ary transformations, and it has the wrong precedence (high,
binary) and the wrong shape (symmetric, single-operand RHS) for chaining.
P2011's entire purpose — UFCS-style left-to-right chaining of range adaptors
and free functions that carry extra arguments, *without* the `operator|`
machinery — is untouched by backtick.

### 15.5 Why `|>` does not replace backtick

`|>` is not an infix-operator facility. It cannot place an arbitrary binary
callable symmetrically between two operands; it always prepends the left
operand to a call on the right, and it is non-overloadable. Backtick's
purpose — infix notation for binary operations that desugars to ordinary,
overload-resolved calls — is untouched by `|>`.

### 15.6 They compose

The two are at their best together: backtick supplies infix detail *inside* a
pipeline stage, `|>` threads the value *between* stages.

```cpp
r |> filter([](auto e){ return e `mod` 2 `eq` 0; }) |> sum()
//                              \_____ eq(mod(e, 2), 0) _____/
```

Guidance for the paper: present them as complementary — backtick for "this is
a binary operation," `|>` for "thread this value through these stages" — and
explicitly disclaim that either subsumes the other. Recording it here so the
EWG question ("doesn't one of these make the other unnecessary?") has a
ready, worked answer.

---

## 16. Producing pipeline-like outcomes with backtick

Backtick is symmetric binary infix, not a pipeline operator (§15) — but its
operator slot is an *arbitrary callable expression*, and it chains
left-associatively. Those two facts let a handful of patterns — each a few
lines of *ordinary user code*, no standard-library addition — reproduce most
pipeline / `|>` / ranges-`|` outcomes with no core language change beyond
backtick itself. **The paper proposes none of these helpers**; scope is
language-only (§16.7 / [library-scope](#library-scope)). They appear here as *motivation* — showing the
operator's reach, and marking precisely where the one real gap vs. `|>` sits.

### 16.1 The threading pattern — `pipe(x, f) = f(x)`

One trivial helper turns backtick into a left-to-right value-threading
operator:

```cpp
inline constexpr auto pipe =
    [](auto&& x, auto&& f) -> decltype(auto)
    { return std::invoke(std::forward<decltype(f)>(f),
                         std::forward<decltype(x)>(x)); };

x `pipe` f `pipe` g `pipe` h     // == h(g(f(x))) — left-assoc, data-flow order
```

Each stage is a unary callable; the reading order matches `|>`.

### 16.2 It drives the existing range-adaptor closures unchanged

The decisive case. Range adaptor *closures* (`views::filter(pred)`,
`views::transform(fn)`) are **already unary callables** — `c | a` is *defined*
as `a(c)`. So `pipe` feeds them directly, with no `bind`:

```cpp
r `pipe` views::filter(pred) `pipe` views::transform(fn)
// identical result and laziness to:
r |  views::filter(pred) |  views::transform(fn)
```

Same closures, same lazy views. Backtick + one helper is a drop-in spelling of
the range pipe. The bespoke per-library `operator|` overloads exist only to
choose the `|` *syntax*; the closure objects themselves need nothing, so they
work under backtick for free.

### 16.3 Parameterized free-function stages — `bind_back`

For a plain free function that takes the piped value first plus extra
arguments, fix the trailing args with `std::bind_back` (C++23) or a lambda:

```cpp
r `pipe` std::bind_back(filter, pred) `pipe` std::bind_back(transform, fn)
// == transform(filter(r, pred), fn)
```

This is exactly the case P2011 `|>` writes more directly —
`r |> filter(pred) |> transform(fn)`, arguments inline. Backtick needs the
`bind_back`/lambda wrapper to turn the stage into a unary callable: same
result, more ceremony. **This is the one ergonomic gap vs. `|>`** (§16.6).

### 16.4 Reusable point-free pipelines — `then` (composition)

Compose stages into a named pipeline once, apply it many times:

```cpp
inline constexpr auto then =
    [](auto f, auto g)
    { return = -> decltype(auto)
        { return g(f(std::forward<decltype(a)>(a)...)); }; };

auto clean = trim `then` lower `then` dedup;   // a reusable callable
clean(s);
```

Mirrors building a reusable view/adaptor chain; left-assoc backtick gives
left-to-right composition.

### 16.5 User-defined short-circuiting (non-strict) operators

This is the strongest single argument in §16, so it leads. C++ reserves
short-circuit / non-strict evaluation to a fixed set of built-ins — `&&`,
`||`, `?:`, `,` — and you **cannot** get it back by overloading: an overloaded
`operator&&` / `operator||` evaluates both operands (the classic footgun, and
the reason the standard discourages overloading them). Backtick reopens this
for users. A helper whose right operand is a *callable* controls whether — and
when — that operand runs:

```cpp
// short-circuiting logical implication:  p ==> q  ≡  !p || q
inline constexpr auto implies =
    [](bool p, auto&& q) -> bool { return !p || q(); };

p `implies` [&]{ return expensive(); }   // q() runs only when p holds
```

The same shape gives lazy defaults (`opt `or_else` [&]{ costly(); }`), guarded
effects, and bespoke control operators — any binary operation that must *not*
evaluate its right side unconditionally. This is a *general* user-facing
capability the language otherwise denies, not a niche trick.

The **monadic chain** is simply the zero-ceremony special case: the stages are
already functions, so no thunk is written and short-circuiting falls out for
free:

```cpp
inline constexpr auto mbind =
    [](auto&& m, auto&& f)
    { return std::forward<decltype(m)>(m)
                 .and_then(std::forward<decltype(f)>(f)); };

parse(s) `mbind` validate `mbind` store;   // stops at the first empty / error
```

(If "monadic" costs more audience than it earns in EWG, lead with the
short-circuit framing above and present this as "chaining fallible steps" — the
capability is the point, not the vocabulary.)

This refines §14.4: backtick **can** express short-circuiting implication after
all — when the right operand is passed as a thunk. What a dedicated `=>`
(P2971R3) adds is only the *ergonomics* of omitting that thunk for the common
boolean case; it is not a hard capability gap. A bare-*expression* RHS still evaluates eagerly
(backtick desugars to a call), so the thunk is the price of generality.

### 16.6 What this recovers — and the one thing it doesn't

Recovered, library-only (no core change beyond backtick itself):

- left-to-right value threading (16.1–16.2),
- the **entire existing ranges adaptor-closure ecosystem**, unchanged (16.2),
- parameterized stages (16.3),
- reusable point-free composition (16.4),
- **user-defined short-circuiting / non-strict operators** (16.5) — a
  capability the language otherwise reserves to `&&` / `||` / `?:` and that
  operator overloading cannot recover; the monadic/fallible chain is its
  zero-ceremony special case.

Not recovered — the precise boundary with `|>`:

- **P2011's inline-argument stage syntax.** `x |> f(a, b, c)` writes the extra
  args in the call and threads `x` in front. Backtick stages must be *unary
  callables*, so the extra args go through `bind_back`/a lambda (16.3). Same
  outcome, more ceremony — this is exactly why backtick does not make `|>`
  redundant (§15.4).
- **Precedence direction.** Backtick binds *high* (tighter than `*`, §4),
  whereas `|>` binds *low*. Pipe-style stages are normally primaries
  (`views::filter(pred)`), so this is usually invisible; but a stage that is
  itself a low-precedence expression must be parenthesised — the opposite
  default from `|>`.

Net: for the *common* pipeline use-cases, backtick plus a one-line helper
(often just `pipe`) is sufficient and reuses the existing closure ecosystem;
the dedicated `|>` earns its keep specifically for inline-argument stages and
low-precedence chaining. Complementary, as §15 concludes.

### 16.7 Scope: motivation, not a library proposal

Every helper above is a few lines of *ordinary user code* — no standard-library
addition is required for any of it, and the paper proposes none. That is
deliberate and load-bearing for process:

- **Keeps the paper in one committee track.** A core-language operator goes
  through EWG/CWG. Bundling standard helpers would add an LEWG track — the
  time-and-motion cost ([alternative-spellings](#alternative-spellings) rebuttal 7, §13.5) doubled across two committees,
  on two schedules, with two sets of bikeshedding. This proposal is
  language-only ([library-scope](#library-scope)).
- **The library layer is optional and can mature independently.** Because the
  operator is expressive enough that `pipe` / `then` / `mbind` are
  user-writable one-liners, there is no rush: land the language feature early
  (targeting C++29), let real usage reveal which helpers are actually worth
  standardizing, and bring those in a separate companion library paper later —
  with field experience behind them rather than ahead.
- **The patterns still pull their weight here, as *motivation*.** Showing the
  reachable outcomes — especially that backtick drives the existing ranges
  adaptor-closure ecosystem unchanged (§16.2) — helps EWG members who spend
  less time on library design see *why* the operator is useful, without asking
  them to approve any library surface. Direction without commitment.

So §16 is a worked illustration of reach, explicitly out of scope for
standardization, with a companion library paper named as the future home for
anything that earns it.

### 16.8 Validation (built Clang)

Every pattern above was compiled and run against the `-fbacktick` Clang
(`clang 23.0.0git`, the `build-backtick` dev build), C++23, `-Wall -Wextra`
clean. A standalone program exercising each one passes end to end:

- **16.1** `3 `pipe` inc `pipe` dbl `pipe` neg` → −8 (left-assoc threading).
- **16.2** `v `pipe` views::filter(pred) `pipe` views::transform(fn)` yields the
  **identical** result (sum 120) to `v | views::filter(pred) | views::transform(fn)` —
  confirming backtick drives the *existing* range adaptor closures unchanged,
  same laziness.
- **16.3** `v `pipe` bind_back(filter,pred) `pipe` bind_back(map,fn)` → 60.
- **16.4** `inc `then` dbl `then` neg` applied to 3 → −8.
- **16.5** `implies` skips its RHS thunk when the antecedent is false and runs
  it when true (short-circuit confirmed); the `mbind` optional chain yields 6
  and short-circuits to empty on the failing input.

So §16 is implementation experience, not assertion. (The program lives outside
the regression suite for now; promoting a reduced form into `clang/test` is a
cheap follow-up, and a natural item for the paper's implementation-experience
section.)

---

## 17. Further semantic clarifications ([nesting-vs-chaining](#nesting-vs-chaining) reframed, [evaluation-order](#evaluation-order), [type-name-slot](#type-name-slot), ADL)

Resolutions reached after implementation, sharpening four points the original
decisions log under-specified.

### 17.1 Nesting vs. chaining — the [nesting-vs-chaining](#nesting-vs-chaining) grouping rule

The operator slot's open and close delimiters are the same token, so the first
interior backtick always closes the slot. Two consequences: the slot can never
contain a *bare* backtick, and what looks like "bare nesting" is
token-identical to an ordinary left-associative chain.

```
a ` f ` b ` g ` c     (chaining-associativity chain, blessed)   -->  g(f(a, b), c)
x ` f ` g ` h ` y     ("bare nesting")      -->  h(f(x, g), y)
```

Same shape, different names. Therefore:

- "Bare nesting" is not a distinct construct and **cannot be diagnosed** — it
  is exactly the chain [chaining-associativity](#chaining-associativity) already defines and blesses. A diagnostic would have
  to fire on legal [chaining-associativity](#chaining-associativity) chaining, a contradiction.
- The original [nesting-vs-chaining](#nesting-vs-chaining) wording ("bare nesting naturally produces a parse error") was
  not just wrong but impossible; the parser is correct to accept it, and Clang
  and GCC agree ([bare-nesting-detection](../ops/DEVIATIONS.md#bare-nesting-detection) / [gcc-bare-nesting-detection](../ops/gcc/DEVIATIONS.md#gcc-bare-nesting-detection), reclassified from "deferred enforcement" to
  "no enforcement needed").

**Rule ([nesting-vs-chaining](#nesting-vs-chaining), reframed):** to nest a backtick expression in the operator slot,
parenthesize it — `x `(f `g` h)` y` == `(g(f, h))(x, y)`. Without parentheses
you get a left-associative chain ([chaining-associativity](#chaining-associativity)). The syntax is new, but the problem class
is old and well-understood: it is the **binary-minus situation**. Subtraction
is *non-associative*, so `a - b - c` == `(a - b) - c` ≠ `a - (b - c)` — the
default left grouping silently changes the result, and the language has never
diagnosed it. Parentheses override the grouping; they do not avoid an error.
(The same `-` is also the precedent for [keyword-escape-coexistence](#keyword-escape-coexistence)'s position-based disambiguation:
`-` is unary in operand position, binary in post-operand position, exactly as
backtick is escape vs. infix.)

**The silent-surprise case, and why it is left undiagnosed.** Because the
greedy chain is always *syntactically* valid, whether it also *type-checks*
depends on the callables. Almost always the chain fails to type-check when a
user actually meant to nest, yielding a (misleading) error rather than a wrong
answer. A fully silent miscompile is possible only with a pathological type
that is simultaneously callable, value-convertible, and non-symmetric:

```cpp
struct Op {
    int v;
    Op operator()(Op a, Op b) const { return Op{a.v*2 + b.v + v}; } // non-symmetric
    operator int() const { return v; }
};
Op f{1}, g{2}, h{3}, x{10}, y{20};

int bare     = x `f `g` h` y;       // greedy chain : h(f(x,g), y)  == 69
int intended = x `(f `g` h)` y;     // nested       : (g(f,h))(x,y) == 47
```

Both compile and differ (69 vs. 47) — the very same answer-changing-on-regroup
that `a - b - c` ≠ `a - (b - c)` already exhibits for binary minus, which no
compiler diagnoses. So this is not even a new category of hazard. It falls
squarely under the **Murphy / Machiavelli rule**: the language defends against
Murphy (honest mistakes), not Machiavelli (deliberate self-sabotage). Building `Op` to be
callable *and* a value *and* asymmetric, then omitting the parentheses, is
self-inflicted; the fix is one pair of parentheses. It does not justify a
normative diagnostic — least of all one that cannot distinguish itself from
blessed [chaining-associativity](#chaining-associativity) chaining.

*Possible QoI follow-up (non-normative).* It may still be worth investigating a
*heuristic* Clang warning — e.g. when a chain's intermediate operand is itself
a callable used in operand position, suggest parentheses. That would be opt-in,
off-by-default diagnostic quality-of-implementation, never a language rule, and
must not fire on ordinary chaining. Flagged for investigation, not committed.

### 17.2 Evaluation order ([evaluation-order](#evaluation-order))

`x `f` y` is defined as the call `f(x, y)`, so it introduces **no new
evaluation-order rule** and inherits [expr.call] wholesale:

- operand evaluation order is **unspecified** (indeterminately sequenced) — the
  same long-standing situation that defeated past attempts to mandate LTR/RTL
  for call arguments;
- since C++17 the callee is sequenced *before* the arguments, so the **slot is
  evaluated before both operands**, even though it is written *between* them.
  Source order `(x, slot, y)` is therefore not the evaluation order
  `(slot, then {x, y})`.

A feature of "it is just `f(x, y)`," not a special case: anyone who knows call
semantics already knows backtick's.

### 17.3 Type-name in the operator slot ([type-name-slot](#type-name-slot))

The slot is any callable expression, and a type-name is callable, so a type in
the slot is well-formed and yields construction:

```cpp
x `T` y          // == T(x, y) : a prvalue T, functional-style construction
a `std::pair` b  // == std::pair(a, b), with CTAD
```

It is always an **expression** (the slot is parsed as an assignment-expression,
[slot-grammar](#slot-grammar); backtick's result is an expression by construction), so it can never appear
in declaration position — the most-vexing-parse declaration reading cannot
arise. The keyword-escape use of backtick (§12) occupies operand/declarator
position, not the post-operand infix position, so there is no collision.
Blessed as a consistent, useful consequence rather than a special rule.

**Implementation status: one compiler, and that is a claim the paper has to
make carefully.** Clang implements it — a bare name is looked up as a type
with a CTAD placeholder, a qualified one via a tentative scope parse, a
builtin through the functional-cast machinery, and all three route to the
`T(x, y)` build path. **GCC does not**: its slot is parsed as an expression,
so `` 1 `P` 2 `` is rejected there, and under `-fbacktick` the two compilers
accept different programs
([gcc-type-slot-parity](../ops/gcc/DEVIATIONS.md#gcc-type-slot-parity)). This
is the one place where the two implementations disagree about what is
well-formed, and it is a gap rather than a design consequence — nothing about
GCC's parser-level desugaring prevents the type arm, it simply has not been
written. Until it is, the implementation-experience section must say that
this section has **single-compiler evidence**, and say which compiler.

### 17.4 ADL is normative (cross-compiler note)

`x `f` y` performs argument-dependent lookup on the slot exactly as the call
`f(x, y)` would ([desugaring-target](#desugaring-target)). This is **normative**: backtick must not silently have
weaker lookup than the call it desugars to. It binds wherever ADL binds in a
call — that is, wherever the slot is an unqualified name, whether or not it
carries template arguments. A qualified name, a member access, or any other
expression in the slot gets no ADL for the same reason the equivalent call
gets none.

Implementation status, for the implementation-experience section: **both
compilers now deliver it, and they agree.** Clang carries the slot to
`BuildCallExpr` as an `UnresolvedLookupExpr`. GCC keeps a bare unqualified-id
slot as an `IDENTIFIER_NODE` and a bare template-id slot as a
`TEMPLATE_ID_EXPR` over one, and runs `perform_koenig_lookup` before
`finish_call_expr`; anything else in the slot is parsed as an ordinary
expression, which is the right answer for it. Getting there took two goes —
resolving the slot name at parse time defeated pure ADL entirely
([gcc-slot-adl](../ops/gcc/DEVIATIONS.md#gcc-slot-adl)), and the fix for that
detected only a bare name, so a template-id slot silently kept the old
behaviour ([gcc-template-id-slot-adl](../ops/gcc/DEVIATIONS.md#gcc-template-id-slot-adl)).
Both are the same lesson for anyone implementing this: the slot has to reach
the call builder unresolved, and "the slot" means every unqualified form of
it, not the easiest one to spot with a two-token peek.

### 17.5 Source ranges of the desugared node ([source-fidelity-node](#source-fidelity-node))

A question an implementer will ask, answered here so the paper need not be
asked it: **the wrapper node spans the written expression; the call it wraps
does not, and that is deliberate.** `-ast-dump` of `x `f` y` shows the
`BacktickInfixExpr` (and, for the Unicode feature, the `UserOperatorExpr`)
covering the whole expression, while the inner `CallExpr` begins at the
operator, because `CallExpr::getBeginLoc` takes its begin from the callee.

That is not a defect of this design; it is what Clang does for every
desugaring. The precedent is C++20's rewritten comparisons: for `p < q` the
`CXXRewrittenBinaryOperator` spans `p < q`, and the synthesized
`CXXOperatorCallExpr` inside it spans only `p <`. Nobody treats that as a bug,
because the semantic node is not the written form and is not what a diagnostic
or an IDE points at — the node built for source fidelity is. This is precisely
the job [source-fidelity-node](#source-fidelity-node) gave that node, and it is
the reason it exists in the AST at all rather than the desugaring being done
bare.

The corollary for anyone replaying this: a tool that wants the written extent
of a backtick expression must read the wrapper, not the call, exactly as a
tool wanting the written extent of `p < q` must read the
`CXXRewrittenBinaryOperator`.

**The wrapper does not get that range for free; it computes it, and until
2026-09-06 it did not.** `BacktickInfixExpr::getBeginLoc` and `getEndLoc`
recover the two operands *as written* from the semantic form and take their
extremes. Three shapes have to be recognised, and they are the same three the
pretty-printer already reconstructs the surface syntax from: the desugared
call (including the member form, whose object argument is the operator slot
and therefore not an operand), the construction a type slot desugars to
([type-name-slot](#type-name-slot)), and that construction's dependent form.
The operands are taken by index, not counted back from the end, because a
selected overload may have default arguments beyond them. When none of the
three matches — a builtin with custom type checking rewrites the call to a
node that keeps neither the callee nor the call shape — nothing is
recoverable and the range falls back to the semantic form's, which is the
operator slot alone; that is the honest answer, and the only requirement on
it is that asking does not crash.

Before that date the wrapper forwarded both locations to the node it wrapped,
so this section described an intention rather than a behaviour: `` 1 `add` 2 ``
reported `<col:16, col:19>` — the operator slot — rather than `<col:13,
col:21>`. The fix is modelled line for line on the Unicode feature's
`UserOperatorExpr::getBeginLoc`, whose doc comment diagnoses the identical
root cause, so a reader comparing the two features finds the same shape in
both. The ranges are now pinned in the tests as literal columns rather than
wildcards, which is what stops the claim lapsing again quietly.

---

## 18. Anticipated objections — pre-loaded rebuttals

Motivation-tier objections raised against the operator as such (not against
its shape — those live with their decision IDs, and spelling lives in §13).
Same purpose as §13.5: the answer ready before EWG asks. Carried in the
paper's "Anticipated objections" section.

### 18.1 "Define `*` on a type instead" (the wrapper-type alternative)

**The objection.** Named binary operations don't need infix spelling;
overload the operator on a type. `saturating_multiplication` doesn't need
`a `mul_sat` b` — it needs a `Saturating<double>` whose `operator*`
saturates.

**Rebuttals:**

1. **The lift is mandatory, not a lighter alternative.** Overloaded
   operators require a class/enum operand ([over.oper]), so `double *
   double` cannot be re-meant at all. Inventing a type is the *only* move
   the language offers; the objection proposes the heavyweight path as if a
   lightweight one existed.
2. **The committee already chose names, on this exact example.** C++26
   saturation arithmetic (P0543R3) is `std::add_sat` / `std::sub_sat` /
   `std::mul_sat` / `std::div_sat` — named free functions in `<numeric>`,
   not a saturating wrapper type. Likewise `std::gcd`/`std::lcm` (C++17),
   `std::midpoint` (P0811, C++20), `std::lerp` (C++20). The library keeps
   choosing names because the type encodes the wrong thing.
3. **Types are not free in C++.** Haskell's `newtype Sat = Sat Double` is
   one line and guaranteed zero-cost — and even there the wrap/unwrap is
   felt as ceremony (`Sum`/`Product`). C++ has no `newtype`. A usable
   `Saturating<T>` is: constructor set; conversion policy (`explicit` =
   safe + noisy, implicit = quiet + dangerous); the rest of the operator
   zoo forwarded; interop debt everywhere (`is_arithmetic` false,
   `numeric_limits` unspecialized, `.value()` at every `double` interface).
   A real class to design, review, and maintain, as a workaround for one
   function lacking an infix spelling.
4. **Wrong scope, and it can't compose.** Wrapping makes *every* operation
   saturating while the wrapper is on; the intent was one multiplication in
   one expression. Saturate/wrap/trap is a property of an *operation*, not
   an *object*. And `operator*` can mean only one thing per type, so one
   expression needing a saturating multiply *and* a wrapping add has
   nowhere to stand; `a `mul_sat` b `add_wrap` c` states each choice at the
   site it applies.
5. **The lift is noise where the objection claims to remove it.**
   `Saturating{a} * b` reads worse than `a `std::mul_sat` b` and
   misdirects: it marks the data as special when the operation is. The
   reader must go find what `Saturating` does to `*`; the named function
   said it in the expression.

**Landing:** the wrapper type is what we write today because the call
syntax reads worse than the operator syntax. The proposal fixes the syntax
instead.

---

## 19. Prior art survey (both uses)

Carried in the paper's "Prior art" section. Sources verified 2026-07-11.

### 19.1 Infix application of named callables — adopters and removers

**Adopters (current):**

- **Haskell** — since the first Report (1990): an ordinary identifier in
  grave accents is an infix operator (`` x `div` y ``).
- **PureScript** — any function infix via backticks; **independently settled
  on left-associative, highest precedence** — the same fixity as [chaining-associativity](#chaining-associativity)/[precedence-level](#precedence-level).
  Corroborating *design* precedent, not just lexical.
  [book.purescript.org/chapter3.html]
- **Idris** — same construct, in the official tutorial.
  [docs.idris-lang.org/en/latest/tutorial/typesfuns.html]
- Haskell-family dialects (Frege, Curry) inherit it.

**Removers (the objection EWG will find — pre-loaded):**

- **Elm** removed backticks in 0.18 (2016). Stated reasons: in practice one
  function (`andThen`) accounted for usage; redundant with Elm's `|>`;
  glyph confusable with quotes in some fonts.
  [github.com/elm-lang/elm-platform/blob/master/upgrade-docs/0.18.md]
- **Unison** removed backtick infix application.
  [github.com/unisonweb/unison/pull/2570]

**Why the removals don't transfer:** both are pipeline-first functional
languages whose dominant backtick idiom was monadic chaining — exactly what
`|>` covers, so backtick carried one idiom that already had a spelling. The
C++ motivating set (`gcd`, `dot`, `mul_sat`, `approx_equal`) is binary
operations, not chains; §15 keeps backtick and `|>` distinct precisely so
neither absorbs the other. Elm folding backtick *into* its pipe supports
that separation. Font-confusability files under §13.1 ergonomics.

**Adjacent spellings of the same demand:** Kotlin `infix fun`; Scala bare
method infix; R `%op%`; Miranda `$fn` (the direct ancestor of Haskell's
backtick); Fortress named operators. The demand recurs; only the spelling
varies. Backtick has the deepest working precedent.

### 19.2 Keyword escapes

Swift `` `class` ``; Kotlin backtick identifiers; F# double-backtick names;
C# `@`-verbatim identifiers; Nim backtick stropping; **Rust `r#` raw
identifiers** — added specifically so the 2018 edition could take `try` /
`async` / `await` as keywords while 2015-edition code kept compiling
(editions + raw identifiers make keyword adoption routine).
[doc.rust-lang.org/edition-guide/rust-2018/module-system/raw-identifiers.html]
C++ is the outlier: no escape, so new keywords break code and the coping
strategies are `co_`-circumlocution and context-sensitive grammar.
