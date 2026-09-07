# Handoff — evidence-debt — The unbuilt hunk, the unwritten test, the unregenerable table

- **Status:** **DONE (gate passed on all four branches).**
- **Branch / commit:**
  - `backtick-trunk` — `2b7471f6bc13` (`~/src/llvm/backtick-trunk`) — the template `-ast-print` test
  - `backtick-23` — `99d75995e800` (`~/src/llvm/backtick`) — cherry-pick, gated independently
  - `unicode-operators-experiment` — `e88b87bef8b7` (`~/src/llvm/unicode`) — completion priority + its test
  - `unicode-operators-upstream` — `c0e07f78e679` (`~/src/llvm/unicode-upstream`) — byte-identical patch
  - `unicode-operators` (this repo) — the `docs:` and `ops:` commits listed at the end
- **Date / agent:** 2026-09-06.
- **Closes:** [`lldb-hunk-verification`](../../BACKLOG.md#lldb-hunk-verification),
  [`code-completion-priority`](../../BACKLOG.md#code-completion-priority),
  [`ucd-input-manifest`](../../BACKLOG.md#ucd-input-manifest),
  [`template-ast-print-test`](../../BACKLOG.md#template-ast-print-test).
- **Opens:** [`clang-slot-adl`](../../BACKLOG.md#clang-slot-adl) / [`clang-slot-adl`](../../DEVIATIONS.md#clang-slot-adl) — **P1, unowned, and the largest thing in this handoff.**

---

## The finding that is bigger than the step

**Clang does no argument-dependent lookup on the backtick slot, and in the
shape that matters it says nothing about it.**
[§17.4](../../../docs/backtick-operator-design.md#174-adl-is-normative-cross-compiler-note)
is *normative* — the slot must get the same ADL as the call it desugars to —
and its implementation-status paragraph reports the rule as delivered by both
compilers. It is not delivered by Clang, and never was.

It fell out of writing [`template-ast-print-test`](../../BACKLOG.md#template-ast-print-test)'s
test: an ADL shape was drafted for the template file, it did not compile, and
the control compiled. Measured on `backtick-trunk`, reproduced on
`backtick-23`, each row diffed against the spelled call:

| Shape | `f(x, y)` | `` x `f` y `` |
|---|---|---|
| Hidden friend `friend int hf(S, S)` | binds `hf` | **error:** *use of undeclared identifier 'hf'* |
| ADL-only namespace member | binds it | **error**, with a typo-correction note offering the qualified name |
| `::pick(double, double)` visible, `ns::pick(U, U)` reachable by ADL | binds **`ns::pick(U, U)`** | binds **`::pick(double, double)`** — **no diagnostic** |
| Same, with an overload *set* visible rather than one function | binds `ns::pick(U, U)` | binds `::pick(double, double)` — no diagnostic |
| In a template, name visible at definition, ADL candidate declared after | ADL at the point of instantiation | slot bound at *definition*; instantiation then fails *no viable conversion* |

**Rows three and four are the serious ones.** `` u `pick` u `` and
`pick(u, u)` call different functions and the compiler is silent. That is the
one thing the whole design promises cannot happen.

**Mechanism, one line deep.** `Parser::ParseRHSOfBinaryExpression` parses the
slot with `BacktickOp = ParseExpression()` (`clang/lib/Parse/ParseExpr.cpp`),
so a bare identifier reaches `Sema::ActOnIdExpression` with
`HasTrailingLParen = false`, and `Sema::UseArgumentDependentLookup`
(`SemaExpr.cpp:3269`) opens with `if (!HasTrailingLParen) return false;`.
Empty lookup then goes to `DiagnoseEmptyLookup` rather than to an ADL-enabled
`UnresolvedLookupExpr`. By the time `Sema::ActOnBacktickOperator` hands `Op`
to `BuildCallExpr` the name is resolved. This is
[gcc-slot-adl](../../gcc/DEVIATIONS.md#gcc-slot-adl) verbatim — *"the slot
arrived as a resolved `FUNCTION_DECL`"* — on the compiler that row records as
the one already getting it right.

**Why nine steps missed it.** No test on the backtick track has ever tried
pure ADL. `clang/test/SemaCXX/backtick-semantics.cpp` §2 is headed *"Qualified
callee (also exercises the ADL-adjacent case)"* and uses `` tx `ns::g` ty `` —
a **qualified** name, which correctly gets no ADL either way, so it passes
whatever the slot does. The file's header comment claims ADL is inherited;
nothing under it tests that.

**The within-compiler control, which makes this a design finding.** The
**Unicode** feature, same build, same machine, is correct: `s ⊞ s` finds a
hidden friend and `u ⊞ u` picks the ADL candidate over a visible
`operator⊞(double, double)`. Its slot never becomes an expression —
`CreateOverloadedUserOp` does its own `LookupOperatorName` and hands an
unresolved set to candidate assembly. **Two features, one compiler, one
difference: whether the slot reaches the call builder unresolved.** That is
the same sentence §17.4 already draws from GCC's two attempts, now with a
control that needs no second compiler.

**What was done about it, and what was deliberately not.** Not fixed — the
choice between fixing the slot and rewording §17.4 is the author's, and a fix
is a parser change on three branches. Recorded in full in
[`clang-slot-adl`](../../DEVIATIONS.md#clang-slot-adl) (measurements,
mechanism, both options with their costs) and as a P1
[backlog row](../../BACKLOG.md#clang-slot-adl). **§17.4 carries a dated
status-correction block** saying the next paragraph must not be written into a
paper and pointing at the ledger; the normative rule above it is untouched,
and the GCC half of the paragraph stands. That block is the one edit here that
exceeds the step file's scope, and it is there because the design doc is what
the papers are written from and it currently contains a false sentence about a
normative rule.

---

## The four rows

### [`lldb-hunk-verification`](../../BACKLOG.md#lldb-hunk-verification) — compiled, on both branches, under two compilers

`lldb/source/Plugins/ExpressionParser/Clang/ClangASTSource.cpp:125`'s
`case DeclarationName::CXXUserOperatorName:` — landed in `U06` commit
`9e4042cc2c76`, and until today the only hunk in the feature no compiler had
seen.

**Two trees, not one, and that is the finding to carry forward.** The step
file and BL07 both say to add `lldb` to BL04's CIR scratch dir and do both
branches there. The first half is right; the second is not, because
`build-cir-scratch` is configured against `~/src/llvm/unicode` alone. The two
Unicode branches sit on **different upstream bases** — 367 files differ under
`lldb/` between them — so a compile on one is not evidence for the other, even
though `ClangASTSource.cpp` is byte-identical on both (checked) and so is
`clang/include/clang/AST/DeclarationName.h`.

```bash
# experiment branch — BL04's standing tree, reconfigured in place
cmake -G Ninja -S ~/src/llvm/unicode/llvm -B ~/src/llvm/build-cir-scratch \
  -DLLVM_ENABLE_PROJECTS='clang;clang-tools-extra;mlir;lldb' \
  -DLLDB_ENABLE_PYTHON=OFF -DLLDB_ENABLE_SWIG=OFF \
  -DLLDB_ENABLE_LIBEDIT=OFF -DLLDB_ENABLE_CURSES=OFF -DLLDB_INCLUDE_TESTS=OFF
ninja -C ~/src/llvm/build-cir-scratch lldbPluginExpressionParserClang   # 3397 targets, EXIT=0

# upstream branch — a fresh tree, deleted afterwards (see "the machine", below)
cmake -G Ninja -S ~/src/llvm/unicode-upstream/llvm -B ~/src/llvm/build-lldb-scratch-upstream \
  -DLLVM_ENABLE_PROJECTS='clang;lldb' \
  -DLLDB_ENABLE_PYTHON=OFF -DLLDB_ENABLE_SWIG=OFF \
  -DLLDB_ENABLE_LIBEDIT=OFF -DLLDB_ENABLE_CURSES=OFF -DLLDB_INCLUDE_TESTS=OFF \
  -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=ON -DLLVM_TARGETS_TO_BUILD=host
ninja -C ~/src/llvm/build-lldb-scratch-upstream lldbPluginExpressionParserClang  # 3338 targets, EXIT=0
```

**What was checked, which is the part that matters.** The switch the hunk
joins is exhaustive over `DeclarationName::NameKind`, so a missing or
misplaced case is a `-Wswitch` warning. **`grep -c Wswitch` is 0 in both
builds.** The CIR tree's build log has no diagnostics of any kind. The
upstream tree's has 87 warnings, all from upstream code
(`-Wattributes` ×43, `-Wunused-variable` ×5, …), of which exactly one is in
`ClangASTSource.cpp` — `-Wcast-qual` at `:238`, on `(void *)decl` in
`FindCompleteType`, 113 lines from the hunk, and present identically in
`~/src/llvm/main`. The two trees also happen to use different host compilers
(`clang++-23` for the CIR one, `/usr/bin/c++` — GCC — for the new one), so
**the hunk is now known to compile clean under both.**

The two "compile-unverified" caveats in `REPLAY.md` are spent; the row's
`Closed by` and the new `REPLAY.md` section say so.

### [`code-completion-priority`](../../BACKLOG.md#code-completion-priority) — fixed, and the row's stated observable was wrong

The fix is the one `||` the row predicted:
`DeclarationName::CXXUserOperatorName` joins `CXXOperatorName`,
`CXXLiteralOperatorName` and `CXXConversionFunctionName` in `getDeclPriority`'s
`DC->isRecord()` arm, so a member user operator is `CCP_Unlikely` (80) rather
than `CCP_MemberDeclaration` (35).

**The gate the row designed cannot work.** It said: *"results are
priority-sorted (`CodeCompleteConsumer.cpp:645`), so an ordering-based test is
the observable"*. The `std::stable_sort` at that line calls
`clang::operator<(const CodeCompletionResult &, const CodeCompletionResult &)`
(`CodeCompleteConsumer.cpp:860`), which compares `getOrderedName()` with
`compare_insensitive` and **never reads `Priority`**. Sorting is alphabetical.
There is no ordering to observe, and a test built on one would pass with and
without the fix.

**The real observable is that `c-index-test` prints the priority**, in
parentheses at the end of each result line, and `clang/test/CodeCompletion/`
already has four tests that drive it (`preamble.c`, `pch-and-module.m`,
`macros-in-modules.{c,m}`), so no new machinery. `clang/test/CodeCompletion/unicode-operator-priority.cpp`
asserts the numbers directly. Before and after, same file, same source line,
member access on a class with a data member, `operator+`, a member
`operator⊞` and a member `operator⊖`:

```
                                     pre-fix        post-fix
FieldDecl mem_zzz                      (35)           (35)
FieldDecl member                       (35)           (35)
CXXMethod operator+                    (80)           (80)
CXXMethod operator⊖                    (35)           (80)
CXXMethod operator⊞                    (35)           (80)
```

Run against the pre-fix binary the file fails on exactly the last two `CHECK`
lines, with FileCheck naming `(35)` as the *"possible intended match"*. It
also pins the two data members at `(35)`, so a change that demoted every
member rather than the operators fails it too.

### [`ucd-input-manifest`](../../BACKLOG.md#ucd-input-manifest) — and the tables do regenerate, byte for byte

- **[`docs/ucd-17.0.0.sha256`](../../../docs/ucd-17.0.0.sha256)** — the five
  inputs, in `sha256sum` **check format**, so `sha256sum -c` reads it directly
  (comment lines are ignored by both readers). Each hash is preceded by its
  version-pinned URL; the header carries each file's own `# Date:` line and
  byte size, and notes that `UnicodeData.txt` is the one input with no date
  header at all, so its hash is the only handle on it.
- **`--verify-manifest`** in `docs/pattern-syntax-audit.py` (~55 lines), and
  **`--emit-header` implies it** — a generated header whose inputs were not
  the published 17.0.0 bytes is not reproducible and should not be committed.
  `--no-verify-manifest` is the escape hatch, and is what auditing a
  *different* UCD version deliberately looks like. A plain audit run with no
  flags is unchanged.

**Verified, in the direction the handoffs README asks for — what was checked,
not only what was changed:**

| Check | Result |
|---|---|
| Re-fetch all five from unicode.org, 2026-09-06 | 5/5, `curl` clean |
| `sha256sum -c docs/ucd-17.0.0.sha256` in the fetch dir | 5/5 `OK` |
| Regenerate `UnicodeOperatorCharSets.h` and diff against the committed one | **byte-identical**, `sha256 52ccbd15e26b…`, and the two Unicode branches' committed copies are the same bytes as each other |
| Refusal: append one comment line to `PropList.txt` | `EXIT=1`, **0 bytes on stdout** — it refuses *before* deriving |
| Refusal: input missing from the directory | `EXIT=1`, four `missing from` lines |
| `--no-verify-manifest` on the tampered tree | still derives |

`docs/unicode-operators.md` §4 gains a paragraph saying this, immediately
before the "One more consequence of R3c" paragraph — the reproducibility
claim is now *checked* rather than asserted, which is what BL07 asked to be
captured if it held.

**Not done, deliberately:** the generator still spells `U1` and `U10` in the
strings it emits into the committed header. [slug-the-ledgers](slug-the-ledgers.handoff.md)
recorded that as an explicit exclusion and flagged it to this step; renaming
them would make the regenerated header differ from the committed one on both
branches, for nothing. The exclusion stands.

### [`template-ast-print-test`](../../BACKLOG.md#template-ast-print-test) — and the negative control is the evidence

`clang/test/AST/backtick-template-print.cpp`, on both backtick branches. A new
file rather than an extension of `clang/test/Parser/backtick-ast-print.cpp`,
because that file's second RUN line re-parses the whole printed output and
`-ast-print` emits both `template<> struct Box<int> { … }` and the `template
struct Box<int>;` that caused it — re-parsing that pair warns
(`-Winstantiation-after-specialization`), which the new file suppresses on its
own RUN line and explains in a comment.

**The observable is that `-ast-print` prints instantiated class-template
member bodies as well as patterns**, so a printed specialization that still
says `` a `add` b `` is `TransformBacktickInfixExpr`'s output coming back out
in the written form. Five shapes: a function-template pattern; a class
template printed as pattern *and* instantiation, including a class-typed
result so the wrapper's subexpression is a `CXXBindTemporaryExpr` again after
substitution; a slot that is a template *parameter*; a dependent qualified
slot; and the type slot substituted from `CXXUnresolvedConstructExpr` to
`CXXTemporaryObjectExpr`.

**Proven load-bearing, and the shape of the proof is the point.** With
`TreeTransform<Derived>::TransformBacktickInfixExpr` altered to
`return Inner;` — dropping the wrapper at instantiation — and clang rebuilt:

```
new  clang/test/AST/backtick-template-print.cpp     FAIL
old  clang/test/Parser/backtick-ast-print.cpp       PASS
```

The printed output shows exactly why: patterns still print
`` a `add` b ``, `` a `mk` b ``, `` a `f` b ``, `` a `T` b ``, while every
*instantiation* reverts to `add(a, b)`, `mk(a, b)`, `f(a, b)`, `Pair2(a, b)`.
**The old file cannot see the difference at all**, which is the hole the row
described. `clang/lib/Sema/TreeTransform.h` was restored and verified
byte-identical (`git diff --stat` empty) and clang rebuilt before the gate.

Explicit return types throughout, per
[`auto-return-round-trip`](../../BACKLOG.md#auto-return-round-trip). A pack
shape was drafted and dropped: `-ast-print` emits `template<> int
sum<<int>>(int a);` for a variadic specialization, an upstream printing bug
with nothing to do with backtick.

---

## Verification evidence — the four gates

All unfiltered, `ulimit -c 0`, exit code captured explicitly, run
back-to-back on a settled machine.

| Branch | Discovered | Passed | Failed | XFAIL | Unsupported | Skipped | `EXIT` |
|---|---|---|---|---|---|---|---|
| baseline `backtick-trunk` | 54109 | 48223 | 0 | 27 | 5853 | 6 | — |
| **after** | **54110** | **48224** | **0** | 27 | 5853 | 6 | **0** |
| baseline `backtick-23` | 54343 | 48501 | 1 | 27 | 5808 | 6 | — |
| **after** | **54344** | **48502** | **1** | 27 | 5808 | 6 | **1** |
| baseline `unicode-operators-experiment` | 54183 | 48295 | 0 | 27 | 5855 | 6 | — |
| **after** | **54184** | **48296** | **0** | 27 | 5855 | 6 | **0** |
| baseline `unicode-operators-upstream` | 54241 | 48323 | 0 | 27 | 5885 | 6 | — |
| **after** | **54242** | **48324** | **0** | 27 | 5885 | 6 | **0** |

**+1 discovered / +1 passed on every branch and nothing else moves.** One lit
test file each; unsupported does not move, because these are ordinary lit
tests and not `clang/test/CIR/` ones. `backtick-23`'s single failure is
[`stray-clang-format-config`](../../BACKLOG.md#stray-clang-format-config),
expected there, so its `EXIT=1` is the baseline.

### The machine — cause found rather than waited out

**The first `backtick-trunk` gate reported 6 failures and all six were
`DirectoryWatcherTest.*` with `No space left on device :
inotify_add_watch()`.** Confirmed as the plan requires and **not** filtered,
**not** budgeted: all **8** cases failed on the pristine
`~/src/llvm/build-main` binary at that moment.

This is the fourth consecutive Clang step to meet these tests, and the first
where the cause was **this step's own doing**: `~/src/llvm/build-lldb-scratch-upstream`
had just materialised 2247 directories, and `cloud-drive-dae` watches every
one. Removing the tree — its job was done, the compile evidence is above —
made all 8 pass on `build-main` **immediately**, on the next invocation. The
re-run of all four gates is the table above.

**The lesson worth carrying:** the budget is a shared resource and a scratch
build tree is a large withdrawal from it. `~/src/llvm/build-cir-scratch` is
standing and paid for; a *second* scratch tree should be deleted the moment
its evidence is recorded, and this one was.

### What else was checked

- **Formatting.** `git-clang-format --diff` with each branch's own in-tree
  `clang-format`: *clang-format did not modify any files* on both Unicode
  branches (the production edit is theirs); *no modified files to format* on
  the backtick branches, whose only change is a new test file. Nothing under
  `clang/lib/Format/` or `clang/unittests/Format/` was touched, so the
  self-format step at ~81/970 was never in play.
- **Build logs warning-free** on both Unicode branches.
- **The two Unicode patches are byte-identical**, verified by diffing the two
  `git show --format=` outputs, not by trusting the cherry-pick.
- **The backtick test file is byte-identical** on the two branches, and the
  `backtick-23` commit is a real cherry-pick with identical patch text.
- **U20's invariant holds, measured the right way — and the way it is
  usually measured is now wrong.** `git log -p
  upstream/main..unicode-operators-upstream | grep -ic backtick` is **0**
  across all 19 branch commits. The two-dot `git diff` form returns **6**,
  and every one is upstream's own drift, because `upstream/main` has moved
  ahead of the branch base (`72417eb739e5`): a shell-quoting local
  `arg_has_backtick` in `lldb/source/Interpreter/Options.cpp` and five lines
  about Markdown fences in `llvm/docs/SphinxQuickstartTemplate.md`. Fetching
  upstream will keep moving the first number and never the second.
  `REPLAY.md` records the restatement, because an agent who runs the two-dot
  form and finds hits has found a fetch, not a regression.
- **Links.** 650 local Markdown links in the six edited files, **0 broken**,
  checked with the GitHub slug rule (runs of whitespace are *not* collapsed —
  see [null-return-suppression](null-return-suppression.handoff.md)'s caveat).

---

## Rows closed, and where each landed

| Row | Destination |
|---|---|
| [`lldb-hunk-verification`](../../BACKLOG.md#lldb-hunk-verification) | Its `Closed by` cell; `ops/unicode-operators/clang/REPLAY.md`, the new **"evidence-debt"** section, **the paragraph beginning "`lldb` is not a replay row"** — which retires the two "compile-unverified" caveats that file carried |
| [`code-completion-priority`](../../BACKLOG.md#code-completion-priority) | Its `Closed by` cell, **plus a new `Correction` paragraph before it** retracting the ordering-based observable; `REPLAY.md`'s new section, **the paragraph beginning "The one thing a replay must not inherit"** |
| [`ucd-input-manifest`](../../BACKLOG.md#ucd-input-manifest) | Its `Closed by` cell; `docs/unicode-operators.md` **§4, the new paragraph immediately before "One more consequence of R3c worth stating"** |
| [`template-ast-print-test`](../../BACKLOG.md#template-ast-print-test) | Its `Closed by` cell. No design-doc destination: it is verification debt, not a claim, and the design says nothing about it that needed changing |

**Opened:** [`clang-slot-adl`](../../BACKLOG.md#clang-slot-adl) (backlog, P1,
`Closed by` **— unowned**) and
[`clang-slot-adl`](../../DEVIATIONS.md#clang-slot-adl) (backtick ledger,
`Status: OPEN`), plus a paragraph in `ops/BACKLOG.md` §7 placing it above
everything else still open on that scale, and a Coverage-table row in
`ops/completion/PLAN.md` saying it has no step. `docs/backtick-operator-design.md`
**§17.4** carries a dated status-correction block immediately before the
implementation-status paragraph.

**No deviation row's `Status:` changed.** Nothing this step touched was one of
the 29 open deviation rows.

---

## Deviations from the step file

1. **[`code-completion-priority`](../../BACKLOG.md#code-completion-priority)'s
   observable is not what the step file says.** *"Results **are**
   priority-sorted (`CodeCompleteConsumer.cpp:645`), so an ordering-based test
   is the observable. Write that test."* The sort is by **name**. Written as
   a direct assertion of the printed priority instead; the step file inherited
   the claim from the row, and the row's `Correction` paragraph now retracts
   it.
2. **[`lldb-hunk-verification`](../../BACKLOG.md#lldb-hunk-verification) took
   two trees, not one.** The step file says to add `lldb` to the standing CIR
   configure "rather than creating a second scratch tree"; that dir is bound
   to `~/src/llvm/unicode`, and the two Unicode branches are on different
   bases. Followed for the experiment branch, and a second tree stood up —
   and then deleted — for the upstream one.
3. **The test landed in `clang/test/AST/`, not as an extension of the existing
   Parser file**, for the re-parse reason above.
4. **§17.4 was edited**, which no row here asked for. It is a *flag*, not a
   rewrite: it does not choose between the two options and leaves the
   normative rule alone. The alternative was leaving a false sentence about a
   normative rule in the document both papers are written from, with three
   plan steps still to run over it.

---

## Discoveries affecting later steps

- **Diffing the operator form against the spelled call has now found four
  defects across two tracks**, and this is the first that is *silent*.
  [null-return-suppression](null-return-suppression.handoff.md) said the
  technique was cheap and worth a sentence in the paper; it is cheaper than
  that. [`clang-slot-adl`](../../DEVIATIONS.md#clang-slot-adl) cost four lines
  of C++ and one `-ast-dump`.
- **`c-index-test` prints information the `-cc1` printers do not.** Priority is
  one; the completion *kind* (`CXXMethod:`, `FieldDecl:`) is another. Any
  later question about how the feature looks to an editor should reach for it
  before concluding the state is unobservable — that conclusion is what
  deferred [`code-completion-priority`](../../BACKLOG.md#code-completion-priority)
  six times.
- **`-ast-print` prints instantiated class-template member bodies but not
  instantiated *function*-template bodies.** `template int fn<int>(int, int);`
  prints as a declaration only. So a round-trip assertion about a transformed
  expression has to be made through a **class** template. This is why the new
  test's centre of gravity is `Box<int>` and not `fn<int>`.
- **A scratch build tree costs the machine ~2200 inotify watches** and the
  budget has no headroom. See "the machine" above.
- **All four build dirs are current** at the new commits, and
  `~/src/llvm/build-cir-scratch` now also has `lldb` in its projects (its CIR
  configuration is otherwise untouched, so BL04's arithmetic still holds).

---

## Forward notes for the NEXT step — [reconcile-implementation-cost](../steps/reconcile-implementation-cost.md)

Read after reading its step file.

- **Your dependency is discharged.** Nothing in U§8 will now cite a
  measurement that is owed. The two numbers this step was told you would want
  are unchanged by it: [`analysis-layer-sites`](../../DEVIATIONS.md#analysis-layer-sites)'
  true count is **seven**, and
  [`expression-node-cost`](../../unicode-operators/clang/DEVIATIONS.md#expression-node-cost)
  has an obligation off its link/unreachable/warning/silence axis, created by
  *meeting another obligation*. Both still carry their dated Notes from
  null-return-suppression and both are still `OPEN`.
- **You have a fifth thing to say about the taxonomy, and it is free.**
  [`code-completion-priority`](../../BACKLOG.md#code-completion-priority) is a
  clean instance of the *"forced by nothing at all and silently wrong if
  omitted"* category — a `NameKind` chain in `getDeclPriority` that no
  `-Wswitch` covers because it is an `||` over equality tests, not a `switch`.
  Six steps walked past it. If U§8 wants a *human*-scale example of the
  thirteen silent sites, this is the most legible one in the whole record: the
  cost of missing it is not a crash, it is that an editor offers `operator⊞`
  ahead of a data member forever.
  **And its sibling shape is the refusal pattern again** — the priority table
  is keyed on a closed set of name kinds, so opening it is one more `||`, never
  a mechanism.
- **[`serialization-tooling-cost`](../../unicode-operators/clang/DEVIATIONS.md#serialization-tooling-cost)
  can now be said to be complete in a way it could not before.** The lldb hunk
  was the one site in the whole `NameKind` list that had never been compiled;
  it now has been, under two compilers, and the `-Wswitch` category is
  therefore *measured* rather than assumed for that site. If U§8 states "33
  sites over `NameKind`", it can now add that every one of them has been
  through a compiler.
- **Do not restate §17.4 or ADL.** U§8 is the Unicode implementation-cost
  section and the Unicode feature's ADL is *correct* — that is the control in
  [`clang-slot-adl`](../../DEVIATIONS.md#clang-slot-adl), and the contrast
  belongs to [reconcile-remainder](../steps/reconcile-remainder.md) and the
  backtick paper, not to U§8. What U§8 *may* fairly say, and
  [`infix-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost)
  already measured, is that the non-member half was free **because** the slot
  never becomes an expression. That sentence is now backed by a compiler that
  gets it wrong the other way.
- **U§4 has a new paragraph** (the reproducibility one). It is not yours, but
  it sits next to
  [`ucd-version-drift`](../../unicode-operators/clang/DEVIATIONS.md#ucd-version-drift)'s
  recommended U§4 note, which is **still unwritten** and belongs to
  [reconcile-declaring-using](../steps/reconcile-declaring-using.md). Do not
  write it on their behalf; do not delete the paragraph that is there.
- **No build, no branch, no gate.** Your gate is that all eight rows carry
  `**RECONCILED**` and name the paragraph. The Unicode ledger has never marked
  a row, so you will be the first to write those markers; the field and the
  words are already in the file's other entries.

---

## Open risks / TODOs

- **[`clang-slot-adl`](../../BACKLOG.md#clang-slot-adl) has no owner and
  gates [backtick-paper](../steps/backtick-paper.md).** It needs the author,
  and the question is a real fork: fix Clang's slot, or reword a normative
  claim. Do not let a paper step reach §17.4 before it is answered.
- **A forward-port to `unicode-operators-experiment` is now outstanding
  again** — `clang/test/AST/backtick-template-print.cpp` is on the two
  backtick branches and not on the experiment branch, which carries the
  backtick feature too. It is a test-only file and will arrive with the next
  backtick merge (the M2 shape); it was deliberately **not** added directly to
  the experiment branch, because a file added independently on both sides of
  that merge conflicts. `unicode-operators-upstream` must never receive it.
- **Nothing is pushed on any branch.** All five (four LLVM + this repo) are
  ahead of every remote, as they were before.
- **The Unicode-branch comment divergence from M2 is still open** —
  `unicode-operators-upstream` still carries the stale
  `CheckUserOperatorDeclaration` comment at `SemaDeclCXX.cpp:17209` that
  `de76585ae45d` fixed on the experiment branch. Untouched here, as by the
  three steps before.
- **`~/src/llvm/build-cir-scratch` now has `lldb` in `LLVM_ENABLE_PROJECTS`.**
  Harmless — nothing rebuilds lldb unless asked — but it is no longer exactly
  the tree BL04 configured, and a `ninja check-clang` there would now also
  configure lldb targets. Its CIR settings are untouched.
