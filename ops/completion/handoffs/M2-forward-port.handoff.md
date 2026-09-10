# Handoff — M2 — forward-port `BL02` and `clang-paper-truth` to the experiment branch

- **Status:** **DONE (gate passed).**
- **Branch / commits:** `unicode-operators-experiment` (`~/src/llvm/unicode`)
  - `85734d71ce1c` — the merge commit
  - `de76585ae45d` — the stale-comment fix (see [The comment nobody owned](#the-comment-nobody-owned))
  - `unicode-operators-upstream` **deliberately untouched**, still `783a9c1a5f6f`.
- **Date:** 2026-09-06.
- **Not a plan step.** Like `M1` and the R-prefixed rebases it gets a handoff, a
  Status-log row in [`ops/completion/PLAN.md`](../PLAN.md) and in
  [`ops/unicode-operators/clang/PLAN.md`](../../unicode-operators/clang/PLAN.md),
  and a [`REPLAY.md`](../../unicode-operators/clang/REPLAY.md) section. It does
  not follow `ops/AGENT_PROTOCOL.md`'s step loop and adds no feature.

## What was merged

`git merge --no-ff 5f70443430b8` — the explicit commit, not the branch name, as
[M1's handoff](../../unicode-operators/clang/handoffs/M1-forward-port.handoff.md)
insists. The tip was confirmed first; the three commits it brought were exactly

| Commit | What |
|---|---|
| `5a2b586463d9` | `BL02` — D16, a type-name in the operator slot yields construction |
| `cfbc69be9d4f` | `BL04` — the ClangIR arms for `BacktickInfixExpr` |
| `5f70443430b8` | [clang-paper-truth](../steps/clang-paper-truth.md) — the three defects that falsified a claim |

`BL04`'s backtick half is a third commit M2's plan text did not anticipate: the
experiment branch had already written *both* wrappers' CIR arms in its own
`BL04` (`6ee1358f7b47`), so the backtick half arrived as an already-applied
duplicate rather than as new work. That is the "trivial conflict in the shared
lead comment" [`ops/completion/PLAN.md`](../PLAN.md)'s Maintenance bullet
predicted, and it is exactly what happened — four times.

## The conflicts, and how each was resolved

**Eight conflicts, in three groups. None of them was a semantic conflict**: not
one required choosing between the two features, because no fix in either commit
reaches the other feature's node. The source-range fix is
`BacktickInfixExpr::getOperand`, the keyword escape is a `DeclarationName`
spelling, and `UserOperatorExpr` has neither.

### Already-applied, take this branch's version (the handoff's warning 2)

| File | Resolution |
|---|---|
| `clang/include/clang/Options/Options.td` | **Ours.** The `ShouldParseIf<cplusplus.KeyPath>` guard on `defm backtick` came *from* here (`U04`), where the two flags deliberately take it together; this branch's comment says so and backtick-trunk's, written later for one flag, does not. The `defm backtick` hunk was dropped entirely, as [clang-paper-truth's handoff](clang-paper-truth.handoff.md) instructs. |
| `clang/test/Lexer/backtick-c-mode.c` | **Ours.** Add/add. The two files' **bodies are byte-identical** — same four RUN lines, same two source lines, same `CHECK` — and only the header comment differs. Kept this branch's, which states the paired-flag reason that is true here. |

### Both sides added at the same anchor — keep both

| File | Resolution |
|---|---|
| `clang/include/clang/Sema/Sema.h` | Both sides inserted a declaration immediately after the existing `ActOnBacktickOperator`. Kept both, with `BL02`'s type-slot overload placed **beside its expression sibling** and `ActOnUserOperator` after them, so the two `ActOnBacktickOperator` overloads read as a pair. |
| `clang/lib/Sema/SemaExpr.cpp` | The same conflict in definition form: `Sema::ActOnBacktickOperator(ParsedType…)` and `Sema::ActOnUserOperator` both follow the expression-form `ActOnBacktickOperator`. Kept both, in that order. |

### The CIR lead comments — ours is the superset

`CIRGenExprAggregate.cpp`, `CIRGenExprComplex.cpp`, `CIRGenExprScalar.cpp`,
`CIRGenFunction.cpp`: **ours**, all four. This branch's `BL04` wrote the arms
for both wrappers; backtick-trunk's wrote them for one. **The arms themselves
are textually identical** — verified line by line against
`git show cfbc69be9d4f -- clang/lib/CIR` — so the only real conflict was in the
two shared lead comments, which on this branch already introduce both wrappers
(*"The two operator-sugar wrappers … Both are gated -- -fbacktick and
-funicode-operators"*) where backtick-trunk's name only one.
`clang/test/CIR/CodeGen/backtick-infix.cpp` was byte-identical on both sides and
git resolved it silently.

### What merged clean, and was checked anyway

`Expr.h`, `Expr.cpp`, `PrettyPrinter.h`, `DeclarationName.cpp`,
`DeclPrinter.cpp`, `ASTDiagnostic.cpp`, `TextNodeDumper.cpp`,
`StmtPrinter.cpp`, `Parser.h`, `ParseExpr.cpp` and the five backtick test files.
Read rather than trusted, because M1's lesson is that an auto-merge is not
evidence both sides survived:

- **`PrettyPrinter.h` did not conflict here** — the trap that hit `backtick-23`
  was the 23.x base lacking `PrettyEnums`, and this branch's base is trunk.
  `BacktickKeywordEscape` is still initialised **last** (after
  `SuppressLambdaBody`) and still **declared last** (line 394, after
  `SuppressLambdaBody` at 382), so no initialiser-order warning.
- **`BacktickInfixExpr::getOperand(unsigned)` came across whole** — the
  three-shape version, `CallExpr` / `CXXTemporaryObjectExpr` /
  `CXXUnresolvedConstructExpr`, indexing rather than counting back. It was **not**
  narrowed to `getCallExpr()`, which matters more here than on backtick-trunk:
  `BL02`'s type slot arrived in the same merge, so the five type-slot nodes in
  `backtick-infix.cpp` exist on this branch from the same commit that fixes them.
- `StmtPrinter::VisitBacktickInfixExpr` carries `BL02`'s three-shape printer *and*
  `clang-paper-truth`'s `VisitMemberExpr` policy routing; `U16`'s
  `VisitUserOperatorExpr` is untouched further down the file.
- `ParseExpr.cpp` has `TryParseBacktickTypeSlot`, the type/expression branch in
  the slot, the two-overload dispatch, **and** `U11`/`U12`'s
  `tok::user_operator` arms at `:692` and `:1373`.

## The fold guard survived, and it was proven rather than read

`Parser::isFoldOperator` on this branch still reads

```cpp
  return Level > prec::Unknown && Level != prec::Conditional &&
         Level != prec::Spaceship && Level != prec::UserInfix;
```

— `prec::UserInfix`, which is this pair of branches' spelling and **not** the
`prec::Backtick` the backtick branches use. Grepping all four branches for one
name is the trap [`ops/completion/PLAN.md`](../PLAN.md)'s gate facts now warn
about; on this branch the guard covers **both** features at once, because `U11`
renamed `prec::Backtick` to `prec::UserInfix` rather than adding a level.

Both negative tests are present and both ran:
`clang/test/Parser/unicode-operator-precedence.cpp` section 9 (`lfold`, `rfold`,
lines 320/322) and section 10's backtick twin (`btfold`, line 405), reached by
RUN lines 3 (`-DERRORS -verify=err`) and 4 (`-fbacktick -DBACKTICK -DERRORS`).

**Verified by removing the clause, not by reading it.** With
`&& Level != prec::UserInfix` deleted, rebuilt, the file **fails**:

```
error: 'err-error' diagnostics expected but not seen:
  Line 322 (directive at :323): expected expression
error: 'err-error' diagnostics seen but not expected:
  Line 322: expected ')'
  Line 322: expression contains unexpanded parameter pack 'N'
```

The clause was restored, rebuilt, and the file passes again.

**One thing that measurement turned up, and a future replay must not lose it:**
of the three fold assertions, **only the right fold `(N ⊞ ...)` at line 322
pins the guard.** The left folds — `(... ⊞ N)` at 320 and the backtick twin
`(... `f` N)` at 405 — still produce `expected expression` with the guard gone,
because they fail earlier in the parse for an unrelated reason. A replay that
kept only the left-fold cases as "the negative test" would leave the guard
unpinned while looking fully covered. `REPLAY.md`'s standing warning says do not
drop the negative tests as redundant; this says **which one** is load-bearing.

## The comment nobody owned

`Sema::CheckUserOperatorDeclaration`'s comment on the `isStatic()` guard gave
the reason [over-oper-restrictions](../../../docs/open-decisions.md#over-oper-restrictions)
explicitly rejected on 2026-09-06 — *"a static member function has no implicit
object parameter, so it can name neither form"* — which does not survive
inspection: the arity rule counts **operands**, so a two-parameter static member
satisfies it, and the rejection comes from the explicit guard rather than from
the rule. Replaced with the reason the author ruled on: the desugaring
equivalence is defined over exactly two spellings, `operator⊞(x, y)` and
`x.operator⊞(y)`, and a static member names neither. Comment only, no behaviour
change, the guard untouched — `de76585ae45d`, +6/−4 in one file.

**Scope note, for the author.** `unicode-operators-upstream` carries the
identical stale comment at `SemaDeclCXX.cpp:17209` and **was not touched**: M2
names the experiment branch only, and this handoff does not extend its own scope.
The two Unicode branches now differ by that comment. It is six lines against
four, so it also moves the replay arithmetic below by +2; whoever next lands on
`unicode-operators-upstream` should carry it, and the doc half of the same
ruling is already owed to
[reconcile-declaring-using](../steps/reconcile-declaring-using.md) as the
`static-member-operators` decision entry.

## Verification evidence

### Gate — GREEN, unfiltered, `EXIT=0`

```
ninja -C ~/src/llvm/build-unicode check-clang > gate.log 2>&1 ; echo "GATE_EXIT=$?"

Total Discovered Tests: 54183
  Passed: 48295   Failed: 0   XFAIL: 27   Unsupported: 5855   Skipped: 6
  370.79 s      GATE_EXIT=0
```

**Exactly the Baselines row** for `unicode-operators-experiment` —
54183 / 48295 / **0** — with no arithmetic to explain, and that is the expected
result rather than a coincidence: the two test files the merge would otherwise
have added, `clang/test/Lexer/backtick-c-mode.c` and
`clang/test/CIR/CodeGen/backtick-infix.cpp`, **already existed here**, and
everything else in the three commits amends files lit counts once. Unsupported
stays 5855 (the two CIR tests, this build having no CIR).

Build: `EXIT=0`, 3000 targets — a full rebuild, because `Expr.h`, `Sema.h`,
`Parser.h` and `PrettyPrinter.h` are all in the merge — and **zero `warning:`
lines** in the log. M1's note still holds: the two old backtick `-Wswitch` gaps
are closed, so a warning here would be new.

### The first run's three failures were the machine, and were confirmed so

The first `check-clang` reported `Failed: 3` — `DirectoryWatcherTest.AddFiles`,
`InitialScanAsync`, `InvalidatedWatcherAsync`, three of the eight the gate facts
name. Confirmed environmental exactly as the plan requires, and **not** budgeted:

- `sysctl fs.inotify.max_user_watches` = **524288**, so the budget is the raised
  one and this is not [`inotify-watch-budget`](../../BACKLOG.md#inotify-watch-budget)'s exhaustion.
- All 8 pass on the pristine `~/src/llvm/build-main` binary.
- All 8 pass on the freshly built `build-unicode` binary, five times over
  (`--gtest_repeat=5`, `PASSED 8 tests` ×5).
- The machine was at load 23–27, finishing the 3000-target rebuild.

Re-run on the settled build gave `Failed: 0` and `EXIT=0`; those are the numbers
above. This is the second consecutive maintenance run to hit it — see
[clang-paper-truth's handoff](clang-paper-truth.handoff.md), same three-of-eight
shape, same resolution — so treat a load-correlated `DirectoryWatcherTest`
failure as the expected cost of gating during a rebuild, not as a finding.

### Targeted re-run of both features' surfaces

11 tests, 11 passed, 0.94 s: `Parser/unicode-operator-precedence.cpp`,
`unicode-operator-infix.cpp`, `unicode-operator-prefix.cpp`,
`AST/unicode-operator-print.cpp`, `SemaCXX/unicode-operator-semantics.cpp`,
`Parser/backtick-infix.cpp`, `backtick-escape.cpp`,
`backtick-escape-diagnostics.cpp`, `backtick-ast-print.cpp`,
`backtick-diagnostics.cpp`, `Lexer/backtick-c-mode.c`. That covers the three
`clang-paper-truth` fixes on their new branch: the pinned literal `<col:N,
col:M>` ranges, the `-ast-print`-and-re-parse round trip of the keyword escape,
and the C-mode inertness.

### Formatting

`git-clang-format --diff --commit HEAD~2` with the **in-tree** `clang-format`
reports two hits, **both inherited and neither M2's**: the `.stream(`
continuation in `DeclPrinter::VisitFieldDecl` (which
[clang-paper-truth's handoff](clang-paper-truth.handoff.md) already records as
pre-existing and deliberately left alone) and `BL02`'s `ActOnBacktickOperator`
call in `ParseExpr.cpp`. Both regions are **byte-identical to backtick-trunk** —
`git diff 5f70443430b8..HEAD` over `DeclPrinter.cpp` and `ParseExpr.cpp` is
empty — so they came across unchanged from commits that gated green there. The
comment commit alone is clean (*"clang-format did not modify any files"*).
Nothing in `clang/lib/Format/` or `clang/unittests/Format/` was touched, so the
self-format step at ~81/970 was never in play.

### The feature diff, re-measured

```
git diff --shortstat 5f70443430b8..HEAD  → 119 files changed, 7600 insertions(+), 47 deletions(-)
git diff -U0 5f70443430b8..HEAD | grep -c '^@@'  → 217
```

M1 could report U19's 110 / 204 / +7341−29 unchanged; **M2 cannot, and the
reason is not the merge.** `BL03` (+4 production files, +1 test) and `BL04` (+4
CIR files, +1 test) landed on this branch after U19's audit, which is 9 of the 9
new files. The remaining movement is the three shared lead comments this merge
resolved in favour of the both-features wording, plus the six-line comment in
`de76585ae45d`. **No ledger row changes classification**; `REPLAY.md`'s new M2
section carries the arithmetic and the re-run contamination scan.

## Discoveries affecting later work

- **`M2` is done, so `backtick-trunk` and `unicode-operators-experiment` have no
  outstanding forward-port.** The next backtick-track change to land on
  `backtick-trunk` — [null-return-suppression](../steps/null-return-suppression.md)
  touches all four branches, so it will do its own — creates a new one only if it
  lands on the backtick branches alone.
- **`unicode-operators-upstream` must still never receive this merge.** Unchanged
  from M1 and restated because it is the whole hazard: the branch is
  `upstream/main` plus Unicode only, and U20's headline result is that
  `git diff upstream/main..HEAD | grep -i backtick` returns nothing.
- **`PrintingPolicy::BacktickKeywordEscape` now exists on this branch**, set from
  `LangOptions::Backtick`. Any test added here whose expected **diagnostic** names
  a keyword-escaped entity under `-fbacktick` must write the backticks. It does
  not interact with `UserOperatorExpr`: a user operator's name is a
  `CXXUserOperatorName`, not an `Identifier`, so it never reaches the arm that
  escapes.
- **`BacktickInfixExpr::getOperand(unsigned)` is available here now**, and is the
  counterpart of `UserOperatorExpr::getOperand` — with the one asymmetry
  clang-paper-truth recorded: the backtick member form puts the *object* in the
  operator slot, so operand 0 is `getArg(0)` and there is no `CXXMemberCallExpr`
  case, whereas `UserOperatorExpr` needs one.
- **Nothing is pushed.** The branch is ahead of every remote, as it was before.

## Open risks / TODOs

- **The comment divergence between the two Unicode branches**, above. One
  paragraph, and the author's call whether to carry it or wait for
  [reconcile-declaring-using](../steps/reconcile-declaring-using.md) to touch
  that branch anyway.
- **Section 9's own comment is now stale in the other direction.**
  `unicode-operator-precedence.cpp:314` still says the fold behaviour is *"pinned
  here, not endorsed -- U§13 lists it as open"*, but
  [fold-over-user-infix](../../../docs/open-decisions.md#fold-over-user-infix)
  was answered on 2026-09-06: excluded in v1, deliberately, for both features.
  Left alone — the U§13 bullet and this file's wording are
  [reconcile-remainder](../steps/reconcile-remainder.md)'s, and M2 does not write
  documentation it does not own.
- **`keyword-escape-printing` is still unruled by the author**, exactly as
  clang-paper-truth left it, and the merge carried the two diagnostic tests that
  pin it onto this branch as well. If the ruling reverses, it now reverses on
  three branches rather than two.
