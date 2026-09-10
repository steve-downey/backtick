# hygiene-parity — The tooling-parity gaps, the dead code, the formatting limit

**Goal.** Six rows with no paper consequence. They are last on purpose — none
of them changes what either paper can claim — but they are not optional,
because two of them are *parity* gaps: a reader comparing the two features
will find the Unicode side supported in tooling and the backtick side not, and
that asymmetry is an artifact of the order the work happened in, not a design
statement.

**Depends on:** clang-paper-truth, so this does not collide with it on the same two
branches.
**Closes:** [`backtick-ast-matchers`](../../BACKLOG.md#backtick-ast-matchers), [`dead-nesting-diagnostic`](../../BACKLOG.md#dead-nesting-diagnostic), [`slot-split-penalty`](../../BACKLOG.md#slot-split-penalty), [`libclang-cursor-arm`](../../BACKLOG.md#libclang-cursor-arm); records [`template-id-code-point`](../../BACKLOG.md#template-id-code-point). ([`confusable-spellings`](../../BACKLOG.md#confusable-spellings) is closed by
reconcile-remainder, where its decision belongs.)
**Refs:** `ops/backlog/steps/BL06-backtick-batch.md` for [`dead-nesting-diagnostic`](../../BACKLOG.md#dead-nesting-diagnostic) and [`libclang-cursor-arm`](../../BACKLOG.md#libclang-cursor-arm);
`U17`'s handoff for the [`backtick-ast-matchers`](../../BACKLOG.md#backtick-ast-matchers) sizing.

## The four to fix

### [`backtick-ast-matchers`](../../BACKLOG.md#backtick-ast-matchers) — ASTMatchers and clang-tidy do not know `BacktickInfixExpr` (P2)

**The same gap `U17` closed for `UserOperatorExpr` on the Unicode side.**
Sized from that step: ~5 production/docs files at +58 lines plus +59 of test.
`clang-tidy` itself needs nothing.

**The trap, from `U17`:** `clang/docs/LibASTMatchersReference.html` is
**generated** and gated by `clang/test/AST/ast_matchers_updated.test` — adding
a matcher without regenerating it fails the gate. Regenerate it; do not
hand-edit it.

### [`libclang-cursor-arm`](../../BACKLOG.md#libclang-cursor-arm) — libclang does not know `BacktickInfixExpr` (P3)

`clang/tools/libclang/CXCursor.cpp`'s exhaustive `MakeCXCursor` switch has no
arm, so **a `-Wswitch` warning is live right now** on this `WERROR=OFF` build
and libclang maps a backtick expression to `CXCursor_NotImplemented`. F24
closed the sibling gap in `ExprEngine.cpp`; `U17` closed the Unicode half and
left this one. **One line next to `CXXRewrittenBinaryOperatorClass`.**

Worth noting in the handoff: this is [`expression-node-cost`](../../unicode-operators/clang/DEVIATIONS.md#expression-node-cost)'s "found only by reading the
build log" category, still unfixed months later, which is a small piece of
evidence for that taxonomy's point.

### [`dead-nesting-diagnostic`](../../BACKLOG.md#dead-nesting-diagnostic) — `err_backtick_nested_requires_parens` is dead code (P3)

Carried since `S04` and **never fired**. Remove it. [`bare-nesting-detection`](../../DEVIATIONS.md#bare-nesting-detection) is RESOLVED in
the other direction — §17.1: bare nesting is blessed [chaining-associativity](../../../docs/backtick-operator-design.md#chaining-associativity) chaining and *cannot*
be diagnosed — so the diagnostic is unfireable **as specified**.

**Do not implement the [nesting-vs-chaining](../../../docs/backtick-operator-design.md#nesting-vs-chaining) lookahead** to make it fire. The row says so and it
is the whole point: the design changed, the diagnostic did not, and deleting
it is what agreeing with the design looks like.

### [`slot-split-penalty`](../../BACKLOG.md#slot-split-penalty) — [format-break-policy](../../../docs/backtick-operator-design.md#format-break-policy)'s slot-interior `SplitPenalty` bump is unimplemented (P3)

The hard constraints suffice for identifier and qualified-name slots; a long
multi-token slot would format badly. Implement the bump, or — if it proves
fiddly against current clang-format — close it as *known formatting limit*
with a test that shows the current output, so the limit is documented rather
than latent. Either is an acceptable outcome; an untested claim is not.

## The one to record

### [`template-id-code-point`](../../BACKLOG.md#template-id-code-point) — `TemplateIdAnnotation` carries no code point (P2 by grade, benign in fact)

For `operator⊞<T>`, `TemplateII = nullptr` and `OpKind = OO_None` — **the same
gap upstream has for literal operators, marked there with a pre-existing
FIXME.** Resolution goes through the `TemplateName`, so **nothing is wrong
today**. Close it as *matches upstream's shape, latent, FIXME already exists
upstream*, and add the sentence to `docs/unicode-operators.md` §8 so a reader
who goes looking finds the answer rather than the gap.

## Do

1. [`backtick-ast-matchers`](../../BACKLOG.md#backtick-ast-matchers) and [`libclang-cursor-arm`](../../BACKLOG.md#libclang-cursor-arm) on `backtick-trunk`, then cherry-pick and **re-verify the
   gate independently** on `backtick-23`.
2. [`dead-nesting-diagnostic`](../../BACKLOG.md#dead-nesting-diagnostic) is a deletion; make sure no test asserts the diagnostic's text before
   removing it.
3. [`slot-split-penalty`](../../BACKLOG.md#slot-split-penalty) on both branches; remember `check-clang` self-formats
   `clang/lib/Format/` **and** `clang/unittests/Format/` with the in-tree
   binary and aborts at ~step 81/970 if your edits do not match — format with
   the `clang-format` you just built.
4. [`template-id-code-point`](../../BACKLOG.md#template-id-code-point) is a row edit and one doc sentence.

## Verify (gate)

- `check-clang` green on both backtick branches against the plan's baselines.
- `ast_matchers_updated.test` passes with the **regenerated** HTML.
- The `-Wswitch` warning for `BacktickInfixExpr` in `CXCursor.cpp` is gone —
  check the build log, since `WERROR` is `OFF` and nothing else will tell you.
- Four `Closed by` cells filled, plus [`template-id-code-point`](../../BACKLOG.md#template-id-code-point) recorded.
