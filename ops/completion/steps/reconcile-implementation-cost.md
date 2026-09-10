# reconcile-implementation-cost — Reconcile U§8: the implementation-cost thesis

**Goal.** Eight deviation rows land in one section, and together they are the
**strongest single piece of evidence the whole prototype produced**. U§8 is
currently an "implementation sketch" with three Clang bullets. What was
measured is a much larger and much more interesting claim, and no paper says
it yet.

**Depends on:** evidence-debt — the evidence debt is discharged first, so this section
does not cite a measurement that is still owed.
**Closes / reconciles:** [`declaration-name-plumbing`](../../unicode-operators/clang/DEVIATIONS.md#declaration-name-plumbing), [`declaring-side-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#declaring-side-parse-cost), [`flag-language-mode`](../../unicode-operators/clang/DEVIATIONS.md#flag-language-mode), [`operator-candidate-assembly`](../../unicode-operators/clang/DEVIATIONS.md#operator-candidate-assembly),
[`expression-node-cost`](../../unicode-operators/clang/DEVIATIONS.md#expression-node-cost), [`serialization-tooling-cost`](../../unicode-operators/clang/DEVIATIONS.md#serialization-tooling-cost), [`ast-node-shape`](../../unicode-operators/clang/DEVIATIONS.md#ast-node-shape), [`codegen-dispatch-sites`](../../unicode-operators/clang/DEVIATIONS.md#codegen-dispatch-sites). Records [`matcher-operator-name`](../../BACKLOG.md#matcher-operator-name) as evidence.
**Refs:** `docs/unicode-operators.md` §8; those eight rows in
`ops/unicode-operators/clang/DEVIATIONS.md`, which are long and should be read
in full before writing a word.

## The thesis, as measured

The rows tell one story in three numbers and one pattern:

1. **[`declaration-name-plumbing`](../../unicode-operators/clang/DEVIATIONS.md#declaration-name-plumbing) — 33 sites over `DeclarationName::NameKind`.** Opening the name
   tables.
2. **[`expression-node-cost`](../../unicode-operators/clang/DEVIATIONS.md#expression-node-cost) — 28 dispatch sites over `Stmt::StmtClass` in 20 files**, on a
   *different* axis, sharing no entry with the first list. And the taxonomy is
   the finding, not the number: **6** forced by a link error, **8** by an
   exhaustive `switch` ending in `llvm_unreachable`, **1** found only by
   reading a `-Wswitch` warning on a `WERROR=OFF` build, and **13** forced by
   nothing at all and silently wrong if omitted.
3. **[`serialization-tooling-cost`](../../unicode-operators/clang/DEVIATIONS.md#serialization-tooling-cost)** raised the `-Wswitch` category to 2 and confirmed both lists
   complete — and found the residue is tiny but silent-when-wrong (the
   `DeclarationNameKey` group: five sites, one decision, module lookup *misses
   silently* if they disagree).
4. **[`codegen-dispatch-sites`](../../unicode-operators/clang/DEVIATIONS.md#codegen-dispatch-sites) (BL04) moves it to 32 sites in 21 files and adds a fourth
   category** the taxonomy did not have: sites forced by nothing at compile
   time that fail loudly the first time anyone builds the configuration they
   live in. What hid ClangIR's four was a CMake default, not a design.
5. **The three-for-three sibling pattern** ([`expression-node-cost`](../../unicode-operators/clang/DEVIATIONS.md#expression-node-cost)(a)): `CheckUserOperator
   Declaration` beside `CheckOverloadedOperatorDeclaration`,
   `CreateOverloadedUserOp` beside `CreateOverloadedBinOp`, `UserOperatorExpr`
   beside `CXXOperatorCallExpr`. **[`serialization-tooling-cost`](../../unicode-operators/clang/DEVIATIONS.md#serialization-tooling-cost) found the fourth instance, and it
   is the first where the right answer is a refusal rather than a sibling** —
   `hasAnyOperatorName()` is keyed on a static spelling table and a user
   operator's spelling is computed. That is [`matcher-operator-name`](../../BACKLOG.md#matcher-operator-name).
6. **[`operator-candidate-assembly`](../../unicode-operators/clang/DEVIATIONS.md#operator-candidate-assembly) / [`expression-node-cost`](../../unicode-operators/clang/DEVIATIONS.md#expression-node-cost)(b) — the node cannot be transparent**, and the
   reason is a *language* consequence, not an implementation cost: a
   transparent wrapper rebuilds as an ordinary call at instantiation,
   `[over.match.call]` rather than `[over.match.oper]`, ADL survives and
   member candidates are lost. **This is the one place the Unicode feature is
   more work than backtick**, and the reason is that a user operator has
   member candidates and a backtick slot does not.
7. **[`ast-node-shape`](../../unicode-operators/clang/DEVIATIONS.md#ast-node-shape)** — the AST-node shape, and U§12's "one level, banked once for
   both features".
8. **[`declaring-side-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#declaring-side-parse-cost), [`flag-language-mode`](../../unicode-operators/clang/DEVIATIONS.md#flag-language-mode)** — the parser and flag story, including U§6's
   "parsing is the *easy* part" claim, which reconcile-remainder also touches (see below).

## The sentence three rows disagree with

[`declaring-side-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#declaring-side-parse-cost), [`infix-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost), [`expression-node-cost`](../../unicode-operators/clang/DEVIATIONS.md#expression-node-cost) and [`prefix-arity-selection`](../../unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection) all name the same claim in U§6:
**"parsing is the *easy* part of this feature, easier even than backtick."**
Four independent measurements pushed back on one sentence. **reconcile-remainder owns U§6**;
this step must not rewrite it, but it should hand reconcile-remainder the U§8-side evidence
and say so in the handoff. A sentence contradicted four times is worth a
paragraph in the paper, not a quiet edit.

## Do

1. Rewrite U§8's Clang bullet list to the **five** items the rows establish —
   Lexer, Parser, `DeclarationName`, **the expression node**, and
   **serialization/modules/tooling** — with the fourth and fifth being what
   [`operator-candidate-assembly`](../../unicode-operators/clang/DEVIATIONS.md#operator-candidate-assembly)/`U13` and [`serialization-tooling-cost`](../../unicode-operators/clang/DEVIATIONS.md#serialization-tooling-cost) asked for and nobody has written.
2. Add the code generator to it, per [`codegen-dispatch-sites`](../../unicode-operators/clang/DEVIATIONS.md#codegen-dispatch-sites).
3. State the numbers as *32 sites over `StmtClass` in 21 files* and *33 over
   `NameKind`*, with the four-category taxonomy, and say the quiet part:
   **the toolchain forces about half of a new node's obligations, warns about
   two, is silent about thirteen, and hides four behind a build configuration
   nobody had turned on.**
4. Record the sibling pattern as a portable finding, with [`matcher-operator-name`](../../BACKLOG.md#matcher-operator-name) as its fourth
   instance and first refusal: every place C++ keys operator behaviour off a
   closed kind, opening it costs a *parallel* implementation, never a widened
   one — **which is why the relaxation provably cannot leak into `operator+`.**
5. Add [`codegen-dispatch-sites`](../../unicode-operators/clang/DEVIATIONS.md#codegen-dispatch-sites)(c): every shape emits CIR instruction-for-instruction
   identical to the explicit call. The desugaring thesis, cashed at the last
   place it could have failed.
6. Mark all eight rows `**RECONCILED**`, naming the paragraph each landed in.
   Close [`matcher-operator-name`](../../BACKLOG.md#matcher-operator-name) as *designed, and cited as evidence*.

## Verify (gate)

- No build; no feature branch.
- All eight rows carry `**RECONCILED**` and a paragraph reference. This is the
  gate — a reconciliation that cannot say where it went did not happen.
- U§8 states a number for each axis, and the numbers match the rows.
- The handoff tells reconcile-remainder exactly what U§6's sentence has to answer for.
