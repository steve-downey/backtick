# Agent protocol — read this first, every time

You are an independent agent with no prior context. You will do **exactly
one step** and stop. Follow this without improvising on process.

1. **Orient.** Read `ops/PLAN.md` in full. Pick the first unchecked step
   whose dependencies (listed beside it) are all checked. That is *your*
   step. If none qualifies, write nothing and report that the plan is
   blocked or complete.
2. **Load context.**
   - Read your step file `ops/steps/NN-*.md` completely.
   - Read the previous step's handoff in `ops/handoffs/` if one exists.
     Treat its "Forward notes" and "Discoveries" as authoritative — they
     override the step file where they conflict.
   - Read the design-doc sections your step file lists from
     `docs/backtick-operator-design.md`.
3. **Execute** the step's "Do" exactly. Keep the diff minimal and gated
   behind `-fbacktick`. If you must deviate, do the smallest thing that
   works and record why (step 6c).
4. **Gate.** Run the step's verification commands. Do **not** proceed unless
   every gate passes, including `check-clang` if the step requires it.
   - If the gate cannot pass: leave the checkbox unchecked, write a handoff
     with Status **BLOCKED** describing exactly where you stopped and what
     you tried, and STOP.
5. **Record green.** Tick your step's box in `ops/PLAN.md`, append one row
   to its Status log, and commit (`[backtick] SNN: <title>`).
6. **Hand off.** This is the part that makes the chain work:
   a. **Read the *next* step's file** `ops/steps/<next>.md` now.
   b. Copy `ops/HANDOFF_TEMPLATE.md` to `ops/handoffs/NN-<slug>.handoff.md`.
   c. Fill it in: what changed, verification evidence, deviations,
      discoveries — and, having just read the next step, write **specific
      forward notes** for the next agent (exact symbol names you found,
      paths that differed, gotchas, anything that will save them a
      discovery). Vague handoffs break the chain; be concrete.
   d. If anything contradicted the design doc, also append a row to
      `ops/DEVIATIONS.md`.
7. **Stop.** Do not begin the next step.

## Naming, for anything you add

**Name it, do not number it.** Every identifier this repo hands to a second
document — a decision, an open question, a deviation row, a backlog entry, a
plan step — is a **slug**: a short kebab-case name for *the question, or the
job*, never for the answer. `mangling-abi`, not `use-vendor-prefix`;
`nesting-vs-chaining`, not `bare-nesting-is-legal`. A slug named for a
conclusion has to be renamed the moment the conclusion reverses, which breaks
every reference to it at exactly the moment the work is under most pressure.
Named for the question, it survives being answered.

- Give the entry **a section headed by its slug**, so the slug is a Markdown
  anchor, in the ledger that owns it (`docs/backtick-operator-design.md` §3,
  `docs/unicode-operators.md` §2, the three `DEVIATIONS.md`, `ops/BACKLOG.md`).
- Make **every reference to it a link to that anchor**, not a bare mention.
  Links can be followed, and a rename becomes a detectable break rather than a
  silent one.
- An ordinal in a checklist is *reading order* and shifts when a step is
  inserted. Carry both if you like — `Stage 3 — grade-concept`, the ordinal
  for reading order and the slug linked — but cross-reference by slug only.
- [`ops/SLUGS.md`](SLUGS.md) maps every retired serial number to its slug, and
  records what was deliberately left numbered: the completed tracks' step ids
  and their handoffs. Read an old handoff with that file open.

See `~/.claude/CLAUDE.md`, "Name things for what they are, not what number they
came in at", for the standing convention this follows.
