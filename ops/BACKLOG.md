# Backlog — defects found and not fixed

Every defect the three implementation tracks turned up and left standing,
collected from the handoffs' "Open risks / TODOs" sections, the three
deviation ledgers, and the F23/F24 defect-fix job. Compiled 2026-08-04, at
the point where Clang backtick (S00–S12), GCC backtick (G01–G10) and Clang
Unicode (U00–U21) are all complete.

This file is for things that are **wrong**, or unverified and plausibly
wrong. Open *design* questions are not defects and live in the deviation
ledgers; §6 points at them so nothing is lost, but they are not backlog.

Severity is about the paper and the prototype, not about shipping:

- **P1** — a claim in a paper is currently false, or a user-visible crash or
  silent miscompile.
- **P2** — real defect, bounded blast radius, no paper claim depends on it.
- **P3** — verification debt, cosmetic, or an upstream annoyance.

**Scheduled work lives in [`ops/completion/PLAN.md`](completion/PLAN.md)** (16
steps, named by slug), which supersedes `ops/backlog/PLAN.md` (BL01–BL04 green,
BL05–BL07 absorbed). Each entry's `Closed by` field is filled in by the step
that closes it; an em dash means nobody owns it yet. Rows re-graded on
2026-08-05 against measurements rather than handoff prose are marked
**[re-graded]**.

Every entry is headed by its **slug** and is therefore a Markdown anchor;
cross-references link to it. `Formerly:` carries the serial number the entry
used to have, because the completed tracks' handoffs still say it and are not
rewritten. [`ops/SLUGS.md`](SLUGS.md) is the whole map.

---

## 1. Backtick track — Clang (`backtick-trunk`, `backtick-23`)

### type-slot-implementation

**Formerly:** `B01`. **Severity:** **P1**.

**Item.** **§17.3's [type-name-slot](../docs/backtick-operator-design.md#type-name-slot) is not implemented.** `` 1 `P` 2 `` for a class `P` is rejected with *'P' does not refer to a value*. The design doc blesses type-name-in-slot and D4307 has a section asserting it, so the paper currently claims a feature the implementation does not deliver. **[re-graded]** It is *three* failure modes, not one — a bare class name, a class template (`use of class template 'pr' requires template arguments`, and a class template is the paper's own example), and a qualified or builtin type (`expected '(' for function-style cast or type construction`). Worse, the claim sits in the **normative** example at `papers/d4307r0.md:940` while the proposed grammar at `:911-914` is `backtick-operator: assignment-expression`, which `std::pair` is not — so the wording contradicts itself. Resolution chosen: **implement**.

**Where.** F23/F24 handoff; `docs/backtick-operator-design.md` §17.3, [type-name-slot](../docs/backtick-operator-design.md#type-name-slot); `papers/d4307r0.md`

**Closed by.** **BL02 — fixed (Clang, both branches) + paper grammar corrected.** All four shapes now construct: bare class, qualified, class template (CTAD via the `getTypeName` deduced-template placeholder), builtin (which then fails with exactly `int(1, 2)`'s semantic diagnostic — parser parity, not a parser error). Dependent slots give `CXXUnresolvedConstructExpr`; `-ast-print` round-trips. `backtick-operator` production now `assignment-expression | simple-type-specifier | typename-specifier` with a lookup-based disambiguation paragraph. Cost measured in [type-slot-cost](DEVIATIONS.md#type-slot-cost). GCC still lacks [type-name-slot](../docs/backtick-operator-design.md#type-name-slot) — recorded as [gcc-type-slot-parity](gcc/DEVIATIONS.md#gcc-type-slot-parity), deliberately not part of BL02.

### keyword-escape-round-trip

**Formerly:** `B02`. **Severity:** P2.

**Item.** **The keyword escape does not round-trip through `-ast-print`.** `` void `new`(); `` prints as `void new();`, which does not re-parse. Different node from the infix wrapper, and a different defect from the one F23/F24 fixed. `backtick-escape.cpp` never runs `-ast-print`, which is why nine steps missed it. The site is `DeclarationName::print`'s `Identifier` arm (`clang/lib/AST/DeclarationName.cpp:131-148`), which is also the **diagnostic** path — so this needs a `PrintingPolicy` bit and a decision about diagnostic wording, not just a guard.

**Where.** F23/F24 handoff

**Closed by.** **[clang-paper-truth](completion/steps/clang-paper-truth.md)** — fixed on `backtick-trunk` and `backtick-23`. The escape now round-trips through `-ast-print`, pinned by new `-ast-print` RUN lines on `clang/test/Parser/backtick-escape.cpp` — including a second line that re-parses the printed output, which is the assertion that matters. The `PrintingPolicy` bit is `BacktickKeywordEscape`, initialised from `LangOptions::Backtick`; the diagnostic-wording question the row demanded is answered, deliberately and in the affirmative, at [keyword-escape-printing](../docs/backtick-operator-design.md#keyword-escape-printing), with the costs in [keyword-escape-printing](DEVIATIONS.md#keyword-escape-printing). **The row understated the scope by four sites**: `DeclarationName::print` alone is not enough, because three `DeclPrinter` declarator printers hand the name to the *type* printer as a placeholder and never reach it, and `StmtPrinter::VisitMemberExpr` prints through a policy-free stream operator. The diagnostic surface was also already split — `ak_declarationname` policy-free, `ak_nameddecl` not — so the two halves would have disagreed about the same name.

### c-mode-tokenization

**Formerly:** `B03`. **Severity:** P2.

**Item.** **`-fbacktick` still lacks `ShouldParseIf<cplusplus.KeyPath>`.** The flag changes C-mode tokenization for a grammar that is C++-only. The Unicode branch carries the paired one-line fix for both flags; the backtick track owes itself the `defm backtick` half. **[re-graded]** The symptom is worse than [flag-language-mode](unicode-operators/clang/DEVIATIONS.md#flag-language-mode) records: C does not merely lose a diagnostic, it **accepts** the grammar — `` int f(int a,int b){ return a `g` b; } `` compiled as C with `-fbacktick` exits 0.

**Where.** [flag-language-mode](unicode-operators/clang/DEVIATIONS.md#flag-language-mode) (resolved on the Unicode branch only); U04 handoff

**Closed by.** **[clang-paper-truth](completion/steps/clang-paper-truth.md)** — `defm backtick` gained `ShouldParseIf<cplusplus.KeyPath>` on `backtick-trunk` and `backtick-23`, and `clang/test/Lexer/backtick-c-mode.c` was carried back from the Unicode branch to both. Re-graded once more and the row's own re-grade holds: measured on the pre-fix binary, `-cc1 -fbacktick -x c` on the reproducer exits **0** while the same compilation without the flag exits 1, so the test's assertion is the *rejection* — `not` on both compilations plus a `diff` of their output. Reconciled into [feature-gating](../docs/backtick-operator-design.md#feature-gating)'s 2026-09-06 log entry and §6.5.

### backtick-source-range

**Formerly:** `B04`. **Severity:** P2.

**Item.** **`BacktickInfixExpr`'s source range does not span its operands** — it is `<col:22, col:23>`, just the callee. Cheap now that `getCallExpr()` exists. Model the fix on `UserOperatorExpr::getBeginLoc` (`ExprCXX.h:471-491`), whose doc comment diagnoses the identical root cause.

**Where.** F23/F24 handoff; U11 handoff

**Closed by.** **[clang-paper-truth](completion/steps/clang-paper-truth.md)** — fixed on `backtick-trunk` and `backtick-23`, modelled on `UserOperatorExpr::getBeginLoc` as the row asked. `` 1 `add` 2 `` was `<col:16, col:19>` and is now `<col:13, col:21>`. **Wider than the row said**: the type slot ([type-name-slot](../docs/backtick-operator-design.md#type-name-slot)) desugars to construction, so `getCallExpr()` is null for it and a call-only fix would have left `` 1 `Pt` 2 `` reporting the slot alone; `BacktickInfixExpr::getOperand` recognises the same three shapes the pretty-printer does. The test assertions were wildcards that could not have failed, and are now literal columns. Reconciled into §17.5 and [source-fidelity-node](../docs/backtick-operator-design.md#source-fidelity-node)'s 2026-09-06 log entry; [backtick-source-locations](DEVIATIONS.md#backtick-source-locations) carries the correction to the clause that said the inner call's paren locations were enough.

### backtick-ast-matchers

**Formerly:** `B05`. **Severity:** P2.

**Item.** **ASTMatchers and clang-tidy do not know `BacktickInfixExpr`.** The same gap U17 closed for `UserOperatorExpr` on the Unicode side, still open here. Sized from U17: ~5 production/docs files at +58 lines plus +59 of test. `clang-tidy` itself needs nothing. Note `clang/docs/LibASTMatchersReference.html` is generated and gated by `clang/test/AST/ast_matchers_updated.test` — adding a matcher without regenerating fails the gate.

**Where.** F23/F24 handoff

**Closed by.** [hygiene-parity](completion/steps/hygiene-parity.md), 2026-09-07. **Fixed on `backtick-trunk` and `backtick-23`**, following `U17`'s shape for `UserOperatorExpr`: `backtickInfixExpr()` declared in `ASTMatchers.h`, defined in `ASTMatchersInternal.cpp`, registered in `Dynamic/Registry.cpp`, and the two `TK_IgnoreUnlessSpelledInSource` traversal sites in `ASTMatchFinder.cpp` without which a matcher sees the synthesized call instead of the operands. `clang/docs/LibASTMatchersReference.html` **regenerated** with `clang/docs/tools/dump_ast_matchers.py`, not hand-edited, so `clang/test/AST/ast_matchers_updated.test` passes. Two new gtest cases in `ASTMatchersNodeTest.cpp`; `matchesConditionally` runs the static and the dynamic matcher and fails if they disagree, so they cover the `Registry.cpp` entry that clang-query and clang-tidy use. **The `U17` sizing was right, which is worth saying in a track that keeps finding recorded numbers wrong**: 5 production/docs files at +58 and +59 of test predicted, **5 files at +59 and +56 of test** measured — `ASTMatchers.h` +14, `ASTMatchFinder.cpp` +29, `ASTMatchersInternal.cpp` +2, `Registry.cpp` +1, the generated HTML +13. `clang-tidy` itself needed nothing, as the row said. The one asymmetry with the Unicode side is that `BacktickInfixExpr` has a fixed arity, so both traversal sites loop over `getOperand(0)`/`getOperand(1)` rather than a `getNumOperands()`.

### dead-nesting-diagnostic

**Formerly:** `B06`. **Severity:** P3.

**Item.** **`err_backtick_nested_requires_parens` is dead code**, carried since S04 and never fired. Remove it — [bare-nesting-detection](DEVIATIONS.md#bare-nesting-detection) is RESOLVED in the other direction (§17.1: bare nesting is blessed [chaining-associativity](../docs/backtick-operator-design.md#chaining-associativity) chaining and cannot be diagnosed), so the diagnostic is unfireable *as specified*. Do not implement the [nesting-vs-chaining](../docs/backtick-operator-design.md#nesting-vs-chaining) lookahead.

**Where.** S04–S11, R23, R24, F23/F24 handoffs (carried nine times)

**Closed by.** [hygiene-parity](completion/steps/hygiene-parity.md), 2026-09-07. **Removed** from `DiagnosticParseKinds.td` on `backtick-trunk` and `backtick-23`. Checked before deleting, as the step required: `git grep` finds the identifier only at its own definition, and no test asserts its text — the closest thing was a stale comment in `clang/test/SemaCXX/backtick-semantics.cpp` calling bare nesting "the current mis-behavior" and promising a future step would cover it, which is exactly backwards and is rewritten. The [nesting-vs-chaining](../docs/backtick-operator-design.md#nesting-vs-chaining) lookahead was **not** implemented and must not be: `int x4 = a `g` b `f` c;` in `clang/test/Parser/backtick-diagnostics.cpp` already pins the form, and it is now annotated to say that it *is* the bare-nesting spelling. §6 item 6 of the design doc, which had listed the diagnostic as one of three to write, says there are two and why the third was withdrawn; [bare-nesting-detection](DEVIATIONS.md#bare-nesting-detection) carries a dated `Log.`

### slot-split-penalty

**Formerly:** `B07`. **Severity:** P3.

**Item.** **[format-break-policy](../docs/backtick-operator-design.md#format-break-policy)'s slot-interior `SplitPenalty` bump is unimplemented.** The hard constraints suffice for identifier and qualified-name slots; a long multi-token slot would format badly.

**Where.** S10 handoff, carried through R23/R24

**Closed by.** [hygiene-parity](completion/steps/hygiene-parity.md), 2026-09-07. **Implemented on `backtick-trunk` and `backtick-23`, and the limit behind it measured and pinned** — the step file allowed either and both were possible. `TokenAnnotator::calculateFormattingInformation` tracks the infix pair and adds a flat 100 to `SplitPenalty` on every slot-interior token (the escape pair is skipped: its slot is one token, so it has no interior). **What the bump can and cannot do was measured, not assumed.** It decides *ties*: a qualified name inside the slot and one outside price identically without it and the formatter splits the slot, and with it the outer name breaks and the slot survives — 25 differing outputs across a before/after sweep of 10 shapes at every `ColumnLimit` from 20 to 90. It cannot touch the case the row worried about, where **no** alternative break fits, because `PenaltyExcessCharacter` is 1,000,000 per column and any additive bump is three or four orders below it; a bump that large would make the slot the no-break zone [format-break-policy](../docs/backtick-operator-design.md#format-break-policy) rejects. Both the fix and the residual limit are pinned in `FormatTest.BacktickOperatorSlotSplitPenalty`; §7's break-policy bullet says both.

### template-ast-print-test

**Formerly:** `B08`. **Severity:** P3.

**Item.** **No `-ast-print` test covers a backtick expression in a template context**, so `TransformBacktickInfixExpr` is unexercised for round-trip. Watch [auto-return-round-trip](#auto-return-round-trip) — write an explicit return type, not `auto`.

**Where.** S11 handoff

**Closed by.** [evidence-debt](completion/steps/evidence-debt.md), 2026-09-06. `clang/test/AST/backtick-template-print.cpp` on both backtick branches: five shapes, each printed as pattern *and* as instantiation, since `-ast-print` prints instantiated class-template member bodies. **The hole was real and the new file is what sees it.** With `TransformBacktickInfixExpr` altered to return the inner expression instead of rebuilding the wrapper, the new test fails and the pre-existing `clang/test/Parser/backtick-ast-print.cpp` still **passes** — the patterns keep printing `` a `add` b `` while every instantiation reverts to `add(a, b)`, `mk(a, b)`, `f(a, b)` and `Pair2(a, b)`. Explicit return types throughout, per [auto-return-round-trip](#auto-return-round-trip). The file says in a comment that it does **not** cover lookup in the slot; see [clang-slot-adl](#clang-slot-adl), which it turned up.

### clang-slot-adl

**Formerly:** none — new slug, 2026-09-06. **Severity:** **P1**.

**Item.** **Clang does no argument-dependent lookup on the backtick slot, and in the worst shape it says nothing about it.** [§17.4](../docs/backtick-operator-design.md#174-adl-is-normative-cross-compiler-note) is normative — the slot must get the same ADL as the call it desugars to — and reports the rule as delivered by both compilers. It is not delivered by Clang. A hidden friend in the slot is *use of undeclared identifier*; worse, when an ordinary-lookup candidate is visible and a better ADL candidate exists, `` u `pick` u `` **binds the ordinary one and `pick(u, u)` binds the ADL one, with no diagnostic** — the operator form calls a different function from the call it is defined to be sugar for. Cause: the slot is parsed with `ParseExpression()`, so `Sema::UseArgumentDependentLookup` sees `HasTrailingLParen = false` and returns false on its first line. This is [gcc-slot-adl](gcc/DEVIATIONS.md#gcc-slot-adl) on the other compiler; the **Unicode** feature in the same build is correct, because its slot never becomes an expression. Full measurements, the mechanism, and the fix-or-reword options are in [clang-slot-adl](DEVIATIONS.md#clang-slot-adl).

**Where.** [evidence-debt](completion/steps/evidence-debt.md), 2026-09-06 — found while writing [template-ast-print-test](#template-ast-print-test)'s test. Missed until now because no test on the track ever tried pure ADL: `clang/test/SemaCXX/backtick-semantics.cpp` §2 announces the ADL case and then uses a **qualified** name, which correctly gets no ADL whatever the slot does.

**Closed by.** [clang-slot-adl](completion/steps/clang-slot-adl.md), 2026-09-06. **Fixed, not reworded** — the author's decision, so §17.4 keeps its claim. `Parser::TryParseBacktickCalleeSlot` parses a bare unqualified name in the slot as the callee it is and builds it with `HasTrailingLParen=true`, so it reaches `BuildCallExpr` unresolved; **the template-id form was done in the same pass**, on the strength of [gcc-template-id-slot-adl](gcc/DEVIATIONS.md#gcc-template-id-slot-adl). New test `clang/test/SemaCXX/backtick-adl.cpp` on both backtick branches, whose augmentation sections fail pre-fix as a *wrong bind*, not a compile error; `backtick-semantics.cpp`'s false ADL claims corrected. §17.4's status-correction block removed and the section rewritten, carrying the within-compiler control — Unicode right, backtick wrong, one build — for [backtick-paper](completion/steps/backtick-paper.md) to take. `unicode-operators-experiment` needs the fix only when it next takes a backtick merge; the Unicode feature there is unaffected and correct.

### libclang-cursor-arm

**Formerly:** `B35`. **Severity:** P3.

**Item.** **libclang does not know `BacktickInfixExpr`.** `clang/tools/libclang/CXCursor.cpp`'s exhaustive `MakeCXCursor` switch has no arm, so a `-Wswitch` warning is still live on this `WERROR=OFF` build and libclang maps a backtick expression to `CXCursor_NotImplemented`. F24 closed the sibling gap in `ExprEngine.cpp`; U17 left the backtick half alone. One line next to `CXXRewrittenBinaryOperatorClass`. *(Added 2026-08-05.)*

**Where.** U17 handoff `:196-200`, `:472-476`

**Closed by.** [hygiene-parity](completion/steps/hygiene-parity.md), 2026-09-07. **Fixed on `backtick-trunk` and `backtick-23`** — one line, `case Stmt::BacktickInfixExprClass:` beside `CXXRewrittenBinaryOperatorClass` in `MakeCXCursor`. The row's claim that the warning was live is **re-derived, not quoted**: rebuilding `CXCursor.cpp.o` alone on the pre-fix tree gives exactly one diagnostic, `warning: enumeration value 'BacktickInfixExprClass' not handled in switch [-Wswitch]` at `CXCursor.cpp:175`, and the same rebuild after the fix is silent. It had been live since `S11` added the node on 2026-06-27, was recorded at `U17` on 2026-08-04, and was still live on 2026-09-07 — **ten weeks and every step of two tracks** — which is the datum [expression-node-cost](unicode-operators/clang/DEVIATIONS.md#expression-node-cost)'s *found only by reading the build log* category wanted: on a `WERROR=OFF` build that category is not merely quiet, it is quiet **for months**. Reconciled into `docs/backtick-operator-design.md` §6 item 7's new tooling paragraph.

## 2. Backtick track — GCC (`backtick`)

### template-id-slot-adl

**Formerly:** `B09`. **Severity:** P2.

**Item.** **Pure ADL on a template-id slot still fails.** `` x `add<int>` y `` takes the old path, because G10's two-token lookahead (`CPP_NAME` + `CPP_BACKTICK`) does not detect a template-id. §17.4's normative claim holds for bare names only.

**Where.** G10 handoff; [gcc-slot-adl](gcc/DEVIATIONS.md#gcc-slot-adl)'s neighbourhood

**Closed by.** [gcc-resync](completion/steps/gcc-resync.md), 2026-09-06. Fixed, not reworded: `cp_parser_backtick_template_id_slot` keeps a bare template-id slot unresolved as a `TEMPLATE_ID_EXPR` and hands it to `perform_koenig_lookup`, at both handler sites. §17.4 rewritten to say ADL binds wherever the slot is an unqualified name, with or without template arguments. New test `g++.dg/backtick/infix-adl-template-id.C`; ledger [gcc-template-id-slot-adl](gcc/DEVIATIONS.md#gcc-template-id-slot-adl).

### module-streaming-escapes

**Formerly:** `B10`. **Severity:** P2.

**Item.** **Module streaming of keyword-escaped names is untested.** `IDENTIFIER_KEYWORD_P` checks in `module.cc:20117` and `:20160` may need attention if a keyword-named entity is exported. Deferred three times.

**Where.** G07, G08, G09, G10 handoffs

**Closed by.** [gcc-resync](completion/steps/gcc-resync.md), 2026-09-06. **Verified not broken** — deferred four times, and it works untouched. A module exporting `` `new` `` and `` Widget::`delete` `` produces a CMI, the importer sees ordinary identifiers, and both mangle with the module-attachment prefix (`_ZW15backtick_escape3newii`, `_ZNW15backtick_escape6Widget6deleteEv`). `module.cc`'s `IDENTIFIER_KEYWORD_P` checks needed no change. Now guarded by `g++.dg/modules/backtick-escape-1_a.C` / `_b.C`.

### grokdeclarator-guard-scope

**Formerly:** `B11`. **Severity:** P3.

**Item.** **The `flag_backtick` guard in `grokdeclarator` is over-permissive** — it suppresses the keyword-declarator error for *all* keyword names when the flag is set, not only explicitly escaped ones. Benign today because the parser rejects non-escaped keywords earlier.

**Where.** [gcc-keyword-declarator](gcc/DEVIATIONS.md#gcc-keyword-declarator); G07–G10 handoffs

**Closed by.** [gcc-resync](completion/steps/gcc-resync.md), 2026-09-06. Guard narrowed: the escape is recorded on the `cp_declarator` (`backtick_escaped_p`, set from a parser flag that `cp_parser_unqualified_id` raises), and `grokdeclarator` requires it rather than trusting `flag_backtick`. Narrowing it turned up a *reachable* sibling — both escape arms were entered on the flag alone although other cases fall through to their `case CPP_BACKTICK` labels, so a bare keyword and a stray `^` diagnosed differently with the flag on; see [escape-arm-entry-token](gcc/DEVIATIONS.md#escape-arm-entry-token).

### gcc-wrapper-parity

**Formerly:** `B12`. **Severity:** P3.

**Item.** **GCC has neither F23 nor F24 fix, and cannot have the first**: no phase-2 AST wrapper was ever built there, and there is no analyzer analogue. No cross-compiler divergence row is warranted — there is nothing to diverge from.

**Where.** F23/F24 handoff

**Closed by.** [gcc-resync](completion/steps/gcc-resync.md), 2026-09-06. **Recorded, not implemented**, which was the row's own conclusion: GCC desugars in the parser, so there is no AST wrapper node and no analyzer analogue to teach — a difference in *kind*, not in behaviour. Written up as [gcc-wrapper-parity](gcc/DEVIATIONS.md#gcc-wrapper-parity) in the GCC ledger, with what the paper should say about the parts of the Clang work that have no GCC counterpart by construction.

### gcc-trunk-pin

**Formerly:** `B13`. **Severity:** P3.

**Item.** **The GCC track is pinned at trunk `c9ee2c5ab6c`** while Clang has moved to 23.x and 24.x. Re-sync before any fresh cross-compiler divergence testing.

**Where.** R23, R24 handoffs

**Closed by.** [gcc-resync](completion/steps/gcc-resync.md), 2026-09-06. Rebased `c9ee2c5ab6c` (2026-06-24) → `4df5e1e9b152` (2026-09-06), 2158 upstream commits, 177 of them in `gcc/cp`, `gcc/c-family` or `libcpp`. Conflict-free, and the feature diff's added and removed lines are byte-identical across the move — only hunk offsets shifted. Gate 88 → 88 before any other change.

## 3. Unicode track — Clang (`unicode-operators-experiment`, `unicode-operators-upstream`)

### unicode-analyzer-sites

**Formerly:** `B14`. **Severity:** **P1**.

**Item.** ~~The static analyzer almost certainly mishandles `UserOperatorExpr`, and nobody has looked.~~ **[re-graded 2026-08-05 — measured, not suspected.]** Three of F24's five defects are **observed** on `build-unicode`: `clang_analyzer_eval(x == 3)` after `int x = 1 ⊞ 2;` reports **both `FALSE` and `TRUE`** where the explicit `operator⊞(1,2)` reports `TRUE` only; `const S &r = 1 ⊞ 2;` yields `(CXXRecordTypedCall, [B1.6])` where the explicit call yields `[B1.8]`, character-for-character F24's symptom; and the CFG carries a temporary-object destructor *and* the implicit one. Only the dropped-successor defect is absent, because U16's `ExprEngine` case keeps the path alive. The node is not transparent to *transformation*, so F24's fix does not transplant unchanged — and there is no `getSubExpr()`, only `getSemanticForm()`. **`CFG.cpp` and `ExprEngine.cpp` are coupled**: U16's grouping is self-consistent only while `CFG.cpp` has no case.

**Where.** U16 handoff; F24 handoff (`Environment.cpp:37`, `CFG.cpp`, `LiveVariables.cpp`, `ExprEngine.cpp`)

**Closed by.** **BL03 — fixed on both Unicode branches.** All six arms landed, each audited against its F24 counterpart rather than transplanted (`getSemanticForm()`, not `getSubExpr()`). **Five of the six are load-bearing, proven by reverting each arm in turn and re-running the new test: every one of the five fails it, and each fails it in its own way** — `findConstructionContexts` → `[B1.6]` not `[B1.8]`; `CFGBuilder::Visit` → `[B1.9]`, the wrapper an element again; `VisitForTemporaries` → a second `~Res() (Temporary object destructor)`; `LiveVariables` → 7 `TRUE` down to 4; `Environment` → down to 3. **The sixth, `ExprEngine`, is unobservable**: with the CFG looking through the node it is unreachable, proven with an `llvm_unreachable` probe that never fired across the whole `clang/test/Analysis` tree. It is changed anyway because the old grouping *asserts* the wrapper is a modelled element, which the CFG change makes false. New defect found in passing: **[null-return-suppression](#null-return-suppression)**.

### clangir-unicode-arms

**Formerly:** `B15`. **Severity:** **P1**.

**Item.** **`clang/lib/CIR/` has never been compiled on this branch and has never seen a `UserOperatorExpr`.** `LLVM_ENABLE_PROJECTS` is `clang;clang-tools-extra`, so the ClangIR code generator is not built. Flagged unchanged by six consecutive steps. **[re-graded]** Not "unknown whether it needs a case at all": U19 identified it as a genuine hole, the four sites are known (`CIRGenExprScalar.cpp:585-587`, `CIRGenExprAggregate.cpp:440-442`, `CIRGenExprComplex.cpp:275-277`, `CIRGenFunction.cpp:1187-1190`), three are copy-paste from the `CXXRewrittenBinaryOperator` arms because `getSemanticForm()` already exists, and the fallbacks are `errorNYI` rather than crashes — so the worst case is a hard NYI diagnostic, not a miscompile. **[the last clause is wrong — measured by BL04.]** Three of the four fallbacks are bounded; the l-value one is not. `emitLValue`'s default arm returns a default-constructed `LValue`, whose null `QualType` asserts in `QualType::getCommonPtr`, so an l-value-returning operator **crashes the compiler** after emitting the NYI diagnostic. The remaining unknown is only whether the build passes. Needs MLIR **and** `CLANG_ENABLE_CIR=ON`; the CMake `FATAL_ERROR`s otherwise.

**Where.** U04, U05, U12, U14, U15 handoffs; U16 `:390-394`; U19 `:131-133`

**Closed by.** **BL04 — measured and fixed on both Unicode branches.** `clang/lib/CIR/` compiled for the first time on this hardware (scratch dir `~/src/llvm/build-cir-scratch`, `mlir` + `CLANG_ENABLE_CIR=ON`). All four sites were real, and each failed in its own way: scalar → `NYI "scalar expression kind: : UserOperatorExpr"`; aggregate → `NYI "AggExprEmitter::VisitStmt: UserOperatorExpr"`; complex → `errorUnsupported`, `"cannot compile this complex expression yet"`, **which does not name the node**; l-value → `NYI "unsupported l-value class"` followed by an **assertion failure**, `!isNull()` in `QualType::getCommonPtr`. Three arms are the predicted copy-paste. The fourth is not: unlike the `CXXRewrittenBinaryOperator` arm beside it, `emitLValue` recurses into the semantic form rather than diagnosing, because an operator returning a reference *is* a call returning a reference. New test `clang/test/CIR/CodeGen/unicode-operator.cpp` checks all five shapes against the explicit call written by hand; the two forms emit instruction-for-instruction identical CIR.

### lldb-hunk-verification

**Formerly:** `B16`. **Severity:** P2.

**Item.** **The lldb hunk is compile-unverified.** One line in `ClangASTSource.cpp:125`; lldb is not in this build's projects. The only hunk in the whole feature no compiler has seen. Prerequisites are all present on this machine; building `lldbPluginExpressionParserClang` alone compiles the TU without linking lldb.

**Where.** U06 handoff; REPLAY row

**Closed by.** [evidence-debt](completion/steps/evidence-debt.md), 2026-09-06. **Compiled, on both Unicode branches, and the caveat is retired.** `lldbPluginExpressionParserClang` built to a linked static library on each: the experiment branch in `~/src/llvm/build-cir-scratch` (BL04's CIR tree, reconfigured with `lldb` added to `LLVM_ENABLE_PROJECTS` rather than standing up a second one), the upstream branch in a fresh `~/src/llvm/build-lldb-scratch-upstream`, because the two branches sit on different upstream bases and 367 files differ under `lldb/` alone — a compile on one is not evidence for the other. `ClangASTSource.cpp` is the same bytes on both. Both builds `EXIT=0` with **zero diagnostics of any kind**, which is the load-bearing part: the switch the hunk joins is exhaustive over `DeclarationName::NameKind`, so a missing or misplaced case is a `-Wswitch` warning and there is none.

### code-completion-priority

**Formerly:** `B17`. **Severity:** P2.

**Item.** **`SemaCodeComplete.cpp:1061`'s completion-priority grouping was never updated.** Left alone by U06, U07, U08, U09, U11 and U16 in turn. Completion after an infix user operator is a reachable state. The reason it kept being deferred is that priorities are not printed.

**Correction, 2026-09-06.** The rest of that sentence — *"but results are priority-sorted (`CodeCompleteConsumer.cpp:645`), so an ordering-based test is the observable"* — **is wrong, and following it wastes an afternoon.** The `std::stable_sort` at that line sorts by `clang::operator<(const CodeCompletionResult &, ...)`, which compares the results' *names* with `compare_insensitive` and never reads `Priority` at all. There is no ordering to observe. The real observable is that **`c-index-test` prints the priority**, in parentheses at the end of each result line (`… (35)`, `… (80)`), so the number can be asserted directly instead of through a proxy for it; `clang/test/CodeCompletion/` already has four tests driven by `c-index-test`, so this needs no new machinery.

**Where.** U08–U16 handoffs (carried six times)

**Closed by.** [evidence-debt](completion/steps/evidence-debt.md), 2026-09-06. **Fixed on both Unicode branches** — one `||` adding `DeclarationName::CXXUserOperatorName` to the chain — with `clang/test/CodeCompletion/unicode-operator-priority.cpp` asserting the priorities directly. Verified in both directions: on the pre-fix binary the two member user operators print `(35)`, grouped with the data members, and the test fails on exactly those two `CHECK` lines; after, they print `(80)` beside `operator+`. The file also pins the data members at `(35)`, so a change that demoted every member rather than the operators would fail too.

### template-id-code-point

**Formerly:** `B18`. **Severity:** P2.

**Item.** **`TemplateIdAnnotation` carries no code point** for `operator⊞<T>` (`TemplateII = nullptr`, `OpKind = OO_None`) — the same gap upstream has for literal operators, marked there with a pre-existing FIXME. Resolution goes through the `TemplateName`, so nothing is wrong today.

**Where.** U07 handoff

**Closed by.** [hygiene-parity](completion/steps/hygiene-parity.md), 2026-09-07. **Recorded, not fixed** — it matches upstream's shape, it is latent, and upstream's own `FIXME` is one line above it. Re-derived by reading `Parser::ParseUnqualifiedIdTemplateId` (`clang/lib/Parse/ParseExprCXX.cpp:2371-2394`): `TemplateII` is non-null only for `IK_Identifier`, so `IK_UserOperatorId` and `IK_LiteralOperatorId` alike get `nullptr`, and `OpKind` is explicitly `OO_None` for the user operator. **And the cost is smaller than the row and the source comment beside it both suppose:** measured on the built binary, a resolved template-id names the operator in full (`no matching function for call to 'operator⊞'`), and an unresolved one gives `use of undeclared 'operator⊞'` with the caret over `operator` only — character-for-character the same shape and the same truncated caret as `operator""_sfx` on a stock compiler. So there is not even the diagnostic-quality cost the in-tree `FIXME` predicts. Recorded in `docs/unicode-operators.md` §8's *Parser, declaring an operator* bullet. **Nothing was changed on either Unicode branch**; filling this in for user operators but not for literal operators would be the odd choice.

### matcher-operator-name

**Formerly:** `B19`. **Severity:** P2.

**Item.** **`hasAnyOperatorName()` cannot express a user operator** and was deliberately not supported: it returns a `StringRef` into a static spelling table and a user operator's spelling is computed. A matcher API that structurally cannot name the operator.

**Where.** U17 handoff; [serialization-tooling-cost](unicode-operators/clang/DEVIATIONS.md#serialization-tooling-cost)

**Closed by.** **[reconcile-implementation-cost](completion/steps/reconcile-implementation-cost.md), 2026-09-06 — recorded as designed, and cited as evidence.** There is nothing to fix: the predicate is keyed on a *static* spelling table and a user operator's spelling is a UTF-8 encoding of a code point computed into a buffer, so the right answer is a refusal and not a sibling. Verified today that the refusal is documented where a user meets it — `userOperatorExpr()`'s own doc comment says the operator's identity is its code point and that `hasAnyOperatorName()` does not apply — and that the matcher is registered for the dynamic layer. Written into [`docs/unicode-operators.md`](../docs/unicode-operators.md) **U§8's [closed-table-sibling-pattern](../docs/unicode-operators.md#closed-table-sibling-pattern)**, as the **fourth row of the table and the paragraph immediately beneath it**: the first three instances are siblings and this is the first where the right answer is a refusal, which is what makes the pattern a claim about closed tables rather than a claim about how much typing a sibling costs.

### astral-plane-mangling

**Formerly:** `B20`. **Severity:** P3.

**Item.** **The astral-plane and zero-padding branches of the mangling derivation are untested by construction** — every [token-set](../docs/unicode-operators.md#token-set) code point is in 0x2190–0x2BFF, so every derived name is exactly four digits. First thing to test if [token-set](../docs/unicode-operators.md#token-set) ever grows past the BMP.

**Where.** U09 handoff; [vendor-extended-mangling](unicode-operators/clang/DEVIATIONS.md#vendor-extended-mangling)

**Closed by.** **[mangling-abi](completion/steps/mangling-abi.md), 2026-09-06 — recorded, not fixed, because there is nothing to fix.** It is a property of the frozen [token-set](../docs/unicode-operators.md#token-set), not a coverage gap: the padding branch and the astral widening are unreachable while every code point is in U+2190–U+2BFF, and reaching them means changing the token set, which is a design change and would bring its own tests. Written into [`docs/unicode-operators.md`](../docs/unicode-operators.md) **U§9's [mangling-derivation-rule](../docs/unicode-operators.md#mangling-derivation-rule)**, the paragraph beginning *"Two branches of that rule are unexercised by construction"*, which also names the two U§13 questions (combining-mark sequences, Latin-1 stragglers) that would first make them reachable. **Answered 2026-09-06:** the author accepted the recommendation at [abi-production-request](../docs/unicode-operators.md#abi-production-request), so the derivation is part of what the paper proposes — and the paragraph therefore **reaches the paper**, because an ABI reviewer asked to bless a derivation is entitled to know which of its branches no test has ever taken. [unicode-paper](completion/steps/unicode-paper.md) carries it.

### ucd-input-manifest

**Formerly:** `B21`. **Severity:** P3.

**Item.** **The UCD 17.0.0 inputs are in neither repo**, so the generated character tables cannot be regenerated without re-fetching five files. A hash manifest in `docs/` is the cheap fix, and the paper's reproducibility claim wants one. Needs network access to unicode.org — it is the only item in either cheap batch with an external dependency.

**Where.** U02 handoff

**Closed by.** [evidence-debt](completion/steps/evidence-debt.md), 2026-09-06. **[`docs/ucd-17.0.0.sha256`](../docs/ucd-17.0.0.sha256)**, in `sha256sum` check format so `sha256sum -c` reads it, carrying each input's version-pinned URL, publication date and size as comments; plus a `--verify-manifest` mode in [`docs/pattern-syntax-audit.py`](../docs/pattern-syntax-audit.py) that `--emit-header` now implies, so a header cannot be regenerated from unverified bytes without the explicit `--no-verify-manifest`. **The reproducibility claim is checked rather than asserted:** the five files were re-fetched from unicode.org on 2026-09-06, all five hashes recorded from that fetch, and the regenerated `UnicodeOperatorCharSets.h` is **byte-identical** to the one committed on both Unicode branches (`sha256 52ccbd15e26b…`). Refusal was tested too — a one-comment-line edit to `PropList.txt` aborts the run with zero bytes on stdout.

### confusable-spellings

**Formerly:** `B22`. **Severity:** P3.

**Item.** **The confusable-to-ASCII spellings are a judgement call, not derived.** ∙ ⋅ → `.` and ⇔ → `<=>` were assigned by hand; the generator has no `confusables.txt` input. They now appear in user-facing diagnostics. The table shape already supports deriving them.

**Where.** U02, U05 handoffs; [exclusion-list-derivation](unicode-operators/clang/DEVIATIONS.md#exclusion-list-derivation)

**Closed by.** [reconcile-remainder](completion/steps/reconcile-remainder.md), 2026-09-06. **Recorded as curated, with the principle written down — not derived.** The judgement call is real and deriving it would be *worse*, which is why the answer is a decision rather than a fix: published confusability data answers "what does this look like", the diagnostic needs "which C++ token does this look like", and three of the thirteen entries are where those two questions come apart (∙ and ⋅ mean multiplication and look like `.`; ⇔ is spelled `<=>`, a token C++ acquired in 2020). Written as [confusable-spelling-provenance](../docs/unicode-operators.md#confusable-spelling-provenance), a full decision entry at the end of U§5, whose stated principle is *the spelling names the token a reader is most likely to mistake the character for, not the operation the character denotes* — and which also carries the wording consequence (*is confusable with*, never *did you mean*, and no fix-it). `papers/dxxxxr0.md` carries the claim and the principle in public register. **Note for anyone reopening it:** this row said the table shape "already supports deriving them", and that is true of the shape and beside the point. Nothing was implemented.

### dependent-template-operator-id

**Formerly:** `B23`. **Severity:** P3.

**Item.** **`t.template operator⊞<int>(0)` on a dependent object expression is rejected.** `DependentTemplateStorage` holds an identifier or a built-in operator kind and nothing else, and a user operator is neither. Falsifies the word "anywhere" in U§7.1. **Corrected 2026-09-06:** this row used to say the limitation was "inherited, not introduced", because user-defined literal operators have had it since C++11. That is false — literal operators share the code path but suffer no limitation from it, since [over.literal]/1 means no valid program contains the construct — and **the limitation is exclusive to the new name kind**. See [operator-id-anywhere](unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere) for the corrected justifying clause and for the wording that must *not* be used.

**Where.** [operator-id-anywhere](unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere); U07, U10 handoffs

**Closed by.** **[reconcile-declaring-using](completion/steps/reconcile-declaring-using.md), 2026-09-06 — the reword is written and this row is closed.** U§7.1's fourth point now says the operator-function-id names the overload set *where* an unqualified-id does, enumerating the positions measured, and the paragraph after it — *"One position is an exception, and it is worth stating rather than defending"* — states the gap with the corrected justification. `papers/dxxxxr0.md` carried the false clause in its *"What is not resolved"* section and was corrected in the same commit; neither paper now contains it. Nothing turned into code, and nothing is pending upstream. Below, the history, unchanged: **on the reword alone.** [decision-brief](completion/steps/decision-brief.md) re-triaged this as a decision; the author answered (c) — *reword and report* — on 2026-09-06, [upstream-triage](completion/steps/upstream-triage.md) found the same day that the report could not be filed as directed (the literal-operator reproducer `t.template operator""_lit<int>(0)` is *correctly* rejected: [over.literal]/1 forbids a member literal operator, GCC agrees, and trunk `SemaTemplate.cpp` handles the kind deliberately at the site), and the author **settled it as option (a) on 2026-09-06: reword only, no upstream report** — see [the answer](../docs/open-decisions.md#2026-09-06--dependent-template-operator-id-a-replacing-the-reopened-half-of-c). **Nothing is pending upstream and no draft is owed.** One clause in U§7.1 closes this row, and the clause must use the corrected justification — the gap is this feature's own, `DependentTemplateStorage` predating the new name kind — and **must not** use the struck "a limitation user-defined literal operators have had since C++11", which is false. The wording to use is in [operator-id-anywhere](unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere)'s *Recommended doc change* item (1). Nothing here turns into code on this project's branches.

### inner-call-source-range

**Formerly:** `B24`. **Severity:** P3.

**Item.** **The inner `CallExpr`'s source range begins at the operator**, after its own first child. `UserOperatorExpr` spans correctly; the inner node does not. Shared artifact with backtick ([backtick-source-range](#backtick-source-range)). **[re-graded]** *Not* cheap, and no longer part of the [backtick-source-range](#backtick-source-range) batch: `CallExpr::getBeginLoc` takes the begin from the callee and trunk **caches** it in a trailing `SourceLocation` (`CallExprBits.HasTrailingSourceLoc`, written by `updateTrailingSourceLoc()` from `CallExpr::Create`) with no public setter. Fixing it needs an upstream-shaped `CallExpr::Create` overload. Re-triage: own step, or WONTFIX on the grounds that the node *as written* spans correctly and a semantic form carrying the callee's range is what `-ast-dump` does for every desugaring.

**Where.** U11, U16 handoffs

**Closed by.** **WONTFIX, 2026-09-06, [upstream-triage](completion/steps/upstream-triage.md).** The node *as written* spans correctly (`UserOperatorExpr <col:30, col:36>` for `x ⊞ y`); the inner `CallExpr` is the semantic form, and taking its begin from its callee is what Clang does for every desugaring. Upstream's own C++20 rewritten comparison is the precedent: for `p < q` the outer `CXXRewrittenBinaryOperator` is `<col:28, col:32>` and the inner synthesized `CXXOperatorCallExpr` is `<col:28, col:30>`, which does not span the written form either and has never been treated as a defect. There is nothing to report upstream — upstream has no user-infix operators, so no upstream-visible symptom exists. **Correction to the re-grade above:** a public setter *does* exist. `CallExpr::setUsesMemberSyntax()` clears `HasTrailingSourceLoc` and calls `updateTrailingSourceLoc()`, and `getBeginLoc()` then takes the begin from argument 0 — exactly the wanted range, no `CallExpr::Create` overload needed. It is declined on meaning, not cost: that bit asserts "a call to an explicit-object member function written with member syntax", which is false of these nodes, and it is serialized into PCHs and modules for any later upstream consumer to read back. Recorded for the papers in [`docs/backtick-operator-design.md`](../docs/backtick-operator-design.md) §17.5, with a dated entry in [source-fidelity-node](../docs/backtick-operator-design.md#source-fidelity-node)'s Log, and in [`docs/unicode-operators.md`](../docs/unicode-operators.md) §7 "Desugaring".

### clangir-backtick-arms

**Formerly:** `B36`. **Severity:** P3.

**Item.** **`clang/lib/CIR/` has never seen a `BacktickInfixExpr` either.** The exact twin of [clangir-unicode-arms](#clangir-unicode-arms) on the backtick branches, using `getSubExpr()` in place of `getSemanticForm()`. The file had no row for it. *(Added 2026-08-05.)*

**Where.** derived from [clangir-unicode-arms](#clangir-unicode-arms)

**Closed by.** **BL04 — fixed on both backtick branches.** The twin was exact, including the crash: all four sites failed with the same diagnostics as `UserOperatorExpr`, naming `BacktickInfixExpr` instead. **That symmetry is the evidence that the l-value crash belongs to `emitLValue`'s default arm rather than to either node** — two unrelated wrappers, one abort. Verified in the same scratch build: `unicode-operators-experiment` carries both features, so one CIR build could compile and run both halves. The backtick-only hunks were then compiled and tested there in isolation (backtick arms alone → `backtick-infix.cpp` passes, `unicode-operator.cpp` fails, and vice versa) and the lines landed on `backtick-trunk`/`backtick-23` are byte-identical to the ones so verified. New test `clang/test/CIR/CodeGen/backtick-infix.cpp`.

### null-return-suppression

**Formerly:** `B37`. **Severity:** P2.

**Item.** **Both wrapper nodes defeat the analyzer's null-return suppression, so the operator form reports false positives the explicit call is spared.** `suppress-null-return-paths` (default **on**) suppresses a null-dereference report whose null came from an inlined callee's return. The suppression is gated on `CallEvent::isCallStmt(E)` in `BugReporterVisitors.cpp`'s handler (`:2365`), and `E` is the tracked expression — for `` p `identity` 0 `` or `p ⊘ 0` that is the *wrapper*, not the `CallExpr`, so the handler bails and the report is emitted. Measured post-BL03 in one TU: the operator form reports, the identically-desugaring explicit call does not; with `suppress-null-return-paths=false` both report. **This is a parity break in the noisy direction**, and it is *not* a BL03 regression — it is inherited from F24 and present on `backtick-trunk`/`backtick-23` too. Worse, **`clang/test/Analysis/backtick-infix.cpp`'s load-bearing assertion silently depends on it**: `bugs_are_still_found` passes only because the suppression misses the wrapper. BL03's own test sets `suppress-null-return-paths=false` deliberately so it tests parity rather than resting on the divergence. Fix is a seventh site — peel both wrappers before the `isCallStmt` test — but it changes an F24 test's premise, so it wants its own step. *(Added 2026-08-09 by BL03.)*

**Where.** BL03 handoff; `clang/lib/StaticAnalyzer/Core/BugReporterVisitors.cpp` (`peelOffOuterExpr`, not `:2365`); `clang/test/Analysis/backtick-infix.cpp`; `clang/test/Analysis/unicode-operator-analysis.cpp`

**Correction, 2026-09-06 ([null-return-suppression](completion/steps/null-return-suppression.md)).** The mechanism above is wrong, and the wrong part is load-bearing: **peeling the wrappers before the `isCallStmt` test changes nothing, because that handler is never reached.** `Tracker::track` calls `peelOffOuterExpr` and then `findNodeForExpression`, and a wrapper is not a program-point statement — the CFG has no element for it, which is exactly what BL03/F24 arranged — so the node lookup fails and the *entire* tracking chain is abandoned before any handler runs. Measured with a probe in `Tracker::track`: for `` p `identity` 0 `` it prints `Inner=BacktickInfixExpr LVNode=NULL` and stops, where the explicit call runs five nested tracks. **A second symptom follows from the same omission and was not recorded here:** the report that *is* emitted carries **2** path notes against the explicit call's **8** — no "Passing null pointer value via 1st parameter", no "Calling", no "Returning null pointer" — so the operator form was both noisier *and* less explained than the call it desugars to.

**Closed by.** **[null-return-suppression](completion/steps/null-return-suppression.md), 2026-09-06 — fixed on all four Clang branches.** One arm per wrapper in `peelOffOuterExpr`, beside the `FullExpr` and `OpaqueValueExpr` arms already there, so the operator form and the call become the *same expression* for everything downstream and every later answer agrees by construction rather than by a fix at each site that asks a question. Measured before and after in one TU carrying all four spellings: before, at the default setting, the three operator forms reported and `identity(p, 0)` did not; after, none of the four reports, and with `suppress-null-return-paths=false` all four do, with byte-identical eight-note paths. **Both Analysis tests were restructured**, because the fix removes what one of them rested on: `bugs_are_still_found` asserted parity at the default setting and passed only because the wrapper defeated the suppression, so it now runs with `suppress-null-return-paths=false` (as the Unicode test always did, deliberately) and a second `-verify` RUN line at the default setting asserts the suppression by having no directive to match. A new operand-dereference case in each file keeps a bug-finding assertion live at the default configuration, where the suppression was never meant to reach. Verified still a test: with `LiveVariables::LookThroughExpr`'s arm reverted, `bugs_are_still_found`'s assertion fails. Reconciled into `docs/backtick-operator-design.md` **§17.6** (the whole new subsection) and [source-fidelity-node](../docs/backtick-operator-design.md#source-fidelity-node)'s **third 2026-09-06 `Log.` entry**, and into `docs/unicode-operators.md` **§8**, the new *"The static analyzer, which no site list contains"* bullet in the **Clang** list.

## 4. Upstream LLVM defects found in passing

Not ours, found while doing this work, and worth reporting.

### increment-decrement-mangling

**Formerly:** `B25`. **Severity:** **P1**.

**Item.** **Clang mis-mangles `operator++` — and `operator--`.** The Itanium ABI spells prefix `pp_` / `mm_` and postfix `pp` / `mm`; Clang emits the postfix form for both. `template<class T> void f(decltype(++T{})); template<class T> void f(decltype(T{}++));` is `error: definition with same mangled name` on Clang and two distinct symbols on GCC 15.2. **[re-graded]** `operator--` fails identically (`_Z1fI1AEvDTmmtlT_EE`), which was recorded nowhere; and LLVM's own demangler *implements* the distinction it cannot emit (`ItaniumDemangle.h:5177-5178`, `:5223-5229`) — `llvm-cxxfilt` round-trips both spellings. A live cross-vendor divergence, unrelated to either feature. **Report upstream.**

**Where.** U21 handoff

**Closed by.** **NOT CLOSED — report [drafted](completion/upstream-drafts/increment-decrement-mangling.md) 2026-09-06 by [upstream-reports](completion/steps/upstream-reports.md), pending the maintainer filing it.** Re-confirmed against trunk `72417eb739e5`: both mangler sites read at that revision, and the collision reproduced on builds of `a815e6f267c1` and `d28193fa1ff6` for `++` **and** `--`, against `g++ 15.2.0`. Eight existing-issue searches, no duplicate. **The reproducer on file does not reproduce as written** — the two templates need explicit instantiations to force emission; the draft carries the corrected one. The row closes when the issue is posted and its number replaces the `LLVM-ISSUE-PENDING` token; until then [mangling-abi](completion/steps/mangling-abi.md) and [unicode-paper](completion/steps/unicode-paper.md) have no number to cite.

### unqualified-id-union-read

**Formerly:** `B26`. **Severity:** P2.

**Item.** **`ParseExprCXX.cpp:2297` reads the wrong union member** for `IK_LiteralOperatorId`. U07 guarded the new kind rather than fixing upstream's read; anyone adding a further `UnqualifiedId` payload hits it first. **[corrected 2026-09-06]** The cited line is no longer the defect: on trunk `72417eb739e5` the `err_missing_dependent_template_keyword` name-building block tests the kind and reads `Identifier`, which is right. The live read is the `OpKind` ternary in `Parser::ParseUnqualifiedIdTemplateId` (`ParseExprCXX.cpp:2374`), which excludes only `IK_Identifier` — and a **second, previously unrecorded** instance of the same ternary in `Parser::AnnotateTemplateIdToken` (`ParseTemplate.cpp:1155`), which has no kind guard at all.

**Where.** U07 handoff

**Closed by.** **NOT CLOSED — report [drafted](completion/upstream-drafts/unqualified-id-union-read.md) 2026-09-06 by [upstream-reports](completion/steps/upstream-reports.md), pending the maintainer filing it.** Confirmed by reading trunk `72417eb739e5`; still latent, with no observable misbehaviour (`operator""_x<'1','2'>()` compiles clean, because nothing downstream consumes the annotation's `Operator` for that kind). Four existing-issue searches: no duplicate, but **#20143** (open since 2014) is a sanitizer report of the *same* read at a third site, `Declarator::isStaticMember()`, which is kind-guarded on trunk today — cited in the draft as the precedent for the fix shape.

### cxxfilt-stdin-nonascii

**Formerly:** `B27`. **Severity:** P3.

**Item.** **`llvm-cxxfilt`'s stdin path splits on non-ASCII**, so `_Z3∂i` piped in is not demangled while the same string as an argv argument is. Affects extended-identifier function names, not this feature's ASCII-derived operator names.

**Where.** U09 handoff; [vendor-extended-mangling](unicode-operators/clang/DEVIATIONS.md#vendor-extended-mangling)

**Closed by.** **NOT CLOSED — report drafted 2026-09-06, pending the maintainer filing it**: [cxxfilt-stdin-nonascii draft](completion/upstream-drafts/cxxfilt-stdin-nonascii.md), by [upstream-triage](completion/steps/upstream-triage.md). Confirmed on two builds against trunk-identical source (`llvm-cxxfilt.cpp` is byte-identical between the build base and `72417eb739e5`); cause is `IsLegalItaniumChar` rejecting every byte `>= 0x80`, so the stdin splitter cuts a UTF-8 identifier into pieces. No duplicate in 5 queries; #39337 (the request that added the split) and #118705 cited as prior art. **#178767 is *not* this bug** — that symbol fails on the argv path too, so it is a demangler limitation, correcting the guess in [upstream-reports](completion/handoffs/upstream-reports.handoff.md)'s forward notes.

### auto-return-round-trip

**Formerly:** `B28`. **Severity:** P3.

**Item.** **`-ast-print` cannot round-trip an `auto`-returning function template** (deduced return type versus the `auto` primary). Pre-existing; costs five minutes to anyone writing a round-trip test.

**Where.** U16 handoff

**Closed by.** **NOT CLOSED — report drafted 2026-09-06, pending the maintainer filing it**: [auto-return-round-trip draft](completion/upstream-drafts/auto-return-round-trip.md), by [upstream-triage](completion/steps/upstream-triage.md). Confirmed on two builds; `DeclPrinter::VisitFunctionDecl` is identical between the build base and trunk `72417eb739e5`. Cause is `QualType Ty = D->getType()` — the type *after* deduction — where `FunctionDecl::getDeclaredReturnType()` exists and is documented for exactly this distinction. Control: the same shape with an explicit return type round-trips clean. No duplicate in 6 queries; #12178, #218420 and #147150 cited as prior art in the same family.

### pch-ast-print-order

**Formerly:** `B29`. **Severity:** P3.

**Item.** **`-ast-print` after a PCH prints a class's fields last** if they precede its methods. Pre-existing; breaks any naive PCH print-diff test.

**Where.** U17 handoff

**Closed by.** **NOT CLOSED — report drafted 2026-09-06, pending the maintainer filing it**: [pch-ast-print-order draft](completion/upstream-drafts/pch-ast-print-order.md), by [upstream-triage](completion/steps/upstream-triage.md). **Likely a comment on the open #24794, not a new issue** — same two functions, its "expels existing decls" half already fixed, this ordering half surviving because both loaders splice at the head. **Correction to the Item above:** the obvious reproducer does not reproduce. A class that sits in the PCH and is never named prints in source order; the class must be *used* from the main file, which is what forces `RecordDecl::LoadFieldsFromExternalStorage` to run before the full lexical load. `DeclBase.cpp` is byte-identical between the build base and trunk `72417eb739e5`. 7 queries.

### operator-caret-range

**Formerly:** `B30`. **Severity:** P3.

**Item.** **The caret for `use of undeclared 'operator⊞'` underlines only the `operator` keyword**, not the glyph. Upstream's shape — `operator+` and `operator""_x` produce the identical 8-column range. Cosmetic and shared.

**Where.** U10 handoff

**Closed by.** **WONTFIX, 2026-09-06, [upstream-triage](completion/steps/upstream-triage.md).** This is upstream's caret range for *every* operator-function-id, not a Unicode one and not a regression: in stock C++23 with no feature flag, `operator+(a, a)` and `operator""_x(a)` on undeclared operators each underline exactly the 8 columns of `operator` and nothing after it, character-identically to the glyph case. Verified independently on two builds (`a815e6f267c1` pristine, and `783a9c1a5f6f` with the flag off). It is cosmetic, no paper claim depends on it, and reporting it as a Unicode defect would be wrong while reporting it as the general case would be a trivial diagnostic-polish issue this project has no standing to prioritise. 3 targeted queries found no existing issue. Recorded for the papers in [operator-name-caret-range](../docs/unicode-operators.md#operator-name-caret-range), a new §10 subsection.

### clangir-lvalue-crash

**Formerly:** `B38`. **Severity:** P2.

**Item.** **`CIRGenFunction::emitLValue`'s default arm turns any unhandled l-value class into an assertion failure, not a diagnostic.** It calls `errorNYI("emitLValue: unsupported l-value class")` and then `return LValue()`; the default-constructed `LValue` carries a null `QualType`, which asserts downstream in `QualType::getCommonPtr` (`!isNull() && "Cannot retrieve a NULL type pointer"`). So the ClangIR NYI path, which is meant to be a hard diagnostic, aborts instead for this one site. Measured by BL04 with **both** wrapper nodes — `BacktickInfixExpr` and `UserOperatorExpr` abort identically at the same arm, which is what localizes it to the arm rather than to either node. Neither feature causes it and neither flag is needed to reach it: any `Expr` class missing from that switch, in l-value position, in a CIR build, does the same. Reachable today only in a `CLANG_ENABLE_CIR=ON` build, which is why nobody here had seen it. BL04 fixed the two arms it needed and left the default alone, since making the default diagnose properly is upstream's design call, not ours. *(Added 2026-09-03 by BL04.)*

**Where.** BL04 handoff; `clang/lib/CIR/CodeGen/CIRGenFunction.cpp` `emitLValue` default arm; [cir-backtick-arms](DEVIATIONS.md#cir-backtick-arms) / [codegen-dispatch-sites](unicode-operators/clang/DEVIATIONS.md#codegen-dispatch-sites)

**Closed by.** **NOT CLOSED — report [drafted](completion/upstream-drafts/clangir-lvalue-crash.md) 2026-09-06 by [upstream-reports](completion/steps/upstream-reports.md), pending the maintainer filing it.** **Widened by the confirmation: the default arm is one instance, not the pattern.** 21 arms of that one switch call `errorNYI(...)` and then `return LValue()`, and the enumerated ones are reachable from stock C++26 — `p...[0]` (`PackIndexingExpr`) in l-value position reproduces both failure modes with no feature flag: `p...[0] = 1;` gives BL04's exact `QualType::getCommonPtr` assertion, `return p...[0];` segfaults in `createStore` from `emitReturnStmt` instead. Verified against trunk `72417eb739e5` by reading `emitLValue` there, and by checking that the CIR build used (`6ee1358f7b47`, base `bb33de72920a`) differs from it only by BL04's two added arms, with `emitReturnStmt` identical. Seven existing-issue searches, no duplicate; **#202097** and **#214443** are the same "NYI, then continue with an invalid value" failure at other CIR sites, both closed, and are cited as prior art.

## 5. Environment and infrastructure

These are not code defects, but each one has already cost an agent a
mis-diagnosis, and each is recorded in a gate-facts section somewhere.

### inotify-watch-budget

**Formerly:** `B31`. **Severity:** P2.

**Item.** **The inotify watch budget is exhausted by a `cloud-drive-dae` process** (65,045 of 65,536), so 8 `DirectoryWatcherTest.*` cases fail intermittently on every branch. Not ours — the untouched binaries fail identically. Fix needs root: uncomment `/etc/sysctl.d/50-ubuntustudio.conf:6` (`fs.inotify.max_user_watches = 524288`, already present and commented out) and `sudo sysctl --system`. **[re-graded by BL01]** They do **not** fail unconditionally: the dependency is on *free* watches, and with ~155 free all 8 pass — BL01's unfiltered gate was clean on both branches with the budget in exactly that state. So do not budget them as expected failures. Also: there is no `DirectoryWatcherTests` binary; clang's unittests are consolidated into `AllClangUnitTests`.

**Closed by.** **CLOSED 2026-08-08 — the maintainer applied the root fix** (uncommented the sysctl line, `sysctl --system`). `fs.inotify.max_user_watches` now reports **524288**; all 8 `DirectoryWatcherTest.*` cases verified passing directly (`AllClangUnitTests --gtest_filter='DirectoryWatcherTest.*'`, 8/8). The latent load-dependent failure mode is gone — 8× headroom over `cloud-drive-dae`'s ~65k hoard. The `GTEST_FILTER` gate-around is obsolete; unfiltered runs stay the standard. **REOPENED 2026-09-03 by BL04 — the root fix does not hold, because the daemon grows into whatever budget it is given.** BL04's first gate failed all 8 with `No space left on device : inotify_add_watch()`; `sysctl` still reported the raised **524288**, and `cloud-drive-dae` was holding **523,774** of it. The 8× headroom argument was wrong: the hoard scaled with the limit. Confirmed environmental the same way as before — all 8 fail identically on the maintainer's untouched `~/src/llvm/build-main` binary. It remains *intermittent*, not deterministic: two later full runs the same day gave 0 failures (the CIR scratch build, unfiltered, `EXIT=0`) and 3 (`build-unicode`, run concurrently with it). So the earlier re-grade stands — still do not budget them as expected failures, still do not filter — but a gate that fails only these 8 is an environment reading, not a regression, and the check is `AllClangUnitTests --gtest_filter='DirectoryWatcherTest.*'` on a build dir your diff never touched. **Not a misbehaving process — `cloud-drive-dae` is the machine's continuous backup**, and watching every file is its job, so its hoard tracks the file count and will grow into any ceiling it is given. 524288 is at least a *plausible* ceiling for this tree rather than the 65536 default that was obviously too small, so the fix was worth making and should not be reverted. What it cannot be is a *guarantee*: with a legitimate consumer sized to the filesystem, free watches stay a shared, load-dependent resource, and these 8 tests are the only thing in `check-clang` that competes for it. Treat that as a standing condition of the environment, not an open defect to design around — the re-grade stands (never filter, never budget as expected failures), and a gate whose only failures are these 8 is an environment reading. Raising the ceiling again is the lever if it recurs, and it needs root.

### clang-executable-version

**Formerly:** `B32`. **Severity:** P2.

**Item.** **`CLANG_EXECUTABLE_VERSION` was set to `24-backtick` / `23-backtick`** in both backtick build dirs on 2026-08-02, and two tests assert on the driver binary's basename: `Analysis/scan-build/cxx-name.test` and `Driver/hip-gz-options.hip`. Proven environmental — the stale pre-edit binaries pass, the identically-sourced `clang-*-backtick` fail. Either revert the setting or add both tests to the backtick track's known-failures list. Both Unicode build dirs are plain `24`.

**Closed by.** **BL01 — fixed.** Reverted to `24`/`23`; 2-edge rebuild; both tests verified failing before and passing after; the orphaned `clang-*-backtick` binaries deleted.

### stray-clang-format-config

**Formerly:** `B33`. **Severity:** P3.

**Item.** **A stray 2018 `/home/sdowney/src/.clang-format`**, outside any repo, is picked up by clang-format walking up the tree and fails `Format/dump-config-objc-stdin.m` on `backtick-23` only. Documented as a known failure; do not "fix" the file.

**Closed by.** **BL01 — documented, no action.** Confirmed as the *only* remaining failure on `backtick-23`, and absent on `backtick-trunk`. `CLAUDE.md`'s known-failure section rewritten, which previously implied it applied to every branch.

### gcc-libstdcxx-build

**Formerly:** `B34`. **Severity:** P3.

**Item.** **GCC's libstdc++ is not built** in `gcc-backtick-build`, so no G-test can link and run. Add `make -j18 all-target-libstdc++-v3` if one ever needs to.

**Closed by.** **BL01 — recorded, no action.** Recipe added to `ops/gcc/PLAN.md`'s new gate-facts section, with the `cc1plus`-not-`xg++` fact and the [gcc-trunk-pin](#gcc-trunk-pin) pin.

## 6. Not defects — open design decisions

Recorded here only so this file is a complete index. Each is measured, has a
recommendation, and needs an author's decision, not an implementer's. **The
questions themselves are no longer restated here** — five of them, with their
options, their measured costs and a recommendation each, are in
[`docs/open-decisions.md`](../docs/open-decisions.md), written by
[decision-brief](completion/steps/decision-brief.md), and the author's answers
get recorded in that file:

- [prefix-arity-selection](../docs/open-decisions.md#prefix-arity-selection) —
  ledger row
  [prefix-arity-selection](unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection).
- [over-oper-restrictions](../docs/open-decisions.md#over-oper-restrictions) —
  ledger row
  [over-oper-restrictions](unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions).
- [fold-over-user-infix](../docs/open-decisions.md#fold-over-user-infix) — the
  U§13 question, answered once for both features; recorded in ledger row
  [infix-parse-cost](unicode-operators/clang/DEVIATIONS.md#infix-parse-cost)
  part (3).
- [postfix-operators](../docs/open-decisions.md#postfix-operators) — ledger row
  [postfix-operators](unicode-operators/clang/DEVIATIONS.md#postfix-operators),
  priced in U§13.1.
- [dependent-template-operator-id](../docs/open-decisions.md#dependent-template-operator-id)
  — the defect row [dependent-template-operator-id](#dependent-template-operator-id)
  re-triaged as a decision, since it falsifies U§7.1's word "anywhere".

The two that are **not** in that file, and where each is answered instead:

- **[operand-sequencing](unicode-operators/clang/DEVIATIONS.md#operand-sequencing)** — member versus non-member operand sequencing, decided by
  overload resolution. A CWG question with no implementation consequence;
  written up by
  [reconcile-declaring-using](completion/steps/reconcile-declaring-using.md).
- **[operator-mangling](../docs/unicode-operators.md#operator-mangling) / [msvc-mangling](unicode-operators/clang/DEVIATIONS.md#msvc-mangling)** — the Itanium first-class `<operator-name>`, and the
  Microsoft ABI, which has no production to borrow. Its own step,
  [mangling-abi](completion/steps/mangling-abi.md).

And one that is a doc sync rather than a decision:

- **U§6** — owes a sixth worked example (`⊖a ⊞ 2 * ⊖b`), evidenced in the
  tree and not yet written into the design;
  [reconcile-remainder](completion/steps/reconcile-remainder.md)'s.

## 7. Suggested order

**Superseded twice.** First by `ops/backlog/PLAN.md`, which scheduled and
gated the top of this list; then, on 2026-09-03, by `ops/completion/PLAN.md`,
which covers *everything* here and orders it differently on purpose.

The order below is by severity — which defect most damages the prototype.
That was right while the prototype was the deliverable. It is no longer:
the three implementation tracks are done, and the remaining question is
**which of these changes a paper.** `ops/completion/PLAN.md` is ordered by
that instead, and its §"Coverage" table maps every open row to a step.

Kept below because the severity reasoning is still true and still useful
when two items compete for one agent:

**BL01 — the four environment rows,
[inotify-watch-budget](#inotify-watch-budget),
[clang-executable-version](#clang-executable-version),
[stray-clang-format-config](#stray-clang-format-config) and
[gcc-libstdcxx-build](#gcc-libstdcxx-build) — first**, ahead of everything.
The first two inject 10 spurious
failures into every backtick gate, and until they are gone each step's Status
row spends a paragraph explaining failures that are not real.

**[type-slot-implementation](#type-slot-implementation)** next among the substantive items: it is still the only place a paper
says something the implementation does not do, and D4307 is the nearer paper.

**[unicode-analyzer-sites](#unicode-analyzer-sites) outranks [type-slot-implementation](#type-slot-implementation) on evidence**, though not on paper-truth. It was written
here as a suspicion; it is now three measured defects including a double
destructor. If the two ever compete for one agent, [unicode-analyzer-sites](#unicode-analyzer-sites) is the more urgent.
[clangir-unicode-arms](#clangir-unicode-arms) goes with it — the same class of unknown, though a smaller one than this
file first claimed.

**[clang-slot-adl](#clang-slot-adl) is added 2026-09-06 and outranks everything still open on this scale.**
It is the only row where the prototype silently computes a different answer
from the program it claims to be sugar for, and the paper sentence it
falsifies is a *normative* one. It was not on this list at any earlier point
because nobody had run the measurement; it took four lines.

**[increment-decrement-mangling](#increment-decrement-mangling)** is independent of everything and should go upstream on its own; it
can run at any time.

The rest batch: **[c-mode-tokenization](#c-mode-tokenization), [backtick-source-range](#backtick-source-range), [dead-nesting-diagnostic](#dead-nesting-diagnostic), [template-ast-print-test](#template-ast-print-test) and [libclang-cursor-arm](#libclang-cursor-arm)** are one sitting on the
backtick branches; **[lldb-hunk-verification](#lldb-hunk-verification), [code-completion-priority](#code-completion-priority) and [ucd-input-manifest](#ucd-input-manifest)** are one sitting on the Unicode
branches. **[inner-call-source-range](#inner-call-source-range) is not in that first batch** — it was listed here as cheap
and it is not; see its row.
