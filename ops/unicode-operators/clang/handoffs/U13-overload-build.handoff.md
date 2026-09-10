# Handoff — U13 Sema: candidate assembly, ADL, no built-in candidates

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `27dc597998dc`
  (parent `02b0b96cf2e5`, U11)
- **Date / agent:** 2026-08-04

**3 production files, +207/−40**, plus one new test. The member half of
U§7 "Using" was the whole of the work, exactly as U11's handoff predicted;
the non-member half — including full ADL — needed no code and got none.

## The three answers the step asked for

### 1. `CreateOverloadedBinOp` could **not** be reused, and the un-reusable part is *one six-line loop*

`Sema::CreateOverloadedUserOp(Scope *, SourceLocation OpLoc, uint32_t CodePoint,
MultiExprArg Operands)` is a **sibling** of `CreateOverloadedBinOp` /
`CreateOverloadedUnaryOp`, declared in `Sema.h` immediately after
`BuildSynthesizedThreeWayComparison` and defined in `SemaOverload.cpp`
immediately before `CreateOverloadedBinOp`. Same shape as U08's
`CheckUserOperatorDeclaration` — two for two, and that is the pattern to
expect for anything else `OverloadedOperatorKind` touches.

What forced the fork, helper by helper (this is the DEV-U12 measurement):

| Helper | Keyed on | Reused? |
|---|---|---|
| `AddNonMemberOperatorCandidates(Fns, Args, CS)` | an `UnresolvedSetImpl` | **yes, verbatim** |
| `AddArgumentDependentLookupCandidates(Name, …)` | a `DeclarationName` | **yes, verbatim** |
| `AddMethodCandidate(Pair, ObjTy, ObjClass, Args, CS)` | a `DeclAccessPair` | **yes, verbatim** |
| `BestViableFunction`, `NoteCandidates`, `err_ovl_*_call` | nothing operator-specific | **yes** |
| `BuildCallExpr`, `BuildMemberReferenceExpr` | nothing operator-specific | **yes** |
| `AddMemberOperatorCandidates(Op, …)` | **`OverloadedOperatorKind`** — its *first line* is `getCXXOperatorName(Op)` | **no.** Its remaining six lines are copied verbatim into a loop over the qualified-lookup result |
| `AddBuiltinOperatorCandidates(Op, …)` | `OverloadedOperatorKind` | **not wanted** (U6) |
| `CXXOperatorCallExpr::Create(…, Op, …)` | stores the kind **in the node** | **no** — see finding 3 below, which is the important one |

So the honest sentence for the paper: the operator machinery is reusable
wherever it is keyed on a *name* and unreachable wherever it is keyed on a
*kind*, and for candidate assembly that boundary falls at exactly one
function's first line.

`OverloadCandidateSet` is constructed with `CSK_Operator` and a **default**
`OperatorRewriteInfo`, whose `OriginalOperator` is `OO_None`; that makes
`isAcceptableCandidate()` return true unconditionally and
`shouldAddReversed()` false, so the C++20 rewritten/reversed machinery is
inert without being special-cased. That was luck worth knowing about.

### 2. How the §17.4 equivalence was proved

`clang/test/SemaCXX/unicode-operator-adl.cpp` mirrors U10's
`SemaCXX/unicode-operator-call.cpp` §4 line for line, as U10 promised it
would. The equivalence is asserted as **type identity over a tag-returning
overload set**, not as "both forms compile":

```cpp
template <int N> struct Tag { static constexpr int value = N; };
// … constexpr Tag<41> operator⊘(A, A);  constexpr Tag<43> operator⊘(E, E);
static_assert((Adl::A{} ⊘ Adl::A{}).value == 41);
static_assert(__is_same(decltype(Adl::A{} ⊘ Adl::A{}),
                        decltype(operator⊘(Adl::A{}, Adl::A{}))));
```

Every candidate in a set returns a distinct type, so "selects the same
overload" is checkable rather than inferable. Done for: pure ADL, an
enumeration's namespace, a pointer's pointee namespace, a **hidden
friend**, a class template argument's namespace, ADL **augmenting** a
visible non-viable ordinary candidate, a using-declaration, and the
dependent/instantiation-time case. The member form gets the same treatment
against its own desugaring: `__is_same(decltype(Mem{1} ⊕ Mem{2}),
decltype(Mem{1}.operator⊕(Mem{2})))` plus value equality.

Two negative halves of the equivalence are pinned too, because they are
where "the same as a call" stops being true and *should*: ADL must **not**
reach an unrelated namespace for fundamental operands, and the explicit
call `operator⊡(d, d)` must **not** find `D`'s member while `d ⊡ d` does.
That asymmetry is [over.match.oper] versus [over.match.call] and is
correct; U10 measured the call half, U13 measures the operator half.

`-ast-dump` evidence is there too (RUN line 3) but it is the weaker
witness: it shows `CallExpr` → `DeclRefExpr 'operator⊞'` for the
non-member form and `CXXMemberCallExpr` → `MemberExpr … .operator⊕` for
the member form — i.e. U§7's two desugarings literally.

### 3. No built-in candidates: measured, and implemented by *not writing a line*

Nothing calls `AddBuiltinOperatorCandidates`, and the source says so in
capitals at the point where the call would go. Measured, all three shapes:

```
a ⊠ b   (nothing named operator⊠ anywhere)  → use of undeclared 'operator⊠'
a ⊟ b   (only operator⊟(Base, Base) visible) → no matching function for call to 'operator⊟'
                                                + candidate not viable: no known conversion from 'int' to 'Base'
p ⊞ n   (int*, long; operator⊞(int,int) visible) → no matching function for call to 'operator⊞'
```

Never an arithmetic fallback, never pointer arithmetic, and never a lexing
or parsing error (U3). `static_assert(5 ⊞ 7 == 12)` — U§1's motivating
line — evaluates.

## What `CreateOverloadedUserOp` actually does

1. Unqualified operator lookup (`LookupOperatorName` →
   `IDNS_NonMemberOperator`) into `UnresolvedSet<8> Fns`.
2. A lambda `BuildNonMemberForm()` that builds the
   `UnresolvedLookupExpr` (`PerformADL=true`) and calls `BuildCallExpr` —
   i.e. **U11's stub, kept as a helper**, because it is exactly the
   non-member half and it is correct.
3. **Type-dependent operand → `BuildNonMemberForm()` and stop deciding.**
   ADL then happens at instantiation from the instantiation context, by
   inheritance.
4. `checkPlaceholderForOverload` on each operand (static helper at
   `SemaOverload.cpp:1189`; usable because the new function lives in that
   file).
5. Member candidates: `LookupQualifiedName` of the same
   `getCXXUserOperatorName(CodePoint)` into `T1`'s `CXXRecordDecl`, guarded
   by `isCompleteType(OpLoc, T1) || T1RD->isBeingDefined()` — upstream's
   guard, copied.
6. **If the member set is empty → `BuildNonMemberForm()`.** The union is
   then exactly the non-member set, so the ordinary call path computes it,
   and every behavior U11 measured (including the
   `use of undeclared 'operator⊠'` text, which comes from
   `BuildRecoveryCallExpr` → `DiagnoseEmptyLookup`) is preserved
   *identically* rather than re-derived. This is why U11's test file needed
   no edits at all.
7. Otherwise one unified `OverloadCandidateSet`: non-member + member + ADL,
   no built-ins, `BestViableFunction`.
8. On success: a non-member winner goes back through
   `BuildNonMemberForm()` (a fortiori it also wins the non-member set on
   its own); a `CXXMethodDecl` winner is built as
   `BuildMemberReferenceExpr(...)` + `BuildCallExpr(...)` — literally
   `x.operator⊕(y)` — so object conversion, access checking, argument
   initialization, temporaries, `CheckForImmediateInvocation` and constexpr
   evaluation are all inherited. The member set is re-resolved by that
   path; it reaches the same function because the best viable candidate of
   the union is a fortiori the best of the member subset.
9. On failure: `err_ovl_no_viable_function_in_call`,
   `err_ovl_ambiguous_call`, `DiagnoseUseOfDeletedFunction` — all streamed
   the `DeclarationName`, so all print `'operator⊕'`.

**Deliberate design note for whoever edits this:** steps 6 and 8 mean the
*expression building* is always done by an existing path and never by new
code. Only candidate assembly is new. Do not "unify" this by hand-rolling
the member call — that would re-implement `CheckMemberOperatorAccess`,
`MaybeBindToTemporary` and friends for no gain.

## Verification evidence

**Build:** `ninja -C /home/sdowney/src/llvm/build-unicode clang` → `EXIT=0`,
**zero** `warning:` lines. The pre-existing backtick-track `-Wswitch` gap on
`BacktickInfixExprClass` (`StaticAnalyzer/Core/ExprEngine.cpp:1688`) did not
resurface. One build cycle was lost to `MultiExprArg` again — see
Discoveries.

**Targeted lit:** `clang/test/{SemaCXX,Parser,CodeGenCXX,AST,Lexer}` plus
both driver tests — **3802 discovered, 3746 passed, 49 unsupported,
7 XFAIL, 0 failed**, 9.4 s. That set contains every backtick test and every
U01–U11 test.

**Full gate:** `ninja -C $B check-clang` → 54145 discovered / 48251 passed /
27 XFAIL / 5853 unsupported / 6 skipped / **8 failed**, 207.8 s.

All 8 are the known `DirectoryWatcherTest.*` inotify cases; measured at
gate time, **65,382 of 65,536** `fs.inotify.max_user_watches` held
machine-wide — the identical figure U06–U11 all recorded. Filtered re-run:

```bash
ulimit -c 0
GTEST_FILTER='-DirectoryWatcherTest.*' $B/bin/llvm-lit -s $B/tools/clang/test
```
→ `EXIT=0`, **54137 discovered / 48251 passed / 0 failed** / 27 XFAIL /
5853 unsupported / 6 skipped; zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines.
177.3 s.

Arithmetic closes exactly: 54137 = U11's 54136 **+1**, 48251 = 48250 **+1**
— the one new lit test and nothing else. **No existing test changed
behavior**, which for a step that rewrites an expression's Sema action is
the claim that matters.

## Deviations from the plan / design

**DEV-U12** (`DEVIATIONS.md`), three parts; part 3 is the one for the
paper and is repeated under Open risks because it is also U16's brief.

The step file's methodology instruction was **stale and was not followed**,
exactly as U11's handoff warned: "write the pure-ADL test first and watch
it fail" — it does not fail, and never did. U11's narrowing **reproduced
exactly**: before any U13 code, `Mem{1} ⊞ Mem{2}` gave
`use of undeclared 'operator⊞'` while every ADL shape in U11's table
already worked. The member case was written first instead, and the ADL
cases were watched for regression while the implementation changed — which
is the DEV-G05 failure mode and the reason those cases are in the new file
rather than left to U11's.

Step file item 4 ("prefix form goes through the unary analogue") is
satisfied by construction rather than by a second function: one action, one
candidate-assembly function, arity is `Operands.size()`. It is **untested
end to end**, because U12 has not landed and `tok::user_operator` appears
in `ParseExpr.cpp` only in `ParseRHSOfBinaryExpression`. See Open risks.

## Discoveries affecting later steps

- **`MultiExprArg` is `MutableArrayRef<Expr *>` and `ArrayRef` will not
  convert *back* either.** U11 lost a cycle passing `ArrayRef` where
  `MultiExprArg` was wanted; U13 lost one passing `ArrayRef<Expr *> Args`
  to `DiagnoseUseOfDeletedFunction`, which takes `MultiExprArg`.
  `MutableArrayRef::drop_front()` returns `MutableArrayRef` and *is* fine.
  Third time will also be `MultiExprArg`; just pass `Operands`.
- **The requires-expression note prints an infix use as an explicit call:**
  `because 'operator⋁(a, b)' would be invalid: use of undeclared 'operator⋁'`
  for source that reads `a ⋁ b`. That is a `StmtPrinter` fidelity bug and
  it is **U16's**, not a Sema bug. It is the first place the missing AST
  node is visible to a *user* rather than to an implementer.
- **The `use of undeclared 'operator⊠'` text survives** because the
  no-member path still goes through `BuildCallExpr` →
  `FinishOverloadedCallExpr` → `BuildRecoveryCallExpr` →
  `DiagnoseEmptyLookup`, which U07 already taught the new name kind. If a
  later step makes the unified path unconditional, that text becomes
  `no matching function for call to 'operator⊠'` and U11's test file will
  need one edit.
- **Diagnostic texts U14/U15 will want, all measured:**
  `use of undeclared 'operator⊠'` /
  `no matching function for call to 'operator⊟'` +
  `candidate function not viable: no known conversion from 'int' to 'Base' for 1st argument` /
  `call to 'operator⊢' is ambiguous` + two `candidate function` notes /
  `'operator⊪' is a private member of 'PrivateOp'` +
  `implicitly declared private here` /
  `call to deleted function 'operator⊩'` +
  `candidate function has been explicitly deleted`.
- **The caret for a member failure underlines the whole expression**
  (`~~^~~` over `m ⊣ b`) while an unqualified-lookup failure carets only
  the operator token. That difference comes from the two different builders
  and is cosmetic; U16's node can make it uniform.
- **`-ast-dump` on a use with errors exits non-zero**, so an ast-dump RUN
  line on a file that also has `expected-error` cases needs
  `// RUN: not %clang_cc1 …  | FileCheck %s`. U11's file avoided this by
  putting its error cases behind `-DERRORS`; U13's uses `not`.
- **Source-range artifact unchanged**: the non-member `CallExpr` still
  begins at the operator, after its own first child (U11's Discovery). The
  member `CXXMemberCallExpr` does *not* have it — it begins at the object
  expression, because `BuildMemberReferenceExpr` puts the base first. So
  the two forms currently disagree about their own extent. U16.

## Forward notes for U14 — semantics sweep

Written after reading `steps/U14-semantics-tests.md`.

- **Read this first: U14's item 4 cannot pass today, and the owner is not
  U13.** It asks for "class-template members, dependent operands … and a
  concept constrained on `a ⊞ b` being well-formed". Dependent operands
  with a **member** operator do not resolve (DEV-U12 part 3) and the
  concept is unsatisfied. This is not a Sema bug U14 should file BLOCKED
  against U13 — it is the missing AST node, and it is **U16's**. The two
  failing shapes are already pinned in
  `SemaCXX/unicode-operator-adl.cpp` §5 under `FIXME(U16)` with
  `expected-error` directives, so U14 does not need to rediscover them.
  **Recommendation: run U16 before U14.** U14's dependency line says
  U13+U12, and on the evidence it should say U13+U12+U16. Whoever
  sequences the plan should decide that explicitly rather than letting U14
  discover it.
- Everything else in U14's list works today and is *not* covered by U13's
  file, which deliberately stops at candidate assembly. Specifically
  untouched and yours: `noexcept(a ⊞ b)` (item 5), evaluation order (item
  6), returned references used as lvalues, explicit-conversion operands,
  `consteval`, a throwing operator, and CodeGen siblings.
- Item 7 (deleted operator) **is** covered — `SemaCXX/unicode-operator-adl.cpp`
  §4b has the member form. Add the non-member form; it goes through
  `BuildCallExpr`, so the text is `call to deleted function 'operator…'`
  from the ordinary path.
- Item 3's `static_assert(5 ⊞ 7 == 12)` is already asserted in §1 of the
  U13 file. Do not duplicate it; extend it (`consteval`, a `constexpr`
  member, a constant-evaluated ADL case).
- Item 8 (prefix equivalents) needs U12. If U12 has not landed when you
  run, scope to the infix cases and say so — do not implement U12's
  parser work.
- **The tag-returning-overload-set idiom is the one to reuse.**
  `template <int N> struct Tag { static constexpr int value = N; };` plus
  one distinct `N` per candidate makes "which overload ran" a compile-time
  assertion. It reads far better in a diff than an `-ast-dump` FileCheck
  and it is what U13 and (per its step file) U15 both use.
- **Glyph budget.** U13's file consumes ⊞ ⊠ ⊟ ⊘ ⊚ ⊛ ⊜ ⊝ ⊨ ⊧ ⊡ ⊕ ⊗ ⊤ ⊥ ⊣ ⊢
  ⊪ ⊩ ⋀ — but that is *within one file*; a different test file may reuse
  any of them freely. Nothing is globally reserved.

## Forward notes for U15 — precedence/associativity sweep

Written after reading `steps/U15-precedence-tests.md`.

- **Items 1–4, 6, 7 and 10 are already asserted** in
  `clang/test/Parser/unicode-operator-infix.cpp` (U11), by
  `static_assert` over deliberately non-commutative, non-associative
  operators (`2*a + b` and `3*a + b`), with the value the *other* grouping
  would produce written in a comment on every line. Read that file before
  writing anything; your job is the parts it does not cover, not a
  re-run. What it does not cover: item 5 (prefix — needs U12), and the
  systematic postfix/cast-operand matrix of item 7 beyond `(int)1.9 ⊞ (int)2.9`.
- **Item 8's mixed chains are also already there**, under `#ifdef BACKTICK`:
  `1 ⊞ 2 \`f\` 3 == 23`, `1 \`f\` 2 ⊞ 3 == 17`, `1 ⊞ 2 \`f\` 3 ⊞ 4 == 50`,
  `2 * 3 \`f\` 4 ⊞ 5 == 86`. If U15 restates them in its own file, keep
  U11's structural rule: with `--check-prefixes=CHECK,BT` the `BT-`
  directives must be **physically last in the file**, because FileCheck
  merges prefixes in *file* order and matches in *dump* order.
- **A grouping surprise you will meet and should not treat as a bug:**
  `(... ⊞ N)` is **not** a fold expression — `Parser::isFoldOperator`
  excludes `prec::UserInfix`, inherited from backtick. Measured as
  `error: expected expression` at the `...`. DEV-U11 part 3; it is a U§13
  open question, not a defect.
- **U13 changed no parsing and no precedence.** Nothing in this step's
  subject matter moved. If a grouping in your file resolves to the wrong
  *overload* rather than the wrong *tree*, that is U13's; if it builds the
  wrong tree, that is U11's or U12's.
- Item 9 (backtick off) is free: U11's RUN lines 1, 3 and 5 already have
  `-fbacktick` off and carry every non-backtick assertion.

## Forward notes for U16 — AST node and `-ast-print` fidelity

Written after reading `steps/U16-ast-print.md`. **Read this section before
designing anything; U13 answered your step's item 2 in advance.**

- **Your step's item 2 asks whether `CXXOperatorCallExpr` can be reused.
  The answer is no, and the reason is worth a paragraph in the paper.** It
  stores `OverloadedOperatorKind` in `CXXOperatorCallExprBits.OperatorKind`
  and every consumer switches on `getOperator()` —
  `TreeTransform::TransformCXXOperatorCallExpr`,
  `RebuildCXXOperatorCallExpr`, `StmtPrinter`, `getSourceRange`, CodeGen's
  `EmitCXXOperatorMemberCallExpr` dispatch. `OO_None` is a valid *value*
  and would silently reach `default:`/`llvm_unreachable` arms. This is the
  same closure DEV-U04 found in `DeclarationName`, one layer down.
- **The node is not cosmetic. It is load-bearing for two-phase lookup, and
  that is the finding of DEV-U12 part 3.** Today a dependent user-operator
  use is an ordinary `CallExpr` with an unresolved callee;
  `TreeTransform::TransformCallExpr` → `RebuildCallExpr` → `ActOnCallExpr`
  rebuilds it as a **call**, so at instantiation it assembles
  [over.match.call] candidates and **member user operators are lost**.
  ADL survives (property of the call); members do not (property of the
  operator syntax). Two shapes are pinned with `FIXME(U16)` in
  `clang/test/SemaCXX/unicode-operator-adl.cpp` §5:
  `dependent_member<Mem>` and `concept MemberCombinable`. **When your node
  lands, both must flip**; delete the `expected-error`/`expected-note`
  directives and assert `== 12` and `MemberCombinable<Mem>`.
- **Therefore your node must round-trip through `TreeTransform` by calling
  back into candidate assembly**, not by transforming its children and
  rebuilding a call. The entry point is
  `Sema::CreateOverloadedUserOp(Scope *S, SourceLocation OpLoc, uint32_t
  CodePoint, MultiExprArg Operands)` (declared in `Sema.h` after
  `BuildSynthesizedThreeWayComparison`, defined in `SemaOverload.cpp`
  before `CreateOverloadedBinOp`). It already handles the dependent case
  itself, takes 1 or 2 operands, and is the *only* thing your
  `RebuildUserOperatorExpr` needs to call. `Sema::ActOnUserOperator` is now
  a five-line forwarder to it; the parser action and the rebuild path can
  share it.
- **A transparent wrapper around the built call — the backtick
  `BacktickInfixExpr` pattern your step file points at — is not sufficient
  on its own.** A wrapper whose `TreeTransform` transforms the inner
  `CallExpr` reproduces today's bug exactly. The node must carry the code
  point **and the original operand expressions** so the rebuild can go
  through `CreateOverloadedUserOp` with them. That is the one design
  constraint U13 imposes on you, and it is worth recording against the
  backtick precedent, which did not need it (backtick's slot is an
  ordinary expression, so its wrapper really can be transparent).
- **Two source-range facts to fix while you are there.** The non-member
  form's `CallExpr` begins at the *operator*, after its own first child
  (U11's Discovery; `BuildCallExpr` takes the range from the synthesized
  callee). The member form's `CXXMemberCallExpr` begins at the *object*.
  So the two desugarings of the same syntax currently disagree about their
  own extent, and a diagnostic that highlights the whole expression gets it
  wrong for one of them. Your node fixes both by construction.
- **The first user-visible symptom of the missing node**, and a good
  regression test for the printer: a `requires`-expression note prints
  `because 'operator⋁(a, b)' would be invalid` for source that reads
  `a ⋁ b`. `SemaCXX/unicode-operator-adl.cpp` and
  `SemaCXX/unicode-operator-call.cpp` both contain such notes; when the
  printer improves, those `expected-note` texts change and must be updated
  together.
- **What the desugaring is, so the printer knows what it is un-printing:**
  non-member → `CallExpr` whose callee is a `DeclRefExpr` to
  `'operator⊞'`; member → `CXXMemberCallExpr` whose callee is a
  `MemberExpr` `.operator⊕`. Both are dumped in §7 of the U13 test file
  with `CHECK` lines you can reuse.
- **`SemaCodeComplete.cpp:1061`** is still the one-line completion-priority
  grouping every step since U06 has left alone. Still yours.

## Open risks / TODOs

- **DEV-U12 part 3 — dependent member user operators — is the largest open
  hole in the feature and it is U16's.** Until it closes, `x ⊞ y` inside a
  template is *less* capable than outside one, and `requires { a ⊞ b; }` is
  wrong for member operators. **U14's item 4 will hit it**; see U14's
  forward notes and consider running U16 first.
- **U12 has not landed, so the prefix form is untested end to end.**
  `CreateOverloadedUserOp` accepts 1 operand and asserts so, and the
  member-candidate path uses `Args.slice(1)` (empty) and
  `Operands.drop_front()` (empty) correctly by construction — but no
  source can reach it: `tok::user_operator` appears in `ParseExpr.cpp` only
  in `ParseRHSOfBinaryExpression`. The **first thing U12 should do after
  its parser arm works** is a prefix member operator (`struct P { int
  operator⊖() const; }; ⊖P{};`), which exercises the one-operand path
  through step 5/8 above.
- **U08's default-argument corner is still untested, and is still not
  reachable.** `int operator⊟(int a, int b = 1)` is a two-operand
  declaration that is also one-argument-viable, so `⊟x` would find it
  through the default argument. U13 deliberately did **not** filter
  candidates by declared arity: U11's stub selected nothing, and adding
  untestable selection logic ahead of U12 would be worse than leaving the
  decision visible. It remains a decision someone must make on purpose —
  U08 recommended "select the form by declared arity, not by call
  viability" — and **U12 is the first step that can write the test.**
- **U04 is still unchecked** with all of Phase B and two Phase C steps
  done. U13 adds a **third** file that will need the UCN/`\N{...}` case
  when U04 lands. The "all three spellings behave identically" claim still
  has no evidence at all, and it is now the oldest unpaid debt in the plan.
- **DEV-U07** (the `ShouldParseIf<cplusplus.KeyPath>` C-mode question,
  paired with `-fbacktick`) is still measured-but-unacted; owner U04/U05.
- The `-Wswitch` `BacktickInfixExprClass` gap in
  `StaticAnalyzer/Core/ExprEngine.cpp:1688` is unchanged and still not to
  be fixed on this branch. U13 did not resurface it (no widely-included
  header changed except `Sema.h`, which the static analyzer does not pull
  in through that TU). **U16 will resurface it the moment it adds a new
  `StmtClass`** — that switch will then be missing *two* cases, and only
  the new one is U16's to fix.
