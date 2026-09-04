# Handoff — BL04 `B15`: build ClangIR and close the unknown

- **Status:** DONE (gate passed on all four branches)
- **Branch / commit:**
  - `unicode-operators-experiment` — `6ee1358f7b47` (both halves)
  - `unicode-operators-upstream` — `783a9c1a5f6f` (`UserOperatorExpr` only)
  - `backtick-trunk` — `cfbc69be9d4f` (`BacktickInfixExpr` only, closes `B36`)
  - `backtick-23` — `1cf901e79df4` (same hunks)
- **Date / agent:** 2026-09-03

## What changed

**Four ClangIR dispatch sites, per node.** On the experiment branch both nodes
get all four, because that branch carries both features; the other three
branches get one node's half each.

| File | Site | `BacktickInfixExpr` | `UserOperatorExpr` |
|---|---|---|---|
| `CIRGenExprScalar.cpp` | `VisitBacktickInfixExpr` / `VisitUserOperatorExpr` | `Visit(e->getSubExpr())` | `Visit(e->getSemanticForm())` |
| `CIRGenExprAggregate.cpp` | same pair | `Visit(e->getSubExpr())` | `Visit(e->getSemanticForm())` |
| `CIRGenExprComplex.cpp` | same pair | `Visit(e->getSubExpr())` | `Visit(e->getSemanticForm())` |
| `CIRGenFunction.cpp` | `emitLValue` | `emitLValue(getSubExpr())` | `emitLValue(getSemanticForm())` |

New tests: `clang/test/CIR/CodeGen/unicode-operator.cpp` (+84) and
`clang/test/CIR/CodeGen/backtick-infix.cpp` (+63). Neither runs unless a build
sets `CLANG_ENABLE_CIR` — `clang/test/CIR/lit.local.cfg` sets
`config.unsupported` otherwise.

Also, before any of that: **`be2670c2513f` (BL03, experiment branch) carried
only its test file.** Its six analyzer arms were still uncommitted in
`~/src/llvm/unicode`. Committed unchanged as `d4afcba409a6`; BL03's Status row
in `ops/backlog/PLAN.md` is annotated. BL03's recorded gate stands — it was run
against exactly that working tree, and the binary it produced still passes
`clang/test/Analysis/unicode-operator-analysis.cpp`, which fails without the
arms. The `unicode-operators-upstream` commit `6428404d98a5` was complete all
along. **Check `git status` in all four worktrees before starting a step.**

## Verification evidence

### The build

```
cmake -G Ninja -S ~/src/llvm/unicode/llvm -B ~/src/llvm/build-cir-scratch \
  -DLLVM_ENABLE_PROJECTS='clang;clang-tools-extra;mlir' -DCLANG_ENABLE_CIR=ON \
  -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_TARGETS_TO_BUILD=host \
  -DCMAKE_C_COMPILER=/usr/bin/clang-23 -DCMAKE_CXX_COMPILER=/usr/bin/clang++-23
```

Configure 105 s; `ninja clang` **5428 edges**, clean. The four production build
dirs were **not** touched by the configure, and their gates below prove it.

### The probes, before the fix — four sites, four different failures

| Shape | Diagnostic |
|---|---|
| scalar | `error: … Not Yet Implemented: scalar expression kind: : UserOperatorExpr` |
| aggregate | `… Not Yet Implemented: AggExprEmitter::VisitStmt: UserOperatorExpr` |
| complex | `error: cannot compile this complex expression yet` — **does not name the node** |
| l-value | `… Not Yet Implemented: emitLValue: unsupported l-value class`, **then `Assertion !isNull() && "Cannot retrieve a NULL type pointer" failed`** |

`BacktickInfixExpr` gives the identical four, naming itself. After the fix all
nine shapes (five unicode incl. prefix, four backtick) compile clean.

### The parity result

`op_form` and `call_form` emit **instruction-for-instruction identical** CIR —
same `cir.alloca`s, same `cir.load`s, same `cir.call` to the same mangled
callee, in the same order — for every shape, l-value included, where the store
lands through the pointer the operator returns:

```
%4 = cir.call @_Zv28op_u22A0R3Boxi(%2, %3) : … -> !cir.ptr<!s32i>
cir.store align(4) %1, %4 : !s32i, !cir.ptr<!s32i>
```

### The gates

| Build dir | D | P | F | X | U | S | Exit |
|---|---|---|---|---|---|---|---|
| `build-cir-scratch` | 54227 | 49227 | **0** | 27 | 4967 | 6 | 0 |
| `build-unicode` | 54183 | 48295 | **0** | 27 | 5855 | 6 | 0 |
| `build-unicode-upstream` | 54241 | 48323 | **0** | 27 | 5885 | 6 | 0 |
| `build-backtick-trunk` | 54108 | 48222 | **0** | 27 | 5853 | 6 | 0 |
| `build-backtick` | 54342 | 48500 | **1** (`B33`) | 27 | 5808 | 6 | 1 |

The four production dirs are their BL01/BL03 baselines **+1 discovered / +1
unsupported** each (+2 on the experiment branch, which gets both tests) with
**passed unchanged** — the signature of a test that is `Unsupported` in that
configuration. `backtick-23`'s single failure is
`Clang :: Format/dump-config-objc-stdin.m`, the documented `B33` artifact.

## Deviations from the plan / design

**`ops/DEVIATIONS.md` DEV-09** (backtick) and
**`ops/unicode-operators/clang/DEVIATIONS.md` DEV-U24** (Unicode).

1. **`B15` said the CIR fallbacks were `errorNYI` "rather than crashes". Wrong
   for one site in four.** `emitLValue`'s default arm returns a
   default-constructed `LValue`, whose null `QualType` asserts in
   `QualType::getCommonPtr`. An l-value-returning operator **aborted the
   compiler** after printing the NYI line. Both nodes do it identically, which
   is what localizes it to the default arm rather than to either wrapper — an
   upstream observation, independent of both features.
2. **The fourth arm is not the copy-paste the step predicted.** Copying the
   `CXXRewrittenBinaryOperator` arm would have kept the diagnostic. The
   wrappers have an answer instead: an operator returning a reference is a
   call returning a reference, and `emitLValue`'s `CallExpr` classes four
   lines above already handle it. So they recurse.
3. **DEV-U13's site count moves 28 → 32 over 20 → 21 files, and gains a
   category.** The taxonomy sorted sites by whether the *build* forces them
   (6 link errors, 8 exhaustive switches, 2 `-Wswitch`, 13 silent). These four
   are forced by nothing at compile time and fail loudly at run time — a fifth
   kind, *latent behind a build configuration*. What hid them was a CMake
   default, not a visitor design.
4. **`B31` is REOPENED.** See below.

## Discoveries affecting later steps

- **`B31`'s root fix did not hold, and the reason matters.** BL04's first gate
  failed all 8 `DirectoryWatcherTest.*` with `No space left on device :
  inotify_add_watch()`. `sysctl fs.inotify.max_user_watches` still reported the
  raised **524288** — and `cloud-drive-dae` was holding **523,774** of it. The
  daemon grew into the new budget; the "8× headroom" argument was wrong.
  Confirmed environmental exactly as before: all 8 fail on the maintainer's
  untouched `~/src/llvm/build-main` binary. It stays *intermittent* — two later
  full runs the same day gave **0** failures (the scratch gate) and **3**
  (`build-unicode`, run concurrently with it), and all five gates above ran
  clean. **Still do not filter them and do not budget them as expected
  failures**; a gate failing only these 8 is an environment reading.
  **`cloud-drive-dae` is the machine's continuous backup**, so watching every
  file is its job and its hoard tracks the file count — it will grow into any
  ceiling. 524288 is a plausible ceiling for this tree where the 65536 default
  plainly was not, so the sysctl fix was right and stays; it just cannot be a
  guarantee. Free watches are a shared, load-dependent resource and these 8
  tests are the only thing in `check-clang` that competes for it. Raising the
  ceiling again is the lever if it recurs, and that needs root.
- **The scratch dir is standing and reusable**, `~/src/llvm/build-cir-scratch`,
  pointed at `~/src/llvm/unicode`. It has `clang`, `FileCheck`, `count`, `not`,
  `split-file` and a full `check-clang` dependency set. **BL07 needs a scratch
  dir too**; the step file suggested combining the configures, and that is no
  longer possible for free — but adding `lldb` to *this* one and rebuilding is
  much cheaper than a fresh tree.
- **One CIR build covers both features.** `unicode-operators-experiment`
  carries backtick *and* Unicode, so `B15` and `B36` were measured, fixed and
  tested in a single build. The single-node forms that land on the other three
  branches were each produced *in that tree* by removing the other node's
  arms, rebuilt (7–19 edges, under a minute) and re-run — each variant passes
  its own test and fails the other's — and the resulting `+` lines were diffed
  against the target worktrees before committing. **Do not point a second
  configure at `~/src/llvm/backtick-trunk` for this; it buys nothing the strip
  test does not.**
- **Enabling CIR changes the gate arithmetic by more than the CIR directory.**
  Against the same source tree: discovered **+44** (the `CIRUnitTests` gtest
  cases — 22 lit shards — which exist only with `CLANG_ENABLE_CIR`),
  unsupported **−888**, passed **+932**. The unsupported term is
  −889 (`clang/test/CIR`: 908 discovered, 908 unsupported → 19) **+1**, and
  that +1 is `clang/test/Frontend/cir-not-built.c`, which requires CIR to be
  **off**. Don't chase it as a regression.
- **`llvm-lit` on a fresh scratch dir needs `ninja FileCheck count not
  split-file` first**, or it aborts with "Did not find FileCheck"; a full
  `check-clang` builds them anyway.
- **`git checkout HEAD~1 -- <path>` stages as well as updates the worktree**,
  so a later `git checkout -- <path>` restores the *old* content from the
  index, not `HEAD`. Use `git checkout HEAD -- <path>` to get back. Cost a
  rebuild here.

## Forward notes for the NEXT step (BL05 — `B25`, the upstream mangling report)

Read after `steps/BL05-upstream-mangling.md`:

- **BL05 touches no branch and needs no build**, which makes it the cheapest
  remaining step by a wide margin — nothing in it depends on BL04.
- **It does need *current* trunk**, and the step says so twice. Note that
  `~/src/llvm/build-main` / `~/src/llvm/main` is the maintainer's pristine
  pair and **must not be disturbed** — but *running* its `bin/clang` is
  read-only and is exactly how BL04 confirmed the `DirectoryWatcherTest`
  failures were environmental. Use it that way for the reproducer, and fetch
  to check how stale it is before claiming "current trunk"; do not build in it.
- **`~/src/llvm/build-cir-scratch` is a second trunk-ish binary** (it is
  `unicode-operators-experiment`, so *not* clean trunk — do not use it for the
  reproducer). Mentioned only so you do not mistake it for one.
- The step wants the ABI paragraph for the `<expression>` production. LLVM's
  own demangler comment (`llvm/include/llvm/Demangle/ItaniumDemangle.h`, the
  `pp_` / `mm_` grammar lines) is the corroboration, not the citation.
- After filing, the step asks you to update three places that hold this as a
  private note. **All three paths are live in this repo** — `docs/unicode-operators.md`,
  `papers/dxxxxr0.md` and DEV-U23 clause (c) in
  `ops/unicode-operators/clang/DEVIATIONS.md` — but the line numbers the step
  quotes are from before BL02 and BL04 edited neighbouring files, so search for
  the text rather than seeking to `:807` and `:715`.

## Open risks / TODOs

- **Nothing is pushed on any branch.** All four are ahead of every remote, and
  now by one more commit each.
- **`B31` is open again, and is an environment condition rather than a bug to
  fix.** `cloud-drive-dae` is the continuous backup and legitimately scales
  with the tree, so no ceiling is permanent; 524288 is at least a plausible
  one. Raising it further needs root and is the maintainer's call.
- **`B37` is still unowned** (BL03 found it; its fix lands on four branches and
  changes `backtick-infix.cpp`'s `bugs_are_still_found` premise).
- **`M2` is still blocked on `BL06`.** Note that BL04 has now put CIR arms on
  `backtick-trunk` that the experiment branch already has, so M2's merge will
  meet them. They are the same lines in the same place, plus the experiment
  branch's shared lead comment — expect a trivial conflict there, not a
  semantic one.
- **`emitLValue`'s crash-on-default is an upstream defect nobody has
  reported.** It is not ours, it is not gated behind either flag, and BL05 is
  the template for what to do with such a thing. Not scheduled.
