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

**Scheduled work lives in `ops/backlog/PLAN.md`** (steps BL01–BL07). The
`Closed by` column below is filled in by the step that closes the row; an
empty cell means nobody owns it yet. Rows re-graded on 2026-08-05 against
measurements rather than handoff prose are marked **[re-graded]**.

---

## 1. Backtick track — Clang (`backtick-trunk`, `backtick-23`)

| ID | Sev | Item | Where | Closed by |
|----|-----|------|-------|-----------|
| B01 | **P1** | **§17.3's D16 is not implemented.** `` 1 `P` 2 `` for a class `P` is rejected with *'P' does not refer to a value*. The design doc blesses type-name-in-slot and D4307 has a section asserting it, so the paper currently claims a feature the implementation does not deliver. **[re-graded]** It is *three* failure modes, not one — a bare class name, a class template (`use of class template 'pr' requires template arguments`, and a class template is the paper's own example), and a qualified or builtin type (`expected '(' for function-style cast or type construction`). Worse, the claim sits in the **normative** example at `papers/d4307r0.md:940` while the proposed grammar at `:911-914` is `backtick-operator: assignment-expression`, which `std::pair` is not — so the wording contradicts itself. Resolution chosen: **implement**. | F23/F24 handoff; `docs/backtick-operator-design.md` §17.3, D16; `papers/d4307r0.md` | **BL02** |
| B02 | P2 | **The keyword escape does not round-trip through `-ast-print`.** `` void `new`(); `` prints as `void new();`, which does not re-parse. Different node from the infix wrapper, and a different defect from the one F23/F24 fixed. `backtick-escape.cpp` never runs `-ast-print`, which is why nine steps missed it. The site is `DeclarationName::print`'s `Identifier` arm (`clang/lib/AST/DeclarationName.cpp:131-148`), which is also the **diagnostic** path — so this needs a `PrintingPolicy` bit and a decision about diagnostic wording, not just a guard. | F23/F24 handoff | |
| B03 | P2 | **`-fbacktick` still lacks `ShouldParseIf<cplusplus.KeyPath>`.** The flag changes C-mode tokenization for a grammar that is C++-only. The Unicode branch carries the paired one-line fix for both flags; the backtick track owes itself the `defm backtick` half. **[re-graded]** The symptom is worse than DEV-U07 records: C does not merely lose a diagnostic, it **accepts** the grammar — `` int f(int a,int b){ return a `g` b; } `` compiled as C with `-fbacktick` exits 0. | DEV-U07 (resolved on the Unicode branch only); U04 handoff | **BL06** |
| B04 | P2 | **`BacktickInfixExpr`'s source range does not span its operands** — it is `<col:22, col:23>`, just the callee. Cheap now that `getCallExpr()` exists. Model the fix on `UserOperatorExpr::getBeginLoc` (`ExprCXX.h:471-491`), whose doc comment diagnoses the identical root cause. | F23/F24 handoff; U11 handoff | **BL06** |
| B05 | P2 | **ASTMatchers and clang-tidy do not know `BacktickInfixExpr`.** The same gap U17 closed for `UserOperatorExpr` on the Unicode side, still open here. Sized from U17: ~5 production/docs files at +58 lines plus +59 of test. `clang-tidy` itself needs nothing. Note `clang/docs/LibASTMatchersReference.html` is generated and gated by `clang/test/AST/ast_matchers_updated.test` — adding a matcher without regenerating fails the gate. | F23/F24 handoff | |
| B06 | P3 | **`err_backtick_nested_requires_parens` is dead code**, carried since S04 and never fired. Remove it — DEV-04 is RESOLVED in the other direction (§17.1: bare nesting is blessed D1 chaining and cannot be diagnosed), so the diagnostic is unfireable *as specified*. Do not implement the D3 lookahead. | S04–S11, R23, R24, F23/F24 handoffs (carried nine times) | **BL06** |
| B07 | P3 | **D8's slot-interior `SplitPenalty` bump is unimplemented.** The hard constraints suffice for identifier and qualified-name slots; a long multi-token slot would format badly. | S10 handoff, carried through R23/R24 | |
| B08 | P3 | **No `-ast-print` test covers a backtick expression in a template context**, so `TransformBacktickInfixExpr` is unexercised for round-trip. Watch B28 — write an explicit return type, not `auto`. | S11 handoff | **BL06** |
| B35 | P3 | **libclang does not know `BacktickInfixExpr`.** `clang/tools/libclang/CXCursor.cpp`'s exhaustive `MakeCXCursor` switch has no arm, so a `-Wswitch` warning is still live on this `WERROR=OFF` build and libclang maps a backtick expression to `CXCursor_NotImplemented`. F24 closed the sibling gap in `ExprEngine.cpp`; U17 left the backtick half alone. One line next to `CXXRewrittenBinaryOperatorClass`. *(Added 2026-08-05.)* | U17 handoff `:196-200`, `:472-476` | **BL06** |

## 2. Backtick track — GCC (`backtick`)

| ID | Sev | Item | Where | Closed by |
|----|-----|------|-------|-----------|
| B09 | P2 | **Pure ADL on a template-id slot still fails.** `` x `add<int>` y `` takes the old path, because G10's two-token lookahead (`CPP_NAME` + `CPP_BACKTICK`) does not detect a template-id. §17.4's normative claim holds for bare names only. | G10 handoff; DEV-G05's neighbourhood | |
| B10 | P2 | **Module streaming of keyword-escaped names is untested.** `IDENTIFIER_KEYWORD_P` checks in `module.cc:20117` and `:20160` may need attention if a keyword-named entity is exported. Deferred three times. | G07, G08, G09, G10 handoffs | |
| B11 | P3 | **The `flag_backtick` guard in `grokdeclarator` is over-permissive** — it suppresses the keyword-declarator error for *all* keyword names when the flag is set, not only explicitly escaped ones. Benign today because the parser rejects non-escaped keywords earlier. | DEV-G07a; G07–G10 handoffs | |
| B12 | P3 | **GCC has neither F23 nor F24 fix, and cannot have the first**: no phase-2 AST wrapper was ever built there, and there is no analyzer analogue. No cross-compiler divergence row is warranted — there is nothing to diverge from. | F23/F24 handoff | |
| B13 | P3 | **The GCC track is pinned at trunk `c9ee2c5ab6c`** while Clang has moved to 23.x and 24.x. Re-sync before any fresh cross-compiler divergence testing. | R23, R24 handoffs | |

## 3. Unicode track — Clang (`unicode-operators-experiment`, `unicode-operators-upstream`)

| ID | Sev | Item | Where | Closed by |
|----|-----|------|-------|-----------|
| B14 | **P1** | ~~The static analyzer almost certainly mishandles `UserOperatorExpr`, and nobody has looked.~~ **[re-graded 2026-08-05 — measured, not suspected.]** Three of F24's five defects are **observed** on `build-unicode`: `clang_analyzer_eval(x == 3)` after `int x = 1 ⊞ 2;` reports **both `FALSE` and `TRUE`** where the explicit `operator⊞(1,2)` reports `TRUE` only; `const S &r = 1 ⊞ 2;` yields `(CXXRecordTypedCall, [B1.6])` where the explicit call yields `[B1.8]`, character-for-character F24's symptom; and the CFG carries a temporary-object destructor *and* the implicit one. Only the dropped-successor defect is absent, because U16's `ExprEngine` case keeps the path alive. The node is not transparent to *transformation*, so F24's fix does not transplant unchanged — and there is no `getSubExpr()`, only `getSemanticForm()`. **`CFG.cpp` and `ExprEngine.cpp` are coupled**: U16's grouping is self-consistent only while `CFG.cpp` has no case. | U16 handoff; F24 handoff (`Environment.cpp:37`, `CFG.cpp`, `LiveVariables.cpp`, `ExprEngine.cpp`) | **BL03** |
| B15 | **P1** | **`clang/lib/CIR/` has never been compiled on this branch and has never seen a `UserOperatorExpr`.** `LLVM_ENABLE_PROJECTS` is `clang;clang-tools-extra`, so the ClangIR code generator is not built. Flagged unchanged by six consecutive steps. **[re-graded]** Not "unknown whether it needs a case at all": U19 identified it as a genuine hole, the four sites are known (`CIRGenExprScalar.cpp:585-587`, `CIRGenExprAggregate.cpp:440-442`, `CIRGenExprComplex.cpp:275-277`, `CIRGenFunction.cpp:1187-1190`), three are copy-paste from the `CXXRewrittenBinaryOperator` arms because `getSemanticForm()` already exists, and the fallbacks are `errorNYI` rather than crashes — so the worst case is a hard NYI diagnostic, not a miscompile. The remaining unknown is only whether the build passes. Needs MLIR **and** `CLANG_ENABLE_CIR=ON`; the CMake `FATAL_ERROR`s otherwise. | U04, U05, U12, U14, U15 handoffs; U16 `:390-394`; U19 `:131-133` | **BL04** |
| B16 | P2 | **The lldb hunk is compile-unverified.** One line in `ClangASTSource.cpp:125`; lldb is not in this build's projects. The only hunk in the whole feature no compiler has seen. Prerequisites are all present on this machine; building `lldbPluginExpressionParserClang` alone compiles the TU without linking lldb. | U06 handoff; REPLAY row | **BL07** |
| B17 | P2 | **`SemaCodeComplete.cpp:1061`'s completion-priority grouping was never updated.** Left alone by U06, U07, U08, U09, U11 and U16 in turn. Completion after an infix user operator is a reachable state. The reason it kept being deferred is that priorities are not printed — but results *are* priority-sorted (`CodeCompleteConsumer.cpp:645`), so an ordering-based test is the observable. | U08–U16 handoffs (carried six times) | **BL07** |
| B18 | P2 | **`TemplateIdAnnotation` carries no code point** for `operator⊞<T>` (`TemplateII = nullptr`, `OpKind = OO_None`) — the same gap upstream has for literal operators, marked there with a pre-existing FIXME. Resolution goes through the `TemplateName`, so nothing is wrong today. | U07 handoff | |
| B19 | P2 | **`hasAnyOperatorName()` cannot express a user operator** and was deliberately not supported: it returns a `StringRef` into a static spelling table and a user operator's spelling is computed. A matcher API that structurally cannot name the operator. | U17 handoff; DEV-U14 | |
| B20 | P3 | **The astral-plane and zero-padding branches of the mangling derivation are untested by construction** — every U1 code point is in 0x2190–0x2BFF, so every derived name is exactly four digits. First thing to test if U1 ever grows past the BMP. | U09 handoff; DEV-U08 | |
| B21 | P3 | **The UCD 17.0.0 inputs are in neither repo**, so the generated character tables cannot be regenerated without re-fetching five files. A hash manifest in `docs/` is the cheap fix, and the paper's reproducibility claim wants one. Needs network access to unicode.org — it is the only item in either cheap batch with an external dependency. | U02 handoff | **BL07** |
| B22 | P3 | **The confusable-to-ASCII spellings are a judgement call, not derived.** ∙ ⋅ → `.` and ⇔ → `<=>` were assigned by hand; the generator has no `confusables.txt` input. They now appear in user-facing diagnostics. The table shape already supports deriving them. | U02, U05 handoffs; DEV-U03 | |
| B23 | P3 | **`t.template operator⊞<int>(0)` on a dependent object expression is rejected.** Inherited, not introduced: `DependentTemplateStorage` holds an identifier or a built-in operator kind and nothing else, and user-defined literal operators have had the identical limitation since C++11. Falsifies the word "anywhere" in U§7.1. | DEV-U10; U07, U10 handoffs | |
| B24 | P3 | **The inner `CallExpr`'s source range begins at the operator**, after its own first child. `UserOperatorExpr` spans correctly; the inner node does not. Shared artifact with backtick (B04). **[re-graded]** *Not* cheap, and no longer part of the B04 batch: `CallExpr::getBeginLoc` takes the begin from the callee and trunk **caches** it in a trailing `SourceLocation` (`CallExprBits.HasTrailingSourceLoc`, written by `updateTrailingSourceLoc()` from `CallExpr::Create`) with no public setter. Fixing it needs an upstream-shaped `CallExpr::Create` overload. Re-triage: own step, or WONTFIX on the grounds that the node *as written* spans correctly and a semantic form carrying the callee's range is what `-ast-dump` does for every desugaring. | U11, U16 handoffs | |
| B36 | P3 | **`clang/lib/CIR/` has never seen a `BacktickInfixExpr` either.** The exact twin of B15 on the backtick branches, using `getSubExpr()` in place of `getSemanticForm()`. The file had no row for it. *(Added 2026-08-05.)* | derived from B15 | **BL04** |

## 4. Upstream LLVM defects found in passing

Not ours, found while doing this work, and worth reporting.

| ID | Sev | Item | Where | Closed by |
|----|-----|------|-------|-----------|
| B25 | **P1** | **Clang mis-mangles `operator++` — and `operator--`.** The Itanium ABI spells prefix `pp_` / `mm_` and postfix `pp` / `mm`; Clang emits the postfix form for both. `template<class T> void f(decltype(++T{})); template<class T> void f(decltype(T{}++));` is `error: definition with same mangled name` on Clang and two distinct symbols on GCC 15.2. **[re-graded]** `operator--` fails identically (`_Z1fI1AEvDTmmtlT_EE`), which was recorded nowhere; and LLVM's own demangler *implements* the distinction it cannot emit (`ItaniumDemangle.h:5177-5178`, `:5223-5229`) — `llvm-cxxfilt` round-trips both spellings. A live cross-vendor divergence, unrelated to either feature. **Report upstream.** | U21 handoff | **BL05** |
| B26 | P2 | **`ParseExprCXX.cpp:2297` reads the wrong union member** for `IK_LiteralOperatorId`. U07 guarded the new kind rather than fixing upstream's read; anyone adding a further `UnqualifiedId` payload hits it first. | U07 handoff | |
| B27 | P3 | **`llvm-cxxfilt`'s stdin path splits on non-ASCII**, so `_Z3∂i` piped in is not demangled while the same string as an argv argument is. Affects extended-identifier function names, not this feature's ASCII-derived operator names. | U09 handoff; DEV-U08 | |
| B28 | P3 | **`-ast-print` cannot round-trip an `auto`-returning function template** (deduced return type versus the `auto` primary). Pre-existing; costs five minutes to anyone writing a round-trip test. | U16 handoff | |
| B29 | P3 | **`-ast-print` after a PCH prints a class's fields last** if they precede its methods. Pre-existing; breaks any naive PCH print-diff test. | U17 handoff | |
| B30 | P3 | **The caret for `use of undeclared 'operator⊞'` underlines only the `operator` keyword**, not the glyph. Upstream's shape — `operator+` and `operator""_x` produce the identical 8-column range. Cosmetic and shared. | U10 handoff | |

## 5. Environment and infrastructure

These are not code defects, but each one has already cost an agent a
mis-diagnosis, and each is recorded in a gate-facts section somewhere.

| ID | Sev | Item | Closed by |
|----|-----|------|-----------|
| B31 | P2 | **The inotify watch budget is exhausted by a `cloud-drive-dae` process** (65,382 of 65,536), so 8 `DirectoryWatcherTest.*` cases fail intermittently on every branch. Not ours — the untouched binaries fail identically. Fix needs root: `sysctl -w fs.inotify.max_user_watches=524288`, persisted in `/etc/sysctl.d/`. The line is already present and **commented out** at `/etc/sysctl.d/50-ubuntustudio.conf:6`. Until then every gate needs the `GTEST_FILTER` re-run. | **BL01** |
| B32 | P2 | **`CLANG_EXECUTABLE_VERSION` was set to `24-backtick` / `23-backtick`** in both backtick build dirs on 2026-08-02, and two tests assert on the driver binary's basename: `Analysis/scan-build/cxx-name.test` and `Driver/hip-gz-options.hip`. Proven environmental — the stale pre-edit binaries pass, the identically-sourced `clang-*-backtick` fail. Either revert the setting or add both tests to the backtick track's known-failures list. Both Unicode build dirs are plain `24`. | **BL01** |
| B33 | P3 | **A stray 2018 `/home/sdowney/src/.clang-format`**, outside any repo, is picked up by clang-format walking up the tree and fails `Format/dump-config-objc-stdin.m` on `backtick-23` only. Documented as a known failure; do not "fix" the file. | **BL01** |
| B34 | P3 | **GCC's libstdc++ is not built** in `gcc-backtick-build`, so no G-test can link and run. Add `make -j18 all-target-libstdc++-v3` if one ever needs to. | **BL01** |

## 6. Not defects — open design decisions

Recorded here only so this file is a complete index. Each is measured, has a
recommendation, and needs an author's decision, not an implementer's:

- **DEV-U15** — a prefix use finds a two-parameter operator through its
  default argument. Keep and document, or reinstate [over.oper]p8.
- **DEV-U16** — member versus non-member operand sequencing, decided by
  overload resolution. CWG question.
- **DEV-U06** — static member user operators, currently rejected with no
  design guidance.
- **U§13** — fold expressions over the user-infix level, to be answered once
  for both features.
- **U8 / DEV-U09** — the Itanium first-class `<operator-name>`, and the
  Microsoft ABI, which has no production to borrow.
- **DEV-U23 / U21** — postfix operators, deferred with a measured account.
- **U§6** — owes a sixth worked example (`⊖a ⊞ 2 * ⊖b`), evidenced in the
  tree and not yet written into the design.

## 7. Suggested order

Superseded by `ops/backlog/PLAN.md`, which schedules and gates this. The
reasoning, updated for what measurement changed:

**BL01 (`B31`–`B34`) first**, ahead of everything. B31+B32 inject 10 spurious
failures into every backtick gate, and until they are gone each step's Status
row spends a paragraph explaining failures that are not real.

**B01** next among the substantive items: it is still the only place a paper
says something the implementation does not do, and D4307 is the nearer paper.

**B14 outranks B01 on evidence**, though not on paper-truth. It was written
here as a suspicion; it is now three measured defects including a double
destructor. If the two ever compete for one agent, B14 is the more urgent.
B15 goes with it — the same class of unknown, though a smaller one than this
file first claimed.

**B25** is independent of everything and should go upstream on its own; it
can run at any time.

The rest batch: **B03, B04, B06, B08 and B35** are one sitting on the
backtick branches; **B16, B17 and B21** are one sitting on the Unicode
branches. **B24 is not in that first batch** — it was listed here as cheap
and it is not; see its row.
