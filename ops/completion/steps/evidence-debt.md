# evidence-debt — Discharge the evidence debt: the unbuilt hunk, the unwritten test, the unregenerable table

**Goal.** Four places where the prototype claims, or is about to claim, that
something was checked and it was not. This step supersedes
`ops/backlog/steps/BL07-unicode-batch.md`, which covered the first three;
read that file, it is good, and this one adds [`template-ast-print-test`](../../BACKLOG.md#template-ast-print-test) and the reason they belong
together.

**Depends on:** nothing.
**Closes:** [`lldb-hunk-verification`](../../BACKLOG.md#lldb-hunk-verification), [`code-completion-priority`](../../BACKLOG.md#code-completion-priority), [`ucd-input-manifest`](../../BACKLOG.md#ucd-input-manifest), [`template-ast-print-test`](../../BACKLOG.md#template-ast-print-test).
**Refs:** `ops/backlog/steps/BL07-unicode-batch.md`; `U06`, `U07`, `U08`,
`U09`, `U11`, `U16`, `U17` handoffs.

## Why these four are one step

Not because they share a branch — [`template-ast-print-test`](../../BACKLOG.md#template-ast-print-test) is on the backtick side — but because
they are the same *kind* of claim. Each is a sentence a paper wants to be able
to say: *the implementation compiles*, *the feature is usable in the editor*,
*the tables are reproducible*, *the round trip works in a template*. None is
currently earned.

## The four

### [`lldb-hunk-verification`](../../BACKLOG.md#lldb-hunk-verification) — the lldb hunk is compile-unverified (P2)

**The only hunk in the whole feature that no compiler has seen.** One line in
`ClangASTSource.cpp:125`; lldb is not in any of these builds' projects. The
prerequisites are on this machine, and **building
`lldbPluginExpressionParserClang` alone compiles the TU without linking
lldb** — that is the cheap path, use it.

`~/src/llvm/build-cir-scratch` is standing from BL04. **Add `lldb` to that
configure and rebuild** rather than creating a second scratch tree; BL04's
handoff says so explicitly and it is much cheaper than a fresh MLIR build.

### [`code-completion-priority`](../../BACKLOG.md#code-completion-priority) — code-completion priority grouping never updated (P2)

`SemaCodeComplete.cpp:1061`. Left alone by `U06`, `U07`, `U08`, `U09`, `U11`
and `U16` **in turn** — six steps, which is the argument. Completion after an
infix user operator is a reachable state.

The row already solved the hard part: the reason it kept being deferred is
that priorities are not printed — **but results *are* priority-sorted**
(`CodeCompleteConsumer.cpp:645`), so an ordering-based test is the observable.
Write that test.

### [`ucd-input-manifest`](../../BACKLOG.md#ucd-input-manifest) — the UCD 17.0.0 inputs are in neither repo (P3, but reproducibility)

The generated character tables cannot be regenerated without re-fetching five
files. **A hash manifest in `docs/` is the cheap fix, and the paper's
reproducibility claim wants one.**

This is the **only item in the plan with an external dependency** — it needs
network access to unicode.org. Do it while the network works; a paper that
claims a frozen, derived token set and cannot rebuild it is making a claim it
cannot honour. Do **not** re-run the generator against a newer UCD to
"refresh" anything: [token-set](../../../docs/unicode-operators.md#token-set) is frozen at 17.0.0 by design, and the manifest exists
to prove the frozen bytes are the ones published.

### [`template-ast-print-test`](../../BACKLOG.md#template-ast-print-test) — no `-ast-print` test covers a backtick expression in a template context (P3)

So `TransformBacktickInfixExpr` is unexercised for round-trip. **Watch [`auto-return-round-trip`](../../BACKLOG.md#auto-return-round-trip)**
— write an explicit return type, not `auto`, because `-ast-print` cannot
round-trip an `auto`-returning function template and you will spend the
afternoon on upstream's bug instead of yours. (upstream-triage reports [`auto-return-round-trip`](../../BACKLOG.md#auto-return-round-trip); this step
just avoids it.)

## Do

1. [`lldb-hunk-verification`](../../BACKLOG.md#lldb-hunk-verification) first — it needs the build reconfigure, so start it and do the others
   while it builds.
2. [`ucd-input-manifest`](../../BACKLOG.md#ucd-input-manifest) next if the network is up; it is the one that can become impossible.
3. [`code-completion-priority`](../../BACKLOG.md#code-completion-priority) and [`template-ast-print-test`](../../BACKLOG.md#template-ast-print-test) are ordinary test work.
4. Four `Closed by` cells; a `REPLAY.md` row for the Unicode-side items.

## Verify (gate)

- The lldb TU **compiles**, and the handoff says with what command and in
  which build dir.
- The completion test asserts an **ordering**, and fails if the grouping is
  reverted.
- The manifest's hashes verify against freshly fetched files, and the
  regenerated tables are **byte-identical** to the ones in tree. If they are
  not, that is a finding, not a fix — stop and report it.
- `check-clang` green on every branch touched.
