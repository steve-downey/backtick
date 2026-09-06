# BL05 — [`increment-decrement-mangling`](../../BACKLOG.md#increment-decrement-mangling): report Clang's `operator++` / `operator--` mangling defect

**Goal.** An upstream bug report exists for a live cross-vendor mangling
divergence that neither feature caused, so it stops being a private note in
`ops/`.

**Depends on:** nothing. Independent of every other step; it can run at any
time, including first.
**Closes:** [`increment-decrement-mangling`](../../BACKLOG.md#increment-decrement-mangling).
**Refs:** `ops/unicode-operators/clang/handoffs/U21-postfix-probe.handoff.md:112-129`
and `:246`; [postfix-operators](../../unicode-operators/clang/DEVIATIONS.md#postfix-operators) clause (c); `docs/unicode-operators.md:807-822`;
`papers/dxxxxr0.md:715-716`.

Nothing lands on either feature branch. This step writes no compiler code.

## The defect

```cpp
struct A { int operator++(); double operator++(int); };
template<class T> void f(decltype(++T{})) {}
template<class T> void f(decltype(T{}++)) {}
```

- **Clang** mangles both as `_Z1fI1AEvDTpptlT_EE` →
  `error: definition with same mangled name as another definition`.
- **GCC 15.2.0** emits `_Z1fI1AEvDTpp_tlT_EE` (prefix) and
  `_Z1fI1AEvDTpptlT_EE` (postfix) — two distinct symbols.

The Itanium ABI's `<expression>` grammar spells prefix `++` as `pp_` and
postfix as `pp`. GCC is right; Clang is wrong.

## Three things to carry into the report that `BACKLOG.md` does not have

1. **`operator--` has the identical defect**, recorded nowhere: the same test
   with `--` gives `error: definition with same mangled name
   '_Z1fI1AEvDTmmtlT_EE'`. The ABI spells `mm_` / `mm`.
2. **LLVM can read what LLVM cannot write.** LLVM's own demangler
   *implements* the distinction — `llvm/include/llvm/Demangle/ItaniumDemangle.h:5177-5178`
   documents the grammar (`::= pp_ <expression>  # prefix ++`) and
   `:5223-5229` parses it
   (`case OperatorInfo::Postfix: if (consumeIf('_')) return parsePrefixExpr(...)`).
   `llvm-cxxfilt` round-trips both spellings correctly. This is the single
   most persuasive line in the report.
3. **The defect is localized.** `clang/lib/AST/ItaniumMangle.cpp` mangles any
   `UnaryOperator` via
   `mangleOperatorName(UnaryOperator::getOverloadedOperator(...), /*Arity=*/1)`
   with no fixity reaching it, and `case OO_PlusPlus: Out << "pp";` /
   `case OO_MinusMinus: Out << "mm";` emit no `_`. The `UnaryOperator` arm
   has `UO->isPostfix()` in hand. **Cite the symbols, not the lines** — they
   differ by base (`:2733` on `main`, `:2808` / `:5600-5606` on the Unicode
   worktree).

## Do

1. **Re-confirm on current LLVM trunk.** The reproductions on file are from
   `~/src/llvm/build-main` and the Unicode worktree's base `06735e8df66d`,
   neither of which is today's trunk. A report against a stale base wastes a
   triager's time and gets closed.
2. **Find the ABI paragraph reference** for the `<expression>` production in
   the Itanium C++ ABI document, so the report cites the specification rather
   than LLVM's own comment.
3. **Search for an existing issue** before filing.
4. **File a GitHub issue on `llvm/llvm-project`** containing: the reproducer,
   both compilers' symbols for `++` and `--`, GCC's version, the ABI
   citation, the demangler-already-implements-it observation, and the two
   mangler sites.
5. **Do not attach a patch** unless upstream asks. `mangleOperatorName` does
   not know fixity, so the fix belongs at the `UnaryOperator` call site (and
   the `CXXOperatorCallExpr` path for the overloaded spelling) — a shape
   question that wants upstream's opinion before code.

## Verify (gate)

No `check-clang`. The gate is:

- the issue exists and its URL is recorded in the handoff;
- the reproducer pasted into it reproduces on **current trunk**, both for
  `++` and for `--`;
- nothing was committed to `backtick-*` or `unicode-operators-*`.

## Capture in handoff

The issue URL, the trunk revision it was confirmed against, and the ABI
paragraph reference.

Then update the three places that carry this as a private note —
`ops/unicode-operators/clang/DEVIATIONS.md` ([postfix-operators](../../unicode-operators/clang/DEVIATIONS.md#postfix-operators) c),
`docs/unicode-operators.md:807-822` and `papers/dxxxxr0.md:715-716` — to
point at the issue. A paper that says "we found a Clang bug" is stronger when
it can say which one.

Note for the paper, from `U21:240-244`: this is *why* [operator-mangling](../../../docs/unicode-operators.md#operator-mangling) stays open. A
first-class `<operator-name>` production needs room for a fixity marker that
`v <digit> <source-name>` does not have — and the `pp`/`pp_` divergence is
evidence that fixity in mangling is easy to get wrong even where the ABI
spells it out.
