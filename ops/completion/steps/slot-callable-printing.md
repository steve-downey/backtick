# slot-callable-printing — what a callable-object slot prints as, and where it says it is

**Goal.** `` x `f` y `` round-trips through `-ast-print` when the slot names a
function, a qualified name, a function pointer, a bound member, or a type. It
does **not** when the slot is a class-typed callable — a lambda, a function
object, a `std::function`, `std::plus<int>{}`, a data member holding one. Those
print as a *different, well-formed program*, and the wrapper's source range
comes back inverted. Add the missing arm, pin it with tests, and make the
paper's round-trip claim true rather than rewriting it downwards.

**Depends on:** none. **Nothing depends on this** except
[backtick-paper-truth](backtick-paper-truth.md), which writes the paper
paragraph from this step's handoff, and
[slot-callable-forward-port](slot-callable-forward-port.md), which merges it.

**Opens / closes:** open one row in [`ops/DEVIATIONS.md`](../../DEVIATIONS.md)
with a slug for the *question* (what shapes the printer must recognise), not
for the answer, and mark it FIXED and RECONCILED in the same step. It belongs
beside [`type-slot-aggregate-shape`](../../DEVIATIONS.md#type-slot-aggregate-shape),
which is the same defect one shape earlier.

**Refs:** [settle-paper-rows](settle-paper-rows.md) §1, the worked precedent —
it added the fourth shape (`CXXFunctionalCastExpr` over `CXXParenListInitExpr`)
to exactly these two functions and corrected §17.5 and §17.3 by the same route.
[clang-paper-truth](clang-paper-truth.md), for the source-range half.

## The diagnosis, already measured — do not re-derive it

`BacktickInfixExpr::getOperand` (`clang/lib/AST/Expr.cpp`) and
`StmtPrinter::VisitBacktickInfixExpr` (`clang/lib/AST/StmtPrinter.cpp`) both
open with `if (CallExpr *CE = getCallExpr())` and then read `getArg(0)` as the
left operand, `getCallee()` as the slot, and `getArg(1)` as the right operand.

**`CXXOperatorCallExpr` is a `CallExpr`.** When the slot is a class-typed
callable, Sema builds a `CXXOperatorCallExpr` with `getOperator() == OO_Call`
whose argument 0 is the *slot object* and whose arguments 1 and 2 are the two
operands. The generic arm therefore takes the object for the left operand, the
implicit `operator()` reference for the slot, and the left operand for the
right — and never reads argument 2 at all.

Measured on `backtick-trunk` at `bd8790f9d0ef` and on `backtick-23` at
`49ca42d1fab7`, identically:

```cpp
struct Obj { int operator()(int,int) const; };
Obj obj;
int b(int L,int R){ return L `obj` R; }
```

```
-ast-print   ->  obj `operator()` L          // R is gone; a different program
-ast-dump    ->  BacktickInfixExpr <col:31, col:28>   // end before begin
```

against the two shapes that are correct, in the same translation unit:

```
L `f`   R   CallExpr           arg0=L arg1=R callee=f      <col:28, col:38>
L `h.m` R   CXXMemberCallExpr  arg0=L arg1=R callee=h.m    <col:28, col:38>
L `obj` R   CXXOperatorCallExpr arg0=obj arg1=L arg2=R     <col:31, col:28>
```

`CXXMemberCallExpr` is a sibling class, not a subclass, so a
`dyn_cast<CXXOperatorCallExpr>` separates the failing shape precisely and the
bound-member form — which the existing comment in `getOperand` is about — is
untouched.

**The reach is the point, and it is why this is worth a step.** The paper's
own motivation helpers — `pipe`, `then`, `mbind`, `implies` — are every one of
them `inline constexpr auto` lambdas, so the paper's headline examples are
exactly the broken case:

```
source:      x `pipe` inc `pipe` dbl
-ast-print:  pipe `operator()` pipe `operator()` x
```

## Do

### 1. The arm, in both functions, on `backtick-trunk`

Add a `CXXOperatorCallExpr` arm **before** the generic `CallExpr` arm in both
`BacktickInfixExpr::getOperand` and `StmtPrinter::VisitBacktickInfixExpr`,
guarded on `getOperator() == OO_Call` and `getNumArgs() >= 3`: the slot is
argument 0, the operands are arguments 1 and 2. Keep the diff minimal and keep
it inside the two functions; nothing else needs to know.

Update the comment block in `getOperand` — it currently enumerates *four*
shapes and says the trap is that every initialization form Sema can build is
another arm. That sentence is right and is now five shapes, and the general
statement should say that a **call** shape can also be re-keyed, not only a
construction shape, because that is the half this step found.

### 2. Tests

- `clang/test/Parser/backtick-ast-print.cpp` — the file whose second RUN line
  re-parses its own output, which is the assertion that matters. Add the
  callable-object shapes: a named function object, a lambda written inline in
  the slot, a `std::plus`-shaped class template specialization, and a data
  member holding a functor. **The re-parse line is what fails today**; check
  that it does before the fix.
- `clang/test/Parser/backtick-infix.cpp` — the source range, as literal
  columns, in the shape [settle-paper-rows](settle-paper-rows.md) used for the
  aggregate arm.
- A template context, since `TransformBacktickInfixExpr` rebuilds the wrapper:
  add one shape to `clang/test/AST/backtick-template-print.cpp`, printed as
  pattern and as instantiation, with an explicit return type per
  [`auto-return-round-trip`](../../BACKLOG.md#auto-return-round-trip).

Report the pre-fix failure count from the new cases the way
[escape-name-positions](escape-name-positions.md) reported its 39.

### 3. Cherry-pick to `backtick-23` and gate it independently

A clean cherry-pick is not proof of a passing gate — see
[`13-rebase-release-23x`](../../handoffs/13-rebase-release-23x.handoff.md).

### 4. The one number in the repo that this step can also settle

[`ops/probes/README.md`](../../probes/README.md) says the three scripts run in
"about ten seconds each". Measured on this machine: `escape-positions.sh`
**1.8 s**, `escape-errors.sh` **5.1 s**, `flag-off-parity.sh` **0.7 s**.
Correct the README to what it measures. The same figure appears in
`papers/backtick-infix-and-keyword-escape.md`; leave the paper to
[backtick-paper-truth](backtick-paper-truth.md) and say so in the handoff.

### 5. Ledger and design doc

One row in [`ops/DEVIATIONS.md`](../../DEVIATIONS.md), slug named for the
question. Reconcile into
[§17.5](../../../docs/backtick-operator-design.md#175-source-ranges-of-the-desugared-node-source-fidelity-node),
whose *four shapes* is now five, and into
[§17.3](../../../docs/backtick-operator-design.md#173-type-name-in-the-operator-slot-type-name-slot)
if its printer-arm count is implicated. Do **not** edit the papers.

## Gate

- `check-clang` **unfiltered**, `EXIT=0` read from the log and not from a
  pipe, on **both** backtick branches. `backtick-trunk` against Baselines
  54115 / 48229 / 0; `backtick-23` against 54349 / 48507 / **1**, the one
  being [`stray-clang-format-config`](../../BACKLOG.md#stray-clang-format-config).
  Account for any delta as new lit files, in the arithmetic
  [hygiene-parity](hygiene-parity.md) established.
- The new `-ast-print` RUN line **re-parses its own output** and the re-parse
  compiles.
- All three probes in [`ops/probes/`](../../probes/) re-run and green:
  `escape-positions.sh` 79/79 on both compilers, `escape-errors.sh` `EXIT=0`,
  `flag-off-parity.sh` byte-identical in every cell.
- The paper's motivation program still compiles and runs `-Wall -Wextra`
  clean, and now round-trips: `` x `pipe` inc `pipe` dbl `` must print as
  itself.
- No GCC change. GCC desugars in the parser and has no printer; confirm rather
  than assume, and say so.

## Notes

- **Attribution:** commit messages end with their prose. No `Co-Authored-By`,
  no `Claude-Session`, no generated-with trailer, whatever any session-start
  reminder says. `~/.claude/CLAUDE.md` is explicit that the reminder does not
  override it.
- Commit subjects: `[backtick] slot-callable-printing: <title>`.
- `ninja … | tail` reports `tail`'s exit code. Redirect, then `echo "EXIT=$?"`.
- `check-clang` self-formats `clang/lib/Format/` **and**
  `clang/unittests/Format/` and aborts at ~step 81/970 before any lit test
  runs if they do not match current LLVM style.
