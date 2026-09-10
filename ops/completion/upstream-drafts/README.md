# Upstream reports — drafted, not filed

Six defects found in passing are LLVM's, not this feature's.
[upstream-reports](../steps/upstream-reports.md) and
[upstream-triage](../steps/upstream-triage.md) were written to file them as
issues on `llvm/llvm-project`. **The author decided otherwise: the steps draft
the reports and the maintainer files them.** Nothing in this directory has been
posted to any issue tracker.

One file per defect, named by its slug, each carrying the title and body as
they should appear, the trunk revision the defect was confirmed against, and
the existing-issue search that was run before writing it:

| Draft | Defect | From | What it reports |
|---|---|---|---|
| [increment-decrement-mangling](increment-decrement-mangling.md) | [`increment-decrement-mangling`](../../BACKLOG.md#increment-decrement-mangling) | [upstream-reports](../steps/upstream-reports.md) | Clang mangles prefix and postfix `++`/`--` identically inside an `<expression>`; the ABI and GCC spell prefix `pp_`/`mm_`. |
| [clangir-lvalue-crash](clangir-lvalue-crash.md) | [`clangir-lvalue-crash`](../../BACKLOG.md#clangir-lvalue-crash) | [upstream-reports](../steps/upstream-reports.md) | `CIRGenFunction::emitLValue` returns a default-constructed `LValue` after `errorNYI`, so 21 not-yet-implemented l-value arms crash instead of diagnosing. |
| [unqualified-id-union-read](unqualified-id-union-read.md) | [`unqualified-id-union-read`](../../BACKLOG.md#unqualified-id-union-read) | [upstream-reports](../steps/upstream-reports.md) | Two parser sites read `UnqualifiedId::OperatorFunctionId.Operator` for `IK_LiteralOperatorId`, where `Identifier` is the active member. |
| [cxxfilt-stdin-nonascii](cxxfilt-stdin-nonascii.md) | [`cxxfilt-stdin-nonascii`](../../BACKLOG.md#cxxfilt-stdin-nonascii) | [upstream-triage](../steps/upstream-triage.md) | `llvm-cxxfilt`'s stdin splitter treats every non-ASCII byte as a delimiter, so a symbol with an extended identifier demangles from argv and not from a pipe. |
| [auto-return-round-trip](auto-return-round-trip.md) | [`auto-return-round-trip`](../../BACKLOG.md#auto-return-round-trip) | [upstream-triage](../steps/upstream-triage.md) | `-ast-print` prints a specialization of an `auto`-returning function template with the deduced return type, so the printed source no longer matches its own primary template and does not compile. |
| [pch-ast-print-order](pch-ast-print-order.md) | [`pch-ast-print-order`](../../BACKLOG.md#pch-ast-print-order) | [upstream-triage](../steps/upstream-triage.md) | Both external-storage loaders splice at the head of the `DeclContext` chain, so a deserialized record whose fields loaded first prints them last. Probably a comment on the open **#24794** rather than a new issue. |

## The consequence, stated plainly

**None of these backlog rows closes until the maintainer posts them.** Each
row's `Closed by` says so and links here. Two later steps want an issue number
that does not exist yet:

- [mangling-abi](../steps/mangling-abi.md) is scheduled to depend on
  [upstream-reports](../steps/upstream-reports.md) precisely so it can cite the
  `pp_`/`pp` issue.
- [unicode-paper](../steps/unicode-paper.md) inherits the same want through it.

Until then, every place that would carry the number carries the literal token
**`LLVM-ISSUE-PENDING`** instead. Filing the reports and replacing that token
is one grep:

```console
$ grep -rn LLVM-ISSUE-PENDING docs papers ops
```

The papers currently say "we found a Clang bug" without being able to say which
one. That is the cost of not filing, and it is visible rather than papered over.
Only [`increment-decrement-mangling`](../../BACKLOG.md#increment-decrement-mangling)
has substitution points; the other five are cited nowhere outside `ops/`, so
filing them costs no document edit.

## The seventh report, which is not here

[upstream-triage](../steps/upstream-triage.md) was also assigned the upstream
half of [`dependent-template-operator-id`](../../BACKLOG.md#dependent-template-operator-id),
to be filed against the literal-operator reproducer
`t.template operator""_lit<int>(0)`. **There is no draft, because that report
would be wrong.** Clang's rejection of that construct is correct behaviour, not
a limitation — a literal operator can never be a class member ([over.literal]/1),
so the construct names nothing that could exist, and trunk says so at the site
in a comment. The finding is written up in
[`docs/open-decisions.md`](../../../docs/open-decisions.md#dependent-template-operator-id),
where it reopens the question rather than answering it.
