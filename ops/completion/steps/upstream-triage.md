# upstream-triage — Triage the upstream annoyances: `B24`, `B27`–`B30`

**Goal.** Five rows that have sat as "upstream's problem, probably" get a
decision each: **report**, or **WONTFIX with the reason recorded**. Either
closes the row. An untriaged row is the thing this step exists to remove.

**Depends on:** nothing. Independent of every other step; good work for a
spare agent.
**Closes:** `B24`, `B27`, `B28`, `B29`, `B30`.

## The five, and what each already knows

- **`B24` — the inner `CallExpr`'s source range begins at the operator.**
  The row **asks for this re-triage by name.** It was listed as cheap, and it
  is not: `CallExpr::getBeginLoc` takes the begin from the callee and trunk
  *caches* it in a trailing `SourceLocation`
  (`CallExprBits.HasTrailingSourceLoc`, written by `updateTrailingSourceLoc()`
  from `CallExpr::Create`) with no public setter. Fixing it needs an
  upstream-shaped `CallExpr::Create` overload. **The recommendation to weigh
  is WONTFIX**, on the grounds the row itself offers: the node *as written*
  (`UserOperatorExpr`, `BacktickInfixExpr`) spans correctly, and a semantic
  form carrying the callee's range is what `-ast-dump` does for every
  desugaring in the language. If you agree, say so in the row and in the
  design docs — it is a defensible position, not a dodge, and the papers
  should state it rather than leave a reader to notice.
- **`B27` — `llvm-cxxfilt`'s stdin path splits on non-ASCII.** `_Z3∂i` piped
  in is not demangled; the same string as an argv argument is. Affects
  extended-identifier function names, **not** this feature's operator names,
  which are ASCII-derived by construction. A clean small upstream report.
- **`B28` — `-ast-print` cannot round-trip an `auto`-returning function
  template.** Pre-existing, and it costs five minutes to everyone who writes a
  round-trip test — evidence-debt has to work around it. Report.
- **`B29` — `-ast-print` after a PCH prints a class's fields last** if they
  precede its methods. Pre-existing; breaks any naive PCH print-diff test.
  Report, and note that U17's round-trip test had to be written around it.
- **`B30` — the caret for `use of undeclared 'operator⊞'` underlines only the
  `operator` keyword**, not the glyph. **Upstream's shape, not a regression:**
  `operator+` and `operator""_x` produce the identical 8-column range. Weigh
  WONTFIX; if reported, report it as the general case, not as a Unicode one.

## Do

1. For each row, decide report-or-WONTFIX and **write the reason in the row's
   `Closed by` cell**, not only in the handoff. A WONTFIX with a reason is a
   closed row; a WONTFIX without one is the same open row with a new label.
2. File the ones you decided to report. Search first; several of these are
   old enough to already exist.
3. For `B24` and `B30`, if the decision is WONTFIX, add one sentence to the
   affected design doc — `docs/backtick-operator-design.md` §17 for `B24`'s
   backtick half, `docs/unicode-operators.md` for the Unicode half and `B30` —
   so the papers can answer the question rather than be asked it.

## Verify (gate)

- No `check-clang`; nothing committed to a feature branch.
- All five rows have a non-empty `Closed by` cell.
- Every "report" has a URL; every "WONTFIX" has a reason a reader who has not
  read this plan would accept.
