# clang-paper-truth — The three Clang defects that falsify a paper claim

**Goal.** Three defects on the backtick branches where the implementation does
not do what a document says. `BL06` had them in a batch with two hygiene items
because they share a branch; this step takes the three that change what a
paper can claim and leaves [`dead-nesting-diagnostic`](../../BACKLOG.md#dead-nesting-diagnostic)/[`libclang-cursor-arm`](../../BACKLOG.md#libclang-cursor-arm) to hygiene-parity.

**Depends on:** decision-brief — only so that a decision does not land on top of this
work. If decision-brief is blocked on the author, this step may run anyway; say so.
**Closes:** [`c-mode-tokenization`](../../BACKLOG.md#c-mode-tokenization), [`keyword-escape-round-trip`](../../BACKLOG.md#keyword-escape-round-trip), [`backtick-source-range`](../../BACKLOG.md#backtick-source-range).
**Refs:** `ops/backlog/steps/BL06-backtick-batch.md` — its [`c-mode-tokenization`](../../BACKLOG.md#c-mode-tokenization), [`backtick-source-range`](../../BACKLOG.md#backtick-source-range) and
[`keyword-escape-round-trip`](../../BACKLOG.md#keyword-escape-round-trip) material is good and this step does not restate it; read it.

## The three

### [`c-mode-tokenization`](../../BACKLOG.md#c-mode-tokenization) — `-fbacktick` lacks `ShouldParseIf<cplusplus.KeyPath>` (P2, worst symptom in the file)

The flag changes **C-mode tokenization** for a grammar that is C++-only, and
the re-grade found the symptom is worse than [`flag-language-mode`](../../unicode-operators/clang/DEVIATIONS.md#flag-language-mode) recorded: C does not
merely lose a diagnostic, it **accepts** the grammar —
`int f(int a,int b){ return a `g` b; }` compiled as C with `-fbacktick` exits
0. The Unicode branch already carries the paired one-line fix for both flags;
the backtick track owes itself the `defm backtick` half.

Add a C-mode test that asserts the *rejection*, not just the diagnostic — the
defect is acceptance, so a test that only checks a warning text would still
pass with the bug present.

### [`keyword-escape-round-trip`](../../BACKLOG.md#keyword-escape-round-trip) — the keyword escape does not round-trip through `-ast-print` (P2)

`` void `new`(); `` prints as `void new();`, which does not re-parse. Note
carefully what the row says: this is a **different node** from the infix
wrapper and a **different defect** from the one F23/F24 fixed, and
`backtick-escape.cpp` never runs `-ast-print`, which is why nine steps missed
it. The site is `DeclarationName::print`'s `Identifier` arm
(`clang/lib/AST/DeclarationName.cpp:131-148`) — **which is also the diagnostic
path.** So this needs a `PrintingPolicy` bit *and* a decision about diagnostic
wording; it is not a guard. Do not make every diagnostic that names a
keyword-escaped entity start printing backticks without deciding that
deliberately and writing the decision down.

### [`backtick-source-range`](../../BACKLOG.md#backtick-source-range) — `BacktickInfixExpr`'s source range does not span its operands (P2)

It is `<col:22, col:23>`, just the callee. Cheap now that `getCallExpr()`
exists. **Model the fix on `UserOperatorExpr::getBeginLoc`**
(`ExprCXX.h:471-491`), whose doc comment diagnoses the identical root cause —
the Unicode side already solved this and the backtick side should look
identical, because a reader comparing the two features will compare exactly
this.

Do **not** be drawn into [`inner-call-source-range`](../../BACKLOG.md#inner-call-source-range) here: the *inner* `CallExpr`'s range is a
separate, non-cheap problem that upstream-triage triages.

## Do

1. Fix all three on `backtick-trunk`, with tests.
2. Verify the gate there.
3. Cherry-pick to `backtick-23` and **re-verify the gate independently** — a
   clean pick is not proof (the clang-format trap in
   `ops/handoffs/13-rebase-release-23x.handoff.md`).
4. Fill three `Closed by` cells.

## Verify (gate)

- `check-clang` green on both branches against the baselines in
  `ops/completion/PLAN.md`; `backtick-23`'s single [`stray-clang-format-config`](../../BACKLOG.md#stray-clang-format-config) failure is expected
  and nothing else is.
- The C-mode test fails without the [`c-mode-tokenization`](../../BACKLOG.md#c-mode-tokenization) fix. Demonstrate that, do not assume
  it — `BL03` set the standard here by reverting each arm in turn.
- `-ast-print` round-trips `` void `new`(); `` back to itself, and the
  diagnostic-wording decision is written down somewhere a paper can cite.

## After this step

**M2 becomes runnable**: it forward-ports `BL02` and this step's fixes to
`unicode-operators-experiment`. See
`ops/unicode-operators/clang/PLAN.md` Phase G, which explains why M2's job is
smaller than its own description.
