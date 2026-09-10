# Handoff — gcc-resync — Re-sync GCC to current trunk, then its open defects

- **Status:** DONE (gate passed)
- **Branch / commit:** `backtick` in `~/bld/gcc/gcc-backtick`, rebased
  `c9ee2c5ab6c` → **`4df5e1e9b152`**, then three commits:
  `edce709e170` (template-id slot ADL), `daf5fa6feb0` (module test),
  `12d3b5b0c07` (the three narrowed guards). Branch tip `b842ac1ed64` →
  `12d3b5b0c07`. Docs and ledgers in *this* repo on `unicode-operators`.
- **Date / agent:** 2026-09-06

## What changed

### The re-sync

`c9ee2c5ab6c` (Daily bump, 2026-06-24) → **`4df5e1e9b152`** (Daily bump,
2026-09-06). **2158 upstream commits**, 177 of them touching `gcc/cp`,
`gcc/c-family` or `libcpp`. All ten feature commits replayed **conflict-free**.
`BASE-VER` was 17.0.0 at both ends, so the move did not cross a release branch.

The tip commit before the rebase is kept as the local tag
**`backtick-pre-resync`** (`b842ac1ed64`), which is what the byte-identity
check below compares against; delete it whenever it stops being useful.

**Upstream churn absorbed: none, semantically.** Only three of the touched
functions moved at all in a way the diff can see, and none of them changed
under the feature's hunks. `cp_parser_postfix_open_square_expression` gained
`CPP_OPEN_SPLICE` handling and a `post_colon_parsing:` label in the *context*
lines around two backtick hunks; everything else is hunk offsets. Proof, and
the thing worth keeping:

```
diff <(git diff c9ee2c5ab6c..backtick-pre-resync | grep -E '^[+-][^+-]') \
     <(git diff 4df5e1e9b152..<post-rebase tip> | grep -E '^[+-][^+-]')
   -> no output
```

The added and removed lines of the whole feature are **byte-identical across
the move**. The full `git diff` differs only in blob hashes, `@@` offsets and
context.

### The defects

**[template-id-slot-adl](../../BACKLOG.md#template-id-slot-adl) — fixed, not
reworded.** `gcc/cp/parser.cc` gains `cp_parser_backtick_template_id_slot`,
which tentatively parses `f<...>` when it is immediately followed by the
closing backtick and returns a `TEMPLATE_ID_EXPR` over the ordinary-lookup
result — or over the bare `IDENTIFIER_NODE` when ordinary lookup finds
nothing, which is the pure-ADL case. Both handler sites use it (the main one
and the RHS-lookahead one G06 added), and the ADL block now branches on
`identifier_p (slot)` so a template-id goes straight to
`perform_koenig_lookup`. New test
`gcc/testsuite/g++.dg/backtick/infix-adl-template-id.C`. New ledger row
[gcc-template-id-slot-adl](../../gcc/DEVIATIONS.md#gcc-template-id-slot-adl).

**[module-streaming-escapes](../../BACKLOG.md#module-streaming-escapes) —
verified not broken.** Deferred by `G07`, `G08`, `G09` and `G10` in turn, and
it works untouched: no production change was needed. New tests
`gcc/testsuite/g++.dg/modules/backtick-escape-1_a.C` / `_b.C`.

**[grokdeclarator-guard-scope](../../BACKLOG.md#grokdeclarator-guard-scope) —
narrowed, and it turned up a live sibling.** The escape is now recorded where
the semantic layer can see it: `cp_declarator` gains `backtick_escaped_p`
(`cp-tree.h`), `cp_parser` gains `backtick_escaped_id_p` (`parser.h`),
`cp_parser_unqualified_id` raises the parser flag when it parses an escape,
`cp_parser_declarator_id` clears it first so it describes one declarator-id
only, `cp_parser_direct_declarator` copies it onto the declarator, and
`grokdeclarator` requires it instead of trusting `flag_backtick`. **See
Discoveries** for the two reachable guards this uncovered. New ledger row
[escape-arm-entry-token](../../gcc/DEVIATIONS.md#escape-arm-entry-token).

**[gcc-wrapper-parity](../../BACKLOG.md#gcc-wrapper-parity) — recorded, not
implemented**, which was the row's own conclusion. Written up as
[gcc-wrapper-parity](../../gcc/DEVIATIONS.md#gcc-wrapper-parity) in the GCC
ledger: a difference **in kind, not in behaviour**, and what the paper should
say about it.

**[gcc-type-slot-parity](../../gcc/DEVIATIONS.md#gcc-type-slot-parity) —
reconciled.** Marked **RECONCILED**, landing in
`docs/backtick-operator-design.md` §17.3, the paragraph added at the end of
that section beginning "Implementation status: one compiler". Note the
distinction the entry now draws: reconciling the row is *recording* the
divergence, not closing it — GCC still rejects `` 1 `P` 2 ``.

### Documents

- **`docs/backtick-operator-design.md` §17.4** rewritten. It said GCC resolves
  the slot name at parse time so ADL fails — true when it was written, false
  since `G10`, and the step file is right that the replacement claim has to be
  scoped: ADL binds **wherever the slot is an unqualified name, with or
  without template arguments**, and a qualified name or arbitrary expression
  correctly gets none, for the same reason the equivalent call gets none.
  Both compilers now deliver that and agree.
- **§17.3** gains the implementation-status paragraph the ledger promised.
- **`ops/gcc/DEVIATIONS.md`**: three new entries; `gcc-type-slot-parity`
  marked; **[gcc-slot-adl](../../gcc/DEVIATIONS.md#gcc-slot-adl) corrected
  from `Status: OPEN` to `RESOLVED`** — its own prose had said "FIXED in G10"
  since June and only the status field lagged. The GCC ledger now has no
  `OPEN` row.
- **`ops/BACKLOG.md`**: five `Closed by` cells filled, each naming what was
  done and where it landed.
- **`ops/gcc/PLAN.md`** gate facts: the pin replaced with the new base, plus
  the stale-header-farm fact below.
- **`CLAUDE.md`**: the GCC row of the worktrees table now says
  `4df5e1e9b152`.

## Verification evidence

**The gate, before and after the rebase — the step file's neutrality
requirement.** `make -C gcc check-c++ RUNTESTFLAGS="dg.exp=g++.dg/backtick/*.C"`:

| Point | Result |
|---|---|
| pre-rebase, on `c9ee2c5ab6c` | **88 expected passes, 0 failures**, `EXIT=0` — exactly G10's number |
| post-rebase, on `4df5e1e9b152`, no other change | **88 expected passes, 0 failures**, `EXIT=0` |
| after template-id slot ADL | **94 / 0**, `EXIT=0` (+6: the new test) |
| after the three narrowed guards | **103 / 0**, `EXIT=0` (+9: three `dg-error` checks × 3 std variants) |

**Fail-before-fix, for the one fix that had a before.** On the post-rebase
binary, before `edce709e170`:

```
error: 'g' was not declared in this scope; did you mean 'ns::g'?
error: expected primary-expression before 'int'
error: expected '`' before 'int'
   -- from:  r_pure = ax `g<int>` ay;
```

After it, that file compiles clean and `-fdump-tree-original` reads

```
(void) (r_pure    = ns::g<int> (…, …))
(void) (r_augment = ns2::h<int> (…, …))
```

— pure ADL resolving into `ns::`, and augmentation preferring `ns2::h` over
the file-scope `h`. The test also covers nested template arguments
(`k<ns3::W<int>>`), the RHS-lookahead handler (`3 * cx `k<int>` cy`), and a
parenthesised slot containing a genuine `<`, so the rollback path is exercised
rather than assumed.

**Fail-before-fix for the guards.** Before `12d3b5b0c07`, with `-fbacktick`:

```
void new (int, int);   ->  error: backtick keyword-escape requires a C++ keyword   (pointing at the '(' )
int f () { return ^; } ->  error: expected unqualified-id before '^' token
```

without it:

```
void new (int, int);   ->  error: expected unqualified-id before 'new'
int f () { return ^; } ->  error: expected primary-expression before '^' token
```

After the fix both are **character-identical with the flag on and off**, which
is the property the ground rule actually asks for and which no test had been
checking.

**Module streaming.** `modules.exp=backtick-escape-1*` → **15 expected passes,
0 failures** (5 checks × 3 std variants): the CMI is produced, the importer
sees ordinary identifiers, and the assembly carries `_ZW15backtick_escape3newii`
and `_ZNW15backtick_escape6Widget6deleteEv` — module-attached mangling, working
unchanged through the escape.

**Wider regression sweep**, whole directories, **0 unexpected failures in each**:

```
g++.dg/parse     4905 passes, 15 xfail,  3 unsupported
g++.dg/lookup    3437 passes,  6 xfail,  2 unsupported
g++.dg/template  9874 passes, 23 xfail,  2 unsupported
g++.dg/overload   692 passes
g++.dg/init      3632 passes,  9 xfail,  8 unsupported
g++.dg/expr       952 passes
```

`modules.exp` in full is **12411 passes / 96 unexpected failures**, and those
96 are **not this change**: none is a backtick test, and every one of them is a
CMI-cache or module-mapper problem — 26 `failed to read compiled module: No
such file or directory`, 11 `Bad file data`, 13 `language dialect differs`,
37 from the mapper test that fails on purpose, one `Bus error`. They were not
baselined against the pre-change tree, which is the one soft spot in this
evidence; see Open risks.

**Not run:** the full `check-c++`. `libstdc++` is not built in this dev build,
so thousands of tests fail to link and there is no baseline to subtract (S12
measured 3785 pre-existing failures on the pinned trunk). The directory sweep
above is the substitute, chosen to cover every path the diff touches.

## Deviations from the plan / design

1. **The rebase target is the latest `Daily bump.`, not the absolute tip.**
   `4df5e1e9b152` (2026-09-06 00:16 UTC) rather than `9a135e85c2e`, which was
   about three hours newer when the fetch ran. A Daily bump is a named daily
   snapshot, the previous pin was one, and it keeps the base reproducible for
   anyone re-deriving these numbers.
2. **The step file offered "extend the lookahead **or** narrow the claim" for
   [template-id-slot-adl](../../BACKLOG.md#template-id-slot-adl). Extending
   won**, because the claim cannot be narrowed honestly: `add<int>(x, y)` gets
   ADL, so a slot that does not is strictly weaker than the call it desugars
   to, which is precisely what §17.4 forbids. Narrowing would have written a
   defect into the paper as a design position.
3. **A fourth defect was fixed that no row asked for** —
   [escape-arm-entry-token](../../gcc/DEVIATIONS.md#escape-arm-entry-token).
   It was found while narrowing the `grokdeclarator` guard, it is the same
   mistake in the same feature, it breaks the flag-gating ground rule, and
   leaving it to be rediscovered would have cost more than the four lines it
   took. Recorded in the ledger rather than as a new backlog row, because it
   is not left standing.
4. **A stale build-dir artifact was repaired**, not a source change: see the
   header-farm fact under Discoveries.
5. **[gcc-slot-adl](../../gcc/DEVIATIONS.md#gcc-slot-adl)'s status was
   corrected** although it is not in this step's list. Its prose has said
   "FIXED in G10" since June while the status field said `OPEN`; §17.4 could
   not be rewritten truthfully while the ledger disagreed with itself.

## Discoveries affecting later steps

- **`cp_parser_enclosed_template_argument_list` cannot be used for a slot
  template-id, and the failure is silent.** It parses `<int>` correctly and
  then loses the closing `>`: on return the lexer sat at the `;` two tokens
  past the closing backtick with the tentative context marked in error, so
  every attempt rolled back and took the old path with no diagnostic anywhere.
  `cp_parser_template_argument_list` alone stops exactly on the `>`, which is
  what the fix uses — consume the `<`, call it, require `CPP_GREATER`, consume
  it. **Two hours went into this**; anyone touching the slot parse should
  start from the working shape rather than the obvious one.
- **`case CPP_BACKTICK:` labels in `parser.cc` are fall-through targets.**
  `CPP_KEYWORD` falls into the one in `cp_parser_unqualified_id`, `CPP_XOR`
  into the one in `cp_parser_primary_expression`. Any future arm keyed on
  `flag_backtick` alone will fire on the wrong token. Test the token type.
  `cp_parser_id_expression`'s arm always did, which is why only two were wrong.
- **GCC's keyword identifiers are interned with `IDENTIFIER_KEYWORD_P` set on
  the shared node**, so nothing downstream can tell `` `new` `` from `new`.
  Any semantic-layer question about "was this escaped?" has to be answered by
  something carried from the parse — now `cp_declarator::backtick_escaped_p`.
  This is the concrete cost of GCC's design choice and the counterpart of
  Clang's token mutation; it is worth a sentence in the paper.
- **The libstdc++ header farm in the build dir goes stale across a re-sync.**
  `x86_64-pc-linux-gnu/libstdc++-v3/include` is a symlink tree made at
  configure time; after 2158 commits it was missing headers the new sources
  reference and `g++.dg/parse/parse5.C` failed with
  `bits/inplace_tags.h: No such file or directory`. `make -C
  x86_64-pc-linux-gnu/libstdc++-v3/include` fixes it in a couple of minutes
  and turned `g++.dg/parse/parse*.C` from 106 passes / **2 failures** into
  **108 / 0** — better than the 105 / 3-unsupported the G-track recorded,
  because three hosted-library tests became runnable. Recorded in
  `ops/gcc/PLAN.md`'s gate facts. Do this straight after any GCC rebase.
- **`modules.exp` shares one `gcm.cache` across std variants** and produces
  ~96 failures in this build dir for that reason alone. A targeted
  `modules.exp=<name>*` run is clean and is the useful gate for a new module
  test.
- **The GCC mirror's remotes are `origin` (steve-downey/gcc), `upstream`
  (git://gcc.gnu.org, push DISABLED) and `ceridwen`.** `upstream/trunk` and
  `upstream/master` are the same ref. Nothing was pushed by this step.

## Forward notes for the NEXT step (written after reading its step file)

**reconcile-remainder is now unblocked** — gcc-resync was its only dependency
— and two of its five groups moved:

- **Group 5 is done, and it should not be redone.**
  [gcc-type-slot-parity](../../gcc/DEVIATIONS.md#gcc-type-slot-parity) is
  marked **RECONCILED** here, landing in §17.3's new closing paragraph, so its
  "if gcc-resync did not take it" clause is answered: it did.
  [gcc-wrapper-parity](../../BACKLOG.md#gcc-wrapper-parity)'s finding is
  written up as [gcc-wrapper-parity](../../gcc/DEVIATIONS.md#gcc-wrapper-parity)
  in the GCC ledger, with the wording the step file asks the papers for —
  reuse it rather than re-deriving it.
- **The GCC ledger has no unreconciled row left.** reconcile-remainder's gate
  says to grep all three ledgers for unmarked rows and put the empty output in
  its handoff; for `ops/gcc/DEVIATIONS.md` that grep is already empty:
  `grep -n 'Status:\*\* OPEN' ops/gcc/DEVIATIONS.md` returns nothing. Two
  ledgers left to clear, not three.
- **Two new GCC rows exist that its list does not mention** —
  [gcc-template-id-slot-adl](../../gcc/DEVIATIONS.md#gcc-template-id-slot-adl)
  and [escape-arm-entry-token](../../gcc/DEVIATIONS.md#escape-arm-entry-token).
  Both are already marked **FIXED** and neither needs reconciling, but both
  have a "Recommended doc change" aimed at the paper's
  implementation-experience section, and the cross-compiler divergence section
  that step is assembling should carry them: the first is a divergence that
  *closed*, the second is one Clang cannot have by construction.

**For backtick-paper**, the implementation-experience section can now say
something it could not before: **the two implementations agree on ADL for
every unqualified slot form**, and the one place they accept different
programs is the type-name slot (§17.3), which is a gap and not a design
consequence. Keep those two apart in the prose; the ledger entries do.

**If you rebuild GCC:** `make -j18 all-gcc` in `~/bld/gcc/gcc-backtick-build`
takes about 12 minutes from cold on this box and about 3 for a `parser.cc`
edit plus the `cc1plus` relink. `xg++` still does not work for ad-hoc checks
(no `liblto_plugin.so`, no `cc1`); `gcc/cc1plus -fbacktick -std=c++23
-fsyntax-only` does. The dejagnu harness drives `xg++` successfully because it
only ever compiles to `.s`.

## Open risks / TODOs

- **The 96 `modules.exp` failures were not baselined against the pre-change
  tree.** Every one is a CMI-cache or mapper problem and none is a backtick
  test, and every line this step added outside the two new module test files
  sits inside a `flag_backtick` guard or is a field initialisation — but the
  honest statement is "attributed, not measured". If anyone wants it measured,
  building `4df5e1e9b152` clean and running `modules.exp` there is about
  twenty minutes.
- **GCC still has no type-name slot.** Recorded, not fixed; §17.3 now says so
  in the design doc. It is the only place under `-fbacktick` where the two
  compilers accept different programs, and it is unscheduled. If a paper wants
  two-compiler evidence for §17.3, that is a step someone has to add.
- **The local tag `backtick-pre-resync`** points at the pre-rebase tip
  `b842ac1ed64`. Harmless, and it is what the byte-identity check compares
  against; delete it when the re-sync stops being interesting.
- **Nothing was pushed.** The `backtick` branch in `~/bld/gcc/gcc-backtick` is
  ahead of `origin/backtick` and `ceridwen/backtick`, both of which still hold
  the pre-rebase history. A push will need `--force-with-lease`, and that is
  the maintainer's call, not an agent's.
- **The `escape_arm` narrowing is defence in depth for `grokdeclarator`
  itself.** No input reaches that guard with an unescaped keyword today,
  because the parser rejects one first — so the narrowing has no
  fail-before-fix demonstration of its own, and the test added for it asserts
  the parser-level diagnostics instead. That is the honest shape of the row:
  it was latent, and it is now closed off at both levels.
