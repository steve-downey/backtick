# Handoff — reconcile-implementation-cost — U§8, the implementation-cost thesis

- **Status:** **DONE (docs gate passed).**
- **Branch / commit:** no branch. `unicode-operators` in *this* repo only —
  `5eedb6a` (`docs:` — U§8) and `5c9e109` (`ops:` — the eight rows, the ledger
  header, the backlog row, the plan and this handoff).
  **Nothing was built and no feature branch was touched** — the four LLVM
  worktrees and the GCC one were *read*, to re-derive counts and to confirm the
  flag guards, and none of them was modified.
- **Date / agent:** 2026-09-06.
- **Reconciles:** [`declaration-name-plumbing`](../../unicode-operators/clang/DEVIATIONS.md#declaration-name-plumbing),
  [`declaring-side-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#declaring-side-parse-cost),
  [`flag-language-mode`](../../unicode-operators/clang/DEVIATIONS.md#flag-language-mode),
  [`operator-candidate-assembly`](../../unicode-operators/clang/DEVIATIONS.md#operator-candidate-assembly) (U§8 half),
  [`expression-node-cost`](../../unicode-operators/clang/DEVIATIONS.md#expression-node-cost),
  [`serialization-tooling-cost`](../../unicode-operators/clang/DEVIATIONS.md#serialization-tooling-cost),
  [`ast-node-shape`](../../unicode-operators/clang/DEVIATIONS.md#ast-node-shape) (U§8 half),
  [`codegen-dispatch-sites`](../../unicode-operators/clang/DEVIATIONS.md#codegen-dispatch-sites).
- **Closes:** [`matcher-operator-name`](../../BACKLOG.md#matcher-operator-name) — designed, and cited as evidence.

---

## The finding that outranks the rewrite

**Three of the four counts this step was instructed to quote were wrong, and
every one was found by re-measuring rather than by reading.** That is now four
consecutive steps in which a recorded mechanism or a recorded number did not
survive being checked, and the pattern is specific enough to state as a rule:
**in this project, a number is wrong roughly as often as the mechanism beside
it, and for the same reason — it was written once and then inherited.**

| Axis | Recorded | Measured, 2026-09-06 | How the error got in |
|---|---|---|---|
| `DeclarationName::NameKind` | 33 sites / 20 files | **34 / 17** | A correct `U06` snapshot; later steps added sites and nobody re-ran it. |
| `UnqualifiedIdKind` (declaring side) | 9 peer sites, *"all exhaustive, so `-Wswitch` found them"* | **12 / 5 files, and only 7 of the 12 are `case` arms** | Five are `==` tests. Nothing checks those, so the reassuring half of the sentence was false for 5/12. |
| `Stmt::StmtClass` + node obligations | 28 (`U16`), then 32 in 21 files (`BL04`) | **43 / 35** | See below — this one is not staleness. |

**The 32 was short of its own inputs on the day it was written.** `U16`'s
accounting — 6 link / 8 unreachable / 1 `-Wswitch` / 13 silent = 28 —
**reproduces site for site** and was exactly right for the tree it was taken
on; I rebuilt it from scratch before touching anything and every one of the 28
lands in the category the row assigns it. What happened next is that
[`serialization-tooling-cost`](../../unicode-operators/clang/DEVIATIONS.md#serialization-tooling-cost)
correctly raised the `-Wswitch` category from 1 to 2 **without moving the
total**, and described four more sites (the importer and three matcher ones)
without counting them at all; then
[`codegen-dispatch-sites`](../../unicode-operators/clang/DEVIATIONS.md#codegen-dispatch-sites)
took `28` as its base and added its 4. So `32 = 28 + 4` was already missing 5
recorded sites, and by then `BL03`'s five analyzer modelling sites existed too.
The seventh analyzer site arrived later still, with
[null-return-suppression](null-return-suppression.handoff.md).

```
28 (U16)  + 1 (U17: CXCursor, -Wswitch)  + 4 (U17: importer + matcher ×3)
          + 5 (BL03: analyzer modelling) + 4 (BL04: ClangIR)
          + 1 (null-return-suppression: the bug reporter)          = 43
```

**The mitigation is in the document, not just in the ledger.**
[dispatch-obligation-taxonomy](../../../docs/unicode-operators.md#dispatch-obligation-taxonomy)
states the categories as a table **that sums to the total**, dates the
measurement, names the branch and the commit, and closes with a paragraph
saying what went wrong with the old figure and why a paper should quote a
measurement with its date and branch attached. A category table that sums is a
cheap invariant and it would have caught every one of these.

---

## What changed

### `docs/unicode-operators.md` U§8 — the whole Clang half

**The opening paragraph** now says what was measured: the parser side really is
small, but this section named **three** Clang work items and the prototype
needed **eight**, and the cost is in the name tables and above all in the
expression node — the one place this feature is *more* work than backtick.

**The Clang bullet list, 3 bullets → 8.** In order:

1. *Lexer* — unchanged.
2. *Parser, using an operator* — the old Parser bullet, kept verbatim and
   marked as having held as written.
3. *Parser, declaring an operator* — **new**. ~90 lines over 8 files, 12
   `UnqualifiedIdKind` dispatch sites in 5, the tentative-parsing arm with its
   two-for-two generalisation, and the `TemplateIdAnnotation` gap.
4. *The name tables — `DeclarationName`* — rewritten. Keeps the worked-precedent
   reassurance (it held), quantifies at 34 sites / 17 files / ~250 lines, and
   replaces the hedge with the real finding: the kind is **not a choice** (the
   3-bit inline space is full) and `ExtraKind` **cannot be appended to**,
   because Objective-C's variable-length selector encoding clamps everything
   above it. So the operator-name space is *packed against another language's
   encoding*, which says how much of the difficulty is inherent (little) and
   how much is bit-packing (most). Carries the generated TableGen site, the
   identity dividend, and — new today — that all 34 sites have now been
   through a compiler.
5. *The expression node* — **new**, and flagged in the prose as the strongest
   single result the prototype produced. `CXXOperatorCallExpr` cannot be reused
   (`OO_None` is a valid value, not an absent one); the node cannot be
   transparent, and the reason is a **language** consequence — a transparent
   wrapper rebuilds as an ordinary call at instantiation, so `[over.match.call]`
   applies, ADL survives and member candidates are lost. Carries the two
   measured shapes, `CXXRewrittenBinaryOperator` as the right model, and the
   operands-not-a-call rule with the backtick printer abort as the evidence.
6. *Serialization, modules and tooling* — **new**. Shape rather than size: the
   five-sites-one-decision lookup key that makes module lookup miss *silently*;
   only the reader and writer forced; the flat ODR answer; ASTMatchers having no
   per-node requirement at all.
7. *The code generator* — **new**. The four ClangIR sites, their four distinct
   failure modes, the one that asserts being localised to the default arm
   (upstream's, not the feature's), the arm that recurses where its model
   diagnoses, and **the CIR instruction-for-instruction identity** — the
   desugaring thesis cashed at the last place it could have failed.
8. *The static analyzer* — the bullet
   [null-return-suppression](null-return-suppression.handoff.md) added, plus one
   new clause: **its seven sites are within the 43, not additional to them.**

**The flag paragraph** gains
[`flag-language-mode`](../../unicode-operators/clang/DEVIATIONS.md#flag-language-mode)'s
finding as a rule — *a feature whose grammar is C++-only must not have a flag
that changes C tokenization* — with both symptoms and the transferable test
lesson (assert a **byte-identical diff** of flag-on against flag-off, because
the two features' symptoms differed and only a diff catches both).

**Two new slug-headed subsections**, so they are anchors and can be linked:

- [dispatch-obligation-taxonomy](../../../docs/unicode-operators.md#dispatch-obligation-taxonomy)
  — the summing table; the configuration-latent category and its
  generalisation; **the obligation created by meeting another obligation**;
  and the finding that *whether the toolchain helps you is a property of how a
  site is spelled, not of what it dispatches on* (three instances: two
  `NameKind` `||` chains and five `UnqualifiedIdKind` `==` tests).
- [closed-table-sibling-pattern](../../../docs/unicode-operators.md#closed-table-sibling-pattern)
  — the four instances as a table, three siblings and one refusal; GCC's
  `ansi_opname` as the same shape in a second compiler; and the conclusion the
  proposal most needs, stated structurally rather than promised: **the
  relaxation provably cannot leak into `operator+`,** because every site is a
  new arm *beside* the old one and no existing table is ever widened.

### Ledgers

Eight rows `OPEN` → `**RECONCILED**`, each naming its destination paragraph.
The ledger header goes from *"two entries"* to *"ten"*, records that three of
the eight carried counts that did not survive re-measurement, and distinguishes
the two **partly** closed rows from
[`postfix-operators`](../../unicode-operators/clang/DEVIATIONS.md#postfix-operators),
which stays `OPEN` with its mangling clause taken.
[`matcher-operator-name`](../../BACKLOG.md#matcher-operator-name)'s `Closed by`
is filled in.

---

## Verification evidence

**No build; no feature branch. Correct for this step** — the step file says so
and nothing here needed a compiler.

### The docs gate

Every row this step claims to close names its **section and paragraph**:

| Row | Destination |
|---|---|
| [`declaration-name-plumbing`](../../unicode-operators/clang/DEVIATIONS.md#declaration-name-plumbing) | U§8, the ***The name tables — `DeclarationName`*** bullet (4th in the Clang list) |
| [`declaring-side-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#declaring-side-parse-cost) | U§8, the new ***Parser, declaring an operator*** bullet (3rd), with the *using* bullet above it kept and marked |
| [`flag-language-mode`](../../unicode-operators/clang/DEVIATIONS.md#flag-language-mode) | U§8, the paragraph beginning *"One wrinkle in the flag story"*, immediately after *"Both implementations stay behind their flag"* |
| [`operator-candidate-assembly`](../../unicode-operators/clang/DEVIATIONS.md#operator-candidate-assembly) | U§8, the new ***The expression node*** bullet (5th) — part (3) only; parts (1) and (2) are U§7's |
| [`expression-node-cost`](../../unicode-operators/clang/DEVIATIONS.md#expression-node-cost) | U§8: (a)(b)(c) in the expression-node bullet; (d) in [dispatch-obligation-taxonomy](../../../docs/unicode-operators.md#dispatch-obligation-taxonomy); the sibling pattern in [closed-table-sibling-pattern](../../../docs/unicode-operators.md#closed-table-sibling-pattern); the *more work than backtick* comparison in U§8's opening paragraph |
| [`serialization-tooling-cost`](../../unicode-operators/clang/DEVIATIONS.md#serialization-tooling-cost) | U§8, the new ***Serialization, modules and tooling*** bullet (6th); identity dividend in the `DeclarationName` bullet; the `hasAnyOperatorName` refusal as the 4th row of [closed-table-sibling-pattern](../../../docs/unicode-operators.md#closed-table-sibling-pattern) |
| [`ast-node-shape`](../../unicode-operators/clang/DEVIATIONS.md#ast-node-shape) | U§8, the expression-node bullet, the sentences beginning *"The node holds its operands and not a built call"* |
| [`codegen-dispatch-sites`](../../unicode-operators/clang/DEVIATIONS.md#codegen-dispatch-sites) | U§8, the new ***The code generator*** bullet (7th); category (a) as the 5th table row and the paragraph under the table in [dispatch-obligation-taxonomy](../../../docs/unicode-operators.md#dispatch-obligation-taxonomy) |
| [`matcher-operator-name`](../../BACKLOG.md#matcher-operator-name) | Its `Closed by` cell; [closed-table-sibling-pattern](../../../docs/unicode-operators.md#closed-table-sibling-pattern), the 4th table row and the paragraph beneath it |

**No row is marked closed that is not.** The Unicode ledger's other 14 rows are
untouched and still `OPEN`; the backtick and GCC ledgers were not edited at all.

### The measurements, so they can be re-run

All on `unicode-operators-upstream` at `c0e07f78e679` (the pure-Unicode branch,
deliberately, so no backtick site can be miscounted as a Unicode one), from
`~/src/llvm/unicode-upstream`, excluding `clang/test/` and `clang/unittests/`.

```bash
# NameKind axis -> 31 case arms in 15 files
grep -rn "^[[:space:]]*case .*CXXUserOperatorName" --include=*.cpp --include=*.h clang/ lldb/
# + clang/include/clang/AST/PropertiesBase.td's PropertyTypeCase (generated, 1)
# + 2 non-switch || chains: SemaExpr.cpp:2644, SemaCodeComplete.cpp:1062
#                                                          = 34 sites / 17 files

# StmtClass axis -> every production mention of the node, classified by hand
grep -rn "UserOperatorExpr" --include=*.cpp --include=*.h --include=*.td --include=*.def clang/
#                                                          = 43 sites / 35 files

# declaring side
grep -rn "IK_UserOperatorId" --include=*.cpp --include=*.h clang/
#   7 `case` arms + 5 `==` tests                           = 12 sites / 5 files
```

**The two axes still share no site**, as
[`expression-node-cost`](../../unicode-operators/clang/DEVIATIONS.md#expression-node-cost)
claimed; four *files* carry sites on both (`RecursiveASTVisitor.h`,
`ASTImporter.cpp`, `ItaniumMangle.cpp`, `TreeTransform.h`), which is worth
knowing because a file-level grep will make them look shared.

**Category sums, verified by enumerating all 43 and assigning each exactly
once:** 6 + 8 + 2 + 19 + 4 + 3 + 1 = 43. The 19 silent = `U16`'s 13, plus the
AST importer, plus `BL03`'s five analyzer modelling sites.

### Things checked rather than assumed

- **`ShouldParseIf<cplusplus.KeyPath>` is present on all four Clang branches** —
  `defm backtick` on `backtick-trunk` (`Options.td:4071`), `backtick-23`
  (`:4022`) and `unicode-operators-experiment` (`:4072`); `defm
  unicode_operators` on `unicode-operators-experiment` (`:4077`) and
  `unicode-operators-upstream` (`:4070`). Note the file has **moved** since
  several handoffs were written: it is `clang/include/clang/Options/Options.td`,
  not `clang/include/clang/Driver/Options.td`, on all four.
- **[`ast-node-shape`](../../unicode-operators/clang/DEVIATIONS.md#ast-node-shape)'s
  recommendation (a) has landed**, which no document said. `BacktickInfixExpr`
  now has a `getCallExpr()` accessor (`clang/lib/AST/Expr.cpp:1609`) that peels
  with `IgnoreImplicit()`, `StmtPrinter::VisitBacktickInfixExpr` uses it and
  falls back to printing the semantic form, the header documents all three
  shapes Sema may wrap the call in, both print tests carry a class-typed
  `~Res()` case, and the `-DPRINTING` workaround the row asked to have deleted
  is **gone** from `clang/test/Parser/unicode-operator-precedence.cpp`. The row
  now records this.
- **The `hasAnyOperatorName` refusal is documented where a user meets it** —
  `ASTMatchers.h:2176`'s doc comment for `userOperatorExpr` says the identity is
  the code point and that `hasAnyOperatorName()` does not apply; the matcher is
  registered in `Registry.cpp:611`.
- **Links.** **1932** local Markdown links checked repo-wide (counted with
  this handoff tracked) with the GitHub
  slug rule (whitespace runs **not** collapsed — see
  [null-return-suppression](null-return-suppression.handoff.md)'s caveat).
  Excluding the vendored `papers/wg21/` tree, **3 broken, all three
  pre-existing** — the `(path)` / `(...)` placeholder examples inside the
  `decision-brief`, `mangling-abi` and `slug-the-ledgers` handoffs, which
  [clang-paper-truth](clang-paper-truth.handoff.md) already recorded. **Zero
  broken anchors anywhere**, so every link written today resolves, including
  the two new `#dispatch-obligation-taxonomy` and
  `#closed-table-sibling-pattern` ones.
- **The papers were not touched** and still cite no internal identifier:
  `grep -nE '\bDEV-[UG]?[0-9]+\b|\bB[0-9]{2}\b|\bD[0-9]{1,2}\b|\bU[0-9]{1,2}\b'`
  over `papers/*.md` and `docs/*.org` is empty, as
  [slug-the-ledgers](slug-the-ledgers.handoff.md) left it.

---

## Deviations from the step file

1. **The Clang list is eight bullets, not five plus the code generator.** The
   step file says *"rewrite U§8's Clang bullet list to the **five** items"* —
   Lexer, Parser, `DeclarationName`, the expression node, serialization — then
   add the code generator, and the analyzer bullet already existed, giving
   seven. It is eight because
   [`declaring-side-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#declaring-side-parse-cost)'s
   own recommendation is *"split U§8's Parser bullet in two — declaring and
   using"*, and that row is one of the eight this step must close. Closing it
   without the split would have been marking a row for something it did not
   ask for.
2. **The numbers the step file told me to state are not the numbers stated.**
   It says *"State the numbers as 32 sites over `StmtClass` in 21 files and 33
   over `NameKind`"*. Both are wrong; see the first section. The step file
   inherited them from the rows, and the rows inherited them from each other.
3. **Nothing was written into U§6, U§7 or U§12**, although three of my rows'
   recommendations name those sections. They belong to
   [reconcile-remainder](../steps/reconcile-remainder.md) and
   [reconcile-declaring-using](../steps/reconcile-declaring-using.md), and the
   two rows involved are marked partly closed and say which half is theirs.
   U§8's opening paragraph carries the U§6-side evidence as a forward-looking
   caveat rather than as a rewrite of the sentence.
4. **§17.4 and ADL are not restated anywhere**, per
   [evidence-debt](evidence-debt.handoff.md)'s instruction. The one adjacent
   thing U§8 does say — that the non-member half was free because the slot never
   becomes an expression — is
   [`infix-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost)'s
   and therefore
   [reconcile-declaring-using](../steps/reconcile-declaring-using.md)'s, so it
   is **not** in U§8 either. See the forward notes.

---

## Discoveries affecting later steps

- **`clang/include/clang/Driver/Options.td` does not exist on any of the four
  branches.** It is `clang/include/clang/Options/Options.td`. Several handoffs
  and ledger rows still give the old path; a grep against it comes back empty
  and looks like a missing edit.
- **A category table that sums is the cheapest possible guard on a count**, and
  this project did not have one. Every arithmetic error found today would have
  been caught by adding the rows up once. If any later step quotes a number
  from a ledger, add the categories.
- **`unicode-operators-upstream` is the right branch to measure Unicode counts
  on**, and `unicode-operators-experiment` is the wrong one: the experiment
  branch carries the backtick feature too, so a grep for a *shape* rather than
  a symbol (`case Stmt::...Class`, `peelOffOuterExpr` arms) will double-count.
- **The four analyzer `case` arms in `CFG.cpp` / `Environment.cpp` and the
  `-Wswitch` one in `ExprEngine.cpp` are simultaneously "analyzer sites" and
  "`StmtClass` dispatch sites".** Any later text that quotes both 7 and 43 must
  say they overlap; U§8's analyzer bullet now does.

---

## Forward notes for the NEXT step — [reconcile-declaring-using](../steps/reconcile-declaring-using.md)

Written after reading its step file.

- **Two of your seven rows have a half already written, and you should read the
  U§8 half before writing the U§7 half, not after.**
  [`operator-candidate-assembly`](../../unicode-operators/clang/DEVIATIONS.md#operator-candidate-assembly)
  is marked `**RECONCILED (U§8 half)**` and its `Status:` line says exactly what
  is left for you: parts (1) and (2) — the **one candidate set ranked
  together**, not three passes (proved both ways round by `MN{} ⊘ 0` and
  `MN{} ⊘ 0L`); the softening of U§7 *Desugaring*'s *"without modification"*;
  and U§7's *no built-in candidates* sentence strengthened **from a rule to a
  non-mechanism** — nothing implements it, `AddBuiltinOperatorCandidates` is
  simply never called. U§8 already says *why* the node exists; U§7 should say
  what a use *means*, and should not repeat the site counts.
- **[`infix-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost)
  is yours and I deliberately left its best sentence for you.**
  [evidence-debt](evidence-debt.handoff.md) flagged it: the non-member half was
  free **because the slot never becomes an expression** — `CreateOverloadedUserOp`
  does its own `LookupOperatorName` and hands an unresolved set to candidate
  assembly. That sentence is now backed by a compiler that gets it wrong the
  other way on the *backtick* slot
  ([`clang-slot-adl`](../../DEVIATIONS.md#clang-slot-adl)), which makes it a
  within-compiler control rather than an assertion. **Do not restate §17.4 or
  the backtick ADL defect while doing it** — that contrast is
  [reconcile-remainder](../steps/reconcile-remainder.md)'s and the backtick
  paper's, and U§8 does not touch it either.
- **U§6's sentence is now contested from four directions and one of them is
  U§8's.** *"Parsing is the easy part of this feature, easier even than
  backtick"* is [reconcile-remainder](../steps/reconcile-remainder.md)'s to
  rewrite, and your
  [`infix-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost)
  is the third of the four. **What U§8 now establishes for that argument, so it
  need not be re-derived:** the first clause survives — the declaring side is
  ~90 lines and the using side is two cases, and the declaring side is *smaller*
  than the name-table cost exactly as the design predicts — while the second
  clause, *easier even than backtick*, needs the node as a caveat, because the
  expression node is the one place this feature is more work than backtick and
  the reason is that a user operator has member candidates and a backtick slot
  does not. U§8's opening paragraph states both halves in one sentence; the
  cleanest thing is to make U§6 agree with it rather than to re-argue it.
- **Do not touch U§8.** If something you write needs a number, link to
  [dispatch-obligation-taxonomy](../../../docs/unicode-operators.md#dispatch-obligation-taxonomy)
  rather than restating it; the whole point of that subsection being an anchor
  is that the count lives in exactly one place from now on.
- **The `static-member-operators` decision entry is still owed and it is
  yours.** [mangling-abi](mangling-abi.handoff.md) and
  [`over-oper-restrictions`](../../unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions)
  both say so: the reason static members stay rejected is the **two-spellings**
  reason, not the implicit-object-parameter one the code comment still asserts,
  and it needs a slug-headed entry in `docs/unicode-operators.md` §2 beside its
  neighbours. `CheckUserOperatorDeclaration`'s comment on both Unicode branches
  still gives the abandoned reason; that is a one-line code fix owned by nobody
  and is **not** yours unless you are already touching those branches.
- **U§4 has two paragraphs about UCD versions now and only one is yours.**
  [evidence-debt](evidence-debt.handoff.md) added the reproducibility paragraph
  immediately before *"One more consequence of R3c"*;
  [`ucd-version-drift`](../../unicode-operators/clang/DEVIATIONS.md#ucd-version-drift)'s
  note is still unwritten and is yours. Do not delete the one that is there.
- **Your gate is the same as mine and the same trap applies:** mark the row, and
  name the *paragraph*. Two of the rows you inherit are marked partly closed, so
  when you finish them, change the `Status:` line's parenthetical as well as
  adding your destination — leaving `**RECONCILED (U§8 half)**` standing after
  the U§7 half lands would be worse than leaving it `OPEN`.
- **No build, no branch.** Same as this step.

---

## Open risks / TODOs

- **Nothing is pushed.** This repo is ahead of every remote, as are the four
  LLVM worktrees and the GCC one; unchanged by this step, which committed only
  here.
- **[`clang-slot-adl`](../../BACKLOG.md#clang-slot-adl) still has no owner and
  still gates [backtick-paper](../steps/backtick-paper.md).** Untouched here and
  restated because it is the largest open thing in the track.
- **`keyword-escape-printing` is still unruled by the author.** Unchanged.
- **The Unicode-branch comment divergence from `M2` is still open** —
  `unicode-operators-upstream` still carries the stale
  `CheckUserOperatorDeclaration` comment at `SemaDeclCXX.cpp:17209`. It now has
  a *second* reason to be fixed: the comment gives a reason the design has
  abandoned (see the forward notes).
- **The four counts in this handoff will go stale the same way the last ones
  did.** They are dated and branch-stamped in U§8 for exactly that reason. If a
  later step adds a site to either axis, the honest minimum is to bump the total
  *and* the category in the taxonomy table, and the table sums so the failure is
  visible.
