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

**Formerly:** `DEV-G05`. **Status:** OPEN

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

**Formerly:** `DEV-G08`. **Status:** OPEN

**Found by.** (BL02, Clang-side)

**Design section.** §17.3 [type-name-slot](../../docs/backtick-operator-design.md#type-name-slot); Clang [type-slot-cost](../DEVIATIONS.md#type-slot-cost)

**What differed.** Clang now implements [type-name-slot](../../docs/backtick-operator-design.md#type-name-slot) (type-name in the slot yields construction, CTAD applying); **GCC does not** — `` 1 `P` 2 `` still fails on the GCC branch, since its slot parse (`cp_parser_assignment_expression` under `backtick_is_operator_p` suppression, plus the G10 bare-name ADL path) has no type arm.

**Cross-compiler note.** Cross-compiler divergence, open: the two compilers now accept different programs under `-fbacktick`. The Clang shape to mirror: intercept a type-name slot before expression parsing (bare name via type lookup with CTAD placeholder, qualified via tentative scope parse, builtin via the functional-cast machinery) and route to the `T(x, y)` build path (`finish_compound_literal` / functional-cast equivalent). Implementing it in GCC is **not** part of BL02.

**Recommended doc change.** Track as a new GCC-track step (or BACKLOG row) once scheduled; until then the paper's implementation-experience section must say [type-name-slot](../../docs/backtick-operator-design.md#type-name-slot) has single-compiler evidence.
