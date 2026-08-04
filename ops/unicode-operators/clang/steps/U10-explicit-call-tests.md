# U10 — Explicit-call sweep

**Goal.** Prove the *name* works before any expression syntax exists:
`operator⊞(a, b)` behaves as an ordinary function in every respect —
lookup, overload sets, ADL, templates, SFINAE, address-taking, linkage.
Tests only; a code change here means an earlier step was incomplete.

**Depends on:** U08, U09.
**Design refs:** U2 (explicit-call spelling works, as for every operator);
U6; §17.4 (ADL is normative).

## Do
Write `clang/test/SemaCXX/unicode-operator-call.cpp` (+ a CodeGen sibling
if a case needs a symbol check), covering:
1. `operator⊞(1, 2)` calling `int operator⊞(int, int)` — the fundamental-only
   case, end to end, with a `static_assert` on a `constexpr` version.
2. Overload sets: several `operator⊞` overloads, ordinary ranking; an
   ambiguity diagnostic that names `operator⊞` readably.
3. Qualified call `N::operator⊞(a, b)`, and a member call
   `x.operator⊞(y)`.
4. ADL: `operator⊞` visible only in an operand's associated namespace,
   found by an unqualified explicit call. Also the *negative* case where no
   overload is viable — the diagnostic must be the ordinary
   no-viable-overload error naming `operator⊞`, never a lex or parse error
   (U3).
5. Templates: a function template `operator⊞`, a class template's member
   operator, a dependent call, SFINAE on the return type, and a
   `requires`-clause use.
6. Address-taking: `auto p = &operator⊞;` and passing it as a
   template argument / function argument; `decltype(operator⊞(a,b))`.
7. Linkage: two TUs, one declaring and one defining, linked — the mangling
   from U09 actually resolves. Use a lit test with two `%clang_cc1` runs
   plus a link step, or `%clang` if the driver is available in the test
   config.
8. Repeat two representative cases with UCN spellings, mixing spellings
   between declaration and call.

## Build
No source change expected.

## Verify (gate)
- All new tests pass; `-verify` diagnostics match exactly.
- `check-clang` green.
- If any case fails, do **not** patch it here unless the fix is a
  one-line omission in a prior step — file it as a BLOCKED handoff naming
  the step that owns it. This step's value is that it is a pure gate.

## Done when
The name behaves exactly like a function name in every tested position, and
the diagnostics for failure are lookup diagnostics, not syntax ones.

## Capture in handoff
Which cases were surprising. In particular, whether ADL on an explicit call
already works "for free" — U13 must reproduce that behavior for the *infix*
form, and GCC's DEV-G05 is the recorded example of an implementation
getting exactly this wrong by resolving too early.

## REPLAY ledger
`upstream replay` (tests).
