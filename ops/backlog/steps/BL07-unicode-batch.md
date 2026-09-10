# BL07 — Unicode batch: [`lldb-hunk-verification`](../../BACKLOG.md#lldb-hunk-verification), [`code-completion-priority`](../../BACKLOG.md#code-completion-priority), [`ucd-input-manifest`](../../BACKLOG.md#ucd-input-manifest)

**Goal.** Three small Unicode-track defects closed. Only one is a clang
source edit, which is what makes the batch cheap — and the whole risk sits in
[`code-completion-priority`](../../BACKLOG.md#code-completion-priority)'s gate.

**Depends on:** BL01.
**Closes:** [`lldb-hunk-verification`](../../BACKLOG.md#lldb-hunk-verification), [`code-completion-priority`](../../BACKLOG.md#code-completion-priority), [`ucd-input-manifest`](../../BACKLOG.md#ucd-input-manifest).
**Refs:** `ops/unicode-operators/clang/handoffs/U06-declaration-name.handoff.md:130`,
`:359-364`; `REPLAY.md:27`, `:234-236`, `:826`;
`U07-operator-function-id.handoff.md:263-269` and the five later handoffs that
carried [`code-completion-priority`](../../BACKLOG.md#code-completion-priority); `U02-charset-tables.handoff.md:41-56`, `:72-86`, `:104-108`,
`:259-262`.

Work on `unicode-operators-experiment`, then replay onto
`unicode-operators-upstream`.

## Do

### [`code-completion-priority`](../../BACKLOG.md#code-completion-priority) — completion-priority grouping (the only source edit)

`~/src/llvm/unicode/clang/lib/Sema/SemaCodeComplete.cpp:1053-1065`, inside
the `DC->isRecord()` arm:

```cpp
    // Explicit operator and conversion function calls are also very rare.
    auto DeclNameKind = ND->getDeclName().getNameKind();
    if (DeclNameKind == DeclarationName::CXXOperatorName ||
        DeclNameKind == DeclarationName::CXXLiteralOperatorName ||
        DeclNameKind == DeclarationName::CXXConversionFunctionName)
      return CCP_Unlikely;
```

Add `DeclarationName::CXXUserOperatorName` to the chain. One `||`; a
single-TU rebuild plus relink.

Carried by six steps in turn (U07, U08, U09, U11, U13, U16, U17). U11 is what
made it urgent: completion after an infix user operator became a reachable
state, and U12 added a second reachable position.

**Its gate has to be designed, or the step closes nothing.** U07 dismissed
this as changing "no behavior a test can see", and no in-tree
`clang/test/CodeCompletion/` file prints priorities. But results **are**
priority-sorted before printing —
`clang/lib/Sema/CodeCompleteConsumer.cpp:645`, `std::stable_sort` — so an
observable exists:

> A lit test using `-code-completion-at` on a member access of a class that
> has both an ordinary member and a member `operator⊞`, asserting with
> `CHECK` / `CHECK-NEXT` that the operator sorts **after** the ordinary
> member.

**Verify it fails before the fix.** Anything less deletes a TODO rather than
closing a defect.

### [`lldb-hunk-verification`](../../BACKLOG.md#lldb-hunk-verification) — the lldb hunk, compile-unverified

`lldb/source/Plugins/ExpressionParser/Clang/ClangASTSource.cpp:125` — a
single `case DeclarationName::CXXUserOperatorName:` joining the existing
"Operator names" group (`:123-126`), landed in U06 commit `9e4042cc2c76`. It
is the only hunk in the whole feature that no compiler has seen.

**No source change. This is build configuration only.** All prerequisites are
already on the machine (`/usr/bin/swig`, python 3.13 dev headers,
`/usr/include/curses.h`, `/usr/include/editline/readline.h`).

Use a **scratch** build dir — not `build-unicode`, whose gate numbers are
load-bearing — and build only the library that owns the file, which compiles
the TU without ever linking `lldb`:

```bash
cmake -G Ninja -S ~/src/llvm/unicode/llvm -B ~/src/llvm/build-lldb-scratch \
  -DLLVM_ENABLE_PROJECTS='clang;lldb' \
  -DLLDB_ENABLE_PYTHON=OFF -DLLDB_ENABLE_SWIG=OFF \
  -DLLDB_ENABLE_LIBEDIT=OFF -DLLDB_ENABLE_CURSES=OFF \
  -DLLDB_INCLUDE_TESTS=OFF \
  -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_TARGETS_TO_BUILD=host
ninja -C ~/src/llvm/build-lldb-scratch lldbPluginExpressionParserClang
```

If BL04's CIR scratch dir already exists, add `lldb` to **that** configure
instead and do both in one build.

**Do it for both Unicode branches** — the "compile-unverified" caveat is
recorded twice, at `REPLAY.md:234-236` and `:826`. Update both, plus
`U06-declaration-name.handoff.md:359-364`. No `check-clang` re-run is needed
for this item.

### [`ucd-input-manifest`](../../BACKLOG.md#ucd-input-manifest) — the UCD manifest

`docs/pattern-syntax-audit.py` (379 lines, in *this* repo, not in LLVM)
derives the frozen [token-set](../../../docs/unicode-operators.md#token-set) operator set and, with `--emit-header`, generates
`~/src/llvm/unicode/clang/lib/Lex/UnicodeOperatorCharSets.h`. It needs five
UCD files, and **none of them is in either repo**:

| File | Source |
|---|---|
| `PropList.txt` | `https://www.unicode.org/Public/17.0.0/ucd/` |
| `DerivedAge.txt` | same |
| `UnicodeData.txt` | same |
| `DerivedCoreProperties.txt` | same |
| `emoji-data.txt` | `https://www.unicode.org/Public/17.0.0/ucd/emoji/` |

Pinned: UCD **17.0.0**, `DerivedAge.txt` dated **2025-07-30**. Never
`latest/` — it is 18.0 now, and re-deriving against it silently produces a
different set, which is the exact failure mode [token-set](../../../docs/unicode-operators.md#token-set) exists to prevent.

**Do this:**

1. Write `docs/ucd-17.0.0.sha256` — the five files, each with its
   version-pinned URL and SHA-256.
2. Add a `--verify-manifest` mode to `docs/pattern-syntax-audit.py` that
   refuses to derive when an input does not match. ~20 lines, and it turns
   the manifest from documentation into a check.

**This is the only item in either batch with an external dependency.** It
needs network access to unicode.org before a single hash can be written. If
that is unavailable, this item is **BLOCKED** — write the BLOCKED handoff for
it and complete [`lldb-hunk-verification`](../../BACKLOG.md#lldb-hunk-verification) and [`code-completion-priority`](../../BACKLOG.md#code-completion-priority); do not fabricate a manifest of
expected-only URLs.

The exact generator command, which the generated header also records at
`UnicodeOperatorCharSets.h:15-24`:

```bash
python3 docs/pattern-syntax-audit.py "$UCD" --emit-header \
    > ~/src/llvm/unicode/clang/lib/Lex/UnicodeOperatorCharSets.h
```

`--emit-header` puts only C++ on stdout and the audit narrative on stderr, so
a regeneration is diffable and still self-documenting.

## Build

`ninja -C ~/src/llvm/build-unicode clang` (for [`code-completion-priority`](../../BACKLOG.md#code-completion-priority) only).

## Verify (gate)

- **[`code-completion-priority`](../../BACKLOG.md#code-completion-priority)**: the new `clang/test/CodeCompletion/` test passes *and* fails on
  a build with the `||` clause reverted. Say in the handoff that you checked
  both directions.
- **[`lldb-hunk-verification`](../../BACKLOG.md#lldb-hunk-verification)**: `ninja … lldbPluginExpressionParserClang` exits 0 with no
  `-Wswitch` on `ClangASTSource.cpp`, on both Unicode branches.
- **[`ucd-input-manifest`](../../BACKLOG.md#ucd-input-manifest)**: re-fetch → hashes match the manifest → re-run the generator →
  `diff` against the committed `UnicodeOperatorCharSets.h` is **empty,
  byte-for-byte**; and
  `AllClangUnitTests --gtest_filter='UnicodeOperatorCharSets*'` stays 14/14
  (which independently pins 32 ranges / 1381 code points / `sizeof == 256` /
  28 exclusions).
- `check-clang` green on `unicode-operators-experiment`, then on
  `unicode-operators-upstream`.

## REPLAY ledger

[`code-completion-priority`](../../BACKLOG.md#code-completion-priority) and [`lldb-hunk-verification`](../../BACKLOG.md#lldb-hunk-verification) are `upstream replay`. [`ucd-input-manifest`](../../BACKLOG.md#ucd-input-manifest) is plan-repo only and touches no
LLVM source — note it as out-of-band rather than giving it a replay class.

## Capture in handoff

For [`code-completion-priority`](../../BACKLOG.md#code-completion-priority), the completion-ordering test's before/after output — it is the
first observable anyone has found for this priority table, and six steps
declined the item for want of exactly that.

For [`ucd-input-manifest`](../../BACKLOG.md#ucd-input-manifest), whether the byte-identical regeneration held. If it did, the
paper's reproducibility claim is now *checked* rather than asserted, which is
worth a sentence in `docs/unicode-operators.md` U§4.
