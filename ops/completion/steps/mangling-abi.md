# mangling-abi — The ABI question, and U§9 with it

**Goal.** `U8` has been "open" since the Unicode track began: the Itanium ABI
has no first-class `<operator-name>` production for a user-defined operator,
the prototype ships a vendor-extended form, and the Microsoft ABI has no
production to borrow at all. This step decides what the paper asks for and
writes U§9 in the same sitting, because the section cannot be written until
the question is answered and answering it *is* writing the section.

**Depends on:** upstream-reports — the report it files is evidence here (see below).
**Closes:** `B20`; reconciles `DEV-U08`, `DEV-U09`, and `DEV-U23`'s mangling
clause; answers §6's `U8 / DEV-U09`.
**Refs:** `docs/unicode-operators.md` §9 and U8; `DEV-U08`, `DEV-U09`;
`ops/unicode-operators/clang/handoffs/U09-mangling.handoff.md`; `U21`'s
mangling note.

## Why this depends on upstream-reports

BL05's own closing note makes the connection, and it is the strongest
argument the section has: **fixity in mangling is easy to get wrong even
where the ABI spells it out.** `B25` is Clang emitting the postfix spelling
for prefix `++` and `--` when the ABI gives `pp_` / `pp` and `mm_` / `mm`,
and GCC gets it right — a live cross-vendor divergence in the exact corner a
first-class `<operator-name>` production would have to specify. Cite the
issue number upstream-reports obtained. A section that argues "the ABI needs room for
fixity" is much stronger when it can point at fixity going wrong today.

## The decision

What does the paper *ask* the ABI groups for? At least these options, and the
step must state the cost of each:

1. **Keep the vendor-extended form** the prototype implements, and say so —
   `v <digit> <source-name>`, with the derived ASCII name. Cheapest, and the
   honest description of what was built.
2. **Ask for a first-class `<operator-name>` production.** Note from `U21`
   that this is *why* `U8` stays open: a first-class production needs room
   for a fixity marker that `v <digit> <source-name>` does not have. If the
   paper asks for one, it must say what it should look like.
3. **Say nothing normative** and mark it a known gap for the ABI groups.

And separately: **the Microsoft ABI**, which `DEV-U09` records as unexamined.
Decide whether the paper claims anything about it. "Unexamined" in a WG21
paper is a fair answer if it is stated; silence is not.

## `B20` belongs here

**The astral-plane and zero-padding branches of the mangling derivation are
untested by construction** — every U1 code point is in `0x2190`–`0x2BFF`, so
every derived name is exactly four digits, and the other branches cannot be
reached without changing U1. That is not a defect to fix; it is a property of
the frozen token set, and it is the *first* thing to test if U1 ever grows
past the BMP. Which of the three options above is chosen changes whether that
sentence belongs in the paper or only in the design doc. Record it wherever
the decision puts it, and close the row either way.

## Do

1. Write the decision as decision-brief writes its pages — question, what was measured,
   options, cost, recommendation — but write it **into `docs/unicode-operators.md`
   §9** rather than into `docs/open-decisions.md`, because unlike decision-brief's four
   this one's answer *is* the section.
2. Reconcile `DEV-U08` (the derivation and its untested branches) and
   `DEV-U09` (§9's closing paragraph, the MSVC gap) into §9 as you go, and
   mark both rows `**RECONCILED**`.
3. Reconcile `DEV-U23`'s mangling clause only — the rest of `DEV-U23` is
   postfix and belongs to decision-brief.
4. Close `B20` with the reasoning above.

## Verify (gate)

- No build; no feature branch touched.
- §9 answers all three of: what is implemented, what is asked for, what is
  unexamined — and cites upstream-reports's issue.
- `DEV-U08` and `DEV-U09` carry `**RECONCILED**` and name the paragraph they
  landed in. `DEV-U23` says which clause was taken and which was left to decision-brief.
- `B20`'s `Closed by` cell is filled.
