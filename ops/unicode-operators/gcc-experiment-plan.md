# GCC Unicode Operators Experiment Plan

## Summary

- Base the first GCC spike on `steve-downey/gcc` trunk backtick branch. That
  branch already solved the shared parser precedence bug,
  `cp_parser_binary_expression` placement, libcpp flag plumbing, and the
  GCC-specific ADL correction.
- Treat it as an experiment base only. For upstream, replay Unicode operators
  onto clean GCC trunk as a separate feature unless backtick has landed first.
- The GCC hard parts are `libcpp` classification, open-ended operator
  identifiers outside `ansi_opname`, overload candidate assembly without a
  built-in `tree_code`, and Itanium mangling.

## Branch Strategy

- Create `unicode-operators-experiment` from the GCC backtick trunk branch.
- Reuse backtick lessons:
  - `c.opt` flag plumbing into `flag_*`;
  - mirroring the C++ flag into `cpp_options`;
  - the fixed highest-binary precedence hook in `cp_parser_binary_expression`;
  - the G06 RHS-lookahead fix for highest-precedence behavior;
  - the G10 explicit `perform_koenig_lookup` lesson.
- Keep every reused dependency labeled in notes as:
  - `backtick dependency`;
  - `upstream replay`;
  - `shared if backtick lands`.
- After the spike works, replay the minimum Unicode patch stack onto clean GCC
  trunk.

## Implementation Changes

- Add independent flag `-funicode-operators` in `gcc/c-family/c.opt`, default
  off, with `flag_unicode_operators`.
- Add a `cpp_options` field, for example `unicode_operators`, initialized from
  the C++ front end only. C and other front ends must retain current behavior.
- Add a libcpp token for one user-operator code point, for example
  `CPP_USER_OPERATOR`, carrying canonical code-point identity.
- Add the frozen UCD 17.0 range table derived from
  `docs/pattern-syntax-audit.py`; keep excluded code points in a separate
  diagnostic table for targeted errors.
- Extend direct UTF-8 and UCN lexing so `⊞`, `\u229E`, `\U0000229E`, and named
  UCN spellings classify identically when the flag is on.
- Create a GCC C++ front-end helper such as `cp_user_operator_id(codepoint)`
  that synthesizes/interns the identifier spelling `operator⊞` or a canonical
  internal equivalent.
- Do not put user operators into `ansi_opname` as if they had a fixed
  `tree_code`. Keep them as open-ended operator identifiers, analogous in
  spirit to literal operator identifiers.
- Extend operator-function-id parsing so `operator⊞` is accepted in
  declarations and explicit calls.
- Update declaration checks:
  - accept unary prefix and binary arities;
  - allow fundamental-only parameters such as `int operator⊞(int, int)`;
  - reject postfix and invalid arities;
  - leave all existing operator rules unchanged.
- Implement explicit call support first: `operator⊞(a, b)`, address-taking,
  overload sets, templates, ADL, diagnostics, and mangling.
- Add Itanium prototype mangling using vendor-extended operator form
  `v<arity><source-name>`, with stable ASCII source names like `op_u229E`.
- Add parser support:
  - binary `CPP_USER_OPERATOR` at the shared highest-binary user-infix level;
  - prefix `CPP_USER_OPERATOR` in operand position;
  - no backtick delimiter suppression flag.
- Implement overload candidate assembly for expression syntax:
  - include member candidates from the left operand for binary form and from
    the operand for prefix form;
  - include non-member candidates from ordinary lookup and ADL;
  - add no built-in candidates;
  - avoid lowering only to `operator⊞(a,b)`, because that would miss member
    operators.
- Add dump/diagnostic printing so GCC consistently prints `operator⊞` in
  errors and tree dumps.

## Test Plan

- Option tests: `-funicode-operators`, `-fno-unicode-operators`, `--help=c++`,
  and unchanged off-flag behavior.
- Lexer tests: direct glyphs, UCN spellings, named UCN spellings,
  adjacent-token splitting, string/comment immunity, C-front-end immunity, and
  excluded-character diagnostics.
- Declaration tests: free, member, template, deleted, constexpr, unary,
  binary, invalid arity, postfix rejection, and fundamental-only overloads.
- Explicit call tests: `operator⊞(a,b)`, address-taking, overload sets,
  templates, pure ADL, ADL augmentation, negative lookup diagnostics, and
  mangled symbols.
- Expression tests: free operator, member operator, pure ADL, overload
  resolution, no viable overload, no built-in fallback, prefix `⊖a`, and
  binary `a ⊞ b`.
- Precedence tests: `-a ⊞ -b`, `a * b ⊞ c`, `a ⊞ b * c`, `a ⊞ b ⊗ c`,
  `⊖a ⊞ b`, and mixed backtick/user-operator chains when both flags are
  enabled.
- GCC gates: targeted `g++.dg` Unicode-operator tests first, then the same
  C++ regression subset used by the backtick branch.

## Assumptions

- The first prototype may lean on the GCC backtick branch to move quickly, but
  the upstream branch must not require unlanded backtick changes.
- If backtick has not landed, duplicate the shared parser precedence machinery
  under a neutral name like `user_infix`.
- Single-code-point operators only. Combining marks, postfix operators,
  user-defined precedence, MSVC ABI, and automatic future Unicode growth are
  out of scope.
