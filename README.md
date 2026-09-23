# backtick

Design documents, papers, and implementation records for two WG21 proposals.

## Papers

- [P4307R0 — An Infix Operator and a Keyword Escape for C++](papers/backtick-infix-and-keyword-escape.md)
- [P4345R0 — Extending C++ with Unicode Mathematical Operators](papers/unicode-mathematical-operators.md)

Build with `make -C papers <name>.html <name>.pdf`.

## Implementations

- LLVM/Clang: [steve-downey/llvm-project](https://github.com/steve-downey/llvm-project)
  - [`backtick-23`](https://github.com/steve-downey/llvm-project/tree/backtick-23)
  - [`backtick-trunk`](https://github.com/steve-downey/llvm-project/tree/backtick-trunk)
  - [`unicode-operators-experiment`](https://github.com/steve-downey/llvm-project/tree/unicode-operators-experiment)
- GCC: [steve-downey/gcc](https://github.com/steve-downey/gcc)
  - [`backtick`](https://github.com/steve-downey/gcc/tree/backtick)

## Layout

- `papers/` — the papers.
- `docs/` — design documents.
- `ops/` — implementation plans, handoffs, and deviation records.
- `examples/` — sample code built with the prototype compilers, from
  [steve-downey/backtick-examples](https://github.com/steve-downey/backtick-examples).

## License

- Code: Apache 2.0, [LICENSE](LICENSE).
- Papers: CC BY 4.0, [LICENSE-CC-BY](LICENSE-CC-BY).
- Other documentation of the code: CC0 1.0, [LICENSE-CC0](LICENSE-CC0).

Vendored subtrees (`papers/wg21/`, `examples/`) carry their own licenses.
