#!/usr/bin/env python3
"""Audit backing the "immutable versus stable" numbers in unicode-operators.md §4.

Distinguishes the immutable Pattern_Syntax *code-point set* from the growing
set of *assigned characters* within it, and measures how a predicate-defined
operator set (unicode-operators.md §5, U1) would have drifted across Unicode
versions.

Also backs §7.1 / U10: Pattern_Syntax is disjoint from XID (C++23
identifiers, P1949) and from the C++11–C++20 Annex E identifier whitelist,
so no C++ standard has ever admitted an operator character into a name.

Also derives the final U1 operator set (§5 predicates + exclusions) and its
range-table shape — the static table a lexer would actually search (§8).

Needs five UCD files in the directory given as argv[1] (default: cwd), from
https://www.unicode.org/Public/17.0.0/ucd/ (emoji-data.txt is under
ucd/emoji/):
    PropList.txt  DerivedAge.txt  UnicodeData.txt  DerivedCoreProperties.txt
    emoji-data.txt

Fetch the **version-pinned** 17.0.0 path, never `latest/`: U1 is a frozen
enumeration, and re-deriving it against a drifting UCD is the exact failure
mode U1 exists to prevent.

Numbers quoted in the design doc were produced against UCD 17.0.0
(DerivedAge.txt dated 2025-07-30).

With `--emit-header`, writes the derived tables to stdout as a C++ header in
the shape of clang/lib/Lex/UnicodeCharSets.h (the audit narrative then goes
to stderr):

    python3 docs/pattern-syntax-audit.py <ucd-dir> --emit-header \\
        > ~/src/llvm/unicode/clang/lib/Lex/UnicodeOperatorCharSets.h
"""

import sys
from collections import defaultdict
from pathlib import Path

EMIT_HEADER = "--emit-header" in sys.argv[1:]
_args = [a for a in sys.argv[1:] if not a.startswith("--")]
D = Path(_args[0]) if _args else Path(".")

if EMIT_HEADER:
    # In header mode stdout carries the generated C++ and nothing else; the
    # audit narrative still runs, on stderr, so a generator run documents
    # itself.
    _stdout_print = print

    def print(*a, **kw):  # noqa: A001 - deliberate shadow
        kw.setdefault("file", sys.stderr)
        _stdout_print(*a, **kw)


def ranges(path, want=None):
    out = []
    for line in open(path, encoding="utf-8"):
        line = line.split("#")[0].strip()
        if not line:
            continue
        cps, val = [x.strip() for x in line.split(";")[:2]]
        if want and val != want:
            continue
        a, b = cps.split("..") if ".." in cps else (cps, cps)
        out.append((int(a, 16), int(b, 16), val))
    return out


ps = set()
for a, b, _ in ranges(D / "PropList.txt", "Pattern_Syntax"):
    ps.update(range(a, b + 1))

# DerivedAge covers assigned code points only; unassigned ones have no age.
age = {}
for a, b, v in ranges(D / "DerivedAge.txt"):
    for cp in range(a, b + 1):
        age[cp] = v

name, gc = {}, {}
for line in open(D / "UnicodeData.txt", encoding="utf-8"):
    f = line.split(";")
    cp = int(f[0], 16)
    if cp in ps:
        name[cp], gc[cp] = f[1], f[2]

ps_assigned = {cp for cp in ps if cp in age}
ps_unassigned = ps - ps_assigned


def V(v):
    return tuple(int(x) for x in v.split("."))


print(f"Pattern_Syntax total code points : {len(ps)}")
print(f"  assigned characters            : {len(ps_assigned)}")
print(f"  UNASSIGNED (reserved) in PS    : {len(ps_unassigned)}")

late = [cp for cp in ps_assigned if V(age[cp]) > (4, 1)]
print(f"\nCharacters assigned at PS code points AFTER the 4.1 freeze: {len(late)}")
byver = defaultdict(list)
for cp in late:
    byver[age[cp]].append(cp)
for v in sorted(byver, key=V):
    cps = sorted(byver[v])
    ex = ", ".join(f"U+{c:04X} {chr(c)} {name.get(c, '?')}" for c in cps[:3])
    print(f"  {v}: {len(cps):3d}   e.g. {ex}")

# The U1 blocks from unicode-operators.md §5 predicate 3.
blocks = [
    (0x2190, 0x21FF), (0x2200, 0x22FF), (0x2300, 0x23FF),
    (0x27C0, 0x27EF), (0x27F0, 0x27FF), (0x2900, 0x297F),
    (0x2980, 0x29FF), (0x2A00, 0x2AFF), (0x2B00, 0x2BFF),
]
inb = lambda cp: any(a <= cp <= b for a, b in blocks)
u1_unassigned = sorted(cp for cp in ps_unassigned if inb(cp))
u1_late = sorted(cp for cp in late if inb(cp))
sm_so = [cp for cp in u1_late if gc.get(cp) in ("Sm", "So")]

print(f"\nWithin the U1 blocks:")
print(f"  unassigned PS code points today: {len(u1_unassigned)}  " +
      ", ".join(f"U+{c:04X}" for c in u1_unassigned))
print(f"  post-4.1 assignments           : {len(u1_late)}")
print(f"  of those, gc Sm/So (would enter a predicate-defined U1 set): {len(sm_so)}")

# --- §7.1 / U10: operator characters vs identifier characters -------------

xid_start, xid_cont = set(), set()
for a, b, v in ranges(D / "DerivedCoreProperties.txt"):
    if v == "XID_Start":
        xid_start.update(range(a, b + 1))
    elif v == "XID_Continue":
        xid_cont.update(range(a, b + 1))

# C++11–C++20 [charname.allowed] Annex E.1 (pre-P1949 identifier whitelist).
E1 = [
    (0xA8, 0xA8), (0xAA, 0xAA), (0xAD, 0xAD), (0xAF, 0xAF), (0xB2, 0xB5),
    (0xB7, 0xBA), (0xBC, 0xBE), (0xC0, 0xD6), (0xD8, 0xF6), (0xF8, 0xFF),
    (0x100, 0x167F), (0x1681, 0x180D), (0x180F, 0x1FFF),
    (0x200B, 0x200D), (0x202A, 0x202E), (0x203F, 0x2040), (0x2054, 0x2054),
    (0x2060, 0x206F), (0x2070, 0x218F), (0x2460, 0x24FF), (0x2776, 0x2793),
    (0x2C00, 0x2DFF), (0x2E80, 0x2FFF), (0x3004, 0x3007), (0x3021, 0x302F),
    (0x3031, 0xD7FF), (0xF900, 0xFD3D), (0xFD40, 0xFDCF), (0xFDF0, 0xFE44),
    (0xFE47, 0xFFFD),
] + [(p << 16, (p << 16) + 0xFFFD) for p in range(1, 15)]
e1 = set()
for a, b in E1:
    e1.update(range(a, b + 1))

ims, imc = set(), set()
for a, b, _ in ranges(D / "PropList.txt", "ID_Compat_Math_Start"):
    ims.update(range(a, b + 1))
for a, b, _ in ranges(D / "PropList.txt", "ID_Compat_Math_Continue"):
    imc.update(range(a, b + 1))

print(f"\nOperator vs identifier space (U10 / U§7.1):")
print(f"  Pattern_Syntax ∩ XID_Start           : {len(ps & xid_start)}")
print(f"  Pattern_Syntax ∩ XID_Continue        : {len(ps & xid_cont)}")
print(f"  Pattern_Syntax ∩ C++11–20 whitelist  : {len(ps & e1)}")
print(f"  ID_Compat_Math_Start (D137051/P3658) : {len(ims)}")
print(f"  ID_Compat_Math_Continue              : {len(imc)}")
print(f"  Pattern_Syntax ∩ ID_Compat_Math      : " +
      ", ".join(f"U+{c:04X} {chr(c)}" for c in sorted(ps & (ims | imc))) +
      "   (exactly the U1 exclusions)")

# --- §5/§8: the final U1 set and its lexer range-table shape ---------------

epres = set()
for a, b, _ in ranges(D / "emoji-data.txt", "Emoji_Presentation"):
    epres.update(range(a, b + 1))

# §5 predicate 5, the named exclusions, each with the reason a lexer should
# report (U§8 keeps them as a table *with reasons*, not as absent entries) and,
# for a confusable, the existing token it apes.
IDENTIFIER_PROFILE = "IdentifierProfile"
CONFUSABLE_WITH = "ConfusableWith"
EMOJI_PRESENTATION = "EmojiPresentation"

NAMED_EXCLUSIONS = {
    # ∂ ∇ ∞ — TR31 §7.1 earmarks these for the identifier side (U10).
    0x2202: (IDENTIFIER_PROFILE, None),
    0x2207: (IDENTIFIER_PROFILE, None),
    0x221E: (IDENTIFIER_PROFILE, None),
    # UTS #39 confusables of tokens C++ already has.
    0x2212: (CONFUSABLE_WITH, "-"),      # − MINUS SIGN
    0x2215: (CONFUSABLE_WITH, "/"),      # ∕ DIVISION SLASH
    0x2044: (CONFUSABLE_WITH, "/"),      # ⁄ FRACTION SLASH
    0x2217: (CONFUSABLE_WITH, "*"),      # ∗ ASTERISK OPERATOR
    0x2223: (CONFUSABLE_WITH, "|"),      # ∣ DIVIDES
    0x2236: (CONFUSABLE_WITH, ":"),      # ∶ RATIO
    0x2219: (CONFUSABLE_WITH, "."),      # ∙ BULLET OPERATOR  — middle-dot family
    0x22C5: (CONFUSABLE_WITH, "."),      # ⋅ DOT OPERATOR     — middle-dot family
    0x2264: (CONFUSABLE_WITH, "<="),     # ≤
    0x2265: (CONFUSABLE_WITH, ">="),     # ≥
    0x21D0: (CONFUSABLE_WITH, "<="),     # ⇐
    0x21D2: (CONFUSABLE_WITH, "=>"),     # ⇒
    0x21D4: (CONFUSABLE_WITH, "<=>"),    # ⇔
}
EXCLUDE = set(NAMED_EXCLUSIONS)

u1_final = sorted(
    cp for cp in ps
    if inb(cp) and gc.get(cp) in ("Sm", "So")
    and cp not in EXCLUDE and cp not in epres
)
rgs = []
for cp in u1_final:
    if rgs and cp == rgs[-1][1] + 1:
        rgs[-1][1] = cp
    else:
        rgs.append([cp, cp])

print(f"\nFinal U1 operator set (§5 predicates, all exclusions applied):")
print(f"  code points : {len(u1_final)}")
print(f"  contiguous ranges : {len(rgs)}  "
      f"(static table: {len(rgs) * 8} bytes at 2×uint32 per range)")
emoji_in_blocks = sorted(c for c in ps if inb(c) and c in epres)
print(f"  emoji-presentation excluded inside the blocks : {len(emoji_in_blocks)}")

# --- --emit-header: the tables as Clang-shaped C++ -------------------------


def ucd_version_and_date():
    """(version, date) as the UCD files themselves report them."""
    version, date = "unknown", "unknown"
    with open(D / "DerivedAge.txt", encoding="utf-8") as f:
        for line in f:
            if line.startswith("# DerivedAge-") and version == "unknown":
                version = line.strip().removeprefix("# DerivedAge-").removesuffix(".txt")
            elif line.startswith("# Date:"):
                date = line.split(":", 1)[1].split(",")[0].strip()
                break
    return version, date


def emit_header(w):
    version, date = ucd_version_and_date()
    excl = sorted(NAMED_EXCLUSIONS) + [c for c in emoji_in_blocks
                                       if c not in NAMED_EXCLUSIONS]
    excl.sort()
    # Every named exclusion must be absent from the emitted set, or the
    # generated exclusion table would be lying about the range table.
    u1 = set(u1_final)
    assert not (u1 & set(excl)), "exclusion listed but present in U1 set"

    def reason_of(cp):
        return NAMED_EXCLUSIONS.get(cp, (EMOJI_PRESENTATION, None))

    w(f"""\
//===--- UnicodeOperatorCharSets.h - U1 user-operator code points ---------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \\file
/// GENERATED FILE - DO NOT EDIT.
///
/// The frozen U1 set of Unicode user-defined operator code points, plus the
/// table of named exclusions and the reason each was kept out.
///
/// Generated by, from a directory holding the five UCD {version} data files
/// (PropList.txt, DerivedAge.txt, UnicodeData.txt, DerivedCoreProperties.txt,
/// emoji/emoji-data.txt) fetched from
/// https://www.unicode.org/Public/{version}/ucd/ :
///
///   python3 docs/pattern-syntax-audit.py <ucd-dir> --emit-header \\
///       > clang/lib/Lex/UnicodeOperatorCharSets.h
///
/// The generator lives in the plan repo, not in LLVM. UCD version {version},
/// DerivedAge.txt dated {date}.
///
/// Derivation (unicode-operators.md U#5, predicates 1-5): Pattern_Syntax, and
/// non-ASCII, and inside the mathematical/arrow blocks (U+2190-21FF,
/// U+2200-22FF, U+2300-23FF, U+27C0-27EF, U+27F0-27FF, U+2900-297F,
/// U+2980-29FF, U+2A00-2AFF, U+2B00-2BFF), and General_Category Sm or So,
/// minus the named exclusions below. The predicates are *derivation inputs*
/// applied once, offline: U1 freezes the resulting enumeration at UCD
/// {version} by fiat, so this table does not track later UCD versions.
///
/// Result: {len(u1_final)} code points in {len(rgs)} contiguous ranges, {len(rgs) * 8} bytes.
///
//===----------------------------------------------------------------------===//

#ifndef LLVM_CLANG_LIB_LEX_UNICODEOPERATORCHARSETS_H
#define LLVM_CLANG_LIB_LEX_UNICODEOPERATORCHARSETS_H

#include "llvm/Support/UnicodeCharRanges.h"
#include <cstdint>

namespace clang {{

/// The frozen U1 user-operator set, UCD {version}: {len(u1_final)} code points in
/// {len(rgs)} ranges, sorted and non-overlapping as llvm::sys::UnicodeCharSet
/// requires.
static const llvm::sys::UnicodeCharRange UserOperatorRanges[] = {{""")

    for i in range(0, len(rgs), 3):
        row = "".join(f"{{0x{a:04X}, 0x{b:04X}}}," .ljust(20)
                      for a, b in rgs[i:i + 3])
        w("    " + row.rstrip())
    w("};")
    w("")
    w("/// Why a code point that a reader might expect to be a user operator is")
    w("/// not one. U05 turns these into diagnostics; the exclusions exist for the")
    w("/// reader's protection, so the diagnostics should say so.")
    w("enum class UserOperatorExclusionReason {")
    w("  /// Not a named exclusion (it simply fails one of predicates 1-4, or is")
    w("  /// a member of the set).")
    w("  None,")
    w("  /// TR31 7.1's mathematical notation profile earmarks it as an")
    w("  /// *identifier* character: it names things, it does not combine them.")
    w("  /// Clang already admits these as identifiers; see")
    w("  /// MathematicalNotationProfileIDStartRanges in UnicodeCharSets.h.")
    w("  IdentifierProfile,")
    w("  /// UTS #39 confusable with an existing C++ token. Rejected outright,")
    w("  /// never aliased: something that looks like `-` but is not must fail to")
    w("  /// lex rather than quietly mean something else.")
    w("  ConfusableWith,")
    w("  /// TR31 7.2's emoji profile carve-out.")
    w("  EmojiPresentation,")
    w("};")
    w("")
    w("struct UserOperatorExclusion {")
    w("  uint32_t CodePoint;")
    w("  UserOperatorExclusionReason Reason;")
    w("  /// For ConfusableWith, the existing token this code point apes;")
    w("  /// nullptr otherwise.")
    w("  const char *Confusable;")
    w("};")
    w("")
    w(f"/// The named exclusions of U#5 predicate 5 ({len(NAMED_EXCLUSIONS)} of them) plus the")
    w(f"/// {len(emoji_in_blocks)} emoji-presentation code points inside the U1 blocks. Sorted by")
    w("/// code point.")
    w("static const UserOperatorExclusion ExcludedOperatorChars[] = {")
    for cp in excl:
        reason, conf = reason_of(cp)
        c = f'"{conf}"' if conf else "nullptr"
        w(f"    // {chr(cp)} U+{cp:04X} {name.get(cp, '?')}")
        w(f"    {{0x{cp:04X}, UserOperatorExclusionReason::{reason}, {c}}},")
    w("};")
    w("")
    w("""\
/// True if \\p C is a member of the frozen U1 user-operator set.
static inline bool isUserOperatorChar(uint32_t C) {
  static const llvm::sys::UnicodeCharSet UserOperatorChars(UserOperatorRanges);
  return UserOperatorChars.contains(C);
}

/// The exclusion table entry for \\p C, or nullptr if \\p C is not a named
/// exclusion. Table is tiny (a linear scan beats a binary search here) and
/// sorted, so the scan can stop early.
static inline const UserOperatorExclusion *
getUserOperatorExclusion(uint32_t C) {
  for (const UserOperatorExclusion &E : ExcludedOperatorChars) {
    if (E.CodePoint == C)
      return &E;
    if (E.CodePoint > C)
      break;
  }
  return nullptr;
}

/// Why \\p C is not a user operator, when there is a named reason to give.
static inline UserOperatorExclusionReason getExclusionReason(uint32_t C) {
  if (const UserOperatorExclusion *E = getUserOperatorExclusion(C))
    return E->Reason;
  return UserOperatorExclusionReason::None;
}

} // namespace clang

#endif // LLVM_CLANG_LIB_LEX_UNICODEOPERATORCHARSETS_H""")


if EMIT_HEADER:
    emit_header(lambda s="": _stdout_print(s))
