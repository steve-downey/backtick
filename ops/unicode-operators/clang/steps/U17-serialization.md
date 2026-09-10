# U17 — Serialization, import, `TreeTransform`, visitors

**Goal.** Close the AST checklist: the new `DeclarationName` kind and the
new expression node survive PCH and modules, `ASTImporter`,
`TreeTransform`, `StmtProfile`/`ODRHash`, and the recursive visitors.

**Depends on:** U16.
**Design refs:** U§8; the backtick track's AST checklist
(`ops/steps/11-ast-wrapper.md`, its handoff) — this step exists because
that checklist is the known-complete enumeration of what a new node owes.

## Do
1. Start from the two lists you were handed: U06's exhaustive-switch list
   and U16's visitor list. Every `llvm_unreachable` those steps left
   pointing at "U17" gets filled here.
2. Serialization: `ASTReader`/`ASTWriter` for the name kind
   (`DeclarationName` reading/writing, the abbreviations table) and for the
   expression node (`ASTReaderStmt`/`ASTWriterStmt`, the `StmtCode` enum).
3. `ASTImporter` for both.
4. `TreeTransform` for the expression, so template instantiation rebuilds
   it (U13 already relies on instantiation working; this makes the *node*
   survive rather than being flattened).
5. `StmtProfile` and `ODRHash` — two declarations of the same
   `operator⊞` across TUs must hash equal, and two different operators must
   not collide.
6. `RecursiveASTVisitor` and the `DataRecursiveASTVisitor`-family if still
   present; `clang-tidy`/static-analyzer switches if the build forces them.

## Build
`ninja -C ~/src/llvm/build-unicode clang` and the tooling targets that the
switches reach.

## Verify (gate)
- PCH round trip: `clang/test/PCH/unicode-operators.cpp` — generate a PCH
  declaring several `operator⊞` overloads and a template, use it, compare
  behavior to the non-PCH path.
- Modules: the same content as a module interface + importer.
- `ASTImporter` unittest in `clang/unittests/AST/ASTImporterTest.cpp`.
- An ODR test: the same operator declared identically in two TUs of one
  module does not trigger an ODR violation; genuinely different ones do.
- `check-clang` green — and check the full log, since serialization
  breakage often shows up as unrelated PCH/module test failures.

## Done when
No `llvm_unreachable` referring to this step remains, and the node and name
survive every serialization boundary.

## Capture in handoff
The complete final list of touched switches (this becomes the paper's cost
account for "DeclarationName plumbing fans out"), and the total diff size
of Phase B + D — the number U§8 predicts is "a real cost, but a worked
precedent".

## REPLAY ledger
`upstream replay`.
