# Handoff — U03 Lexer: `tok::user_operator` from UTF-8 glyphs

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `dacbe22ddeef`
  (parent `2389fe7be452`, U02)
- **Date / agent:** 2026-08-04

This is the first commit on the branch that changes what the compiler *does*.
U01 added an inert flag; U02 added an uncalled table. U03 wires them together.

## What changed

Five files in `/home/sdowney/src/llvm/unicode`, +148 source lines.

| File | Line (post-edit) | Change |
|------|------------------|--------|
| `clang/include/clang/Basic/TokenKinds.def` | **173–181**, immediately after `TOK(raw_identifier)` | `TOK(user_operator)` + a comment saying why it is not a `PUNCTUATOR` |
| `clang/include/clang/Lex/Lexer.h` | **383–402**, just above `getRawToken` | two `static uint32_t getUserOperatorCodePoint(...)` declarations (public) |
| `clang/lib/Lex/Lexer.cpp` | **15** | `#include "UnicodeOperatorCharSets.h"` (next to `UnicodeCharSets.h`) |
| `clang/lib/Lex/Lexer.cpp` | **506–535**, between `getSpelling` and `MeasureTokenLength` | the two `getUserOperatorCodePoint` definitions |
| `clang/lib/Lex/Lexer.cpp` | **1940–1947**, in `tryConsumeIdentifierUTF8Char` | the adjacency fix — see "Deviations" |
| `clang/lib/Lex/Lexer.cpp` | **4653–4666**, in `LexTokenInternal`'s `default:` case | **the hook**: the classification and `FormTokenWithChars(..., tok::user_operator)` |
| `clang/unittests/Lex/LexerTest.cpp` | **891–964** | six new `LexerTest.UnicodeOperator*` cases |
| `clang/test/Lexer/unicode-operators.cpp` | new, 113 lines | three `RUN:` lines (ON / OFF `-dump-tokens`, plus an off-flag `-fsyntax-only` diagnostic check) |

**In this repo:** `PLAN.md` (U03 ticked, Status row, a **fifth** gate fact — see
"Open risks"), `REPLAY.md` U03 row, this handoff. **No `DEVIATIONS.md` row** —
nothing contradicted `docs/unicode-operators.md`; the one surprise was a Clang
implementation fact, recorded below and in the commit message.

## The three judgement calls the step asked for

### 1. Token kind: `TOK(user_operator)`, not `PUNCTUATOR`

`PUNCTUATOR(X, Y)` binds a kind to **one fixed spelling string** `Y`
(`PUNCTUATOR(backtick, "`")`), and everything that consumes the `.def` —
`tok::getPunctuatorSpelling`, `TokenConcatenation`, clang-format — assumes that
string *is* the token's text. A user operator has 1,381 possible spellings (plus
their UCN forms), so there is no `Y` to write. `TOK(X)` is the form used by every
kind whose text comes from the source: `identifier`, `raw_identifier`,
`numeric_constant`, `string_literal`. Placed immediately after
`TOK(raw_identifier)` for exactly that reason — it groups with the
spelling-carrying kinds, not with the punctuators 90 lines below.

Inserting a `TOK` mid-file renumbers every later `tok::` enumerator. Nothing
broke: `check-clang` is green, and the only range comparison over token kinds in
the tree (`Token::isAnnotation()`, `K >= tok::annot_typename`) is over the
annotation block at the end.

### 2. Identity: **derived from the spelling, no payload field**

`Lexer::getUserOperatorCodePoint(const Token &, const SourceManager &, const LangOptions &)`
→ `uint32_t`, plus a `StringRef` overload for the raw decode. The token itself
carries nothing but its location and length.

Three reasons, in order of weight:

1. **`Token` has exactly one payload slot** (`PtrData`), and it is the
   `IdentifierInfo *` slot. Using it would make the token pretend to be an
   identifier and would require a `Preprocessor` to populate — but
   `Lexer::LexFromRawLexer` has no `PP`, and **clang-format lexes in raw mode**
   (`FormatTokenLexer::getNextToken` → `Lex->LexFromRawLexer`), so U18 would
   have needed a second, divergent path. Deriving from the spelling works
   identically in raw and cooked mode.
2. **U1 makes the derivation total.** Every user-operator token is exactly one
   code point — no combining marks, no multi-character operators, no operator a
   prefix of another — so the spelling is a complete and unambiguous encoding of
   the identity. The decode is `llvm::convertUTF8Sequence` over 3 bytes plus a
   "did it consume everything" check.
3. **It keeps the off-flag guarantee trivial**: nothing is stored, so there is
   nothing to store differently when the flag is off.

The `Token` overload goes through `Lexer::getSpelling(Tok, SM, LangOpts)`, which
cleans escaped newlines and trigraphs first — so a UTF-8 sequence preceded by a
line splice still decodes. That matters: `LexTokenInternal`'s own comment warns
that `BufferPtr` may point at an escaped newline.

### 3. Classification order: **U1 before XID**

The hook sits *before* `LexUnicodeIdentifierStart`, so a U1 code point never
reaches `isAllowedInitiallyIDChar`. U02 measured the sets disjoint over all
1,381 members (against Clang's *18.0* tables — DEV-U02), so the order cannot
change behavior. It was chosen anyway because it makes the off-flag claim
provable by inspection: with `LangOpts.UnicodeOperators` false the `if` is
dead and control reaches `LexUnicodeIdentifierStart` on exactly the upstream
path, with no intervening statement.

## The hook site, verbatim

`clang/lib/Lex/Lexer.cpp`, `Lexer::LexTokenInternal`, the non-ASCII `default:`
case — after `llvm::convertUTF8Sequence` succeeds and after
`CheckUnicodeWhitespace`, immediately before
`return LexUnicodeIdentifierStart(Result, CodePoint, CurPtr);` (line 4667):

```cpp
      if (LangOpts.UnicodeOperators && isUserOperatorChar(CodePoint)) {
        MIOpt.ReadToken();
        FormTokenWithChars(Result, CurPtr, tok::user_operator);
        return true;
      }
```

`MIOpt.ReadToken()` is required — both arms of `LexUnicodeIdentifierStart` call
it, and skipping it would corrupt multiple-include-guard detection.

**The UCN decode path at `Lexer.cpp:4614` (`case '\\':`) was deliberately left
alone.** U02's forward notes offered the choice of hooking the shared funnel
`LexUnicodeIdentifierStart` (which would have made UCN spellings work for free);
U03 scoped to the UTF-8 site instead, because U04 is a real step with its own
gate and its own `\N{...}` and identifier-adjacency cases. See U04's notes.

## Verification evidence

**Build:** `ninja -C /home/sdowney/src/llvm/build-unicode clang AllClangUnitTests`
→ `BUILD_EXIT=0`, 1142 edges, ~11 min (a `TokenKinds.def` edit rebuilds most of
clang; the follow-up `Lexer.cpp`-only edit was **7 edges, ~1 min**). No new
warnings.

**Targeted lit:** `Lexer/unicode-operators.cpp` → PASS (all three RUN lines).
`clang/test/Lexer/`, `clang/test/Preprocessor/`, `Driver/funicode-operators.c`
→ 538 discovered, 520 passed, 18 unsupported, 0 failed.

**Unittest:** `AllClangUnitTests --gtest_filter='LexerTest.*:UnicodeOperatorCharSets*'`
→ **50 tests, 50 passed** — 36 in `LexerTest` (30 pre-existing + the 6 new) and
14 in `UnicodeOperatorCharSetsTest`.

| New test | Asserts |
|----------|---------|
| `UnicodeOperatorToken` | `a ⊞ b` → identifier / `user_operator` / identifier, and the token decodes to `0x229E` |
| `UnicodeOperatorAdjacency` | `a⊞b` → the same three tokens **in ordinary (non-preprocessor) mode** |
| `UnicodeOperatorsAreNeverAPrefixOfEachOther` | `⊞⊗` → two tokens, `0x229E` then `0x2297` |
| `UnicodeOperatorRequiresTheFlag` | flag off ⇒ no token is `tok::user_operator` |
| `UnicodeOperatorExcludedCodePointIsNotAToken` | U+2212 − stays out **with the flag on** |
| `UnicodeOperatorCodePointFromSpelling` | the decode is total over one-code-point spellings and returns 0 for empty / two code points / a truncated sequence |

**Full gate:** `ninja -C $B check-clang` → 54128 discovered / 48234 passed /
27 XFAIL / 5853 unsupported / 6 skipped / **8 failed**, 174 s test time.

All 8 are `DirectoryWatcherTest.*`, all with
`No space left on device : inotify_add_watch()`. **Not ours**, proven three ways:

1. The untouched `build-backtick-trunk/tools/clang/unittests/AllClangUnitTests`
   binary (built 2026-07-29, no U-track code) fails the **identical 8** right now.
2. The cause was measured: `cloud-drive-dae` (pid 14599) holds **65,045 of the
   machine's 65,536 `fs.inotify.max_user_watches`**. Not fixable without root
   or killing the user's sync daemon; `unshare -Ur` is denied in this sandbox.
3. The arithmetic closes exactly: 54128 = U02's 54121 **+7** (6 gtest cases +
   1 lit test), and 48234 = U02's 48235 + 7 − 8.

Re-run with those 8 excluded — which is exactly the `check-clang` set minus
`DirectoryWatcher`:

```bash
GTEST_FILTER='-DirectoryWatcherTest.*' $B/bin/llvm-lit -s $B/tools/clang/test
```
→ `LIT_EXIT=0`, **54120 discovered / 48234 passed / 0 failed** / 27 XFAIL /
5853 unsupported / 6 skipped. Zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines.
`ulimit -c 0` was set; no cores. This is the project's own
`dump-config-objc-stdin.m` precedent, with harder proof; it is recorded as a
fifth gate fact in `PLAN.md` so the next agent does not re-derive it.

**Off-flag behavior is byte-identical to before the edit.** A `-dump-tokens`
snapshot over the whole test corpus (operators spaced, adjacent, doubled;
string, raw-string and char literals; line and block comments) was taken on
`2389fe7be452` *before* touching `Lexer.cpp` and `diff`ed against the same run
after: **IDENTICAL**. And the diagnostic U01 pinned is unchanged, verbatim:

```
error: unexpected character '⊞' U+229E
error: expected ';' after top level declarator
```

With the flag **on**, both of those errors disappear and `a ⊞ b` and `a⊞b`
produce the same single `expected ';' after top level declarator` at the same
column — i.e. the operator is now a token in both spacings, and the parser
(which does not know it yet) is the only thing complaining.

**Do not use `~/src/llvm/build-main/bin/clang` as the upstream oracle for
diagnostics.** It is stale relative to this branch's base and renders the same
diagnostic as `error: unexpected character <U+229E>` — no glyph, no `U+` suffix
in the same shape. The correct "before" is this branch at `2389fe7be452` with
the flag off, as U01's handoff already said.

## Deviations from the plan / design

No `DEVIATIONS.md` row: `docs/unicode-operators.md` said nothing that turned
out to be false. But **one prediction in U02's handoff was wrong**, and it cost
the step a second build:

> "The other three `tryConsumeIdentifierUTF8Char` call sites … are the *continue*
> path… `a⊞b` splitting into three tokens depends on the continue path
> **rejecting** ⊞ — which it already does… You should not have to touch those."

It rejects ⊞ for *classification* and then **consumes it anyway for error
recovery**. `Lexer.cpp:1936–1963`: when `!isAllowedIDChar`, if
`DiagnoseAndContinue` (true whenever the lexer is not raw, not in a PP
directive, and not in preprocessed-output mode) it diagnoses
`err_character_not_allowed_identifier` (`DiagnosticLexKinds.td:137`,
`"character %0 not allowed %select{in|at the start of}1 an identifier"`) and falls
through with the comment
"Carry on as if the codepoint was valid for recovery purposes." So upstream
`a⊞b` is **one identifier** `a⊞b`, not `a`, stray, `b`. Without a second hook,
the step's headline adjacency property — the one the step file calls out as
"the property that makes the feature usable without whitespace rules" — would
have been broken in every ordinary compile.

The fix is eight lines in `tryConsumeIdentifierUTF8Char`, in the same reject
family as the existing `isASCII || isUnicodeWhitespace` early return:

```cpp
    if (LangOpts.UnicodeOperators && isUserOperatorChar(CodePoint))
      return false;
```

**Why this was nearly missed, and the discovery that goes with it:**
`-dump-tokens` is a *strictly preprocessor* action, so `CompilerInvocation` sets
`PreprocessorOutputOpts::ShowCPP` and `Preprocessor::isPreprocessedOutput()` is
**true**. That makes `DiagnoseAndContinue` false, which makes the recovery path
not run, which makes `a⊞b` split into three tokens *in the `-dump-tokens` output
only*. The lit test passed while the compiler was wrong. The unittest (an
ordinary `Preprocessor`) is what caught it. There is a `NOTE:` in the lit test
recording this, and it is the most important operational fact in this handoff.

Two smaller judgement calls, recorded because a reviewer will ask:

1. **The step's `-dump-tokens` gate is necessary but not sufficient.** Every
   future lexer step should assert the property under an ordinary `Preprocessor`
   too (a `LexerTest` case, or `-fsyntax-only` + `-verify`), not only under
   `-dump-tokens`/`-E`.
2. **`getUserOperatorCodePoint` returns `0` rather than `std::optional`.** U+0000
   is not a valid spelling for anything, and 0 is what the existing
   `tryReadUCN`-family helpers use as their "no code point" answer.

## Discoveries affecting later steps

- **`-dump-tokens` and `-E` run with `isPreprocessedOutput()` set.** Three
  lexer behaviors are conditioned on it: the identifier-recovery absorb in
  `tryConsumeIdentifierUTF8Char` / `tryConsumeIdentifierUCN`, the
  "drop the character" branch in `LexUnicodeIdentifierStart`, and every
  `maybeDiagnose*` call. **A `-dump-tokens` test does not exercise any of
  them.** (`CompilerInvocation.cpp:5004`,
  `Opts.ShowCPP = isStrictlyPreprocessorAction(Action) && !Args.hasArg(OPT_dM)`;
  `CompilerInstance.cpp:504` feeds it to `setPreprocessedOutput`.)
- Off the flag with `-dump-tokens`, a U1 code point is `tok::unknown` with **no
  diagnostic**; off the flag with `-fsyntax-only` it is
  `err_character_not_allowed` and the character is dropped. Same code, two
  behaviors, for the reason above.
- **`Lexer::LexFromRawLexer` has no `Preprocessor`** and clang-format uses it
  (`FormatTokenLexer.cpp:1619`). Any future design that wants to hang data off
  a user-operator token must work without a `PP`.
- **Incremental build cost:** a `TokenKinds.def` edit is 1142 edges (~11 min) —
  comparable to U01's `Options.td`. A `Lexer.cpp`-only edit is **7 edges**.
  Sequence future lexer steps so the `.def`/`.h` churn happens once.
- The full gate is ~174 s of testing, ~20 min wall including test-dep builds.

## Forward notes — U04, U05 and U06 are all unblocked

All three depend only on U03 and touch nearly disjoint files. If they run
sequentially, **U06 first** is the better order: it is the plan's hardest step,
it touches shared headers (so it wants a clean tree to rebase nothing onto), and
neither U04 nor U05 needs anything from it.

### For U04 — UCN and `\N{...}` spellings

- **Your hook is one line, at a site U03 deliberately did not touch.**
  `Lexer.cpp:4614`, `LexTokenInternal`'s `case '\\':`, after
  `tryReadUCN(CurPtr, BufferPtr, &Result)` yields a non-zero `CodePoint` and
  after `CheckUnicodeWhitespace`, immediately before
  `return LexUnicodeIdentifierStart(Result, CodePoint, CurPtr);`. Copy the
  block U03 added at 4653 verbatim. **Both sites then converge on
  `isUserOperatorChar` + `FormTokenWithChars(..., tok::user_operator)`** — which
  is the convergence U§8 asserts and your step file asks you to confirm. Do
  *not* duplicate the table search: if you find yourself writing a second
  `isUserOperatorChar` call in a third place, factor the four lines into a
  private `Lexer::LexUserOperator(Token &, uint32_t, const char *)` and call it
  from both.
- **The second hook is the one that will bite you**, and it is the exact mirror
  of the bug U03 found: `Lexer::tryConsumeIdentifierUCN` (`Lexer.cpp:1873–1915`,
  immediately *above* `tryConsumeIdentifierUTF8Char`) has the identical
  "carry on as if the codepoint was valid for recovery purposes" fall-through.
  U03 added the `LangOpts.UnicodeOperators && isUserOperatorChar` early return
  to the UTF-8 one only. **`a⊞b` will absorb the UCN into the identifier
  in any ordinary compile until you add the same two lines at
  `Lexer.cpp:1883`** (after that function's
  `if (isASCII(CodePoint) || isUnicodeWhitespace(CodePoint)) return false;`).
  That is precisely your step's "`a⊞b` must produce the same three tokens
  as `a⊞b`" gate.
- **Test it under an ordinary `Preprocessor`, not only `-dump-tokens`** — see
  "Discoveries". Add the UCN adjacency case to `LexerTest` next to
  `UnicodeOperatorAdjacency`; the `-dump-tokens` RUN lines will pass either way
  and will not tell you the truth.
- **Identity comes free, but only if you canonicalize.** `Lexer::getSpelling`
  returns the *source* spelling — `⊞`, not `⊞` — so
  `getUserOperatorCodePoint(Tok, SM, LangOpts)` currently returns **0** for a
  UCN-spelled token. Fix it in the `StringRef` overload
  (`Lexer.cpp:506`), not at the call sites: recognize a leading `\u` / `\U` /
  `\N{` and decode it there, so every consumer (U06's `DeclarationName`, U07,
  U09) gets the same scalar value from either spelling with no code of its own.
  The in-tree machinery to reuse is `expandUCNs()` in `Lexer.cpp` (the same
  helper `Preprocessor::LookUpIdentifierInfo` uses to make `é` and `é`
  the same `IdentifierInfo`) and `tryReadUCN` / `getCharAndSizeSlow`.
  `\N{...}` is handled by `tryReadNamedUCN`. **Add a
  `UnicodeOperatorCodePointFromSpelling` case per spelling form** — that
  unittest is the cheapest possible proof of the U11 equivalence.
- The token also gets `Token::HasUCN` set on the identifier path today; a
  user-operator token formed at 4614 will not have it unless you set it. Decide
  whether anything needs it (U16's `-ast-print` might) and say so.
- **No NFC anywhere** (U§8's "no normalization at lex time").

### For U05 — exclusion diagnostics

- **Emit from the U03 classification point**, i.e. right where the
  `if (LangOpts.UnicodeOperators && isUserOperatorChar(CodePoint))` fails. The
  natural shape is an `else if` on
  `getUserOperatorExclusion(CodePoint)` returning non-null, at
  `Lexer.cpp:4653`. Do it at **both** sites if U04 has landed (UTF-8 and UCN),
  or factor `LexUserOperator` first — coordinate with U04 rather than each
  adding a copy.
- **The rendering helper to reuse is `EscapeSingleCodepointForDiagnostic`**
  (`Lexer.cpp`, used by `CheckCodepointValidInIdentifier`; `err_character_not_allowed` itself is
  `DiagnosticLexKinds.td:135`). It is what
  produces the `'⊞' U+229E` shape in
  `error: unexpected character '⊞' U+229E`. Your messages must read next to
  that one; do not invent a second way to print a code point.
- **Off-flag wording you must not change**, still pinned:
  `error: unexpected character '⊞' U+229E` then
  `error: expected ';' after top level declarator` (spaced), and
  `error: character '⊞' U+229E not allowed in an identifier` then
  `error: use of undeclared identifier 'a⊞b'` (adjacent — note the *second*
  form, which U01/U02 did not have; it comes from the recovery path U03
  documented).
- The existing diagnostic carries `FixItHint::CreateRemoval`. For
  `ConfusableWith` you want `CreateReplacement` with
  `UserOperatorExclusion::Confusable` (the table already carries `-`, `/`, `*`,
  `|`, `:`, `.`, `<=`, `>=`, `=>`, `<=>`). **Do not alias** — the fix-it is a
  suggestion, the token must still fail to lex (U§5, and
  `LexerTest.UnicodeOperatorExcludedCodePointIsNotAToken` already asserts
  U+2212 mints no token with the flag on; extend that test rather than
  replacing it).
- **On the D137051 interaction your step asks about:** U02 already measured the
  answer in-tree. `MathematicalNotationProfileIDStartRanges` in
  `clang/lib/Lex/UnicodeCharSets.h` contains exactly ∂ U+2202, ∇ U+2207,
  ∞ U+221E plus ten Mathematical-Italic variants, and all 1,381 U1 members are
  outside it (DEV-U02). So with the math-identifier extension on, ∂ **is** a
  valid identifier and your `IdentifierProfile` message must not fire for it —
  which is exactly U10's composability claim holding. Check which `-std=` and
  which `LangOpts` turn that extension on before writing the test's RUN line;
  `isAllowedIDChar`'s `IsExtension` out-parameter and
  `diagnoseMathematicalNotationInIdentifier` (`Lexer.cpp:1897`) are where it is
  decided.

### For U06 — `DeclarationName` (the hard step)

U03's identity decision hands you a **`uint32_t` code point**, canonical across
spellings once U04 lands. Build `getCXXUserOperatorName(uint32_t)` on that, not
on an `IdentifierInfo *`: the acceptance criterion your step names ("two
spellings of the same code point must yield the same `DeclarationName`") is then
satisfied by construction, because the lexer boundary already canonicalized.
`Lexer::getUserOperatorCodePoint` is the single funnel; call it, do not re-decode.

Then, the two structural facts you would otherwise spend a day discovering.
Both are in `clang/include/clang/Basic/IdentifierTable.h:885–941` and
`clang/include/clang/AST/DeclarationName.h:148–228`:

- **The 3-bit inline `StoredNameKind` space is completely full.** `PtrMask = 7`
  and all eight values 0–7 are taken (`StoredIdentifier` 0, two ObjC selector
  kinds, `StoredCXXConstructorName` 3 … `StoredCXXOperatorName` 6,
  `StoredDeclarationNameExtra` 7). So a new kind **cannot** be an inline stored
  kind — it must go through `StoredDeclarationNameExtra` and a new
  `detail::DeclarationNameExtra::ExtraKind`, exactly the `CXXLiteralOperatorName`
  route your step tells you to follow. Your step's pitfall ("an added enumerator
  can overflow the available bits") is real but it is *this*, not a
  `NameKind` overflow: `NameKind` is `UncommonNameKindOffset(8) + ExtraKind` and
  grows freely.
- **`ExtraKind` has a load-bearing ordering constraint that no comment on the
  enum states.** The four enumerators are `CXXDeductionGuideName=0`,
  `CXXLiteralOperatorName=1`, `CXXUsingDirective=2`, `ObjCMultiArgSelector=3`,
  and the single field `ExtraKindOrNumArgs` stores `ObjCMultiArgSelector + N`
  for an N-argument ObjC selector — `getKind()` clamps anything `>= 3` back to
  `ObjCMultiArgSelector`. **Appending `CXXUserOperatorName` after
  `ObjCMultiArgSelector` will silently misclassify every multi-keyword ObjC
  selector.** Insert it at index 3, pushing `ObjCMultiArgSelector` to 4, and
  update the mirrored `NameKind` enumerators in `DeclarationName.h:208–228`.
  That renumbering is worth a `DEVIATIONS.md` row and a paper sentence: the cost
  of an open-ended operator name is not the pointer bits, it is that the
  closed enum is packed against ObjC's variable-length encoding.
- **Model the extra-data class on `detail::CXXLiteralOperatorIdName`**
  (`DeclarationName.h:112–133`): derive from
  `detail::DeclarationNameExtra` and `llvm::FoldingSetNode`, carry the payload
  plus a `void *FETokenInfo`, and give it
  `void Profile(llvm::FoldingSetNodeID &)` — for you, `ID.AddInteger(CodePoint)`
  rather than `AddPointer`. It **must** be `alignas(IdentifierInfoAlignment)`,
  and you must add it to the `static_assert` list at `DeclarationName.h:186–194`
  (six entries today) or the build will not tell you politely.
- Printing `operator⊞` needs the UTF-8 encoding of the code point:
  `llvm::convertCodePointToUTF8(CodePoint, Buf)` from
  `llvm/Support/ConvertUTF.h`, already included by `Lexer.cpp`.
- Renumbering `NameKind` changes values that `ASTWriter`/`ASTReader` write for
  `DeclarationName`; self-consistent within a build, but it means **U17 must
  re-check any hard-coded name-kind constant**, and it is one more reason to do
  U06 before U04/U05 rather than rebasing them over it.
- `tok::user_operator` renumbered `tok::` too (U03). If any switch you touch
  indexes a table by token kind, it is generated from the `.def` and is fine.

## Open risks / TODOs

- **The gate has a new environment-only failure mode.** Eight
  `DirectoryWatcherTest.*` cases fail whenever the machine's inotify watch
  budget is exhausted. Recorded as a fifth gate fact in `PLAN.md` with the
  measurement command and the `GTEST_FILTER` workaround. If a future agent sees
  `Failed: 8` and all eight are DirectoryWatcher with
  `inotify_add_watch()`, it is not a regression — but *check*, do not assume.
- **UCN spellings are inert and asymmetric until U04.** `⊞` still lexes as
  an ill-formed identifier character, and `getUserOperatorCodePoint` returns 0
  for such a token. Nothing depends on it yet; U06 must not be written against
  the assumption that the code point it is handed is already spelling-independent
  — it will be, after U04.
- **`Token::HasUCN` is not set on user-operator tokens** (they take no UCN path
  yet). U04 decides.
- **No `-verify` test exists for the on-flag path**, because there is no parse
  yet: with the flag on, `a ⊞ b` produces `expected ';' after top level
  declarator`, which is the parser's ignorance, not a designed diagnostic. U11
  is where that becomes a real expectation.
- **clang-format is untouched and unaffected** — it lexes raw with a `LangOpts`
  that never sets `UnicodeOperators`, so both new hooks are dead there. U18
  turns them on and will be the first consumer of the raw-mode path.
