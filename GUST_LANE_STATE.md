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

## Phase 26 FFI-R2 active work held at authority boundary (2026-10-20)

The Cranelift R2 worktree is `codex/phase26-1r2-fallible-out-prototype` at
`6cafb2eaa7254985dccfc217c61482903801cffa`, with uncommitted compiler,
worker, and runtime changes. No R2 capability PR has been published. All six
Phase 26 rows and the general mode 63 follow-up remain OPEN.

The current test-only signed Byte adapter witness parsed the source-produced
scoped canonical program, admitted a signed test object, lowered that same
program, linked with the pinned compiler-owned runtime, and ran the resulting
executable to its expected exit code 2. Work `1792502866032` finished with
exit 0; its sole wait was reaped. The frozen result is
`/home/gust/phase26-recovery/boot970ebe4e/r2-scoped-actual-signed-link-unit-v1/result.json`
at SHA-256 `9c15997f08330257a1cb4cb7a62dfcd090fc6274fd28258e44d7903eaf0339f5`.
All 163 input hashes matched before and after, peak memory was 1,357,692,928
bytes, and OOM counters stayed zero. This observes the call and accepted byte
count; it does not independently prove returned byte values. The production
signing roots and approved package registry remain empty.

Two decisions block the full safe first-release claim: the operator's pending
choice of direct Vector versus branded Index tagged success representation,
and ownership of a generic safe Vector repair. A separate compile-only R4
probe accepted safe source assignments to Vector `len` and `capacity`; no
hostile generated executable was run. The source-level observation and the
existing unchecked native index and growth paths require a generic correction
before a safe wrapper can rely on Vector backing or capacity. The R2 patch
also still needs output byte, failure/contradiction, bootstrap, Stdlib wrapper,
production signer/package, and public gate qualification.

The complete current evidence and next frontier are pinned in
`/home/gust/phase26-recovery/boot970ebe4e/r2-current-handoff-20261020.json`
at SHA-256 `3b6d17c69e709ea9458beb4749ed59ce3092c59ac67f8720156baf2423593294`.
No own job or wait is live. This is a terminal work record, not a Phase 26
completion or a decision to change public representation or Vector semantics.

### Resumption (2026-10-20)

The operator resumed this Cranelift lane on the same worktree and branch.
The terminal state above is historical. Work continues on independent R2
qualification: actual output bytes, failure and cleanup paths, graph budgets,
and generic caller shapes. The public tagged-result and collection ownership
decisions remain open and are not being implemented by inference.

### Post-R4 R2 successor (2026-10-20)

The active isolated R2 successor is
`/home/gust/code/worktrees/gust/p26-r2-scoped-copy` on
`codex/phase26-1r2-scoped-copy`, based on merged R4 main `7e52a303`. The
original prototype worktree and its frozen evidence remain untouched. This
successor is still uncommitted and has no R2 pull request.

The source-produced caller-borrowed five-argument fixture is now enrolled as
`tests/cranelift/phase26_r2_scoped_caller_five_arg.gst` (SHA-256
`cf49093591bc4adb2faacded836d7406c4ec02725774cbacbc952d10b2f82236`).
The normal post-R4 Gust compiler and normal Rust worker produced its canonical
bundle, then refused the production CLI route at canonical validation with
`byte-span Call requires exact signed approved-package admission`. Actual
compiler exit was 1 and no executable was produced. The diagnostic result is
`r2-post-r4-inrepo-current-cli-v1/output/result.json` under the private
Phase 26 recovery root, SHA-256
`e10fdd8e373f5038a5a065d84612cb2789d00a2609fb7e9896f9d1fe4e04c246`.
Only the source module path differs from the earlier private capture after
normalizing path identity; this is not package admission.

Separately, the current Rust test profile parsed the post-R4 canonical
program, admitted its signed test package, linked the compiler-owned runtime,
and executed the generated program with exit 2. A read-only trace of that
exact executable observed output bytes 3 and 4 before exit. The normal worker
ELF is SHA-256 `2426f845f633cf93e00f95fb2bc804dd0e60c58705ba4e51c5657ff9b2772028`;
the focused signed witness and byte trace are
`r2-post-r4-signed-borrowed-native-unit-v1/result.json` and
`r2-post-r4-borrowed-output-byte-trace-v1/result.json` in the same recovery
root. The later one-reference layout, ordinary operation dispatch, and
meaning-anchored renamed-module parser controls pass in focused Rust tests;
their test-only hardening is still in progress.

The production package registry and signer root remain empty. Full FFI-R2
still needs its coherent failure and cleanup cohort, bounded malformed-graph
controls, bootstrap and owning guard qualification, and publication. The
tagged public result choice and generic safe Vector invariant repair remain
separate OPEN decisions; this record does not claim a safe wrapper,
production approval, or Phase 26 closure.

### R2 scoped-copy qualification update (2026-10-21)

The same `codex/phase26-1r2-scoped-copy` successor remains active on merged R4
base `7e52a303`; no R2 PR has been published. The test-profile owning guard V2
completed with exit 0 after three in-repo source-to-canonical comparisons,
production default-denial, focused parser and runtime tests, and four signed
native test executables. Its immutable result and 35 retained artifacts are at
`/home/gust/phase26-recovery/boot970ebe4e/r2-owning-fullguard-v2` and
`r2-owning-fullguard-v2-retained-v1` under the same recovery root. This result
predates the resource compatibility correction below and is predecessor
evidence, not a current-source guard pass.

The first R2 native bootstrap attempt stopped at compiler stage 1: the new
generic nonlive resource check rejected the existing Guard → ReadDir loop →
CloseDir path in `compiler/resolver.gst`. The correction retains the historical
directory shadow transition while enforcing the new nonlive check for generic
resource owners, including authenticated `fallible_owned_out` acquisitions.
Focused changed-source controls passed legal direct release, rejected a
scheduled owner's transfer and repeated consumption, and preserved the legacy
open-directory move refusal. The changed-source native fixed point then passed:
stage 1 and stage 2 each emitted one identical object and linked identical
compiler executables. Frozen outcomes are `r2-owning-legacy-correction-focus-v4`
and `r2-owning-bootstrap-v2`; the latter's objects, tools, and logs are retained
in `r2-owning-bootstrap-v2-retained-v1` under the recovery root. The bootstrap
stage-1 compiler build is the positive observation of the previously failing
directory loop. No generated hostile source executable was run.

The R2 owning guard now includes checked-in generic resource positives and
misuse negatives so CI can preserve this correction. Its changed-source run,
registration and pinned text inventory, fixed-commit review, PR checks, and
merge are still pending. The production signing roots remain empty. Public
tagged-result representation and the separate generic Vector safety floor
remain OPEN; all six Phase 26 rows and general mode 63 remain OPEN.

### R2 validator and signed-test checkpoint (2026-10-21)

The same Cranelift successor remains active at `bdc8f61c` plus uncommitted
R2 corrections; there is still no R2 PR or production signing root. Formal
review of the first complete candidate found three bounded worker omissions:
reserved TryCreate/Free calls could take another canonical policy route,
fallible cleanup could select an inline callee, and a tag-9-only constructor
could miss the new reachability budget. The worker now rejects those routes.
The focused parser result at
`/home/gust/phase26-recovery/boot970ebe4e/r2-bounded-validator-v3/result.json`
(SHA-256 `5c62f89c589daec80b01c1f4b723dab407ae4848b94d202b4a1dc9f5bf18f7ae`)
records eight passing tests, including actual source-produced flat constructor
controls, exact earlier-authority classification for Free, and graph bounds.
Its source census matched before, after, and the tested checkout; OOM events
were unchanged. This is focused worker validation, not a refreshed full R2
owning guard or native bootstrap.

The six signed test cases now share test-only adapter build/signing and runtime
staging/link assertions. All six passed on the pinned runtime archive, and the
four owning-guard executables are byte-identical to their earlier qualified
versions. Evidence is
`/home/gust/phase26-recovery/boot970ebe4e/r2-shared-test-helper-v1/result.json`
(SHA-256 `5a4ec6d753c8559cef0336749e65714fbbc6053c988dd8996cb3bbbb83bb1a2b`).
The new flat canonical test fixture must be enrolled in the prospective R2
source/tool and registration census before publication; historical predecessor
records are unchanged.

Two decisions remain held: whether to authorize an independently checked,
versioned collection intrinsic meaning for the scoped worker, and whether the
CI owner may provision GDB for the proposed test-only byte observer. The
private observer has measured completed ReadOutput bytes 3 and 4 followed by
one completed Free on an exact signed executable; this alone does not prove
the final Vector backing or public safe API. No collection semantic edit or
tool installation follows from elapsed time. The public tagged-result choice
and generic Vector invariant repair also remain OPEN. All six Phase 26 rows,
general mode 63, production approval, publication, and phase closure remain
OPEN while independent authorized checks continue.

### R2 bounded terminal state: WAITING_FOR_OPERATOR_AUTHORITY (2026-10-21)

The same Cranelift task and `codex/phase26-1r2-scoped-copy` worktree are
preserved at `bdc8f61c` plus the bounded review corrections above. The owning
guard now names all five fallible cleanup tests. The new source-produced flat
canonical fixture is in Git's intended tracked set. The R2 successor inventory
records six additional semantic spelling sites; removing that sole successor
record leaves the merged-main registry unchanged. Nine read-only registration,
predecessor, syntax, and diff checks passed with identical source hashes before
and after. The immutable receipt is
`/home/gust/phase26-recovery/boot970ebe4e/r2-bounded-postreview-static-v1/result.json`
(SHA-256 `a2e019038e3fda62cff5868e0f6cb92da206cb67fef158ab2feac3f9c6a75481`).
This is static enrollment evidence, not a new full owning guard or bootstrap.

On the exact earlier signed executable, a private fixture-specific observation
found the output allocation's backing bytes `3,4` before its one completed
region Free and still `3,4` at normal wrapper return. The reversed `3,5`
expectation was rejected. Its independent audit is
`/home/gust/phase26-recovery/boot970ebe4e/r2-finish-byte-backing-observer-v2-independent-audit-v1.json`
(SHA-256 `8af9a2af327b459045fd10c894e75677f7fbe8e4de7d2aa24603881f4f6723b2`).
This is one known fixture and ABI, not generic collection or public safe API
qualification; the CI observer dependency remains unapproved.

The remaining R2 semantic work waits on the operator's shared-zone decision
for the proposed versioned `collection_intrinsic.v1` contract. The test-only CI
byte observer waits on the separate GDB provisioning decision. On approval,
resume this same patch with the authorized generic operation proof and the
approved byte oracle, then refresh exact tool/source binding, focused tests,
full owning guard, native fixed point, registration pins, and fixed-head review
before publication. No elapsed time supplies either approval. Public tagged
result representation and the generic Vector safety repair remain separate
OPEN decisions. There is no R2 PR, production signing authority, Phase 26
capability closure, or phase completion claim.

### R2 resumed under bounded shared-zone authority (2026-10-21)

The operator explicitly authorized the reviewed `collection_intrinsic.v1`
proposal (private v3 SHA-256
`f8c3abece4ac88b502060894610e4a1ad6b2608aec6c8da67e71d7893d0a7775`)
and, separately, test-only GDB provisioning for the R2 byte and cleanup
observer. This resumes the same Cranelift task and invalidates the waiting
state above. The four collection operations require independent worker checks
for type, brand, layout, bounds, freshness, and cleanup; legacy operations and
the seven runtime hooks retain their meaning. GDB is not a product dependency.
The next step is the exact operation requirement and witness map, followed by
coherent producer, parser, proof, lowering, focused validation, and refreshed
owning gates. No public tagged-result or generic Vector safety-floor decision
was supplied, and no safe-wrapper or Phase 26 closure is claimed.

### R2 executable collection checkpoint (2026-10-21)

The same `codex/phase26-1r2-scoped-copy` patch remains active and unmerged.
The typed producer now emits versioned executable Create, Read, Clear, and
Append operations. The worker checks their layout, brand, value versions,
caller Arena histories, and scoped owner cleanup before lowering. The actual
caller Return schedule now requires the scoped Call to be evaluated before a
deferred Arena Free. Source-produced `input.len` forgery and copied-alias
programs reached canonical MIR and were rejected by the current worker at
their caller provenance checks; neither generated program was executed.

Focused evidence is the immutable
`/home/gust/phase26-recovery/boot970ebe4e/r2-intrinsic-scoped-and-caller-controls-v8/result.json`
(16 scoped, 13 provenance, and 2 budget tests passed), the exact current
worker artifact in `r2-intrinsic-current-worker-v1`, and the current normal
CLI result in `r2-intrinsic-current-cli-v1/output/result.json`. Six signed
native test fixtures passed in `r2-intrinsic-signed-native-matrix-v1`.
On that matrix's exact borrowed-caller ELF, the test-only GDB observer in
`r2-intrinsic-current-byte-observer-v1` saw copied backing bytes `3,4`
before one completed region Free and after the wrapper returned count two;
the `3,5` oracle was rejected. This qualifies that fixture and test profile,
not arbitrary collection safety, public API, or production package trust.

The additive registry, bootstrap-sensitive frontend fixed point, refreshed
tool binding and full owning guard still require current-source validation.
The public tagged-result contract and separate generic Vector safety repair
remain OPEN. All six Phase 26 rows, general mode 63, and phase closure remain
OPEN; there is no R2 PR or production signing root.
