# Handoff — escape-positions-forward-port — the escape's name positions and the aggregate slot, carried to the Unicode branch

- **Status:** **DONE (gate passed).**
- **Branch / commits:**
  - `unicode-operators-experiment` (`~/src/llvm/unicode`) — **`e09b559d631c`**, the merge commit
  - `unicode-operators-upstream` — **deliberately untouched**, still `8c2a90f56b00`
  - `unicode-operators` (this repo) — the `ops:` commit carrying this file, the
    [`REPLAY.md`](../../unicode-operators/clang/REPLAY.md) section, the new
    [`ops/DEVIATIONS.md`](../../DEVIATIONS.md) row, the Baselines update and the
    Status-log rows
- **Date:** 2026-09-08.
- **Not a plan step.** Like `M1`, `M2`, `unicode-branch-maintenance` and the
  R-prefixed rebases it gets a handoff, a Status-log row in
  [`ops/completion/PLAN.md`](../PLAN.md) and in
  [`ops/unicode-operators/clang/PLAN.md`](../../unicode-operators/clang/PLAN.md),
  and a `REPLAY.md` section. It does not follow `ops/AGENT_PROTOCOL.md`'s step
  loop, adds no feature, and **ticks no checkbox** — [`ops/completion/PLAN.md`](../PLAN.md)
  is complete and stays complete.

---

## The merge

`git merge --no-ff 14f6373ccc7d` — the explicit commit, not the branch name, as
[M1's handoff](../../unicode-operators/clang/handoffs/M1-forward-port.handoff.md)
insists and the two merges since have repeated. The tip was confirmed first and
the merge base was exactly `c0d69702b6d7`, the last merge's, so the two commits
it brought were exactly the two that had accumulated:

| Commit | What | Why it was deferred |
|---|---|---|
| `3b2103895224` | [settle-paper-rows](settle-paper-rows.handoff.md) — the fourth inner shape a type slot can build | landed on the backtick branches alone |
| `14f6373ccc7d` | [escape-name-positions](escape-name-positions.handoff.md) — the keyword escape reaches every name position | same |

## There were no conflicts, and the predicted one was a misreading

[escape-name-positions' handoff](escape-name-positions.handoff.md) warned that
*"this one will not be clean"* — it touches `TypePrinter.cpp`,
`DeclPrinter.cpp` and `StmtPrinter.cpp`, and *"`unicode-operators-experiment`
has its own arms in the last two"*. **Two of the three are wrong.** The Unicode
side's own change to each file, `git diff --numstat c0d69702b6d7 7278a2985659`:

| File | Unicode side's change |
|---|---|
| `clang/lib/AST/DeclPrinter.cpp` | **none** |
| `clang/lib/AST/TypePrinter.cpp` | **none** |
| `clang/lib/AST/NestedNameSpecifier.cpp` | **none** |
| `clang/lib/AST/StmtPrinter.cpp` | 17 / 0 — `VisitUserOperatorExpr` alone |

The reason is structural and worth carrying: **a user operator's name is a
`CXXUserOperatorName`, not an `IdentifierInfo`**, so it prints through
`DeclarationName::print` and reaches none of the identifier printers the escape
had to teach. Its one `StmtPrinter` arm sits beside
`VisitCXXRewrittenBinaryOperator`; the escape's edits are `VisitLabelStmt` and
`VisitGotoStmt` at the top of the file and the aggregate arm inside
`VisitBacktickInfixExpr`. Different functions, hundreds of lines apart. **The
two features share a token and a precedence level, not a name representation.**

`git merge` reported *"Automatic merge went well"* over seven auto-merged files
and no conflict markers anywhere.

## An auto-merge is not evidence, so it was measured

M1's lesson. Three independent checks, all of which have to agree:

- **The merge delta is exactly the two commits.** `git diff --shortstat
  7278a2985659 e09b559d631c` → **20 files, +437/−82**, and 437 = 79 + 358,
  82 = 8 + 74, the two commits' own totals. Git applied them whole and added
  nothing.
- **None of the 82 deleted lines is Unicode text.** `git diff 7278a2985659 |
  grep '^-[^-]' | grep -Ec 'user_operator|UserOperator|UserInfix|unicode|⊞'`
  → **0**.
- **The feature diff against the new backtick tip did not move.**
  `git diff --shortstat 14f6373ccc7d..e09b559d631c` → **121 files, +7701/−57**
  and **221 hunks** — identical to
  [unicode-branch-maintenance](unicode-branch-maintenance.handoff.md)'s reading
  against the old tip. The backtick side advanced by two commits and the
  Unicode side is unchanged to the line.

Both sides were then read in the four files where they overlap
(`StmtPrinter.cpp`, `DeclarationName.h`/`.cpp`, `ParseExprCXX.cpp`,
`ParseTentative.cpp`, `Expr.cpp`, `ParseExpr.cpp`) rather than trusted:
`VisitUserOperatorExpr` and the two escape printer arms and the aggregate arm
all present; `printIdentifierSpelling` and `getCXXUserOperatorName` side by
side; `isBacktickEscape`'s nested-name-specifier arm and the
`tok::user_operator` declarator arms both in `ParseExprCXX.cpp`;
`isCXXDeclarationSpecifier`'s `tok::backtick` predicate and the Unicode arm both
in `ParseTentative.cpp`. **Thirteen of the twenty files are byte-identical to
`backtick-trunk`** (`git diff 14f6373ccc7d -- <file>` empty), including all six
of `ParseDecl.cpp`, `ParseDeclCXX.cpp`, `ParseStmt.cpp`, `ParseTemplate.cpp`,
`Parser.cpp` and `Parser.h`.

## The fold guard survived, and it was proven a third time

`Parser::isFoldOperator` still reads

```cpp
  return Level > prec::Unknown && Level != prec::Conditional &&
         Level != prec::Spaceship && Level != prec::UserInfix;
```

— `prec::UserInfix`, this pair of branches' spelling, **not** the
`prec::Backtick` the backtick branches use.

**Verified by deleting the clause and rebuilding**, as both previous merges did
and for the reason [`REPLAY.md`](../../unicode-operators/clang/REPLAY.md)'s
standing warning gives: it fails silently. Without it,
`clang/test/Parser/unicode-operator-precedence.cpp` fails, **on line 322 only**
— the right fold `(N ⊞ ...)`:

```
error: 'err-error' diagnostics expected but not seen:
  Line 322 (directive at :323): expected expression
error: 'err-error' diagnostics seen but not expected:
  Line 322: expected ')'
  Line 322: expression contains unexpanded parameter pack 'N'
error: 'err-note' diagnostics seen but not expected:
  Line 322: to match this '('
```

**One correction to the two earlier records**: they quote the first three
stanzas; the `err-note` line is in the same output and is simply not carried in
either. A future replay comparing character for character should expect four.
The clause was restored, `clang` rebuilt (`EXIT=0`), the file passes, and
`git status` is clean at `e09b559d631c`.

## Flag-off parity, measured byte-identically

Two programs with **no backtick and no user operator**, exercising every
construct whose lookahead the escape work moved — namespace, namespace alias,
using-directive, class-head, base-specifier, mem-initializer, scoped and
unscoped enum, type / template-template / constrained template parameters,
alias and alias-template, concept, label and `goto`, a three-component
nested-name-specifier, a constructor declarator, and two tentative-parse
ambiguities — one well-formed, one ill-formed throughout:

```
                            flag on vs flag off   flag off vs pristine build-main
-fsyntax-only, well-formed   IDENTICAL (0 lines)   IDENTICAL
-fsyntax-only, ill-formed    IDENTICAL (43 lines)  IDENTICAL
-ast-print                   IDENTICAL (77 lines)  IDENTICAL
-ast-dump                    IDENTICAL (277 lines) IDENTICAL
```

`-ast-dump` is compared with `0x[0-9a-f]+` normalized; that is the only
difference in it, and it is allocation addresses. `-ast-print` is the column
that matters here, because the printers are what this merge changed in shared
code: with `Policy.BacktickKeywordEscape` off, `printIdentifierSpelling` and
`DeclPrinter`'s policy-aware `printName` produce upstream's exact bytes. And a
bare backtick with the flag off is still upstream's *expected unqualified-id*,
identical on both binaries. `~/src/llvm/main` is the exact upstream base of
this branch (`git merge-base HEAD main` == `main` == `a815e6f267c1`), which is
what makes the third column a control rather than a coincidence.

## Both features work, and the backtick half is byte-identical to its own branch

- **19 targeted lit tests, 19 passed, 1.08 s** — the nine Unicode files
  (`Parser/unicode-operator-{precedence,infix,prefix,decl}.cpp`,
  `AST/unicode-operator-print.cpp`, `SemaCXX/unicode-operator-{semantics,adl}.cpp`,
  `Analysis/unicode-operator-analysis.cpp`,
  `CodeCompletion/unicode-operator-priority.cpp`) and the ten backtick ones,
  **including the merge's new `Parser/backtick-escape-positions.cpp`** and the
  two files carrying the aggregate cases.
- **The escape's broad positions and the aggregate slot were also run as a
  program**, not only as tests: a twenty-line TU that *declares and then uses*
  an escaped namespace, struct, alias, scoped enum, template type parameter,
  function and label, and applies `` 1 `Agg` 2 `` to an aggregate with a
  defaulted third member. It compiles clean (`EXIT=0`) on the merged branch
  **and on `build-backtick-trunk`**, and their `-Xclang -ast-print` output is
  **byte-identical** — the control that matters, since it says the backtick
  feature behaves here exactly as on the branch it was gated on. Every escaped
  name prints back escaped (`` namespace `namespace` ``, `` enum class `enum` ``,
  `` template <class `typename`> ``, `` `goto`: ``, `` goto `goto`; ``), which
  is `escape-name-positions`' printer half working through this branch's
  printers; `` Agg g = 1 `Agg` 2; `` prints as written, which is
  `settle-paper-rows`' arm. The `-ast-print` round trip itself is pinned by
  `Parser/backtick-escape-positions.cpp`'s third RUN line, which passes.

## Gate — GREEN, unfiltered, `EXIT=0`, first run

```
ninja -C ~/src/llvm/build-unicode check-clang > gate.log 2>&1 ; echo "GATE_EXIT=$?"

Total Discovered Tests: 54190
  Passed: 48302   Failed: 0   XFAIL: 27   Unsupported: 5855   Skipped: 6
  662.51 s      GATE_EXIT=0
```

**+1 discovered / +1 passed** over the Baselines row (54189 / 48301) **and
nothing else moves** — the one new lit file, landing in *passed* because it is
an ordinary lit test. The aggregate commit adds no file, its two cases going
into `Parser/backtick-infix.cpp` and `Parser/backtick-ast-print.cpp`, and lit
discovers files rather than cases.

Measured with `ulimit -c 0`, output redirected and the exit code captured
explicitly — `ninja … | tail` reports `tail`'s status.

**No `DirectoryWatcherTest` failures, and this is the first Unicode-branch
merge in this plan to go green on the first run.** The machine was quiet when
the gate started (about 100 inotify instances open across all processes) and
the run needed no repeat, so [`inotify-watch-budget`](../../BACKLOG.md#inotify-watch-budget)
cost nothing here. It has not gone away; it was simply not in the way.

Build: `EXIT=0`, **750 targets** (`DeclarationName.h` and `Parser.h` are both
in the merge), **zero `warning:` lines** in the log.

## Formatting

`git-clang-format --diff --commit 7278a2985659` with the **in-tree**
`clang-format` reports **one** region and it is **inherited**: the
`dyn_cast<CXXParenListInitExpr>` continuation in
`BacktickInfixExpr::getOperand`, **byte-identical to `backtick-trunk`**, so it
came across unchanged from a commit that gated green there. `clang/lib/AST/` is
not in `check-clang`'s self-format glob — re-read out of
`clang/lib/Format/CMakeLists.txt`, which globs `clang/lib/Format/**`,
`include/clang/Format/*.h`, `tools/clang-format/*.cpp` and
`unittests/Format/*.{cpp,h}` — and **this merge touches no file in that glob at
all**, so the step at ~81/970 was never in play. Reformatting it would make the
two branches differ for nothing; same disposition M2 and
unicode-branch-maintenance gave their inherited hits.

## What the probe sweep found — one new row, unowned

[escape-name-positions](escape-name-positions.handoff.md) closes with the
observation that *"the escape's coverage is now defined by a rule rather than by
a list, and a rule can be violated silently"*, and that the probe programs are
the cheap defence and are not in the repo. Rewriting them found a violation:
[`escape-in-qualified-type-name`](../../DEVIATIONS.md#escape-in-qualified-type-name).

**Clang does not reach the escape in a qualified *type-specifier*, and GCC
does.** Eight one-line programs, `-std=c++20 -fbacktick -fsyntax-only`, on the
merged `clang` and on `cc1plus` from `gcc-backtick-build`:

| Program | Clang | GCC |
|---|---|---|
| `` struct `union` { struct S{int a;}; }; `union`::S g; `` | accepts | accepts |
| `` struct `union` { struct S{int a;}; }; int f(){ `union`::S s; …} `` | accepts | accepts |
| `` namespace `namespace` { struct S{int a;}; } `namespace`::S g; `` | accepts | accepts |
| `` namespace `namespace` { struct S{int a;}; } int f(){ `namespace`::S s{1}; …} `` | **rejects** | accepts |
| `` namespace N { struct `union`{int a;}; } N::`union` g; `` | **rejects** | accepts |
| `` namespace N { struct `union`{int a;}; } using X = N::`union`; `` | **rejects** | accepts |
| `` namespace N { struct `union`{int a;}; } int f(){ return sizeof(N::`union`); } `` | **rejects** | accepts |
| `` namespace N { int `new` = 1; } int f(){ return N::`new`; } `` | accepts | accepts |

Two Clang sites, one shape: the escape is reached in a qualified name only
where the name is read as an *unqualified-id*, which is why the expression row
works and the type-specifier rows do not; and
`isCXXDeclarationSpecifier`'s escape arm answers with `Actions.getTypeName`,
which says *not a type* for a namespace and so parses the block-scope
declaration as an expression.

**It is not this merge's.** Every Clang reading reproduces byte-identically on
`build-backtick-trunk`'s binary, so it stands on both backtick branches and
predates the forward-port. **It is not fixed and it is not owned** — two parser
sites on two branches plus a test in each suite — and it implicates
[§12](../../../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers)'s
*"wherever the grammar uses `identifier` as a terminal"* and
[§17.8](../../../docs/backtick-operator-design.md#178-which-of-this-is-clangs-alone-and-why)'s
*"two kinds, and both are one-liners"*, which is now three and includes the
first divergence in which **GCC is the wider implementation**.

## Discoveries affecting later work

- **`backtick-trunk` and `unicode-operators-experiment` have no outstanding
  forward-port.** Everything on the backtick branches is landed here. The next
  one is created only by a backtick-track change that lands on the backtick
  branches alone.
- **`unicode-operators-upstream` must still never receive the merge.**
  Unchanged from M1, M2 and unicode-branch-maintenance, and restated because it
  is the whole hazard: that branch is `upstream/main` plus Unicode only.
- **The printers were never the collision risk, and the reason generalizes.**
  The two features share `tok::user_operator`/`tok::backtick`'s precedence
  level, `ParseExpr.cpp` and clang-format — the three constructs `REPLAY.md` §1
  already names as the entire coupling — and nothing else. A future merge should
  expect conflicts *there* and at the tooling anchors
  [unicode-branch-maintenance](unicode-branch-maintenance.handoff.md) lists, and
  not in name printing.
- **The four tooling anchors that carry two arms here and one upstream are
  unchanged** by this merge and the warning stands: copy the `UserOperatorExpr`
  *arm*, never the region.
- **The fold-guard failure output has four stanzas, not three.** Recorded
  above and in `REPLAY.md`.
- **Nothing is pushed.** `unicode-operators-experiment` is ahead of every remote
  by this merge and this repo by this commit. All four branches track
  `ceridwen`, **not** `origin`, and both remotes were in sync at the last push,
  so a push needs both. Pushing is the maintainer's call.

## Open risks / TODOs

- **[`escape-in-qualified-type-name`](../../DEVIATIONS.md#escape-in-qualified-type-name)
  is open and unowned**, above. Do not fix it by reflex on one branch: it is a
  two-site Clang change that has to land on `backtick-trunk` and `backtick-23`
  together, and the second site is inside a tentative-parse predicate, which is
  exactly where escape-name-positions found that *a predicate answers, a parse
  consumes*.
- **[`escape-type-keyword-binding`](../../gcc/DEVIATIONS.md#escape-type-keyword-binding)
  is still open and still the author's**, untouched here.
- **The probe programs are still not in the repo.** They have now caught
  something on all four occasions they have been run. Roughly forty one-line
  programs and a `bash` loop — `zsh` does not word-split, which has cost this
  track several sweeps.
- **Section 9's comment in `unicode-operator-precedence.cpp` is still stale**,
  as M2 and unicode-branch-maintenance both recorded: line 314 calls the fold
  behaviour *"pinned here, not endorsed"* when
  [fold-over-user-infix](../../../docs/open-decisions.md#fold-over-user-infix)
  was answered on 2026-09-06. It is a comment on all four branches and costs
  four gates; untouched again.
- **The inherited `ASTMatchersNodeTest.cpp` formatting region** from the last
  merge is still there, and still `backtick-trunk`'s to fix if anyone wants it
  fixed.
