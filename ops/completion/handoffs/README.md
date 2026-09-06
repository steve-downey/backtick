# Handoffs — completion track

One file per completed step, named `CNN-<slug>.handoff.md`, copied from
`ops/HANDOFF_TEMPLATE.md` and filled in per `ops/AGENT_PROTOCOL.md` step 6.

Everything in `ops/backlog/handoffs/README.md` still applies — close `BNN`
rows in the same commit, send deviations to the touched track's ledger, two
Status rows per Clang step, a `REPLAY.md` row for anything on a Unicode
branch. Three things are specific to this track:

- **Most steps here are documents, not diffs.** Their gate is that every row
  they claim to close is *marked* in its ledger, naming the section and
  paragraph it landed in. Say the paragraph. "Reconciled into §8" is not
  evidence; "§8, the fourth bullet and the taxonomy paragraph after it" is.
- **A `Decide` step that ends BLOCKED on the author has succeeded.** Write the
  brief, attach it, stop. Do not choose on the author's behalf to have
  something to tick.
- **Say what you checked, not only what you changed.** Several steps close a
  row by *verifying it is not broken* — [`module-streaming-escapes`](../../BACKLOG.md#module-streaming-escapes)'s module streaming, [`ucd-input-manifest`](../../BACKLOG.md#ucd-input-manifest)'s
  regenerated tables. A verified-not-broken row is a real result and the
  handoff is the only place the verification exists.
