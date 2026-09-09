# Handoff — backtick-paper-truth — one exception, a rejection in print, and a hundred dashes

- **Status:** **DONE (gate passed).**
- **Branch / commit:** no branch — this repo only. `8f9f9f2` (`docs:` — the
  paper) and the `ops:` commit carrying this file, the ticked box, the
  Status-log row, one new backlog row and `CLAUDE.md`'s Phase J paragraph.
  Facts re-derived against `backtick-trunk`'s built clang
  (`~/src/llvm/build-backtick-trunk`, read-only) and against
  [slot-callable-printing](slot-callable-printing.handoff.md).
- **Date / agent:** 2026-09-09 (the step ran across midnight; the sibling and
  dependency steps it cites are 2026-09-08).
- **This closes Phase J, and with it every box in every plan in this repo.**

---

## What changed

`papers/backtick-infix-and-keyword-escape.md`, and nothing else outside this
repo's ops bookkeeping. `docs/backtick-operator-design.md` and
`docs/infix-backtick-operator.org` were **not** touched; the second is
implicated and got a row instead (see *Deviations*).

### The round-trip claim (§Implementation experience)

Rewritten from what [slot-callable-printing](slot-callable-printing.handoff.md)
landed, and re-derived on the built compiler rather than read off its handoff.
The paper now says:

> `-ast-print` round-trips **every shape the operator can take**, with one
> exception a reviewer will find: a slot naming a builtin whose call the
> semantic layer rewrites into a node that is no longer a call
> (`` a `__builtin_shufflevector` b ``) prints as the rewrite, because the
> rewrite is not expressible in the syntax at all.

**The review's *"a different, well-formed program"* is corrected, and the
correction is the interesting half.** The paragraph now says the two fixed
exceptions failed in *opposite* ways:

| arm | how it failed |
|---|---|
| type slot naming an aggregate | **silently** — printed the desugaring, which was well-formed and plausible and not what was written; in the deduced case, a cast applied to a comma expression |
| slot whose *value* is a class-typed callable | **loudly** — printed text naming `operator()` as a free function, which does not compile, dropped an operand, and reported a source range whose end preceded its beginning |

and closes on *"a claim tested only where the printer already works is
untested whichever way it fails."*

**The bold general statement is kept exactly as it stood** — *"A round-trip
claim is a claim about every node the semantic layer can build, not about the
nodes the printer was written against"* — and the paper now says when it was
written and that the second instance was found **afterwards**, by asking the
question the sentence asks. That is item 1's whole point and it is the last
paragraph of the section.

The mechanism sentence is written to the boundary
[slot-callable-printing](slot-callable-printing.handoff.md) measured, not to
the loose one: *a slot whose **value** is a class-typed callable … is called
through the object's own `operator()`, which the semantic layer keys as an
operator call: the slot lands at argument zero and the operands shift one
place along*. It does **not** say "a lambda in the slot", because a callable
reached through a conversion to a function pointer printed correctly all
along.

§"The operator slot is an assignment-expression" — *"a qualified name, a
member access, **a lambda**"* — **needed no edit**: it was true of the parse
and is now true of the printer as well, which is what step 21 landed.

### Figures, all re-derived

| | paper said | paper says | source |
|---|---|---|---|
| escape sweep runtime | "about ten seconds" | **"under two seconds"** | own run, 1.61 / 1.63 / 1.61 s, 79/79 both compilers |
| GCC resync | "2158 commits, 177 of them in the C++ front end and the preprocessor" | 2158 unchanged; **177 "touching the C++ front end, the front-end infrastructure it shares with C, or the preprocessor"** | [gcc-resync](gcc-resync.handoff.md), which counted `gcc/cp`, `gcc/c-family`, `libcpp` |

### Citations

- **A.6, `^^`.** *"claimed by reflection [@P2996R5], which itself moved from
  single `^` to `^^`"* → claimed by reflection **[@P2996R13]**, and the move
  attributed to **[@P3381R0]**. P2996R5 (2024-08-14) spells the operator `^`;
  R13 (2025-06-20) is the current revision in `csl.json`. The sentence also
  now records that P3381R0's candidate table reaches this section's
  free-character count independently, calling the backtick *the third
  character recently added to the basic character set, after `$` and `@`*.
- **A.1 gains the rejection, quoted.** P3381R0 evaluated eleven candidate
  spellings and rejected the backtick in print, on the Markdown span. The
  paper now quotes that paragraph, grants it, and answers it: *"that operator
  is not this one. A reflection operator is written once per reflection and
  sits inside dense expression text, where a backtick operator is written
  where the name of an operation would go."* Concede, then defeat — the move
  A.1 was already built on, now aimed at a named paper instead of an
  anticipated objection.
- **Elm** trimmed to what its link carries: *"citing a single function,
  `andThen`, as pretty much the only one that used the feature."* The
  `|>`-redundancy argument survives two sentences later as the paper's own
  analysis. The font-confusability sentence is **gone** — see *Deviations*.
- **PureScript**, both passages, *"independently"* dropped. §Prior art now
  carries the real fact: the fixity is Haskell 2010 §4.4.2's `infixl 9`
  default, PureScript's own documentation says *"like in Haskell"*, and the
  strength is that **Haskell lets a fixity declaration override it and
  PureScript does not** — and PureScript has twice declined to add one, once
  as [an issue against the
  compiler](https://github.com/purescript/purescript/issues/137) and again as
  a standing Discourse proposal. §Precedence's copy now points at that history
  instead of restating a convergence claim.
- `[lex.pptoken]` in A.2 trap 2 marked `{.sref}` — **and one more**, see
  *Deviations*.

### One voice pass

Density only; the argument shape is untouched. Numbers in *Verification
evidence*.

## Verification evidence

### The compiler, read-only

```
$ ~/src/llvm/build-backtick-trunk/bin/clang -fbacktick -std=c++23 \
      -Xclang -ast-print -fsyntax-only rt.cpp
    return L `fnobj` R;              // named function object
    return L `lam` R;                // lambda held in a variable
    return L `plusish<int>{}` R;     // class template specialization temporary
    return L `f` R;                  // plain function
    return L `Agg` R;                // aggregate type slot
    return __builtin_shufflevector(x, y);   // the one exception
```

Five of six print as written; the sixth prints as its rewrite. That is exactly
the claim the paragraph now makes, and it is the whole exception list.

### The sweep, measured here

```
$ for i in 1 2 3; do /usr/bin/time -f "%e s" bash ops/probes/escape-positions.sh; done
ALL   79/79   79/79     1.61 s
ALL   79/79   79/79     1.63 s
ALL   79/79   79/79     1.61 s
```

Reproduces [slot-callable-printing](slot-callable-printing.handoff.md)'s
**1.6 s** exactly. The step file's 1.8 s is two measurements old.

### The build

```
$ rm -f papers/generated/backtick-infix-and-keyword-escape.{pdf,html}
$ make -C papers backtick-infix-and-keyword-escape.html \
       backtick-infix-and-keyword-escape.pdf > build.log 2>&1; echo "EXIT=$?"
EXIT=0
$ grep -ci "missing character\|warning\|error" build.log
0
```

Artifacts deleted first, so `EXIT=0` is not a no-op make. `monofont: "DejaVu
Sans Mono"` is untouched in the front matter and the `code span.er` style is
still in the **body**; there is no `header-includes` key and `\pnum` renders.

### Citations resolve with no fetch

Both new ids are in `papers/wg21/data/csl.json` already
(`P3381R0` 2024-09-17, `P2996R13` 2025-06-20), and the built PDF's References
section lists all six cited papers: P0543R3, P2011R1, P2558R2, P2971R3,
**P2996R13**, **P3381R0**.

### The Wording did not move

The Wording section was **not edited at all**. Comparing the pre-step and
post-step PDF text layers over `11 Wording` … `12 Appendix A`, whitespace and
pagination normalised, the two are word-for-word identical; the single
residual token is a **page number** left behind because the
`[expr.backtick]`p3 footnote floated to the next page, and the footnote text
itself is present in both PDFs. `{.pnum}` markers, `[text]{.add}` spans and
every block quote render as before.

### Voice metrics

Prose only: front matter, fenced code, block quotes, tables, headings and
inline code stripped. 8,805 words before, 9,143 after — the pass is net
positive because two paragraphs were split and the P3381R0 engagement is new
text.

| marker | before | after | target | his papers |
|---|--:|--:|--:|--:|
| em-dashes | 117 = 132.9/10k | **16 = 17.5/10k** | ≤ 20/10k | 20.1/10k |
| "However" | 3 = 3.4/10k | **15 = 16.4/10k** | ≥ 12/10k | 17.6/10k formal |
| "of course" | 0 | **2 = 2.2/10k** | — | 3.0/10k formal |
| appositive `, not Y` tail | 15 | **2** | ≤ 1 | 0.4/10k |
| "worth" as a move | 8 | **0** | ~1 | — |
| That/It/This-is openers | 5.1/100s | 4.9/100s | — | 3.3/100s |
| And/But/So openers | 2.9/100s | 2.5/100s | — | 0.4/100s |

```
$ python3 ~/.claude/skills/voice/scripts/lexcheck.py --register formal \
      papers/backtick-infix-and-keyword-escape.md
WARN   3 contraction(s) — papers don't use them
```

Before the pass it printed `WARN appositive ', not Y' tail x14` and
`WARN 1 contraction(s)`. **The tail warning is gone.** The contraction count
went 1 → 3 and the two added are *inside the verbatim P3381R0 quotation*
(*"it's pretty small"*, *"we also just don't think it's good enough"*);
lexcheck does not strip block quotes. That is the same warning class, not a
new one, and the alternative is misquoting a WG21 paper.

**On the two remaining appositive tails.** Both are out of this step's reach.
One is the protected bold general statement, which item 1 exists to keep. The
other, *"they are operator spellings, not names"*, is in the Wording section's
drafting notes, which this step left untouched so that the "nothing moved"
diff above could be exact. **`lexcheck` itself reports neither** — its
`TAIL_NOT` regex excludes newlines and both of these wrap — so the gate's
named tool is clean; the 2 is my own flattened count, which is the honest one.

### Public text stands alone

```
$ grep -nE "ops/|DEVIATIONS|PLAN\.md|BACKLOG|handoff|\bU[0-9][0-9]\b|\bS[0-9][0-9]\b|\bG[0-9][0-9]\b|BL0|slug" \
      papers/backtick-infix-and-keyword-escape.md
(no output)
```

### Scope

```
$ git diff --name-only        # before the ops commit
CLAUDE.md
ops/BACKLOG.md
ops/completion/PLAN.md
papers/backtick-infix-and-keyword-escape.md
```

## Deviations from the plan / design

1. **A second unmarked stable reference was marked.** The step file's item 8
   names one, `[lex.pptoken]` in A.2. There were two: §"Evaluation order is
   the call's" wrote `[expr.call]` bare, in ordinary prose, where sixteen
   others carry `{.sref}`. Both are marked now. Same defect, same fix, and a
   bare `[expr.call]` renders as literal brackets.
2. **The Elm font-confusability sentence was removed, not rehomed.** Item 6
   offered "cite a second source or trim to what the link supports"; trimming
   is what the step recommended and what I did. That left the paragraph's
   closing sentence — *"The font-confusability complaint is real, small, and
   filed where it belongs, in Appendix A.1"* — pointing at an objection no
   longer introduced **and** at an A.1 that discusses Markdown and keyboard
   layouts, never glyph confusability. Keeping it would have cited an
   objection nobody in the record makes. It is gone; if the author wants the
   point, it needs a source and a home in A.1, and it is not in the backlog
   because it is a choice rather than a defect.
3. **The Wording section, including its drafting notes, was left entirely
   alone.** The step file protects `[text]{.add}`, `{.pnum}` and the block
   quotes; the drafting-note bullets are ordinary prose and were fair game by
   that reading. I did not touch them, because the gate asks for a proof that
   nothing in the Wording moved and an exact proof is worth more than one
   comma. The cost is the second appositive tail above.
4. **The em-dash pass overshot and was walked back on purpose.** The
   enumeration pass took the count to **2** (2.2/10k) before I restored seven
   paired interruptions, landing at 16 (17.5/10k). See *Discoveries*:
   [unicode-paper-truth](unicode-paper-truth.handoff.md) flagged undershoot as
   the opposite failure mode and it is real.
5. **`CLAUDE.md`'s Phase J paragraph was updated.** It said Phase J was open
   and told an arriving agent to take the first unchecked step. After this
   step there is none. Two sentences and a layout bullet, no more.

Nothing contradicted a design doc, so **no `DEVIATIONS.md` entry is owed**.
The three ledgers still read **0 / 1 / 0**, the one being
[`escape-type-name-spelling`](../../gcc/DEVIATIONS.md#escape-type-name-spelling).

## Discoveries affecting later steps

- **A grid table will be silently destroyed by a paragraph-reflow script.**
  §"Neither replaces the other" is a pandoc **grid** table (`+---+`), where
  the `|` must line up with the `+`. My reflow collapsed one row's padding and
  pandoc emitted it as a literal line of text — *and the build still exited
  0*. It was caught by reading the rendered table in the PDF, not by the
  gate. **Check every table you touch in the output, not the source**, and
  the cheap invariant is that every line of a grid table is the same length:
  `awk '/^[|+]/ {print length}' | sort -u`.
- **The paper's other tables are pipe tables and do not care.** Only the
  P2011 comparison is a grid table.
- **The dash pass splits the way the sibling handoff said it does**, and its
  ratio held: of ~101 cuts, about 85 were one-token punctuation swaps
  (`— X —` → `(X)`, single pivot → `:`/`;`/`,`) and about 16 needed the
  sentence rewritten. The expensive ones are exactly where a dash sat with a
  second tell in the same clause.
- **Ten "However"s were available without manufacturing any.** The concessions
  were already in the argument, carried by a colon or a bare "and": the honest
  gap before `|>`, the single-compiler type slot, "neither compiler did on its
  first attempt", the A.4 better-engineered stranger, the Markdown friction
  being survivable, the EWG restriction question. None was bolted onto a
  non-concession.
- **Cutting dashes with "rather than" trips a different check.** Replacing
  appositive tails and pivots with *rather than* took `rather` to 23 = 26/10k
  against a base of 5.9, and `lexcheck` warned — a **new warning class**,
  which the gate forbids. The fix is to vary: `and not X`, a full stop, or
  reverting a comma form that the tail regex does not match (`, not two, and
  …` is invisible to it because of the second comma). Twelve substitutions
  took it back under the threshold.
- **`-ast-print` remains the cheapest paper-truth instrument in this repo.**
  Six shapes in one file, one command, and it settles a whole paragraph.

## Forward notes for the NEXT step

**There is no next step.** `ops/completion/PLAN.md` has 24 boxes and every one
is `[x]` or `[—]`; `ops/PLAN.md`, `ops/gcc/PLAN.md`,
`ops/unicode-operators/clang/PLAN.md` and `ops/backlog/PLAN.md` were already
complete. `docs/open-decisions.md` has no open question. **An agent arriving
with no other instruction should not go looking for work in `ops/`**, and
`CLAUDE.md` now says so instead of pointing at Phase J.

For whoever *is* handed the next piece of work, in the order it would bite:

- **Both papers are now fact-checked against the built compilers and voiced.**
  D4345R0 by [unicode-paper-truth](unicode-paper-truth.handoff.md), D4307R0
  here. Any further edit to either should re-run the same three checks: build
  both formats with the artifacts deleted first, `lexcheck --register formal`,
  and the prose-only dash/However rates.
- **Two backlog rows are corrections waiting for a passing edit, not steps.**
  [`hunk-count-provenance`](../../BACKLOG.md#hunk-count-provenance) (two
  Unicode documents) and
  [`sweep-timing-figure`](../../BACKLOG.md#sweep-timing-figure) (the backtick
  blog post, opened here). Neither owes a measurement. Whoever next opens
  `docs/infix-backtick-operator.org` or `docs/unicode-infix-operators.org`
  should fix them in passing.
- **If a paper is revised, the Wording is the region to leave alone**, and the
  proof technique above — `pdftotext -layout`, slice the section, normalise
  whitespace and page numbers, diff word by word — takes about a minute and is
  worth running whenever anything near it changes. Watch for the floating
  footnote: `[expr.backtick]`p3's footnote lands on whichever page holds the
  note and will move without the text moving.
- **The blog posts are the only reader-facing prose that has never had a voice
  pass**, and both carry a stale figure. They are `blog` register, not
  `formal`; `lexcheck --register blog` is a different set of thresholds
  (contractions expected, And/But/So openers expected).

## Open risks / TODOs

- **The em-dash rate landed at 17.5/10k against his published 20.1.** Under,
  again, though much less so than
  [unicode-paper-truth](unicode-paper-truth.handoff.md)'s 15.9. Seven paired
  interruptions were deliberately restored to get there and a couple more
  could go back with no harm; the candidates are the parenthesised
  interruptions in §"Fitting the grammar" and A.4.
- **The Elm paragraph is now shorter than the record it summarises.** Two of
  its three original reasons were real and unsourced. If someone finds where
  the `|>`-redundancy and glyph-confusability arguments were actually made,
  the paragraph wants them back with a citation.
- **`sweep-timing-figure` deliberately did not extend
  [`hunk-count-provenance`](../../BACKLOG.md#hunk-count-provenance).** The
  step file asked me to check, and I did: that row's question is *where a hunk
  count came from*, this one's is *what the sweep costs*. Folding them would
  leave a slug that names half its content, which is the failure the naming
  convention exists to prevent. Two rows, one paragraph each.
- **Nothing is pushed.** This repo is two commits ahead of its remotes. It
  tracks `ceridwen` **and** `origin`; the maintainer's call.
- **The three contractions `lexcheck` reports are two quotation marks away
  from zero** and should stay. A paraphrase of P3381R0 would be worth less
  than the quote.
