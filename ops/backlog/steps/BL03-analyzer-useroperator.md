# BL03 — `B14`: fix the static analyzer for `UserOperatorExpr`

**Goal.** The static analyzer sees a user-operator expression exactly as it
sees the explicit call it desugars to — same values, same construction
contexts, same destructor count.

**Depends on:** BL01; **M1** (see below).
**Closes:** `B14`.
**Refs:** `ops/handoffs/15-defect-fixes.handoff.md:88-155` (F24's account of
the same five sites for `BacktickInfixExpr`, and its test);
`ops/unicode-operators/clang/handoffs/U16-ast-print.handoff.md:445-457` (what
U16 recorded and deliberately left); DEV-U13.

## This is not speculative any more

`BACKLOG.md` says "almost certainly mishandles … and nobody has looked".
Someone has looked. **Three of F24's five defects are observed** on
`~/src/llvm/build-unicode/bin/clang -cc1 -std=c++23 -funicode-operators`:

- **Value loss / spurious path split.** With
  `-analyze -analyzer-checker=core,debug.ExprInspection`:
  ```cpp
  int operator⊞(int a, int b){ return a+b; }
  void t(){ int x = 1 ⊞ 2;          clang_analyzer_eval(x == 3); } // FALSE *and* TRUE
  void u(){ int x = operator⊞(1,2); clang_analyzer_eval(x == 3); } // TRUE
  ```
  The operator form splits the state because the initializer's value is
  unknown. `` 1 `add` 2 `` on the post-F24 backtick branch reports `TRUE`
  only. No parity.
- **Broken construction context.** `const S &r = 1 ⊞ 2;` versus
  `const S &r = operator⊞(1, 2);` under
  `-analyze -analyzer-checker=debug.DumpCFG -analyzer-config cfg-temporary-dtors=true`
  gives `(CXXRecordTypedCall, [B1.6])` where the explicit call gives
  `[B1.8]` — character-for-character the symptom F24 quotes.
- **Double destructor**, plus the wrapper appearing as a CFG element of its
  own (`7: [B1.3] ⊞ [B1.4]`). The explicit form has neither.

The one F24 defect *not* present is the dropped-successor /
whole-function-unanalyzed one: U16's `ExprEngine` case keeps the path alive.

## The five sites F24 fixed (commit `169e45c7916f` on `backtick-trunk`)

| File / site | Precedent followed | What was broken |
|---|---|---|
| `Analysis/CFG.cpp:2382-2389` `CFGBuilder::Visit` | `VisitConstantExpr` | wrapper was a CFG element of its own |
| `Analysis/CFG.cpp:1652-1660` `findConstructionContexts` | `ParenExprClass` | context chain broke at the wrapper |
| `Analysis/CFG.cpp:5208-5214` `VisitForTemporaries` | `ParenExpr`/`ConstantExpr` `goto tryAgain` | `default:` dropped `ExternallyDestructed` → double destroy |
| `Analysis/LiveVariables.cpp:185-188` `LookThroughExpr` | `FullExpr`, `OpaqueValueExpr` | value reaped as dead the instant it was bound; every result read back UNKNOWN |
| `StaticAnalyzer/Core/Environment.cpp:56-57` `ignoreTransparentExprs` | `ConstantExpr`, `ExprWithCleanups` | read of the wrapper did not resolve to the call's binding |
| `StaticAnalyzer/Core/ExprEngine.cpp:1879-1882` `Visit` | `ConstantExpr`/`ExprWithCleanups` | the `-Wswitch` gap; path dropped |

`LiveVariables` was **not** on F24's original list and is the one that would
have been missed. It was found by diffing `clang_analyzer_eval` output
against the plain call, not by any diagnostic. Use the same technique here
rather than trusting the site list.

## Do

Work on `unicode-operators-experiment`, then replay onto
`unicode-operators-upstream`.

1. **Audit each of the six arms individually.** Do not transplant the diff.
   Two mechanical reasons it cannot be transplanted:
   - There is **no `getSubExpr()`** on `UserOperatorExpr`. It is
     `getSemanticForm()` (`ExprCXX.h:442-443`), and `getOperand(I)` *recovers*
     operands from that form (`ExprCXX.cpp:135-155`). No hunk compiles
     verbatim.
   - `UserOperatorExpr` is **not transparent to transformation** —
     `TransformUserOperatorExpr` (`TreeTransform.h:14234-14259`) transforms
     the operands *as written* and re-runs `Sema::CreateOverloadedUserOp`,
     because carrying the syntax across instantiation is why the node exists
     (DEV-U13). Argue each analyzer arm on its own terms. Value-wise the node
     *is* its semantic form — the constructor copies type, value kind and
     object kind from it (`ExprCXX.h:427-428`) — which is the sense of
     "transparent" the analyzer cares about, but say so in the handoff rather
     than assuming it.
2. **`CFG.cpp` and `ExprEngine.cpp` are coupled. Fix them in the same
   commit.** U16 grouped `UserOperatorExprClass` with
   `CXXRewrittenBinaryOperatorClass` at
   `~/src/llvm/unicode/clang/lib/StaticAnalyzer/Core/ExprEngine.cpp:1913-1917`,
   which runs pre/post-stmt checkers and binds nothing. That is currently
   *self-consistent* only because `CFG.cpp` has no case, so the wrapper
   genuinely is a CFG element. Fix `CFG.cpp` and leave `ExprEngine` alone and
   the pairing breaks — the arm has to become `Dst.insert(Pred)`
   ("handled due to fully linearised CFG") at the same time. This is exactly
   why `BACKLOG.md` says the sites must be audited one at a time.
3. **Write the test.** There is **no `clang/test/Analysis/` test on the
   Unicode branch at all**. F24's `clang/test/Analysis/backtick-infix.cpp`
   transplants directly and pins the three things to assert:
   - value-flow parity with the explicit call,
   - a null dereference still reported *through* the operator,
   - the CFG element list for a class-typed result, showing the construction
     context reaching the materialization and **exactly one** destructor.

   Cover the prefix form too (U12) — the node is the same node, but the
   operand recovery differs (`NumOperands == 1`).

## Sequencing — run M1 first

`ops/unicode-operators/clang/steps/M1-forward-port-backtick-fixes.md` is
written and unchecked. It merges F23/F24 onto `unicode-operators-experiment`
and must **not** reach `unicode-operators-upstream`. Running it before this
step puts the `BacktickInfixExpr` arms in-tree immediately beside where the
`UserOperatorExpr` arms go — strictly easier, and it costs nothing.

## Build

`ninja -C ~/src/llvm/build-unicode clang`

## Verify (gate)

- The new `clang/test/Analysis/unicode-operator-*.cpp` passes, and each of
  the three assertions above **fails** if you revert the corresponding arm.
  Check that; an analyzer test that passes either way is worthless.
- `clang_analyzer_eval` parity: infix, prefix, member and non-member forms
  all report exactly what the explicit call reports.
- `check-clang` green on `unicode-operators-experiment`, then again on
  `unicode-operators-upstream` after the replay.

## REPLAY ledger

`upstream replay`. All six sites are `UserOperatorExpr`-only and carry no
backtick dependency, so they replay onto clean `main` unchanged — but state
that explicitly, because M1 will have put `BacktickInfixExpr` arms in the
same switches on the experiment branch and those are **not** part of the
replay.

## Capture in handoff

Which of the six arms actually needed to differ from F24's, and why. That is
the answer to a question the paper asks: how much of a wrapper node's
obligation is generic, and how much depends on whether the node is
transparent to transformation.
