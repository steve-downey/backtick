# Handoff — escape-name-positions — the escape reaches every name position

- **Status:** **DONE (gates passed)**. The author's answer is recorded, built
  in both compilers, and written into every document that carried the old
  measurement. [settle-paper-rows](settle-paper-rows.handoff.md) is unblocked
  and its box is ticked with this one.
- **Branch / commit:**
  - `backtick-trunk` — `14f6373ccc7d`
  - `backtick-23` — `3cc2ef27489a` (cherry-pick, gated independently)
  - GCC `backtick` — `7f987d05e14`
  - `unicode-operators` in *this* repo — the step file, the documents, the
    ledgers, the plan and this handoff. **Neither Unicode branch was touched**;
    see *Open risks*.
- **Date / agent:** 2026-09-08.
- **Answers:** [escape-name-positions](../../../docs/open-decisions.md#escape-name-positions),
  option **(c)**, with the recommendation's transitional half struck.
- **Closes:** [`escape-name-positions`](../../DEVIATIONS.md#escape-name-positions)
  and [`escape-alias-name-parity`](../../gcc/DEVIATIONS.md#escape-alias-name-parity),
  both **FIXED and RECONCILED**.
- **Opens:** [`escape-type-keyword-binding`](../../gcc/DEVIATIONS.md#escape-type-keyword-binding),
  which is **older than this change** and was found by re-measuring.

---

## The answer, and the part of it that is not the option letter

**(c) — implement the broad set in both compilers**, so the prototypes reach
what the proposed [lex.name] wording already said: an escaped-identifier may
appear wherever the grammar uses `identifier` as a terminal.

The brief had recommended *(c), and until it lands, (b) with the example
changed*. **The author struck the hedge**, and the reason is worth carrying
forward because it applies to every staging question this project has left:
*there is no real shipped anything other than a GitHub fork, and no one is
relying on anything.* Staging costs something and buys nothing when nobody is
downstream. So no paper says a position is unprototyped, and the wording's own
example, `` struct `union` { }; ``, is not changed — it compiles.

The recommendation was also explicit that
[`escape-alias-name-parity`](../../gcc/DEVIATIONS.md#escape-alias-name-parity)
is not a separate question. It closed out of the same GCC arm as the eight
positions neither compiler took, which is what *one cause, not three* meant.

## What changed

### Clang — `backtick-trunk` `14f6373ccc7d`, `backtick-23` `3cc2ef27489a`

- `clang/lib/Parse/Parser.cpp`, `clang/include/clang/Parse/Parser.h` —
  `Parser::ConsumeBacktickEscape` is the escape parse lifted out of
  `ParseUnqualifiedId`; `isBacktickEscape()` and `isBacktickEscapeAt(N)` are
  the predicates. Both existing arms (`ParseUnqualifiedId`,
  `ParseCastExpression`) now call the helper, so there is one copy of the
  three-token consume-and-rewrite instead of two.
- **Name positions** — `ParseDeclCXX.cpp` (`ParseNamespace`,
  `ParseClassSpecifier`, `ParseMemInitializer`, `ParseBaseTypeSpecifier`,
  `ParseUsingDirective`), `ParseDecl.cpp` (`ParseEnumSpecifier`,
  `ParseEnumBody`, and the decl-specifier `case tok::backtick:`),
  `ParseTemplate.cpp` (`ParseTypeParameter`,
  `ParseTemplateTemplateParameter`, and two lookaheads in
  `isStartOfTemplateTypeParameter`), `ParseStmt.cpp` (the label at the top of
  `ParseStatementOrDeclarationAfterAttributes`, and `ParseGotoStatement`),
  `ParseExprCXX.cpp` (`ParseOptionalCXXScopeSpecifier`, for a *middle*
  component of a nested-name-specifier). **Fourteen new call sites that consume
  the escape**, plus five lookahead uses in three functions that must not —
  counted from the diff, not from the estimate.
- **Two sites that must not consume**, and they are the interesting ones:
  - `ParseTentative.cpp`, `isCXXDeclarationSpecifier` — runs inside the
    backtracking token cache. Rewriting `Tok` there trips
    `Preprocessor::AnnotatePreviousCachedTokens`, whose assertion is *"The
    annotation should be until the most recent cached token"*. It answers by
    calling `Actions.getTypeName` on the escaped keyword instead and leaves
    the consuming to `ParseDeclarationSpecifiers`.
  - `ParseCXXInlineMethods.cpp`, `ConsumeAndStoreFunctionPrologue` — caching
    an inline constructor's *ctor-initializer* rather than parsing it. It
    stores the escape's three tokens untouched.
- **Printing**, because a new name position is a new printing surface:
  `printIdentifierSpelling` (`DeclarationName.h` / `.cpp`) is the shared
  helper for printers that hold an `IdentifierInfo` rather than a
  `DeclarationName`; `TypePrinter.cpp` (seven sites), `NestedNameSpecifier.cpp`
  (namespace and namespace-alias), `StmtPrinter.cpp` (`VisitLabelStmt`,
  `VisitGotoStmt`). `DeclPrinter.cpp` needed a different fix for the same
  cause: `Out << D->getDeclName()` uses `operator<<`, which builds a
  **default** `PrintingPolicy` in which the escape is off — enum names,
  namespace names, template type-parameter names, template template-parameter
  names and concept names all printed the bare keyword through it.
- `clang/test/Parser/backtick-escape-positions.cpp` — new. Declares *and then
  uses* each position, and its third RUN line re-parses its own `-ast-print`
  output.

### GCC — `backtick` `7f987d05e14`

- `gcc/cp/parser.cc` — `cp_parser_backtick_escaped_identifier` is the escape
  parse lifted out of `cp_parser_unqualified_id`, and `cp_parser_identifier`
  gains an arm calling it. **That one arm reaches every position**, because
  `cp_parser_identifier` is where a class-head-name, an enum-name, an
  enumerator, a namespace-name, a template parameter name, a
  mem-initializer, a label, a `goto`'s label and the alias, alias-template and
  concept names all read their bare `CPP_NAME`.
- The rest is the **guards**: `cp_lexer_nth_token_starts_name` and
  `cp_lexer_name_width` replace bare `CPP_NAME` tests and `+ 1` offsets at the
  namespace-definition and alias-declaration dispatch, the concept dispatch,
  `cp_parser_class_head`, `cp_parser_enum_specifier`, the labeled-statement
  dispatch and `cp_parser_label_for_labeled_statement`,
  `cp_parser_template_parameter` and `cp_parser_type_parameter`,
  `cp_parser_namespace_definition`, `cp_parser_class_name`,
  `cp_parser_nested_name_specifier_opt`, `cp_parser_qualifying_entity`,
  `cp_parser_template_id` and `cp_parser_constructor_declarator_p`.
- **Two GCC-only pieces of work**: `cp_parser_alias_declaration` builds its own
  declarator with `make_id_declarator` rather than going through
  `cp_parser_direct_declarator`, so it must set `backtick_escaped_p` itself or
  `grokdeclarator` rejects the keyword the escape yields; and
  `cp_parser_constructor_declarator_p` decides on the first token, so a
  constructor named by an escape needs it.
- `gcc/testsuite/g++.dg/backtick/escape-positions.C` — new, `-std=c++20`
  pinned in `dg-options` (the suite runs a file at three standards, and
  concepts, alias templates and scoped enums are not in gnu++98; without the
  pin the file fails there and only there).

### This repo

- `docs/backtick-operator-design.md` — [§12](../../../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers)'s
  position section rewritten (the table is now all `accepts / accepts`, plus
  the use-side paragraph, the surviving divergence, and what it cost);
  [keyword-escape-coexistence](../../../docs/backtick-operator-design.md#keyword-escape-coexistence)'s
  Status stops saying *scope open*, with a dated `Log.`;
  [§17.8](../../../docs/backtick-operator-design.md#178-which-of-this-is-clangs-alone-and-why)'s
  divergence list is *two kinds, and both are one-liners*.
- `docs/open-decisions.md` — the answer section, the summary table row, the
  preamble, and a row in *Where each answer was recorded*. The page now reads
  **six answered, none open**.
- Both backtick ledgers; `ops/completion/PLAN.md` (checklist, both Coverage
  tables, Baselines, Status rows); `CLAUDE.md`.
- `papers/backtick-infix-and-keyword-escape.md` and
  `docs/infix-backtick-operator.org` — the position list in three places each,
  and the divergence list.

## Verification evidence

### The nineteen positions, re-measured from programs

Not from the old table. **Twenty-three one-line programs** covering the
seventeen rows of §12's table — the declarator-id row is five spellings, the
enum row is scoped and unscoped, the expression row is a primary-expression
and a member access, which is where "nineteen positions" comes from. Run on
the built `clang++` from `build-backtick-trunk` and on `cc1plus` from
`gcc-backtick-build`, `-std=c++20 -fbacktick -fsyntax-only`, in a `bash`
script with an array (`zsh` does not word-split, which has now cost this track
three probe sweeps).

| | before | after |
|---|---|---|
| Clang accepts | 12 / 23 | **23 / 23** |
| GCC accepts | 9 / 23 | **23 / 23** |

`` struct `union` { }; `` **compiles on both.**

### The use positions, which nobody had measured

**Fifteen more programs** — a type-specifier, a member's type, an enum type,
an enumerator in an expression, a scoped enumerator, a qualified namespace
member, a using-directive, an alias, an alias template specialization, a
concept in a type-constraint, a type parameter used as a type, a template
template parameter specialized, a base-specifier, a mem-initializer naming a
base, and a *middle* component of a nested-name-specifier. Before, on the
first fourteen: Clang 5 / 14, GCC 8 / 14. After: **15 / 15 on both.**

The fifteenth was added last and is the one worth naming, because it is the
one a reader will hit first. The *last* component of a qualified name is an
unqualified-id and was always reachable, so `` N::`new` `` worked from the
start and `` `module`::inner::f() `` did not — and the second is the shape the
hatch exists for. It is read by `ParseOptionalCXXScopeSpecifier`'s loop, which
is a different parser from `ParseUnqualifiedId` and one of the places the
parser speculates, so the escape is consumed there **only when it is actually
followed by `::`**.

### Flag-off parity, measured byte-identically

Structural first: Clang's lexer emits `tok::backtick` only when
`LangOpts.Backtick`, and `-fbacktick` carries
`ShouldParseIf<cplusplus.KeyPath>` so it cannot be set in C at all; libcpp
emits `CPP_BACKTICK` only when `CPP_OPTION (pfile, backtick_is_operator)`.
Every arm added here is keyed on that token and is therefore unreachable with
the flag off. Measured anyway, on two programs containing **no backtick** and
exercising every construct whose lookahead moved — one well-formed, one
ill-formed in each of them (seventeen errors, 67 lines of diagnostics):

```
              flag on vs flag off      flag on vs pristine build-main
clang  ok      IDENTICAL (0 lines)      IDENTICAL
clang  bad     IDENTICAL (67 lines)     IDENTICAL
cc1plus ok     IDENTICAL (0 lines)      —
cc1plus bad    IDENTICAL (67 lines)     —
```

The pristine-`build-main` column is the stronger control and is the one worth
repeating: it says the flag-on diagnostics are what upstream Clang produces,
not merely what this branch produces both ways.

### Gates

```
backtick-trunk   check-clang   14f6373ccc7d_GATE
backtick-23      check-clang   3cc2ef27489a_GATE
GCC              dg.exp=g++.dg/backtick/*.C   110 passes / 0 failures  (was 109; +1)
```

### Failing first, on a pre-fix binary

`build-backtick` (`backtick-23`) had not taken the change when the test was
written, so it is the control, run on the new test file:

```
$ build-backtick/bin/clang -cc1 -std=c++20 -fbacktick -fsyntax-only \
      clang/test/Parser/backtick-escape-positions.cpp
  ... 2 warnings and 39 errors generated.
```

Post-fix: zero. And the printing half, on the same probe file before and
after — `union u0{1};`, `enum class {`, `namespace namespace {`,
`template <class typename>`, `try:`, `goto try;`, `class::`new`` — every one
of which is source that does not re-parse; after, each is escaped and the
`-ast-print` output re-parses clean.

### Documents

- Both paper formats build, `EXIT=0`, **0 missing characters**
  (`grep -ci "missing character"` over the full pandoc/LaTeX output → 0).
  `papers/generated/` removed afterwards; it is build output.
- `lexcheck --register formal` on the paper: three warnings, all pre-existing
  and all at their pre-step counts (`, not Y` ×14, `exactly` ×12, one
  contraction). `--register blog` on the `.org`: **clean** — it took two
  passes, the first draft having pushed the em-dash rate to 39 per 10k.
- 2597 local Markdown links repo-wide, **0 broken**.
- Public text swept for internal identifiers: no slug, no ledger name, no path
  under `ops/` in either deliverable's new text.

## Deviations from the step file

1. **The brief's price was for half the job.** *"One helper plus up to eight
   call sites in Clang, one `cp_parser_identifier` arm plus its guards in
   GCC"* was right about the shape and about the declaration half. It came to
   **thirteen Clang call sites** and roughly fifteen GCC guard edits, and the
   overrun is entirely in the two things the measurement had not looked at:
   the *use* positions and the *printers*. The step file was written after the
   first of those was found and says so; the second was found after it.
2. **One position in the answer's list needed a second call site of a
   different kind.** A label is `ParseStatementOrDeclarationAfterAttributes`
   for the definition and `ParseGotoStatement` for the reference. A label you
   can define but not jump to is not worth having, so both are in.
3. **`use-meminit-base` in the first probe set conflated two things** — a
   mem-initializer naming an escaped base, which worked, and a *constructor*
   named by an escape, which did not, in GCC. Split, and both work.

## Discoveries affecting later work

- **A tentative-parse predicate must not rewrite the token stream, and the
  symptom is an assertion three layers away.** `isCXXDeclarationSpecifier` is
  called with a `TentativeParsingAction` open, so `Tok` comes from the
  preprocessor's token cache; `ConsumeBacktickEscape`'s `PP.EnterToken` breaks
  the invariant `Preprocessor::AnnotatePreviousCachedTokens` asserts. The
  general rule for this feature: **a predicate answers, a parse consumes**, and
  where the predicate needs to know what a name means it should ask Sema
  (`getTypeName`) rather than the parser. `ParseTentative.cpp`'s existing
  declarator arm had already reached the same conclusion by skipping tokens
  rather than rewriting them; it just was not written down.
- **`operator<<(raw_ostream &, DeclarationName)` builds a default
  `PrintingPolicy`.** Every printer that reaches a name through it prints with
  the escape off, whatever policy the caller was using. That is a trap for the
  whole `keyword-escape-printing` decision and it is not visible at the call
  site — `Out << D->getDeclName()` looks policy-aware and is not.
- **A list of cross-compiler divergences is only as good as the programs it
  was measured with.** [`escape-type-keyword-binding`](../../gcc/DEVIATIONS.md#escape-type-keyword-binding)
  had been sitting in §12's *first* row — the plain declarator-id, the oldest
  and best-tested position — for two months, because every probe anyone wrote
  used `new`, `class`, `union` or `try`, and all four are pure keywords. `int`
  and `long` are not: they carry a global binding to the builtin type in GCC's
  name table.
- **Nineteen one-line programs took about ten minutes and have now caught
  something on all three occasions they have been run.** This is the third.

## Forward notes — there is no next step

`ops/completion/PLAN.md` has nineteen boxes and all of them are `[x]` or
`[—]`. `docs/open-decisions.md` has no open question. Both papers are written,
both build in both formats, and both say what the compilers do.

What is genuinely left, for whoever picks this up:

- **Nothing is pushed.** Three branches are ahead of their remotes by one
  commit each (`backtick-trunk`, `backtick-23`, GCC `backtick`) and this repo
  by two. Pushing is the maintainer's call.
- **The three upstream reports are still drafted and unfiled**, in
  [`upstream-drafts/`](../upstream-drafts/README.md), and their backlog rows
  say so. That is the author's, not an agent's.
- **[`escape-type-keyword-binding`](../../gcc/DEVIATIONS.md#escape-type-keyword-binding)
  is open and is an implementer's question nobody has priced.** Do not fix it
  by reflex: making GCC accept `` int `int` = 0; `` means shadowing a global
  binding on the shared interned identifier, and the design says nothing about
  which of the two keyword representations is right. It is also the least
  valuable corner of the hatch — the keywords a future revision is likely to
  take are not type keywords.
- **`unicode-operators-experiment` does not have any of this.** It carries the
  backtick feature through
  [unicode-branch-maintenance](unicode-branch-maintenance.handoff.md)'s merge,
  which now predates two commits: `settle-paper-rows`'s aggregate arm and this
  one. That is a forward-port and belongs to whoever next merges
  `backtick-trunk` into it. **This one will not be clean**: it touches
  `TypePrinter.cpp`, `DeclPrinter.cpp` and `StmtPrinter.cpp`, and
  `unicode-operators-experiment` has its own arms in the last two.
  `unicode-operators-upstream` must never receive it.

## Open risks / TODOs

- **The escape's coverage is now defined by a rule rather than by a list, and
  a rule can be violated silently.** Every position in §12's table has a
  positive test in both suites; a position nobody has thought of does not. The
  probe scripts are the cheap defence and they are not in the repo — they are
  twenty-three plus fourteen one-line programs and a `bash` loop, about ten
  minutes to rewrite. Whoever next touches the escape should rewrite them
  rather than trust the table.
- **Neither test suite has a negative test for a *malformed* escape in the new
  positions** — `` struct `notakeyword` { }; ``, `` namespace `new { } ``.
  The error paths are exercised only by the shared helper's two diagnostics,
  which the old positions already pinned. That is a smaller gap than the one
  this step closed, but it is the same shape.
