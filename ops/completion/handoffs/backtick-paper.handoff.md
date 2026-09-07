# Handoff — backtick-paper — D4307R0, and the blog version

- **Status:** **DONE (gate passed).**
- **Branch / commit:** no branch. `unicode-operators` in *this* repo only —
  a `docs:` commit (`papers/backtick-infix-and-keyword-escape.md`, `docs/infix-backtick-operator.org`
  + `.meta`, `docs/backtick-operator-design.md`) and an `ops:` commit (the two
  ledgers, the plan, this handoff). **Nothing was built and no feature branch
  was touched.** Four pre-built compilers were *read and run* to re-derive
  every claim below — `~/src/llvm/build-backtick-trunk/bin/{clang,clang++,clang-format}`,
  `~/src/llvm/build-unicode/bin/clang++`, and
  `~/bld/gcc/gcc-backtick-build/gcc/cc1plus`; none of their worktrees was
  modified (`git status --porcelain` clean in each, before and after).
- **Date / agent:** 2026-09-07.
- **Closes:** nothing in `ops/BACKLOG.md`. This is the deliverable.
- **Opens:** four rows, none owned —
  [`escape-name-positions`](../../DEVIATIONS.md#escape-name-positions),
  [`type-slot-aggregate-shape`](../../DEVIATIONS.md#type-slot-aggregate-shape),
  [`escape-alias-name-parity`](../../gcc/DEVIATIONS.md#escape-alias-name-parity),
  [`escape-diagnostic-spelling`](../../gcc/DEVIATIONS.md#escape-diagnostic-spelling).
  **The ledgers no longer read zero open rows**; see *Open risks*, because
  [unicode-paper](../steps/unicode-paper.md)'s closing gate asserts they do.

---

## The gate is a count: 57 claims checked, 5 failed

The step file's gate is *"every 'we implemented X' claim has been checked
against the tree in this step, and the handoff says how many were checked and
whether any failed."* Every claim in the paper and in the `.org` was re-derived
from a running compiler rather than quoted from a handoff — which is this
track's house standard, and it earned its keep again.

**Clang, on `backtick-trunk`'s build (49 checks, 3 failures).** Basic
desugaring; left association; symmetric prefix binding (`` -1 `neg` -2 ``);
binding tighter than `*`; a qualified-name slot; a named lambda *and* a
lambda-expression written directly in the slot; the type slot for a plain
class, for `std::pair` under CTAD, and for a user deduction guide; bare
nesting and parenthesised nesting, **69 and 47**, the design doc's own numbers;
ADL by augmentation, by hidden friend, and through a template-id slot; a
qualified slot and a function-pointer slot; the escape in seven positions;
`-ast-print` round-tripping the escape, the infix form and the constructor
type slot, plus the printed file re-parsing; `-ast-dump` keeping the bare
identifier; a diagnostic naming the entity `` `new` ``; the wrapper's source
range spanning the written expression (`<col:9, col:17>` against the inner
call's `<col:12, col:15>`); the fold rejection; the C-mode gate; flag-off
behaviour; clang-format's spacing and its break policy at `ColumnLimit: 40`;
all six motivation programs, `-Wall -Wextra` clean, with the ranges comparison
returning **120 = 120** through `|` and through `` `pipe` ``; and analyzer
parity, both forms silent at the default configuration and **note-for-note
identical** with `suppress-null-return-paths=false`.

**The within-compiler control was re-measured, not quoted.** On
`~/src/llvm/build-unicode/bin/clang++` (the experiment branch, which carries
both features and has *not* taken the ADL fix), one file, one build, one
invocation:

```
static_assert(__is_same(decltype(pick(u, u)), AdlTag));   // the call     — passes
static_assert(__is_same(decltype(u ⊞ u),      AdlTag));   // Unicode      — passes
auto op_p = u `pick` u;   // backtick — error: no viable conversion from 'U' to 'double'
```

The backtick form resolves `::pick(double, double)` by ordinary lookup while
the Unicode operator beside it picks up `ns::pick` by ADL. That is the control
the paper now argues from, and it is a live measurement rather than a
retelling. The fixed `backtick-trunk` binary binds the ADL candidate in all
three shapes.

**GCC, on `cc1plus` (8 checks, 2 failures).** Core semantics including the same
69 / 47; the escape in declarator-ids, member access and primary position; the
escape rejected in class-head, enum and namespace names; the type slot
rejected (*no match for call to '(Pt)(int&, int&)'*); the fold rejected;
flag-off *stray '`' in program*; `` 1 `(`new`)` 2 `` accepted and
`` 1 ``new`` 2 `` rejected — the second with a diagnostic that is, to the
word, Clang's (*expected expression between backticks* / *expected expression
between '`' and '`'*).

**One methodological trap, recorded because it silently inverts results.** In
`zsh`, an unquoted `$CMD` holding a command line is **not** word-split, so
`if $G file` runs a single nonexistent program and reports failure for every
probe. My first GCC sweep came back *"GCC rejects everything"*, which is
wrong. Write the command out, or use `${=G}`.

### The five failures

| # | Claim | What is true |
|---|---|---|
| 1 | the paper's [lex.name] wording — *"wherever the grammar uses identifier as a terminal"* — and its example `` struct `union` { }; `` | **Neither** compiler takes the escape in a *class-head-name*, *enum-name*, *namespace-name* or template parameter name. [`escape-name-positions`](../../DEVIATIONS.md#escape-name-positions) has the position table |
| 2 | *"a transparent AST wrapper so `-ast-print` round-trips the surface syntax"* | An **aggregate** type slot prints as the desugaring: `` a `Agg` b `` → `Agg(a, b)`. Sema builds a `CXXFunctionalCastExpr` for parenthesised aggregate initialisation, which is a fourth inner shape and no arm recognises it |
| 3 | §17.5's *"the wrapper node spans the written expression"* | Same shape, same cause: `` a `Agg` b `` reports `<col:13, col:16>`, the operator slot. Recorded with #2 as [`type-slot-aggregate-shape`](../../DEVIATIONS.md#type-slot-aggregate-shape) |
| 4 | *"Both are implemented … in two independent compilers"*, of the escape | `` using `class` = int; `` is accepted by Clang and rejected by GCC — the **second** place the two accept different programs, where §17.8 said there was one. [`escape-alias-name-parity`](../../gcc/DEVIATIONS.md#escape-alias-name-parity) |
| 5 | [keyword-escape-printing](../../../docs/backtick-operator-design.md#keyword-escape-printing), ratified by the author 2026-09-06 | Clang delivers it; **GCC prints the bare keyword** — `note: initializing argument 1 of 'void new(int)'`, a spelling no program under the flag can contain. This is the question [clang-paper-truth](clang-paper-truth.handoff.md) left as *"cheap to check with the built `cc1plus`; nobody owns it"*. Now checked. [`escape-diagnostic-spelling`](../../gcc/DEVIATIONS.md#escape-diagnostic-spelling) |

Five failures, four rows: #2 and #3 are one defect seen from two sides. **None
of them blocks the paper** — the paper now states each one — and none is more
than a small unwritten arm, except the first, which is also a scope question
the author owes and which [keyword-escape-coexistence](../../../docs/backtick-operator-design.md#keyword-escape-coexistence)'s
Status has said was open since it was written.

## The paper could not produce a PDF, and nobody had noticed

`make backtick-infix-and-keyword-escape.pdf` failed with `! Undefined control sequence. l.1443 \pnum`.
It is not LaTeX and it is not the wording: the paper's front matter carried a
`header-includes` key holding an HTML `<style>` block, and a `header-includes`
in the document **replaces** the one `wg21/data/metadata.yaml` supplies, which
is where `\pnum` — and the rest of the wg21 preamble — is defined. The
`{=html}` block now sits at the top of the body, later in the cascade than the
highlighter's own rule, so it still wins; both formats build.

`papers/unicode-mathematical-operators.md` is unaffected because it uses no `{.pnum}` span. **It will
be affected the moment it gains wording**, which is [unicode-paper](../steps/unicode-paper.md)'s job.

## What changed, and where

### `papers/backtick-infix-and-keyword-escape.md`

- **Front matter** — `header-includes` removed, the style block moved into the
  body with a comment saying why. This is the PDF fix.
- **The proposal** — the slot is *"an arbitrary expression parsed as an
  assignment-expression, or a type-name, which constructs"*. The paper
  described one production and its own wording had three.
- **The productions** — the grammar block gains *simple-type-specifier* and
  *typename-specifier*, matching [expr.backtick], plus the sentence saying
  the type reading is a rule and not a consequence. The paper contradicted
  itself here.
- **The productions, fold paragraph** — stops asserting `expected expression`,
  which is Clang's text; GCC says *expected binary operator before '`' token*.
  The decision is unchanged and still stated.
- **The escape yields an ordinary identifier** — a new paragraph carrying
  [keyword-escape-printing](../../../docs/backtick-operator-design.md#keyword-escape-printing):
  the escape is the name's spelling, printers and diagnostics put it back, the
  dump keeps the bare word as the evidence that the name is ordinary, and GCC
  diverges.
- **Implementation experience — rewritten, and it is most of this step.**
  - The branch links were **broken**: there is no branch named `backtick` on
    any LLVM remote. Now `backtick-23` and `backtick-trunk`, named as two
    branches carrying one feature diff, with the test directories corrected
    (`AST/`, `Analysis/` and `CIR/CodeGen/` were missing) and GCC's module
    pair named.
  - The re-sync as a maintenance datum: 2158 upstream commits, every added and
    removed line unchanged across the move.
  - **New: *What is implemented, and what is not*** — the escape's real
    position set, the type slot's single-compiler evidence, the two
    round-trip exceptions, and the two-entry list of programs the compilers
    treat differently.
  - **Rewritten: *Argument-dependent lookup, which both implementations got
    wrong*.** The old section said the divergence was GCC's and that the
    Clang implementation was the one that got it right. That was false when it
    was written. It now says both got it wrong the same way, gives GCC's two
    goes and Clang's silent wrong bind, then the **within-compiler control** —
    one build, one machine, one author, one difference — and the near-miss,
    with *augmentation* named as the test to ask an implementation for.
  - **New: *What the AST node costs, and which compiler pays it*** — the seven
    analyzer sites with the seventh created by meeting the other six, the
    2-versus-8 path notes, and §17.8's point that GCC pays none of it by
    construction and gets none of the fidelity it buys.
  - **New: *The gate is the part that fails quietly*** — the C-mode
    acceptance and GCC's fall-through arms, with the check that finds both:
    byte-identical output flag-on and flag-off on a program that never
    mentions the feature.
  - ***What the parsers confirmed*** keeps the nesting-is-chaining argument and
    gains the deleted diagnostic — carried through most of the implementation,
    never once fired, removed rather than made to fire.
- **Voice pass.** `lexcheck --register formal` had **six errors before this
  step** and has none after: `footgun`, `earns its keep`, `earn`/`earns`
  (the transactional frame, zero in his prose), `idiom` ×7 and `precisely` ×2
  against a ceiling of one. The three remaining warnings (`, not Y` tails ×14,
  `exactly` ×12, one contraction) are all at or below their pre-step counts —
  they are the paper's existing texture, not this step's.

### `docs/infix-backtick-operator.org` and `.meta`

- **The false consequence, in the register of the blog**: *"A type name is
  callable, so a type in the slot constructs"* is replaced by the account of
  getting it wrong — a bare type name is not an assignment-expression, so the
  "consequence" contradicted his own grammar and the first implementation
  rejected every type-slot shape with three different diagnostics.
- **Three new sections** — *What I got wrong* (the ADL story, the qualified-name
  test, the within-compiler control), *What the AST wrapper costs* (including
  both leaked flag gates), *What isn't done yet* (the escape positions, the
  alias divergence, the Clang-only type slot).
- Branch links corrected the same way as the paper's; the re-sync datum added.
- **Voice.** `lexcheck --register blog` is **clean**. It was not: one
  wager-frame error (*"earn a place in a library"*), `rather` and `exactly`
  at 3× base, and em-dashes at **114/10k** against a blog base of ~0 and a
  paper rate of 20. Now **20/10k**, the dashes converted to parentheses,
  commas, semicolons and full stops rather than deleted.
- `.meta` date 2026-06-29 → 2026-09-07. The content moved substantially, which
  is the step file's own condition.

### `docs/backtick-operator-design.md`

Three corrections, all made because the paper is written from this document
and would otherwise have inherited them:

- **§17.8** — *"the one place the two implementations genuinely disagree"* is
  **two**, both named, plus the diagnostic-spelling divergence kept explicitly
  apart because it is text and not accepted programs.
- **§17.5** — *"Three shapes have to be recognised"* is the count of the shapes
  that *were* recognised, not of the shapes Sema can build. The general
  statement is added: every initialisation form Sema can produce for
  `T(x, y)` is another arm, and a missing arm is silent, because it prints the
  desugaring.
- **§12** — the position list is labelled as the *implemented* list and gains
  the measured coverage, with the scope question stated: an escape hatch whose
  purpose is that a future keyword stops breaking code has to reach the
  positions where broken code names things, and `struct module { };` is one.
- **§3 [keyword-escape-printing](../../../docs/backtick-operator-design.md#keyword-escape-printing)**
  gains a dated `Log.`: the ruling has single-compiler evidence.

## Verification evidence

### Builds

```
$ make -C papers backtick-infix-and-keyword-escape.html backtick-infix-and-keyword-escape.pdf
  generated/backtick-infix-and-keyword-escape.html   154 KB
  generated/backtick-infix-and-keyword-escape.pdf    154 KB, 18 pages     # did not build before this step
```

`emacs --batch … org-html-export-to-html` on the `.org` completes with no
errors (only the standard `htmlize.el` fontification warnings), and the export
carries the new section headings and the corrected branch names. The generated
HTML was deleted afterwards; `docs/` is source only.

### Public text stands alone

Two sweeps over `papers/backtick-infix-and-keyword-escape.md`, `docs/infix-backtick-operator.org` and
the `.meta`:

1. The retired-serial and internal-path forms —
   `DEV-*`, `B\d\d`, `BL\d\d`, `D\d`, `S\d\d`, `G\d\d`, `U\d`, `U§`, `§1\d`,
   `ops/`, `BACKLOG`, `DEVIATIONS`, `handoff`, `PLAN.md`, `slug` — **one hit,
   `.. slug:` in the Nikola `.meta`, which is a URL slug and not an
   identifier.**
2. Every **live** slug in the repo, harvested from the three ledgers, the
   backlog, the two design docs, `docs/open-decisions.md` and
   `ops/completion/steps/` — **143 candidates, zero real hits.** The six
   matches are English words that happen to be slugs elsewhere
   (`qualified`, `single`, `template`, `variable`, `primary-expression`, and
   `evaluation-order` in the phrase *"adds no evaluation-order rule"*).

The companion Unicode work is referred to twice, in the ADL section of each
deliverable, as *"user-defined operators spelled with Unicode symbols, a
companion design not proposed here"* — the thing, described, with no document
number and no file path, because the control is unreadable without saying what
the second feature was.

### Links

**2339 local Markdown links** across every tracked `.md` outside
`papers/wg21/`, **0 broken** — file existence plus GitHub-style anchor slugs,
whitespace runs not collapsed, links inside code spans and fences excluded.
The four new ledger anchors resolve from all seven places that link to them.

## Deviations from the step file

1. **The step file's list of *what has changed under the paper* is
   incomplete, and the missing item was the largest.** It names
   clang-paper-truth's three fixes, the type slot, the back-end symmetry, the
   ADL finding and the GCC parity note. It does not say that the paper's
   *existing* ADL paragraph asserted the opposite of the truth — that the
   defect was GCC's and Clang was the reference. Rewriting it, rather than
   appending the finding beside it, is the substance of the step.
2. **Four rows were opened.** The step file expects the paper to *state* what
   the tracks found, not to find more. Reading the paper line by line against
   the compilers is what the gate asks for, and it produced five failures.
   Per the instruction that a genuine question is recorded as a row rather
   than left in prose, they are rows.
3. **`docs/backtick-operator-design.md` was edited**, which the step file
   permits (*"if the design doc is the one that is wrong, fix it first and say
   so"*) and here required: two of the paper's inherited claims come straight
   from §17.5 and §17.8.
4. **A build-system fix was made.** Not in the step file; the gate says the
   paper renders, and it did not.
5. **A voice pass was made over passages this step did not otherwise touch** —
   the nine impostor and rationed words above. They are errors under the
   skill's own rules and the file is this step's deliverable.

## Discoveries affecting later steps

- **A `header-includes` key in a wg21 paper's front matter silently disables
  the LaTeX preamble.** The HTML target keeps building, so the breakage is
  invisible until someone asks for a PDF. If a paper needs per-document HTML,
  put it in a `{=html}` block in the body.
- **`zsh` does not word-split an unquoted parameter**, so a `$CMD` holding a
  command line fails as one nonexistent program. Every probe in a loop then
  reports failure, which looks exactly like a feature that does not work.
- **Probing positions is cheap and finds things a test suite does not.**
  Eleven one-line programs through two compilers, about ten minutes, produced
  four of this step's five failures. Neither compiler's test suite contains a
  negative test for any of those positions, so nothing was failing.
- **A round-trip claim is a claim about every node Sema can build**, not about
  the nodes the printer was written against. The aggregate type slot was
  reachable from the paper's own example set (`` a `Pt` b `` with an aggregate
  `Pt`), and both the printer and the range recovery miss it.
- **`~/src/llvm/build-unicode` still has the pre-fix backtick slot**, which is
  what makes the within-compiler control reproducible today. Whoever
  eventually forward-ports [clang-slot-adl](clang-slot-adl.handoff.md) to
  `unicode-operators-experiment` destroys the ability to demonstrate it on a
  live binary. The measurement above is the record; take a copy of the output
  before that merge if anyone wants it again.

## Forward notes for the NEXT step — [unicode-paper](../steps/unicode-paper.md)

Written after reading its step file.

- **Its closing claim is no longer true, and it should say so rather than
  assert it.** *"All three deviation ledgers are empty of unreconciled rows"*
  was true for one day. This step opened four `OPEN` rows —
  [`escape-name-positions`](../../DEVIATIONS.md#escape-name-positions),
  [`type-slot-aggregate-shape`](../../DEVIATIONS.md#type-slot-aggregate-shape),
  [`escape-alias-name-parity`](../../gcc/DEVIATIONS.md#escape-alias-name-parity),
  [`escape-diagnostic-spelling`](../../gcc/DEVIATIONS.md#escape-diagnostic-spelling).
  **All four are backtick-side and none is yours.** The honest closing
  sentence is that every step is checked, both papers are finished, and four
  rows opened by the last paper pass remain unowned — which is a better
  ending than a false one.
- **The PDF trap is waiting for you, and only for you.** `papers/unicode-mathematical-operators.md`
  builds a PDF today because it has no `{.pnum}` span. Your step adds wording.
  Check `papers/unicode-mathematical-operators.md`'s front matter for a `header-includes` key
  **before** you write wording, and build the PDF, not just the HTML — the
  HTML target will not tell you.
- **Do not re-tell the ADL control.** `papers/backtick-infix-and-keyword-escape.md` now carries it from
  the backtick side, describing your feature as *"user-defined operators
  spelled with Unicode symbols, a companion design not proposed here"*. From
  your side the same fact is one clause, not a section: the Unicode operator
  inherited ADL from its first commit because its slot never becomes an
  expression — which is
  [`infix-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost)'s
  measurement, already in U§8, and is why the non-member half was free. Two
  papers narrating the same anecdote at length reads as one paper split.
- **The `.org` counterpart exists** — `docs/unicode-infix-operators.org` and
  its `.meta`, both present. Mine's `.meta` date moved to 2026-09-07; consider
  whether the two posts should be dated apart, since they will publish as
  neighbours.
- **`LLVM-ISSUE-PENDING` is still in three places** — `papers/unicode-mathematical-operators.md`'s
  Acknowledgments and `docs/unicode-operators.md` twice. It is yours to
  decide what a paper does with an unfiled report; the author declined to file
  it, so *"reported upstream as PENDING"* is not a claim the paper can make.
- **The separable-fates grep needs its base pinned**, per
  [reconcile-remainder](reconcile-remainder.handoff.md): the two-dot form
  against `upstream/main` returns six hits that are all upstream's drift.
  Use `git log -p upstream/main..unicode-operators-upstream | grep -ic
  backtick`, or diff against the branch base `d28193fa1ff6`.
- **The voice numbers to expect.** `papers/unicode-mathematical-operators.md` has not had a lexcheck
  pass in this track. Mine had six errors before I touched it, all of them
  in prose no step had ever revisited. Run
  `python3 ~/.claude/skills/voice/scripts/lexcheck.py papers/unicode-mathematical-operators.md
  --register formal` early — it is thirty seconds — and the same for the
  `.org` with `--register blog`, where the tell to expect is em-dash
  saturation.

## Open risks / TODOs

- **Nothing is pushed, and the paper now links to branch names that exist on
  the remote but are five commits behind.** `origin/backtick-23` and
  `origin/backtick-trunk` are real; both local branches are ahead by 5, and
  the GCC `backtick` branch is ahead of `origin/backtick` by 2170 commits and
  will need `--force-with-lease` after the re-base. The paper says the forks
  are public, which is true, and a reader following the links today gets the
  pre-re-sync GCC branch. **Pushing is the maintainer's call and should happen
  before the paper is circulated.**
- **The four new rows have no step and no owner.** Three are one parser arm
  each; the fourth
  ([`escape-name-positions`](../../DEVIATIONS.md#escape-name-positions))
  carries a design question for the author about the escape's intended
  coverage. None blocks either paper.
- **The paper's [lex.name] example declares a class with an escaped name**,
  which neither prototype accepts. It is kept, because the wording proposes
  the broad form and the implementation-experience section now says which
  positions are prototyped — but a reviewer who copies that example into a
  branch will find it rejected, and that is a real risk of the choice.
- **`~/src/llvm/build-cir-scratch`, `build-unicode*` and both backtick build
  dirs were read, never written.** No `ninja`, no `make` outside `papers/`.
