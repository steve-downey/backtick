# Draft upstream report — [`pch-ast-print-order`](../../BACKLOG.md#pch-ast-print-order)

**Status: DRAFTED, NOT FILED.** The author decided this track drafts its
upstream reports and does not post them. Nothing below has been sent to any
issue tracker. The maintainer files it.

- **Target:** `llvm/llvm-project`. **Probably a comment on the open issue
  #24794 rather than a new issue** — see "The existing issue" below; the
  maintainer should decide which, and the body is written to work either way.
  Suggested labels if new: `clang`, `clang:modules`.
- **Confirmed against trunk:** `clang/lib/AST/DeclBase.cpp` is **byte-identical**
  between `d28193fa1ff6` (2026-08-04, the base of
  `~/src/llvm/build-unicode-upstream`) and `upstream/main` at **`72417eb739e5`**
  (2026-09-05, fetched 2026-09-06), and `RecordDecl::LoadFieldsFromExternalStorage`
  was read out of `72417eb739e5` itself. So the reproduction exercises today's
  trunk code. Reproduced on `783a9c1a5f6f` (base `d28193fa1ff6`,
  `~/src/llvm/build-unicode-upstream`, no feature flags passed).
- **Existing-issue search (2026-09-06).** Queries against
  `repo:llvm/llvm-project` (`is:issue`, open and closed):
  `ast-print PCH member order` (0), `LoadFieldsFromExternalStorage order` (0),
  `deserialized class member declaration order` (0), `ast-print reorder fields`
  (0), `PCH declaration order lexical` (0),
  `modules declaration order fields methods` (0), **`BuildDeclChain` (1 —
  #24794, the hit)**.
- **Correction to the note on file.** `ops/BACKLOG.md` describes this as
  "`-ast-print` after a PCH prints a class's fields last". That is true but
  under-specified, and the obvious reproducer **does not reproduce**: a class
  that sits in a PCH and is never named prints in source order. The class must
  actually be *used* from the main file. The reproducer below pins that, and
  the cause explains it.

## The existing issue

**#24794** (open since 2015, "RecordDecl::LoadFieldsFromExternalStorage()
expels existing decls from the DeclContext linked list") is the same two
functions and the same design. Its reported symptom — that
`LoadFieldsFromExternalStorage` *overwrote* the chain with
`std::tie(FirstDecl, LastDecl) = BuildDeclChain(...)`, dropping decls
entirely — **has since been fixed**: trunk splices instead of assigning. The
ordering consequence described below is what survives that fix, because both
loaders splice at the **front**. So this is not a duplicate of #24794 as
written, and it is not a regression either; it is the remainder of it, and it
should probably be recorded there.

---

## Title

`[clang] Class members come back in the wrong order after PCH/module deserialization when fields load before the rest (-ast-print shows fields last)`

## Body (paste below this line)

When a class is deserialized from a PCH, its members can come back in an order
that is not the source order: the fields end up **after** the member
functions, even though they were declared before them. `-ast-print` is the
easiest way to see it, but the reordered chain is `DeclContext`'s, so anything
that walks `decls_begin()` sees it.

### Reproducer

```console
$ cat pch2.cpp
#ifndef HEADER
#define HEADER
struct Mem {
  int v;
  constexpr int get() const { return v; }
  constexpr int add(int n) const { return v + n; }
};
#else
constexpr Mem m{7};
static_assert(m.get() == 7);
#endif

$ clang -cc1 -std=c++23 -emit-pch -o pch2.pch pch2.cpp
$ clang -cc1 -std=c++23 -ast-print -include pch2.cpp pch2.cpp > direct.txt
$ clang -cc1 -std=c++23 -include-pch pch2.pch -ast-print pch2.cpp > pch.txt
$ diff -u direct.txt pch.txt
--- direct.txt
+++ pch.txt
@@ -1,11 +1,11 @@
 struct Mem {
-    int v;
     constexpr int get() const {
         return this->v;
     }
     constexpr int add(int n) const {
         return this->v + n;
     }
+    int v;
 };
 constexpr Mem m{7};
 static_assert(m.get() == 7);
```

The same source compiled whole, and compiled with its first half precompiled,
print different member orders for the same class.

### The trigger

The class must be *used* from the main file. If nothing names `Mem`, it prints
in source order and there is no difference:

| Main file after the PCH | Result |
|---|---|
| *(nothing)* | source order — no bug |
| `Mem g;` | fields last |
| `int use(Mem m) { return m.get(); }` | fields last |

Merely naming the type is enough, because that is what forces the record to be
completed.

### Cause

Two loaders splice into the same linked list, and both splice at the front.

`RecordDecl::LoadFieldsFromExternalStorage` (`clang/lib/AST/Decl.cpp`, as of
`72417eb739e5`) loads only the fields, and puts them at the head:

```cpp
  Source->FindExternalLexicalDecls(this, [](Decl::Kind K) {
    return FieldDecl::classofKind(K) || IndirectFieldDecl::classofKind(K);
  }, Decls);
  ...
  auto [ExternalFirst, ExternalLast] =
      BuildDeclChain(Decls, /*FieldsAlreadyLoaded=*/false);
  ExternalLast->NextInContextAndBits.setPointer(FirstDecl);
  FirstDecl = ExternalFirst;
```

Later, walking the context calls
`DeclContext::LoadLexicalDeclsFromExternalStorage`
(`clang/lib/AST/DeclBase.cpp`), which reads **all** the lexical decls, drops
the fields it already has, and splices the remainder at the head as well:

```cpp
  // We may have already loaded just the fields of this record, in which case
  // we need to ignore them.
  bool FieldsAlreadyLoaded = false;
  if (const auto *RD = dyn_cast<RecordDecl>(this))
    FieldsAlreadyLoaded = RD->hasLoadedFieldsFromExternalStorage();

  // Splice the newly-read declarations into the beginning of the list
  // of declarations.
  Decl *ExternalFirst, *ExternalLast;
  std::tie(ExternalFirst, ExternalLast) =
      BuildDeclChain(Decls, FieldsAlreadyLoaded);
  ExternalLast->NextInContextAndBits.setPointer(FirstDecl);
  FirstDecl = ExternalFirst;
```

`BuildDeclChain`'s skip is the `FieldsAlreadyLoaded && isa<FieldDecl>(D)`
`continue`. So the second load prepends the methods in front of the fields the
first load already placed, and the source order is inverted between the two
groups. Splicing at the beginning is only order-preserving when the list is
empty, which is what the comment assumes and what stops being true as soon as
`field_begin()` has run.

When nothing completes the record first, only the second loader runs, it
splices into an empty list, and the order is correct — which is the table
above.

### Impact

Modest but real, and it is a footgun rather than a miscompile:

- It makes the natural PCH/module test — print the whole TU with and without
  precompilation and `diff` — fail for a reason unrelated to whatever is being
  tested. A test author's first assumption is that their own change reordered
  something.
- Any consumer that walks `DeclContext::decls()` for a deserialized record and
  cares about declaration order sees the same inversion. `-ast-print` is the
  visible one; it is not special.

### Relationship to #24794

**#24794** reported the stronger version of this — that
`LoadFieldsFromExternalStorage` assigned rather than spliced, and so *expelled*
implicit members that Sema had already added. That has been fixed; trunk
splices. What remains is the ordering above, which the fix did not address
because both splices go to the front. If it is preferred to keep this on
#24794 rather than open a second issue, this is a comment on it.

### Suggested direction

No patch offered — the ordering is a property of how the two loaders share the
chain, and there is more than one reasonable fix (have the field loader append
rather than prepend once a full load has happened; or have the full load
re-splice the fields into their recorded positions; or record the lexical order
and sort on completion). Which is right depends on how much
`hasLoadedFieldsFromExternalStorage` is meant to be an optimisation versus a
guarantee, which is upstream's call.
