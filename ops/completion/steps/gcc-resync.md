# gcc-resync — Re-sync GCC to current trunk, then its four open defects

**Goal.** The GCC track has been parked since `G10`. It is pinned at trunk
`c9ee2c5ab6c` while the Clang side has moved to 23.x and 24.x, and it carries
four open rows including one that **falsifies a normative claim in the design
doc**. This is the most perishable work in the plan: every week makes the
re-sync worse and the second implementation is the whole point of the exercise.

**Depends on:** nothing.
**Closes:** [`template-id-slot-adl`](../../BACKLOG.md#template-id-slot-adl), [`module-streaming-escapes`](../../BACKLOG.md#module-streaming-escapes), [`grokdeclarator-guard-scope`](../../BACKLOG.md#grokdeclarator-guard-scope), [`gcc-wrapper-parity`](../../BACKLOG.md#gcc-wrapper-parity), [`gcc-trunk-pin`](../../BACKLOG.md#gcc-trunk-pin); reconciles [`gcc-type-slot-parity`](../../gcc/DEVIATIONS.md#gcc-type-slot-parity).
**Refs:** `ops/gcc/PLAN.md`; `ops/gcc/DEVIATIONS.md`; the `G07`–`G10`
handoffs; `ops/BACKLOG.md` §2.

## Why the second implementation still matters

`CLAUDE.md` says it: cross-compiler divergences "are exactly what CWG/EWG ask
about". A paper with two implementations that agree is a much stronger paper
than one with two implementations one of which was last built months ago
against a different base.

## Do, in this order

### 1. [`gcc-trunk-pin`](../../BACKLOG.md#gcc-trunk-pin) — re-sync to current GCC trunk

Rebase the `backtick` branch off `c9ee2c5ab6c` onto current trunk. Treat this
as the R-prefixed rebases were treated on the Clang side: **not a plan step
under `AGENT_PROTOCOL`, but it still gets a Status-log row and a handoff**, so
the base change is not lost. Re-establish the gate before touching anything
else — `make -C gcc check-c++ RUNTESTFLAGS="dg.exp=g++.dg/backtick/*.C"` — and
record the new base commit.

Build reminder from `CLAUDE.md`: the dev build is
`--disable-bootstrap --enable-languages=c,c++`, and **`xg++` does not work**
in it (no `liblto_plugin.so`, no `cc1`). Drive `cc1plus` directly for syntax
checks.

### 2. [`template-id-slot-adl`](../../BACKLOG.md#template-id-slot-adl) — pure ADL on a template-id slot (P2, paper-truth)

`` x `add<int>` y `` takes the old path, because `G10`'s two-token lookahead
(`CPP_NAME` + `CPP_BACKTICK`) does not detect a template-id. **§17.4's
normative claim — "the slot must get the same ADL as the plain call" — holds
for bare names only**, which means the design doc currently overstates what
GCC does. Either extend the lookahead or narrow the claim; the paper cannot
keep the sentence as it is.

Note the neighbourhood: [`gcc-slot-adl`](../../gcc/DEVIATIONS.md#gcc-slot-adl) was the ADL defect `G10` fixed with an
explicit `perform_koenig_lookup` on a bare-name slot. This is the same defect
one grammar production over.

### 3. [`module-streaming-escapes`](../../BACKLOG.md#module-streaming-escapes) — module streaming of keyword-escaped names (P2, deferred three times)

`IDENTIFIER_KEYWORD_P` checks in `module.cc:20117` and `:20160` may need
attention if a keyword-named entity is exported. Deferred by `G07`, `G08`,
`G09` and `G10` in turn — which is itself the argument for doing it now. The
deliverable is a **test that exports a keyword-escaped entity across a module
boundary**; if it passes untouched, the row closes as verified, which is a
result.

### 4. [`grokdeclarator-guard-scope`](../../BACKLOG.md#grokdeclarator-guard-scope) — the `flag_backtick` guard in `grokdeclarator` is over-permissive (P3)

It suppresses the keyword-declarator error for *all* keyword names when the
flag is set, not only explicitly escaped ones. Benign today because the parser
rejects non-escaped keywords earlier — so this is a latent trap, and the fix is
to narrow the guard and add the test that would have caught it.

### 5. [`gcc-wrapper-parity`](../../BACKLOG.md#gcc-wrapper-parity) — record, do not implement

GCC has neither the F23 nor the F24 fix, **and cannot have the first**: no
phase-2 AST wrapper was ever built there, and there is no analyzer analogue.
The row's own conclusion is that **no cross-compiler divergence row is
warranted — there is nothing to diverge from.** Write that into
`ops/gcc/DEVIATIONS.md` as the finding it is: a place where the two
implementations differ *in kind*, not in behaviour, and the paper should say
which parts of the Clang work have no GCC counterpart by construction.

### 6. [`gcc-type-slot-parity`](../../gcc/DEVIATIONS.md#gcc-type-slot-parity) — reconcile

The one unreconciled row in the GCC ledger. Mark it `**RESOLVED**` or
`**RECONCILED**` per that file's existing convention.

## Verify (gate)

- The GCC gate passes on the new base: `make -C gcc check-c++
  RUNTESTFLAGS="dg.exp=g++.dg/backtick/*.C"`, with the pre-rebase result
  recorded beside the post-rebase one so the re-sync is shown to be neutral.
- [`template-id-slot-adl`](../../BACKLOG.md#template-id-slot-adl)'s and [`module-streaming-escapes`](../../BACKLOG.md#module-streaming-escapes)'s new tests fail before their fixes where a fix was made,
  and are recorded as *verified-not-broken* where none was needed.
- Five `Closed by` cells filled; [`gcc-type-slot-parity`](../../gcc/DEVIATIONS.md#gcc-type-slot-parity) marked.
- §17.4 in `docs/backtick-operator-design.md` either still says what GCC does,
  or has been narrowed. **Do not leave it overstated** — that is the paper-truth
  half of this step and the reason it is in Phase C.
