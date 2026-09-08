# Handoff — unicode-branch-maintenance — the queued forward-port, and the comment the other branch still had

- **Status:** **DONE (both gates passed).**
- **Branch / commits:**
  - `unicode-operators-experiment` (`~/src/llvm/unicode`) — `7278a2985659`, the merge commit
  - `unicode-operators-upstream` (`~/src/llvm/unicode-upstream`) — `8c2a90f56b00`, the comment fix
  - `unicode-operators` (this repo) — the `ops:` commit carrying this file, the
    [`REPLAY.md`](../../unicode-operators/clang/REPLAY.md) section, the Baselines
    update and the Status-log rows
- **Date:** 2026-09-07.
- **Not a plan step.** Like `M1`, `M2` and the R-prefixed rebases it gets a
  handoff, a Status-log row in [`ops/completion/PLAN.md`](../PLAN.md) and in
  [`ops/unicode-operators/clang/PLAN.md`](../../unicode-operators/clang/PLAN.md),
  and a `REPLAY.md` section. It does not follow `ops/AGENT_PROTOCOL.md`'s step
  loop, adds no feature, and **ticks no checkbox** —
  [`ops/completion/PLAN.md`](../PLAN.md) is complete and stays complete.

---

## Job 1 — the merge

`git merge --no-ff c0d69702b6d7` on `unicode-operators-experiment`: the
explicit commit, not the branch name, as
[M1's handoff](../../unicode-operators/clang/handoffs/M1-forward-port.handoff.md)
insists and [M2](M2-forward-port.handoff.md) repeated. The tip was confirmed
first. Merge base was `5f70443430b8` — M2's merge — so the four commits it
brought were exactly the four that had accumulated since:

| Commit | What | Why it was deferred |
|---|---|---|
| `c1c6af4dd620` | [null-return-suppression](null-return-suppression.handoff.md) — the **backtick** half of the `peelOffOuterExpr` fix | this branch had already landed both halves in its own `1f0790897357` |
| `2b7471f6bc13` | [evidence-debt](evidence-debt.handoff.md) — `clang/test/AST/backtick-template-print.cpp` | a file added independently on both sides of a merge conflicts |
| `9504b2c1fc51` | [clang-slot-adl](clang-slot-adl.handoff.md) — `Parser::TryParseBacktickCalleeSlot` | to ride one merge |
| `c0d69702b6d7` | [hygiene-parity](hygiene-parity.handoff.md) — the tooling surface, the dead diagnostic, the slot penalty | same |

**`clang-slot-adl` is the one that changes behaviour here.** Until this merge
the branch's backtick slot did no argument-dependent lookup, so
`` u `pick` u `` could bind a different overload from `pick(u, u)` **with no
diagnostic**. It now carries `TryParseBacktickCalleeSlot` and
`clang/test/SemaCXX/backtick-adl.cpp`, and both of that test's `static_assert`
discriminators pass. The branch's *Unicode* operator never had the defect and
still does not — its slot never becomes an expression.

## The conflicts, and how each was resolved

**Seven conflicts, in three groups, and none of them was semantic.** No fix in
the four commits reaches `UserOperatorExpr`, and the resolutions are checkable
in one number: the merge is 17 files, **+484/−14**, and **all 14 deleted lines
are backtick text** — the withdrawn `err_backtick_nested_requires_parens`,
three `// D8:` comments hygiene-parity renamed to slugs, the
`BacktickOp = ParseExpression()` line clang-slot-adl replaces, and four lines
of stale test prose. No Unicode line was moved, reworded or removed.

### Both sides added at the same anchor — keep both, backtick after Unicode

This is the resolution [hygiene-parity's handoff](hygiene-parity.handoff.md)
predicted for three files, and it applied to four:

| File | Resolution |
|---|---|
| `clang/include/clang/ASTMatchers/ASTMatchers.h` | `userOperatorExpr`'s doc comment + declaration, then `backtickInfixExpr`'s. Both sit after `cxxRewrittenBinaryOperator`, which is why `U17` and hygiene-parity chose the same line. |
| `clang/lib/ASTMatchers/ASTMatchersInternal.cpp` | The same conflict in definition form. Both, same order. |
| `clang/tools/libclang/CXCursor.cpp` | Two `case` labels wanting one line in `MakeCXCursor`'s run. Both, Unicode first. |
| `clang/lib/ASTMatchers/ASTMatchFinder.cpp` | **Four hunks, and the only resolution that needed writing rather than concatenating.** The conflict split one function (`Traverse…Expr`) and one `else if` arm into two hunks each, with shared text between them, so "keep both" meant reconstructing each side whole: two complete `Traverse` overrides and two complete `else if` arms. `git diff` over the file removes nothing. |

`clang/lib/ASTMatchers/Dynamic/Registry.cpp` did **not** conflict, exactly as
hygiene-parity predicted — the file is alphabetical and `backtickInfixExpr`
sorts nowhere near `userOperatorExpr`.

### Both sides appended a test block sharing one closing brace

| File | Resolution |
|---|---|
| `clang/unittests/ASTMatchers/ASTMatchersNodeTest.cpp` | `ASTMatchersTestUnicodeOperators` (2 cases) and `ASTMatchersTestBacktick` (2 cases) both end at the file's next `}`. Kept both, with the brace closing the Unicode block **restored** — concatenating the two hunks naively would have left the last Unicode `TEST` unterminated. |
| `clang/unittests/Format/FormatTest.cpp` | Identical shape: `FormatTest.UnicodeOperatorFormatting` and `FormatTest.BacktickOperatorSlotSplitPenalty`. Same fix. |

### Already applied, and this branch says more — ours

`clang/lib/StaticAnalyzer/Core/BugReporterVisitors.cpp`. The branch landed
[null-return-suppression](null-return-suppression.handoff.md) first, in
`1f0790897357`, peeling **both** wrappers under a lead comment that names both
features; `backtick-trunk`'s commit peels one under a single-feature comment.
Kept this branch's — the same disposition M2 gave the four CIR lead comments,
and the arms are otherwise identical.

### What merged clean, and was checked anyway

`Parser.h`, `ParseExpr.cpp`, `DiagnosticParseKinds.td`, `Registry.cpp`,
`TokenAnnotator.cpp`, `TokenAnnotatorTest.cpp`, `LibASTMatchersReference.html`,
`backtick-semantics.cpp`, `backtick-diagnostics.cpp`,
`test/Analysis/backtick-infix.cpp`, and the two new test files. Read rather
than trusted, because M1's lesson is that an auto-merge is not evidence both
sides survived:

- **Every backtick-only file is byte-identical to `backtick-trunk`** —
  `git diff c0d69702b6d7 -- <file>` is empty for `Parser.h`,
  `backtick-adl.cpp`, `backtick-template-print.cpp`, `backtick-semantics.cpp`,
  `backtick-diagnostics.cpp` and `test/Analysis/backtick-infix.cpp`.
- **`ParseExpr.cpp` carries all of it**: `TryParseBacktickTypeSlot` at `:316`,
  `TryParseBacktickCalleeSlot` at `:392`, the dispatch at `:613`/`:622`, and
  `U11`/`U12`'s `tok::user_operator` arms further down.
- **The dead diagnostic is gone** — `err_backtick_nested_requires_parens` is
  absent from `DiagnosticParseKinds.td` here too.
- **`TokenAnnotator.cpp` kept both edits**: this branch's `endsOperand` helper
  and Unicode fixity arm, *and* hygiene-parity's slot-interior `SplitPenalty`
  block in `calculateFormattingInformation`.
- **The generated `LibASTMatchersReference.html` has both entries**,
  `backtickInfixExpr` at `:1429` and `userOperatorExpr` at `:2477`.

## The fold guard survived, and it was proven rather than read

`Parser::isFoldOperator` still reads

```cpp
  return Level > prec::Unknown && Level != prec::Conditional &&
         Level != prec::Spaceship && Level != prec::UserInfix;
```

— `prec::UserInfix`, this pair of branches' spelling, **not** the
`prec::Backtick` the backtick branches use, and unchanged through a merge that
rewrote sixty lines of the same file around it.

**Verified by deleting the clause and rebuilding**, as `M2` did and for the
reason `REPLAY.md`'s standing warning gives: it fails silently. Without it,
`clang/test/Parser/unicode-operator-precedence.cpp` fails, **on line 322
only** — the right fold `(N ⊞ ...)`:

```
error: 'err-error' diagnostics expected but not seen:
  Line 322 (directive at :323): expected expression
error: 'err-error' diagnostics seen but not expected:
  Line 322: expected ')'
  Line 322: expression contains unexpanded parameter pack 'N'
```

Character for character M2's result. The clause was restored, `clang` rebuilt,
the file passes, and `git status` is clean. **This is a second independent
confirmation that only the right fold pins the guard** — the left fold at line
320 and the backtick twin at line 405 still produce `expected expression`
without it, failing earlier for an unrelated reason.

## Job 2 — the comment on `unicode-operators-upstream`

`Sema::CheckUserOperatorDeclaration`'s `isStatic()` guard still carried the
reason [over-oper-restrictions](../../../docs/open-decisions.md#over-oper-restrictions)
rejected on 2026-09-06 — *"a static member function has none, so it can name
neither form"* — which does not survive inspection: the arity rule counts
**operands**, so `static S operator⊞(S, S)` has two and the rule alone would
accept it; the rejection comes from the guard three lines above.

**M2's wording was copied, not rewritten.** The six replacement lines are
byte-identical to `de76585ae45d` on the experiment branch — verified by
extracting the comment block from both worktrees and diffing them — so the two
Unicode branches stop differing by this paragraph, which was the point.
Comment only, +6/−4 in one file, the guard untouched: `8c2a90f56b00`. The
decision itself is written up as
[static-member-operators](../../../docs/unicode-operators.md#static-member-operators).

**The two Unicode branches now differ only by their intended difference.**
`git diff unicode-operators-upstream unicode-operators-experiment --
clang/lib/Sema/SemaDeclCXX.cpp` is 4 insertions / 44 deletions and **every
line of it is upstream base drift** (the union memcpy work in
`DefineImplicitCopyAssignment` / `DefineImplicitMoveAssignment`, which trunk
has and the 23.x-era base does not). Nothing about the user operator differs.

## Verification evidence

### Gates — both GREEN, unfiltered, `EXIT=0`

```
ninja -C ~/src/llvm/build-unicode          check-clang   → GATE_EXIT=0
  Total Discovered Tests: 54189
    Passed: 48301   Failed: 0   XFAIL: 27   Unsupported: 5855   Skipped: 6
    413.11 s

ninja -C ~/src/llvm/build-unicode-upstream check-clang   → GATE_EXIT=0
  Total Discovered Tests: 54242
    Passed: 48324   Failed: 0   XFAIL: 27   Unsupported: 5885   Skipped: 6
    480.30 s
```

`unicode-operators-experiment` is **+5 discovered / +5 passed** over its
Baselines row (54184 / 48296) **and nothing else moves** — the two new lit
files land in *passed* rather than *unsupported*, being ordinary lit tests, and
the three new gtest cases are individually discovered, which is the arithmetic
[hygiene-parity](hygiene-parity.handoff.md) had to explain on the backtick
branches. `unicode-operators-upstream` is **exactly its Baselines row**
(54242 / 48324 / 0), which is the expected result for a comment-only commit.

Both measured unfiltered, with `ulimit -c 0`, output redirected and the exit
code captured explicitly — `ninja … | tail` reports `tail`'s status.

### The `DirectoryWatcherTest` failures are the environment, and were confirmed by cause

**Three gate runs before those two readings failed only
`DirectoryWatcherTest.*`, and a different subset every time**: the experiment
branch's first run failed `InitialScanSync` / `InvalidatedWatcher` /
`ModifyFile`, the upstream branch's first failed `DeleteFile` /
`DeleteWatchedDir` / `InvalidatedWatcher`, and its second failed
`InitialScanAsync` alone. Every failure was
`No space left on device : inotify_add_watch()`. **A changing subset is the
signature** — [clang-slot-adl](clang-slot-adl.handoff.md)'s formulation — and a
real regression fails the same tests every time.

Confirmed by **cause**, not waited out:

- `sysctl fs.inotify.max_user_watches` = **524288**, the raised value.
- `cloud-drive-dae` was measured holding **523,730** of it, leaving **558**
  free for the entire machine. That is the worst level any step has recorded —
  [`inotify-watch-budget`](../../BACKLOG.md#inotify-watch-budget)'s reopening
  measured 523,774 of the same ceiling and expected 3-of-8, whereas at 558 free
  **all eight** cases fail.
- At that moment all 8 failed on the **pristine `~/src/llvm/build-main`
  binary**, standalone, and on the freshly built `build-unicode` one.
- No scratch tree of this session's making exists;
  `~/src/llvm/build-cir-scratch` is the one standing tree and is deliberate.
- When the hoard receded the same binary ran **`[  PASSED  ] 8 tests`**, and
  that is the run immediately before the green upstream gate above.

**Nothing was filtered and nothing was budgeted.** The gates were re-run until
the environment allowed a reading, which is what
[`inotify-watch-budget`](../../BACKLOG.md#inotify-watch-budget) prescribes.

### Targeted re-runs

**17 lit tests, 17 passed, 1.02 s**, covering both features' surfaces on the
merged branch: `Parser/unicode-operator-precedence.cpp`, `-infix`, `-prefix`,
`AST/unicode-operator-print.cpp`, `SemaCXX/unicode-operator-semantics.cpp`,
`SemaCXX/unicode-operator-adl.cpp`, `Analysis/unicode-operator-analysis.cpp`,
`CodeCompletion/unicode-operator-priority.cpp`, `Parser/backtick-infix.cpp`,
`backtick-escape.cpp`, `backtick-diagnostics.cpp`, `backtick-ast-print.cpp`,
`SemaCXX/backtick-adl.cpp`, `backtick-semantics.cpp`,
`AST/backtick-template-print.cpp`, `Analysis/backtick-infix.cpp`,
`Lexer/backtick-c-mode.c`.

**The four ASTMatchers gtest cases run and pass together** —
`ASTMatchersTestUnicodeOperators.{UserOperatorExpr,UserOperatorExprTraversal}`
and `ASTMatchersTestBacktick.{BacktickInfixExpr,BacktickInfixExprTraversal}` —
which is the check that matters after that particular conflict: the two nodes'
matchers, static and dynamic, agree at the same anchor.

### Builds

`unicode-operators-experiment`: `EXIT=0`, **948 targets** — a full rebuild,
`ASTMatchers.h` and `Parser.h` both being in the merge — and **zero
`warning:` lines** in the log. `unicode-operators-upstream`: `EXIT=0`, 16
targets, zero warnings.

### Formatting

`git-clang-format --diff --commit HEAD~1` with the **in-tree** `clang-format`
reports **one** region, and it is **inherited, not this merge's**: the three
`matchesConditionally` calls in
`ASTMatchersTestBacktick.BacktickInfixExprTraversal`, which are
**byte-identical to `backtick-trunk`** and therefore came across unchanged
from a commit that gated green there. `clang/unittests/ASTMatchers/` is **not**
in `check-clang`'s self-format glob — that is `clang/lib/Format/` and
`clang/unittests/Format/` — so it never reaches the step at ~81/970.
Reformatting it would make the two branches differ for nothing. Same
disposition M2 gave its two inherited hits. The upstream commit is clean
(*"clang-format did not modify any files"*).

### The feature diff, re-measured

```
git diff --shortstat c0d69702b6d7..7278a2985659  → 121 files, +7701/−57
git diff -U0 c0d69702b6d7..7278a2985659 | grep -c '^@@'  → 221
```

against M2's 119 / 217 / +7600−47. The movement is the two backtick test files
this branch did not have plus hygiene-parity's edits; **no ledger row changes
classification**, and `REPLAY.md`'s new section carries the arithmetic and the
re-run contamination scan (same six production files, same four comment-only
entries, one addition that predates this merge).

## Discoveries affecting later work

- **`backtick-trunk` and `unicode-operators-experiment` have no outstanding
  forward-port.** Everything the three completion steps queued is landed. The
  next one is created only by a backtick-track change that lands on the
  backtick branches alone.
- **`unicode-operators-upstream` must still never receive the merge.**
  Unchanged from M1 and M2 and restated because it is the whole hazard: that
  branch is `upstream/main` plus Unicode only, and `git log -p
  upstream/main..unicode-operators-upstream | grep -ic backtick` is the
  invariant (**0**; the two-dot form now returns upstream's own drift and is
  not the check — see
  [evidence-debt's `REPLAY.md` section](../../unicode-operators/clang/REPLAY.md)).
- **Four tooling anchors now carry two arms here and one upstream** —
  the matcher declaration and definition, `ASTMatchFinder`'s traversal
  override and its `TK_IgnoreUnlessSpelledInSource` arm, `MakeCXCursor`'s case
  run, and the matcher unit tests. Every Unicode entry among them is already on
  `unicode-operators-upstream` and unchanged, but a replay that copies a
  *region* rather than an *arm* now carries a backtick sibling with it. Same
  hazard `BL03` and `null-return-suppression` already record: same change, same
  semantics, different neighbours. Unlike those two, there is nothing to strip
  from a shared lead comment — these are separate functions and separate arms,
  each with its own comment.
- **`ASTMatchersTestBacktick` and `ASTMatchersTestUnicodeOperators` are
  deliberately two suites**, not one parameterised suite. hygiene-parity named
  its suite "the counterpart of `ASTMatchersTestUnicodeOperators` above on the
  Unicode branch" — on that branch they are now adjacent, and the comment reads
  as written.
- **Nothing is pushed.** Both LLVM branches and this repo are ahead of every
  remote, as they were before. Note that all four branches track `ceridwen`,
  **not** `origin`, and both remotes were in sync at the last push — a later
  push needs both.

## Open risks / TODOs

- **[`inotify-watch-budget`](../../BACKLOG.md#inotify-watch-budget) is worse
  than the last few steps saw it.** `cloud-drive-dae` was measured holding
  **523,730 of 524,288** watches during this work — 558 free for the whole
  machine — and at that level *all eight* `DirectoryWatcherTest` cases fail on
  the pristine `~/src/llvm/build-main` binary, standalone, repeatedly. It needs
  root and it is the maintainer's; budget one or two extra gate runs for it and
  measure the hoard before suspecting a diff.
- **The inherited `ASTMatchersNodeTest.cpp` formatting region** above. It is
  `backtick-trunk`'s to fix if anyone wants it fixed, and fixing it on one
  branch alone would create the drift this handoff just closed.
- **Section 9's comment in `unicode-operator-precedence.cpp` is still stale**
  in the direction M2 recorded: line 314 says the fold behaviour is *"pinned
  here, not endorsed -- U§13 lists it as open"*, but
  [fold-over-user-infix](../../../docs/open-decisions.md#fold-over-user-infix)
  was answered on 2026-09-06. Untouched here, as by M2 and the four steps
  since; it is a comment on all four branches and costs four gates.
- **The four unowned deviation rows** [backtick-paper](backtick-paper.handoff.md)
  opened are still unowned. Deliberately out of scope here.
