# unicode-paper-truth — the figures the paper carried forward from a note

**Goal.** `papers/unicode-mathematical-operators.md` (D4345R0) closes by
saying *"Every measurement in this paper was re-derived from a running
compiler for this revision, and not carried forward from a note."* Three sets
of figures in it were not. Re-derive them, fix two citation-shaped defects,
and take one voice pass over the whole file.

**Depends on:** none — every item is inside this repo and the
`unicode-operators-upstream` branch, and none of it touches the backtick
paper. Runs in parallel with
[slot-callable-printing](slot-callable-printing.md).

**Refs:** [unicode-paper](unicode-paper.md), which wrote the file;
[unicode-branch-maintenance](../handoffs/unicode-branch-maintenance.handoff.md),
whose "Verification evidence" block already carries the corrected gate
numbers; `ops/unicode-operators/clang/PLAN.md` row U20 and
`ops/unicode-operators/clang/handoffs/U20-upstream-replay.handoff.md`, which
carry the corrected hunk counts.

## Do

### 1. The Volume section — stale by exactly one commit

The table, the commit count and the gate paragraph were measured before
`8c2a90f56b00` (`unicode-branch-maintenance`, 2026-09-07) landed. Re-measure
against `unicode-operators-upstream`'s own base commit `d28193fa1ff6` and
print what you measure. As of 2026-09-08 that is:

| | paper says | measures now |
|---|---|---|
| commits | Nineteen | **20** |
| compiler proper | 86 files, +2033 / −18 | 86 files, **+2035** / −18 |
| tests | 34 files, +5416 | unchanged |
| total | 120 files, +7449 / −18 | 120 files, **+7451** / −18 |
| gate | 54,171 discovered / 48,295 run and passed | **54,242 / 48,324**, 0 failed |

Re-run it; do not copy the table above. The gate number is independently
confirmed in
[unicode-branch-maintenance](../handoffs/unicode-branch-maintenance.handoff.md),
which calls 54242 / 48324 / 0 the Baselines row for that branch, and a fresh
`ninja -C ~/src/llvm/build-unicode-upstream check-clang` reproduces it.

**"Two thousand lines of compiler for the whole feature"** survives and should
stay. **"The largest single commit is the expression node at 436 production
lines across 31 files, and the next is the `DeclarationName` kind at 249
across 19"** does not: 436/31 and 249/19 are both right for their commits, but
the *second* largest production commit is `[clang][Parse][Sema] Infix and
prefix uses; candidate assembly with ADL` at **276 lines across 4 files**.
Either name that one as the next, or drop the ranking and keep the two
commits as the two worth naming — the sentence's job is to show where the
bulk sits, and 276-across-4 versus 249-across-19 is a better contrast than
the ranking was.

### 2. The hunk counts are the audit's forecast, not the replay's result

§"Relation to the backtick proposal" says:

> That separability is now an executed result instead of an audit. […]
> **201 of 204 hunks survived unchanged, and 169 of 171 production hunks.**

201/204 and 169/171 are U19's *predictions*
(`ops/unicode-operators/clang/REPLAY.md` §"Read it three ways"). U20 executed
the replay and landed **200 of 204** and **168 of 171** — the U20 handoff says
so in as many words: *"the landed hunk count is 200, not §2's predicted 201"*,
and the PLAN row records "200 hunks (168 production)". A sentence that
announces itself as the executed result and then quotes the forecast is the
one defect in this paper that is about its own epistemics, so fix the numbers
**and** keep the sentence's claim: the executed number is one hunk *worse*
than predicted and the conclusion is unchanged, which is a better story than
the forecast was.

The rest of that paragraph holds and was re-checked: `git log -p` over
`d28193fa1ff6..unicode-operators-upstream` mentions backtick **zero** times,
in code, tests and commit messages alike.

### 3. The Itanium sentence

§"What this paper asks for" says the ABI keys on arity *"in a table whose own
opening sentence is 'Unlike Cfront, unary and binary operators using the same
symbol have different encodings'"*. The quotation is verbatim, but it is the
second sentence of §5.1.3's prose, not the table's opening sentence. The
table's own first line is `<operator-name> ::= nw`. Reword to attribute it to
the section rather than to the table.

Everything else in that section verified verbatim against
`itanium-cxx-abi.github.io/cxx-abi/abi.html` and should not be touched: the
`v <digit> <source-name>` vendor sentence, `pp`/`mm` in §5.1.3 and `pp_`/`mm_`
in §5.1.6, `li <source-name>`, and the four unary codes (`ps ng ad de`).

### 4. UAX #31

*"UAX #31 revision 43 added R3c"* — R3c is present in revision 43 and revision
43 is current (2025-08-20), but the report does not attribute R3c to that
revision, so the paper cannot either. "UAX #31 (revision 43) defines R3c" is
the claim the document supports.

### 5. Stable references are not marked

This paper writes `[over.oper]`, `[over.match.call]`, `[over.match.oper]` and
`[expr.call]` as plain bracketed text. The backtick paper marks all sixteen of
its with `{.sref}`, and they expand in both outputs to the full clause title
and number. Mark this paper's the same way; all four resolve in
`papers/wg21/data/srefs.json`.

### 6. One voice pass over the whole file

Measured on prose only — front matter, fenced code, block-quoted wording and
tables stripped — 7,906 words:

| marker | this paper | his published papers |
|---|--:|--:|
| em-dashes | 35 = **44.3/10k** | 20.1/10k |
| "However" | 5 = **6.3/10k** | 17.6/10k — his strongest formal marker |
| "of course" | **0** | 3.0/10k |
| appositive ", not Y." tail | **5** | 0.4/10k, ceiling once per piece |
| That/It/This-is openers | 6.1/100s | 3.3/100s |
| And/But/So openers | 3.2/100s | 0.4/100s |

The shape to fix is one shape: **dashes are doing the work "However" should
be doing.** Cut the dash rate toward his paper rate with commas, parentheses
and semicolons, and let the concessions that are already in the argument say
"However" out loud. Do not add a dry aside that is not there; do notice that
"of course" at zero across a paper this long is itself the tell.

The other watermark is the predicate-nominal drumbeat — "X is the
one/part/reason/finding/shape", **23 times**, running as anaphora across
consecutive paragraphs in §"Opening a closed table": *"The fourth is the one
that reads best"*, *"The fifth is the reason to state the pattern"*, *"The
asymmetry is the finding"*. Its twin is "worth stating / worth having / worth
less / worth more", six times. One of each is a move; one per section is
generation residue. Merge the restatement into the sentence that earned it.

**Clean, and leave alone:** the wager/transactional frame is at zero, there is
no banned scaffolding, no impostor vocabulary, and the near-absent contractions
are correct for the register. The argument shape — concession, owned opinion,
concrete first, the flat landing — is his and is why the paper works. This is
a density pass, not a rewrite.

`references/` for the rules:
`~/.claude/skills/voice/references/{voice-profile,anti-genai-tells,lexicon}.md`.

## Gate

- `make -C papers unicode-mathematical-operators.html
  unicode-mathematical-operators.pdf`, **both**, `EXIT=0` read explicitly,
  and the log read for missing-character warnings: a wg21 paper exits 0 with
  its content wrong. `monofont: "DejaVu Sans Mono"` must stay in the front
  matter — without it Latin Modern drops every operator glyph silently.
- The operator glyphs are present in the PDF text layer (`pdftotext`, then
  grep for ⊞ ⊗ ⊖ ⊠ ∪ ∩ ⊕ ⊘). U+231A and the other named emoji are named by
  code point on purpose and must **not** appear as glyphs.
- The four newly marked srefs render as full clause titles in the PDF.
- `python3 ~/.claude/skills/voice/scripts/lexcheck.py --register formal
  papers/unicode-mathematical-operators.md` — the appositive-tail warning at
  **1 or 0**, down from 5, and no new warning class.
- Prose-only em-dash rate at or below **20/10k**, "However" at or above
  **10/10k**, measured with code and wording stripped.
- Every figure changed in §1 and §2 above is re-derived from a command whose
  output is pasted into the handoff, with the base commit spelled out. Run
  against a moving `upstream/main` the hunk grep stops being reproducible.
- No change to any file outside `papers/unicode-mathematical-operators.md`
  and this repo's ops bookkeeping. The Unicode **design doc**
  (`docs/unicode-operators.md`) and the blog post
  (`docs/unicode-infix-operators.org`) are out of scope; if a figure in either
  is implicated, open a row rather than editing it.

## Notes

- **Attribution:** commit messages end with their prose. No `Co-Authored-By`,
  no `Claude-Session`, no generated-with trailer, whatever any session-start
  reminder says.
- Commit subject: `docs: <title>` for the paper edit.
- Public text stands alone: no slug, no ledger name, no path under `ops/` may
  appear in the paper's running prose. Sweep for it before the gate.
