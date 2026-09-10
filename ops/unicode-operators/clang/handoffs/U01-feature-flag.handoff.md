# Handoff — U01 Feature flag `-funicode-operators`

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `3014f97cfc31`
  (parent `bd6f4d5fa102`, the U00 base)
- **Date / agent:** 2026-08-03

## What changed

Four files in `/home/sdowney/src/llvm/unicode`, +9 source lines and one new
test. **This is the first commit on the branch that changes the compiler.**

| File | Line (post-edit) | Change |
|------|------------------|--------|
| `clang/include/clang/Basic/LangOptions.def` | **537**, immediately after `Backtick` at 536 | `LANGOPT(UnicodeOperators, 1, 0, NotCompatible, "Unicode user-defined operators")` |
| `clang/include/clang/Options/Options.td` | **4070–4073**, immediately after the `defm backtick` block (4066–4069) | `defm unicode_operators : BoolFOption<"unicode-operators", LangOpts<"UnicodeOperators">, DefaultFalse, PosFlag<SetTrue, [], [], "Enable Unicode user-defined operators">, NegFlag<SetFalse>, BothFlags<[], [ClangOption, CC1Option]>>;` |
| `clang/lib/Driver/ToolChains/Clang.cpp` | **7948–7950**, immediately after the `-fbacktick` `addLastArg` | `Args.addLastArg(CmdArgs, options::OPT_funicode_operators, options::OPT_fno_unicode_operators);` |
| `clang/test/Driver/funicode-operators.c` | new, 20 lines | ON / OFF / DEFAULT / BOTH `RUN:` lines |

Nothing else. `CompilerInvocation.cpp` untouched, as the step directed.

## The three names, verbatim (quote these; do not re-derive)

| Thing | Exact spelling |
|-------|----------------|
| Driver / cc1 flag | `-funicode-operators` / `-fno-unicode-operators` |
| TableGen `defm` record | `unicode_operators` |
| Generated option enumerators | `options::OPT_funicode_operators`, `options::OPT_fno_unicode_operators` |
| `LangOptions` member | `LangOpts.UnicodeOperators` (`bool`, 1 bit, default `0`) |
| `LangOptions.def` compatibility kind | `NotCompatible` |
| Diagnostic text derived from the LANGOPT description | `"Unicode user-defined operators"` |

The U00 forward notes predicted `OPT_funicode_operators` /
`OPT_fno_unicode_operators` and were exactly right.

## Verification evidence

**Build:** `ninja -C /home/sdowney/src/llvm/build-unicode clang` →
`BUILD_EXIT=0`, 882 edges incremental (~6 min). No new warnings.

**Full gate:** `ninja -C $B check-clang` → `GATE_EXIT=0`

```
Testing Time: 206.32s
Total Discovered Tests: 54107
  Skipped          :     6 (0.01%)
  Unsupported      :  5853 (10.82%)
  Passed           : 48221 (89.12%)
  Expectedly Failed:    27 (0.05%)
  Failed           :     0
```

Against U00's baseline (54106 / 48220 / 0 / 27 / 5853 / 6) that is **exactly
+1 discovered and +1 passed** — the new driver test — and every other bucket
byte-identical. Zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines in the log.

**Targeted lit:** `funicode-operators.c` and `fbacktick.c`, 2 discovered,
2 passed, 0.09 s.

**cc1 acceptance:** `-funicode-operators`, `-fno-unicode-operators`, and
`-funicode-operators -fbacktick` all exit 0 on a trivial TU.
`-cc1 -funicode-operators -round-trip-args` exits 0 (marshalling generates
and re-parses the flag cleanly).

**Driver forwarding**, `clang -### -funicode-operators -fbacktick`:
```
"-fbacktick"
"-funicode-operators"
```
Both present — U7 composability holds at the driver level.

**Proof the flag actually reaches `LangOpts`** (the step's "Done when"). A
`-###` grep only proves the argv; the AST-file compatibility check proves the
`LangOptions` field. Build a PCH with the flag, load it without:
```
error: Unicode user-defined operators was enabled in precompiled file
       '…/u01.pch' but is currently disabled
```
Loading the same PCH *with* `-funicode-operators` exits 0. That message is
generated from the `NotCompatible` LANGOPT and its description string, so it
can only appear if the flag set `LangOpts.UnicodeOperators`. **This is the
cheapest LangOpts round-trip assertion available — later steps should reuse
it rather than adding a `-###` grep and calling it proof.**

**"Changes nothing observable otherwise":** a TU containing `int c = a ⊞ b;`
produces byte-identical diagnostics with and without the flag (see the
verbatim text in Forward notes for U03).

## Deviations from the plan / design

**None.** No `DEVIATIONS.md` row. Every U00 forward note was accurate: all
three edit sites were where they were said to be, the 5-arg `LANGOPT` form
compiled, and the explicit `addLastArg` was indeed necessary — backtick's
DEV-01/02/03 covered the whole of this step's discovery cost, which is
precisely why this step was cheap.

Two things worth stating because the step file asks:

1. **The backtick `BoolFOption` needed no adjustment whatsoever.** The new
   `defm` sits directly beneath it with the identical shape. The `defm`
   blocks in that region of `Options.td` are not alphabetised, so the two
   flags stay visually adjacent, which is what a reader of the paper wants.
2. **`-funicode-operators` and `-fbacktick` share nothing.** No common
   record, no `Group`, no `ShouldParseIf`. (Contrast `-freflection`, four
   lines above, which carries `ShouldParseIf<cplusplus.KeyPath>`. We did not
   copy that: the flag is deliberately accepted in C mode too, matching
   `-fbacktick`. Whether the *feature* should be C++-only is a U-decision no
   one has made; nothing enforces it yet, and nothing needs to until U03
   gives the flag an effect.)

## Discoveries affecting later steps

- **`-round-trip-args` works and is free.** This is an assertions build, so
  `CompilerInvocation` round-tripping can be requested per-run. Any later
  step that adds a `LangOpt` or a cc1 option gets a free marshalling check
  from it.
- **The PCH-mismatch trick above is the LangOpts assertion of choice.**
  It costs two `-cc1` invocations and no test infrastructure.
- **Incremental build cost after a `LangOptions.def` / `Options.td` edit is
  882 edges, ~6 minutes** — not the 3299/12 min cold figure. Touching those
  two headers rebuilds most of Basic/Driver/Frontend but not all of Sema and
  CodeGen. A `Lexer.cpp`-only edit (U03) will be far smaller; an
  `Options.td`-touching edit is close to the worst case short of cold.
- **`ulimit -c 0` before the gate** still matters (two upstream XFAILs crash
  clang on purpose); it was set for this run and no cores were written.
- Gate wall time was ~11 min with the build already warm.

## Forward notes for the NEXT steps

U02 and U03 are both unblocked in principle, but **U03 depends on U02 as well
as on this step**, so the next runnable step is **U02** (dep: U00 only) —
which does not depend on U01 and touches entirely disjoint files. If two
agents run, U02 is the only one that can start now.

### For U02 — charset tables

U01 gives U02 nothing it needs and takes nothing away; the files are
disjoint (`LangOptions.def` / `Options.td` / `Clang.cpp` vs.
`clang/lib/Lex/`). Everything U02 needs is in **U00's** forward notes, which
remain current — the generator script `docs/pattern-syntax-audit.py`, the
UCD **17.0.0** versioned URL (never `latest`), the
`llvm::sys::UnicodeCharRange` array shape in `clang/lib/Lex/UnicodeCharSets.h`,
the DEV-U01 UCD-18.0-in-tree discrepancy, and the fact that `LexTests` is not
a ninja target (build `AllClangUnitTests`).

One addition from this step: **do not gate the tables on
`LangOpts.UnicodeOperators`.** U02 is pure data plus two pure lookup
functions (`isUserOperatorChar`, `getExclusionReason`); the flag check
belongs at the single call site U03 adds in the lexer, not in the table
header. Keeping the tables flag-free is also what lets U02's unittest call
them directly with no `LangOptions` object.

### For U03 — lexer token

- **The flag test to write is `LangOpts.UnicodeOperators`** — that is the
  member spelling; `LangOpts` is already in scope everywhere in `Lexer.cpp`
  as the `Lexer`'s own `LangOpts` reference. Model the guard on how
  `Lexer.cpp` already tests `LangOpts.Backtick` for the backtick token (the
  backtick diff is present on this branch). The in-tree pattern to copy is
  the **only** `LangOpts.Backtick` reference in `clang/lib/Lex/Lexer.cpp`,
  at **line 4566**:
  ```cpp
  Kind = LangOpts.Backtick ? tok::backtick : tok::unknown;
  ```
  Note the shape: flag *off* falls back to `tok::unknown` rather than
  skipping the classification, which is how backtick got "byte-identical to
  upstream when off" for a single ASCII character. U03's non-ASCII case is
  not identical — off the flag the code point must reach the existing
  `unexpected character` path, not become `tok::unknown` — so copy the
  ternary's spirit, not its literal fallback.
- **The exact off-flag behavior U03 must preserve, verbatim.** Measured on
  this commit, for `int c = a ⊞ b;` at U+229E, and **identical with and
  without `-funicode-operators` today**:
  ```
  error: unexpected character '⊞' U+229E
  error: expected ';' after top level declarator
  ```
  The first is `diag::err_non_ascii` territory in the lexer's non-ASCII slow
  path; the second is the parser recovering. U03's gate says "without the
  flag, lexes exactly as upstream" — *this* is the string to FileCheck
  against, and U05 must phrase its exclusion diagnostics consistently with
  the `'⊞' U+229E` glyph-plus-scalar rendering, which comes from the existing
  `%0`/`%1` formatting of that diagnostic. Reuse that rendering; do not
  invent a second way to print a code point.
- **U03's step 4 caution is already half-satisfied:** the flag currently has
  no effect anywhere, so any behavioral difference U03 observes between the
  two flag states is entirely U03's own doing. Take a `-dump-tokens` snapshot
  of the literal/comment/raw-string cases *before* editing `Lexer.cpp` and
  diff against it; you do not need `build-main` for this, since this branch
  at `3014f97cfc31` is a valid "before" for every U-step.
- **Do not add a second flag check in the driver or `CompilerInvocation`.**
  The plumbing is complete and proven; U03 needs only the `LangOpts` read.

## Open risks / TODOs

- **The flag is accepted in C mode.** No `ShouldParseIf<cplusplus.KeyPath>`,
  matching `-fbacktick`. Harmless while the flag is inert; if U08 or the
  paper concludes the feature is C++-only, the guard goes on the `defm` and
  this handoff is where the decision was deferred from.
- **`-funicode-operators` is `NotCompatible` for AST files.** That is the
  right default (it changes the language), and it is what makes the PCH
  assertion above work. If a later step wants modules built with and without
  the flag to interoperate, that is a deliberate change to this line, not an
  oversight to fix silently.
- Nothing about the *feature* exists yet. `docs/unicode-operators.md` U7 is
  now implemented in full and needs no reconciliation.
