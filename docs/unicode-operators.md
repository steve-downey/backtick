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
| U1 | Operator tokens are **single non-ASCII code points** with the Pattern_Syntax property, drawn from the mathematical/arrow blocks, shipped as a **frozen enumeration pinned to Unicode 17.0** | **Proposed** | Pattern_Syntax is immutable *per code point* by Unicode stability policy — but not closed: 79 of its 2,760 code points are unassigned, and Unicode keeps assigning characters at them (453 since the 4.1 freeze; U§4). So the ceiling is guaranteed, the contents are not, and the list must be frozen by *this proposal*, not by Unicode. Single code point, NFC, no combining marks: keeps lexing trivial (one code point = one token), avoids the normalization/rendering questions Mn sequences drag in (negated operators like `⊕̸` are a v2 candidate, U§13). Non-ASCII by construction: every ASCII Pattern_Syntax character is already claimed or reserved by the grammar (§14). Confusables with existing punctuators are excluded by name (U§5). The standard would carry the final enumerated list normatively — the same standing as the existing UAX #31 reference for identifiers (U§4). |
| U2 | `operator⊞` is an *operator-function-id*; an ordinary overloadable free or member function, with **no class/enum-parameter requirement** | **Proposed** | Exactly the existing operator-function machinery, one production wider. The explicit-call spelling `operator⊞(a, b)` works, as it does for every operator today. [over.oper]'s "at least one class or enum parameter" rule exists to protect the built-in meaning of the token — a user operator *has* no built-in meaning to protect, so `operator⊞(int, int)` is legal and `5 ⊞ 7` finds it. That is the point: the fundamental-type case (`5 ⊞ 7`) is the motivating one. |
| U3 | Lexing is **declaration-independent**: every set member is always an operator token (under U7's flag), whether or not any `operator⊞` is in scope | **Proposed** | The lexer cannot consult declarations — tokenization precedes lookup (preprocessing, template bodies, header order). So the operator set is fixed by the *grammar*, not by what is declared; a use with no viable `operator⊞` fails at overload resolution with an ordinary "no match" diagnostic, exactly as an undeclared `operator+` on a class type does. This is Julia's model (fixed parse table, users define methods) and the opposite of Swift's (declaration-gated parsing), and it is the only model that works in C++ (U§11). |
| U4 | Binary user operators occupy **the backtick precedence level** (D2 Option A): tighter than `*`, looser than unary; operands are cast-expressions; **left-associative** (D1) | **Proposed** | One level for *all* user-introduced infix — named (backtick) and symbolic (this) — so mixed chains group left with no precedence table to learn. Reuses D2's litigated resolution wholesale, including the symmetric-prefix property: `-a ⊞ -b` is `operator⊞(-a, -b)`. Everything §4 records in favour of Option A applies unchanged. |
| U5 | **Unary prefix** operators are declared with one parameter; prefix vs infix is disambiguated by grammatical position; **no postfix forms** | **Proposed** | Arity selects the form, as it does for `operator-` today (two parameters / one member parameter = binary; one / none = prefix). Position disambiguates uses: post-operand → infix, operand position → prefix — the same strategy as `-`, `*`, `&`, and D10's escape-vs-operator split. Declining postfix eliminates the prefix/postfix ambiguity that forces Swift's whitespace-sensitivity rules; nothing mathematical is lost (postfix notation is rare outside `!`, and `!` is taken). |
| U6 | Candidate assembly is that of the **existing overloaded operators**: member candidates + non-member candidates found by unqualified lookup and **ADL**; no built-in candidates | **Proposed** | §17.4's rule carries over verbatim and stays normative: `x ⊞ y` must find every `operator⊞` the call `operator⊞(x, y)` would, including by ADL into the operands' associated namespaces — the mechanism that makes `std::cout << x` work is the mechanism that makes a library's `⊗` work on its own types. The GCC parse-time-resolution defect (DEV-G05) is the cautionary tale: carry the name unresolved into the call machinery. There are no built-in candidates because there are no built-in meanings (U2). |
| U7 | Gated behind its own flag, `-funicode-operators`, independent of and composable with `-fbacktick` | **Proposed** | Same D5 rationale: opt-in prototype vehicle, default build byte-identical to upstream. A separate flag because the features are separable proposals with separable fates; a translation unit may enable either, both, or neither, and U4's shared precedence level must parse identically whichever subset is on. |
| U8 | Mangling: Itanium **vendor-extended operator** (`v <arity> <source-name>`) with a code-point-derived source-name, e.g. `⊞` binary → `v2` + `op_u229E` | **Proposed — open (ABI)** | The `v` production exists precisely for operators the grammar didn't anticipate; precedent for naming-by-derived-source-name is `li<name>` for literal-operator suffixes, and precedent for retrofitting a real code is `aw` for `co_await`. A standardized feature would want a first-class `<operator-name>` production keyed by code point, which needs cross-vendor agreement — flagged open, not resolved. MSVC mangling unexamined. |
| U9 | **No user-declared precedence or associativity, ever** | **Proposed** | Fixity is the rock other designs founder on. A declared precedence is a semantic property that must travel with the name across headers, modules, and translation units; two TUs disagreeing about `a ⊕ b ⊗ c` is an ODR/IFNDR factory, and the parse of an expression comes to depend on which imports are visible (Haskell's fixity-import problem; Swift's precedencegroup conflicts). Fixed fixity makes the *parse* of any expression depend on nothing but the expression — only the *meaning* of `operator⊞` travels, and that is just ordinary lookup. This is D1/D2's "one level, left, learn it once" argument with the alternative's failure mode named. |
| U11 | **UCN spellings form operator tokens**: a universal-character-name (including `\N{...}`) designating a U1 code point is that operator token | **Proposed** | Preserves the extended-character ≡ UCN equivalence the language maintains for identifiers, for the same reason it exists there: the escape hatch when the source encoding, font, or review tool can not carry or render the glyph — `operator\N{SQUARED PLUS}` stays writable and legible where `operator⊞` is tofu. The absence of UCN punctuators today is an accident of every punctuator being basic-character-set, not a rule to inherit; these are the first non-basic tokens. Structurally free: the UCN-designated code point takes the same phase-3 classification as a literal one on the lexer's existing UCN path (XID → identifier, U1 → operator, else ill-formed), so `a\u229Eb` ≡ `a ⊞ b` (U§8). |
| U12 | **A separate paper from D4307** — with D4307 carrying an informative future-directions appendix, and its precedence level named the *user-infix level* | **Proposed** | D14's own rule decides it: bundle what shares a design surface within one committee, split what crosses committees. The measured wording overlap is one grammar production plus the precedence prose; everything else is disjoint (normative character table, UCN/identifier interplay, operator-function-id and [over.oper] changes, SG16 review, ABI note — none of which backtick touches). The routing differs (SG16 and the ABI group vs EWG/CWG alone), the maturity differs (two implementations vs none — bundling dilutes D4307's strongest asset), and the fates must stay separable: Unicode-allergy is real in the room and must not be able to sink backtick. The shared-discussion value is recovered without coupling: D4307 presents one *user-infix level* with an informative appendix showing this direction, EWG banks the shared decisions (one level, left-assoc, desugar-to-call) once with the whole landscape visible, and this paper inherits them as adopted precedent (U§12). |
| U10 | **Operator characters are never identifier characters** — the token set and the identifier set stay disjoint | **Proposed** | TR31 partitions syntax space from identifier space by construction, and it holds empirically: Pattern_Syntax ∩ XID_Start = Pattern_Syntax ∩ XID_Continue = ∅ in UCD 17.0. It also holds *historically* in C++: the C++11–C++20 Annex E identifier whitelist has zero overlap with Pattern_Syntax (it even carves × and ÷ out of the middle of the Latin-1 letter ranges), so no standard has ever admitted a function *named* ⊞ and no existing code can conflict (U§7.1). The function-name use is already served: `operator⊞` *is* a name — callable, address-taken, passable — Haskell's `(⊞)` section spelled the C++ way. And admitting bare-⊞ identifiers would create the design's one true ambiguity, `⊞(x)` in operand position (U§7.1), whose only resolutions are whitespace sensitivity (the Swift trap U5 already declined) or worse. Composes cleanly with Clang's shipped math-identifier extension (D137051, Clang 16) and P3658R1: both admit exactly the TR31 §7.1 ID_Compat_Math sets, whose overlap with Pattern_Syntax is precisely {∂ ∇ ∞} — the three U1 already cedes to the identifier side — so operator set and extended identifier set stay disjoint even with the extension on, and mangling stays structurally distinct with nothing new (U§9). |

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
- **Pattern_Syntax is immutable — per code point, not per character.** The
  Unicode Character Encoding Stability Policy
  (unicode.org/policies/stability_policy.html, "Property Value Stability",
  guarantee dating from Unicode 4.1): "The Pattern_Syntax and
  Pattern_White_Space properties are immutable code point properties, which
  means that their property values for all Unicode code points will never
  change." So no code point will ever gain or lose the property. But
  **immutable is not closed**: the frozen set deliberately *contains
  unassigned code points*, and Unicode assigns new characters at them —
  see the audit below. This distinction is the first question EWG/SG16 will
  ask, and it drives U1's frozen-enumeration shape.
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

**Immutable versus stable — what Unicode 18.0 can and cannot do.** The
distinction, audited against UCD 17.0 (`PropList.txt` × `DerivedAge.txt`,
2025-07-30), since EWG will ask for numbers:

- Pattern_Syntax is **2,760 code points**, fixed since Unicode 4.1 (2005).
  As of 17.0, **2,681** of them carry assigned characters; **79 are still
  unassigned** — reserved slots *inside* the immutable set.
- Since the 4.1 freeze, Unicode has assigned **453 new characters** at
  Pattern_Syntax code points, in nearly every release: 130 in 7.0, 48 in
  11.0, 11 in 14.0 (the U+2E55–2E5C bracket pairs), 3 in 16.0, and **one in
  17.0 itself** — U+2B96 ⮖ EQUALS SIGN WITH INFINITY ABOVE. This is by
  design, and R3c says so explicitly: "Unassigned code points are not
  characters; they are therefore excluded by this definition" — meaning the
  R3c operator set is defined over *assigned* characters and **grows** when
  a later version assigns one.
- Within the U1 blocks specifically: **283** post-freeze assignments, **279**
  of them General_Category Sm/So — i.e. a predicate-defined operator set,
  re-derived per Unicode version, would have grown by 279 operators since
  2005. Two code points in the U1 blocks (U+2B74, U+2B75) are unassigned
  today; 18.0 could fill them.
- General_Category is **not** immutable either: the stability policy permits
  gc changes that preserve a character's "fundamental identity" (only Cc,
  Co, Cs are frozen), so even the assigned side of an Sm/So predicate is
  version-dependent in principle.

So: **Unicode 18.0 cannot mint an operator-eligible character outside the
2,760, and can (and predictably will) mint them inside it.** Two consequences
for the design. First, growth is *lexically benign*: a newly assigned code
point was previously not a valid token at all, so an assignment can only make
previously-ill-formed programs well-formed — it can never change the meaning
of a valid one (the same benignity argument that lets identifiers ride
Unicode updates under the grows-only XID stability guarantee). Second,
growth is nonetheless *unauditable in advance*: the UTS #39 confusability
exclusion (U1) cannot be evaluated for characters that do not exist yet, so
a predicate-defined set would auto-admit unvetted symbols. That asymmetry —
benign to the lexer, blind to the audit — is why U1 freezes an enumeration
pinned to a named Unicode version instead of tracking the predicate, and why
adopting later additions is a deliberate act of a future revision (U§13),
not an automatic consequence of a UCD update.

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

- Predicates 3–5 are applied **once**, against UCD 17.0, and the proposal
  ships the resulting **enumerated list** normatively. Block membership and
  General_Category are *derivation inputs*, not ongoing dependencies — the
  list is frozen by fiat, because it has to be: re-running the derivation
  against a later UCD *would* yield a different set (279 Sm/So characters
  have been assigned inside these blocks since the Pattern_Syntax freeze,
  and U+2B74–2B75 are still open — U§4). Freezing the enumeration is what
  neutralizes both that growth and the gc-instability of an "Sm-only" rule.
- **NFC is required** (as it already is in identifier context); combining
  marks are excluded, so every operator is exactly one code point and maximal
  munch is trivial — there are no multi-character user operators and no
  operator is a prefix of another.
- Latin-1 candidates (± × ÷ ¬ ¦ °) fail predicate 3 deliberately. × and ÷
  read as `*` and `/` with all the aliasing questions that implies, ¬ as `!`;
  admitting them is a coherent *extension*, not part of the minimal set. Open
  question U§13.
- The result, measured against UCD 17.0 with every exclusion applied, is
  **1,381 code points in 32 contiguous ranges** (`pattern-syntax-audit.py`)
  — ⊞ ⊠ ⊕ ⊖ ⊗ ⊘ ⊙ ∘ ⋄ ⋈ ∪ ∩ ⊎ ⊓ ⊔ ↦ ⇝ ⊢ ⊨ and their supplemental
  variants — which is the entire point: the ASCII inventory (§14.3) offered
  a handful of two-character sequences; this offers actual notation.

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

### 7.1 Operator characters as ordinary names (U10)

Several languages let operator-ish characters appear in ordinary identifiers
(Lisp/Scheme famously; Agda; Julia admits a few), so the question will come
up: could a *function named* `⊞` — the bare character as an identifier —
coexist with `operator⊞`? The instinct that the uses are distinguishable by
grammatical position (the D10 move) is mostly right; here is the full
position analysis, and where it breaks.

**First, the conflict cannot arise in C++ today — and never could have.**
Verified against the UCD and the historical standards (checks in
`pattern-syntax-audit.py`):

- **C++23 (P1949):** identifiers are XID_Start/XID_Continue, and
  Pattern_Syntax ∩ XID_Start = Pattern_Syntax ∩ XID_Continue = **∅** in
  UCD 17.0. TR31 partitions syntax space from identifier space by
  construction, precisely so parsers can classify a code point without
  context; the partition holds empirically.
- **C++11 through C++20** ([charname.allowed], the Annex E whitelist): the
  allowed ranges have **zero overlap with Pattern_Syntax** — all 2,760, not
  just the U1 blocks. The whitelist was generous about *future* characters
  (all of U+3031–D7FF and planes 1–14, which is how the incoherent emoji
  identifiers of the P1949 motivation got in), but it deliberately stepped
  around the syntax blocks, down to carving × (U+00D7) and ÷ (U+00F7) out
  of the middle of the Latin-1 letter ranges C0–D6/D8–F6.

So no conforming C++ program in any standard has ever contained a function
named `⊞`, and U1 does not change that: the operator set is carved from
Pattern_Syntax, the identifier set from XID, and they can never meet.

**Second, the live extension surface: Clang already ships math identifiers,
and stays disjoint.** The user demand for operator-ish characters in
*names* is real and already answered — by exactly the TR31 §7.1 profile:

- **Clang D137051** (Corentin Jabot, landed December 2022, Clang 16):
  admits the ID_Compat_Math sets into identifiers, **on by default** in
  C++/C2x modes with an `ext_mathematical_notation` extension warning. The
  review is explicit that Sm/So operator characters (⊞ ⊕ ⊗, arrows) are
  *not* included.
- **P3658R1** "Adjust identifier following new Unicode recommendations"
  (2025) proposes the same ID_Compat_Math sets for standard C++ — necessary
  as an explicit exception precisely because ∂ ∇ ∞ carry Pattern_Syntax,
  and the stability policy forbids ever adding them to XID.
- Measured against UCD 17.0 (audit script): ID_Compat_Math_Start is 13
  code points (∂ ∇ ∞ plus ten plane-1 mathematical-style variants of ∂ and
  ∇), ID_Compat_Math_Continue is 43 (adding super/subscript digits and
  signs — none of them Pattern_Syntax), and **Pattern_Syntax ∩
  ID_Compat_Math = exactly {∂, ∇, ∞}** — the three characters U1 already
  excludes and cedes to the identifier side.

So even with the Clang extension enabled, the operator set and the
(extended) identifier set are disjoint: `int ∂(int, int)` is a function
named by an ordinary (extended) identifier, `int operator⊞(int, int)` is an
operator-function, and no code point is legal in both roles. The
composition rule for any *future* identifier extension falls out: take the
TR31 §7.1 side of the line, never admit a U1 code point, and every lexed
code point classifies as exactly one of identifier-constituent or operator
token — context-free, declaration-free.

**Third, the position analysis, had a character been in both classes.**
This is the situation the partition rule exists to prevent. Suppose one
code point `⊞` were *both* an identifier and an operator:

- *Post-operand (infix) position*: never ambiguous. An identifier cannot
  follow a complete operand, so `a ⊞ b` is the operator, full stop.
  `a ⊞ (x, y)` likewise parses one way only: `operator⊞(a, (x, y))`, whose
  right operand is a parenthesized comma expression (evaluate `x`, yield
  `y`). It *reads* like a call of a function `⊞` juxtaposed after `a` — but
  juxtaposition is not grammar, so under an identifier-only reading it is an
  error anyway, for a different reason. Visually confusable, never
  ambiguous. (QoI note for U§10: an infix RHS that is a parenthesized
  comma-expression is almost certainly this confusion; a `-Wcomma`-family
  warning would catch it.)
- *Operand position, followed by an operand*: `⊞ x` is the prefix operator
  only (identifier-then-expression is not grammar). Unambiguous.
- *Operand position, bare*: `f = ⊞;` has only the identifier reading (a
  prefix operator with no operand is an error). Unambiguous — and
  unnecessary, because `f = operator⊞;` already works (below).
- *Operand position, followed by `(`* — **the one true ambiguity**:
  `⊞(x)` is a call of the function `⊞` with argument `x`, *and* the prefix
  `operator⊞` applied to the parenthesized expression `(x)`. Both readings
  are grammatical in the same position, and they name different entities.
  Every resolution costs something real: whitespace sensitivity (`⊞(x)`
  call vs `⊞ (x)` prefix — the Swift rule U5 declined postfix specifically
  to avoid); a prefer-the-call rule (then parenthesizing a prefix operand
  *changes its meaning* — `⊞x` versus `⊞(x)` — which is worse); or
  declaration-dependent disambiguation (new ambiguity machinery in
  overload-resolution territory, for no gain).

**Fourth, the payoff of a both-classes character would be nil, because the
function-name use already exists.** `operator⊞` *is* the name of the function: `operator⊞(a, b)` calls
it, `&operator⊞` takes its address, and the operator-function-id names the
overload set anywhere an unqualified-id does — exactly as `operator+` works
for existing operators. This is Haskell's `(⊞)` section, spelled the way C++
has always spelled it. A bare-identifier `⊞` would buy use-site brevity
only, at the price of the design's single genuine ambiguity.

Hence U10: the sets stay disjoint. TR31 already made the right cut; the
proposal keeps it.

---

## 8. Implementation sketch

The parser side is small — smaller than backtick's, since §5/§17.1 vanish
(U§6). The real work in both compilers is the same item: **the operator-name
tables are closed**, and this feature opens them.

**Token classification is a static range table, not a predicate.** Because
U1 is a frozen enumeration, the lexer never evaluates Unicode properties:
the derivation (Pattern_Syntax ∩ blocks ∩ Sm/So, minus the exclusions and
the 12 emoji-presentation code points inside the blocks) runs once,
offline, and yields — against UCD 17.0 — **1,381 code points in 32
contiguous ranges**: a 256-byte sorted table, one binary search
(`pattern-syntax-audit.py` derives it). The check sits only on the
non-ASCII slow path, after UTF-8 decode, where both lexers already do
exactly this shape of lookup for extended identifiers — Clang's static
range arrays in `clang/lib/Lex/UnicodeCharSets.h` (whose XID tables run to
hundreds of ranges) and libcpp's generated `ucnid.h` tables in GCC. ASCII
sources never touch it, and the order of checks against XID is immaterial
because U10 makes the sets disjoint.

Keep the **exclusion list as a second, tiny table with reasons**, not
merely as absent entries: U+2212 in source should produce "U+2212 MINUS
SIGN is not an operator; did you mean `-`?" — and ∂ ∇ ∞ "is an identifier
character (mathematical notation profile), not an operator" — rather than
a generic stray-character error. The exclusions exist for the *reader's*
protection; the diagnostics should say so.

Two rules that fall out of single-code-point tokens. First, **UCN spellings
form operator tokens** (U11): a *universal-character-name* — including the
C++23 named form — designating a U1 code point forms that operator token,
exactly as a UCN designating an XID character participates in an identifier.
`operator\u229E`, `operator\N{SQUARED PLUS}`, and `operator⊞` are the same
declaration, and `a \N{CIRCLED TIMES} b` is `a ⊗ b`. An earlier draft of
this sketch banned UCN spellings "as for every punctuator" — wrong, and
instructively so: no punctuator has a UCN spelling because every punctuator
is basic-character-set, an accident, not a principle. These are the first
non-basic tokens, and the extended-character ≡ UCN equivalence the language
maintains for identifiers — the escape hatch for limited source encodings
and for every environment that renders math glyphs as tofu — must extend to
them. No phase-ordering wrinkle arises: the lexer's existing UCN path
already produces a code point during phase-3 token formation, and that code
point takes the same three-way classification as a literal one (XID →
identifier-constituent, U1 → operator token, otherwise ill-formed), so
`a\u229Eb` lexes as `a ⊞ b` exactly as `a⊞b` does. Second, **no
normalization runs at lex time** — the token is one scalar value however
spelled; NFC questions arrive only with v2's combining-mark sequences
(U§13).

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

**No new mangling is needed to keep operators apart from math-identifier
functions** (U§7.1): a function *named* with an extended identifier —
`int ∂(int, int)` under Clang's D137051 extension, or a hypothetical
`int ⊞(int, int)` — mangles as an ordinary `<source-name>` (decimal byte
length + UTF-8 bytes, how Itanium mangles every extended identifier today),
while `operator⊞` mangles in `<operator-name>` space (`v2…` for the
prototype, a two-letter code if standardized). The two productions are
disjoint by the mangling grammar itself — a source-name begins with a
digit, an operator-name with letters — so the declarations are structurally
distinguishable end to end: by the `operator` keyword in the declaration,
by grammatical position at the use site, and by production in the mangled
name. (Under U10 the question is doubly moot, since no code point can be
legal in both roles — but the manglings would not collide even if one
were.)

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
  typed. Two fallbacks are always available: `operator⊞(a, b)` is an
  ordinary call, and the UCN spelling `operator\N{SQUARED PLUS}` (U11)
  stays writable — and legible, if verbose — in any encoding and any font.
  A project that hates the glyphs can simply not declare any.
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

**One paper or two — the evidence (U12).** D14 settled the bundling rule
for this project: bundle what shares a design surface within one committee;
split what is separable across committees. Applying it here:

- *Wording overlap is small.* Backtick's wording: one punctuator, the
  infix-expression production, the desugaring clause, the escape. This
  paper's wording: a normative ~1,381-entry character table (U1), UCN and
  identifier interaction (U10/U11), the operator-function-id extension and
  the [over.oper] class-or-enum carve-out (U2), and an ABI note (U§9). The
  intersection is one grammar production plus the precedence prose. The
  *rationale* overlaps heavily; the *wording* barely does.
- *The routing differs* — SG16 first, and the ABI group for U8, neither of
  which backtick needs. By D14's own criterion, that is a split.
- *The maturity differs.* D4307's strongest asset is two independent
  implementations; this sketch has none. Bundling dilutes the implemented
  paper's credibility with the unimplemented half.
- *The fates must be separable.* Some of the room finds any non-ASCII token
  disqualifying; they must be able to vote that conviction without taking
  backtick down.

The cost of splitting — EWG discussing user infix twice — is recovered
structurally: D4307 names its precedence level the **user-infix level**
(not the backtick level) and carries a short **informative future-directions
appendix** pointing at this sketch. EWG then has its one
operators-and-infix discussion with the whole landscape visible and banks
the shared decisions — one level, left-associative, desugar-to-call — once;
this paper inherits them as adopted precedent instead of reopening them.

**On undercutting, and on taste.** Opening real operators does soften
§14.4's "backtick removes the motivation" argument, and the honest framing
is partition, not competition: named operations read as words —
`` f `bind` g `` — and symbols are for domains where the notation is the
established vocabulary (⊗ in linear algebra, ⋈ in relational algebra,
lattice ⊓/⊔). Writing `f ⊚ g` for bind is notation abuse; but the
standard's position on notation abuse was settled when `operator<<` shipped
on streams: the language provides the mechanism, and style guides and
clang-tidy police taste. Both papers can state the expectation as
non-normative guidance — backtick for named combinators, symbols for
established notation — without pretending the grammar can enforce it.

Scope otherwise mirrors D13: pure core language, no library additions; SG16
review before EWG.

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
- **Track P3658R1.** If it lands, ∂ ∇ ∞ become *standard* identifier
  characters and U1's exclusion of them stops being a courtesy to a profile
  and becomes a hard requirement of the identifier grammar. Either way the
  exclusion stands; only its citation changes.
- **Set delivery — settled direction: enumerate.** The U§4 audit closes
  this: a property-reference set (the P1949 model for identifiers) is
  version-dependent, because Unicode assigns new characters inside
  Pattern_Syntax in nearly every release and R3c's operator definition
  tracks assignment. Identifiers can afford that — XID has a grows-only
  stability guarantee and identifier growth is benign — but operator growth
  bypasses the confusability audit (U§4). So: a frozen enumeration, pinned
  to Unicode 17.0, in normative text. A future revision of the standard may
  adopt later-assigned symbols the way it adopts anything else —
  deliberately, by paper, after audit — and the Pattern_Syntax ceiling
  guarantees any such addition lands inside the already-reserved 2,760.
- **`operator` + token adjacency.** Whether `operator ⊞` (space) and
  `operator⊞` both parse (they should — same as `operator +` / `operator+`),
  and what clang-format canonicalizes.
