# Unicode Operators Experiment Plans

These plans turn `docs/unicode-operators.md` into concrete implementation
work for LLVM/Clang and GCC.

The backtick branches are useful experiment bases because they already prove
the shared user-infix precedence decision and expose compiler-specific parser
hazards. They are not intended to become required upstream dependencies for
Unicode operators. Once a prototype works, replay the minimum Unicode patch
stack onto clean upstream branches unless backtick has landed first.

- [LLVM/Clang experiment plan](clang-experiment-plan.md)
- [GCC experiment plan](gcc-experiment-plan.md)
