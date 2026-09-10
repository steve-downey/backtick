# SLUGS — the map from retired serial numbers to slugs

Every internal identifier in this repo used to be a serial number. A serial
number is unique and nothing else: it does not say what the thing is, it does
not survive its list being reordered, and a reader who meets it has to go and
look it up. This file retires them. See `~/.claude/CLAUDE.md`, "Name things for
what they are, not what number they came in at", and
`ops/completion/steps/slug-the-ledgers.md`, the step that did it.

A slug names **the question, or the job — never the answer**, so that answering
an open question graduates it in place and every existing link stays valid.

Each entry now lives in a section headed by its slug, so the slug is a Markdown
anchor and every cross-reference is a link to it. The old number survives inside
the entry on a `Formerly:` line, because forty handoffs still say `DEV-U13` and
those are not rewritten.

## What was *not* renamed, and why

**The completed tracks' step ids stay: `S00`–`S12`, `G01`–`G10`, `U00`–`U21`,
`BL01`–`BL04`, and the maintenance ids `M1`, `M2`, `R23`, `R24`, `F23`, `F24`.**
They are a closed historical record. They appear in commit messages that cannot
be rewritten, and the handoff filenames under `ops/handoffs/`,
`ops/gcc/handoffs/`, `ops/unicode-operators/clang/handoffs/` and
`ops/backlog/handoffs/` are the only index into forty documents. Renaming them
buys nothing and costs `git log --grep`.

**The historical documents are not rewritten either** — every `handoffs/`
directory, the completed tracks' step files (`ops/steps/`, `ops/gcc/steps/`,
`ops/unicode-operators/clang/steps/`, `ops/backlog/steps/BL01`–`BL04`), their
`PLAN.md`s, and `ops/unicode-operators/clang/REPLAY.md`. They record what an
agent knew at the time; editing them to use names that did not then exist would
make them lie. **This is a decision, not an oversight**, and it is why the
verification grep for retired identifiers is scoped to `docs/`, `papers/`,
`ops/*.md` and `ops/completion/` — the live documents — plus the three
deviation ledgers wherever they live. Read an old handoff with this file open.

`ops/backlog/steps/BL05`–`BL07` are the exception among the step files: they are
unexecuted and `ops/completion/PLAN.md` schedules them, so they are live and
they were rewritten.

**`docs/pattern-syntax-audit.py` keeps its numbers too, and this one is not
about history.** The generator's comments say `U1` and `U10`, and it *emits*
those strings into the header it generates — `UnicodeOperatorCharSets.h`, which
is committed on all four LLVM branches. Renaming them in the script would make
the regenerated header differ byte-for-byte from the one that shipped, for no
reason but a name, and the reproducibility claim the paper wants rests on that
file regenerating identically. Whoever regenerates the tables gets to decide
whether to spend that diff; until then the script is deliberately out of step.
The slugs it wants are [`token-set`](../docs/unicode-operators.md#token-set) for
`U1` and
[`operator-identifier-disjointness`](../docs/unicode-operators.md#operator-identifier-disjointness)
for `U10`.

## One deliberate collision

`null-return-suppression` is both a defect and the completion step that fixes
it. That is the naming convention working, not a clash: the step is named for
the job, and the job is that defect.

## Backtick design decisions

Home: `docs/backtick-operator-design.md`

| Formerly | Slug | Entry |
|---|---|---|
| `D1` | `chaining-associativity` | [decision](../docs/backtick-operator-design.md#chaining-associativity) |
| `D2` | `precedence-level` | [decision](../docs/backtick-operator-design.md#precedence-level) |
| `D3` | `nesting-vs-chaining` | [decision](../docs/backtick-operator-design.md#nesting-vs-chaining) |
| `D4` | `slot-grammar` | [decision](../docs/backtick-operator-design.md#slot-grammar) |
| `D5` | `feature-gating` | [decision](../docs/backtick-operator-design.md#feature-gating) |
| `D6` | `desugaring-target` | [decision](../docs/backtick-operator-design.md#desugaring-target) |
| `D7` | `source-fidelity-node` | [decision](../docs/backtick-operator-design.md#source-fidelity-node) |
| `D8` | `format-break-policy` | [decision](../docs/backtick-operator-design.md#format-break-policy) |
| `D9` | `braced-init-operands` | [decision](../docs/backtick-operator-design.md#braced-init-operands) |
| `D10` | `keyword-escape-coexistence` | [decision](../docs/backtick-operator-design.md#keyword-escape-coexistence) |
| `D11` | `alternative-spellings` | [decision](../docs/backtick-operator-design.md#alternative-spellings) |
| `D12` | `pipeline-operator-relation` | [decision](../docs/backtick-operator-design.md#pipeline-operator-relation) |
| `D13` | `library-scope` | [decision](../docs/backtick-operator-design.md#library-scope) |
| `D14` | `paper-bundling` | [decision](../docs/backtick-operator-design.md#paper-bundling) |
| `D15` | `evaluation-order` | [decision](../docs/backtick-operator-design.md#evaluation-order) |
| `D16` | `type-name-slot` | [decision](../docs/backtick-operator-design.md#type-name-slot) |

## Unicode design decisions

Home: `docs/unicode-operators.md`

| Formerly | Slug | Entry |
|---|---|---|
| `U1` | `token-set` | [decision](../docs/unicode-operators.md#token-set) |
| `U2` | `operator-function-id` | [decision](../docs/unicode-operators.md#operator-function-id) |
| `U3` | `lexing-and-declarations` | [decision](../docs/unicode-operators.md#lexing-and-declarations) |
| `U4` | `user-infix-precedence` | [decision](../docs/unicode-operators.md#user-infix-precedence) |
| `U5` | `unary-forms` | [decision](../docs/unicode-operators.md#unary-forms) |
| `U6` | `candidate-assembly` | [decision](../docs/unicode-operators.md#candidate-assembly) |
| `U7` | `unicode-feature-gating` | [decision](../docs/unicode-operators.md#unicode-feature-gating) |
| `U8` | `operator-mangling` | [decision](../docs/unicode-operators.md#operator-mangling) |
| `U9` | `user-declared-fixity` | [decision](../docs/unicode-operators.md#user-declared-fixity) |
| `U10` | `operator-identifier-disjointness` | [decision](../docs/unicode-operators.md#operator-identifier-disjointness) |
| `U11` | `ucn-spellings` | [decision](../docs/unicode-operators.md#ucn-spellings) |
| `U12` | `paper-separation` | [decision](../docs/unicode-operators.md#paper-separation) |

## Backtick deviations (Clang)

Home: `ops/DEVIATIONS.md`

| Formerly | Slug | Entry |
|---|---|---|
| `DEV-01` | `options-td-path` | [deviation](DEVIATIONS.md#options-td-path) |
| `DEV-02` | `langopt-macro-arity` | [deviation](DEVIATIONS.md#langopt-macro-arity) |
| `DEV-03` | `driver-flag-forwarding` | [deviation](DEVIATIONS.md#driver-flag-forwarding) |
| `DEV-04` | `bare-nesting-detection` | [deviation](DEVIATIONS.md#bare-nesting-detection) |
| `DEV-05` | `backtick-source-locations` | [deviation](DEVIATIONS.md#backtick-source-locations) |
| `DEV-06` | `wrapper-inner-shape` | [deviation](DEVIATIONS.md#wrapper-inner-shape) |

> **`DEV-06` was assigned twice, on two branches.** This map's `DEV-06` is
> `wrapper-inner-shape`. The `main` branch independently used `DEV-06` for a
> *different* defect, a type name in the operator slot, in a row added after
> this branch had already re-slugged the ledger. That row's substance now
> lives in [`type-slot-cost`](DEVIATIONS.md#type-slot-cost) (Clang, which
> implements it) and [`gcc-type-slot-parity`](gcc/DEVIATIONS.md#gcc-type-slot-parity)
> (GCC, which does not), so nothing is lost — but a reader following `DEV-06`
> out of `main`'s history lands on the wrong entry. **This is the failure the
> slug convention exists to prevent**, caught in a merge rather than by
> inspection, and it is the strongest argument in this file for the rename.

| `DEV-07` | `analysis-layer-sites` | [deviation](DEVIATIONS.md#analysis-layer-sites) |
| `DEV-08` | `type-slot-cost` | [deviation](DEVIATIONS.md#type-slot-cost) |
| `DEV-09` | `cir-backtick-arms` | [deviation](DEVIATIONS.md#cir-backtick-arms) |

## Backtick deviations (GCC)

Home: `ops/gcc/DEVIATIONS.md`

| Formerly | Slug | Entry |
|---|---|---|
| `DEV-G04` | `gcc-bare-nesting-detection` | [deviation](gcc/DEVIATIONS.md#gcc-bare-nesting-detection) |
| `DEV-G05` | `gcc-slot-adl` | [deviation](gcc/DEVIATIONS.md#gcc-slot-adl) |
| `DEV-G06a` | `gcc-precedence-placement` | [deviation](gcc/DEVIATIONS.md#gcc-precedence-placement) |
| `DEV-G06b` | `gcc-tree-canonicalisation` | [deviation](gcc/DEVIATIONS.md#gcc-tree-canonicalisation) |
| `DEV-G06c` | `gcc-ternary-normalisation` | [deviation](gcc/DEVIATIONS.md#gcc-ternary-normalisation) |
| `DEV-G07a` | `gcc-keyword-declarator` | [deviation](gcc/DEVIATIONS.md#gcc-keyword-declarator) |
| `DEV-G08` | `gcc-type-slot-parity` | [deviation](gcc/DEVIATIONS.md#gcc-type-slot-parity) |
| `DEV-G11` | `gcc-dependent-slot-lookup` | [deviation](gcc/DEVIATIONS.md#gcc-dependent-slot-lookup) — from `main`, never slugged there |
| `DEV-G12` | `gcc-type-slot-parity` | folded in; `main`'s row recorded GCC's diagnostic, which that entry now carries |

## Unicode deviations (Clang)

Home: `ops/unicode-operators/clang/DEVIATIONS.md`

| Formerly | Slug | Entry |
|---|---|---|
| `DEV-U01` | `ucd-version-drift` | [deviation](unicode-operators/clang/DEVIATIONS.md#ucd-version-drift) |
| `DEV-U02` | `disjointness-evidence` | [deviation](unicode-operators/clang/DEVIATIONS.md#disjointness-evidence) |
| `DEV-U03` | `exclusion-list-derivation` | [deviation](unicode-operators/clang/DEVIATIONS.md#exclusion-list-derivation) |
| `DEV-U04` | `declaration-name-plumbing` | [deviation](unicode-operators/clang/DEVIATIONS.md#declaration-name-plumbing) |
| `DEV-U05` | `declaring-side-parse-cost` | [deviation](unicode-operators/clang/DEVIATIONS.md#declaring-side-parse-cost) |
| `DEV-U06` | `over-oper-restrictions` | [deviation](unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions) |
| `DEV-U07` | `flag-language-mode` | [deviation](unicode-operators/clang/DEVIATIONS.md#flag-language-mode) |
| `DEV-U08` | `vendor-extended-mangling` | [deviation](unicode-operators/clang/DEVIATIONS.md#vendor-extended-mangling) |
| `DEV-U09` | `msvc-mangling` | [deviation](unicode-operators/clang/DEVIATIONS.md#msvc-mangling) |
| `DEV-U10` | `operator-id-anywhere` | [deviation](unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere) |
| `DEV-U11` | `infix-parse-cost` | [deviation](unicode-operators/clang/DEVIATIONS.md#infix-parse-cost) |
| `DEV-U12` | `operator-candidate-assembly` | [deviation](unicode-operators/clang/DEVIATIONS.md#operator-candidate-assembly) |
| `DEV-U13` | `expression-node-cost` | [deviation](unicode-operators/clang/DEVIATIONS.md#expression-node-cost) |
| `DEV-U14` | `serialization-tooling-cost` | [deviation](unicode-operators/clang/DEVIATIONS.md#serialization-tooling-cost) |
| `DEV-U15` | `prefix-arity-selection` | [deviation](unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection) |
| `DEV-U16` | `operand-sequencing` | [deviation](unicode-operators/clang/DEVIATIONS.md#operand-sequencing) |
| `DEV-U17` | `ast-node-shape` | [deviation](unicode-operators/clang/DEVIATIONS.md#ast-node-shape) |
| `DEV-U18` | `ucn-operator-spellings` | [deviation](unicode-operators/clang/DEVIATIONS.md#ucn-operator-spellings) |
| `DEV-U19` | `exclusion-diagnostics` | [deviation](unicode-operators/clang/DEVIATIONS.md#exclusion-diagnostics) |
| `DEV-U20` | `clang-format-user-operators` | [deviation](unicode-operators/clang/DEVIATIONS.md#clang-format-user-operators) |
| `DEV-U21` | `feature-coupling` | [deviation](unicode-operators/clang/DEVIATIONS.md#feature-coupling) |
| `DEV-U22` | `replay-ordering` | [deviation](unicode-operators/clang/DEVIATIONS.md#replay-ordering) |
| `DEV-U23` | `postfix-operators` | [deviation](unicode-operators/clang/DEVIATIONS.md#postfix-operators) |
| `DEV-U24` | `codegen-dispatch-sites` | [deviation](unicode-operators/clang/DEVIATIONS.md#codegen-dispatch-sites) |

## Defects

Home: `ops/BACKLOG.md`

| Formerly | Slug | Entry |
|---|---|---|
| `B01` | `type-slot-implementation` | [defect](BACKLOG.md#type-slot-implementation) |
| `B02` | `keyword-escape-round-trip` | [defect](BACKLOG.md#keyword-escape-round-trip) |
| `B03` | `c-mode-tokenization` | [defect](BACKLOG.md#c-mode-tokenization) |
| `B04` | `backtick-source-range` | [defect](BACKLOG.md#backtick-source-range) |
| `B05` | `backtick-ast-matchers` | [defect](BACKLOG.md#backtick-ast-matchers) |
| `B06` | `dead-nesting-diagnostic` | [defect](BACKLOG.md#dead-nesting-diagnostic) |
| `B07` | `slot-split-penalty` | [defect](BACKLOG.md#slot-split-penalty) |
| `B08` | `template-ast-print-test` | [defect](BACKLOG.md#template-ast-print-test) |
| `B09` | `template-id-slot-adl` | [defect](BACKLOG.md#template-id-slot-adl) |
| `B10` | `module-streaming-escapes` | [defect](BACKLOG.md#module-streaming-escapes) |
| `B11` | `grokdeclarator-guard-scope` | [defect](BACKLOG.md#grokdeclarator-guard-scope) |
| `B12` | `gcc-wrapper-parity` | [defect](BACKLOG.md#gcc-wrapper-parity) |
| `B13` | `gcc-trunk-pin` | [defect](BACKLOG.md#gcc-trunk-pin) |
| `B14` | `unicode-analyzer-sites` | [defect](BACKLOG.md#unicode-analyzer-sites) |
| `B15` | `clangir-unicode-arms` | [defect](BACKLOG.md#clangir-unicode-arms) |
| `B16` | `lldb-hunk-verification` | [defect](BACKLOG.md#lldb-hunk-verification) |
| `B17` | `code-completion-priority` | [defect](BACKLOG.md#code-completion-priority) |
| `B18` | `template-id-code-point` | [defect](BACKLOG.md#template-id-code-point) |
| `B19` | `matcher-operator-name` | [defect](BACKLOG.md#matcher-operator-name) |
| `B20` | `astral-plane-mangling` | [defect](BACKLOG.md#astral-plane-mangling) |
| `B21` | `ucd-input-manifest` | [defect](BACKLOG.md#ucd-input-manifest) |
| `B22` | `confusable-spellings` | [defect](BACKLOG.md#confusable-spellings) |
| `B23` | `dependent-template-operator-id` | [defect](BACKLOG.md#dependent-template-operator-id) |
| `B24` | `inner-call-source-range` | [defect](BACKLOG.md#inner-call-source-range) |
| `B25` | `increment-decrement-mangling` | [defect](BACKLOG.md#increment-decrement-mangling) |
| `B26` | `unqualified-id-union-read` | [defect](BACKLOG.md#unqualified-id-union-read) |
| `B27` | `cxxfilt-stdin-nonascii` | [defect](BACKLOG.md#cxxfilt-stdin-nonascii) |
| `B28` | `auto-return-round-trip` | [defect](BACKLOG.md#auto-return-round-trip) |
| `B29` | `pch-ast-print-order` | [defect](BACKLOG.md#pch-ast-print-order) |
| `B30` | `operator-caret-range` | [defect](BACKLOG.md#operator-caret-range) |
| `B31` | `inotify-watch-budget` | [defect](BACKLOG.md#inotify-watch-budget) |
| `B32` | `clang-executable-version` | [defect](BACKLOG.md#clang-executable-version) |
| `B33` | `stray-clang-format-config` | [defect](BACKLOG.md#stray-clang-format-config) |
| `B34` | `gcc-libstdcxx-build` | [defect](BACKLOG.md#gcc-libstdcxx-build) |
| `B35` | `libclang-cursor-arm` | [defect](BACKLOG.md#libclang-cursor-arm) |
| `B36` | `clangir-backtick-arms` | [defect](BACKLOG.md#clangir-backtick-arms) |
| `B37` | `null-return-suppression` | [defect](BACKLOG.md#null-return-suppression) |
| `B38` | `clangir-lvalue-crash` | [defect](BACKLOG.md#clangir-lvalue-crash) |

## Slug to number

| Slug | Formerly | Home |
|---|---|---|
| [`alternative-spellings`](../docs/backtick-operator-design.md#alternative-spellings) | `D11` | `docs/backtick-operator-design.md` |
| [`analysis-layer-sites`](DEVIATIONS.md#analysis-layer-sites) | `DEV-07` | `ops/DEVIATIONS.md` |
| [`ast-node-shape`](unicode-operators/clang/DEVIATIONS.md#ast-node-shape) | `DEV-U17` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`astral-plane-mangling`](BACKLOG.md#astral-plane-mangling) | `B20` | `ops/BACKLOG.md` |
| [`auto-return-round-trip`](BACKLOG.md#auto-return-round-trip) | `B28` | `ops/BACKLOG.md` |
| [`backtick-ast-matchers`](BACKLOG.md#backtick-ast-matchers) | `B05` | `ops/BACKLOG.md` |
| [`backtick-source-locations`](DEVIATIONS.md#backtick-source-locations) | `DEV-05` | `ops/DEVIATIONS.md` |
| [`backtick-source-range`](BACKLOG.md#backtick-source-range) | `B04` | `ops/BACKLOG.md` |
| [`bare-nesting-detection`](DEVIATIONS.md#bare-nesting-detection) | `DEV-04` | `ops/DEVIATIONS.md` |
| [`braced-init-operands`](../docs/backtick-operator-design.md#braced-init-operands) | `D9` | `docs/backtick-operator-design.md` |
| [`c-mode-tokenization`](BACKLOG.md#c-mode-tokenization) | `B03` | `ops/BACKLOG.md` |
| [`candidate-assembly`](../docs/unicode-operators.md#candidate-assembly) | `U6` | `docs/unicode-operators.md` |
| [`chaining-associativity`](../docs/backtick-operator-design.md#chaining-associativity) | `D1` | `docs/backtick-operator-design.md` |
| [`cir-backtick-arms`](DEVIATIONS.md#cir-backtick-arms) | `DEV-09` | `ops/DEVIATIONS.md` |
| [`clang-executable-version`](BACKLOG.md#clang-executable-version) | `B32` | `ops/BACKLOG.md` |
| [`clang-format-user-operators`](unicode-operators/clang/DEVIATIONS.md#clang-format-user-operators) | `DEV-U20` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`clangir-backtick-arms`](BACKLOG.md#clangir-backtick-arms) | `B36` | `ops/BACKLOG.md` |
| [`clangir-lvalue-crash`](BACKLOG.md#clangir-lvalue-crash) | `B38` | `ops/BACKLOG.md` |
| [`clangir-unicode-arms`](BACKLOG.md#clangir-unicode-arms) | `B15` | `ops/BACKLOG.md` |
| [`code-completion-priority`](BACKLOG.md#code-completion-priority) | `B17` | `ops/BACKLOG.md` |
| [`codegen-dispatch-sites`](unicode-operators/clang/DEVIATIONS.md#codegen-dispatch-sites) | `DEV-U24` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`confusable-spellings`](BACKLOG.md#confusable-spellings) | `B22` | `ops/BACKLOG.md` |
| [`cxxfilt-stdin-nonascii`](BACKLOG.md#cxxfilt-stdin-nonascii) | `B27` | `ops/BACKLOG.md` |
| [`dead-nesting-diagnostic`](BACKLOG.md#dead-nesting-diagnostic) | `B06` | `ops/BACKLOG.md` |
| [`declaration-name-plumbing`](unicode-operators/clang/DEVIATIONS.md#declaration-name-plumbing) | `DEV-U04` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`declaring-side-parse-cost`](unicode-operators/clang/DEVIATIONS.md#declaring-side-parse-cost) | `DEV-U05` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`dependent-template-operator-id`](BACKLOG.md#dependent-template-operator-id) | `B23` | `ops/BACKLOG.md` |
| [`desugaring-target`](../docs/backtick-operator-design.md#desugaring-target) | `D6` | `docs/backtick-operator-design.md` |
| [`disjointness-evidence`](unicode-operators/clang/DEVIATIONS.md#disjointness-evidence) | `DEV-U02` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`driver-flag-forwarding`](DEVIATIONS.md#driver-flag-forwarding) | `DEV-03` | `ops/DEVIATIONS.md` |
| [`evaluation-order`](../docs/backtick-operator-design.md#evaluation-order) | `D15` | `docs/backtick-operator-design.md` |
| [`exclusion-diagnostics`](unicode-operators/clang/DEVIATIONS.md#exclusion-diagnostics) | `DEV-U19` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`exclusion-list-derivation`](unicode-operators/clang/DEVIATIONS.md#exclusion-list-derivation) | `DEV-U03` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`expression-node-cost`](unicode-operators/clang/DEVIATIONS.md#expression-node-cost) | `DEV-U13` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`feature-coupling`](unicode-operators/clang/DEVIATIONS.md#feature-coupling) | `DEV-U21` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`feature-gating`](../docs/backtick-operator-design.md#feature-gating) | `D5` | `docs/backtick-operator-design.md` |
| [`flag-language-mode`](unicode-operators/clang/DEVIATIONS.md#flag-language-mode) | `DEV-U07` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`format-break-policy`](../docs/backtick-operator-design.md#format-break-policy) | `D8` | `docs/backtick-operator-design.md` |
| [`gcc-bare-nesting-detection`](gcc/DEVIATIONS.md#gcc-bare-nesting-detection) | `DEV-G04` | `ops/gcc/DEVIATIONS.md` |
| [`gcc-keyword-declarator`](gcc/DEVIATIONS.md#gcc-keyword-declarator) | `DEV-G07a` | `ops/gcc/DEVIATIONS.md` |
| [`gcc-libstdcxx-build`](BACKLOG.md#gcc-libstdcxx-build) | `B34` | `ops/BACKLOG.md` |
| [`gcc-precedence-placement`](gcc/DEVIATIONS.md#gcc-precedence-placement) | `DEV-G06a` | `ops/gcc/DEVIATIONS.md` |
| [`gcc-slot-adl`](gcc/DEVIATIONS.md#gcc-slot-adl) | `DEV-G05` | `ops/gcc/DEVIATIONS.md` |
| [`gcc-ternary-normalisation`](gcc/DEVIATIONS.md#gcc-ternary-normalisation) | `DEV-G06c` | `ops/gcc/DEVIATIONS.md` |
| [`gcc-tree-canonicalisation`](gcc/DEVIATIONS.md#gcc-tree-canonicalisation) | `DEV-G06b` | `ops/gcc/DEVIATIONS.md` |
| [`gcc-trunk-pin`](BACKLOG.md#gcc-trunk-pin) | `B13` | `ops/BACKLOG.md` |
| [`gcc-dependent-slot-lookup`](gcc/DEVIATIONS.md#gcc-dependent-slot-lookup) | `DEV-G11` | `ops/gcc/DEVIATIONS.md` |
| [`gcc-type-slot-parity`](gcc/DEVIATIONS.md#gcc-type-slot-parity) | `DEV-G08`, `DEV-G12` | `ops/gcc/DEVIATIONS.md` |
| [`gcc-wrapper-parity`](BACKLOG.md#gcc-wrapper-parity) | `B12` | `ops/BACKLOG.md` |
| [`grokdeclarator-guard-scope`](BACKLOG.md#grokdeclarator-guard-scope) | `B11` | `ops/BACKLOG.md` |
| [`increment-decrement-mangling`](BACKLOG.md#increment-decrement-mangling) | `B25` | `ops/BACKLOG.md` |
| [`infix-parse-cost`](unicode-operators/clang/DEVIATIONS.md#infix-parse-cost) | `DEV-U11` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`inner-call-source-range`](BACKLOG.md#inner-call-source-range) | `B24` | `ops/BACKLOG.md` |
| [`inotify-watch-budget`](BACKLOG.md#inotify-watch-budget) | `B31` | `ops/BACKLOG.md` |
| [`keyword-escape-coexistence`](../docs/backtick-operator-design.md#keyword-escape-coexistence) | `D10` | `docs/backtick-operator-design.md` |
| [`keyword-escape-round-trip`](BACKLOG.md#keyword-escape-round-trip) | `B02` | `ops/BACKLOG.md` |
| [`langopt-macro-arity`](DEVIATIONS.md#langopt-macro-arity) | `DEV-02` | `ops/DEVIATIONS.md` |
| [`lexing-and-declarations`](../docs/unicode-operators.md#lexing-and-declarations) | `U3` | `docs/unicode-operators.md` |
| [`libclang-cursor-arm`](BACKLOG.md#libclang-cursor-arm) | `B35` | `ops/BACKLOG.md` |
| [`library-scope`](../docs/backtick-operator-design.md#library-scope) | `D13` | `docs/backtick-operator-design.md` |
| [`lldb-hunk-verification`](BACKLOG.md#lldb-hunk-verification) | `B16` | `ops/BACKLOG.md` |
| [`matcher-operator-name`](BACKLOG.md#matcher-operator-name) | `B19` | `ops/BACKLOG.md` |
| [`module-streaming-escapes`](BACKLOG.md#module-streaming-escapes) | `B10` | `ops/BACKLOG.md` |
| [`msvc-mangling`](unicode-operators/clang/DEVIATIONS.md#msvc-mangling) | `DEV-U09` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`nesting-vs-chaining`](../docs/backtick-operator-design.md#nesting-vs-chaining) | `D3` | `docs/backtick-operator-design.md` |
| [`null-return-suppression`](BACKLOG.md#null-return-suppression) | `B37` | `ops/BACKLOG.md` |
| [`operand-sequencing`](unicode-operators/clang/DEVIATIONS.md#operand-sequencing) | `DEV-U16` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`operator-candidate-assembly`](unicode-operators/clang/DEVIATIONS.md#operator-candidate-assembly) | `DEV-U12` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`operator-caret-range`](BACKLOG.md#operator-caret-range) | `B30` | `ops/BACKLOG.md` |
| [`operator-function-id`](../docs/unicode-operators.md#operator-function-id) | `U2` | `docs/unicode-operators.md` |
| [`operator-id-anywhere`](unicode-operators/clang/DEVIATIONS.md#operator-id-anywhere) | `DEV-U10` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`operator-identifier-disjointness`](../docs/unicode-operators.md#operator-identifier-disjointness) | `U10` | `docs/unicode-operators.md` |
| [`operator-mangling`](../docs/unicode-operators.md#operator-mangling) | `U8` | `docs/unicode-operators.md` |
| [`options-td-path`](DEVIATIONS.md#options-td-path) | `DEV-01` | `ops/DEVIATIONS.md` |
| [`over-oper-restrictions`](unicode-operators/clang/DEVIATIONS.md#over-oper-restrictions) | `DEV-U06` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`paper-bundling`](../docs/backtick-operator-design.md#paper-bundling) | `D14` | `docs/backtick-operator-design.md` |
| [`paper-separation`](../docs/unicode-operators.md#paper-separation) | `U12` | `docs/unicode-operators.md` |
| [`pch-ast-print-order`](BACKLOG.md#pch-ast-print-order) | `B29` | `ops/BACKLOG.md` |
| [`pipeline-operator-relation`](../docs/backtick-operator-design.md#pipeline-operator-relation) | `D12` | `docs/backtick-operator-design.md` |
| [`postfix-operators`](unicode-operators/clang/DEVIATIONS.md#postfix-operators) | `DEV-U23` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`precedence-level`](../docs/backtick-operator-design.md#precedence-level) | `D2` | `docs/backtick-operator-design.md` |
| [`prefix-arity-selection`](unicode-operators/clang/DEVIATIONS.md#prefix-arity-selection) | `DEV-U15` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`replay-ordering`](unicode-operators/clang/DEVIATIONS.md#replay-ordering) | `DEV-U22` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`serialization-tooling-cost`](unicode-operators/clang/DEVIATIONS.md#serialization-tooling-cost) | `DEV-U14` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`slot-grammar`](../docs/backtick-operator-design.md#slot-grammar) | `D4` | `docs/backtick-operator-design.md` |
| [`slot-split-penalty`](BACKLOG.md#slot-split-penalty) | `B07` | `ops/BACKLOG.md` |
| [`source-fidelity-node`](../docs/backtick-operator-design.md#source-fidelity-node) | `D7` | `docs/backtick-operator-design.md` |
| [`stray-clang-format-config`](BACKLOG.md#stray-clang-format-config) | `B33` | `ops/BACKLOG.md` |
| [`template-ast-print-test`](BACKLOG.md#template-ast-print-test) | `B08` | `ops/BACKLOG.md` |
| [`template-id-code-point`](BACKLOG.md#template-id-code-point) | `B18` | `ops/BACKLOG.md` |
| [`template-id-slot-adl`](BACKLOG.md#template-id-slot-adl) | `B09` | `ops/BACKLOG.md` |
| [`token-set`](../docs/unicode-operators.md#token-set) | `U1` | `docs/unicode-operators.md` |
| [`type-name-slot`](../docs/backtick-operator-design.md#type-name-slot) | `D16` | `docs/backtick-operator-design.md` |
| [`type-slot-cost`](DEVIATIONS.md#type-slot-cost) | `DEV-08` | `ops/DEVIATIONS.md` |
| [`type-slot-implementation`](BACKLOG.md#type-slot-implementation) | `B01` | `ops/BACKLOG.md` |
| [`ucd-input-manifest`](BACKLOG.md#ucd-input-manifest) | `B21` | `ops/BACKLOG.md` |
| [`ucd-version-drift`](unicode-operators/clang/DEVIATIONS.md#ucd-version-drift) | `DEV-U01` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`ucn-operator-spellings`](unicode-operators/clang/DEVIATIONS.md#ucn-operator-spellings) | `DEV-U18` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`ucn-spellings`](../docs/unicode-operators.md#ucn-spellings) | `U11` | `docs/unicode-operators.md` |
| [`unary-forms`](../docs/unicode-operators.md#unary-forms) | `U5` | `docs/unicode-operators.md` |
| [`unicode-analyzer-sites`](BACKLOG.md#unicode-analyzer-sites) | `B14` | `ops/BACKLOG.md` |
| [`unicode-feature-gating`](../docs/unicode-operators.md#unicode-feature-gating) | `U7` | `docs/unicode-operators.md` |
| [`unqualified-id-union-read`](BACKLOG.md#unqualified-id-union-read) | `B26` | `ops/BACKLOG.md` |
| [`user-declared-fixity`](../docs/unicode-operators.md#user-declared-fixity) | `U9` | `docs/unicode-operators.md` |
| [`user-infix-precedence`](../docs/unicode-operators.md#user-infix-precedence) | `U4` | `docs/unicode-operators.md` |
| [`vendor-extended-mangling`](unicode-operators/clang/DEVIATIONS.md#vendor-extended-mangling) | `DEV-U08` | `ops/unicode-operators/clang/DEVIATIONS.md` |
| [`wrapper-inner-shape`](DEVIATIONS.md#wrapper-inner-shape) | `DEV-06` | `ops/DEVIATIONS.md` |
