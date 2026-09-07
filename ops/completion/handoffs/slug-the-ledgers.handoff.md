# Handoff — slug-the-ledgers — Retire the serial numbers

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators` in *this* repo only —
  `d90c65b89ff5` (the slugging) plus a follow-up carrying this handoff. No
  feature branch was touched, no compiler built, nothing landed in any LLVM or
  GCC worktree.
- **Date / agent:** 2026-09-05

## What changed

**New file.** [`ops/SLUGS.md`](../../SLUGS.md) — **106** retired identifiers
mapped to slugs, both directions (number → slug with a link to the entry, and
slug → number), plus the record of what was deliberately *not* renamed and why.

**The two decision logs**, converted from table rows to sections headed by
their slug, with the full convention shape — **Question / Status / Decision /
Why / Log**, plus **Decided by** so a later reader can tell a ruling from an
observation:

- `docs/backtick-operator-design.md` §3 — 16 entries, `D1`–`D16`.
- `docs/unicode-operators.md` §2 — 12 entries, `U1`–`U12`, reordered so
  `operator-identifier-disjointness` sits with the other lexical decisions
  instead of after the paper-scope one (the old table had `U10` last).

**The three deviation ledgers**, same treatment, keeping their own column
names as fields and gaining a **`Status:`** field:

- `ops/DEVIATIONS.md` — 9 entries (`DEV-01`–`DEV-09`).
- `ops/gcc/DEVIATIONS.md` — 7 entries (`DEV-G04`–`DEV-G08`, including the
  `a`/`b`/`c` splits).
- `ops/unicode-operators/clang/DEVIATIONS.md` — 24 entries
  (`DEV-U01`–`DEV-U24`), **all `OPEN`**, which is accurate: this ledger has
  never marked a row and the plan's ground rule now says how it starts.

**`ops/BACKLOG.md`** — 38 defect entries (`B01`–`B38`), sections headed by
their slug, keeping `Severity` / `Item` / `Where` / `Closed by` as fields. An
unowned row's `Closed by` is now an em dash rather than an empty table cell.

**The cross-reference sweep** — 792 bare mentions rewritten as **links to the
anchor**, across `CLAUDE.md`, both design docs, `ops/PLAN.md`,
`ops/BACKLOG.md`, the three ledgers, all of `ops/completion/`, and
`ops/backlog/steps/BL05`–`BL07`.

**The papers lost their identifiers outright.** 17 in `papers/backtick-infix-and-keyword-escape.md` and
2 in `papers/unicode-mathematical-operators.md` were **removed**, not renamed — nine section headings
shed a trailing `(D6)`-style parenthetical, and the running text now describes
the reason or the effect. `papers/backtick-infix-and-keyword-escape.md`'s "Design choices and decisions"
lead-in no longer promises that "EWG poll outcomes can be recorded against
these numbers"; it says the decisions are one to a section so EWG can poll any
one of them on its own, which is the thing that was actually wanted.

**The conventions now require this of later work:**

- `ops/AGENT_PROTOCOL.md` gains a "Naming, for anything you add" section — slug
  the question or the job, head a section with it, link every reference.
- `ops/HANDOFF_TEMPLATE.md`'s deviations prompt asks for a link, not a mention.
- `ops/completion/PLAN.md`'s ground rules: the "everything new is named" rule
  now covers what a step *adds*, not only what this step renamed; and the
  "mark the ledger" rule points at the `Status:` field rather than at "the last
  column", which no longer exists.
- `CLAUDE.md`'s Layout gains `ops/SLUGS.md` and drops three now-meaningless
  identifier *ranges* (`D1–D16`, `U1–U11`, `B01–B38`).

**Step-file titles.** Seven `ops/completion/steps/*.md` H1s had been mechanically
turned into strings of links; they are plain prose again. The `Closes:` line
directly beneath each one carries the links.

## Verification evidence

No build, no feature branch — correct for this step.

**Gate 1–3, the three greps the step file names**, run over `docs/`, `papers/`,
`ops/*.md` and `ops/completion/`:

```
grep -rnE '\bD1?[0-9]\b'      -> 32 hits, all ops/SLUGS.md map rows
                                  + 3 in ops/completion/steps/slug-the-ledgers.md
grep -rnE 'DEV-[UG]?[0-9]'    -> 82 hits, all ops/SLUGS.md map rows
                                  + 5 in ops/completion/steps/slug-the-ledgers.md
grep -rnE '\bB[0-9][0-9]?\b'  -> 77 hits, all ops/SLUGS.md map rows
                                  + 2 in ops/completion/steps/slug-the-ledgers.md
                                  + 2 in ops/BACKLOG.md: `[B1.6]`, `[B1.8]`, `[B1.9]`
                                    — CFG **block labels** quoted from analyzer
                                    output, not defect ids. False positives.
```

`**Formerly:**` lines are excluded from all three counts, as the gate allows.

**Two live files still spell the retired identifiers, and both are deliberate:**

- **`ops/SLUGS.md`** is the map. It is the `Formerly:` line for the whole repo;
  if it did not name the numbers it would not work.
- **`ops/completion/steps/slug-the-ledgers.md`** is this step's own spec,
  quoting what it retired. It now opens with an `Executed` note saying so, so
  the hits read as history rather than as an oversight.

**The historical directories are excluded on purpose, and this is a decision.**
Every `handoffs/` tree, the completed tracks' step files and `PLAN.md`s, and
`ops/unicode-operators/clang/REPLAY.md` record what an agent knew at the time;
editing them to use names that did not then exist would make them lie. The
completed tracks' step ids (`S00`–`S12`, `G01`–`G10`, `U00`–`U21`,
`BL01`–`BL04`, `M1`/`M2`, `R23`/`R24`, `F23`/`F24`) are kept for the same
reason plus a harder one: they are in commit messages that cannot be rewritten,
and the handoff filenames are the only index into forty documents. Renaming
them would cost `git log --grep` and buy nothing. `ops/SLUGS.md` says all of
this at the top so a reader of an old handoff can translate.

**Gate: every reference is a link, and every link resolves.** Checked
mechanically over every tracked `.md` outside `papers/wg21/` (the vendored
pandoc framework), resolving each relative target's file *and* its anchor
against GitHub heading slugification:

```
local links: 828   anchored: 795   broken: 0
```

Including the untracked-at-the-time `ops/SLUGS.md` the count was 1029 / 1007 /
0. **A separate check that mattered more than it looks:** the mechanical sweep
first produced 382 links wrapped in backticks (`` `[slug](path)` ``), which
render as literal text and are *not* links, and 6 links inside fenced code
blocks, which render as raw markdown. Both classes were found by scanning inline
code spans for `](`, and both are now zero.

**Gate: the papers cite no internal identifier at all**, neither number nor
slug:

```
grep -nE '\bDEV-[UG]?[0-9]+\b|\bB[0-9]{2}\b|\bD[0-9]{1,2}\b|\bU[0-9]{1,2}\b' \
    papers/backtick-infix-and-keyword-escape.md papers/unicode-mathematical-operators.md papers/p0000r0.md docs/*.org
    -> (no output)
```

The two `.org` blog sources were already clean.

## Deviations from the plan / design

None that contradict the design — this step touches no compiler. Three
judgement calls the step file left open:

1. **The deviation ledgers became sections, not just renamed rows.** The step
   file says "same shape … the conversion is mostly naming", but the gate
   demands that every reference be a *link to an anchor*, and a table row is
   not an anchor. Sections were the only shape that satisfies both.
2. **`docs/pattern-syntax-audit.py` keeps `U1` and `U10`.** Not history — it
   *emits* those strings into `UnicodeOperatorCharSets.h`, which is committed
   on all four LLVM branches. Renaming them would make the regenerated header
   differ byte-for-byte from the one that shipped, for nothing but a name, and
   the reproducibility claim rests on that file regenerating identically. It is
   recorded as an explicit exclusion in `ops/SLUGS.md`, with the two slugs it
   wants, so whoever regenerates the tables decides whether to spend the diff.
3. **`ops/backlog/steps/BL05`–`BL07` were rewritten** although they live under
   a superseded plan, because `ops/completion/PLAN.md` schedules them —
   upstream-reports executes `BL05` verbatim. `BL01`–`BL04` were left alone.

## Discoveries affecting later steps

- **Two old `Decision` cells were topics, not decisions.** `D2` said
  "Precedence vs. unary prefix" and `D8` said "clang-format break policy" —
  the question, with the actual ruling buried in the rationale. Both were
  restated as decisions
  ([`precedence-level`](../../../docs/backtick-operator-design.md#precedence-level),
  [`format-break-policy`](../../../docs/backtick-operator-design.md#format-break-policy)).
  Worth knowing that the old log's second column was not uniformly a decision.
- **`U10`, `U11` and `U12` were genuinely ambiguous** and needed 20 decisions
  by hand: the Unicode *decisions* were `U1`–`U12` unpadded while the Unicode
  *steps* are `U00`–`U21` zero-padded, so `U10`/`U11`/`U12` collide exactly.
  In `ops/BACKLOG.md`'s `Where` fields and in the ledgers' `Found by` fields
  they are always steps; in `docs/unicode-operators.md` prose they are always
  decisions; in `ops/unicode-operators/clang/DEVIATIONS.md` prose they are
  both. **If you are reading an old handoff, this collision is why a bare `U11`
  is not self-describing** — which is the whole argument for slugs, met in the
  wild while retiring them.
- **`null-return-suppression` is deliberately both** a defect
  ([`null-return-suppression`](../../BACKLOG.md#null-return-suppression)) and
  the completion step that fixes it. That is the convention working — the step
  is named for the job, and the job is that defect — not a clash to resolve.
- **Anchors are GitHub-slugified heading text.** Every entry's heading is
  exactly its slug, so `#<slug>` always works. Do not add decoration to an
  entry heading; it would change the anchor and silently break every link.
- The link checker used here is four lines of Python (walk `]\(…\)`, resolve
  the path, slugify the target file's headings, compare) and is worth re-running
  after any step that edits a ledger.

## Forward notes for the NEXT step (written after reading its step file)

Three steps are unblocked and all three are desk work with no dependencies:
**upstream-reports**, **upstream-triage**, **decision-brief**. The plan says to
start with **decision-brief** if only one agent is available, because it blocks
the most.

**The map lives at `ops/SLUGS.md`** — repo root `ops/`, sibling of `PLAN.md`
and `BACKLOG.md`. From `ops/completion/steps/` that is `../../SLUGS.md`; from
`docs/` it is `../ops/SLUGS.md`.

**The exact slugs the three next steps name**, all of them live anchors now:

*decision-brief's five questions*

| Was | Now | Entry |
|---|---|---|
| `DEV-U15` | `prefix-arity-selection` | `ops/unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection` |
| `DEV-U06` | `over-oper-restrictions` | `…/DEVIATIONS.md#over-oper-restrictions` |
| `DEV-U23` | `postfix-operators` | `…/DEVIATIONS.md#postfix-operators` |
| `B23` | `dependent-template-operator-id` | `ops/BACKLOG.md#dependent-template-operator-id` |
| `DEV-U16` | `operand-sequencing` | `…/DEVIATIONS.md#operand-sequencing` (explicitly *not* decision-brief's — reconcile-declaring-using records it) |
| `U8` | `operator-mangling` | `docs/unicode-operators.md#operator-mangling` (mangling-abi's, not decision-brief's) |

U§13's fold-expression question has **no slug** — it is a design-doc section,
not a ledger entry, and it stays `U§13`.

*upstream-reports' three*

| Was | Now |
|---|---|
| `B25` | [`increment-decrement-mangling`](../../BACKLOG.md#increment-decrement-mangling) |
| `B38` | [`clangir-lvalue-crash`](../../BACKLOG.md#clangir-lvalue-crash) |
| `B26` | [`unqualified-id-union-read`](../../BACKLOG.md#unqualified-id-union-read) |

*upstream-triage's five*

| Was | Now |
|---|---|
| `B24` | [`inner-call-source-range`](../../BACKLOG.md#inner-call-source-range) |
| `B27` | [`cxxfilt-stdin-nonascii`](../../BACKLOG.md#cxxfilt-stdin-nonascii) |
| `B28` | [`auto-return-round-trip`](../../BACKLOG.md#auto-return-round-trip) |
| `B29` | [`pch-ast-print-order`](../../BACKLOG.md#pch-ast-print-order) |
| `B30` | [`operator-caret-range`](../../BACKLOG.md#operator-caret-range) |

**Specific things you will hit:**

- **`ops/backlog/steps/BL05-upstream-mangling.md` has been rewritten to use
  slugs** and upstream-reports says to execute it "exactly as written". It
  still is, semantically — only the identifiers moved. Its own closing note
  asks you to update three files afterwards; upstream-reports already corrects
  that note.
- **decision-brief's gate says to rewrite `ops/BACKLOG.md` §6** to point at
  `docs/open-decisions.md` instead of restating the questions. §6 is now a
  bullet list of links, so replacing it is a small edit — but keep it a list of
  *links*, not bare slugs, or you break the convention this step just
  established.
- **`docs/open-decisions.md` is a new file and will need slugs of its own**,
  one per question. Reuse the ledger slug where there is one — a page for
  `prefix-arity-selection` should be headed `prefix-arity-selection`, so the
  ledger entry and the brief share a name and the brief can be linked to by
  the same word. The two that have no ledger entry (U§13's folds, and whatever
  you call the "anywhere" re-triage) need new slugs named for the *question*.
  They do **not** go in `ops/SLUGS.md`: that file maps retired numbers, and a
  slug that never had a number needs no row.
- **When you close a row, mark it in place.** A defect's `Closed by` field and
  a deviation's `Status:` field are what the plan's docs-step gate reads. Name
  the section *and the paragraph*, per `ops/completion/handoffs/README.md`.
- **Do not restore a number anywhere.** If you need to refer to a completed
  track's step, `U09` and `BL05` and `S11` are still correct and still live —
  those were never retired.

## Open risks / TODOs

- **`docs/pattern-syntax-audit.py` is deliberately out of step** (see
  Deviations 2). It is `evidence-debt`'s to decide, since that step owns
  regenerating the character tables and the hash manifest
  ([`ucd-input-manifest`](../../BACKLOG.md#ucd-input-manifest)): if it
  regenerates the header anyway, renaming the two comments costs nothing extra;
  if it does not, leave them.
- **Nothing verifies links in CI.** The check here was ad hoc. A dead anchor is
  exactly the failure this convention exists to make visible, and right now it
  is visible only to whoever thinks to look. Worth ten lines in a Makefile
  target if anyone touches the repo's tooling.
- **The `Log.` field of every decision entry carries one line** — the rename,
  dated. That is the shape, not a placeholder: divergences append dated entries
  to the implicated question's Log rather than getting a file or a number of
  their own. `decision-brief`'s answers should land there as well as in
  `docs/open-decisions.md`.
- **Two step files under `ops/backlog/steps/` were rewritten but their plan was
  not.** `ops/backlog/PLAN.md` still uses numbers throughout; it is superseded
  and its `BL01`–`BL04` rows are a closed record, so that is correct. But
  `ops/completion/PLAN.md` tells agents to read its "Gate facts" section, which
  therefore still speaks in `B31`/`B33` terms. If that ever confuses someone,
  the fix is to move the gate facts into the completion plan, not to renumber
  the old one.
