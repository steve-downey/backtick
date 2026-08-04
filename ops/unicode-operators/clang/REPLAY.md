# Replay ledger — what can be lifted onto clean `main`

The experiment branch is based on `backtick-trunk`, which is not upstream.
The upstream Unicode patch must not require unlanded backtick changes
(U7, U12 — the two features must be able to have separate fates). This
ledger is how that stays true without anyone having to reconstruct it at
the end.

**Every step appends at least one row**, even if the row says "nothing
backtick-related". U19 audits the ledger against the actual diff; U20
executes it.

Classifications:

- `upstream replay` — lift the hunk onto clean `main` as-is.
- `backtick dependency` — works only because the backtick diff is present;
  a standalone equivalent must be written for `main`. Name it in the notes.
- `shared if landed` — reusable if backtick lands first; otherwise needs a
  standalone equivalent.

| Step | Files / hunks | Class | Standalone equivalent needed on `main` |
|------|---------------|-------|----------------------------------------|
