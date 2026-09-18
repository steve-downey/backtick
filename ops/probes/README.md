# Probes — the sweeps, checked in

Three `bash` scripts — **2.0 s, 5.0 s and 0.4 s** on this machine, best of
three consecutive runs each, warm — that ask the questions this feature keeps
getting wrong. **Re-run them after touching the keyword escape.**
They have found something on six of the seven occasions they have been run, and
three of those five were after somebody had written down that the coverage was
complete. **The sixth found nothing, and the run is recorded anyway**: it was
[slot-callable-printing](../completion/steps/slot-callable-printing.md), which
changed the AST printer and not the escape, so a green sweep is the expected
reading rather than a disappointing one. A sweep that is only run when it is
expected to fail stops being a control. **The seventh**,
[escape-any-identifier](../completion/steps/escape-any-identifier.md), found
its own probes out of date: three of `escape-errors.sh`'s malformed escapes
wrapped `notakeyword`, which the content rule made well-formed, and they now
wrap `3`, `+` and `&&`. The GCC printer finding that run produced
([escape-alternative-token-spelling](../gcc/DEVIATIONS.md#escape-alternative-token-spelling))
came from the test suite, not from a sweep.

They are `bash` and they use bash arrays. **`zsh` does not word-split**, and
that has cost this track several sweeps; run them with `bash`, not by typing
their contents into an interactive shell.

| Script | Question | Failure mode it catches |
|---|---|---|
| [`escape-positions.sh`](escape-positions.sh) | Where does the escape reach? | A name position nobody thought of. Ninety-eight one-line programs in five categories — declaration, use, qualified, escapes whose keyword is a *type* keyword, and escapes of a word that is not a keyword at all — run against both compilers. Run it under `STD=c++17` as well as the default: category E must not move. |
| [`escape-errors.sh`](escape-errors.sh) | Does a bad escape diagnose **and stop**? | A parser loop. Twenty-three malformed or unresolvable escapes, each under `timeout`; a timeout is a failure, not a slow test. |
| [`flag-off-parity.sh`](flag-off-parity.sh) | Does the flag change a program containing no backtick? | A leaked flag gate. Byte-identical comparison of flag-on against flag-off, and of flag-off against a pristine upstream binary, over `-fsyntax-only`, `-ast-print`, `-ast-dump` and generated assembly. |

Defaults point at `~/src/llvm/build-backtick-trunk` and
`~/bld/gcc/gcc-backtick-build`; override with `CLANG`, `CC1PLUS`,
`PRISTINE_CLANG`, `PRISTINE_CC1PLUS`, `STD`, `TIMEOUT`. GCC's dev build has no
working `xg++`, so `cc1plus` is the entry point.

```bash
ops/probes/escape-positions.sh              # the coverage table
ops/probes/escape-positions.sh --verbose    # with the diagnostic for each rejection
ops/probes/escape-errors.sh                 # exit 1 if anything hung or was accepted
ops/probes/flag-off-parity.sh               # exit 1 if the flag changed anything
CLANG=~/src/llvm/build-backtick/bin/clang++ ops/probes/escape-positions.sh
```

## Why these are scripts and not a test suite

They are a **map**, not a gate. The suites that pin the answers are
`clang/test/Parser/backtick-escape-positions.cpp`,
`clang/test/Parser/backtick-escape-diagnostics.cpp` and
`gcc/testsuite/g++.dg/backtick/escape-positions.C`, and every row these
scripts report green has a test behind it. What a script buys that a test
suite does not is the ability to ask a question **nobody has written a test
for yet** — which is how all five findings arrived, including the one where
the two compilers disagreed and neither suite failed.

The three questions are genuinely different and the difference has bitten:

- A coverage sweep reads *exit status*, so **rejects** and **never finishes**
  look the same to it. That is why `escape-errors.sh` exists and runs
  everything under `timeout`.
- An error sweep that reads only exit status will not notice that the answer
  was right and the **sentence** was wrong. Reading the diagnostics is what
  found GCC printing an escaped *type* name bare
  ([escape-type-name-spelling](../gcc/DEVIATIONS.md#escape-type-name-spelling)).
- Neither of the first two will notice that the flag changed a program that
  never mentions the feature. That has leaked three times, twice through
  diagnostics, and only byte-identity finds it.
