# Draft upstream report — [`auto-return-round-trip`](../../BACKLOG.md#auto-return-round-trip)

**Status: DRAFTED, NOT FILED.** The author decided this track drafts its
upstream reports and does not post them. Nothing below has been sent to any
issue tracker. The maintainer files it.

- **Target:** `llvm/llvm-project`, new issue. Suggested labels: `clang`,
  `clang:frontend`.
- **Confirmed against trunk:** `DeclPrinter::VisitFunctionDecl` extracted from
  `d28193fa1ff6` (2026-08-04, the base of `~/src/llvm/build-unicode-upstream`)
  and from `upstream/main` at **`72417eb739e5`** (2026-09-05, fetched
  2026-09-06) is **identical**, so the reproduction below exercises today's
  trunk code. Reproduced on two builds: `783a9c1a5f6f` (base `d28193fa1ff6`,
  `~/src/llvm/build-unicode-upstream`, no feature flags passed) and
  `a815e6f267c1` (2026-06-13, `~/src/llvm/build-main`, pristine). Both print
  character-identical output.
- **Existing-issue search (2026-09-06), no duplicate.** Queries against
  `repo:llvm/llvm-project` (`is:issue`, open and closed):
  `ast-print deduced return type` (3, unrelated),
  `ast-print round trip template` (1 — #218420, see below),
  `"-ast-print" auto function template` (7, none this),
  `getDeclaredReturnType print` (0),
  `ast-print invalid source specialization` (2, unrelated),
  `in:title ast-print` (21, all read).
  **Three are prior art rather than duplicates**, and the report cites them:
  **#12178** ("clang -ast-print isn't production quality", open since 2012) is
  the umbrella for `-ast-print` emitting source that does not compile;
  **#218420** (open) and **#147150** (open) are two other specific instances of
  it. This is a fourth, with a one-line cause and a named accessor for the fix,
  which is why it is worth its own issue rather than a comment on #12178.
- **Attach the patch only if asked.** The one-line change is obvious, but
  whether a *specialization* of an `auto` template should print `auto` (the
  declaration as written) or should not be printed at all is a policy question
  for whoever owns `DeclPrinter`.

---

## Title

`[clang] -ast-print emits non-compiling source for a specialization of a function template with a deduced return type`

## Body (paste below this line)

`-ast-print` prints the implicit specialization of an `auto`-returning function
template with the *deduced* return type. The printed specialization then does
not match the primary template it is printed next to, so the output does not
compile — which makes `-ast-print` unusable as a round-trip oracle for any
translation unit containing such a template.

```console
$ cat auto-rt.cpp
template <class T> auto f(T t) { return t; }
int main() { return f(0); }

$ clang++ -std=c++23 -Xclang -ast-print -fsyntax-only auto-rt.cpp
template <class T> auto f(T t) {
    return t;
}
template<> int f<int>(int t) {
    return t;
}
int main() {
    return f(0);
}

$ clang++ -std=c++23 -Xclang -ast-print -fsyntax-only auto-rt.cpp > out.cpp
$ clang++ -std=c++23 -fsyntax-only out.cpp
out.cpp:4:16: error: no function template matches function template specialization 'f'
    4 | template<> int f<int>(int t) {
      |                ^
out.cpp:1:25: note: candidate template ignored: could not match 'auto (int)' against 'int (int)'
    1 | template <class T> auto f(T t) {
      |                         ^
1 error generated.
```

`decltype(auto)` behaves the same way (`template<> int h<int>(int t)`).

### The control

With an explicit return type the same shape round-trips cleanly, which
isolates the deduction as the cause:

```console
$ cat ctrl.cpp
template <class T> T g(T t) { return t; }
int main() { return g(0); }

$ clang++ -std=c++23 -Xclang -ast-print -fsyntax-only ctrl.cpp > ctrl-out.cpp
$ clang++ -std=c++23 -fsyntax-only ctrl-out.cpp     # exit 0
```

The printed `template<> int g<int>(int t)` matches `T g(T)` and compiles.

### Cause

`DeclPrinter::VisitFunctionDecl` takes the type to print from
`FunctionDecl::getType()` (`clang/lib/AST/DeclPrinter.cpp`, as of
`72417eb739e5`):

```cpp
  QualType Ty = D->getType();
  ...
  if (const FunctionType *AFT = Ty->getAs<FunctionType>()) {
    ...
      AFT->getReturnType().print(Out, Policy, Proto);
```

For a function with a deduced return type, `getType()` is the type *after*
deduction, so the printer prints `int`. `FunctionDecl` already carries an
accessor for exactly this distinction, with a doc comment that names the
problem (`clang/include/clang/AST/Decl.h`):

```cpp
  /// Get the declared return type, which may differ from the actual return
  /// type if the return type is deduced.
  QualType getDeclaredReturnType() const {
    auto *TSI = getTypeSourceInfo();
    QualType T = TSI ? TSI->getType() : getType();
    return T->castAs<FunctionType>()->getReturnType();
  }
```

Printing `getDeclaredReturnType()` would emit `auto`, and
`template<> auto f<int>(int t)` is valid and does re-deduce to the same thing.

Note that the plain non-template case is not affected in practice —
`auto k(int t) { return t; }` prints as `int k(int t)`, which is also the
deduced type rather than the type as written, but there is no primary
declaration for it to disagree with, so the output still compiles. The
template specialization is where the same substitution becomes a hard error.

### Why it matters

`-ast-print` is the standard way to write a "the AST round-trips" test —
print, re-compile, compare — and this makes that test impossible to write the
obvious way for any file containing an `auto`-returning function template. The
workaround is to avoid deduced return types in the test input, which quietly
constrains what such tests can cover. That is the cost being reported: not a
miscompile, but an oracle that cannot be used where it is most wanted.

This is a specific instance of the general complaint in **#12178**, alongside
**#218420** and **#147150**; it is filed separately because the cause is one
line and the accessor that fixes it already exists and is documented for this
exact case.
