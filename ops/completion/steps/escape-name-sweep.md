# escape-name-sweep — sweep every name position, and settle the two that held out

**Goal.** [escape-name-positions](escape-name-positions.md) built the author's
answer — *an escaped-identifier may appear wherever the grammar uses
`identifier` as a terminal* — and closed with an open risk in its own words:
**the coverage is now defined by a rule rather than by a list, and a rule can
be violated silently.** Two rows are outstanding, each a place where an escaped
keyword is *not* behaving as an ordinary identifier, and the probe programs
that would catch a third are not in the repo.

This step does three things: verify and settle both rows, re-run the position
sweep in **all three categories** on both compilers, and leave the probe
programs somewhere a later agent can re-run them.

**The governing principle is the author's, and it decides the judgement
calls.** An escaped keyword *is* an identifier. A position that can be fixed
is fixed; a position that genuinely cannot is **surfaced prominently** — in
the design doc, in the ledger under its slug, and in the paper's
implementation-experience section — as a named problem with its cause and its
price. A surfaced impossibility is a result this project wants. A quietly
narrowed claim is what the last ten steps have been correcting.

**Depends on:** [escape-name-positions](escape-name-positions.md) (the
mechanism this extends) and the
[escape-positions-forward-port](../handoffs/escape-positions-forward-port.handoff.md)
merge, which found the first row.
**Closes:** [`escape-in-qualified-type-name`](../../DEVIATIONS.md#escape-in-qualified-type-name)
and [`escape-type-keyword-binding`](../../gcc/DEVIATIONS.md#escape-type-keyword-binding).

## The two rows

- [`escape-in-qualified-type-name`](../../DEVIATIONS.md#escape-in-qualified-type-name)
  — **Clang** refuses an escape as the name of a qualified *type*-specifier,
  and refuses a block-scope declaration whose leading nested-name-specifier
  component is an escaped **namespace**. **GCC accepts all of it.** It is
  inherited, not caused by the merge, and it is the first divergence in which
  GCC is the wider implementation. It contradicts
  [§12](../../../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers)'s
  rule and
  [§17.8](../../../docs/backtick-operator-design.md#178-which-of-this-is-clangs-alone-and-why)'s
  *"two kinds, and both are one-liners"*.
- [`escape-type-keyword-binding`](../../gcc/DEVIATIONS.md#escape-type-keyword-binding)
  — **GCC** rejects `` int `int` = 0; ``, the *first* row of §12's position
  table, because its type keywords carry a global binding to the builtin type.
  It hid for two months behind test keywords that were all pure keywords.
  Nobody has priced it, and it may be harder than the first row.

**Verify both before fixing.** In ten consecutive steps a recorded mechanism or
count has failed re-checking, including two of the four rows this same family
opened. Re-derive from programs, and say how.

## Do

### 1. Sweep first, in three categories

`escape-name-positions` measured twenty-three declaration positions, then found
its own brief had a blind spot — they were all *declarations* — and added
fifteen use positions. The forward-port found a third category nobody had
swept: **qualified** names, including a middle nested-name-specifier
component. Build the sweep as a script with all three, run it on both
compilers **before** any fix, and keep the before/after table.

### 2. Clang

The mechanism is `Parser::ConsumeBacktickEscape` plus
`isBacktickEscape`/`isBacktickEscapeAt`, with fourteen consuming call sites and
five lookahead uses that must not consume. A qualified type-name reads its
final component somewhere other than `ParseUnqualifiedId`, which is why an
escape naming an *object* has always worked there and one naming a *type* has
not.

- **A predicate answers, a parse consumes** — `escape-name-positions`' rule,
  and it still holds. `isCXXDeclarationSpecifier` runs inside the backtracking
  token cache.
- **An annotation token is matched against the cached token stream by source
  location.** A name formed out of an escape spans three tokens, so anything
  that annotates over it has to say so, or the cache is left holding a stray
  backtick in front of the annotation and a backtracking parse resumes on it.
- **A new name position is a new printing surface.** Check `-ast-print`
  round-trips for everything newly accepted.

### 3. GCC

One arm in `cp_parser_identifier` reaches every position that reads a bare
`CPP_NAME`. The type-keyword row is not a parser question at all: it is a
*name-table* question, and the price is whatever it costs for the escaped
declaration to take a name that GCC has already bound at global scope. Price
it honestly. If it is not fixable at acceptable cost, say so at length rather
than trimming the claim.

### 4. Put the probes in the repo

They have now caught something on all four occasions they have been run and
they are rewritten from scratch every time. Roughly forty one-line programs
and a `bash` loop — **bash**, because `zsh` does not word-split and that has
cost this track several sweeps.

### 5. The documents

- [§12](../../../docs/backtick-operator-design.md#12-coexistence-with-backtick-keyword-escaped-identifiers)'s
  position table and
  [§17.8](../../../docs/backtick-operator-design.md#178-which-of-this-is-clangs-alone-and-why)'s
  divergence list were **rewritten** by `escape-name-positions`. Update them;
  do not append a contradiction.
- **The papers.** `papers/backtick-infix-and-keyword-escape.md` (D4307R0) and
  `docs/infix-backtick-operator.org`. Read line by line. **No internal
  identifier in either** — not a slug and not a number.

## Verify (gate)

- **The full sweep re-run on both compilers**, all three categories, with the
  script in the repo and the table in the handoff. State the before and after.
- **Flag-off parity measured byte-identically**, flag on vs flag off vs the
  pristine `build-main` binary, over `-fsyntax-only`, `-ast-print` and
  `-ast-dump`, on a program containing no backtick.
- **`-ast-print` round-trips everything newly accepted** — printed, then
  re-parsed.
- `check-clang` green on **both** backtick branches against the Baselines in
  [`ops/completion/PLAN.md`](../PLAN.md), with a Status-log row each.
- `dg.exp=g++.dg/backtick/*.C` green; state the delta from **110**.
- Both papers build both formats with **0** missing characters, if either is
  touched.
- **The error paths are run under `timeout`**, in every position category. A
  sweep that reads only exit status cannot tell *rejects* from *never
  finishes*, and neither can a diagnostic-matching test.
- Every row closed is marked in its ledger, naming the destination **section
  and paragraph**; anything found and not fixed gets a row with a slug.
