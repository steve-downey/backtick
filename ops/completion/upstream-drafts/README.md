# Upstream reports — drafted, not filed

Three defects found in passing are LLVM's, not this feature's.
[upstream-reports](../steps/upstream-reports.md) was written to file them as
issues on `llvm/llvm-project`. **The author decided otherwise: the step drafts
the reports and the maintainer files them.** Nothing in this directory has been
posted to any issue tracker.

One file per defect, named by its slug, each carrying the title and body as
they should appear, the trunk revision the defect was confirmed against, and
the existing-issue search that was run before writing it:

| Draft | Defect | What it reports |
|---|---|---|
| [increment-decrement-mangling](increment-decrement-mangling.md) | [`increment-decrement-mangling`](../../BACKLOG.md#increment-decrement-mangling) | Clang mangles prefix and postfix `++`/`--` identically inside an `<expression>`; the ABI and GCC spell prefix `pp_`/`mm_`. |
| [clangir-lvalue-crash](clangir-lvalue-crash.md) | [`clangir-lvalue-crash`](../../BACKLOG.md#clangir-lvalue-crash) | `CIRGenFunction::emitLValue` returns a default-constructed `LValue` after `errorNYI`, so 21 not-yet-implemented l-value arms crash instead of diagnosing. |
| [unqualified-id-union-read](unqualified-id-union-read.md) | [`unqualified-id-union-read`](../../BACKLOG.md#unqualified-id-union-read) | Two parser sites read `UnqualifiedId::OperatorFunctionId.Operator` for `IK_LiteralOperatorId`, where `Identifier` is the active member. |

## The consequence, stated plainly

**None of the three backlog rows closes until the maintainer posts them.** Each
row's `Closed by` says so and links here. Two later steps want an issue number
that does not exist yet:

- [mangling-abi](../steps/mangling-abi.md) is scheduled to depend on
  [upstream-reports](../steps/upstream-reports.md) precisely so it can cite the
  `pp_`/`pp` issue.
- [unicode-paper](../steps/unicode-paper.md) inherits the same want through it.

Until then, every place that would carry the number carries the literal token
**`LLVM-ISSUE-PENDING`** instead. Filing the three reports and replacing that
token is one grep:

```console
$ grep -rn LLVM-ISSUE-PENDING docs papers ops
```

The papers currently say "we found a Clang bug" without being able to say which
one. That is the cost of not filing, and it is visible rather than papered over.
