# slug-the-ledgers — Retire the serial numbers

**Goal.** Every internal identifier in this repo is a serial number: `B03`,
`DEV-U13`, `D16`, `U8`, `S04`, `G10`, `BL02`. None of them says what it is.
A reader who meets `DEV-U13` in a handoff has to go and look it up, and a
reader who meets it in a *paper draft* has to be stopped by an editor. Replace
them with slugs — short kebab-case names for the question or the job.

**Depends on:** nothing.
**Blocks:** every `reconcile-*` step and `mangling-abi`, because those rewrite
exactly the paragraphs that are dense with these references. Renaming after
them means touching the same paragraphs twice, and the second pass is the one
that gets skipped.
**Refs:** `~/.claude/CLAUDE.md`, "Name things for what they are, not what
number they came in at" — the standing convention this step applies.
`~/src/transpose/main/docs/decisions.md` is the worked example.

## The rule, restated for this repo

**A slug names the question, or the job — never the answer.** `mangling-abi`,
not `use-vendor-prefix`; `nesting-vs-chaining`, not `bare-nesting-is-legal`. A
slug named for a conclusion has to be renamed when the conclusion reverses,
which breaks every reference at exactly the moment the work is under most
pressure. Named for the question, it survives being answered — and answering
an open question then **graduates it in place**, with every existing link
still valid.

## What gets renamed

Four namespaces, in increasing order of how much they hurt today:

1. **The decision logs** — `docs/backtick-operator-design.md`'s `D1`–`D16` and
   `docs/unicode-operators.md`'s `U1`–`U11`. **These are the worst offenders**
   and the reason this step exists: they are cited throughout the design docs,
   the papers, the deviation ledgers and forty handoffs, and `D8` tells a
   reader nothing at all. They are also the closest match to the convention's
   origin, so give them the full entry shape: **Question / Status / Decision /
   Why / Log**, one section per question, `Decided by` on anything decided.
2. **The deviation ledgers** — `DEV-01`–`DEV-09`, `DEV-U01`–`DEV-U24`,
   `DEV-G01`–`DEV-G08`. Same shape: each row already *is* a question ("what the
   design said" versus "what was true"), so the conversion is mostly naming.
3. **The defect backlog** — `B01`–`B38` in `ops/BACKLOG.md`. These are defects
   rather than questions, so slug them for the defect: `c-mode-tokenization`,
   `keyword-escape-round-trip`, `null-return-suppression`, `clangir-lvalue-crash`.
4. **The completed tracks' step ids** — `S00`–`S12`, `G01`–`G10`, `U00`–`U21`,
   `BL01`–`BL04`. **Leave these alone.** They are a closed historical record,
   they appear in commit messages that cannot be rewritten, and the handoff
   filenames are the only index into forty documents. Renaming them buys
   nothing and costs the ability to `git log --grep`. Say so in the ledger so
   the next reader does not think it was an oversight.

## Do

1. **Choose the slugs first, in one pass, and write the mapping down** before
   editing anything. A mapping table in `ops/SLUGS.md` is the deliverable that
   makes the rest mechanical — and it is also what lets a reader of an old
   handoff translate.
2. Rewrite the four ledgers, giving the two decision logs the full entry shape.
   Keep the old identifier in the entry as a `Formerly:` line; forty handoffs
   still say `DEV-U13` and cannot be edited.
3. Rewrite every live cross-reference — this plan, its step files,
   `ops/BACKLOG.md`, both design docs, both papers — as **links to the
   anchor**, not bare mentions. Links are the point: they can be followed, and
   a rename becomes a detectable break rather than a silent one.
4. **Do not rewrite the completed tracks' handoffs.** They are the record of
   what an agent knew at the time, and editing them to use names that did not
   exist then makes them lie.
5. Update `ops/AGENT_PROTOCOL.md` and this plan's ground rules to require
   slugs for anything added afterwards.

## Verify (gate)

- No build; no feature branch.
- `ops/SLUGS.md` maps every retired identifier to its slug, both directions.
- **No live document cites a retired identifier except as `Formerly:`.** Grep
  for `\bD1?[0-9]\b`, `DEV-[UG]?[0-9]`, and `\bB[0-9][0-9]?\b` across
  `docs/`, `papers/`, `ops/*.md`, `ops/completion/` and put the output in the
  handoff. The historical handoff directories are excluded on purpose — say
  that in the same breath, so the exclusion reads as a decision.
- Every reference is a link, and every link resolves. A dead anchor is the
  failure mode this whole convention exists to make visible; check them.
- The papers are checked too: per the standing convention, **public text must
  not cite internal identifiers at all** — not the numbers and not the slugs.
  Where a paper cites one, the fix is to describe the reason or the effect,
  not to substitute a prettier identifier.
