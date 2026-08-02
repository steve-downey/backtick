#!/usr/bin/env python3
"""Audit backing the "immutable versus stable" numbers in unicode-operators.md §4.

Distinguishes the immutable Pattern_Syntax *code-point set* from the growing
set of *assigned characters* within it, and measures how a predicate-defined
operator set (unicode-operators.md §5, U1) would have drifted across Unicode
versions.

Also backs §7.1 / U10: Pattern_Syntax is disjoint from XID (C++23
identifiers, P1949) and from the C++11–C++20 Annex E identifier whitelist,
so no C++ standard has ever admitted an operator character into a name.

Needs four UCD files in the directory given as argv[1] (default: cwd), from
https://www.unicode.org/Public/UCD/latest/ucd/ :
    PropList.txt  DerivedAge.txt  UnicodeData.txt  DerivedCoreProperties.txt

Numbers quoted in the design doc were produced against UCD 17.0.0
(DerivedAge.txt dated 2025-07-30).
"""

import sys
from collections import defaultdict
from pathlib import Path

D = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")


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
