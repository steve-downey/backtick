# C01 — File the upstream defects: `B25`, `B38`, `B26`

**Goal.** Three defects that are LLVM's, not this feature's, stop being
private notes in `ops/` and become issues the papers can cite.

**Depends on:** nothing.
**Closes:** `B25`, `B38`, `B26`.

Placed first in the plan not because it is urgent but because **an issue takes
calendar time to be triaged**, and C04 and C15 both want to cite one. Nothing
lands on any feature branch. This step writes no compiler code.

## Do

### 1. `B25` — the `operator++` / `operator--` mangling divergence (P1)

**Execute `ops/backlog/steps/BL05-upstream-mangling.md` exactly as written.**
It is a complete step file: the reproducer, both compilers' symbols, the three
things `BACKLOG.md` does not carry (the `operator--` twin, LLVM's demangler
already implementing what its mangler cannot emit, the two localized mangler
sites), and the instruction not to attach a patch. Do not restate it here and
do not improve on it.

One correction to its closing note: the three places it asks you to update
afterwards **all exist** — `docs/unicode-operators.md`, `papers/dxxxxr0.md`,
and `DEV-U23` clause (c) — but its line numbers predate BL02 and BL04. Search
for the text.

### 2. `B38` — `emitLValue`'s crash-on-default (new, found by BL04)

`CIRGenFunction::emitLValue`'s default arm emits
`errorNYI("emitLValue: unsupported l-value class")` and then `return LValue()`.
That `LValue` carries a null `QualType`, which asserts downstream in
`QualType::getCommonPtr`. So the one path in ClangIR that is *meant* to be a
hard diagnostic aborts instead.

Carry into the report what makes it credible: **two unrelated expression
classes abort identically at that arm.** BL04 measured it with
`BacktickInfixExpr` and `UserOperatorExpr`, which share no code and no flag,
and got the same assertion — that is what localizes it to the arm rather than
to a node. Say that it is reachable only in a `CLANG_ENABLE_CIR=ON` build,
which is why it has not been hit, and that any `Expr` class missing from that
switch in l-value position reaches it.

**Do not propose the fix.** Whether the default should diagnose-and-recover
(with what `LValue`?) or `llvm_unreachable` is upstream's design call, and the
CIR project is mid-bring-up. Report the shape and stop.

Reproducing it needs a CIR build. `~/src/llvm/build-cir-scratch` is standing
and has one — but it is `unicode-operators-experiment`, so **the reproducer in
the issue must not use either feature.** Find an `Expr` class that is absent
from that switch and can be an l-value in plain C++, and check the reproducer
against a *clean* trunk CIR build or against upstream's own CI, not against
that scratch dir.

### 3. `B26` — `ParseExprCXX.cpp:2297` reads the wrong union member

For `IK_LiteralOperatorId`. U07 guarded the new kind rather than fixing
upstream's read, so it is latent: the next person to add a `UnqualifiedId`
payload hits it first. Small, self-evident, and the kind of thing that gets
fixed the day it is reported. Confirm the line still says what U07 said it
said — it will have moved.

## Verify (gate)

- No `check-clang`. Nothing is committed to any feature branch — confirm with
  `git status` in all five worktrees and say so.
- Three issue URLs, recorded in the handoff and in each row's `Closed by` cell.
- Each reproducer re-confirmed against **current** trunk, not against a
  worktree base. `~/src/llvm/main` is the pristine tree: fetch it to see how
  stale it is, run its binaries, do not build in it.
- Search for an existing issue before filing each one.

## Capture in handoff

The three URLs and the trunk revision each was confirmed against. Then update
`docs/unicode-operators.md`, `papers/dxxxxr0.md` and `DEV-U23` (c) to cite the
`B25` issue by number, per BL05's own instruction — a paper that says "we found
a Clang bug" is stronger when it can say which one.
