# Handoffs — backlog defect-fix track

One file per completed step, named `BLNN-<slug>.handoff.md`, copied from
`ops/HANDOFF_TEMPLATE.md` and filled in per `ops/AGENT_PROTOCOL.md` step 6.

Two things differ from the feature tracks:

- **A step here closes `BNN` rows, not a feature increment.** Say which rows,
  and fill their `Closed by` cells in `ops/BACKLOG.md` in the same commit.
  A row closed with no evidence is worse than an open one.
- **Deviations go to the ledger of whichever track the step touched** —
  `ops/DEVIATIONS.md`, `ops/gcc/DEVIATIONS.md`, or
  `ops/unicode-operators/clang/DEVIATIONS.md`. This track has no ledger of
  its own, because a defect fix is a correction to an existing track's
  record, not a new source of design surprise.

Steps that touch a Unicode branch also append a `REPLAY.md` row. Steps that
touch a Clang branch write **two** Status-log rows, one per branch — a clean
cherry-pick is not proof of a passing gate.
