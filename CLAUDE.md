# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## What this repository is

The design documents, the two WG21 papers, and the supporting scripts for
adding an infix backtick operator and a backtick keyword escape to C++, plus
the Unicode-operator companion proposal. It contains **no compiler source**;
the prototypes live in two forks (below).

The thesis being tested: `` x `op` y `` is sugar for `op(x, y)`, desugared in
the front end so overload resolution, ADL, templates, constexpr, and codegen
are all inherited rather than reimplemented. See
`docs/backtick-operator-design.md`.

The implementation work that produced this is finished. The step-by-step
plans, handoffs, and deviation ledgers it ran on were transient and have been
removed; git history still has them. What is still open:

- **`gcc-dependent-slot-lookup`** — a GCC prototype defect. GCC drops the
  definition-context ordinary lookup for every dependent slot and keeps only
  ADL, so `` t `pipe` inc `` is rejected inside a template where
  `pipe(t, inc)` compiles. Clang is the conforming side. §17.4 and the
  backtick paper print the divergence; fixing it un-qualifies both.
- **`backtick-paper-companion`** — the backtick paper must name its precedence
  level the **user-infix level** and carry a short informative
  future-directions appendix pointing at the Unicode paper, the condition
  [`paper-separation`](docs/unicode-operators.md#paper-separation) split the
  papers under. It should land before the two papers go in together.
- Two printer gaps, neither affecting acceptance: GCC escapes a
  *declaration's* name but prints a *type's* name bare, and Clang's
  `-ast-dump` does the mirror image.

When auditing for outstanding work, read the design docs' lists of what each
paper must carry, not only the decision logs.

## Layout

- `docs/backtick-operator-design.md` — the canonical backtick design and
  decisions log (§3, one slugged entry per question), precedence rationale
  (§4), the same-delimiter parsing problem (§5), per-compiler implementation
  notes (§6 Clang, §7 clang-format, §8 GCC), and post-implementation
  clarifications (§17). The backtick paper is written from it.
- `docs/unicode-operators.md` — the Unicode design doc, the counterpart of the
  one above: decisions log (§2), token set, grammar, implementation sketch,
  ABI (§9), open questions. The Unicode paper is written from it.
- `docs/open-decisions.md` — the questions the implementation measured and
  only the author could settle, one slug-headed page each, with the dated
  answers. All are answered.
- `papers/` — the two WG21 papers, **named by name and not by number**: the
  number lives in the front matter and in the prose, because the upload
  system renames whatever is uploaded.
  - `papers/backtick-infix-and-keyword-escape.md` — **D4307R1** (P4307R0
    published).
  - `papers/unicode-mathematical-operators.md` — **D4345R1** (P4345R0
    published).
  - `make -C papers <basename>.html <basename>.pdf` builds either. **Build the
    PDF, not only the HTML**, and read the log: a wg21 paper can exit 0 with
    its content wrong. A `header-includes` key in the front matter silently
    replaces the wg21 LaTeX preamble (`\pnum` then undefined), and Latin
    Modern carries none of the Unicode operator glyphs, so both papers set
    `monofont`.
- `docs/infix-backtick-operator.org`, `docs/unicode-infix-operators.org`
  (each + a `.meta`) — the blog-post version of each paper, org-mode with a
  Nikola sidecar, in the informal register. Prefer the `voice` skill when
  drafting or editing these or the papers.
- `probes/` — sweeps, in `bash` because `zsh` does not word-split.
  `escape-positions.sh` asks where the keyword escape reaches (ninety-eight
  one-line programs in five categories, both compilers); `escape-errors.sh`
  asks whether the error paths diagnose and *stop*, under `timeout`;
  `flag-off-parity.sh` asks whether the flag changes a program containing no
  backtick. **Re-run them after touching the escape.** The backtick paper
  links `escape-positions.sh`.
- `build/` — `configure-{clang23,clang-trunk,gcc-trunk}-backtick.sh`, the
  reproducible configure invocations (below).
- `examples/` — a CMake project vendored by `git subtree` from
  `steve-downey/backtick-examples`, that *uses* the prototype compilers.
  `make TOOLCHAIN=gcc-backticks`, `clang-23-backticks`, or
  `clang-trunk-backticks` selects an `~/install/` prefix and adds
  `-fbacktick`; see `examples/etc/*-backticks-toolchain.cmake`. Change it
  upstream and `git subtree pull --prefix=examples`.

## The implementation branches

| Track | Fork branch | Base | Source worktree | Build dir |
|-------|-------------|------|-----------------|-----------|
| Clang | `backtick-23` | `release/23.x` | `~/src/llvm/backtick` | `~/src/llvm/build-backtick` |
| Clang | `backtick-trunk` | LLVM `main` | `~/src/llvm/backtick-trunk` | `~/src/llvm/build-backtick-trunk` |
| Clang | `unicode-operators-experiment` | `backtick-trunk` | `~/src/llvm/unicode` | |
| Clang | `unicode-operators-upstream` | LLVM `main`, no backtick | `~/src/llvm/unicode-upstream` | |
| GCC   | `backtick` | GCC trunk `4df5e1e9b152` | `~/bld/gcc/gcc-backtick` | `~/bld/gcc/gcc-backtick-build` |

The LLVM branches are on `steve-downey/llvm-project`, the GCC one on
`steve-downey/gcc`. The directory `~/src/llvm/backtick` holds branch
**`backtick-23`**; there is no branch named plain `backtick` on the LLVM fork.

Clang tests: `clang/test/**/backtick-*.cpp`, `clang/test/Driver/fbacktick.c`,
`clang/unittests/Format/`. GCC tests: `gcc/testsuite/g++.dg/backtick/*.C`.

**A change to the Clang backtick implementation goes on both backtick
branches.** Do it on one, pass its gate, cherry-pick, and pass the gate again
on the other: the bases drift, so a clean cherry-pick is not a passing gate.
`unicode-operators-experiment` is downstream of `backtick-trunk`, so a change
landing on the backtick branches alone owes it a merge (the tracks share
`clang/lib/AST`, `Parse` and `Sema`); check a predicted collision with
`git diff --numstat` before writing about it. `unicode-operators-upstream`
must never receive such a merge.

The maintainer's pristine build is `~/src/llvm/build-main` (`~/src/llvm/main`);
do **not** disturb it.

## Build & test

Clang (dev build has assertions on; flag is `-fbacktick`). Substitute
`build-backtick-trunk` / `backtick-trunk` for the trunk branch:
```bash
ninja -C ~/src/llvm/build-backtick clang                 # build
ninja -C ~/src/llvm/build-backtick check-clang           # full regression gate
~/src/llvm/build-backtick/bin/llvm-lit -v \
    ~/src/llvm/backtick/clang/test/Parser/backtick-infix.cpp   # one test
```

Two gotchas that make a failed gate look green:

- **`ninja … | tail` reports `tail`'s exit code, not ninja's.** Redirect and
  check explicitly: `ninja check-clang > gate.log 2>&1; echo "EXIT=$?"`.
- **`check-clang` self-formats `clang/lib/Format/` and
  `clang/unittests/Format/`** with the in-tree `clang-format`, and aborts at
  about step 81/970, before any lit test runs, if edits there don't match the
  current LLVM style. A conflict-free rebase does not imply a passing gate.

Known failures, and nothing else is acceptable:

- **`Clang :: Format/dump-config-objc-stdin.m` on `backtick-23` only** — a
  stray `Language: Cpp` config at `/home/sdowney/src/.clang-format` (2018,
  outside any repo) is picked up by clang-format walking up the tree. It fails
  identically on the pristine binary and passes on every trunk-based branch.
  Do not budget it elsewhere, and do not "fix" it by touching that file.
- `DirectoryWatcherTest.*` is **not** a known failure. It used to fail when
  the machine ran out of inotify watches; `fs.inotify.max_user_watches` is now
  524288. If it fails again, check that sysctl before suspecting your diff.
- If `Analysis/scan-build/cxx-name.test` or `Driver/hip-gz-options.hip`
  fails, check the build dir's `CLANG_EXECUTABLE_VERSION` first; a
  `-backtick` suffix there breaks both.

GCC (dev build is `--disable-bootstrap --enable-languages=c,c++`):
```bash
cd ~/bld/gcc/gcc-backtick-build && make -j18 all-gcc      # build cc1plus
# quick syntax check — use cc1plus directly; xg++ fails (no liblto_plugin.so / cc1 in dev build):
~/bld/gcc/gcc-backtick-build/gcc/cc1plus -fbacktick -std=c++23 -fsyntax-only file.cc
# regression gate (dejagnu), one dir or one file:
make -C gcc check-c++ RUNTESTFLAGS="dg.exp=g++.dg/backtick/*.C"
```

### Installing a track's compiler

Each track installs into its own version-suffixed prefix under `~/install/`,
so all of them and any vanilla toolchain can coexist on `PATH`:

| Track | Prefix | Real binary | Symlinks |
|-------|--------|-------------|----------|
| Clang 23 | `~/install/clang-23-backtick` | `clang-23-backtick` | `clang`, `clang++` → it |
| Clang trunk | `~/install/clang-trunk-backtick` | `clang-24-backtick` (trunk's current major) | `clang`, `clang++` → it |
| GCC trunk | `~/install/gcc-trunk-backtick` | `gcc-17-backtick`, `g++-17-backtick`, ... | none needed |

`build/configure-*.sh` hold the configure invocations, so they live somewhere
other than a build directory's cache. Each is safe to re-run in an existing
build directory (for Clang only the install prefix and the `clang` target's
`VERSION` change, a cheap relink) or to seed a fresh one:

```bash
# Clang: from a fresh or existing build dir
cd ~/src/llvm/build-backtick && ~/src/backtick/build/configure-clang23-backtick.sh
ninja install

# GCC: from a fresh build dir
cd ~/bld/gcc/gcc-backtick-build && ~/src/backtick/build/configure-gcc-trunk-backtick.sh
make -j18 all && make -j18 install
```

`all-gcc` / `install-gcc` are enough for `cc1plus -fsyntax-only`, but install
no runtime (no libstdc++ headers, no libasan); use the full `all` / `install`
for a prefix that can build and link a project. Both Clang scripts put
`compiler-rt` in `LLVM_ENABLE_RUNTIMES`; `ninja runtimes && ninja
install-runtimes` adds it to an installed prefix. The Clang renaming is
CMake's `CLANG_EXECUTABLE_VERSION` with `-backtick` appended; the GCC one is
`--program-suffix`.

## Working conventions

- **Everything is gated behind the flag.** New behavior sits behind
  `-fbacktick` (Clang `LangOptions` `Backtick`; GCC `flag_backtick` /
  `OPT_fbacktick`), or `-funicode-operators` for the Unicode work. With the
  flag off, a build must behave exactly as upstream.
- **Commit messages:** `[backtick] <slug>: <title>` on the Clang branches,
  `[backtick][gcc] <slug>: <title>` on the GCC branch, `docs: …` or
  `papers: …` here.
- **Name things by slug, never by serial number.** A serial number says
  nothing about what it names and shifts when a list is reordered; a slug
  named for the question survives its answer changing. Decisions in the
  design docs are slug-headed anchors, and each records the number it used to
  carry as `Formerly`.
- **When the build contradicts the design, fix the design doc.** Record the
  measurement in the affected section or decision's Log, and note
  cross-compiler divergences explicitly; they are what CWG and EWG ask about.

## Design facts worth knowing before editing

- **Precedence (§4,
  [precedence-level](docs/backtick-operator-design.md#precedence-level)):**
  highest-precedence *binary* operator — tighter than `*`, looser than
  unary/prefix; operands are cast-expressions, so `` -a `f` -b `` ==
  `f(-a, -b)`. The slot is an assignment-expression
  ([slot-grammar](docs/backtick-operator-design.md#slot-grammar)).
- **Same-delimiter problem (§5):** open and close are the same token. The
  operator interpretation is suppressed inside the slot — Clang
  `BacktickIsOperator` (modeled on `GreaterThanIsOperator`), GCC
  `backtick_is_operator_p` (modeled on `greater_than_is_operator_p`).
- **Nesting vs. chaining (§17.1,
  [nesting-vs-chaining](docs/backtick-operator-design.md#nesting-vs-chaining)):**
  "bare nesting" is *token-identical* to a left-associative chain
  ([chaining-associativity](docs/backtick-operator-design.md#chaining-associativity))
  and correctly accepted by both compilers. To nest, parenthesize the slot.
- **Keyword escape (§12,
  [keyword-escape-coexistence](docs/backtick-operator-design.md#keyword-escape-coexistence)):**
  the same backtick token, disambiguated by grammatical position
  (operand/declarator position → escaped identifier; post-operand position →
  infix operator). It yields an ordinary identifier; lookup, mangling and ABI
  are unchanged. **The word inside need not be a keyword**
  ([escape-content](docs/backtick-operator-design.md#escape-content)):
  `` `foobar` `` *is* `foobar`. Built on all four branches.
- **ADL is normative (§17.4):** the slot gets the same ADL as the plain call.
  Clang carries it as an `UnresolvedLookupExpr`; GCC resolves a bare-name slot
  with explicit `perform_koenig_lookup`.
