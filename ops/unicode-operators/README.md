# Unicode Operators Experiment Plans

These plans turn `docs/unicode-operators.md` into concrete implementation
work for LLVM/Clang and GCC.

The backtick branches are useful experiment bases because they already prove
the shared user-infix precedence decision and expose compiler-specific parser
hazards. They are not intended to become required upstream dependencies for
Unicode operators. Once a prototype works, replay the minimum Unicode patch
stack onto clean upstream branches unless backtick has landed first.

- [LLVM/Clang experiment plan](clang-experiment-plan.md) — narrative
  rationale (branch strategy, replay assumptions, scope)
- [GCC experiment plan](gcc-experiment-plan.md) — same, for GCC

The Clang track's *operational* document — the one an agent reads — is
[`clang/PLAN.md`](clang/PLAN.md): the U00–U20 checklist with dependencies,
one self-contained step file per step under `clang/steps/`, handoffs in
`clang/handoffs/`, and two ledgers (`clang/DEVIATIONS.md`,
`clang/REPLAY.md`). It runs on `ops/AGENT_PROTOCOL.md`, one step per agent,
exactly as the backtick tracks did. The GCC track has no step machinery
yet; recast `gcc-experiment-plan.md` the same way when it starts.
