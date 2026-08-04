# Handoff — U09 Itanium mangling, vendor-extended operator form

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `77f6a10f9bb4`
  (parent `07901af9f62d`, U08)
- **Date / agent:** 2026-08-04

The smallest step in Phase B by a wide margin — **2 production files,
+71/−11**, one of them a nine-line honest error — and the one that makes a
de facto ABI decision. U06 collapsed Itanium's three holes into one and U07
named the arity trap in writing; both were exactly right, and there were no
surprises in the mechanism. The surprises are all in the *evidence*: see
"The demangler result" below, which is stronger than U§9 claims.

## The mangling, stated

`clang/lib/AST/ItaniumMangle.cpp`, the `CXXUserOperatorName` arm of
`CXXNameMangler::mangleOperatorName(DeclarationName, unsigned)` (U06's site
27, formerly the `llvm_unreachable` at `:2662`):

```
<operator-name> ::= v <digit> <source-name>      # vendor extended operator
```

- **`<digit>`** is the operator's **declared arity** — 1 prefix, 2 infix —
  counting a member's implicit object parameter. Not the parameter count.
- **`<source-name>`** is derived from the operator's **Unicode code point**,
  never from a spelling, and emitted as an ordinary `<source-name>` (decimal
  byte length, then the identifier), following `li <source-name>` directly
  above it in the same switch.

### The source-name derivation rule (this is the ABI decision)

Stated in a comment beside the code, because the paper will quote it:

> `"op_u"` followed by the code point in **UPPERCASE hexadecimal**, with no
> `"U+"` prefix, zero-padded to a **minimum of four digits** and widened as
> required above the BMP (five digits from U+10000, six from U+100000).

So U+229E → `op_u229E`, U+2A0D → `op_u2A0D`, U+0F3A (were it ever admitted)
→ `op_u0F3A`, U+1D6C1 → `op_u1D6C1`. Binary U+229E therefore mangles as
**`v28op_u229E`** (`v`, arity `2`, length `8`, `op_u229E`).

Two properties worth having in the record:

- **Injectivity comes from hex, not from the padding.** Leading zeros are
  only ever added to reach four digits, and every code point above 0xFFFF is
  already at least five, so no two distinct code points can derive the same
  source-name.
- **Both the padding and the widening are unexercised by construction
  today.** Every U1 code point is in 0x2190–0x2BFF
  (`clang/lib/Lex/UnicodeOperatorCharSets.h:48`), so every derived name is
  exactly four hex digits. The `if (Hex.size() < 4)` branch is dead against
  the frozen set. It is there because the rule is an ABI statement, not a
  formatting convenience, and the set can grow. Said out loud here so nobody
  later reads coverage into it.

The implementation is six lines. `llvm::utohexstr(CodePoint, /*LowerCase=*/false)`
gives the unpadded uppercase hex — **do not** use its third `Width`
parameter, which forces *exactly* that many digits and would truncate an
astral code point to its low nibbles.

## The arity fix — U07's forward note, confirmed and fixed

`ItaniumMangle.cpp`, `mangleUnqualifiedName`. Before U09, the switch read

```cpp
  case DeclarationName::CXXOperatorName:
    if (ND && Arity == UnknownArity) { /* getNumParams() + implicit object */ }
    [[fallthrough]];
  case DeclarationName::CXXConversionFunctionName:
  case DeclarationName::CXXLiteralOperatorName:
  case DeclarationName::CXXUserOperatorName:      // <-- below the fallthrough
    mangleOperatorName(Name, Arity);
```

`CXXUserOperatorName` sat *below* the arity computation, so a user operator
arriving directly reached `mangleOperatorName` with `UnknownArity`. The fix
is one line moved: `case DeclarationName::CXXUserOperatorName:` now sits
**above** `case DeclarationName::CXXOperatorName:` and shares its block,
with a comment saying why. No duplication was needed — the computation is
identical, and it is identical because U08's operand-count formula and
upstream's are the same formula.

The member-infix case is the one that shows it and it is pinned:
`int T::operator⊞(T) const` — one declared parameter — mangles
`_ZNK1Tv28op_u229EES_`, arity **2**.

## MSVC: an honest error, not a scheme

`clang/lib/AST/MicrosoftMangle.cpp`, `MicrosoftCXXNameMangler::mangleUnqualifiedName`
(U06's site 28). The `llvm_unreachable` is replaced by the existing house
mechanism for "this ABI has no encoding for that":

```cpp
      Error(ND->getLocation(), "Unicode user-defined operator");
      break;
```

which routes through `diag::err_ms_mangle_unsupported` ("cannot mangle this
%0 yet"). Observed on `-triple x86_64-pc-windows-msvc`:

```
error: cannot mangle this Unicode user-defined operator yet
    2 | int operator⊞(S, S) { return 1; }
      |     ^
```

**Declarations are fine** — the name is representable, only the symbol is
not — so a Windows target accepts `int operator⊗(S, S);` and rejects the
first *definition*, at codegen. Note for the test author: **CodeGen stops
emitting after the first mangling error**, so only one `msvc-error` can be
pinned per RUN line.

No scheme was invented. Recorded as **DEV-U09**, whose point is that
"unexamined" undersells the finding: Itanium had a production waiting for
operators it did not anticipate and Microsoft has none, so a portable
version of this feature needs a Microsoft decision that Itanium does not.

## The demangler result — the claim being tested, and it passed twice

U§9 says "demangler-tolerated". The measurement is stronger than that.
**Both `llvm-cxxfilt` and GNU binutils `c++filt` 2.46 — a different
vendor's demangler, unmodified — render every form**, verbatim:

```
_Zv28op_u229E1SS_          -> operator op_u229E(S, S)
_Zv18op_u22961S            -> operator op_u2296(S)
_ZNK1Tv28op_u229EES_       -> T::operator op_u229E(T) const
_ZNK1Tv18op_u2296Ev        -> T::operator op_u2296() const
_ZNH1Ev28op_u2297ES_S_     -> E::operator op_u2297(this E, E)
_ZNH1Ev18op_u2298ES_       -> E::operator op_u2298(this E)
_Zv28op_u22A0IiEiT_S0_     -> int operator op_u22A0<int>(int, int)
_ZN1Nv28op_u229FE1SS0_     -> N::operator op_u229F(S, S)
_Zv28op_u21901SS_          -> operator op_u2190(S, S)
_Zv28op_u2BFF1SS_          -> operator op_u2BFF(S, S)
```

binutils `c++filt` 2.46 produces character-identical output for every one of
those it was given (checked on rows 1, 3, 7). Nothing crashed; nothing was
passed through unchanged. **Existing toolchains need no change to inspect
these symbols**, which is the strongest single thing the prototype can say
about the `v` production and exactly what an ABI reviewer asks first.

## The disjointness gate (U§9) — measured, and it holds

The D137051 math-identifier extension **is** in this build and needs no
flag: `int ∂(int x)` compiles under plain `-std=c++23`, warning
`mathematical notation character '∂' U+2202 in an identifier is a C++2d
extension [-Wc++2d-extensions]`. It mangles as an ordinary `<source-name>`:

```
@"_Z3\E2\88\82i"     (llvm-cxxfilt / c++filt: ∂(int))
```

Decimal byte length `3` then the UTF-8 bytes — against `_Zv28op_u229E1SS_`,
which is `v` + arity + a `<source-name>`. A source-name begins with a digit
and an operator-name with a letter; the productions cannot collide. U§9's
claim is confirmed, with no new machinery, and both symbols demangle.

**A tooling wrinkle worth the paper's footnote, and it cuts the design's
way.** `llvm-cxxfilt`'s *stdin* path splits its input on non-ASCII bytes, so
`echo '_Z3∂i' | llvm-cxxfilt` prints the string back unchanged, while
`llvm-cxxfilt '_Z3∂i'` demangles it. The operator symbols have no such
problem — they are pure ASCII by construction, because the code point went
into the name as hex. So the *operator* spelling is better behaved in
existing tooling than the extended-identifier-function spelling U10
declines, which is a small independent argument for U10 that U§7.1 does not
currently make.

## What changed

Two production files, **+71 / −11**, plus one new lit test.

| File | Change |
|------|--------|
| `clang/lib/AST/ItaniumMangle.cpp` | +62/−9: the `CXXUserOperatorName` arm in `mangleOperatorName` (mostly the derivation-rule comment), and the hoist of that case above the arity computation in `mangleUnqualifiedName` |
| `clang/lib/AST/MicrosoftMangle.cpp` | +9/−2: the `Error(...)` diagnostic |
| `clang/test/CodeGenCXX/unicode-operator-mangle.cpp` | new, 122 lines, 3 RUN lines |

**In this repo:** `PLAN.md` (U09 ticked, Status row), `REPLAY.md` U09 row
(`upstream replay`, flagged **ABI-open**), `DEVIATIONS.md` **DEV-U08** and
**DEV-U09**, this handoff.

## Verification evidence

**Build:** `ninja -C /home/sdowney/src/llvm/build-unicode clang llvm-cxxfilt`
→ `EXIT=0`, **17 edges**, ~2 min. **Zero `warning:` lines.** Note U08's
warning caveat did *not* apply here: U09 touches no header, so
`ExprEngine.cpp` was not recompiled and the pre-existing backtick-track
`-Wswitch` gap on `BacktickInfixExprClass` did not surface. The warning
budget on this branch is still not structurally zero — see U08's handoff —
it just happens to be zero for a step that touches only two `.cpp` files.

**New test:** `clang/test/CodeGenCXX/unicode-operator-mangle.cpp`, PASS on
first `llvm-lit` run, 0.10 s, three RUN lines:

1. `-std=c++23 -funicode-operators -triple x86_64-linux-gnu -emit-llvm | FileCheck`
2. the same **plus `-fbacktick`** — the U7 composability ground rule, one RUN line
3. `-triple x86_64-pc-windows-msvc -verify=msvc -DMSVC_UNSUPPORTED` — the
   MSVC diagnostic

Symbols pinned by `CHECK-DAG` (all of these are literal, and they are the
canonical set for the paper):

| Declaration | Symbol |
|---|---|
| `int operator⊞(S, S)` (free infix) | `_Zv28op_u229E1SS_` |
| `int operator⊖(S)` (free prefix) | `_Zv18op_u22961S` |
| `int T::operator⊞(T) const` (**member infix**, 1 param / arity 2) | `_ZNK1Tv28op_u229EES_` |
| `int T::operator⊖() const` (member prefix, 0 params / arity 1) | `_ZNK1Tv18op_u2296Ev` |
| `int E::operator⊗(this E, E)` (explicit object, C++23) | `_ZNH1Ev28op_u2297ES_S_` |
| `int E::operator⊘(this E)` | `_ZNH1Ev18op_u2298ES_` |
| `template int operator⊠<int>(int, int)` (**template instantiation**) | `_Zv28op_u22A0IiEiT_S0_` |
| `int N::operator⊟(S, S)` (namespace scope) | `_ZN1Nv28op_u229FE1SS0_` |
| `int operator←(S, S)` (U+2190, low end of U1) | `_Zv28op_u21901SS_` |
| `int operator⯿(S, S)` (U+2BFF, high end of U1) | `_Zv28op_u2BFF1SS_` |
| `int operator≨(S, S)` (U+2268) | `_Zv28op_u22681SS_` |
| `int ∂(int)` (D137051 math identifier — *not* an operator) | `_Z3\E2\88\82i` |

plus `CHECK:` lines that the explicit calls `operator⊞(s, s)` and
`operator⊖(s)` in `call_all()` emit calls to the same two symbols.

**Full gate:** `ninja -C $B check-clang` → 54141 discovered / 48247 passed /
27 XFAIL / 5853 unsupported / 6 skipped / **8 failed**, 165.3 s test time.

All 8 are the known `DirectoryWatcherTest.*` cases with
`No space left on device : inotify_add_watch()` — `PLAN.md`'s fifth gate
fact, measured again at gate time: **65,382 of 65,536**
`fs.inotify.max_user_watches` held machine-wide, identical to U06/U07/U08.
Filtered re-run:

```bash
ulimit -c 0
GTEST_FILTER='-DirectoryWatcherTest.*' $B/bin/llvm-lit -s $B/tools/clang/test
```
→ `EXIT=0`, **54133 discovered / 48247 passed / 0 failed** / 27 XFAIL /
5853 unsupported / 6 skipped; zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines.
171.2 s.

Arithmetic closes exactly: 54133 = U08's 54132 **+1**, 48247 = 48246 **+1**
— the one new lit test and nothing else. **No existing test changed
behavior**, which is the claim that matters for a step editing the two
manglers every C++ symbol in the tree goes through.

## Deviations from the plan / design

**DEV-U08** (`DEVIATIONS.md`) — U§9's mangling paragraph should carry the
derivation *rule* rather than the `op_u229E` example; "demangler-tolerated"
should become the two-demangler measurement; and the arity nuance below
should be a footnote, because it argues for the first-class
`<operator-name>` production U8 already prefers.

**DEV-U09** — U§9's "MSVC mangling unexamined" should say what is actually
true: the Itanium ABI reserves a production for unanticipated operators and
the Microsoft ABI does not, so a portable feature needs a Microsoft decision
that Itanium does not; the prototype declines to invent one and diagnoses.

One scope call a reviewer will ask about: **the test includes explicit-object
member operators and the U1 range endpoints, which the step file does not
name.** `this`-parameter members cost two lines and exercise the *other*
branch of the operand-count formula (declared parameters only, no implicit
object), which is the branch U08 got for free and nothing had yet mangled;
the range endpoints cost three lines and are the only evidence that the hex
derivation is not accidentally right for one glyph.

## Discoveries affecting later steps

- **The arity digit is stable where linking uses it, and follows the
  expression elsewhere — and that is upstream's shape, not ours.** In
  `<base-unresolved-name>` position, `mangleUnresolvedName` passes the
  *call's* argument count as `knownArity`. So
  `template <class T> auto k(T t) -> decltype(t.operator⊞(t));` instantiated
  at a class with a member infix `operator⊞` mangles
  `_Z1kI1REDTcldtfp_onv18op_u229Efp_EET_` — `on v1`, arity **1**, for an
  operator whose defining symbol is `v2`. Upstream does exactly the same for
  the built-ins: the identical program with `operator+` mangles `onps`, i.e.
  **unary** plus, for a binary member. It is inherited behavior, it is
  invisible to linkage, and no assert fires. Do not "fix" it in a later step
  without checking what upstream does with `operator+` first.
- **No `UnknownArity` path reaches the new arm.** The arm asserts
  `Arity == 1 || Arity == 2`, mirroring what `mangleOperatorName(OO_Plus, …)`
  does one function below. Probed deliberately and none of these trips it:
  `&operator⊞` as an initializer, `H<&operator⊞>` as a non-type template
  argument (mangles `_ZN1HIXadL_Zv28op_u229E1SS0_EEE1fEv`),
  `decltype(&operator⊖)` as a type template argument, a dependent
  `decltype(operator⊞(a, b))`, and `decltype(&T::operator⊞)`.
- **`llvm::utohexstr`'s third parameter is a trap**: `Width` forces
  *exactly* that many digits and truncates from the high end. The
  minimum-width padding is done by hand for that reason.
- **U04 is now the only thing between the prototype and the step file's
  "all three spellings produce the same symbol" gate** — see the forward
  note below.
- **The five U17 `DeclarationNameKey` holes are now trivially reachable**,
  as U06 predicted: this branch has a codegen test, so any agent who adds
  `-emit-pch` or `-fmodules` to a RUN line will hit them. Nothing in U09's
  test does.

## Forward notes for U10 — explicit-call sweep

U10 is a pure test gate and depends entirely on these symbols. Everything
below was measured while doing U09, so it is recipe, not speculation.

- **Your item 7 (linkage across two TUs) works, and here is a recipe that
  does not depend on a system linker.** Both were verified:

  1. *Preferred, hermetic:* compile each TU with
     `%clang_cc1 -std=c++23 -funicode-operators -triple x86_64-linux-gnu -emit-llvm-bc -o %t1.bc`,
     then `llvm-link %t1.bc %t2.bc -S -o - | FileCheck`. The declaring TU's
     `declare … @_Zv28op_u229E1SS_` becomes a `define` after the merge —
     that *is* the resolution proof, and it is one FileCheck line.
  2. *Real link, also verified:* `%clang -c` each TU then `%clang a.o b.o -o %t`
     links (the only failure observed was the expected "undefined reference
     to `main`" when neither TU had one). `llvm-nm` on the two objects shows
     `U _Zv28op_u229E1SS_` and `T _Zv28op_u229E1SS_`.

  `llvm-nm`, `llvm-link` and `llvm-cxxfilt` are **not** in
  `clang/test/lit.cfg.py`'s `tools` substitution list but are on `PATH` in
  the clang test config — existing tests call them bare (see
  `clang/test/InterfaceStubs/*.cpp`). Use them bare, not as `%llvm-nm`.
- **Your item 8 (UCN spellings) is still blocked on U04, which is still
  unchecked.** Verified today: `int operator⊞(int,int);` under
  `-funicode-operators` gives `error: character '⊞' U+229E not allowed in an
  identifier` — the UCN does not lex as an operator token. Check `PLAN.md`
  before writing those RUN lines; if U04 has landed by then, U09's mangling
  needs **no change at all** to make them agree, because the derivation
  reads the `DeclarationName`'s code point and no spelling ever reaches the
  mangler. The one-line proof to add at that point is a second declaration
  spelled `operator\N{SQUARED PLUS}` in
  `clang/test/CodeGenCXX/unicode-operator-mangle.cpp` and a `CHECK-NOT` for
  any second `op_u229E` symbol.
- **Do not re-pin symbols that `unicode-operator-mangle.cpp` already pins.**
  It owns free infix/prefix, member infix/prefix, explicit-object members,
  the template instantiation, namespace scope, the U1 endpoints and the
  `∂` disjointness case. Your CodeGen sibling should cover only what the
  *call* sweep needs — overload-set selection emitting the right one of two
  symbols, an ADL-found callee, a dependent call — and should reference this
  file rather than duplicating it.
- **Item 6 (address-taking) is verified working today**, in all three forms
  the step names: `int (*p)(S, S) = &operator⊞;` initializes to
  `@_Zv28op_u229E1SS_`; `H<&operator⊞>` as a non-type template argument
  mangles `_ZN1HIXadL_Zv28op_u229E1SS0_EEE1vE`; and
  `decltype(&operator⊖)` works as a type template argument. If any of those
  fails for you, it is a regression, not a discovery.
- **Item 3's member call `x.operator⊞(y)` and item 5's dependent call both
  work**, including in `decltype`. See the arity note in Discoveries for the
  one cosmetic oddity in the dependent-member case — it is upstream's, it
  affects no symbol you can link against, and it is **not** a U10 finding.
- **Item 4's ADL answer is expected to be yes** and U08's handoff explains
  why (the `setNonMemberOperator` fix). U09 adds nothing to that; the note
  U08 left you — "explicit call works is *not* evidence that `x ⊞ y` will,
  because the operator path uses `IDNS_NonMemberOperator` and the ADL path
  `IDNS_Ordinary`" — is still the sentence U13 needs from you.
- **If a case fails, the step file is right that you should not patch it
  here.** The one thing that would be U09's to fix is a *symbol* that is
  wrong or unstable; anything about lookup, overloads or diagnostics belongs
  to U07/U08.
- Glyphs used by `unicode-operator-mangle.cpp`, added to the running list:
  ⊞ U+229E, ⊖ U+2296, ⊗ U+2297, ⊘ U+2298, ⊠ U+22A0, ⊟ U+229F, ← U+2190,
  ⯿ U+2BFF, ≨ U+2268. Still free inside `{0x2266, 0x22C4}`: ⊣ U+22A3,
  ⊤ U+22A4, ⊥ U+22A5, ⊨ U+22A8, ⋀–⋃ U+22C0+.

## Open risks / TODOs

- **The ABI is decided by a prototype step and nothing revisits it.** The
  `op_u<HEX>` derivation and the `v <arity>` encoding are U09's, they are
  now in the REPLAY ledger flagged **ABI-open**, and U19 must surface that
  row as the one item that is not merely a replay question. U8 stays
  `Proposed — open (ABI)`; the real answer is a first-class
  `<operator-name>` keyed by code point, which needs the Itanium ABI group.
- **MSVC is unimplemented on purpose** and a Windows target therefore cannot
  compile a definition. That is deliberate (DEV-U09), but it means the
  feature is currently Itanium-only in a way the design doc's "unexamined"
  does not convey.
- **The astral-plane and zero-padding halves of the derivation rule are
  untested by construction** — no U1 code point is above 0xFFFF. If U1 ever
  grows past the BMP, that branch is the first thing to write a test for.
- **The `-Wswitch` `BacktickInfixExprClass` gap** in
  `StaticAnalyzer/Core/ExprEngine.cpp:1688` is still there; U09 simply did
  not rebuild that file. Unchanged from U08's note, still a backtick-track
  issue, still not to be fixed here.
- **`SemaCodeComplete.cpp:1061`** remains the one-line completion-priority
  grouping U06, U07 and U08 all left alone. Still flagged for U16.
