# BL01 — Environment: make the gate readable (`B31`, `B32`, `B33`, `B34`)

**Goal.** A `check-clang` run on the backtick branches reports zero failures
that are not real, so every later step's Status row does arithmetic instead
of writing a paragraph of excuses.

**Depends on:** nothing. This runs first *because* `B31` + `B32` inject 10
spurious failures into every backtick gate.
**Closes:** `B31`, `B32`, `B33`, `B34`.

## Do

### 1. `B32` — `CLANG_EXECUTABLE_VERSION` (P2, the one real change)

`CLANG_EXECUTABLE_VERSION` was set to `24-backtick` / `23-backtick` in the two
backtick build dirs on 2026-08-02. Two tests assert on the driver binary's
basename and fail as a result:

- `Clang :: Analysis/scan-build/cxx-name.test`
- `Clang :: Driver/hip-gz-options.hip`

Proven environmental — the stale pre-edit binaries pass, the
identically-sourced `clang-*-backtick` fail.

**Do this:** reconfigure both build dirs back to the plain version, matching
the two Unicode build dirs which are already `24`:

```bash
cmake -S ~/src/llvm/backtick-trunk/llvm -B ~/src/llvm/build-backtick-trunk \
      -DCLANG_EXECUTABLE_VERSION=24
cmake -S ~/src/llvm/backtick/llvm       -B ~/src/llvm/build-backtick \
      -DCLANG_EXECUTABLE_VERSION=23
```

Then rebuild. This is a relink and a symlink rename, not a full rebuild.

**Alternative, if the suffixed binary names turn out to be wanted for some
reason not recorded anywhere:** leave the setting and add both tests to this
track's known-failures list in `ops/backlog/PLAN.md`'s gate facts instead. If
you take this branch, say why in the handoff — the recommendation is to
revert, because it deletes two failures rather than documenting them forever.

### 2. `B31` — the inotify watch budget (P2, needs root)

8 `DirectoryWatcherTest.*` cases fail intermittently on **every** branch,
including untouched binaries, with
`No space left on device : inotify_add_watch()`. A `cloud-drive-dae` process
holds ~65,382 of the 65,536 available watches.

**This needs root, so it is a request to the maintainer, not an agent
action.** The fix is already sitting commented out on this machine:

```
/etc/sysctl.d/50-ubuntustudio.conf:6:#fs.inotify.max_user_watches = 524288
```

Uncomment that line and `sudo sysctl --system`. Verify with
`cat /proc/sys/fs/inotify/max_user_watches` (currently `65536`).

**Do this:** state the request plainly in the handoff with the exact line and
command. If the maintainer has applied it by the time you gate, run the gate
**unfiltered** and record that the 8 are gone. If not, the
`GTEST_FILTER='-DirectoryWatcherTest.*'` re-run stays mandatory and stays
documented — that is not a BLOCKED condition for this step.

Before believing any DirectoryWatcher failure, check the budget:

```bash
for p in /proc/[0-9]*/fdinfo/*; do grep -c '^inotify' $p; done | paste -sd+ | bc
cat /proc/sys/fs/inotify/max_user_watches
```

### 3. `B33` — the stray `.clang-format` (P3, no action)

`Clang :: Format/dump-config-objc-stdin.m` fails on `backtick-23` only,
because a 2018 `Language: Cpp` config at `/home/sdowney/src/.clang-format` —
outside any repo — is picked up by clang-format walking up the directory
tree. It fails identically on the pristine `build-main` binary and it
**passes** on every trunk-based branch.

**Do this:** confirm it is documented as `backtick-23`-only in
`ops/backlog/PLAN.md`'s gate facts and in `CLAUDE.md`. Do **not** touch or
delete the stray file. Close the row as "documented, no action".

### 4. `B34` — GCC's libstdc++ (P3, record only)

libstdc++ is not built in `gcc-backtick-build`, so no G-test can link and
run. Nothing needs it today.

**Do this:** add the recipe to `ops/gcc/PLAN.md`'s build/gate section so the
next GCC agent does not rediscover it:

```bash
cd ~/bld/gcc/gcc-backtick-build && make -j18 all-target-libstdc++-v3
```

Close the row as "recorded, no action".

## Verify (gate)

- `check-clang` on **both** backtick build dirs, run **unfiltered**, with the
  two `CLANG_EXECUTABLE_VERSION`-driven failures gone.
- Green means: zero failures beyond the 8 `DirectoryWatcherTest.*` cases, and
  zero at all if the maintainer applied the sysctl. On `backtick-23`,
  `Format/dump-config-objc-stdin.m` is still expected (`B33`).
- The two Unicode build dirs are untouched — confirm their
  `CLANG_EXECUTABLE_VERSION` is still plain `24` and do not rebuild them.

## Capture in handoff

**The new baselines**, which every later step subtracts against: discovered /
passed / failed / XFAIL / unsupported / skipped for `backtick-trunk` and
`backtick-23`, both filtered and unfiltered. Replace the pre-BL01 table in
`ops/backlog/PLAN.md` with them.

Also: whether the sysctl was applied, and by whom, so a later agent seeing 8
DirectoryWatcher failures knows whether that is expected or a regression.

## Bookkeeping

Also correct `ops/BACKLOG.md` itself while you are in it — the file
overstates two rows and understates three, and the corrections are already
evidenced in this plan's step files:

- **`B14`** — "almost certainly … nobody has looked" is stale. Three of
  F24's five defects are now *observed*; see `steps/BL03-analyzer-useroperator.md`.
- **`B15`** — "unknown whether it needs a case at all" is stale. The four
  sites are known and the failure mode is `errorNYI`; see
  `steps/BL04-clangir.md`.
- **`B25`** — add `operator--`, which fails identically.
- **`B03`** — the flag does not merely change C-mode *diagnostics*; C
  **accepts** the infix grammar with it. See `steps/BL06-backtick-batch.md`.
- **`B24`** — remove it from §7's "cheap and can be batched" sentence; it is
  not cheap. See `steps/BL06-backtick-batch.md`.
- **`B35`, `B36`** — two new rows, already added when this track was
  scaffolded. Leave them.

Commit as `ops: BL01 — …`.
