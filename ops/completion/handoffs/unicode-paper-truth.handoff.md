# Handoff — unicode-paper-truth — three stale figures, two citations, and what a density pass actually costs

- **Status:** **DONE (gate passed).**
- **Branch / commit:** no branch — this repo only.
  `b26062a` (`docs:` — the paper) and the `ops:` commit carrying this file, the
  ticked box, the Status-log row, the Coverage note and one new backlog row.
  Measured against `unicode-operators-upstream` at `8c2a90f56b00`
  (`~/src/llvm/unicode-upstream`, build `~/src/llvm/build-unicode-upstream`),
  base commit **`d28193fa1ff6`**.
- **Date / agent:** 2026-09-08.

---

## What changed

`papers/unicode-mathematical-operators.md`, and nothing else outside this
repo's ops bookkeeping. `docs/unicode-operators.md` and
`docs/unicode-infix-operators.org` were **not** touched; both are implicated
and got a row instead (see *Deviations*).

**§Volume — every number re-derived, none copied from the step file.**

| | paper said | paper says |
|---|---|---|
| date of measurement | 2026-09-07 | 2026-09-08 |
| commits | Nineteen | **Twenty** |
| compiler proper | 86 files, +2033 / −18 | 86 files, **+2035** / −18 |
| tests | 34 files, +5416 | unchanged |
| total | 120 files, +7449 / −18 | 120 files, **+7451** / −18 |
| gate | 54,171 discovered / 48,295 passed | **54,242 / 48,324**, none failed |

*"Two thousand lines of compiler for the whole feature"* survives untouched, as
the step said it should.

**The ranking sentence was wrong in its second place, and is now three.** It
named the expression node (436 production lines / 31 files) and then the
`DeclarationName` kind (249 / 19) as *the next*. The actual second is
`[clang][Parse][Sema] Infix and prefix uses; candidate assembly with ADL` at
**276 / 4**. The step offered two ways out; I took the one it recommended and
named all three, because 276-across-4 against 249-across-19 is the contrast
that shows the shape:

> The largest single commit is the expression node, 436 production lines across
> 31 files. After it come the parse and candidate assembly, 276 lines across 4,
> and the `DeclarationName` kind, 249 across 19: nearly the same size as each
> other, and one of them touches five times as many files.

**§Relation to the backtick proposal — the forecast is now labelled as one.**
`201 of 204` / `169 of 171` → **`200 of 204` / `168 of 171`**, plus a sentence
that keeps the epistemics rather than quietly renumbering:

> The audit that preceded the replay predicted 201 and 169, so the executed
> number came in one hunk worse than the forecast and the conclusion did not
> move.

**Two citations.**

- §What this paper asks for: *"in a table whose own opening sentence is
  'Unlike Cfront…'"* → **"in a table §5.1.3 introduces by saying 'Unlike
  Cfront…'"**. The quotation is verbatim and stays; only the attribution
  moved, from the table to the section, because the table's own first line is
  `<operator-name> ::= nw`. Nothing else in that section was touched — the
  vendor sentence, `pp`/`mm`, `pp_`/`mm_`, `li <source-name>` and the four
  unary codes are as they were.
- §Deriving it: *"UAX #31 revision 43 added R3c"* → **"UAX #31 (revision 43)
  defines R3c"**. R3c is in revision 43 and revision 43 is current; the report
  does not say revision 43 *added* it, so the paper no longer does.

**Four stable references marked, at eight sites.** `[over.oper]` (×4),
`[over.match.call]`, `[over.match.oper]` (×2), `[expr.call]` (×2) now carry
`{.sref}`. Two of them carry a paragraph suffix and the suffix goes *after* the
attribute — `[over.oper]{.sref}p8`, `[over.match.oper]{.sref}p2` — which renders
correctly (see below).

**One density pass.** See *Discoveries* for what it cost and what it did not.

`ops/BACKLOG.md` gains [`hunk-count-provenance`](../../BACKLOG.md#hunk-count-provenance).
`ops/completion/PLAN.md` gains the ticked box, the Status-log row and a Coverage
paragraph saying that row has no step.

---

## Verification evidence

### The figures, re-derived, with the base commit spelled out

All run in `~/src/llvm/unicode-upstream`. **The base commit is written out in
every one of them**, for the reason the paper itself gives two sections later:
against a moving `upstream/main` the backtick grep stops being reproducible.

```
$ git rev-list --count d28193fa1ff6..unicode-operators-upstream
20

$ git diff --shortstat d28193fa1ff6..unicode-operators-upstream
 120 files changed, 7451 insertions(+), 18 deletions(-)

$ git diff --numstat d28193fa1ff6..unicode-operators-upstream \
    | grep -v $'\t'"clang/test/" | grep -v $'\t'"clang/unittests/" \
    | awk '{a+=$1;d+=$2;n++} END{print n" files, +"a" / -"d}'
86 files, +2035 / -18

$ git diff --numstat d28193fa1ff6..unicode-operators-upstream \
    | grep -E $'\t'"(clang/test/|clang/unittests/)" \
    | awk '{a+=$1;d+=$2;n++} END{print n" files, +"a" / -"d}'
34 files, +5416 / -0

$ git diff --numstat d28193fa1ff6..unicode-operators-upstream \
    | awk '{a+=$1;d+=$2;n++} END{print n" files, +"a" / -"d}'
120 files, +7451 / -18
```

Production is *not* `clang/test/` and *not* `clang/unittests/`, by path prefix,
which is how the existing figures were derived and is why the two splits sum to
the total exactly.

Per-commit production ranking, same split, sorted:

```
$ for c in $(git rev-list --reverse d28193fa1ff6..unicode-operators-upstream); do
    stat=$(git show --numstat --format= $c \
      | grep -v $'\t'"clang/test/" | grep -v $'\t'"clang/unittests/" \
      | awk '{a+=$1;n++} END{printf "%d %d", a+0, n+0}')
    echo "$stat $(git show -s --format=%s $c)"
  done | sort -rn | head -4
436 31 [clang][AST] UserOperatorExpr: operator syntax survives instantiation
276 4  [clang][Parse][Sema] Infix and prefix uses; candidate assembly with ADL
249 19 [clang][AST] DeclarationName kind for Unicode user-defined operators
201 5  [clang][Lex][Parse] Diagnose excluded code points with reasons
```

The backtick grep, pinned:

```
$ git log -p d28193fa1ff6..unicode-operators-upstream | grep -ci backtick
0
```

### The gate

```
$ ninja -C ~/src/llvm/build-unicode-upstream check-clang > gate.log 2>&1; echo "EXIT=$?"
EXIT=0

Testing Time: 303.98s
Total Discovered Tests: 54242
  Skipped          :     6 (0.01%)
  Unsupported      :  5885 (10.85%)
  Passed           : 48324 (89.09%)
  Expectedly Failed:    27 (0.05%)
```

**Zero failed** — the summary prints no `Failed` line at all when there are
none. Unfiltered, exit code read from the log rather than from a pipe. This is
**exactly** the Baselines row
[unicode-branch-maintenance](unicode-branch-maintenance.handoff.md) recorded
for this branch (54242 / 48324 / 0), independently reproduced, and it is what
the paper now prints.

### The paper builds

```
$ make -C papers unicode-mathematical-operators.html unicode-mathematical-operators.pdf \
    > paper.log 2>&1; echo "EXIT=$?"
EXIT=0
$ grep -ci "missing character\|warning\|error" paper.log
0
```

Both artifacts were **deleted first** and re-created, so `EXIT=0` is not a
no-op make. `monofont: "DejaVu Sans Mono"` is untouched in the front matter.

Glyphs in the PDF **text layer** (`pdftotext`, then grep):

```
⊞ 40   ⊗ 11   ⊖ 11   ⊠ 4   ∪ 2   ∩ 2   ⊕ 4   ⊘ 2
```

The named emoji are **absent as glyphs**, which is the point of naming them by
code point: `⌚ 0  ⌛ 0  ⏩ 0  ⏰ 0  ⬛ 0  ⭐ 0  ⭕ 0`.

The four new srefs expand in both outputs. From the PDF text layer:

```
12.4 Overloaded operators [over.oper] imposes five restrictions …
Reinstating 12.4 Overloaded operators [over.oper]p8 for user operators …
the ordinary call path: 12.2.2.2 Function call syntax [over.match.call], not
  12.2.2.3 Operators in expressions [over.match.oper].
of the postfix-expression, and 7.6.1.3 Function call [expr.call] sequences it …
12.2.2.3 Operators in expressions [over.match.oper]p2 gives an overloaded …
```

and the HTML carries `title="12.4 Overloaded operators"` on the anchor. The
`p8` / `p2` suffixes read correctly after the expansion.

### The corrected figures reach the PDF

```
$ grep -n "54,242\|48,324\|2035\|7451\|Twenty commits\|200 of 204\|168 of 171\|revision 43\|5.1.3 introduces" paper.txt
182: UAX #31 (revision 43) defines R3c, "User-Defined Operators": …
550: +2035 / −18
552: +7451 / −18
554: Twenty commits, in groups that can be reviewed independently: …
564: The regression gate is the full check-clang suite: 54,242 tests discovered, 48,324 run and passed, none failed.
768: table §5.1.3 introduces by saying "Unlike Cfront, …
868: … 200 of 204 hunks survived unchanged,
869: and 168 of 171 production hunks. The audit that preceded the replay predicted 201 and 169, so the …
```

### Voice metrics, before and after

Prose only: front matter, fenced code, block quotes, tables, headings and
inline code stripped. 7,555 words after (7,548 before — the pass is net
neutral, which matters, because every one of these is a *rate*).

| marker | before | after | target | his papers |
|---|--:|--:|--:|--:|
| em-dashes | 35 = 46.4/10k | **12 = 15.9/10k** | ≤ 20/10k | 20.1/10k |
| "However" | 5 = 6.6/10k | **9 = 11.9/10k** | ≥ 10/10k | 17.6/10k formal |
| "of course" | 0 | **2 = 2.6/10k** | non-zero | 3.0/10k formal |
| appositive `, not Y` tail | 5 | **1** | ≤ 1 | 0.4/10k |
| That/It/This-is openers | 6.1/100s | **5.4/100s** | — | 3.3/100s |
| And/But/So openers | 2.9/100s | 2.8/100s | — | 0.4/100s |
| "worth X-ing" as a move | 9 | **2** | ~1 | — |

```
$ python3 ~/.claude/skills/voice/scripts/lexcheck.py --register formal \
    papers/unicode-mathematical-operators.md
clean (7962 prose tokens)
```

Before the pass it printed
`WARN appositive ', not Y' tail x5`. No new warning class appeared.

### Public text stands alone

```
$ grep -n "ops/\|DEVIATIONS\|PLAN\.md\|BACKLOG\|handoff\|\bU[0-9][0-9]\b\|\bS[0-9][0-9]\b\|\bG[0-9][0-9]\b\|BL0\|slug" \
    papers/unicode-mathematical-operators.md
(no output)
```

### Scope

```
$ git diff --name-only        # before commit
ops/completion/PLAN.md
papers/unicode-mathematical-operators.md
```

---

## Deviations from the plan / design

**One, and it is a row rather than an edit.** The step file scopes
`docs/unicode-operators.md` and `docs/unicode-infix-operators.org` out and says
to open a row if either is implicated. Both are: each prints the audit's
forecast as the replay's result, in the same words the paper did.

- `docs/unicode-operators.md`: *"201 of 204 hunks survive onto clean trunk, and
  169 of 171 production hunks"*
- `docs/unicode-infix-operators.org`: *"201 of 204 hunks came across unchanged
  (169 of 171 in the compiler proper)"*

Opened as [`hunk-count-provenance`](../../BACKLOG.md#hunk-count-provenance),
with the corrected numbers, the reason for the difference (hunks separated on
the branch by a backtick line coalesce on clean trunk — content, not coverage)
and where both are recorded. `ops/completion/PLAN.md`'s Coverage section says
in as many words that this row has no step and does not want one: no
measurement is owed, so it is two paragraphs in whatever pass next touches
either file.

Nothing contradicted the design, so no `DEVIATIONS.md` entry.

---

## Discoveries affecting later steps

**The voice pass is where the time went, and it splits cleanly in two.**

1. **Punctuation-only substitutions — cheap, mechanical, ~18 of 23 dash cuts.**
   A *single* dash acting as a pivot (`X — so Y`, `X — a gloss of X`) takes a
   colon, a semicolon, a comma or parentheses with no other change. A *paired*
   dash carrying an interruption (`Every shape — a, b, c — emits…`) becomes
   parentheses as one unit, or should be kept. These never needed a rewrite and
   never touched a claim.
2. **Sentences where a dash and a separate tell sat together — expensive, ~5.**
   *"the flag is inert — not merely harmless, but byte-identical…"* is a dash, a
   `not X, but Y` antithesis and a "worth writing" in one clause. Those had to
   be rewritten as sentences, and each took a couple of minutes of getting the
   meaning back intact. Budget for these separately; they are the only ones with
   any risk of changing what the paper says.

**Which edits were worth making, and which were not.**

- **Worth it:** the dash cuts, all of them. The paper reads faster and nothing
  was lost, because in every case the punctuation was carrying the pause and the
  words were doing the work.
- **Worth it:** the predicate-nominal merges. *"The fourth is the one that reads
  best, because the answer is not a sibling at all"* → *"The fourth produced no
  sibling at all."* The nominal was a wind-up for a sentence that was already
  there. Same for *"The asymmetry is the finding."*, which was deleted outright:
  the bolded sentence after it **is** the finding, and saying so first was pure
  restatement.
- **Marginal:** the `And/But/So` opener rate (2.8/100s against his 0.4). The
  step set no target for it, `voice-profile.md` §6 explicitly licenses the habit
  as a signature, and cutting it would have been fixing a metric rather than the
  prose. Left alone deliberately. **Do the same on the backtick paper** — its
  rate is 3.0 and the same reasoning applies.
- **Not worth it, and actively bad:** adding "However" anywhere the argument
  does not already concede. Each of the four I added lands on a concession that
  was already in the sentence and was being carried by a dash or a bare "and".
  A "However" bolted onto a non-concession reads worse than the dash it
  replaced. If the count runs short, the fix is to find more real concessions,
  not to sprinkle.

**Traps, in the order they will bite the next agent.**

- **`lexcheck` cannot see a tail that wraps across a line.** Its `TAIL_NOT`
  regex is `,\s*not\s+[a-z][^,.;:!?\n]{0,40}[.;]` — the middle class excludes
  `\n`, so *", not\na preference."* is invisible to it while being exactly the
  tell. It happens to catch *",\nnot a preference."* because `\s*` follows the
  comma. **Count them yourself with whitespace flattened** before trusting a
  clean run. The backtick paper has fourteen and is hard-wrapped at ~78
  columns, so several are certainly split.
- **Same trap in your own measurement script.** My first counter reported
  "of course" as 1 when the file had 2, because one of them straddled a line
  break. Flatten whitespace before matching any multi-word phrase. Single-token
  counts (em-dash, "However") are safe either way.
- **Fixing a "worth X" can trip a different rule.** I replaced *"the next is…"*
  with *"the two commits worth naming are…"* and `lexcheck` immediately
  reported `ERROR impostor phrase 'worth naming'`. Re-run `lexcheck` after
  every batch, not once at the end.
- **The paper build log is silent when it succeeds.** No "Missing character"
  line, no warning, nothing but the two `pandoc` invocations. A zero grep count
  is therefore not evidence the run happened — **delete the artifacts first**
  and check they came back.
- **Hard-wrapped source.** Both papers are wrapped at ~78 columns. String
  substitution leaves ragged lines and an unreadable diff, so reflow every
  paragraph you touch. A `textwrap.wrap` over blank-line-delimited paragraphs
  works, but it **must skip** list items, block quotes, tables, pandoc divs and
  fenced code — `textwrap` will happily merge a `- ` bullet into the paragraph
  above it. On the backtick paper it must also skip the entire Wording section:
  `{.pnum}`, `[text]{.add}` and the block quotes are a protected region and
  reflowing them would be a normative change.

**Mechanics that will transfer.**

- The measurement script and the reflow script are throwaway and live in the
  scratchpad; they are ten lines each and are faster to rewrite than to find.
  What matters is the *strip list*: front matter, fenced code, block quotes,
  table rows, pandoc divs, HTML comments, headings, then inline `` `code` ``.
  That is the list that reproduces the step file's own baseline numbers to
  within a word or two.
- Sref suffixes: `[over.oper]{.sref}p8` is correct and renders as
  `12.4 Overloaded operators [over.oper]p8`. `wg21/MANUAL.md` writes paragraph
  refs as `{.sref}/2`; both work, and I kept the paper's existing `p8` spelling
  rather than renumbering its prose.
- `check-clang` on `build-unicode-upstream` is ~5 minutes wall from an
  up-to-date build (304 s of test time). **Start it in the background before
  reading anything** — it is the only slow thing in a step like this, and it is
  independent of every edit.

---

## Forward notes for the NEXT step
### ([backtick-paper-truth](../steps/backtick-paper-truth.md), written after reading its file)

Its item 9 is the same job as my item 6 **in a much worse form**, and the two
gates differ in a way that matters.

- **119 em-dashes at 125.9/10k, against my 35 at 46.4.** Mine came down to 12
  with 23 substitutions, of which 18 were one-token punctuation swaps. Yours is
  roughly a hundred cuts to reach 20/10k on 9,453 words (**≈19 dashes may
  survive**). Do it as one enumeration pass, not opportunistically: list every
  prose-region dash with its line and its full sentence, classify each as
  *paired-interruption* (keep, or parenthesise as a unit) or *single-pivot*
  (colon / semicolon / comma), and only then start editing. The classification
  is where the judgement is; the edit is not.
- **"However" ≥ 12/10k on 9,453 words is ≥ 12 occurrences, from 2.** That is ten
  new ones, and it is a harder problem than my four. **Look for the double
  duty**: a dash that is standing in for a concession converts to "However" and
  reduces both counts at once. I got exactly one of those (*"…gives a
  character-identical diagnostic — but that rejection is correct"* → *"…
  diagnostic. However, that rejection is correct"*), and that shape — a dash
  followed by `but` — is the cleanest conversion there is. Grep for `— but`,
  `— though`, `— and yet` first; each is a free one. If ten real concessions do
  not exist in the file, say so in the handoff rather than manufacturing them.
- **Fourteen appositive tails to one.** Mine went five to one and the trick that
  did most of the work was replacing the comma with `and`: *"derivation inputs,
  not ongoing dependencies"* → *"derivation inputs and not ongoing
  dependencies"*. That is a real prose change (it drops the antithetical beat),
  not a way around the checker, and it is right where the negated half carries
  content. Where the negated half is a bare foil, cut it entirely. **Pick which
  one you keep first** — I kept the stated principle the whole section builds
  to, and edited the other four around it.
- **Its item 3 corrects a count I can corroborate.** `gcc-resync`'s handoff and
  its Status-log row both say **177 commits touching `gcc/cp`, `gcc/c-family`
  or `libcpp`** — three directories, and the paper names two. The row is quoted
  verbatim in `ops/completion/PLAN.md`'s Status log if the handoff is
  inconvenient to open.
- **Its item 1 depends on [slot-callable-printing](../steps/slot-callable-printing.md),
  which is step 21 and was running in parallel with me in this same worktree.**
  Check its box and its handoff before you write the round-trip paragraph; if it
  ended `BLOCKED`, the paragraph you write is a different one. I touched none of
  its files and it touched none of mine.
- **Do not assume its baseline numbers are still current.** Mine reproduced to
  within a word (7,548 measured against 7,906 quoted — a stripping difference,
  not drift) and every count matched exactly. Re-derive anyway; the step file
  says so and it is two commands.
- **`papers/backtick-infix-and-keyword-escape.md` is untouched by this step.**
  `git log -1 --stat` on `b26062a` shows one file.

---

## Open risks / TODOs

- [`hunk-count-provenance`](../../BACKLOG.md#hunk-count-provenance) is **open
  and unowned**. It is two paragraphs in two files, both outside this step's
  scope, with no measurement owed. It does not block anything and it does not
  want a step; it wants to ride along with the next edit to either file.
- The paper's em-dash rate landed at 15.9/10k against his published 20.1. That
  is *under* his rate rather than at it, which is the opposite failure mode from
  the one the gate guards against. Two or three of the twenty-three cuts could
  have been left as dashes with no harm. If a later pass wants to loosen it, the
  paired-interruption ones are the ones to restore, and the file is not short of
  candidates.
- `CLAUDE.md`'s summary still says `ops/completion/PLAN.md` has "exactly one"
  unchecked step and that an arriving agent should not look for work in `ops/`.
  Four steps (21–24) are unchecked and 22 is now three of them away from the
  end. Not this step's to fix, and noted because the next agent will read that
  paragraph first and be misled by it.
