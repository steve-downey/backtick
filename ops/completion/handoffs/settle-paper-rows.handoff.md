# Handoff — settle-paper-rows — the four rows the paper pass opened

- **Status:** **BLOCKED on the author**, and that is the successful outcome for
  the part that is blocked. **Two of the four rows are fixed, gated and
  reconciled**; the other two are **one question**, priced in both compilers
  and put to the author as
  [escape-name-positions](../../../docs/open-decisions.md#escape-name-positions).
  The plan's box stays **unchecked** — no green, no check, and this track's
  rule that a `Decide` step ends by asking rather than by choosing.
- **Branch / commit:**
  - `backtick-trunk` — `3b2103895224`
  - `backtick-23` — `d93d6c520e6f` (cherry-pick, gated independently)
  - GCC `backtick` — `eb59d9b897e`
  - `unicode-operators` in *this* repo — the docs, ledgers, plan and this
    handoff. Neither Unicode branch was touched, and neither needs to be by
    this step; see *Open risks*.
- **Date / agent:** 2026-09-07.
- **Closes:** [`type-slot-aggregate-shape`](../../DEVIATIONS.md#type-slot-aggregate-shape)
  and [`escape-diagnostic-spelling`](../../gcc/DEVIATIONS.md#escape-diagnostic-spelling),
  both **FIXED and RECONCILED**.
- **Leaves open, with the author:**
  [`escape-name-positions`](../../DEVIATIONS.md#escape-name-positions) and
  [`escape-alias-name-parity`](../../gcc/DEVIATIONS.md#escape-alias-name-parity).
  **They are not two questions.** Answering the first answers the second.
- **Opens:** nothing. No new ledger row, no new backlog row.

---

## The four verdicts, in one place

| Row | Verdict | Where it landed |
|---|---|---|
| [`type-slot-aggregate-shape`](../../DEVIATIONS.md#type-slot-aggregate-shape) | **Fixed**, both backtick branches | [§17.5](../../../docs/backtick-operator-design.md#175-source-ranges-of-the-desugared-node-source-fidelity-node), the paragraph beginning *"Three was the count of the shapes that had been recognised"* and the general-statement paragraph after it; [§17.3](../../../docs/backtick-operator-design.md#173-type-name-in-the-operator-slot-type-name-slot), the cost paragraph |
| [`escape-diagnostic-spelling`](../../gcc/DEVIATIONS.md#escape-diagnostic-spelling) | **Fixed**, GCC | [keyword-escape-printing](../../../docs/backtick-operator-design.md#keyword-escape-printing)'s `Log.`, the 2026-09-07 entry beginning *"GCC now delivers the diagnostic half too"*; [§17.8](../../../docs/backtick-operator-design.md#178-which-of-this-is-clangs-alone-and-why)'s closing paragraph |
| [`escape-name-positions`](../../DEVIATIONS.md#escape-name-positions) | **Half reconciled, half the author's** | the measurement into [§12](../../../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers)'s *"Which positions are implemented"* paragraph and its table; the question into [`docs/open-decisions.md`](../../../docs/open-decisions.md#escape-name-positions) |
| [`escape-alias-name-parity`](../../gcc/DEVIATIONS.md#escape-alias-name-parity) | **Corrected, then folded into the question above** | the fact into [§17.8](../../../docs/backtick-operator-design.md#178-which-of-this-is-clangs-alone-and-why)'s *"Keep that separate…"* paragraph; the direction of the fix is not this row's to choose |

## What changed

### `backtick-trunk` / `backtick-23` — `3b2103895224` / `d93d6c520e6f`

- `clang/lib/AST/Expr.cpp` — `BacktickInfixExpr::getOperand` gains an arm for
  `CXXFunctionalCastExpr` over `CXXParenListInitExpr`, taking
  `getUserSpecifiedInitExprs()`. Its doc comment goes from *three shapes* to
  four and now states the trap in general: there is no rule, every
  initialization form Sema can build for `T(x, y)` is another arm, and a
  missing arm is silent.
- `clang/lib/AST/StmtPrinter.cpp` — `VisitBacktickInfixExpr` gains the same
  arm. **The type is printed from the semantic node**, exactly as the
  `CXXTemporaryObjectExpr` arm above it does, so one rule covers all four
  shapes and the CTAD exception the paper already states stays a single stated
  exception. Printing the *written* type here was tried first and rejected for
  that reason: it is more faithful (it reproduces `` a `AggT` b `` and
  `` a `AggAlias` b `` exactly) but it makes two adjacent arms answer the same
  question two different ways, which is a thing a design document then has to
  explain and a later reader has to re-derive.
- `clang/test/Parser/backtick-infix.cpp` — two cases beside the other type
  slots: a plain aggregate with the range pinned as literal columns, and one
  with a default member initializer, which is what pins
  *user-specified* rather than *all* initializers.
- `clang/test/Parser/backtick-ast-print.cpp` — the printing, plain and under
  CTAD.
- **Both files are now pinned to `-std=c++20`**, including the second
  `-ast-print` RUN line that re-parses the first's output. Parenthesized
  aggregate initialization is C++20 and neither file pinned a standard; with
  cc1's default the aggregate cases are a `RecoveryExpr` and prove nothing.

### GCC `backtick` — `eb59d9b897e`

- `gcc/cp/error.cc` — `dump_decl_name` prints `` `kw` `` when `flag_backtick`
  and `IDENTIFIER_KEYWORD_P`. That is the whole of the intended change, and it
  is sound on its own terms: under the flag a *declaration* can be named by a
  keyword only if it was escaped, because `grokdeclarator` rejects the bare
  declarator-id.
- `gcc/cp/cp-tree.h`, `gcc/cp/parser.cc` — `cp_printing_raw_token`, set around
  the one `c_parse_error` call in `cp_parser_error_1`. **This is the half that
  matters**; see *Discoveries*.
- `gcc/testsuite/g++.dg/backtick/escape-diag.C` — two directives, in the file
  that already owns the flag-off parity half.

### This repo

- `docs/backtick-operator-design.md` — §17.5 (four shapes, and why the general
  statement survives being fixed), §17.3 (*two printer arms* → three), §12
  (the nineteen-position table), §17.8 (*two kinds, four programs*, and the
  diagnostic divergence that lasted a day), and dated `Log.` entries on
  [keyword-escape-printing](../../../docs/backtick-operator-design.md#keyword-escape-printing)
  and [keyword-escape-coexistence](../../../docs/backtick-operator-design.md#keyword-escape-coexistence).
- `docs/open-decisions.md` — a **sixth question page**, the first backtick-side
  one and the only open one, plus the summary table row and a corrected
  preamble. The file said *"Five questions"* in three places.
- `papers/backtick-infix-and-keyword-escape.md` — three passages, below.
- `docs/infix-backtick-operator.org` — the same three, in the blog register.
- Both backtick ledgers, `ops/completion/PLAN.md` (the step, both Coverage
  tables, a Baselines note and four Status rows), and `CLAUDE.md`, which said
  the completion plan had 16 steps with nothing checked.

## Verification evidence

### Clang

```
backtick-trunk   check-clang   54114 / 48228 / 0    EXIT=0   (Baseline: identical)
backtick-23      check-clang   54348 / 48506 / 1    EXIT=1   (Baseline: identical)
```

XFAIL 27, skipped 6, unsupported 5853 / 5808 — all unchanged. `backtick-23`'s
single failure is `Clang :: Format/dump-config-objc-stdin.m`
([`stray-clang-format-config`](../../BACKLOG.md#stray-clang-format-config)),
this branch's standing reading, which fails identically on the pristine
`build-main` binary. Both runs unfiltered, `ulimit -c 0`, exit code read from
the log rather than through a pipe. **No count moved**, because lit discovers
files and the cases went into files that already existed.

**Failing first, on a pre-fix binary.** `build-backtick` (`backtick-23`) had
not taken the change yet when the new cases were written, so it *is* the
control, run on the new test content:

```
$ build-backtick/bin/clang -cc1 -std=c++20 -fbacktick -ast-dump  backtick-infix.cpp
  BacktickInfixExpr <col:19, col:22> 'Agg'      # the operator slot; written is <col:16, col:24>
  BacktickInfixExpr <col:21, col:25> 'Agg3'     #   ditto, <col:18, col:27>
$ build-backtick/bin/clang -cc1 -std=c++20 -fbacktick -ast-print backtick-ast-print.cpp
  Agg t5 = Agg(1, 2);
  auto t6 = (aggT<int>)(3, 4);
```

**The second line is worse than the row recorded and is the finding.**
`(aggT<int>)(3, 4)` is not the desugaring: it is a cast applied to a comma
expression — a *different program*, and the `-ast-print` test's second RUN line
would not have re-parsed it. The row said the aggregate slot "prints as the
desugaring"; for the deduced case it printed something that does not mean what
was written.

Post-fix, the same three lines are `<col:16, col:24>`, `<col:18, col:27>`,
`` Agg t5 = 1 `Agg` 2; `` and `` auto t6 = 3 `aggT<int>` 4; ``.

### GCC

```
$ make -C gcc check-c++ RUNTESTFLAGS="dg.exp=g++.dg/backtick/*.C"
  # of expected passes            109        (was 103; +6 = 2 directives x 3 standards)
  # of unexpected failures          0
```

Four entity-naming surfaces, checked by hand against the four the row named:

```
note: initializing argument 1 of 'void `new`(int)'
note: initializing argument 1 of 'void S::`delete`(int)'
error: request for member 'bad' in 's.S::`new`', which is of non-class type 'int'
error: '`class`' cannot be used as a function
error: no matching function for call to 'N::T::`try`(int)'
```

**Flag-off parity, measured rather than asserted:** a program containing no
backtick, compiled with `-fbacktick` and without it, produces byte-identical
diagnostics (`diff` of both outputs, empty). The intermediate build that did
*not* is the reason the guard exists, and it is recorded below rather than
quietly discarded.

### Documents

- Both paper formats build, `EXIT=0`, **0 missing characters** (`grep -ci
  "missing character"` over the full pandoc/LaTeX output → 0). The generated
  directory was removed afterwards; `papers/generated/` is build output.
- `lexcheck --register formal` on the paper: three warnings, all pre-existing
  and all at their pre-step counts (`, not Y` ×14, `exactly` ×12, one
  contraction). `--register blog` on the `.org`: **clean** — it took two
  passes, because the first draft of the new material pushed the em-dash rate
  from 20 to 24 per 10k and added two appositive tails.
- Public text swept for internal identifiers: no slug, no ledger name, no path
  under `ops/` in either deliverable's new text.

## Deviations from the step file

1. **The step file expected the alias parity to be *either* a fix or part of
   question 3, and it is part of question 3 — but the row was also wrong about
   the facts.** It is **three programs, not one**: an *alias-declaration*
   name, an *alias-template* name and a *concept* name, all accepted by Clang
   and rejected by GCC. One cause. Nineteen positions were probed instead of
   the eight the row was written from, and the position table in §12 is
   correspondingly larger in both directions — both compilers accept the
   escape in three positions §12 never listed (a `friend` declaration's name,
   a non-type template parameter's, a using-declaration's) and reject it in
   three more nobody had checked (an enumerator, a mem-initializer, a label).
2. **The GCC fix needed a second commit's worth of thinking inside one
   commit**, which the step file anticipated in the abstract ("the trap to
   expect") and which arrived exactly there.
3. **Nothing was done about the papers' [lex.name] example.** The
   recommendation is to change it — `` struct `union` { }; `` is the one line
   in either paper a reviewer can copy into a prototype and watch fail — but
   the example is part of the proposed wording, and changing what a paper
   *proposes* is the author's. It is stated as the fallback half of the
   recommendation instead.

## Discoveries affecting later work

- **`dump_decl_name` is GCC's whole answer to "print the name of a
  declaration", and it is also where a raw token arrives.** `cp_parser_error_1`
  maps `CPP_KEYWORD` to `CPP_NAME` and hands the token's `IDENTIFIER_NODE` to
  `%qE` — with a comment in the source saying it does this because
  `c_parse_error` does not understand keywords. Both paths reach the same
  funnel with the same tree, so **no tree-level test can separate them**;
  `IDENTIFIER_BINDING` does not work either, because a class member's name has
  none. The parser is the only place that knows, and it knows for the length
  of one call. **This is the GCC counterpart of the split
  [clang-paper-truth](clang-paper-truth.handoff.md) found on the Clang side**,
  where *diagnostic argument kind* decides — Clang has an argument kind to
  hang it on and GCC does not, which is the whole difference between six sites
  and one guard.
- **A round-trip claim is a claim about every node Sema can build.** This is
  [backtick-paper](backtick-paper.handoff.md)'s discovery and this step is the
  second instance in two days: the printer and the range recover the operands
  from *whatever Sema built*, so the set of arms is open-ended and a missing
  arm prints something plausible. The failure is not "less faithful" — for the
  deduced aggregate it was a different program. If a fifth initialization form
  ever appears, nothing will report it.
- **`zsh` does not word-split an unquoted parameter.** Recorded by
  [backtick-paper](backtick-paper.handoff.md), hit again here on the first
  probe sweep, which came back "Clang rejects all nineteen positions". The
  probe scripts are `bash` with an array, which is the fix.
- **Two lit files in the backtick set had no `-std`** and therefore ran at
  cc1's default. Anything that needs a C++20-or-later rule silently becomes a
  `RecoveryExpr` there and the FileCheck lines fail in a way that reads like a
  bug in the change. Both are pinned now; the others in
  `clang/test/Parser/backtick-*` already were.

## Forward notes — there is no next step

This is the last step in `ops/completion/PLAN.md`, and it is the only unchecked
one. What the next agent does depends entirely on one thing:

**If the author has answered
[escape-name-positions](../../../docs/open-decisions.md#escape-name-positions):**

- Record the answer in that file's `## Answers` section, in the shape the five
  answers there already use — the option chosen, the reason if it differs from
  the recommendation, and *the doc work it generates* — and add its row to
  *Where each answer was recorded*.
- Append a dated `Log.` line to
  [keyword-escape-coexistence](../../../docs/backtick-operator-design.md#keyword-escape-coexistence),
  whose Status can then stop saying *scope open*.
- Then, and only then, mark
  [`escape-name-positions`](../../DEVIATIONS.md#escape-name-positions) and
  [`escape-alias-name-parity`](../../gcc/DEVIATIONS.md#escape-alias-name-parity)
  `RECONCILED`, naming the destination paragraph. **Deciding is not
  reconciling** — this track's rule, and the reason the two rows are still
  `OPEN` today.
- If the answer is **(c)**, the implementation is priced in the brief and the
  prices are real code sites, not estimates: one helper plus up to eight call
  sites in Clang on **both** backtick branches, one `cp_parser_identifier` arm
  plus its guards in GCC, and the alias routing's two-token lookahead becoming
  four. The reassuring half is measured too: in every rejected position a
  backtick is *currently always an error*, so accepting the escape there cannot
  change the meaning of any well-formed program.
- If the answer is **(b)**, the work is one example in the paper's wording and
  one sentence beside it, and the two rows close on the reword — the same shape
  [dependent-template-operator-id](../../../docs/open-decisions.md#dependent-template-operator-id)
  ended in.

**If the author has not answered:** there is nothing else outstanding in
`ops/`. Do not go looking for work in the plan; every other box is `[x]` or
`[—]`, and the maintenance merge M2 is long done.

## Open risks / TODOs

- **`unicode-operators-experiment` does not have the aggregate arm.** It
  carries the backtick feature through
  [unicode-branch-maintenance](unicode-branch-maintenance.handoff.md)'s merge,
  which predates this commit, so its `-ast-print` has the same hole. That is a
  forward-port, not a defect of this step, and it belongs to whoever next
  merges `backtick-trunk` into it — the same job that handoff describes, with
  the same conflict shape (`StmtPrinter.cpp` and `Expr.cpp` are not among the
  four two-armed tooling anchors, so this one should be clean).
  `unicode-operators-upstream` must not receive it, for the reason that handoff
  gives.
- **Nothing is pushed.** Three branches are ahead of their remotes by one
  commit each (`backtick-trunk`, `backtick-23`, GCC `backtick`), and this repo
  by two. All six were in sync on both remotes as of 2026-09-07; pushing is the
  maintainer's call.
- **The papers now say the divergence list is two causes and four programs.**
  If the author answers **(c)**, that sentence, §17.8 and §12's table all move
  together, and the paper's *"implemented in two independent compilers"*
  framing gets simpler rather than more complicated. Whoever writes that up
  should re-derive the table rather than editing the numbers — nineteen
  one-line programs, about ten minutes, and it has now caught something on
  each of the two occasions it has been run.
