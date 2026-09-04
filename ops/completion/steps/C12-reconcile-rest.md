# C12 — Reconcile the rest: U§5, §10, §6, §12, §13, and the backtick and GCC ledgers

**Goal.** The eleven remaining deviation rows, across three ledgers, plus the
one §6 item that is a two-line sync rather than a decision. After this the
deviation ledgers are empty of unreconciled rows for the first time since the
tracks began.

**Depends on:** C08 — the GCC row and the cross-compiler material need the
re-synced state.
**Closes / reconciles:** `DEV-U03`, `DEV-U18`, `DEV-U19`, `DEV-U20`,
`DEV-U21`, `DEV-U22`; `DEV-06`, `DEV-07`, `DEV-08`, `DEV-09`; `DEV-G08` if
C08 did not take it. Closes §6's U§6 item.
**Refs:** `docs/unicode-operators.md` §5, §6, §10, §12, §13;
`docs/backtick-operator-design.md`; all three deviation ledgers.

## Group 1 — the token set, its exclusions and their diagnostics (U§5 / §10)

`DEV-U03`, `DEV-U18`, `DEV-U19`, `DEV-U20`.

`DEV-U03` carries `B22`: **the confusable-to-ASCII spellings are a judgement
call, not derived.** `∙ ⋅ → .` and `⇔ → <=>` were assigned by hand; the
generator has no `confusables.txt` input, and these strings now appear in
**user-facing diagnostics**. The table shape already supports deriving them.
Decide here whether the paper claims them as derived or admits them as
curated — and if curated, say by what principle. Close `B22` either way;
that is a recording, not an implementation, so it belongs in this step and
not in C13.

`DEV-U18` targets U§8's "two rules that fall out of single-code-point tokens"
and the exclusion diagnostics; `DEV-U19` targets §5 predicate 5, §10 and
§7.1; `DEV-U20` targets §10's clang-format bullet and §11's open-question list.

## Group 2 — U§6, the sentence four rows disagree with

**"Parsing is the *easy* part of this feature, easier even than backtick."**
`DEV-U05`, `DEV-U11`, `DEV-U13` and `DEV-U15` each pushed back on it, from
four different directions, and C10 will have handed you its half of the
evidence. **This is the one sentence in the design doc that measurement most
clearly falsified, and four independent contradictions is a paper paragraph,
not a quiet edit.** Rewrite it to say what is true — parsing was the easy part
of *backtick*; here the parse is easy and the *name* and the *node* are not —
and say that the correction is itself a finding.

Also here: **§6 owes its sixth worked example**, `⊖a ⊞ 2 * ⊖b`. Note that it
**already exists in `papers/dxxxxr0.md:271`** and is missing only from
`docs/unicode-operators.md`, whose §6 stops at five. This is a sync, not
authorship — copy it with its comment and check the precedence it shows still
matches the tree.

## Group 3 — separable fates (U§12, and the replay ledger)

`DEV-U21` and `DEV-U22`. These target the replay assumptions and §12's claim
that the two features can have separate fates — which `U20` then *proved* by
building the Unicode feature on clean `main` with no backtick dependency, and
which `BL03` and `BL04` have both preserved since. §12 should state the proof,
not the intention: `git diff upstream/main..unicode-operators-upstream | grep
-i backtick` returns nothing, and three separate steps have kept it that way.

## Group 4 — the backtick ledger

`DEV-06`, `DEV-07`, `DEV-08` into `docs/backtick-operator-design.md`; that file
already uses `**RECONCILED**` for four rows, so follow its convention exactly.

**`DEV-09` is BL04's** and is the ClangIR row: four arms for
`BacktickInfixExpr`, one of which is a real answer rather than a copy, and the
cross-compiler note that **the two features cost exactly the same in the back
end** — same sites, same order, same failure modes — in contrast to the AST
work where `DEV-U13` found the Unicode wrapper strictly more expensive.
**Code generation sees only the desugared call, so the asymmetry disappears at
exactly the point the design predicts it should.** That sentence belongs in
§17, and it is one of the better things either paper can say.

## Group 5 — GCC

`DEV-G08`, if C08 did not take it. And the cross-compiler divergence section
generally: `B12`'s finding from C08 — that GCC has no phase-2 AST wrapper and
therefore *cannot* have F23's fix — is a difference **in kind**, and the
papers should say which parts of the Clang work have no GCC counterpart by
construction.

## Do

1. Work group by group. Mark each row as you land it, naming the paragraph.
2. **`ops/unicode-operators/clang/DEVIATIONS.md` has never used a status
   marker.** Adopt the other two ledgers' `**RECONCILED**` convention, and
   after this step confirm the file has no unmarked row left.
3. While in `CLAUDE.md`'s neighbourhood: its Layout section does not mention
   `docs/unicode-operators.md`, the 857-line Unicode design doc that is the
   exact counterpart of `backtick-operator-design.md`. Add it.

## Verify (gate)

- No build; no feature branch.
- **Zero unreconciled rows remain in any of the three ledgers.** Check with a
  grep, and put the grep and its empty output in the handoff — this is the
  step that gets to make that claim, and it should be able to prove it.
- §6's sixth example is present and matches the paper's.
- `B22`'s `Closed by` cell is filled.
