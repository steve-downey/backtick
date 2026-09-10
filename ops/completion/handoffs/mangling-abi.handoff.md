# Handoff — mangling-abi — The ABI question, and U§9 with it

- **Status:** **GREEN (gate passed, and the step is complete).** It stood
  BLOCKED on the author on 2026-09-06 — which is what success looks like for a
  `Decide` step under this track's second rule — and the author answered the
  same day, **accepting the recommendation as written**. The answer is
  recorded, so the box is ticked. Same shape as
  [decision-brief](decision-brief.handoff.md), which stood blocked from
  2026-09-05 to 2026-09-06.
- **A second answer was recorded here as bookkeeping**, because it lives in
  the same document: [dependent-template-operator-id](../../../docs/open-decisions.md#dependent-template-operator-id)'s
  reopened report half is settled as **option (a), reword only, no upstream
  report**. None of the work it generates was done — the reword is
  [reconcile-declaring-using](../steps/reconcile-declaring-using.md)'s. See
  "The second answer" below.
- **Branch / commit:** no branch. `unicode-operators` in *this* repo only —
  `968cfe7` (`docs:`, U§9 and the decision entry), `97c7823` (`ops:`, the
  ledgers, the backlog row, the plan and `CLAUDE.md`), and the two commits
  recording the answers. **Nothing was built and
  no feature branch was touched**; `backtick-23`, `backtick-trunk`,
  `unicode-operators-experiment`, `unicode-operators-upstream` and the GCC
  `backtick` branch are untouched, as the step file's "No build; no feature
  branch touched" requires.
- **Date / agent:** 2026-09-06.

## The question, as it is now framed

**What does the paper ask the Itanium ABI group for?** That is the only open
thing in U§9, and framing it took most of the step, because the section
previously ran three questions together under one "flagged open, not
resolved". They are separable and only one of them needs the author:

| | Settled? | Where |
|---|---|---|
| What the prototype **implements** | yes — it is a measurement | [mangling-derivation-rule](../../../docs/unicode-operators.md#mangling-derivation-rule) |
| What the paper **asks for** | **answered 2026-09-06** — the recommendation, as written | [abi-production-request](../../../docs/unicode-operators.md#abi-production-request) |
| What is **unexamined** (Windows) | yes — a stated position, not silence | [microsoft-abi-position](../../../docs/unicode-operators.md#microsoft-abi-position) |

The three options are the step file's, with their costs measured rather than
asserted. The recommendation, **accepted by the author on 2026-09-06 as
written**, is:

> **(a) and (b) together, non-normatively.** Describe the vendor-extended form
> as the fallback that needs no ABI action — that it exists at all is a
> genuine result, because it means the feature is implementable and
> inspectable with today's toolchains — and *then* ask the ABI group for a
> first-class production, with a concrete shape, marked explicitly as a
> request rather than as proposed wording.

and the shape asked for is the `v` production with the vendor digit replaced
by a fixity marker and the vendor prefix by a standard code:

```
<operator-name> ::= uo <fixity> <source-name>    # user-defined operator
<fixity>        ::= i                            # infix
                ::= p                            # prefix
                ::= s                            # postfix (reserved; no v1 spelling)
```

`uo` is unused in the ABI's `<operator-name>` table (checked against the
current published grammar); the letters are the ABI group's to pick and the
section says so. Three things about the shape are load-bearing: **the fixity
marker**, which is the whole reason to ask; **the ASCII hex name** rather than
the operator's UTF-8 bytes; and **that it is a small delta** from a production
the ABI already has and every demangler already parses.

**The postfix constraint was honoured, and it is the strongest argument in the
brief.** [decision-brief](decision-brief.handoff.md) answered
[postfix-operators](../../../docs/open-decisions.md#postfix-operators) as
*declined for v1, explicitly not foreclosed*, and handed the mangling clause
here. `v <digit> <source-name>` keys on **arity**, and prefix and postfix
unaries share arity 1 — so option (a) taken *alone*, if the vendor form ever
became the standardized encoding, would quietly foreclose the thing that
answer was careful to keep open. That is why the recommendation is not (a)
alone, and why `s` is reserved in the sketch rather than omitted. Nothing in
U§9 forecloses postfix; it is written to keep it takeable.

## The second answer, recorded here as bookkeeping

Not this step's question, and **none of the work it generates was done here.**
It is recorded in this step because it lives in
[`docs/open-decisions.md`](../../../docs/open-decisions.md), which this step
had open.

**[dependent-template-operator-id](../../../docs/open-decisions.md#dependent-template-operator-id),
the report half [upstream-triage](upstream-triage.handoff.md) reopened →
option (a): reword only, no upstream report.** The gap is this feature's own,
not inherited. Nothing is pending upstream, no draft is owed, and the row
closes on the reword alone.

Recorded in four places, because the false clause was in four:

| Where | What changed |
|---|---|
| [`docs/open-decisions.md`](../../../docs/open-decisions.md) | a dated answer after the reopening entry, and the **summary-table row 5** rewritten so it no longer reads as partly reopened |
| [`operator-id-anywhere`](../../unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere) | `Status:` restated as final and reword-only; the report obligation dropped; a pointer to its own *Recommended doc change* item (1) as the wording to use |
| [`dependent-template-operator-id`](../../BACKLOG.md#dependent-template-operator-id) | `Closed by` says it closes on the reword alone and names [reconcile-declaring-using](../steps/reconcile-declaring-using.md); the **Item** — which still asserted the false claim outright — carries a dated correction |
| `ops/completion/PLAN.md` | a Status row saying the answer was recorded and the reword was not written |

**The justifying clause reconcile-declaring-using must use**, so it does not
have to reconstruct this: *`DependentTemplateStorage` is keyed by an
`IdentifierInfo *` or an `OverloadedOperatorKind`, and a user operator is
neither — the same closure-over-a-fixed-operator-table cost as*
[declaration-name-plumbing](../../unicode-operators/clang/DEVIATIONS.md#declaration-name-plumbing)
*and*
[operator-candidate-assembly](../../unicode-operators/clang/DEVIATIONS.md#operator-candidate-assembly)
*, reaching a third data structure.* **The clause it must not use** — *"a
limitation user-defined literal operators have had since C++11"* — is false
(literal operators share the code path but suffer no limitation from it, since
[over.literal]/1 means no valid program contains the construct), and it is
what an *earlier* version of that step's own ledger row recommended. The row
now forbids it in the same item that supplies the replacement.

## What changed

**`docs/unicode-operators.md`** — §9 rewritten from five paragraphs into three
slug-headed subsections (so each is an anchor and can be linked), and the §2
[operator-mangling](../../../docs/unicode-operators.md#operator-mangling) entry
updated to point at them:

| Subsection | What it now carries |
|---|---|
| [mangling-derivation-rule](../../../docs/unicode-operators.md#mangling-derivation-rule) | the grammar box; the **derivation rule** as a block quote (`op_u` + uppercase hex, min four digits, widened above the BMP) instead of the `op_u229E` example; injectivity from the hex; the unexercised padding/astral branches; the two-demangler measurement with four symbol forms; the retained math-identifier disjointness paragraph; the inherited arity-digit wrinkle |
| [abi-production-request](../../../docs/unicode-operators.md#abi-production-request) | the open decision, in decision-brief's five-part shape: question, what was measured (4 bullets), the options (a)/(b)/(c), the cost of each, the recommendation with the sketched production and three notes, and `Status: open` |
| [microsoft-abi-position](../../../docs/unicode-operators.md#microsoft-abi-position) | Itanium reserves a production and Microsoft has none; the honest diagnostic the prototype emits; declaration accepted, definition rejected at codegen, pinned by a RUN line; and the one-line answer to "how much does this touch ABI?" |

**Ledgers and bookkeeping**

- [`vendor-extended-mangling`](../../unicode-operators/clang/DEVIATIONS.md#vendor-extended-mangling)
  → **RECONCILED**, naming a paragraph per clause (a/b/c). Its original prose
  is kept below a "Superseded prose" line as the record of what was found.
- [`msvc-mangling`](../../unicode-operators/clang/DEVIATIONS.md#msvc-mangling)
  → **RECONCILED**, naming all three paragraphs of
  [microsoft-abi-position](../../../docs/unicode-operators.md#microsoft-abi-position),
  and noting that the bare "unexamined" parenthetical is gone from §2's **Why**.
- [`postfix-operators`](../../unicode-operators/clang/DEVIATIONS.md#postfix-operators)
  — **clause (3) only** taken, into
  [abi-production-request](../../../docs/unicode-operators.md#abi-production-request)'s
  third measured bullet and Recommendation point 1. Clauses (1), (4) and (5)
  stay open and stay [reconcile-remainder](../steps/reconcile-remainder.md)'s;
  the row's `Status:` says exactly that.
- [`astral-plane-mangling`](../../BACKLOG.md#astral-plane-mangling) — `Closed
  by` filled: **recorded, not fixed, because there is nothing to fix.**
- The Unicode ledger's header no longer claims that no row has ever been
  reconciled; it names the two that now are.
- `ops/completion/PLAN.md` — checklist line annotated (unticked, and saying
  what is settled and what awaits), Housekeeping item closed, two Status rows.
- `CLAUDE.md` — Layout gains `docs/open-decisions.md` and an ABI clause for
  §9. This is the plan's standing Housekeeping item, which
  [upstream-reports](upstream-reports.handoff.md) and
  [upstream-triage](upstream-triage.handoff.md) both declined on the grounds
  that a narrow step should not rewrite the repo's front door. This step does
  rewrite §9 substantively, so it took it.

## Verification evidence

There is no build gate. The step file's gate is four bullets and all four are
met; the plan's docs gate is "every row this step claims to close is marked in
its ledger, naming the section **and paragraph** it landed in", which is why
the two `RECONCILED` markers above run long.

- **§9 answers all three questions** — implemented / asked for / unexamined —
  one subsection each, and the intro paragraph names them in that order.
- **It cites upstream-reports's issue** as far as one exists: the token
  `LLVM-ISSUE-PENDING`, in the fourth measured bullet, beside a link to the
  unfiled draft. `grep -rn LLVM-ISSUE-PENDING docs papers ops` is **unchanged
  at 4 substitution points** (U§9, U§13.1, `papers/unicode-mathematical-operators.md`
  Acknowledgments, [`postfix-operators`](../../unicode-operators/clang/DEVIATIONS.md#postfix-operators)
  clause (c)) plus the sites that merely describe the token. No number was
  invented.
- **Link check, repo-wide:** 1510 local links in `docs/`, `ops/` and
  `CLAUDE.md`, **0 broken** — file existence and GitHub-style anchor slugs
  both. (The checker's only hits are markdown-shaped things inside code spans,
  `[bool p, auto&& q](...)` and friends, in prose that predates this step.)
- **What was checked, not only changed:** the ABI production and its prose
  were read out of the published grammar, not taken from a handoff —
  `curl -sS https://itanium-cxx-abi.github.io/cxx-abi/abi.html`, §5.1.3
  *Operator Encodings*. `uo` was confirmed absent from the `<operator-name>`
  table before the sketch used it, and `ps`/`ng`/`ad`/`de` were confirmed to
  be the four unary codes cited in the arity/fixity bullet.

## Deviations from the plan / design

**One new ABI fact, and it is the reason the recommendation is not (a).** No
document in this repo had read the *prose* under the `v <digit> <source-name>`
production, only the production. §5.1.3 says:

> Vendors who define builtin **extended operators** (e.g. `__imag`) shall
> encode them as a `v` prefix followed by the operand count as a single
> decimal digit, and the name in `<length,ID>` form.

A user-declared operator is not a vendor builtin. The prototype's encoding is
grammatically well formed and demangles everywhere — that stands, and it is
measured — but it is **outside the stated purpose of the paragraph that
defines it**, which is the cleanest argument in the section for asking for a
first-class production rather than proposing the vendor form as the answer. It
is recorded in the second measured bullet.

A second, smaller one: §5.1.3's own opening line is *"Unlike Cfront, unary and
binary operators using the same symbol have different encodings"*, and the
table spends four codes (`ps`, `ng`, `ad`, `de`) keeping unary `+ - & *` apart
from their binary selves. Distinguishing forms of one symbol is a **principle
the ABI already holds**; the vendor production is simply the one place it has
no room to. That reframes the ask from "please add something new" to "please
extend a rule you already keep", which is a materially easier request, and it
is now in the third measured bullet.

Neither contradicts the design, so neither got a ledger row — they are
findings *for* the section, recorded in the section, which is where the
divergence rule sends them.

## Discoveries affecting later steps

- **The Itanium ABI HTML is worth reading, not just grepping.** ~290 KB,
  fetched in a second, and the *prose* between the productions is where two of
  this step's four measured bullets came from. Strip tags with
  `sed 's/<[^>]*>//g'` and take section numbers from the nearest preceding
  `<h4>`/`<h5>`, as the prior two handoffs said — but read the surrounding
  paragraph, not only the grammar line.
- **U§9 is now three anchors, and both papers will want to link them
  individually.** [unicode-paper](../steps/unicode-paper.md)'s step file
  already anticipates this ("mangling-abi rewrote U§9 — what is implemented,
  what is asked for…"); the split matches that sentence exactly.
- **The §2 decision entry and the section now disagree deliberately about
  scope**: [operator-mangling](../../../docs/unicode-operators.md#operator-mangling)
  stays `Proposed — open (ABI)` because *one third* of it is open, and its
  Status line says which third. Do not read the `open` marker as "none of this
  is settled" — the derivation and the Microsoft position are.
- **Nothing here is on a feature branch, so `REPLAY.md` gains no row.** The
  Unicode ledger's `RECONCILED` markers are the only state change outside the
  design doc.

## Forward notes for the NEXT step (written after reading its step file)

The next unchecked step is **[clang-paper-truth](../steps/clang-paper-truth.md)**
(ordinal 6). It is a *code* step on the backtick branches and shares nothing
with this one, which is the good news: **it is not blocked by the author's
answer here**, and its own dependency line already says it may run while
decision-brief is blocked, so the same reasoning covers a blocked mangling-abi.

- **It is the first code step in this track since `BL04`.** Everything since
  has been documents. Re-read the gate facts in `ops/backlog/PLAN.md` and
  `CLAUDE.md` before building — in particular the two that make a failed gate
  look green (`ninja … | tail` reports `tail`'s exit code; `check-clang`
  self-formats `clang/lib/Format/` **and** `clang/unittests/Format/` and
  aborts around step 81/970 before any lit test runs).
- **`backtick-23` has exactly one expected failure**,
  [`stray-clang-format-config`](../../BACKLOG.md#stray-clang-format-config),
  and `backtick-trunk` has none. The `DirectoryWatcherTest` cases are **not**
  expected failures any more — do not budget them and do not filter them out.
- **Its [`keyword-escape-round-trip`](../../BACKLOG.md#keyword-escape-round-trip)
  item contains a decision, and this track's ground rule applies to it.**
  `DeclarationName::print`'s `Identifier` arm is also the diagnostic path, so
  "should every diagnostic that names a keyword-escaped entity start printing
  backticks?" is a question with a paper consequence. The step file says to
  write the decision down; if it feels like the author's rather than the
  implementer's, the precedent is right here — brief it, stop, and say so.
  Give it a slug and a section in
  [`docs/open-decisions.md`](../../../docs/open-decisions.md) if you do; that
  file's front matter names the three items deliberately *not* in it, and a
  fourth would need adding there too.
- **`build-main` is 2.8 months stale** (`a815e6f267c1`, vs trunk
  `72417eb739e5` as of 2026-09-06) and is not a current-trunk oracle. The
  cheap technique the last two steps used: extract the implicated function
  with `awk '/^ReturnType Class::fn\(/,/^}/'` from `git show upstream/main:<path>`
  and from the branch, and `diff`. `~/src/llvm/main` is fetched, so no network
  is needed.
- **Do not touch U§9 to record anything about backtick mangling.** The
  keyword escape yields an ordinary identifier and mangles as one; if that
  needs saying, it belongs in `docs/backtick-operator-design.md`, and U§9's
  three subsections are about the *Unicode* operator name kind only.

**Two carried-forward items that are currently unowned**, noted here because
nothing else will remind anyone of them:

- **The `static-member-operators` decision entry is the only *new* document
  [decision-brief](decision-brief.handoff.md)'s answers require, and it has no
  ledger row to prompt it.** The
  [over-oper-restrictions](../../../docs/open-decisions.md#over-oper-restrictions)
  answer says static members stay rejected *on the two-spellings reason*, and
  that reason has to be written down somewhere a paper can cite.
  [reconcile-declaring-using](../steps/reconcile-declaring-using.md) owns U§7
  and is the natural home; the entry belongs in
  `docs/unicode-operators.md` §2, slug-headed like its neighbours.
- **`CheckUserOperatorDeclaration`'s comment still asserts the abandoned
  reason.** On both Unicode branches it says the rejection is because a static
  member has no implicit object parameter; the design has abandoned that
  reason in favour of the two-spellings one. One line, on two branches, owned
  by nobody — it wants whichever step next builds on
  `unicode-operators-experiment` / `unicode-operators-upstream` (M2 is the
  first that will), and it must land on **both**, gated behind the flag like
  everything else.

## Open risks / TODOs

- **The answer commits the paper to a shape it may be argued out of in the
  room, and that is the point of asking rather than deciding.** If it has to
  move, the edit is contained: the Recommendation block in
  [abi-production-request](../../../docs/unicode-operators.md#abi-production-request)
  is the only prose that changes, the four measured bullets stand whatever is
  asked for, and the one downstream consequence is already resolved —
  [`astral-plane-mangling`](../../BACKLOG.md#astral-plane-mangling)'s
  `Closed by` now says the untested-branches paragraph **reaches the paper**,
  because the derivation is part of what is being proposed.
- **What the papers still cannot claim.** (i) **No issue number.** U§9 and
  `papers/unicode-mathematical-operators.md` both say `LLVM-ISSUE-PENDING`; until the maintainer
  files the [draft](../upstream-drafts/increment-decrement-mangling.md), the
  papers cannot say "reported as #N", and the fixity argument rests on a
  divergence a reader must reproduce themselves. (ii) **Nothing has been put
  to the ABI group.** Whatever the author chooses, the paper can say what it
  *asks*, not what any ABI group has said back. (iii) **Nothing is claimed
  about Microsoft beyond the shape of the gap** — that is deliberate and
  stated, but it does mean the paper cannot claim the feature is portable.
  (iv) **The `uo` letters are this repo's invention**, offered as a shape; the
  paper must not present them as agreed.
- **`papers/unicode-mathematical-operators.md` has not been updated to match the new §9** and
  deliberately so — the paper is [unicode-paper](../steps/unicode-paper.md)'s,
  and it should be written from the *answered* section, not from a
  recommendation. Its Acknowledgments paragraph is the only place it currently
  touches this material.
- **The `v`-production evidence is a 2026-08-04 measurement** (U09: two
  demanglers, ten symbol forms, binutils `c++filt` 2.46). Nothing suggests it
  has moved, and the symbols are pinned by a lit test on both Unicode
  branches, but if a reviewer asks for it fresh it is a rebuild away and the
  branches have since been rebased.
