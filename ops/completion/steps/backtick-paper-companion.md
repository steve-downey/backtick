# backtick-paper-companion — D4307 names the level it shares, and the paper that shares it

**Goal.** Discharge both halves of an obligation this project decided and
never built: D4307R0 names its precedence level the **user-infix level**, and
carries a short **informative** future-directions appendix pointing at the
Unicode direction. Cite D4345 in the three places D4307 already leans on it
without naming it.

**Depends on:** none. Nothing depends on it either, but **it should land
before the two papers are submitted together**, because it is the condition
the decision to split them was taken under.

**Refs:** [`paper-separation`](../../../docs/unicode-operators.md#paper-separation),
the decision; [`paper-bundling`](../../../docs/backtick-operator-design.md#paper-bundling),
the rule it applies; `docs/backtick-operator-design.md` §9's list of what the
paper must carry, which is where the action item is written down.

## This is a decision already taken, not a proposal

Two documents say it, and one of them makes it a condition rather than a
preference.

`docs/backtick-operator-design.md`, in the list of what the paper must carry:

> Name the [precedence-level](#precedence-level) precedence level the
> **user-infix level**, not the backtick level, and carry a short
> **informative future-directions appendix** pointing at the Unicode operator
> sketch […] EWG then has its one operators-and-infix discussion with the
> whole landscape visible, banks the shared decisions (one level, left-assoc,
> desugar-to-call) once, and the follow-on paper inherits them as adopted
> precedent instead of reopening them. The appendix is informative and the
> papers' fates stay separate — Unicode-allergy must not be able to sink
> backtick.

`paper-separation`'s **Why** makes the appendix the mechanism that pays for
the split:

> The shared-discussion value is recovered without coupling: D4307 presents
> one *user-infix level* with an informative appendix showing this direction,
> EWG banks the shared decisions (one level, left-assoc, desugar-to-call)
> once with the whole landscape visible, and this paper inherits them as
> adopted precedent (U§12).

Without the appendix the split still happens and the recovery does not. That
is the argument for splitting running on one leg.

## Measured, 2026-09-15, reviewing PR #3

```
$ grep -c 'user-infix' papers/backtick-infix-and-keyword-escape.md
0
$ grep -cE 'D4345|P4345' papers/backtick-infix-and-keyword-escape.md
0
$ grep -cE 'D4307|P4307' papers/unicode-mathematical-operators.md
6
```

D4345R0 was restructured on 2026-09-09 and built the symmetric half: a
"Relation to D4307" note after its design section, a "Separability from
D4307, in evidence" section at the end, and four references in between. So
the two papers are now asymmetric in a way a WG21 reader will notice, and the
paper that does not name the other is the one that introduces the shared
level.

## Do

### 1. Name the level

In **"Precedence: the highest binary operator, and why not higher"**. The
level is currently introduced as this feature's own. Name it the *user-infix
level* at its introduction and use that name in the grammar discussion under
**"The productions"**, where the paper says "one new top level in each
compiler's binary operator precedence table".

D4345's wording for the same level is "the highest binary level, tighter than
`*` and looser than the unary operators, left-associative, with
cast-expression operands. That is the *user-infix level*". **Do not copy that
sentence.** D4307 introduces the level and D4345 inherits it; the paper that
introduces a thing states it in its own words, and the one that inherits it
cites. Getting this backwards is the mistake `paper-structure-design-first`
records against D4345's earlier draft.

One sentence saying the level is not backtick's alone, and that a companion
paper proposes a second user-introduced infix syntax at the same strength.

### 2. Appendix B, informative, short

Appendix A is "alternative spellings, and the lexical inventory", A.1–A.7, so
this is **Appendix B**. Four things, and no more:

- What D4345 proposes, in two or three sentences.
- That it sits at the same level, and that the level was designed to be shared
  rather than widened later.
- Which shared decisions EWG banks by discussing them once: one level,
  left-associative, desugar-to-call. Those three and not a longer list — they
  are the three `paper-separation` names.
- That the appendix is **informative**, that the two papers are adoptable
  independently and in either order, and that nothing in D4307 is contingent
  on D4345.

That last bullet is load-bearing and is the reason the appendix is bounded.
`paper-separation` split the papers partly so that "Unicode-allergy is real in
the room and must not be able to sink backtick". An appendix that reads as a
package deal re-couples the fates the split exists to keep apart, and would be
worse than no appendix.

D4345's "Relation to D4307" is the model for length and tone, and this is its
mirror. It is not a summary of D4345.

### 3. The evidence citation, which is the one that is not a courtesy

In **"Argument-dependent lookup, which both implementations got wrong"**, the
within-compiler control — one build, one machine, one author, one difference —
is the strongest evidence in the paper for the desugaring thesis, and the
other arm of it is currently "a companion design not proposed here".
Anonymous. A reader who wants to check the control has nothing to look up.

Name D4345 there. This is a citation defect and it would be worth fixing on
its own even if the appendix were declined.

### 4. The two places that state a shared decision as this paper's alone

- **"Two uses, one paper; no library"** states `paper-bundling`'s rule — bundle
  what shares a design surface within one committee, split what is separable
  across committees — and applies it only to the library split. The Unicode
  split is the other application of the same rule, by the same author, and
  belongs in the same paragraph or immediately after it.
- **The fold-operator exclusion**, under "The productions". D4345 states the
  same exclusion and adds that "D4307's backtick operator gets the
  character-identical diagnostic at the same level, so the decision covers
  both features and is taken once". From D4307's side it currently reads as
  taken independently. One clause noting the companion relies on it.

### 5. Put it in the Coverage table

This item had no row anywhere in `ops/` — it lived in `docs/` and the Coverage
table only claims to cover `ops/`. Add the step to the table with this row as
its scope, so the next audit finds it by grep. See **Notes**.

## Gate

1. ```
   grep -c 'user-infix' papers/backtick-infix-and-keyword-escape.md   # > 0
   grep -cE 'D4345' papers/backtick-infix-and-keyword-escape.md       # >= 4
   ```
   Four: the level, the appendix, the ADL control, and the bundling section.
2. `make -C papers backtick-infix-and-keyword-escape.html
   backtick-infix-and-keyword-escape.pdf` — **both**, exit 0, and read the
   log. The PDF is the one that catches a broken preamble.
3. The wording section is **untouched**. Appendix B is informative and adds no
   normative text; if this step has edited `[expr.backtick]` or `[lex.name]`,
   it has gone wrong.
4. Appendix B is under 40 lines, and says in as many words that the papers are
   independently adoptable.
5. Voice: the appendix is new prose, so it has had no pass. Em-dashes under
   about 20 per 10k, and none of the four coinages
   [`backtick-paper-truth`](backtick-paper-truth.md) and the 2026-09-09 voice
   pass removed. Prefer the `voice` skill.
6. Nothing in `docs/` needs to change. The design doc already says what to do;
   this step does it. Tick `paper-separation`'s obligation by adding a `Log.`
   line to it, dated, naming this step.

## Notes

**Cite D4345 in plain text, not `[@D4345]`.** D4307's citations run through
citeproc against the wg21 bibliography, which has no entry for an unpublished
D-number. D4345 already cites "D4307" as plain text for the same reason, six
times. Match it, and revisit when both have P-numbers.

**Why this was not already tracked.** `ops/completion/PLAN.md`'s Coverage
table opens "every open item has a home" and enumerates backlog rows,
deviation rows and design decisions — everything that originates in `ops/`. A
"what the paper must carry" list in a design doc has the same force and none
of the tracking, so this one went stale silently while every plan box read
green. It was found by a PR review on 2026-09-15 rather than by the plan, and
the plan is what should have found it. Step 5 above is the narrow fix; the
general one is to read the design docs' paper-requirements lists when auditing
whether work is outstanding.

**This step edits one file.** No compiler source, no test, no gate on any
branch, and no forward-port to `unicode-operators-experiment`.
