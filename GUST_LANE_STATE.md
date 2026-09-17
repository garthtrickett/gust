# Gust Lane State — Cranelift Lane Terminal Record

## Phase 24 closed — generated-C backend retirement (Patch 24.18, merged 2026-09-17)

Phase 24 is closed. Later architecture phases remain inactive pending fresh
activation: Phase 24.5, Phase 25, Stdlib implementation, Web Slice 1.

### What Phase 24 claims — and what it does not

The closure sentence is NARROWER than the one this phase was scoped to make,
and the narrowing is the substance of the record rather than a caveat.

Scoped: *Gust no longer emits C as a compiler backend.*

Measured on merged main `790f9387`, that is **false** — `./gust --backend
mir-to-c` emits C. So Phase 24 closed on what is verified:

> Gust no longer emits C on any default or publication route: the default
> route is native and the bootstrap emitter is refused without its authority.
> The deprecated explicit spellings are retained for 28 registered live-C
> cases pending issue #398, and the repository still contains C under Phase 25
> ownership.

Each clause was measured, not asserted:

| invocation | result |
| --- | --- |
| `./gust <src>` | native, emits no C |
| `./gust --backend bootstrap-emitter` | refused without the authority |
| `GUST_BOOTSTRAP_EMITTER=1 … bootstrap-emitter` | emits C, bootstrap-only |
| `./gust --backend mir-to-c` | **emits C** |

The exception is bounded, not open-ended: `check_retained_residue()` fails if
the live-C surface moves off 28, so the claim cannot quietly widen while the
closure stays green.

It does NOT claim the repository contains no C, that the bootstrap is native,
that a host C compiler is unnecessary, that the compiler is consolidated, that
intrinsic IDs exist, or that Phase 24 is more than backend retirement.

### Closure evidence (all measured, none cited on trust)

- Closure PR: `garthtrickett/gust#438`
- PR head: `9ac701932bfbeff5d01bbf5095d8732acfce0ac0`
- Merge main: `790f93872f8cd8bb9057c63ce47c2a9221068e1b`, merged 2026-09-17
- Workflow population on the closure head: **303/303 successful**, 0 failing
- Review state: 2 threads, both resolved — an unwired closure guard and a
  vacuous boundary check, both found by review and both introduced by this
  patch
- Authoritative Historical Full run: **35201456702**, event `schedule`,
  completed `success` on exact merged main
  `927892b31fdfc509eb6a3c82697acdd862863134`
- Job population: **18 unique jobs**, budgets `{jobs: 18, skipped: 0}`. Zero
  skipped is load-bearing: the workflow gates `inventory` on the actor and
  every other job depends on it, so a skipped suite reports success while
  executing nothing
- Retirement rows: **14 of 14 DONE**, in the amended order with 24.15a before
  24.15
- Patches merged: #429 (24.12c), #435 (24.12d), #421 (24.13), #423 (24.14),
  #410 (24.15a), #426 (24.15), #427 (24.16), #438 (24.18)

### Standing truth for the next lane activation

- The publication path is closed **for the bootstrap-only spelling**.
  `--backend bootstrap-emitter` is refused without `GUST_BOOTSTRAP_EMITTER`,
  so the entry Patch 24.11 created cannot be reached by knowing its name.
  It is NOT closed for the deprecated aliases: `--backend mir-to-c` and
  `--backend c` are advertised in the checked help and reach
  `codegen_generate` with no authority check. Raised in review on #439 --
  the unqualified claim was false for exactly the callers #398 is about.
- The default route is native and the bootstrap chain reaches the emitter
  through one gated entry.
- **28 live-C cases remain** and still emit C through the deprecated explicit
  spellings. Re-derived on this tree rather than carried forward: **24 are
  stdlib-owned and 4 are cranelift-owned**, not the 25/3 an earlier draft
  said -- that split was taken when the surface was 26 cases and stopped being
  true when `scripts/phase22_opening.sh` regained one. The cranelift four are
  `phase12_5_route_architecture.sh`, `phase22_opening.sh` (2) and
  `run-gust-file.sh`, and they are this lane's to convert without any
  cross-lane coordination. The stdlib 24 are the `stdlib_s1_*_parity.sh`
  guards, their justfile recipes and `tests/e2e_codegen_assertions.gst`
  (AGENTS.md line 98). Issue **#398** owns the removal and gates restoring the
  unqualified closure sentence.
- **Phase 25 should not begin while #398 is open.** Phase 25 retires the
  bootstrap C; starting it on top of an unfinished backend retirement layers
  one retirement on another, which is the sequencing error that produced the
  deferral in the first place.
- Carried defects, each filed with evidence: **#398** (retained spellings),
  **#437** (28 parity guards pinned as unreachable rather than adjudicated),
  **#436** (the C toolchain provenance scan excludes the justfile).

## Opening preflight closed (Patch 24.4, merged 2026-09-12)

The make-compiler-meaning-explicit preflight (Patches 24.0–24.4) is closed.
Later architecture phases were inactive at the time of this record: Phase 24
backend retirement, Phase 24.5, Phase 25, Stdlib implementation, Web Slice 1.
Phase 24 has since closed — see the record above; the rest remain inactive.

### What the preflight claims

Filename-selected behaviours are characterized with paired pre-change
evidence, the universal rule is decided authority carried as future work,
and compiler-recognized concrete semantic spellings are completely
classified. It does NOT claim removal of the filename-selected
typechecker branches (they still select; Patch 24.3 stays UNCHECKED),
intrinsic IDs, native bootstrap, or backend retirement.

### Closure evidence (all measured, none cited on trust)

- Closure PR: `garthtrickett/gust#384`
- Exact PR head: `6b6afac00639c9b86098db5d704870422d470229`
- Merge main: `37b1bf8f3a6891bc8877edc811b5676672f01596`
- Workflow population: 110/110 `pull_request` workflows `completed success`
  on the exact head, including Codex Trusted Gate, PR Fast, Heavy Guards.
- Review state: zero review threads and zero required approvals outstanding
  at merge (one post-merge bot usage-limit notice, not a review).
- Authoritative Historical Full: run `34656598379`
  (`workflow_dispatch` on exact main `4fcee4b4`), `completed success`,
  18/18 jobs, 2026-09-11T23:04:00Z–2026-09-12T00:19:32Z.
  Budgets: 180 min/job timeouts, max-parallel 4.
- Stale citation rejected: `a92a8ca` (superseded by the fresh run above).
- Bootstrap: `gust_v4.c` byte-identical fixed point
  (`a1ba675a`/65998, stage2 == stage3).
- Rename-invariance: 8/8 recorded observations hold through the rebuilt
  compiler (`phase24_filename_behavior_characterization evidence`).
- CR-15: complete and handed off. No-fallback: explicit, default
  `cranelift`.

### Standing truth for the next lane activation

- `main` head: `37b1bf8f` (closure merge).
- The next Historical Full nightly is the standing Level-3 signal; a red
  nightly reopens the Level-3 evidence question per lane policy.
- Known follow-ups (not defects): dormant pre-24.3b inventory terminals
  stay dormant by design; the 24.2g-auth aggregate copy is history (the
  live comparison reads the rotated value); per-transition text-surface
  rows record era states and are not live-compared.
- No unmerged semantic changes remain on this lane.

## Vision-lane verification of the terminal record (2026-09-12)

Re-derived independently from GitHub and git on 2026-09-12 ~03:30 UTC by the
docs/vision lane, without resuming Cranelift work. Every claim above holds,
with one count relabelled:

- Exact PR head `6b6afac0…` carries **109 `pull_request` workflow runs, all
  `completed success`, plus one `push`-triggered `Codex Trusted Gate`, also
  `completed success` — 110 runs in total.** The line above that reads
  "110/110 `pull_request` workflows … including Codex Trusted Gate" counts
  the push run inside the pull_request total; the population and the verdict
  are unchanged.
- PR #384 merged as `37b1bf8f` at 2026-09-12T01:40:11Z with zero review
  threads; PR #385 (this record) merged as `093c0fc9` at 02:31:43Z.
- Historical Full `34656598379`: `workflow_dispatch`, exact head `4fcee4b4`,
  `completed success`, 18/18 jobs, 2026-09-11T23:04:00Z–2026-09-12T00:19:32Z.
- The scheduled nightly on the closure merge had not yet fired at
  verification time; the latest scheduled run was `34577854352` on
  `2a91c35a`, `success`. The first post-closure nightly is the standing
  Level-3 signal named above.
