# U07 — Parse `operator⊞` as an *operator-function-id*

**Goal.** `operator` followed by a `user_operator` token parses as a
declarator-id and yields the U06 `DeclarationName`, wherever an
*operator-function-id* is allowed: declarations, definitions, explicit
calls, qualified names, friend declarations, address-of.

**Depends on:** U06.
**Design refs:** U§7 "Declaring"; U2; U§6 (grammar, one production wider).

## Do
1. In `Parser::ParseUnqualifiedIdOperator`
   (`clang/lib/Parse/ParseExprCXX.cpp`), add a case: after `operator`, a
   `tok::user_operator` builds a `UnqualifiedId` of the new kind, gated on
   `LangOpts.UnicodeOperators`.
2. Extend `UnqualifiedId` in `clang/include/clang/Sema/DeclSpec.h` with the
   setter/getter pair for the new kind (again model on the literal-operator
   member), and teach `Sema::GetNameFromUnqualifiedId` to produce the U06
   `DeclarationName`.
3. Make sure the source range is right — the `operator` keyword location
   plus the operator token — because every diagnostic downstream, and U16's
   printing, depend on it.
4. Not this step: arity rules, class-or-enum rules, mangling, infix use.
   A declaration that is semantically wrong should still *parse* here.

## Build
`ninja -C ~/src/llvm/build-unicode clang`

## Verify (gate)
- `clang/test/Parser/unicode-operator-decl.cpp`: free function declaration
  and definition; member function; `friend`; qualified
  `int N::operator⊞(int, int) { … }`; template; explicit specialization;
  `= delete`; `constexpr`.
- The three UCN spellings (U04) declare the *same* entity — declare with
  `\N{SQUARED PLUS}`, define with the glyph, and check it is one function,
  not two. This is the acceptance test for U06's uniquing at the parser
  level.
- `-ast-dump` shows the declaration with the name printed as `operator⊞`.
- Without the flag, `operator⊞` produces upstream's diagnostic, unchanged.
- `check-clang` green.

## Done when
`operator⊞` is a declarable, printable name in every position an
*operator-function-id* may appear, with spelling-independent identity.

## Capture in handoff
The `UnqualifiedId` kind name and the exact `GetNameFromUnqualifiedId`
entry. Any position where the parser refused and you had to add a second
hook (qualified-id and friend paths often diverge) — U10 tests those
positions.

## Pitfalls
Tentative parsing: a declarator beginning with `operator` is usually
unambiguous, but confirm `TentativeParsing` paths don't need a peer change
(the backtick track hit exactly this at S08 for a different reason). If
they do and you defer it, say so loudly.

## REPLAY ledger
`upstream replay`.
