# settle-paper-rows — the four rows the paper pass opened, and who owns each

**Goal.** [backtick-paper](backtick-paper.md) re-derived 57 implementation
claims against the built compilers, five failed, and the four rows it opened
have no owner: two in [`ops/DEVIATIONS.md`](../../DEVIATIONS.md) and two in
[`ops/gcc/DEVIATIONS.md`](../../gcc/DEVIATIONS.md). Settle each of them —
**fix it, reconcile it, or put it to the author with options and a price** —
so that the three ledgers again read zero unreconciled rows, or say exactly
whose answer they are waiting for.

**Depends on:** [backtick-paper](backtick-paper.md) ✔, which opened all four.
Nothing depends on this.
**Closes / reconciles:**
[`type-slot-aggregate-shape`](../../DEVIATIONS.md#type-slot-aggregate-shape),
[`escape-diagnostic-spelling`](../../gcc/DEVIATIONS.md#escape-diagnostic-spelling),
[`escape-name-positions`](../../DEVIATIONS.md#escape-name-positions),
[`escape-alias-name-parity`](../../gcc/DEVIATIONS.md#escape-alias-name-parity).
**Refs:** [clang-slot-adl](clang-slot-adl.md), the precedent for a step written
after the plan was, for a defect the plan could not have known about;
[clang-paper-truth](clang-paper-truth.md), which took the Clang half of the
printing question and found it was six sites and not one;
[decision-brief](decision-brief.md) and [mangling-abi](mangling-abi.md), the
worked shape of a step that ends by asking rather than by choosing.

## Why this is one step and not four

Three of the four are about the keyword escape and two of those are the same
question seen from two compilers, so splitting them would put the same
question in front of the author twice with half the evidence each time. The
fourth is a printer defect that shares nothing with them except its
provenance. One step, four verdicts.

**The verdicts are not interchangeable, and the ground rule decides which is
which.** *Decisions are the author's. A `Decide` step produces options, costs
and a recommendation. It does not choose.* So: where the design says a thing
and the implementation simply does not do it, fix the implementation. Where
the honest answer is that the design claimed more than it decided, write the
question up with prices and stop. A `BLOCKED` handoff on the author is the
correct end for that part.

## Do

### 1. [`type-slot-aggregate-shape`](../../DEVIATIONS.md#type-slot-aggregate-shape) — fix it

This one is a defect with an obvious fix and no question in it.
[§17.5](../../../docs/backtick-operator-design.md#175-source-ranges-of-the-desugared-node-source-fidelity-node)
says the wrapper spans the written expression and names three inner shapes;
there is a fourth. A type slot naming an **aggregate** initializes through
parenthesized aggregate initialization, so Sema builds a
`CXXFunctionalCastExpr` over a `CXXParenListInitExpr` and no arm of
`BacktickInfixExpr::getOperand` or `StmtPrinter::VisitBacktickInfixExpr`
recognises it.

- Add the arm in both places. Take the **user-specified** initializers: the
  full list carries defaulted members beyond the two operands.
- Print the type the way the constructor arm does — from the semantic node —
  so that one rule covers all four shapes and the CTAD exception the paper
  already states stays a single stated exception rather than becoming two
  different behaviours in adjacent arms.
- Test it in the files that already own these two claims, not in a new file:
  the range in `clang/test/Parser/backtick-infix.cpp` beside the other type
  slots, pinned as literal columns, and the printing in
  `clang/test/Parser/backtick-ast-print.cpp`, whose second RUN line re-parses
  what it printed. Parenthesized aggregate initialization is C++20, and
  neither file pins a `-std`.
- **Show the new cases failing on a pre-fix binary**, this track's standard of
  proof, and say what they printed instead.
- Land on `backtick-trunk`, then cherry-pick to `backtick-23` and gate it
  independently.

### 2. [`escape-diagnostic-spelling`](../../gcc/DEVIATIONS.md#escape-diagnostic-spelling) — fix it if the price is a printer arm

[keyword-escape-printing](../../../docs/backtick-operator-design.md#keyword-escape-printing)
is **ratified**: under the flag the escape is the only spelling the name has,
so a diagnostic naming the entity `new` names it with a spelling no program
can contain. Clang delivers it. GCC prints the bare keyword. The ruling is the
author's and it is already given; what is left is whether GCC can be brought
into line at a price worth paying, which is an implementer's question.

The escape yields the shared interned keyword `IDENTIFIER_NODE` and carries no
trace of how it was spelled, exactly as on the Clang side — but under
`-fbacktick` a *declaration* can only be named by a keyword if it was escaped,
because `grokdeclarator` rejects the bare form. That is the condition to
print on.

**The trap to expect is the one the Clang half already hit**: which printing
surfaces count. `-fbacktick` must not change what a program containing **no
backtick** diagnoses — that is what
[gcc-resync](gcc-resync.md)'s last commit fixed at the parser level, and the
same mistake is available one layer down in the printer. Check it the way
that commit's test does: a program with no backtick, flag on and flag off,
byte-identical.

If the surfaces cannot be separated for less than a rewrite, stop and write it
up as an option with its price instead.

### 3. [`escape-name-positions`](../../DEVIATIONS.md#escape-name-positions) — the author's

Neither compiler takes the escape in a *class-head-name*, *enum-name*,
*namespace-name* or template parameter name, and the paper's [lex.name]
wording admits all of them — its own example is `` struct `union` { }; ``.
Two things are owed and only the first is yours:

- **Yours:** [§12](../../../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers)'s
  position list must say that it is the *implemented* list and that the rest
  are unwritten parser arms rather than decisions — nothing in the
  disambiguation argument turns on them, since a *class-head-name* is a name
  position exactly as a declarator-id is.
- **The author's:** what should the escape's coverage *be*? An escape hatch
  whose purpose is that a future keyword stops breaking code has to reach the
  positions in which the broken code names things, and `struct module { };` is
  one of them.
  [keyword-escape-coexistence](../../../docs/backtick-operator-design.md#keyword-escape-coexistence)'s
  Status has said *scope open* since it was written.

Write it up in [`docs/open-decisions.md`](../../../docs/open-decisions.md) in
the shape already there — the question, what was measured, the options, the
cost of each, a recommendation — and **price the options by measurement, not
by estimate**. A price nobody measured is the thing this track keeps catching.

### 4. [`escape-alias-name-parity`](../../gcc/DEVIATIONS.md#escape-alias-name-parity) — with 3, unless it is separable

Clang accepts `` using `class` = int; `` and GCC rejects it. Do not fix this
one by reflex: §12's position list does **not** include the
alias-declaration's *identifier*, so Clang's acceptance is as much beyond the
decided set as GCC's rejection is behind it, and which way the two should be
brought together is part of question 3 and not independent of it. Establish
which of the two compilers is doing the undecided thing, price the fix in
whichever direction, and hand it to the author with 3.

### 5. The documents

- Mark every row you settle in its ledger, **naming the destination section
  and paragraph**. A row the author now owns stays `OPEN` with a dated note
  saying so — deciding is not reconciling and neither is asking.
- [§17.5](../../../docs/backtick-operator-design.md#175-source-ranges-of-the-desugared-node-source-fidelity-node)
  and [§17.3](../../../docs/backtick-operator-design.md#173-type-name-in-the-operator-slot-type-name-slot)
  carry the shape count and the printer-arm count; both are wrong by one.
- [§17.8](../../../docs/backtick-operator-design.md#178-which-of-this-is-clangs-alone-and-why)
  says how many places the two compilers accept different programs and keeps
  the diagnostic-spelling divergence separate from that count. Both halves
  move if 2 or 4 lands.
- **The papers.** `papers/backtick-infix-and-keyword-escape.md` states the
  round-trip exceptions, the list of programs the two compilers treat
  differently, and that GCC prints the bare keyword. Every one of those
  sentences is downstream of a verdict here. Fix what changes, **with no
  internal identifier in it**, and re-check that both formats still build with
  no missing characters — a missing glyph is a warning and the build still
  exits 0.

## Verify (gate)

- **Clang:** the two new test cases fail on a pre-fix binary and pass after;
  `check-clang` green on **both** backtick branches against the Baselines in
  [`ops/completion/PLAN.md`](../PLAN.md), with a Status-log row each. Adding
  cases to existing lit files moves no count; say so, or state the delta.
- **GCC:** `dg.exp=g++.dg/backtick/*.C` green — 103 passes and 0 failures
  before this step; state the delta, because pinning a diagnostic adds
  directives and each directive is a test.
- **Flag-off parity, measured, not assumed:** a program that contains no
  backtick diagnoses byte-identically with the flag on and off, on whichever
  compiler this step touched.
- **Every one of the four rows has a verdict in its ledger** — `FIXED` /
  `RECONCILED` with a named destination paragraph, or `OPEN` with a dated note
  naming the question the author owes and where the brief is.
- If any part of this is put to the author, the handoff's Status is
  **BLOCKED** and the plan's box stays unchecked. That is the successful
  outcome for that part, not a failure of it.
