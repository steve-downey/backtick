# U16 — AST node and `-ast-print` fidelity

**Goal.** A user-operator expression prints back as written (`a ⊞ b`,
`⊖a`), not as its desugared call, and `-ast-dump` identifies it clearly.

**Depends on:** U13.
**Design refs:** U§7 (desugaring); backtick §6.4/§11 phase 2 and
`ops/handoffs/11-ast-wrapper.handoff.md` — the worked precedent, including
DEV-05's finding that source locations live in the inner `CallExpr`'s paren
fields and the printer reconstructs syntax from *structure*.

## Do
1. Follow the backtick track's wrapper pattern: a transparent expression
   node around the built call, carrying the operator's identity and
   location, forwarding type/value-category/dependence to the inner call.
   Read S11's handoff before designing anything — it records what the
   backtick wrapper had to implement and what it could skip.
2. Alternative worth considering and recording: reuse
   `CXXOperatorCallExpr` (which already exists to print operator syntax for
   a call) rather than a new node. If `CXXOperatorCallExpr` is welded to
   `OverloadedOperatorKind`, say so — that is more evidence for U§8's
   "the operator-name tables are closed" thesis.
3. Implement `StmtPrinter` for infix and prefix forms, and `-ast-dump`
   labelling that shows the code point.
4. Do not store the operator spelling as a string if the code point plus
   the printing path can regenerate it — but the *round trip must preserve
   the original spelling choice* only insofar as the design requires. U11
   made glyph and UCN the same token; printing the glyph for a UCN-spelled
   source is acceptable and probably right. Decide, document, and test
   whichever way you go.

## Build
`ninja -C ~/src/llvm/build-unicode clang`

## Verify (gate)
- `clang/test/AST/unicode-operator-print.cpp`: `-ast-print` round trip —
  print, re-parse the printed output, print again, compare. Infix, prefix,
  chained, parenthesized, member form, template form.
- `-ast-dump` output identifies the node and the operator.
- The wrapper is transparent: `-emit-llvm` output is unchanged versus the
  pre-U16 build for the same input (the node must not alter codegen).
- `check-clang` green.

## Capture in handoff
The node name, the file list touched, and — critically — **every visitor,
profiler, and switch the new node forced you to update**, cross-checked
against U06's list. U17 finishes that list.

## REPLAY ledger
`upstream replay`; note explicitly whether the wrapper *class* is shared
with backtick's or a sibling. If shared, it is `shared if landed` and U20
must synthesize a standalone version.
