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

Each decision is headed by its **slug** and is therefore a Markdown anchor;
every cross-reference links to it. `Formerly:` carries the serial number the
entry used to have, because the completed tracks' handoffs still say it and
are not rewritten. [`ops/SLUGS.md`](../ops/SLUGS.md) is the whole map.

### token-set

**Formerly:** `U1`.

**Question.** Which code points are operator tokens, and who freezes the list?

**Status.** **Proposed**

**Decision.** Operator tokens are **single non-ASCII code points** with the Pattern_Syntax property, drawn from the mathematical/arrow blocks, shipped as a **frozen enumeration pinned to Unicode 17.0**

**Why.** Pattern_Syntax is immutable *per code point* by Unicode stability policy — but not closed: 79 of its 2,760 code points are unassigned, and Unicode keeps assigning characters at them (453 since the 4.1 freeze; U§4). So the ceiling is guaranteed, the contents are not, and the list must be frozen by *this proposal*, not by Unicode. Single code point, NFC, no combining marks: keeps lexing trivial (one code point = one token), avoids the normalization/rendering questions Mn sequences drag in (negated operators like `⊕̸` are a v2 candidate, U§13). Non-ASCII by construction: every ASCII Pattern_Syntax character is already claimed or reserved by the grammar (§14). Confusables with existing punctuators are excluded by name (U§5). The standard would carry the final enumerated list normatively — the same standing as the existing UAX #31 reference for identifiers (U§4).

**Decided by.** Undecided — the whole log is Proposed until the paper is polled.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

### operator-function-id

**Formerly:** `U2`.

**Question.** What kind of entity is `operator⊞`, and which of [over.oper]'s restrictions apply to it?

**Status.** **Proposed**

**Decision.** `operator⊞` is an *operator-function-id*; an ordinary overloadable free or member function, with **no class/enum-parameter requirement**

**Why.** Exactly the existing operator-function machinery, one production wider. The explicit-call spelling `operator⊞(a, b)` works, as it does for every operator today. [over.oper]'s "at least one class or enum parameter" rule exists to protect the built-in meaning of the token — a user operator *has* no built-in meaning to protect, so `operator⊞(int, int)` is legal and `5 ⊞ 7` finds it. That is the point: the fundamental-type case (`5 ⊞ 7`) is the motivating one.

**Decided by.** Undecided — the whole log is Proposed until the paper is polled.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

**Log.** 2026-09-06 — [over-oper-restrictions](open-decisions.md#over-oper-restrictions) answered (a) by the design author. The class-or-enum waiver this entry records is **not the only [over.oper] rule that does not carry over**, and U§7 "Declaring" is owed the full enumeration: of the five restrictions, class-or-enum, no-default-arguments ([over.oper]p8) and not-variadic are all waived, the arity table has no entry to consult, and only the static-member rule is kept — and kept by choice, on the two-spellings reason, not by consequence of the arity rule. The generalization to state: **[over.oper]'s restrictions protect a token whose parse, arity and fixity the grammar already fixed, so a user operator inherits only what its own declared forms need.** Writing owed by [reconcile-declaring-using](../ops/completion/steps/reconcile-declaring-using.md).

**Log.** 2026-09-06 — written. U§7 "Declaring" now enumerates the five restrictions in a table with the generalization stated as a rule, and the kept one has its own entry, [static-member-operators](#static-member-operators). The variadic waiver was re-derived rather than taken from the row: `int operator⊞(int, int, ...)` is accepted, and the ellipsis is inert because operator syntax cannot pass a trailing argument.

### lexing-and-declarations

**Formerly:** `U3`.

**Question.** Does tokenization depend on what has been declared?

**Status.** **Proposed**

**Decision.** Lexing is **declaration-independent**: every set member is always an operator token (under [unicode-feature-gating](#unicode-feature-gating)'s flag), whether or not any `operator⊞` is in scope

**Why.** The lexer cannot consult declarations — tokenization precedes lookup (preprocessing, template bodies, header order). So the operator set is fixed by the *grammar*, not by what is declared; a use with no viable `operator⊞` fails at overload resolution with an ordinary "no match" diagnostic, exactly as an undeclared `operator+` on a class type does. This is Julia's model (fixed parse table, users define methods) and the opposite of Swift's (declaration-gated parsing), and it is the only model that works in C++ (U§11).

**Decided by.** Undecided — the whole log is Proposed until the paper is polled.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

### user-infix-precedence

**Formerly:** `U4`.

**Question.** Where do binary user operators sit in the precedence table, and how do they associate?

**Status.** **Proposed**

**Decision.** Binary user operators occupy **the backtick precedence level** ([precedence-level](backtick-operator-design.md#precedence-level) Option A): tighter than `*`, looser than unary; operands are cast-expressions; **left-associative** ([chaining-associativity](backtick-operator-design.md#chaining-associativity))

**Why.** One level for *all* user-introduced infix — named (backtick) and symbolic (this) — so mixed chains group left with no precedence table to learn. Reuses [precedence-level](backtick-operator-design.md#precedence-level)'s litigated resolution wholesale, including the symmetric-prefix property: `-a ⊞ -b` is `operator⊞(-a, -b)`. Everything §4 records in favour of Option A applies unchanged.

**Decided by.** Undecided — the whole log is Proposed until the paper is polled.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

**Log.** 2026-09-06 — [fold-over-user-infix](open-decisions.md#fold-over-user-infix) answered (a) by the design author: **a user-introduced infix operator is not a fold operator**, in v1, and the answer is the same for both features because they share this one level. `(... ⊞ N)` and `` (... `f` N) `` are ill-formed and stay so. Stated as a *decision* rather than left as the `expected expression` diagnostic it currently is, because that diagnostic reads like an oversight; U§13 has no fold entry and must gain one ([reconcile-remainder](../ops/completion/steps/reconcile-remainder.md)'s). Admitting folds later would change only ill-formed programs, so the exclusion forecloses nothing — but it is not free to keep: `Level != prec::UserInfix` in `Parser::isFoldOperator` is a **silent** guard on all four Clang branches, and a replay onto clean `main` must *add* that clause rather than rename one.

### unary-forms

**Formerly:** `U5`.

**Question.** Which unary forms exist, and what tells prefix from infix?

**Status.** **Proposed**

**Decision.** **Unary prefix** operators are declared with one parameter; prefix vs infix is disambiguated by grammatical position; **no postfix forms**

**Why.** Two independent claims, and the entry used to run them together. **Arity selects the form at the point of declaration**, as it does for `operator-` today (two operands / one as a member = infix; one / none as a member = prefix). **Grammatical position selects it at the point of use**: post-operand → infix, operand position → prefix — the same strategy as `-`, `*`, `&`, and [keyword-escape-coexistence](backtick-operator-design.md#keyword-escape-coexistence)'s escape-vs-operator split. The second needs no help from the first, which is what makes the Swift whitespace trap avoidable — and it is why a defaulted trailing parameter can make an infix-declared operator prefix-usable without anything being wrong (U§7 "Declaring"). Declining postfix eliminates the prefix/postfix ambiguity that forces Swift's whitespace-sensitivity rules; nothing mathematical is lost (postfix notation is rare outside `!`, and `!` is taken). Since there is no postfix form, there is also no postfix *diagnostic*: `a⊖` is an infix use with its right operand missing, so it is `expected expression` with the caret past the operator, character-identical to `a +;` and the same with or without a space. That is the ordinary quality of error C++ gives for an incomplete binary expression, but it is not the fixity complaint "declining postfix" leads a reader to expect. **Priced by U21 (U§13.1), which reframes the decision from "postfix is ambiguous" to "postfix is a pure extension we can decline for free":** a one-token greedy-infix rule does resolve the ambiguity without whitespace sensitivity or backtracking, and a prototype of it works — but it costs the missing-right-operand diagnostic for *every* user of the feature, forces a hand-curated normative token list whose contents move with the dialect, needs a cross-vendor Itanium change (prefix and postfix unaries share an arity, and Clang already mis-mangles `++` where GCC does not), and adds LEWG to the routing via a compiler-known `std::postfix`. Since the rule only ever reinterprets programs v1 rejects, v1 declines it without foreclosing v2.

**Decided by.** Undecided — the whole log is Proposed until the paper is polled.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

**Log.** 2026-09-06 — the writing owed by the three answers below is done, by [reconcile-declaring-using](../ops/completion/steps/reconcile-declaring-using.md). The **Why** above now carries the declaration-arity / use-position split and the plain sentence about what a postfix attempt produces; U§7 "Declaring" carries the default-argument waiver and its consequence; and the static-member choice has its own entry, [static-member-operators](#static-member-operators), because it is a decision in its own right rather than a sub-point of this one. The postfix reframing (answer 3) is U§13.1's and is [reconcile-remainder](../ops/completion/steps/reconcile-remainder.md)'s.

**Log.** 2026-09-06 — **three of decision-brief's five answers land here, and none of them changes the decision; they settle what it means.** (1) [prefix-arity-selection](open-decisions.md#prefix-arity-selection) answered (a): [over.oper]p8 stays **waived**, so a user operator may have default arguments and a defaulted trailing parameter makes an infix-declared operator usable in prefix position. This entry's "arity selects the form" therefore runs two claims together and must be split: **arity selects the form at the point of declaration, grammatical position selects it at the point of use**, and the second needs no help from the first — which is what makes the Swift trap avoidable. (2) [over-oper-restrictions](open-decisions.md#over-oper-restrictions) answered (a): static member user operators stay **rejected**, but *not* on this entry's "two parameters, or one as a member" reading. The arity rule as implemented counts operands, so `static S operator⊞(S, S)` has two and would have been accepted; the rejection is a choice, and its reason is that the desugaring equivalence is defined over exactly two spellings, `operator⊞(x, y)` and `x.operator⊞(y)`, and a static member names neither. That choice is owed a decision entry of its own (suggested slug `static-member-operators`). (3) [postfix-operators](open-decisions.md#postfix-operators) answered (a): the decline is **for v1 and explicitly not foreclosed**, argued in U§13.1's *affordable and declined* terms, not the *ambiguous* terms this entry's original rationale used. Also owed here: one plain sentence saying what a postfix attempt actually produces (`expected expression`, character-identical to `a +;`), since "declining postfix" currently implies a diagnostic that does not exist. Decided by the design author; the writing is [reconcile-declaring-using](../ops/completion/steps/reconcile-declaring-using.md)'s and [reconcile-remainder](../ops/completion/steps/reconcile-remainder.md)'s.

### static-member-operators

**Question.** May a user operator be declared as a **static** member function?

**Status.** **Proposed**

**Decision.** **No.** A user *operator function* is a non-member function or a non-static member function; a static member declaration of one is ill-formed.

**Why.** Not because the arity rule excludes it — it does not. The rule counts *operands*, so `static S operator⊞(S, S)` has two of them and would be accepted; a compiler that implements this must reject it deliberately, and the prototype does, with an explicit guard ahead of the arity check reusing the existing "cannot be a static member function" diagnostic. The reason is the desugaring, which is the whole content of the feature: `x ⊞ y` is defined to mean exactly one of **two** spellings — `operator⊞(x, y)` or `x.operator⊞(y)` — and a static member names neither. `x.operator⊞(y)` on a static member is legal C++, but it discards the object expression and passes *one* argument to a two-parameter function, so it does not mean `⊞(x, y)`; and `S::operator⊞(x, y)` would be a third spelling reached by a class-directed lookup rule that nothing in [candidate-assembly](#candidate-assembly) provides. Admitting static members would therefore not extend the equivalence, it would replace it. The C++23 `static operator()` / `static operator[]` precedent does not carry: those operators' meaning is given by the standard, which says how the object expression is treated, whereas a user operator's meaning is *only* the equivalence — there is no other place to say what a static form would do. Nothing is foreclosed: this is a restriction, and a later revision could lift it by writing down the third spelling and the lookup that finds it.

**Decided by.** The design author, 2026-09-06 — [over-oper-restrictions](open-decisions.md#over-oper-restrictions), option (a). The *decision* was never in doubt; what the answer settled is the reason, the previous one having failed inspection.

**Log.** 2026-09-06 — created by [reconcile-declaring-using](../ops/completion/steps/reconcile-declaring-using.md), which owed it. Recorded here rather than as a sub-point of [unary-forms](#unary-forms) because it is a restriction on *declarations* with a rationale of its own, and because the `static operator()` question will be asked of it directly. The superseded reason — "a static member has no implicit object parameter, so it can name neither form" — is false of the implementation as built and must not be reintroduced; see [over-oper-restrictions](../ops/unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions).

### candidate-assembly

**Formerly:** `U6`.

**Question.** How are candidates assembled for `x ⊞ y`?

**Status.** **Proposed**

**Decision.** Candidate assembly is that of the **existing overloaded operators**: member candidates + non-member candidates found by unqualified lookup and **ADL**, ranked as **one** set; no built-in candidates

**Why.** §17.4's rule carries over verbatim and stays normative: `x ⊞ y` must find every `operator⊞` the call `operator⊞(x, y)` would, including by ADL into the operands' associated namespaces — the mechanism that makes `std::cout << x` work is the mechanism that makes a library's `⊗` work on its own types. The GCC parse-time-resolution defect ([gcc-slot-adl](../ops/gcc/DEVIATIONS.md#gcc-slot-adl)) is the cautionary tale: carry the name unresolved into the call machinery. There are no built-in candidates because there are no built-in meanings ([operator-function-id](#operator-function-id)).

**Decided by.** Undecided — the whole log is Proposed until the paper is polled.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

**Log.** 2026-09-06 — three clauses of this decision are now measured rather than asserted, and U§7 "Using" carries them ([reconcile-declaring-using](../ops/completion/steps/reconcile-declaring-using.md)). (1) The three candidate sources are **one set ranked together**: with a member `operator⊘(long)` and a non-member `operator⊘(MN, int)` both visible, `MN{} ⊘ 0` picks the non-member and `MN{} ⊘ 0L` the member, so the wording now says "one set" — a member-first fallback is a different design and this distinguishes them. (2) **ADL is inherited by not writing code**: the callee is a name, never a parsed expression, and it reaches candidate assembly unresolved. (3) **"No built-in candidates" is a non-mechanism** — nothing assembles a built-in set, so there is nothing to suppress. A consequence this entry did not anticipate is recorded in U§7 "Desugaring": since the operands are the selected call's arguments, **which overload wins decides the sequencing**, and that is asked as a CWG question rather than settled here.

### unicode-feature-gating

**Formerly:** `U7`.

**Question.** One flag for both features, or one flag each?

**Status.** **Proposed**

**Decision.** Gated behind its own flag, `-funicode-operators`, independent of and composable with `-fbacktick`

**Why.** Same [feature-gating](backtick-operator-design.md#feature-gating) rationale: opt-in prototype vehicle, default build byte-identical to upstream. A separate flag because the features are separable proposals with separable fates; a translation unit may enable either, both, or neither, and [user-infix-precedence](#user-infix-precedence)'s shared precedence level must parse identically whichever subset is on.

**Decided by.** Undecided — the whole log is Proposed until the paper is polled.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

### operator-mangling

**Formerly:** `U8`.

**Question.** How does a user operator mangle?

**Status.** **Proposed — open (ABI)** — open in the sense the whole log is open, i.e. until the paper is polled. Nothing in it is undecided: what the prototype *implements* is [mangling-derivation-rule](#mangling-derivation-rule), what the paper *asks for* was answered by the author on 2026-09-06 in [abi-production-request](#abi-production-request), and the Windows gap is [microsoft-abi-position](#microsoft-abi-position).

**Decision.** Mangling: Itanium **vendor-extended operator** (`v <arity> <source-name>`) with a code-point-derived source-name, e.g. `⊞` binary → `v2` + `op_u229E`. The derivation rule — `op_u` + uppercase hex, minimum four digits, widened above the BMP — is stated in full in [mangling-derivation-rule](#mangling-derivation-rule); the example above is not the rule.

**Why.** The `v` production exists precisely for operators the grammar didn't anticipate; precedent for naming-by-derived-source-name is `li<name>` for literal-operator suffixes, and precedent for retrofitting a real code is `aw` for `co_await`. A standardized feature would want a first-class `<operator-name>` production keyed by code point **and by fixity**, which needs cross-vendor agreement — flagged open, not resolved, and the recommendation with its options and costs is [abi-production-request](#abi-production-request). MSVC has no production to borrow at all: [microsoft-abi-position](#microsoft-abi-position).

**Decided by.** The design author, 2026-09-06, on [abi-production-request](#abi-production-request) — the *ask* is settled. The entry as a whole stays Proposed on the same terms as the rest of the log: it is polled with the paper.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged. 2026-09-06 — [mangling-abi](../ops/completion/steps/mangling-abi.md) wrote U§9 out as three named subsections and put the open half in [abi-production-request](#abi-production-request) with options, costs and a recommendation; the `v`-production derivation and the Microsoft position are settled there and no longer open. 2026-09-06 — **the author answered [abi-production-request](#abi-production-request), accepting the recommendation as written**: describe the vendor-extended form as the fallback needing no ABI action *and* ask for a first-class production, as a request rather than as wording, with a fixity marker and `s` reserved so postfix stays takeable. Two facts from the ABI's prose carried the argument and are recorded there — §5.1.3 scopes `v` to vendor builtins, and the same table already spends four codes distinguishing unary from binary forms of one symbol.

### user-declared-fixity

**Formerly:** `U9`.

**Question.** May a user declare precedence or associativity?

**Status.** **Proposed**

**Decision.** **No user-declared precedence or associativity, ever**

**Why.** Fixity is the rock other designs founder on. A declared precedence is a semantic property that must travel with the name across headers, modules, and translation units; two TUs disagreeing about `a ⊕ b ⊗ c` is an ODR/IFNDR factory, and the parse of an expression comes to depend on which imports are visible (Haskell's fixity-import problem; Swift's precedencegroup conflicts). Fixed fixity makes the *parse* of any expression depend on nothing but the expression — only the *meaning* of `operator⊞` travels, and that is just ordinary lookup. This is [chaining-associativity](backtick-operator-design.md#chaining-associativity)/[precedence-level](backtick-operator-design.md#precedence-level)'s "one level, left, learn it once" argument with the alternative's failure mode named.

**Decided by.** Undecided — the whole log is Proposed until the paper is polled.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

### operator-identifier-disjointness

**Formerly:** `U10`.

**Question.** May an operator character also be an identifier character?

**Status.** **Proposed**

**Decision.** **Operator characters are never identifier characters** — the token set and the identifier set stay disjoint

**Why.** TR31 partitions syntax space from identifier space by construction, and it holds empirically: Pattern_Syntax ∩ XID_Start = Pattern_Syntax ∩ XID_Continue = ∅ in UCD 17.0. It also holds *historically* in C++: the C++11–C++20 Annex E identifier whitelist has zero overlap with Pattern_Syntax (it even carves × and ÷ out of the middle of the Latin-1 letter ranges), so no standard has ever admitted a function *named* ⊞ and no existing code can conflict (U§7.1). The function-name use is already served: `operator⊞` *is* a name — callable, address-taken, passable — Haskell's `(⊞)` section spelled the C++ way. And admitting bare-⊞ identifiers would create the design's one true ambiguity, `⊞(x)` in operand position (U§7.1), whose only resolutions are whitespace sensitivity (the Swift trap [unary-forms](#unary-forms) already declined) or worse. Composes cleanly with Clang's shipped math-identifier extension (D137051, Clang 16) and P3658R1: both admit exactly the TR31 §7.1 ID_Compat_Math sets, whose overlap with Pattern_Syntax is precisely {∂ ∇ ∞} — the three [token-set](#token-set) already cedes to the identifier side — so operator set and extended identifier set stay disjoint even with the extension on, and mangling stays structurally distinct with nothing new (U§9).

**Decided by.** Undecided — the whole log is Proposed until the paper is polled.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

**Log.** 2026-09-06 — *partly superseded the same day; the entry below corrects the struck clause. Kept, because the reword this entry asks for is the reword that was written.* [dependent-template-operator-id](open-decisions.md#dependent-template-operator-id) answered (c) by the design author, which touches this entry through the U§7.1 argument it rests on. U§7.1's fourth point — the operator-function-id "names the overload set anywhere an unqualified-id does", which is the reason a bare-identifier `⊞` would buy nothing — is **false in one position** and gets reworded rather than defended: `t.template operator⊞<int>(0)` on a dependent object expression is rejected, ~~an inherited limitation of every operator-function-id that is not a fixed `OverloadedOperatorKind` (user-defined literal operators have had it since C++11)~~ — **struck: false, see the next entry**; the limitation is this feature's own. The argument for disjointness is unaffected — the reword costs a clause and removes the one sentence in the design an implementer can falsify. Reword owed by [reconcile-declaring-using](../ops/completion/steps/reconcile-declaring-using.md); the upstream report, against the literal-operator reproducer, by [upstream-triage](../ops/completion/steps/upstream-triage.md).

**Log.** 2026-09-06 — **the reword is written, and the reason above is corrected.** [dependent-template-operator-id](open-decisions.md#dependent-template-operator-id) was re-answered (a), *reword only, no upstream report*: the literal-operator reproducer is **correctly** rejected, because [over.literal]/1 means a literal operator can never be a class member and so no valid program contains the construct. **The gap is therefore this feature's own and is not inherited from anything** — the clause "a limitation user-defined literal operators have had since C++11", which the entry above used, is false and must not be written into U§7.1 or either paper. The accurate reason, and the one U§7.1 now gives, is that Clang's dependent-template storage holds an identifier or a built-in operator kind and nothing else: the same closure-over-a-fixed-operator-table cost as the name tables and candidate assembly (U§8), reaching a third data structure. The disjointness argument is unaffected, which was the point of rewording rather than defending. Also strengthened here: the disjointness claim itself is now verified at **two** Unicode versions — the frozen 17.0 token set against identifier tables labelled 18.0 — which is the version-skew case an implementation actually faces (U§4, U§7.1).


### ucn-spellings

**Formerly:** `U11`.

**Question.** Does a universal-character-name spell an operator token?

**Status.** **Proposed**

**Decision.** **UCN spellings form operator tokens**: a universal-character-name (including `\N{...}`) designating a [token-set](#token-set) code point is that operator token

**Why.** Preserves the extended-character ≡ UCN equivalence the language maintains for identifiers, for the same reason it exists there: the escape hatch when the source encoding, font, or review tool can not carry or render the glyph — `operator\N{SQUARED PLUS}` stays writable and legible where `operator⊞` is tofu. The absence of UCN punctuators today is an accident of every punctuator being basic-character-set, not a rule to inherit; these are the first non-basic tokens. Structurally free: the UCN-designated code point takes the same phase-3 classification as a literal one on the lexer's existing UCN path (XID → identifier, [token-set](#token-set) → operator, else ill-formed), so `a\u229Eb` ≡ `a ⊞ b` (U§8).

**Decided by.** Undecided — the whole log is Proposed until the paper is polled.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

### paper-separation

**Formerly:** `U12`.

**Question.** Does this ship inside D4307, or in a paper of its own?

**Status.** **Proposed**

**Decision.** **A separate paper from D4307** — with D4307 carrying an informative future-directions appendix, and its precedence level named the *user-infix level*

**Why.** [paper-bundling](backtick-operator-design.md#paper-bundling)'s own rule decides it: bundle what shares a design surface within one committee, split what crosses committees. The measured wording overlap is one grammar production plus the precedence prose; everything else is disjoint (normative character table, UCN/identifier interplay, operator-function-id and [over.oper] changes, SG16 review, ABI note — none of which backtick touches). The routing differs (SG16 and the ABI group vs EWG/CWG alone), the maturity differs (two implementations vs none — bundling dilutes D4307's strongest asset), and the fates must stay separable: Unicode-allergy is real in the room and must not be able to sink backtick. The shared-discussion value is recovered without coupling: D4307 presents one *user-infix level* with an informative appendix showing this direction, EWG banks the shared decisions (one level, left-assoc, desugar-to-call) once with the whole landscape visible, and this paper inherits them as adopted precedent (U§12).

**Decided by.** Undecided — the whole log is Proposed until the paper is polled.

**Log.** 2026-09-05 — retired the serial number in favour of this slug; wording unchanged.

---

## 3. What transfers from backtick

The backtick project's settled decisions map onto this feature almost
one-for-one; the table records the mapping so the sketch doesn't re-litigate
what is already litigated.

| Backtick | Here | Note |
|----------|------|------|
| [chaining-associativity](backtick-operator-design.md#chaining-associativity) left-associative | [user-infix-precedence](#user-infix-precedence) | Verbatim. |
| [precedence-level](backtick-operator-design.md#precedence-level) / §4 precedence (Option A) | [user-infix-precedence](#user-infix-precedence) | Same level, shared with backtick; `-a ⊞ -b` symmetric for the §4 reasons. |
| [slot-grammar](backtick-operator-design.md#slot-grammar) slot = assignment-expression | — | No slot: the operator *is* the token. The whole slot-grammar question vanishes. |
| [feature-gating](backtick-operator-design.md#feature-gating) flag-gated | [unicode-feature-gating](#unicode-feature-gating) | Own flag. |
| [desugaring-target](backtick-operator-design.md#desugaring-target) desugar to a call | [operator-function-id](#operator-function-id)/[candidate-assembly](#candidate-assembly) | Call to `operator⊞` via operator-style candidate assembly rather than a slot expression. |
| [braced-init-operands](backtick-operator-design.md#braced-init-operands) no braced-init-list operands | carried | Operands are cast-expressions ([user-infix-precedence](#user-infix-precedence)), so excluded the same way. |
| [keyword-escape-coexistence](backtick-operator-design.md#keyword-escape-coexistence) position disambiguation | [unary-forms](#unary-forms) | Reused for prefix-vs-infix instead of escape-vs-infix. |
| [evaluation-order](backtick-operator-design.md#evaluation-order) evaluation order is the call's | carried | It is just `operator⊞(x, y)`; [expr.call] wholesale, nothing new. |
| [type-name-slot](backtick-operator-design.md#type-name-slot) type-name in the slot | — | No slot, no analogue. |
| §5 same-delimiter problem | **does not arise** | Each operator is one distinct token, not a matched pair. No `BacktickIsOperator` analogue, no suppression flag, nothing. |
| §17.1 nesting vs chaining | **does not arise** | No delimiters to nest; chains are ordinary left-associative operator chains. |
| §17.4 ADL is normative | [candidate-assembly](#candidate-assembly) | Verbatim, with [gcc-slot-adl](../ops/gcc/DEVIATIONS.md#gcc-slot-adl) as the recorded pitfall. |

Two things do **not** transfer, and they are the feature's real costs:

1. **A declaration is required.** Backtick needs no new declaration form; this
   needs `operator⊞` to be declarable, which touches declarators, name
   mangling ([operator-mangling](#operator-mangling)), and both compilers' closed operator-name tables (U§8).
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
  ask, and it drives [token-set](#token-set)'s frozen-enumeration shape.
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
- Within the [token-set](#token-set) blocks specifically: **283** post-freeze assignments, **279**
  of them General_Category Sm/So — i.e. a predicate-defined operator set,
  re-derived per Unicode version, would have grown by 279 operators since
  2005. Two code points in the [token-set](#token-set) blocks (U+2B74, U+2B75) are unassigned
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
exclusion ([token-set](#token-set)) cannot be evaluated for characters that do not exist yet, so
a predicate-defined set would auto-admit unvetted symbols. That asymmetry —
benign to the lexer, blind to the audit — is why [token-set](#token-set) freezes an enumeration
pinned to a named Unicode version instead of tracking the predicate, and why
adopting later additions is a deliberate act of a future revision (U§13),
not an automatic consequence of a UCD update.

**The audit is reproducible, and that is now checked rather than asserted.**
`docs/pattern-syntax-audit.py` derives every number above, and the frozen
token set with them, from five UCD 17.0.0 files that live in no repo.
`docs/ucd-17.0.0.sha256` records their version-pinned URLs and SHA-256 hashes,
and the script refuses to derive from an input that does not match — a check
`--emit-header` performs by default, so the generated character table cannot
be rebuilt from unverified bytes by accident. Re-fetched from unicode.org on
2026-09-06, the five inputs matched, and the regenerated table was
**byte-identical** to the one in the Clang branches. Freezing a set to a named
Unicode version is only worth something if the frozen bytes can be shown to be
the published ones; this is how.

**Two Unicode versions are in play at once, and that separation is the
design, not an oversight.** The [token-set](#token-set) list is frozen at UCD 17.0.0 **by this
proposal**; an implementation's *identifier* tables track whatever UCD
version that implementation has adopted, which in the prototype's host
compiler is already Unicode 18.0. The two are deliberately not coupled: the
operator list is normative text that a future revision moves by an explicit
act, while identifier space rides Unicode's schedule under the grows-only XID
guarantee. What the skew buys is a stronger check than a single-version one —
the disjointness the whole design rests on has been verified with the frozen
17.0 set on one side and an 18.0 identifier set on the other (U§7.1), which
is the configuration a real implementation actually faces. Had the frozen set
been defined by a *predicate* rather than enumerated, that check would have
had nothing stable to run against.

One more consequence of R3c worth stating: since Pattern_Syntax includes the
ASCII operator characters (`+ < | !` …), R3c does not hand C++ a usable set
directly. Every ASCII member is already a token, a token prefix, or blocked by
the adjacency rules §14.1 catalogues. The usable pool is exactly
**Pattern_Syntax minus ASCII** — which is why this sketch is the non-ASCII
companion to §14, not an application of it.

---

## 5. The token set ([token-set](#token-set))

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

## 6. Grammar ([user-infix-precedence](#user-infix-precedence), [unary-forms](#unary-forms))

Binary user operators drop into the backtick level of §4's grammar (the [precedence-level](backtick-operator-design.md#precedence-level)
Option A slot), which becomes the level for *all* user-introduced infix:

```
infix-expression:                       // §4's backtick-expression, widened
    cast-expression
    infix-expression ` operator-expression ` cast-expression
    infix-expression user-operator cast-expression

unary-expression:
    ...existing productions...
    user-operator cast-expression       // prefix form (unary-forms)
```

where *user-operator* is any single code point in the [token-set](#token-set) set. One precedence
level, left-associative, operands are cast-expressions; a prefix user operator
binds like the other unary operators, tighter than any binary.

Disambiguation between the infix and prefix productions is by grammatical
position, exactly as for `-` (and as [keyword-escape-coexistence](backtick-operator-design.md#keyword-escape-coexistence) disambiguates escape vs infix):
post-operand → infix; operand position → prefix. The expression grammar
strictly alternates operand and operator positions, so the two never coincide.

```cpp
-a ⊞ -b            // operator⊞(-a, -b)                 symmetric (precedence-level/§4)
a * b ⊞ c          // a * operator⊞(b, c)               ⊞ binds tighter than *
a ⊞ b `f` c        // f(operator⊞(a, b), c)             shared level, left-assoc
a ⊞ ⊖b             // operator⊞(a, operator⊖(b))        prefix in operand position
⊖a ⊞ b             // operator⊞(operator⊖(a), b)        same, on the left
```

What does *not* appear: a same-delimiter suppression flag (§5), a nesting rule
(§17.1), a slot grammar ([slot-grammar](backtick-operator-design.md#slot-grammar)). These operators are ordinary distinct tokens and
the ordinary operator-precedence machinery handles them; parsing is the *easy*
part of this feature, easier even than backtick.

---

## 7. Declarations, lookup, desugaring ([operator-function-id](#operator-function-id), [lexing-and-declarations](#lexing-and-declarations), [candidate-assembly](#candidate-assembly))

**Declaring.** *operator-function-id* grows one production: `operator`
followed by a user-operator token. Everything downstream is the existing
machinery: free function or member, any parameter types, templates,
`constexpr`, `= delete`, the lot — including the motivating case,
`constexpr int operator⊞(int a, int b) { return a + b; }`, so that `5 ⊞ 7`
is 12.

*Which of [over.oper]'s restrictions carry over.* This design used to name
one departure from [over.oper], the class-or-enum parameter requirement.
Building the declaring side showed the departure is nearly total.
[over.oper] imposes five restrictions on an operator function; a user
operator inherits exactly one of them, and keeps a second by choice:

| [over.oper] restriction | For a user operator |
|---|---|
| at least one class-or-enum parameter | **waived** — the rule protects a token's built-in meaning and a user operator has none ([operator-function-id](#operator-function-id)) |
| no default arguments ([over.oper]p8) | **waived** — with a consequence, below, that is intended rather than tolerated |
| not variadic | **waived** — `int operator⊞(int, int, ...)` is accepted; operator syntax cannot pass a trailing argument, so the ellipsis is inert |
| the arity fixed for the token | **inherited**, and it is the only rule with content: counting the implicit object parameter, one operand declares the prefix form and two the infix form |
| not a static member | **kept, by choice** — [static-member-operators](#static-member-operators) |

Stated as a rule rather than as a list: **[over.oper]'s restrictions protect
a token whose parse, arity and fixity the grammar has already fixed. A user
operator's grammar fixes only its arity, so arity is the only restriction it
inherits.** Default arguments and variadic parameter lists then fall out as
*allowed by derivation* rather than by fiat. That matters more than it looks:
the prototype reached the same place by omission — nothing rejects a default
argument on a user operator because nothing rejects one on an ordinary
function — and a waiver arrived at by omission is not a decision until it is
written down.

*Arity and position are independent claims, and each does its own work.*
[unary-forms](#unary-forms) says "arity selects the form"; that runs two
claims together and both are needed. **Arity selects the form at the point of
declaration. Grammatical position selects it at the point of use.** The
second needs no help from the first — a use in operand position is prefix and
a use after a complete operand is infix, and nothing consults a declaration
to decide, which is what keeps this design clear of the whitespace rule Swift
needs.

*The consequence of their independence, stated outright.* With [over.oper]p8
waived, a defaulted trailing parameter makes an **infix-declared operator
usable in prefix position**. With `constexpr int operator⊟(int a, int b = 1)`
and nothing else in scope, `⊟5` is well-formed and calls it with `b`
defaulted. That is intended, not a hole: `⊟5` *is* `operator⊟(5)`, which is
what the desugaring promises, and filtering candidates by declared arity in
the parser would break the very equivalence the design rests on
([candidate-assembly](#candidate-assembly)). Declare a genuine prefix
overload alongside and `⊠5` is ambiguous — the ordinary ambiguity of `f(int)`
against `f(int, int = 1)`, reported by overload resolution rather than by
anything this feature adds. A reader who dislikes dual-fixity operators has a
conservative option, and it is one diagnostic: reinstate p8 for user
operators, at the price of making the declaration rules a special case again.

*The one restriction kept is kept as a choice.* A static member user operator
is rejected — but not because the arity rule excludes it. That rule counts
*operands*, so `static S operator⊞(S, S)` has two and would be accepted; the
rejection is an explicit guard that runs first. Its reason is
[static-member-operators](#static-member-operators): the desugaring
equivalence is defined over exactly two spellings, `operator⊞(x, y)` and
`x.operator⊞(y)`, and a static member names neither.

**Using.** `x ⊞ y` assembles candidates the way an overloaded operator does:
member candidates from the left operand's class, non-member candidates from
unqualified lookup *and ADL* on both operands ([candidate-assembly](#candidate-assembly), normative per §17.4's
rule). There are no built-in candidates. Building it turned three parts of
that sentence from assertions into results, and each is something an
implementer can check.

- **The three sources are one candidate set, ranked together — not three
  passes with a fallback.** Measured both ways round, with a member
  `operator⊘(long) const` and a non-member `operator⊘(MN, int)` both visible:
  `MN{} ⊘ 0` selects the **non-member** and `MN{} ⊘ 0L` selects the
  **member**. Neither source is preferred; the better conversion sequence
  wins, as it does for `operator+`. This is the observable that distinguishes
  this design from a member-first-then-free-function fallback, and it is why
  the meaning of `x ⊞ y` is settled by overload resolution rather than by the
  grammar.
- **ADL is inherited by *not* writing code, and that is a measured result.**
  The callee is a name the compiler forms from the token — never an
  expression the parser resolves. The unqualified lookup is an operator-name
  lookup (it searches the non-member operator namespace by construction, so
  it cannot see members), and its result is handed to candidate assembly as
  an *unresolved* set, so argument-dependent lookup happens inside overload
  resolution with the arguments in hand. Hidden friends reachable by nothing
  else, ADL-only namespace members, augmentation of a non-viable
  ordinary-lookup set, and ADL from the instantiation context in a template
  all work, with no candidate-assembly code written for any of them. The
  *member* half is the part that had to be implemented (U§8); the ADL half
  is what you get by leaving the name alone.
- **"There are no built-in candidates" is a non-mechanism, not a rule.**
  Nothing implements it: no built-in candidate set is ever assembled for a
  user operator, so there is nothing to suppress. `1 ⊠ 2` with nothing
  declared is `use of undeclared 'operator⊠'`, and `p ⊞ n` on an `int *` and
  an `int` is the same rather than pointer arithmetic. That is the
  structural difference from `operator+`, and it is an absence rather than a
  decision taken in code.

If nothing viable is found, the diagnostic is the ordinary no-viable-overload
error, naming `operator⊞` — a use is never a *lexing* error in a translation
unit with the feature on ([lexing-and-declarations](#lexing-and-declarations));
it is at worst a lookup/overload failure, the same category of error as
`std::cout << my_type{}` without the `<<` overload.

**Desugaring.** The result *is* the call `operator⊞(x, y)`, or
`x.operator⊞(y)` when a member candidate wins, so [desugaring-target](backtick-operator-design.md#desugaring-target)'s inheritance
list — overload resolution, ADL, templates, SFINAE, constexpr, conversions,
value categories, codegen — carries over. Two qualifications, both learned by
building it.

*The desugaring is exact for a non-dependent use and needs a node to survive
a dependent one.* "Without modification" was too strong. A non-dependent use
really is an ordinary `CallExpr` or `CXXMemberCallExpr` and nothing else, but
a use with a type-dependent operand is rebuilt at instantiation, and an
ordinary call rebuilds under the rules for a *call* — which keeps ADL,
because ADL is a property of the call, and loses the **member** candidates,
because being written as an operator is a property of the syntax. So the
operator-ness of the use has to be recorded in the AST: that is what the
`UserOperatorExpr` wrapper is for, and U§8 gives the measurement. The wrapper
spans the written expression while the call inside it begins at the glyph,
the same division of labour C++20's rewritten comparisons already use; see
[source-fidelity-node](backtick-operator-design.md#source-fidelity-node) and §17.5 there.

*Evaluation order is the selected call's, which means it depends on which
overload wins.* [evaluation-order](backtick-operator-design.md#evaluation-order) is inherited, but it cannot be cited wholesale
here, because it is written for an operator whose callee is an *expression*.
Stated for this feature, it is a two-case rule, and both cases are exactly
what the corresponding spelled call gives:

- **Non-member:** the operands are the two arguments, so they are
  indeterminately sequenced in an unspecified order — `operator⊞(x, y)`.
  `-Wunsequenced` fires on `arr[i++] ⊩ i++` exactly as it does on the spelled
  call.
- **Member:** the left operand is the object expression, which is part of the
  postfix-expression, and [expr.call] sequences that before every argument —
  so `x` is sequenced before `y`. Measured in constant evaluation and in the
  emitted IR, and `-Wunsequenced` is correspondingly silent on the member
  form and on its `x.operator⊪(y)` spelling.

**So the sequencing of `x ⊞ y` is determined by overload resolution**, which
is a property no existing C++ operator has: [over.match.oper] gives an
overloaded built-in-spelled operator the *built-in's* sequencing however it
was declared, and a user operator has no built-in to borrow sequencing from.
The design takes the position that the call's rules are the right ones — they
are what the two spellings the desugaring is defined over actually mean — but
this is a question for CWG rather than something the design can settle by
itself, and it is asked in those terms rather than inherited by silence.

One sentence of [evaluation-order](backtick-operator-design.md#evaluation-order) does **not** carry over and must not be
quoted here: that the callee is sequenced before both operands, so the slot
is evaluated first. A backtick slot is an expression and can have side
effects; a Unicode operator's callee is a name, so there is no callee
subexpression for the rule to sequence. It is a backtick-only observation.

### 7.1 Operator characters as ordinary names ([operator-identifier-disjointness](#operator-identifier-disjointness))

Several languages let operator-ish characters appear in ordinary identifiers
(Lisp/Scheme famously; Agda; Julia admits a few), so the question will come
up: could a *function named* `⊞` — the bare character as an identifier —
coexist with `operator⊞`? The instinct that the uses are distinguishable by
grammatical position (the [keyword-escape-coexistence](backtick-operator-design.md#keyword-escape-coexistence) move) is mostly right; here is the full
position analysis, and where it breaks.

**First, the conflict cannot arise in C++ today — and never could have.**
Verified against the UCD and the historical standards (checks in
`pattern-syntax-audit.py`):

- **C++23 (P1949):** identifiers are XID_Start/XID_Continue, and
  Pattern_Syntax ∩ XID_Start = Pattern_Syntax ∩ XID_Continue = **∅** in
  UCD 17.0. TR31 partitions syntax space from identifier space by
  construction, precisely so parsers can classify a code point without
  context; the partition holds empirically. **It has been checked at two
  Unicode versions, which is the interesting part**: the audit script derives
  the ∅ from the published UCD 17.0.0 files, and a second, per-code-point
  sweep runs the frozen 1,381-member [token-set](#token-set) set against a compiler's *own*
  identifier tables — which are labelled **Unicode 18.0**, because a compiler
  updates its XID tables on Unicode's schedule while a frozen operator list
  does not move. Zero of the 1,381 are XID_Start, zero XID_Continue, zero in
  the math-identifier profile below, zero in the C++11–C++20 whitelist. So
  the partition survives exactly the version skew a real implementation
  lives with, which is a stronger result than the one the design originally
  claimed and is checked by a unit test rather than argued.
- **C++11 through C++20** ([charname.allowed], the Annex E whitelist): the
  allowed ranges have **zero overlap with Pattern_Syntax** — all 2,760, not
  just the [token-set](#token-set) blocks. The whitelist was generous about *future* characters
  (all of U+3031–D7FF and planes 1–14, which is how the incoherent emoji
  identifiers of the P1949 motivation got in), but it deliberately stepped
  around the syntax blocks, down to carving × (U+00D7) and ÷ (U+00F7) out
  of the middle of the Latin-1 letter ranges C0–[desugaring-target](backtick-operator-design.md#desugaring-target)/[format-break-policy](backtick-operator-design.md#format-break-policy)–F6.

So no conforming C++ program in any standard has ever contained a function
named `⊞`, and [token-set](#token-set) does not change that: the operator set is carved from
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
  ID_Compat_Math = exactly {∂, ∇, ∞}** — the three characters [token-set](#token-set) already
  excludes and cedes to the identifier side.

So even with the Clang extension enabled, the operator set and the
(extended) identifier set are disjoint: `int ∂(int, int)` is a function
named by an ordinary (extended) identifier, `int operator⊞(int, int)` is an
operator-function, and no code point is legal in both roles. The
composition rule for any *future* identifier extension falls out: take the
TR31 §7.1 side of the line, never admit a [token-set](#token-set) code point, and every lexed
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
  call vs `⊞ (x)` prefix — the Swift rule [unary-forms](#unary-forms) declined postfix specifically
  to avoid); a prefer-the-call rule (then parenthesizing a prefix operand
  *changes its meaning* — `⊞x` versus `⊞(x)` — which is worse); or
  declaration-dependent disambiguation (new ambiguity machinery in
  overload-resolution territory, for no gain).

**Fourth, the payoff of a both-classes character would be nil, because the
function-name use already exists.** `operator⊞` *is* the name of the
function: `operator⊞(a, b)` calls it, `&operator⊞` takes its address, and the
operator-function-id names the overload set where an unqualified-id does —
qualified, member and arrow calls, address-taken bare or `&`-ed, as a
non-type template argument, target-typed out of an overload set, as a pointer
to member, in templates, in SFINAE and in a *requires*-expression, all
without a production change. This is Haskell's `(⊞)` section, spelled the way
C++ has always spelled it. A bare-identifier `⊞` would buy use-site brevity
only, at the price of the design's single genuine ambiguity.

**One position is an exception, and it is worth stating rather than
defending.** As a *dependent* template name after the `template` keyword —
`t.template operator⊞<int>(0)`, with `t` of dependent type — the
operator-function-id is rejected. Every non-dependent spelling of the same
thing works, including `T{}.operator⊞<int>(0)` and a dependent call without
the disambiguator, and `t.template operator+<int>(0)` compiles, so the gap is
narrow and specific. **It is this feature's own gap, not an inherited one.**
Clang's storage for a dependent template name holds an identifier or a
built-in operator kind and nothing else, and a user operator is neither: it
is the same closure-over-a-fixed-operator-table cost as the name tables and
candidate assembly (U§8), reaching a third data structure. Nothing about the
design forces it — a third alternative in that storage would close it — but
the qualifier costs a clause and removes the one sentence here an implementer
can falsify.

Hence [operator-identifier-disjointness](#operator-identifier-disjointness): the sets stay disjoint. TR31 already made the right cut; the
proposal keeps it.

---

## 8. Implementation sketch

The parser side is small, and the measurement bears that out: the *using*
side is two cases in the existing precedence machinery, and the *declaring*
side is about ninety lines. But this section named **three** Clang work items
and the prototype needed **eight**, and the cost is not in the parser at all.
The real work in both compilers is the same item: **the operator-name tables
are closed**, and this feature opens them — in the name tables, and, above
all, in the expression node, which is the one place this feature is *more*
work than backtick. (§5/§17.1 vanish, so U§6's "parsing is the easy part"
survives; its *comparison* against backtick needs the node as a caveat.)

**Token classification is a static range table, not a predicate.** Because
[token-set](#token-set) is a frozen enumeration, the lexer never evaluates Unicode properties:
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
because [operator-identifier-disjointness](#operator-identifier-disjointness) makes the sets disjoint.

Keep the **exclusion list as a second, tiny table with reasons**, not
merely as absent entries: U+2212 in source should produce "U+2212 MINUS
SIGN is not an operator; did you mean `-`?" — and ∂ ∇ ∞ "is an identifier
character (mathematical notation profile), not an operator" — rather than
a generic stray-character error. The exclusions exist for the *reader's*
protection; the diagnostics should say so.

Two rules that fall out of single-code-point tokens. First, **UCN spellings
form operator tokens** ([ucn-spellings](#ucn-spellings)): a *universal-character-name* — including the
C++23 named form — designating a [token-set](#token-set) code point forms that operator token,
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
identifier-constituent, [token-set](#token-set) → operator token, otherwise ill-formed), so
`a\u229Eb` lexes as `a ⊞ b` exactly as `a⊞b` does. Second, **no
normalization runs at lex time** — the token is one scalar value however
spelled; NFC questions arrive only with v2's combining-mark sequences
(U§13).

**Clang — eight work items, of which this section used to name three.**
Every count below was re-measured on the `unicode-operators-upstream` branch
at `c0e07f78e679` on 2026-09-06; where a figure disagrees with one recorded
earlier in the project, the earlier one was a snapshot taken before later
steps added sites, and the greps that produce these are recorded in
[the Clang deviation ledger](../ops/unicode-operators/clang/DEVIATIONS.md).

- *Lexer:* the [token-set](#token-set) set is a static property of a code point; lex a member as a
  new token kind (e.g. `tok::user_operator`) carrying the code point, gated on
  the [unicode-feature-gating](#unicode-feature-gating) flag. UTF-8 decoding of non-ASCII already exists on the identifier
  path; this adds a second consumer.
- *Parser, using an operator:* the `prec::Level` introduced for backtick
  serves as-is; a `tok::user_operator` case joins `tok::backtick` in
  `ParseRHSOfBinaryExpression`, and a case in `ParseCastExpression` handles
  the prefix form. No suppression flag, no delimiter matching. This is the
  bullet the sketch had, and it held as written.
- *Parser, declaring an operator:* the half the sketch left out, and the
  larger of the two. `operator⊞` has to become a *name*: a new
  `UnqualifiedIdKind` with its code-point payload and its setter, one arm in
  `ParseUnqualifiedIdOperator`, one in `Sema::GetNameFromUnqualifiedId`, and
  **12 dispatch sites over `UnqualifiedIdKind` in 5 files** — about 90 lines
  across 8 files in all, which is *less* than the name-table cost below, the
  ordering this design predicts. Two findings sit inside it. **Tentative
  parsing needs an arm of its own:** `Parser::TryParseOperatorId` assumes a
  *conversion-type-id* follows anything it does not recognise, so the
  ambiguous `S operator⊛(S, S);` was re-parsed as an expression and rejected
  until a four-line case was added — and the backtick prototype needed a peer
  change in the same function for an unrelated reason, which makes *a compiler
  that separates declarations from expressions by trial parse must be told
  about any new declarator-id token* two-for-two rather than a coincidence.
  And **`TemplateIdAnnotation` has no slot for a code point**, exactly as it
  has none for a literal-operator suffix (upstream's own `// FIXME: Store name
  for literal operator too.`); `operator⊞<T>` resolves through the
  `TemplateName` instead, so nothing is wrong today.
- *The name tables — `DeclarationName`:* overloaded operators are
  `CXXOperatorName` over the closed `OverloadedOperatorKind` enum, indexed
  into tables all over Sema; a user operator needs a new `DeclarationName`
  kind carrying the code point. **`CXXLiteralOperatorName` is the worked
  precedent this section promised, and it transplanted almost line for line**
  — `operator""_suffix` is already a name kind keyed by open-ended extra data
  and threaded through declaration, lookup and mangling. The cost is **34
  dispatch sites over `DeclarationName::NameKind` across 17 files**, for
  roughly 250 lines of production code: a number small enough to be an
  argument *for* the design rather than a caveat against it. Every one of the
  34 has now been through a compiler — the last of them, in the debugger's
  expression parser, was the only hunk in the feature that no build had ever
  seen, and it compiles clean under two host compilers. But the sharp
  edge is somewhere else, and it is the sentence a committee reader wants.
  The new kind is **not a choice**: the inline 3-bit `StoredNameKind` space is
  completely full, all eight values taken, so any new kind is *forced* through
  `DeclarationNameExtra` and the literal-operator route is the only route.
  And `DeclarationNameExtra::ExtraKind` **cannot be appended to**, because its
  single field encodes an N-argument Objective-C selector as
  `ObjCMultiArgSelector + N` and clamps every value at or above that back to
  it; the new kind must be *inserted before* Objective-C's, renumbering an
  enum in a shared header. So the operator-name space is not merely closed, it
  is **packed against a variable-length encoding belonging to another
  language** — which says exactly how much of the difficulty is inherent to
  open-ended operator names (little) and how much is one compiler's
  bit-packing (most of it). One of the 34 sites is **generated**, from
  `clang/include/clang/AST/PropertiesBase.td` into
  `AbstractBasicReader/Writer.inc`, so it is not greppable as C++ and only a
  `-Wswitch` warning finds it. There is also an **identity dividend** the
  choice bought without meaning to: keying the name on the code point rather
  than on an interned spelling makes the on-disk lookup key
  context-independent, so no cross-module remapping table is needed — unlike
  the identifier- and selector-keyed kinds, whose key is a module-local ID the
  reader has to translate.
- *The expression node:* absent from this sketch, and **the strongest single
  result the prototype produced**, because here the closed table changes what
  programs *mean* rather than how much code they take.
  `CXXOperatorCallExpr` cannot be reused: it stores an
  `OverloadedOperatorKind`, and `OO_None` is a *valid* value of that enum
  rather than an absent one, so every consumer that switches on
  `getOperator()` — `TreeTransform`, `StmtPrinter`, the source-range
  accessors, CodeGen's member-call dispatch, the `isInfixBinaryOp` family, and
  the X-macro that generates their arms — would reach an `llvm_unreachable` or
  take a default arm silently. Nor can the node be **transparent**. Backtick's
  wrapper can be, because a backtick slot's meaning *is* the call it desugars
  to. This one cannot, and the reason is a language consequence rather than an
  implementation cost: a transparent wrapper is rebuilt at instantiation as an
  ordinary call, so resolution runs under [over.match.call] instead of
  [over.match.oper] — **ADL survives, because ADL is a property of the call,
  and member candidates are lost, because they are a property of the operator
  syntax.** Measured: `template <class T> auto f(T a, T b) { return a ⊕ b; }`
  with a member `operator⊕` fails at instantiation with *use of undeclared
  `operator⊕`*, and `requires(T a, T b) { a ⊕ b; }` is unsatisfied for that
  `T`. So `UserOperatorExpr` stores the code point, the arity and the
  operator's location — the whole of the "operator-ness" a use has to carry —
  and recovers its operands *as written* from the semantic form, the technique
  `CXXRewrittenBinaryOperator::getDecomposedForm` uses, which keeps
  `children()` a single edge so no operand is reachable twice. That upstream
  node is the better model throughout: it exists for exactly this reason, to
  record that an expression was *written* one way and *means* another so that
  instantiation can redo the resolution rather than replay the result.
  **The node holds its operands and not a built call, and that is a design
  answer rather than a preference:** Sema may re-wrap the result it hands back
  — a class-typed prvalue with a non-trivial destructor comes back inside a
  `CXXBindTemporaryExpr` — so a node that *is* the operator survives that, and
  a node that *hides* a call does not. The backtick prototype learned the same
  thing from the other end, by aborting in its pretty-printer on
  `` (1 `f` 2) `` for a class-typed `f`; the two features share a precedence
  level and a desugaring and must **not** share a node-representation
  strategy. Cost: **43 sites across 35 files name the node**, a fan-out on a
  completely different axis from the name tables', sharing no site with them
  and only four files. What the sites are is less interesting than which of
  them the toolchain made you find, which is
  [dispatch-obligation-taxonomy](#dispatch-obligation-taxonomy) below.
- *Serialization, modules and tooling:* also absent from this sketch, and here
  the shape is the finding rather than the size, which is small. A new
  operator-name kind owes a `DeclContext` lookup-table key and a stable hash
  that must **agree** with it — five sites that are *one* decision, not five,
  because any disagreement makes module lookup **miss silently** rather than
  fail. A new expression node owes a reader, a writer, an importer, two
  profilers and a matcher-traversal pair, of which **only the reader and the
  writer are forced by the build**. Those two were written under that force
  and were correct on their first *execution* — which did not happen until a
  PCH round-trip a step later: the toolchain forced the code and was silent
  about its correctness, which is the clearest instance in the whole track of
  the pattern [dispatch-obligation-taxonomy](#dispatch-obligation-taxonomy)
  describes. On ODR the answer is now flat: two declarations of the same
  `operator⊞` in two translation units of one module merge silently and two
  different ones are diagnosed, and both fall out of hashing the code point.
  The tooling surface is real and entirely unforced — ASTMatchers has no
  per-node requirement at all, so a new node is simply *invisible* to it until
  a matcher is written for it.
- *The code generator:* four sites in ClangIR that **no site list contained**,
  because `clang/lib/CIR/` was never built — every build directory in the
  project was configured without it, and six consecutive steps recorded the
  gap without closing it. Built, the four fail four different ways: two
  `errorNYI` naming the node; one `errorUnsupported` whose message does *not*
  name it, and which would be the hardest of the four to attribute in the
  field; and one that diagnoses and then **asserts**, because a default arm
  returns a default-constructed `LValue` and the type accessor then trips a
  null check. That last one is not the new node's — the backtick wrapper
  aborts identically at the same site, which localises it to the default arm
  and makes it an upstream observation rather than a feature cost. Three of
  the four arms are the predicted copy-paste; the fourth is a genuine design
  answer, because the model arm there diagnoses NYI and copying it would have
  been wrong: an operator returning a reference *is* a call returning a
  reference, and the `CallExpr` classes four lines above already handle it, so
  the wrapper arms recurse where the model refuses. **And the desugaring
  thesis survives its last test:** every shape — scalar, aggregate, complex,
  l-value and prefix — emits CIR *instruction for instruction identical* to
  the explicit call written out by hand, including the store through the
  pointer an l-value-returning operator returns. That is the furthest
  downstream the claim has been checked on either feature.
- *The static analyzer, which no site list contains:* `UserOperatorExpr` is a
  source-fidelity wrapper of exactly [source-fidelity-node](backtick-operator-design.md#source-fidelity-node)'s
  shape, and such a node owes the analyzer **parity with the call it desugars
  to** — seven sites, six of which the toolchain never mentions. Six are
  modelling sites that stop the analyzer seeing the wrapper as a thing that
  happens; the seventh is in the bug *reporter*, and exists because of the
  other six, since a node the CFG looks through has no program point for the
  tracker to find. Missing it made `p ⊘ 0` report a null dereference that
  `operator⊘(p, 0)` was spared, with two path notes where the call's report
  carried eight. The full account is backtick §17.6, and the fact that it is
  written up there rather than here is the finding: **both features had the
  identical defect in the identical place**, so the obligation belongs to
  wrapper nodes as such and not to either feature. These seven are *within*
  the 43 above, not additional to them: five are silent, one is the single
  `-Wswitch` site that any build log would have shown, and the seventh is the
  one no axis reaches
  ([dispatch-obligation-taxonomy](#dispatch-obligation-taxonomy)).

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
  `perform_koenig_lookup`-inclusive call path (the [gcc-slot-adl](../ops/gcc/DEVIATIONS.md#gcc-slot-adl) correction made
  this path honest), is the parallel move.

Both implementations stay behind their flag ([unicode-feature-gating](#unicode-feature-gating)); a default build lexes these
code points exactly as today (an error outside literals), byte-identical to
upstream — the same discipline as [feature-gating](backtick-operator-design.md#feature-gating).

**One wrinkle in the flag story, worth a footnote to anyone replaying the
patch: a feature whose grammar is C++-only must not have a flag that changes C
tokenization.** Both `-fbacktick` and `-funicode-operators` were accepted in C
mode and were not inert there. The Unicode flag *suppressed* the accurate
"unexpected character U+229E" diagnostic and left only the misleading recovery
error; the backtick flag was worse, because a delimited slot lets the recovery
**succeed**, so `` int f(int a, int b) { return a `g` b; } `` compiled as C
exited 0 — C accepting C++ grammar. Neither flag can ever do anything useful
outside C++: C has no `operator` keyword, so no operator can be declared and
the token has no production to appear in. The fix is one
`ShouldParseIf<cplusplus.KeyPath>` per flag, which upstream's `-freflection`
already carries; both prototypes now have it on every branch. The lesson for
the *test*, which is the transferable half: the assertion has to be that
flag-on and flag-off output are **byte-identical**, not that some particular
diagnostic appears, because for one of the two features the symptom was a
worse message and for the other it was an acceptance.

### dispatch-obligation-taxonomy

The 43 sites are worth less than the answer to a different question: **which
of them did the toolchain make you find?** Sorting them by what would have
gone wrong had each been omitted is the result, and it is not a shape anybody
predicted.

| What forces the site | Sites | What omitting it costs |
|---|---:|---|
| A link error | 6 | The build fails. Six headers declare one visitor method per node from a generated `#define STMT(Node, Base)` block and dispatch to it from a generated switch. |
| An exhaustive `switch` ending in `llvm_unreachable` | 8 | Compiles; aborts the first time the node reaches it. |
| A `-Wswitch` warning, on a build whose `LLVM_ENABLE_WERROR` is `OFF` | 2 | Found only by *reading the build log*. The second of the two was not in the log at all until a link step happened to rebuild the library it lives in. |
| Nothing at all | 19 | Silently wrong. The four scalar/complex/aggregate/constant emitters and three more in the l-value emitter, the constant evaluator, the bytecode compiler, the deserializer's allocation arm, the AST importer, two traversal hooks, the dump label — and five analyzer modelling sites, where the cost is that the analyzer stops seeing the enclosing function at all. |
| Nothing at compile time, and only in a configuration nobody had built | 4 | Latent. Three fail loudly the first time a use is compiled; the fourth aborts. |
| Nothing, and *absent* rather than wrong | 3 | The node is simply invisible to the matcher layer until somebody writes a matcher for it. |
| **Nothing — and the site exists only because another obligation was met** | 1 | See below. It is off this axis entirely. |

So the toolchain forces about a third of a new node's obligations, warns about
two, is **silent about nineteen**, hides four behind a build configuration, and
does not have an opinion about three more.

**The configuration-latent row is the one a vendor prototyping a language
change is most likely to ship without,** and it is worth stating why it exists.
Those four are the second code generator, ClangIR. Nothing about them failed to compile;
what made them latent was a CMake default, not a property of the language or of
the visitor design, and every build directory in this project had that default.
The general statement: **a new expression node's obligations are bounded by the
configuration of the tree you measure in, not by the tree.**

**Two things this axis structurally cannot see, and measurement found both
where review had not.**

First, **an obligation created by meeting another obligation** — the last row
of the table. The axis sorts sites by how *dispatch* fails, and this one is not
a dispatch site. Teaching the control-flow graph to look through the wrapper,
which the analyzer requires, is what removes the wrapper's program point;
removing its program point is what makes the bug reporter's node lookup fail;
and that abandons the whole diagnostic tracking chain before any handler runs.
Nothing forces it: no link error, no unreachable, no warning, no failing test.
It sits *below* even the warned-about sites, and it exists **only because two
earlier obligations were met correctly**. The full account is backtick §17.6,
and that it is written up there rather than here is itself the finding: both
features had it identically, so it belongs to source-fidelity wrapper nodes as
such.

Second, **whether the toolchain helps you is a property of how a site is
spelled, not of what it dispatches on.** A `switch` over a closed enum is
checked; a chain of `==` tests against the same enum is not; and the two are
interchangeable at the moment of writing. Of the 34
`DeclarationName::NameKind` sites, two are `||` chains rather than `switch`
arms — one choosing which diagnostic an empty lookup gets, one assigning
code-completion priority — and the second was walked past by six consecutive
steps. Its cost is not a crash: it is that an editor offers `operator⊞` ahead
of a data member, forever. Five of the 12 `UnqualifiedIdKind` sites have the
same spelling and the same absence of help. **An implementer estimating this
feature from the shape of the enums will under-count by exactly the sites
somebody once wrote as an `if`.**

**A note on the numbers themselves, because the paper stakes a claim on them.**
Everything above was re-measured on one branch on one day, and the categories
sum to the total by construction. The project's *first* accounting — 6 link, 8
unreachable, 1 warning, 13 silent, 28 in all — reproduces exactly and was
exactly right for the tree as it then stood; what has moved since is the tree,
not the arithmetic. But two later figures were recorded and never added up: the
`-Wswitch` category was correctly raised from 1 to 2 while the total was left
at 28, and a subsequent count then took 28 as its base, so a figure of "32
sites" circulated in this project's own notes that was short of its own inputs
before it was written, and short of the tooling, importer and analyzer sites
that had already been found. **The lesson is the same one the table teaches:
a count is only as good as the last thing that was allowed to change it,** and
a paper should quote a measurement with the date and the branch attached. The
figures in this section were taken on 2026-09-06 from the branch carrying the
Unicode feature alone, at commit `c0e07f78e679`, deliberately not from the
branch that carries both features, where a grep for a *shape* rather than a
symbol double-counts.

### closed-table-sibling-pattern

Four times in one prototype, opening a closed operator table produced a
**parallel** implementation rather than a widened one:

| What is closed | The existing thing | What the feature got |
|---|---|---|
| `OverloadedOperatorKind`, declaration checking | `CheckOverloadedOperatorDeclaration` | `CheckUserOperatorDeclaration` |
| `OverloadedOperatorKind`, candidate assembly | `CreateOverloadedBinOp` | `CreateOverloadedUserOp` |
| `OverloadedOperatorKind`, the AST node | `CXXOperatorCallExpr` | `UserOperatorExpr` |
| a static spelling table, the matcher API | `hasAnyOperatorName()` | *nothing — a refusal* |

The first three are siblings, and each was written by discovering that the
existing helper is keyed end to end on the operator kind. The fourth is the
interesting one, because it is the first where the right answer is **not** a
sibling: `hasAnyOperatorName()` returns a `StringRef` into a *static* spelling
table, and a user operator's spelling is a UTF-8 encoding of a code point that
has to be computed into a buffer, so a matcher over user operators must be
keyed on the code point and the predicate simply does not apply to it. The
matcher that does exist says so in its own documentation, which is the honest
form of the refusal.

Little of this is Clang's in particular. GCC's `ansi_opname` is a fixed-size
table indexed by tree code, and the move there is the same one:
`cp_literal_operator_id` already synthesizes an identifier *outside* that table
for `operator""_suffix`, and a `cp_user_operator_id` does it for `operator⊞`.
Two compilers, one shape.

**The consequence is the reassurance this proposal most needs to give, and it
is structural rather than promised.** Every site is parallel and no table the
existing operators are keyed on is ever widened, so **the relaxation provably
cannot leak into `operator+`.** Nothing that resolves, mangles, prints,
analyzes or generates code for a built-in or overloaded operator is touched:
the new kind is a new arm *beside* the old one everywhere it appears, and a
program that declares no user operator reaches none of them. That is a
stronger claim than "it is behind a flag", and it is strongest in the two
places where the closure has an observable *language* consequence rather than
a plumbing cost — the name tables and the expression node.

---

## 9. ABI and mangling ([operator-mangling](#operator-mangling) — open)

Mangling is the one place this feature touches ABI at all; everything else is
front-end sugar, inherited from the ordinary function the operator desugars to.
So this section has exactly three things to say, and says them in that order:
what the prototype **implements** ([mangling-derivation-rule](#mangling-derivation-rule)), what the paper should **ask**
the ABI groups for ([abi-production-request](#abi-production-request) — still open, and the only open thing here),
and what is **unexamined** ([microsoft-abi-position](#microsoft-abi-position)).

### mangling-derivation-rule

The Itanium **vendor-extended operator** production exists for operators the
grammar did not anticipate, and the prototype uses it:

```
<operator-name> ::= v <digit> <source-name>      # vendor extended operator
```

`<digit>` is the operator's **declared arity** — 1 prefix, 2 infix, counting a
member's implicit object parameter, not its parameter count. `<source-name>`
is derived from the operator's **code point**, never from a spelling, and
emitted as an ordinary `<source-name>` (decimal byte length, then the
identifier) exactly as `li <source-name>` does for a literal-operator suffix
directly above it in the same table. The derivation rule, which is the
sentence an ABI group would review and the one the paper will be quoted on:

> `op_u`, followed by the code point in **uppercase hexadecimal**, with no
> `U+` prefix, zero-padded to a **minimum of four digits** and widened as
> required above the BMP — five digits from U+10000, six from U+100000.

So U+229E → `op_u229E`, and binary `⊞` mangles as `v28op_u229E` (`v`, arity
`2`, length `8`, the name). Injectivity comes from the hex, not from the
padding: leading zeros are only ever added to reach four digits and every code
point above U+FFFF already needs five, so no two operators can derive the same
name. The rule is stated in the prototype's source beside the code, because it
is an ABI statement rather than a formatting convenience.

**Two branches of that rule are unexercised by construction, and will stay
that way while [token-set](#token-set) is frozen.** Every [token-set](#token-set) code point lies in
U+2190–U+2BFF, so every derived name is exactly four hex digits: the padding
branch and the astral widening cannot be reached without changing the token
set. That is a property of the frozen set, not a gap in testing — and it is
the first thing to exercise if a later revision admits anything above the BMP,
which the combining-mark and Latin-1 questions in U§13 would both do.

**"Demangler-tolerated" undersells the measurement.** Both `llvm-cxxfilt` and
GNU binutils `c++filt` 2.46 — a different vendor's demangler, unmodified —
render every form tested, character-identically, including nested-name,
const-qualified member, C++23 explicit-object member and template-id:

```
_Zv28op_u229E1SS_     -> operator op_u229E(S, S)
_ZNK1Tv28op_u229EES_  -> T::operator op_u229E(T) const
_Zv28op_u22A0IiEiT_S0_-> int operator op_u22A0<int>(int, int)
_ZNH1Ev28op_u2297ES_S_-> E::operator op_u2297(this E, E)
```

Existing toolchains need **no change** to inspect these symbols, which is the
first question an ABI reviewer asks and the strongest single thing the
prototype can say about the `v` production. The symbols are pure ASCII by
construction — the code point went into the name as hex — which matters more
than it looks: `nm | c++filt` already loses *extended-identifier* names today,
because `llvm-cxxfilt`'s stdin path splits its input on non-ASCII bytes. A
scheme that put UTF-8 in the mangled name would inherit that defect; this one
does not, and the operator spelling is therefore better behaved in shipped
tooling than the extended-identifier-function spelling [operator-identifier-disjointness](#operator-identifier-disjointness) declines.

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
name. (Under [operator-identifier-disjointness](#operator-identifier-disjointness) the question is doubly moot, since no code point can be
legal in both roles — but the manglings would not collide even if one
were.)

**One wrinkle in the arity digit, inherited rather than introduced.** In
`<base-unresolved-name>` position — a dependent `decltype(t.operator⊞(t))` —
the digit is the *call's* argument count, so a member infix operator whose
definition mangles `v2` mangles `on v1 …` there. Upstream does exactly the
same for the built-in operators: `decltype(t.operator+(t))` mangles `onps`,
i.e. **unary** plus, for a binary member `operator+`. It is invisible to
linkage, since the defining symbol is unaffected, and bug-compatible with what
a demangler already expects. It is also an argument about what to ask for: a
production keyed by code point and fixity has no arity digit to disagree
about.

### abi-production-request

**The question.** What does the paper ask the Itanium ABI group for? This is
the one genuinely open decision in this section, and it is the author's — the
ABI is not WG21's to legislate, so the paper is making a request, and the
choice is how strong a request to make.

**What was measured.**

- *The vendor-extended form works, end to end.* Twelve symbols pinned by a
  lit test — free, member, explicit-object, template instantiation, namespace
  scope, both ends of [token-set](#token-set) — and two independent demanglers render all of
  them (above). Nothing in the prototype needed an ABI change to ship.
- *The ABI's own prose scopes that production more narrowly than the
  prototype's use of it.* §5.1.3 *Operator Encodings*, immediately under the
  production, reads: "Vendors who define builtin **extended operators** (e.g.
  `__imag`) shall encode them as a `v` prefix followed by the operand count as
  a single decimal digit, and the name in `<length,ID>` form." A user-declared
  operator is not a vendor builtin. The prototype's encoding is grammatically
  well formed and demangles everywhere, and it is outside the stated purpose
  of the paragraph that defines it — which is exactly the argument for a
  first-class production if the feature standardizes.
- *`v <digit>` keys on arity, and arity is not fixity.* Prefix and postfix
  unary operators share arity 1, so the production cannot tell them apart —
  in a table whose own opening sentence is "Unlike Cfront, unary and binary
  operators using the same symbol have different encodings", and which spends
  four codes (`ps`, `ng`, `ad`, `de`) keeping `+`, `-`, `&` and `*` apart from
  their binary selves. Distinguishing forms of one symbol is a principle the
  ABI holds; the vendor production is simply the one place it has no room to.
  That costs v1 nothing, because v1 has no postfix. It costs v2 everything:
  postfix is **declined and explicitly not foreclosed** (U§13.1), and if
  `v <digit> <source-name>` were ever to become the *standardized* encoding,
  taking postfix later would require grafting a fixity convention onto a
  production that has no room for one — which is a cross-vendor ABI change
  made under pressure instead of one made now, in the open.
- *Fixity in mangling is easy to get wrong even where the ABI spells it out.*
  It spells it out twice: §5.1.3 gives `pp` and `mm` for the postfix forms in
  `<expression>` context, §5.1.6 *Expressions* gives `pp_ <expression>` and
  `mm_ <expression>` for the prefix ones. GCC 15.2.0 emits all four
  distinctly; **Clang emits the postfix spelling for both fixities of both
  operators**, so two function templates distinguished only by `++T{}` versus
  `T{}++` collide — `error: definition with same mangled name`. LLVM's own
  demangler already parses the trailing `_` its mangler never emits. U§13.1
  has the reproducer and the symbols. Reported upstream as
  **LLVM-ISSUE-PENDING**
  ([draft](../ops/completion/upstream-drafts/increment-decrement-mangling.md),
  not yet filed). A section arguing that the ABI needs room for fixity is a
  great deal stronger for pointing at fixity going wrong today, in the exact
  corner where the ABI *does* have room and an implementation still missed it.

**The options.**

- **(a) Describe the vendor-extended form and ask for nothing.** The paper
  says what is implemented, observes that it needs no ABI action, and stops.
- **(b) Ask for a first-class `<operator-name>` production, and say what it
  should look like.** The paper carries the derivation rule as a proposal to
  the ABI group, keyed by code point and carrying a fixity marker.
- **(c) Say nothing normative and mark it a known gap** for the ABI groups —
  what this section said before it was written out.

**The cost of each.**

- **(a)** is cheapest and is the honest description of what was built, and it
  has two real defects. Nothing fixes the *derivation* across vendors, so two
  implementations shipping the feature would each pick an `op_u…` convention
  and disagree silently — a mangled name is a linker-visible contract, and
  "whatever the prototype did" is not one. And it quietly resolves the postfix
  question the wrong way: adopting an arity-keyed encoding as the answer
  forecloses the fixity distinction that U§13.1 was careful to keep open. The
  ABI's own scoping of `v` to vendor builtins makes it awkward on its own
  terms besides.
- **(b)** costs a commitment the paper may be argued out of, and it needs a
  second body: the Itanium ABI group is not WG21, works on its own calendar,
  and a Microsoft answer would still be missing ([microsoft-abi-position](#microsoft-abi-position)). Against
  that, it is the only option that produces one encoding for everybody, and
  the only one that keeps postfix takeable. The delta being asked for is
  small — see the shape below — which is what makes it plausible to ask.
- **(c)** is the weakest of the three and the easiest to write. "This is a
  gap" invites precisely the question the prototype already has an answer to,
  and it spends the strongest evidence in the section (two demanglers,
  unmodified, rendering ten symbol forms) on nothing.

**Recommendation: (a) and (b) together, non-normatively.** Describe the
vendor-extended form as *the fallback that needs no ABI action* — that it
exists is a genuine result, because it means the feature is implementable and
inspectable with today's toolchains — and then ask the ABI group for a
first-class production, with a concrete shape, marked explicitly as a request
rather than as proposed wording. The shape to ask for is the `v` production
with the vendor digit replaced by a fixity marker and the vendor prefix
replaced by a standard code:

```
<operator-name> ::= uo <fixity> <source-name>    # user-defined operator
<fixity>        ::= i                            # infix
                ::= p                            # prefix
                ::= s                            # postfix (reserved; no v1 spelling)
```

Three things about that shape are load-bearing and the letters are not; the
ABI group picks the letters.

1. **The fixity marker is the whole point of asking.** It is what `v <digit>`
   cannot express, it is what §5.1.3/§5.1.6 already found necessary for `++`
   and `--`, and reserving `s` now is what lets a later revision take postfix
   without an ABI change. This is the clause the
   [postfix-operators](../ops/unicode-operators/clang/DEVIATIONS.md#postfix-operators)
   ledger row leaves to this section: v1 declines postfix, and declining it costs nothing later *only
   if* the encoding it standardizes has somewhere to put the distinction.
2. **The name stays the ASCII hex derivation**, not the operator's UTF-8
   bytes, even though UTF-8 would demangle to `operator⊞` and read better.
   The derivation is injective and mechanical, so a demangler that wants to
   print the glyph can invert it; whereas putting non-ASCII into symbol names
   buys that prettiness at the cost of every tool in the pipeline, one of
   which — `llvm-cxxfilt` on stdin — is measurably broken for exactly this
   today. Pretty demangling is a demangler feature; it should not be bought
   with a mangling decision.
3. **It is a small delta from something the ABI already has.** Same arity of
   payload, same `<source-name>` encoding, same position in the table as
   `li <source-name>`; only the key changes, from *which vendor invented this
   builtin* to *which code point, in which fixity*. Asking for a production
   nobody has to invent machinery for is a different conversation from asking
   for a new mangling scheme.

**Answered 2026-09-06 by the design author: the recommendation above, as
written.** Describe the vendor-extended form as the fallback that needs no ABI
action, then ask the ABI group for a first-class production with the shape
sketched above — **marked explicitly as a request rather than as proposed
wording**, since the Itanium ABI is not WG21's to legislate — with `s`
reserved so that postfix stays takeable. The letters are still the ABI group's
to pick and the paper must not present them as agreed.

So the paper's ABI section has a settled shape: *this is what we built and it
needs nothing from you; this is what we would ask for if the feature
standardizes; and this is the one question Windows still owes an answer to.*
[operator-mangling](#operator-mangling) stays `Proposed — open (ABI)` for the
reason the whole log is Proposed — it is polled with the paper, not before —
and no longer because anything here is undecided.

### microsoft-abi-position

"Unexamined" reads as *not yet looked at*. The operative fact is sharper, and
the paper should say it: **the Itanium ABI reserves a production for operators
it did not anticipate and the Microsoft ABI does not**, so a portable version
of this feature needs a Microsoft decision that Itanium does not need.

The prototype found this out at the moment the name became declarable rather
than at some future date, because `MicrosoftCXXNameMangler::mangleUnqualifiedName`
switches exhaustively over the name kind. It **declined to invent a scheme**
and reports the existing house diagnostic instead — `cannot mangle this
Unicode user-defined operator yet` — so a Windows target accepts every
*declaration*, since the name itself is representable, and rejects the first
*definition* at codegen. That behaviour is pinned by a RUN line in the
mangling test, so it is a stated position rather than an omission.

Declining to invent an ABI is a defensible answer and a committee reader will
recognize it as one; a silently invented scheme would have been the worst
available outcome, since it would have been binding on Windows the day it
shipped. So this is also the cleanest single answer to "how much does this
feature touch ABI?" — **one production on Itanium, one unanswered question on
Windows, and nothing else.**

---

## 10. Security, confusability, tooling

The objections are known in advance; pre-load the answers (§13.5 discipline).

- **Confusables / Trojan-source.** The set *by construction* excludes UTS #39
  confusables of existing tokens ([token-set](#token-set)'s exclusion list) — the dangerous
  direction (a char that renders like `-` but isn't) is a lexing error, never
  a quiet alias. Math symbols are bidi-neutral, and UTS #55's source-handling
  guidance (which TR31 itself points at) covers the rest; SG16 review is the
  natural venue and P1949 established the working relationship.
- **"How do I type ⊞?"** The honest answer is Julia's answer: editor input
  methods (LaTeX-name completion — `\boxplus<TAB>` — in every major editor
  Julia touched), plus the observation that code is read far more often than
  typed. Two fallbacks are always available: `operator⊞(a, b)` is an
  ordinary call, and the UCN spelling `operator\N{SQUARED PLUS}` ([ucn-spellings](#ucn-spellings))
  stays writable — and legible, if verbose — in any encoding and any font.
  A project that hates the glyphs can simply not declare any.
- **Grep and diff.** A single distinctive code point greps *better* than most
  identifiers and much better than backtick (which is shell-quoting-hostile);
  `git grep ⊞` just works. Fonts and terminals in 2026 render the math blocks
  reliably — this objection aged out with APL's era.
- **clang-format** treats a user operator as a binary/unary operator token at
  the fixed level — no §7-style delimiter pairing, no break-suppression
  zones. Strictly less work than backtick's formatting story.

### operator-name-caret-range

One diagnostic detail, recorded here so the paper answers it rather than being
asked it. The caret for `error: use of undeclared 'operator⊞'` underlines the
`operator` keyword and stops there — eight columns — rather than covering the
glyph as well.

**This is upstream's range for every operator-function-id, not a Unicode
one.** In stock C++23 with the feature off, `operator+(a, a)` and
`operator""_x(a)` on undeclared operators produce a caret of exactly the same
eight columns. Nothing about a multi-byte name causes it and nothing in this
proposal changes it; the glyph case is character-identical to the built-in
case, which is the only claim the paper needs to make. Tightening the range
would be a diagnostic-polish change to Clang affecting `operator+` first and
this feature only incidentally, so it is not proposed here.

- **Julia** — the closest model and the load-bearing precedent for [lexing-and-declarations](#lexing-and-declarations): the
  *parser* carries a fixed table of Unicode operator code points (parseable
  whether or not defined); users just add methods to a symbol. No fixity
  declarations. Julia demonstrates both the mechanism and two decades of the
  input-method story at scale. Divergence: Julia buckets its table into many
  precedence classes mirroring math convention; [user-declared-fixity](#user-declared-fixity) deliberately declines that
  (one level, parenthesize) for the [chaining-associativity](backtick-operator-design.md#chaining-associativity)/[precedence-level](backtick-operator-design.md#precedence-level) teachability reasons.
- **Swift** — custom operators from a Unicode operator character set, but
  *declaration-gated parsing* (`infix operator ⊕: PrecedenceGroup`) plus
  precedencegroups plus whitespace-sensitivity rules for prefix/postfix. The
  cautionary tale on all three counts: parse-depends-on-declarations is
  impossible in C++'s phase structure ([lexing-and-declarations](#lexing-and-declarations)), precedencegroups reintroduce the
  fixity-travel problem ([user-declared-fixity](#user-declared-fixity)), and postfix is what forces the whitespace rules
  ([unary-forms](#unary-forms) declines postfix instead).
- **Haskell** — arbitrary symbolic operators with `infixl 0–9` fixity
  declarations; the fixity must be *known to parse*, so it travels with
  imports — the module-boundary problem [user-declared-fixity](#user-declared-fixity) names. (Backtick took Haskell's
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

They share one precedence level ([user-infix-precedence](#user-infix-precedence)), so mixing is unsurprising, and a library
can offer both trivially (`operator⊞` delegating to `boxplus` or vice versa).
Backtick also remains the honest baseline this proposal must beat: 90% of the
value is available today by naming the function well. The case for symbols is
the residual 10% — domains (linear algebra, lattices, relational algebra,
units) where the notation *is* the established vocabulary and `` `tensor` `` is
the transliteration.

**One paper or two — the evidence ([paper-separation](#paper-separation)).** [paper-bundling](backtick-operator-design.md#paper-bundling) settled the bundling rule
for this project: bundle what shares a design surface within one committee;
split what is separable across committees. Applying it here:

- *Wording overlap is small.* Backtick's wording: one punctuator, the
  infix-expression production, the desugaring clause, the escape. This
  paper's wording: a normative ~1,381-entry character table ([token-set](#token-set)), UCN and
  identifier interaction ([operator-identifier-disjointness](#operator-identifier-disjointness) / [ucn-spellings](#ucn-spellings)), the operator-function-id extension and
  the [over.oper] class-or-enum carve-out ([operator-function-id](#operator-function-id)), and an ABI note (U§9). The
  intersection is one grammar production plus the precedence prose. The
  *rationale* overlaps heavily; the *wording* barely does.
- *The routing differs* — SG16 first, and the ABI group for [operator-mangling](#operator-mangling), neither of
  which backtick needs. By [paper-bundling](backtick-operator-design.md#paper-bundling)'s own criterion, that is a split.
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

Scope otherwise mirrors [library-scope](backtick-operator-design.md#library-scope): pure core language, no library additions; SG16
review before EWG.

---

## 13. Open questions

- **EWG appetite.** The feature is implementable (U§8) and groundable (U§4);
  the open question is whether the room wants user-defined *symbols* at all.
  §14.4's "the demand for new punctuators largely evaporates under backtick"
  cuts both ways here — it must be answered with the notation-density
  argument (U§12) or the paper has no motivation section.
- **Combining-mark sequences (v2).** R3c's Continue set admits Mn precisely
  for negated operators (`⊕̸`). Excluded from v1 ([token-set](#token-set)) to keep one-codepoint
  lexing; a v2 could admit `<operator, Mn*>` sequences under NFC. Needs a
  rendering/confusability story first.
- **Postfix operators (v2).** Answered, with a measurement, in §13.1: it is
  implementable and it is a pure extension of the v1 grammar, so v1 declines
  it without foreclosing it.
- **Latin-1 stragglers.** ± × ÷ ¬ fail [token-set](#token-set)'s block predicate but are the
  symbols users will ask for first. Admitting them means answering the
  aliasing question (is `×` a user operator or a confusable of `*`?) that the
  block restriction currently sidesteps.
- **Feature-test macro.** `__cpp_unicode_operators` on the usual pattern.
- **Track P3658R1.** If it lands, ∂ ∇ ∞ become *standard* identifier
  characters and [token-set](#token-set)'s exclusion of them stops being a courtesy to a profile
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

### 13.1 Postfix operators — the price, measured (U21)

[unary-forms](#unary-forms) declines postfix. The question comes back anyway, so here is the answer
with a number on it. Everything below was measured against Clang on the
prototype branch, not reasoned from the grammar; a throwaway implementation
of the candidate rule (68 lines, one file) was built and run on the witness
expressions, then discarded.

**The tempting design is wrong for a reason worth stating.** Partitioning [token-set](#token-set)
into an infix half and a postfix half makes fixity a property of the code
point. It is not: the code point belongs to whoever is writing the domain,
and pre-assigning its fixity pre-assigns its meaning. Fixity has to be
user-declarable or the feature is not worth having. That rules out the cheap
answer and forces the question to be about *parsing*.

**Arity cannot declare it, and the `int` dummy is unavailable.** `operator++`
tells its two forms apart by a dummy `int` parameter — `operator++(T)` is
prefix, `operator++(T, int)` is postfix ([over.inc]p1, enforced in Clang at
`SemaDeclCXX.cpp` `CheckOverloadedOperatorDeclaration`). [operator-function-id](#operator-function-id) removes the
class-or-enum parameter requirement, which makes `operator⊞(T, int)` a
perfectly ordinary *infix* operator whose right operand is an `int`. So the
convention is spent. A distinguished tag type is forced, not stylistic:

```cpp
T operator⊕(std::postfix, T t);   // postfix:  a⊕
T operator⊕(T lhs, T rhs);        // infix:    a ⊕ b
```

**`operator++` does not, in fact, solve this problem — it dodges it.** `++`
has no infix form, so after a complete operand `a++` can only be postfix and
one token of position settles it. A user operator declared both ways gives
the parser a token it cannot classify from position alone. And the dodge is
visible in the compiler: postfix-ness has no representation anywhere in
Clang. It is re-derived at every consumer from `OO_PlusPlus` plus an argument
count — `ExprCXX.cpp` `getSourceRangeImpl`, `StmtPrinter.cpp`
`VisitCXXOperatorCallExpr`, `TreeTransform.h` `RebuildCXXOperatorCallExpr`'s
`isPostIncDec` — after `SemaOverload.cpp` `CreateOverloadedUnaryOp`
synthesizes an `IntegerLiteral` `0` as a second argument precisely so that
downstream code can recover the fixity it was not told. There is no
`isPostfix()` on `CXXOperatorCallExpr` and no predicate anywhere in Clang for
"this token can begin an expression". Both would have to be written. This is
the fourth consecutive place where opening a closed operator concept costs a
*parallel* mechanism rather than a widened one.

**The candidate rule: greedy-infix.** After a complete operand, a user
operator followed by a token that can begin a *cast-expression* is infix;
otherwise it is postfix. One token of lookahead, no backtracking, no
whitespace sensitivity, and — the property that matters — the parser still
never consults a declaration ([lexing-and-declarations](#lexing-and-declarations)). Sema then resolves whichever shape the
parser produced, and a postfix shape with no postfix overload in scope is an
ordinary no-viable-overload error. It is the same greedy-operand preference
[precedence-level](backtick-operator-design.md#precedence-level)/§4 already adopted for `-a ⊞ -b` == `⊞(-a, -b)`: a second application of a
litigated rule, not a new one, which is the framing EWG needs.

**It works.** The prototype puts the decision in
`Parser::ParsePostfixExpressionSuffix` — one `case`, one `NextToken()` call.
Measured, with `⊖` declared unary:

```cpp
a ⊖;          // postfix — parses, resolves
(void)(a ⊖);  // postfix
a ⊖ / a;      // postfix, then binary /
(a ⊖) ⊗;      // postfix, chained through parentheses
a ⊞ b;        // infix, unchanged
```

**The price is four things, and only the first was expected.**

*One: the paren-forcing set is larger than "prefix-unary ∩ infix-binary".*
The real set is every token that can begin a cast-expression and could also
follow a complete operand. Measured against Clang's own dispatch
(`ParseExpr.cpp`, `ParseCastExpression`'s 135-label token switch, whose
`default:` is exactly "cannot begin a cast-expression") that is `*`, `&`,
`+`, `-`, a prefix user operator — *and* `++`, `--`, `(`, `[`, and `&&`.

```cpp
a ⊖ * b     // infix:  ⊖(a, *b)     -> "indirection requires pointer operand"
a ⊖ && b    // infix:  ⊖(a, &&b)    -> "use of undeclared label 'b'"
a ⊖ (b)     // infix:  ⊖(a, b)      -> "requires 1 argument, but 2 were provided"
a ⊖ ⊗       // infix, then ⊗ awaits an operand -> "expected expression"
(a ⊖) * b   // the workaround, in every case
```

`&&` is the one that should stop the discussion: it is a cast-expression
starter only because of the GNU address-of-label extension
(`ParseExpr.cpp`, `case tok::ampamp`, ungated in every language mode), and
`a ⊖ && b` is an entirely ordinary thing to write. The rule can of course be
specified by a hand-curated token list that puts `&&` on the terminator side
— but then it is a curated list, not a derivation, and the standard has to
carry it and re-audit it every time a token that can start an expression is
added. `^^` was added for reflection while this was being written, and its
case in Clang is gated on the language mode; `[` branches on C++ and
Objective-C; `^` on blocks. A predicate derived from the compiler's own
notion of "can begin an expression" therefore makes **the fixity of an
expression depend on the dialect**, which is a fresh violation of exactly the
property [user-declared-fixity](#user-declared-fixity) was written to protect.

*Two: the chained-postfix wart is a hard error with an unhelpful message.*
`a ⊖ ⊗` takes `⊗` as the start of an operand and then fails at the `;` with
`expected expression`, pointing at the semicolon and mentioning neither
postfix nor the fix. Unlike the backtick project's [bare-nesting-detection](../ops/DEVIATIONS.md#bare-nesting-detection), this one is
diagnosable — the parser knows it has just taken a user operator as infix and
run into a non-operand — so it is a QoI problem, not a grammatical one.

*Three, and this is the expensive one: it costs a diagnostic the whole
feature currently has.* Under greedy-infix a missing right operand is no
longer a parse error. `a ⊞ ;` becomes a well-formed postfix parse, and the
error moves to overload resolution — "no matching function for call to
`operator⊞` … requires 2 arguments, but 1 was provided" — naming a unary call
the programmer never wrote. Four existing negative tests on the prototype
branch change behaviour under the rule, and every one of them is this shape;
two are fold expressions, where the parse cascades into `expected ')'` and
`expression contains unexpanded parameter pack`. That cost is paid by every
user of the feature, not only by the ones who declare a postfix operator.

*Four: it reopens the ABI question ([operator-mangling](#operator-mangling)), and not hypothetically.* Two unary
forms have the same arity, so the [operator-mangling](#operator-mangling) prototype scheme `v <arity>
<source-name>` gives `⊖a` and `a⊖` the same mangled operator-name. The
Itanium ABI already has this problem and already solved it: the
`<expression>` production spells prefix `++` as `pp_` and postfix as `pp`.
GCC 15.2 emits both; Clang emits `pp` for both, and the collision is real —

```cpp
struct A { int operator++(); double operator++(int); };
template <class T> void f(decltype(++T{})) {}
template <class T> void f(decltype(T{}++)) {}
// clang: error: definition with same mangled name '_Z1fI1AEvDTpptlT_EE'
// gcc:   _Z1fI1AEvDTpp_tlT_EE  and  _Z1fI1AEvDTpptlT_EE
```

(The two templates need explicit instantiations — `template void f<A>(int);`
and `template void f<A>(double);` — before anything is mangled and the
collision fires. `operator--` fails identically. Re-confirmed against LLVM
trunk `72417eb739e5` on 2026-09-06; reported upstream as
**LLVM-ISSUE-PENDING** — the report is
[drafted](../ops/completion/upstream-drafts/increment-decrement-mangling.md)
and awaiting filing, and that token is the placeholder to replace with the
issue number.)

A user operator would need the same trailing-`_` convention grafted onto the
`v <arity> <source-name>` production, which is a cross-vendor ABI change on
top of a mangling [operator-mangling](#operator-mangling) already flags as open. There is one escape: if the
postfix use *synthesizes* the `std::postfix` tag as a real first argument —
`operator++(int)`'s trick, generalized — then the postfix call has two
arguments, mangles distinctly, and overload-resolves without a new mechanism.
That is the design to pursue if postfix is ever taken. It still needs a
fixity bit on the AST node, because arity no longer recovers it.

*And the library cost, which changes the paper's routing.* A
compiler-known `std::postfix` makes this library-affects-language. The
precedent is `operator<=>` and `std::strong_ordering`, and its cost in Clang
is not small: `ComparisonCategories.{h,cpp}` is 452 lines of dedicated AST
support, `Sema::CheckComparisonCategoryType` is ninety more with its own
`InvalidSTLDiagnoser`, and 26 files know about it. The consequence for the
paper is the one that matters: **LEWG joins a proposal already routed to
SG16, EWG/CWG and the ABI group.** [library-scope](backtick-operator-design.md#library-scope)'s rule — bundle what shares a design
surface within one committee, split what crosses committees — says on its own
terms that this does not belong in v1.

**Recommendation: decline postfix for v1, and say why in these terms.** Not
because it cannot be done — it can, and cheaply in code — but because
greedy-infix is a **pure extension of the v1 grammar**, so declining costs
nothing later. The rule fires only where a user operator is followed by a
token that cannot begin a cast-expression, and v1 requires a cast-expression
there; every program greedy-infix reinterprets is a program v1 rejects. That
is structural, and it is what the prototype measured: the only behaviour that
changed was in diagnostics on already-ill-formed code, and no well-formed
program changed meaning. So v1 answers the question with "one fixity per
arity, declared", v2 can answer it with "a tag type and one token of
lookahead", and nothing in v1 has to be taken back to get there — including
the fact that fixity stays user-declarable in both, which is the constraint
the whole question exists to protect.

The alternatives are worse and should be recorded as such: whitespace
sensitivity (Swift's answer, declined by [unary-forms](#unary-forms), and the reason this section
exists) makes `a ⊖ b` and `a ⊖b` different programs; a code-point partition
makes the committee choose fixity for every symbol in the table; and doing
nothing at all is what v1 does, at the cost of one paragraph in the paper
instead of a section in the standard.
