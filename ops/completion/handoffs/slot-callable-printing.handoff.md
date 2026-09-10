# Handoff — slot-callable-printing — the fifth inner shape, and a call Sema re-keyed

- **Status:** **DONE (gates passed).**
- **Branch / commit:**
  - `backtick-trunk` — `28b685c86ea2`
  - `backtick-23` — `8d003dd45c52` (cherry-pick, gated independently)
  - GCC `backtick` — **not touched**, and that is a finding rather than an
    omission; see *Verification evidence*.
  - `unicode-operators` in *this* repo — the design doc, the ledger, the
    probes README, the plan, `CLAUDE.md` and this handoff. **Neither Unicode
    branch was touched**; the merge is
    [slot-callable-forward-port](../steps/slot-callable-forward-port.md).
- **Date / agent:** 2026-09-08.
- **Opens and closes, in the same step:**
  [`slot-callable-shape`](../../DEVIATIONS.md#slot-callable-shape), **FIXED and
  RECONCILED**. The three ledgers still read **0 / 1 / 0**, the one being
  [`escape-type-name-spelling`](../../gcc/DEVIATIONS.md#escape-type-name-spelling).

---

## The diagnosis was right, and re-checking it found one thing it got wrong

The step file's measurement reproduced exactly, on both branches, at the
commits it named. `CXXOperatorCallExpr` **is a** `CallExpr`; a slot whose
*value* is a class-typed callable is called through the object's `operator()`,
which Sema keys as `CXXOperatorCallExpr` with `getOperator() == OO_Call`,
argument 0 the slot object and arguments 1 and 2 the operands; the generic arm
in both functions read it at the wrong indices and never read argument 2.

**The one thing the brief had wrong is worth keeping**, because it is the part
a paper paragraph turns on. The brief calls what the printer produced *"a
different, well-formed program"*. It is a different program and it is **not
well-formed**: the text names `operator()` as a free function, and unqualified
lookup does not find one. Measured, on the pre-fix `backtick-trunk` binary,
feeding `-ast-print`'s output back in:

```
error: use of undeclared 'operator()'   ×5
```

Inside a class, where `operator()` *is* found, it is still ill-formed — the
printed `` *this `operator()` L `` gives *no viable conversion from 'const S'
to 'int'*, because the object has been moved into an operand position.

So the two halves of this defect failed differently, and only one of them was
silent:

| half | how it failed | what would have caught it |
|---|---|---|
| printing | **loud** — the printed program does not compile | the `-ast-print` test's second RUN line, which re-parses its own output. It had no case of this shape. A coverage hole, not a silence. |
| source range | **silent** — `<col:31, col:28>`, end before begin | nothing, except literal columns pinned in a test |

That distinction is now in
[§17.5](../../../docs/backtick-operator-design.md#175-source-ranges-of-the-desugared-node-source-fidelity-node)
and in the ledger row, and it is the honest correction to §17.5's own general
statement, which had said a missing arm *"is silent — it prints the
desugaring, which is well-formed, plausible, and not what was written."* Two
instances now: the aggregate one was well-formed, this one is not, and the
general statement holds either way once it stops claiming well-formedness.

## What changed

### Clang — `backtick-trunk` `28b685c86ea2`, `backtick-23` `8d003dd45c52`

Two arms, both **ahead of** the generic `CallExpr` arm, both guarded on
`getOperator() == OO_Call && getNumArgs() >= 3`:

- `BacktickInfixExpr::getOperand` (`clang/lib/AST/Expr.cpp`) — returns
  `OCE->getArg(I + 1)`.
- `StmtPrinter::VisitBacktickInfixExpr` (`clang/lib/AST/StmtPrinter.cpp`) —
  prints `getArg(1)`, the slot as `getArg(0)`, `getArg(2)`.

The comment block in `getOperand` said the trap was that every *initialization*
form Sema can build for `T(x, y)` is another arm. That is half of it. It now
says a **call** can be re-keyed too — Sema chooses the node from the call's
shape, so the operands are not at a fixed index of the call it built.

Tests, all into files that already existed, so **no lit count moves**:

- `clang/test/Parser/backtick-ast-print.cpp` — six shapes: a named function
  object, a lambda written inline in the slot, a lambda held in a variable
  (what the paper's helpers are), a `std::plus`-shaped class template
  specialization `` `plusish<int>{}` ``, a data member holding a functor, and
  a **surrogate call** — a callable used through its conversion to a function
  pointer.
- `clang/test/Parser/backtick-infix.cpp` — the range as literal columns,
  `<col:43, col:60>`, in the shape
  [settle-paper-rows](../steps/settle-paper-rows.md) used for the aggregate arm.
- `clang/test/AST/backtick-template-print.cpp` — case 6, printed as pattern
  **and** as instantiation, explicit return type per
  [`auto-return-round-trip`](../../BACKLOG.md#auto-return-round-trip).

**Pre-fix failure count: seven of the eight new checks failed.** Five of the
six `-ast-print` shapes; the literal-column range; and the *instantiation*
half of the template case. The two that passed are the two that say where the
boundary is — see *Discoveries*.

### This repo

- [`ops/DEVIATIONS.md`](../../DEVIATIONS.md) — one row,
  [`slot-callable-shape`](../../DEVIATIONS.md#slot-callable-shape), named for
  the question (what shape a callable slot's call takes) and not for the
  answer, placed beside
  [`type-slot-aggregate-shape`](../../DEVIATIONS.md#type-slot-aggregate-shape),
  which is the same defect one shape earlier.
- `docs/backtick-operator-design.md` —
  [§17.5](../../../docs/backtick-operator-design.md#175-source-ranges-of-the-desugared-node-source-fidelity-node)
  gains the fifth shape, the loud/silent paragraph above, and the
  surrogate-call boundary; its general statement now names **two** ways the
  arms multiply. §17.3's *"three printer arms"* is relabelled *"three
  type-slot printer arms"* — it was a count of the type slot's arms all along
  and is unchanged by this row, which now cannot be misread against §17.5's
  total.
- [`ops/probes/README.md`](../../probes/README.md) — *"about ten seconds
  each"* → the measured **1.6 s / 5.0 s / 0.4 s**, and the find-rate corrected
  from five-of-five to **five of six**, this run being the sixth and green.
- `docs/backtick-operator-design.md` also carried *"about ten seconds"* twice
  for `escape-positions.sh` alone; both now say **1.6 seconds**.
- `ops/completion/PLAN.md` (box 21, a Baselines note, a Coverage row, three
  Status rows), `CLAUDE.md` (the Phase J paragraph now says the compiler
  defect is fixed and what is left).

## Verification evidence

### Gates, both branches, unfiltered, exit code read from the log

```
backtick-trunk   check-clang   EXIT=0   54115 discovered / 48229 passed / 0 failed
backtick-23      check-clang            54349 discovered / 48507 passed / 1 failed
```

XFAIL 27, skipped 6, unsupported 5853 / 5808 — all unchanged, and both rows
are **exactly** the Baselines. No delta to account for: cases went into three
lit files that already existed, and lit discovers files, not cases.

`backtick-23`'s one failure is `Clang :: Format/dump-config-objc-stdin.m`,
[`stray-clang-format-config`](../../BACKLOG.md#stray-clang-format-config),
**re-confirmed rather than budgeted**: run from the same working directory
(`build-backtick/tools/clang/test`), the pristine `~/src/llvm/build-main`
`clang-format` fails identically —

```
Configuration file(s) do(es) not support Objective-C: /home/sdowney/src/.clang-format
```

a 2018 file outside any repo. `ninja` was redirected to a log and `EXIT=$?`
appended to it, never piped.

### The re-parse RUN line, which is the assertion that matters

`clang/test/Parser/backtick-ast-print.cpp`'s second RUN line feeds
`-ast-print`'s output back to the compiler. **Before**: five
`use of undeclared 'operator()'` errors. **After**: clean, and the file's
`PRINT` checks pass. Same for `clang/test/AST/backtick-template-print.cpp`,
whose second RUN line re-parses its instantiations.

### The paper's motivation program

Built and run on the fixed `backtick-trunk` binary, `-std=c++23 -Wall -Wextra`,
**zero warnings**, exit 0, and the ranges comparison agrees through `|` and
through `` `pipe` `` (300 = 300). And it round-trips:

```
int r = x `pipe` inc `pipe` dbl;
auto twice = inc `then` dbl;
for (int n : v `pipe` std::views::filter(pred) `pipe` std::views::transform(fn))
```

— all three print as themselves under `-ast-print`. Before the fix the first
printed as `` pipe `operator()` pipe `operator()` x ``.

### The three probes, re-run on both branches' binaries

| script | question | result | time (best of 3) |
|---|---|---|---|
| `escape-positions.sh` | where does the escape reach? | **79/79 on both compilers**, with `backtick-trunk`'s binary and again with `backtick-23`'s | **1.6 s** |
| `escape-errors.sh` | does a bad escape diagnose *and stop*? | **46/46 diagnosed**, `EXIT=0`, no timeout | **5.0 s** |
| `flag-off-parity.sh` | does the flag change a program with no backtick? | **byte-identical in every cell**, `EXIT=0` | **0.4 s** |

Run with `bash`, not `zsh`. `flag-off-parity.sh`'s one non-identical cell is
the standing one: GCC flag-off against pristine differs in two assembly lines,
which are the `.ident` build-date string.

**They found nothing, and the run is recorded anyway.** This step changed the
AST printer, not the escape, so a green sweep is the expected reading. A sweep
run only when it is expected to fail has stopped being a control, and the
README now says so.

### No GCC change, confirmed rather than assumed

GCC desugars in the parser and has no pretty-printer for the form, so there is
no counterpart to either function. Checked, not inferred: all six shapes —
named function object, inline lambda, lambda variable, class-template
specialization temporary, data-member functor, surrogate — are accepted by
`~/bld/gcc/gcc-backtick-build/gcc/cc1plus -fbacktick -std=c++23 -fsyntax-only`
before and after, `EXIT=0`. `dg.exp=g++.dg/backtick/*.C` was not re-run and
does not move; nothing on that side was edited.

## Deviations from the step file

1. **The brief's "different, well-formed program" is wrong** and the handoff
   and the ledger say so with the measurement. See the table above. This
   matters to [backtick-paper-truth](../steps/backtick-paper-truth.md): the
   paper must not repeat it.
2. **A sixth `-ast-print` shape was added that nothing asked for** — the
   surrogate call — and it is the one that pins the *boundary*. The arm's real
   condition is the node kind and `OO_Call`, not any property of the slot's
   type, and without a case on the other side of that line the next reader has
   only the comment.
3. **Two design-doc figures were corrected beyond the ledger reconciliation**:
   `docs/backtick-operator-design.md` carried the same stale *"about ten
   seconds"* sweep timing twice. The step file named only
   `ops/probes/README.md`, but the design doc was open for §17.5 and §17.3
   anyway, and [backtick-paper-truth](../steps/backtick-paper-truth.md)
   declares the design doc **out of scope**, so leaving it would have left it
   unowned. See *Open risks* for the one occurrence nobody owns.

## Discoveries affecting later steps

- **`CXXOperatorCallExpr` is a `CallExpr`, and that is a standing hazard for
  this feature.** Any code that reasons about `BacktickInfixExpr`'s inner node
  by `dyn_cast<CallExpr>` gets the re-keyed shape too, with its arguments
  shifted by one. `getCallExpr()` is documented as *the desugared call* and is
  still that — it is the *indices* that are not stable, not the cast.
- **The boundary is `OO_Call`, not "the slot is a class type".** A callable
  used through its **conversion to a function pointer** — a surrogate call —
  is not re-keyed: Sema builds a plain `CallExpr` whose callee is the converted
  object, and the generic arm printed it correctly all along. Both sides of
  that line are now cases in `backtick-ast-print.cpp`.
- **In a template, only the instantiation ever failed.** The pattern's inner
  node is an ordinary dependent `CallExpr` — callee `f`, arguments `a` and `b`
  — because overload resolution has not run. The re-keying happens in
  `TreeTransform`'s rebuild. **A template test that checks only the pattern
  proves nothing about this class of defect**, which is exactly the gap
  `evidence-debt` opened `backtick-template-print.cpp` to close.
- **`-ast-print` prints a lambda over three lines.** A `PRINT` check for a
  lambda written inline in the slot has to be split across two directives, not
  widened with `{{.*}}`.
- **The `-ast-print` re-parse RUN line is a strong gate and a narrow one.** It
  caught this defect's printing half the instant a case existed, and it says
  nothing at all about source ranges. Ranges need literal columns; there is no
  self-checking form of them.

## Forward notes for [backtick-paper-truth](../steps/backtick-paper-truth.md)

**§1 — the round-trip paragraph. What the paper may now claim, precisely:**

> `-ast-print` round-trips every shape the operator can take, with **one**
> exception — a slot naming a builtin whose call the semantic layer rewrites
> into a node that is no longer a call (`` a `__builtin_shufflevector` b ``),
> which prints as the rewrite because the rewrite is not expressible in the
> syntax.

That is the whole of the exception list now. The paragraph's *"second
exception"* (the aggregate type slot) and its **third** — this one — are both
fixed, and the paper should say the general lesson caught it a second time
rather than renumbering the list. **The bold sentence at the end of that
section — *"A round-trip claim is a claim about every node the semantic layer
can build, not about the nodes the printer was written against"* — was written
before this instance was found, and this instance is its strongest support.
Protect it, and say when it was written.**

Two precise facts for that paragraph, both measured here:

- The shape was **a slot whose value is a class-typed callable** — every
  lambda, function object and `std::function`. Do not write "a lambda in the
  slot": the failing condition is a call to the object's `operator()`, and a
  callable reached through a *conversion to a function pointer* printed
  correctly all along. That is a sharper sentence and a true one.
- **What it printed was not a well-formed program.** Say it printed something
  that does not compile — it named `operator()` as a free function, dropped an
  operand, and reported a source range that ended before it began. The
  aggregate case *was* well-formed and plausible, and the contrast between the
  two is the interesting half: the same defect one shape earlier failed
  silently, this one failed loudly, and neither was caught, because the test
  file had no case of either shape. **A round-trip claim tested only where the
  printer already works is untested whichever way it fails.**

**§1's second half.** §"Design choices and decisions", *"The operator slot is
an assignment-expression"*, advertises the slot as admitting *"a qualified
name, a member access, **a lambda**"*. That sentence was true of the parse and
false of the printer; it is now true of both, and a lambda written **inline in
the slot** is pinned in `backtick-ast-print.cpp` as well as a named one.

**§2 — the sweep timing.** Re-measured here, best of three consecutive warm
runs each: `escape-positions.sh` **1.6 s** (the step file and the brief both
say 1.8 s — that figure is one measurement old), `escape-errors.sh` **5.0 s**,
`flag-off-parity.sh` **0.4 s**. The paper's sentence is about
`escape-positions.sh` alone, so the number it wants is **1.6 seconds**, and
`ops/probes/README.md` and `docs/backtick-operator-design.md` now both say
that. Take it from here or re-measure and say which.

**Nothing else in the paper is implicated by this step.** No new divergence,
no new deviation row beyond
[`slot-callable-shape`](../../DEVIATIONS.md#slot-callable-shape) (which is
`FIXED and RECONCILED` and must not appear in public text), and the
divergence list stays at one.

## Forward notes for [slot-callable-forward-port](../steps/slot-callable-forward-port.md)

- **The commit to merge is `28b685c86ea2`** on `backtick-trunk`. Five files:
  `clang/lib/AST/Expr.cpp`, `clang/lib/AST/StmtPrinter.cpp`,
  `clang/test/Parser/backtick-ast-print.cpp`,
  `clang/test/Parser/backtick-infix.cpp`,
  `clang/test/AST/backtick-template-print.cpp`. **131 insertions, 13
  deletions**, identical on both backtick branches — the cherry-pick was clean
  and `git show --stat` matches line for line.
- **The Baselines row must not move.** No new lit file; all three test files
  already exist on `unicode-operators-experiment`
  (`escape-positions-forward-port` and `unicode-branch-maintenance` carried
  them). Expect **54190 / 48302 / 0**, unchanged.
- **The predicted `StmtPrinter.cpp` collision is real but almost certainly
  not a conflict.** `VisitUserOperatorExpr` and `VisitBacktickInfixExpr` are
  different functions in the same file; run `git diff --numstat` before
  writing a paragraph about it, per that step's own rule.
- **`UserOperatorExpr::getOperand` does not need the same arm, and this is
  proven rather than read.** Measured on `~/src/llvm/build-unicode`'s clang
  (branch `unicode-operators-experiment` at `5fd79178d2a7`), `-ast-print`:

  ```cpp
  struct Fn { int operator()(int,int) const; };
  Fn fn;
  struct W { Fn f; int operator⊞(const W&) const; };
  int operator⊞(const Fn&, const Fn&);
  int a() { return fn ⊞ fn; }   // prints as  fn ⊞ fn
  int b() { return w1 ⊞ w2; }   // prints as  w1 ⊞ w2
  ```

  Both round-trip. The reason is structural and worth carrying: a Unicode
  operator's semantic form is a call to a **declared function** `operator⊞`,
  either `operator⊞(x, y)` or `x.operator⊞(y)`, and neither is an `OO_Call`
  `CXXOperatorCallExpr` — there is no `OverloadedOperatorKind` for ⊞ at all.
  `UserOperatorExpr::getOperand` (`clang/lib/AST/ExprCXX.cpp:135`) already
  checks `CXXMemberCallExpr` **before** `CallExpr`, for the same
  "`X` is a `CallExpr`" reason this step's arm exists, so the file already
  contains the idiom.
- **The defect is live on `unicode-operators-experiment` today, and the merge
  is what fixes it.** Confirmed on the same binary, both features on:

  ```
  int c(int L, int R) { return L `fn` R; }
  -ast-print  ->  return fn `operator()` L;
  ```

  That is a good post-merge check: re-run it and it must print `` L `fn` R ``.
- **`unicode-operators-upstream` must never receive this merge**, and
  `git diff upstream/main..unicode-operators-upstream | grep -i backtick`
  returning nothing is part of that step's gate.
- The fold-guard proof on that branch is `Level != prec::UserInfix`, **not**
  `prec::Backtick` — the spelling differs per pair, and grepping the wrong one
  looks exactly like the loss it warns about.

## Open risks / TODOs

- **`docs/infix-backtick-operator.org` still says the sweep takes "ten seconds
  to run", and nobody owns it.** The blog post is out of scope for
  [backtick-paper-truth](../steps/backtick-paper-truth.md) by that step's own
  gate, and it was out of scope here. The measured figure is **1.6 s**; it is a
  one-word fix for whatever pass next touches that file. It joins
  [`hunk-count-provenance`](../../BACKLOG.md#hunk-count-provenance) as a
  correction waiting for a passing edit rather than a step.
- **Nothing is pushed.** `backtick-trunk` and `backtick-23` are each one
  commit further ahead of their remotes, on top of what was already unpushed;
  this repo is ahead by this step's commit. All branches track `ceridwen`
  **and** `origin`. The maintainer's call.
- **The motivation program's *whole* round trip was not attempted.** Its
  `-ast-print` output is ~57k lines of instantiated standard library, and
  re-parsing that exercises upstream's printing of libstdc++ rather than this
  feature. What is verified is that the three backtick lines print as
  themselves; the in-tree round trip is
  `clang/test/Parser/backtick-ast-print.cpp`'s own RUN line.
- **`getOperand`'s fallback is still the honest one and still untested for the
  re-keyed shape's edges.** A `CXXOperatorCallExpr` with `OO_Call` and fewer
  than three arguments cannot arise from this syntax — the form always passes
  two operands — but the guard is there because the alternative is reading
  `getArg(2)` out of range if it ever does.
- **Section 9's comment in `unicode-operator-precedence.cpp` is still stale**
  on all four branches, as four handoffs have now recorded.
