# Deviation ledger — Unicode operators, Clang track

Each row is a place the build taught us something `docs/unicode-operators.md`
didn't know. Unlike the backtick ledgers, this one runs against a design
that is entirely **Proposed** — a row here is not an embarrassment, it is
the point of building the prototype. The paper author reconciles rows into
U§2 (decisions log) and the affected U§ section.

Record cross-compiler divergences (Clang vs GCC vs the backtick tracks)
here too; they are exactly what SG16/EWG/CWG ask about.

| ID | Step | Design section affected | What the design said | What was true | Recommended doc change |
|----|------|------------------------|----------------------|---------------|------------------------|
| DEV-U01 | U00 (for U02/U05) | U§4, U§7.1, U1, U10 | Everything is derived and checked against **UCD 17.0.0** / UAX #31 revision 43 — including the U10 claim "Pattern_Syntax ∩ XID_Start = Pattern_Syntax ∩ XID_Continue = ∅ in UCD 17.0" and the Clang math-identifier composition argument. | Clang trunk's in-tree tables have already moved to **Unicode 18.0**: `clang/lib/Lex/UnicodeCharSets.h` labels `XIDStartRanges`, `XIDContinueRanges`, `MathematicalNotationProfileIDStartRanges` and `…ContinueRanges` "Unicode 18.0". So U02's in-tree disjointness cross-check runs U1@17.0 against XID@18.0 — a *stronger* check if it passes, but not the one the doc claims to have made. (The `ID_Compat_Math_Start` table does contain exactly ∂ U+2202, ∇ U+2207, ∞ U+221E plus 10 Mathematical-Italic variants, as U10 asserts.) | Note in U§4 that the frozen U1 set is pinned to UCD 17.0 **by the proposal** while implementations track whatever UCD their identifier tables use — that separation is the point of U1, but the disjointness claim in U§7.1/U10 should be re-stated as verified at 17.0 *and* 18.0 once U02 measures it. If U02's cross-check finds any overlap at 18.0, that is a U10 finding, not a table bug. |
