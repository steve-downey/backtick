# Handoff — upstream-triage: five annoyances triaged, two closed, three drafted, and one report that must not be filed

- **Status:** DONE (the step's own gate passed in full). Two qualifications,
  both stated on the checklist line as well as here: the three "report" rows
  are **drafted, not filed**, on the same amendment
  [upstream-reports](upstream-reports.handoff.md) carried; and the **sixth**
  item this step was given — the upstream half of
  [`dependent-template-operator-id`](../../BACKLOG.md#dependent-template-operator-id)
  — **was not done and has no draft**, because the report would have been
  wrong. That item is returned to the author, not deferred.
- **Branch / commit:** no branch. `ops/completion` track, this repo only.
  Nothing landed on `backtick-23`, `backtick-trunk`,
  `unicode-operators-experiment`, `unicode-operators-upstream` or the GCC
  `backtick` branch; all five confirmed **CLEAN** by `git status --porcelain`
  before and after. No compiler source was modified anywhere, and nothing was
  built in `~/src/llvm/main` / `~/src/llvm/build-main` — its binaries were run,
  nothing else.
- **Date / agent:** 2026-09-06.

## The six, each with its decision and its reason

| Row | Decision | Reason in one line | Closes? |
|---|---|---|---|
| [`inner-call-source-range`](../../BACKLOG.md#inner-call-source-range) | **WONTFIX** | The wrapper spans the written expression and the inner `CallExpr` takes its begin from its callee — exactly what upstream's own C++20 rewritten comparison does — and there is no upstream-visible symptom to report because upstream has no user-infix operators. | **Yes** |
| [`cxxfilt-stdin-nonascii`](../../BACKLOG.md#cxxfilt-stdin-nonascii) | **REPORT** | `IsLegalItaniumChar` rejects every byte `>= 0x80`, so the stdin splitter cuts a UTF-8 identifier apart and argv and stdin disagree inside one tool. | No — [drafted](../upstream-drafts/cxxfilt-stdin-nonascii.md), pending the maintainer |
| [`auto-return-round-trip`](../../BACKLOG.md#auto-return-round-trip) | **REPORT** | `DeclPrinter` prints the *deduced* return type for a specialization of an `auto` template, so the printed source no longer matches its own primary and does not compile; `getDeclaredReturnType()` exists and is documented for exactly this. | No — [drafted](../upstream-drafts/auto-return-round-trip.md), pending the maintainer |
| [`pch-ast-print-order`](../../BACKLOG.md#pch-ast-print-order) | **REPORT** | Both external-storage loaders splice at the head of the `DeclContext` chain, so the group that loads second ends up first; open **#24794** is the same two functions with its other half already fixed. | No — [drafted](../upstream-drafts/pch-ast-print-order.md), pending the maintainer |
| [`operator-caret-range`](../../BACKLOG.md#operator-caret-range) | **WONTFIX** | It is upstream's caret range for *every* operator-function-id — `operator+` and `operator""_x` in stock C++ with no flag give the identical 8 columns — so it is cosmetic, not a regression, and no paper claim depends on it. | **Yes** |
| [`dependent-template-operator-id`](../../BACKLOG.md#dependent-template-operator-id) (report half) | **CANNOT BE FILED — returned to the author** | The literal-operator reproducer is *correctly* rejected: a literal operator can never be a class member, so the construct names nothing that could exist, and trunk says so at the site in a comment. | No — the question is reopened |

Both WONTFIX reasons are written into the row **and** into a design doc, per
the step file's item 3, so the papers answer the question rather than being
asked it.

## What changed

New, in [`upstream-drafts/`](../upstream-drafts/README.md), following that
directory's established shape exactly — metadata block (target, labels, trunk
revision, duplicate searches), then title, then body:

| File | What it reports |
|---|---|
| [`cxxfilt-stdin-nonascii.md`](../upstream-drafts/cxxfilt-stdin-nonascii.md) | the stdin/argv split; 5 queries; #39337 and #118705 as prior art; an explicit "#178767 is not this bug" note |
| [`auto-return-round-trip.md`](../upstream-drafts/auto-return-round-trip.md) | the deduced-return-type print; 6 queries; #12178 / #218420 / #147150 as the same family |
| [`pch-ast-print-order.md`](../upstream-drafts/pch-ast-print-order.md) | the two head-splices; 7 queries; **probably a comment on #24794 rather than a new issue**, and the body is written to work either way |

Edited:

- `ops/BACKLOG.md` — six `Closed by` cells. Two WONTFIX with their reasoning
  and their design-doc destinations; three "drafted, pending filing" linking
  their drafts; and
  [`dependent-template-operator-id`](../../BACKLOG.md#dependent-template-operator-id)
  rewritten to say the pair has become a single done half and a reopened
  question. Two **Item** corrections are folded into the cells rather than
  given rows of their own (divergences append to the entry that owns the
  claim).
- `docs/backtick-operator-design.md` — new **§17.5**, "Source ranges of the
  desugared node", and a second dated `Log.` entry on
  [source-fidelity-node](../../../docs/backtick-operator-design.md#source-fidelity-node),
  which is the decision that owns the wrapper node and therefore owns this.
  **No new slug was minted**: the finding belongs to an existing question, and
  the convention is that a divergence appends to the implicated entry.
- `docs/unicode-operators.md` — §7 "Desugaring" gains a closing sentence
  pointing at that decision and §17.5; §10 gains a new slug-headed subsection
  [operator-name-caret-range](../../../docs/unicode-operators.md#operator-name-caret-range),
  so the caret finding is an anchor a later document can link to.
- `docs/open-decisions.md` — a dated entry in the Answers section, *"the report
  half is reopened"*, and the summary table's row 5 annotated to point at it.
- [`operator-id-anywhere`](../../unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere)
  — the false clause struck in three places: the `Status:` line, the "What was
  true" conclusion, and Recommended doc change (1), which explicitly told a
  later agent to write the false sentence into U§7.1. Row stays **OPEN** — the
  reword is still unwritten.
- `ops/completion/PLAN.md` — box ticked with its qualification, the Coverage
  table's "upstream-triage (2nd)" row corrected, three Status-log rows.
- [`upstream-drafts/README.md`](../upstream-drafts/README.md) — retitled to six
  defects across two steps, a `From` column added, and a closing section
  **"The seventh report, which is not here"** so nobody goes looking for a
  draft that was deliberately not written.

## Verification evidence

### What was checked, not only what was changed

**Trunk is `72417eb739e5`** (2026-09-05), already fetched into
`~/src/llvm/main`; no network was needed and nothing was fetched or built
there. **No build here is on trunk** — the newest base is `d28193fa1ff6`
(2026-08-04, `~/src/llvm/build-unicode-upstream`, tip `783a9c1a5f6f`) and
`build-main` is `a815e6f267c1` (2026-06-13, ~2.8 months stale). So I used
[upstream-reports](upstream-reports.handoff.md)'s method: read the implicated
code at `72417eb739e5`, and reproduce on the newest build whose relevant code
is identical to that revision. **The identity was checked, not assumed:**

```console
$ git diff --numstat d28193fa1ff6 upstream/main -- <file>
clang/lib/AST/DeclBase.cpp                     IDENTICAL
llvm/tools/llvm-cxxfilt/llvm-cxxfilt.cpp       IDENTICAL
clang/lib/AST/DeclPrinter.cpp                  47+/19-   -> VisitFunctionDecl extracted from both: IDENTICAL
clang/lib/Sema/SemaTemplate.cpp                103+/92-  -> the IK_LiteralOperatorId arm: IDENTICAL
```

Every reproduction below therefore exercises today's trunk code, and every
quote is from `72417eb739e5` itself.

**[`cxxfilt-stdin-nonascii`](../../BACKLOG.md#cxxfilt-stdin-nonascii) —
reproduced from a real compiled symbol, on two builds.**

```console
$ clang++ -std=c++23 -c ext-id.cpp -o ext-id.o     # int ∂(int x) { return x; }
$ llvm-nm --defined-only ext-id.o
0000000000000000 T _Z3∂i
$ llvm-cxxfilt '_Z3∂i'                              # argv
∂(int)
$ echo '_Z3∂i' | llvm-cxxfilt                       # stdin
_Z3∂i
$ llvm-nm --defined-only ext-id.o | llvm-cxxfilt    # the realistic pipeline
0000000000000000 T _Z3∂i
```

ASCII control passes on both paths. Cause read at `72417eb739e5`:
`llvm_cxxfilt_main` passes `Split=true` for stdin and `false` for argv;
`SplitStringDelims` cuts on `!IsLegalItaniumChar`, which is
`isAlnum(C) || C=='.' || C=='$' || C=='_'` — `char` is signed, so all three
UTF-8 bytes of `∂` are delimiters.

**[`auto-return-round-trip`](../../BACKLOG.md#auto-return-round-trip) —
reproduced with its control, on two builds, character-identical output.**

```console
$ clang++ -std=c++23 -Xclang -ast-print -fsyntax-only auto-rt.cpp > out.cpp
$ clang++ -std=c++23 -fsyntax-only out.cpp
out.cpp:4:16: error: no function template matches function template specialization 'f'
note: candidate template ignored: could not match 'auto (int)' against 'int (int)'
```

The printed specialization is `template<> int f<int>(int t)` against a primary
of `template <class T> auto f(T t)`. **Control:** the same shape with an
explicit return type (`template <class T> T g(T t)`) round-trips and compiles,
exit 0 — which is what isolates deduction as the cause. `decltype(auto)`
behaves identically. The non-template `auto k(int t)` also prints as
`int k(int t)`, but has no primary to disagree with, so it still compiles;
that boundary is in the draft.

**[`pch-ast-print-order`](../../BACKLOG.md#pch-ast-print-order) — reproduced,
and the trigger isolated.**

```console
$ clang -cc1 -std=c++23 -ast-print -include pch2.cpp pch2.cpp > direct.txt
$ clang -cc1 -std=c++23 -include-pch pch2.pch -ast-print pch2.cpp > pch.txt
$ diff -u direct.txt pch.txt
 struct Mem {
-    int v;
     constexpr int get() const { … }
     constexpr int add(int n) const { … }
+    int v;
 };
```

**The trigger matters and the row did not have it** (table verified, three
cases): with nothing naming `Mem` after the PCH there is **no difference**;
`Mem g;` is enough to produce it; a member call likewise. Cause read at
`72417eb739e5`: `RecordDecl::LoadFieldsFromExternalStorage` splices fields at
the head, then `DeclContext::LoadLexicalDeclsFromExternalStorage` reads
everything, drops the fields via `BuildDeclChain`'s
`FieldsAlreadyLoaded && isa<FieldDecl>(D)` continue, and splices the rest at
the head *again*. Its own comment — "Splice the newly-read declarations into
the beginning of the list" — is only order-preserving when the list is empty,
which stops being true the moment `field_begin()` has run.

**[`operator-caret-range`](../../BACKLOG.md#operator-caret-range) — re-checked
independently rather than taken from the prior handoff**, in stock C++23 with
**no feature flag**, on `build-main` (pristine) and `build-unicode-upstream`:

```
error: use of undeclared 'operator+'          error: use of undeclared 'operator⊞'
  int f() { return operator+(a, a); }           int f() { return operator⊞(a, a); }
                   ^~~~~~~~                                      ^~~~~~~~
```

Both builds, both spellings, the same 8 columns; `operator""_x` too.

**[`inner-call-source-range`](../../BACKLOG.md#inner-call-source-range) —
reproduced on both feature branches, and the WONTFIX's premise tested.**

```
UserOperatorExpr <col:30, col:36> 'int' infix '⊞' U+229E    # spans x ⊞ y — correct
`-CallExpr      <col:32, col:36> 'int'                      # begins at the glyph
```

The premise the WONTFIX rests on — "a semantic form carrying the callee's
range is what `-ast-dump` does for every desugaring" — was **not** taken on
trust. Control, stock C++20, no feature:

```
CXXRewrittenBinaryOperator <col:28, col:32> 'bool'       # spans p < q
`-CXXOperatorCallExpr      <col:28, col:30> 'bool' '<'   # does NOT span it
```

That is a shipped C++20 feature whose inner synthesized node has a range that
does not match the written form, and nobody treats it as a defect. The
argument holds, and it now has a citation rather than an assertion.

**[`dependent-template-operator-id`](../../BACKLOG.md#dependent-template-operator-id)
— the report was tested before being written, and failed the test.**

```console
$ clang++ -std=c++23 -fsyntax-only deptmpl.cpp        # no feature flag, both builds
error: literal operator 'operator""_lit' must be in a namespace or global scope
error: 'operator""_lit' following the 'template' keyword cannot refer to a dependent template
```

The reproducer cannot be written without a **second, prior** error: the member
declaration it needs is itself ill-formed. Four spellings tried — member,
static member, member template, and a class using-declaration importing a
namespace-scope one — all rejected, and `g++` agrees
(*"must be a non-member function"*). [over.literal]/1 is why. And trunk
handles the kind on purpose (`Sema::ActOnTemplateName`, `SemaTemplate.cpp`,
identical between the build base and `72417eb739e5`):

```cpp
  case UnqualifiedIdKind::IK_LiteralOperatorId:
    // This is a kind of template name, but can never occur in a dependent
    // scope (literal operators can only be declared at namespace scope).
    break;
```

The positive control still holds: `t.template operator+<int>(0)` compiles.

### Duplicate searches — 18 queries, no duplicate for any of the three

`gh api -X GET search/issues -f q='repo:llvm/llvm-project is:issue …'`, open
and closed, per the prior handoff's recipe (`gh search issues` ANDs over title
*and* body and gives false negatives). Full lists are in each draft. **Note the
search endpoint has a secondary rate limit that `gh api rate_limit` does not
show** — it returned 403 with `search.remaining` reporting 30; spacing the
calls out cleared it.

Four results are worth carrying forward:

- **#24794** (open since 2015) — the *hit*, found by querying the internal
  symbol `BuildDeclChain` rather than the symptom. Same two functions as the
  PCH defect. Its reported half (the field loader *assigned* to the chain and
  expelled decls) **has been fixed**; trunk splices. The ordering half survives
  because both splices go to the front. Not a duplicate, but very likely where
  the report belongs.
- **#39337** (closed FIXED, 2019) — the feature request that added the
  cxxfilt line-splitting in the first place, so it is where the
  under-inclusive predicate came from. **#118705** fixed a crash in that same
  path, which shows it is maintained.
- **#12178** (open since 2012, "clang -ast-print isn't production quality") is
  the umbrella for `-ast-print` emitting non-compiling source, with **#218420**
  and **#147150** as two other live instances. Cited as prior art in the
  `auto` draft, with the argument for a separate issue stated (one-line cause,
  named accessor).
- **#178767 is *not*
  [`cxxfilt-stdin-nonascii`](../../BACKLOG.md#cxxfilt-stdin-nonascii)** —
  correcting the prior handoff's forward note, which flagged it as possibly the
  same bug from another angle. Checked: that symbol fails on the **argv** path
  too, so it is a demangler limitation, whereas this bug is precisely that argv
  and stdin disagree.

### Docs gate

- All five rows named by the step have a non-empty, reasoned `Closed by`. Every
  WONTFIX gives a reason that stands without this plan (upstream's own
  behaviour, reproduced, with a control); every "report" links a complete
  draft in place of the URL the amendment removed.
- **1437 local links across 177 markdown files checked; 0 broken outside
  pre-existing ones.** The 34 hits are all in the vendored `papers/wg21/`
  tooling docs and two `path` placeholders in earlier handoffs, none touched
  here. The three anchors this step created —
  [`operator-name-caret-range`](../../../docs/unicode-operators.md#operator-name-caret-range),
  the `source-fidelity-node` Log destination, and the reopening entry in
  `docs/open-decisions.md` — all resolve.
- `grep -rn LLVM-ISSUE-PENDING docs papers ops` is **unchanged at 4
  substitution points**. None of this step's three defects is cited outside
  `ops/`, so filing them costs no document edit; the drafts README now says so.

## Deviations from the plan / design

Four, all corrections to things that were on file. Each was fixed in the row or
clause that owns the claim rather than given a ledger row of its own, per the
convention that a divergence appends to the implicated entry.

1. **The sixth item's report cannot be filed, and this is the significant
   one.** I was directed to file it against the literal-operator reproducer
   specifically, and explicitly told not to generalise it into a user-operator
   report. Both instructions are right in their own terms and the first is
   unexecutable: the reproducer is correctly rejected. **I did neither** — no
   bogus draft, no unauthorised generalisation — and returned the question with
   the evidence. What this costs the design is not small: the control that
   turned this from a defect into a decision was "the identical construct on a
   literal operator gives the identical diagnostic, therefore the limitation is
   inherited". The first clause is true and the conclusion does not follow.
   Literal operators share the code path and suffer **no limitation** from it,
   because no valid program puts them there. **The limitation is exclusive to
   the new name kind**, and the sentence
   [`operator-id-anywhere`](../../unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere)
   told a later agent to write into U§7.1 — "a limitation user-defined literal
   operators have had since C++11" — is false. Struck there, corrected wording
   supplied in the reopening entry.
2. **[`inner-call-source-range`](../../BACKLOG.md#inner-call-source-range)'s
   re-grade is wrong about the cost.** It says fixing it needs "an
   upstream-shaped `CallExpr::Create` overload" because the cached begin loc
   has "no public setter". There *is* one: `CallExpr::setUsesMemberSyntax()` is
   public, clears `HasTrailingSourceLoc`, calls `updateTrailingSourceLoc()`,
   and `getBeginLoc()` then returns argument 0's begin — the wanted range,
   today, with no upstream change. The row still closes WONTFIX, on a
   **better** reason: that bit asserts "a call to an explicit-object member
   function written with member syntax", which is false of these nodes, and it
   is serialized into PCHs and modules for any later upstream consumer to read
   back. Declined on meaning, not on cost — and the row now says which.
3. **[`pch-ast-print-order`](../../BACKLOG.md#pch-ast-print-order) is
   under-specified and the obvious reproducer does not reproduce.** "Prints a
   class's fields last" is true only when the class is *used* from the main
   file. My first attempt — class in the PCH, empty main file — printed in
   source order and looked like a non-defect. Corrected in the row and pinned
   with a three-case table in the draft.
4. **#178767 is not the cxxfilt bug**, contrary to the prior handoff's forward
   note. See above.

## Discoveries affecting later steps

- **Querying by internal symbol name beats querying by symptom.** Seven
  symptom-shaped queries for the PCH defect returned **zero** results; one
  query for `BuildDeclChain` found the ten-year-old open issue about the same
  two functions. When a defect has a cause, search the cause. This is the
  single most useful thing this step learned and it generalises to every
  remaining upstream question.
- **`gh api search/issues` has a secondary rate limit invisible to
  `gh api rate_limit`.** It 403s while `.resources.search.remaining` still
  reads 30. Space the calls; do not treat the 403 as "no results".
- **The build-base/trunk diff technique is cheap and worth doing every time.**
  Two of the five files I needed were byte-identical between `d28193fa1ff6`
  and trunk, which converts "my build is stale" into a one-line fact in the
  report. For the three that differed, extracting the single function with
  `git show upstream/main:<path>` and diffing was seconds.
- **`~/src/llvm/build-unicode-upstream` is the right binary for stock-C++
  questions** — newest base here, and passing no feature flag makes it behave
  as trunk. `build-main` remains useful as the pristine second opinion, which
  is how the caret range was double-checked.
- **[`backtick-source-range`](../../BACKLOG.md#backtick-source-range)'s
  `Closed by` still says `BL06`, which no longer exists.** The Coverage table
  routes it to [clang-paper-truth](../steps/clang-paper-truth.md). I did not
  edit it — it is that step's row, not mine — but noting it so it is not read
  as already closed. Related: the `-ast-dump` above shows
  `BacktickInfixExpr <col:33, col:36>` spanning only the operator name for
  `` return x `add` y; `` (operands at cols 30 and 38), which is that row's
  defect, still live, and is a ready-made before/after for it.

## Forward notes for the NEXT step (written after reading its step file)

The next unchecked step is **[mangling-abi](../steps/mangling-abi.md)** (ordinal
5); ordinal 4 is checked and ordinal 8 is `[—]`.

- **Its dependency is satisfied but hollow, and the plan already says so.** It
  depends on [upstream-reports](../steps/upstream-reports.md) "so it can cite
  the issue number", and **there is no issue number** — that report is drafted
  and unfiled, as are mine. Write around the literal token
  `LLVM-ISSUE-PENDING`; do not invent a number and do not wait for one. The
  four substitution points are unchanged by this step.
- **Nothing I triaged is mangling-adjacent, with one near-miss worth knowing.**
  [`cxxfilt-stdin-nonascii`](../../BACKLOG.md#cxxfilt-stdin-nonascii) is about
  demangling *extended-identifier* names, not operator names — this feature's
  derived names are ASCII by construction, so §9 is unaffected. But if §9 ends
  up recommending anything that would put non-ASCII bytes in a mangled name,
  that draft becomes directly relevant and should be cited. It is the kind of
  thing worth one sentence in §9's tooling paragraph either way: the pipeline
  `nm | c++filt` already loses extended identifiers today.
- **The prior handoff's Itanium ABI note is good and still applies**:
  `curl -sS https://itanium-cxx-abi.github.io/cxx-abi/abi.html` is ~290 KB,
  greppable, and section numbers come from the nearest preceding `<h4>`/`<h5>`.
  mangling-abi wants it for the `v <digit> <source-name>` vendor-extended
  production. §5.1.3 and §5.1.6 are already found and recorded.
- **Do not re-derive the fixity argument** — [upstream-reports](upstream-reports.handoff.md)
  established it (`pp_`/`pp`, `mm_`/`mm`, Clang wrong and GCC right) and
  `docs/unicode-operators.md` §9's closing paragraph already carries the
  sentence mangling-abi was told to expect.
- **Housekeeping is still owed and mangling-abi is a fair place for it**:
  `CLAUDE.md`'s Layout section mentions neither `docs/unicode-operators.md`
  nor `docs/open-decisions.md`. The plan assigns it to "whichever step first
  edits that file"; two steps have now declined it on the grounds that a
  narrow step should not rewrite the repo's front door. mangling-abi rewrites
  U§9 substantively, which is a better claim on it than either of ours.

## Open risks / TODOs

- **The reopened decision blocks nothing, and should not be allowed to look
  like it does.** The reword half owed by
  [reconcile-declaring-using](../steps/reconcile-declaring-using.md) is
  **unblocked** — only the justifying clause changed, and the corrected wording
  is in the reopening entry. If the author never revisits the report question,
  the row closes on the reword alone (option (a)), which was always a
  defensible answer. Nothing downstream needs the issue.
- **Six drafts now exist and nobody upstream has seen any of them.** Three from
  the prior step, three from this one. The calendar-time argument that placed
  this phase first in the plan is not being spent. That is the author's call
  and it is visible in the rows, the checklist lines and the drafts README.
- **The drafts will go stale.** Mine cite line-adjacent facts at
  `72417eb739e5`; `DeclPrinter.cpp` and `SemaTemplate.cpp` both moved
  substantially in the month before it. Every quote is anchored to a symbol as
  well as a file, so re-checking is minutes, but do re-read the quoted hunks if
  filing is weeks away.
- **The PCH report may be better as a comment than an issue**, and I could not
  decide that for the maintainer. #24794 is ten years old and open; adding to
  it risks the finding being lost in a stale thread, while a new issue risks
  being closed as a duplicate of it. The draft is written to serve either and
  says which sections to drop for the comment form.
- **One thing I deliberately did not check**: whether the `auto` round-trip
  defect also affects class templates and variable templates with deduced
  types. The report stands on the function-template case, which is reproduced
  and controlled; widening it without testing would weaken it.
