# Infix Backtick: Worked Examples

[![OpenSSF Baseline](https://www.bestpractices.dev/projects/12577/baseline)](https://www.bestpractices.dev/projects/12577)

Real code from the ranges and senders idioms, rewritten with the infix backtick
operator, and compiled by the two prototype compilers that implement it.

`views::filter(r, pred)` is the primary overload. `views::filter(pred)` is a closure
that remembers `pred` and waits for a range, and `operator|` is what finally applies
it. Two of those three exist because C++ has no way to write the first one between
its arguments.

```c++
r | views::filter(pred) | views::transform(fn)      // today
r `views::filter` pred `views::transform` fn        // the same calls
```

The design, the plan, and both compiler prototypes live in the
[backtick](https://github.com/steve-downey/backtick) repo. This one only uses them.
`backtick-examples.org` is the reading order; `make presentation` exports it, pulling
the code straight out of the sources so nothing in the prose can drift from what
compiles.

## The examples

Every example ships twice, from two sources that differ only in how they spell their
calls: `<name>.pipe.cpp` and `<name>.backtick.cpp`. Both are built by the same
compiler at the same settings, and `<name>.equivalent` requires their output to be
identical and to match a checked-in `<name>.expected`. Two programs agreeing isn't
evidence on its own, so the golden is what pins the behaviour and the pairwise diff
is what pins the claim that only the spelling changed. The `.pipe` half is compiled
with `-fno-backtick`, so it is code proven to build with the feature off.

| | |
|---|---|
| `src/examples/ranges/triples` | Niebler's Pythagorean triples, nested |
| `src/examples/ranges/sieve` | Eratosthenes; every stage converts |
| `src/examples/ranges/calendar` | Niebler's calendar, ported to `std::ranges` and `std::chrono` |
| `src/examples/senders/chain` | `just`/`then`/`when_all`/`sync_wait` |
| `src/examples/senders/hop` | `starts_on` and `continues_on`, which the pipe could never spell |
| `src/examples/senders/scan` | P2300's async inclusive scan, and where the operator stops |
| `src/examples/scorecard` | one compiled instance of each interface shape |
| `src/examples/consteval` | a pipeline evaluated entirely at compile time, sized from the command line |
| `src/examples/gating` | proof that nothing here builds without the flag |

`consteval` is the one pair that is not there to be read as an idiom. It exists to
be measured: it runs its whole pipeline in a `static_assert`, and `-DSMD_EVAL_N=400`
resizes the work so the cost of a spelling can be read as a curve rather than a
single number. The assert checks the pipeline against a hand-written loop over the
same sieve, so it holds at every size and the sweep needs no table of answers.

`src/smd/infix/pipe.hpp` is the only library code: one combinator, for the adaptors
that take nothing beyond their subject and so have no second operand to write.

## What it turned up

Writing these found two things one-line examples would not have, both recorded in
the backtick repo's deviation ledgers:

- **DEV-06 / DEV-G12.** A type name in the operator slot (design D16, carried in the
  paper's wording example as ``a `std::pair` b``) is not implemented by either
  prototype, in any spelling.
- **DEV-G11.** GCC rejects a bare slot name in a dependent context; Clang accepts it.

Repros for both are in `docs/divergences/`.

## Building

Nothing here builds with a stock compiler. The three toolchains that work are the
prototypes, installed by `ops/build/configure-*-backtick.sh` in the backtick repo:

| `TOOLCHAIN=` | Prefix | Compiler |
|---|---|---|
| `clang-23-backticks` (default) | `~/install/clang-23-backtick` | clang 23.1.0-rc2 |
| `clang-trunk-backticks` | `~/install/clang-trunk-backtick` | clang 24.0.0git |
| `gcc-backticks` | `~/install/gcc-trunk-backtick` | g++ 17.0.0 |

So `make` alone builds with the release/23.x clang prototype, and
`make TOOLCHAIN=gcc-backticks` builds with the GCC one. Each toolchain gets its own
`.build/build-$(TOOLCHAIN)` tree, so all three coexist. By default the build and test
is address sanitized, plus some compatible sanitizers. Alternatives are specified with
CONFIG, e.g. `make TOOLCHAIN=gcc-backticks CONFIG=RelWithDebInfo`.

An example is only done when all three agree. Where the Clang and GCC prototypes
disagree, that is a finding for `ops/gcc/DEVIATIONS.md` in the backtick repo, and the
example gets adjusted afterwards.

## Divergences from the copier template

This project is generated from [steve-downey/example](https://github.com/steve-downey/example)
and mostly follows it. `copier update` will conflict on these deliberate changes:

- `Makefile` defaults `TOOLCHAIN` to `clang-23-backticks` instead of falling back to
  `etc/toolchain.cmake` and the system compiler, and drops the `papers/wg21` targets
  (the paper this code feeds lives in the backtick repo).
- `CMakePresets.json` replaces the eight Beman CI presets with one per prototype.
- `.github/workflows/{ci_tests.yml,test_makefile.yaml,codeql.yml}` are removed: they
  compile the project in containers with stock compilers, which cannot work here.
  The pre-commit, doxygen, dependency-review, and scorecard workflows are kept.
- `.pre-commit-config.yaml` runs the prototype's `clang-format`, since only that one
  has a rule for the operator, and skips `*.expected`, which is golden output compared
  byte for byte. It also skips the vendored `infra/` subtree.
- `cmake/add_paired_example.cmake`, `cmake/compare-output.cmake`,
  `cmake/compare-golden.cmake` and `cmake/require-gated.cmake` are new.


## Building presentations with Emacs and org-transclusion

This project uses [nobiot's org-transclusion](https://github.com/nobiot/org-transclusion) and org-export to produce an HTML file for use in presentations. Every example carries `// <uuid>` … `// <uuid> end` anchor pairs, and `backtick-examples.org` names them, so the prose gets the code that actually compiled and no more of it than is useful.

`make presentation` builds the project, runs the tests, and then runs the org export.

The `infra` directory is vendored in from the Beman Project via `git subtree`.

The makefile provides a variety of tools. It will install most borrowing from PyPI as long as `uv` is available. The installation is in a local `.venv` so as not to mess up the rest of your environment.

```shell
(backtick-examples) sdowney@pwyll:~/src/surround/backtick-examples (main ±)
$ make help
clean                          Clean the build artifacts
clean-reconf                   Delete the current configured build tree
clean-venv                     Delete python virtual env
compile                        Compile the project
compile_commands.json          symlink the current compile commands db
compile-headers                Compile the headers
coverage                       Build and run the tests with the GCOV profile and process the results
ctest                          Run CTest on current build
dev-shell                      Shell with the venv activated
docs                           Build the docs with Doxygen
help                           Show this help.
install                        Install the project
install-uv                     install uv via `pipx install uv`
lint                           Run all configured tools in pre-commit
lint-manual                    Run all manual tools in pre-commit
mrdocs                         Build the docs with MrDocs
reconf                         Recreate the current configured build tree
realclean                      Delete the generated build infrastructure
show-venv                      Debugging target - show venv details
test                           Rebuild and run tests
testinstall                    Test the installed package
venv                           Create python virtual env
view-coverage                  View the coverage report
```

`docs` and `mrdocs` are not included in the example at the moment.

`lint` uses pre-commit to drive the various lint tools.

Use this project as you see fit.

The code in infra is Apache 2.0 licensed, see https://github.com/bemanproject/infra for more details. The CMakeLists.txt is derived from https://github.com/bemanproject/exemplar the purpose of which is to be a concrete but boring example of a well behaved CMake C++ project using the current tools and practices.

The css in `etc/`  is exported from emacs based on the modus tinted themes via `org-html-htmlize-generate-css` .

The Makefile that drives the workflow is mine, is Apache 2.0 licensed, and take what you need from it. No part of it is interesting enough to be protected.
