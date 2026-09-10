# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## What this repository is

This repo holds **only the design, plan, and operational record** for adding an
infix backtick operator (and a backtick keyword-escape) to C++ — a WG21
proposal prototyped in two real compilers. It contains **no compiler source**.
The actual implementation lives in two external git worktrees (see below); this
repo was split out of the Clang worktree (`[backtick] move planning docs & ops
into standalone repo`). **This repo is the authoritative copy** of the `docs/`
and `ops/` trees — the duplicate copies in the LLVM worktree are being removed,
so make all design-doc / plan / handoff / deviation edits here.

The thesis being tested: `x `op` y` is sugar for `op(x, y)`, desugared in the
front end so overload resolution, ADL, templates, constexpr, and codegen are
all inherited rather than reimplemented. See `docs/backtick-operator-design.md`.

**Current state:** all three implementation tracks are fully checked off —
Clang backtick S00–S12, GCC backtick G01–G10, and Clang Unicode U00–U21
(`ops/unicode-operators/clang/PLAN.md`; the second feature is implemented,
not merely planned). Treat that step machinery as a completed record unless a
*new* step is added to a `PLAN.md`.

**Live work is in `ops/completion/PLAN.md`** — 24 steps, named by slug.
**That is where an agent picks up work.** It supersedes `ops/backlog/PLAN.md`
(BL01–BL04 green; BL05–BL07 absorbed) and covers *all* remaining work in one
plan: the 31 open `BNN` rows in `ops/BACKLOG.md`, the 29 unreconciled rows
across the three DEVIATIONS ledgers, the 7 open design decisions, and the two
papers.

**Every phase is done, A–J, and nothing is waiting on the author.**
Both papers are written and both build, and `docs/open-decisions.md` has no
open question. **Phase J (steps 21–24) is what a fact, cite and voice review
of the two papers found on 2026-09-08**, and all four steps are green: one
live Clang defect — a slot whose value is a class-typed callable
printed as a different program and carried an inverted source range, which is
every lambda the backtick paper's motivation section uses — two sets of
figures in the Unicode paper carried forward from a note, four citation
defects in the backtick paper, and a prose em-dash rate at six times the
author's published-paper rate in both. **The compiler defect is fixed**
(`slot-callable-printing`, on both backtick branches, 2026-09-08:
`CXXOperatorCallExpr` is a `CallExpr`, and the generic arm read it at the
wrong argument indices), and so are the Unicode paper's figures, and so is the
sixth forward-port onto `unicode-operators-experiment`
(`slot-callable-forward-port`, 2026-09-08), and so is the backtick paper
(`backtick-paper-truth`, 2026-09-09: the round-trip claim rewritten from what
the compiler step landed, the `^^` citation split between P2996R13 and
P3381R0 — which rejected the backtick for reflection in print, and is now
engaged by name — and one voice pass taking the em-dash rate from 126 to 17.5
per 10k). The last three steps of Phase I were the backtick paper's own gate
finding four claims the built compilers did not
support: `settle-paper-rows` fixed two and put the other two — one question,
seen from two compilers — to the author; `escape-name-positions` built the
answer, which was to let the keyword escape reach every position the grammar
writes an identifier in; and `escape-name-sweep` swept all of them again, in
four categories rather than one, and closed the two that had held out. **There
is now no program the two compilers treat differently on account of the
keyword escape.** **There is no unchecked step in any plan, and an agent arriving with no other
instruction should not go looking for work in `ops/`.** One deviation row is open, it is a diagnostic
rather than an acceptance divergence, and it is measured and surfaced rather
than owned: `ops/gcc/DEVIATIONS.md#escape-type-name-spelling` — GCC escapes
the name of a *declaration* and prints the name of a *type* bare.

Steps are **named by slug, never numbered** — the checklist's ordinals are
reading order and shift when a step is inserted; the slug is the identity and
is what every cross-reference uses. The plan's own first step,
`slug-the-ledgers`, retired the serial numbers this repo used to carry in its
decision logs, deviation ledgers and backlog, for the same reason.
[`ops/SLUGS.md`](ops/SLUGS.md) is the map from every retired number to its
slug, and it also records what was deliberately *not* renamed. See
`~/.claude/CLAUDE.md`, "Name things for what they are, not what number they
came in at".

It is **ordered by what each item does to a paper**, not by severity and not
by when the item was noticed — the implementation tracks are complete, so the
remaining question is which of these changes what a paper can claim. Phase A
is upstream reports (issues take calendar time to cite), Phase B is the
decisions that need the *author* rather than an implementer, then paper-truth
defects, evidence debt, reconciliation section by section, hygiene, and the
two papers last. `ops/completion/PLAN.md`'s "Coverage" table maps every open
row to its step; nothing in `ops/` is outside it.

No maintenance merge is outstanding. Six have run — M1, M2,
`unicode-branch-maintenance`, and on 2026-09-08 `escape-positions-forward-port`,
`escape-name-sweep-forward-port` and `slot-callable-forward-port`, which carried
`slot-callable-printing`'s callable-slot printer arm onto
`unicode-operators-experiment` and gated green at the Baselines row; the latest
is `ops/completion/handoffs/slot-callable-forward-port.handoff.md`, and between
them the six record what conflicts to expect and where the two features actually
collide. **Check a predicted collision with one `git diff --numstat` before
writing the paragraph about it** — three merges running have turned on that.
A new one is owed only if a later change lands on the backtick branches alone
— the two Clang tracks share `clang/lib/AST`, `clang/lib/Parse` and
`clang/lib/Sema`, and `unicode-operators-experiment` is downstream of
`backtick-trunk`.
`unicode-operators-upstream` is not, and must never receive such a merge.

Maintenance rebases (R-prefixed rows in the `ops/PLAN.md` Status log) are not
plan steps and do not follow `ops/AGENT_PROTOCOL.md`; they still get a handoff
and a Status-log row so base-commit changes are not lost.

## Layout

- `docs/unicode-operators.md` — the Unicode design doc, the exact counterpart
  of the backtick one below: the decisions log (§2, one slugged entry per
  question), the token set, the grammar, the implementation sketch, ABI (§9,
  three slugged subsections — what is implemented, what the paper asks the ABI
  groups for, and the Microsoft gap), and the open questions.
  `papers/unicode-mathematical-operators.md` (D4345R0) is written from it.
- `docs/open-decisions.md` — the questions the implementation measured and
  only the design author can settle, one slug-headed page each (question /
  what was measured / options / cost / recommendation), with the author's
  dated answers recorded at the bottom. Written by `ops/completion`'s
  `decision-brief`; the reconcile steps and both papers cite the answers.
- `docs/backtick-operator-design.md` — the canonical design + decisions log
  (§3, one slugged entry per question), precedence rationale (§4), the
  same-delimiter parsing problem (§5),
  per-compiler implementation plans (§6 Clang, §7 clang-format, §8 GCC), and
  post-implementation clarifications (§17). This is the source of truth the
  paper is written from; deviations get reconciled back into it.
- `papers/` — the two WG21 papers, **named by name and not by number**, per
  `~/.claude/CLAUDE.md`: the number lives in the front matter and in the prose,
  because the upload system renames whatever is uploaded and a name is what a
  reader finds later.
  - `papers/backtick-infix-and-keyword-escape.md` — **D4307R0**, the backtick
    paper, written from `docs/backtick-operator-design.md`.
  - `papers/unicode-mathematical-operators.md` — **D4345R0**, the Unicode
    paper, written from `docs/unicode-operators.md`.
  - `make -C papers <basename>.html <basename>.pdf` builds either. **Build the
    PDF, not only the HTML**, and read the log: a wg21 paper can exit 0 with
    its content wrong. Both traps are live here — a `header-includes` key in
    the front matter silently replaces the wg21 LaTeX preamble (`\pnum` then
    undefined), and Latin Modern carries none of the Unicode operator glyphs,
    so the Unicode paper sets `monofont`.
- `docs/infix-backtick-operator.org` and `docs/unicode-infix-operators.org`
  (each + a `.meta`) — the blog-post version of each paper, org-mode source
  with a Nikola sidecar. Reader-facing prose the design docs feed, in the
  informal register. Prefer the `voice` skill when drafting or editing either.
- `ops/PLAN.md` — master operational checklist (Clang phases A–C, then GCC).
- `ops/gcc/PLAN.md` — the GCC sub-plan (G01–G10).
- `ops/BACKLOG.md` — every defect the three tracks found and left standing,
  one slugged entry each, with a `Closed by` field naming the step that closes
  it. Open *design* questions are not in it; §6 indexes those.
- `ops/SLUGS.md` — the map from every retired serial number to its slug, both
  directions, and the record of what was left numbered on purpose.
- `ops/completion/PLAN.md` — the completion track (24 steps, named by slug), which schedules
  and gates **everything** still outstanding: defects, reconciliation,
  decisions and the papers. **Every box is ticked**; Phase J, steps 21–24,
  was opened by the 2026-09-08 review of the two papers and closed the same
  day. Nothing in it was blocked on the author.
- `docs/open-decisions.md` — the single record of the questions that need the
  author and of the rulings already given. All six are answered, the last
  being `escape-name-positions`; nothing in the completion plan is waiting on
  the author.
- `ops/backlog/PLAN.md` — the defect-fix track (BL01–BL07). Superseded;
  BL01–BL04's Status rows and handoffs are the record of four closed defects.
- `ops/AGENT_PROTOCOL.md` — the one-step-per-agent execution loop. **Read it
  before doing any plan step.**
- `ops/steps/NN-*.md`, `ops/gcc/steps/GNN-*.md` — one self-contained spec per
  step (the "Do" and the verification gate).
- `ops/handoffs/`, `ops/gcc/handoffs/` — one handoff per completed step. The
  previous step's handoff (its "Forward notes" / "Discoveries") **overrides the
  step file where they conflict** and carries the real symbol names, paths, and
  build/test invocations the next agent needs.
- `ops/DEVIATIONS.md`, `ops/gcc/DEVIATIONS.md` — ledger of every place build
  reality contradicted the design (DEV-NN / DEV-GNN), including cross-compiler
  divergences, with reconciliation status.
- `ops/probes/` — the sweeps, in `bash` because `zsh` does not word-split.
  `escape-positions.sh` asks where the keyword escape reaches, as seventy-nine
  one-line programs in four categories run against both compilers;
  `escape-errors.sh` asks whether the error paths diagnose and *stop*, under
  `timeout`; `flag-off-parity.sh` asks whether the flag changes a program
  containing no backtick, byte-identically and against pristine binaries.
  **Re-run them after touching the escape.** They have found something on
  every occasion they have been run, including a parser loop and a
  cross-compiler divergence in the run that installed them here.
- `examples/` — a self-contained CMake project (vendored in via `git subtree`,
  own history) that *uses* the prototype compilers rather than building them.
  `make TOOLCHAIN=gcc-backticks`, `TOOLCHAIN=clang-23-backticks`, and
  `TOOLCHAIN=clang-trunk-backticks` select the three `~/install/` prefixes and
  add `-fbacktick`; see `examples/etc/*-backticks-toolchain.cmake`. This is
  where sample code for the paper gets compiled and run for real.

## The implementation worktrees (where the code actually is)

The Clang track is maintained on **two parallel branches** — one on the LLVM 23
release branch, one on trunk. They carry a byte-identical feature diff and
differ only in their final clang-format-conformance commit; see
`ops/handoffs/13-rebase-release-23x.handoff.md` and
`ops/handoffs/14-rebase-trunk.handoff.md`.

| Track | Branch | Base | Source worktree | Build dir |
|-------|--------|------|-----------------|-----------|
| Clang | `backtick-23` | `upstream/release/23.x` (llvmorg-23.1.0-rc2) | `~/src/llvm/backtick` | `~/src/llvm/build-backtick` |
| Clang | `backtick-trunk` | `upstream/main` | `~/src/llvm/backtick-trunk` | `~/src/llvm/build-backtick-trunk` |
| GCC   | `backtick` | GCC trunk `4df5e1e9b152` | `~/bld/gcc/gcc-backtick` | `~/bld/gcc/gcc-backtick-build` |

Clang tests for both branches: `clang/test/**/backtick-*.cpp`,
`clang/test/Driver/fbacktick.c`, `clang/unittests/Format/`.
GCC tests: `gcc/testsuite/g++.dg/backtick/*.C`.

Note the worktree directory `~/src/llvm/backtick` holds branch **`backtick-23`**,
not a branch named `backtick` — the directory name predates the split and was
kept so `~/src/llvm/build-backtick` stays valid. There is no branch named plain
`backtick` on any LLVM remote; it was deleted when the two lines were split.

**A change to the Clang implementation must be applied to both branches.** Do the
work on one, verify its gate, then cherry-pick and re-verify on the other — the
two bases drift independently, so a clean cherry-pick is not proof of a passing
gate (see the clang-format trap in `ops/handoffs/13-rebase-release-23x.handoff.md`).

The Clang worktrees may still carry stale copies of these `docs/` and `ops/`
trees pending their removal; ignore them and treat this repo as authoritative.
The maintainer's pristine main build is `~/src/llvm/build-main` (`~/src/llvm/main`)
— do **not** disturb it; all feature work happens in the backtick worktrees/builds.

## Build & test

Clang (dev build has assertions on; flag is `-fbacktick`). Substitute
`build-backtick-trunk` / `backtick-trunk` for the trunk branch:
```bash
ninja -C ~/src/llvm/build-backtick clang                 # build
ninja -C ~/src/llvm/build-backtick check-clang           # full regression gate
~/src/llvm/build-backtick/bin/llvm-lit -v \
    ~/src/llvm/backtick/clang/test/Parser/backtick-infix.cpp   # one test
```

Two gotchas that make a failed gate look green — both cost real time already:

- **`ninja … | tail` reports `tail`'s exit code, not ninja's.** Redirect and
  check explicitly: `ninja check-clang > gate.log 2>&1; echo "EXIT=$?"`.
- **`check-clang` self-formats `clang/lib/Format/` *and*
  `clang/unittests/Format/`**, with the **in-tree** `clang-format`, and aborts
  at ~step 81/970 before any lit test runs if the edits there don't match the
  current LLVM style. A conflict-free rebase does not imply a passing gate.
  (Glob corrected by U18; the original wording named only `lib/`.)

**Known failures, and nothing else is acceptable.** The full accounting lives
in `ops/backlog/PLAN.md`'s gate facts; the short form:

- **(closed 2026-08-08)** The 8 `DirectoryWatcherTest.*` cases used to fail
  intermittently when the machine ran out of free inotify watches
  ([inotify-watch-budget](ops/BACKLOG.md#inotify-watch-budget)).
  The root fix is applied: `fs.inotify.max_user_watches` is now 524288, so
  they are ordinary tests — do **not** budget them as expected failures and
  do **not** filter them out. If they ever fail again, check
  `sysctl fs.inotify.max_user_watches` (a reimage or sysctl change could
  revert it) before suspecting your diff.
- **`Clang :: Format/dump-config-objc-stdin.m` on `backtick-23` only** — a
  stray `Language: Cpp` config at `/home/sdowney/src/.clang-format` (dated
  2018, outside any repo) picked up by clang-format walking up the directory
  tree. It fails identically on the pristine `build-main` binary. It **passes**
  on every trunk-based branch, so do not budget it on `backtick-trunk` or the
  Unicode branches — and do not "fix" it by touching that file
  ([stray-clang-format-config](ops/BACKLOG.md#stray-clang-format-config)).

`Analysis/scan-build/cxx-name.test` and `Driver/hip-gz-options.hip` used to
fail here too, from a `CLANG_EXECUTABLE_VERSION` of `23-backtick`/`24-backtick`.
BL01 reverted that on 2026-08-05; both pass now and the suffixed binaries are
gone. If you see them fail again, check the build dir's cache before anything
else ([clang-executable-version](ops/BACKLOG.md#clang-executable-version)).

GCC (dev build is `--disable-bootstrap --enable-languages=c,c++`):
```bash
cd ~/bld/gcc/gcc-backtick-build && make -j18 all-gcc      # build cc1plus
# quick syntax check — use cc1plus directly; xg++ fails (no liblto_plugin.so / cc1 in dev build):
~/bld/gcc/gcc-backtick-build/gcc/cc1plus -fbacktick -std=c++23 -fsyntax-only file.cc
# regression gate (dejagnu), one dir or one file:
make -C gcc check-c++ RUNTESTFLAGS="dg.exp=g++.dg/backtick/*.C"
```

### Installing a track's compiler

Each track can be installed into its own version-suffixed prefix under
`~/install/`, so all three (and any vanilla toolchain already there, e.g.
`~/install/llvm-23`) can coexist on `PATH` without colliding:

| Track | Prefix | Real binary | Symlinks |
|-------|--------|-------------|----------|
| Clang 23 | `~/install/clang-23-backtick` | `clang-23-backtick` | `clang`, `clang++` → it |
| Clang trunk | `~/install/clang-trunk-backtick` | `clang-24-backtick` (trunk's current major) | `clang`, `clang++` → it |
| GCC trunk | `~/install/gcc-trunk-backtick` | `gcc-17-backtick`, `g++-17-backtick`, ... (trunk's current major) | none needed — GCC names every installed program |

`ops/build/configure-{clang23,clang-trunk,gcc-trunk}-backtick.sh` hold the
reproducible configure invocations (this is the fix for "LLVM CMake
reproducibility is difficult without a stored command somewhere, and GCC
`config.status` is fragile" — the invocation lives here, not only in a build
directory's cache). Each script is safe to re-run in an existing build
directory (Clang: only the install prefix and the `clang` target's `VERSION`
property change, so it's a cheap relink, not a rebuild) or to seed a fresh
one:

```bash
# Clang: from a fresh or existing build dir
cd ~/src/llvm/build-backtick && ~/src/backtick/ops/build/configure-clang23-backtick.sh
ninja install

# GCC: from a fresh build dir (re-running configure in an existing one is
# fine for a prefix/suffix-only change, but prefer a fresh dir if unsure)
cd ~/bld/gcc/gcc-backtick-build && ~/src/backtick/ops/build/configure-gcc-trunk-backtick.sh
make -j18 all && make -j18 install
```

`all-gcc` / `install-gcc` are enough for `cc1plus -fsyntax-only` checks, but
they install a compiler with no runtime: no libstdc++ headers, no libasan.
Use the full `all` / `install` above for a prefix that can actually build and
link a project. The Clang side is the same story — both configure scripts put
`compiler-rt` in `LLVM_ENABLE_RUNTIMES` so `-fsanitize=` links; `ninja
runtimes && ninja install-runtimes` adds it to an already-installed prefix.

The Clang mechanism is CMake's native `CLANG_EXECUTABLE_VERSION` (normally
just the LLVM major, e.g. `23`; the scripts append `-backtick`) — the same
mechanism that produces the real `clang-23` binary in a vanilla
`~/install/llvm-23`. The GCC mechanism is `./configure --program-suffix=...`,
which is what `~/install/gcc-17` already uses. Neither script invents a new
renaming convention; both extend the one already in use for the vanilla
installs.

## Working conventions

- **One step per agent, no improvising on process.** Follow `ops/AGENT_PROTOCOL.md`
  exactly: orient → load context (step file + prior handoff + named design
  sections) → execute the "Do" → run the gate → only then tick the box, append a
  Status-log row, commit, and write the next handoff (after reading the next
  step's file). Never start the next step.
- **No green, no check.** A step's checkbox in `PLAN.md` is ticked only after its
  verification gate passes (`check-clang` must stay green for Clang steps). If it
  can't pass: leave it unchecked, write a `BLOCKED` handoff, stop.
- **Everything gated behind the flag.** All new behavior sits behind `-fbacktick`
  (Clang `LangOptions` `Backtick`; GCC `flag_backtick` / `OPT_fbacktick`). A
  default build (flag off) must behave exactly as upstream. Keep diffs minimal —
  touch only what the step names.
- **Commit messages** (in *this* repo and the worktrees): `[backtick] <slug>: <title>`
  for Clang-track work, `[backtick][gcc] <slug>: <title>` for GCC-track, `docs: …`
  for design-doc edits, `ops: …` for plan/ledger bookkeeping. The completed
  tracks used `SNN` / `GNN` / `UNN` and those commits stay as they are — see
  `ops/completion/steps/slug-the-ledgers.md` for why the historical ids are
  deliberately not rewritten.
- **Feedback loop.** When build reality contradicts the design doc, append a row
  to the relevant `DEVIATIONS.md` and reference it in the handoff; the design-doc
  author reconciles it into §3 / the affected section. Record cross-compiler
  divergences in `ops/gcc/DEVIATIONS.md` — they are exactly what CWG/EWG ask about.

## Design facts worth knowing before editing

- **Precedence (§4,
  [precedence-level](docs/backtick-operator-design.md#precedence-level)):**
  highest-precedence *binary* operator — tighter than `*`, looser than
  unary/prefix; operands are cast-expressions, so `-a `f` -b` == `f(-a, -b)`
  (symmetric). The slot is an assignment-expression
  ([slot-grammar](docs/backtick-operator-design.md#slot-grammar)).
- **Same-delimiter problem (§5):** open and close are the same token. Suppress
  the operator interpretation inside the slot — Clang `BacktickIsOperator`
  (modeled on `GreaterThanIsOperator`), GCC `backtick_is_operator_p` (modeled on
  `greater_than_is_operator_p`).
- **Nesting vs. chaining (§17.1,
  [nesting-vs-chaining](docs/backtick-operator-design.md#nesting-vs-chaining)):**
  "bare nesting" is *token-identical* to a left-associative chain
  ([chaining-associativity](docs/backtick-operator-design.md#chaining-associativity))
  and therefore correctly accepted, not diagnosed, by both compilers
  ([bare-nesting-detection](ops/DEVIATIONS.md#bare-nesting-detection),
  [gcc-bare-nesting-detection](ops/gcc/DEVIATIONS.md#gcc-bare-nesting-detection)).
  To nest, parenthesize the slot.
- **Keyword-escape (§12,
  [keyword-escape-coexistence](docs/backtick-operator-design.md#keyword-escape-coexistence)):**
  the same backtick token, disambiguated purely by
  grammatical position (operand/declarator position → escaped identifier;
  post-operand position → infix operator). Yields an ordinary identifier;
  lookup/mangling/ABI unchanged.
- **ADL is normative (§17.4):** the slot must get the same ADL as the plain call.
  Clang carries it as an `UnresolvedLookupExpr`; GCC resolves a bare-name slot
  via explicit `perform_koenig_lookup` (the
  [gcc-slot-adl](ops/gcc/DEVIATIONS.md#gcc-slot-adl) defect, fixed in G10).
