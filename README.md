# backtick

Design documents, papers, and implementation records for two WG21 proposals.

## Papers

In org-mode, built with the vendored wg21org exporter; the Unicode paper as
mailed, the backtick paper as mailed plus R2's wording for module names:

- [D4307R2 — An Infix Operator and a Keyword Escape for C++](papers/backtick-infix-and-keyword-escape.org)
- [D4345R1 — Extending C++ with Unicode Mathematical Operators](papers/unicode-mathematical-operators.org)

`make papers` builds both as HTML and PDF; `make -C papers help` lists the
other targets.

The markdown files beside them are the pre-mailing drafts, which still build
with `make -C papers -f mpark.mk html pdf`:
[the infix operator](papers/backtick-infix-operator.md),
[the keyword escape](papers/backtick-keyword-escape.md) (split out for a
while, and folded back in for the mailing), and
[the Unicode operators](papers/unicode-mathematical-operators.md).

## Implementations

- LLVM/Clang: [steve-downey/llvm-project](https://github.com/steve-downey/llvm-project)
  - [`backtick-trunk`](https://github.com/steve-downey/llvm-project/tree/backtick-trunk)
    — the backtick operator and keyword escape, on LLVM main.
  - [`backtick-23`](https://github.com/steve-downey/llvm-project/tree/backtick-23)
    — the same feature on the LLVM 23 release branch.
  - [`unicode-operators-experiment`](https://github.com/steve-downey/llvm-project/tree/unicode-operators-experiment)
    — Unicode operators, built on top of `backtick-trunk`.
  - [`unicode-operators-upstream`](https://github.com/steve-downey/llvm-project/tree/unicode-operators-upstream)
    — Unicode operators alone, on LLVM main, with no backtick code.
- GCC: [steve-downey/gcc](https://github.com/steve-downey/gcc)
  - [`backtick`](https://github.com/steve-downey/gcc/tree/backtick)
    — the backtick operator and keyword escape, on GCC trunk.

## Layout

- `papers/` — the papers.
- `docs/` — design documents.
- `probes/` — scripts that sweep both compilers for the keyword escape's coverage,
  error paths, and flag-off parity.
- `build/` — configure scripts for the prototype compilers.
- `examples/` — sample code built with the prototype compilers, from
  [steve-downey/backtick-examples](https://github.com/steve-downey/backtick-examples).

## License

- Code: Apache 2.0, [LICENSE](LICENSE).
- Papers: CC BY 4.0, [LICENSE-CC-BY](LICENSE-CC-BY).
- Other documentation of the code: CC0 1.0, [LICENSE-CC0](LICENSE-CC0).

Vendored subtrees (`papers/wg21/`, `examples/`) carry their own licenses.
