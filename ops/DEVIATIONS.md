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

### backtick-source-locations

**Formerly:** `DEV-05`. **Status:** **RECONCILED**

**Found by.** S11

**Design section.** §11 phase 2; step S11

**What the design said.** Step says "remembers the two backtick locations" (implies dedicated SourceLocation fields in BacktickInfixExpr)

**What was true.** Backtick source locations are NOT stored separately in BacktickInfixExpr. They are already in the inner CallExpr's LParen/RParen location fields (passed as OpenLoc/CloseLoc to BuildCallExpr). The pretty-printer reconstructs syntax from structure (LHS, callee, RHS), not from source locations. This is sufficient for round-trip and for source ranges.

**Recommended doc change.** **RECONCILED** into §6.4 and §11 phase 2 (locations live in the inner `CallExpr` paren locs; no separate wrapper fields).

### wrapper-inner-shape

**Formerly:** `DEV-06`. **Status:** OPEN

**Found by.** (maintenance, 2026-08-04)

**Design section.** §6.4; §11 phase 2

**What the design said.** The wrapper wraps "the desugared `CallExpr`", and its pretty-printer reconstructs the surface form from that call's structure (LHS, callee, RHS)

**What was true.** Sema's result is not always a `CallExpr`, so the node carries a *semantic form*, not a call. `MaybeBindToTemporary` wraps a class-typed prvalue with a non-trivial destructor in a `CXXBindTemporaryExpr` and adds a consuming `ImplicitCastExpr` under ARC; a builtin with custom type checking replaces the call outright with a node that is neither a call nor keeps the callee (`` a `__builtin_shufflevector` b `` yields a `ShuffleVectorExpr`). `StmtPrinter` `cast<CallExpr>`'d it and crashed on the first shape; the second is unprintable as backtick syntax at all. Fixed by documenting `Inner` honestly and adding `getCallExpr()`, which looks through the implicit nodes and returns null when no call remains; the printer falls back to the semantic form. Test: `clang/test/Parser/backtick-ast-print.cpp`.

**Recommended doc change.** Reword §6.4 / §11 phase 2: the wrapper holds **whatever Sema built**, and the printer's structural reconstruction is best-effort — correct for every well-formed backtick use whose slot is a real callee, and degraded (prints the desugaring) for a builtin rewrite. The "sugar for `op(x, y)`" thesis is unaffected; what is affected is the claim that round-trip is unconditional.

### analysis-layer-sites

**Formerly:** `DEV-07`. **Status:** OPEN

**Found by.** (maintenance, 2026-08-04)

**Design section.** §11 phase 2 ("purely additive"); §6.4 site list

**What the design said.** Phase 2 is a "thin transparent AST wrapper … purely additive"; the S11 site list covers AST, Sema, CodeGen, serialization and the exhaustive `StmtClass` switches

**What was true.** A new `Expr` node also has obligations in the **Analysis / StaticAnalyzer** layer, and nothing in the toolchain forces them. `ExprEngine::Visit`'s missing case (a `-Wswitch` warning only, and `LLVM_ENABLE_WERROR` is OFF) meant the path was dropped without a successor, so **the whole enclosing function went unanalyzed** — `core.NullDereference` missed a bug through a backtick call that it catches through the same call written normally. Three more sites were silent: `CFGBuilder::Visit` (wrapper became a CFG element of its own), `findConstructionContexts` (construction-context chain broke, so a lifetime-extended temporary was modelled as an ordinary one), `VisitForTemporaries` (dropped `ExternallyDestructed`, giving a *double* destructor in the CFG), plus `LiveVariables::LookThroughExpr` (liveness keyed on the wrapper while the binding was keyed on the call, so every backtick result read back as unknown) and `Environment::ignoreTransparentExprs`. Fixed on both branches; test `clang/test/Analysis/backtick-infix.cpp`.

**Recommended doc change.** Add an implementation-experience note to §6/§11: a transparent front-end wrapper is *not* free — it costs five analysis-layer sites that the compiler will not tell you about, and getting them wrong silently disables the static analyzer rather than failing a build. This is the backtick counterpart of the Unicode track's "6 link / 8 unreachable / 1 warning / 13 silence" accounting ([expression-node-cost](unicode-operators/clang/DEVIATIONS.md#expression-node-cost)) and belongs in the same paragraph.

### type-slot-cost

**Formerly:** `DEV-08`. **Status:** OPEN

**Found by.** BL02

**Design section.** §3 [type-name-slot](../docs/backtick-operator-design.md#type-name-slot); §17.3; paper `[expr.backtick]` grammar

**What the design said.** [type-name-slot](../docs/backtick-operator-design.md#type-name-slot) is "blessed as a consequence, not a special rule": the slot is any callable expression, a type-name is callable, so `` x `T` y `` == `T(x, y)` falls out for free

**What was true.** It does not fall out. A bare type-name is not an *assignment-expression*, so the "consequence" contradicted the proposal's own grammar (`backtick-operator: assignment-expression` vs. the normative `r7` example `` a `std::pair` b ``), and the implementation rejected all four type-slot shapes (bare class, class template, qualified, builtin) with three different diagnostics. Delivering [type-name-slot](../docs/backtick-operator-design.md#type-name-slot) cost: **two grammar productions plus a lookup-based disambiguation paragraph in the paper**; **one parser routine** (`Parser::TryParseBacktickTypeSlot`, ~70 lines: slot-local pre-annotation mirroring the expression parser's trigger set, a `getTypeName` probe for bare identifiers — whose deduction-context default is also what makes CTAD work, no separate template arm needed — a tentative-parse probe for qualified template-names, and the functional-cast `DeclSpec` arm for builtins/annotated types); **a `ParsedType` threaded beside the slot's `ExprResult`**; **a Sema overload** routing to `ActOnCXXTypeConstructExpr` (CTAD, temporaries, and dependent construction inherited); and **two printer arms** (`CXXTemporaryObjectExpr`, `CXXUnresolvedConstructExpr`) to keep `-ast-print` round-tripping. No AST change: F23's `getCallExpr()` contract already tolerated a non-call inner. Full parity with the spelled form verified, including `` 1 `int` 2 `` failing with exactly `int(1, 2)`'s diagnostic and a function hiding a same-named class resolving to the call.

**Recommended doc change.** Reword [type-name-slot](../docs/backtick-operator-design.md#type-name-slot)/§17.3: "blessed as a consequence" is wrong *as grammar* — the type slot is a deliberate second production with a disambiguation rule (the type interpretation wins exactly when lookup finds a type or class template), not a freebie. Quote the measured cost (1 parser routine, 1 Sema overload, 2 printer arms, 2 grammar productions) in the implementation-experience section; "consequences" of a design are not free.

### cir-backtick-arms

**Formerly:** `DEV-09`. **Status:** OPEN

**Found by.** BL04

**Design section.** §6 (the Clang implementation plan's site list); §17

**What the design said.** The design's Clang site list, and [`clangir-backtick-arms`](BACKLOG.md#clangir-backtick-arms) behind it, treat ClangIR as an open question of the same shape as the Unicode track's [`clangir-unicode-arms`](BACKLOG.md#clangir-unicode-arms) — a code generator nobody had built, whose worst case was assumed to be a hard `Not Yet Implemented` diagnostic.

**What was true.** **`BacktickInfixExpr` needs four ClangIR arms, and one of the four fallbacks is an abort rather than a diagnostic.** Measured by compiling `clang/lib/CIR/` for the first time (`mlir` + `CLANG_ENABLE_CIR=ON`). Scalar and aggregate emit `errorNYI` naming the node; complex emits `errorUnsupported` (`"cannot compile this complex expression yet"`) which does **not** name it; and `emitLValue` falls to a default arm that returns a default-constructed `LValue`, whose null `QualType` then asserts — so `` (b `at` 1) = 42 `` **crashed the compiler**. `UserOperatorExpr` behaves identically at every one of the four, which is what shows the crash belongs to `emitLValue`'s default arm and not to either wrapper. The fix is three copy-paste arms using `getSubExpr()` plus one that is *not* a copy: `emitLValue` recurses into the sub-expression instead of diagnosing, because a backtick call returning a reference is a call returning a reference and the `CallExpr` classes above already handle it. **The cross-compiler note worth carrying:** this is a place where the two features cost exactly the same — four arms each, same sites, same order, same failure modes — in contrast to the AST-node work, where [expression-node-cost](unicode-operators/clang/DEVIATIONS.md#expression-node-cost) found the Unicode wrapper strictly more expensive because it cannot be transparent to `TreeTransform`. Code generation sees only the desugared call, so the asymmetry disappears at exactly the point the design predicts it should.

**Recommended doc change.** Add the code generator to §6's site list with the two-column shape above, and state the symmetry in §17: the backtick wrapper and the Unicode wrapper diverge in the front end and converge in the back end, which is the design's own claim about where the sugar stops mattering. Note separately, as an upstream observation rather than a feature one, that `CIRGenFunction::emitLValue`'s default arm turns any unhandled l-value class into an assertion failure.
