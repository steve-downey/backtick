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

- **`backtick-paper-companion`** — the backtick paper must name its
  precedence level the **user-infix level** and carry a short informative
  future-directions appendix pointing at the Unicode paper, the condition
  [`paper-separation`](docs/unicode-operators.md#paper-separation) split the
  papers under. The mailed D4307R1 does not: its grammar names
  *user-infix-expression*, but it never cites P4345. For R2.
- The blog post (`docs/infix-backtick-operator.org`) does not mention that
  the escape reaches module names
  ([`escape-module-names`](docs/backtick-operator-design.md#escape-module-names));
  D4307R2 carries the wording and the line-start collision. Whether the post
  should is undecided.
- One printer gap, not affecting acceptance: Clang's `-ast-dump` prints a
  declaration's name bare and the same name inside a type escaped. (GCC's
  opposite split was
  [`gcc-type-name-printing`](docs/backtick-operator-design.md#gcc-type-name-printing),
  now fixed.)

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
- `docs/unicode-operators-r1-material.md` — what the 2026-09-23 SG16 review of
  P4345R0 asked for, and the measurements it prompted, as material for a clean
  R1. Seven sections: the MathClass inclusion predicate (with sizes for four
  variants), floor-and-grow and the one-line stabilization ask to Unicode, the
  confusables measurement (only 5 of 12 exclusions are derivable from UTS #39,
  which is why the list stays enumerated), postfix, Scala prior art, the
  citation gaps, and the reversibility principle. **Reverses `token-set`'s
  "settled direction: enumerate".** Each claim is marked *Measured*,
  *Recommended* or *Decided*. The fixity objections from the same review are
  not here — they are in
  [`user-declared-fixity`](docs/unicode-operators.md#user-declared-fixity)'s
  log under 2026-09-23.
- `docs/open-decisions.md` — the questions the implementation measured and
  only the author could settle, one slug-headed page each, with the dated
  answers. All are answered.
- `papers/` — the WG21 papers, **named by name and not by number**: the
  number lives in the front matter and in the prose, because the upload
  system renames whatever is uploaded.
  - `papers/backtick-infix-and-keyword-escape.org` — **D4307R2** in
    progress: R1 as mailed, the infix operator and the keyword escape in one
    paper, rewritten for the committee without the implementation detail and
    history, plus the module-name wording.
  - `papers/unicode-mathematical-operators.org` — **D4345R1** as mailed
    (P4345R0 published).
  - The markdown papers are the pre-mailing drafts:
    `papers/backtick-infix-operator.md` (D4307R1, infix only) and
    `papers/backtick-keyword-escape.md` (DxxxxR0), the two-paper split of
    2026-09-23 that the mailing folded back into one
    ([`paper-bundling`](docs/backtick-operator-design.md#paper-bundling)), and
    `papers/unicode-mathematical-operators.md`. They still build through
    mpark/wg21 (`papers/wg21/`) with `make -C papers -f mpark.mk html pdf`,
    into `papers/generated/`.
  - `make papers` builds the org papers as HTML and PDF and checks the
    result (no external loads, no `Missing character`);
    `make papers/<basename>.pdf` builds one, and `make -C papers help`
    lists the rest. They build with wg21org, vendored as a squashed git
    subtree at `papers/wg21org/` (from `steve-downey/wg21org` `main` on
    GitHub — the same exporter `transcode` uses; **pull from GitHub, not from
    `~/src/wg21org`**, whose local `main` has lagged it and once cost this
    repo the whole pnum/wording vocabulary). The exporter finds its CSS,
    prolog and preamble next to itself, so the subtree carries no local
    edits. **Always `git subtree pull --squash`**: wg21org's own history
    carries the work address this repo was scrubbed of. The exporter refuses
    to run without its pinned org-transclusion submodule, registered here as
    `papers/wg21org/packages/org-transclusion` — the papers Makefile checks
    it out on first use (`make -C papers submodule`). `make -C papers check`
    re-exports both and fails on any external load.
  - **Build the PDF, not only the HTML**, and read the log: a paper can exit
    0 with its content wrong. The Unicode operator glyphs are the live trap —
    Latin Modern has none of them, so both org papers set
    `#+LATEX_COMPILER: lualatex` with a Noto Sans Math / DejaVu fallback and
    DejaVu Sans Mono; grep the `.log` for `Missing character`. (Under mpark
    the matching traps were a `header-includes` key replacing the preamble,
    and `monofont`.)
  - The org papers are in wg21org's own markup
    (`papers/wg21org/AUTHORING.md` is the reference, including its
    "Converting from mpark/wg21 markdown" list): front matter `#+DOCNUMBER` /
    `#+AUDIENCE`; references in `papers/references.bib` for org-cite with
    `#+cite_export: csl`; `[[sref:]]`, `[[insert:]]` / `[[delete:]]`,
    `#+begin_pnum`, `#+begin_grammar` (keywords as `~kw~`),
    `#+begin_wgexample`, and a `:WG21_CHANGE: add` heading for a new
    subclause. Inline code is `~code~`. The `#+bind:` preludes are honoured
    by wg21org's export itself.
  - **The committee papers carry no implementation detail and no
    implementation history**; early feedback was that both were for the
    wrong audience. That material lives in the design docs and the blog
    posts.
- `docs/infix-backtick-operator.org`, `docs/unicode-infix-operators.org`
  (each + a `.meta`) — the blog-post version of each paper, org-mode with a
  Nikola sidecar, in the informal register. Prefer the `voice` skill when
  drafting or editing these or the papers.
- `probes/` — sweeps, in `bash` because `zsh` does not word-split.
  `escape-positions.sh` asks where the keyword escape reaches (a hundred and
  ten one-line programs in six categories, module names the sixth, both
  compilers); `escape-errors.sh`
  asks whether the error paths diagnose and *stop*, under `timeout`;
  `flag-off-parity.sh` asks whether the flag changes a program containing no
  backtick. **Re-run them after touching the escape.** The escape draft
  (`papers/backtick-keyword-escape.md`) links `escape-positions.sh`; the
  mailed paper does not.
- `build/` — `configure-{clang23,clang-trunk,gcc-trunk}-backtick.sh`, the
  reproducible configure invocations (below).
- `examples/` — a CMake project vendored by `git subtree` from
  `steve-downey/backtick-examples`, that *uses* the prototype compilers.
  `make TOOLCHAIN=gcc-backticks`, `clang-23-backticks`, or
  `clang-trunk-backticks` selects an `~/install/` prefix and adds
  `-fbacktick`; see `examples/etc/*-backticks-toolchain.cmake`. Change it
  upstream and `git subtree pull --prefix=examples`.
- **Slide decks** — `make slides`, exported to reveal.js by org-re-reveal, the
  machinery carried over from `steve-downey/cppnow26`'s `trees/`. A deck is
  any org file under `talks/`, **and any `docs/*-talk.org`** — a deck that
  transcludes from a design doc stays next to what it transcludes. A deck
  exports to its own name (`docs/foo-talk.org` → `docs/foo-talk.html`), not to
  a `-slides` suffix: which rule builds a `.html` is decided by whether the
  source is in the Makefile's `DECK_ORGFILES`, not by the output's name. Decks
  are filtered out of `ORGFILES` and `BLOG_ORGFILES`, so `org-html` and
  `blog-md` stay about prose. **A new deck that comes out as a plain XHTML
  article is one that matched neither pattern, or that is missing
  `#+SETUPFILE: ../etc/deck.setup`.**
  - `etc/deck.setup` carries everything common to all decks — reveal root,
    version, `reveal_single_file`, theme, CSS. Its paths are `../`-relative
    and every deck sits one level under the root, which is what lets one file
    serve both `talks/` and `docs/`. A deck sets only what it differs on.
  - `make slides` clones reveal.js 6.0.1 into `.tools/` on first use; both
    that directory and the built HTML are ignored by git. Because
    `deck.setup` sets `#+OPTIONS: reveal_single_file:t`, the built HTML
    inlines all of its CSS and JS and then needs neither `.tools/` nor a
    network — check that by grepping the output for `src=`/`href=` and
    finding only the deliberate hyperlinks.
  - `etc/my_theme.css` is the reveal theme; `etc/modus-{vivendi,operandi}-tinted.css`
    supply the syntax-highlighting classes that `org-html-htmlize-output-type
    'css` emits. Those two are **bare CSS here and HTML `<style>` fragments in
    cppnow26** — `#+REVEAL_EXTRA_CSS` inlines a file inside a `<style>`
    element of its own, and a nested tag silently costs you the first rule.
  - `etc/slide-footer.el` builds the per-slide footer from three variables a
    deck sets in its own Local Variables block. All three are `org-`-prefixed
    on purpose: the export runs in a *copy* of the deck's buffer, and
    `org-element-copy-buffer` carries a buffer-local across only if its name
    matches `^\(org-\|orgtbl-\)`. Under any other prefix the footer silently
    comes out empty. Leaving all three blank emits no postamble at all, which
    is also what keeps the jQuery CDN tag out of a single-file deck.
  - The `.deps` recipes pipe through `xargs -r`. Without it GNU `xargs` runs
    `printf` once on empty input and, since the format carries a `$(dir $<)`
    prefix, writes the *directory* into the deps file as a prerequisite —
    whereupon every file added to that directory rebuilds the deck.

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
  Clang carries it as an `UnresolvedLookupExpr`; GCC parses a bare-name slot
  as a call's callee and builds the call in `cp_parser_backtick_call`, a copy
  of `cp_parser_postfix_expression`'s Koenig rules. Test any change inside a
  template too: that is where GCC's first two fixes still failed.
