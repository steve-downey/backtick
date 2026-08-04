# U02 — Frozen U1 range table + exclusion table (generated)

**Goal.** Land the character data the lexer will search: the frozen U1
operator set as a static sorted range table, and the exclusion list as a
second table carrying a *reason* per entry. Data only — no lexer changes.

**Depends on:** U00. (Parallel with U01; they touch disjoint files.)
**Design refs:** U1 (frozen enumeration pinned to UCD 17.0); U§5 (the five
predicates and the named exclusions); U§8 first three paragraphs (static
range table, exclusions as a table *with reasons*).

## Do
1. Extend `docs/pattern-syntax-audit.py` (in *this* repo) with an emitter —
   a `--emit-header` mode — that writes the derived set as C++ static range
   arrays in the shape Clang already uses in
   `clang/lib/Lex/UnicodeCharSets.h`. Do not hand-transcribe 1,381 code
   points; the table must be reproducible from the script plus a named UCD
   version.
2. Run it against **UCD 17.0.0** and check the output into the worktree as
   generated source (e.g. `clang/lib/Lex/UnicodeOperatorCharSets.h`), with
   a header comment giving the exact generator command, the UCD version,
   and the `DerivedAge.txt` date.
3. Emit two tables:
   - `UserOperatorRanges` — the U1 set. Expect **1,381 code points in 32
     contiguous ranges** (~256 bytes). A different count is a finding, not
     a typo to paper over: record it in DEVIATIONS and stop to think.
   - `ExcludedOperatorChars` — the named exclusions of U§5 predicate 5,
     each with an enumerated reason (`IdentifierProfile` for ∂ ∇ ∞;
     `ConfusableWith` plus the ASCII token it apes for U+2212, U+2215,
     U+2044, U+2217, U+2223, U+2236, U+22C5, U+2264, U+2265, ⇐ ⇒ ⇔ and the
     middle-dot family; `EmojiPresentation`). U05 consumes the reasons.
4. Add the lookup entry points (`isUserOperatorChar(UTF32)`,
   `getExclusionReason(UTF32)`) next to the tables. Nothing calls them yet.

## Build
`ninja -C ~/src/llvm/build-unicode clang`

## Verify (gate)
- A unittest (`clang/unittests/Lex/`) asserting: ⊞ U+229E, ⊗ U+2297, ↦
  U+21A6 are in; ASCII `+` is out; ∂ U+2202, ∇ U+2207, ∞ U+221E are out
  *and* report `IdentifierProfile`; U+2212 is out *and* reports
  `ConfusableWith` `-`; the paired brackets ⟨ U+27E8 / ⟧ U+27E7 are out;
  U+2B74/U+2B75 (unassigned) are out.
- Assert the invariant U10 rests on: no U1 code point is XID_Start or
  XID_Continue. Cheapest as a table cross-check against the existing
  `UnicodeCharSets.h` XID arrays — and it is the single most valuable
  assertion in this step, because the whole no-ambiguity argument dies
  without it.
- Table is sorted and non-overlapping (assert it; a binary search over an
  unsorted table fails silently).
- `check-clang` green.

## Done when
Both tables are in the tree, generated and reproducible, with the count and
disjointness assertions passing.

## Capture in handoff
The header path and the exact generator command. The measured range count.
Where `UnicodeCharSets.h` keeps its XID tables and what shape its search
uses (`searchInUnicodeRanges`-style helper or open-coded) — U03 will match
that shape rather than invent one.

## Pitfalls
The audit script needs five UCD files in a directory passed as `argv[1]`;
they are not in the repo. Fetch UCD **17.0.0** specifically, not `latest` —
`latest` will drift and silently re-derive a different set, which is the
exact failure mode U1 exists to prevent.

## REPLAY ledger
`upstream replay`. This data has no relationship to backtick.
