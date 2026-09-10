# Handoff — U02 Frozen U1 range table + exclusion table (generated)

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `2389fe7be452`
  (parent `3014f97cfc31`, U01)
- **Date / agent:** 2026-08-03

## What changed

Two repos, as the step requires: the generator lives here, the generated
header lands in LLVM.

**In `/home/sdowney/src/llvm/unicode` (commit `2389fe7be452`):**

| File | Change |
|------|--------|
| `clang/lib/Lex/UnicodeOperatorCharSets.h` | **new, 182 lines, generated.** `UserOperatorRanges[]` (32 `llvm::sys::UnicodeCharRange`), `enum class UserOperatorExclusionReason`, `struct UserOperatorExclusion`, `ExcludedOperatorChars[]` (28 entries), and the three lookups. |
| `clang/unittests/Lex/UnicodeOperatorCharSetsTest.cpp` | **new**, 14 gtest cases. |
| `clang/unittests/Lex/CMakeLists.txt` | +1 line, the new source in `add_clang_unittest(LexTests …)`. |

Nothing else. No lexer change, no flag check, no existing TU includes the new
header yet — U03 is the first consumer.

**In this repo:** `docs/pattern-syntax-audit.py` grew `--emit-header` (and its
named exclusions became a dict carrying reason + confusable spelling);
`PLAN.md` U02 ticked + Status row; `REPLAY.md` U02 row; `DEVIATIONS.md`
DEV-U02 and DEV-U03; this handoff.

## Pinned values (quote these; do not re-derive)

| Thing | Value |
|-------|-------|
| Generated header | `/home/sdowney/src/llvm/unicode/clang/lib/Lex/UnicodeOperatorCharSets.h` |
| Namespace | `clang` (unlike `UnicodeCharSets.h`, which is at global scope) |
| U1 set | **1,381 code points in 32 contiguous ranges = 256 bytes** — exactly what U§5/U§8 predicted |
| Exclusion table | **28 entries** = 16 named (U§5 predicate 5) + 12 emoji-presentation |
| Lookups | `bool clang::isUserOperatorChar(uint32_t)`, `clang::UserOperatorExclusionReason clang::getExclusionReason(uint32_t)`, `const clang::UserOperatorExclusion *clang::getUserOperatorExclusion(uint32_t)` |
| Reasons | `UserOperatorExclusionReason::{None, IdentifierProfile, ConfusableWith, EmojiPresentation}` |
| Unittest binary | `AllClangUnitTests` (there is no `LexTests` target) |
| gtest filter | `UnicodeOperatorCharSetsTest.*` |
| UCD | 17.0.0, `DerivedAge.txt` dated 2025-07-30, from `https://www.unicode.org/Public/17.0.0/ucd/` |

**Exact generator command** (the header records it too):

```bash
# five UCD 17.0.0 files in $UCD: PropList.txt DerivedAge.txt UnicodeData.txt
# DerivedCoreProperties.txt emoji-data.txt   (the last from .../ucd/emoji/)
python3 docs/pattern-syntax-audit.py "$UCD" --emit-header \
    > /home/sdowney/src/llvm/unicode/clang/lib/Lex/UnicodeOperatorCharSets.h
```

`--emit-header` puts **only** the C++ on stdout and the audit narrative on
stderr, so a regeneration is diffable and still self-documenting. The five UCD
files are deliberately not checked into either repo; re-fetch them
version-pinned. **Never `latest/`** — it is 18.0 now, and re-deriving against
it would silently produce a different set (that is the whole point of U1).

## Verification evidence

**Build:** `ninja -C /home/sdowney/src/llvm/build-unicode AllClangUnitTests` →
`BUILD_EXIT=0`, 17 edges. **No warnings** from either new file — in
particular the `static const` tables and `static inline` lookups produce no
`-Wunused-*` even in a TU that uses only some of them (probed before writing
the test, by compiling a stub that includes both charset headers with
`-Wall -Wextra`).

**Unittest:** `AllClangUnitTests --gtest_filter='UnicodeOperatorCharSets*'` →
**14 tests from 1 test suite ran, 14 passed, 0 failed.** The cases:

| Test | Asserts |
|------|---------|
| `FrozenCountsMatchTheDerivation` | 32 ranges, 1381 code points, `sizeof == 256` |
| `TableIsSortedAndNonOverlapping` | explicit loop (`Lower <= Upper`, `Lower > prev.Upper + 1` — a gap of exactly 1 would mean the generator failed to merge) plus constructing `llvm::sys::UnicodeCharSet`, which runs LLVM's own `NDEBUG`-conditional assert |
| `Members` | ⊞ U+229E, ⊗ U+2297, ↦ U+21A6, and ⮖ U+2B96 (the one character Unicode 17.0 itself assigned inside the blocks) |
| `AsciiIsNeverAUserOperator` | all 128 ASCII code points |
| `OutsideTheBlocks` | × U+00D7, ÷ U+00F7, U+2E55, U+205E |
| `PairedBracketsAreNotOperators` | ⟨ ⟩ ⟦ ⟧ ⌈ ⌋ |
| `UnassignedCodePointsAreNotOperators` | U+2B74/U+2B75 out, U+2B73/U+2B76 in |
| `IdentifierProfileExclusions` | ∂ ∇ ∞ out **and** reason `IdentifierProfile` |
| `ConfusableExclusionsCarryTheTokenTheyApe` | all 13 confusables out, reason `ConfusableWith`, exact `Confusable` string; plus ∑ U+2211 / ∓ U+2213 / ⇑ U+21D1 still **in** (the exclusion is a hole in a range, not a widened gap) |
| `EmojiPresentationExclusions` | 7 of the 12 |
| `ExclusionTableIsSortedAndConsistent` | sorted, none is a member, `Confusable` non-null iff `ConfusableWith`, 28 entries |
| `NonExclusionsReportNoReason` | members, ASCII, unassigned, and a bracket all report `None` |
| **`UserOperatorsAreNeverIdentifierChars`** | **all 1,381** members vs `XIDStartRanges`, `XIDContinueRanges`, `MathematicalNotationProfileIDStartRanges`, `…ContinueRanges`, `C11AllowedIDCharRanges` |
| `TightestGapAgainstMathIdentifiers` | U+205E and U+2070 both non-members, U+2070 *is* `ID_Compat_Math_Continue`, and no code point in U+2000–U+218F is a member |

**Full gate:** `ninja -C $B check-clang` → `GATE_EXIT=0`

```
Testing Time: 168.40s
Total Discovered Tests: 54121
  Skipped          :     6 (0.01%)
  Unsupported      :  5853 (10.81%)
  Passed           : 48235 (89.12%)
  Expectedly Failed:    27 (0.05%)
```

Against U01 (54107 / 48221 / 0 failed / 27 / 5853 / 6): **exactly +14
discovered and +14 passed**, the 14 new gtest cases, every other bucket
byte-identical. Zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines; lit prints no
`Failed` bucket at all when it is empty, which is what "0 failed" looks like
here. `ulimit -c 0` was set; no cores.

**Reproducibility:** re-running the generator without `--emit-header` prints
the audit numbers the design doc quotes (2760 / 2681 / 79 Pattern_Syntax; 453
post-4.1 assignments; 279 Sm/So inside the blocks; 1381 / 32 / 12), and the
stderr of an `--emit-header` run is byte-identical to that stdout (`diff` →
IDENTICAL). The header regenerates byte-for-byte from the same inputs.

## Deviations from the plan / design

The counts came out exactly as U§5/U§8 predicted — **1,381 / 32 / 256 bytes**
— so there is no count deviation. Two rows filed, both about what the
implementation had to *decide* that the prose left open:

- **DEV-U02** — the U10 disjointness cross-check, run against Clang's in-tree
  tables. See "Discoveries".
- **DEV-U03** — U§5 predicate 5's exclusion list is prose and had to be
  enumerated: "the middle-dot family" resolves to exactly U+2219 ∙ and U+22C5
  ⋅ (U+00B7 MIDDLE DOT is *not* Pattern_Syntax at all — Unicode withheld it
  because it is used *in identifiers*, a small extra piece of U10 evidence);
  U+2044 ⁄ FRACTION SLASH is listed but is **outside the U1 blocks**, so it
  already fails predicate 3 and is the only named exclusion that would not
  otherwise have qualified; and no per-character confusable spellings were
  given, so U02 assigned them (see the table below).

Three smaller judgement calls, recorded because a reviewer will ask:

1. **The generator, not the header, is the source of truth for the
   exclusions.** `NAMED_EXCLUSIONS` in `docs/pattern-syntax-audit.py` is now a
   dict `{code point: (reason, confusable)}` whose key set is exactly the old
   `EXCLUDE` set — so the derived 1,381 is unchanged by construction.
2. **The 12 emoji-presentation code points are enumerated in the exclusion
   table**, not just absent, so U05 can say *why*. They are ⌚ ⌛ ⏩ ⏪ ⏫ ⏬ ⏰
   ⏳ ⬛ ⬜ ⭐ ⭕.
3. **The tables are in `namespace clang`** and the lookups are
   `static inline`, unlike `UnicodeCharSets.h`'s global-scope arrays. Reason:
   this header defines functions, and `static inline` is what keeps an unused
   include warning-free. If U03 prefers file-static helpers in `Lexer.cpp`
   instead, nothing here blocks that.

The confusable spellings assigned (DEV-U03):

| | | | | | |
|---|---|---|---|---|---|
| − U+2212 → `-` | ∕ U+2215 → `/` | ⁄ U+2044 → `/` | ∗ U+2217 → `*` | ∣ U+2223 → `\|` | ∶ U+2236 → `:` |
| ∙ U+2219 → `.` | ⋅ U+22C5 → `.` | ≤ U+2264 → `<=` | ≥ U+2265 → `>=` | ⇐ U+21D0 → `<=` | ⇒ U+21D2 → `=>` |
| ⇔ U+21D4 → `<=>` | | | | | |

∙ and ⋅ map to `.` rather than `*`: the exclusion is about *visual* confusion,
and they are dot-shaped, whatever their mathematics means.

## Discoveries affecting later steps

- **The U10 disjointness invariant holds, and holds harder than the design
  claims.** All 1,381 U1 members were checked, one code point at a time,
  against Clang's own identifier tables — which DEV-U01 established are
  labelled **Unicode 18.0** while U1 is frozen at **17.0**. Result: zero
  XID_Start, zero XID_Continue, zero `ID_Compat_Math_Start`, zero
  `ID_Compat_Math_Continue`, zero in the C++11–C++20 `[charname.allowed]`
  whitelist. **The 17.0-vs-18.0 mismatch did not matter — and its not
  mattering is the interesting result**: it is exactly the version-skew case a
  real implementation faces (compiler updates XID on Unicode's schedule; the
  frozen operator list does not move), and the partition survived it. This is
  the paper's empirical answer to "what happens when Unicode updates?" (DEV-U02).
- **`UnicodeCharSets.h`'s search shape, for U03 to match** (the step asked):
  plain `static const llvm::sys::UnicodeCharRange Name[] = {{lo, hi}, …}`
  arrays, three per line, sorted; **no** `searchInUnicodeRanges` helper. Every
  lookup in `Lexer.cpp` is the same four lines — a *function-local* `static
  const llvm::sys::UnicodeCharSet` over the array, then `.contains(C)`; see
  `isUnicodeWhitespace` at `Lexer.cpp:1600` and `isMathematicalExtensionID` at
  1609. `UnicodeCharSet::contains` is `std::lower_bound`. The function-local
  static matters: the constructor's sortedness/overlap assert then runs once
  per process, not once per code point. `isUserOperatorChar` copies that shape
  exactly.
- **The `UnicodeCharSet` constructor's assert is free in this build** (it is
  an assertions build) but it is `NDEBUG`-conditional upstream, so the
  unittest asserts sortedness itself as well.
- **Clang unittests may include lib-private headers by relative path** —
  `#include "../../lib/Lex/UnicodeCharSets.h"` works with no CMake change;
  precedent is `Driver/GCCVersionTest.cpp` and `AST/ByteCode/*`. That is how
  the cross-check reaches the XID tables.
- **Incremental cost of this step:** 17 ninja edges (~2 min) for
  `AllClangUnitTests`; the full `check-clang` was ~19 min wall, 168 s of
  testing. A header nothing includes is nearly free to build.

## Forward notes for the NEXT step (U03 — `tok::user_operator`)

Read after U03's step file. The step tells you to hook "the non-ASCII slow
path … `LexUnicodeIdentifierStart` / `tryConsumeIdentifierUTF8Char`"; here is
what is actually there, verified at `2389fe7be452`.

- **There is exactly one funnel, and both decode paths reach it.** In
  `Lexer::LexTokenInternal`, `clang/lib/Lex/Lexer.cpp`:
  - **line 4614** — the UTF-8 path: `default:` case, `--CurPtr`,
    `llvm::convertUTF8Sequence(…, strictConversion)`, whitespace check, then
    `return LexUnicodeIdentifierStart(Result, CodePoint, CurPtr);`
  - **line 4582** — the UCN path: `case '\\':`, `tryReadUCN(…)`, same
    whitespace check, same `return LexUnicodeIdentifierStart(...)`.
  So a check at the top of **`Lexer::LexUnicodeIdentifierStart`
  (`Lexer.cpp:1942`)**, before its `isAllowedInitiallyIDChar` call at 1945,
  catches both. **Note what that buys and costs:** it makes U04's UCN
  spellings (`⊞`) work almost for free — but U03's step says UTF-8 only,
  so either scope the hook to the 4614 site and let U04 widen it, or hook the
  funnel and say so in your handoff, leaving U04 to test `\N{…}` and the
  identifier-adjacency cases. Hooking the funnel is the smaller diff; U04's
  step should then be re-read for what remains.
- **The other three `tryConsumeIdentifierUTF8Char` call sites** (`Lexer.cpp`
  2060, 2193, 2217, 2287 — `LexIdentifierContinue` and friends) are the
  *continue* path, i.e. a code point in the middle of an identifier. `a⊞b`
  splitting into three tokens depends on the continue path **rejecting** ⊞ —
  which it already does, because ⊞ is not XID_Continue (U02 just proved it for
  all 1,381). You should not have to touch those; verify with `-dump-tokens`
  rather than by editing.
- **The flag test is `LangOpts.UnicodeOperators`** (U01), and `LangOpts` is a
  member reference already in scope in every one of those functions.
- **Off-flag behaviour, verbatim, and where it comes from.** For
  `int c = a ⊞ b;` today (identical with and without the flag, since the flag
  is still inert):
  ```
  error: unexpected character '⊞' U+229E
  error: expected ';' after top level declarator
  ```
  The first is `diag::err_character_not_allowed`
  (`DiagnosticLexKinds.td:133`, text `"unexpected character %0"`), emitted
  from `CheckCodepointValidInIdentifier` (`Lexer.cpp:1809`, called at 1975
  from `LexUnicodeIdentifierStart`'s failure tail), with the `'⊞' U+229E`
  rendering produced by **`EscapeSingleCodepointForDiagnostic(CodePoint)`**
  and a `FixItHint::CreateRemoval`. That is the exact function U05 must reuse
  for its exclusion diagnostics — do not invent a second way to print a code
  point. Note it also emits a *removal fix-it*; an exclusion diagnostic
  probably wants a replacement fix-it instead (`ConfusableWith` carries the
  token to replace with).
- **The tables you now have**, includable as `#include
  "UnicodeOperatorCharSets.h"` from `Lexer.cpp` (same directory, exactly how
  `UnicodeCharSets.h` is included at `Lexer.cpp:14`):
  `clang::isUserOperatorChar(uint32_t)` is the only one U03 needs.
  `getExclusionReason` / `getUserOperatorExclusion` are U05's; leaving them
  uncalled is warning-free (verified).
- **Order against XID is immaterial but pick operator-first**: U02 measured
  the sets disjoint, so the order cannot change behaviour, and putting the U1
  check first makes the gate on `LangOpts.UnicodeOperators` the only thing
  standing between the two classifications — easier to prove "off the flag,
  byte-identical to upstream".
- **Literals/comments/raw strings need no work and that is testable now.**
  They never reach `LexTokenInternal`'s `default:` case — the string and
  comment lexers consume their bodies byte-wise. Take the `-dump-tokens`
  snapshot on `2389fe7be452` before editing, as U01's handoff advises, and
  diff.
- **Token kind:** nothing in U02 constrains it. But note the shape U02 proved:
  every U1 operator is exactly **one code point**, no operator is a prefix of
  another, so the token's spelling length in bytes is 1–3 (all of U1 is in the
  BMP, U+2190–U+2BFF: 3 UTF-8 bytes) or 6/10 as a UCN. Deriving identity by
  re-decoding the spelling is therefore cheap and unambiguous — which is the
  step's stated preference.

## Open risks / TODOs

- **The UCD files are not in either repo.** Regeneration requires re-fetching
  the five 17.0.0 files. If that matters for the paper's reproducibility
  claim, checking a hash manifest into `docs/` would be the cheap fix — not
  done, out of scope for U02.
- **`ExcludedOperatorChars` includes U+2044, which is not in the blocks.**
  Harmless (it is not in the U1 set either way), and it makes the diagnostic
  possible; but it means "in the exclusion table" ≠ "would otherwise have been
  an operator". DEV-U03 recommends the doc say so.
- **The confusable spellings are a judgement call**, not derived from UTS #39
  data — the generator has no confusables.txt input. If SG16 pushes back, the
  fix is to add `confusables.txt` to the generator's inputs and derive the
  mapping; the table shape already supports it.
- **Nothing calls the tables.** If U03 slips, the header is dead code that
  still costs a `check-clang` slot only for its unittest. That is intended.
