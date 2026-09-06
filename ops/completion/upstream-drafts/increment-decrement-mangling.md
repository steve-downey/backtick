# Draft upstream report — [`increment-decrement-mangling`](../../BACKLOG.md#increment-decrement-mangling)

**Status: DRAFTED, NOT FILED.** The author decided this step drafts the three
reports and does not post them. Nothing below has been sent to any issue
tracker. The maintainer files it; until then there is no issue number, and
every document that wants to cite one carries the placeholder token
`LLVM-ISSUE-PENDING` instead (grep for it).

- **Target:** `llvm/llvm-project`, new issue. Suggested labels: `clang`,
  `clang:codegen`, `ABI`.
- **Confirmed against trunk:** source read at **`72417eb739e5`** (2026-09-05,
  `upstream/main` as fetched 2026-09-06). Binary reproduction on two builds of
  trunk: `a815e6f267c1` (2026-06-13, `~/src/llvm/build-main`) and
  `783a9c1a5f6f` (base `d28193fa1ff6`, 2026-08-04,
  `~/src/llvm/build-unicode-upstream`, feature flags off). Both mangler sites
  quoted below were read out of `72417eb739e5` itself, so the report is
  against today's trunk even though no binary of today's trunk exists here.
- **Existing-issue search (2026-09-06), no duplicate found.** Queries run
  against `repo:llvm/llvm-project` (`is:issue`, open and closed):
  `mangling increment` (12 hits, none related), `"pp_"` (0),
  `mangled name decltype postfix` (0), `in:title mangling operator++` (4 —
  #140654 `extern "C"`, #22958 unresolved operator names, #12704 MicrosoftMangle,
  #8263 assertion; none is this), `"definition with same mangled name"` (47 —
  all modules/pack-expansion/attribute manglings; #26427 is the closest in
  shape and is about `SUBSTPACK`, not fixity), `"prefix ++" mangling` (55, none
  related), `mangleOperatorName` (1, unrelated), `"DTpp"` (0).
- **Do not attach a patch** unless upstream asks. `mangleOperatorName` does not
  know fixity, so the fix belongs at the `UnaryOperator` call site and at the
  `CXXOperatorCallExpr` path for the overloaded spelling — a shape question
  that wants upstream's opinion first.

## Correction to the reproducer on file

`ops/backlog/steps/BL05-upstream-mangling.md` gives the two function templates
alone. **That does not reproduce**: with no instantiation nothing is mangled
and the file compiles clean. The reproducer below adds the two explicit
instantiations that force emission. Verified both ways on both builds.

---

## Title

`[clang] Itanium mangling of prefix ++ / -- inside <expression> omits the trailing '_', colliding with postfix`

## Body (paste below this line)

Clang mangles prefix and postfix `++` identically inside an `<expression>`, so
two function templates that differ only in the fixity of an increment in a
`decltype` collide. GCC does not; the Itanium ABI says GCC is right. `--` has
the identical defect.

### Reproducer

```cpp
// repro-inc.cpp
struct A { int operator++(); double operator++(int); };
template <class T> void f(decltype(++T{})) {}
template <class T> void f(decltype(T{}++)) {}
template void f<A>(int);      // forces emission of both
template void f<A>(double);
```

```console
$ clang++ -std=c++17 -c repro-inc.cpp
repro-inc.cpp:3:24: error: definition with same mangled name '_Z1fI1AEvDTpptlT_EE' as another definition
    3 | template <class T> void f(decltype(T{}++)) {}
      |                        ^
repro-inc.cpp:2:24: note: previous definition is here
    2 | template <class T> void f(decltype(++T{})) {}
      |                        ^
```

```console
$ g++ -std=c++17 -c repro-inc.cpp && nm --defined-only repro-inc.o
0000000000000000 W _Z1fI1AEvDTpp_tlT_EE     # prefix
0000000000000000 W _Z1fI1AEvDTpptlT_EE      # postfix
```

`operator--` fails the same way — the same file with `--` throughout:

```console
$ clang++ -std=c++17 -c repro-dec.cpp
repro-dec.cpp:3:24: error: definition with same mangled name '_Z1fI1AEvDTmmtlT_EE' as another definition
$ g++ -std=c++17 -c repro-dec.cpp && nm --defined-only repro-dec.o
0000000000000000 W _Z1fI1AEvDTmm_tlT_EE     # prefix
0000000000000000 W _Z1fI1AEvDTmmtlT_EE      # postfix
```

GCC is `g++ (Ubuntu 15.2.0-16ubuntu1) 15.2.0`.

### What the ABI says

The Itanium C++ ABI gives the two fixities different spellings, in two places:

- **§5.1.3 Operator Encodings** — `<operator-name> ::= pp` is annotated
  *"`++` (postfix in `<expression>` context)"*, and `::= mm` likewise for `--`.
- **§5.1.6 Expressions** — the `<expression>` production has dedicated
  alternatives for the prefix forms:

  ```
  <expression> ::= pp_ <expression>   # prefix ++
               ::= mm_ <expression>   # prefix --
  ```

So `pp` is postfix, `pp_` is prefix, and Clang emits `pp` for both.

### LLVM already reads what it cannot write

LLVM's own demangler implements the distinction. In
`llvm/include/llvm/Demangle/ItaniumDemangle.h` the grammar comment carries both
productions, the operator table marks `pp`/`mm` as `OperatorInfo::Postfix`, and
`parseExpr`'s postfix arm consumes an optional `_` and re-parses as prefix:

```cpp
    case OperatorInfo::Postfix: {
      // Postfix unary operator: expr @
      if (consumeIf('_'))
        return getDerived().parsePrefixExpr(Sym, Op->getPrecedence());
      ...
```

`llvm-cxxfilt` round-trips all four spellings correctly:

```console
$ llvm-cxxfilt _Z1fI1AEvDTpp_tlT_EE _Z1fI1AEvDTpptlT_EE _Z1fI1AEvDTmm_tlT_EE _Z1fI1AEvDTmmtlT_EE
void f<A>(decltype(++A{}))
void f<A>(decltype(A{}++))
void f<A>(decltype(--A{}))
void f<A>(decltype(A{}--))
```

So this is not a gap in LLVM's understanding of the ABI; the mangler and the
demangler disagree with each other.

### Where it is

Two sites in `clang/lib/AST/ItaniumMangle.cpp`, both localized (line numbers as
of `72417eb739e5`; the symbols are the stable reference):

- `CXXNameMangler::mangleOperatorName(OverloadedOperatorKind, unsigned Arity)`
  emits `case OO_PlusPlus: Out << "pp";` and `case OO_MinusMinus: Out << "mm";`
  (`:2770`, `:2772`). It has an arity but no fixity, and both fixities are
  1-ary, so it cannot tell them apart.
- `CXXNameMangler::mangleExpression`'s `case Expr::UnaryOperatorClass:`
  (`:5579`) calls
  `mangleOperatorName(UnaryOperator::getOverloadedOperator(UO->getOpcode()), /*Arity=*/1)`
  — and it *does* have the fixity in hand: `UO->isPostfix()`.
  `case Expr::CXXOperatorCallExprClass:` (`:5717`) is the same shape for the
  overloaded spelling, where the argument count is the only fixity signal.

Since `mangleOperatorName` cannot know the fixity, a fix presumably belongs at
those two call sites rather than in the shared helper — but that is a shape
question for whoever owns the mangler, so no patch is attached. Happy to write
one on request.

### Environment

`clang version 24.0.0git` and `23.0.0git`, x86_64-unknown-linux-gnu; the code
quoted above is from `main` at `72417eb739e5`.
