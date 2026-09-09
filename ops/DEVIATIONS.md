# Deviation ledger — implementation reality vs. the proven design

Each row is a place the build taught us something the paper didn't know.
The paper author reconciles these into `docs/backtick-operator-design.md`
§3 (decisions log) and the relevant section. This file is the operational
half of "we have merely proved, not tested."

Each entry is headed by its **slug** and is therefore a Markdown anchor;
cross-references link to it. `Formerly:` carries the serial number the entry
used to have, because the completed tracks' handoffs still say it and are not
rewritten. [`ops/SLUGS.md`](SLUGS.md) is the whole map.

### options-td-path

**Formerly:** `DEV-01`. **Status:** **RECONCILED**

**Found by.** S00 (for S01)

**Design section.** §6.5; step S01

**What the design said.** Driver flag lives in `clang/include/clang/Driver/Options.td`

**What was true.** `Options.td` moved to `clang/include/clang/Options/Options.td`

**Recommended doc change.** **RECONCILED** into §6.5 (path corrected).

### langopt-macro-arity

**Formerly:** `DEV-02`. **Status:** **RECONCILED**

**Found by.** S00 (for S01)

**Design section.** §6.5; step S01

**What the design said.** `LANGOPT(Backtick, 1, 0, "...")` (4 args)

**What was true.** `LANGOPT` now takes 5 args incl. a compatibility kind: `LANGOPT(Name, Bits, Default, Compatibility, Description)`, e.g. `LANGOPT(C99, 1, 0, NotCompatible, "C99")`. 4-arg form won't compile.

**Recommended doc change.** **RECONCILED** into §6.5 (5-arg `NotCompatible` form shown).

### driver-flag-forwarding

**Formerly:** `DEV-03`. **Status:** **RECONCILED**

**Found by.** S01

**Design section.** §6.5; step S01

**What the design said.** `BoolFOption` with `BothFlags<[], [ClangOption, CC1Option]>` + marshalling is sufficient for driver→cc1 forwarding

**What was true.** Marshalling alone does NOT forward the flag. The driver parses it (ClangOption) but won't emit it in the cc1 argv without an explicit `Args.addLastArg(CmdArgs, OPT_fbacktick, OPT_fno_backtick)` in `Clang.cpp::ConstructJob()`. Reference: `-freflection` (CC1Option only, no forwarding); `-fsized-deallocation` (also needs explicit `addLastArg`).

**Recommended doc change.** **RECONCILED** into §6.5 (explicit `addLastArg` in `Clang.cpp::ConstructJob()` noted).

### bare-nesting-detection

**Formerly:** `DEV-04`. **Status:** **RESOLVED**

**Found by.** S04

**Design section.** §3 [nesting-vs-chaining](../docs/backtick-operator-design.md#nesting-vs-chaining); §6 step 6

**What the design said.** Bare nested backtick `x \`f \`g\` h\` y` "naturally produces a parse error" because BacktickIsOperator=false causes the inner backtick to have prec::Unknown, terminating the slot

**What was true.** The greedy-close parse is ambiguous but NOT an error: the parser treats the inner backtick as the close, giving two chained operators `x \`f\` g \`h\` b` = `h(f(x,g),b)` — silently wrong. Detecting this requires lookahead (checking what follows the apparent close backtick) and was deferred.

**Recommended doc change.** **RESOLVED** ([nesting-vs-chaining](../docs/backtick-operator-design.md#nesting-vs-chaining) reframed, design §17.1): not a defect. "Bare nesting" is token-identical to blessed [chaining-associativity](../docs/backtick-operator-design.md#chaining-associativity) chaining, so it cannot and should not be diagnosed; parentheses are required to nest, exactly like ordinary operator grouping. The original "parse error" wording was impossible. A heuristic, off-by-default QoI warning is noted for investigation only.

**Log.** 2026-09-07 — [hygiene-parity](completion/steps/hygiene-parity.md) removed the diagnostic this row's resolution had orphaned. `err_backtick_nested_requires_parens` had been carried since `S04`, was never referenced from anywhere but its own definition in `DiagnosticParseKinds.td`, and could not fire: the input it names is the input [chaining-associativity](../docs/backtick-operator-design.md#chaining-associativity) blesses. §6 item 6 of the design doc, which had listed it as one of three diagnostics to write, now says there are two and why the third was withdrawn. Status unchanged — **RESOLVED**, and now resolved in the source as well as on paper.

### backtick-source-locations

**Formerly:** `DEV-05`. **Status:** **RECONCILED**

**Found by.** S11

**Design section.** §11 phase 2; step S11

**What the design said.** Step says "remembers the two backtick locations" (implies dedicated SourceLocation fields in BacktickInfixExpr)

**What was true.** Backtick source locations are NOT stored separately in BacktickInfixExpr. They are already in the inner CallExpr's LParen/RParen location fields (passed as OpenLoc/CloseLoc to BuildCallExpr). The pretty-printer reconstructs syntax from structure (LHS, callee, RHS), not from source locations. This is sufficient for round-trip and for source ranges.

**Recommended doc change.** **RECONCILED** into §6.4 and §11 phase 2 (locations live in the inner `CallExpr` paren locs; no separate wrapper fields).

**Correction (2026-09-06, [clang-paper-truth](completion/steps/clang-paper-truth.md)).** One clause of *What was true* was false and had been reconciled into §6.4 as written: **"This is sufficient for round-trip and for source ranges."** It is sufficient for the round-trip, which reconstructs the syntax from structure, and it is *not* sufficient for source ranges. The paren locations live on the inner `CallExpr`, whose `getBeginLoc()` comes from its synthesized callee, so the wrapper that forwarded to it reported the operator slot and not the written expression ([backtick-source-range](BACKLOG.md#backtick-source-range)). The wrapper now computes its range from the operands it recovers from the semantic form; §6.4's sentence is corrected and §17.5 gains the paragraph that says how, and says that before this date the section described an intention. The row stays **RECONCILED** — the no-separate-fields finding, which is what it was written for, still holds and is still what §6.4 says.

### wrapper-inner-shape

**Formerly:** `DEV-06`. **Status:** **RECONCILED** — 2026-09-06, [reconcile-remainder](completion/steps/reconcile-remainder.md). Into `docs/backtick-operator-design.md` in two places. **§6, item 4 (Sema)**, the block appended to that item beginning *"What Sema hands back is not always a call, and the phase-2 wrapper must be documented as holding a semantic form"*: the three shapes that reach the wrapper, the accessor that looks through the implicit nodes and **returns null when no call remains**, and — the part this row exists for — the separation of the two claims, *sugar for `op(x, y)`* unaffected and *`-ast-print` round-trips* qualified. **§11 phase 2**, the paragraph beginning *"'Purely additive' is the word this phase got wrong"*, which cites this row alongside [analysis-layer-sites](#analysis-layer-sites) for the same reason: the wrapper is additive in the sense that nothing existing changes, and not additive in the sense the phrase invites.

**Found by.** (maintenance, 2026-08-04)

**Design section.** §6.4; §11 phase 2

**What the design said.** The wrapper wraps "the desugared `CallExpr`", and its pretty-printer reconstructs the surface form from that call's structure (LHS, callee, RHS)

**What was true.** Sema's result is not always a `CallExpr`, so the node carries a *semantic form*, not a call. `MaybeBindToTemporary` wraps a class-typed prvalue with a non-trivial destructor in a `CXXBindTemporaryExpr` and adds a consuming `ImplicitCastExpr` under ARC; a builtin with custom type checking replaces the call outright with a node that is neither a call nor keeps the callee (`` a `__builtin_shufflevector` b `` yields a `ShuffleVectorExpr`). `StmtPrinter` `cast<CallExpr>`'d it and crashed on the first shape; the second is unprintable as backtick syntax at all. Fixed by documenting `Inner` honestly and adding `getCallExpr()`, which looks through the implicit nodes and returns null when no call remains; the printer falls back to the semantic form. Test: `clang/test/Parser/backtick-ast-print.cpp`.

**Recommended doc change.** Reword §6.4 / §11 phase 2: the wrapper holds **whatever Sema built**, and the printer's structural reconstruction is best-effort — correct for every well-formed backtick use whose slot is a real callee, and degraded (prints the desugaring) for a builtin rewrite. The "sugar for `op(x, y)`" thesis is unaffected; what is affected is the claim that round-trip is unconditional.

### analysis-layer-sites

**Formerly:** `DEV-07`. **Status:** **RECONCILED** — 2026-09-06, [reconcile-remainder](completion/steps/reconcile-remainder.md), **at the corrected count of seven**. §17.6 already carried the full account (six modelling sites plus the reporting site, with the rule for a reviewer); what this row asked for and did not have was the note in the *site list*, which is what an implementer reads first. Written as **§6, new item 7**, *"The analysis layer, which no site list contained"* — seven sites, one of them announced and only as a `-Wswitch` warning, pointing at §17.6 for the account — and as the second half of **§11 phase 2**'s *"'Purely additive' is the word this phase got wrong"* paragraph, whose closing sentence is the generalization: **the transparency is what costs, not the node**, and every silent site is silent for exactly that reason. §6's test item gains the diff-against-the-spelled-call-at-more-than-one-configuration line, which is what found all of it. **Count re-derived, not quoted:** `grep -rn BacktickInfixExpr clang/lib/Analysis clang/lib/StaticAnalyzer` on `backtick-trunk` @ `9504b2c1fc51` gives **seven distinct sites in five files** — `CFGBuilder::findConstructionContexts`, `CFGBuilder::Visit`, `CFGBuilder::VisitForTemporaries`, `LiveVariables::LookThroughExpr`, `Environment::ignoreTransparentExprs`, `ExprEngine::Visit`, and `peelOffOuterExpr` in the bug reporter. This row's own *"Recommended doc change"* said **five**; its body listed six; the 2026-09-06 note said seven. Seven is right.

**Found by.** (maintenance, 2026-08-04)

**Design section.** §11 phase 2 ("purely additive"); §6.4 site list

**What the design said.** Phase 2 is a "thin transparent AST wrapper … purely additive"; the S11 site list covers AST, Sema, CodeGen, serialization and the exhaustive `StmtClass` switches

**What was true.** A new `Expr` node also has obligations in the **Analysis / StaticAnalyzer** layer, and nothing in the toolchain forces them. `ExprEngine::Visit`'s missing case (a `-Wswitch` warning only, and `LLVM_ENABLE_WERROR` is OFF) meant the path was dropped without a successor, so **the whole enclosing function went unanalyzed** — `core.NullDereference` missed a bug through a backtick call that it catches through the same call written normally. Three more sites were silent: `CFGBuilder::Visit` (wrapper became a CFG element of its own), `findConstructionContexts` (construction-context chain broke, so a lifetime-extended temporary was modelled as an ordinary one), `VisitForTemporaries` (dropped `ExternallyDestructed`, giving a *double* destructor in the CFG), plus `LiveVariables::LookThroughExpr` (liveness keyed on the wrapper while the binding was keyed on the call, so every backtick result read back as unknown) and `Environment::ignoreTransparentExprs`. Fixed on both branches; test `clang/test/Analysis/backtick-infix.cpp`.

**Recommended doc change.** Add an implementation-experience note to §6/§11: a transparent front-end wrapper is *not* free — it costs five analysis-layer sites that the compiler will not tell you about, and getting them wrong silently disables the static analyzer rather than failing a build. This is the backtick counterpart of the Unicode track's "6 link / 8 unreachable / 1 warning / 13 silence" accounting ([expression-node-cost](unicode-operators/clang/DEVIATIONS.md#expression-node-cost)) and belongs in the same paragraph.

**Note, 2026-09-06 ([null-return-suppression](completion/steps/null-return-suppression.md)) — the count is seven, not six, and the seventh is in a different layer.** `Status:` is untouched; this row is still [reconcile-remainder](completion/steps/reconcile-remainder.md)'s to reconcile, and what changes is the number it should carry. The six sites above are all *modelling* sites, and meeting them is what creates the seventh: a node the CFG is taught to look through has no program point in the exploded graph, so the bug reporter's `Tracker::track` — which calls `peelOffOuterExpr` and then `findNodeForExpression` — finds no node and abandons the whole tracking chain, taking the default `suppress-null-return-paths` and every explanatory note with it. Nothing forces it: no `-Wswitch` warning, no link error, no crash, no failing test, so it is *below* even the one warned-about site in this row's accounting. Both features carried it from their first analyzer pass; fixed on all four Clang branches, with the rule stated for a paper in `docs/backtick-operator-design.md` **§17.6**.

### type-slot-cost

**Formerly:** `DEV-08`. **Status:** **RECONCILED** — 2026-09-06, [reconcile-remainder](completion/steps/reconcile-remainder.md). Into `docs/backtick-operator-design.md` in three places. **§17.3** is rewritten around the correction: the paragraph beginning *"This was recorded as a consequence rather than a rule, and that is wrong as grammar"* (a bare type-name is not an *assignment-expression*, so the "consequence" contradicted the proposal's own grammar while a normative example depended on it, and the first implementation rejected all four shapes with three different diagnostics); the paragraph beginning *"Stated correctly, it is a deliberate second production with a disambiguation rule"*; and the paragraph beginning *"And it is not free, which is the point of recording the price"*, which carries the measured cost — two grammar productions, one ~70-line parser routine, a parsed type threaded beside the slot's expression result, one Sema overload, two printer arms, no AST change — and closes on the general lesson, that a consequence which contradicts the grammar is not a consequence. **[type-name-slot](../docs/backtick-operator-design.md#type-name-slot)**'s **Why** is reworded and its old clause **struck in place** in a new dated `Log.`, so the record of what was believed survives without being quotable as fact. **§6 gains item 9** pointing at §17.3, so the site list stops implying the slot is free. `papers/backtick-infix-and-keyword-escape.md` already said *"not a blessed consequence"* and needed no change — checked, not assumed.

**Found by.** BL02

**Design section.** §3 [type-name-slot](../docs/backtick-operator-design.md#type-name-slot); §17.3; paper `[expr.backtick]` grammar

**What the design said.** [type-name-slot](../docs/backtick-operator-design.md#type-name-slot) is "blessed as a consequence, not a special rule": the slot is any callable expression, a type-name is callable, so `` x `T` y `` == `T(x, y)` falls out for free

**What was true.** It does not fall out. A bare type-name is not an *assignment-expression*, so the "consequence" contradicted the proposal's own grammar (`backtick-operator: assignment-expression` vs. the normative `r7` example `` a `std::pair` b ``), and the implementation rejected all four type-slot shapes (bare class, class template, qualified, builtin) with three different diagnostics. Delivering [type-name-slot](../docs/backtick-operator-design.md#type-name-slot) cost: **two grammar productions plus a lookup-based disambiguation paragraph in the paper**; **one parser routine** (`Parser::TryParseBacktickTypeSlot`, ~70 lines: slot-local pre-annotation mirroring the expression parser's trigger set, a `getTypeName` probe for bare identifiers — whose deduction-context default is also what makes CTAD work, no separate template arm needed — a tentative-parse probe for qualified template-names, and the functional-cast `DeclSpec` arm for builtins/annotated types); **a `ParsedType` threaded beside the slot's `ExprResult`**; **a Sema overload** routing to `ActOnCXXTypeConstructExpr` (CTAD, temporaries, and dependent construction inherited); and **two printer arms** (`CXXTemporaryObjectExpr`, `CXXUnresolvedConstructExpr`) to keep `-ast-print` round-tripping. No AST change: F23's `getCallExpr()` contract already tolerated a non-call inner. Full parity with the spelled form verified, including `` 1 `int` 2 `` failing with exactly `int(1, 2)`'s diagnostic and a function hiding a same-named class resolving to the call.

**Recommended doc change.** Reword [type-name-slot](../docs/backtick-operator-design.md#type-name-slot)/§17.3: "blessed as a consequence" is wrong *as grammar* — the type slot is a deliberate second production with a disambiguation rule (the type interpretation wins exactly when lookup finds a type or class template), not a freebie. Quote the measured cost (1 parser routine, 1 Sema overload, 2 printer arms, 2 grammar productions) in the implementation-experience section; "consequences" of a design are not free.

### cir-backtick-arms

**Formerly:** `DEV-09`. **Status:** **RECONCILED** — 2026-09-06, [reconcile-remainder](completion/steps/reconcile-remainder.md). Both halves. The site-list half is **§6, new item 8**, *"The code generator"*: four arms, four *unlike* failure modes, the l-value default arm that asserts rather than diagnoses (so `` (b `at` 1) = 42 `` crashed the compiler), and the one arm that is not a copy-paste, with the reason — a call returning a reference is a call returning a reference. The argument half is a **new §17.7**, *"The two features diverge in the front end and converge in the back end"*, whose middle paragraph is the cross-compiler note this row calls out: the same four arms in the same four files with the same failure modes for both features, and instruction-for-instruction identical generated code, **in contrast to the AST work** where [expression-node-cost](unicode-operators/clang/DEVIATIONS.md#expression-node-cost) found the Unicode wrapper strictly more expensive. Its closing paragraph is the one the row asks the paper to make: the front end is where two sugars for a call can cost different amounts, and the back end is where they provably cannot. The upstream observation is kept separate, in that section's last paragraph, as an upstream defect rather than a feature one. **Re-derived:** four arms in four files on `backtick-trunk`, and `UserOperatorExpr` on `unicode-operators-upstream` occupies the same four files at the same four places — the symmetry is in the tree, not only in the ledger.

**Found by.** BL04

**Design section.** §6 (the Clang implementation plan's site list); §17

**What the design said.** The design's Clang site list, and [`clangir-backtick-arms`](BACKLOG.md#clangir-backtick-arms) behind it, treat ClangIR as an open question of the same shape as the Unicode track's [`clangir-unicode-arms`](BACKLOG.md#clangir-unicode-arms) — a code generator nobody had built, whose worst case was assumed to be a hard `Not Yet Implemented` diagnostic.

**What was true.** **`BacktickInfixExpr` needs four ClangIR arms, and one of the four fallbacks is an abort rather than a diagnostic.** Measured by compiling `clang/lib/CIR/` for the first time (`mlir` + `CLANG_ENABLE_CIR=ON`). Scalar and aggregate emit `errorNYI` naming the node; complex emits `errorUnsupported` (`"cannot compile this complex expression yet"`) which does **not** name it; and `emitLValue` falls to a default arm that returns a default-constructed `LValue`, whose null `QualType` then asserts — so `` (b `at` 1) = 42 `` **crashed the compiler**. `UserOperatorExpr` behaves identically at every one of the four, which is what shows the crash belongs to `emitLValue`'s default arm and not to either wrapper. The fix is three copy-paste arms using `getSubExpr()` plus one that is *not* a copy: `emitLValue` recurses into the sub-expression instead of diagnosing, because a backtick call returning a reference is a call returning a reference and the `CallExpr` classes above already handle it. **The cross-compiler note worth carrying:** this is a place where the two features cost exactly the same — four arms each, same sites, same order, same failure modes — in contrast to the AST-node work, where [expression-node-cost](unicode-operators/clang/DEVIATIONS.md#expression-node-cost) found the Unicode wrapper strictly more expensive because it cannot be transparent to `TreeTransform`. Code generation sees only the desugared call, so the asymmetry disappears at exactly the point the design predicts it should.

**Recommended doc change.** Add the code generator to §6's site list with the two-column shape above, and state the symmetry in §17: the backtick wrapper and the Unicode wrapper diverge in the front end and converge in the back end, which is the design's own claim about where the sugar stops mattering. Note separately, as an upstream observation rather than a feature one, that `CIRGenFunction::emitLValue`'s default arm turns any unhandled l-value class into an assertion failure.

### keyword-escape-printing

**Status:** **RECONCILED**

**Found by.** [clang-paper-truth](completion/steps/clang-paper-truth.md)

**Design section.** §12; §3 [keyword-escape-coexistence](../docs/backtick-operator-design.md#keyword-escape-coexistence)

**What the design said.** The keyword escape "does all of its work in the parser and none anywhere else" — it yields an ordinary identifier, and lookup, mangling, linkage and ABI are unchanged, so the feature is "purely source-level". §12 named no consequence for printing at all.

**What was true.** **Purely source-level is exactly why printing is not free.** The name the escape yields is an ordinary identifier whose *spelling* is a keyword, and nothing in the AST remembers that it was written with backticks — so every printer that emits source has to put them back or it emits text that does not re-parse. `` void `new`(); `` printed as `void new();`. Fixing it is not a guard on one site:

- `DeclarationName::print`'s `Identifier` arm is the site that decides, and it is the **diagnostic** path as well as the printing path. That is what makes it a decision rather than a fix; it is recorded as [keyword-escape-printing](../docs/backtick-operator-design.md#keyword-escape-printing).
- Three declarator printers in `DeclPrinter` (`VisitTypedefDecl`, `VisitFieldDecl`, `VisitVarDecl`, the last covering parameters) never reach it: they hand the name to the **type** printer as a placeholder `StringRef` taken from `NamedDecl::getName()`. A field `` int `delete`; `` printed bare while the function beside it printed escaped.
- `StmtPrinter::VisitMemberExpr` prints through `operator<<(raw_ostream&, DeclarationNameInfo)`, which constructs a default `PrintingPolicy` and so carries none.
- The diagnostic surface was **internally split** before anything was changed, and upstream owns the split: `ak_declarationname` prints through the policy-free stream operator, while `ak_nameddecl` beside it uses `ASTContext::getPrintingPolicy()`. So *"redefinition of X"* and *"no matching function for call to X"* would have disagreed about the same name.
- `TextNodeDumper::VisitMemberExpr` had the mirror-image problem: it prints `*getMemberDecl()`, and `operator<<(raw_ostream&, const NamedDecl&)` *does* take the context's policy, so `-ast-dump` would have escaped member names while printing every other name bare through `VisitNamedDecl`'s policy-free path.

**Recommended doc change.** **RECONCILED** into `docs/backtick-operator-design.md` in three places, on the same day the defect was fixed. §3 gains the decision entry [keyword-escape-printing](../docs/backtick-operator-design.md#keyword-escape-printing) — the whole entry, whose **Why** is the argument for escaping in diagnostics too and whose **Log** lists the sites. §12 gains the **Printing and diagnostics** paragraph, immediately before **Costs.**, which states the rule in two sentences and says why `-ast-dump` goes the other way. The **Costs.** paragraph after it is left as it stands: the printing sites are a cost of the *escape*, and the sentence there already says "tooling must distinguish the two uses" — but a reader who wants the tally now has the decision entry's Log to go to.
### clang-slot-adl

**Formerly:** none — new slug, 2026-09-06. **Status:** **FIXED and RECONCILED**

**Found by.** [evidence-debt](completion/steps/evidence-debt.md), while writing [template-ast-print-test](BACKLOG.md#template-ast-print-test)'s template round-trip test

**Design section.** [§17.4 ADL is normative](../docs/backtick-operator-design.md#174-adl-is-normative-cross-compiler-note); §6 (the Clang plan)

**What the design said.** §17.4 is normative — *"`x `f` y` performs argument-dependent lookup on the slot exactly as the call `f(x, y)` would … backtick must not silently have weaker lookup than the call it desugars to"* — and its implementation-status paragraph reports the rule as delivered: *"**both compilers now deliver it, and they agree.** Clang carries the slot to `BuildCallExpr` as an `UnresolvedLookupExpr`."*

**What was true.** **Clang has never done ADL on the slot, and the failure is silent in the shape that matters most.** The claim was written from the shape of the code rather than from a measurement, and no test on the backtick track has ever exercised pure ADL: `clang/test/SemaCXX/backtick-semantics.cpp` §2 is headed *"Qualified callee (also exercises the ADL-adjacent case)"* and uses `` tx `ns::g` ty `` — a **qualified** name, which correctly gets no ADL either way, so it passes whatever the slot does. Measured on `backtick-trunk`, and reproduced on `backtick-23`, always against the spelled call as the control:

| Shape | `f(x, y)` | `` x `f` y `` |
|---|---|---|
| Hidden friend (`struct S { friend int hf(S, S); };`) | binds `hf` | **error:** *use of undeclared identifier 'hf'* |
| ADL-only namespace member | binds it | **error**, plus a typo-correction note offering the qualified name |
| Augmentation: `::pick(double, double)` visible, `ns::pick(U, U)` reachable by ADL | binds **`ns::pick(U, U)`** | binds **`::pick(double, double)`** — **no diagnostic** |
| Same, with an overload *set* visible rather than one function | binds `ns::pick(U, U)` | binds `::pick(double, double)` — no diagnostic |
| Inside a template, name visible at definition, ADL candidate declared after it | ADL at the point of instantiation, binds the ADL candidate | slot bound at *definition* time to the visible one; instantiation then fails with *no viable conversion* |

**The third and fourth rows are the serious ones: the operator form calls a different function from the call it is defined to be sugar for, and says nothing.**

**The cause is one line, and it is the same one GCC had.** `Parser::ParseRHSOfBinaryExpression` parses the slot with `BacktickOp = ParseExpression()` (`clang/lib/Parse/ParseExpr.cpp`), so a bare identifier reaches `Sema::ActOnIdExpression` with `HasTrailingLParen = false`. `Sema::UseArgumentDependentLookup` (`SemaExpr.cpp:3269`) opens with `if (!HasTrailingLParen) return false;` — ADL is off before any other test runs — and an empty lookup with no trailing `(` goes to `DiagnoseEmptyLookup` rather than to an ADL-enabled `UnresolvedLookupExpr`. By the time `Sema::ActOnBacktickOperator` hands `Op` to `BuildCallExpr`, the name is already resolved. This is [gcc-slot-adl](gcc/DEVIATIONS.md#gcc-slot-adl) *verbatim* — "the backtick slot was parsed as a standalone assignment-expression … the slot arrived as a resolved `FUNCTION_DECL`" — on the compiler that ledger row records as the one already getting it right.

**The control that makes this a design finding and not just a bug.** The **Unicode** feature, in the same compiler and on the same machine, is correct: `s ⊞ s` finds a hidden friend, and `u ⊞ u` picks the ADL candidate over a visible `operator⊞(double, double)`. Its slot never becomes an expression — `Sema::CreateOverloadedUserOp` does its own `LookupOperatorName` and hands an unresolved set to candidate assembly ([infix-parse-cost](unicode-operators/clang/DEVIATIONS.md#infix-parse-cost) measured exactly this). **Two features, one compiler, one difference: whether the slot reaches the call builder unresolved.** That is the same sentence §17.4 already draws from GCC's two attempts, now with a within-compiler control.

**Recommended doc change, and the fix it implies.** **Option 1 was taken: fixed, on both backtick branches, and §17.4 keeps its claim.**
[clang-slot-adl](completion/steps/clang-slot-adl.md), 2026-09-06.

*The fix.* `Parser::TryParseBacktickCalleeSlot` (`clang/lib/Parse/ParseExpr.cpp`), a sibling of the `TryParseBacktickTypeSlot` arm [type-name-slot](../docs/backtick-operator-design.md#type-name-slot) already put in the slot, parses a bare unqualified name — a plain identifier or a template-id over one — and builds it with `Sema::ActOnIdExpression(..., HasTrailingLParen=true)`, so it reaches `BuildCallExpr` as an `UnresolvedLookupExpr`. In the slot the closing backtick *is* the trailing `(`. Anything else falls through to `ParseExpression` with the token stream untouched, which is the right answer for a qualified name, a member access, a callable object or a function pointer: the equivalent call gets no ADL either. **Both unqualified forms were done in one pass** on the strength of [gcc-template-id-slot-adl](gcc/DEVIATIONS.md#gcc-template-id-slot-adl), whose whole content is that fixing only the bare identifier leaves the template-id silently on the old path.

*Where it landed in the design.* [§17.4](../docs/backtick-operator-design.md#174-adl-is-normative-cross-compiler-note), the implementation-status paragraph and the three paragraphs now following it — **RECONCILED**. The status-correction block [evidence-debt](completion/steps/evidence-debt.md) put above that paragraph is **removed**; it existed only to keep the paragraph out of a paper. The rewritten paragraph names both compilers' mechanisms; the paragraph after it says both got there on a second attempt and that the two failures were the same failure; the paragraph after **that** is the within-compiler control, written for a paper to take; and the last one is the near-miss — the qualified-name test that made this invisible for nine steps, and the augmentation shape that is the only one which fails *silently* and therefore the only one worth calling an ADL test.

*The test.* `clang/test/SemaCXX/backtick-adl.cpp`, on both backtick branches: eight sections, every shape written twice — once as a spelled call, once as the operator, with the call as the control — including the two augmentation sections whose pre-fix failure is a **wrong bind rather than a compile error**. `clang/test/SemaCXX/backtick-semantics.cpp`'s prolog and section-2 heading, which both claimed ADL coverage they never had, are corrected to say so and to point at the new file.

### escape-name-positions

**Formerly:** none — new slug, 2026-09-07. **Status:** **ANSWERED, FIXED and RECONCILED**

**Found by.** [backtick-paper](completion/steps/backtick-paper.md), checking the paper's proposed wording against both prototypes.

**Design section.** [§12 Coexistence with backtick keyword-escaped identifiers](../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers); §3 [keyword-escape-coexistence](../docs/backtick-operator-design.md#keyword-escape-coexistence), whose Status already reads *scope open*.

**What the design said.** §12 lists the escape's positions as *operand / primary-expression / declarator-id / after `.` `->` `::`*, and says nothing about the rest of the grammar. `papers/backtick-infix-and-keyword-escape.md`'s [lex.name] wording is broader than that list — *"An escaped-identifier may appear wherever the grammar uses identifier as a terminal"* — and its example declares `` struct `union` { }; ``.

**What was true.** Measured 2026-09-07 on the built `backtick-trunk` `clang++` and on `cc1plus` from `~/bld/gcc/gcc-backtick-build`, one probe per position, flag on:

| Position | Clang | GCC |
|---|---|---|
| variable, function, member, `typedef` declarator-id | accepts | accepts |
| qualified name in an out-of-class member definition | accepts | accepts |
| primary-expression, and after `.` | accepts | accepts |
| *class-head-name* (`` struct `union` { }; ``) | **rejects** — *declaration of anonymous struct must be a definition* | **rejects** — *expected identifier before '`' token* |
| *enum-name*, scoped or not | **rejects** | **rejects** |
| *namespace-name* | **rejects** | **rejects** |
| template parameter name | **rejects** | **rejects** |
| name in an *alias-declaration* (`` using `class` = int; ``) | **accepts** | **rejects** — see [escape-alias-name-parity](gcc/DEVIATIONS.md#escape-alias-name-parity) |

So the two implementations agree on the escape's coverage everywhere except the alias-declaration, and the coverage they agree on is **narrower than the wording the paper proposes**. The wording's own example is in the unimplemented set.

**Corrected and extended, 2026-09-07** by [settle-paper-rows](completion/steps/settle-paper-rows.md), which probed **nineteen** positions rather than eight. Two of the table's readings were incomplete. Both compilers also accept the escape in a `friend` declaration's name, in a **non-type** template parameter name and in a *using-declaration* name — none of them in §12's list. Both also reject it in an *enumerator* name, a *mem-initializer* name and a label. And the divergence is **three** positions, not one: Clang alone accepts an *alias-declaration* name, an *alias-template* name and a *concept* name ([escape-alias-name-parity](gcc/DEVIATIONS.md#escape-alias-name-parity)). The full table is in §12. **The finding is that the boundary was never decided**: every position either compiler accepts is one whose name it parses through the routine the escape arm was written into, and every position it rejects reads a bare identifier token somewhere else. That is why a *concept* name is in and a *class-head-name* is out.

**Recommended doc change.** Two questions, and only the first is a defect. (1) §12's position list should say that it is the *implemented* list and that the unimplemented positions are unwritten parser arms, not decisions — nothing in the disambiguation argument turns on them, since a *class-head-name* is a name position exactly as a declarator-id is. (2) The design owes an answer to *what should the escape's coverage be?* An escape hatch whose point is that a future keyword stops breaking code has to cover the positions in which the broken code names things, and `struct module { };` is one of them. Until that is answered, the paper states the implemented set, which [backtick-paper](completion/steps/backtick-paper.md) has done in its *What is implemented, and what is not* section, and keeps the broad wording as the proposal.

**Half reconciled, half the author's, 2026-09-07.** The defect half is **RECONCILED into [§12](../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers)** — the paragraph headed *"Which positions are implemented — a measurement, not a decision, and that is the finding"* and the nineteen-row table under it, which replaces the eight-row one. The scope half is **the author's and stays OPEN**: the question, four options and what each costs in each compiler are written up as [escape-name-positions](../docs/open-decisions.md#escape-name-positions), the sixth question on that page and the only backtick-side one. [keyword-escape-coexistence](../docs/backtick-operator-design.md#keyword-escape-coexistence)'s Log points at it. **Do not read the §12 reconciliation as an answer** — it records what is implemented, not what should be.

**Answered 2026-09-07; built and reconciled 2026-09-08.** The author answered [escape-name-positions](../docs/open-decisions.md#escape-name-positions) **(c)** — implement the broad set in both compilers — and struck the recommendation's transitional half, because there is no shipped implementation but a GitHub fork and nothing is relying on it. [escape-name-positions](completion/steps/escape-name-positions.md) built it: all nineteen positions are accepted by both compilers, `` struct `union` { }; `` compiles, and [escape-alias-name-parity](gcc/DEVIATIONS.md#escape-alias-name-parity) closed with it out of the same GCC arm, exactly as the brief said it would.

**Two things the brief could not have known, both found by measuring rather than by reading, and both of them cost about as much as the priced work.** (1) **Declaring a name is half a hatch.** The nineteen positions were all *declarations*; taking `` struct `union` { }; `` without `` `union` u; `` delivers a type nothing can name. Fifteen more programs probe the *use* positions — a decl-specifier, a base-specifier, a nested-name-specifier including a *middle* component of one, a template-name being specialized, a using-directive, a type-constraint, a constructor's name — and both compilers now take all fifteen. (2) **A new name position is a new printing surface.** `-ast-print` round-tripping is a paper claim, and enum names, namespace names, template parameter names, labels and nested-name-specifiers all printed the keyword bare, because they reach an identifier without going through `DeclarationName::print` — and because `operator<<(raw_ostream &, DeclarationName)` builds a *default* printing policy, in which the escape is off.

**Reconciled into** [§12](../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers) — the paragraph headed *"Which positions the escape reaches — decided 2026-09-07, and built"*, the seventeen-row table under it, the *"Declaring a name is half a hatch"* paragraph and the *"What it cost, and where the cost is"* paragraph — and into §3 [keyword-escape-coexistence](../docs/backtick-operator-design.md#keyword-escape-coexistence)'s `Log.`, whose Status stops saying *scope open* after eleven weeks.


### type-slot-aggregate-shape

**Formerly:** none — new slug, 2026-09-07. **Status:** **FIXED and RECONCILED**

**Found by.** [backtick-paper](completion/steps/backtick-paper.md), checking the paper's round-trip claim.

**Design section.** [§17.5](../docs/backtick-operator-design.md#175-source-ranges-of-the-desugared-node-source-fidelity-node); [§17.3](../docs/backtick-operator-design.md#173-type-name-in-the-operator-slot-type-name-slot); [type-slot-cost](#type-slot-cost)

**What the design said.** §17.5: *"Three shapes have to be recognised, and they are the same three the pretty-printer already reconstructs the surface syntax from: the desugared call (including the member form), the construction a type slot desugars to, and that construction's dependent form."* §17.3 says the type slot cost *"two printer arms to keep `-ast-print` round-tripping"*.

**What was true.** There is a fourth shape, and both the printer and the range recovery miss it. A type slot naming an **aggregate** initializes through parenthesized aggregate initialization (C++20), so Sema hands back a `CXXFunctionalCastExpr` rather than a `CXXTemporaryObjectExpr`. Measured on `backtick-trunk`:

```
struct Agg { int x, y; };
int a, b;
auto r = a `Agg` b;

$ clang++ -fbacktick -Xclang -ast-print   ->  auto r = Agg(a, b);          // not the written form
$ clang++ -fbacktick -Xclang -ast-dump    ->  BacktickInfixExpr <col:13, col:16> 'Agg'
                                              `-CXXFunctionalCastExpr ...   // the slot alone, not <col:10, col:18>
```

A type slot naming a class with a constructor round-trips correctly (`` a `Pt` b ``), and so does a CTAD slot, which prints its deduced specialization (`` a `std::pair<int, double>` b ``) — re-parseable and equivalent, though not the written token sequence.

**Recommended doc change.** §17.5's *three shapes* becomes four, and the fourth is the honest general statement of the trap the section already makes: the wrapper's range and the printer both recover the operands from **whatever Sema built**, so every new initialization form Sema can produce for `T(x, y)` is another arm, and each one fails quietly by printing the desugaring. §17.3's *"two printer arms"* is the count for the shapes it implemented, not for the shapes the type slot can produce.

**Fixed and reconciled** by [settle-paper-rows](completion/steps/settle-paper-rows.md), 2026-09-07, on `backtick-trunk` and `backtick-23`. One arm in `BacktickInfixExpr::getOperand` (`clang/lib/AST/Expr.cpp`) and one in `StmtPrinter::VisitBacktickInfixExpr`, both matching `CXXFunctionalCastExpr` over `CXXParenListInitExpr` and taking the **user-specified** initializers, because the full list carries defaulted members beyond the two operands. The type is printed from the semantic node as the constructor arm prints it, so CTAD keeps one stated exception rather than two adjacent arms answering the same question two ways. Cases added to `clang/test/Parser/backtick-infix.cpp` (the range, as literal columns) and `clang/test/Parser/backtick-ast-print.cpp` (the printing, whose second RUN line re-parses what it printed); both files are now pinned to `-std=c++20`, since parenthesized aggregate initialization is C++20 and neither pinned a standard. **Reconciled into [§17.5](../docs/backtick-operator-design.md#175-source-ranges-of-the-desugared-node-source-fidelity-node)** — the paragraph beginning *"Three was the count of the shapes that had been recognised"*, and the general-statement paragraph after it — **and into [§17.3](../docs/backtick-operator-design.md#173-type-name-in-the-operator-slot-type-name-slot)**, the cost paragraph, whose *"two printer arms"* is now three.

**One thing the row understated.** The pre-fix behaviour was not only less faithful, it was *wrong* for the CTAD aggregate: `` a `aggT` b `` printed `(aggT<int>)(3, 4)`, a cast applied to a comma expression, which is a different program. Measured on the pre-fix `backtick-23` binary before the cherry-pick.

### slot-callable-shape

**Formerly:** none — new slug, 2026-09-08. **Status:** **FIXED and RECONCILED**

**Found by.** The Phase J review pass of [`papers/backtick-infix-and-keyword-escape.md`](../papers/backtick-infix-and-keyword-escape.md), re-deriving the round-trip claim against the built compilers — the same route that opened [type-slot-aggregate-shape](#type-slot-aggregate-shape), one shape earlier.

**Design section.** [§17.5](../docs/backtick-operator-design.md#175-source-ranges-of-the-desugared-node-source-fidelity-node); [§17.3](../docs/backtick-operator-design.md#173-type-name-in-the-operator-slot-type-name-slot)

**What the design said.** §17.5 named **four** inner shapes and framed the trap as an *initialization* problem: *"every initialization form Sema can produce for `T(x, y)` is another arm."* All four are reached through `BacktickInfixExpr::getCallExpr()` or through the type slot's construction node, and the first of them — the generic call — reads `getArg(0)`, `getCallee()`, `getArg(1)`.

**What was true.** There is a fifth shape, and it is not an initialization form at all: it is the ordinary call, *re-keyed*. A slot whose **value** is a class-typed callable — a lambda, a named function object, a `std::function`, `std::plus<int>{}`, a data member holding a functor — is called through the object's `operator()`, and Sema builds a `CXXOperatorCallExpr` with `getOperator() == OO_Call` whose argument 0 is the **slot object** and whose arguments 1 and 2 are the two operands. `CXXOperatorCallExpr` **is a** `CallExpr`, so the generic arm accepted it and read the slot as the left operand, the implicit `operator()` reference as the slot, and the left operand as the right one — never reading argument 2. Measured on `backtick-trunk` at `bd8790f9d0ef` and `backtick-23` at `49ca42d1fab7`, identically:

```
struct Obj { int operator()(int,int) const; };
Obj obj;
int b(int L,int R){ return L `obj` R; }

-ast-print   ->  obj `operator()` L                     // R gone; a different program
-ast-dump    ->  BacktickInfixExpr <col:31, col:28>     // end before begin
```

**The reach is why it mattered.** The paper's motivation helpers — `pipe`, `then`, `mbind`, `implies` — are every one of them `inline constexpr auto` lambdas, so the paper's headline examples were exactly the broken case: `` x `pipe` inc `pipe` dbl `` printed as `` pipe `operator()` pipe `operator()` x ``.

**Which half was silent.** The printing half was **not** silent, and that is a correction to §17.5's own general statement: the printed text names `operator()` as a free function, which unqualified lookup does not find, so the printed program does not compile and the `-ast-print` re-parse RUN line catches it — the file simply had no case of this shape. The **range** half was silent, and inverted, because nothing re-checks a source range but the literal columns a test pins.

**Fixed and reconciled** by [slot-callable-printing](completion/steps/slot-callable-printing.md), 2026-09-08, on `backtick-trunk` (`28b685c86ea2`) and `backtick-23` (`8d003dd45c52`). One arm in `BacktickInfixExpr::getOperand` (`clang/lib/AST/Expr.cpp`) and one in `StmtPrinter::VisitBacktickInfixExpr` (`clang/lib/AST/StmtPrinter.cpp`), both **ahead of** the generic `CallExpr` arm and both guarded on `getOperator() == OO_Call && getNumArgs() >= 3`: the slot is argument 0, the operands are arguments 1 and 2. Cases added to three files that already existed, so no lit count moves: `clang/test/Parser/backtick-ast-print.cpp` (six shapes, of which five printed wrong before), `clang/test/Parser/backtick-infix.cpp` (the range, as literal columns) and `clang/test/AST/backtick-template-print.cpp` (the substituted form, which only ever failed in the *instantiation*, since the pattern's inner node is an ordinary dependent `CallExpr`). **Reconciled into [§17.5](../docs/backtick-operator-design.md#175-source-ranges-of-the-desugared-node-source-fidelity-node)** — *four shapes* is now five, and the general statement now says a call can be re-keyed as well as an initialization multiplied — **and into [§17.3](../docs/backtick-operator-design.md#173-type-name-in-the-operator-slot-type-name-slot)**, whose *three printer arms* is a count of the **type slot's** arms and is unchanged by this row, which now says so explicitly rather than leaving the reader to compare it against §17.5's total.

**The boundary, pinned rather than assumed.** A callable used through its *conversion to a function pointer* — a surrogate call — is **not** re-keyed: Sema builds a plain `CallExpr` whose callee is the converted object, so the generic arm already printed it correctly. That case is in the test file so that the line between the two arms is a test rather than a recollection.

**No GCC change, confirmed rather than assumed.** GCC desugars in the parser and has no pretty-printer for the form, so there is nothing on that side to get wrong. All six shapes are accepted by `cc1plus -fbacktick` before and after.

### escape-in-qualified-type-name

**Formerly:** none — new slug, 2026-09-08. **Status:** **FIXED and RECONCILED**

**Found by.** [escape-positions-forward-port](completion/handoffs/escape-positions-forward-port.handoff.md),
probing the escape's new coverage on the merged Unicode branch. **It is not
the merge's**: every program below behaves byte-identically on
`backtick-trunk`'s own binary, so it is on both backtick branches and predates
the forward-port. It was found because the merge re-ran a probe sweep, which is
the third time that habit has caught something.

**Design section.** [§12](../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers);
[§17.8](../docs/backtick-operator-design.md#178-which-of-this-is-clangs-alone-and-why);
[escape-name-positions](#escape-name-positions)

**What the design said.** §12, since
[escape-name-positions](../docs/open-decisions.md#escape-name-positions) was
answered (c) and built: *"an escaped-identifier may appear wherever the grammar
uses `identifier` as a terminal. Both prototypes now do that."* The position
table is all *accepts / accepts*. §17.8: the places the two implementations
genuinely disagree are *"two kinds again, and both are one-liners"*, and both
of those are Clang accepting what GCC refuses.

**What was true.** **A qualified *type-specifier* is a third kind, and it runs
the other way — Clang refuses what GCC takes.** Measured on the merged branch's
`clang` and on `cc1plus` from `gcc-backtick-build`, `-std=c++20 -fbacktick
-fsyntax-only`, one program per line:

| Program | Clang | GCC |
|---|---|---|
| `` struct `union` { struct S { int a; }; }; `union`::S g; `` | accepts | accepts |
| `` struct `union` { struct S { int a; }; }; int f() { `union`::S s; …} `` | accepts | accepts |
| `` namespace `namespace` { struct S{int a;}; } `namespace`::S g; `` | accepts | accepts |
| `` namespace `namespace` { struct S{int a;}; } int f() { `namespace`::S s{1}; …} `` | **rejects** — *expected '(' for function-style cast or type construction* | accepts |
| `` namespace N { struct `union` { int a; }; } N::`union` g; `` | **rejects** — *expected a type* | accepts |
| `` namespace N { struct `union` { int a; }; } using X = N::`union`; `` | **rejects** — *expected a type* | accepts |
| `` namespace N { struct `union` { int a; }; } int f() { return sizeof(N::`union`); } `` | **rejects** — *expected a type* | accepts |
| `` namespace N { int `new` = 1; } int f() { return N::`new`; } `` | accepts | accepts |

**Two Clang sites, one shape.** The escape is reached in a qualified name only
where the name is read as an *unqualified-id* — which is why the last row, an
expression, works and the type-specifier rows do not.

- **The final component of a qualified type-name.** After
  `ParseOptionalCXXScopeSpecifier` has taken `N::`, the type name is read by
  the decl-specifier path rather than by `ParseUnqualifiedId`, and that path
  has no `tok::backtick` arm, so `` N::`union` `` is *expected a type*
  wherever a type-specifier is wanted — a declaration, an
  *alias-declaration*, a `sizeof`.
- **A leading escape naming a *namespace*, at block scope.**
  `isCXXDeclarationSpecifier`'s `tok::backtick` arm — which
  [escape-name-positions](#escape-name-positions) wrote deliberately as a
  predicate that asks Sema rather than consuming — answers with
  `Actions.getTypeName` on the escaped keyword. A namespace name is not a
  type, so it answers *not a declaration* and the statement is parsed as an
  expression. At namespace scope, where no tentative parse runs, the same
  declaration is accepted.

**Recommended doc change.** Two things, and the first is the defect. (1) §12's
*"wherever the grammar uses `identifier` as a terminal"* is the rule the author
chose and the prototypes do not yet meet it: the seventeen-row table probed
*declaration* positions and the fifteen use-position programs probed the
*qualifier* half of a nested-name-specifier, never the qualified type-name. §12
should either gain the two arms or say that the qualified type-specifier is the
one position still unreached, and that it is a missing parser arm rather than a
decision — nothing in the disambiguation rule turns on it. (2) §17.8's *"two
kinds, and both are one-liners"* is **three**, and this one is the only
divergence in which **GCC is the wider implementation and Clang the narrower**;
GCC needs nothing, because `cp_parser_identifier` is where a qualified
type-name reads its `CPP_NAME` too — the one-arm reach
[escape-name-positions](#escape-name-positions) recorded.

**Fixed** by [escape-name-sweep](completion/steps/escape-name-sweep.md),
2026-09-08, on both backtick branches. **The row understated it by three
times.** Re-derived from twenty-five programs rather than eight, Clang
refused **twelve**, not four: every shape in which a qualified name ends in a
*type* — a declaration, an *alias-declaration*, a `sizeof`, a block-scope
declaration, a parameter, a return type, a `new` expression, a template
argument, a `static_cast`, a dependent `typename`, and both halves escaped —
plus the leading escaped namespace at block scope. Four qualified type shapes
already worked and say why the others did not: an
*elaborated-type-specifier*, a base-specifier, a mem-initializer's base and a
*middle* nested-name-specifier component all go through parsers
[escape-name-positions](#escape-name-positions) had already taught.

**Four Clang sites, and the row's "two sites, one shape" was the right shape
with the wrong count.** `TryAnnotateTypeOrScopeTokenAfterScopeSpec` reads the
final component of a qualified type and had no escape arm;
`TryAnnotateTypeOrScopeToken`'s *typename-specifier* branch reads it a second
time for `typename T::`union``; `ParseDeclarationSpecifiers`' `annot_cxxscope`
case reads it a third time, for the non-tentative path, where a qualified
type-specifier is not annotated but looked up directly; and
`isCXXDeclarationSpecifier`'s existing `tok::backtick` arm answered with
`Actions.getTypeName` on the escaped keyword, which says *not a type* for a
namespace, so it now annotates and asks again — which is exactly what the
identifier arm beside it does for `N::T`. A fifth site,
`isConstructorDeclarator`, is a **regression the fix caused and the sweep
caught**: `` `union`::`union`() { } `` had been accepted by accident, because
the old code bailed out of the decl-specifier on seeing a backtick and left it
to the declarator, and looking the name up as a type first took that away.

**The third of those arms shipped an infinite loop, and the *error* sweep is
the only thing that could have caught it.** `ParseDeclarationSpecifiers`'
recovery for a qualified name that does not resolve is *implicit-int*, which
does not apply to an escape and consumes nothing, so
`` namespace N { int x; } N::`union` g; `` — a well-formed escape naming
something that is not a type — re-entered the same `case` with the token
stream unchanged, indefinitely. The bail-out the arm replaced had been
preventing that by accident. Nothing in either suite covered a malformed *or*
an unresolvable escape in a qualified position, and a `-verify` test would not
have caught it either: **a test that never terminates does not fail.** The
probe that found it is [`ops/probes/escape-errors.sh`](probes/escape-errors.sh),
twenty-three programs run under `timeout`, and it is a different question from
the one a coverage sweep asks. `clang/test/Parser/backtick-escape-diagnostics.cpp`
now pins it.

**The interesting cost is not the arms; it is that an annotation token is
matched against the cached token stream by source location.** An escape is
three tokens where the grammar wants one, so `ConsumeBacktickEscape` now
optionally reports the escape's extent and every annotation formed over an
escaped name begins at the opening backtick and ends at the closing one. The
same reasoning fixed a latent bug in the helper itself: it pushed the
following token back with `PP.EnterToken` unconditionally, which is wrong
under backtracking because the pushed token is then not in the cache and the
cache is left pointing past a token the parser has not consumed. It now uses
the `AnnotateScopeToken` idiom — `PP.RevertCachedTokens (1)` when
backtracking, `PP.EnterToken` otherwise — which is what makes an escape
consumable inside a tentative parse at all. `escape-name-positions`' rule
still holds and is now sharper: **a predicate answers and a parse consumes,
unless the predicate is one of the ones whose job is to annotate**, and those
have to annotate over the whole escape.

**Reconciled into** [§12](../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers),
the new paragraph headed *"A third category was found the same way, by
sweeping rather than by a failing test"* and the third bullet of *"What it
cost, and where the cost is"*, which is the annotation-token cost; and into
[§17.8](../docs/backtick-operator-design.md#178-which-of-this-is-clangs-alone-and-why),
the paragraph beginning *"Everything else this paragraph has ever carried is
gone"* — where it is the third of three closed divergences and the only one
that ever ran with GCC as the wider implementation — and the closing paragraph
*"One asymmetry the escape did add to this section"*. Pinned by
`clang/test/Parser/backtick-escape-positions.cpp`'s qualified section, whose
third RUN line re-parses its own `-ast-print` output, and by the matching
section of `gcc/testsuite/g++.dg/backtick/escape-positions.C`, so a
divergence in either direction is now a test failure rather than a probe
result.
