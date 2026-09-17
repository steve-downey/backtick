# escape-any-identifier — the escape takes an identifier, not a keyword

**Goal.** Build the rule the author decided on 2026-09-17,
[escape-content](../../../docs/backtick-operator-design.md#escape-content):
anything spelled as an identifier may stand between the backticks, and what
comes out is that identifier and nothing more specific. `` `foobar` `` **is**
`foobar`. Both prototypes reject `` `foobar` `` today. This step makes them
accept it, on both Clang branches and on GCC, and measures the two
consequences the decision derives but nobody has asked a compiler about.

**Depends on:** none. Nothing depends on it either, but **the two papers may
not be submitted while it is open**: D4307R0 proposes this rule, and the
sentence saying the forks do not yet implement it is in the paper precisely
because this box is unticked.

**Refs:** [escape-content](../../../docs/backtick-operator-design.md#escape-content),
the decision and its cost paragraph;
[the ruling](../../../docs/open-decisions.md#2026-09-17--escape-content-the-escape-takes-any-identifier);
§12's *What may stand between the backticks*;
[keyword-escape-printing](../../../docs/backtick-operator-design.md#keyword-escape-printing),
which is why no printer changes.

## This is a decision, not a defect

Nothing diverged and nothing was measured wrong. The prototypes restrict the
escape to keywords because that is what the design said until 2026-09-17, and
the paper carried the restriction to EWG as an open choice. The author closed
it, for the reason the hatch exists: an escape that only accepts words that
are *already* keywords cannot be written until the standard that takes the
word has shipped, so it can repair a break and can never prevent one. There is
therefore no ledger row to close, and opening one would be wrong.

## Measured, 2026-09-17, on `backtick-trunk` at `28b685c86e`

The restriction is one predicate, asked twice:

```
clang/lib/Parse/Parser.cpp:2667  Parser::isBacktickEscapeAt
    Kw.getIdentifierInfo() && Kw.getIdentifierInfo()->isKeyword(getLangOpts())
clang/lib/Parse/Parser.cpp:2691  Parser::ConsumeBacktickEscape
    if (!Tok.getIdentifierInfo() || !...->isKeyword(getLangOpts()))
        Diag(..., diag::err_backtick_escape_not_keyword);
```

and `err_backtick_escape_not_keyword` in
`clang/include/clang/Basic/DiagnosticParseKinds.td:216`, *"backtick
keyword-escape requires a C++ keyword"*.

**The printing side already implements the identity half of the rule**, which
is worth reading before touching anything, because it is why this step is
small. `DeclarationName::print` and `printIdentifierSpelling`
(`clang/lib/AST/DeclarationName.cpp:133`, `:152`) put the backticks back when
`II->getTokenID() != tok::identifier` — when the *spelling is a keyword* — and
never because a name was written escaped, which the AST does not record. A
name that is not a keyword therefore already prints bare, which is what
[escape-content](../../../docs/backtick-operator-design.md#escape-content)
says it must. Do not add an "was escaped" bit to make anything round-trip; if
one seems necessary, the change has gone wrong.

## Do

### 1. Clang, on `backtick-trunk` first, then cherry-picked to `backtick-23`

- Both predicates accept any identifier-spelled word: identifiers, keywords,
  and the [lex.digraph] alternative representations (`and`, `bitor`, …),
  which the decision includes deliberately and which `isKeyword` currently
  excludes because their `TokenID` is a punctuator kind (`and` is
  `tok::ampamp` carrying an `IdentifierInfo`).
- **Do not write the predicate as `Tok.getIdentifierInfo() != nullptr`
  alone.** `Token::getIdentifierInfo` reinterprets `PtrData` for any token
  that is not a literal or `eof`, so an *annotation* token answers with
  something that is not an `IdentifierInfo`. The existing code has the same
  exposure and it has never been reachable; do not widen it. Guard on
  `!Tok.isAnnotation()`, or test the token kind directly, and say in a
  comment which one you chose and why.
- Rename the diagnostic to `err_backtick_escape_not_identifier` and reword it
  to *"backtick escape requires an identifier"*. It still has work to do:
  `` `3` ``, `` `+` ``, `` `"s"` `` and `` `` ` `` `` must diagnose and stop.
- Nothing else. No printer, no `PrintingPolicy` bit, no Sema, no AST.
  `ConsumeBacktickEscape` already rewrites the token into the interned
  identifier and everything downstream sees a name.

### 2. GCC

The same predicate in the arm the escape shares with `cp_parser_identifier`,
and the matching diagnostic. Confirm the symbol names in the worktree rather
than trusting this paragraph; the ledgers describe the arm, not its current
shape.

### 3. Tests

Two existing Clang lines assert the restriction and must be rewritten, not
deleted — `clang/test/Parser/backtick-escape-diagnostics.cpp:7` and `:36`
(`` (void)`foo`(); `` and `` NS::`notakeyword` q0; ``). Both become
well-formed spellings of names that are simply not declared, so they move to
the accepting test with a declaration, and the diagnostics file keeps the
error path with a non-identifier inside the backticks instead.

New coverage, in `clang/test/Parser/backtick-escape.cpp` and the GCC
equivalent under `gcc/testsuite/g++.dg/backtick/`:

- **Identity.** `` int `foobar` = 1; int y = foobar; `` compiles, and so does
  the reverse order. One redeclaration pair, one spelled each way, is the
  sharpest form: `` int foo; int `foo`; `` is a redefinition and must
  diagnose as one.
- **Mangling.** `` void g(int, `foobar`); `` beside `void g(int, foobar);`
  in the ABI test, which already pins `` g(int, `int`) `` as `_Z1gi3int`.
- **Printing.** `-ast-print` of a declaration whose name was escaped and is
  not a keyword emits it **bare**, and the output re-parses. This is the
  assertion that pins the identity rule at the printer, and it passes today
  only because nothing can produce such a name today.
- **Alternative tokens.** `` int `and` = 0; ``, and it is still `int`.
- **The error path.** A non-identifier between the backticks diagnoses and
  *stops*, in every one of `escape-errors.sh`'s positions.

### 4. The probes

`ops/probes/escape-positions.sh` gets a **fifth category**: the same programs
with the keyword replaced by an ordinary identifier. Seventy-nine programs
vary the position four ways and have never once varied the word, which is the
fifth thing the sweep did not ask and the fourth category is the warning about
(it found `` int `int` = 0; `` after two months by changing the keyword).
Re-run all three probes. `flag-off-parity.sh` is the one that matters most
here: a program containing no backtick must still compile and diagnose
identically, and this change touches a predicate that runs on every backtick.

### 5. The forward-port, which is owed and is not optional

This lands in `clang/lib/Parse/Parser.cpp` on the backtick branches alone, so
it is the **seventh** backtick merge onto `unicode-operators-experiment`, per
CLAUDE.md's rule and the six that precede it. Predict the collision, then
**check the prediction with one `git diff --numstat` before writing the
paragraph about it** — three merges running have turned on that.
`unicode-operators-upstream` must not receive it.

## Gate

1. `check-clang` green on **both** Clang branches. Redirect and check the exit
   code; `ninja … | tail` reports `tail`'s status. Budget only the two known
   failures CLAUDE.md lists, and `dump-config-objc-stdin.m` on `backtick-23`
   only.
2. GCC: `make -C gcc check-c++ RUNTESTFLAGS="dg.exp=g++.dg/backtick/*.C"`
   clean.
3. All three probes re-run against both compilers, the fifth category
   included, and the new totals written into §12's sweep table. **Do not
   update the table from the old totals plus arithmetic**; paste what the
   script printed.
4. The two derived claims in §12 are measured and the word *derived* comes
   out of the one that survives:
   - a reserved name stays reserved (`` `__foo` `` is what `__foo` is);
   - **a macro name between the backticks is replaced**, because the escape is
     a phase 7 construct and the preprocessor has never heard of it. Ask both
     compilers with `#define foobar 3` and `` int `foobar` = 0; ``. If either
     says otherwise, that is a finding and it goes in a ledger and in the
     paper's drafting note, which now states the phase-4 behaviour as fact.
5. The paper: strike the three places that say the forks do not implement the
   rule (the abstract's last sentence, the *escape yields an ordinary
   identifier* section, and the fifth-sweep paragraph in *implementation
   experience*), and only then. `make -C papers
   backtick-infix-and-keyword-escape.html backtick-infix-and-keyword-escape.pdf`
   — **both**, exit 0, and read the log.
6. `Log.` lines dated and appended to
   [escape-content](../../../docs/backtick-operator-design.md#escape-content)
   and to the ruling in `docs/open-decisions.md`, saying what was measured.
   §12's *What is not built* paragraph is deleted, not amended.

## Notes

**Do not treat this as a widening of the escape's risk surface.** Every
program it newly accepts is one both compilers reject today, in a position
where a backtick is an error with the flag on and not a token at all with the
flag off. It is the same shape of change as
[escape-name-positions](escape-name-positions.md), and the same argument
covers it.

**The docs are already written.** This step writes code, tests, probes and the
three paper sentences named in the gate; `docs/backtick-operator-design.md`,
`docs/open-decisions.md`, `docs/infix-backtick-operator.org` and the rest of
the paper landed with the decision on 2026-09-17 and are not this step's to
revisit.
