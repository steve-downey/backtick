# U13 — Sema: candidate assembly, ADL, no built-in candidates

**Goal.** Replace U11's stub: `x ⊞ y` assembles candidates exactly as an
overloaded operator does — member candidates plus non-member candidates
from unqualified lookup **and ADL** — with no built-in candidates, and
desugars to the call `operator⊞(x, y)` (member form `x.operator⊞(y)`).

**Depends on:** U11. (Parallel with U12; coordinate if both are in flight,
since U12's prefix action lands in the same Sema file.)
**Design refs:** U6; U§7 "Using" and "Desugaring"; §17.4 (ADL normative);
`ops/gcc/DEVIATIONS.md` DEV-G05 — the recorded defect from resolving a
bare-name slot too early.

## Do
1. Model on `Sema::CreateOverloadedBinOp`
   (`clang/lib/Sema/SemaOverload.cpp`): build an `UnresolvedLookupExpr` for
   `operator⊞` so ADL happens at the right time and in the right scope,
   add member candidates from the left operand's class, add non-member
   candidates from unqualified lookup, run `AddArgumentDependentLookup`
   over both operands' associated namespaces.
2. **Add no built-in candidates.** There are no built-in meanings (U2/U6);
   `AddBuiltinOperatorCandidates` and friends must not be called. A
   fundamental-type pair must find the user's `operator⊞(int,int)` and
   nothing else — assert that a *missing* overload does not silently pick
   up an arithmetic conversion.
3. Handle dependent types: in a template, the expression is built as
   dependent and re-resolved at instantiation, with ADL performed at
   instantiation from the instantiation context. Ordinary two-phase
   behavior — inherit it, don't reimplement it.
4. Prefix form (U12's action) goes through the unary analogue,
   `CreateOverloadedUnaryOp`-shaped, with the same rules.
5. Diagnostics on failure: the ordinary no-viable-overload text naming
   `operator⊞`, with both operand types shown.

## Build
`ninja -C ~/src/llvm/build-unicode clang`

## Verify (gate)
- `clang/test/SemaCXX/unicode-operator-adl.cpp`: pure-ADL case (operator
  visible only in an operand's namespace, never by unqualified lookup),
  augmentation case (both, with ordinary ranking), and a case where ADL
  must *not* fire (fundamental operands only, operator in an unrelated
  namespace → no viable overload).
- Equivalence assertion, the normative one from §17.4: for each ADL case,
  `x ⊞ y` and the explicit `operator⊞(x, y)` from U10 select the **same**
  overload. Best expressed with `-ast-dump` comparison or a `static_assert`
  on a tag-returning overload set.
- No-built-in check: with no `operator⊞` in scope, `1 ⊞ 2` is a
  no-viable-overload error, not a built-in `+`-like fallback.
- Template/dependent cases, member form, and `constexpr` evaluation
  (`static_assert(5 ⊞ 7 == 12)` — U§1's motivating line).
- `check-clang` green.

## Done when
Infix and prefix uses resolve through the ordinary operator candidate
machinery, ADL included, with no built-in candidates and no early
resolution.

## Capture in handoff
The Sema entry points used and whether `CreateOverloadedBinOp` could be
reused directly or had to be forked (if forked: what forced it — that is a
finding about how closed `OverloadedOperatorKind` really is, and belongs in
DEVIATIONS and eventually in the paper). U14/U15 need the diagnostic texts.

## Pitfalls
DEV-G05 in the GCC track was exactly this: a bare-name operand resolved at
parse time silently lost ADL, and the tests that would have caught it did
not exist until late. Write the pure-ADL test **first**, before the
implementation, and watch it fail for the right reason.

## REPLAY ledger
`upstream replay`.
