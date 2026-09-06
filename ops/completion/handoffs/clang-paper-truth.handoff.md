# Handoff — clang-paper-truth — The three Clang defects that falsify a claim

- **Status:** **DONE (gate passed on both branches).**
- **Branch / commit:**
  - `backtick-trunk` — `5f70443430b8` (`~/src/llvm/backtick-trunk`)
  - `backtick-23` — `2f4f59444d07` (`~/src/llvm/backtick`), cherry-picked and
    re-gated independently
  - `unicode-operators` (this repo) — `413fbc3` (`docs:`, the design doc) and
    `cf6c1ad` (`ops:`, the ledgers, the backlog, the plan and this handoff)
- **Date / agent:** 2026-09-06.
- **The dependency note the step file asked for:** [decision-brief](decision-brief.handoff.md)
  was **not** blocked — it was answered on 2026-09-06 and all five answers are
  "change no code", so nothing landed on top of this work.

## The three defects: what was wrong, and what a document had claimed

### [c-mode-tokenization](../../BACKLOG.md#c-mode-tokenization) — the flag was not C++-only

`defm backtick` had no `ShouldParseIf<cplusplus.KeyPath>`, so `-fbacktick`
reached `LangOptions` in a C compilation. **The row's own re-grade was right
and is now measured a third time**: on the pre-fix binary,

```
$ clang -cc1 -fbacktick -fsyntax-only -x c -   # int f(int a,int b){ return a `g` b; }
exit=0                                          # C accepts the C++ infix grammar
$ clang -cc1            -fsyntax-only -x c -
error: expected ';' after return statement       exit=1
```

The claim it falsified is [feature-gating](../../../docs/backtick-operator-design.md#feature-gating)'s:
a flag that "keeps existing valid programs unchanged" was making an invalid C
program valid. The fix is the one line the Unicode branch has carried since
`U04`, plus the comment block above it.

### [backtick-source-range](../../BACKLOG.md#backtick-source-range) — the wrapper did not span what was written

`BacktickInfixExpr::getBeginLoc`/`getEndLoc` forwarded to `Inner`, whose range
is `BuildCallExpr`'s — the synthesized callee, i.e. the operator slot. `` 1
`add` 2 `` reported `<col:16, col:19>` instead of `<col:13, col:21>`.

**This is the one that falsified a document outright.** `docs/backtick-operator-design.md`
§17.5, written on 2026-09-06 by [upstream-triage](upstream-triage.handoff.md)
to close [inner-call-source-range](../../BACKLOG.md#inner-call-source-range)
WONTFIX, says "the wrapper node spans the written expression; the call it
wraps does not, and that is deliberate." Neither half was true of the build:
the wrapper spanned exactly what the call did. The WONTFIX argument survives —
it was an argument about which node a tool should read — but its premise had
to be made true, and [source-fidelity-node](../../../docs/backtick-operator-design.md#source-fidelity-node)
now carries a dated entry saying so.

**Wider than the step file scoped it.** The step file and `BL06` both frame
the fix in terms of `getCallExpr()`. That is a *call*-only recovery, and
`BL02` added the type slot after `BL06` was written: `` 1 `Pt` 2 `` desugars to
a `CXXTemporaryObjectExpr`, for which `getCallExpr()` is null, so a call-only
fix would have left every type-slot node — five of the eleven in
`backtick-infix.cpp` — still reporting the operator slot, and would have
created a parity gap between the two halves of the same syntax. The fix
recognises the same three shapes `StmtPrinter::VisitBacktickInfixExpr` already
reconstructs from.

### [keyword-escape-round-trip](../../BACKLOG.md#keyword-escape-round-trip) — the escape did not round-trip, and the fix is a decision

`` void `new`(); `` printed as `void new();`, which does not re-parse. The
paper claim it falsifies is `papers/d4307r0.md`'s implementation-experience
bullet, *"a transparent AST wrapper so `-ast-print` round-trips the surface
syntax"* — true of the infix form, false of the escape, and the escape is half
the paper.

**The row understated the scope by five sites.** `DeclarationName::print`'s
`Identifier` arm is where the escaping goes, but three other paths never reach
it and one reaches it when it should not:

| Site | Why it needed touching |
|---|---|
| `DeclarationName::print` | the escape itself, behind the new policy bit |
| `DeclPrinter::VisitTypedefDecl` / `VisitFieldDecl` / `VisitVarDecl` | they hand the name to the **type** printer as a placeholder `StringRef` from `NamedDecl::getName()`; a field `` int `delete`; `` printed bare while the function beside it printed escaped |
| `StmtPrinter::VisitMemberExpr` | prints through `operator<<(raw_ostream&, DeclarationNameInfo)`, which constructs a default `PrintingPolicy` |
| `ASTDiagnostic`'s `ak_declarationname` | same policy-free stream operator — and its `ak_nameddecl` sibling **already** used `ASTContext::getPrintingPolicy()`, so the diagnostic surface was internally split before anything changed: *"redefinition of `` `new` ``"* against *"no matching function for call to `new`"*, about the same entity |
| `TextNodeDumper::VisitMemberExpr` | gated the **other** way: it prints `*getMemberDecl()`, and `operator<<(raw_ostream&, const NamedDecl&)` *does* take the context's policy, so `-ast-dump` would have escaped member names while `VisitNamedDecl` printed every other name bare |

**The decision the step file demanded, made and written down.** The rule is:
*the escape is part of the name's spelling, so every printer handed the
compilation's policy puts it back — `-ast-print` and diagnostics alike — and
`-ast-dump` is the one view that keeps the bare identifier, because the dump is
the evidence that the name really is ordinary.* It is
[keyword-escape-printing](../../../docs/backtick-operator-design.md#keyword-escape-printing)
in the decisions log, with its reversal cost stated, and §12 carries the
two-sentence version a paper can cite. See **Open risks** below: the author has
not ruled on it.

## What changed

**`backtick-trunk` `5f70443430b8`, identical on `backtick-23` `2f4f59444d07`.**
9 source files, 5 test files, +215/−14.

- `clang/include/clang/Options/Options.td` — `ShouldParseIf<cplusplus.KeyPath>`
  on `defm backtick`, with the four-line comment saying what the symptom was.
- `clang/include/clang/AST/Expr.h` — `BacktickInfixExpr::getOperand(unsigned)`
  declared, `getBeginLoc`/`getEndLoc` rewritten to use it, `getSourceRange()`
  added. The doc comment is the counterpart of `UserOperatorExpr`'s.
- `clang/lib/AST/Expr.cpp` — `BacktickInfixExpr::getOperand` out of line, next
  to `getCallExpr()`. Recognises `CallExpr`, `CXXTemporaryObjectExpr`,
  `CXXUnresolvedConstructExpr`; returns null otherwise. **Indexes** rather than
  counting back from the last argument, because a selected overload may carry
  default arguments past the two operands.
- `clang/include/clang/AST/PrettyPrinter.h` — `BacktickKeywordEscape : 1`,
  initialised `BacktickKeywordEscape(LO.Backtick)`. Declared **last**, after
  `SuppressLambdaBody`, to match the initialiser order.
- `clang/lib/AST/DeclarationName.cpp`, `DeclPrinter.cpp` (new file-static
  `writtenDeclName`), `StmtPrinter.cpp`, `ASTDiagnostic.cpp`,
  `TextNodeDumper.cpp` — the five routing sites in the table above.
- Tests: new `clang/test/Lexer/backtick-c-mode.c`; `-ast-print` + re-parse RUN
  lines and three declarator cases on `backtick-escape.cpp`; two
  diagnostic-wording cases on `backtick-escape-diagnostics.cpp`; literal column
  ranges and a `` `__builtin_shufflevector` `` case on `backtick-infix.cpp`;
  the false comment at the foot of `backtick-ast-print.cpp` replaced.

**This repo.** `docs/backtick-operator-design.md`: the new decision entry
[keyword-escape-printing](../../../docs/backtick-operator-design.md#keyword-escape-printing);
dated `Log.` entries on [feature-gating](../../../docs/backtick-operator-design.md#feature-gating)
and [source-fidelity-node](../../../docs/backtick-operator-design.md#source-fidelity-node);
§6.4's "enough for source ranges" clause corrected and §6.5 given the
`ShouldParseIf` sentence; §12's new **Printing and diagnostics** paragraph;
§17.5's two new paragraphs. Ledgers and backlog per the table below.

## Verification evidence

### Gates

Both run unfiltered, `ulimit -c 0`, redirected with the exit code captured
explicitly — never through `tail`.

| Branch | Discovered | Passed | Failed | XFAIL | Unsupported | Skipped | `EXIT` |
|---|---|---|---|---|---|---|---|
| baseline `backtick-trunk` | 54108 | 48222 | 0 | 27 | 5853 | 6 | — |
| **`backtick-trunk` after** | **54109** | **48223** | **0** | 27 | 5853 | 6 | **0** |
| baseline `backtick-23` | 54342 | 48500 | 1 | 27 | 5808 | 6 | — |
| **`backtick-23` after** | **54343** | **48501** | **1** | 27 | 5808 | 6 | **1** |

`+1` discovered and `+1` passed on each: `clang/test/Lexer/backtick-c-mode.c`,
the only file added. `backtick-23`'s single failure is
[stray-clang-format-config](../../BACKLOG.md#stray-clang-format-config),
`Clang :: Format/dump-config-objc-stdin.m`, expected and unchanged. **The
plan's Baselines table is updated in the `ops/completion/PLAN.md` Status log,
not in `ops/backlog/PLAN.md`.**

**One environment reading, recorded because the next agent will hit it.** The
first completed `backtick-trunk` gate reported `Failed: 1` —
`DirectoryWatcherTest/InitialScanAsync`, one of the eight the plan's gate facts
name. Confirmed environmental exactly as the plan requires and **not** budgeted:
`sysctl fs.inotify.max_user_watches` = 524288; all 8 pass on the pristine
`~/src/llvm/build-main` binary; all 8 pass on the freshly built
`backtick-trunk` binary, and `InitialScanAsync` passes `--gtest_repeat=5`. It
is a timing flake under load, not a watch-budget exhaustion — the machine was
at load 27 finishing a full rebuild. Re-running `check-clang` on the settled
build gave `Failed: 0` and `EXIT=0`, and those are the numbers in the table.

### Each fix demonstrated failing first — not assumed

Run against the **pre-fix** `backtick-23` binary (`1cf901e79df4`, clang 23.1.0-rc2),
using the new tests' own content, before the cherry-pick:

- **c-mode.** `-cc1 -fbacktick -fsyntax-only` on `backtick-c-mode.c` exits **0**
  and prints nothing; without the flag it exits 1 with the stray-backtick
  error. So both of the test's assertions fail: `not` on the first RUN line,
  and the `diff` on the third. A test that only checked the diagnostic text
  would have passed with the bug present, which is why it does not.
- **Source range.** The pre-fix dump gives `<col:16, col:19>`, `<col:25,
  col:28>`, `<col:17, col:20>` … against the pinned `<col:13, col:21>`,
  `<col:13, col:30>`, `<col:13, col:22>`, `<col:16, col:23>`. Note the old
  assertions were `BacktickInfixExpr {{.*}} 'int'` — the wildcard swallowed the
  range, so **the fix could not have failed them**; that is why the step file
  said to tighten first.
- **Escape.** Pre-fix `-ast-print` of `backtick-escape.cpp` emits `void new();`,
  `int delete;`, `s.delete`, `a `(new)` b`; re-parsing it gives **13 errors**.
  Post-fix it emits the backticks and re-parses with exit 0.

### What was checked, not only changed

- **The `-ast-dump` split is upstream's, not ours, and was found by measuring
  rather than reasoned about.** `TextNodeDumper::VisitNamedDecl` prints through
  `operator<<(raw_ostream&, DeclarationName)`, which builds a
  `PrintingPolicy(LangOptions())`; `VisitMemberExpr` prints `*getMemberDecl()`,
  and `operator<<(raw_ostream&, const NamedDecl&)` calls `printName(OS)`, which
  takes `getASTContext().getPrintingPolicy()`. The first `-ast-dump` run after
  the `DeclarationName` change showed `FunctionDecl … delete` beside
  `MemberExpr … .`delete`` in the same dump. Same shape in
  `ASTDiagnostic.cpp`'s two argument kinds.
- **`IdentifierInfo::getTokenID() != tok::identifier` is the right predicate**,
  and is exactly `isKeyword(LangOpts)` for this purpose without needing
  `LangOptions` in a printer: `IdentifierTable::AddKeyword` gives a
  non-`identifier` `TokenID` only for `KS_Enabled` / `KS_Extension`, and
  `KS_Future` keywords are added as `tok::identifier` with
  `setIsFutureCompatKeyword`. Read out of `clang/lib/Basic/IdentifierTable.cpp`,
  not assumed.
- **The guard the plan says fails silently is intact on all four branches —
  and the plan names it with the wrong symbol on two of them.** It is
  `Level != prec::`**`Backtick`** in `Parser::isFoldOperator` on `backtick-trunk`
  and `backtick-23`, and `Level != prec::`**`UserInfix`** on
  `unicode-operators-experiment` and `unicode-operators-upstream`; the
  precedence level itself is `prec::Backtick = 16` on the backtick branches.
  The plan's Gate facts and `REPLAY.md` say `prec::UserInfix` for all four, so
  the obvious grep comes back **empty on a backtick branch and looks exactly
  like the silent loss the fact exists to warn about**. Corrected in the Gate
  facts; all four verified by reading the predicate out of each worktree.
  Nothing here goes near it.
- **Formatting.** `git-clang-format --diff --commit HEAD` with the in-tree
  binary is clean over everything this step wrote. Its one remaining hit is the
  pre-existing `.stream(` continuation style in `DeclPrinter::VisitFieldDecl`,
  which upstream already disagrees with and which was left alone. Nothing in
  `clang/lib/Format/` or `clang/unittests/Format/` was touched, so the
  self-format step at ~81/970 is not in play.
- **Link check, repo-wide.** 1612 local Markdown links, 8 broken — **all eight
  pre-existing** and none of them created or touched here (they are the
  date-headed `docs/open-decisions.md` anchors and three `<path>`-placeholder
  examples inside handoff prose).

## Rows closed, and where each landed

**Backlog** — three `Closed by` cells filled, each naming the section it
reconciled into:

| Row | Destination |
|---|---|
| [c-mode-tokenization](../../BACKLOG.md#c-mode-tokenization) | [feature-gating](../../../docs/backtick-operator-design.md#feature-gating)'s **2026-09-06 `Log.` entry** (the whole entry) and **§6.5**, its closing sentence |
| [backtick-source-range](../../BACKLOG.md#backtick-source-range) | **§17.5**, the two new paragraphs after *"The corollary for anyone replaying this"*; [source-fidelity-node](../../../docs/backtick-operator-design.md#source-fidelity-node)'s **2026-09-06 `Log.` entry**; **§6.4**, the sentence beginning *"They are **not** enough"* |
| [keyword-escape-round-trip](../../BACKLOG.md#keyword-escape-round-trip) | **§3**, the whole new [keyword-escape-printing](../../../docs/backtick-operator-design.md#keyword-escape-printing) entry; **§12**, the **Printing and diagnostics** paragraph immediately before **Costs.** |

**Deviation ledger** — one correction and one new row:

- [backtick-source-locations](../../DEVIATIONS.md#backtick-source-locations)
  gains a dated **Correction** paragraph. The row is `RECONCILED` and stays
  `RECONCILED`; what is corrected is one clause of its *What was true* —
  *"This is sufficient for round-trip and for source ranges"* — which was false
  about ranges and had been reconciled into §6.4 as written. The
  no-separate-fields finding it exists for still holds.
- [keyword-escape-printing](../../DEVIATIONS.md#keyword-escape-printing) is
  **new**, and **RECONCILED** on the day it was written, naming §3's entry and
  §12's paragraph. Its *What was true* is the six-site tally above, including
  the two upstream splits that were there before this feature.
- [flag-language-mode](../../unicode-operators/clang/DEVIATIONS.md#flag-language-mode)
  (Unicode ledger, **not** closed here — it is
  [reconcile-implementation-cost](../steps/reconcile-implementation-cost.md)'s)
  gains a dated **Note** saying the backtick debt it records is paid, with two
  corrections to its measurement: for `-fbacktick` the symptom was *acceptance*,
  not a worse diagnostic, and therefore a diagnostic-text test would not have
  been enough. Its `Status:` is untouched.

## Deviations from the step file

1. **The source-range fix is `getOperand`, not `getCallExpr`.** Reason above:
   the type slot post-dates `BL06`. The step file's "Cheap now that
   `getCallExpr()` exists" is still true — `getOperand` is 15 lines and uses it
   — but a fix that stopped there would have been half a fix.
2. **The escape fix is six sites, not one.** The step file names
   `DeclarationName::print` and says correctly that it needs a `PrintingPolicy`
   bit and a decision. It does not say that four other printers route around
   that function; nobody knew.
3. **The diagnostic decision was taken by this step rather than referred.** The
   step file's gate says "the diagnostic-wording decision is written down
   somewhere a paper can cite", which reads as an instruction to decide, and
   the fix cannot be landed without deciding. Flagged under Open risks all the
   same.
4. **`clang/test/Lexer/backtick-c-mode.c` is not a byte copy** of the Unicode
   branch's file: its header comment drops the `-funicode-operators` pairing
   (that flag does not exist on these branches) and the reference to the
   ledger's old serial number, and states the acceptance symptom, which is the
   backtick-specific one.

## Discoveries affecting later steps

- **`PrintingPolicy` now has a bit that reaches diagnostics.** Any step adding a
  test whose expected diagnostic names a keyword-escaped entity must write the
  backticks. Only `-fbacktick` / the escape is affected.
- **`BacktickInfixExpr::getOperand(unsigned)` exists** and is the right way to
  get the operands as written from anywhere — analysis, matchers, libclang. It
  is the counterpart of `UserOperatorExpr::getOperand`, with one deliberate
  difference: the backtick member form puts the *object* in the operator slot,
  so operand 0 is `getArg(0)` and there is no `CXXMemberCallExpr` special case.
  `UserOperatorExpr` needs one because its member form's object *is* operand 0.
- **`backtick-escape.cpp` now has four RUN lines**, two of them `-ast-print`.
  Anything added to that file must round-trip.
- **The PCH trap that cost this step ~90 minutes.** A mid-run `llvm-23` package
  upgrade on the host replaced `/usr/bin/clang++-23`; the running `check-clang`
  died with `error while loading shared libraries: libclang-cpp.so.23.1`, and
  the next ninja invocation rebuilt **all 4044** targets because the CMake PCH
  was stale. If a gate dies with a linker/loader error from the *host*
  compiler, it is not your diff; re-run it, and budget a full rebuild.

## Forward notes for the NEXT step — [null-return-suppression](../steps/null-return-suppression.md)

Read after reading its step file.

- **Both backtick build dirs are current and fully built** at the new commits,
  and `~/src/llvm/build-backtick-trunk` was rebuilt from scratch today, so its
  ccache/PCH state is fresh. The two Unicode build dirs were **not** touched and
  may still hit the same host-compiler PCH invalidation on their first ninja —
  budget for it before concluding anything about your own diff.
- Your step touches `clang/test/Analysis/backtick-infix.cpp`, which this step
  did **not** change: it passed unmodified through the source-range fix, so the
  analyzer's expected output does not carry backtick wrapper ranges. Do not
  expect churn there from this step.
- The seventh site you are looking for is in `BugReporterVisitors.cpp`; nothing
  here moved it.
- **Your `bugs_are_still_found` rewrite has a new neighbour to keep consistent
  with:** `backtick-infix.cpp` (the Parser one, not the Analysis one) now pins
  literal `<col:N, col:M>` ranges. If you add lines to *that* file the columns
  are unaffected, but if you add lines **before** line 108 the
  `` `__builtin_shufflevector` `` case's `<col:40, col:63>` is a *column*, not a
  line, so it still holds. Only re-indentation would break it.

**For [hygiene-parity](../steps/hygiene-parity.md)**, which depends on this
step: [libclang-cursor-arm](../../BACKLOG.md#libclang-cursor-arm) is still
open and `CXCursor.cpp` is untouched, and
[dead-nesting-diagnostic](../../BACKLOG.md#dead-nesting-diagnostic)'s
`err_backtick_nested_requires_parens` is still present and still unfired —
`git grep` in `clang/` finds only its definition in
`DiagnosticParseKinds.td`. Neither was in scope here.

**For M2**, which the step file says becomes runnable now: it forward-ports
`BL02` **and this commit** to `unicode-operators-experiment`. Three warnings
worth having in advance:

1. `PrettyPrinter.h` conflicted on `backtick-23` because the 23.x base lacks
   `PrettyEnums` in the constructor's initialiser list. Expect the same shape of
   conflict wherever the Unicode branches' bases differ; the resolution is
   always "keep the branch's list, append `BacktickKeywordEscape(LO.Backtick)`
   last", and the **field must stay declared last too**, after
   `SuppressLambdaBody`, or the initialiser order warning fires.
2. The Unicode branches already carry `ShouldParseIf<cplusplus.KeyPath>` on
   `defm backtick` (that is where it came from) and already have
   `clang/test/Lexer/backtick-c-mode.c`. **Those two hunks will conflict as
   already-applied.** Take the Unicode branch's version of the test file — it
   is the original, and its header comment is correct there — and drop the
   `Options.td` hunk entirely.
3. The escape fix's six sites are all in files the Unicode feature also edits,
   but `UserOperatorExpr` has no keyword-escape, so there is no interaction to
   reason about — only textual conflicts. `TextNodeDumper::VisitMemberExpr` and
   `StmtPrinter::VisitMemberExpr` are the two most likely, since U17 touched
   that area.

## Open risks / TODOs

- **The author has not ruled on
  [keyword-escape-printing](../../../docs/backtick-operator-design.md#keyword-escape-printing).**
  It changes user-visible diagnostic text under `-fbacktick`, which is the one
  thing the step file warned against doing accidentally — so it was done
  deliberately, argued, and written down, and the entry states the reversal
  cost (one more policy bit plus an opt-in at each printer entry point).
  Nothing else in the repo depends on the answer. If the author prefers
  diagnostics to stay bare, the change is confined to `ASTDiagnostic.cpp`'s
  gate plus a second bit; the two tests that pin it are the last block of
  `backtick-escape-diagnostics.cpp`.
- **`papers/d4307r0.md` was not edited.** Its round-trip claim (the Clang
  bullet in *Implementation experience*) was false for the escape and is now
  true, so nothing there needs correcting — but
  [backtick-paper](../steps/backtick-paper.md) can now say something stronger
  than it could yesterday: that the escape round-trips, that the flag is inert
  in C, and that the wrapper's range is the written extent. All three are
  measured and pinned, and all three are exactly the sort of claim a reviewer
  checks.
- **The GCC side has no counterpart to the escape's printing question**, because
  GCC has no `-ast-print`. Whether its diagnostics name a keyword-escaped entity
  with or without backticks was **not** measured here and is a cross-compiler
  divergence candidate — the kind `ops/gcc/DEVIATIONS.md` exists for. Cheap to
  check with the built `cc1plus`; nobody owns it.
