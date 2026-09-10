# U21 — Postfix feasibility probe (design probe, not a feature step)

**Goal.** Answer, with measurement rather than recollection, whether
postfix user operators can be added without whitespace sensitivity or
unbounded lookahead — and if not, produce the written argument for why
not. The deliverable is a *finding*, not necessarily a feature.

**Depends on:** U12, U13. Independent of U19/U20 — it does not block the
upstream replay and must not land feature code on the replay path.
**Design refs:** U5 (no postfix, and the Swift trap it declines); U3
(lexing/parsing is declaration-independent); U2 (fundamental-type
parameters — the reason the `int` dummy convention is unavailable);
U§13 (open questions, where the finding lands).

## Why this step exists
The question has already been asked of the author, so the paper must
pre-load an answer (§13.5 discipline). The half-formed proposal on the
table is a compiler-known tag type:

```cpp
T operator⊕(std::postfix, T t);   // postfix:  a⊕
T operator⊕(T lhs, T rhs);        // infix:    a ⊕ b
```

The analysis to test, and to confirm or refute:

1. `operator++` disambiguates prefix from postfix **by position only**,
   which is free *because `++` has no infix form*. A user operator can be
   declared both infix and postfix, so after a complete operand the parser
   cannot tell a finished expression from one awaiting a right operand.
   The `++` case never faces this question.
2. The `int` dummy convention cannot be reused, because U2 admits
   `operator⊕(T, int)` as a legitimate *infix* declaration. A distinguished
   tag type is therefore forced, not stylistic.
3. The tag disambiguates **declarations**; the ambiguity is at the **use
   site**; U3 forbids the parser from consulting declarations. So the tag
   may be inert for parsing.
4. Witness: `a ⊕ * b`, `a ⊕ - b`, `a ⊕ & b` — every token that is both
   prefix-unary and infix-binary reproduces it. Resolving it needs
   lookahead over an arbitrary-length operand.

## Do
1. **Measure the `++` machinery.** Read, don't recall: how Clang
   represents and disambiguates prefix vs postfix `operator++` end to end
   — parser, `CreateOverloadedUnaryOp` (the synthesized dummy argument),
   `CheckOverloadedOperatorDeclaration`, the AST node, mangling. Write down
   exactly which parts are keyed on `OverloadedOperatorKind` and which are
   arity-generic. Three prior steps (U08, U13, U16) each found "sibling,
   not widening"; establish whether this is a fourth.
2. **Confirm or refute the ambiguity.** Construct the minimal grammar
   experiment. Determine precisely what lookahead would be required, and
   whether Clang's existing tentative-parse machinery could carry it. Do
   NOT land a speculative implementation on the feature path; if you
   prototype, do it on a scratch branch or behind a distinct sub-flag, and
   say which in the handoff.
3. **Price the greedy-infix rule — this is the candidate design.**
   (A disjoint infix/postfix partition of U1 was considered and
   **rejected by the author**: it pre-assigns fixity, and therefore
   meaning, to code points that belong to whoever is writing the domain.
   Fixity must be user-declarable or the feature is not worth having.
   Do not revive it.)

   The rule, which keeps the parser declaration-independent (U3): after a
   complete operand, a user operator followed by a token that **can begin
   a cast-expression** is infix; otherwise it is postfix. One token of
   lookahead, no backtracking, no whitespace sensitivity. Sema then
   resolves whichever shape the parser produced; a postfix shape with no
   postfix overload in scope is an ordinary no-viable-overload error, per
   U3. Fixity lives in the declaration — the tag type distinguishes the
   two unary forms, which arity alone cannot.

   Measure specifically:
   - Is "can this token begin a cast-expression" genuinely a one-token
     test in Clang's parser, or does it drag in tentative parsing? Name
     the predicate if one exists.
   - The paren-forcing set: confirm it is exactly the prefix-unary ∩
     infix-binary tokens (`*`, `&`, `+`, `-`, `++`, `--`, and prefix user
     operators), and that everything else — `/`, `%`, `==`, `,`, `)`,
     `;`, `]` — needs no parens.
   - **Chained postfix `a⊕⊗`**: greedy-infix should take `⊗` as the start
     of an operand and then fail. Confirm, and characterise the
     diagnostic. `(a⊕)⊗` is the workaround.
   - `a⊕(b)` reads as infix `⊕(a, b)` because `(` begins an operand.
     Confirm.
   - Note that this is the same greedy-operand preference D2/§4 already
     adopted for `-a ⊞ -b` == `⊞(-a, -b)` — a second application of a
     litigated rule, not a new one. That framing matters to EWG.
   - Both warts are the silently-different-parse family; compare against
     DEV-04's reasoning on the backtick side, where a token-identical
     alternative parse was judged acceptable *because* it matched a
     blessed construct. Does that argument transfer here, or not?
4. **Cost the library dependency.** A compiler-known `std::postfix` makes
   this library-affects-language, with `operator<=>`/`std::strong_ordering`
   as precedent. Note the routing consequence: LEWG joins a paper already
   going to SG16, EWG and the ABI group.
5. Write the finding as prose fit to drop into U§13, with the witness
   expressions and the price comparison: whitespace sensitivity (Swift's
   answer, declined by U5) / no postfix at all / greedy-infix with
   parens where the operand-initial tokens collide.

## Verify (gate)
This is a probe, so the usual "no green, no check" rule applies to the
*tree*, not to a feature:
- A written finding exists and reaches a recommendation.
- If any code was landed on the feature branch, `check-clang` is green by
  the usual rule. If nothing was landed, say so explicitly — that is the
  expected outcome.
- Every claim in §1 of this file is confirmed or refuted by reference to
  actual source, with file:line.

## Done when
U§13 can state what postfix would cost and why the proposal does or does
not take it, with a compiler-measured basis rather than an argument from
first principles.

## Capture in handoff
The `++` mechanism as measured; whether the ambiguity is real; the lookahead
characterisation; the greedy-infix pricing including both warts; and a clear
recommendation. A recommendation *against* postfix — or for deferring it to
a v2 alongside U§13's other candidates — is a perfectly good result. So is
"greedy-infix works, here is what it costs." Do not tune the finding toward
either; the value is in the measurement.

## REPLAY ledger
Probe only. If nothing lands, the row says so. Nothing here may end up on
the U20 replay path.
