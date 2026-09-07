# Handoff — reconcile-remainder — U§5, §6, §8, §10, §12, §13, the backtick ledger, and the end of the ledgers

- **Status:** **DONE (docs gate passed).**
- **Branch / commit:** no branch. `unicode-operators` in *this* repo only —
  `684c92d` (`docs:` — `docs/unicode-operators.md`, `docs/backtick-operator-design.md`,
  `papers/dxxxxr0.md`, `papers/d4307r0.md`) and the `ops:` commit carrying
  fourteen ledger rows, the Unicode ledger's rewritten header, the backlog row,
  `REPLAY.md` §5, the experiment plan, the plan and this handoff.
  **Nothing was built and no feature branch was touched.** Four LLVM worktrees
  and their pre-built binaries were *read and run* to re-derive every figure
  below; none was modified.
- **Date / agent:** 2026-09-06.
- **Reconciles:** [`exclusion-list-derivation`](../../unicode-operators/clang/DEVIATIONS.md#exclusion-list-derivation),
  [`ucn-operator-spellings`](../../unicode-operators/clang/DEVIATIONS.md#ucn-operator-spellings),
  [`exclusion-diagnostics`](../../unicode-operators/clang/DEVIATIONS.md#exclusion-diagnostics),
  [`clang-format-user-operators`](../../unicode-operators/clang/DEVIATIONS.md#clang-format-user-operators),
  [`feature-coupling`](../../unicode-operators/clang/DEVIATIONS.md#feature-coupling),
  [`replay-ordering`](../../unicode-operators/clang/DEVIATIONS.md#replay-ordering),
  [`postfix-operators`](../../unicode-operators/clang/DEVIATIONS.md#postfix-operators)
  (clauses (4) and (5)); the outstanding halves of
  [`infix-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost),
  [`prefix-arity-selection`](../../unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection)
  and [`ast-node-shape`](../../unicode-operators/clang/DEVIATIONS.md#ast-node-shape);
  and [`wrapper-inner-shape`](../../DEVIATIONS.md#wrapper-inner-shape),
  [`analysis-layer-sites`](../../DEVIATIONS.md#analysis-layer-sites),
  [`type-slot-cost`](../../DEVIATIONS.md#type-slot-cost),
  [`cir-backtick-arms`](../../DEVIATIONS.md#cir-backtick-arms).
  [`gcc-type-slot-parity`](../../gcc/DEVIATIONS.md#gcc-type-slot-parity) was
  taken by [gcc-resync](gcc-resync.handoff.md) and was **not** re-done.
- **Closes:** [`confusable-spellings`](../../BACKLOG.md#confusable-spellings) —
  as *curated, with the principle written down*, which is the answer and not a
  deferral.

---

## The three ledgers, at the end

```
$ grep -n 'Status:\*\* OPEN' ops/DEVIATIONS.md ops/gcc/DEVIATIONS.md \
      ops/unicode-operators/clang/DEVIATIONS.md
$ echo $?
1
```

Nothing. And a per-entry sweep, because a grep for one spelling of `OPEN` is
not proof that every row is *marked* — it is only proof that none says that
word:

```
ops/DEVIATIONS.md:                        11 rows, unreconciled/unmarked = 0
ops/gcc/DEVIATIONS.md:                    10 rows, unreconciled/unmarked = 0
ops/unicode-operators/clang/DEVIATIONS.md: 24 rows, unreconciled/unmarked = 0
```

- **`ops/DEVIATIONS.md`** — 11 rows: 8 `RECONCILED`, 2 `RESOLVED`, 1
  `FIXED and RECONCILED`. Four of the eight were marked here.
- **`ops/gcc/DEVIATIONS.md`** — 10 rows: 2 `RESOLVED`, 3 `FIXED`, 1
  `RECONCILED`, 1 `RECORDED`, 3 `NO DOC CHANGE`. **Untouched by this step**;
  [gcc-resync](gcc-resync.handoff.md) left it clear and its forward note said
  so, which was correct — two ledgers to clear, not three.
- **`ops/unicode-operators/clang/DEVIATIONS.md`** — 24 rows, **all
  `RECONCILED`**, from 17/7 at the start of this step. Its header is rewritten
  to say so, and to say when: four steps of one day, 2026-09-06.

**This is the first time since the tracks began that no ledger carries an
unreconciled row.**

---

## The findings that outrank the rewrite

### Two more recorded mechanisms failed re-checking — five now, in five steps

The run continues, and both of this step's are in rows I was reconciling.

**1. [`ucn-operator-spellings`](../../unicode-operators/clang/DEVIATIONS.md#ucn-operator-spellings)'s
clause (c) is wrong, and it is wrong in the direction that mattered.** It says
that "every *excluded* code point" gets the exclusion reason when spelled as a
literal glyph and *no lexer diagnostic at all* when spelled as a UCN, and its
recommendation (3) asks the reader to **decide** whether the exclusion messages
must fire for UCN spellings. There was nothing to decide: **they already do.**

```
$ printf 'int x = 1 \xe2\x88\x92 2;\n'   # literal U+2212
error: '−' U+2212 is not a user-defined operator: it is confusable with '-'
$ printf 'int x = 1 \\u2212 2;\n'        # the same code point as a UCN
error: '−' U+2212 is not a user-defined operator: it is confusable with '-'
```

Same message, both spellings; only the caret differs (six columns for the
escape, one for the glyph). Both are silent with the flag off. The asymmetry
the clause describes is **real but narrower and inherited**: it applies to a
code point that is neither in the set *nor excluded* nor XID — checked with
¬ U+00AC, ± U+00B1 and ☺ U+263A — which gets upstream's `unexpected character`
when written literally and nothing when written as a UCN, identically with the
flag off and on, at every `-std=`. So the row asked for a *decision* about a
gap the implementation had already closed, and the honest reconciliation is a
correction, not a ruling.

**2. [`replay-ordering`](../../unicode-operators/clang/DEVIATIONS.md#replay-ordering)'s
headline command is no longer reproducible, and looks like contamination.**
The row, the step file and U§12's intended claim all give it as

```
git diff upstream/main..unicode-operators-upstream | grep -i backtick   -> nothing
```

Run today it returns **six lines**. All six are upstream's own — Markdown
fence guidance in a docs file, and an `arg_has_backtick` local in lldb —
arriving on `upstream/main` after the branch point. Against the branch's
actual base `d28193fa1ff6` the count is **0**, as claimed. The claim is true;
the *check* was not reproducible, and a reviewer running it in six months
would have concluded the separability result was false. Both destinations now
pin the base commit and say why.

### A fourth bad count, and it was measured on the wrong branch

[`clang-format-user-operators`](../../unicode-operators/clang/DEVIATIONS.md#clang-format-user-operators)
records "3 production files, +32/−9". Measured:

| Where | Production diff |
|---|---|
| `unicode-operators-upstream` vs. its base — **the standalone cost** | **+40/−1** over 3 files |
| the U18 commit on `unicode-operators-experiment` | +47/−10 over the same 3 files |
| recorded in the row | +32/−9 |

The nine deletions exist only on the experiment branch, and they are the
refactor of the *backtick* track's inline post-operand test — not this
feature's cost at all. **The standalone figure is both the larger and the
simpler one**, and it is the one a paper wants, because it is what the feature
costs a compiler that has never heard of backtick. `papers/dxxxxr0.md` said
"32 lines" and now says about forty across three files.

### Both papers were carrying claims their own answers had discarded — again

This is the **third consecutive step** to find that, and the second to find it
in `papers/dxxxxr0.md`.

- Its *Fold expressions* section said the exclusion "is inherited from sharing
  the level" and that admitting the level to `fold-operator` "is an open
  question". The author answered it on 2026-09-06: **excluded, deliberately,
  one answer for both features.** Inherited and decided are not the same claim,
  and the difference is exactly what the answer was for.
- The same paper listed **Fold expressions** under *What is not resolved*.
- And the formatting figure above.

`papers/d4307r0.md` had no fold sentence at all; the decision said it owed one,
and it now has it in *The productions*.

**The rule from [reconcile-declaring-using](reconcile-declaring-using.handoff.md)
held and should be treated as standing procedure: when an answer changes a
claim, grep the papers for the old claim before writing the new one.** Neither
of these would have been found by an identifier sweep — both are prose.

### A section heading had been silently deleted

`docs/unicode-operators.md` has had no `## 11. Prior art` heading since
`a9fdb73` (*"docs: the two WONTFIX answers, and a reopened question"*), which
replaced it, and the `---` above it, with the new `operator-name-caret-range`
subsection. The prior-art list has been hanging off the end of §10 ever since.
That is why
[`clang-format-user-operators`](../../unicode-operators/clang/DEVIATIONS.md#clang-format-user-operators)
and other rows cite a "U§11's open-question list" that no reader could find —
the list they mean is **§13's**, and §11 is prior art. Heading restored; the
stale `U§11` citations in ledger rows are left as they are, since the rows are
history and the destinations are named in their `Status` lines.

---

## What changed, and where

### `docs/unicode-operators.md`

**U§5** — predicate 5 stops being prose and becomes the enumeration the
implementation has always had: **28 code points, 3 identifier-profile / 13
confusable / 12 emoji**, every one spelled out with the ASCII token it apes,
followed by the two corrections the enumeration forced (the middle-dot family
is exactly ∙ U+2219 and ⋅ U+22C5, and U+00B7 was never a candidate; U+2044 ⁄ is
outside the blocks and already fails predicate 3). A new slug-headed
subsection, [confusable-spelling-provenance](../../../docs/unicode-operators.md#confusable-spelling-provenance),
in the full **Question / Status / Decision / Why / Decided by / Log** shape,
answers the derived-or-curated question: **curated**, deriving would be worse,
and the principle is *the spelling names the token a reader is most likely to
mistake the character for, not the operation the character denotes* — which is
also why the message says *is confusable with* and carries **no fix-it**.

**U§6** — three changes to one section, deliberately in one step because they
are one paragraph. (a) The structural one-liner, before the examples:
`ParseCastExpression` reads the prefix production and
`ParseRHSOfBinaryExpression` the infix one, they never see the same token, so
**no disambiguation state exists** — stated against §5's suppression flag,
which is the contrast that makes it mean something. (b) The **sixth worked
example**, `⊖a ⊞ 2 * ⊖b`, with the note about why it is there. (c) The
contested sentence, rewritten as a three-bullet split plus the
finding-about-the-finding paragraph.

**U§8** — two rewrites, no counts touched. Paragraph 2 becomes the
emission-scope rule and its two consequences (the disjointness argument
turned around, and `operator∂`-closed-up as a second argument for it). The UCN
paragraph gains the classification/identity split. And
[closed-table-sibling-pattern](../../../docs/unicode-operators.md#closed-table-sibling-pattern)
gains its **fifth row**, which resolves a live collision — the table said *four
times*, §13.1 said *the fourth*, and they meant different fours.

**U§10** — the clang-format bullet, measured, with the precedence-query trap
called out as the one a reviewer forgets and turned into the argument for one
fixed level.

**U§12** — the largest block: separable fates as an executed result with the
base pinned; the three coupled constructs with the silent one named; the
shared level surfacing twice independently; **the two features must not share
an AST representation** ([`ast-node-shape`](../../unicode-operators/clang/DEVIATIONS.md#ast-node-shape)'s
owed sentence, in the design register); the formatting comparison; the postfix
routing bullet; the maintenance-cost datum; and the *maturity differs* bullet
corrected from "this sketch has none" to one implementation, which has been
false since the prototype was built.

**U§13** — the fold bullet (new), and the `operator`-adjacency bullet rewritten
from an open question to an answered one.

**§2** — [ucn-spellings](../../../docs/unicode-operators.md#ucn-spellings)'s
**Why** amended from *"Structurally free"* to the split, and a dated `Log.`
giving the acceptance criterion at declaration-and-use level.

### `docs/backtick-operator-design.md`

**§6** gains three items: the analysis layer (7 sites, one announced),
the code generator (4 arms, 4 unlike failure modes, one of them an assert),
and a pointer to the priced type slot; its test item gains the
diff-at-two-configurations line. **§11 phase 2**'s *"purely additive"* is
corrected in place, closing on the generalization — **the transparency is what
costs, not the node**. **§17.3** is rewritten around the correction that a bare
type-name is not an *assignment-expression*, with the measured price, and
[type-name-slot](../../../docs/backtick-operator-design.md#type-name-slot)'s
old clause is **struck in place** in a dated `Log.` rather than deleted.
**§17.7** (new) states the back-end symmetry. **§17.8** (new) says which of
§§17.5–17.7 has no GCC counterpart *by construction*, and keeps that separate
from the one real gap.

### `papers/`

Four passages, all described above. **No internal identifier was introduced.**

### Ledgers and bookkeeping

Ten Unicode rows and four backtick rows marked; the Unicode header rewritten;
[`confusable-spellings`](../../BACKLOG.md#confusable-spellings)'s `Closed by`
filled; `REPLAY.md` §5's two traps struck **in place** with their corrections
attached; the experiment plan's replay assumption replaced; the plan's
checklist, two Coverage rows and four Status-log rows.

---

## Verification evidence

**No build; no feature branch. Correct for this step** — the step file says so.

### The docs gate: every row names its destination section *and paragraph*

| Row | Destination |
|---|---|
| [`exclusion-list-derivation`](../../unicode-operators/clang/DEVIATIONS.md#exclusion-list-derivation) | U§5 predicate 5 (the 3/13/12 enumeration) and the paragraph after it beginning *"Two corrections the enumeration forced"*; the new [confusable-spelling-provenance](../../../docs/unicode-operators.md#confusable-spelling-provenance); `papers/dxxxxr0.md`'s exclusions section, the paragraph beginning *"The ASCII token named beside each confusable is curated, not derived"* |
| [`ucn-operator-spellings`](../../unicode-operators/clang/DEVIATIONS.md#ucn-operator-spellings) | U§8, the four-paragraph block beginning *"An earlier draft called that 'structurally free'"*, whose last paragraph answers clause (3) with the correction; [ucn-spellings](../../../docs/unicode-operators.md#ucn-spellings)'s amended **Why** and its new `Log.` |
| [`exclusion-diagnostics`](../../unicode-operators/clang/DEVIATIONS.md#exclusion-diagnostics) | U§8 paragraph 2 — the paragraph beginning *"But the three reasons do not have the same scope"*, its two bullets, and the two paragraphs after them (*"That asymmetry is the sharpest evidence…"*, *"And a second, independent argument…"*); U§5's [confusable-spelling-provenance](../../../docs/unicode-operators.md#confusable-spelling-provenance), last two paragraphs |
| [`clang-format-user-operators`](../../unicode-operators/clang/DEVIATIONS.md#clang-format-user-operators) | U§10's clang-format bullet and its sub-paragraph *"The third touch point is the one a reviewer will forget"*; U§13's rewritten adjacency bullet; U§12's paragraph *"They do not share a formatting story either"* |
| [`feature-coupling`](../../unicode-operators/clang/DEVIATIONS.md#feature-coupling) | the experiment plan's *Upstream Replay Assumptions*, the struck bullet and its numbered three plus the soft-coupling bullet; U§12's paragraphs *"The coupling, measured, is three constructs…"* and *"The shared level surfaced twice, independently"* |
| [`replay-ordering`](../../unicode-operators/clang/DEVIATIONS.md#replay-ordering) | `REPLAY.md` §5's *"Two ordering traps"*, both struck in place with corrections plus the conflicts-not-fuzz third; the experiment plan's *"The replay is executed, not assumed"* bullet; U§12's *"Separable fates are now an executed result"* paragraph and the maintenance-cost paragraph |
| [`postfix-operators`](../../unicode-operators/clang/DEVIATIONS.md#postfix-operators) | (4) U§12's fourth bullet, *"And postfix, if it were ever taken, would move the routing again"*; (5) [closed-table-sibling-pattern](../../../docs/unicode-operators.md#closed-table-sibling-pattern)'s fifth table row and the paragraph *"The fifth is different again"*, with §13.1's *"fourth consecutive place"* corrected to *fifth* and cross-linked. (1) and (2) verified already written, not re-done |
| [`infix-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost) | (1) U§6, the block beginning *"'Parsing is the easy part…' — the first half survives measurement"*; (3) U§13's new fold bullet, plus `papers/dxxxxr0.md`'s rewritten *Fold expressions* and `papers/d4307r0.md`'s new paragraph in *The productions*. Parenthetical now **RECONCILED (all three parts)** |
| [`prefix-arity-selection`](../../unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection) | U§6, the paragraph beginning *"That is not merely a rule the parser follows"*. Parenthetical now **RECONCILED (all four recommendations)** |
| [`ast-node-shape`](../../unicode-operators/clang/DEVIATIONS.md#ast-node-shape) | U§12, the paragraph beginning *"What the two features must not share is an AST representation"*. Parenthetical now **RECONCILED (both halves)** |
| [`wrapper-inner-shape`](../../DEVIATIONS.md#wrapper-inner-shape) | `docs/backtick-operator-design.md` §6 item 4, the appended block *"What Sema hands back is not always a call"*; §11 phase 2's *"'Purely additive' is the word this phase got wrong"* |
| [`analysis-layer-sites`](../../DEVIATIONS.md#analysis-layer-sites) | §6's new item 7, *"The analysis layer, which no site list contained"*; the second half of §11 phase 2's corrected paragraph; §6's test item |
| [`type-slot-cost`](../../DEVIATIONS.md#type-slot-cost) | §17.3's three new paragraphs (*"This was recorded as a consequence…"*, *"Stated correctly…"*, *"And it is not free…"*); [type-name-slot](../../../docs/backtick-operator-design.md#type-name-slot)'s reworded **Why** and its striking `Log.`; §6's new item 9 |
| [`cir-backtick-arms`](../../DEVIATIONS.md#cir-backtick-arms) | §6's new item 8, *"The code generator"*; the new **§17.7**, whose middle paragraph is the cross-compiler symmetry and whose last is the upstream observation kept separate |
| [`confusable-spellings`](../../BACKLOG.md#confusable-spellings) | its `Closed by` cell; [confusable-spelling-provenance](../../../docs/unicode-operators.md#confusable-spelling-provenance); the paper paragraph above |

**No row is marked closed that is not**, and two rows I could have taken were
deliberately not: `gcc-type-slot-parity` (gcc-resync's, and already
`RECONCILED`) and every row in `ops/gcc/DEVIATIONS.md`, which was not edited.

### The measurements, re-derived rather than quoted

Unicode facts on the pre-built `~/src/llvm/build-unicode-upstream` binaries
(`clang++`, `clang-format`), worktree `~/src/llvm/unicode-upstream` @
`c0e07f78e679`; backtick facts by reading `~/src/llvm/backtick-trunk` @
`9504b2c1fc51`. Nothing was rebuilt.

| Claim | How it was checked | Result |
|---|---|---|
| the exclusion table's shape | read `clang/lib/Lex/UnicodeOperatorCharSets.h` | **28 entries: 13 confusable, 3 identifier-profile, 12 emoji** — matches the ledger |
| U+2044 is outside the blocks | its value against the block list in the same header | 0x2044 < 0x2190, so predicate 3 already excludes it |
| the middle-dot family | the table's dot-spelled entries | exactly U+2219 and U+22C5; no U+00B7 anywhere |
| exclusion diagnostic, literal *and* UCN | `1 − 2` and `1 − 2`, flag on and off | **identical message in both spellings**, flag-gated; see the findings |
| the residual asymmetry is upstream's | ¬ U+00AC, ± U+00B1, ☺ U+263A, literal and UCN, flag on and off | literal → `unexpected character`, UCN → nothing, unchanged by the flag |
| ∂ ∇ ∞ are identifier characters here | `int ∂(int); int u = ∂(1);` | compiles, `-Wc++2d-extensions` warning only |
| …and the note is operator-position-only | `struct T { operator ∂(); };` | `unknown type name '∂'` **+** the identifier-profile note |
| `operator∂` closed up is one identifier | `-ast-dump` of `int operator∂(S, S);` | `FunctionDecl … operator∂ 'int (S, S)'` — an ordinary function |
| no fix-it on a confusable | `int operator ∙(S, S);` | the confusability error, no `fix-it:` line |
| one classification point, four callers | `grep isUserOperatorCodePoint` over `clang/lib`, `clang/include` | 1 definition, **4** call sites (2 in the decode paths, 2 in identifier continuation) |
| identity canonicalizes UCNs at one place | read `Lexer::getUserOperatorCodePoint(StringRef)` | one `if (Spelling.front() == '\\') return decodeUCNSpelling(...)` |
| …and three spellings are one entity | declare with `\N{SQUARED PLUS}`, define with the glyph, use with `⊞`, `-emit-llvm` | one symbol, `_Zv28op_u229E1SS_` |
| the sixth example's tree | type-forced probe: `⊖: A→B`, `⊞: (B,int)→C`, `*: (C,B)→E` | compiles ⇒ **`(⊖a ⊞ 2) * ⊖b`**, as both documents say |
| fold is `expected expression` in both features | `(t ⊞ ...)` on the Unicode binary, `` (t `f` ...) `` on `build-backtick-trunk` | **character-identical**, caret on the `...` |
| the fold guard is present | read `Parser::isFoldOperator` | `Level != prec::UserInfix`, third clause |
| the three coupled constructs | `prec::UserInfix`; `isFoldOperator`; `endsOperand` on **both** Unicode branches | `endsOperand` names `TT_BacktickEscapeClose` on `unicode-operators-experiment` and **does not** on `unicode-operators-upstream` |
| clang-format's standalone cost | `git diff --numstat <base>..HEAD -- clang/lib/Format/` | **+40/−1** over 3 files; the U18 commit on the experiment branch is +47/−10 |
| …and no new `TokenType` | `git diff … \| grep '^+.*TYPE('` over the Format headers | empty |
| `operator ⊞` canonicalizes | `clang-format` on `S operator ⊞(S,S);` | `S operator⊞(S, S);` |
| `BreakBeforeBinaryOperators: All` | a chain at `ColumnLimit: 28` | the break lands **before** `⊞` |
| the analyzer site count | `grep -rn BacktickInfixExpr clang/lib/Analysis clang/lib/StaticAnalyzer` | **7 sites in 5 files**; enclosing functions confirmed by reading back to each definition |
| the CIR arms, both features | `grep -rn` in `clang/lib/CIR/` on each branch | **4 arms, same 4 files, same 4 places** for `BacktickInfixExpr` and `UserOperatorExpr` |
| the separability grep | against `upstream/main` and against the base `d28193fa1ff6` | **6** and **0** — see the findings |

### Links

**2179 local Markdown links** across every tracked `.md` outside
`papers/wg21/`, **0 broken** — file existence and GitHub-style anchor slugs,
whitespace runs not collapsed, links inside inline code spans and fenced
blocks excluded. The new `#confusable-spelling-provenance` anchor resolves
from all four places that link to it, and the restored `## 11. Prior art`
heading adds an anchor rather than breaking one.

### Public text

`grep -nE '\bDEV-[UG]?[0-9]+\b|\bB[0-9]{2}\b|\bD[0-9]{1,2}\b|\bU[0-9]{1,2}\b|U§'`
over `papers/*.md` and `docs/*.org` finds **only the four pre-existing `U§`
references** [reconcile-declaring-using](reconcile-declaring-using.handoff.md)
flagged for [unicode-paper](../steps/unicode-paper.md). This step introduced
none.

---

## Deviations from the step file

1. **[`postfix-operators`](../../unicode-operators/clang/DEVIATIONS.md#postfix-operators)
   was taken although it is not in the "Closes / reconciles" list.** Its gate —
   *zero unreconciled rows in any of the three ledgers* — could not otherwise
   pass, and [reconcile-declaring-using](reconcile-declaring-using.handoff.md)'s
   forward notes said so by name. Its clauses (1) and (2) were verified already
   written before being marked, rather than re-done.
2. **Item 3 of the "Do" (`CLAUDE.md`'s Layout) was already done** by
   [mangling-abi](mangling-abi.handoff.md) and is not re-done. `CLAUDE.md` is
   untouched by this step.
3. **U§8 was edited**, although
   [reconcile-implementation-cost](reconcile-implementation-cost.handoff.md)'s
   forward notes say not to touch it. That instruction is about the *counts*
   and the cost thesis, and neither was touched: no figure in U§8 was
   restated or changed, and [dispatch-obligation-taxonomy](../../../docs/unicode-operators.md#dispatch-obligation-taxonomy)
   is untouched. What was edited is paragraph 2 (the exclusion reasons) and the
   UCN paragraph, which are
   [`exclusion-diagnostics`](../../unicode-operators/clang/DEVIATIONS.md#exclusion-diagnostics)'s
   and [`ucn-operator-spellings`](../../unicode-operators/clang/DEVIATIONS.md#ucn-operator-spellings)'s
   named destinations and were left alone by that step, plus the fifth row of
   [closed-table-sibling-pattern](../../../docs/unicode-operators.md#closed-table-sibling-pattern),
   which resolves the four-versus-four collision described above.
4. **`papers/dxxxxr0.md` and `papers/d4307r0.md` were edited**, which the step
   file does not mention. The fold decision explicitly owes a sentence in the
   backtick paper and names this step as owner of its documentation, and the
   Unicode paper's own fold section asserted the two things the answer
   discarded. The other two edits are a corrected figure this step measured and
   a claim this step decided. Everything else in both papers is left to
   [unicode-paper](../steps/unicode-paper.md) and
   [backtick-paper](../steps/backtick-paper.md).
5. **A missing section heading was restored** in `docs/unicode-operators.md`.
   Not in scope as written; it is a destination-section defect that made two of
   this step's own rows cite a section that did not exist.
6. **U§12's *maturity differs* bullet was corrected** from "this sketch has
   none" to one implementation. Out of scope as a row, incoherent to leave: it
   sat four lines above the paragraph in which this step reports the executed
   replay of the prototype it claims does not exist.

---

## Discoveries affecting later steps

- **A ledger row can be stale about a *gap* as well as about a mechanism.**
  [`ucn-operator-spellings`](../../unicode-operators/clang/DEVIATIONS.md#ucn-operator-spellings)
  asked for a decision about a diagnostic asymmetry that the implementation had
  already closed. When a row's recommendation says *"decide whether X"*, run X
  before writing the decision; the answer may be that X is done.
- **A grep is not a reproducible check unless its endpoints are pinned.** The
  separability result is the strongest single thing U§12 has and its evidence
  was a command whose meaning drifts with upstream. Any check a paper cites
  should name its commits.
- **The `-Wc++2d-extensions` math-identifier extension is on by default at
  every `-std=`**, with no flag, which is what makes the ∂ ∇ ∞ exclusion
  diagnostic a note rather than an error. Anything reasoning about identifiers
  and this feature has to account for it; it is not a hypothetical future
  extension.
- **A type-forced probe is the cheapest way to pin a precedence claim.** Give
  each operator a distinct result type and let the program fail to compile if
  the tree is different; it is stronger than reading `-ast-dump` and it fits in
  six lines. Used here for U§6's sixth example.
- **Two documents disagreeing about a count is a detectable defect and nobody
  was detecting it.** §13.1 said *the fourth* and U§8's table said *four times*
  of a different four. A count that appears in two places should appear in one,
  with the other linking to it — which is what
  [reconcile-implementation-cost](reconcile-implementation-cost.handoff.md)
  concluded about counts generally, applied to a count that is not a site
  count.

---

## Forward notes for the NEXT step — [hygiene-parity](../steps/hygiene-parity.md)

Written after reading its step file.

- **Its "Closes" list is already right about
  [`confusable-spellings`](../../BACKLOG.md#confusable-spellings)** — the step
  file says in its own parenthetical that reconcile-remainder closes it. It is
  closed, in `ops/BACKLOG.md` and as
  [confusable-spelling-provenance](../../../docs/unicode-operators.md#confusable-spelling-provenance).
  The plan's Coverage table said otherwise and is corrected. **Nothing else in
  that step's list was touched here.**
- **Its [`template-id-code-point`](../../BACKLOG.md#template-id-code-point)
  item asks for one sentence in `docs/unicode-operators.md` §8, and §8 moved
  under this step.** Two places in §8 are now dense: paragraph 2 (exclusion
  reasons) and the UCN block. The `TemplateIdAnnotation` sentence belongs with
  neither — put it in the ***Parser, declaring an operator*** bullet, which
  already names the `TemplateIdAnnotation` gap and is
  [reconcile-implementation-cost](reconcile-implementation-cost.handoff.md)'s
  text, so append rather than rewrite.
- **Both of its `-Wswitch` claims are about the backtick side and neither was
  touched here.** The `CXCursor.cpp` warning is still live; I did not build.
  But note that `docs/backtick-operator-design.md` §6 now has **ten** numbered
  items rather than seven, and items 7 and 8 (the analysis layer, the code
  generator) are exactly the categories
  [`libclang-cursor-arm`](../../BACKLOG.md#libclang-cursor-arm) sits beside —
  when that row closes, §6's item 7 is where the tooling sentence goes.
- **The formatting item's gate warning is the real one.** `check-clang`
  self-formats `clang/lib/Format/` **and** `clang/unittests/Format/` with the
  in-tree binary and aborts at ~step 81/970. Nothing in this step went near
  either, so that trap is untouched and undisarmed.
- **No build, no branch here.** hygiene-parity is the first step in a while
  that genuinely needs both, on `backtick-trunk` and `backtick-23`, with the
  gate re-verified independently on each.

---

## Open risks / TODOs

- **`papers/dxxxxr0.md`'s *What is not resolved* list still contains two items
  the author has since decided**, and they are not mine: *"Default arguments in
  prefix position. Keep the relaxation and document it, or reinstate
  [over.oper]p8"* was answered (keep the relaxation), and *"Static member user
  operators, currently rejected"* now has a decision entry with a reason. Both
  are [unicode-paper](../steps/unicode-paper.md)'s, and both are the same shape
  of defect this step and the last two found by accident. **The list is worth
  reading against `docs/open-decisions.md`'s answers line by line**, not
  grepped. *Member-versus-non-member sequencing* is genuinely still open and
  should stay.
- **`papers/d4307r0.md`'s implementation-experience section does not say that
  the type-name slot has single-compiler evidence**, which
  `docs/backtick-operator-design.md` §17.3 now says it must.
  [backtick-paper](../steps/backtick-paper.md)'s, flagged by
  [gcc-resync](gcc-resync.handoff.md) too, and §17.8 now gives it the framing:
  the wrapper's cost has no GCC counterpart *by construction*, the type slot is
  a *gap*, and the two must not be run together.
- **`papers/dxxxxr0.md` still carries four `U§` cross-references.** Unchanged,
  still [unicode-paper](../steps/unicode-paper.md)'s.
- **The stale `U§11` citations in ledger rows are not fixed.** The heading is
  restored, but §11 is *prior art* and the rows that say "U§11's open-question
  list" mean §13. The rows are history and their `Status` lines name the real
  destinations, so this is recorded rather than rewritten.
- **`CheckUserOperatorDeclaration`'s comment still asserts the abandoned
  static-member reason** on both Unicode branches. Still unowned; `M2` is still
  the first step that will be in that file.
- **Nothing is pushed.** This repo is ahead of every remote, as are the LLVM
  and GCC worktrees; unchanged by this step, which committed only here.
