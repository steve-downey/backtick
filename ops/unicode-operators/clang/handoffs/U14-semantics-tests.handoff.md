# Handoff — U14 semantics sweep

- **Status:** DONE (gate passed)
- **Branch / commit:** `unicode-operators-experiment` @ `608ee6925c7a`
  (parent `8a84ef99a79c`, U12)
- **Date / agent:** 2026-08-04

**No production file was touched, and no case needed one.** All nine areas
of the step's inventory passed against the binary exactly as U12 left it —
not one rebuild, not one Sema edit, not one BLOCKED handoff. That is the
step's result, and it is the second time a sweep on this track has produced
it (U10 was the first, for the explicit call).

The paper can say this literally: *for the expression semantics, nothing had
to be reimplemented.* The one thing that is **not** simply "the call" is
recorded as DEV-U16 and is a design-text problem, not a compiler one.

## The one finding: evaluation order splits in two, and D15 does not

This is the whole answer to the step's "capture in handoff" question, so it
is first.

D15 / §17.2 says the operator "introduces **no new evaluation-order rule**
and inherits [expr.call] wholesale", and then states two consequences as if
they always hold. Neither survives contact unqualified.

### (a) "Operand order is unspecified" is true only of the non-member form

For a **member** operator the left operand is the *object expression*, which
is part of the postfix-expression, and [expr.call]p8 sequences the
postfix-expression before every argument. So `x ⊞ y` **does** sequence `x`
before `y` when a member overload wins. Measured three independent ways:

| Observation | Non-member `⊩` | Member `⊪` | Built-in `<<` |
|---|---|---|---|
| constant evaluation of a double-write probe | `1122` **or** `2211` permitted | `1122` **guaranteed** | n/a |
| `-Wunsequenced` on `i++ OP i++` | **warns** | silent | silent |
| emitted IR | order unspecified, not checked | object's call first | n/a |

The `-Wunsequenced` triple is the sharpest evidence in the whole file that
the operator got *the call's* rules and not *an operator's*, because the
three behaviours are actually distinguishable:

```
(void)(i++ << i++);              // silent: [expr.shift] sequences LHS before RHS
(void)nonmember_op(i++, i++);    // warns
(void)(i++ ⊩ i++);               // warns, same text, same caret column
(void)(objs[i++] ⊪ i++);         // silent
(void)(objs[i++].operator⊪(i++));// silent — the member form's own desugaring
```

The consequence, which is the sentence for the paper: **the sequencing of
`x ⊞ y` is determined by overload resolution.** No existing C++ operator
behaves that way — [over.match.oper]p2 makes an *overloaded*
built-in-spelled operator use the built-in's sequencing regardless of
member-ness, and a user operator has no built-in to borrow sequencing from.
It is defensible (it is exactly what `x.operator⊞(y)` and `operator⊞(x, y)`
respectively give, which *is* the U6/§17.4 equivalence) but it has to be
**decided**, not inherited by silence.

### (b) "The slot is evaluated before both operands" is vacuous here

Backtick's slot is an *expression* and can have side effects, which is what
makes that sentence worth saying. A Unicode operator's callee is a **name**:
there is no callee subexpression, so [expr.call]p8's first sentence has
nothing to sequence. Quoting D15 verbatim into the Unicode paper imports a
clause that cannot apply.

Both parts are DEV-U16 with the recommended doc change.

## What I asserted about evaluation order, and why

The step was explicit that over-claiming here would misrepresent D15, so
the file states each claim at exactly the strength the standard gives:

- **Non-member:** `static_assert(order_op() == 1122 || order_op() == 2211);`
  — indeterminately sequenced, so no interleaving (which `1212`/`2121`
  would show) but no order. Each operand writes to the probe variable
  *twice*, which is what makes interleaving observable at all.
- **The inheritance claim as an equation:**
  `static_assert(order_op() == order_call());` — whichever order this
  implementation picks, it picks the same one for the operator syntax and
  for the explicit call. This is strictly stronger than two assertions that
  happen to match, and it does not name an order.
- **Member:** `static_assert(order_member() == 1122);` — asserted *as an
  order*, because [expr.call]p8 guarantees it, plus
  `order_member() == order_member_call()`.
- **Nothing asserts left-to-right for the non-member form**, even though
  both of Clang's constant evaluators currently evaluate the left operand
  first. I measured that (it is `1122` in `ExprConstant.cpp` and in the
  bytecode interpreter alike) and deliberately did not write it down.
- In the CodeGen file, `nested` checks that the operator's call comes after
  *both* operand calls and deliberately does **not** check which operand
  call comes first; a comment says why.

## What changed

**Production: nothing.** `git show --stat` is two test files.

| File | Change |
|------|--------|
| `clang/test/SemaCXX/unicode-operator-semantics.cpp` | **new**, 642 lines, 6 RUN lines |
| `clang/test/CodeGenCXX/unicode-operator-semantics.cpp` | **new**, 149 lines, 5 RUN lines |

**In this repo:** `PLAN.md` (U14 ticked, Status row), `REPLAY.md` U14 row,
`DEVIATIONS.md` **DEV-U16**, this handoff.

### The Sema file

Six RUN lines, which are themselves item 9 (the flag matrix) and item 3's
second constant evaluator:

```
-funicode-operators -verify                                              # unicode alone
-funicode-operators -fbacktick -DBACKTICK -verify                        # both
-funicode-operators -fexperimental-new-constant-interpreter -verify      # bytecode evaluator
-funicode-operators -fbacktick -DBACKTICK -fexperimental-new-constant-interpreter -verify
-DOFF -verify=off                                                        # neither flag
-fbacktick -DOFF -verify=off                                             # backtick alone
```

Nine sections matching the step's nine items, with the prefix twins carried
**inline in each section** rather than collected in a block — the point
being that the two fixities are one feature (a one-argument call and a
two-argument call), so section 8 holds only the prefix cases with no infix
analogue at all.

Deliberately *not* restated: `static_assert(5 ⊞ 7 == 12)` (U13 §1), ADL and
candidate assembly (U13's whole file), grouping and precedence (U11/U12's
Parser files), the two `FIXME(U16)` regression shapes (U13 §5). The header
comment names each sibling file and what it owns.

### The CodeGen file

The strongest single piece of evidence in the step, and the shape worth
copying: a `-DFORM_OP` / `-DFORM_CALL` macro pair spells the *same function
bodies* two ways —

```cpp
#ifdef FORM_OP
#define INFIX(a, b) ((a) ⊞ (b))
#define MEMBER(a, b) ((a) ⊪ (b))
#else
#define INFIX(a, b) operator⊞((a), (b))
#define MEMBER(a, b) (a).operator⊪((b))
#endif
```

— and the two `-emit-llvm` outputs are `diff`ed. **They are byte-identical**,
including the `invoke`/`landingpad` structure, and identical again with
`-fbacktick` added. Not "both compile", not "both call the right symbol":
the same module. Everything else in the file (the throwing operator's
invoke + cleanup landing pad, the `noexcept` operator's absence of one, the
`store i32 42` through a reference return, the member operand order) is a
FileCheck on the operator-syntax build.

## The nine areas, and what passed unmodified

All nine. The ones worth naming, because they are new evidence rather than
a re-run:

1. **Operands / value categories.** `const&`-vs-`&&` non-member overload
   pairs; member ref-qualifiers on *both* fixities — and for the prefix form
   the object argument is the only operand, so `⊖rq` vs `⊖RQ{}` is the
   cheapest value-category test in the tree. An `&&`-only member prefix
   operator rejects an lvalue with the ordinary
   `expects an rvalue for object argument` note. Reference returns assign
   through in both fixities, member and not; prvalue stays prvalue, xvalue
   stays xvalue.
2. **Conversions.** Converting constructor and conversion function on both
   operands; **explicit** ones correctly not used (copy-initialization of a
   parameter, the call's rule, not a looser one) with the ordinary
   no-known-conversion note; `[over.match.best]` ambiguity naming the
   operator with two `candidate function` notes.
3. **constexpr / consteval.** Constexpr member operators both fixities;
   constant-evaluated ADL; `consteval` immediate invocation and the ordinary
   `call to consteval function 'operator⊤' is not a constant expression`
   when the operands are not constants; the operator in a
   default-member-initializer, an array bound, an enumerator, a template
   argument; `&operator⊟` taken and called. **Both constant evaluators
   agree on every assertion, including the evaluation-order probes** — the
   `-fexperimental-new-constant-interpreter` RUN lines that U16 and U17 both
   flagged as never written are now written, and `ByteCode/Compiler.cpp`'s
   `VisitUserOperatorExpr` needed nothing.
4. **Templates.** The reason this step gained its U16 dependency, and it is
   fully closed. New shapes nobody had run: a **member operator found
   through a dependent base**, both fixities (U16 and U17 each flagged this
   as untested); a class template's member operator *and* a partial
   specialization's; a member operator template deduced through operator
   syntax; late-declared operators found by ADL at instantiation, both
   fixities; SFINAE on the prefix form; concepts on both fixities; a
   compound requirement `{ a ⊞ b } noexcept` and `-> SameAs<int>`.
   **And U16's specific worry, now pinned:** a *non-dependent* use inside a
   template is bound at definition time and is **not** re-resolved against
   the instantiation context — an exact-match overload declared *after* the
   template cannot steal the call, in either fixity. That is the property
   `TransformUserOperatorExpr`'s unconditional rebuild has to preserve, and
   it does.
5. **Exception specifications.** `noexcept(a ⊞ b)` is the callee's, both
   fixities, member and non-member; computed specifications
   (`noexcept(sizeof(T) == sizeof(int))`); forwarding
   `noexcept(noexcept(a ⊣ b))` through a template; the operand of `noexcept`
   is unevaluated. `Sema::canThrow` forwards through the node and needed
   nothing. Runtime half in the CodeGen file.
6. **Evaluation order.** Above.
7. **Deleted operators.** Non-member infix and non-member prefix, both
   `call to deleted function 'operator…'` + `candidate function has been
   explicitly deleted`; a deleted overload correctly *not* selected; a
   deleted operator unsatisfying a concept rather than hard-erroring.
   (Member forms were already U13 §4b.)
8. **Prefix equivalents.** Carried inline throughout. Section 8 holds the
   two that have no infix analogue: a member prefix operator can only be
   overloaded on cv-/ref-qualification (its only operand is the object), and
   stacking `⊯⊯1` is literally call nesting —
   `static_assert((⊯⊯1) == operator⊯(operator⊯(1)))`.
9. **Flags.** The RUN matrix, plus a `#ifdef BACKTICK` block. One assertion
   there is worth knowing about: **`1 \`operator⊟\` 2` works** — a user
   operator's overload set as the backtick *slot*, since the slot is an
   assignment-expression and an *operator-function-id* is an id-expression —
   and it equals `1 ⊟ 2`. Nothing else in the tree does that.

## Verification evidence

**No build.** `git status` before the commit was two untracked test files;
`ninja clang` was never run, because there was nothing to compile.

**Targeted lit,** after the gate finished (see the trap below):
`clang/test/{SemaCXX,CodeGenCXX,Parser,AST,PCH,Modules}` → **4877
discovered / 4810 passed / 0 failed / 9 XFAIL / 58 unsupported**, 13.7 s.

**Full gate:** `ninja -C /home/sdowney/src/llvm/build-unicode check-clang`
→ `EXIT=0`

```
Total Discovered Tests: 54166
  Passed: 48280   Unsupported: 5853   Expectedly Failed: 27   Skipped: 6
  Failed: 0
```

171.2 s test time; zero `FAIL:`/`UNRESOLVED:`/`TIMEOUT:` lines; zero
`warning:` lines in the log (grepped, not inferred from the exit code).
Discovered is exactly U12's 54164 **+2** and passed 48278 **+2** — the two
new tests, nothing else changed behaviour.

**Green unfiltered for the second run in a row.** The 8
`DirectoryWatcherTest.*` cases passed again, so no `GTEST_FILTER` re-run was
needed. U12's warning still stands: do not conclude the artifact is gone.

## Deviations from the plan / design

**DEV-U16** (`DEVIATIONS.md`), the evaluation-order split described above.
It is the *only* row U14 produced, which is itself the headline: eight of
the nine areas fell out of being a call with nothing left over.

**No step-file instruction was deviated from, and nothing was patched.**
The scope discipline the step insisted on was never tested, because no case
failed. Two cases needed a test-side fix during authoring and neither was a
compiler issue: a concept-name typo (`-> __is_same_as(int)` is not a valid
compound-requirement return-type-requirement; a one-line `SameAs` concept
fixed it) and a glyph collision (I had reused `⊤` for both a `consteval`
operator in §3 and a `noexcept`-computing template in §5, and the
non-template won overload resolution — renamed to `⊲`).

Two things done **beyond** the step file:
- the `-fexperimental-new-constant-interpreter` RUN lines, which U16 and
  U17 both flagged as a one-line test nobody had written;
- the byte-identical-IR `diff` construction, which the step did not ask for
  and which turned out to be the strongest available statement of the
  claim.

## Discoveries affecting later steps

- **`-Wunsequenced` is on by default** (no `-Wall` needed) and is a free,
  very sharp oracle for "did this get the call's rules?". Any later step
  wanting to distinguish call semantics from operator semantics should
  reach for it first.
- **Never run `llvm-lit` while `check-clang` is running in the background.**
  I did, and got *4131 failures* out of 4877 — the gate was relinking
  binaries under the test run. Re-running after the gate finished gave 0
  failures. If a targeted run reports mass failure, check whether a build is
  in flight before believing a word of it.
- **`git status` in the worktree is the honest report of a tests-only
  step.** Both U10 and U14 produce a two-file diff; say so in the Status
  log rather than reporting "no rebuild needed" as a cost saving.
- **The member/non-member sequencing split is invisible to `-ast-print` and
  `-ast-dump`.** It only shows in constant evaluation, `-Wunsequenced`, and
  emitted IR. Anyone auditing the node's behaviour from the AST alone will
  miss it.
- **`Tag<N>` numbering across files is not coordinated and does not need to
  be**; this file runs 1–30 in its own namespace.
- The `⊤`/`⊲` collision above generalises: **a file that declares the same
  glyph twice with different semantics will silently resolve to the
  non-template / better-match candidate.** Give each property its own glyph.

## Forward notes for U15 — precedence and associativity sweep

Written after reading `steps/U15-precedence-tests.md`. **U12's forward notes
for U15 are the substantive ones and are still exactly right — read them
first.** In particular: your items 1–7 and 10 are already asserted in
`Parser/unicode-operator-infix.cpp` and `Parser/unicode-operator-prefix.cpp`,
mostly by value rather than by dump; your genuinely-new material is `*p ⊞ *q`,
`a.m ⊞ b.m`, `a ⊞ b, c`, the four-term `a ⊞ b ⊗ c ⊞ d` chain, and the
three-way `⊖a ⊞ b \`f\` c`. These add to that list rather than repeat it.

- **U14 asserts no grouping at all, deliberately** — every expression in
  both new files is either parenthesized or single-operator. So nothing in
  my files can conflict with yours, and nothing in them pre-empts your item
  list. The one exception is section 9's
  `static_assert((1 ⊟ 2 \`fn\` 3) == 43)`, which is a mixed-chain grouping
  assertion (your item 8) that happened to be the cheapest way to show the
  two flags composing. Keep it or supersede it; do not assume it is absent.
- **`1 \`operator⊟\` 2` (§9 of my Sema file) is worth lifting into your
  file.** It is your item 8's territory from an angle the step does not
  list: the *slot* holding a user operator's overload set. It parses, it
  equals `1 ⊟ 2`, and it is a one-line demonstration that the two features
  compose at the grammar level rather than merely coexisting.
- **Your step says "a failure here is a U11/U12 bug — file BLOCKED against
  the owner."** U14 is the precedent that the scope rule is real and that
  the honest outcome may simply be "nothing to file". If your sweep passes
  clean, say so as a *result*: U§12's "one level, banked once" argument is
  evidenced by a test file that needed no compiler change, and that
  sentence is quotable.
- **Use values, not dumps, and keep U11/U12's constants.** `2a+b`, `3a+b`,
  `100a+b`, `5a+b` are already in use; reusing them lets a reader compare
  numbers across the three Parser files. `Tag<N>` is the alternative the
  step offers and is better for a *type* claim than a grouping claim.
- **Evaluation order is not precedence and is now spoken for.** If a
  grouping test of yours happens to have side effects in both operands, be
  aware that `-Wunsequenced` may fire on the non-member form (see DEV-U16);
  parenthesize or use side-effect-free operands so your file stays about
  grouping.
- **Glyph budget.** U14 consumed, within its two files only: ⊞ ⊕ ⊖ ⊗ ⊘ ⊙ ⊚
  ⊛ ⊜ ⊝ ⊟ ⊠ ⊡ ⊢ ⊣ ⊤ ⊥ ⊨ ⊩ ⊪ ⊬ ⊭ ⊮ ⊯ ⊲ ⋀ ⋁. Nothing is globally reserved —
  reuse any of them. U10's free list is unchanged except that U14 used ⊲
  (U+22B2) and ⊮ ⊯ (U+22AE, U+22AF) from the U+22AE–U+22BF span, so the
  still-untouched-anywhere set is U+22A6, U+22A7, U+22B0, U+22B1,
  U+22B3–U+22BF, U+22C2–U+22C4.
- **Gate expectations for you:** baseline is now 54166 discovered / 48280
  passed / 0 failed, unfiltered. Two runs in a row have been clean without
  the `DirectoryWatcherTest` filter; keep the filtered command in your
  pocket anyway. Budget ~12 min for the gate and **zero** for the build if,
  like U14, you touch no production file.

## Open risks / TODOs

- **DEV-U16 is a decision the paper owes, not a bug.** Nobody has chosen
  whether U§7 states the member/non-member sequencing split or leaves it
  implicit in "it is the call". It is cheap to state and impossible to
  discover from the design text as written.
- **DEV-U15's default-argument corner is still measured-but-undecided**,
  unchanged from U12. U14 pins the accepting behaviour a second time
  (`(⊬5) == operator⊬(5)`) and adds nothing to the argument. My judgement
  agrees with U12's: change the declaration rule or the doc, not the use
  rule.
- **U04 is still unchecked** and is now the *only* thing between the
  implementation and a complete Phase A. Both of U14's files will want a
  `-DUCN` addition when it lands, bringing the count of files awaiting it to
  seven. It also still blocks U18.
- **DEV-U07** (`ShouldParseIf<cplusplus.KeyPath>` for both flags) remains
  measured-but-unacted; owner U04/U05.
- **The `-Wswitch` `BacktickInfixExprClass` gap remains open in two files**
  (`StaticAnalyzer/Core/ExprEngine.cpp`, `tools/libclang/CXCursor.cpp`),
  untouched and not to be fixed on this branch. U14 recompiled nothing, so
  it did not resurface.
- **`clang/lib/CIR/` is still untouched and uncompiled.** U14's CodeGen file
  exercises the classic code generator only; the CIR path has still never
  seen a `UserOperatorExpr`.
- **The inotify/`DirectoryWatcherTest` artifact did not fire again.** Two
  clean runs is not proof it is gone.
