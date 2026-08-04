# U08 — Sema declaration rules and arity

**Goal.** Decide which `operator⊞` declarations are legal, and diagnose the
rest. Two parameters (one, as a member) = infix; one (none, as a member) =
prefix; **no** class-or-enum parameter requirement; no postfix form.

**Depends on:** U07.
**Design refs:** U2 (no [over.oper] class-or-enum rule — this is the
motivating case, `int operator⊞(int, int)`); U5 (arity selects the form,
no postfix); U§7 "Declaring".

## Do
1. In `Sema::CheckOverloadedOperatorDeclaration`
   (`clang/lib/Sema/SemaDeclCXX.cpp`) — or a sibling for the new name kind
   — implement the rules:
   - free function: 1 param → prefix, 2 params → infix, anything else →
     error naming the two legal arities;
   - member: 0 params → prefix, 1 param → infix, otherwise error;
   - **skip** the "at least one class or enum parameter" check. It protects
     built-in meanings; there are none here. Make that a deliberate,
     commented branch, not an accident of not calling the checker.
   - no `int` dummy-parameter postfix convention: `operator⊞(T, int)` is
     just a two-parameter infix operator. There is no way to spell a
     postfix user operator (U5) and no way to detect that someone tried —
     the declaration is indistinguishable from an ordinary infix one, so
     do not guess at a diagnostic. The postfix error surfaces at the use
     site (U12), not here.
2. Leave every existing operator's rules untouched. The regression risk is
   that a refactor of the shared checker changes behavior for
   `operator+`; if you must refactor, the gate must show `check-clang`
   unchanged.
3. Defaulted/deleted, `constexpr`, `consteval`, templates, variadic
   parameters, default arguments: allow whatever the ordinary function
   rules allow. Only arity is special.

## Build
`ninja -C ~/src/llvm/build-unicode clang`

## Verify (gate)
- `-verify` test `clang/test/SemaCXX/unicode-operator-decl.cpp`:
  - accepted: `int operator⊞(int, int);` (the fundamental-only case — the
    point of U2), `Vec operator⊖(Vec const&);`, member infix and prefix
    forms, template forms, `constexpr`, `= delete`.
  - rejected with a specific message: zero params free, three params free,
    two params member, and the member-prefix/free-prefix confusion.
- A parallel test asserting the *existing* operators still reject
  `int operator+(int, int)` — proving the U2 relaxation was scoped to the
  new name kind only.
- `check-clang` green.

## Done when
Arity selects the form, fundamental-type parameter lists are accepted for
user operators only, and no existing operator's rules moved.

## Capture in handoff
The checker function you extended and whether the class-or-enum check was
reachable from a shared path (if it was, exactly how you scoped the
bypass). U11 and U13 need to know which `FunctionDecl` predicate answers
"is this a user operator, and of which arity".

## REPLAY ledger
`upstream replay`.
