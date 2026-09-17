# Handoff — escape-any-identifier — Clang trunk is built and gated; GCC and the 23.x branch are not

- **Status:** **PARTIAL — one of three implementations done, gate green on it.
  The box stays unticked.**
- **Branch / commits:**
  - `llvm-project` `claude/backticks-identifier-proposal-gyjab5`, off
    `backtick-trunk` (`28b685c86e`) — **`43508c7c1e`** (the predicate, the
    diagnostic, the tests as written from the source) and **`ccc352392d`**
    (what the built compiler corrected). Opened as
    [steve-downey/llvm-project#1](https://github.com/steve-downey/llvm-project/pull/1)
    against `backtick-trunk`.
  - `backtick-23` — **not touched.** Owed.
  - GCC `backtick` — **not touched.** Owed.
  - `unicode-operators-experiment` — **not touched.** The seventh forward-port
    is owed once both Clang branches carry this.
  - this repo — the decision and its documents, the fifth probe category, and
    the two corrections measurement forced.
- **Date:** 2026-09-17.
- **Opens one row**, [`ast-dump-type-name-spelling`](../../DEVIATIONS.md#ast-dump-type-name-spelling),
  which is older than this change. Closes none. The ledgers read **1 / 1 / 0**.

---

## Where it was done, which is not where the plan says

**There is no `~/src/llvm/backtick-trunk` in this container and no
`~/src/llvm/build-backtick-trunk`.** This ran in a Claude Code web session with
a fresh clone of `steve-downey/llvm-project` and no build directory at all. The
build is `/home/user/build-bt`, configured from scratch:

```
cmake -G Ninja llvm -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_PROJECTS=clang -DLLVM_TARGETS_TO_BUILD=X86 \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DLLVM_USE_LINKER=lld \
  -DLLVM_OPTIMIZED_TABLEGEN=ON -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF
```

Four cores, about 50 minutes for `clang`, another 40 for `check-clang`
including the 444-second test run. **It is not the maintainer's build**: X86
only, no `clang-tools-extra`, Release rather than the dev configuration. Read
the gate below as *this configuration is green*, and re-run it on
`~/src/llvm/build-backtick-trunk` before believing it of the real one.

## The gate

```
ninja check-clang
Testing Time: 444.00s
Total Discovered Tests: 54117
  Skipped          :    14
  Unsupported      :  5866
  Passed           : 48210
  Expectedly Failed:    27
```

No failures, `ninja` exit 0, checked explicitly rather than through a pipe.
Neither of `CLAUDE.md`'s two budgeted failures appeared: `dump-config-objc-stdin.m`
is a `backtick-23` story and this is trunk, and the inotify tests are fixed.

The 19 `backtick-*` lit tests pass on their own too. The sweep
[`ops/probes/escape-positions.sh`](../../probes/escape-positions.sh), clang-only
because this container has no `cc1plus`:

| STD | A | B | C | D | **E** | total |
|---|---|---|---|---|---|---|
| `c++20` | 23/23 | 16/16 | 25/25 | 15/15 | **19/19** | 98/98 |
| `c++17` | 22/23 | 15/16 | 25/25 | 15/15 | **19/19** | 96/98 |

The two C++17 rejections are `decl-concept` and `use-type-constraint`, which
are C++20 features and not escapes. **Category E is identical in both
dialects, which is the decision stated as a measurement.**

## What the change is

`isEscapableWord` — `!Tok.isAnnotation() && Tok.getIdentifierInfo()` — in place
of `IdentifierInfo::isKeyword(getLangOpts())` at both sites in
`clang/lib/Parse/Parser.cpp`, and `err_backtick_escape_not_keyword` renamed to
`err_backtick_escape_not_identifier`. Nothing else in `lib/`. Three properties
fall out of the predicate rather than being coded:

- alternative tokens are in, because `and` carries an `IdentifierInfo` whose
  `TokenID` is `tok::ampamp` — which is precisely why `isKeyword` excluded it;
- punctuation stays out, because `&&` carries no `IdentifierInfo`;
- the annotation guard closes a latent assert the old predicate had.

**clang-format needed nothing, checked rather than assumed.** Its annotator
decides escape-versus-infix by the previous token alone
(`TokenAnnotator.cpp`, `determineTokenType`) and never asks what is inside.

## Two findings, neither of them this change's doing

1. **A function-like macro is not replaced when escaped.** Object-like ones
   are, with the *expanded from macro* note on the diagnostic, which is phase 4
   proving it ran. Function-like ones are replaced only when the name is
   followed by `(`, and after the escape's closing backtick it is not — so
   `` int `FUNC` = 7; `` declares a variable while `FUNC(1)` still expands in
   the same TU. §12 said "neither shields nor causes" and now says both halves.
   `clang/test/Parser/backtick-escape-macros.cpp` pins it.
2. **[`ast-dump-type-name-spelling`](../../DEVIATIONS.md#ast-dump-type-name-spelling)**
   — a declaration's name dumps bare, the same name inside a *type* dumps
   escaped. Predates the content rule (`` `union` `` behaves identically), is
   the mirror of GCC's [`escape-type-name-spelling`](../../gcc/DEVIATIONS.md#escape-type-name-spelling),
   and is asserted in both halves by the ABI test so it cannot drift.

## Forward notes — what the next agent has to do

1. **Cherry-pick onto `backtick-23` and gate it there.** A clean cherry-pick is
   not proof of a passing gate; budget `dump-config-objc-stdin.m` on that
   branch and nothing else.
2. **GCC.** The same predicate in the arm the escape shares with
   `cp_parser_identifier`, plus the matching diagnostic, plus the same tests
   under `gcc/testsuite/g++.dg/backtick/`. **Confirm the symbol names in the
   worktree**; this handoff has not read GCC's source.
3. **Re-run the probes with both compilers.** The table above has an empty GCC
   column. Run the sweep twice per compiler, `STD=c++17` and `STD=c++20`, and
   put the real totals in §12's table — paste what the script printed, do not
   add arithmetic to the old numbers.
4. **The seventh forward-port**, after both Clang branches carry it, onto
   `unicode-operators-experiment` only. Predict the collision, then check the
   prediction with one `git diff --numstat` before writing the paragraph.
   `Parser.cpp` is the file; the Unicode side does not touch
   `ConsumeBacktickEscape`.
5. **Only then, the paper.** Three sentences say the forks do not implement
   this rule: the abstract's last sentence, the end of *The escape yields an
   ordinary identifier*, and the fifth-sweep paragraph in *Implementation
   experience*. They come out when GCC lands, not when Clang does. Half a rule
   implemented is not the rule.
6. **Then tick the box** in [`ops/completion/PLAN.md`](../PLAN.md) and write
   the Status-log row. It is unticked on purpose: this agent did a third of the
   step and says so.
