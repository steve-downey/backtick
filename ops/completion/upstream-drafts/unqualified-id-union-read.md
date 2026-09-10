# Draft upstream report — [`unqualified-id-union-read`](../../BACKLOG.md#unqualified-id-union-read)

**Status: DRAFTED, NOT FILED.** The author decided this step drafts the three
reports and does not post them. Nothing below has been sent to any issue
tracker.

- **Target:** `llvm/llvm-project`, new issue. Suggested labels: `clang`,
  `clang:parser`.
- **Confirmed against trunk:** source read at **`72417eb739e5`** (2026-09-05,
  `upstream/main` as fetched 2026-09-06). This is a static defect — a read of
  the wrong union member with no observable misbehaviour today — so the
  confirmation is the code, quoted from that revision, not a binary.
- **Existing-issue search (2026-09-06), no exact duplicate.** Queries against
  `repo:llvm/llvm-project` (`is:issue`, open and closed):
  `UnqualifiedId union literal operator` (2, unrelated), `AnnotateTemplateIdToken`
  (32, all unrelated crashes), `"OperatorFunctionId"` (1 — **#20143**, see
  below), `in:title literal operator template-id` (0).
  **#20143 (open, filed 2014) is the same read at a third site**: a sanitizer
  report of "load of value too big" from `getName().OperatorFunctionId.Operator`
  in `Declarator::isStaticMember()`. That site is kind-guarded on trunk today;
  the two sites below are not. Cite it — it is the same union, the same member,
  and the same fix.

## Correction to the note on file

`ops/BACKLOG.md` cites `ParseExprCXX.cpp:2297`. On current trunk that line is
in the `err_missing_dependent_template_keyword` name-building block, and **that
block is correct**: it tests `IK_OperatorFunctionId` before reading
`OperatorFunctionId.Operator` and otherwise reads `Id.Identifier`, which is the
active member for `IK_LiteralOperatorId`. The live defect is the *other* site
U07 flagged, the `OpKind` ternary in `Parser::ParseUnqualifiedIdTemplateId`,
plus a second, previously unrecorded instance of it in
`Parser::AnnotateTemplateIdToken`. Both are quoted below.

---

## Title

`[clang][parser] UnqualifiedId::OperatorFunctionId.Operator is read for IK_LiteralOperatorId, where Identifier is the active union member`

## Body (paste below this line)

`UnqualifiedId` stores its payload in a union
(`clang/include/clang/Sema/DeclSpec.h`, as of `72417eb739e5`):

```cpp
  union {
    /// When Kind == IK_Identifier, the parsed identifier, or when
    /// Kind == IK_UserLiteralId, the identifier suffix.
    const IdentifierInfo *Identifier;

    /// When Kind == IK_OperatorFunctionId, the overloaded operator
    /// that we parsed.
    struct OFI OperatorFunctionId;
    ...
```

`setLiteralOperatorId` sets `Identifier`, so for `IK_LiteralOperatorId` the
active member is the `IdentifierInfo *`. `OFI::Operator` is the first member of
`OFI`, so reading it for that kind reinterprets the low half of a heap pointer
as an `OverloadedOperatorKind`.

Two places do exactly that.

**1. `Parser::ParseUnqualifiedIdTemplateId`, `clang/lib/Parse/ParseExprCXX.cpp:2364`**

```cpp
  if (Id.getKind() == UnqualifiedIdKind::IK_Identifier ||
      Id.getKind() == UnqualifiedIdKind::IK_OperatorFunctionId ||
      Id.getKind() == UnqualifiedIdKind::IK_LiteralOperatorId) {
    ...
    // FIXME: Store name for literal operator too.
    const IdentifierInfo *TemplateII =
        Id.getKind() == UnqualifiedIdKind::IK_Identifier ? Id.Identifier
                                                         : nullptr;
    OverloadedOperatorKind OpKind =
        Id.getKind() == UnqualifiedIdKind::IK_Identifier
            ? OO_None
            : Id.OperatorFunctionId.Operator;   // <-- IK_LiteralOperatorId lands here
```

The `if` admits `IK_LiteralOperatorId` explicitly; the ternary only excludes
`IK_Identifier`. The garbage `OpKind` is then stored in the
`TemplateIdAnnotation`.

**2. `Parser::AnnotateTemplateIdToken`, `clang/lib/Parse/ParseTemplate.cpp:1155`**

```cpp
    OverloadedOperatorKind OpKind =
        TemplateName.getKind() == UnqualifiedIdKind::IK_Identifier
            ? OO_None
            : TemplateName.OperatorFunctionId.Operator;
```

No guard at all — every non-`IK_Identifier` kind reaching this function reads
`OperatorFunctionId.Operator`.

### Impact

Latent today, as far as we could tell: a literal-operator template-id such as

```cpp
template <char...> constexpr int operator""_x() { return 1; }
constexpr int a = operator""_x<'1', '2'>();
```

compiles clean, because resolution goes through the `TemplateName` and nothing
downstream consumes `TemplateIdAnnotation::Operator` for that kind. What is
being read is still an out-of-range enum value loaded from a pointer — the
sanitizer diagnostic in **#20143**, which reported this same read at a third
site, `Declarator::isStaticMember()` in `clang/lib/Sema/DeclSpec.cpp`. That one
is guarded today:

```cpp
         (getName().getKind() == UnqualifiedIdKind::IK_OperatorFunctionId &&
          CXXMethodDecl::isStaticOverloadedOperator(
              getName().OperatorFunctionId.Operator));
```

and `Sema::GetNameFromUnqualifiedId` switches on the kind properly. So the fix
shape is settled by precedent: test for `IK_OperatorFunctionId` rather than
merely excluding `IK_Identifier`, and pass `OO_None` otherwise.

The reason to fix it now rather than when it bites: the next person to add a
payload to that union — which is what surfaced this — inherits both reads, and
for a payload that is not a pointer the mirror mistake is a null dereference
rather than a benign junk enum. The `FIXME: Store name for literal operator
too.` immediately above site 1 is the same observation from the other side.
