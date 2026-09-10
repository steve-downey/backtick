# Handoff — U00 Experiment worktree, branch, and baseline gate

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `bd6f4d5fa102edef9888640e661aac5e76e0c07d`
  (no source change; identical to `backtick-trunk` tip)
- **Date / agent:** 2026-08-03

## What changed

No compiler source. Infrastructure only, plus plan-repo bookkeeping.

**In `/home/sdowney/src/llvm/`:**
- New worktree `/home/sdowney/src/llvm/unicode` on new branch
  `unicode-operators-experiment`, created from `backtick-trunk`.
- New build dir `/home/sdowney/src/llvm/build-unicode`.
- Nothing else touched. `main`, `build-main`, `backtick`, `build-backtick`,
  `backtick-trunk`, `build-backtick-trunk` are all as they were.

**In this repo:**
- `PLAN.md` — U00 ticked; Status-log row appended; the "Build & test" block
  rewritten from *intended* to *pinned/measured* (see "Deviations" below —
  the known-failure text was wrong for this base).
- `REPLAY.md` — first row (U00, `backtick dependency`: the base itself).
- `DEVIATIONS.md` — DEV-U01 (Clang's in-tree Unicode tables are UCD **18.0**,
  not the 17.0 the design derives against).
- This handoff.

## Pinned values (quote these; do not re-derive)

```bash
WT=/home/sdowney/src/llvm/unicode           # worktree, branch unicode-operators-experiment
B=/home/sdowney/src/llvm/build-unicode      # build dir
```

| Thing | Value |
|-------|-------|
| Branch | `unicode-operators-experiment` |
| Base commit (= `backtick-trunk` tip) | `bd6f4d5fa102edef9888640e661aac5e76e0c07d` |
| **`upstream/main` commit under it (U20 needs this)** | `bb33de72920a7a62633af0f1ab484d114a07fe7f` |
| Backtick commits on top of upstream | 45 (`git rev-list --count upstream/main..HEAD`) |
| Compiler version string | `clang version 24.0.0git (…bd6f4d5fa102)`, `Build config: +assertions` |
| Built binary | `$B/bin/clang` → `clang-24` |
| Build cost, cold | **735 s (12 m 15 s)**, 3299 ninja edges, `clang` target only |
| `check-clang` cost | **723 s (12 m 03 s)** wall; of which 204.45 s is lit testing, the rest builds test deps |
| Disk after `clang` + `check-clang` | build dir **4.9 G**, worktree 2.6 G (`build-backtick-trunk` is 7.4 G — it has built more targets). 454 G free on `/`. |

**CMake line, verbatim, as run:**

```bash
cmake -G Ninja \
  -S /home/sdowney/src/llvm/unicode/llvm \
  -B /home/sdowney/src/llvm/build-unicode \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra" \
  -DLLVM_ENABLE_RUNTIMES="compiler-rt" \
  -DLLVM_TARGETS_TO_BUILD=host \
  -DBUILD_SHARED_LIBS=OFF \
  -DLLVM_OPTIMIZED_TABLEGEN=OFF \
  -DLLVM_CCACHE_BUILD=OFF \
  -DCMAKE_C_COMPILER=clang-23 \
  -DCMAKE_CXX_COMPILER=clang++-23 \
  -DLLVM_PARALLEL_COMPILE_JOBS=12 \
  -DLLVM_PARALLEL_LINK_JOBS=1 \
  -DCMAKE_INSTALL_PREFIX=/home/sdowney/install/clang-trunk-unicode
```

This is `build-backtick-trunk`'s configuration, not
`ops/handoffs/00-baseline.handoff.md`'s. See "Deviations".

## Verification evidence

**Gate — `ninja -C $B check-clang`, `NINJA_EXIT=0`:**

```
Testing Time: 204.45s
Total Discovered Tests: 54106
  Skipped          :     6 (0.01%)
  Unsupported      :  5853 (10.82%)
  Passed           : 48220 (89.12%)
  Expectedly Failed:    27 (0.05%)
  Failed           :     0
```

Zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines in the log. **Byte-for-byte the
same counts** `ops/handoffs/14-rebase-trunk.handoff.md` recorded for
`backtick-trunk` — which is the strongest available evidence that the new
worktree and build dir are faithful clones of the reference setup.

**Inherited-backtick smoke test** (step "Do" item 5), on a file carrying
basic infix, a left-assoc chain, a qualified slot, and a D10 keyword escape:

```
clang -cc1 -fbacktick -std=c++23 -fsyntax-only  → exit 0
clang      -fbacktick -std=c++23 -fsyntax-only  → exit 0   (driver forwards)
clang                 -std=c++23 -fsyntax-only  → error: expected ';' after
                                                  top level declarator  (correct:
                                                  default build is upstream)
clang -cc1 -fbacktick -ast-dump                 → 4 × BacktickInfixExpr
```

**Targeted lit** (pins the fast-gate command shape):

```
$B/bin/llvm-lit -sv $WT/clang/test/Parser/backtick-infix.cpp \
                    $WT/clang/test/Parser/backtick-precedence.cpp \
                    $WT/clang/test/Driver/fbacktick.c
→ 3 discovered, 3 passed
```

## Deviations from the plan / design

**1. The step file's and PLAN.md's known-failure rule was wrong for this base.**
Both said green means "**exactly one** failure,
`Clang :: Format/dump-config-objc-stdin.m`". On this base green is **zero**
failures — that test passes on trunk. The one-failure rule is a `backtick-23`
fact that leaked into this track's step text;
`ops/handoffs/14-rebase-trunk.handoff.md` already recorded that trunk tolerates
the stray `/home/sdowney/src/.clang-format` (which is still present at
`/home/sdowney/src/.clang-format`, untouched). **I corrected the PLAN.md "Build
& test" block** rather than leave a wrong gate rule in the operational document
— U00 is the step PLAN.md designates to pin those values. No DEVIATIONS row:
this contradicts the plan, not `docs/unicode-operators.md`.

**2. The CMake configuration came from the live build dir, not from
`ops/handoffs/00-baseline.handoff.md`,** as the orchestrator directed. The
step file says to copy the older handoff's invocation verbatim; that handoff
is a year old and describes the *original* `backtick` build. Two real
differences, both resolved in favour of the live `build-backtick-trunk`:
- `LLVM_ENABLE_RUNTIMES=compiler-rt` — the old handoff says "no runtimes".
- `CMAKE_INSTALL_PREFIX` — pointed at a fresh
  `/home/sdowney/install/clang-trunk-unicode` so a stray `ninja install`
  cannot clobber `clang-trunk-backtick`. This is the one intentional
  divergence from the reference cache.

Everything else (`Release`, assertions ON, `clang;clang-tools-extra`,
targets=host, static libs, un-optimized tablegen, no ccache, clang-23
compilers, 12 compile / 1 link job) is identical; verified by diffing the two
`CMakeCache.txt` files key by key. The only residual diff is cosmetic —
CMake resolved `clang-23` to `/usr/bin/clang-23`.

**3. DEV-U01 filed:** Clang's in-tree Unicode tables are **UCD 18.0**, the
design derives against **UCD 17.0**. Details in `DEVIATIONS.md`; consequences
for U02 in the forward notes below.

## Discoveries affecting later steps

- **`LexTests` is not a ninja target.** The 00-baseline handoff's finding still
  holds on trunk: `clang/unittests/Lex/CMakeLists.txt` says
  `add_clang_unittest(LexTests …)`, but that folds into the single
  `AllClangUnitTests` binary. Distinct binaries that *do* exist:
  `SemaTests`, `FormatTests`, `BasicTests`,
  `ClangReplInterpreterTests`, `ClangScalableAnalysisTests`. To run a Lex
  unittest (U02 adds one):
  ```bash
  ninja -C $B AllClangUnitTests
  $B/tools/clang/unittests/AllClangUnitTests --gtest_filter='Lex*'
  ```
- **A cold `clang` build here is 12 minutes, not hours.** 20 cores, 91 G RAM,
  page cache warm from the sibling worktree. `check-clang` is another 12.
  Budget ~25 minutes for a full build-and-gate cycle per step — but note both
  exceed the 10-minute Bash timeout ceiling, so run them backgrounded and poll.
- **`ulimit -c 0` before the gate.** Two upstream XFAIL tests crash clang on
  purpose; without it you get multi-MB cores and desktop crash popups. They are
  counted in `Expectedly Failed` and are not ours.
- 462 G free on `/` before this work; the new build dir is the only consumer
  added.

## Forward notes for the NEXT steps

U01 and U02 both depend only on U00 and **touch disjoint files** — they can be
done in either order, or concurrently by two agents, without conflict. U01 is
the smaller.

### U01 — flag `-funicode-operators`

All three edit sites are verified present in this worktree. Model the new flag
on `-fbacktick`, which sits at each of them:

1. `clang/include/clang/Basic/LangOptions.def` **line 536**:
   ```
   LANGOPT(Backtick        , 1, 0, NotCompatible, "backtick operator and identifier escaping")
   ```
   Add `UnicodeOperators` beside it in the same 5-arg form (DEV-02 of the
   backtick ledger). Note the column alignment of the existing entries.
2. `clang/include/clang/Options/Options.td` **lines 4066–4069** — note the
   path is `clang/include/clang/Options/`, **not** `clang/include/clang/Driver/`
   (backtick DEV-01):
   ```
   defm backtick : BoolFOption<"backtick",
     LangOpts<"Backtick">, DefaultFalse,
     PosFlag<SetTrue, [], [], "Enable backtick infix operator and identifier escaping">,
     NegFlag<SetFalse>, BothFlags<[], [ClangOption, CC1Option]>>;
   ```
   Copy that shape exactly. The `BothFlags<[], [ClangOption, CC1Option]>` is
   required and is *still* not sufficient — see (3). The entry sits between
   `-freflection` and `-fsized-deallocation`; `defm` blocks there are not
   alphabetised, so placing `unicode_operators` directly after `backtick` is
   fine and keeps the two visible together.
3. `clang/lib/Driver/ToolChains/Clang.cpp` **line 7945–7946**:
   ```cpp
   // -fbacktick enables the backtick infix operator and identifier escaping.
   Args.addLastArg(CmdArgs, options::OPT_fbacktick, options::OPT_fno_backtick);
   ```
   This explicit `addLastArg` is backtick DEV-03 and it is **load-bearing**:
   marshalling alone parses the flag but never emits it into the cc1 argv.
   Add the parallel two lines. The option record names TableGen will generate
   are `OPT_funicode_operators` / `OPT_fno_unicode_operators` (underscores for
   the hyphens).
4. The step says "nothing else" — heed it. Do **not** touch
   `CompilerInvocation.cpp`; `MarshallingInfoFlag` handles the round-trip.
5. Test: copy `clang/test/Driver/fbacktick.c` as the template for
   `clang/test/Driver/funicode-operators.c`; it already has the
   `-###`-forwarding and default-absent idioms. The U7 composability assertion
   (`-funicode-operators -fbacktick` together, both forwarded) has no
   precedent to copy — write it as one extra `RUN:` line in that new file.
6. Gate: `check-clang` must stay at **0 failures**, not "one known failure".

### U02 — the U1 range table and the exclusion table

- **The generator script is `docs/pattern-syntax-audit.py` in *this* repo**, and
  it already derives the final set — the `--emit-header` mode is an addition to
  working code, not a rewrite. Its docstring names the five UCD files it needs
  in `argv[1]`: `PropList.txt`, `DerivedAge.txt`, `UnicodeData.txt`,
  `DerivedCoreProperties.txt`, `emoji-data.txt` (the last under `ucd/emoji/`).
  Fetch from `https://www.unicode.org/Public/17.0.0/ucd/` — **the versioned
  path, never `latest/`** (the step's own pitfall; `latest` is 18.0 now, see
  next bullet, so this is not hypothetical).
- **Shape to match, in `clang/lib/Lex/UnicodeCharSets.h`:**
  ```cpp
  #include "llvm/Support/UnicodeCharRanges.h"
  static const llvm::sys::UnicodeCharRange XIDStartRanges[] = {
      {0x0041, 0x005A},   {0x0061, 0x007A},   …
  ```
  i.e. a plain `static const llvm::sys::UnicodeCharRange Name[] = {…}` array of
  `{first, last}` pairs, three per line, sorted. Lookup is
  `llvm::sys::UnicodeCharSet(Ranges).contains(C)` — `UnicodeCharSet`'s
  constructor **already asserts sortedness and non-overlap** in an assertions
  build (this is an assertions build), so the step's "table is sorted and
  non-overlapping" gate is largely free; still assert it explicitly, since the
  check is `NDEBUG`-conditional upstream. `Lexer.cpp` includes
  `llvm/Support/UnicodeCharRanges.h` directly and is the model consumer.
- **DEV-U01 matters here.** The in-tree tables are labelled **Unicode 18.0**
  (`XIDStartRanges` line 13, `XIDContinueRanges` line 252,
  `MathematicalNotationProfileIDStartRanges` line 396,
  `MathematicalNotationProfileIDContinueRanges` line 414), while U1 is pinned
  to 17.0. The U10 disjointness cross-check the step calls "the single most
  valuable assertion" will therefore be U1@17.0 vs XID@18.0. That is a
  *stronger* result if it passes — say so in the handoff. If it fails, it is a
  U10 finding for the paper, not a table typo.
- **The math-identifier carve-out already exists in-tree and matches U10
  exactly.** `MathematicalNotationProfileIDStartRanges` contains precisely
  `{0x2202 ∂, 0x2207 ∇, 0x221E ∞}` plus ten Mathematical-Italic variants
  (U+1D6C1 … U+1D7C3); `MathematicalNotationProfileIDContinueRanges` is
  `{0xB2–0xB3, 0xB9, 0x2070, 0x2074–0x207E, 0x2080–0x208E}`. So U02's
  `IdentifierProfile` exclusion reason can and should cite this array by name
  rather than hard-coding three code points. Watch the near miss:
  Pattern_Syntax's block `0x2055–0x205E` ends five code points before
  ID_Compat_Math_Continue's `0x2070`; that is the tightest gap in the whole
  disjointness argument and is worth an explicit test case.
- The unittest goes in `clang/unittests/Lex/` and runs out of
  `AllClangUnitTests` (see Discoveries) — there is no `LexTests` binary to
  build. Add the new file to `add_clang_unittest(LexTests …)` in
  `clang/unittests/Lex/CMakeLists.txt` anyway; that is still the right list.

## Open risks / TODOs

- **U20's replay target will drift.** `bb33de72920a` is `upstream/main` as of
  the 2026-07-29 rebase; by the time U20 runs, `main` will have moved
  thousands of commits. Recorded here as the *base of this experiment*, which
  is what U19's audit needs; U20 should replay onto then-current `main`.
- The step file's "exactly one known failure" text is corrected in PLAN.md but
  **still stands uncorrected in `steps/U00-baseline.md`** (I left the step file
  alone — steps are specs, and rewriting a completed step's gate would erase
  the record of what was specified). Later steps quote PLAN.md, which is now
  right.
- Neither `-funicode-operators` nor any Unicode behaviour exists yet; the
  branch is byte-identical to `backtick-trunk`. The first commit that changes
  compiler behaviour is U01's.
- The GCC Unicode track (`ops/unicode-operators/gcc-experiment-plan.md`) has no
  operational plan or worktree yet and was not touched.
