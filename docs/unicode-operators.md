# Unicode User-Defined Operators — Design Sketch

Exploratory follow-on to the infix backtick operator (`backtick-operator-design.md`,
paper D4307). Nothing in this document is implemented; every decision below is
**Proposed**. Bare `Dn` and `§n` references are into the backtick design doc;
`Un` decisions and `U§n` sections are this document's own.

This is the non-ASCII companion to §14: that appendix inventories the exhausted
*ASCII* lexical real estate and concludes (§14.4) that backtick removes most of
the motivation to spend it. The remaining pool — Unicode characters with
syntactic status that C++ has never assigned — is much larger, and as of
UAX #31 revision 43 has normative footing (U§4). The question this sketch works
through: what would it take to let users *declare* operators drawn from it?

---

## 1. Thesis in one line

`x ⊞ y` is sugar for `operator⊞(x, y)`, where `operator⊞` is an ordinary
overloadable function the user declared. The same bet as backtick — desugar to
a call in the front end so overload resolution, ADL, templates, constexpr, and
codegen are inherited rather than reimplemented — applied to *symbols* instead
of *names*. Backtick lifts any existing name into infix position with zero
declarations; this lifts a fixed, frozen set of Unicode symbols into operator
position, at the price of a declaration.

```cpp
int operator⊞(int, int);            // an ordinary function declaration
5 ⊞ 7                               // operator⊞(5, 7)

Matrix operator⊗(Matrix const&, Matrix const&);
a ⊗ b ⊗ c                           // operator⊗(operator⊗(a, b), c) — left-assoc

Vec operator⊖(Vec const&);          // one parameter -> unary prefix form
⊖v                                  // operator⊖(v)
```

---

## 2. Decisions log (all Proposed)

| ID | Decision | Status | Rationale |
|----|----------|--------|-----------|
| U1 | Operator tokens are **single non-ASCII code points** with the Pattern_Syntax property, drawn from the mathematical/arrow blocks, shipped as a **frozen enumeration** | **Proposed** | Pattern_Syntax is immutable by Unicode stability policy, so the set can never grow or shrink under us (U§4). Single code point, NFC, no combining marks: keeps lexing trivial (one code point = one token), avoids the normalization/rendering questions Mn sequences drag in (negated operators like `⊕̸` are a v2 candidate, U§13). Non-ASCII by construction: every ASCII Pattern_Syntax character is already claimed or reserved by the grammar (§14). Confusables with existing punctuators are excluded by name (U§5). The standard would carry the final enumerated list normatively — the same standing as the existing UAX #31 reference for identifiers (U§4). |
| U2 | `operator⊞` is an *operator-function-id*; an ordinary overloadable free or member function, with **no class/enum-parameter requirement** | **Proposed** | Exactly the existing operator-function machinery, one production wider. The explicit-call spelling `operator⊞(a, b)` works, as it does for every operator today. [over.oper]'s "at least one class or enum parameter" rule exists to protect the built-in meaning of the token — a user operator *has* no built-in meaning to protect, so `operator⊞(int, int)` is legal and `5 ⊞ 7` finds it. That is the point: the fundamental-type case (`5 ⊞ 7`) is the motivating one. |
| U3 | Lexing is **declaration-independent**: every set member is always an operator token (under U7's flag), whether or not any `operator⊞` is in scope | **Proposed** | The lexer cannot consult declarations — tokenization precedes lookup (preprocessing, template bodies, header order). So the operator set is fixed by the *grammar*, not by what is declared; a use with no viable `operator⊞` fails at overload resolution with an ordinary "no match" diagnostic, exactly as an undeclared `operator+` on a class type does. This is Julia's model (fixed parse table, users define methods) and the opposite of Swift's (declaration-gated parsing), and it is the only model that works in C++ (U§11). |
| U4 | Binary user operators occupy **the backtick precedence level** (D2 Option A): tighter than `*`, looser than unary; operands are cast-expressions; **left-associative** (D1) | **Proposed** | One level for *all* user-introduced infix — named (backtick) and symbolic (this) — so mixed chains group left with no precedence table to learn. Reuses D2's litigated resolution wholesale, including the symmetric-prefix property: `-a ⊞ -b` is `operator⊞(-a, -b)`. Everything §4 records in favour of Option A applies unchanged. |
| U5 | **Unary prefix** operators are declared with one parameter; prefix vs infix is disambiguated by grammatical position; **no postfix forms** | **Proposed** | Arity selects the form, as it does for `operator-` today (two parameters / one member parameter = binary; one / none = prefix). Position disambiguates uses: post-operand → infix, operand position → prefix — the same strategy as `-`, `*`, `&`, and D10's escape-vs-operator split. Declining postfix eliminates the prefix/postfix ambiguity that forces Swift's whitespace-sensitivity rules; nothing mathematical is lost (postfix notation is rare outside `!`, and `!` is taken). |
| U6 | Candidate assembly is that of the **existing overloaded operators**: member candidates + non-member candidates found by unqualified lookup and **ADL**; no built-in candidates | **Proposed** | §17.4's rule carries over verbatim and stays normative: `x ⊞ y` must find every `operator⊞` the call `operator⊞(x, y)` would, including by ADL into the operands' associated namespaces — the mechanism that makes `std::cout << x` work is the mechanism that makes a library's `⊗` work on its own types. The GCC parse-time-resolution defect (DEV-G05) is the cautionary tale: carry the name unresolved into the call machinery. There are no built-in candidates because there are no built-in meanings (U2). |
| U7 | Gated behind its own flag, `-funicode-operators`, independent of and composable with `-fbacktick` | **Proposed** | Same D5 rationale: opt-in prototype vehicle, default build byte-identical to upstream. A separate flag because the features are separable proposals with separable fates; a translation unit may enable either, both, or neither, and U4's shared precedence level must parse identically whichever subset is on. |
| U8 | Mangling: Itanium **vendor-extended operator** (`v <arity> <source-name>`) with a code-point-derived source-name, e.g. `⊞` binary → `v2` + `op_u229E` | **Proposed — open (ABI)** | The `v` production exists precisely for operators the grammar didn't anticipate; precedent for naming-by-derived-source-name is `li<name>` for literal-operator suffixes, and precedent for retrofitting a real code is `aw` for `co_await`. A standardized feature would want a first-class `<operator-name>` production keyed by code point, which needs cross-vendor agreement — flagged open, not resolved. MSVC mangling unexamined. |
| U9 | **No user-declared precedence or associativity, ever** | **Proposed** | Fixity is the rock other designs founder on. A declared precedence is a semantic property that must travel with the name across headers, modules, and translation units; two TUs disagreeing about `a ⊕ b ⊗ c` is an ODR/IFNDR factory, and the parse of an expression comes to depend on which imports are visible (Haskell's fixity-import problem; Swift's precedencegroup conflicts). Fixed fixity makes the *parse* of any expression depend on nothing but the expression — only the *meaning* of `operator⊞` travels, and that is just ordinary lookup. This is D1/D2's "one level, left, learn it once" argument with the alternative's failure mode named. |

---

## 3. What transfers from backtick

The backtick project's settled decisions map onto this feature almost
one-for-one; the table records the mapping so the sketch doesn't re-litigate
what is already litigated.

| Backtick | Here | Note |
|----------|------|------|
| D1 left-associative | U4 | Verbatim. |
| D2 / §4 precedence (Option A) | U4 | Same level, shared with backtick; `-a ⊞ -b` symmetric for the §4 reasons. |
| D4 slot = assignment-expression | — | No slot: the operator *is* the token. The whole slot-grammar question vanishes. |
| D5 flag-gated | U7 | Own flag. |
| D6 desugar to a call | U2/U6 | Call to `operator⊞` via operator-style candidate assembly rather than a slot expression. |
| D9 no braced-init-list operands | carried | Operands are cast-expressions (U4), so excluded the same way. |
| D10 position disambiguation | U5 | Reused for prefix-vs-infix instead of escape-vs-infix. |
| D15 evaluation order is the call's | carried | It is just `operator⊞(x, y)`; [expr.call] wholesale, nothing new. |
| D16 type-name in the slot | — | No slot, no analogue. |
| §5 same-delimiter problem | **does not arise** | Each operator is one distinct token, not a matched pair. No `BacktickIsOperator` analogue, no suppression flag, nothing. |
| §17.1 nesting vs chaining | **does not arise** | No delimiters to nest; chains are ordinary left-associative operator chains. |
| §17.4 ADL is normative | U6 | Verbatim, with DEV-G05 as the recorded pitfall. |

Two things do **not** transfer, and they are the feature's real costs:

1. **A declaration is required.** Backtick needs no new declaration form; this
   needs `operator⊞` to be declarable, which touches declarators, name
   mangling (U8), and both compilers' closed operator-name tables (U§8).
2. **A character-set decision is required.** Backtick spent one ASCII
   character; this must carve, freeze, and defend a set of thousands (U§5),
   with the confusability and input-method questions that come with it (U§10).

---

## 4. Unicode grounding — UAX #31 revision 43

Facts checked against UAX #31 revision 43 (Unicode 17.0.0, 2025-08-20).

- **UAX31-R3c "User-Defined Operators"** is the normative hook: it defines
  operator syntax with Start = the set of characters with syntactic use
  (Pattern_Syntax) and Continue = Pattern_Syntax plus nonspacing marks
  (General_Category Mn, admitted so that composed forms like a negated
  operator can be written). It also records the lexical-ambiguity guidance
  this sketch follows: operators should not contain characters that can begin
  an identifier or literal.
- **Pattern_Syntax is immutable**: UAX #31 states the Pattern_Syntax and
  Pattern_White_Space properties are "absolutely invariant, not changing with
  successive versions of Unicode." This is the property that makes a frozen
  operator set safe to standardize: no future Unicode version can add to,
  remove from, or re-purpose it.
- **A correction to the obvious reading of §7.1.** TR31's §7.1 "Mathematical
  Compatibility Notation Profile" is an *identifier* profile, not an operator
  one: it admits ∂, ∇, ∞ (and style variants, plus sub/superscripts) as
  identifier characters, and its companion syntax profile *removes* those
  three from syntactic use. Consequence for us: the operator set comes from
  **R3c**, and ∂ ∇ ∞ must be **excluded** from it — TR31 has earmarked them
  for the other side of the line (they name things; they don't combine
  things).
- **Confusables and source handling.** UTS #39 (confusable detection) and
  UTS #55 (source-code handling, which TR31 itself points at for these
  characters) are the security-review companions; U§5 and U§10 apply them.
- **The standard already normatively references UAX #31.** C++23 adopted
  P1949R7, defining identifiers by XID_Start/XID_Continue with a normative
  reference to UAX #31 (R1). A proposal referencing R3c is the *same shape of
  citation to the same document* — precedent exists, and SG16 has the
  machinery to review it.

One more consequence of R3c worth stating: since Pattern_Syntax includes the
ASCII operator characters (`+ < | !` …), R3c does not hand C++ a usable set
directly. Every ASCII member is already a token, a token prefix, or blocked by
the adjacency rules §14.1 catalogues. The usable pool is exactly
**Pattern_Syntax minus ASCII** — which is why this sketch is the non-ASCII
companion to §14, not an application of it.

---

## 5. The token set (U1)

A code point is a *user-operator token* iff all of:

1. it has the **Pattern_Syntax** property (immutable, U§4);
2. it is **outside ASCII** (every ASCII candidate is claimed — §14);
3. it lies in the **mathematical and arrow blocks**: Arrows (U+2190–21FF),
   Mathematical Operators (U+2200–22FF), Miscellaneous Technical
   (U+2300–23FF), Miscellaneous Mathematical Symbols-A/B (U+27C0–27EF,
   U+2980–29FF), Supplemental Arrows-A/B (U+27F0–27FF, U+2900–297F),
   Supplemental Mathematical Operators (U+2A00–2AFF), Miscellaneous Symbols
   and Arrows (U+2B00–2BFF);
4. its General_Category is **Sm or So** — excluding the paired brackets
   (Ps/Pe: ⟨ ⟩ ⟦ ⟧ ⌈ ⌉ ⌊ ⌋ …), which are delimiters, not infix material, and
   are worth keeping unspent for any future bracketing proposal;
5. it is **not on the named exclusion list**:
   - **∂ ∇ ∞** — earmarked by TR31's mathematical profile as *identifier*
     characters (U§4);
   - **UTS #39 confusables of existing tokens** — U+2212 − (minus sign),
     U+2215 ∕ and U+2044 ⁄ (division/fraction slashes), U+2217 ∗ (asterisk
     operator), U+2223 ∣ (divides), U+2236 ∶ (ratio), U+22C5 ⋅ and the
     middle-dot family, U+2264/U+2265 ≤ ≥ and the double-arrow implication
     family ⇐ ⇒ ⇔ (confusable with `<=`, `>=`, `=>` digraph-space) — these
     are **rejected outright, never aliased**: a program containing a
     character that *looks like* `-` but isn't must fail to lex, not quietly
     mean something else;
   - anything with emoji presentation (TR31 §7.2's Emoji Profile carve-out).

Notes on the shape of this definition:

- Predicates 3–5 are applied **once**, to the (frozen) Pattern_Syntax set, and
  the proposal ships the resulting **enumerated list** normatively. Block
  membership and General_Category are *derivation inputs*, not ongoing
  dependencies — later Unicode versions cannot change the list, because
  Pattern_Syntax cannot change (U§4). The gc-stability weakness of an
  "Sm-only" rule is thereby avoided.
- **NFC is required** (as it already is in identifier context); combining
  marks are excluded, so every operator is exactly one code point and maximal
  munch is trivial — there are no multi-character user operators and no
  operator is a prefix of another.
- Latin-1 candidates (± × ÷ ¬ ¦ °) fail predicate 3 deliberately. × and ÷
  read as `*` and `/` with all the aliasing questions that implies, ¬ as `!`;
  admitting them is a coherent *extension*, not part of the minimal set. Open
  question U§13.
- The result is on the order of two thousand code points — ⊞ ⊠ ⊕ ⊖ ⊗ ⊘ ⊙ ∘ ∙
  ⋄ ⋈ ∪ ∩ ⊎ ⊓ ⊔ ↦ ⇝ ⊢ ⊨ and their supplemental variants — which is the
  entire point: the ASCII inventory (§14.3) offered a handful of two-character
  sequences; this offers actual notation.

---

## 6. Grammar (U4, U5)

Binary user operators drop into the backtick level of §4's grammar (the D2
Option A slot), which becomes the level for *all* user-introduced infix:

```
infix-expression:                       // §4's backtick-expression, widened
    cast-expression
    infix-expression ` operator-expression ` cast-expression
    infix-expression user-operator cast-expression

unary-expression:
    ...existing productions...
    user-operator cast-expression       // prefix form (U5)
```

where *user-operator* is any single code point in the U1 set. One precedence
level, left-associative, operands are cast-expressions; a prefix user operator
binds like the other unary operators, tighter than any binary.

Disambiguation between the infix and prefix productions is by grammatical
position, exactly as for `-` (and as D10 disambiguates escape vs infix):
post-operand → infix; operand position → prefix. The expression grammar
strictly alternates operand and operator positions, so the two never coincide.

```cpp
-a ⊞ -b            // operator⊞(-a, -b)                 symmetric (D2/§4)
a * b ⊞ c          // a * operator⊞(b, c)               ⊞ binds tighter than *
a ⊞ b `f` c        // f(operator⊞(a, b), c)             shared level, left-assoc
a ⊞ ⊖b             // operator⊞(a, operator⊖(b))        prefix in operand position
⊖a ⊞ b             // operator⊞(operator⊖(a), b)        same, on the left
```

What does *not* appear: a same-delimiter suppression flag (§5), a nesting rule
(§17.1), a slot grammar (D4). These operators are ordinary distinct tokens and
the ordinary operator-precedence machinery handles them; parsing is the *easy*
part of this feature, easier even than backtick.

---

## 7. Declarations, lookup, desugaring (U2, U3, U6)

**Declaring.** *operator-function-id* grows one production: `operator`
followed by a user-operator token. Everything downstream is the existing
machinery: free function or member, any parameter types, templates,
`constexpr`, `= delete`, the lot. Arity selects the form (U5): two parameters
(or one, as a member) declare the infix form; one parameter (or none, as a
member) declares the prefix form — the same convention as `operator-`.
Unlike the existing operators there is **no class-or-enum parameter
requirement** (U2): that rule protects built-in meanings, and user operators
have none, so `constexpr int operator⊞(int a, int b) { return a + b; }` is
legal and `5 ⊞ 7` is 12.

**Using.** `x ⊞ y` assembles candidates exactly as an overloaded operator
does: member candidates from the left operand's class, non-member candidates
from unqualified lookup *and ADL* on both operands (U6, normative per §17.4's
rule). There are no built-in candidates. If nothing viable is found, the
diagnostic is the ordinary no-viable-overload error, naming `operator⊞` — a
use is never a *lexing* error in a translation unit with the feature on (U3);
it is at worst a lookup/overload failure, the same category of error as
`std::cout << my_type{}` without the `<<` overload.

**Desugaring.** The result *is* the call `operator⊞(x, y)` (member form:
`x.operator⊞(y)`), so D6's inheritance list — overload resolution, ADL,
templates, SFINAE, constexpr, conversions, value categories, codegen — and
D15's evaluation-order story carry over without modification.

---

## 8. Implementation sketch

The parser side is small — smaller than backtick's, since §5/§17.1 vanish
(U§6). The real work in both compilers is the same item: **the operator-name
tables are closed**, and this feature opens them.

**Clang.**

- *Lexer:* the U1 set is a static property of a code point; lex a member as a
  new token kind (e.g. `tok::user_operator`) carrying the code point, gated on
  the U7 flag. UTF-8 decoding of non-ASCII already exists on the identifier
  path; this adds a second consumer.
- *Parser:* the `prec::Level` introduced for backtick serves as-is; a
  `tok::user_operator` case joins `tok::backtick` in
  `ParseRHSOfBinaryExpression`, and a case in `ParseCastExpression` handles
  the prefix form. No suppression flag, no delimiter matching.
- *The hard part — `DeclarationName`:* overloaded operators are
  `CXXOperatorName` over the closed `OverloadedOperatorKind` enum, which is
  indexed into tables all over Sema. User operators need a new
  `DeclarationName` kind carrying the code point. The precedent is
  **`CXXLiteralOperatorName`** — `operator""_suffix` already demonstrates a
  DeclarationName kind keyed by open-ended extra data (an `IdentifierInfo`),
  threaded through declaration, lookup, and mangling. This is a real cost —
  DeclarationName plumbing fans out — but it is a *worked* precedent, not
  terra incognita.

**GCC.**

- *libcpp:* a new token type carrying the code point, gated on
  `flag_unicode_operators`; UTF-8 identifier lexing again provides the
  decoding machinery.
- *Parser:* a new case alongside the backtick level in
  `cp_parser_binary_expression`'s precedence table, plus the prefix case; no
  `backtick_is_operator_p` analogue needed.
- *The hard part —* `ansi_opname` *:* GCC's operator identifiers live in a
  fixed-size table indexed by tree code. The precedent is again literal
  operators: `cp_literal_operator_id` synthesizes an identifier
  (`operator""_suffix`) outside that table. A `cp_user_operator_id` doing the
  same for `operator⊞`, resolved through the ordinary
  `perform_koenig_lookup`-inclusive call path (the DEV-G05 correction made
  this path honest), is the parallel move.

Both implementations stay behind their flag (U7); a default build lexes these
code points exactly as today (an error outside literals), byte-identical to
upstream — the same discipline as D5.

---

## 9. ABI and mangling (U8 — open)

Prototype answer: the Itanium **vendor-extended operator** production,
`v <digit> <source-name>`, exists for exactly this — e.g. binary `⊞` mangles
as `v2` plus a code-point-derived source-name such as `op_u229E`, giving
stable, demangler-tolerated symbols for the fork. Precedents: literal-operator
suffixes mangle by derived name (`li<length><suffix>`), and `co_await` shows a
new operator earning a first-class code (`aw`) when it standardizes.

Open for a real proposal: a first-class `<operator-name>` production keyed by
code point (cross-vendor agreement in the Itanium ABI group), and the MSVC
scheme (unexamined). Mangling is the one place this feature touches ABI at
all; everything else is front-end sugar. Flagged open, not resolved.

---

## 10. Security, confusability, tooling

The objections are known in advance; pre-load the answers (§13.5 discipline).

- **Confusables / Trojan-source.** The set *by construction* excludes UTS #39
  confusables of existing tokens (U1's exclusion list) — the dangerous
  direction (a char that renders like `-` but isn't) is a lexing error, never
  a quiet alias. Math symbols are bidi-neutral, and UTS #55's source-handling
  guidance (which TR31 itself points at) covers the rest; SG16 review is the
  natural venue and P1949 established the working relationship.
- **"How do I type ⊞?"** The honest answer is Julia's answer: editor input
  methods (LaTeX-name completion — `\boxplus<TAB>` — in every major editor
  Julia touched), plus the observation that code is read far more often than
  typed. The fallback is always available: `operator⊞(a, b)` is an ordinary
  call, and a project that hates the glyphs can simply not declare any.
- **Grep and diff.** A single distinctive code point greps *better* than most
  identifiers and much better than backtick (which is shell-quoting-hostile);
  `git grep ⊞` just works. Fonts and terminals in 2026 render the math blocks
  reliably — this objection aged out with APL's era.
- **clang-format** treats a user operator as a binary/unary operator token at
  the fixed level — no §7-style delimiter pairing, no break-suppression
  zones. Strictly less work than backtick's formatting story.

---

## 11. Prior art

- **Julia** — the closest model and the load-bearing precedent for U3: the
  *parser* carries a fixed table of Unicode operator code points (parseable
  whether or not defined); users just add methods to a symbol. No fixity
  declarations. Julia demonstrates both the mechanism and two decades of the
  input-method story at scale. Divergence: Julia buckets its table into many
  precedence classes mirroring math convention; U9 deliberately declines that
  (one level, parenthesize) for the D1/D2 teachability reasons.
- **Swift** — custom operators from a Unicode operator character set, but
  *declaration-gated parsing* (`infix operator ⊕: PrecedenceGroup`) plus
  precedencegroups plus whitespace-sensitivity rules for prefix/postfix. The
  cautionary tale on all three counts: parse-depends-on-declarations is
  impossible in C++'s phase structure (U3), precedencegroups reintroduce the
  fixity-travel problem (U9), and postfix is what forces the whitespace rules
  (U5 declines postfix instead).
- **Haskell** — arbitrary symbolic operators with `infixl 0–9` fixity
  declarations; the fixity must be *known to parse*, so it travels with
  imports — the module-boundary problem U9 names. (Backtick took Haskell's
  named-infix side; this takes the symbolic side while refusing the fixity
  side.)
- **OCaml** — user symbolic operators whose fixity is *derived from the first
  character*, fixed by the language: existence proof that programmers accept
  fixed, non-declarable fixity for user operators.
- **Fortress** — already cited (§14.5, §19.1) for named operators; its
  fuller ambition was exactly mathematical Unicode notation. It died with its
  project, not with this idea.
- **Raku** — user-defined operators via grammar mutation, the far end of the
  spectrum and the anti-goal: this sketch adds *no* user-extensible grammar,
  only a wider fixed token set.
- **APL** — the historical objection ("write-only glyph soup") and the
  historical rebuttal: APL's glyphs were *primitive and unsearchable*; these
  are user-*named* functions (`operator⊞` has a declaration you can go read)
  in standard Unicode with standard input methods.

---

## 12. Relation to backtick; scope

Complementary, not competing — the same relationship §15 establishes with
`|>`, one layer up:

- **Backtick**: any *name*, zero declarations, ceremony at the use site
  (`` a `boxplus` b ``). The general facility.
- **This**: fixed symbol set, declaration required, notation at the use site
  (`a ⊞ b`). The density upgrade for operations a library uses constantly.

They share one precedence level (U4), so mixing is unsurprising, and a library
can offer both trivially (`operator⊞` delegating to `boxplus` or vice versa).
Backtick also remains the honest baseline this proposal must beat: 90% of the
value is available today by naming the function well. The case for symbols is
the residual 10% — domains (linear algebra, lattices, relational algebra,
units) where the notation *is* the established vocabulary and `` `tensor` `` is
the transliteration.

Scope, mirroring D13/D14: pure core language, no library additions; a
**separate paper** from D4307 (separable design surface, separable fate —
backtick must not sink if EWG balks at Unicode), citing D4307's adopted
precedence/associativity/desugaring decisions as its foundation. SG16 review
before EWG.

---

## 13. Open questions

- **EWG appetite.** The feature is implementable (U§8) and groundable (U§4);
  the open question is whether the room wants user-defined *symbols* at all.
  §14.4's "the demand for new punctuators largely evaporates under backtick"
  cuts both ways here — it must be answered with the notation-density
  argument (U§12) or the paper has no motivation section.
- **Combining-mark sequences (v2).** R3c's Continue set admits Mn precisely
  for negated operators (`⊕̸`). Excluded from v1 (U1) to keep one-codepoint
  lexing; a v2 could admit `<operator, Mn*>` sequences under NFC. Needs a
  rendering/confusability story first.
- **Latin-1 stragglers.** ± × ÷ ¬ fail U1's block predicate but are the
  symbols users will ask for first. Admitting them means answering the
  aliasing question (is `×` a user operator or a confusable of `*`?) that the
  block restriction currently sidesteps.
- **Feature-test macro.** `__cpp_unicode_operators` on the usual pattern.
- **Set delivery.** Ship the frozen enumeration in normative text, or
  normatively reference R3c-plus-stated-predicates and let the enumeration be
  informative? (P1949 referenced the properties; but our predicates are
  compound, and an enumeration is auditable. Leaning: enumerate.)
- **`operator` + token adjacency.** Whether `operator ⊞` (space) and
  `operator⊞` both parse (they should — same as `operator +` / `operator+`),
  and what clang-format canonicalizes.
