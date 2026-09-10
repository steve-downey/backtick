# U06 — `DeclarationName` kind for user operators

**Goal.** Open Clang's closed operator-name space: a new `DeclarationName`
kind carrying a code point, so `operator⊞` can be *named* at all. This is
the step the whole feature turns on; everything downstream is plumbing that
follows from it.

**Depends on:** U03. (Parallel with U04 and U05.)
**Design refs:** U§8 "Clang — *The hard part — `DeclarationName`*"; U2.

## Do
1. Read `CXXLiteralOperatorName` end to end first — `operator""_suffix` is
   the worked precedent: a `DeclarationName` kind keyed by open-ended extra
   data (an `IdentifierInfo *`) rather than by an index into a closed enum.
   Follow it; do not extend `OverloadedOperatorKind`, which is indexed into
   fixed-size tables throughout Sema and cannot grow open-endedly.
2. Add the kind (e.g. `CXXUserOperatorName`) in
   `clang/include/clang/AST/DeclarationName.h` + `.cpp`: the enumerator,
   the extra-data class, `DeclarationNameTable` creation
   (`getCXXUserOperatorName(...)`), folding-set uniquing, printing
   (`printName` → `operator⊞`), and `getFETokenInfo`-style accessors if the
   precedent has them.
3. Decide and record the identity representation: an `IdentifierInfo *` for
   the operator's spelling (closest to the precedent, gives uniquing and
   hashing for free) versus a raw `UTF32` code point. Whichever you choose,
   two spellings of the same code point (glyph and UCN, U04) **must** yield
   the same `DeclarationName` — that is the acceptance criterion, and it
   argues for canonicalizing to the code point before creating the name.
4. Chase the exhaustive switches. `getNameKind()` switches exist in
   AST printing, `ASTContext`, mangling, serialization, `ODRHash`,
   `TreeTransform`, `StmtProfile`, and the recursive AST visitors. Handle
   what the build forces; leave unreachable-for-now cases as explicit
   `llvm_unreachable` with a comment naming the step that fills them
   (U09 mangling, U17 serialization). List every one you touched or
   deliberately deferred — U17 works from that list.
5. Nothing parses this yet. The gate is that the AST layer can represent
   and print the name.

## Build
`ninja -C ~/src/llvm/build-unicode clang`

## Verify (gate)
- Unittest in `clang/unittests/AST/`: create the name twice from two
  spellings, assert pointer-equal (uniquing), assert `getAsString()` is
  `operator⊞`, assert the kind round-trips.
- `check-clang` green — this step touches shared headers, so a clean full
  gate here is worth more than usual. Watch for build breaks in unrelated
  targets (clang-tidy, static analyzer) that switch over name kinds.

## Done when
The name kind exists, uniques correctly across spellings, prints, and the
tree builds and gates green with the new enumerator present.

## Capture in handoff
**The list of every exhaustive switch you found**, with file:line and
whether you filled it or deferred it. This is the single most valuable
artifact of the step; U09, U16, and U17 each start from it. Also: the final
identity representation and the reason, and how large the diff turned out
(the design calls this a "real cost" — quantify it for the paper).

## Pitfalls
`DeclarationName` packs its kind into low pointer bits in some builds; an
added enumerator can overflow the available bits. If you hit that, it is a
DEVIATION and a genuine finding about the cost of open-ended operator names
— record it in detail rather than working around it quietly.

## REPLAY ledger
`upstream replay`, and the largest single item in the ledger. Note
precisely which files are shared with the backtick diff (few should be) so
U20 can predict conflicts.
