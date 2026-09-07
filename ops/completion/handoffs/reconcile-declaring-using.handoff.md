# Handoff — reconcile-declaring-using — U§7 and §7.1: declaring, using, desugaring

- **Status:** **DONE (docs gate passed).**
- **Branch / commit:** no branch. `unicode-operators` in *this* repo only —
  `feccd46` (`docs:` — U§7, U§7.1, U§4 and the §2 decisions log, including the
  new [static-member-operators](../../../docs/unicode-operators.md#static-member-operators)
  entry), `e1bdd07` (`docs:` — the two falsifiable sentences in
  `papers/unicode-mathematical-operators.md`) and the `ops:` commit carrying the eight ledger rows,
  the ledger header, the backlog row, the plan and this handoff.
  **Nothing was built and no feature branch was touched.** The
  `unicode-operators-upstream` worktree and its pre-built binary were *read
  and run* to re-derive every measurement quoted below; nothing in any LLVM or
  GCC worktree was modified.
- **Date / agent:** 2026-09-06.
- **Reconciles:** [`ucd-version-drift`](../../unicode-operators/clang/DEVIATIONS.md#ucd-version-drift),
  [`disjointness-evidence`](../../unicode-operators/clang/DEVIATIONS.md#disjointness-evidence),
  [`over-oper-restrictions`](../../unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions),
  [`operator-id-anywhere`](../../unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere),
  [`infix-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost) (U§7 half),
  [`prefix-arity-selection`](../../unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection)
  (decision entry + U§7 half),
  [`operand-sequencing`](../../unicode-operators/clang/DEVIATIONS.md#operand-sequencing)
  (as an open CWG question), and the outstanding U§7 half of
  [`operator-candidate-assembly`](../../unicode-operators/clang/DEVIATIONS.md#operator-candidate-assembly).
- **Closes:** [`dependent-template-operator-id`](../../BACKLOG.md#dependent-template-operator-id)
  — on the reword alone, as the author's second answer directed.

---

## The finding that outranks the rewrite

**Both papers were already carrying sentences the author's answers discarded,
and nobody had gone to look.** `papers/unicode-mathematical-operators.md` asserted, in its own words:

1. *"not a static member: kept. The arity rule presupposes an implicit object
   parameter, and a static member has none, so it can name neither form."*
   That is the reason [decision-brief](decision-brief.handoff.md) established
   does **not survive inspection** — the arity rule counts *operands*, so a
   two-parameter static member has two and would be accepted.
2. *"One limitation is inherited rather than introduced … The identical
   construct on a user-defined literal operator produces a character-identical
   diagnostic, and has since C++11."* That is the clause
   [upstream-triage](upstream-triage.handoff.md) disproved, which
   [mangling-abi](mangling-abi.handoff.md) then forbade in four places.

The prohibition was carefully installed in the ledger row, the backlog row,
the open-decisions answer and the plan — every place a *future* writer would
look — and the false clause was sitting in the deliverable the whole time.
**A prohibition on writing something is not a check that it is not already
written.** Both are corrected in `e1bdd07`; the corrected paper text is quoted
under "Verification evidence" so it can be read against the prohibition
without opening the paper.

The rule this suggests, for the two paper steps: **when an answer changes a
reason, grep the papers for the old reason before writing the new one.** The
old reason is prose, not an identifier, so it does not turn up in the
identifier sweeps [slug-the-ledgers](slug-the-ledgers.handoff.md) established.

## The second finding: a fourth recorded mechanism that was wrong

Continuing a run that is now five steps long.
[`infix-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost),
[reconcile-implementation-cost](reconcile-implementation-cost.handoff.md)'s
forward notes and [clang-slot-adl](clang-slot-adl.handoff.md) all say that
`Sema::CreateOverloadedUserOp` *"does its own `LookupOperatorName`"*. **It does
not.** `Sema::ActOnUserOperator` (`clang/lib/Sema/SemaExpr.cpp:6764`) performs
the lookup — deliberately, because it is the one part that needs a `Scope`, and
because `TreeTransform` re-uses the phase-1 result rather than looking the name
up again in a scope it has not got — and hands an `UnresolvedSet` to
`CreateOverloadedUserOp`, which turns it into an `UnresolvedLookupExpr` with
`PerformADL=true`.

**The conclusion is unchanged and slightly stronger**: the name is never
resolved to a `FunctionDecl` on the way in, which is why ADL is inherited. But
the sentence as recorded names the wrong function, and a reader who greps
`CreateOverloadedUserOp` for `LookupOperatorName` finds nothing and concludes
the claim is false. U§7 "Using" states the mechanism without naming either
function, so the doc cannot go stale this way.

---

## What changed

### `docs/unicode-operators.md` — U§7 "Declaring"

Was: one paragraph, "arity selects the form", one named departure from
[over.oper]. Now four movements.

1. **A five-row table of [over.oper]'s restrictions** and what happens to each:
   class-or-enum **waived**, no-default-arguments **waived**, not-variadic
   **waived**, the arity rule **inherited** and the only one with content, and
   not-a-static-member **kept, by choice**.
2. **The generalization as a rule**, which is sharper than the list:
   *[over.oper]'s restrictions protect a token whose parse, arity and fixity
   the grammar has already fixed; a user operator's grammar fixes only its
   arity, so arity is the only restriction it inherits.* Default arguments and
   variadic parameter lists then fall out as **allowed by derivation** — and
   the paragraph says outright that the prototype got there by *omission*, and
   that a waiver arrived at by omission is not a decision until it is written
   down.
3. **Arity and position as two independent claims** — declaration-arity,
   use-position — with the consequence stated rather than left implicit: a
   defaulted trailing parameter makes an **infix-declared operator usable in
   prefix position**, that is intended, filtering candidates by declared arity
   would break the equivalence the design rests on, and the ambiguity against a
   genuine prefix overload is the ordinary ambiguity of `f(int)` against
   `f(int, int = 1)`. The conservative alternative is named and priced at one
   diagnostic.
4. **The static-member paragraph**, which says the rejection is a guard and not
   a consequence, and points at the new decision entry for the reason.

### `docs/unicode-operators.md` — U§7 "Using"

One sentence became three bullets, each a claim an implementer can check:
**one candidate set ranked together** (measured both ways round);
**ADL inherited by not writing code** (the callee is a name the compiler forms,
never an expression the parser resolves, so the unresolved set reaches
overload resolution and ADL happens there); and **"no built-in candidates" as a
non-mechanism** — nothing assembles a built-in set, so there is nothing to
suppress. The site counts are *not* repeated: where size is the point the text
points at U§8, per
[reconcile-implementation-cost](reconcile-implementation-cost.handoff.md)'s
instruction that the count lives in one place.

### `docs/unicode-operators.md` — U§7 "Desugaring"

Two qualifications where there were none. **(a)** *"without modification"* is
softened: exact for a non-dependent use, and needing the node to survive a
dependent one, because a rebuilt ordinary call keeps ADL (a property of the
call) and loses member candidates (a property of the syntax). **(b)** The
wholesale citation of
[evaluation-order](../../../docs/backtick-operator-design.md#evaluation-order)
is gone, replaced by the two-case rule this feature actually has, then the
paragraph that matters: **the sequencing of `x ⊞ y` is determined by overload
resolution**, which no existing C++ operator does, and which is asked of CWG
rather than settled here. A closing paragraph says the callee-before-operands
sentence is **backtick-only** and must not be quoted for a Unicode operator —
a Unicode operator has no callee subexpression to sequence.

### `docs/unicode-operators.md` — U§7.1 and U§4

- The fourth point no longer says **"anywhere"**. It says *where* an
  unqualified-id does and enumerates the positions measured, and a new
  paragraph states the one exception with the accurate reason. **The forbidden
  clause was not written.**
- The first bullet of the *"conflict cannot arise in C++ today"* list now says
  the disjointness has been checked **at two Unicode versions**, that the
  second check is a unit test rather than an argument, and why the skew is the
  interesting configuration.
- **U§4** gains a paragraph — *"Two Unicode versions are in play at once"* —
  immediately before *"One more consequence of R3c"* and immediately after
  [evidence-debt](evidence-debt.handoff.md)'s reproducibility paragraph, which
  is untouched. It says the frozen list is frozen **by the proposal** while
  identifier tables ride Unicode's schedule, and that the separation is what
  makes the disjointness check stronger rather than weaker.

### `docs/unicode-operators.md` — §2, the decisions log

- **New entry [static-member-operators](../../../docs/unicode-operators.md#static-member-operators)**,
  in the full Question / Status / Decision / Why / Decided by / Log shape,
  sited between [unary-forms](../../../docs/unicode-operators.md#unary-forms)
  and [candidate-assembly](../../../docs/unicode-operators.md#candidate-assembly).
  It is the only *new document* the author's five answers required. No
  `Formerly:` field: it never had a number.
- [unary-forms](../../../docs/unicode-operators.md#unary-forms)'s **Why** is
  rewritten to split declaration-arity from use-position, and gains the plain
  sentence about what a postfix attempt produces. The postfix *pricing*
  sentences are untouched — they are U§13.1's material and
  [reconcile-remainder](../steps/reconcile-remainder.md)'s.
- [operator-function-id](../../../docs/unicode-operators.md#operator-function-id),
  [candidate-assembly](../../../docs/unicode-operators.md#candidate-assembly)
  (whose **Decision** now says the candidates are ranked as **one** set) and
  [operator-identifier-disjointness](../../../docs/unicode-operators.md#operator-identifier-disjointness)
  each gain a dated `Log.` entry. The last of these **strikes the false clause
  in place** in its own earlier `Log.` — struck, not deleted, so the record of
  what was believed survives without a reader being able to quote it as fact.

### `papers/unicode-mathematical-operators.md`

Two passages, both described above. Public text: **no internal identifier was
introduced**, and one pre-existing internal reference (`U§4`) was removed as a
side effect of rewriting the bullet it was in. Four `U§` cross-references
survive elsewhere in the paper and are [unicode-paper](../steps/unicode-paper.md)'s
to remove — see the forward notes.

### Ledgers and bookkeeping

Eight rows marked, the ledger header rewritten (**17 `RECONCILED` / 7 `OPEN`**,
the partly-closed list re-stated, and a new warning that three rows carried a
bad *mechanism* alongside the three that carried a bad *count*),
[`dependent-template-operator-id`](../../BACKLOG.md#dependent-template-operator-id)'s
`Closed by` filled in, and the plan's checklist, Coverage row and Status log.

---

## Verification evidence

**No build; no feature branch. Correct for this step** — the step file says so.

### The docs gate: every row names its destination section *and paragraph*

| Row | Destination |
|---|---|
| [`ucd-version-drift`](../../unicode-operators/clang/DEVIATIONS.md#ucd-version-drift) | U§4, the new paragraph beginning *"Two Unicode versions are in play at once"*; U§7.1, the first bullet of *"First, the conflict cannot arise in C++ today"* |
| [`disjointness-evidence`](../../unicode-operators/clang/DEVIATIONS.md#disjointness-evidence) | U§7.1, the same first bullet, the added sentences from *"It has been checked at two Unicode versions"* to the end of the bullet; framing in the U§4 paragraph above |
| [`over-oper-restrictions`](../../unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions) | U§7 "Declaring": the five-row restriction table, the rule paragraph after it, and the closing paragraph *"The one restriction kept is kept as a choice"*; §2's new [static-member-operators](../../../docs/unicode-operators.md#static-member-operators); a `Log.` on [operator-function-id](../../../docs/unicode-operators.md#operator-function-id) |
| [`operator-id-anywhere`](../../unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere) | U§7.1, the reworded fourth point and the new paragraph after it, *"One position is an exception, and it is worth stating rather than defending"*; U§7 "Using", the second bullet; a `Log.` on [operator-identifier-disjointness](../../../docs/unicode-operators.md#operator-identifier-disjointness) |
| [`infix-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost) | U§7 "Using", the second and third bullets — **part (2) only**; parts (1) (U§6) and (3) (U§13) are [reconcile-remainder](../steps/reconcile-remainder.md)'s and the row says so |
| [`prefix-arity-selection`](../../unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection) | [unary-forms](../../../docs/unicode-operators.md#unary-forms)'s **Why** (the split, and the postfix-attempt sentence); U§7 "Declaring", the two paragraphs beginning *"Arity and position are independent claims"* and *"The consequence of their independence"* — **the U§6 one-liner is left to [reconcile-remainder](../steps/reconcile-remainder.md)** and the row says so |
| [`operand-sequencing`](../../unicode-operators/clang/DEVIATIONS.md#operand-sequencing) | U§7 "Desugaring", the second qualification: the two bullets and the paragraph beginning *"So the sequencing of `x ⊞ y` is determined by overload resolution"*, plus the closing backtick-only paragraph. **Marked as recorded-as-an-open-CWG-question, which the row states in those words** |
| [`operator-candidate-assembly`](../../unicode-operators/clang/DEVIATIONS.md#operator-candidate-assembly) | U§7 "Using" bullets 1 and 3, and "Desugaring"'s first qualification; a `Log.` and a `Decision` change on [candidate-assembly](../../../docs/unicode-operators.md#candidate-assembly). Its `Status:` parenthetical is now **RECONCILED (both halves)** |
| [`dependent-template-operator-id`](../../BACKLOG.md#dependent-template-operator-id) | Its `Closed by` cell; U§7.1 as above; and the corrected paper paragraph |

**No row is marked closed that is not.** The Unicode ledger's other seven rows
are untouched and still `OPEN`; the backtick and GCC ledgers were not edited.

### The clause, as written, so it can be checked against the prohibition

U§7.1, the new paragraph after the fourth point, in full:

> **One position is an exception, and it is worth stating rather than
> defending.** As a *dependent* template name after the `template` keyword —
> `t.template operator⊞<int>(0)`, with `t` of dependent type — the
> operator-function-id is rejected. Every non-dependent spelling of the same
> thing works, including `T{}.operator⊞<int>(0)` and a dependent call without
> the disambiguator, and `t.template operator+<int>(0)` compiles, so the gap is
> narrow and specific. **It is this feature's own gap, not an inherited one.**
> Clang's storage for a dependent template name holds an identifier or a
> built-in operator kind and nothing else, and a user operator is neither: it
> is the same closure-over-a-fixed-operator-table cost as the name tables and
> candidate assembly (U§8), reaching a third data structure. Nothing about the
> design forces it — a third alternative in that storage would close it — but
> the qualifier costs a clause and removes the one sentence here an implementer
> can falsify.

`grep -rn "since C++11" docs/ papers/` now returns only
`docs/open-decisions.md` (twice, in the answer that *forbids* the clause) and
`docs/unicode-operators.md` once, inside the struck-through text of the
superseded `Log.` entry, immediately followed by *"struck: false, see the next
entry"*. **Neither paper contains it.**

### The decision entry, as written

> ### static-member-operators
>
> **Question.** May a user operator be declared as a **static** member function?
>
> **Status.** **Proposed**
>
> **Decision.** **No.** A user *operator function* is a non-member function or
> a non-static member function; a static member declaration of one is
> ill-formed.
>
> **Why.** Not because the arity rule excludes it — it does not. The rule
> counts *operands*, so `static S operator⊞(S, S)` has two of them and would be
> accepted; a compiler that implements this must reject it deliberately, and
> the prototype does, with an explicit guard ahead of the arity check reusing
> the existing "cannot be a static member function" diagnostic. The reason is
> the desugaring, which is the whole content of the feature: `x ⊞ y` is defined
> to mean exactly one of **two** spellings — `operator⊞(x, y)` or
> `x.operator⊞(y)` — and a static member names neither. `x.operator⊞(y)` on a
> static member is legal C++, but it discards the object expression and passes
> *one* argument to a two-parameter function, so it does not mean `⊞(x, y)`;
> and `S::operator⊞(x, y)` would be a third spelling reached by a
> class-directed lookup rule that nothing in candidate-assembly provides.
> Admitting static members would therefore not extend the equivalence, it would
> replace it. The C++23 `static operator()` / `static operator[]` precedent does
> not carry: those operators' meaning is given by the standard, which says how
> the object expression is treated, whereas a user operator's meaning is *only*
> the equivalence — there is no other place to say what a static form would do.
> Nothing is foreclosed: this is a restriction, and a later revision could lift
> it by writing down the third spelling and the lookup that finds it.
>
> **Decided by.** The design author, 2026-09-06 — over-oper-restrictions,
> option (a). …
>
> **Log.** 2026-09-06 — created by reconcile-declaring-using, which owed it. …

(Links elided in this quotation only; they are live in the file.)

### The measurements, re-derived rather than quoted

All on the pre-built `unicode-operators-upstream` binary,
`~/src/llvm/build-unicode-upstream/bin/clang++ -funicode-operators -std=c++23
-fsyntax-only`, worktree at `c0e07f78e679`, 2026-09-06. Nothing was rebuilt.

| Claim | How it was checked | Result |
|---|---|---|
| static member rejected | `struct S { static S operator⊞(S, S); };` | `error: overloaded 'operator⊞' cannot be a static member function` |
| …and rejected by a *guard*, not by arity | read `Sema::CheckUserOperatorDeclaration` (`clang/lib/Sema/SemaDeclCXX.cpp`) | `if (MD && MD->isStatic())` returns three lines *before* `NumOperands = NumDeclaredParams + (HasImplicitObjectParam ? 1 : 0)` |
| default-argument prefix use | `constexpr int operator⊟(int a, int b = 1) { return a * 7 + b; }` | `static_assert(⊟5 == 36)` **and** `static_assert((5 ⊟ 1) == 36)` both pass |
| …ambiguous against a real prefix overload | add `constexpr int operator⊠(int a)` beside `operator⊠(int, int = 1)` | `error: call to 'operator⊠' is ambiguous`, both candidates noted |
| variadic allowed | `int operator⊞(int, int, ...);` | accepted |
| arity diagnostic | `int operator⊗(int, int, int);` | `error: user-defined operator 'operator⊗' must have one parameter (prefix) or two parameters (infix) (has 3 parameters)` |
| postfix attempt | `return a⊖;` | `error: expected expression`, caret past the operator |
| dependent template-id rejected, non-dependent fine | `t.template operator⊞<int>(0)` vs `t.template operator+<int>(0)`, `T{}.operator⊞<int>(0)`, `t.operator⊞(0)` | only the first is rejected, with *'operator⊞' following the 'template' keyword cannot refer to a dependent template* |
| the storage that causes it | `clang/include/clang/AST/TemplateName.h:553`, `:599` | `struct IdentifierOrOverloadedOperator` with constructors from `const IdentifierInfo *` and `OverloadedOperatorKind`; `DependentTemplateStorage` holds one |
| one set ranked together | member `operator⊘(long) const`, non-member `operator⊘(MN, int)` | `MN{} ⊘ 0` → non-member, `MN{} ⊘ 0L` → member, both by `static_assert(__is_same(...))` |
| no built-in candidates | `int *p; int n; p ⊞ n;` | `error: use of undeclared 'operator⊞'`, not pointer arithmetic |
| …and no mechanism behind it | read `Sema::CreateOverloadedUserOp` | `AddNonMemberOperatorCandidates`, a six-line member loop, `AddArgumentDependentLookupCandidates`, and an explicit comment where `AddBuiltinOperatorCandidates` is *not* called |
| member sequences its left operand first | constant-evaluation probe with a marker per operand | member form yields `12`, i.e. left then right |
| `-Wunsequenced` triple | `arr[i++] ⊩ i++`, `objs[i++] ⊪ i++`, `objs[i++].operator⊪(i++)`, `arr[i++] << i++` | exactly one warning, on the **non-member** form |
| disjointness at 18.0 tables | `clang/lib/Lex/UnicodeCharSets.h` labels; `AllClangUnitTests --gtest_filter='*UnicodeOperatorCharSets*'` | tables say **Unicode 18.0**; **14/14 cases pass**, including `UserOperatorsAreNeverIdentifierChars` and `TightestGapAgainstMathIdentifiers` |
| the frozen set's own version | `clang/lib/Lex/UnicodeOperatorCharSets.h` header comment | UCD **17.0.0**, 1,381 code points |

**Nothing in U§7 quotes a site count**, so
[reconcile-implementation-cost](reconcile-implementation-cost.handoff.md)'s
figures were not restated and cannot go stale here; where size is the point,
the text points at U§8.

### Links

**2035 local Markdown links** across every tracked `.md` outside
`papers/wg21/`, **0 broken** — file existence and GitHub-style anchor slugs,
whitespace runs not collapsed, with links inside inline code spans and fenced
blocks excluded (which is why this count does not report the three
placeholder-example "breaks" earlier handoffs describe). The new
`#static-member-operators` anchor resolves from all five places that link to it.

---

## Deviations from the step file

1. **`papers/unicode-mathematical-operators.md` was edited, which the step file does not mention.**
   The step's own material was already in the paper in falsified form; see the
   first section. The edit is confined to the two passages the author's answers
   contradict, cites no internal identifier, and leaves the rest of the paper
   to [unicode-paper](../steps/unicode-paper.md).
2. **The U§6 additions two of my rows recommend were not written.**
   [`prefix-arity-selection`](../../unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection)
   asks for a structural one-liner after U§6's production and
   [`infix-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost)
   asks for the *"parsing is the easy part"* rewrite. Both belong to a
   paragraph [reconcile-remainder](../steps/reconcile-remainder.md) is
   rewriting, my step file hands that sentence over explicitly, and two steps
   editing one paragraph is how a sentence gets lost. Both rows are marked
   partly closed and name what is left.
3. **An eighth row was closed.** The step file lists seven;
   [reconcile-implementation-cost](reconcile-implementation-cost.handoff.md)'s
   forward notes assign the U§7 half of
   [`operator-candidate-assembly`](../../unicode-operators/clang/DEVIATIONS.md#operator-candidate-assembly)
   here as well, and leaving `**RECONCILED (U§8 half)**` standing after that
   half landed would have been worse than leaving it open.
4. **The `CheckUserOperatorDeclaration` comment on the two Unicode branches
   still gives the abandoned reason.** Unchanged here, deliberately: it is a
   code edit on two feature branches and this step touches no branch. It is
   still owned by nobody and `M2` is still the first step that will be in that
   file.

---

## Discoveries affecting later steps

- **`~/src/llvm/build-unicode-upstream` has a current `clang++` and a current
  `AllClangUnitTests`**, so a Unicode behavioural question costs one
  `-fsyntax-only` invocation and no build. `AllClangUnitTests` is the single
  binary — there is no `LexTests` target — and
  `--gtest_filter='*UnicodeOperatorCharSets*'` runs the disjointness sweep in
  under a second. This is much cheaper than the ledger prose implies and no
  later step should treat a Unicode claim as expensive to re-check.
- **A `static_assert` on `__is_same(decltype(...), Tag)` is the cheapest way to
  observe *which* overload won**, and it is what makes the one-candidate-set
  claim checkable at all; a compiles/does-not test cannot see it. Same shape as
  [clang-slot-adl](clang-slot-adl.handoff.md)'s tag-typed ADL sections, arrived
  at independently.
- **The design doc's `Log.` entries are now load-bearing prose, not
  bookkeeping.** Three of them carried claims that later turned out false. When
  correcting one, strike the clause in place rather than deleting it — a
  deleted false claim leaves the papers looking unexplained, and a silently
  edited one destroys the record of what was believed.
- **`docs/open-decisions.md`'s "Where each answer was recorded" table is the
  fastest way into this material** and it is accurate; it was checked against
  every destination it names while writing this step.

---

## Forward notes for the NEXT step — [reconcile-remainder](../steps/reconcile-remainder.md)

Written after reading its step file.

- **Your Group 2 sentence is now contested from four directions and three of
  the four are written up.** U§8's opening paragraph has
  [reconcile-implementation-cost](reconcile-implementation-cost.handoff.md)'s
  half; U§7 "Using" and "Declaring" now have mine. What is *not* written, and
  is yours, is the U§6 paragraph itself plus the **structural one-liner**
  [`prefix-arity-selection`](../../unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection)
  asks for: the prefix production is read in operand position by
  `ParseCastExpression` and the infix production in operator position by
  `ParseRHSOfBinaryExpression`, two functions that never see the same token, so
  **no disambiguation state exists** — the contrast being §5's same-delimiter
  suppression flag, which backtick needs and this feature does not. That row
  and [`infix-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost)
  are both marked partly closed and both name exactly what they are still owed;
  finish them by *appending* to their `Status:` line, not by rewriting mine.
- **Do not re-open U§7, U§7.1 or the sequencing question.** If Group 4's §17
  sentence about the back end wants a Unicode-side counterpart, link to U§7
  rather than restating it — the *"sequencing is determined by overload
  resolution"* paragraph is the one place that finding lives.
- **Your step-file item 3 is already done.** `CLAUDE.md`'s Layout section names
  `docs/unicode-operators.md` in its first bullet — [mangling-abi](mangling-abi.handoff.md)
  took the housekeeping item. Do not add a second bullet for it; check the
  section before assuming any of the standing housekeeping notes are still
  open.
- **Your gate says "zero unreconciled rows remain in any of the three
  ledgers", and one row will still be open after your eleven.**
  [`postfix-operators`](../../unicode-operators/clang/DEVIATIONS.md#postfix-operators)
  is `OPEN` with only its mangling clause taken; its clauses (1), (4) and (5)
  are U§13.1's, which is your section
  ([mangling-abi](mangling-abi.handoff.md) says so explicitly). Take it, or
  your gate cannot pass — and it is not in your step file's "Closes /
  reconciles" list, so nothing else will remind you.
- **U§13 has no fold entry and must gain one**
  ([`infix-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost)
  part (3), answered `fold-over-user-infix` (a)). It is an *addition*, not an
  amendment; [decision-brief](decision-brief.handoff.md)'s handoff has the
  measured cost of ever reversing it, and the standing silent guard is in the
  plan's Gate facts.
- **The Unicode ledger stands at 17 `RECONCILED` / 7 `OPEN`**, and the seven
  are exactly your six plus `postfix-operators`. Its header carries that count;
  update it when you land, as I updated it from ten.
- **No build, no branch** — same as this step, unless your Group 5 work needs
  the GCC tree, which [gcc-resync](gcc-resync.handoff.md) left settled.

---

## Open risks / TODOs

- **The papers have not been re-read end to end against the answered
  sections**, and this step found two false sentences in one of them by
  accident. [unicode-paper](../steps/unicode-paper.md) and
  [backtick-paper](../steps/backtick-paper.md) should budget a *reading*, not
  only a rewrite of the sections they touch.
- **`papers/unicode-mathematical-operators.md` still carries four `U§` cross-references** (to U§2
  twice, U§4 and U§7) — design-doc section numbers in public text, which a
  paper reader cannot resolve. Not introduced here, and one was removed here;
  the remaining four are [unicode-paper](../steps/unicode-paper.md)'s, and they
  are the same category of defect
  [slug-the-ledgers](slug-the-ledgers.handoff.md) cleaned up for slugs and
  numbers. `grep -n 'U§' papers/unicode-mathematical-operators.md` finds them.
- **`CheckUserOperatorDeclaration`'s comment still asserts the abandoned
  static-member reason** on both Unicode branches, and the design now
  contradicts it in a document a reviewer may read beside the code. Still
  unowned; `M2` is the first step that will be in that file.
- **Nothing is pushed.** This repo is ahead of every remote, as are the LLVM
  and GCC worktrees; unchanged by this step, which committed only here.
