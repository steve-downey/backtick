# Handoff — U15 precedence and associativity sweep

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `c25fdda912be`
  (parent `608ee6925c7a`, U14)
- **Date / agent:** 2026-08-04

**No production file was touched, and no grouping failed.** The third sweep
on this track to produce that result (U10, U14, U15), and this one is the
sweep the paper leans on hardest: every grouping in U§6's worked-example
table is now asserted, under every relevant flag combination, by a file that
required no compiler change to make pass.

The step file's scope rule — *"a failure here is a U11/U12 bug, file BLOCKED
against the owner"* — was never invoked, because U11 and U12 have no bug.
The one thing that did fail is a **backtick** defect that predates the whole
Unicode experiment and is unreachable from any pure-Unicode expression
(DEV-U17, below).

## The sentence U§12 can quote

Written the way it should be quoted, because the step file asked for it:

> The claim that one precedence level suffices for all user-introduced infix
> notation is not an aspiration in the prototype. `a ⊞ b` and ``a `f` b``
> enter the *same* level from two different spellings, and every mixed chain
> — ``a ⊞ b `f` c``, ``a `f` b ⊞ c``, ``a ⊞ b `f` c ⊞ d``,
> ``a `f` b ⊗ c `f` d``, ``⊖a ⊞ b `f` c`` — has the *same type* as its
> explicitly left-nested parenthesization. Not the same value: the same type,
> which is a statement about the parse and not about the arithmetic. EWG can
> decide "one level, left-associative, desugars to a call" once, and both
> features are covered by the decision, because in the implementation there is
> only one level to decide about.

The second half is worth quoting too, and is cheaper than it sounds:

> With `-fbacktick` off and on, and the mixed-chain section preprocessed out
> so both compilations see the same tokens, the printed ASTs of the whole
> precedence test are **byte-identical**. Neither flag perturbs the other's
> precedence, because neither flag *has* a precedence — the level exists in
> `OperatorPrecedence.h` whether either is on or not.

## What changed

**Production: nothing.** `git show --stat` is one test file.

| File | Change |
|------|--------|
| `clang/test/Parser/unicode-operator-precedence.cpp` | **new**, 467 lines, 9 RUN lines |

**In this repo:** `PLAN.md` (U15 ticked, Status row), `REPLAY.md` U15 row,
`DEVIATIONS.md` **DEV-U17**, this handoff.

### Two oracles, and why both

U12's forward notes were right that items 1–7 and 10 were largely already
asserted by value in `Parser/unicode-operator-infix.cpp` and
`Parser/unicode-operator-prefix.cpp`. **This file is therefore not primarily
a re-assertion; it is a re-presentation with a second oracle that the value
assertions cannot provide.**

- **Values** — the same four constants the other two Parser files use
  (`⊞` = 2a+b, `⊗` = 3a+b, backtick `f` = 5a+b, prefix `⊖` = 3a+1), plus a
  fifth (`⊚` = 7a+b) declared *after* every use of the others so that
  declaration order is visibly irrelevant. A wrong grouping is a wrong
  number, and the numbers are comparable across the three files.
- **Types** — the same operators overloaded on `Tag<N>` computing the same
  arithmetic in the type system, so a grouping claim is
  `__is_same(decltype(a ⊞ b ⊗ c), decltype((a ⊞ b) ⊗ c))`. This is the form
  the parent step asked for and it is strictly better than a number for the
  associativity claims: it says *the chain and its parenthesization are the
  same parse*, once per chain, without the reader doing arithmetic to
  believe it. `!__is_same(…, decltype(a ⊞ (b ⊞ c)))` is written next to it so
  the equality is not vacuous.

Both survive AST-printing churn. Four `-ast-dump` groups remain, for the
tree shapes a reader will picture.

### The nine RUN lines

```
-funicode-operators -fsyntax-only -verify                                    # unicode alone
-funicode-operators -fbacktick -DBACKTICK -fsyntax-only -verify              # both flags
-funicode-operators -DERRORS -fsyntax-only -verify=err
-funicode-operators -fbacktick -DBACKTICK -DERRORS -fsyntax-only -verify=err
-funicode-operators -ast-dump | FileCheck
-funicode-operators -fbacktick -DBACKTICK -DPRINTING -ast-dump | FileCheck --check-prefixes=CHECK,BT
-funicode-operators -ast-print > %t.uni.txt                                  # item 9, as a diff
-funicode-operators -fbacktick -ast-print > %t.both.txt
diff %t.uni.txt %t.both.txt
```

The last three are item 9 ("the same expressions parse identically with
`-fbacktick` off") stated as a *diff* rather than as two passing
compilations, following U14's byte-identical-IR construction. There is no
`-DOFF` line: U11 and U12 already pin the flag-off diagnostics exactly, and
adding a third copy would have made this file about lexing.

### The eleven sections

0 operators · 1 left-associativity (incl. the four-term single-operator
chain) · 2 **one level for all user infix** (both interleavings of
`⊞`/`⊗`, the four-term two-operator chains, and the declared-last `⊚`) ·
3 tighter than every built-in binary (`* / % + - << >> < > == & ^ | && ||`,
fourteen assertions) · 4 looser than unary, operands are cast-expressions ·
5 prefix tighter than any binary, **including the three-strength shape** ·
6 the levels below (`==`, `=` and its right-associativity, the *comma
operator*, `?:`) · 7 postfix and cast operands (`*p ⊞ *q`, `a.m ⊞ b.m`,
`ps->m`, `s1.mf()`, `g(2) ⊞ g(3)`, `arr[i]`, `(int)x`, `static_cast`,
`i++ ⊞ j++`) · 8 parenthesized regrouping · 9 **not a fold operator** ·
10 **mixed chains** · 11a printability control · 11 AST shapes.

## Verification evidence

**No build.** `ninja clang` was never run; `git status` before the commit was
one untracked test file. The gate log has **zero** `warning:` lines
(grepped, not inferred).

**Targeted lit:** `clang/test/Parser/unicode-operator-precedence.cpp` →
exit 0, all 9 RUN lines. (Run *before* the gate started; per U14's warning I
did not overlap them.)

**Full gate:** `ninja -C /home/sdowney/src/llvm/build-unicode check-clang`
→ `EXIT=1`, 8 failed:

```
Total Discovered Tests: 54167
  Passed: 48273   Unsupported: 5853   Expectedly Failed: 27   Skipped: 6
  Failed: 8
```

**All 8 are `DirectoryWatcherTest.*` and the artifact is back.**
`No space left on device : inotify_add_watch()`; the machine held **65,382 of
65,536** watches at gate time. U12's and U14's two-run unfiltered streak is
over — U12 was right that it was not proof the artifact had gone. Filtered
re-run per PLAN.md:

```
GTEST_FILTER='-DirectoryWatcherTest.*' ./bin/llvm-lit -s ./tools/clang/test
→ EXIT=0
Total Discovered Tests: 54159
  Passed: 48273   Unsupported: 5853   Expectedly Failed: 27   Skipped: 6
  Failed: 0
```

zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines. 180.0 s test time (166.2 s
filtered).

**The arithmetic, like for like.** Compare against U14's *filtered
equivalent*, not its unfiltered row: U14 was 54166 / 48280 unfiltered, i.e.
54158 / 48272 minus the 8 DirectoryWatcher cases. U15 filtered is
54159 / 48273 — exactly **+1 discovered / +1 passed**, the one new test. No
existing test changed behaviour.

## Deviations from the plan / design

**DEV-U17** (`DEVIATIONS.md`), and it is *not* a Unicode deviation. Full
detail is in the ledger row; the short version:

`BacktickInfixExpr::Inner` is documented in `clang/include/clang/AST/Expr.h:2242`
as *"Always a CallExpr"*, and it is not. `Sema::ActOnBacktickOperator`
(`SemaExpr.cpp:6764`) stores whatever `BuildCallExpr` returned, which for a
class-typed result is a `CXXBindTemporaryExpr` wrapping the call.
`StmtPrinter::VisitBacktickInfixExpr` (`StmtPrinter.cpp:1632`) does
`cast<CallExpr>(Node->getSubExpr())` and aborts. Minimal repro, **no Unicode
operator involved**:

```cpp
struct S { ~S(); };
S f(int, int);
void h() { (void)(1 `f` 2); }      // -fbacktick -ast-print  → assertion failure
```

and a trivially-destructible class reaches it through `decltype`, where
[expr.call]p11's deferred temporary produces the same node:

```cpp
struct S {}; S f(int,int); using T = decltype(1 `f` 2);   // -fbacktick -ast-dump → abort
```

**It reproduces on the untouched `/home/sdowney/src/llvm/build-backtick-trunk/bin/clang`.**
Pre-existing, backtick-owned, printing-only (`-fsyntax-only` and codegen are
fine). I did not patch it — it is out of this plan's scope and the ground
rules say touch only what the step names.

**The Unicode node does not have the defect**, and that contrast is the
paper-grade part. `UserOperatorExpr` stores its *operands*, so there is no
"the child is always a call" invariant to be wrong about; §11a of the new
test asserts that `decltype(Res{1} ⊢ Res{2} ⊢ Res{3})` and
`decltype(⊢⊢Res{1} ⊢ Res{2})` with a non-trivial `~Res()` dump and print
correctly in both fixities. The design lesson, stated in the ledger and worth
a sentence in U§8: **an expression node that *is* the operator survives Sema
re-wrapping its result; an expression node that *hides* a call does not.**

**Cost to this step:** section 10's eight `decltype`-of-a-backtick-chain
assertions are compiled by the `-verify` RUN lines and excluded from the
`-ast-dump` one by `-DPRINTING`. That macro exists for no other reason and
should be deleted when the backtick track fixes the printer.

**No step-file instruction was deviated from.** Two things done beyond it:
the `-ast-print` diff pair (item 9 as a diff), and §11a.

## Discoveries affecting later steps

- **Every grouping in U§6's worked-example table is now asserted**, all five
  lines, under `-funicode-operators` alone and under both flags. Three of the
  five were already in U11/U12; the `` a ⊞ b `f` c `` line is now asserted by
  value, by type, and by AST dump.
- **U12's warning about the three-strength shape is confirmed and is now
  pinned in the tree.** `⊖a ⊞ 2 * ⊖b` is `((⊖a) ⊞ 2) * (⊖b)` == 70, and the
  reading most people expect, `⊖a ⊞ (2 * ⊖b)`, is 22. Both are asserted,
  adjacent, with a comment saying which is which. **This is the single
  expression in the sweep whose grouping surprises readers**, and U§6 should
  gain it as a sixth worked example — it is the only one that shows prefix >
  user-infix > `*` at once.
- **Nothing else surprised me.** In particular the *comma operator* (as
  opposed to the argument comma U11 tests) and `x = y = 1 ⊞ 2` both behave
  exactly as the ordinary levels predict, and `i++ ⊞ j++` needs no
  parenthesisation.
- **`(... ⊞ N)` and `(N ⊞ ...)` are both `expected expression`**, the left
  fold erroring at the `...` and the right fold at its `...` — and
  `` (... `f` N) `` is **character-identical**. `(... + N)` folds normally, so
  this is about `prec::UserInfix`'s absence from `isFoldOperator` and nothing
  else. Now pinned in the `-DERRORS` blocks of both features. U§13 still owes
  a decision; the character-identical texts are an argument for deciding it
  **once for both features**, like the precedence level itself.
- **The `-ast-print` diff idiom generalises and is cheap.** Compiling the
  same TU with and without `-fbacktick` and diffing the printed AST is a
  one-line proof of flag-independence that no pair of separately-passing
  compilations gives you. U18 may want the same construct for
  clang-format's two flag states.
- **`-Wconstant-logical-operand` fires on `1 ⊞ 2 && 0`** even though the left
  operand is a call — it looks through to the constant. Use function
  parameters for `&&`/`||` grouping tests. (Cousin of U14's `-Wunsequenced`
  note: the default-on warnings see through the operator syntax to the call,
  which is itself evidence the desugaring is real.)
- **`Tag<N>` as a grouping oracle costs one line per operator** and is worth
  it: `template <int A, int B> constexpr Tag<2*A+B> operator⊞(Tag<A>, Tag<B>)`
  beside the `int` overload, no ambiguity, and both oracles usable in the
  same expression file.
- **Glyph budget.** U15 used only ⊞ ⊗ ⊖ ⊟ ⊚ ⊢, all previously used
  elsewhere. U10's free list is unchanged as U14 left it: **U+22A6, U+22A7,
  U+22B0, U+22B1, U+22B3–U+22BF, U+22C2–U+22C4** untouched anywhere.

## Forward notes for U04 — lexer: UCN and `\N{...}` spellings

Written after reading `steps/U04-lexer-ucn.md`. U04 is now the **oldest
unpaid debt in the plan and the only thing between the implementation and a
complete Phase A**; it also blocks U18, and it is the last unchecked step
that any other step is waiting on.

- **The step's real hazard is not in the lexer, it is in
  `Lexer::getUserOperatorCodePoint`** (`clang/lib/Lex/Lexer.cpp:506`, declared
  `Lexer.h:394`/`:399`). It takes the token's **raw spelling** and decodes it
  as one UTF-8 scalar, returning 0 if the spelling is empty, not valid UTF-8,
  or longer than one code point. A UCN-spelled token's spelling is the ten
  ASCII bytes `\U0000229E`, which will decode as `\` and then fail the
  `Begin != End` check → **0**. That function is the identity function for the
  whole feature: `DeclarationName` uses its result as the operator's identity
  (`DeclarationName.h:142`, `:567`, `:741`), and Parse (`ParseExpr.cpp`,
  `ParseExprCXX.cpp:2517`), Sema, mangling, AST printing and serialization
  (`ASTBitCodes.h:2212`) all route through it. **If U04 makes the lexer form a
  `tok::user_operator` from a UCN without teaching this function to decode
  UCN spellings, everything downstream silently gets code point 0** — the
  token will lex, `-dump-tokens` will look right, and `operator\U0000229E`
  will get a different `DeclarationName` from `operator⊞`. That is the exact
  failure the step's "confirm the equivalence holds at token level" gate is
  aimed at, but the gate as written (`-dump-tokens` identical) would **not**
  catch it. Add a declaration/use equivalence assertion — declare with one
  spelling, use with another, in the same TU — as a mandatory extra gate.
- **The two literal-glyph classification sites U03 left you** are
  `Lexer.cpp:4662` (`LexUnicodeIdentifierStart`'s caller: `isUserOperatorChar`
  → `FormTokenWithChars(…, tok::user_operator)`) and `Lexer.cpp:1945` (inside
  identifier lexing: a U1 code point *ends* the identifier, which is what makes
  `a⊞b` three tokens). The step's "one classification helper, two callers"
  instruction is already half-satisfied — the helper is
  `isUserOperatorChar(uint32_t)` in `clang/lib/Lex/UnicodeOperatorCharSets.h:154`,
  and it takes a code point, not bytes. **So convergence is achievable and
  U§8's assertion is likely to hold**; the UCN path only has to produce a
  `uint32_t` and ask the same question. Say so explicitly in your handoff
  either way — the step file calls this out as the fact U18 and the paper both
  need.
- **Eight test files will want a `-DUCN` addition** once you land, not seven:
  add `clang/test/Parser/unicode-operator-precedence.cpp` to U12's and U14's
  lists. For mine the cheapest useful addition is a *declaration/use* cross:
  declare `operator\U0000229E` and assert `1 ⊞ 2 == 4` still holds — that
  tests the identity property above, not just the token.
- **Do not add NFC processing** (U§8) and do not let the UCN path see
  `-fbacktick`: DEV-U07's `ShouldParseIf<cplusplus.KeyPath>` observation is
  still measured-but-unacted and is nominally owned by you.

## Forward notes for U05 — exclusion diagnostics with reasons

Written after reading `steps/U05-exclusion-diagnostics.md`.

- **Your table and accessors already exist and are unused.** U02 built
  `ExcludedOperatorChars` plus `getUserOperatorExclusion(uint32_t)` and
  `getExclusionReason(uint32_t)` in
  `clang/lib/Lex/UnicodeOperatorCharSets.h:161`/`:174`, returning
  `UserOperatorExclusionReason` (`None` / `ConfusableWith` /
  `IdentifierProfile` / `EmojiPresentation`) and, for `ConfusableWith`, a
  `const char *` ASCII replacement in the entry — so the step's "the ASCII
  token comes from the table, not from a switch" is already true of the data;
  you only have to route it. **Nothing calls `getExclusionReason` today**;
  grep confirms zero callers outside the header. That is your whole diff:
  three diagnostics in `DiagnosticLexKinds.td` and one call at each of the two
  U03 classification points named in the U04 note above (`Lexer.cpp:1945` and
  `Lexer.cpp:4662`).
- **Both sites currently fall through to *upstream's* recovery**, which is the
  behaviour you must preserve off-flag: `:4662` falls to
  `LexUnicodeIdentifierStart` and then `err_invalid_utf8`, `:1945` falls to
  `CheckCodepointValidInIdentifier`. Guard your new diagnostics with
  `LangOpts.UnicodeOperators` at both, exactly as `isUserOperatorChar` is
  guarded there now, and the "flag off == upstream" property stays true by
  inspection — which is how U03 deliberately arranged those two `if`s.
- **The D137051 interaction the step asks you to record is measurable before
  you write a line**, and U02 already half-measured it (DEV-U02: U1@17.0 ∩
  XID@18.0 = ∅ across all 1381 members). What is *not* measured is whether
  `∂ ∇ ∞` are accepted as identifiers in the test configuration — check
  `MathematicalNotationProfileIDStartRanges` in
  `clang/lib/Lex/UnicodeCharSets.h` and whether the `-fmath-identifiers`-ish
  path is on by default at `-std=c++23`. If it is on, your
  `IdentifierProfile` message must **not** fire for those three, and the test
  has to assert the non-firing. Either result is paper-grade; say which you
  got.
- **The non-aliasing assertion is the security property**, not a nicety —
  `int x = 1 − 2;` (U+2212) must fail, never quietly become subtraction. Write
  that one first; it is the assertion U§10 exists for.
- **Take U04 first if you can only take one.** U05's diagnostics are additive
  and nothing waits on them; U04 blocks U18 and is the last gap in the "all
  spellings behave identically" claim, which currently has **zero** evidence
  in the tree.

## Open risks / TODOs

- **DEV-U17 is a real bug in shipped-on-the-branch backtick code**, not a
  design question. It is printing-only and pre-existing, but it is a crash,
  and the backtick track should fix it before that diff goes anywhere. The
  `-DPRINTING` macro in the precedence test is a marker for it and should be
  deleted with the fix.
- **U§6 owes a sixth worked example** (`⊖a ⊞ 2 * ⊖b`) and **U§13 owes the
  fold decision**. Both are now evidenced in the tree and neither has been
  taken.
- **DEV-U15's default-argument corner** and **DEV-U16's evaluation-order
  split** remain measured-but-undecided, unchanged by U15.
- **DEV-U07** (`ShouldParseIf<cplusplus.KeyPath>` for both flags) remains
  measured-but-unacted; owner U04/U05.
- **The `-Wswitch` `BacktickInfixExprClass` gap remains open in two files**
  (`StaticAnalyzer/Core/ExprEngine.cpp`, `tools/libclang/CXCursor.cpp`),
  untouched and not to be fixed on this branch. U15 recompiled nothing, so it
  did not resurface.
- **`clang/lib/CIR/` is still untouched and uncompiled.**
- **The inotify/`DirectoryWatcherTest` artifact is back** after two clean
  runs. Budget for the filtered re-run; the check is in PLAN.md's gate facts.
- **Phase C and Phase D are now complete.** The only unchecked steps are U04,
  U05, U18 (blocked on U04), and the two Phase E replay steps. U19 can start
  as soon as U18 lands; its ledger input from U15 is written to be split
  mechanically (see the REPLAY row).
