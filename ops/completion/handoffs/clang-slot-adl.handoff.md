# Handoff — clang-slot-adl — Clang does no ADL on the backtick slot

- **Status:** **DONE (gate passed on both backtick branches).**
- **Branch / commit:**
  - `backtick-trunk` — `9504b2c1fc51` (`~/src/llvm/backtick-trunk`)
  - `backtick-23` — `3a03487496a7` (`~/src/llvm/backtick`) — cherry-pick, gated independently
  - `unicode-operators` (this repo) — `5f545d9` (`docs:` — §17.4: the status
    correction removed and four paragraphs written), followed by the
    `ops: clang-slot-adl` commit that carries this file, the step file, the
    two ledger rows and the plan's checklist, Coverage, Baselines, critical
    path and Status log
- **Date / agent:** 2026-09-06.
- **Closes:** [`clang-slot-adl`](../../BACKLOG.md#clang-slot-adl).
- **Reconciles:** [`clang-slot-adl`](../../DEVIATIONS.md#clang-slot-adl) → **FIXED and RECONCILED**.
- **This step had no step file when it was assigned.** It was written first —
  [`steps/clang-slot-adl.md`](../steps/clang-slot-adl.md) — and inserted into
  Phase D, because a step with no file cannot be picked up or audited.

---

## The fix, and why it is where it is

**One function, and the whole defect is one boolean.**
`Parser::TryParseBacktickCalleeSlot` in `clang/lib/Parse/ParseExpr.cpp`,
declared beside `TryParseBacktickTypeSlot` in `clang/include/clang/Parse/Parser.h`
and called from the slot in `ParseRHSOfBinaryExpression` immediately before the
`ParseExpression()` fall-through it replaces for one shape.

The slot is a **callee**, and in the slot the closing backtick is the trailing
`(`. `Sema::UseArgumentDependentLookup` opens with
`if (!HasTrailingLParen) return false;`, and `ParseExpression` had no way to
say the name was a callee, so the name was resolved before
`Sema::ActOnBacktickOperator` ever handed it to `BuildCallExpr`. The new
function parses a bare unqualified name and builds it with
`Actions.ActOnIdExpression(..., /*HasTrailingLParen=*/true, ...)`, which is
exactly what `ParseCastExpression`'s identifier arm does when the next token
really is `(`. Nothing in Sema changed.

**Entry is narrow on purpose.** It returns an *unset* `ExprResult` — leaving
the token stream untouched, so the caller runs `ParseExpression` as before —
unless the token is an `identifier` or an `annot_template_id`, and for an
identifier unless the next token is a backtick or a `<`. Then it parses an
unqualified-id under a `TentativeParsingAction` and **commits only if the very
next token is the closing backtick**; otherwise it reverts. That is what makes
`` x `a < b` y `` and `` x `f<int> + g` y `` keep their old parse: for the
first, `ParseUnqualifiedIdTemplateId` returns `TNK_Non_template` without a
diagnostic and leaves the cursor on `<`, so the revert is clean.

**Both unqualified forms in one pass**, on the strength of
[`gcc-template-id-slot-adl`](../../gcc/DEVIATIONS.md#gcc-template-id-slot-adl):
GCC's first fix for this same defect looked for a bare identifier and left the
template-id slot silently on the old path, which cost a second step, a second
ledger row and a §17.4 rewrite. §17.4 says ADL binds "wherever the slot is an
unqualified name, whether or not it carries template arguments"; that sentence
is true of Clang on the first try now.

**One `ExprResult` subtlety worth knowing.** `Sema::ActOnIdExpression` can
return an *unset* result when typo correction proposes a keyword. Falling
through to `ParseExpression` at that point would re-parse tokens that are
already consumed, so the function converts unset to `ExprError()`. Do not
"simplify" that away.

### What deliberately did **not** change

A qualified name, a member access, a callable object, a function pointer, a
parenthesised expression and a type-name slot all still go through
`ParseExpression` (or, for the type slot, `TryParseBacktickTypeSlot` ahead of
it), and all still get **no** ADL — which is correct, because the equivalent
spelled call gets none either. Section 7 of the new test asserts each of those
as a *binding*, not as "it compiles", and section 8 asserts the
[basic.lookup.argdep]/3 block-scope rule, which is the check that the slot did
not simply gain unconditional ADL. Those sections pass **identically before
and after** the fix; they were run against the pre-fix binary to prove it.

## Proof that it was failing first

`clang/test/SemaCXX/backtick-adl.cpp` was run, unchanged, on the **pre-fix**
`backtick-23` binary (`~/src/llvm/build-backtick/bin/clang`, which at that
point had not yet taken the cherry-pick and is byte-identical to trunk in this
neighbourhood). Every one of the six ADL sections failed and both control
sections passed:

```
error: 'expected-error' diagnostics seen but not expected:
  Line  29: use of undeclared identifier 'hf'
  Line  43: use of undeclared identifier 'go'; did you mean 'ns::go'?
  Line  59: static assertion failed due to requirement '__is_same(OrdinaryTag, AdlTag)'
  Line  72: static assertion failed due to requirement '__is_same(OrdinaryTag, AdlTag)'
  Line  86: use of undeclared identifier 'addt'; did you mean 'ns::addt'?
  Line 100: use of undeclared identifier 'later'
  Line 102: use of undeclared identifier 'laterT'
  ...
15 errors generated.
```

**Lines 59 and 72 are the ones that matter.** They are not compile errors in
the defect; they are `static_assert`s that catch a *wrong bind*. Pre-fix,
`` u `pick` u `` compiled cleanly and produced `OrdinaryTag` while
`pick(u, u)` produced `AdlTag` — the operator form calling a different
function from the call it is sugar for, with no diagnostic at all. That is
the whole reason this was P1, and it is why the test discriminates by tag type
rather than by whether the line compiles. **Do not weaken those two sections
into a compiles/does-not check.**

Post-fix the same file passes on both branches, and both silent cases now bind
the ADL candidate. **Nothing is newly diagnosed** — nothing needed to be: the
right function is simply selected, which is what "sugar for the call" means.

## Verification evidence

| Branch | Discovered | Passed | Failed | Exit |
|---|---|---|---|---|
| `backtick-trunk` @ `9504b2c1fc51` | 54111 | 48225 | **0** | `EXIT=0` |
| `backtick-23` @ `3a03487496a7` | 54345 | 48503 | **1** ([`stray-clang-format-config`](../../BACKLOG.md#stray-clang-format-config)) | `EXIT=1` |

XFAIL 27, skipped 6, unsupported 5853 / 5808 — all unchanged. Both are exactly
**+1 discovered / +1 passed** over the Baselines, from the single new lit file;
the Baselines table in [`ops/completion/PLAN.md`](../PLAN.md) is updated. Run
with `ulimit -c 0`, output redirected, `EXIT=` captured explicitly — `ninja …
| tail` reports `tail`'s status.

Cherry-pick verified beyond "it applied": `git show` of the two commits differs
only in blob hashes.

The 17 backtick lit tests (the `backtick-*` files plus
`Driver/fbacktick.c`) were run on their own on both branches as well as inside
the gate — 16 passed, 1 unsupported, on each. The `-ast-print` round-trip test
[evidence-debt](evidence-debt.handoff.md) added is among them, and it was the
one at risk: the slot is now built from a different node kind, and the printer
reconstructs the written form from the desugared call. It passes untouched.

**The within-compiler control was re-measured here rather than taken from the
ledger**, on `~/src/llvm/build-unicode/bin/clang++ -funicode-operators`: a
friend `operator⊞` found by ADL alone, and `u ⊞ u` selecting
`ns::operator⊞(U, U)` over a visible, viable `::operator⊞(double, double)` —
the exact shape the backtick operator got wrong and now gets right. That build
is unmodified by this step.

### The inotify budget cost two gate runs on trunk, and the shape is worth recording

The first two `check-clang` runs on `backtick-trunk` each failed **2**
`DirectoryWatcherTest` cases — and a **different two each time**
(`DeleteFile`/`ModifyFile`, then `DeleteWatchedDir`/`InvalidatedWatcher`),
every failure `No space left on device : inotify_add_watch()`. Measured at the
time: `cloud-drive-dae` held **523,713 of the 524,288** watches, leaving 196
free for the whole gate. All 8 cases passed standalone on the feature binary
and on the pristine `~/src/llvm/build-main` one, three times each. Nothing was
filtered and nothing was budgeted; the gate was re-run until the environment
allowed a reading, which the third run gave. **A changing subset is the
signature** — a real regression fails the same tests every time.

## Deviations from the plan / design

None to add. [`clang-slot-adl`](../../DEVIATIONS.md#clang-slot-adl) already
existed and is now marked; nothing else contradicted the design, because the
design was right and the implementation was not.

The one judgement call the step file did not pre-empt: **the fix covers the
template-id slot as well as the bare identifier**, which is more than the
minimum needed to make the failing shapes pass, and it is in the step file as
a requirement because of the GCC precedent rather than because anyone measured
Clang's template-id slot first. It was measured — pre-fix,
`` u `addt<char>` u `` was *use of undeclared identifier* while
`addt<char>(u, u)` bound fine.

## Discoveries affecting later steps

- **`unicode-operators-experiment` does not have this fix, and now the
  outstanding forward-port is not test-only.** [evidence-debt](evidence-debt.handoff.md)
  left a test-only forward-port outstanding for that branch; this step **adds
  to it**, and the added part is a real parser change. That branch's slot is
  still `BacktickOp = ParseExpression()` at `clang/lib/Parse/ParseExpr.cpp:566`
  and its backtick operator therefore still has the defect. Its **Unicode**
  operator does not and never did — see below. Whoever runs the next backtick
  merge into that branch takes `9504b2c1fc51` with everything else; the
  neighbourhood is byte-identical, so no conflict is expected in
  `ParseExpr.cpp`, and `Parser.h`'s new declaration sits directly under
  `TryParseBacktickTypeSlot`, which that branch already has.
  `unicode-operators-upstream` must **not** receive it — it has no backtick
  feature at all.
- **The within-compiler control is a measured fact, not a rhetorical one**, and
  it is the strongest implementation-experience material this track has
  produced. Same build, same machine: `s ⊞ s` finds a hidden friend and
  `u ⊞ u` picks the ADL candidate over a visible `operator⊞(double, double)`,
  while the backtick equivalents did neither. The mechanism is one sentence —
  the Unicode slot **never becomes an expression**, because
  `Sema::CreateOverloadedUserOp` performs its own `LookupOperatorName` and
  hands an unresolved set to candidate assembly, so ADL is inherited without
  anyone deciding to inherit it. The backtick slot *was* an expression, and an
  expression's name is resolved before the call builder sees it.
- **`clang/test/SemaCXX/backtick-semantics.cpp` no longer claims to test ADL**,
  in its prolog or in its section-2 heading, and points at the new file
  instead. That false claim is the entire reason this survived nine steps: a
  section headed "Qualified callee (also exercises the ADL-adjacent case)" was
  enough to stop anyone writing the test that would have failed. If you are
  ever tempted to write "also exercises" in a test heading, write the test.
- **The augmentation shape is the only ADL check worth having.** Hidden
  friends and ADL-only namespace members fail *loudly* when the slot has no
  ADL, so any of them would have caught this — but the shape that catches a
  *partial* or *future* regression is a visible, viable ordinary candidate
  plus a better ADL candidate, with the choice made observable by return type.
  It is the only shape in which weaker lookup produces no diagnostic.
- `check-clang` self-formats `clang/lib/Format/` **and**
  `clang/unittests/Format/` before any lit test runs; this step touched
  neither, and the format step passed on both branches. Still worth knowing
  that the gate can abort at ~step 106/165 before testing anything.

## Forward notes for the NEXT step

The next unchecked step whose dependencies are met is
[reconcile-declaring-using](../steps/reconcile-declaring-using.md), which is a
documents-only step on `docs/unicode-operators.md` §7 / §7.1 and is untouched
by this one — no branch, no build, and none of its seven rows is affected.
Two things from here are worth its attention anyway:

- Its [`infix-parse-cost`](../../unicode-operators/clang/DEVIATIONS.md#infix-parse-cost)
  row is the measurement of the Unicode slot's parse, and that row is now
  *also* the explanation of why the Unicode feature got ADL for free. If §7
  "Using" says how the Unicode slot is parsed, the sentence and §17.4's third
  paragraph in the backtick doc are two views of one fact; keep them
  consistent, and cross-link rather than restate.
- The `-fbacktick` slot is not the `-funicode-operators` slot and never was.
  Do not import §17.4's language into U§7; the Unicode operator has no slot to
  give ADL to.

For [backtick-paper](../steps/backtick-paper.md), whose dependency list this
step joined: **your material is written and waiting in
[§17.4](../../../docs/backtick-operator-design.md#174-adl-is-normative-cross-compiler-note)**,
four paragraphs of it. Its step file has a bullet saying what to take. Public
text cites no slug and no internal identifier — describe the control, do not
name the ledger row.

## Open risks / TODOs

- The forward-port to `unicode-operators-experiment` above. It is not this
  step's, and the branch is not in this step's gate; it is now larger than
  [evidence-debt](evidence-debt.handoff.md) left it.
- **The inotify budget will do this again.** It is
  [`inotify-watch-budget`](../../BACKLOG.md#inotify-watch-budget), it needs
  root, and it is the maintainer's. Any Clang step after this one should
  expect to spend one or two extra gate runs on it and should check the hoard
  (`cloud-drive-dae`'s share of `fs.inotify.max_user_watches`) before
  suspecting its own diff.
- `TryParseBacktickCalleeSlot`'s `TentativeParsingAction` re-parses a
  template-id slot that turns out not to end at the backtick. That is a parse
  cost on an already-ill-formed or unusual shape and nothing measured it; it
  is noted only so a later reader knows it was a choice. The alternative —
  scanning for the matching `>` by hand — was rejected as worse.
- Nothing was done about `` x ``new`` y ``, a keyword-escaped name in the
  operator slot. It is diagnosed as an empty slot, because the caller's
  empty-slot check fires on the opening escape backtick before any slot parse
  happens. That is pre-existing, unrelated to ADL, and has no row; if anyone
  wants it, it is a new one.
