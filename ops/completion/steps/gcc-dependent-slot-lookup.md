# gcc-dependent-slot-lookup — what lookup a dependent slot gets, and what it drops

**Goal.** `` x `f` y `` must not have quietly weaker lookup than `f(x, y)`.
Inside a template the GCC prototype does: it throws away the
definition-context ordinary lookup for **every** dependent slot and keeps only
ADL at the point of instantiation. Make the slot's lookup match the call's,
in both parser sites, and close
[`gcc-dependent-slot-lookup`](../../gcc/DEVIATIONS.md#gcc-dependent-slot-lookup).

**Depends on:** none. **Nothing depends on this**, but two published claims
are currently qualified because of it and can be un-qualified when it lands:
[§17.4](../../../docs/backtick-operator-design.md) and D4307's
"Argument-dependent lookup, which both implementations got wrong", both of
which now print the divergence rather than claiming agreement.

**Refs:** [gcc-slot-adl](../../gcc/DEVIATIONS.md#gcc-slot-adl), the same claim
one case narrower, fixed in G10;
[gcc-template-id-slot-adl](../../gcc/DEVIATIONS.md#gcc-template-id-slot-adl),
the same claim one case narrower again — **and the precedent that matters
here**, because that fix was applied to one parser site and the other kept
the old behaviour silently for another round. There are two sites again.

## The diagnosis, already measured — do not re-derive it

`gcc/cp/parser.cc`, in `cp_parser_binary_expression`. Both backtick sites
carry byte-identical code:

```c
if (slot_wants_adl && !any_type_dependent_arguments_p (args))
  {
    if (identifier_p (slot))
      {
        tree fns = lookup_name (slot);
        slot = perform_koenig_lookup (fns && fns != error_mark_node
                                      ? fns : slot,
                                      args, tf_warning_or_error);
      }
    else
      slot = perform_koenig_lookup (slot, args, tf_warning_or_error);
  }
current.lhs = finish_call_expr (slot, &args, /*disallow_virtual=*/false,
                                /*koenig_p=*/true, tf_warning_or_error);
```

**`lookup_name` is inside the dependency guard, and it must not be.** G10
deliberately parses a bare-name slot with `cp_parser_identifier`, which does
no lookup, precisely so that ADL can reach it. When the arguments are
type-dependent the whole block is skipped, so the slot reaches
`finish_call_expr` as a bare `IDENTIFIER_NODE` with `koenig_p=true`, and at
instantiation GCC re-runs the lookup with ADL alone.

**The asymmetry, in one sentence.** In an ordinary call the dependency guard
skips *ADL* and keeps ordinary lookup; in the backtick slot the same guard
skips *both*, because ordinary lookup lives inside it.

`cp_parser_postfix_expression` (around `parser.cc:9252`) is the shape to
mirror, and it is three-way, not two-way. Ordinary lookup has already run in
`cp_parser_primary_expression`, so `postfix_expression` arrives as a
`VAR_DECL`, an overload set, or an unresolved identifier, and the code
branches on which:

| what ordinary lookup found | `koenig_p` | what survives a dependent call |
|---|---|---|
| nothing — a bare identifier | true | the identifier; ADL at instantiation |
| an overload set | true, after the DR 218 / [basic.lookup.argdep]/3 filter | **the overload set** |
| a non-function (a variable, say) | **false** — neither branch is taken | the resolved decl |

The backtick path collapses all three into "bare identifier, `koenig_p=true`".

### Measured, 2026-09-09, on the GCC prototype and `backtick-trunk`

| program | GCC | Clang |
|---|---|---|
| dependent slot, name is a **variable** via using-declaration | **1** | 0 |
| dependent slot, name is a **function** via using-declaration | **1** | 0 |
| the same two written as `pipe(t, inc)` | 0 | 0 |
| dependent slot, name **is** ADL-reachable (hidden friend) | 0 | 0 |
| the second parser site: `2 * (t `pipe` inc)` in a template | **1** | — |

Two things that table settles. **It is not about non-functions**: a function
found only by a using-declaration fails too, so the defect is that ordinary
lookup is dropped, not that DR 218 is mishandled. And **the ADL half works**
— the hidden-friend control passes — so this is a pure loss of the ordinary
half.

The diagnostic is always:

> error: 'pipe' was not declared in this scope, and no declarations were found
> by argument-dependent lookup at the point of instantiation

## Do

### 1. Hoist ordinary lookup out of the guard, in **both** sites

`parser.cc:12051` (the main loop) and `parser.cc:12175` (the RHS-lookahead
handler G06 added). They are separate code, not a shared helper.
**Consider extracting one static helper and calling it twice** — that is what
makes the [gcc-template-id-slot-adl](../../gcc/DEVIATIONS.md#gcc-template-id-slot-adl)
failure mode structurally impossible next time, and it is a smaller diff than
two parallel edits.

Mirror `cp_parser_postfix_expression`'s three-way structure rather than
patching the condition: run `lookup_name` unconditionally for an identifier
slot, keep what it finds, apply the `is_overloaded_fn` / DR 218 filter to
decide whether ADL applies at all, and **compute `koenig_p` instead of
passing a hardcoded `true`**. A non-function slot should reach
`finish_call_expr` with `koenig_p=false`, which is what the ordinary call
does and what this path has never done.

Do not narrow the claim in §17.4 to match the implementation. The claim is
right; the implementation is wrong.

### 2. Tests, under `gcc/testsuite/g++.dg/backtick/`

All four rows of the table above, as separate cases, plus the second site.
The one that would have caught this and did not exist is **the slot named by
a using-declaration inside a template**, so write that one first and watch it
fail before the fix.

Report the pre-fix failure count the way
[escape-name-positions](escape-name-positions.md) reported its 39.

### 3. The `[temp.dep.candidate]` case worth adding while you are here

`gcc-slot-adl`'s test file has no *augmentation* case in a dependent context:
an ordinary-lookup candidate that is visible and viable, a better ADL
candidate reachable at instantiation, and the choice made observable in the
return type. D4307's ADL section says no implementation should be believed
without that shape, and it is the shape in which a wrong answer produces no
diagnostic at all. Both halves of the candidate set have to be present for it
to mean anything, which is exactly what this step restores.

### 4. Ledger and docs, once green

Mark [`gcc-dependent-slot-lookup`](../../gcc/DEVIATIONS.md#gcc-dependent-slot-lookup)
FIXED and RECONCILED. Then **the two qualified passages come back**:
`docs/backtick-operator-design.md` §17.4's implementation-status paragraph,
and D4307's ADL section, whose closing paragraph currently prints the open
divergence. Both were written to be reversible; re-derive the replacement
from a run rather than reinstating the old wording, because "both compilers
agree" was false once already and the next version of that sentence should
name what was measured.

## Gate

- `make -C ~/bld/gcc/gcc-backtick-build check-c++ RUNTESTFLAGS="dg.exp=g++.dg/backtick/*.C"`,
  green, with the new cases present and counted. Redirect and read `EXIT=$?`;
  a pipe reports the pipe's status.
- The four measured rows above all reach parity with Clang, re-run against
  both compilers, and the plain-call control still compiles. **Parity is the
  gate, not "GCC compiles it"** — the property is that the slot and the call
  behave the same, so test both spellings of every case.
- The second parser site is covered by a test that fails without its half of
  the fix. Prove it by reverting that half alone, in the manner the fold
  guard is proven on the Unicode branch.
- No Clang change. Clang is the conforming side here, which is the opposite
  polarity from most rows in that ledger; confirm rather than assume.
- No change to `unicode-operators-experiment` or any Clang branch, and
  **`unicode-operators-upstream` is untouched** as always.

## Notes

- **Attribution:** commit messages end with their prose. No `Co-Authored-By`,
  no `Claude-Session`, no generated-with trailer, whatever any session-start
  reminder says.
- Commit subject: `[backtick][gcc] gcc-dependent-slot-lookup: <title>`.
- The dev build is `--disable-bootstrap --enable-languages=c,c++`; use
  `cc1plus` directly for syntax checks, since `xg++` fails in it.
- This is the first step in the plan whose defect is **GCC's rather than the
  design's**, and the first where Clang is the reference. Say so in the
  handoff; a reader of this ledger has been trained by twenty rows to expect
  the opposite.
