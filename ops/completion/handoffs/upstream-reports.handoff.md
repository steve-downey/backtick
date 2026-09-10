# Handoff — upstream-reports: the three upstream defects, drafted and not filed

- **Status:** DONE (gate passed **as amended** — see "The one amendment" below;
  the step's original "three issue URLs" bullet is not met, by the author's
  decision, and **the three backlog rows stay open**).
- **Branch / commit:** no branch. `ops/completion` track, this repo only.
  Nothing landed on `backtick-23`, `backtick-trunk`,
  `unicode-operators-experiment`, `unicode-operators-upstream` or the GCC
  `backtick` branch; all five confirmed `CLEAN` by `git status --porcelain`
  before and after this step.
- **Date / agent:** 2026-09-06.

## The one amendment, and its consequence

The step file says to file three issues on `llvm/llvm-project`. **The author
decided otherwise: draft the reports, do not file them.** No `gh issue create`
was run and nothing was posted to any tracker. Everything else in the step was
done in full — each defect reproduced or re-read against *current* trunk, an
existing-issue search run for each, and each report written out complete, title
and body, ready to post.

**So the three rows do not close.** Each `Closed by` cell now says "NOT CLOSED —
report drafted 2026-09-06, pending the maintainer filing it" and links its
draft. Two consequences that are the author's to absorb, stated here rather
than papered over:

- **[mangling-abi](../steps/mangling-abi.md) has no issue number to cite.** It
  is scheduled after this step for exactly that reason. Its checklist line now
  says so and tells it to write around the placeholder.
- **[unicode-paper](../steps/unicode-paper.md) inherits the same gap.** The
  papers currently say "we found a Clang bug" without being able to say which
  one — `papers/unicode-mathematical-operators.md`'s Acknowledgments now names the ABI sections and
  the `--` twin, but the issue number is the token `LLVM-ISSUE-PENDING`.

Filing the three reports and substituting the numbers is one grep:

```console
$ grep -rn LLVM-ISSUE-PENDING docs papers ops
```

**Four substitution points**: `docs/unicode-operators.md` §9 and §13.1,
`papers/unicode-mathematical-operators.md` Acknowledgments, and
[`postfix-operators`](../../unicode-operators/clang/DEVIATIONS.md#postfix-operators)
clause (c). The grep also finds the token *described* rather than standing in
for a number — in `ops/BACKLOG.md`, `ops/completion/PLAN.md`, the drafts README
and here; leave those alone. Only the mangling defect has a placeholder — the other two are cited
nowhere outside `ops/`, so filing them costs no document edit.

**Why the box is ticked anyway.** The gate bullet that fails was removed by the
person who owns the plan, not failed by the agent; every other bullet passed.
Leaving it unchecked would send the next agent to redo three confirmations and
eight-plus duplicate searches. The checklist line carries the qualification in
full, so nobody can read the tick as "the defects are reported".

## What changed

New — `ops/completion/upstream-drafts/`, one file per defect plus a README:

| File | What it is |
|---|---|
| [`README.md`](../upstream-drafts/README.md) | what the directory is, the three-row table, and the pending-number consequence |
| [`increment-decrement-mangling.md`](../upstream-drafts/increment-decrement-mangling.md) | metadata (target, labels, trunk revision, 8 duplicate searches, no-patch instruction) + title + body |
| [`clangir-lvalue-crash.md`](../upstream-drafts/clangir-lvalue-crash.md) | same shape; 7 duplicate searches; two reproducers |
| [`unqualified-id-union-read.md`](../upstream-drafts/unqualified-id-union-read.md) | same shape; 4 duplicate searches; two sites |

Edited:

- `ops/BACKLOG.md` — the three `Closed by` cells, each saying *drafted, pending
  filing* and linking its draft. [`unqualified-id-union-read`](../../BACKLOG.md#unqualified-id-union-read)'s
  **Item** also gains a dated correction, because the line it cites is no longer
  the defect.
- `docs/unicode-operators.md` — **§13.1**, the paragraph after the `pp_`/`pp`
  code block: the missing explicit instantiations, the `operator--` twin, the
  trunk revision, and the placeholder. **§9**, a new closing paragraph: a
  first-class `<operator-name>` needs room for a fixity marker, and the
  `pp_`/`pp` divergence is the evidence that fixity is easy to get wrong — the
  sentence [mangling-abi](../steps/mangling-abi.md) was told to expect.
- `papers/unicode-mathematical-operators.md` — Acknowledgments, third paragraph: `--` added, ABI
  §5.1.3 / §5.1.6 named, "It is being reported upstream" → "Reported upstream as
  llvm/llvm-project LLVM-ISSUE-PENDING". **No internal identifier or file path
  in the paper**, per `~/.claude/CLAUDE.md`'s public-text rule — the token is the
  only marker, and it is deliberately conspicuous.
- [`postfix-operators`](../../unicode-operators/clang/DEVIATIONS.md#postfix-operators)
  **clause (c)** — the citation, the two reproducer corrections, and the ABI
  section numbers. **Clause (3) of its Recommended doc change was not touched**:
  the mangling clause is mangling-abi's, per decision-brief.
- `ops/completion/PLAN.md` — box ticked with the qualification, mangling-abi's
  line annotated, four Status-log rows appended.

## Verification evidence

### What was checked, not only what was changed

**Trunk is `72417eb739e5`** (2026-09-05), fetched into `~/src/llvm/main` on
2026-09-06 (`git fetch upstream`; nothing built there, nothing else touched).
**No build here is on it** — the newest bases are `d28193fa1ff6` (2026-08-04,
`build-unicode-upstream`) and `a815e6f267c1` (2026-06-13, `build-main`, which is
2.8 months stale. That is worth knowing before any step budgets `build-main` as
"trunk"). So each defect was confirmed by *reading the implicated code at
`72417eb739e5`* and, where a binary can show it, reproducing on the newest build
whose relevant code is identical to that revision. Each draft states which.

**[`increment-decrement-mangling`](../../BACKLOG.md#increment-decrement-mangling)
— reproduced, both operators, both builds.**

```console
$ clang++ -std=c++17 -c repro-inc.cpp     # build-main AND build-unicode-upstream
error: definition with same mangled name '_Z1fI1AEvDTpptlT_EE' as another definition
$ clang++ -std=c++17 -c repro-dec.cpp
error: definition with same mangled name '_Z1fI1AEvDTmmtlT_EE' as another definition
$ g++ -std=c++17 -c repro-inc.cpp && nm --defined-only repro-inc.o
_Z1fI1AEvDTpp_tlT_EE   _Z1fI1AEvDTpptlT_EE          # g++ (Ubuntu 15.2.0-16ubuntu1)
$ llvm-cxxfilt _Z1fI1AEvDTpp_tlT_EE _Z1fI1AEvDTpptlT_EE _Z1fI1AEvDTmm_tlT_EE _Z1fI1AEvDTmmtlT_EE
void f<A>(decltype(++A{}))   void f<A>(decltype(A{}++))
void f<A>(decltype(--A{}))   void f<A>(decltype(A{}--))
```

Mangler sites read at `72417eb739e5`: `mangleOperatorName`'s
`case OO_PlusPlus: Out << "pp";` / `case OO_MinusMinus: Out << "mm";`
(`ItaniumMangle.cpp:2770`, `:2772`), `mangleExpression`'s
`case Expr::UnaryOperatorClass:` (`:5579`, which has `UO->isPostfix()` in hand)
and `case Expr::CXXOperatorCallExprClass:` (`:5717`). Demangler at
`ItaniumDemangle.h:5178-5179` (grammar), `:3438`/`:3452` (the operator table
marking `pp`/`mm` `OperatorInfo::Postfix`), `:5224-5231` (`if (consumeIf('_'))`).

**ABI paragraph found**, which BL05 asked for and no document here had:
**§5.1.3 Operator Encodings** — `<operator-name> ::= pp # ++ (postfix in
<expression> context)` — and **§5.1.6 Expressions** —
`<expression> ::= pp_ <expression> # prefix ++`. Two citations, not one; the
`<operator-name>` table is where the ABI says `pp` *means* postfix.

**[`clangir-lvalue-crash`](../../BACKLOG.md#clangir-lvalue-crash) — reproduced
twice, with stock C++26 and no feature flag.**

```console
$ clang++ -std=c++2c -fclangir -emit-cir -o /dev/null repro-assign.cpp
error: ClangIR code gen Not Yet Implemented: emitLValue: PackIndexingExpr
Assertion `!isNull() && "Cannot retrieve a NULL type pointer"' failed.
    ... emitStoreOfScalar <- emitStoreThroughLValue <- emitBinaryOperatorLValue <- emitLValue
$ clang++ -std=c++2c -fclangir -emit-cir -o /dev/null repro-return.cpp
error: ClangIR code gen Not Yet Implemented: emitLValue: PackIndexingExpr
    ... segfault in createStore <- emitReturnStmt
```

where the two files are `template <class... T> void assign(T &...p) { p...[0] = 1; }`
and `template <class... T> int &first(T &...p) { return p...[0]; }`, each with a
one-line instantiation. The first is **BL04's exact assertion**, reached without
either feature.

The build is `build-cir-scratch` (`6ee1358f7b47`, base `bb33de72920a`), so the
step file's "check against a clean trunk CIR build, not that scratch dir" was
answered by *diffing the path instead of rebuilding it*: `emitLValue` extracted
from that branch and from `upstream/main` differ by exactly ten lines — BL04's
two `case` arms for the local wrapper classes — and `CIRGenFunction::emitReturnStmt`
is byte-identical. Everything the reproducers touch is `72417eb739e5` code. (A
clean trunk CIR build was not stood up; a full MLIR+CIR configure and build is
hours, and the diff is decisive.)

**[`unqualified-id-union-read`](../../BACKLOG.md#unqualified-id-union-read) —
confirmed by reading `72417eb739e5`; still latent.**
`operator""_x<'1','2'>()` compiles clean on both builds, as U07 predicted
(resolution goes through the `TemplateName`). Nothing observable to reproduce;
the confirmation is the code.

### Duplicate searches — 19 queries, no duplicate for any of the three

Run with `gh api search/issues`, `repo:llvm/llvm-project is:issue`, open and
closed. Full query lists are in each draft. Three results are worth carrying:

- **#20143** (open since 2014) — "load of value too big at DeclSpec.cpp:325": a
  sanitizer report of the *same* wrong-union read at a third site,
  `Declarator::isStaticMember()`. That site is kind-guarded on trunk today, which
  settles the fix shape for the two that are not. It is prior art, not a
  duplicate.
- **#202097** (closed 2026-06-07) — `emitDeclRefLValue` reports `errorNYI` and
  then continues with `Address::invalid()`, asserting. Same failure mode as the
  CIR defect, different site.
- **#214443** (closed) — NYI, then crash in `CastOp::fold`. Same again.

Two site-by-site fixes of that pattern did not reach `emitLValue`, which is the
argument the draft makes for reporting the shape rather than one arm.

### Docs gate

`grep -rn LLVM-ISSUE-PENDING docs papers ops` → 4 sites, all intended. A link
check over the nine touched files: **498 local links, 0 broken** (the only miss
was this handoff before it existed).

## Deviations from the plan / design

Three findings contradicted what was on file. All were corrected in place, in
the row or clause that owns the claim, rather than getting a ledger row of their
own — divergences append to the implicated entry.

1. **The mangling reproducer on file does not reproduce.** `BL05`'s and U§13.1's
   two function templates need `template void f<A>(int);` and
   `template void f<A>(double);` before anything is mangled. A report filed with
   the version on file would have been closed as not-reproducible. Corrected in
   the draft, in U§13.1, and in
   [`postfix-operators`](../../unicode-operators/clang/DEVIATIONS.md#postfix-operators)
   clause (c).
2. **[`clangir-lvalue-crash`](../../BACKLOG.md#clangir-lvalue-crash) is wider than
   "the default arm".** 21 arms of that one switch do `errorNYI(...);
   return LValue();`, and the enumerated ones are reachable from stock C++ — which
   is *why* a no-feature reproducer exists. The step file told me to find an
   `Expr` class **absent** from the switch that is an l-value in plain C++; I
   could not find one (in plain C++ every l-value-producing class is either
   handled or explicitly NYI), and the enumerated NYI arms are a strictly better
   reproducer because they need no downstream patch to reach. Recorded in the
   row.
3. **[`unqualified-id-union-read`](../../BACKLOG.md#unqualified-id-union-read)'s
   cited line is not the defect any more, and there is a second site.**
   `ParseExprCXX.cpp:2297`'s block kind-tests correctly today. The live read is
   the `OpKind` ternary at `:2374` (`ParseUnqualifiedIdTemplateId`), which
   excludes only `IK_Identifier`, and the same ternary appears **unguarded** at
   `ParseTemplate.cpp:1155` (`AnnotateTemplateIdToken`) — previously unrecorded
   anywhere. Both are in the draft; the row's Item carries the correction.

## Discoveries affecting later steps

- **`~/src/llvm/build-main` is 2.8 months behind trunk** (`a815e6f267c1`,
  2026-06-13, vs `72417eb739e5`). It is still the right binary for "is this
  environmental" questions, but it is **not** a current-trunk oracle. Any step
  whose gate says "confirm on current trunk" should either read the source at
  `upstream/main` or diff the implicated function between the build's base and
  `upstream/main`, which is what this step did three times and is cheap.
- **The technique generalises and is worth reusing:** extract the one function
  with `awk '/^ReturnType Class::fn\(/,/^}/'` from
  `git show upstream/main:<path>` and from the branch, and `diff`. It converts
  "my build is stale" from a blocker into two commands.
- **`gh` is authenticated and the search API works**, but `gh search issues`
  ANDs every term over title *and* body, so specific multi-word queries return
  zero and look like "no duplicates" when they are really "no such phrase". Use
  `gh api -X GET search/issues -f q='repo:llvm/llvm-project is:issue …'` and
  sanity-check one query you know should hit. `--state all` is rejected — that
  flag takes `open|closed` only; omitting it searches both.
- **The Itanium ABI HTML is fetchable and greppable** —
  `curl -sS https://itanium-cxx-abi.github.io/cxx-abi/abi.html`, ~290 KB, then
  grep and strip tags. Section numbers come from the nearest preceding `<h4>`/
  `<h5>`. mangling-abi will want this for the `v <digit> <source-name>`
  vendor-extended production.
- **`build-cir-scratch` is healthy and fast to use** for CIR questions; a
  `-fclangir -emit-cir` syntax probe is a couple of seconds. Remember it is
  `unicode-operators-experiment`, so pass no feature flag and check any
  conclusion against `git show upstream/main:` before generalising it.

## Forward notes for the NEXT step (written after reading its step file)

**upstream-triage** is the next unchecked step and it is unblocked. It asks for
report-or-WONTFIX on five rows, and it says "file the ones you decided to
report".

- **Ask the author first, or draft rather than file.** This step was written to
  file three issues and was amended to draft them. There is no reason to think
  the amendment was about *these* three specifically rather than about an agent
  posting to a public tracker at all. If you draft, put the files next to mine
  in [`upstream-drafts/`](../upstream-drafts/README.md), one per slug, same
  shape — metadata block (target, labels, trunk revision, duplicate searches),
  then title, then body — and say *drafted, pending filing* in the `Closed by`
  cell rather than closing the row. A WONTFIX row closes normally; only the
  "report" ones are affected.
- **The duplicate-search recipe above is the one to reuse**, and two of your
  five are old enough that a duplicate is genuinely likely —
  [`auto-return-round-trip`](../../BACKLOG.md#auto-return-round-trip) and
  [`pch-ast-print-order`](../../BACKLOG.md#pch-ast-print-order) are `-ast-print`
  round-trip complaints, and `"-ast-print"` as a quoted phrase is a productive
  query. Remember a duplicate found is a real result and closes the row better
  than a new issue would.
- **[`cxxfilt-stdin-nonascii`](../../BACKLOG.md#cxxfilt-stdin-nonascii) has a
  live neighbour**: #178767, "[tools][cxxfilt] llvm-cxxfilt cannot undecorate a
  valid c++ symbol", open. Read it before writing anything — it may be the same
  splitting bug seen from another angle.
- **Confirm on current trunk the same way.** `build-main` is stale (above); for
  `llvm-cxxfilt` and `-ast-print` the honest check is the newest build plus a
  `git diff` of the implicated file between that build's base and
  `upstream/main`. `~/src/llvm/main` is fetched as of 2026-09-06, so
  `upstream/main` is local and no network is needed for the source reads.
- **[`operator-caret-range`](../../BACKLOG.md#operator-caret-range)'s WONTFIX
  case is already made for you**, and this step re-checked it on the pristine
  `build-main` binary rather than leaving you to: `operator+(a,a)` and
  `operator""_x(a)` on undeclared operators both give
  `error: use of undeclared '…'` with a caret underlining exactly the 8 columns
  of `operator` and nothing after it. Upstream's shape, no Unicode involved.
  Report it as the general case or not at all, exactly as the step file says.
- **Both WONTFIX candidates owe a design-doc sentence** (step file item 3). That
  is the part most likely to be dropped, and it is the part the papers need.

## Open risks / TODOs

- **Three reports exist and nobody upstream has seen them.** Until they are
  filed the three rows are open, the two dependent steps have no number, and the
  calendar-time argument that put this step first in the plan is not being
  spent. That is the author's call and it is now visible in five places: the
  three `Closed by` cells, the checklist line, and
  [`upstream-drafts/README.md`](../upstream-drafts/README.md).
- **The drafts will go stale.** Each cites line numbers at `72417eb739e5`;
  `ItaniumMangle.cpp`, `ParseExprCXX.cpp` and `CIRGenFunction.cpp` all moved
  substantially in the three months before it. Symbols are cited alongside every
  line number for that reason, but if filing is weeks away, re-read the four
  quoted hunks first. Ten minutes.
- **`operator--`'s divergence is in no paper.** U§13.1 and the paper now mention
  it, but the *prototype* evidence in `ops/` still only ever measured `++`
  before today. Nothing depends on it; noting it so nobody re-derives it.
- **A clean-trunk CIR build still does not exist here.** The diff argument is
  sound and is written into the draft, but if a triager asks "does it reproduce
  on a build with none of your patches", the honest answer today is "the code
  path is identical; we have not run it". Standing up one is hours, and the
  maintainer may prefer to let upstream's own CI answer it.
- **`docs/unicode-operators.md` is still not in `CLAUDE.md`'s Layout section**,
  and neither is `docs/open-decisions.md`. The plan's Housekeeping note assigns
  that to "whichever step first edits that file", and this step did edit it — I
  left it, because `CLAUDE.md` describes the *layout* and I would rather the
  step that rewrites U§7/§9 substantively take it than have a report-drafting
  step touch the repo's front door. It is still owed.
