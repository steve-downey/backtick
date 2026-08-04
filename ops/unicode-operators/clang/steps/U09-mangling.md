# U09 — Itanium mangling, vendor-extended operator form

**Goal.** `operator⊞` mangles to a stable, demangler-tolerated symbol using
the Itanium vendor-extended operator production, so linking and ABI
inspection work for the prototype.

**Depends on:** U07. (Parallel with U08 — one touches Sema, one
`ItaniumMangle.cpp`.)
**Design refs:** U8 (`v <arity> <source-name>`, e.g. binary ⊞ → `v2` +
`op_u229E`); U§9 (why this stays disjoint from math-identifier function
names, and what remains open).

## Do
1. In `clang/lib/AST/ItaniumMangle.cpp`, handle the U06 name kind in
   `mangleUnqualifiedName` / the `<operator-name>` switch: emit `v`,
   the arity digit (1 prefix, 2 infix), then the derived source-name.
2. Derive the source-name deterministically from the **code point**, not
   the spelling: `op_u229E` for U+229E — uppercase hex, no `U+`, at least
   four digits, more for astral planes. Write the rule down in a comment;
   it is a de facto ABI decision for the prototype and the paper will quote
   it.
3. The precedent to copy for "derived source-name" is
   `<source-name>`-based literal-operator mangling (`li<length><suffix>`).
   Follow its length-prefix handling exactly.
4. Microsoft mangling: `MicrosoftMangle.cpp` almost certainly has an
   exhaustive switch that now fails to build. Emit a clean
   "unsupported/unimplemented" diagnostic there rather than fabricating a
   scheme — U§9 flags MSVC explicitly as unexamined, and inventing one
   quietly would be a worse outcome than an honest error.

## Build
`ninja -C ~/src/llvm/build-unicode clang`

## Verify (gate)
- `clang/test/CodeGenCXX/unicode-operator-mangle.cpp`: `-emit-llvm` and
  FileCheck the symbol for free infix, free prefix, member infix, and a
  template instantiation.
- All three spellings (glyph, `\u`, `\N{}`) produce the **same** symbol.
- `llvm-cxxfilt` on the produced symbols does not crash and produces
  something readable; record what it prints, exactly, in the handoff. The
  demangler's tolerance of the `v` production is the claim being tested.
- A function *named* with an extended identifier (Clang's D137051 math
  identifiers, if available in this build) mangles as an ordinary
  `<source-name>` and does not collide — U§9's disjointness claim. If the
  extension isn't available, say so and skip rather than fake it.
- `check-clang` green.

## Done when
Symbols are stable, spelling-independent, arity-tagged, demangler-tolerated,
and structurally distinct from extended-identifier function names.

## Capture in handoff
The exact mangled strings for a canonical set (they go straight into the
paper), the demangler output, and whether MSVC mangling was reachable.

## Pitfalls
Arity in the `v` production is the *operator's* arity as declared. Member
infix has one parameter but arity 2 — mangle the operator form, not the
parameter count, and test the member case specifically.

## REPLAY ledger
`upstream replay`. Flag this row **ABI-open** (U8 is unresolved); U19 needs
to surface it as the one item that is not merely a replay question.
