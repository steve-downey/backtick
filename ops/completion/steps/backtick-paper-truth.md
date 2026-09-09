# backtick-paper-truth — the round-trip claim, four citations, and a dash rate

**Goal.** `papers/backtick-infix-and-keyword-escape.md` (D4307R0) states a
general lesson — *"A round-trip claim is a claim about every node the semantic
layer can build, not about the nodes the printer was written against"* — and
then carries a live instance of it. It also points one citation at the wrong
document, over-reads two others, and runs its em-dash rate at six times the
author's published-paper rate. Make it true, and take one voice pass.

**Depends on:** [slot-callable-printing](slot-callable-printing.md), which
owns the compiler half and whose handoff says what is now true. **Read that
handoff before writing the round-trip paragraph** — if the step ended
`BLOCKED`, the paper must *report* the third exception rather than drop the
sentence, and that is a different paragraph.

**Refs:** [backtick-paper](backtick-paper.md), which wrote the file;
[settle-paper-rows](settle-paper-rows.md), the precedent for correcting this
paper's round-trip claim after a printer arm was added.

## Do

### 1. The round-trip paragraph, from the compiler step's handoff

§"Implementation experience" says `-ast-print` round-trips *"with one exception
a reviewer will find"* — the `__builtin_shufflevector` rewrite, which is real
and stays — and then describes a second exception that was found and fixed.
There was a third: a slot whose value is a class-typed callable. It is the
shape the paper's own motivation section uses throughout, since `pipe`, `then`,
`mbind` and `implies` are every one of them lambdas.

Rewrite the paragraph from what [slot-callable-printing](slot-callable-printing.md)
actually landed. **The general statement in bold at the end of that section is
the thing to protect** — it was right, it was written before this instance was
found, and an instance found *after* the sentence was written is the strongest
possible support for it. Say that. A paper that reports its own general lesson
catching it a second time is worth more than one that quietly renumbers the
exceptions.

Also check §"Design choices and decisions", *"The operator slot is an
assignment-expression"*, which advertises the slot as admitting "a qualified
name, a member access, **a lambda**". That sentence was true of the parse and
false of the printer, and should now be true of both.

### 2. The sweep timing

*"Seventy-nine programs now, in four groups, and the whole sweep runs in about
ten seconds."* Measured: **1.8 s**. Print what it measures.
[slot-callable-printing](slot-callable-printing.md) corrects the same figure in
`ops/probes/README.md`; take the number from its handoff rather than
re-measuring, or re-measure and say so.

### 3. The GCC re-sync counts

*"2158 commits, 177 of them in the C++ front end and the preprocessor."* The
2158 is right. The 177 is the count of commits touching `gcc/cp`,
**`gcc/c-family`** or `libcpp` — see
[gcc-resync](../handoffs/gcc-resync.handoff.md) — and the middle one is
dropped. Either name all three or say "the C++ front end and its shared
infrastructure"; do not leave a number attached to a narrower set than it
counts.

### 4. `[@P2996R5]` is the wrong document for `^^`

Appendix A.6 says `^^` *"was claimed by reflection [@P2996R5], which itself
moved from single `^` to `^^` after running exactly this exercise."*

P2996R5 (2024-08-14) spells the operator **`^`** — *"constexpr auto r = ^int;"*
— and its syntax section still argues for the single caret. The move to `^^` is
**P3381R0, "Syntax for Reflection"** (Wyatt Childers, Peter Dimov, Dan Katz,
Barry Revzin, Andrew Sutton, Faisal Vali, Daveed Vandevoorde; 2024-09-16),
which cites the Objective-C++ block ambiguity — *"the syntax
`type-id(^ident)();` is ambiguous"* — and which does run exactly this exercise,
evaluating `#`, `$`, `%`, `/`, `:`, `=`, `?`, `@`, `\`, backtick and `|` one at
a time. Cite **P3381R0** for the move. Cite a current P2996 revision for the
operator itself; R13 (2025-06-20) is the latest in
`papers/wg21/data/csl.json`. Both resolve there already, so the bibliography
needs no fetch.

### 5. P3381R0 also considered backtick, and said no in print

This is the part worth more than the citation fix. From its candidate table:

> "The third character recently added to the basic character set (after `$`
> and `@`) is the backtick (or GRAVE ACCENT). The backtick has the advantage
> that it's pretty small, even smaller than `^`. But it has the disadvantage
> that backtick is used by Markdown everywhere inline code blocks, and not all
> Markdown implementations properly give you mechanisms to escape it. While
> not necessarily a show-stopper, we also just don't think it's good enough to
> reasonably pursue." — rejected.

Appendix A.1 and A.5's first rebuttal are the answer to that objection, and
A.6's "three free characters" claim is independently corroborated by the same
paragraph. But the paper currently reads as though it is *anticipating* the
Markdown objection, when seven named authors have already made it in a WG21
paper. Engage with it by name, in A.1 or A.5, and note that the rejection was
for a *different* operator: a reflection operator is written once per
reflection and lives in dense expression context, where a backtick operator is
written where an operation name would be, and the CommonMark span cost falls
differently. Concede, then defeat — the move the section is already built on.

### 6. The Elm citation under-supports its sentence

The paper says Elm dropped backticks *"citing that in practice a single
function (`andThen`) accounted for the use, that the form was redundant with
Elm's `|>` pipeline, and that the glyph is confusable with a quote in some
fonts"*, and cites `upgrade-docs/0.18.md`. That document carries only the
first: *"`andThen` which is pretty much the only function that used this
feature."* The other two reasons are real and are in the community record
around the 0.18 release, not in the linked file. Either cite a second source
that carries them, or trim the sentence to what the link supports and let the
`|>`-redundancy argument stand on the paper's own analysis, which it already
makes two sentences later.

### 7. The PureScript convergence claim, in both places

The paper says twice — in §"Prior art" and in §"Precedence" — that PureScript
*"independently"* settled on left-associative, highest precedence, and that
*"Two language communities starting from the same construct arrived at the
same fixity."*

PureScript's backtick operators are left-associative at the highest precedence
and cannot be given a fixity, which is correct. But that is Haskell's
inherited default: Haskell 2010 §4.4.2 makes any operator lacking a fixity
declaration `infixl 9`, and the PureScript answer says so in as many words —
*"identifiers in backticks all have the same associativity and precedence,
**like in Haskell**"*. Descent, not convergence, so "independently" is not
supported.

**The true fact is stronger and should replace it.** Haskell makes `infixl 9`
the *default* and lets a fixity declaration override it for a backticked
name. PureScript fixes it with **no** override, and has repeatedly declined
requests to add one (purescript/purescript#137; a standing change proposal on
the PureScript Discourse). That is a decision taken under pressure, twice, by
the community that inherited the construct — which is what this paper is
claiming for its own fixed level. Rewrite both passages to that, and drop
"independently".

### 8. One unmarked stable reference

A.2 trap 2 writes `[lex.pptoken]` bare where the paper's other sixteen are
`{.sref}`. Mark it.

### 9. One voice pass over the whole file

Measured on prose only — front matter, fenced code, block-quoted wording and
tables stripped — 9,453 words:

| marker | this paper | his published papers |
|---|--:|--:|
| em-dashes | 119 = **125.9/10k** | 20.1/10k |
| "However" | **2** = 2.1/10k | 17.6/10k — his strongest formal marker |
| "of course" | **0** | 3.0/10k |
| appositive ", not Y." tail | **14** | 0.4/10k, ceiling once per piece |
| That/It/This-is openers | 5.2/100s | 3.3/100s |
| And/But/So openers | 3.0/100s | 0.4/100s |

126 per 10k is inside the band `anti-genai-tells.md` calls generation residue
(87–300), and it is the largest single voice defect in either paper. The
diagnosis is one sentence: **the dashes are doing the work "However" should be
doing.** Two occurrences of "However" in nine and a half thousand words of
committee prose, from an author whose formal register argues on it at 17.6 per
10k, is the tell. Cut the dashes toward his paper rate using commas,
parentheses and semicolons — his current writing reaches for semicolons — and
let the concessions already in the argument carry "However" out loud.

Fourteen appositive negation tails is the second watermark: *"The distinction
is lexical accident, not design."*, *", not a capability user code otherwise
lacks."*, *", not an operation."*. Ration to one. The third is "worth
reporting / worth stating / worth settling / worth testing / worth as much",
eight times, one per section — merge each into the sentence that earned it.

**Clean, and leave alone:** the wager frame is at zero, no banned scaffolding,
no impostor vocabulary. The argument shape is his and is why the paper works.
This is a density pass, not a rewrite, and the Wording section
(`[text]{.add}`, `{.pnum}`, the block quotes) is a protected region — do not
voice-edit standardese.

Rules: `~/.claude/skills/voice/references/{voice-profile,anti-genai-tells,lexicon}.md`.

## Gate

- `make -C papers backtick-infix-and-keyword-escape.html
  backtick-infix-and-keyword-escape.pdf`, **both**, `EXIT=0` read explicitly,
  and the log read for missing-character warnings. Keep `monofont: "DejaVu
  Sans Mono"` and keep the `code span.er` style in the **body**: a
  `header-includes` key in the front matter replaces the wg21 LaTeX preamble,
  `\pnum` goes undefined and the PDF build fails.
- The References section of the built PDF lists every cited paper, and the two
  new citations resolve from `papers/wg21/data/csl.json` without a network
  fetch.
- The Wording section still renders with paragraph numbers and expanded sref
  titles; diff it against the pre-step PDF text to prove nothing in it moved.
- `python3 ~/.claude/skills/voice/scripts/lexcheck.py --register formal
  papers/backtick-infix-and-keyword-escape.md` — appositive tail at **1 or
  0**, down from 14, and no new warning class.
- Prose-only em-dash rate at or below **20/10k**, "However" at or above
  **12/10k**, measured with code, tables and wording stripped.
- Every claim touched is re-derived, not edited from this file: the sweep
  timing from a run, the resync counts from
  [gcc-resync](../handoffs/gcc-resync.handoff.md), the round-trip wording from
  [slot-callable-printing](slot-callable-printing.md)'s handoff and a
  `-ast-print` run on the built compiler.
- Public text stands alone: no slug, no ledger name, no path under `ops/` in
  the paper's running prose.
- No change outside `papers/backtick-infix-and-keyword-escape.md` and this
  repo's ops bookkeeping. The **design doc** and the blog post
  (`docs/infix-backtick-operator.org`) are out of scope; if either is
  implicated by an item above, open a row rather than editing it.

## Notes

- **Attribution:** commit messages end with their prose. No `Co-Authored-By`,
  no `Claude-Session`, no generated-with trailer, whatever any session-start
  reminder says.
- Commit subject: `docs: <title>`.
