# U19 — Replay-ledger audit

**Goal.** Turn `REPLAY.md`'s per-step rows into a single verdict: exactly
what the upstream Unicode patch stack contains, and exactly what it must do
about backtick. No compiler changes.

**Depends on:** U14, U15, U17, U18.
**Design refs:** `ops/unicode-operators/clang-experiment-plan.md`
("Upstream Replay Assumptions"); U7 (independent flags); U12 (separate
paper — the replay must not make the two features share a fate).

## Do
1. Read every `REPLAY.md` row and reconcile it against the actual diff:
   ```bash
   git -C ~/src/llvm/unicode diff backtick-trunk..unicode-operators-experiment --stat
   ```
   A file in the diff with no ledger row is a gap — close it now, while the
   agent who wrote it is still findable via the handoffs.
2. Classify every hunk, not every file:
   - `upstream replay` — lift as-is onto clean `main`;
   - `backtick dependency` — exists only because the backtick diff is
     present; needs a standalone equivalent written for `main`;
   - `shared if landed` — reusable only if backtick lands first.
3. For each `backtick dependency` and `shared if landed` item, write the
   standalone equivalent as a concrete instruction, not a note: which
   symbol to introduce on `main`, under which name. The user-infix
   `prec::Level` is the obvious one — on clean `main` it must be introduced
   *by this patch stack*, named `UserInfix`, with the Unicode feature as
   its sole initial client.
4. Order the upstream stack into landable commits — flag, tables, lexer,
   UCN, diagnostics, DeclarationName, operator-function-id, decl rules,
   mangling, parse, Sema, AST, serialization, format, tests — and note
   which could plausibly go up as independent PRs.
5. Split the test files U15 marked as mixed: pure-Unicode cases for the
   upstream stack, mixed-chain cases held back for the experiment branch.
6. Record the ABI-open item from U09 separately: it is the one thing that
   is not a replay question but a cross-vendor question.

## Verify (gate)
- Every file in the experiment diff appears in the audit with a
  classification.
- The proposed upstream stack, read as a list, contains no item that
  mentions backtick.
- No compiler change, so no `check-clang` requirement — but state the
  branch's current gate status so U20 has a "before" number.

## Done when
`REPLAY.md` carries a final section: the ordered upstream commit list, the
standalone-equivalent instructions, and the held-back items.

## Capture in handoff
The count of hunks in each category. That ratio is itself a paper result —
it measures how much of this feature was genuinely inherited from the
backtick work versus independent.

## REPLAY ledger
This step *is* the ledger.
