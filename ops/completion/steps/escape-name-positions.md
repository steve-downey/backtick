# escape-name-positions — build the escape's coverage the author decided

**Goal.** The author answered
[escape-name-positions](../../../docs/open-decisions.md#escape-name-positions)
**(c)** on 2026-09-07: *implement the broad set in both compilers, so the
prototypes catch up with the [lex.name] wording.* An escaped-identifier may
appear wherever the grammar uses `identifier` as a terminal. Build that, in
Clang on **both** backtick branches and in GCC, and make every document say
what is then true.

The answer also disposes of the transitional half of the recommendation. The
brief said *(c), and until it lands, (b) with the example changed*; the author
struck the hedge, with the reason: **there is no shipped anything but a GitHub
fork and nobody is relying on it**, so there is no window to stage.

**Depends on:** [settle-paper-rows](settle-paper-rows.md), which measured the
nineteen positions, wrote the brief and ended BLOCKED on it. This step is what
unblocks that one; tick its box too when the two rows it left open go
`RECONCILED`.
**Closes:** [`escape-name-positions`](../../DEVIATIONS.md#escape-name-positions)
and [`escape-alias-name-parity`](../../gcc/DEVIATIONS.md#escape-alias-name-parity).
The recommendation is explicit that the second is not a separate question and
must not be answered separately: GCC's alias, alias-template and concept names
come into line out of the same arm.

## Why this is a step and not a footnote on settle-paper-rows

That step's job was to *ask*. Answering it is a diff in three trees, two
compilers' test suites, four documents and two papers, and it went on to
uncover two things the brief could not have known. A step that ends BLOCKED
and a step that ends green are different work with different gates, and
folding them together would leave no record of which measurement belongs to
which.

## Do

### 1. Clang, on `backtick-trunk` first, then `backtick-23`

The escape arm in `ParseUnqualifiedId` already does the whole job — consume
three tokens, push the following token back with `PP.EnterToken`, rewrite
`Tok` into an identifier. Lift it into one helper and call it from each name
position that reads a bare identifier token of its own.

- **The lexer is the flag gate.** `Lexer::LexTokenInternal` produces
  `tok::backtick` only when `LangOpts.Backtick`, and `-fbacktick` carries
  `ShouldParseIf<cplusplus.KeyPath>`, so it cannot be set in C at all. Every
  arm keyed on `Tok.is(tok::backtick)` is therefore unreachable with the flag
  off. Say so, and **measure it anyway** — this is the third step in a row to
  touch a lookahead predicate, and the previous two both broke flag-off
  parity first.
- **A lookahead predicate must step over three tokens where it stepped over
  one.** A label is told from an expression statement by the `:` *after* the
  name; a template type-parameter from a non-type one by the token after the
  name. Both look one token ahead today.
- **Do not rewrite `Tok` inside a tentative parse.** `isCXXDeclarationSpecifier`
  runs inside the backtracking token cache, and consuming the escape there
  trips `Preprocessor::AnnotatePreviousCachedTokens`, which asserts that an
  annotation ends at the most recently cached token. Answer such a predicate
  by looking the name up instead, and leave the consuming to the real parse.

### 2. GCC, on `backtick`

One arm in `cp_parser_identifier`, which is where every one of these names
reads its bare `CPP_NAME` — including the alias, alias-template and concept
names Clang already took. Then the *guards* in front of the positions: each is
a `cp_lexer_next_token_is (… CPP_NAME)` or a peek at the token after a name.
Give them a shared `starts_name` predicate and a `name_width`, so no call site
open-codes "three".

The two positions with no Clang counterpart to copy: an alias-declaration
builds its own declarator rather than going through `cp_parser_direct_declarator`,
so it has to carry `backtick_escaped_p` itself or `grokdeclarator` rejects the
keyword it yields; and `cp_parser_constructor_declarator_p` decides on the
first token.

### 3. Accepting a declaration is only half of it

A type nothing can name is not an escape hatch. `struct module { };` is the
case that motivates the whole feature and `module m;` is the line after it.
**Probe the use side as well as the declaration side** — the name in a
decl-specifier, in a base-specifier, in a nested-name-specifier, as a
template-name, in a using-directive, in a type-constraint — and treat a
position that can be declared but not used as unfinished, not as out of scope.

### 4. Printing

[keyword-escape-printing](../../../docs/backtick-operator-design.md#keyword-escape-printing)
is ratified: under the flag the escape is the only spelling the name has, so
every printer that emits source re-emits it. New name positions are new
printing surfaces, and `-ast-print` round-tripping is a paper claim.
`DeclarationName::print` escapes; a printer that reaches an identifier without
going through it does not, and `operator<<(raw_ostream &, DeclarationName)`
uses a **default** policy, so it does not either.

### 5. The documents

- [§12](../../../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers)'s
  position table and its *"Which positions are implemented"* paragraph were
  written from the *old* measurement. **Update them; do not append a
  contradiction.**
- [keyword-escape-coexistence](../../../docs/backtick-operator-design.md#keyword-escape-coexistence)'s
  Status has read *scope open* since it was written. It can stop.
- [§17.8](../../../docs/backtick-operator-design.md#178-which-of-this-is-clangs-alone-and-why)
  says *two kinds, and four programs*. Both halves move.
- Record the answer in [`docs/open-decisions.md`](../../../docs/open-decisions.md)
  the way the eight answers there already are — a dated section, the
  implicated `Log.` fields, the ledger rows' `Status:`, and a row in *Where
  each answer was recorded*.
- **The papers.** `papers/backtick-infix-and-keyword-escape.md` and
  `docs/infix-backtick-operator.org` state which positions are prototyped and
  which programs the two compilers treat differently. Read them line by line;
  three separate steps have caught them asserting things the project had
  already disproved. **No internal identifier in either.** Re-check that both
  formats build with no missing characters — a missing glyph is a warning and
  the build still exits 0.

## Verify (gate)

- **The nineteen positions re-measured on both compilers after the change**,
  from programs, not from the old table. Say how many programs.
- **Flag-off parity, measured byte-identically**, on a program containing no
  backtick — one well-formed and one ill-formed in every construct whose
  lookahead moved, since a diagnostic is where the last two breakages showed.
- `` struct `union` { }; `` compiles on both compilers.
- `check-clang` green on **both** backtick branches against the Baselines in
  [`ops/completion/PLAN.md`](../PLAN.md), with a Status-log row each and the
  Baselines updated for any test file added.
- `dg.exp=g++.dg/backtick/*.C` green; state the delta from **109**.
- Both papers build both formats with **0** missing characters.
- Every row this step closes is marked in its ledger, naming the destination
  **section and paragraph**.
