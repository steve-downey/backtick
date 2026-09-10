# Handoff — unicode-paper — the Unicode paper, its number, and the blog version

- **Status:** **GREEN (gate passed; all four bullets).** It stood BLOCKED on
  the author for the document number earlier the same day — which is what
  success looks like for this kind of dependency under this track's rules —
  and the author answered: **D4345R0, *Extending C++ with Unicode Mathematical
  Operators***, together with authorisation to rename the backtick paper as
  well. Both are applied, so the box is ticked by a resumption of *this* step,
  the same shape as [decision-brief](decision-brief.handoff.md) and
  [mangling-abi](mangling-abi.handoff.md). **`ops/completion/PLAN.md` now has
  no unchecked box.**
- **Branch / commit:** no branch. `unicode-operators` in *this* repo only —
  `cdbc86e` (`docs:` — the paper, `docs/unicode-infix-operators.org` + `.meta`,
  one typo in `docs/unicode-operators.md`), `30c5385` (`ops:` — the plan and
  this handoff, while the step was blocked), then the number-and-rename pair
  once the author answered: a `docs:` commit carrying both `git mv`s, the two
  front-matter fields, every path reference repo-wide and `CLAUDE.md`, and an
  `ops:` commit correcting the plan and this handoff to green. **Nothing was built and no feature branch
  was touched.** Three pre-built compilers were *read and run* —
  `~/src/llvm/build-unicode-upstream/bin/{clang,clang++,clang-format,llvm-cxxfilt}`,
  `~/src/llvm/build-unicode/bin/clang++`, `~/src/llvm/build-cir-scratch/bin/clang++`
  — plus `~/src/llvm/build-backtick-trunk/bin/clang++`, the system `g++ 15.2.0`
  and `c++filt 2.46`, and `~/src/llvm/build-main` read once as a stale oracle.
  Every worktree was `git status --porcelain` clean before and after.
- **Date / agent:** 2026-09-07.
- **Closes:** nothing in `ops/BACKLOG.md`. This is the deliverable.
- **Opens:** **nothing.** No ledger row. The Unicode ledger was clear when this
  step started and is clear now.

---

## The number, the title, and why neither file is named after a number

**`document: D4345R0`**, **`title: "Extending C++ with Unicode Mathematical
Operators"`**. The subtitle is kept — *Declaring `operator⊞`, and what an
implementation says about it* — because the author supplied a title and did
not ask for the subtitle to go, and it is the half that says what the paper
does.

**The filename is a judgement and here it is.** `~/.claude/CLAUDE.md` is
explicit: a paper file is named by *name*, never by number —
`papers/algorithms-for-trees.md`, never `papers/D4322R0-….md` — because the
WG21 upload system renames whatever is uploaded, a name is what someone finds
later, and the number belongs in the front matter and the prose. So renaming
`papers/dxxxxr0.md` to `papers/d4345r0.md` would have satisfied nothing: it
replaces a placeholder number with a real one and entrenches exactly the thing
the convention forbids. The paper is now

- **`papers/unicode-mathematical-operators.md`** — D4345R0, from the title.

**And the same decision, taken once, applies to the sibling.** The author
authorised the second rename, so both papers leave this sitting consistent
with each other and with the convention rather than one of each:

- **`papers/backtick-infix-and-keyword-escape.md`** — D4307R0, from its title
  *An Infix Operator and a Keyword Escape for C++* and its subtitle *Two jobs
  for the backtick*.

**Why that basename and not `infix-backtick-operator`.**
`docs/infix-backtick-operator.org` already exists and is the blog version of
that paper. Giving the paper the same basename in a different directory would
make one name mean two documents, which is the confusion the naming rule
exists to prevent — and note the Unicode pair does not have that problem by
accident, it has it by construction: `papers/unicode-mathematical-operators.md`
against `docs/unicode-infix-operators.org`. `backtick-infix-and-keyword-escape`
carries the token a reader would search for and names **both** jobs, which is
the paper's own framing: they are proposed together, with equal standing,
because they share the character.

One consequence worth stating: the two papers were inconsistent for exactly as
long as it took to ask, and **the backtick paper was the one out of line** —
`d4307r0.md` was number-named from the day it was created. It is not any more.

**The extent of the substitution.** Every occurrence of the *path* was
rewritten, in 15 files for the Unicode paper and 14 for the backtick one,
including historical handoffs: a path is a location, not a claim, and thirty
pointers to a file that no longer exists are worse than a rewritten record.
The *number* was changed only where a live document names the paper's number.
`CLAUDE.md`'s Layout now lists `papers/` explicitly, with both filenames, both
numbers, the naming rule and both PDF traps.

**What `grep -rIn -i dxxxx` returns, and why it is not zero.** Three kinds of
hit, and **no live document among them**:

- `ops/completion/steps/unicode-paper.md` — this step's own spec, in the
  sentences describing the state the step was *given* (*"still has `DXXXXR0`
  as its document number"*). That file now opens with a dated note giving the
  real number, both new paths, and the fact that the narrative below it
  describes the past. Rewriting the spec would have falsified the record of
  what the step was asked to do.
- this handoff and `ops/completion/PLAN.md`, which cannot describe a
  substitution without naming what was substituted.
- nothing else. **No paper, no design doc, no ledger, no `CLAUDE.md`.**

The step file's gate says *"no `DXXXX` left anywhere in the repo (`grep -ri
dxxxx` is the check)"*, and that wording cannot be satisfied without editing
the spec's own account of itself and the records that describe the change; the
dated note is the honest reading of it.

`grep -rIn dxxxxr0` — the old *path* — returns nothing outside those same
three records. Every `papers/*.md` path in the repo was resolved against the
filesystem: the only ones that do not exist are the two old names and two
worked examples (`papers/d4345r0.md`, `papers/algorithms-for-trees.md`) quoted
in this handoff and in the step file's note to explain the naming rule. **No
pointer is dangling; the four are prose about names, not references to
files.**

## The gate this step actually owns, and the part of it that is no longer true

The step file's closing gate says: *"all three deviation ledgers are empty of
unreconciled rows."* **That held for one day.**
[backtick-paper](backtick-paper.handoff.md) re-derived 57 claims the day before
this step, five failed, and it opened four rows:

```
$ grep -c '\*\*Status:\*\* \*\*OPEN\*\*' ops/DEVIATIONS.md ops/gcc/DEVIATIONS.md \
      ops/unicode-operators/clang/DEVIATIONS.md
ops/DEVIATIONS.md:2
ops/gcc/DEVIATIONS.md:2
ops/unicode-operators/clang/DEVIATIONS.md:0
```

(Note the spelling: those four rows carry `**Status:** **OPEN**` on the same
line as `**Formerly:**`, so the older `grep -n 'Status:\*\* OPEN'` idiom that
several handoffs use **misses them and reports zero**. Use the pattern above.)

The four are
[`escape-name-positions`](../../DEVIATIONS.md#escape-name-positions),
[`type-slot-aggregate-shape`](../../DEVIATIONS.md#type-slot-aggregate-shape),
[`escape-alias-name-parity`](../../gcc/DEVIATIONS.md#escape-alias-name-parity)
and [`escape-diagnostic-spelling`](../../gcc/DEVIATIONS.md#escape-diagnostic-spelling).
**All four are backtick-track, none is owned, and none of them is this step's
to reconcile** — this step's destinations are `papers/unicode-mathematical-operators.md` and
`docs/unicode-operators.md`, and reaching into the backtick ledger is exactly
the scope creep the per-section reconciliation was designed to prevent.

**So the gate was narrowed, deliberately, and here is the narrowing:** this
step gates on **the Unicode ledger being clear** and **its own claims
holding**. Both are met, and the four numbered gate bullets in the step file
all pass. The step file's *closing* paragraph — the "when this is done" list,
which says every plan is checked, both papers are finished, all three ledgers
are empty and every `BNN` row has a `Closed by` cell — is now true of
everything except the ledgers, and its own instruction covers that case:
*"say which one is not, because that is the only thing left."* It is the
ledgers, it is four rows, they are backtick-track, and they are unowned. The
plan's Coverage table says so on both halves; see *Open risks*.

## The gate is a count: 89 claims checked, 14 failed

Every claim in the paper and in the `.org` was re-derived from a running
compiler rather than quoted from a ledger, which is this track's house
standard, and it earned its place again — the failure rate is 16%, three times
[backtick-paper](backtick-paper.handoff.md)'s 9%, on a paper nobody had
re-checked since it was drafted.

**Language and grammar (30 checks, 0 failures).** Basic declaration and
`static_assert(5 ⊞ 7 == 12)`; left association; symmetric prefix binding;
binding tighter than `*`; the fifth worked example `⊖a ⊞ 2 * ⊖b`, by a
**type-forced probe** rather than by reading a dump — give each operator a
distinct result type and let the program fail to compile if the tree is
different; the member forms; both fixities of one code point in one expression
(`` ⊖a ⊖ b `` and `` ⊖⊖1 ⊖ ⊖⊖2 ``); `-ast-print` round-tripping both; the
five [over.oper] outcomes including a **variadic** user operator and a
defaulted trailing parameter making an infix declaration prefix-usable;
the ordinary ambiguity when a real prefix overload joins it; static members
rejected with their own diagnostic; `MN{} ⊘ 0` selecting the non-member and
`MN{} ⊘ 0L` the member; `1 ⊠ 2` as *use of undeclared `'operator⊠'`*;
`p ⊞ n` on an `int *` as a no-viable-overload error rather than pointer
arithmetic; hidden-friend ADL, augmentation over a visible ordinary-lookup
candidate, ADL at instantiation; the fold rejection, **character-identical** to
the backtick form's on `build-backtick-trunk`; `-Wunsequenced` firing on the
non-member form and silent on the member one.

**The node, and it is now a positive result.** The paper described the
dependent-member failure and then said *"the fix is a node"*, leaving a reader
to guess whether it was built. It is, and both shapes now pass:

```cpp
struct M { constexpr int operator⊕(M) const { return 1; } };
template <class T> constexpr auto f(T a, T b) { return a ⊕ b; }
static_assert(f(M{}, M{}) == 1);                                    // passes
template <class T> concept Addable = requires(T a, T b) { a ⊕ b; };
static_assert(Addable<M>);  static_assert(!Addable<struct NoOp>);   // passes
```

**Unicode (12 checks, 1 failure).** The five UCD 17.0 files were **fetched
fresh**, checked against `docs/ucd-17.0.0.sha256` (5/5 match), and
`pattern-syntax-audit.py --verify-manifest` re-run: 2,760 Pattern_Syntax code
points, 2,681 assigned, **79** unassigned, **453** post-4.1 assignments with
one in 17.0 itself (U+2B96 ⮖), **283** inside the blocks of which **279** are
Sm/So, and the final set **1,381 code points in 32 ranges, 256 bytes**. Every
number in the paper's token-set section reproduces. Disjointness likewise: 0
XID_Start, 0 XID_Continue, 0 Annex E, and Pattern_Syntax ∩ ID_Compat_Math is
exactly `∂ ∇ ∞` — the three exclusions. The one failure is the exclusion list;
see below.

**Diagnostics (6 checks, 0 failures).** The confusability error for a literal
`−` and for `−`, **identical text, only the caret differing**; no fix-it
on either; the emoji message; `int ∂(int); int u = ∂(1);` compiling with only
`-Wc++2d-extensions`; `operator ∂` producing *unknown type name* plus the
identifier-profile note; `int operator∂(S, S);` closed up dumping as an
ordinary `FunctionDecl` named `operator∂`.

**Mangling and ABI (9 checks, 0 failures).** All four symbol forms in the
paper reproduce byte for byte, plus the explicit-object member
`_ZNH1Ev28op_u2297ES_S_`; `llvm-cxxfilt` and **GNU `c++filt` 2.46** render all
five character-identically; a Windows target accepts the declaration and
rejects the definition with *cannot mangle this Unicode user-defined operator
yet*; three spellings of one operator (glyph, `⊞`, `\N{SQUARED PLUS}`)
produce **one symbol**; and the increment/decrement defect reproduces — Clang
*definition with same mangled name `_Z1fI1AEvDTpptlT_EE`*, GCC 15.2.0 emitting
`_Z1fI1AEvDTpp_tlT_EE` and `_Z1fI1AEvDTpptlT_EE` distinctly.

**Toolchain and gating (12 checks, 0 failures).** PCH round-trip; a named
module exporting `operator⊞` and a second TU importing and using it; the
`userOperatorExpr` matcher registered at `Registry.cpp:611` and its
`hasAnyOperatorName` refusal documented at `ASTMatchers.h:2177`; clang-format
spacing, `operator ⊞` canonicalizing under `SpaceAfterOperatorKeyword` and
reversing when it is set, and `BreakBeforeBinaryOperators: All` breaking
*before* `⊞` at `ColumnLimit: 28`; clang-format's cost **+40/−1 over three
production files** with **no new `TokenType`**; both flags composing on one TU
with a mixed `` a ⊞ b `plus` c `` chain type-forced to prove left association
across them; **byte-identical** C-mode output flag-on and flag-off;
**byte-identical** IR flag-on and flag-off on a TU that never mentions the
feature; and only four feature diagnostics exist, all flag-gated.

**Code generation (6 checks, 0 failures).** LLVM IR for the operator form and
the hand-written call, diffed function body against function body, identical
for a scalar return, an aggregate return and an l-value-returning operator
stored through. Then the same three in **CIR**, on
`~/src/llvm/build-cir-scratch` (the only tree in the project configured with
`-DCLANG_ENABLE_CIR=ON`), with the callee symbol normalised: identical.

**Counts and volume (14 checks, 6 failures).** See the table.

### The fourteen failures

| # | Claim | What is true |
|---|---|---|
| 1 | the confusable exclusions are *"U+2212 −, U+2215 ∕, U+2217 ∗, U+2223 ∣, U+2236 ∶, U+2219 ∙, U+22C5 ⋅, U+2264 ≤, U+2265 ≥, and ⇐ ⇒ ⇔"* — **twelve** | The shipped table has **thirteen**. **U+2044 ⁄ FRACTION SLASH is on it**, spelled `/`, and `1 ⁄ 2` gets the confusability error rather than a stray-character one. The paper's later paragraph — *"named in the draft exclusion list, is outside the blocks and already fails predicate 3"* — reads as though it had been dropped, and U§5 says the opposite in as many words: it is *"kept on the list so the list reads as the confusability audit's own output"* |
| 2 | the exclusion list's shape | The paper never gave the counts at all. It is **28 = 3 identifier-profile + 13 confusable + 12 emoji**, pinned by a unit test that asserts `28u` |
| 3 | *"`operator⊞`, `operator⊞` and `operator\N{SQUARED PLUS}` are the same declaration"* | The **glyph is printed twice**; the numeric-UCN spelling `operator⊞` was lost somewhere. The sentence claims three spellings and shows two |
| 4 | Compiler proper: 77 files, +1940 / −18 | **86 files, +2033 / −18** |
| 5 | Tests: 32 files, +5133 | **34 files, +5416** |
| 6 | Total: 109 files, +7073 / −18 | **120 files, +7449 / −18** |
| 7 | *"Fifteen commits"* | **Nineteen** |
| 8 | *"That ledger has twenty-three rows"* | **Twenty-four** |
| 9 | *"twenty-one gated steps"* | **Twenty-two** (`U00`–`U21`; the baseline step is gated too) |
| 10 | the expression node at *"437 lines across 31 files"* | **436** production lines across 31 files |
| 11 | the declaration checker at *"54 lines"* | **53** |
| 12 | *"67 dispatch sites across three independent axes"*, with a 14 / 8 / 2 / 1 / 42 table | **89**: 34 over the name kind, 12 over the declarator-id kind, 43 over the node. The 67 was a mixed-axis count that does not reproduce and whose categories were never re-added. The node's 43 now carry [dispatch-obligation-taxonomy](../../../docs/unicode-operators.md#dispatch-obligation-taxonomy)'s seven categories, which **sum** |
| 13 | *"The three-for-three result"*, with *"there is a fourth"* | **Five**, per [closed-table-sibling-pattern](../../../docs/unicode-operators.md#closed-table-sibling-pattern): three siblings, one documented refusal, and postfix-ness, which has nothing to make a sibling of |
| 14 | the candidate assembler, *"of which exactly one six-line helper could not be reused, the one whose first line converts an operator kind into a name"* | Not what the source says. `SemaOverload.cpp:15505`'s own comment gives the split, and it is a cleaner claim: **everything keyed off an operator kind** could not be reused (member candidates, built-in candidates, rewritten candidates, the operator-call node) and **everything keyed off a `DeclarationName`** was reused verbatim (`AddNonMemberOperatorCandidates`, `AddMethodCandidate`, `AddArgumentDependentLookupCandidates`, `BestViableFunction`, the call builders). *"Candidate assembly is the only genuinely new code"* |

Failures 4–9 are one kind of error and worth naming as one: **the branch grew
after the paper's figures were taken, and nothing re-took them.** Two of the
four steps that added to it were in this very plan. Failures 12–14 are the
other kind: a figure or a mechanism recorded once and inherited, which is now
the seventh, eighth and ninth instance of the run
[reconcile-implementation-cost](reconcile-implementation-cost.handoff.md)
started counting.

## The paper's PDF could not show its own subject matter

`make unicode-mathematical-operators.pdf` succeeded, exit 0, 14 pages — and emitted **136 `Missing
character` warnings**, one per operator glyph per occurrence. Latin Modern,
which the wg21 template uses, has none of the mathematical and arrow blocks in
either its roman or its mono face. `pdftotext` on the result:

```
A user should be able to declare operator? and write a ? b.
constexpr int operator?(int, int);
```

A paper whose entire subject is `operator⊞`, rendering `operator` followed by
nothing, in every code block and in its own subtitle. The HTML target is fine,
because a browser substitutes a font, so **the breakage is invisible unless
someone builds the PDF and reads the log**. Exactly the shape of
[backtick-paper](backtick-paper.handoff.md)'s `\pnum` finding, one target over.

The fix is two lines and no LaTeX:

- **`monofont: "DejaVu Sans Mono"` in the front matter.** `monofont` and
  `mainfont` are pandoc variables consumed by the template's `$fonts.latex()$`
  partial. They are **not** `header-includes`, so setting them does not
  clobber the wg21 preamble — this is the safe way to reach the LaTeX preamble
  from a wg21 paper, and it is worth knowing. 136 → 29.
- **The remaining 29 were prose, in the roman font.** Every operator glyph in
  running text is now in a code span, which is what they are — tokens — so
  they take the mono font. That left 13: the twelve emoji and `⁄`, which DejaVu
  Sans Mono does not carry. The twelve emoji are now **named by code point**,
  which is both font-independent and the better way to write a normative
  exclusion list; `⁄` keeps its glyph in prose, where Latin Modern Roman has
  it. **Zero missing characters**, both formats build, 14 pages.

`mainfont` was tried and rejected: it works, but it changes the paper's body
typography away from what every other wg21 paper renders as, for thirteen
characters.

## What changed, and where

### `papers/unicode-mathematical-operators.md`

- **Front matter** — `monofont`, with a comment saying why it is not a style
  preference. No `header-includes` was added; the file never had one, which is
  why its PDF built at all.
- **The token set** — the exclusion list rewritten with its counts and its
  thirteenth entry, U+2044 given its own paragraph saying why a redundant
  exclusion is kept, the emission-scope rule stated in a transferable form
  (*a reason is emittable at token classification if and only if its code
  points can not also be identifier constituents*), and the middle-dot
  correction kept while the U+2044 "correction" — which was not one — goes.
- **Disjointness** — says the measurement is a unit test that iterates the
  whole set against the compiler's own tables, rather than an assertion.
- **UCN spellings** — the third spelling restored, with the acceptance
  criterion in the sentence: declare with one, define with another, use with a
  third, one symbol.
- **The grammar** — the infix production's cost is honest about the flag
  argument threaded to the three precedence queries; the prefix cost is *about*
  forty lines and says it shares the infix form's Sema entry point.
- **ADL** — rewritten around the mechanism rather than a line count: the callee
  is a name the compiler forms and never an expression the parser resolves.
  The backtick contrast is **one clause, not a section** — both of its
  compilers resolved the slot in the parser and both silently lost ADL — per
  [backtick-paper](backtick-paper.handoff.md)'s forward note that two papers
  narrating the same anecdote at length reads as one paper split.
- **The expression node** — the dependent-member failure is now past tense with
  the node's arrival stated and measured, plus the operands-not-a-call rule and
  why Sema re-wrapping the result is what decides it.
- **Implementation experience** — the largest change.
  - **New: *The desugaring survives to the back end***, placed second, where
    [`codegen-dispatch-sites`](../../unicode-operators/clang/DEVIATIONS.md#codegen-dispatch-sites)(c)
    belongs. Five shapes, two code generators, instruction-identical.
  - **Volume** re-measured and dated, with the commit groups as they exist.
  - **The `check-clang` sentence** stops implying the suite runs twice and says
    what is actually asserted, then adds the two flag checks that *are*
    byte-identical diffs.
  - **New: *Opening a closed table cost a parallel implementation, five times
    out of five***, replacing *the three-for-three result*, ending on the
    leak-into-`operator+` argument stated structurally, with GCC's `ansi_opname`
    as the same shape in a second compiler.
  - **The dispatch table** replaced with the seven-category taxonomy, dated and
    branch-stamped, with the configuration-latent paragraph, the
    obligation-created-by-meeting-an-obligation row, and the spelled-not-
    dispatched finding.
  - **New: *The design document was wrong about the cost, in a predictable
    direction***, carrying U§6's correction and the reason it happened.
- **Mangling and ABI** — three subsections, in
  [mangling-abi](mangling-abi.handoff.md)'s order and on its ruling. The
  derivation rule as a block quote with injectivity and the two unexercised
  branches; the two-demangler result with the `c++filt`-loses-UTF-8 argument
  for ASCII hex; then **the request**, marked as a request, with the `uo
  <fixity> <source-name>` sketch, **the letters explicitly the ABI group's**,
  `s` reserved so postfix stays takeable, and the three arguments (the ABI's
  own scoping of `v` to vendor builtins, no cross-vendor derivation, arity is
  not fixity) with the `++`/`--` defect as the evidence that fixity is easy to
  get wrong where the ABI *does* have room. Then Windows.
- **What is not resolved** — four items, each open because someone other than
  the author must answer, and a closing paragraph naming the four that are
  decided and where each is argued.
- **Relation to the backtick proposal** — separable fates as an executed result
  with **the base commit's necessity spelled out in prose**, per
  [reconcile-remainder](reconcile-remainder.handoff.md); the three coupled
  constructs with the silent one named.
- **Acknowledgments** — the `++`/`--` defect keeps its reproducer summary and
  **stops claiming it was reported**: *"a report is written and this revision
  cites no issue number, because none has been filed yet"*, with the
  `LLVM-ISSUE-PENDING` token preserved as an HTML comment so the substitution
  point survives without appearing in the rendered paper.
- **Voice.** `lexcheck --register formal` clean. It found one impostor phrase
  (*worth naming*), `rather` at 27/10k against a base of 5.9 (21 uses, 8 of
  them pre-existing), and `machinery` — a blog word with zero occurrences in
  his published papers. All introduced by this step and all removed. The one
  remaining warning is the appositive `, not Y` tail at ×5, and **every one of
  the five predates this step**.

### `docs/unicode-infix-operators.org` and `.meta`

The post's abstract said *"nothing here is implemented, and there is no paper
yet"* and its closing section said *"nothing will be for a while"*. Both false
since the prototype was built. Rewritten in blog register:

- The build stated up front, with the standard it sets for the rest of the post.
- The parse result given its structural reason — two productions read by two
  different functions that never see the same token, so there is no
  disambiguation state to get wrong — against backtick's suppression flag.
- **New: *The hard parts are elsewhere, and I under-priced them***, carrying
  U§6's correction in the first person, then the `DeclarationName` cost, then
  the packed-against-Objective-C's-encoding finding, then mangling with the
  fixity argument for asking, then Windows.
- The exclusion list at 28 with the curated-not-derived principle and the
  *is confusable with* / no-fix-it reasoning.
- **New: *Two things the build told me that no amount of writing would have*** —
  the UCN identity trap (and the general point: a test written at the level of
  the mechanism is a different test from one written at the level of the
  claim), and ADL arriving free, with the backtick contrast as the control.
- **New: *What the node costs*** — the dependent-member failure, the node, and
  the 89-site fan-out with the spelled-not-dispatched finding.
- **New: *What isn't done yet*** — one compiler, Windows, sequencing, combining
  marks, Latin-1, postfix.
- Separable fates and the twice-surfaced shared level added to *Where this
  leaves backtick*.
- **Voice.** `lexcheck --register blog` clean (it found `exactly` at 19/10k
  against a base of 4.4). Em-dashes **7.3/10k**, below the paper rate and below
  the backtick post's 19.7. Contractions 94, and the register did not drift
  formal.
- `.meta` date 2026-08-02 → **2026-09-08**, one day after the backtick post's,
  per that step's forward note that they publish as neighbours.

### `docs/unicode-operators.md`

One character. U§7's default-argument paragraph said *"Declare a genuine prefix
overload alongside and `⊠5` is ambiguous"* two lines after establishing `⊟`.
The paper had it right; the design doc did not.

## Verification evidence

### Builds

Both papers, both formats, rebuilt after the renames, because a filename
change is not inert until it has been shown to be:

```
$ make -C papers unicode-mathematical-operators.html unicode-mathematical-operators.pdf
  generated/unicode-mathematical-operators.html  110 KB
  generated/unicode-mathematical-operators.pdf   143 KB, 14 pages
  Missing character warnings: 0        # 136 before this step
  Other warnings:              none    # the placeholder's "unrecognized
                                       # document number" warning is gone

$ make -C papers backtick-infix-and-keyword-escape.html backtick-infix-and-keyword-escape.pdf
  generated/backtick-infix-and-keyword-escape.html  155 KB
  generated/backtick-infix-and-keyword-escape.pdf   155 KB, 18 pages
  Missing character warnings: 1        # pre-existing; see below
```

Neither regressed. The backtick paper's content is **byte-identical** to the
committed `d4307r0.md` (`diff` against `git show HEAD:papers/d4307r0.md` is
empty), so its PDF still builds on
[backtick-paper](backtick-paper.handoff.md)'s `header-includes` fix and the
rename touched nothing inside it.

**One pre-existing defect the rebuild surfaced, and it is not mine to fix.**
`papers/backtick-infix-and-keyword-escape.md` line 229 has a lone `≡` U+2261
in a code comment — *`// short-circuiting logical implication:  p => q  ≡  !p
|| q`* — and Latin Modern Mono does not carry it, so one character is missing
from that PDF. It was there before this step and
[backtick-paper](backtick-paper.handoff.md) did not catch it, because it
counted the `\pnum` failure and not the warning log. Two one-line fixes exist
— give that paper a `monofont` as this one has, or reword the comment — and
both are edits to a paper outside this step's destinations, so it is recorded
here rather than made. It is the smallest open thing in the track.

`emacs --batch … org-html-export-to-html` on the `.org` completes with no
errors; the export carries the new section headings. The generated HTML was
deleted afterwards — `docs/` is source only.

### The separable-fates grep, with its base pinned and its empty output

```
$ cd ~/src/llvm/unicode-upstream
$ git log -p d28193fa1ff6..HEAD | grep -ic backtick
0
$ git diff upstream/main..HEAD | grep -ic backtick        # the unpinned form
6
```

Zero, as claimed. The six are upstream's own drift, which is why the paper now
spells out in prose that the base has to be pinned.

### Public text stands alone

Two sweeps over `papers/unicode-mathematical-operators.md`, `docs/unicode-infix-operators.org` and the
`.meta`:

1. Retired serial and internal-path forms — `DEV-*`, `B\d\d`, `BL\d\d`,
   `D\d{1,2}`, `S\d\d`, `G\d\d`, `U\d{1,2}`, `U§`, `§1\d`, `ops/`, `BACKLOG`,
   `DEVIATIONS`, `handoff`, `PLAN.md`, `slug`, `open-decisions`,
   `AGENT_PROTOCOL`, `REPLAY` — **one hit, `.. slug:` in the Nikola `.meta`,
   a URL slug and not an identifier.**
2. Every **live** slug in the repo, harvested from the three ledgers, the
   backlog, the two design docs, `docs/open-decisions.md` and both
   `steps/` directories — **145 candidates, zero real hits.** The six matches
   are `evaluation-order` used as an English noun phrase (×3) and
   `operator-function-id`, which is the C++ grammar's own non-terminal (×3).

The four `U§` cross-references
[reconcile-remainder](reconcile-remainder.handoff.md) flagged are gone: `U§2`
became *"frozen by this paper"* and *"the exclusion list below"*, `U§4` became
*"this proposal"*, and `U§7` became *"the desugaring equivalence below"*.

### Links

**2420 local Markdown links** across every tracked `.md` outside
`papers/wg21/`, **0 broken** — file existence plus GitHub-style anchor slugs,
whitespace runs not collapsed, links inside code spans and fences excluded.
Re-run after both renames. A second check, because a rename breaks *paths* and
not only links: every `papers/*.md` path mentioned anywhere in the repo was
resolved against the filesystem. Four do not exist, and none of them is a
pointer — the two old names and two worked examples (`papers/d4345r0.md`,
`papers/algorithms-for-trees.md`), all of them prose explaining the naming
rule, in this handoff and in the step file's dated note.

## Deviations from the step file

1. **The paper is not renamed and the number is not assigned.** The step file's
   own clause covers this; see the top. Nothing is half-renamed.
2. **The gate was narrowed and the narrowing is stated**, above and in the
   plan's Status row. The three-ledger clause is not this step's to meet.
3. **A build-system fix was made**, and it is the second one in two steps. Not
   in the step file; the gate says the paper renders, and it rendered without
   its subject matter.
4. **`docs/unicode-operators.md` was edited** — one character, a typo the paper
   does not inherit. Fixed because a reader of the design doc would.
5. **The step file's *"What has changed under the paper"* list is right about
   every item and silent about the largest source of error**, which was not a
   reconciliation at all: six of the fourteen failures are figures that went
   stale because the branch kept growing. A paper's numbers need re-taking on
   the day it is finished, and no step file says so.
6. **`LLVM-ISSUE-PENDING` was moved into an HTML comment** rather than left in
   the rendered text. The instruction was to leave the token and say what the
   paper cannot claim; a placeholder issue number in *published* text is itself
   an internal identifier in public text, so the token survives as a
   substitution marker and the prose says the true thing. The doc-side
   substitution points are untouched: `grep -rn LLVM-ISSUE-PENDING docs ops`
   is unchanged at its four sites.

## Discoveries affecting later steps

- **`monofont:` / `mainfont:` in a wg21 paper's front matter reach the LaTeX
  preamble without clobbering `header-includes`.** They go through the
  template's `$fonts.latex()$` partial, which is a different variable. If a
  paper ever needs preamble content that `header-includes` would replace,
  these two are the safe channel, and `include-in-header` is the next thing to
  try.
- **A wg21 PDF can build cleanly and be wrong.** `make` exits 0; the
  `Missing character` warnings scroll past; the HTML is perfect. Any paper with
  non-Latin content should be checked with
  `make X.pdf 2>&1 | grep -c 'Missing character'` and with `pdftotext`, not by
  the exit code.
- **`grep -n 'Status:\*\* OPEN'` does not find the four rows
  [backtick-paper](backtick-paper.handoff.md) opened**, because they carry
  `**Formerly:** … **Status:** **OPEN**` on one line. Several handoffs use that
  idiom as proof the ledgers are clear. Use
  `grep -c '\*\*Status:\*\* \*\*OPEN\*\*'`.
- **The UCD files are one `curl` away and the manifest works.** Five fetches,
  `sha256sum -c docs/ucd-17.0.0.sha256` 5/5, and
  `pattern-syntax-audit.py --verify-manifest` reproduces every Unicode number
  in the paper in about a second. [evidence-debt](evidence-debt.handoff.md)'s
  manifest is not a formality; it makes the paper's most reviewer-facing
  numbers re-checkable by anyone, and it was used in anger here.
- **A type-forced probe pins a precedence claim better than a dump.** Give each
  operator a distinct result type and `static_assert(__is_same(...))` the
  result; the program fails to compile if the tree is different. Used for the
  fifth worked example and for the mixed backtick/Unicode chain.
- **`build-cir-scratch` is the only tree in the project with
  `-DCLANG_ENABLE_CIR=ON`.** Every other build directory answers *"clang IR
  support not available"*. It is still current (`6ee1358f7b47`) and it is what
  makes the CIR half of the desugaring claim re-checkable.
- **The `zsh` trap [backtick-paper](backtick-paper.handoff.md) recorded is
  real and it caught me too.** An unquoted `$CXX` holding a command line is not
  word-split, so every probe in a loop reports failure and it looks exactly
  like a feature that does not work. Write the command out.

## Forward notes

**There is no next step, and no unchecked box.** `ops/completion/PLAN.md` is
complete: seventeen steps, sixteen ticked and one marked not-applicable with
its reason, plus the maintenance rows.

What a later agent most needs from this step is not about the paper:

- **A wg21 paper can build cleanly and be wrong, in two different ways, and
  this repo has hit both.** `header-includes` in the front matter silently
  replaces the wg21 LaTeX preamble; a font without your glyphs silently drops
  them. `make` exits 0 for both. The check is
  `make X.pdf 2>&1 | grep -c 'Missing character'` plus `pdftotext`, and it is
  now written into `CLAUDE.md` so the next person does not have to rediscover
  it.
- **`monofont:` and `mainfont:` reach the LaTeX preamble without clobbering
  `header-includes`**, because they are template variables consumed by
  `$fonts.latex()$`. That is the safe channel into a wg21 preamble.

## Open risks / TODOs — the closing list for the whole track

Everything below is outstanding across the *entire* completion track. Nothing
after this will collect it: the plan is complete.

1. **Four deviation rows are open and none is owned** —
   [`escape-name-positions`](../../DEVIATIONS.md#escape-name-positions),
   [`type-slot-aggregate-shape`](../../DEVIATIONS.md#type-slot-aggregate-shape),
   [`escape-alias-name-parity`](../../gcc/DEVIATIONS.md#escape-alias-name-parity),
   [`escape-diagnostic-spelling`](../../gcc/DEVIATIONS.md#escape-diagnostic-spelling).
   All backtick-track, all opened 2026-09-07 by
   [backtick-paper](backtick-paper.handoff.md), after this plan was written, so
   no step covers them. **The track can no longer claim all three ledgers are
   clear** — that was true for one day, 2026-09-06 — and the claim should not
   be restored without a step that closes them. Three are one unwritten parser
   arm each; the fourth carries a design question for the author about how far
   the keyword escape is meant to reach. **Neither paper is blocked by any of
   them**; `papers/backtick-infix-and-keyword-escape.md` states all four.

   *Correcting my own earlier note:* I previously wrote that the plan's
   Coverage table predated these rows. Half true. Its **backlog** half already
   had a `— (… no step)` row, added by backtick-paper; its **deviation** half
   did not, and its "29 open deviation rows" count predated them. That was a
   one-line honest fix and it is made: the deviation table gains the same
   `— (no step)` row and the count now says what it counts and as of when.

2. **A one-character defect in the backtick paper's PDF.** `≡` U+2261 in a code
   comment, not in Latin Modern Mono. Pre-existing, found by rebuilding after
   the rename, and deliberately not fixed here because that paper's prose is
   outside this step. `monofont` or a reworded comment; either is one line.

3. **Nothing is pushed.** This repo is ahead of every remote, as are the four
   LLVM worktrees and the GCC one. `origin/backtick-23` and
   `origin/backtick-trunk` are behind; the GCC `backtick` branch is ~2170
   commits ahead of `origin/backtick` and needs `--force-with-lease` after its
   re-base. **Both papers link to those public forks**, so a reader following
   the links today gets the pre-re-sync state. Pushing is the maintainer's call
   and should happen before either paper circulates. **The two Unicode branches
   are not pushed either**, and the paper's volume table and site counts are
   measured against `unicode-operators-upstream` at `c0e07f78e679`; a reviewer
   who wants to reproduce them needs the branch to be reachable.

4. **The queued forward-port to `unicode-operators-experiment`.**
   [clang-slot-adl](clang-slot-adl.handoff.md)'s fix has not reached it, which
   is what keeps `~/src/llvm/build-unicode` able to demonstrate the
   within-compiler ADL control on a live binary.
   [backtick-paper](backtick-paper.handoff.md) recorded that the merge destroys
   that ability and that its transcript is the record. This step used the same
   binary only for the both-flags-compose checks and did not need the defect.
   Nothing blocks the merge.

5. **`CheckUserOperatorDeclaration`'s comment on `unicode-operators-upstream`
   still gives the abandoned static-member reason.** M2 fixed it on the
   experiment branch (`de76585ae45d`); the upstream branch was deliberately not
   merged and still says a static member "has no implicit object parameter",
   which the design has replaced with the two-spellings reason the paper now
   prints. One line, on one branch, owned by nobody.

6. **`CLAUDE.md` says M2 is outstanding.** Its *Current state* section reads
   *"One maintenance merge is outstanding, M2 … it runs after
   clang-paper-truth"*, and [M2-forward-port](M2-forward-port.handoff.md) says
   **DONE, 2026-09-06**, as does the plan's Maintenance section. This step
   rewrote `CLAUDE.md`'s Layout for the renames and left *Current state* alone,
   because correcting a claim about a merge is not a rename; it is still stale
   on that one point.

7. **The paper asks the ABI group for something nobody has asked them yet.**
   The `uo` letters are this repo's invention, offered as a shape and marked as
   one. If the request moves in the room the edit is contained: the sketch and
   its three load-bearing notes are the only prose that changes, and the
   measured bullets stand whatever is asked for.

8. **What the paper still cannot claim, and why.** No upstream issue number,
   because the report is drafted and not filed — so the fixity argument rests
   on a divergence a reader must reproduce, and the reproducer is in the paper.
   Nothing back from any ABI group, because nothing has been put to one.
   Nothing about Microsoft beyond the shape of the gap, so it cannot claim the
   feature is portable. And **one implementation**, which the paper says, and
   which is the whole reason the two papers are separate.

9. **The counts in this paper will go stale the way the last ones did.** Six of
   this step's fourteen failures were figures that went stale because the
   branch kept growing and nobody re-took them — and two of the four steps that
   grew it were in this plan. They are now dated and branch-stamped, and the
   taxonomy table sums so an omission is visible. If anything lands on either
   Unicode branch, the volume table and the site counts need re-taking, and
   this step is the evidence that nobody does it unprompted.
