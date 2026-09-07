# LLVM/Clang Unicode Operators Experiment Plan

**This is the narrative rationale, not the operational document.** The
executable form of this plan — checklist, dependencies, per-step specs and
gates, handoffs, ledgers — is `clang/PLAN.md` and `clang/steps/U00–U20`.
Read that to *do* the work; read this for why the branch base, the replay
discipline, and the scope boundary are what they are. Where the two differ
on a mechanical detail, `clang/PLAN.md` wins; where a step file contradicts
its predecessor's handoff, the handoff wins.

## Summary

- Start the first prototype on `steve-downey/llvm` branch `backtick-trunk`.
  It already proves the shared user-infix precedence level, parser shape, AST
  wrapper pattern, serialization hazards, and clang-format integration.
- Treat `backtick-trunk` as an experiment base only. The eventual upstreamable
  Unicode work must be replayed onto clean upstream `main` and split from
  backtick unless backtick has landed first.
- The main technical target is not parsing; it is making Clang support an
  open-ended overloaded operator name like `operator⊞`.

## Branch Strategy

- Create an experiment branch from `backtick-trunk`, for example
  `unicode-operators-experiment`.
- Reuse backtick infrastructure where it reduces discovery cost:
  - the highest-binary user-infix precedence level;
  - `ParseRHSOfBinaryExpression` lessons;
  - transparent expression wrapper pattern;
  - AST serialization/import/visitor/`TreeTransform` checklist;
  - clang-format tokenization and spacing lessons.
- Keep notes during implementation classifying each dependency:
  - `backtick dependency`: only works because the experiment is based on
    backtick;
  - `upstream replay`: must be added independently on clean `main`;
  - `shared if landed`: can be reused if backtick lands first.
- After the prototype works, create a clean branch from upstream `main` and
  replay only the minimal Unicode-operator changes.

## Implementation Changes

- Add independent flag `-funicode-operators`, default off, wired through
  `LangOptions` and cc1 forwarding.
- Add `tok::user_operator` carrying the canonical single code point, with
  support for direct UTF-8 glyphs and UCN spellings such as `\u229E`,
  `\U0000229E`, and `\N{SQUARED PLUS}`.
- Add the frozen UCD 17.0 operator range table from
  `docs/pattern-syntax-audit.py`; keep excluded code points in a diagnostic
  table with specific messages.
- Add a new open-ended `DeclarationName` kind for user operators, modeled on
  `CXXLiteralOperatorName`, carrying a canonical `IdentifierInfo *` or
  equivalent code-point identity.
- Extend `operator-function-id` parsing to accept `operator⊞` under the flag.
- Update Sema operator declaration rules:
  - allow unary prefix and binary arities;
  - allow fundamental-only parameter lists such as `int operator⊞(int, int)`;
  - reject invalid arities and postfix forms;
  - preserve existing operator rules unchanged.
- Implement explicit-call support first: `operator⊞(a, b)`, address-taking,
  lookup, overload sets, templates, ADL, diagnostics, and mangling.
- Implement Itanium prototype mangling with vendor-extended operator form
  `v<arity><source-name>`, using a stable ASCII source name like `op_u229E`.
- Add infix and prefix expression parsing:
  - binary user operators at the shared user-infix precedence level,
    left-associative;
  - prefix user operators in operand position;
  - no backtick-style delimiter suppression logic.
- Build user-operator expressions through the existing overloaded-operator
  candidate machinery, including member candidates, unqualified lookup, and
  ADL, with no built-in candidates.
- Add AST/printing/tooling support after semantics are green, using the
  backtick wrapper checklist as the implementation guide.

## Test Plan

- Driver tests for `-funicode-operators` acceptance, cc1 forwarding, and
  default-off behavior.
- Lexer tests for glyphs, UCN spellings, named UCN spellings,
  adjacent-token splitting, and excluded-character diagnostics.
- Declaration tests for free/member operators, templates, deleted functions,
  constexpr functions, valid unary/binary arity, invalid arity, and
  fundamental-only overloads.
- Explicit-call tests for `operator⊞(a, b)`, address-taking, overload sets,
  ADL, templates, SFINAE, diagnostics, and mangled names.
- Expression tests for `a ⊞ b`, `⊖a`, member operators, free operators, pure
  ADL, no viable overload, and no built-in fallback.
- Precedence tests for `-a ⊞ -b`, `a * b ⊞ c`, `a ⊞ b * c`, `a ⊞ b ⊗ c`,
  `⊖a ⊞ b`, and mixed backtick/user-operator chains when both flags are
  enabled.
- AST/tooling tests for `-ast-dump`, `-ast-print` round trip, PCH/modules
  serialization, AST import, `TreeTransform`, clang-format spacing, and full
  `check-clang`.

## Upstream Replay Assumptions

- The experiment may depend on backtick branch infrastructure, but the
  upstream Unicode PR must not require unlanded backtick changes.
- ~~If backtick has not landed, rename or duplicate the shared precedence
  concept as `UserInfix` in the Unicode branch.~~ **Corrected 2026-09-06: the
  coupling is three constructs, not one, and only the first is a rename.**
  Measured over the whole diff and then executed:
  1. `prec::UserInfix` — this assumption's own item, and a rename;
  2. `Parser::isFoldOperator`'s `Level != prec::UserInfix` exclusion, which on
     clean `main` is an **addition** rather than a rename. **This is the one
     that fails silently** — omit it and a user operator quietly becomes a
     fold operator, with no warning, no link error and no failing test. It is
     also load-bearing on the design side now, since the exclusion is a
     *decision* (U§13) rather than an accident;
  3. clang-format's file-static `endsOperand` helper in `TokenAnnotator.cpp`,
     which on the experiment branch names the backtick token type
     `TT_BacktickEscapeClose` and on the replayed branch does not.

  Each standalone equivalent is under ten lines. Beyond the three, exactly
  three hunks of 204 have no clean-`main` counterpart, and **201 of 204 hunks
  survive, 169 of 171 production hunks**.
- **The replay is executed, not assumed.** It was performed on
  `upstream/main` @ `d28193fa1ff6` — 825 commits past the experiment base —
  and `git diff d28193fa1ff6..unicode-operators-upstream | grep -i backtick`
  returns nothing; the gate was baseline +72/+72 with zero failures and no
  pre-existing test changed. **Pin the base commit when re-running that
  grep**: against a moving `upstream/main` it matches upstream's own
  backticks (Markdown fences, an unrelated lldb variable) and looks like
  contamination that is not there. The drift itself was priced: 825 commits
  touched 25 of 109 files (+319/−144) and cost nothing, and neither
  `DeclarationName`/`IdentifierTable.h` nor `UnicodeCharSets.h` moved at all.
- **One soft coupling is not a hunk and is upstreaming hygiene rather than
  design:** `Sema::CreateOverloadedUserOp`'s doc comment cites the backtick
  design document's ADL section, which upstream cannot reference.
- Combining-mark operator sequences, user-defined precedence, postfix
  operators, MSVC mangling, and future Unicode-version growth are out of scope
  for the first prototype.
