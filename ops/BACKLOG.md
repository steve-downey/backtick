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

---

## 1. Backtick track — Clang (`backtick-trunk`, `backtick-23`)

| ID | Sev | Item | Where |
|----|-----|------|-------|
| B01 | **P1** | **§17.3's D16 is not implemented.** `` 1 `P` 2 `` for a class `P` is rejected with *'P' does not refer to a value*. The design doc blesses type-name-in-slot and D4307 has a section asserting it, so the paper currently claims a feature the implementation does not deliver. Either implement it or cut the section. | F23/F24 handoff; `docs/backtick-operator-design.md` §17.3, D16; `papers/d4307r0.md` |
| B02 | **P2** | **The keyword escape does not round-trip through `-ast-print`.** `` void `new`(); `` prints as `void new();`, which does not re-parse. Different node from the infix wrapper, and a different defect from the one F23/F24 fixed. `backtick-escape.cpp` never runs `-ast-print`, which is why nine steps missed it. | F23/F24 handoff |
| B03 | P2 | **`-fbacktick` still lacks `ShouldParseIf<cplusplus.KeyPath>`.** The flag changes C-mode tokenization for a grammar that is C++-only. The Unicode branch carries the paired one-line fix for both flags; the backtick track owes itself the `defm backtick` half. | DEV-U07 (resolved on the Unicode branch only); U04 handoff |
| B04 | P2 | **`BacktickInfixExpr`'s source range does not span its operands** — it is `<col:22, col:23>`, just the callee. Cheap now that `getCallExpr()` exists. | F23/F24 handoff; U11 handoff |
| B05 | P2 | **ASTMatchers and clang-tidy do not know `BacktickInfixExpr`.** The same gap U17 closed for `UserOperatorExpr` on the Unicode side, still open here. | F23/F24 handoff |
| B06 | P3 | **`err_backtick_nested_requires_parens` is dead code**, carried since S04 and never fired. Remove it, or implement the D3 lookahead it was written for. | S04–S11, R23, R24, F23/F24 handoffs (carried nine times) |
| B07 | P3 | **D8's slot-interior `SplitPenalty` bump is unimplemented.** The hard constraints suffice for identifier and qualified-name slots; a long multi-token slot would format badly. | S10 handoff, carried through R23/R24 |
| B08 | P3 | **No `-ast-print` test covers a backtick expression in a template context**, so `TransformBacktickInfixExpr` is unexercised for round-trip. | S11 handoff |

## 2. Backtick track — GCC (`backtick`)

| ID | Sev | Item | Where |
|----|-----|------|-------|
| B09 | P2 | **Pure ADL on a template-id slot still fails.** `` x `add<int>` y `` takes the old path, because G10's two-token lookahead (`CPP_NAME` + `CPP_BACKTICK`) does not detect a template-id. §17.4's normative claim holds for bare names only. | G10 handoff; DEV-G05's neighbourhood |
| B10 | P2 | **Module streaming of keyword-escaped names is untested.** `IDENTIFIER_KEYWORD_P` checks in `module.cc:20117` and `:20160` may need attention if a keyword-named entity is exported. Deferred three times. | G07, G08, G09, G10 handoffs |
| B11 | P3 | **The `flag_backtick` guard in `grokdeclarator` is over-permissive** — it suppresses the keyword-declarator error for *all* keyword names when the flag is set, not only explicitly escaped ones. Benign today because the parser rejects non-escaped keywords earlier. | DEV-G07a; G07–G10 handoffs |
| B12 | P3 | **GCC has neither F23 nor F24 fix, and cannot have the first**: no phase-2 AST wrapper was ever built there, and there is no analyzer analogue. No cross-compiler divergence row is warranted — there is nothing to diverge from. | F23/F24 handoff |
| B13 | P3 | **The GCC track is pinned at trunk `c9ee2c5ab6c`** while Clang has moved to 23.x and 24.x. Re-sync before any fresh cross-compiler divergence testing. | R23, R24 handoffs |

## 3. Unicode track — Clang (`unicode-operators-experiment`, `unicode-operators-upstream`)

| ID | Sev | Item | Where |
|----|-----|------|-------|
| B14 | **P1** | **The static analyzer almost certainly mishandles `UserOperatorExpr`, and nobody has looked.** F24 found that the equivalent gap for `BacktickInfixExpr` was not a warning but five defects — a dropped CFG successor that left *whole functions unanalyzed*, a broken construction-context chain, a double destructor, and a `LiveVariables` hole that silently returned UNKNOWN for every result. U16 recorded only that the node is absent from `ignoreTransparentExprs`. The node is *not* transparent to transformation, so F24's fix does not transplant unchanged; the five sites still have to be audited one at a time. | U16 handoff; F24 handoff (`Environment.cpp:37`, `CFG.cpp`, `LiveVariables.cpp`, `ExprEngine.cpp`) |
| B15 | **P1** | **`clang/lib/CIR/` has never been compiled on this branch and has never seen a `UserOperatorExpr`.** `LLVM_ENABLE_PROJECTS` is `clang;clang-tools-extra`, so the ClangIR code generator is not built. Flagged unchanged by six consecutive steps. Unknown whether it needs a case at all; unknown is the problem. | U04, U05, U12, U14, U15 handoffs |
| B16 | P2 | **The lldb hunk is compile-unverified.** One line in `ClangASTSource.cpp:125`; lldb is not in this build's projects. The only hunk in the whole feature no compiler has seen. | U06 handoff; REPLAY row |
| B17 | P2 | **`SemaCodeComplete.cpp:1061`'s completion-priority grouping was never updated.** Left alone by U06, U07, U08, U09, U11 and U16 in turn. Completion after an infix user operator is a reachable state. | U08–U16 handoffs (carried six times) |
| B18 | P2 | **`TemplateIdAnnotation` carries no code point** for `operator⊞<T>` (`TemplateII = nullptr`, `OpKind = OO_None`) — the same gap upstream has for literal operators, marked there with a pre-existing FIXME. Resolution goes through the `TemplateName`, so nothing is wrong today. | U07 handoff |
| B19 | P2 | **`hasAnyOperatorName()` cannot express a user operator** and was deliberately not supported: it returns a `StringRef` into a static spelling table and a user operator's spelling is computed. A matcher API that structurally cannot name the operator. | U17 handoff; DEV-U14 |
| B20 | P3 | **The astral-plane and zero-padding branches of the mangling derivation are untested by construction** — every U1 code point is in 0x2190–0x2BFF, so every derived name is exactly four digits. First thing to test if U1 ever grows past the BMP. | U09 handoff; DEV-U08 |
| B21 | P3 | **The UCD 17.0.0 inputs are in neither repo**, so the generated character tables cannot be regenerated without re-fetching five files. A hash manifest in `docs/` is the cheap fix, and the paper's reproducibility claim wants one. | U02 handoff |
| B22 | P3 | **The confusable-to-ASCII spellings are a judgement call, not derived.** ∙ ⋅ → `.` and ⇔ → `<=>` were assigned by hand; the generator has no `confusables.txt` input. They now appear in user-facing diagnostics. The table shape already supports deriving them. | U02, U05 handoffs; DEV-U03 |
| B23 | P3 | **`t.template operator⊞<int>(0)` on a dependent object expression is rejected.** Inherited, not introduced: `DependentTemplateStorage` holds an identifier or a built-in operator kind and nothing else, and user-defined literal operators have had the identical limitation since C++11. Falsifies the word "anywhere" in U§7.1. | DEV-U10; U07, U10 handoffs |
| B24 | P3 | **The inner `CallExpr`'s source range begins at the operator**, after its own first child. `UserOperatorExpr` spans correctly; the inner node does not. Shared artifact with backtick (B04). | U11, U16 handoffs |

## 4. Upstream LLVM defects found in passing

Not ours, found while doing this work, and worth reporting.

| ID | Sev | Item | Where |
|----|-----|------|-------|
| B25 | **P1** | **Clang mis-mangles `operator++`.** The Itanium ABI spells prefix `pp_` and postfix `pp`; Clang emits `pp` for both. `template<class T> void f(decltype(++T{})); template<class T> void f(decltype(T{}++));` is `error: definition with same mangled name` on Clang and two distinct symbols on GCC 15.2. A live cross-vendor divergence, unrelated to either feature. **Report upstream.** | U21 handoff |
| B26 | P2 | **`ParseExprCXX.cpp:2297` reads the wrong union member** for `IK_LiteralOperatorId`. U07 guarded the new kind rather than fixing upstream's read; anyone adding a further `UnqualifiedId` payload hits it first. | U07 handoff |
| B27 | P3 | **`llvm-cxxfilt`'s stdin path splits on non-ASCII**, so `_Z3∂i` piped in is not demangled while the same string as an argv argument is. Affects extended-identifier function names, not this feature's ASCII-derived operator names. | U09 handoff; DEV-U08 |
| B28 | P3 | **`-ast-print` cannot round-trip an `auto`-returning function template** (deduced return type versus the `auto` primary). Pre-existing; costs five minutes to anyone writing a round-trip test. | U16 handoff |
| B29 | P3 | **`-ast-print` after a PCH prints a class's fields last** if they precede its methods. Pre-existing; breaks any naive PCH print-diff test. | U17 handoff |
| B30 | P3 | **The caret for `use of undeclared 'operator⊞'` underlines only the `operator` keyword**, not the glyph. Upstream's shape — `operator+` and `operator""_x` produce the identical 8-column range. Cosmetic and shared. | U10 handoff |

## 5. Environment and infrastructure

These are not code defects, but each one has already cost an agent a
mis-diagnosis, and each is recorded in a gate-facts section somewhere.

| ID | Sev | Item |
|----|-----|------|
| B31 | P2 | **The inotify watch budget is exhausted by a `cloud-drive-dae` process** (65,382 of 65,536), so 8 `DirectoryWatcherTest.*` cases fail intermittently on every branch. Not ours — the untouched binaries fail identically. Fix needs root: `sysctl -w fs.inotify.max_user_watches=524288`, persisted in `/etc/sysctl.d/`. Until then every gate needs the `GTEST_FILTER` re-run. |
| B32 | P2 | **`CLANG_EXECUTABLE_VERSION` was set to `24-backtick` / `23-backtick`** in both backtick build dirs on 2026-08-02, and two tests assert on the driver binary's basename: `Analysis/scan-build/cxx-name.test` and `Driver/hip-gz-options.hip`. Proven environmental — the stale pre-edit binaries pass, the identically-sourced `clang-*-backtick` fail. Either revert the setting or add both tests to the backtick track's known-failures list. |
| B33 | P3 | **A stray 2018 `/home/sdowney/src/.clang-format`**, outside any repo, is picked up by clang-format walking up the tree and fails `Format/dump-config-objc-stdin.m` on `backtick-23` only. Documented as a known failure; do not "fix" the file. |
| B34 | P3 | **GCC's libstdc++ is not built** in `gcc-backtick-build`, so no G-test can link and run. Add `make -j18 all-target-libstdc++-v3` if one ever needs to. |

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

B01 first: it is the only item where a paper says something the
implementation does not do, and D4307 is the nearer paper.

Then B14 and B15 together, because F24 established that "the analyzer is
missing a case" is not a warning-level problem, and B15 is the same class of
unknown — a whole code generator that has never seen the node.

B25 is independent of everything and should go upstream on its own.

The rest are cheap and can be batched: B03, B04, B06 and B08 are one sitting
on the backtick branches; B16, B17 and B21 are one sitting on the Unicode
branches.
