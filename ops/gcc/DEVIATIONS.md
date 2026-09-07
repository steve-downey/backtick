# GCC deviation ledger

Same purpose as `ops/DEVIATIONS.md`, for the GCC track. Additionally record
**cross-compiler divergences**: anywhere GCC and Clang had to differ in
accepted programs, diagnostics, or behavior. Those differences are exactly
what CWG/EWG ask about and belong in the paper's implementation-experience
section.

Each entry is headed by its **slug** and is therefore a Markdown anchor;
cross-references link to it. `Formerly:` carries the serial number the entry
used to have, because the completed tracks' handoffs still say it and are not
rewritten. [`ops/SLUGS.md`](../SLUGS.md) is the whole map.

### gcc-bare-nesting-detection

**Formerly:** `DEV-G04`. **Status:** **RESOLVED**

**Found by.** G04

**Design section.** §3 [nesting-vs-chaining](../../docs/backtick-operator-design.md#nesting-vs-chaining); Clang [bare-nesting-detection](../DEVIATIONS.md#bare-nesting-detection)

**What differed.** Bare nested backtick `x \`f \`g\` h\` y` cannot be detected and rejected: after parsing slot `f`, the next CPP_BACKTICK is indistinguishable from a close backtick, so it is consumed as the close. Result silently parses as two chained operators `h(f(x,g),y)`. Matches Clang [bare-nesting-detection](../DEVIATIONS.md#bare-nesting-detection) exactly.

**Cross-compiler note.** Cross-compiler match: both compilers silently accept. [nesting-vs-chaining](../../docs/backtick-operator-design.md#nesting-vs-chaining) enforcement requires lookahead or two-pass. Deferred.

**Recommended doc change.** **RESOLVED** ([nesting-vs-chaining](../../docs/backtick-operator-design.md#nesting-vs-chaining) reframed, design §17.1): no enforcement needed. Both compilers correctly accept the bare form because it *is* a valid [chaining-associativity](../../docs/backtick-operator-design.md#chaining-associativity) chain (token-identical to nesting); diagnosing it would contradict [chaining-associativity](../../docs/backtick-operator-design.md#chaining-associativity). The cross-compiler match stands, now as intended behavior rather than a shared gap.

### gcc-slot-adl

**Formerly:** `DEV-G05`. **Status:** **RESOLVED**

**Found by.** G05

**Design section.** §8 point 3 ("inheriting ADL")

**What differed.** Pure ADL — where the function is *only* visible in a namespace and not at file scope — did NOT work in G05. The backtick slot was parsed as a standalone assignment-expression; `cp_parser_lookup_name` fired on the slot identifier before `finish_call_expr` could apply Koenig. The postfix-expression loop then rejected the unresolved identifier (not followed by `(`) via `unqualified_name_lookup_error`. ADL *augmentation* also failed because the slot arrived as a resolved `FUNCTION_DECL`. **FIXED in G10**: for a bare CPP_NAME slot immediately followed by the closing CPP_BACKTICK, the parser now calls `cp_parser_identifier` to get an IDENTIFIER_NODE without lookup, performs explicit ordinary lookup then `perform_koenig_lookup(fns ?: id, args, ...)`, then calls `finish_call_expr`. Both pure ADL and augmentation now work (verified in infix-adl.C). The same fix is applied to the RHS-lookahead handler added in G06.

**Cross-compiler note.** **FIXED — cross-compiler agreement restored**: Clang uses `UnresolvedLookupExpr`; GCC now uses explicit `perform_koenig_lookup` on a bare IDENTIFIER_NODE. Both compilers deliver full ADL for bare-name slots.

**Recommended doc change.** **RESOLVED (G10)**: no doc change needed; §17.4 is normative and the implementation now conforms.

### gcc-precedence-placement

**Formerly:** `DEV-G06a`. **Status:** **FIXED**

**Found by.** G06

**Design section.** §4 Option A ("highest binary precedence")

**What differed.** G03's backtick handler in `cp_parser_binary_expression` fired only at the top of the loop on `current.lhs`, meaning standard binary operators (`*`, `+`, etc.) accumulated into `current.lhs` before backtick could fire. Result: `a * b `f` c` parsed as `f(a*b, c)` — backtick had the *lowest* effective binary precedence, not the highest. Fix added in G06: a while-loop RHS-lookahead handler after `cp_parser_simple_cast_expression` processes backtick(s) on the just-parsed RHS *before* building the enclosing binary op. Now `a * b `f` c` → `a * f(b, c)`.

**Cross-compiler note.** Cross-compiler: Clang had correct highest-precedence behavior from S03. GCC needed the fix.

**Recommended doc change.** **FIXED in G06** — parser.cc now implements §4 Option A correctly.

### gcc-tree-canonicalisation

**Formerly:** `DEV-G06b`. **Status:** **NO DOC CHANGE**

**Found by.** G06

**Design section.** §4 Option A (dump readability)

**What differed.** GCC canonicalises commutative `MULT_EXPR` with the "more complex" subexpression on the left: `a * f(b,c)` is stored and printed as `f(b,c) * a` in `-fdump-tree-original`. Semantics are identical.

**Cross-compiler note.** Cross-compiler: Clang's AST dump shows `a * f(b,c)` in source order.

**Recommended doc change.** **NO DOC CHANGE** — internal tree canonicalisation, not observable at the language level.

### gcc-ternary-normalisation

**Formerly:** `DEV-G06c`. **Status:** **NO DOC CHANGE**

**Found by.** G06

**Design section.** §4 (ternary operand)

**What differed.** GCC normalises `p != 0 ? q : f(r,d)` to `p == 0 ? f(r,d) : q` in the GENERIC tree (inverts condition, swaps arms). The generated code is semantically identical.

**Cross-compiler note.** Cross-compiler: Clang preserves source order.

**Recommended doc change.** **NO DOC CHANGE** — GENERIC-level normalisation, not a language difference.

### gcc-keyword-declarator

**Formerly:** `DEV-G07a`. **Status:** **NO DOC CHANGE**

**Found by.** G07

**Design section.** §12 (ABI: "yields an ordinary identifier")

**What differed.** In GCC, keyword IDENTIFIER_NODEs have `IDENTIFIER_KEYWORD_P` permanently set on the shared interned node. `grokdeclarator` (decl.cc) uses this flag to emit "declarator-id missing; using reserved word". The fix: add `if (!flag_backtick)` guard in `grokdeclarator` to suppress the error. The alternative (clearing the keyword bit on the node) was unsafe—it affects the global node used by token-to-keyword conversion in the lexer.

**Cross-compiler note.** Cross-compiler difference: Clang mutates the token in-place (`setKind(tok::identifier)`) before the semantic layer, avoiding the check entirely. GCC's semantic layer needed explicit awareness of the escape.

**Recommended doc change.** **NO DOC CHANGE** — implementation-internal. The ABI/name behavior matches spec (§12).

### gcc-type-slot-parity

**Formerly:** `DEV-G08`. **Status:** **RECONCILED** (gcc-resync, 2026-09-06)

**Found by.** (BL02, Clang-side)

**Design section.** §17.3 [type-name-slot](../../docs/backtick-operator-design.md#type-name-slot); Clang [type-slot-cost](../DEVIATIONS.md#type-slot-cost)

**What differed.** Clang now implements [type-name-slot](../../docs/backtick-operator-design.md#type-name-slot) (type-name in the slot yields construction, CTAD applying); **GCC does not** — `` 1 `P` 2 `` still fails on the GCC branch, since its slot parse (`cp_parser_assignment_expression` under `backtick_is_operator_p` suppression, plus the G10 bare-name ADL path) has no type arm.

**Cross-compiler note.** Cross-compiler divergence, open: the two compilers now accept different programs under `-fbacktick`. The Clang shape to mirror: intercept a type-name slot before expression parsing (bare name via type lookup with CTAD placeholder, qualified via tentative scope parse, builtin via the functional-cast machinery) and route to the `T(x, y)` build path (`finish_compound_literal` / functional-cast equivalent). Implementing it in GCC is **not** part of BL02.

**Recommended doc change.** **RECONCILED (gcc-resync, 2026-09-06)** into §17.3 [type-name-slot](../../docs/backtick-operator-design.md#type-name-slot), the paragraph added at the end of that section: the divergence stands and is now stated as such in the design doc, so the paper's implementation-experience section cannot claim two-compiler evidence for the type-name slot without first implementing it in GCC. Reconciling the row is not implementing the feature — GCC still rejects `` 1 `P` 2 `` — and the row is closed as *recorded*, not as *fixed*. Implementing it in GCC remains unscheduled; it is a self-contained piece of work, and §17.3 now says what it would take.

### gcc-template-id-slot-adl

**Status:** **FIXED** (gcc-resync, 2026-09-06)

**Found by.** gcc-resync, re-testing §17.4 after the re-sync

**Design section.** §17.4 ADL is normative; [gcc-slot-adl](#gcc-slot-adl) is the same defect one grammar production over

**What differed.** §17.4 says the slot gets the same ADL as the plain call. G10 made that true for a bare name by keeping it as an `IDENTIFIER_NODE` and running `perform_koenig_lookup`, but detected the bare name with a two-token peek — `CPP_NAME` followed by the closing `CPP_BACKTICK` — which a template-id never matches, because the token after the name is `<`. So `` x `add<int>` y `` fell to the resolve-at-parse-time path: pure ADL failed outright with *"'add' was not declared in this scope"*, and augmentation never saw the associated namespaces. `add<int>(x, y)` gets ADL, so the slot was strictly weaker than the call it desugars to, and §17.4 was overstated for GCC.

**Cross-compiler note.** Clang was never affected: an `UnresolvedLookupExpr` carries template arguments, so the bare name and the template-id take one path there. The divergence is closed — both compilers now deliver full ADL for every unqualified slot form.

**Recommended doc change.** **RESOLVED** — §17.4 rewritten to say that ADL binds wherever the slot is an unqualified name, *with or without template arguments*, and that a qualified name or arbitrary expression correctly gets none. Fixed by extending the detection rather than narrowing the claim; `cp_parser_backtick_template_id_slot` parses `f<...>` tentatively and hands `perform_koenig_lookup` a `TEMPLATE_ID_EXPR`.

### escape-arm-entry-token

**Status:** **FIXED** (gcc-resync, 2026-09-06)

**Found by.** gcc-resync, while narrowing [grokdeclarator-guard-scope](../BACKLOG.md#grokdeclarator-guard-scope)

**Design section.** §12 keyword-escape; the ground rule that a default build behaves exactly as upstream

**What differed.** Both escape arms in `parser.cc` sat behind a `case CPP_BACKTICK:` label that another case falls through to — `CPP_KEYWORD` in `cp_parser_unqualified_id`, `CPP_XOR` in `cp_parser_primary_expression` — and each tested only `flag_backtick`, never the token in hand. So under `-fbacktick` a *bare* keyword in name position entered the escape arm, was consumed as though it were the opening backtick, and reported *"backtick keyword-escape requires a C++ keyword"* against the token after it; `void new (int, int);` pointed at the `(`. A stray `^` reported *"expected unqualified-id"* instead of *"expected primary-expression"*. Neither program contains a backtick, and both diagnose differently with the flag on.

**Cross-compiler note.** Clang cannot have this defect by construction: it recognises the escape in the lexer and mutates the token to `tok::identifier`, so no semantic-layer arm is keyed on the flag. This is the same asymmetry [gcc-keyword-declarator](#gcc-keyword-declarator) records, met a second time — GCC's escape needs the *token type*, not the flag, at every point where the two could disagree.

**Recommended doc change.** No design change; §12 is unaffected. Worth one sentence in the paper's implementation-experience section, because it is the concrete cost of GCC's keyword identifiers being interned with the keyword bit set: the flag alone is never a safe proxy for "this name was escaped", and the implementation has to carry the fact explicitly — on the token where the escape is parsed, and on the declarator where `grokdeclarator` later needs it.

### gcc-wrapper-parity

**Status:** **RECORDED** (gcc-resync, 2026-09-06) — nothing to diverge from

**Found by.** F23 / F24 (Clang-side), recorded here by gcc-resync

**Design section.** §17 implementation experience; Clang [wrapper-inner-shape](../DEVIATIONS.md#wrapper-inner-shape) and [analysis-layer-sites](../DEVIATIONS.md#analysis-layer-sites)

**What differed.** GCC carries neither the F23 fix nor the F24 one, **and cannot carry the first**: no phase-2 AST wrapper node was ever built there. GCC desugars the operator in the parser and hands `finish_call_expr` an ordinary call, so there is no `BacktickInfixExpr` to teach anything about, and no static analyzer analogue that would need teaching.

**Cross-compiler note.** This is a difference **in kind, not in behaviour**, and it is the interesting kind. It is not a divergence row in the usual sense — the two implementations accept the same programs and emit the same code — it is a whole class of Clang work with no GCC counterpart, because the two front ends chose different representations for the same desugaring. The paper should say so plainly rather than leaving a reader to infer that GCC is missing something: a front end that desugars in the parser pays none of the AST-node cost, and gets none of the source fidelity that cost buys.

**Recommended doc change.** State in the implementation-experience section which parts of the Clang work have no GCC counterpart *by construction* — the AST node and everything downstream of it (source-fidelity printing, the analyzer arms, the CIR arms, serialization) — and separate that from the parts GCC simply has not done ([gcc-type-slot-parity](#gcc-type-slot-parity)). The first is a design consequence and belongs in the argument; the second is a gap and belongs in the status table.

### escape-alias-name-parity

**Formerly:** none — new slug, 2026-09-07. **Status:** **OPEN**

**Found by.** [backtick-paper](../completion/steps/backtick-paper.md), probing the escape's grammatical coverage in both compilers.

**Design section.** [§12](../../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers); Clang [escape-name-positions](../DEVIATIONS.md#escape-name-positions)

**What differed.** The name in an *alias-declaration*. Measured 2026-09-07, flag on, both compilers:

```
using `class` = int;
clang++ -fbacktick   ->  accepted
cc1plus -fbacktick   ->  error: expected nested-name-specifier before '`' token
```

Every other position the two were probed in agrees — both accept declarator-ids (variables, functions, members, `typedef` names, out-of-class definitions), primary-expressions and names after `.`; both reject class-head, enum, namespace and template-parameter names ([escape-name-positions](../DEVIATIONS.md#escape-name-positions) has the table).

**Cross-compiler note.** This is the **second** place where the two implementations accept different programs under `-fbacktick`; [gcc-type-slot-parity](#gcc-type-slot-parity) is the first. Like that one it is a gap and not a disagreement: GCC parses an alias-declaration's name through a path that never reaches the escape arm, and nothing in the design says it should not. Note that `docs/backtick-operator-design.md` §17.8 says *"the one place the two implementations genuinely disagree"* — that sentence needs a second entry, and it now has one.

**Recommended doc change.** §17.8's *one place* becomes two, with both named and both marked as gaps. The paper's implementation-experience section already lists both, as the whole list of programs the compilers treat differently under the flag; keep the two in one place so the list stays checkable.

### escape-diagnostic-spelling

**Formerly:** none — new slug, 2026-09-07. **Status:** **OPEN**

**Found by.** [backtick-paper](../completion/steps/backtick-paper.md), measuring the question [clang-paper-truth](../completion/handoffs/clang-paper-truth.handoff.md) left open under *"The GCC side has no counterpart to the escape's printing question … nobody owns it."*

**Design section.** §3 [keyword-escape-printing](../../docs/backtick-operator-design.md#keyword-escape-printing), ratified by the author 2026-09-06; §12's **Printing and diagnostics** paragraph

**What differed.** The decision is that the escape is part of the name's spelling, so a diagnostic names the entity `` `new` `` and not `new` — under the flag there is no other way to write it, and text copied out of a diagnostic should re-parse. Clang implements that. GCC does not. Measured 2026-09-07 on a two-declaration, one-bad-call file:

```
clang:  error: no matching function for call to '`new`'
gcc:    note: initializing argument 1 of 'void new(int)'
```

GCC's note names the entity with a spelling no program can contain, which is the exact condition the decision exists to remove. GCC has no `-ast-print`, so the printing half of the decision has no GCC counterpart at all; the diagnostic half does, and diverges.

**Cross-compiler note.** Not a difference in accepted programs — both compile the same file — so it belongs beside [gcc-wrapper-parity](#gcc-wrapper-parity) rather than beside the two acceptance gaps. It is one `%D`-formatting decision deep in GCC's diagnostic printer and nothing in the design prevents it; the reason it was not done is that nobody had measured it. Now measured.

**Recommended doc change.** [keyword-escape-printing](../../docs/backtick-operator-design.md#keyword-escape-printing) should record that the ruling is delivered by one compiler, the way [§17.3](../../docs/backtick-operator-design.md#173-type-name-in-the-operator-slot-type-name-slot) records single-compiler evidence for the type slot. The paper says so in one clause and does not claim it of both.
