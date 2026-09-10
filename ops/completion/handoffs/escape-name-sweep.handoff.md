# Handoff — escape-name-sweep — the escape reaches a qualified type, and a type keyword

- **Status:** **DONE (gates passed).** Both rows fixed. There is now **no
  program the two compilers treat differently on account of the keyword
  escape**; the one acceptance divergence left in the feature is the type-name
  slot, which belongs to the operator.
- **Branch / commit:**
  - `backtick-trunk` — `bd8790f9d0ef`
  - `backtick-23` — `49ca42d1fab7` (cherry-pick, gated independently)
  - GCC `backtick` — `d11d9b97a14`
  - `unicode-operators` in *this* repo — the step file, the probes, the
    documents, both ledgers, the plan and this handoff. **Neither Unicode
    branch was touched**; see *Open risks*.
- **Date / agent:** 2026-09-08.
- **Closes:** [`escape-in-qualified-type-name`](../../DEVIATIONS.md#escape-in-qualified-type-name)
  and [`escape-type-keyword-binding`](../../gcc/DEVIATIONS.md#escape-type-keyword-binding),
  both **FIXED and RECONCILED**.
- **Opens:** [`escape-type-name-spelling`](../../gcc/DEVIATIONS.md#escape-type-name-spelling),
  a **diagnostic** divergence and not an acceptance one, found by reading the
  error-path sweep's diagnostics rather than only its exit codes. Measured,
  surfaced in §12, §17.8 and both papers, and **deliberately not fixed** — see
  *Deviations*. The three ledgers therefore read 0 / 1 / 0.

---

## Both rows were verified before being fixed, and both were wrong about size

The brief said to re-derive rather than read, because in ten consecutive steps
a recorded mechanism or count has failed re-checking. Two more did.

**[`escape-in-qualified-type-name`](../../DEVIATIONS.md#escape-in-qualified-type-name)
was three times the size its row recorded.** The row had eight programs and
four Clang rejections. Twenty-five programs — written before touching anything
— gave **twelve**: every shape in which a qualified name ends in a *type*
(declaration, *alias-declaration*, `sizeof`, block-scope declaration,
parameter, return type, `new` expression, template argument, `static_cast`,
dependent `typename`, and both halves escaped) plus the leading escaped
namespace at block scope. **Four qualified type shapes already worked**, and
they are the ones that say why the others did not: an
*elaborated-type-specifier*, a base-specifier, a mem-initializer's base and a
*middle* nested-name-specifier component all go through parsers
[escape-name-positions](escape-name-positions.handoff.md) had already taught.
GCC took all twenty-five before and after.

**[`escape-type-keyword-binding`](../../gcc/DEVIATIONS.md#escape-type-keyword-binding)
was priced as expensive and is cheap.** Its row said fixing it *"means
shadowing a global binding"* and called it *"an implementer's question that
nobody has priced"*. The measurement first: fifteen programs, GCC rejecting
seven of them at three different diagnostics (`redeclared as different kind of
entity` from `duplicate_decls`, `conflicts with a previous declaration` from
`update_binding`, `using typedef-name 'int' after 'struct'` from
`lookup_and_check_tag`) and Clang taking all fifteen. Then the observation
that makes it cheap, which the row did not have.

## The observation, because it is the transferable part

**In C++ a declaration can be named by a keyword only if it was escaped.**
`grokdeclarator` rejects a bare reserved word as a declarator-id — that check
is `escape-name-positions`' own — and `int` is a keyword token everywhere
else. So a declaration that collides with GCC's global binding for `int` is
**never a redeclaration**, and the parser does not have to thread "this name
came from an escape" down into name lookup. That threading is what would have
made it expensive, and it is what "shadowing a global binding" implies. It is
not needed.

GCC's own source asked for the fix. `record_builtin_type`'s comment:

> The calls to `set_global_binding` below should be eliminated. Built-in types
> should not be looked up by name; their names are keywords that the parser
> can recognize. However, there is code in `c-common.cc` that uses
> `identifier_global_value` to look up built-in types by name.

The fix does not eliminate the bindings — that is upstream's call and would
change the C front end. It steps around them for the one kind of declaration
that can collide with one.

## What changed

### Clang — `backtick-trunk` `bd8790f9d0ef`, `backtick-23` `49ca42d1fab7`

Five arms, and the fifth is the interesting one:

- `Parser::TryAnnotateTypeOrScopeTokenAfterScopeSpec` (`Parser.cpp`) — the
  qualified type-specifier. **It peeks and consumes only once `getTypeName`
  has said the name is a type.** On every other path out of that function the
  token has to still be there: an expression's name is read by
  `ParseUnqualifiedId`, and `AnnotateScopeToken` rewinds the token cache by
  one, which is only correct if the token it pushes back came from the cache.
  Consuming unconditionally here corrupts the cache on the not-a-type path.
- `Parser::TryAnnotateTypeOrScopeToken`'s *typename-specifier* branch — reads
  the same name a second time, for `` typename T::`union` ``.
- `Parser::ParseDeclarationSpecifiers`' `case tok::annot_cxxscope:`
  (`ParseDecl.cpp`) — reads it a **third** time. This is the non-tentative
  path: at namespace scope no tentative parse runs, `TryAnnotateCXXScopeToken`
  produces only a scope annotation, and the type name is then looked up
  directly rather than annotated. `Next.isNot(tok::identifier)` was the bail
  out. **This arm shipped an infinite loop on its first build**, and the sweep
  caught it: the recovery path for an unresolved qualified name is
  *implicit-int*, which does not apply to an escape and makes no progress on
  one, so `` namespace N { int x; } N::`union` g; `` — a well-formed escape
  naming something that is not a type — re-entered the case with the token
  stream unchanged, forever. The old bail-out had been doing that job by
  accident. That path now ends the decl-specifier.
- `Parser::isCXXDeclarationSpecifier`'s existing `case tok::backtick:`
  (`ParseTentative.cpp`) — it answered with `Actions.getTypeName` on the
  escaped keyword, and a namespace is not a type, so `` `ns`::T t; `` at block
  scope parsed as an expression. It now annotates and asks again, which is
  exactly what the identifier arm beside it does for `N::T`.
- `Parser::isConstructorDeclarator` (`ParseDecl.cpp`) — **a regression the
  first four caused, and the sweep caught it.**
  `` `union`::`union`() { } `` had been accepted by *accident*: the old code
  bailed out of the decl-specifier on seeing a backtick and left it to the
  declarator. Looking the name up as a type first took that away.

Plus the annotation machinery, which is the row's real cost:

- `Parser::ConsumeBacktickEscape` takes an optional `SourceRange *` and
  reports the escape's extent — opening backtick to closing backtick —
  because **an annotation token is matched against the cached token stream by
  source location** and an escape is three tokens where the grammar wants one.
- The same helper had a **latent backtracking bug**. It pushed the following
  token back with `PP.EnterToken` unconditionally. Under backtracking that
  token is then not in the cache, and the cache is left pointing past a token
  the parser has not consumed. It now uses the `AnnotateScopeToken` idiom:
  `PP.RevertCachedTokens(1)` when backtracking, `PP.EnterToken` otherwise.
  **That change is what makes an escape consumable inside a tentative parse at
  all**, and it refines `escape-name-positions`' rule rather than breaking it:
  *a predicate answers and a parse consumes* — unless the predicate's job is
  to annotate, and then it must annotate over the whole escape.
- `Parser::ParseOptionalCXXScopeSpecifier` gives an escaped component the
  whole escape's range, via a new `Parser::escapeTokenLength`. Without it the
  scope annotation begins at the *keyword* and `AnnotatePreviousCachedTokens`
  matches the wrong cached token, leaving the opening backtick stranded in
  front of the annotation for the next backtracking parse to resume on.
- `tok::backtick` added to `TryAnnotateTypeOrScopeToken`'s entry assertion.

`clang/test/Parser/backtick-escape-positions.cpp` gains the qualified section
and the type-keyword section; `clang/test/Parser/backtick-escape-diagnostics.cpp`
gains the error paths for a qualified escape, **including the one that
looped**. **No new test file** — both go into files that already exist, so the
lit counts do not move.

### GCC — `backtick` `d11d9b97a14`

One predicate and three call sites, all gated on `flag_backtick`:

- `cp_builtin_reserved_type_binding_p` (`gcc/cp/decl.cc`, declared in
  `cp-tree.h`) — an artificial `TYPE_DECL` at `BUILTINS_LOCATION` whose name is
  a **keyword**. Deliberately *not* the non-keyword ones `record_builtin_type`
  also binds (`__int128_t` and friends), which ordinary code may still
  redeclare.
- `duplicate_decls` — returns *not a redeclaration*, beside the existing arm
  that does the same for an undeclared builtin **function**.
- `update_binding` (`gcc/cp/name-lookup.cc`) — treats the binding as absent,
  next to `anticipated_builtin_p`, which is the same idea for functions and
  had no type analogue.
- `lookup_and_check_tag` (`gcc/cp/decl.cc`) — drops it, or an
  elaborated-type-specifier reports `` struct `int` `` as *using typedef-name
  'int' after 'struct'*.

`gcc/testsuite/g++.dg/backtick/escape-positions.C` gains the matching
qualified and type-keyword sections, so a divergence in **either** direction
is now a test failure rather than a probe result.

### This repo

- **[`ops/probes/`](../../probes/) is new, and it is half the point of the
  step.** `escape-positions.sh` is seventy-nine one-line programs in four
  categories run against both compilers; `escape-errors.sh` is twenty-three
  malformed or unresolvable escapes run under `timeout`, because *rejects* and
  *hangs* are the same exit status to a sweep that only counts; and
  `flag-off-parity.sh` is the other half of the claim. `bash`, with bash arrays
  — `zsh` does not word-split, and that has cost this track several sweeps.
  **Two of the three found something in this step**, one of them the step's
  own loop. [`ops/probes/README.md`](../../probes/README.md) says what each
  one asks and why the three questions are different, and `CLAUDE.md`'s Layout
  section now points at the directory with *re-run them after touching the
  escape*.
- `docs/backtick-operator-design.md` — §12 gains the qualified-name paragraph,
  the type-keyword paragraph, the four-category sweep table and a third bullet
  under *"What it cost"*, and its **Printing and diagnostics** paragraph gains
  the one thing GCC does not deliver; §17.8's divergence list is rewritten to
  **one**, with a new closing paragraph for the annotation-token asymmetry and
  a correction to the *"lasted one day"* claim;
  [keyword-escape-coexistence](../../../docs/backtick-operator-design.md#keyword-escape-coexistence)
  gains a dated `Log.` entry.
- Both backtick ledgers, `ops/completion/PLAN.md` (checklist, both Coverage
  tables, Baselines, Status rows), `CLAUDE.md` (the status paragraph, the step
  count, and a Layout entry for `ops/probes/` telling the next agent to re-run
  them), the step file, this handoff.
- `papers/backtick-infix-and-keyword-escape.md` and
  `docs/infix-backtick-operator.org` — the position list, the sweep story
  (now four sweeps), the cost (now three things, not two), the loop and what
  caught it, the divergence list (now one program, and the escape is not in
  it), and the half of the printing ruling GCC does not deliver.

## Verification evidence

### The sweep, before and after, both compilers

`ops/probes/escape-positions.sh`, `-std=c++20 -fbacktick -fsyntax-only`, on
`build-backtick-trunk`'s `clang++` and `gcc-backtick-build`'s `cc1plus`:

| Category | Programs | Clang before | Clang after | GCC before | GCC after |
|---|---|---|---|---|---|
| A. declaration positions | 23 | 23 | 23 | 23 | 23 |
| B. use positions | 16 | 16 | 16 | 16 | 16 |
| C. qualified positions | 25 | **13** | **25** | 25 | 25 |
| D. type-keyword escapes | 15 | 15 | 15 | *see below* | **15** |
| **total** | **79** | **67** | **79** | — | **79** |

`backtick-23`'s binary gives the same 79/79 after the cherry-pick.

**The GCC "before" for category D is deliberately not a number, because a
number there would be one this handoff had not measured.** Category D did not
exist as a script section until after the GCC fix landed; what *was* measured
on the pre-fix binary is **nine of its fifteen programs**, of which **seven
were rejected** — variable, function, alias, class-head, alias-template,
enum-name and namespace-name — and two accepted — parameter and member.
**Eleven type keywords were measured on the pre-fix binary in a plain
declarator-id and every one was rejected** — `int`, `long`, `char`, `bool`,
`void`, `double`, `unsigned`, `signed`, `short`, `float`, `wchar_t` — while
`auto`, `const` and `new`, keywords that are not builtin *type names*, were
accepted. That last line is the cause in one line: the keywords that fail are
exactly the ones `record_builtin_type` binds. The six
D-category programs not run pre-fix are the use positions and the coexistence
case; they would have been rejected, since their declarations were, but that
is an inference and it is written here as one. This is the same habit the row
itself exists to enforce: **in ten consecutive steps a recorded count has
failed re-checking, and the cheapest way to add an eleventh is to publish an
arithmetic result as a measurement.**

### The error paths, under `timeout`

`ops/probes/escape-errors.sh`. Twenty-three programs — malformed escapes in
each of the four position categories, and *well-formed* escapes naming nothing
or naming the wrong kind of thing, which is the shape that made a recovery
loop possible. Run under `timeout 10`; a timeout is a failure, not a slow
test. **46 of 46 (23 × 2 compilers) diagnose and stop.** Before the fourth
arm's correction, `undeclared-qual-type` hung Clang indefinitely — the sweep
is the only reason it was found, because a `-verify` test would simply never
have finished and no existing test covers a qualified escape at all.

Of those forty-six diagnostics, the ones that *name an escaped entity* name it
with its backticks in Clang — `` no member named '`union`' in namespace 'N' ``,
`` no type named '`union`' in 'N::S' `` — and so do GCC's, **except where the
name it prints is a type**. That exception is the row this step opens; see
*Deviations* 4.

### `-ast-print` round-trips everything newly accepted

Twenty-seven programs covering every newly accepted qualified shape, the
out-of-line escaped-class constructor, and the type-keyword escapes: printed
with `-ast-print`, then fed back to the compiler. **27/27 re-parse.** Every
escaped name prints escaped —
`` N::`union` g; ``, `` using X = N::`union`; ``,
`` `namespace`::`union` g; ``, `` typename T::`union` m; ``,
`` `union`::`union`() { } ``, `` struct `int` { ... } ``,
`` using `char` = double; ``. **The printers needed no change** — the shared
`printIdentifierSpelling` and `NestedNameSpecifier` work
[escape-name-positions](escape-name-positions.handoff.md) did already covers
every one of these, which is worth recording because that step's own lesson
was that a new name position is usually a new printing surface. These are not:
they are old printing surfaces reached by new parses. The round trip is pinned
in-tree by
`clang/test/Parser/backtick-escape-positions.cpp`'s third RUN line, which
re-parses the file's own `-ast-print` output and passes.

### Flag-off parity, measured byte-identically, on both compilers

`ops/probes/flag-off-parity.sh`. Two programs containing **no backtick** — one
well-formed, one ill-formed — covering every construct whose lookahead or
lookup moved: namespace, namespace alias, using-directive, class-head,
base-specifier, mem-initializer, scoped and unscoped enum, all three kinds of
template parameter, alias and alias-template, concept, label and `goto`,
three-component nested-name-specifiers, qualified types in a declaration, a
`sizeof`, a `static_cast` and a `typename`, out-of-line member and constructor
definitions, and every builtin type name spelled as a keyword.

```
                              flag on vs flag off      flag off vs pristine
clang  -fsyntax-only ok        IDENTICAL (0 lines)      IDENTICAL
clang  -fsyntax-only bad       IDENTICAL (50 lines)     IDENTICAL
clang  -ast-print              IDENTICAL (85 lines)     IDENTICAL
clang  -ast-dump               IDENTICAL (331 lines)    IDENTICAL
cc1plus -fsyntax-only ok       IDENTICAL (0 lines)      IDENTICAL
cc1plus -fsyntax-only bad      IDENTICAL (60 lines)     IDENTICAL
cc1plus generated assembly     IDENTICAL (282 lines)    differs in 2 lines
```

`backtick-23`'s one failure is `Clang :: Format/dump-config-objc-stdin.m`,
the permanent [`stray-clang-format-config`](../../BACKLOG.md#stray-clang-format-config).
Re-confirmed rather than budgeted: the pristine `build-main` `clang-format`
also dumps `Language: Cpp` from stdin, because it walks up to
`/home/sdowney/src/.clang-format`, a 2018 file outside any repo. Both rows are
exactly the Baselines.

`-ast-dump` is compared with `0x[0-9a-f]+` normalized; that is allocation
addresses and is the only thing that differs run to run. The pristine controls
are `~/src/llvm/build-main/bin/clang++` and
`~/bld/gcc/build-trunk/gcc/cc1plus`. **The two assembly lines are the
`.ident` build-date string** (`20260906` against `20260808`) and nothing else
— checked on a one-line file. Neither pristine binary shares an upstream
revision with its feature binary, so that column is a weaker control than the
first; it happens to be clean anyway, everywhere except the build stamp.

### ABI, on the hardest name the feature has

`` int g (int p, `int` q) `` mangles as **`_Z1gi3int` in both compilers** —
GCC's assembly `.globl _Z1gi3int`, Clang's IR `define ... @_Z1gi3int`. And in
the same translation unit `int x = 0;` still declares a builtin `int`,
`sizeof(int)` is still 4, and `typedef int myint;` still works. That is §12's
ABI paragraph — *the escape yields an ordinary identifier* — demonstrated on
the one name where GCC previously had a second entity of its own.

### Gates

```
backtick-trunk   check-clang    EXIT=0   54115 / 48229 / 0 failed   XFAIL 27
backtick-23      check-clang    54349 / 48507 / 1 failed   XFAIL 27
GCC   dg.exp=g++.dg/backtick/*.C   EXIT=0   110 passes / 0 failures   (was 110; +0)
GCC   dg.exp  (all of g++.dg)  75745 passes / 287 XFAIL / 0 unexpected failures
```

The GCC backtick delta is **zero** and that is correct: the two new sections
went into the existing `escape-positions.C`, and its `dg-options` pins one
standard, so dejagnu counts the file once however many declarations it holds.
The wider `dg.exp` run is **not the step's required gate**. It ran to
completion — `g++.sum` written, **75745 expected passes, 287 expected
failures, 345 unsupported, 0 unexpected failures** — and it was started
because `update_binding` and `duplicate_decls` are core name lookup and a
measurement there is worth more than an argument. **What it can establish is
bounded, and saying so is better than quoting a number as though it proved
more**: every guard this step adds to GCC is `flag_backtick && …` and no test
in `g++.dg` passes the flag, so the only failure it could ever have reported
is a build-level mistake. The zero is the reading, and it is a smaller reading
than the size of the number suggests.

**This paragraph said "stopped short" for about ten minutes.** The run
finished while a `pkill` aimed at it was in flight, and the first version of
this handoff recorded the partial count as final. Caught by looking at
`g++.sum` instead of at the process table — which is the same failure the step
spent all day on, a status read where an output should have been.

### Documents

- Both papers build **both formats**, `EXIT=0`, **0 missing characters**
  (`grep -ci "missing character"` over the full pandoc/LaTeX output → 0).
  `papers/generated/` removed afterwards; it is build output.
- `lexcheck --register formal` on the paper: two warnings, both pre-existing
  (`, not Y` ×14 — unchanged — and one contraction). The `exactly` warning
  present before is gone, and `exactly` still occurs 12 times: the added words
  moved the *rate* under the threshold. `--register blog` on the `.org`:
  **clean**, 3739 prose tokens.
- Every link added or changed by this step resolves: **98 checked, 0 broken**.
- Public text swept for internal identifiers: no slug, no ledger name, no path
  under `ops/` in either deliverable's new text. The one path either paper now
  gestures at is *"checked into the repository"*, unnamed.

## Deviations from the step file

1. **The step file said "two more call sites in that idiom" was the likely
   shape, following the row.** It was five arms and three supporting changes,
   and the supporting changes are where the difficulty is. The row's *"two
   Clang sites, one shape"* had the shape right — the escape is reached in a
   qualified name only where the name is read as an unqualified-id — and the
   count wrong by more than double.
2. **`escape-type-keyword-binding` was fixed rather than surfaced.** The brief
   allowed for it not being fixable at acceptable cost, and its own ledger row
   expected shadowing. It is three call sites. The row's closing judgement —
   *"the least valuable corner of the hatch"* — is contradicted in the ledger
   rather than quietly dropped: it is true about likelihood and irrelevant to
   the claim, since the position it failed in is the *first row* of §12's
   table.
3. **A fourth probe category and a third probe script were added that nothing
   asked for**, and both earned their place in the same run: the type-keyword
   category is the axis the two-month-old divergence hid along, and the
   error-path script is what caught this step's own infinite loop.
4. **One thing found was surfaced and not fixed, deliberately, and it is the
   one place this step declined the "fix what is fixable" instruction.**
   [`escape-type-name-spelling`](../../gcc/DEVIATIONS.md#escape-type-name-spelling)
   is a **diagnostic** divergence: GCC escapes the name of a *declaration* —
   which is what [`escape-diagnostic-spelling`](../../gcc/DEVIATIONS.md#escape-diagnostic-spelling)
   fixed, in `dump_decl_name`, "GCC's one funnel for the name of a
   declaration" — and prints the name of a *type* bare, because a class or
   enum type is printed by `dump_aggr_type`, which ends at
   `pp_cxx_tree_identifier` and never reaches that funnel. So GCC will report
   `` 'struct union' has no member named '`new`' ``: one sentence, two names,
   one escaped and one not, from two printers. Clang escapes both.

   It is not the same change as the two rows this step closed — those are name
   lookup, this is the diagnostic printer — and **it is the third time this
   feature has touched GCC's error printer, both previous first builds being
   wrong in the same direction**: a program containing no backtick started
   reporting against a backticked spelling. A funnel one layer out has more
   callers, not fewer, and the guard that makes it safe is a claim about which
   identifiers can only have come from an escape — airtight for a declarator-id
   and unchecked for a type name reached through `TYPE_NAME`. The measurement
   is done and is in the row; the fix needs its own step, its own flag-off
   parity run and its own negative test. **It changes no program's
   acceptance**, which is why §17.8's list is still one, and it is surfaced in
   §12's *Printing and diagnostics*, in §17.8's closing paragraph and in both
   papers rather than left in the ledger.

## Discoveries affecting later work

- **An annotation token is matched against the cached token stream by source
  location, and that is now a standing constraint on this feature.** Anything
  that folds a name into an annotation — `annot_typename`, `annot_cxxscope`,
  `annot_template_id` — must span the escape's backticks, not the keyword.
  `AnnotatePreviousCachedTokens` does not assert when it finds *no* match; it
  silently declines the optimization, which is harmless. It *does* corrupt
  when it finds the **wrong** match, which is what an annotation beginning at
  the keyword does: it matches the keyword's cached token and leaves the
  opening backtick in front of the annotation. Failures from this are
  backtracking-only and look like a stray `` ` `` appearing from nowhere.
- **`PP.EnterToken` is not safe under backtracking and `AnnotateScopeToken`
  already knew.** Its `if (PP.isBacktrackEnabled()) PP.RevertCachedTokens(1);
  else PP.EnterToken(Tok, true);` is the idiom, and it was in the file the
  whole time.
- **A qualified type name is read in three places in Clang and one in GCC.**
  That asymmetry is the same one as §§17.5–17.7 and it will recur: a parser
  that annotates and backtracks has more surfaces than a parser that does not.
- **`isConstructorDeclarator` decides on the first token after the scope
  specifier, and a constructor named by an escape had been working by
  accident.** Any future change that makes the decl-specifier path *more*
  willing to resolve a qualified name will break it again, silently, in
  exactly one program shape.
- **GCC binds builtin type names at global scope under their keyword
  spelling**, and the C++ front end's own comment says the bindings should not
  exist. `IDENTIFIER_KEYWORD_P (DECL_NAME (decl))` is what separates them from
  the non-keyword builtin names that ordinary code may redeclare.
- **A recovery path that does not consume is an infinite loop waiting for a
  new token kind.** `ParseDeclarationSpecifiers`' unresolved-qualified-name
  recovery is implicit-int; it terminated for every existing token only
  because the arms in front of it bailed out first. This is the second time a
  behaviour of this feature turned out to be **working by accident** — the
  other is `isConstructorDeclarator` above — and both accidents were the old
  code giving up early on a backtick.
- **A coverage sweep and an error sweep ask different questions, and the
  second one is the one that finds hangs.** *Rejects* and *never finishes* are
  indistinguishable to a script that only reads exit status, and a `-verify`
  test that never terminates does not fail either. `escape-errors.sh` runs
  everything under `timeout` and treats a timeout as a failure. It found the
  loop, and reading its *output* rather than its status found
  [`escape-type-name-spelling`](../../gcc/DEVIATIONS.md#escape-type-name-spelling).
- **The sweep has now caught something on all five occasions it has been
  run**, and three of the five were after somebody had written down that the
  coverage was complete. It caught two things this time. It is in the repo now.

## Forward notes — there is no next step

`ops/completion/PLAN.md` has twenty boxes and all of them are `[x]` or `[—]`.
`docs/open-decisions.md` has no open question. The three deviation ledgers
read **0 / 1 / 0** open rows, the one being
[`escape-type-name-spelling`](../../gcc/DEVIATIONS.md#escape-type-name-spelling),
which is measured, surfaced in both papers, and an implementer's question
rather than the author's.

What is left, for whoever picks this up:

- **Nothing is pushed.** `backtick-trunk`, `backtick-23` and GCC `backtick`
  are each one commit ahead of their remotes on top of what was already
  unpushed; this repo is ahead by the step's commits. All four branches track
  `ceridwen` **and** `origin` and both need a push. That is the maintainer's
  call.
- **`unicode-operators-experiment` does not have this commit.** It is current
  as of `e09b559d631c`, which predates `bd8790f9d0ef`. That is a forward-port
  and belongs to whoever next merges `backtick-trunk` into it.
  **`unicode-operators-upstream` must never receive it.** This one should be
  clean where the last was predicted not to be and was: it touches
  `Parser.cpp`, `Parser.h`, `ParseDecl.cpp`, `ParseExprCXX.cpp` and
  `ParseTentative.cpp`, and the Unicode side has arms in the last two —
  `tok::user_operator` declarator arms in `ParseExprCXX.cpp` and a Unicode arm
  in `ParseTentative.cpp`'s `isCXXDeclarationSpecifier`, which is the same
  switch this step edits. **Expect a conflict in that switch**, and resolve it
  *keep both*: the Unicode arm and the backtick arm are different `case`
  labels.
- **The three upstream reports are still drafted and unfiled**, in
  [`upstream-drafts/`](../upstream-drafts/README.md). The author's.
- **Section 9's comment in `unicode-operator-precedence.cpp` is still stale**
  on all four branches, as three handoffs have now recorded.

## Open risks / TODOs

- **[`escape-type-name-spelling`](../../gcc/DEVIATIONS.md#escape-type-name-spelling)
  is open, measured and unowned.** See *Deviations* 4. It is the only thing
  either compiler does differently under the flag, and it is text rather than
  acceptance.
- **The negative-test gap `escape-name-positions` recorded is closed on the
  Clang side and open on the GCC side.**
  `clang/test/Parser/backtick-escape-diagnostics.cpp` now covers a malformed
  and an unresolvable escape in a qualified position, including the loop.
  `g++.dg/backtick/escape-diag.C` does not; the GCC behaviour is right — the
  error probe checks it every run — but nothing in the suite pins it.
- **The GCC fix removes the builtin type's global binding from a translation
  unit that escapes that keyword.** `record_builtin_type`'s comment names one
  consumer, `identifier_global_value` in `c-common.cc`. Nothing in the C++
  front end reached it in the runs above, and the flag-off parity is exact,
  but a TU that both escapes `` `int` `` *and* drives that consumer is
  untested — there is no such program in either suite, because there is no
  such consumer in C++.
- **`Parser::escapeTokenLength` computes a spelling length from two file
  locations and falls back to the keyword's own length when they are not in
  one file.** A macro-expanded escape therefore gets a token whose length does
  not span its backticks. No test covers a macro-expanded escape in a
  nested-name-specifier, and it is not obvious the feature should support one.
