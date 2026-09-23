# P4345R1 — material from the SG16 review

Working notes for a clean R1 of *Unicode Mathematical Operators* (P4345R0),
gathered from the SG16 review of **2026-09-23** and from the measurements that
review prompted. Not a draft of the paper: a list of what has to change, what
was measured, and which parts are decided against which are still open.

Two conventions for reading this. **Measured** means a number produced here
against pinned data, and the derivation is named so it can be re-run.
**Recommended** means an inference from that data, offered and not settled.
**Decided** means the design author has ruled.

Data used by the measurements below:

- UCD 17.0.0 `PropList.txt` and `UnicodeData.txt`, fetched from the
  version-pinned URLs in [`ucd-17.0.0.sha256`](ucd-17.0.0.sha256) and verified
  against its hashes.
- `MathClass-15.txt`, revision 15, dated 2017-06-01, from
  `https://www.unicode.org/Public/math/revision-15/`.
- `confusables.txt`, UTS #39, from `https://www.unicode.org/Public/security/latest/`.
- The 1,381-code-point allowed set, parsed from
  [`unicode-operator-token-ranges.org`](unicode-operator-token-ranges.org).

The fixity objections from the same reviewer community are **not** repeated
here. They are logged in
[`unicode-operators.md`](unicode-operators.md#user-declared-fixity)'s
`user-declared-fixity` **Log.** under 2026-09-23 and indexed from §13.

---

## 1. The inclusion predicate — use MathClass, not blocks

**SG16's request.** Classify with the properties UTR #25 defines, as a subset
of Pattern_Syntax, instead of limiting the set to a list of blocks.

**Why it is right on its own terms.** §4 of the design doc says blocks "record
allocation order". Using them to mean *is a mathematical operator* is a proxy,
and it is the same shape of reasoning the paper criticises when it rejects
deriving precedence from block or range. MathClass is the assertion itself,
from the report §5 already draws the repertoire from.

**Measured**, against UCD 17.0.0 × MathClass-15:

| predicate | size | ranges | vs current |
|---|---|---|---|
| current — PS ∧ non-ASCII ∧ nine blocks ∧ `gc` Sm/So | 1,381 | 32 | — |
| keep blocks, add a MathClass screen | 1,000 | 43 | −381, +0 |
| drop blocks — PS ∧ MathClass ∈ {R,B,N,L,U,V} ∧ `gc` Sm/So | 1,134 | 61 | −381, +134 |
| also drop classes N and L | 854 | 54 | −578, +51 |

The 381 removed in every variant are the same, and none of them is defensible
in the room:

- **346 with no MathClass entry at all** — the Miscellaneous Technical and
  Miscellaneous Symbols and Arrows residue the block predicate admits: `⌫`,
  `⏨`, `⭖`.
- **27 Glyph_Part** — `⎛ ⎜ ⎝ ⌠ ⎧`, the fragments a typesetter assembles tall
  brackets from. The current set lets you declare an operator on a piece of a
  glyph.
- **8 fences, openings and closings.**

Dropping the block screen adds 134, of which 116 are outside the nine blocks:
`¬ ± × ÷` — the "Latin-1 stragglers" §13 lists as "the symbols users
will ask for first" — and about a hundred Geometric Shapes (`■ □ ▲ △ ▶ ○ ★`).
The existing exclusion list still catches `⇐ ⇒ ⇔ ≤ ≥ − ∕ ∗ ∙ ⋅ ∶ ∣ ⁄ ∇`,
because exclusions apply after the predicate.

Do **not** take the {R,B,U,V} variant. Dropping class L loses `∑ ∏ ∫ ⨁ ⨂`, and
`⨁` is a plausible user operator for a direct sum.

**Recommended.** Keep the block screen *and* add MathClass as an additional
filter — 1,000 code points in 43 ranges. That takes the whole win without
opening the Latin-1 aliasing question ("is `×` a user operator or a confusable
of `*`?") that §13 currently sidesteps on purpose. Admitting `¬ ± × ÷` is a
separate decision that deserves its own argument.

**The consistency point R1 must make explicitly.** The paper is about to use
MathClass for the repertoire while refusing it for precedence
([`user-declared-fixity`](unicode-operators.md#user-declared-fixity), 2026-09-23).
That is defensible, and it will read as inconsistent unless the reason is
stated in the same breath: the repertoire predicate is a *derivation input*
alongside `PropList`, `UnicodeData`, `DerivedAge`, `DerivedCoreProperties` and
`emoji-data`, evaluated mechanically; a precedence table would be normative
text asserting what an operator *means*. One is a classification C++ consumes,
the other is a semantic claim C++ would be making.

---

## 2. Floor and grow — the direction of drift is what matters

**SG16's request.** Define the process, the algorithm, instead of fixing a
table against an arbitrary Unicode version that may not be the one an
implementation supports. Let Unicode define the set; let implementations pick
it up as they see fit.

**The design author's framing, and the one to write from.** Drift is not
uniformly risky, and the paper currently prices it as though it were. Turning
ill-formed code into well-formed is fine. A portability base is fine. **What
is not fine is a rule that stops GCC from adding the operator Unicode 21
hypothetically adds.** A frozen enumeration does precisely that: it makes
conformance *prohibit* support for a newer Unicode, in a language that already
lets identifiers track the implementation's version.

**The normative shape that follows.**

- **Floor.** The predicate evaluated at Unicode 17.0. A conforming
  implementation accepts at least that. This is the portability base and what
  makes a program's validity predictable.
- **No ceiling.** An implementation may evaluate the predicate against any
  later Unicode it supports. GCC picking up a Unicode 21 operator is
  conforming, and not an extension it has to apologise for.
- **Exclusions are normative and bind at every version**, because they protect
  *C++ token spellings* — a fixed target no Unicode version moves. See §3.

Portability failures under this are the good kind. A Unicode 21 operator fails
on a Unicode 17 implementation with a diagnostic saying it is not an operator.
No one gets a silently different program. That is where identifiers have been
since P1949, uncontroversially.

It also shortens the normative text, which is worth saying to SG16 directly:
the standard carries a predicate, a floor version and twelve exclusions, not a
thousand-entry table. The frozen 17.0 enumeration becomes the worked example
and the floor's expansion, and `pattern-syntax-audit.py` becomes the check that
an implementation's table matches the Unicode version it claims.

### What to ask Unicode for

An editor of the Unicode specification said that if C++ were prepared to rely
on MathClass, Unicode would work to stabilize it. That offer is the most
valuable thing in the review and it can be wasted by accepting it vaguely.

Framed by direction, the ask is almost nothing. **Additions are free** — a code
point entering the operator classes was previously not a token at all, so it
can only turn ill-formed into well-formed. The only non-benign move is a code
point *leaving*: reclassified from B to G, say, or an entry dropped. That turns
working code into a syntax error. So:

1. **Once a code point is in the operator classes, it stays in them. Additions
   unrestricted.** This is strictly weaker than immutability and is the same
   shape as XID's grows-only guarantee.
2. **Normative standing**, so the standard can reference it. MathClass
   currently says of itself that it is "*NOT* formally part of the Unicode
   Character Database at this time".
3. **Maintenance.** Revision 15 is dated 2017-06-01 over a Unicode 9.0
   repertoire — eight versions stale. "Stabilize" has to include "maintain"
   before it means anything.

### What this does to the existing decision

§13's "Set delivery — settled direction: enumerate" reverses, and its stated
reason inverts, and does not merely weaken. §4 currently reads: growth is
lexically benign, *but* unauditable in advance, "that asymmetry … is why
[token-set] freezes an enumeration". Under the direction argument, benign
growth is the whole case **for** the predicate, and the audit worry is answered
by §3 — the exclusion list protects C++'s tokens, not Unicode's set. The
paragraph does not need softening. Its conclusion needs swapping, because its
own premises now point the other way.

The historical number flips with it. §4's "a predicate-defined set would have
grown by 279 operators since 2005" reads as a warning under the frozen model.
Under the predicate model it is 279 notations users would have had.

---

## 3. Confusables — measured, and the exclusion list cannot be derived

**The question.** If inclusion becomes algorithmic, can exclusion be
algorithmic too? §4 says the confusability audit "cannot be evaluated for
characters that do not exist yet, so a predicate-defined set would auto-admit
unvetted symbols". That is the objection the whole freeze rests on.

**Measured.** Of the twelve curated confusable exclusions, **five** are
derivable from UTS #39's `confusables.txt`:

| code points | UTS #39 skeleton | derivable |
|---|---|---|
| `−` `∕` `∗` `∶` `∣` | ASCII `-` `/` `*` `:` `l` | yes |
| `∙` `⋅` | `·` U+00B7, not `.` | no |
| `⇐` `⇒` `⇔` `≤` `≥` | **no entry at all** | no |

The seven failures are not gaps in the data. UTS #39 answers *what does this
look like* — homoglyphs. The exclusion list answers *what will a C++ programmer
read this as*. `⇒` is not a homoglyph of `=>`; no Unicode property says a
single glyph mimics a two-character ASCII token, because that relation exists
only relative to a language's token set. This confirms
[`confusable-spelling-provenance`](unicode-operators.md#confusable-spelling-provenance)
— "curated, hand-assigned editorial judgement, not generator output" — with a
measurement instead of an assertion.

**The consequence, and it is what makes §2 safe.** The exclusion list is not a
filter over Unicode's set. It is a list of *C++ tokens being protected*. A new
Unicode operator is admitted unless it mimics one of those, and the set of
those is C++'s and fixed. So §4's objection does not block a predicate; it
describes something the predicate never needed to do.

### `⇒` and the others stay excluded

**Decided.** SG16 gave weak support for admitting `⇒` despite its confusability
with `=>`, on the grounds that the confusion risk is practically low in a
compiled language. Declined, and **not because the risk assessment is wrong** —
because excluding now and admitting later runs ill-formed → well-formed, which
is the reversible direction, while admitting now and retracting later breaks
working code.

Record SG16's position and the reason for declining separately. The next person
to raise this should see that it was a reversibility judgement, not a
disagreement about the hazard.

**One precision to state where this is recorded.** Under floor-and-grow, an
implementation may exceed the floor on the inclusion side, but the exclusion
list binds at every version. So "adding is easy" means easy for WG21, by a
paper striking a line from the list — an implementer cannot unilaterally enable
`operator⇒`. That is deliberate: implementations disagreeing about whether
`a ⇒ b` is a user operator or a syntax error *would* be a meaning-changing
divergence and not a benign one. It does make the twelve exclusions the
most rigid thing in the design, and the paper should say so.

---

## 4. Postfix — the repertoire argument, which is stronger than the cost one

**Reported from the review.** The latest revision of the UTR #25 work on how
the math symbols are used found that **none** of them are postfix operators in
practice — factorial `!` not being a math symbol. The recommendation was that
there is little real-world use for postfix, so excluding it is more than fine,
notwithstanding C++'s own `++` and `--`.

**Measured, and it corroborates structurally.** MathClass has no postfix class.
The categories are `U`, "operators that are only unary", and `V`, "unary or
binary depending on context"; there is no third. Only **6** of the current
1,381 are `U` or `V` at all.

**What to do with it.** Put this in front of §13.1's cost argument, not after
it. Postfix is currently declined because it is expensive and produces
misparses — a measured argument, and a defensive one. It can now be declined
because **it buys no notation**: there is nothing in the set to write postfix.
The `++`/`--` objection then answers itself, since those are ASCII, and so is
`!`.

**Needs checking before citing.** Scala appears to have shipped arbitrary
postfix operators — its spec says "A postfix operator can be an arbitrary
identifier" — then put them behind `import scala.language.postfixOps` and
dropped them in Scala 3. If that holds it is a language that tried this and
retreated, which is worth a sentence. Not verified here.

---

## 5. Scala — the closest prior art, and §11 does not mention it

**Verified**, from the Scala 2.13 specification, *Prefix, Infix, and Postfix
Operations*:

> The precedence of an infix operator is determined by the operator's first
> character. Characters are listed below in increasing order of precedence,
> with characters on the same line having the same precedence.
>
> (all letters …) `|` `^` `&` `=` `!` `<` `>` `:` `+` `-` `*` `/` `%`
> (other operator characters, as defined in chapter 1, **including Unicode
> categories `Sm` and `So`**)

Unicode `Sm`/`So` operators sit at the **highest** infix precedence, above
`*` — which is this paper's rule, arrived at independently. Left-associative,
except that an operator ending in `:` is right-associative.

§11 Prior art currently has Julia, Swift, Haskell, OCaml, Fortress, Raku and
APL. It should have Scala, and Scala is the closest of them: a shipping
language in which Unicode mathematical symbols are user-definable infix
operators at one maximal precedence level, left-associative.

**It cuts both ways, and the paper is stronger for saying so.** Scala *does*
derive precedence from the character, on a fixed table — the derived model,
shipping. The honest reading is the distinction §11 already draws for OCaml:
Scala derives from a small ASCII alphabet whose first character carries the
arithmetic analogy, and puts everything Unicode into one bucket at the top.
Which is one level. So Scala is evidence for this design's precedence choice
*and* an existence proof for the derived table, and it belongs in
`user-declared-fixity`'s log as well as in §11.

Divergences to note: Scala allows multi-character operators, has the trailing
`:` associativity rule, and has postfix (see §4).

---

## 6. Citation gaps

**Measured** against `papers/unicode-mathematical-operators.md` and
`papers/references.bib`.

- **P4345R0 does not cite UTR #25 at all.** The paper's citation set is
  `@binutils @D137051 @gcc15 @itanium-abi @julia-operators @ocaml-expr
  @P1949R7 @P3658R1 @P4307R0 @swift-operators @UAX31 @UAX31-45 @UCD17`.
  `@UTR25` exists in `references.bib` and is unused; the `.org` abstract cites
  it. The entire repertoire derives from a report the markdown paper never
  cites. This is the worst of the gaps and SG16's request lands directly on it.
- **UTS #39 has no bib entry.** It is discussed in four places in
  `unicode-operators.md`, and §3 above turns on it. Both halves need saying in
  the paper with the citation attached: what was used, and what deliberately
  was not — `confusables.txt` is not a generator input, by decision.
- **The emoji carve-out** cites "TR31 §7.2" in prose. `emoji-data.txt` is a
  generator input and UTS #51 is not cited.
- **Scala** — no bib entry, see §5.
- **Identifier profile** is fine. `@UAX31` and `@UAX31-45` cover §7.1.

---

## 7. State the reversibility principle once

Four decisions in the paper are resolved on the same argument, and §13's fold
entry already half-notices it: admitting folds later "takes nothing back …
the same forward-compatibility shape as §13.1's answer on postfix".

The four:

- **postfix** (§13.1) — declined, and a future revision admitting it makes
  previously ill-formed programs well-formed;
- **fold expressions over the user-infix level** (§13) — same;
- **the confusable exclusions** (§3 above) — same;
- **the token-set floor** (§2 above) — an implementation supporting a later
  Unicode only ever accepts more.

At four instances this should be stated once as a principle and cited, instead
of re-derived each time. It is also the paper's best answer to "why is v1 so
conservative": every open direction was resolved the way that can be undone.
