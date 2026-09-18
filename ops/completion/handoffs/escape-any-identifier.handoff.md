# Handoff — escape-any-identifier — the escape takes any identifier, in both compilers and on all four branches

- **Status:** **DONE (gate passed).** Finished on 2026-09-17 on the
  maintainer's machine, from where the first session (below, *The first
  third*) stopped.
- **Branch / commits:**
  - `backtick-trunk` (`~/src/llvm/backtick-trunk`) — **fast-forwarded** to
    [PR #1](https://github.com/steve-downey/llvm-project/pull/1)'s head,
    `43508c7c1e96` + **`ccc352392df4`**. Nothing added on top.
  - `backtick-23` (`~/src/llvm/backtick`) — cherry-picks **`029e7192d565`**,
    **`cb2fe74759c2`**. Clean.
  - GCC `backtick` (`~/bld/gcc/gcc-backtick`) — **`0ebcbb73213`**.
  - `unicode-operators-experiment` (`~/src/llvm/unicode`) — **`9b1a1b6c58d8`**,
    the seventh forward-port, `git merge --no-ff ccc352392df4`.
  - `unicode-operators-upstream` — **untouched**, `8c2a90f56b00`.
  - this repo — this file, the plan's box and Status rows, §12 and
    [escape-content](../../../docs/backtick-operator-design.md#escape-content),
    the ruling's `Log` in `docs/open-decisions.md`, the paper, one GCC ledger
    row, `ops/probes/escape-errors.sh`.
  - **Nothing has been pushed**, to `origin` or `ceridwen`, on any repository.
- **Opens and closes one row**,
  [`escape-alternative-token-spelling`](../../gcc/DEVIATIONS.md#escape-alternative-token-spelling),
  a GCC printer finding fixed in the same commit. The ledgers still read
  **1 / 1 / 0** open.

---

## The gates

| Gate | Result |
|---|---|
| `check-clang`, `backtick-trunk`, `build-backtick-trunk` | **54117 discovered / 48231 passed / 0 failed**, XFAIL 27, skipped 6, unsupported 5853, 200.59 s, `EXIT=0` read from the log. The maintainer's build, which the first session's number was not. |
| `check-clang`, `backtick-23`, `build-backtick` | **54351 / 48509 / 1**, XFAIL 27, skipped 6, unsupported 5808. The one is `Format/dump-config-objc-stdin.m`, *Configuration file(s) do(es) not support Objective-C: /home/sdowney/src/.clang-format* — [`stray-clang-format-config`](../../BACKLOG.md#stray-clang-format-config), budgeted on this branch only. |
| `check-clang`, `unicode-operators-experiment`, `build-unicode` | **54192 / 48304 / 0**, XFAIL 27, skipped 6, unsupported 5855, 200.53 s, `EXIT=0`, **zero `warning:` lines**. The last Baselines row, 54190 / 48302, plus the two new test files. |
| GCC `check-c++ RUNTESTFLAGS="dg.exp=g++.dg/backtick/*.C"` | **149 expected passes, 0 unexpected.** `modules.exp=backtick-*` too: **15 / 0**. |
| `escape-positions.sh` | `STD=c++20` **98/98 clang, 98/98 gcc**; `STD=c++17` **96/98 both**, the two being `decl-concept` and `use-type-constraint`. Category E **19/19 in every cell**. Same numbers with `CLANG=` pointed at `build-backtick`. |
| `escape-errors.sh` | **46/46 diagnosed and stopped**, `EXIT=0`, against both trunk and 23.x clang. |
| `flag-off-parity.sh` | **Identical in every flag-on/flag-off cell, both compilers.** Flag-off vs pristine identical for Clang; for GCC's assembly it differs in 2 lines, which are the `.ident` string (`20260906` vs `20260808`) — the branch's base moved when `main` was merged on 2026-09-09 and `build-trunk` did not. Shown, not assumed. |
| papers | `make -C papers backtick-infix-and-keyword-escape.html …pdf`, `EXIT=0`, **0** warning / error / missing-character lines; artifacts land in `papers/generated/`. |

## What was measured before the change

The step asked for the `requires` pair to be run **before** the fix, because it
had only been read from the source. The installed prefixes predate the change,
so it was run on three compilers: `~/install/clang-trunk-backtick`,
`~/install/clang-23-backtick`, and the GCC build before its rebuild. **All three
reject `` bool `requires`(int); `` under `-std=c++17` and accept it under
`-std=c++20`** — GCC by a different route (a C++20 keyword is a plain
`CPP_NAME` below C++20, and its predicate asked for `CPP_KEYWORD`), with the same
answer. The macro and reserved-name claims were asked of GCC before the change
as well: `#define foobar 3` then `` int `foobar` `` was already reported against
the replacement list, which is phase 4 running.

## GCC

`cp_token_escapable_word_p` (`gcc/cp/parser.cc`): `CPP_NAME`, `CPP_KEYWORD`, or
`token->flags & NAMED_OP`. It replaces `CPP_KEYWORD` in
`cp_parser_backtick_escaped_identifier` and in the lookahead
`cp_lexer_nth_token_starts_name` — **two** sites, the second being the one the
first session's forward note did not know about. An alternative token has no
identifier on the token; the escape recovers it with
`get_identifier (cpp_type2name (token->type, token->flags))`, which is how
`cp_parser_std_attribute` already recovers an attribute name spelled `and`.
Diagnostic: *backtick escape requires an identifier*. `cp_lexer_name_width`
needed nothing — it keys on the backtick.

**One finding**, [`escape-alternative-token-spelling`](../../gcc/DEVIATIONS.md#escape-alternative-token-spelling):
the design said the `and`-escaped / `foobar`-bare printing asymmetry needed
teaching in neither compiler. True of Clang, whose `IdentifierInfo` for `and`
carries `tok::ampamp`. False of GCC, whose `dump_decl_name` asked only
`IDENTIFIER_KEYWORD_P`, so a variable declared `` `and` `` was named `'and'` in
a diagnostic. It now also asks for `NODE_OPERATOR` on the cpplib node. Pinned in
`escape-identifier.C`.

Tests: `escape-identifier.C` and `escape-macros.C` new, mirroring the Clang
files; `escape-abi.C` gains `_Z8ordinaryi` and `_Z9takes_andi3and`, **the same
symbols Clang pins**; `escape-tentative.C` gains the three non-keyword shapes;
`escape-diag.C` swaps `` `x` `` for four non-words and a `clash` redeclaration;
`lex-token.C` only changes its expected message. No `-std` in any of them, so
the harness runs each under every dialect in its list (98, 11/14, 17, 20, 29 as
configured), which is the dialect pair and more.

GCC's object-like-macro error lands on the **`#define` line** with *in expansion
of macro* at the escape, and it stops at one error where Clang adds a recovery
`expected unqualified-id`. Both halves of the macro claim agree across
compilers.

## The forward-port, predicted and then checked

Prediction: the only file both sides touch is
`DiagnosticParseKinds.td`. `git diff --numstat` before merging — the Unicode side
since `28b685c86ea2` touches that file alone of the incoming eight, at line 786;
the incoming hunk is at 216. **No conflict predicted, none happened.** Verified
the usual four ways: the merge delta is **8 files, +300/−27**, exactly the
incoming pair's; the deleted lines are identical as a set; the feature diff
against the new backtick tip is **121 files, +7701/−57, 221 hunks at `-U0`**,
unchanged for the fifth merge running; `ParseExpr.cpp` is not in the merge, and
`Level != prec::UserInfix` is still at line 309. **The fold guard was read, not
re-proven by deletion** this time — the merge does not touch `ParseExpr.cpp`, so
the deletion experiment would be a control and nothing more.
`git -C ~/src/llvm/unicode-upstream log -p d28193fa1ff6..HEAD | grep -ic backtick`
→ **0**.

## The paper

The three sentences are gone: the abstract's *"One rule in this revision is
ahead of the forks"*, the *escape yields an ordinary identifier* section's
*"the one thing … the two forks do not yet implement"*, and the fifth-sweep
paragraph, which is rewritten from the measurements above and now reports the
GCC printer line. **One more sentence was wrong and was not on the list**: the
same section said *"A macro name is still replaced"* without qualification.
Both compilers show that is true of an object-like macro and not of a
function-like one, so it now says both, and so does the drafting note in the
Wording. The implementation-changed bullet's *seventy-nine* is *ninety-eight*.

## Forward notes

- **Push** is the one thing left undone, and it is the maintainer's call:
  `backtick-trunk`, `backtick-23`, `unicode-operators-experiment` and GCC
  `backtick` are all ahead of `ceridwen` / `origin`. PR #1 is subsumed by the
  fast-forward and can be merged or closed.
- `ops/probes/README.md` and `docs/infix-backtick-operator.org` quote sweep
  timings; with 98 programs the sweep is slower than 1.6 s. See the Status row.

---

# The first third, as written by the session that did it

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
