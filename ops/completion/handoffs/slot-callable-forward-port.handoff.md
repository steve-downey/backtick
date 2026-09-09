# Handoff — slot-callable-forward-port — the sixth backtick merge, and the first predicted conflict that was priced before it was written

- **Status:** **DONE (gate passed).**
- **Branch / commits:**
  - `unicode-operators-experiment` (`~/src/llvm/unicode`) — **`0041778f1d4e`**, the merge commit
  - `unicode-operators-upstream` — **deliberately untouched**, still `8c2a90f56b00`
  - `backtick-trunk` / `backtick-23` — **not touched**; the merge is one-way
  - `unicode-operators` (this repo) — the `ops:` commit carrying this file, the
    [`REPLAY.md`](../../unicode-operators/clang/REPLAY.md) section, the Baselines
    note, `CLAUDE.md`'s merge paragraph and two Status-log rows
- **Date:** 2026-09-08.
- **A plan step this time**, unlike the five merges before it: it is box **24**
  of [`ops/completion/PLAN.md`](../PLAN.md), so it follows
  [`ops/AGENT_PROTOCOL.md`](../../AGENT_PROTOCOL.md)'s loop and **ticks a box**.
  It still gets the `REPLAY.md` section and the
  [`ops/unicode-operators/clang/PLAN.md`](../../unicode-operators/clang/PLAN.md)
  row every forward-port gets.
- **Opens and closes nothing.** No new deviation row; the three ledgers still
  read **0 / 1 / 0**, the one being
  [`escape-type-name-spelling`](../../gcc/DEVIATIONS.md#escape-type-name-spelling).

---

## The merge

`git merge --no-ff 28b685c86ea2` — the explicit commit, not the branch tip, per
[M1's rule](../../unicode-operators/clang/handoffs/M1-forward-port.handoff.md)
that `backtick-trunk` moves under you. The merge base was exactly
`bd8790f9d0ef`, the last merge's target, so the one commit it brought was
exactly the one that had accumulated:

| Commit | What | Why it was deferred |
|---|---|---|
| `28b685c86ea2` | [slot-callable-printing](slot-callable-printing.handoff.md) — a slot whose *value* is a class-typed callable calls the object's `operator()`, which Sema keys as a `CXXOperatorCallExpr` with `OO_Call`, its operands at arguments 1 and 2 | landed on the backtick branches alone |

`git merge` reported *"Automatic merge went well"* over the five files. **No
conflicts.**

## The predicted conflict was real for once, and one command settled it *first*

The two merges before this one each predicted a collision that could not have
happened, and each spent a section afterwards explaining why. Both closed with
the same instruction: **one `git diff --numstat` settles a predicted collision
before you write a paragraph about it.**

This step's prediction had a genuine basis, and it is worth saying so plainly:
**`StmtPrinter.cpp` carries `VisitUserOperatorExpr` on this branch, and
`VisitBacktickInfixExpr` is exactly the function the incoming commit edits.**
Same file, both features, both printers — not two features that merely share a
directory.

It was checked **before** the merge, with the command those two sections each
concluded with:

| File | This branch's hunks (`bd8790f9d0ef..5fd79178d2a7`) | Incoming hunks (`bd8790f9d0ef..28b685c86ea2`) |
|---|---|---|
| `clang/lib/AST/Expr.cpp` | 2713, 3560, 3888 — `isUnusedResultAWarning`, `isConstantInitializer`, `HasSideEffects` | 1622–1651 — `BacktickInfixExpr::getOperand` |
| `clang/lib/AST/StmtPrinter.cpp` | 2283 — `VisitUserOperatorExpr` | 1638–1665 — `VisitBacktickInfixExpr` |

**640 lines and one function apart in the printer, over a thousand in
`Expr.cpp`.** The rule has now paid three merges running: twice by retiring an
imaginary prediction, once by pricing a real one in a single command and a
minute. It costs less than the paragraph explaining the prediction afterwards,
which is the whole argument for it.

## An auto-merge is not evidence, so it was measured four ways

M1's lesson. Every check has to agree:

- **The merge delta is exactly the incoming commit.**
  `git diff --shortstat 5fd79178d2a7 0041778f1d4e` → **5 files, +131/−13**, and
  `git diff --shortstat bd8790f9d0ef 28b685c86ea2` → **5 files, +131/−13**.
  Identical. Git applied the commit whole and added nothing.
- **The 13 deleted lines are the incoming commit's own, as a set.** Not merely
  the same count: `diff <(git diff 5fd79178d2a7 0041778f1d4e | grep '^-[^-]' |
  sort) <(git diff bd8790f9d0ef 28b685c86ea2 | grep '^-[^-]' | sort)` is empty.
  And **none is Unicode text** — `grep -Ec
  'user_operator|UserOperator|UserInfix|unicode|⊞'` over them → **0**.
- **The feature diff against the new backtick tip did not move.**
  `git diff --shortstat 28b685c86ea2..0041778f1d4e` → **121 files, +7701/−57**,
  and **221 hunks at `-U0`** (207 at the default `-U3`) — identical to the last
  three merges' reading. The backtick side advanced by a commit and the Unicode
  side is unchanged to the line. **Quote the `-U` flag with the number**, per
  the last merge's correction.
- **The three test files are byte-identical to `backtick-trunk`**
  (`git diff 28b685c86ea2 HEAD -- <file>` empty for
  `clang/test/AST/backtick-template-print.cpp`,
  `clang/test/Parser/backtick-ast-print.cpp`,
  `clang/test/Parser/backtick-infix.cpp`). The two production files differ in
  **twenty-two lines and every one is Unicode work** — the three
  `case UserOperatorExprClass:` arms and `VisitUserOperatorExpr`, read out of
  the diff rather than assumed.

§1's `awk` contamination recipe over
`28b685c86ea2..unicode-operators-experiment` hits the **same** six production
files it always has, plus `SemaOverload.cpp`'s doc comment,
`BugReporterVisitors.cpp`, the four comment-only entries and the test files.
**No new production file** — and neither `Expr.cpp` nor `StmtPrinter.cpp`
appears, which is the same fact from the other side: they are
`backtick-trunk`'s files now except for their Unicode arms.

## `UserOperatorExpr::getOperand` needs no equivalent arm — proven with a program

The incoming defect is that **`CXXOperatorCallExpr` *is a* `CallExpr`**, so a
generic `dyn_cast<CallExpr>` arm silently gets the re-keyed shape with its
arguments shifted by one. `UserOperatorExpr::getOperand`
(`clang/lib/AST/ExprCXX.cpp:135`) reaches through
`getSemanticForm()->IgnoreImplicit()` with the same idiom, so the question is
whether it has the same hole.

**It does not, and the reason is structural**: a user operator's semantic form
is a call to a **declared function** — `operator⊞(x, y)` or `x.operator⊞(y)` —
and **there is no `OverloadedOperatorKind` for ⊞ at all**, so the `OO_Call`
re-keying cannot arise. The file already contains the idiom for the same
reason, checking `CXXMemberCallExpr` **before** `CallExpr`.

Read that way it is an argument. Measured on the merged binary,
`-std=c++23 -fbacktick -funicode-operators -Xclang -ast-print`, it is a result —
six shapes, every one printing as written:

```cpp
int a() { return fn ⊞ fn; }                          // operand is a class-typed callable
int b() { return w1 ⊞ w2; }                          // operand is a class holding one
int c(int L, int R) { return L `fn` R; }             // the shape the merge fixes
int d(int L, int R) { return (L `fn` R) ⊞ 0; }       // both features, one expression
int e(int L, int R) { return L ⊞ R `fn` 1; }         // both features, precedence
int g(int L, int R) { return fn(L, R) ⊞ fn(R, L); }  // operand is a call's result
```

**and the printed output re-parses clean, `EXIT=0`** — the round trip, not just
the print, which is the assertion `backtick-ast-print.cpp`'s second RUN line
makes and the one the incoming defect failed. `-ast-dump` shows both node kinds
carrying **forward** ranges — `UserOperatorExpr <col:18, col:25>`,
`BacktickInfixExpr <col:30, col:37>` — so the *silent* half of the incoming
defect, the inverted source range, is absent here too. Both halves checked,
because they failed differently on the backtick side.

**The defect was live on this branch and the merge is what fixed it.**
[slot-callable-printing](slot-callable-printing.handoff.md) measured
`` L `fn` R `` printing as `` fn `operator()` L `` on `5fd79178d2a7`'s binary —
a program that does not compile, naming `operator()` as a free function.
Structurally confirmed here too:
`git show 5fd79178d2a7:clang/lib/AST/StmtPrinter.cpp | grep -c 'OO_Call && '`
→ **0**, the merged file → **1**. It prints as itself now.

## The fold guard survived, and it was proven a fifth time

`Parser::isFoldOperator` still reads

```cpp
  return Level > prec::Unknown && Level != prec::Conditional &&
         Level != prec::Spaceship && Level != prec::UserInfix;
```

— `prec::UserInfix`, this pair of branches' spelling, **not** the
`prec::Backtick` the backtick branches use. Grepping the wrong one looks exactly
like the loss it warns about.

**Verified by deleting the clause and rebuilding**, per the standing warning at
the top of [`REPLAY.md`](../../unicode-operators/clang/REPLAY.md): it fails
silently. Without it, `clang/test/Parser/unicode-operator-precedence.cpp` fails
**on line 322 only** — the right fold `(N ⊞ ...)`:

```
error: 'err-error' diagnostics expected but not seen:
  Line 322 (directive at :323): expected expression
error: 'err-error' diagnostics seen but not expected:
  Line 322: expected ')'
  Line 322: expression contains unexpanded parameter pack 'N'
error: 'err-note' diagnostics seen but not expected:
  Line 322: to match this '('
4 errors generated.
```

**Four stanzas, `4 errors generated.` as the tail** — character for character
what the last two merges recorded. Restored with `git checkout --`, `clang`
rebuilt (`EXIT=0`, **zero `warning:` lines**), the file passes, `git status`
clean at `0041778f1d4e`. **Fifth independent confirmation that only the right
fold pins it**, and worth more than usual here for the opposite reason to last
time: this merge touches `ParseExpr.cpp` **not at all**, so a surviving guard is
the expected reading and the check is a control rather than a rescue.

## The separability gate's command is stale — quote the base commit

The step file's gate says
`git diff upstream/main..unicode-operators-upstream | grep -i backtick` must
return nothing. **It no longer does. It returns six lines, and none of them is
this project's.**

`upstream/main` has moved to `72417eb739e5`, **17,471 files** past this
branch's base `d28193fa1ff6`. The six hits are upstream's own drift, appearing
as `-` lines because the diff runs *from* upstream's newer state: LLDB's
`arg_has_backtick` and four MLIR documentation lines about Markdown backtick
fences.

The property that is load-bearing for the Unicode paper's separability claim is
about the branch's **own commits**, so quote its base:

```
git -C ~/src/llvm/unicode-upstream log -p d28193fa1ff6..HEAD | grep -ic backtick   → 0
git -C ~/src/llvm/unicode-upstream diff    d28193fa1ff6..HEAD | grep -ic backtick   → 0
```

Twenty commits, **zero mentions**, tip unchanged at `8c2a90f56b00`, working tree
clean, and `git merge-base --is-ancestor 0041778f1d4e HEAD` **false** — the merge
is not present and must never be.

**This is the same class of correction as the `-U0`-versus-`-U3` one the last
merge recorded**: a gate command has to name the reference it measures against,
or it decays into a false alarm that the next agent has to spend ten minutes
disproving. Whoever next edits
[`slot-callable-forward-port.md`](../steps/slot-callable-forward-port.md) or
writes another merge step should copy the `d28193fa1ff6..HEAD` form.

## Flag-off parity and the probes

All three run with `bash`, not `zsh`, `CLANG=~/src/llvm/build-unicode/bin/clang++`:

| Probe | Question | Result |
|---|---|---|
| `escape-positions.sh` | where does the escape reach? | **79/79 clang, 79/79 gcc** — A 23/23, B 16/16, C 25/25, D 15/15 |
| `escape-errors.sh` | does a bad escape diagnose *and stop*? | **`EXIT=0`**, 23 × 2, all diagnosed, nothing hung |
| `flag-off-parity.sh` | does the flag change a program with no backtick? | **`EXIT=0`**, byte-identical in every cell |

```
                              flag on vs flag off      flag off vs pristine
clang  -fsyntax-only ok        IDENTICAL (0 lines)      IDENTICAL
clang  -fsyntax-only bad       IDENTICAL (50 lines)     IDENTICAL
clang  -ast-print              IDENTICAL (85 lines)     IDENTICAL
clang  -ast-dump               IDENTICAL (331 lines)    IDENTICAL
cc1plus -fsyntax-only ok       IDENTICAL (0 lines)      IDENTICAL
cc1plus -fsyntax-only bad      IDENTICAL (60 lines)     IDENTICAL
cc1plus generated assembly     IDENTICAL (282 lines)    differs in 2 lines
```

Every cell matches the last merge's reading exactly. The two assembly lines are
the `.ident` build-date string. **The gate's phrase "both features off" is
satisfied by construction and it is worth saying how**: the harness's "off"
column passes **neither** `-fbacktick` nor `-funicode-operators`, and the third
column compares it against `~/src/llvm/build-main`, a binary that has neither
feature and is this branch's exact upstream base. That is what makes the column
a control rather than a coincidence.

**They found nothing, and the run is recorded anyway.** This merge changed the
AST printer and not the escape, so a green sweep is the expected reading —
`ops/probes/README.md` now says a sweep run only when it is expected to fail has
stopped being a control.

## Gate — GREEN, unfiltered, `EXIT=0`, first run

```
ninja -C ~/src/llvm/build-unicode check-clang > gate.log 2>&1 ; echo "GATE_EXIT=$?"

GATE_EXIT=0
Testing Time: 198.94s

Total Discovered Tests: 54190
  Skipped          :     6 (0.01%)
  Unsupported      :  5855 (10.80%)
  Passed           : 48302 (89.13%)
  Expectedly Failed:    27 (0.05%)
  Failed           :     0
```

**Exactly the Baselines row, delta 0** — 54190 / 48302 / 0 — because the
incoming commit's eight new cases went into three lit files this branch already
had, and **lit discovers files, not cases**. XFAIL 27, unsupported 5855,
skipped 6, all unchanged.

Measured with `ulimit -c 0`, output redirected and the exit code appended to the
log and read back out of it — `ninja … | tail` reports `tail`'s status.

**Green on the first run**, and the cheap reason is recorded because the last
merge lost three runs to it: the machine held **101 inotify instances** when the
gate started, against `fs.inotify.max_user_watches` of 524,288, so
[`inotify-watch-budget`](../../BACKLOG.md#inotify-watch-budget) was not in the
way. It has not gone away. Measure the hoard before suspecting a diff.

Builds: the merge build `EXIT=0`, **17 targets**, **zero `warning:` lines**
grepped from the log rather than inferred; both fold-guard builds `EXIT=0`
likewise. Seventeen targets is correct — the merge touches two `clang/lib/AST`
files and three tests, and nothing downstream of them rebuilds beyond `clang`.

Targeted lit, both features, both flags and the combination: **33 tests, 32
passed, 1 unsupported, 0.36 s** — every `unicode-operator-*` and `backtick*`
file under `clang/test/`, plus `Driver/fbacktick.c` and
`Driver/funicode-operators.c`. The one unsupported is
`CIR/CodeGen/backtick-infix.cpp`, which needs a CIR-enabled build; that is the
build configuration, not a regression. The *combination* is not covered by any
lit file and was run as the program above, both flags in one TU.

## Formatting

`git-clang-format --diff --commit 5fd79178d2a7` with the **in-tree**
`clang-format` (invoked as
`python3 clang/tools/clang-format/git-clang-format --binary
~/src/llvm/build-unicode/bin/clang-format`, because there is no
`git-clang-format` on `PATH` on this machine) reports **"clang-format did not
modify any files"** — the second merge running with nothing to report.

The inherited `dyn_cast<CXXParenListInitExpr>` region in
`BacktickInfixExpr::getOperand` is in a file this merge *does* touch this time,
and still reports clean: the incoming commit rewrote the function around it and
gated green on `backtick-trunk` with it. It is still there and still
`backtick-trunk`'s to fix; fixing it on one branch alone would create drift.

`check-clang`'s self-format glob — `clang/lib/Format/**`,
`include/clang/Format/*.h`, `tools/clang-format/*.cpp`,
`unittests/Format/*.{cpp,h}` — contains **no file this merge touches**, so the
abort at ~81/970 was never in play.

## Deviations from the step file

1. **The merge commit subject is `[unicode] slot-callable-forward-port: …`, not
   `[backtick] …`.** The step file's Notes say `[backtick]`. Every one of the
   five merges before it used `[unicode]` on this branch —
   `git log --oneline --merges` reads M1, M2, `unicode-branch-maintenance`,
   `escape-positions-forward-port`, `escape-name-sweep-forward-port`, all
   `[unicode]` — and that is what an audit or a replay greps for. `CLAUDE.md`'s
   convention list is about which *track* a commit belongs to; the branch's own
   five-deep precedent is the more specific rule and is the one followed. The
   record in this repo is `ops: slot-callable-forward-port — …`, also per
   precedent. **Nothing is pushed**, so a maintainer who disagrees can amend.
2. **The gate's `upstream/main..` command was replaced, not skipped**, and the
   replacement plus the reason is a whole section above. The property it exists
   to check is measured and holds.

## Discoveries affecting later work

- **`backtick-trunk` and `unicode-operators-experiment` have no outstanding
  forward-port.** Everything on the backtick branches is landed here. The next
  one is created only by a backtick-track change that lands on the backtick
  branches alone.
- **`unicode-operators-upstream` must still never receive the merge.**
  Unchanged from all five previous merges, and restated because it is the whole
  hazard: that branch is `upstream/main` plus Unicode only. **Check it against
  `d28193fa1ff6`, not `upstream/main`.**
- **`UserOperatorExpr::getOperand` has no `OO_Call` hazard, and the reason is
  the absence of an `OverloadedOperatorKind` for ⊞ rather than anything about
  the operand's type.** If a future Unicode change ever gives a user operator a
  spelling the semantic layer can rewrite into a different node kind — the way
  `__builtin_shufflevector` is rewritten out of being a call — that argument
  stops holding and `getOperand` needs the same treatment
  `BacktickInfixExpr::getOperand` just got.
- **The two features touch in `clang/lib/AST` now, and not only in
  `ParseExpr.cpp`, clang-format and the precedence level.** `Expr.cpp` and
  `StmtPrinter.cpp` each carry arms of both. `REPLAY.md` §1's "three constructs
  are the entire coupling" is still right about *coupling* — nothing here is
  shared logic — but it is no longer right as a list of shared **files**, and a
  future merge should read it that way.
- **Check a predicted conflict before recording it.** Three merges running.
  `git diff --numstat <backtick-tip-at-last-merge> <unicode-head> -- <file>`
  and its incoming twin cost one command each.
- **Nothing is pushed.** `unicode-operators-experiment` is ahead of every remote
  by this merge and this repo by this commit; `backtick-trunk` and `backtick-23`
  remain ahead by their own unpushed work. All four LLVM branches track
  `ceridwen` **and** `origin`. Pushing is the maintainer's call.

## Forward notes for [backtick-paper-truth](../steps/backtick-paper-truth.md)

Box **23** is the only unchecked step left in the plan and it was **being
executed concurrently with this one, by another agent**; its files
(`papers/backtick-infix-and-keyword-escape.md`) were deliberately not touched
here. If that step is still open when you read this, one thing from here is
relevant to it and nothing else is:

- **The round-trip paragraph may now say the fix is on every branch that
  carries the feature, not only on the backtick branches.** Both Clang tracks
  and `unicode-operators-experiment` have it as of `0041778f1d4e`; GCC has no
  counterpart because it desugars in the parser and has no printer for the form,
  which [slot-callable-printing](slot-callable-printing.handoff.md) confirmed
  rather than assumed. **No internal identifier goes into the paper** — say
  "both compilers" and "the implementation", never a slug or a branch name, per
  the public-text rule.
- Everything else the paper needs is in
  [slot-callable-printing's forward notes](slot-callable-printing.handoff.md),
  which are more precise than anything measured here. In particular the sweep
  timing is **1.6 s**, and the failing condition is **a call to the object's
  `operator()`** — not "a lambda in the slot", because a callable reached
  through a conversion to a function pointer printed correctly all along.

## What is left outstanding when this step is done

Phase J's merge work ends here, and so does the plan's, so this is worth saying
plainly rather than by implication.

**Outstanding:**

- **[backtick-paper-truth](../steps/backtick-paper-truth.md), box 23** — the
  only unchecked box in [`ops/completion/PLAN.md`](../PLAN.md), in flight with
  another agent as this was written. It is a paper edit and depends on nothing
  here.

**Not outstanding, and the record should not read as though they were:**

- **No maintenance merge is owed.** Six have run. The next is created only by a
  backtick-track change landing on the backtick branches alone.
- **All four branches are green at their Baselines rows**, and no branch is
  waiting on the author.
- **One deviation row is open across the three ledgers** —
  [`escape-type-name-spelling`](../../gcc/DEVIATIONS.md#escape-type-name-spelling)
  — and it is a *diagnostic* divergence, not an acceptance one: GCC escapes the
  name of a **declaration** and prints the name of a **type** bare. It is
  measured and surfaced rather than owned, and it was out of scope here.

## Open risks / TODOs

- **The step file's `upstream/main..` gate command is wrong and is still in the
  step file.** The section above gives the replacement. Fixing the step file
  itself would edit a step that has now run, so it is recorded here and in
  `REPLAY.md` instead; the next merge step's author should copy the
  `d28193fa1ff6..HEAD` form rather than the stale one.
- **Section 9's comment in `unicode-operator-precedence.cpp` is still stale** on
  all four branches, as five handoffs have now recorded: line 314 calls the fold
  behaviour *"pinned here, not endorsed -- U§13 lists it as open"* when
  [fold-over-user-infix](../../../docs/open-decisions.md#fold-over-user-infix)
  was answered on 2026-09-06. It is a comment on four branches and costs four
  gates, which is exactly why nobody has done it; it wants a step of its own
  that fixes all four at once. **Sixth recording.**
- **`docs/infix-backtick-operator.org` still says the sweep takes "ten seconds
  to run", and nobody owns it.** Measured figure **1.6 s**. Opened by
  [slot-callable-printing](slot-callable-printing.handoff.md); untouched here,
  the blog post being out of scope. It joins
  [`hunk-count-provenance`](../../BACKLOG.md#hunk-count-provenance) as a
  correction waiting for a passing edit rather than a step.
- **The inherited `ASTMatchersNodeTest.cpp` and `BacktickInfixExpr::getOperand`
  formatting regions** are still there, and still `backtick-trunk`'s to fix.
  Fixing either on one branch alone would create drift.
- **`inotify-watch-budget` cost nothing here and that is luck, not resolution.**
  101 instances at gate time against a hoard that has twice been measured near
  524,000. Measure it before suspecting a diff.
