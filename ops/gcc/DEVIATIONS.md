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

**What differed.** Clang now implements [type-name-slot](../../docs/backtick-operator-design.md#type-name-slot) (type-name in the slot yields construction, CTAD applying); **GCC does not** — `` 1 `P` 2 `` still fails on the GCC branch, since its slot parse (`cp_parser_assignment_expression` under `backtick_is_operator_p` suppression, plus the G10 bare-name ADL path) has no type arm. Re-measured 2026-09-09: Clang now accepts `` 1 `Point` 2 `` and GCC rejects it with *"no match for call to '(Point) (int, int)'"*, which shows the two front ends fail at different points — GCC resolves the name and then looks for an `operator()` on an object of that type, where Clang refuses a slot naming a type before it gets that far. The fix is therefore not the same edit in the two compilers.

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

**Formerly:** none — new slug, 2026-09-07. **Status:** **FIXED and RECONCILED**

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

**Corrected 2026-09-07** by [settle-paper-rows](../completion/steps/settle-paper-rows.md), which probed nineteen name positions in both compilers rather than the eight this row was written from. **It is three programs, not one.** Clang alone accepts an *alias-declaration* name, an *alias-template* name and a *concept* name; GCC rejects all three. One cause, and the row's diagnosis was right as far as it went: Clang parses all three through `ParseUnqualifiedId`, where the escape arm lives, and GCC parses them through `cp_parser_identifier`, which requires a bare `CPP_NAME` token. The corrected list is in [§12](../../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers)'s table.

**Reconciled where it is a fact; open where it is a question, 2026-09-07.** The fact — three programs, one cause — is **RECONCILED into [§17.8](../../docs/backtick-operator-design.md#178-which-of-this-is-clangs-alone-and-why)**, the paragraph beginning *"Keep that separate from the places where the two implementations genuinely disagree"*, which now reads *two kinds, and four programs*. **The direction of the fix is not this row's to choose and is not a parity question on its own.** §12's decided position list contains no alias-declaration name, so Clang's acceptance is as far outside the decided set as GCC's rejection is behind it, and which way the two are brought together is part of [escape-name-positions](../DEVIATIONS.md#escape-name-positions). Priced there, in both directions, as the sixth question of [`docs/open-decisions.md`](../../docs/open-decisions.md#escape-name-positions). **Do not fix this by reflex in either compiler before that is answered.**

**Fixed and reconciled 2026-09-08** by [escape-name-positions](../completion/steps/escape-name-positions.md), which is the step the author's answer generated. The direction is the one the brief said it would be if the answer was (c): GCC comes up to Clang, not the other way round, and it does so out of the same `cp_parser_identifier` arm that gave the other eight positions — which is why this row could not be answered on its own. All three programs (an *alias-declaration* name, an *alias-template* name, a *concept* name) now compile in both compilers; so do the eight positions neither took. The alias half needed one thing the others did not: `cp_parser_alias_declaration` builds its own declarator with `make_id_declarator` rather than going through `cp_parser_direct_declarator`, so it has to carry `backtick_escaped_p` itself or `grokdeclarator` rejects the keyword the escape yields.

**Reconciled into** [§12](../../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers), the paragraph headed *"Which positions the escape reaches — decided 2026-09-07, and built"* and the seventeen-row table under it, in which this row's three programs are now `accepts / accepts`; and into [§17.8](../../docs/backtick-operator-design.md#178-which-of-this-is-clangs-alone-and-why), the paragraph beginning *"Keep that separate from the places where the two implementations genuinely disagree"*, which loses its second kind and its three programs and gains the one divergence that replaced them ([escape-type-keyword-binding](#escape-type-keyword-binding)).

### escape-type-keyword-binding

**Formerly:** none — new slug, 2026-09-08. **Status:** **FIXED and RECONCILED**

**Found by.** [escape-name-positions](../completion/steps/escape-name-positions.md), checking that the newly accepted positions were usable and not merely declarable.

**Design section.** [§12](../../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers); §3 [keyword-escape-coexistence](../../docs/backtick-operator-design.md#keyword-escape-coexistence)

**What differed.** An escape whose keyword is a **type** keyword. Measured 2026-09-08, flag on, in five positions:

```
int `int` = 0;                       clang++ accepted   cc1plus  error: 'int `int`' redeclared as different kind of entity
void `long`();                       clang++ accepted   cc1plus  rejected
using `int` = char;                  clang++ accepted   cc1plus  rejected
struct `int` { };                    clang++ accepted   cc1plus  error: using typedef-name 'int' after 'struct'
template<class T> using `long` = T;  clang++ accepted   cc1plus  error: redeclared as different kind of entity
```

**This is not caused by the position work and is not new**, which is the reason it is a row rather than a note: the first line is a plain *declarator-id*, the position [§12](../../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers)'s table has recorded as accepted by both compilers since the escape was first built. The table was measured with `new`, `class`, `union` and `try`, which are pure keywords, and the divergence hid behind that choice for two months.

**Cross-compiler note.** The cause is a GCC representation choice that has nothing to do with the escape: `int` and `long` carry a **global binding to the builtin type** in GCC's name table, so the identifier the escape yields is already bound to something and `grokdeclarator` reports a redeclaration. Clang's keywords carry no binding, so the identifier the escape yields is fresh. Nothing in the design says which is right — but the escape's whole purpose says something: the keywords a future revision is most likely to take are not type keywords, so this is the least valuable corner of the hatch, and it is also the corner where "the escape yields an ordinary identifier" is least true in GCC.

**Recommended doc change.** [§12](../../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers) states it as the one surviving acceptance divergence, which it now does, and [§17.8](../../docs/backtick-operator-design.md#178-which-of-this-is-clangs-alone-and-why)'s list of programs the two compilers treat differently carries it in place of the three alias/concept programs it replaces. Whether GCC should be made to accept it — and what that costs, since it means shadowing a global binding — is an implementer's question that nobody has priced, and it should not be answered by reflex any more than the alias parity was.

**Fixed** by [escape-name-sweep](../completion/steps/escape-name-sweep.md), 2026-09-08, on the GCC `backtick` branch. **Priced first, and it came in far under the row's own estimate**, because the row had the mechanism right and the consequence wrong. Shadowing a global binding sounds expensive; it is not, once one observation is made: **in C++ a declaration can be named by a keyword only if it was escaped.** `grokdeclarator` rejects a bare reserved word as a declarator-id — that check is [escape-name-positions](../DEVIATIONS.md#escape-name-positions)' own — and `int` is a keyword token everywhere else, so no program can reach the builtin's binding by writing its name. A declaration that collides with one is therefore never a *re*-declaration, and the parser does not have to thread "this name came from an escape" down into name lookup, which is what would have made it expensive.

**Three call sites and one predicate, all gated on `flag_backtick`.** `cp_builtin_reserved_type_binding_p` (`gcc/cp/decl.cc`) is true for the artificial `TYPE_DECL`s `record_builtin_type` binds at `BUILTINS_LOCATION` under a *keyword* spelling — not the non-keyword ones like `__int128_t`, which ordinary code may still redeclare. `duplicate_decls` returns *not a redeclaration* for such an `olddecl`, beside the existing arm that does the same for an undeclared builtin **function**; `update_binding` (`gcc/cp/name-lookup.cc`) treats the binding as absent, next to `anticipated_builtin_p`, which is the same idea for functions and had no type analogue; and `lookup_and_check_tag` drops it, or an elaborated-type-specifier reports `` struct `int` `` as *using typedef-name 'int' after 'struct'*.

**GCC's own source asked for this.** `record_builtin_type`'s comment reads *"The calls to set_global_binding below should be eliminated. Built-in types should not be looked up by name; their names are keywords that the parser can recognize. However, there is code in c-common.cc that uses identifier_global_value to look up built-in types by name."* The fix does not eliminate the bindings — that is upstream's call and would change the C front end — it steps around them for the one kind of declaration that can collide with one.

**Measured after, on fifteen programs** covering variable, function, alias, alias-template, class-head, enum-name, namespace-name, parameter, member and block scope, plus the four use positions and the coexistence case. All fifteen accepted by both compilers. **The "before" is stated as what was run and not as a total**: nine of those fifteen were measured on the pre-fix binary, seven of them rejected and two — parameter and member — accepted, and eleven type keywords were measured in a plain declarator-id and every one rejected, while `auto`, `const` and `new` were accepted. That last line is the cause in one line: the keywords that fail are exactly the ones `record_builtin_type` binds. **The keyword still names the builtin in the same translation unit** — `` struct `int` { int a; }; int x = 0; `int` v{1}; `` compiles, and `sizeof(int)` is still four — and `` int g (int p, `int` q) `` mangles as `_Z1gi3int` in **both** compilers, which is [§12](../../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers)'s ABI paragraph demonstrated on the hardest name it has. Flag-off parity measured byte-identically over `-fsyntax-only` on a well-formed and an ill-formed program and over the generated assembly, against the same binary with the flag off and against pristine trunk `cc1plus`; the only difference anywhere is the `.ident` build-date string between the two binaries.

**The row's closing judgement was wrong, and it is worth saying so.** It called this *"the least valuable corner of the hatch"*, because the keywords a future revision is likely to take are not type keywords. That is true about *likelihood* and irrelevant to the claim: the design says the escape yields an ordinary identifier, and the position it failed in was the *first row* of §12's table. A hatch that works for `module` and not for `int` is a hatch with an unstated exception, and the exception was invisible for two months because every probe used a pure keyword.

**Reconciled into** [§12](../../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers), the new paragraph headed ***"And a fourth, which is not about parsing at all"*** and the sweep table above *"What it cost, and where the cost is"*; into [§17.8](../../docs/backtick-operator-design.md#178-which-of-this-is-clangs-alone-and-why), the paragraph beginning *"Everything else this paragraph has ever carried is gone"*, where it is the second of three closed divergences and the section drops to **one** remaining, which is the type-name slot and has nothing to do with the escape; and into §3 [keyword-escape-coexistence](../../docs/backtick-operator-design.md#keyword-escape-coexistence)'s **`Log.`, the 2026-09-08 entry**. Pinned by `gcc/testsuite/g++.dg/backtick/escape-positions.C`'s type-keyword section and the matching section of `clang/test/Parser/backtick-escape-positions.cpp`.

### escape-diagnostic-spelling

**Formerly:** none — new slug, 2026-09-07. **Status:** **FIXED and RECONCILED**

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

**Fixed and reconciled** by [settle-paper-rows](../completion/steps/settle-paper-rows.md), 2026-09-07, on the GCC `backtick` branch — the ruling was ratified, so what was left was an implementer's question and not the author's. The condition is one `-fbacktick` already guarantees: a *declaration* can be named by a keyword only if it was escaped, because `grokdeclarator` rejects the bare declarator-id. `dump_decl_name` (`gcc/cp/error.cc`), GCC's one funnel for the name of a declaration, prints `` `kw` `` on that condition. Verified on four surfaces that name an entity — an argument note, a member reference, *cannot be used as a function*, and *no matching function for call to*.

**The fix was wrong on its first build, in exactly the way this branch's previous commit warns about, and the second one is the interesting part.** `cp_parser_error_1` hands a *keyword token* to `%qE` as though it were a name — with a comment in the source saying that is what it is doing — so the funnel escaped it too, and `void new (int, int);`, a program containing no backtick at all, began reporting its error against a backticked spelling. The parser now says, for the length of that one call, that what it has in hand is a raw token (`cp_printing_raw_token`, `gcc/cp/cp-tree.h`). **This is GCC's version of the split Clang draws by diagnostic argument kind**, and it is one guard where Clang needed six sites. `g++.dg/backtick/escape-diag.C` pins both halves: the escaped spelling, and the two backtick-free diagnostics that must not change.

**Reconciled into** §3 [keyword-escape-printing](../../docs/backtick-operator-design.md#keyword-escape-printing)'s **`Log.`, the 2026-09-07 entry beginning *"GCC now delivers the diagnostic half too"***, which records the general fact the two implementations share — the escape keeps no trace of how it was written, so an implementation must decide which printing surfaces name an entity — and into [§17.8](../../docs/backtick-operator-design.md#178-which-of-this-is-clangs-alone-and-why), the closing paragraph, which is the paper-facing version and now says the divergence lasted one day.

### gcc-dependent-slot-lookup

**Formerly:** `DEV-G11`, on `main` only — the row was written after this branch had already re-slugged the ledger, so it never had a slug and would have been lost in the merge. Carried forward here, re-measured rather than copied.

**Status.** **OPEN**, unowned. Cross-compiler divergence, and the conforming side is Clang.

**Closed by.** [gcc-dependent-slot-lookup](../completion/steps/gcc-dependent-slot-lookup.md), which carries the measured diagnosis, the two parser sites, and the parity gate.

**Found by.** (post-G10, in `backtick-examples`); re-confirmed 2026-09-09 against `backtick-trunk` and the GCC prototype.

**Design section.** §8 point 3 / §17.4 [ADL is normative](../../docs/backtick-operator-design.md#adl-normative); [gcc-slot-adl](#gcc-slot-adl) and [gcc-template-id-slot-adl](#gcc-template-id-slot-adl) are the same claim in two narrower cases, both of them closed.

**What differed.** An **unqualified slot name in a dependent context** is rejected by GCC and accepted by Clang. The slot names a namespace-scope *variable* made visible by a using-declaration, and the use is inside a function template:

```cpp
namespace smd::infix {
  inline constexpr auto pipe = [](auto&& x, auto&& f) { return f(x); };
}
using smd::infix::pipe;
inline constexpr auto inc = [](int x){ return x + 1; };
template<class T> auto g(T t) { return t `pipe` inc; }
int main() { return g(1); }
```

Clang exits 0 with no diagnostic. GCC exits 1 with

> error: 'pipe' was not declared in this scope, and no declarations were found by argument-dependent lookup at the point of instantiation

G10 made a bare-name slot run `perform_koenig_lookup`, but for a *dependent* call GCC re-runs the lookup at instantiation and keeps only the ADL result, discarding the ordinary lookup from the definition context. ADL finds nothing here, because `pipe` is a variable rather than a function and no argument's associated namespace is `smd::infix`. A qualified slot works, and so does the same expression outside a template.

**Cross-compiler note.** Clang carries the slot as an `UnresolvedLookupExpr`, which retains the definition-context lookup result, so both Clang tracks accept. [temp.dep.candidate] makes the candidate set for a dependent call ordinary lookup at the point of *definition* plus ADL at the point of *instantiation*; GCC is dropping the first half. Since the slot is defined to desugar to a call, **Clang's behaviour is the conforming one and GCC's is a bug**, which is the opposite polarity from most rows here.

**Recommended doc change.** Until it is fixed, §17.4's claim must be qualified for GCC: the prototype requires a qualified slot name inside a template when the callee is not ADL-reachable. **This bears on what a paper may claim about two-compiler evidence for ADL in dependent contexts**, so it is surfaced rather than owned.

### escape-type-name-spelling

**Formerly:** none — new slug, 2026-09-08. **Status:** **OPEN**, unowned.

**Found by.** [escape-name-sweep](../completion/steps/escape-name-sweep.md), running the error-path half of its sweep ([`ops/probes/escape-errors.sh`](../probes/escape-errors.sh)) and reading the diagnostics rather than only the exit codes.

**Design section.** §3 [keyword-escape-printing](../../docs/backtick-operator-design.md#keyword-escape-printing); [§12](../../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers)'s **Printing and diagnostics** paragraph; [§17.8](../../docs/backtick-operator-design.md#178-which-of-this-is-clangs-alone-and-why)

**What differed.** [escape-diagnostic-spelling](#escape-diagnostic-spelling) closed on 2026-09-07 with the claim that GCC now spells an escaped name with its backticks in diagnostics. **That is true of a *declaration*'s name and false of a *type*'s.** The fix went into `dump_decl_name`, "GCC's one funnel for the name of a declaration"; a class or enum type is printed by `dump_aggr_type`, which ends at `pp_cxx_tree_identifier (pp, DECL_NAME (decl))` and never reaches that funnel. Measured 2026-09-08, flag on, one program per line:

```
struct `union` { }; int f(`union` u) { return u + 1; }
  gcc:   no match for 'operator+' (operand types are 'union' and 'int')
  clang: invalid operands to binary expression ('`union`' and 'int')

struct `union` { }; `union` f() { return 1; }
  gcc:   could not convert '1' from 'int' to 'union'
  clang: no viable conversion from returned value of type 'int' ...

struct `union` { }; int f() { `union` u; return u.`new`; }
  gcc:   'struct union' has no member named '`new`'          <- both in one line
  clang: no member named '`new`' in '`union`'

enum class `enum` { A }; int f() { return `enum`::A; }
  gcc:   cannot convert 'enum' to 'int' in return
  clang: cannot initialize return object of type 'int' ...

template <class T> struct W { }; struct `union` { }; W<`union`> w; int f() { return w; }
  gcc:   cannot convert 'W<union>' to 'int' in return
  clang: no viable conversion from returned value of type 'W<`union`>' to ...

namespace N { struct S{}; } template <class T> struct W { typename T::`union` m; }; W<N::S> w;
  gcc:   no type named 'union' in 'struct N::S'
  clang: no type named '`union`' in 'N::S'
```

The third line is the sharpest: **one GCC diagnostic prints the same feature both ways**, escaping the member name and not the type it is a member of, because the two halves come from different printers.

**Cross-compiler note.** Not a difference in accepted programs — both compilers accept and reject exactly the same programs under the flag, which is what [§17.8](../../docs/backtick-operator-design.md#178-which-of-this-is-clangs-alone-and-why) records — so this belongs beside [gcc-wrapper-parity](#gcc-wrapper-parity) and [escape-diagnostic-spelling](#escape-diagnostic-spelling) rather than beside an acceptance gap. `union` and `enum` are also the *worst* case for it: a bare type name in a diagnostic is not merely unre-parseable, it reads as a class-key, and `'struct union' has no member named ...` is a sentence about a program nobody wrote. The last line shows a second, separate surface: `%qE` applied to an `IDENTIFIER_NODE` for a *dependent* name does not reach `dump_decl_name` either.

**Recommended doc change.** §12's **Printing and diagnostics** paragraph and §3 [keyword-escape-printing](../../docs/backtick-operator-design.md#keyword-escape-printing)'s `Log.` should say that the ruling is delivered on declaration names in both compilers and on **type** names in Clang only, which is the same shape as [§17.3](../../docs/backtick-operator-design.md#173-type-name-in-the-operator-slot-type-name-slot)'s single-compiler evidence and should be stated the same way. §17.8's closing paragraph currently says the divergence *lasted one day*; it lasted one day for one half of the surface.

**Not fixed, and deliberately so.** It is not the same change as the two rows [escape-name-sweep](../completion/steps/escape-name-sweep.md) closed — those are name lookup, this is the diagnostic printer — and it is the third time this feature has touched GCC's error printer. **Both previous times the first build was wrong in the same direction**: `cp_parser_error_1` hands a raw keyword token to `%qE` as though it were a name, and a program containing *no backtick* began reporting against a backticked spelling ([escape-diagnostic-spelling](#escape-diagnostic-spelling)). A funnel one layer further out has more callers, not fewer, and the guard that makes it safe is `flag_backtick` plus a claim about *which* identifiers can only have come from an escape — a claim that is airtight for a declarator-id and has not been checked for a type name reached through `TYPE_NAME`. The measurement is done; the fix needs its own step, its own flag-off parity run, and its own negative test, and it should not be taken by reflex any more than the alias parity or the type-keyword binding was.
