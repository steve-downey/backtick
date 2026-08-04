# U01 — Feature flag `-funicode-operators`

**Goal.** A driver + cc1 flag, default off, reaching `LangOptions` as
`UnicodeOperators`. No behavior change yet — this step only makes the
switch exist and arrive.

**Depends on:** U00.
**Design refs:** U7 (own flag, composable with `-fbacktick`); backtick
design §6.5 and `ops/DEVIATIONS.md` DEV-01/02/03, which already paid for
this exact plumbing.

## Do
1. Add `LANGOPT(UnicodeOperators, 1, 0, NotCompatible, "Unicode user-defined operators")`
   to `clang/include/clang/Basic/LangOptions.def` (5-arg form — DEV-02).
2. Add the `BoolFOption` for `-funicode-operators` / `-fno-unicode-operators`
   in `clang/include/clang/Options/Options.td` (note the path — DEV-01),
   directly alongside the existing `-fbacktick` entry.
3. Add the explicit `Args.addLastArg(CmdArgs, options::OPT_funicode_operators,
   options::OPT_fno_unicode_operators)` in `Clang.cpp::ConstructJob()` —
   marshalling alone does **not** forward it (DEV-03).
4. Nothing else. No lexer, no parser, no diagnostic.

## Build
`ninja -C ~/src/llvm/build-unicode clang`

## Verify (gate)
- New driver test `clang/test/Driver/funicode-operators.c`: the flag is
  accepted, `-###` shows it forwarded to cc1, `-fno-` suppresses it, and it
  is absent by default.
- `-funicode-operators -fbacktick` together are accepted and both forward
  (U7 composability — assert it here, once, cheaply).
- `check-clang` green.

## Done when
The flag round-trips driver → cc1 → `LangOpts.UnicodeOperators`, alone and
with `-fbacktick`, and changes nothing observable otherwise.

## Capture in handoff
The exact option record name, the `LangOpts` member spelling, and whether
the backtick `BoolFOption` needed any adjustment to sit next to it.

## REPLAY ledger
Every line of this step is `upstream replay` — the flag is independent of
backtick by construction. Say so explicitly in the row; U20 should be able
to lift this commit unmodified.
