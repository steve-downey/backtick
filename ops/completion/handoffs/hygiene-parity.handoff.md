# Handoff — hygiene-parity — The tooling-parity gaps, the dead code, the formatting limit

- **Status:** **DONE (gate passed on both backtick branches).**
- **Branch / commit:**
  - `backtick-trunk` — `c0d69702b6d7` (`~/src/llvm/backtick-trunk`)
  - `backtick-23` — `69ac49d3e209` (`~/src/llvm/backtick`) — cherry-pick, **regenerated and re-gated independently**
  - `unicode-operators` (this repo) — `1de6aae` (`docs:` — `docs/backtick-operator-design.md` §6 items 6 and 7, §7's break-policy bullet; `docs/unicode-operators.md` §8) and the `ops:` commit carrying five backlog rows, one ledger `Log.`, the plan and this handoff
- **Date / agent:** 2026-09-07.
- **Closes:** [`backtick-ast-matchers`](../../BACKLOG.md#backtick-ast-matchers),
  [`libclang-cursor-arm`](../../BACKLOG.md#libclang-cursor-arm),
  [`dead-nesting-diagnostic`](../../BACKLOG.md#dead-nesting-diagnostic),
  [`slot-split-penalty`](../../BACKLOG.md#slot-split-penalty); records
  [`template-id-code-point`](../../BACKLOG.md#template-id-code-point).
- **Deviation ledgers:** **no new row, and all three still read zero open.**
  [`bare-nesting-detection`](../../DEVIATIONS.md#bare-nesting-detection) gains a
  dated `Log.` and keeps its **RESOLVED** status; nothing else in any ledger
  was touched.
- **`REPLAY.md`:** **no row — nothing landed on a Unicode branch.** Neither
  Unicode worktree was modified; `~/src/llvm/unicode-upstream` was *read* and
  its pre-built `clang++` *run*, for the `U17` template and the
  [`template-id-code-point`](../../BACKLOG.md#template-id-code-point)
  measurements.
- **Papers:** **untouched, and checked before deciding not to touch them.**
  See *Verification evidence*.

---

## The four fixes, and what each one actually was

### [`backtick-ast-matchers`](../../BACKLOG.md#backtick-ast-matchers) — the matcher, and the sizing that held

`backtickInfixExpr()` follows `U17`'s `userOperatorExpr()` exactly:
`VariadicDynCastAllOfMatcher<Stmt, BacktickInfixExpr>` declared in
`ASTMatchers.h` beside `cxxRewrittenBinaryOperator`, defined in
`ASTMatchersInternal.cpp`, registered in `Dynamic/Registry.cpp`, plus the two
`TK_IgnoreUnlessSpelledInSource` traversal sites in `ASTMatchFinder.cpp` —
`TraverseBacktickInfixExpr` in the visitor and the `dyn_cast` arm in the
as-is/not-spelled scope pair. Without those two a matcher sees the synthesized
call rather than the operands, which the new test pins in both directions.

`clang/docs/LibASTMatchersReference.html` was **regenerated** with
`clang/docs/tools/dump_ast_matchers.py` on each branch, never hand-edited. The
script reads only the tree (`ASTMatchers.h` plus the class names it harvests
from `clang/include/clang/AST/*.h`) and needs no network.

**This is the one recorded estimate in five steps that held.** `U17` predicted
~5 production/docs files at +58 plus +59 of test; measured, 5 files at **+59**
(`ASTMatchers.h` +14, `ASTMatchFinder.cpp` +29, `ASTMatchersInternal.cpp` +2,
`Registry.cpp` +1, generated HTML +13) and **+56** of test. `clang-tidy`
itself needed nothing, as the row said. The only asymmetry with the Unicode
side is arity: `BacktickInfixExpr::getOperand(unsigned)` takes 0 or 1 and there
is no `getNumOperands()`, so both traversal sites loop `for (unsigned I = 0; I != 2; ++I)`.

### [`libclang-cursor-arm`](../../BACKLOG.md#libclang-cursor-arm) — one line, and ten weeks

One `case Stmt::BacktickInfixExprClass:` beside `CXXRewrittenBinaryOperatorClass`
in `MakeCXCursor`. **The row's claim that the warning was live was re-derived
rather than quoted**, by rebuilding that one object file before the fix:

```
$ ninja tools/clang/tools/libclang/CMakeFiles/libclang.dir/CXCursor.cpp.o
clang/tools/libclang/CXCursor.cpp:175:11: warning: enumeration value
    'BacktickInfixExprClass' not handled in switch [-Wswitch]
1 warning generated.
```

and the full post-fix rebuild of `clang` + `AllClangUnitTests` on
`backtick-trunk` — 493 targets — emits **zero** diagnostics of any kind. That
is the gate bullet the step asked for, and it is the only way to check it: the
build is `WERROR=OFF`.

**The interesting number is the elapsed time, not the line count.** `S11` added
the node on 2026-06-27, `U17` recorded the warning on 2026-08-04, and it was
still being emitted on 2026-09-07 — ten weeks, across every step of two tracks,
*including the step that wrote it down*. That is a real datum for
[`expression-node-cost`](../../unicode-operators/clang/DEVIATIONS.md#expression-node-cost)'s
taxonomy: its *found only by reading the build log* category is not merely
quiet, it is quiet for months, and a `-Wswitch` warning in a `WERROR=OFF`
configuration is empirically indistinguishable from silence. The taxonomy's
counts are unchanged and were not touched; what this adds is the half-life.

### [`dead-nesting-diagnostic`](../../BACKLOG.md#dead-nesting-diagnostic) — deleted, and the stale comments with it

`err_backtick_nested_requires_parens` removed from `DiagnosticParseKinds.td`.
Checked before deleting, as the step required: `git grep` over the whole tree
finds the identifier at its own definition and nowhere else, and no test
asserts its text.

The [nesting-vs-chaining](../../../docs/backtick-operator-design.md#nesting-vs-chaining)
lookahead was **not** implemented, and the step file is right that this is the
point. Two test comments were the residue of the design's old position and are
now the opposite of misleading:

- `clang/test/SemaCXX/backtick-semantics.cpp` said bare nesting "silently
  parses as h(f(x,g),y) (no error)… documented but not tested here to avoid
  anchoring the current **mis-behavior**; S06 or a future step will cover it."
  Every clause of that is now wrong: it is not a mis-behaviour, it is the
  design, and no future step is coming.
- `clang/test/Parser/backtick-diagnostics.cpp`'s `int x4 = a `g` b `f` c;` was
  labelled only as a chain. **It is also the bare-nesting spelling** — the two
  are token-identical, which is the whole argument — so it is annotated to say
  so. The form was already pinned; it is now pinned *as the thing the deleted
  diagnostic claimed to reject*.

### [`slot-split-penalty`](../../BACKLOG.md#slot-split-penalty) — implemented **and** the limit pinned

The step file offered implement-or-document. Both were possible and both were
done, because measuring the bump is what showed where it stops working.

`TokenAnnotator::calculateFormattingInformation` carries a line-local
`InBacktickSlot` toggled by `TT_BacktickInfixOpen`/`Close` and adds a flat
`PenaltyBreakInsideBacktickSlot = 100` to every token between them. The escape
pair is deliberately excluded: its slot is a single keyword token, so it has no
interior and the rule would be inert there. Verified in the annotator's own
debug dump — slot-interior `P=` values move 520→620, 23→123, 36→136, while the
close backtick and the right operand stay at 36.

**What it can do.** It decides ties. A qualified name inside the slot and one
outside price identically without it (both 520 for the identifier after `::`),
so clang-format splits whichever it reaches first — the slot. With the bump the
outer name breaks and the slot survives:

```
                                          ColumnLimit: 40
before   return aaaa::bbbb::cccc `xxxx::yyyy::      after   return aaaa::bbbb::
             zzzz` dddd;                                        cccc `xxxx::yyyy::zzzz` dddd;
```

Measured by diffing the pre-change binary against the post-change one over 10
shapes × every `ColumnLimit` from 20 to 90: **25 differing outputs, every one
in that direction**, and none anywhere else. An earlier sweep of 8 shapes found
**zero** differences, which is why the second sweep was written to hunt ties
specifically — a null result from a badly chosen corpus is not a null result.

**What it cannot do, which is the row's own worry.** Where *no* alternative
break fits inside the column limit, `PenaltyExcessCharacter` is 1,000,000 per
column and dominates any additive bump by three or four orders of magnitude, so
the slot is split anyway. A bump large enough to win that would be ≥ the excess
penalty, i.e. exactly the no-break zone
[format-break-policy](../../../docs/backtick-operator-design.md#format-break-policy)
rejects. **So the row's "a long multi-token slot would format badly" is true and
is not fully fixable within the decision**, and saying so is the answer, not a
deferral. Both halves are pinned by `FormatTest.BacktickOperatorSlotSplitPenalty`
and both are written into §7.

Three `// D8:` comments in `clang/lib/Format` and `clang/unittests/Format` were
renamed to `format-break-policy` — a retired serial number, in the code
implementing that exact decision, in the files this step was already editing.
Nothing else in either worktree was renamed; the other `D3` / `D16` / `S04`
comments are left, and are noted below.

## The one recorded item

### [`template-id-code-point`](../../BACKLOG.md#template-id-code-point) — recorded, and **cheaper than recorded**

Closed as *matches upstream's shape, latent, upstream's `FIXME` already exists*.
Re-derived by reading `Parser::ParseUnqualifiedIdTemplateId`
(`clang/lib/Parse/ParseExprCXX.cpp:2371-2394`, and note the function is not
`AnnotateTemplateIdToken`): `TemplateII` is non-null only for `IK_Identifier`,
so `IK_UserOperatorId` and `IK_LiteralOperatorId` alike get `nullptr`, and
`OpKind` is explicitly `OO_None` for the user operator.

**And the recorded cost is too high, which is a small instance of the pattern
this track keeps hitting.** The row grades it P2, and the in-tree `FIXME` beside
it says the gap "only costs diagnostic quality". Measured on
`~/src/llvm/build-unicode-upstream/bin/clang++`:

| Probe | Result |
|---|---|
| `template <typename T> int operator⊞(T, T);` used both infix and as `operator⊞<S>(a, b)` | compiles |
| a non-viable `operator⊞<S>(a, b)` | `error: no matching function for call to 'operator⊞'` — **named in full** |
| an *undeclared* `operator⊞<S>(a, b)` | `error: use of undeclared 'operator⊞'`, caret over `operator` only |
| the control, `operator""_sfx<'a'>()` undeclared, **no flag** | `error: use of undeclared 'operator""_sfx'`, caret over `operator` only |

Same message shape, same eight-column truncated caret, on a stock compiler for
the feature C++ already has. So there is **no observable cost at all** here, not
even the diagnostic-quality one the `FIXME` predicts, because the name a
diagnostic prints comes from the resolved `TemplateName` and not from the
annotation. Recorded in `docs/unicode-operators.md` §8's *Parser, declaring an
operator* bullet, appended rather than rewritten, per
[reconcile-remainder](reconcile-remainder.handoff.md)'s forward note.

**Nothing was changed on either Unicode branch.** Filling the slot in for user
operators and not for literal operators would be the odd choice, and the in-tree
`FIXME` is the right place for the note.

---

## What changed, and where

### The two backtick branches (identical content, gated separately)

| File | What |
|---|---|
| `clang/include/clang/ASTMatchers/ASTMatchers.h` | `backtickInfixExpr` declaration + doc comment |
| `clang/lib/ASTMatchers/ASTMatchersInternal.cpp` | its definition |
| `clang/lib/ASTMatchers/Dynamic/Registry.cpp` | `REGISTER_MATCHER(backtickInfixExpr)` |
| `clang/lib/ASTMatchers/ASTMatchFinder.cpp` | `TraverseBacktickInfixExpr` + the not-spelled-in-source arm |
| `clang/docs/LibASTMatchersReference.html` | **regenerated** |
| `clang/tools/libclang/CXCursor.cpp` | one `case` |
| `clang/include/clang/Basic/DiagnosticParseKinds.td` | `err_backtick_nested_requires_parens` **deleted** |
| `clang/lib/Format/TokenAnnotator.cpp` | the slot-interior penalty; one comment renamed |
| `clang/unittests/ASTMatchers/ASTMatchersNodeTest.cpp` | 2 new gtest cases |
| `clang/unittests/Format/FormatTest.cpp` | 1 new gtest case; one comment renamed |
| `clang/unittests/Format/TokenAnnotatorTest.cpp` | one comment renamed |
| `clang/test/SemaCXX/backtick-semantics.cpp`, `clang/test/Parser/backtick-diagnostics.cpp` | comments only, no assertions changed |

### This repo

- **`docs/backtick-operator-design.md` §6 item 6** — rewritten: there are two
  diagnostics, not three, and the paragraph says why the third was withdrawn
  rather than deleting the mention. **§6 item 7** gains a second paragraph, *the
  tooling surface*, where [reconcile-remainder](reconcile-remainder.handoff.md)'s
  forward note said it should go. **§7's break-policy bullet** gains the measured
  reach of the bump and the named limit.
- **`docs/unicode-operators.md` §8** — the *Parser, declaring an operator*
  bullet's `TemplateIdAnnotation` sentence, appended to.
- **`ops/BACKLOG.md`** — five `Closed by` cells. Two of them
  ([`dead-nesting-diagnostic`](../../BACKLOG.md#dead-nesting-diagnostic),
  [`libclang-cursor-arm`](../../BACKLOG.md#libclang-cursor-arm)) said **`BL06`**,
  a step that never ran and was superseded; they now name this one.
- **`ops/DEVIATIONS.md`** — one dated `Log.` on
  [`bare-nesting-detection`](../../DEVIATIONS.md#bare-nesting-detection).

---

## Verification evidence

### Gates

| Branch | Discovered | Passed | Failed | XFAIL | Skipped | Unsupported |
|---|---|---|---|---|---|---|
| `backtick-trunk` (`c0d69702b6d7`) | **54114** | **48228** | **0** | 27 | 6 | 5853 |
| `backtick-23` (`69ac49d3e209`) | **54348** | **48506** | **1** | 27 | 6 | 5808 |

Baseline before this step was 54111/48225/0 and 54345/48503/1. **Both rows move
by exactly +3 discovered / +3 passed and by nothing else** — the three new gtest
cases (`ASTMatchersTestBacktick.BacktickInfixExpr`,
`ASTMatchersTestBacktick.BacktickInfixExprTraversal`,
`FormatTest.BacktickOperatorSlotSplitPenalty`). Unsupported is unchanged, so all
three land in *passed*. Both run unfiltered, `ulimit -c 0`, exit code captured
explicitly rather than through a pipe.

`backtick-23`'s single failure is
[`stray-clang-format-config`](../../BACKLOG.md#stray-clang-format-config), the
permanent one: `Clang :: Format/dump-config-objc-stdin.m`, caused by a 2018
`Language: Cpp` file at `/home/sdowney/src/.clang-format` outside any repo. It
fails identically on the pristine `build-main` binary and is not to be "fixed".
`ninja check-clang` therefore exits 1 on that branch by design; the exit code
was captured and read rather than piped.

### The step's four named gate bullets

1. **`check-clang` green on both branches against the baselines** — above.
2. **`ast_matchers_updated.test` passes with the regenerated HTML** — it does,
   on both. On `backtick-23` the cherry-picked HTML was **regenerated again from
   scratch** before building, and `git status` came back clean: the 23.x base
   has the same matcher set here, so the generated file is identical. That check
   was worth running rather than assuming — a generated file that happens to
   cherry-pick cleanly is not evidence that it is what the generator produces.
3. **The `-Wswitch` warning is gone** — the full rebuild of `clang` +
   `AllClangUnitTests` on `backtick-trunk` (493 targets) has `grep -c warning`
   = **0**. The pre-fix single-object rebuild is quoted above.
4. **Four `Closed by` cells filled plus the recorded row** — five cells, each
   naming its destination section.

### The papers, checked and deliberately not edited

The step has no paper consequence, but that is a claim, so it was checked rather
than assumed — the last three steps each found a paper carrying something its
own answers had discarded.

- `papers/d4307r0.md` §*Bare nesting is chaining; real nesting takes parentheses*
  already says the form "cannot be diagnosed without contradicting
  left-associativity, and it does not need to be". Deleting the diagnostic
  **confirms** that paragraph; nothing to change.
- Its implementation-experience section says both parsers accept the form as a
  chain. Still true.
- `docs/infix-backtick-operator.org` says the same in the informal register.
  Still true.
- Neither paper nor the `.org` mentions libclang, ASTMatchers, clang-tidy,
  clang-query or `SplitPenalty` at all — so nothing there is falsified by the
  parity work, and nothing was added.

### Links and identifiers

**2310 local Markdown links** across every tracked `.md` outside `papers/wg21/`,
**0 broken** — file existence plus GitHub-style anchor slugs, links inside
inline code spans and fenced blocks excluded. **No internal identifier was
introduced into `papers/`**, which were not opened for editing at all.

---

## Deviations from the step file

1. **Three `// D8:` code comments were renamed** to the
   [format-break-policy](../../../docs/backtick-operator-design.md#format-break-policy)
   slug. Not in the step's list. It is a bounded set (a `git grep` for our
   retired ids over `clang/lib/Format` and `clang/unittests/Format` finds
   exactly these three), it is the decision this step implements, and all three
   files were being edited anyway. **Other retired ids in the worktrees were
   left alone** — see the risks below.
2. **Two test files gained comment-only edits**
   (`backtick-semantics.cpp`, `backtick-diagnostics.cpp`). The step file only
   said to check that no test asserts the deleted diagnostic's text. It does
   not, but one of them asserted in prose that the accepted behaviour was a
   *mis-behaviour awaiting a future step*, which the deletion makes actively
   false. No assertion was touched and no test count moved.
3. **`docs/backtick-operator-design.md` §6 item 6 was rewritten**, which is a
   design-doc edit the step file did not schedule. It had to be: item 6 listed
   the deleted diagnostic as one of three to write, so deleting the code without
   it would have left the design doc specifying a diagnostic that no longer
   exists.
4. **[`slot-split-penalty`](../../BACKLOG.md#slot-split-penalty) was closed by
   doing both of the step's two alternatives**, not one. The document-the-limit
   branch was written *because* implementing the bump is what located the limit.

---

## Discoveries affecting later steps

- **A null result from a sweep is only as good as its corpus.** The first
  before/after formatting sweep — 8 shapes × 17 column limits — found zero
  differences and would have supported "the bump is inert, close it as a known
  limit". It was wrong. The bump decides *ties*, so a corpus has to contain
  ties: two structures of the same shape, one inside the slot and one outside.
  The second sweep was built that way and found 25. **If a measurement is going
  to justify a negative conclusion, design the corpus for the mechanism, not for
  the symptom.**
- **A generated file is not verified by a clean cherry-pick.** `git
  cherry-pick` reproduced `LibASTMatchersReference.html` byte-for-byte on
  `backtick-23`, which proves only that the two bases have the same
  neighbourhood in that file. Re-running the generator is a different check and
  is the one the gate actually tests.
- **`clang/unittests/` is built into one `AllClangUnitTests` binary in these
  build dirs**, and `ninja ASTMatchersTests` is *not* a target — but
  `ninja FormatTests` **is**, and the `FormatTests` executable exists separately
  under `tools/clang/unittests/Format/`. The Format gtests are **not** in
  `AllClangUnitTests`: `AllClangUnitTests --gtest_filter='*BacktickOperator*'`
  reports "0 tests" and looks exactly like a missing test. Run
  `./tools/clang/unittests/Format/FormatTests` for those.
- **The `-Wswitch` half-life is ten weeks on this project**, measured. Anything
  that reasons about how a compiler announces the cost of a new AST node should
  use that rather than "the build tells you".
- **`ninja` progress in a redirected log shows the last edit *started*, not
  finished**, so a log whose tail sits on one file for ten minutes is normal
  under 20-way parallelism and is not a hang. Check `ps` for live compilers
  before concluding anything.

---

## Forward notes for the NEXT step — [backtick-paper](../steps/backtick-paper.md)

Written after reading its step file.

- **Its dependency list is now fully met.** `clang-paper-truth`,
  [clang-slot-adl](clang-slot-adl.handoff.md), `reconcile-remainder` and this
  step are all green. Nothing else gates it.
- **This step gives the paper nothing to say, and that is the useful fact.**
  Its "parity gaps closed so the paper does not have to explain them" clause is
  discharged: a reviewer comparing the two features will now find both with an
  ASTMatchers matcher, a Registry entry, a libclang cursor arm and a regenerated
  reference doc. **Do not add a tooling section.** The one sentence worth
  lifting, if any, is the half-life datum — a `-Wswitch` warning on a
  `WERROR=OFF` build went unfixed for ten weeks across two tracks *including
  the step that recorded it* — which belongs beside §17.6's "the compiler tells
  you about exactly one of seven", if the paper makes that argument at all.
  §6 item 7's new second paragraph is the design-doc text to work from.
- **One design-doc claim is new and quotable**: §7 now says the slot-interior
  penalty is implemented, decides ties, and **cannot** beat the
  excess-character penalty, with both halves pinned by one test. If the paper
  says anything about formatting, that is the honest form of it — *stickier
  than its surroundings, not atomic*.
- **§6 item 6 changed under you.** The design doc used to specify three
  diagnostics; it now specifies two, with a paragraph about the withdrawn third.
  `papers/d4307r0.md` was checked and needs no change — its nesting section
  already argues the form should not be diagnosed — but if you touch that
  section, the implementation now *agrees with it in code*, which it did not
  before, and that is a stronger sentence than the one there.
- **The `.md` → paper build was not exercised here.** `make -C papers` has not
  been run in this session by anyone; budget for it being the first thing that
  is broken.
- **Its gate is a count**: how many "we implemented X" claims were checked and
  whether any failed. Three of this step's five rows had a recorded fact that
  measurement corrected (the `U17` sizing held; the libclang timeline, the
  `TemplateIdAnnotation` cost, and the split-penalty reach did not match what
  was written). **Assume the paper's claims are wrong at a similar rate** and
  budget the check accordingly.

---

## Open risks / TODOs

- **The queued forward-port to `unicode-operators-experiment` just got bigger,
  and it is still not mine.** `M2` already owed that branch
  [evidence-debt](evidence-debt.handoff.md)'s test-only port and
  [clang-slot-adl](clang-slot-adl.handoff.md)'s parser change. **This commit
  adds five more files to it**, and three will conflict rather than merge
  cleanly, because the Unicode branch already edits the same lines for
  `UserOperatorExpr`: `ASTMatchers.h` (the new matcher goes immediately after
  `cxxRewrittenBinaryOperator`, where `userOperatorExpr` already sits),
  `ASTMatchersInternal.cpp` (same two lines), and `ASTMatchFinder.cpp` (both
  traversal sites are adjacent to `U17`'s). `CXCursor.cpp` will conflict as
  two `case` labels wanting the same line. **The resolution is always "keep
  both, backtick after Unicode"** — they are independent nodes. `Registry.cpp`
  is alphabetical and `backtickInfixExpr` sorts nowhere near `userOperatorExpr`,
  so that one is clean. It will still ride one merge.
- **`clang/lib/Format/TokenAnnotator.cpp` will also conflict on that merge**, in
  `calculateFormattingInformation`'s locals and in `canBreakBefore` — the
  Unicode branches have their own edits nearby. The slot-penalty block is
  self-contained and has no Unicode counterpart (the Unicode operator is a
  single token, so it has no slot).
- **Retired serial numbers survive in the worktrees' code comments.** This step
  renamed the three `D8`s it was already touching and left the rest: `D3`,
  `D16`, `S04`, `S06`, `DEV-04`, `U16` and others appear in comments in
  `clang/lib/Parse`, `clang/lib/Sema`, the backtick tests and — on the Unicode
  branches — in `ParseExprCXX.cpp`'s `TemplateIdAnnotation` `FIXME`. Renaming
  them is a real job with a real cost (a full gate per branch for comment
  edits) and nobody owns it. It is **not** urgent: the code is not the document
  a second reader follows by reference.
- **The `TemplateIdAnnotation` `FIXME` on both Unicode branches overstates its
  own cost** — it says the gap "only costs diagnostic quality (U16)", and this
  step measured the diagnostic quality to be indistinguishable from upstream's.
  Correcting a comment would cost two full gates. Left as it is, with the
  measurement in `docs/unicode-operators.md` §8 where a reader will find it.
- **`dispatch-obligation-taxonomy` (U§8) could take the half-life datum** and
  did not, because [reconcile-implementation-cost](reconcile-implementation-cost.handoff.md)'s
  forward notes ask that its counts and taxonomy be left alone. The datum is in
  the backtick design doc's §6 item 7 instead.
  [unicode-paper](../steps/unicode-paper.md) may want it.
- **Nothing is pushed.** This repo and both backtick worktrees are ahead of
  every remote, as they were before this step.
