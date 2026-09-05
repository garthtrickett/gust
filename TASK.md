# Phase 23 — MIR-to-C Deprecation

<!-- The first-line Phase 23 heading is retained as a compatibility anchor for
     immutable predecessor closure guards. The active Cranelift roadmap begins
     immediately below. -->

# Phase 24 Opening Preflight — Make Compiler Meaning Explicit

**Lane:** Cranelift. Branches follow the existing
`codex/phase<N>-<patch>-<slug>` pattern.

Workflow, Monitoring, Merge, Phase Completion, Runner, Issue Intake, and Git
Authorization policies are defined in `AGENTS.md`. Shared semantic ownership is
defined in `docs/SHARED_SEMANTIC_ZONE.md`. This bounded preflight is the active
Cranelift roadmap. It is not activation of Phase 24 backend retirement.

The preflight removes accepted or rejected Gust meaning selected by source-file
name fragments before any backend is retired or compiler structure is changed.
It first freezes both sides of the existing branches, then inventories concrete
stdlib/runtime spellings recognized by compiler code, and only then permits the
smallest filename-independent correction already supported by live semantic
authority. Patch 24.1 found one genuine unresolved choice; the operator resolved
it on 2026-09-03 in favour of universal non-POD rejection with semantically
inert source filenames and no internal compilation profile for these checks.

## Roadmap Activation

Phase 23 formally closed on 2026-09-02. Its closure PR #298 completed
**125/125** strict exact-head `pull_request` workflows with zero unfinished or
non-success workflows, zero reviews, and zero unresolved non-outdated review
threads. Exact head `aef80c40737cb3288f4ede2c234ade3118ddf316` merged as exact
main `a69023f305df973d47bb1d3a7f18ed32fedcfced`.

Docs PR #299 then recorded the future architecture sequence. Its exact head
`78a09041e017c35870805c5499869158cbbb3149` completed **10/10** strict
exact-head `pull_request` workflows with zero unfinished/non-success workflows,
zero reviews, and zero review threads, and merged as exact main
`1c5e7fe5dee11aa00019bffafe14778a449b96d4`.

On 2026-09-02 the operator explicitly authorized this roadmap promotion and the
Cranelift completion loop through the opening-preflight closure only. The
operator required characterization before correction and prohibited selecting
a new Gust semantic rule for convenience.

After Patch 24.1 merged, the operator explicitly resolved its recorded TCS
decision on 2026-09-03: the existing non-POD stack restriction applies
universally to local declarations and guard-payload bindings. Source filenames
are semantically inert, and these checks do not use an internal compilation
profile. Patch 24.1a records that authority without changing compiler behaviour;
Patch 24.2 remains report-only and Patch 24.3 owns the later correction.

After Patch 24.0 merged, the operator explicitly amended the sequence on
2026-09-02: schedule and activate the compiler-owned CR-15 protected-Resource
guard derivation before Patch 24.1, hand verified compiler authority to Stdlib,
then resume this preflight unchanged. That instruction resolves only the
sequencing and implementation authority already selected by OD-2 and OD-13; it
does not reopen either decision or authorize Stdlib implementation.

On 2026-09-04 the operator activated one narrow compiler-owned prerequisite
discovered by the preserved Stdlib S1.9 witness: implicit local binding of a
compiler-tracked linear Resource transfers cleanup ownership to exactly one
destination and invalidates the source binding and source-rooted access. This
rule is generic over resolved Resource metadata and is enforced before backend
selection. Patches 24.2e–24.2h own only its roadmap authority, implementation,
conditional isolated seed reconvergence, and checked S1.9 handoff. The broad
Patch 24.3 compiler-source migration remains paused until Stdlib S1.12.

The initial activation did not authorize CR-15. This amendment does, but still
does not authorize Phase 24 backend-retirement implementation, Phase 24.5
consolidation, Phase 25, TypeEnvironment splitting, `FunctionCheckFrame`,
intrinsic-ID implementation, native-command decomposition, registry or CI
consolidation, edits to `TASK_STDLIB.md`, Stdlib implementation, Web Slice 1,
or another operator-owned semantic/product decision.

## Preflight Boundary

In scope:

- exact characterization of the current accepted/rejected behaviour with and
  without the `test_tcs_` and `test_index_` source-name fragments, including
  byte-identical renamed witnesses and stable diagnostic observations;
- an exact compiler-source inventory of concrete stdlib/runtime spellings that
  influence semantic classification or intrinsic behaviour, with source site,
  decision, current authority, eventual intrinsic owner, phase, reason, and
  falsifier;
- the smallest generic compiler-owned correction that makes the characterized
  behaviour independent of source filename using authority that already exists;
- default/explicit native and retained explicit compatibility-path parity,
  explicit no-fallback behaviour, diagnostics, artifacts, bootstrap
  convergence, generated authority, review gates, and exact-main Historical
  qualification for the completed preflight; and
- an isolated generated bootstrap-seed reconvergence after the self-hosted
  typechecker reaches its final preflight form.

Out of scope:

- deleting, disabling, or changing the accepted spelling or output of the
  retained generated-C compatibility backend;
- changing canonical MIR, native lowering, ABI/layout, runtime symbols,
  target/linker policy, resource/drop/move/provenance semantics, operator
  semantics, or Phase 9G artifact ownership;
- inventing a fixture-name exception, compiler-module exception, stdlib-type
  exception, backend-only rule, fallback, or environment-selected meaning;
- introducing an internal compilation profile, fixture exception, or other
  selector for the universally applicable non-POD checks;
- assigning intrinsic IDs, replacing recognized spellings, splitting
  typechecker state or modules, decomposing the native command, refactoring the
  registry/CI topology, or beginning any backend-retirement deletion; and
- editing Stdlib-owned sources or roadmap, Phase 24.5, Phase 25, or Web Slice 1.

CR-15 is a prerequisite sequence, not part of the filename/spelling preflight.
Its exact boundary is Patches 24.0b–24.0f below. Patch 24.1 remains paused until
the compiler authority, isolated seed, exact-main qualification, and checked
Stdlib handoff are complete.

## Status

- [x] Patch 24.0 — Opening-Preflight Roadmap Activation — DONE
- [x] Patch 24.0a — CR-15 Sequencing and Roadmap Amendment — DONE
- [x] Patch 24.0b — CR-15 Opening Evidence and Inert Derivation Contract — DONE
- [x] Patch 24.0c — Protected-Resource Guard Derivation — DONE
- [x] Patch 24.0d — CR-15 Cross-Path and Adversarial Qualification — DONE
- [x] Patch 24.0e — CR-15 Bootstrap Seed Reconvergence — DONE
- [x] Patch 24.0f — CR-15 Closure and Stdlib Handoff — DONE
- [x] Patch 24.1 — Filename-Selected Behaviour Characterization — DONE
- [x] Patch 24.1a — Universal TCS Semantic Decision Authority — DONE
- [x] Patch 24.2 — Compiler-Recognized Semantic Spelling Inventory — DONE
- [x] Patch 24.2e — S1.9 Resource-Assignment Prerequisite Amendment — DONE
- [x] Patch 24.2f — Generic Implicit Linear-Resource Assignment Transfer — DONE
- [x] Patch 24.2g — Resource-Assignment Bootstrap Seed Reconvergence — DONE
- [x] Patch 24.2h — S1.9 Prerequisite Closure and Stdlib Handoff — DONE
- [ ] Patch 24.3 — Filename-Independent Typechecker Correction
- [ ] Patch 24.3a — Preflight Bootstrap Seed Reconvergence
- [ ] Patch 24.4 — Opening-Preflight Closure

Status rows are machine-parsed. Keep each row as
`- [ ] Patch 24.N — <Title>` or `- [x] Patch 24.N — <Title> — DONE`; an
inserted amendment may append one lowercase letter to `N`.

## Immutable Contracts

- Renaming a source file cannot change whether the contained Gust program is
  accepted, rejected, or assigned a diagnostic.
- Characterization precedes correction. A passing post-change fixture is not
  evidence of what either pre-change branch did.
- Patch 24.3 universally rejects non-POD local declarations and guard-payload
  bindings. Source filenames are semantically inert, and no internal compilation
  profile selects these checks. This is operator authority recorded by Patch
  24.1a, not a rule selected by implementation convenience.
- The spelling inventory is report-only. It identifies semantic decisions and
  their eventual intrinsic owner but assigns no intrinsic IDs and changes no
  dispatch.
- Cranelift remains the default production backend and never falls back. The
  retained explicit compatibility route and bootstrap chain remain available
  exactly as Phase 23 left them until separately activated retirement phases.
- `make gust`, `make bootstrap`, and `gust_v4.c` retain their current host-C
  bootstrap chain. A changed seed is generated at a stage-2/stage-3 fixed point
  and published alone.
- No compiler-module, fixture-name, source-spelling, stdlib-type, or backend
  exception is an acceptable correction.
- CR-15 is compiler-owned, backend-neutral derivation over resolved generic
  Resource and protected-access metadata. It may not reopen arbitrary
  user-written generic functions or recognize `Mutex`, `MutexGuard`,
  `sync.lock`, or `sync.get` in either backend.
- The selected initial API shape is module-level `sync.lock(&mutex)` returning
  a move-only `MutexGuard[T, ctx]` and `sync.get(&guard)` returning guard-rooted
  `&T`. The compiler derives concrete acquisition, guard, destructor, and
  rooted-accessor identities; Stdlib retains ownership of representation,
  re-entrancy, implementation, tests, examples, and later ergonomics.
- CR-15 lowers through ordinary canonical calls and the existing Resource
  cleanup and protected-access semantics in both retained compiler paths.
  Backend-specific lowering and fallback are forbidden.
- Implicit local binding of a compiler-tracked linear Resource is an ownership
  transfer: the destination owns the sole cleanup obligation, and the source
  binding plus access rooted in it is invalid after the transfer. The rule is
  driven only by resolved generic Resource metadata before backend selection;
  no filename, fixture, backend, stdlib type, or consumer spelling may select it.
- Phase 24 backend retirement, Phase 24.5 consolidation, and Phase 25 native
  bootstrap remain inactive after this preflight closes.

## Validation Model

**Level 1 — authority and inventory:** exact roadmap/status parsing; paired
filename-branch inventory; concrete-spelling inventory completeness and unique
site identity; registry/schema/projection freshness; predecessor closure;
consumer, guard, fixture, and workflow reachability; explicit no-fallback; and
diff hygiene.

**Level 2 — focused behaviour:** pre-change byte-identical renamed pairs on both
sides of each filename branch; accepted/rejected result, diagnostic, emitted
artifact, side-effect, and cleanup comparison; post-change rename invariance;
default/explicit native identity; retained compatibility-path parity; and
positive/negative falsifiers proving the former branches cannot reappear.

**Bootstrap — self-hosted compiler:** `make gust` for each compiler-source
patch; both retained compiler paths where affected; then an isolated
`gust_v4.c`-only reconvergence with stage 2/stage 3 byte identity.

**CR-15 — protected-Resource derivation:** preserve the checked rejected
generic witness before implementation; require inferred and explicit concrete
guard identities, branded protected access while the guard is live, obligation
transfer on move, exactly-once cleanup across every existing exit form, and
negative evidence for forgery, escape, post-move/post-cleanup access,
unprotected types, unresolved placeholders, arbitrary generic functions,
spelling-specific recognition, backend divergence, and fallback.

**Closure — exact final preflight main:** one authoritative `Cranelift Historical
Full` run on the exact merged final preflight implementation main, with the
complete registry-derived job population successful and zero unresolved
material review findings. Record run ID, full SHA, event, conclusion, unique job
population, and budgets. Wrong-SHA, wrong-event, partial, stale, red, fallback,
or pulse/registrar observations are not closure evidence.

Every PR is qualified only by the complete workflow population filtered to its
exact full 40-character head SHA and `event == "pull_request"`, current-main
ancestry, and zero unresolved non-outdated review threads. Local validation is
advisory; GitHub Actions is authoritative.

## Patch 24.0 — Opening-Preflight Roadmap Activation

**Purpose:** promote only the operator-authorized opening preflight into the
Cranelift task authority without changing compiler behaviour, backend routes,
bootstrap artifacts, or later-phase activation.

**Steps:**

- Record exact Phase 23 closure and docs-direction predecessor evidence plus the
  operator's bounded activation.
- Define the ordered characterization, inventory, correction, isolated seed,
  and closure patches with their invariants, stop boundary, and evidence.
- Preserve completed predecessor guards through an explicit roadmap-only
  inventory successor; retain the first-line Phase 23 compatibility anchor
  until a separately activated backend-retirement patch removes obsolete
  predecessor machinery.
- Keep the completed Phase 23 text below as an immutable record.

**Exit Gate:** the roadmap and its activation are mechanically reviewable; the
only live semantic work authorized is Patches 24.1–24.3; Phase 23 closure and
its exact retained-route inventory remain green; no compiler, backend, runtime,
bootstrap, Stdlib, or accepted-program behaviour changes; and the roadmap PR's
exact-head workflows and review gates pass.

## Patch 24.0a — CR-15 Sequencing and Roadmap Amendment

**Purpose:** promote the already-decided compiler-owned CR-15 derivation into
an active, bootstrap-safe sequence before Patch 24.1 without implementing it or
changing the Phase 24 opening-preflight boundary.

**Steps:**

- Preserve the live seven-point report and its checked rejected witness as the
  predecessor contract.
- Record separate opening/inert-contract, implementation, qualification,
  generated-seed, and closure/handoff patches.
- Update the Cranelift future sequence so CR-15 completes before the opening
  preflight, while backend retirement, Phase 24.5, Phase 25, Web Slice 1, and
  Stdlib implementation remain inactive.
- Preserve completed Phase 23 consumer authority through an exact roadmap-only
  successor that rejects partial, extra, or substituted text-surface changes.

**Exit Gate:** only roadmap, future-sequence, and generated predecessor
authority changes; CR-15 is explicitly activated and Patch 24.1 is explicitly
paused; the operator-selected protected-Resource derivation boundary and all
non-claims are complete; Phase 23 closure and exact retained-route inventory
remain green; and the amendment PR's exact-head workflows and review gates pass.

## Patch 24.0b — CR-15 Opening Evidence and Inert Derivation Contract

**Purpose:** freeze the rejected reusable-guard baseline and add only the inert,
compiler-owned metadata/derivation contract needed to distinguish a protected
Resource family from arbitrary user generics before accepted meaning changes.

**Steps:**

- Reproduce the checked `MutexGuard[T, ctx]` declaration, destructor, call, and
  accessor failures from current main and preserve full diagnostic identities.
- Inventory the resolved Resource, protected-access, brand, constructor,
  destructor, obligation, and concrete type/call-registration facts available
  before either backend.
- Define a generic derivation descriptor and stable identity rules driven only
  by those resolved facts. Keep it inert: no previously rejected program may
  become accepted in this patch.
- Add structural falsifiers for `Mutex`, `MutexGuard`, `sync.lock`, and
  `sync.get` recognition and for reopening arbitrary user-written generic
  functions.

**Exit Gate:** the complete pre-change rejection is reproducible through both
retained paths before backend selection; the descriptor is backend-neutral and
inert; no accepted meaning, MIR operation/meaning, ABI/layout/runtime symbol,
backend route/fallback, Stdlib source, or seed changes; and `make gust` plus
focused authority/registry/reachability guards pass.

## Patch 24.0c — Protected-Resource Guard Derivation

**Purpose:** implement the smallest generic compiler-owned derivation selected
by OD-2 and OD-13 for the module-level protected-Resource guard surface.

**Steps:**

- From a concrete protected Resource type and context brand, derive concrete
  acquisition, guard, destructor, and rooted-accessor identities before normal
  call checking and concrete type registration.
- Admit the selected module-level `sync.lock(&mutex)` / `sync.get(&guard)`
  contract without admitting arbitrary user-written generic functions or
  extension-method syntax.
- Substitute the concrete protected type and brand through branded-nesting,
  opaque construction, destructor signature, acquisition obligation, move,
  cleanup, and protected-access checks.
- Lower accepted calls through ordinary canonical calls and the existing
  Resource/protected-access machinery. Add no MIR instruction, changed MIR
  meaning, runtime symbol, ABI/layout rule, backend-specific recognition, or
  fallback.

**Exit Gate:** inferred and explicit guard identities agree; the selected safe
surface accepts for multiple protected types/brands; arbitrary generic
functions and unprotected types still reject; ownership transfer and
guard-rooted liveness use the existing generic rules; default/explicit
Cranelift and retained explicit compatibility paths agree; no backend contains
a consumer spelling; `make gust` passes; and the implementation PR contains no
`gust_v4.c` change.

## Patch 24.0d — CR-15 Cross-Path and Adversarial Qualification

**Purpose:** qualify the landed derivation as a generic semantic capability and
close every falsifier before bootstrap reconvergence or Stdlib handoff.

**Steps:**

- Exercise at least two protected Resource families and two context brands with
  inferred and explicit concrete result identities through both retained paths.
- Require identical acceptance, diagnostics, canonical MIR, exit status,
  output, side effects, artifacts, and cleanup with explicit no-fallback.
- Cover move transfer, every existing scope-exit form, exactly-once destructor
  execution, protected reference escape, use after move/cleanup, construction
  forgery, unresolved placeholders, wrong brand, unprotected input, nested
  scopes, and repeated acquisition.
- Prove a spelling-substituted consumer with equivalent resolved metadata
  derives identically, while a same-spelled consumer without the metadata does
  not receive authority.

**Exit Gate:** every positive, negative, parity, resource, liveness, and
mutation-sensitive case is registry-owned and reachable; ordinary canonical
MIR is byte-identical between inferred/explicit equivalents; MIR-to-C remains
the semantic oracle; Cranelift has no bespoke lowering and never falls back;
all observed differences are zero or owned with a falsifier; and no Stdlib,
ABI/layout/runtime-symbol, route/default, or seed change occurs.

## Patch 24.0e — CR-15 Bootstrap Seed Reconvergence

**Purpose:** reconverge the generated bootstrap seed after the self-hosted
derivation implementation in a strictly isolated publication.

**Steps:**

- Start from exact merged Patch 24.0d main and run the repository bootstrap
  entry point without hand-editing generated output.
- Require stage 2 and stage 3 byte identity and rerun the CR-15 positive,
  negative, resource, liveness, parity, and no-fallback evidence through the
  rebuilt compiler.
- Publish only `gust_v4.c`. If the seed is already byte-identical, record the
  checked no-diff fixed point instead of manufacturing a seed commit.

**Exit Gate:** bootstrap reaches a byte-identical fixed point; a changed seed is
the sole PR path; both retained compiler paths preserve the qualified CR-15
contract; and no Phase 25 bootstrap-route or Stdlib work is introduced.

## Patch 24.0f — CR-15 Closure and Stdlib Handoff

**Purpose:** close only the compiler-owned derivation and issue the checked
handoff that permits the Stdlib lane to resume S1.8–S1.11 before Cranelift
returns to Patch 24.1.

**Steps:**

- Re-run the opening baseline, derivation, cross-path/adversarial, registry,
  schema/projection, consumer, guard, fixture, workflow-reachability,
  no-fallback, package/install, and bootstrap authorities.
- Run and independently qualify one authoritative Historical Full on exact
  merged final CR-15 implementation/seed main with its complete
  registry-derived job population successful and zero unresolved material
  review findings.
- Generate closure/handoff authority from its registry source, record exact
  PR heads, merge mains, workflow populations, review state, Historical run ID,
  event, full SHA, jobs, conclusion, and budgets, then mark all CR-15 rows DONE.
- Notify the Stdlib lane only after the closure PR merges and the compiler
  authority is re-derived on current main. The handoff authorizes S1.8–S1.11
  under their own roadmap; it does not implement or edit them.

**Exit Gate:** CR-15 is verified complete on merged current main; protected
Resource guard derivation remains generic, backend-neutral, no-fallback, and
bootstrap-converged; both retained paths agree; the checked handoff is durable;
Patch 24.1 is next; and Phase 24 backend retirement, Phase 24.5, Phase 25, Web
Slice 1, and Stdlib implementation remain inactive in this lane.

## Patch 24.1 — Filename-Selected Behaviour Characterization

**Purpose:** freeze what the compiler currently does on both sides of every
`test_tcs_` and `test_index_` filename branch before any branch is replaced.

**Steps:**

- Enumerate every filename-dependent decision site and every current caller or
  fixture that can reach it.
- For each distinct behaviour, create byte-identical source pairs whose only
  difference is a filename that does or does not contain the selecting fragment.
- Record acceptance, rejection, full diagnostic identity, artifacts, cleanup,
  and both retained compiler-path observations without normalizing a difference
  away.
- Map each branch to current VISION/shared-zone/compiler authority and state
  whether that authority already requires a universal rule, already defines a
  non-user-selectable internal profile, or leaves a genuine decision open.

**Exit Gate:** every live filename-selected site has positive and negative
rename witnesses, both pre-change outcomes are reproducible, the complete site
and fixture manifests are mutation-sensitive, and no compiler behaviour has
changed. If existing authority does not decide the replacement model, stop here
with the paired evidence and decision report.

## Patch 24.1a — Universal TCS Semantic Decision Authority

**Purpose:** record the operator-selected universal non-POD rule after Patch
24.1 characterization and before the report-only spelling inventory, without
changing compiler behaviour.

**Steps:**

- Preserve Patch 24.1's observations as historical evidence and record the
  selected successor authority separately.
- Require universal rejection of non-POD local declarations and guard-payload
  bindings in all Gust programs.
- Require source filenames to be semantically inert and forbid an internal
  compilation profile for these checks.
- Preserve the Patch 24.2 report-only and Patch 24.3 implementation boundaries.

**Exit Gate:** VISION, roadmap, future-sequence, registry, schema, and generated
decision authority agree on the universal rule; the observational Patch 24.1
record remains unchanged; no compiler/runtime/Stdlib source, accepted program
meaning, MIR, ABI/layout, backend route, bootstrap seed, or Patch 24.2 inventory
changes; and the authority PR's exact-head workflows and review gates pass.

## Patch 24.2 — Compiler-Recognized Semantic Spelling Inventory

**Purpose:** expose concrete stdlib/runtime spellings that compiler code treats
as semantic categories or intrinsic operations, without replacing them.

**Steps:**

- Scan compiler-owned source for exact names, prefixes, and suffixes used in
  semantic classification, source admission, type construction, code
  generation, canonical-MIR selection, ABI/layout decisions, or runtime-call
  recognition.
- Record one stable row per site with spelling, file/line identity, layer,
  decision made, semantic role, current authority, present owner, eventual
  intrinsic owner, intended later phase, reason retained, and falsifier.
- Separate semantic/intrinsic recognition from diagnostics, serialization,
  mangling, generated names, comments, fixtures, and non-decision comparisons.
- Add substitution, omission, duplicate-site, unclassified-site, and stale-line
  falsifiers. Make no intrinsic-ID, dispatch, compiler-structure, or semantic
  change.

**Exit Gate:** every compiler-recognized concrete stdlib/runtime decision site
is classified exactly once; zero unknown decision sites remain; non-semantic
spellings are explicitly partitioned; registry and generated review projection
agree; and the inventory guard detects omission, substitution, duplication,
and classification drift.

## Patch 24.2e — S1.9 Resource-Assignment Prerequisite Amendment

**Purpose:** interpose only the operator-authorized generic implicit
linear-Resource assignment correction before Stdlib S1.9 resumes, without
resuming or widening Patch 24.3.

**Steps:**

- Preserve the checked S1.9 witness as read-only cross-lane evidence and record
  its generic compiler ownership without absorbing any Stdlib path.
- Define separate implementation, conditional seed-only, and closure/handoff
  rows with pre-backend, retained-path, cleanup, and falsifier evidence.
- Pause Patch 24.3 until Stdlib S1.12 after the S1.9 handoff.

**Exit Gate:** only roadmap and required generated predecessor authority change;
the correction is generic over compiler-tracked Resource metadata; no compiler,
runtime, MIR, backend, ABI/layout, bootstrap seed, or Stdlib behaviour changes;
and the amendment PR's exact-head workflows and review gates pass.

## Patch 24.2f — Generic Implicit Linear-Resource Assignment Transfer

**Purpose:** make an implicit local binding from a compiler-tracked linear
Resource perform the same single-owner source invalidation required of an
ownership transfer, before either backend is selected.

**Steps:**

- Characterize the accepted implicit-binding gap and the already-rejected
  explicit use-after-move, extra-owner, and invalid lifecycle controls.
- When a local declaration initializer is an identifier bound to an owned,
  compiler-tracked linear Resource, bind the existing cleanup identity to the
  destination and transition the source to moved exactly once.
- Reject later source use and source-rooted protected access while preserving
  valid destination use and exactly one destination cleanup.
- Add a spelling-neutral Resource witness and structural falsifiers forbidding
  filename, fixture, backend, consumer, or stdlib-type recognition.

**Exit Gate:** the invalid aliasing program rejects with the generic
`LinearResourceUseAfterMove` diagnostic before backend selection; the valid
one-destination transfer compiles and schedules exactly one cleanup through
both retained compiler paths; generic and adversarial controls pass; no MIR,
ABI/layout, runtime, backend route/fallback, Stdlib source, or seed changes; and
`make gust` plus focused resource, cleanup, registry, and predecessor guards
pass.

## Patch 24.2g — Resource-Assignment Bootstrap Seed Reconvergence

**Purpose:** isolate any generated seed change required by Patch 24.2f.

**Steps:**

- Start from exact merged Patch 24.2f main and run the repository bootstrap
  entry point without hand-editing generated output.
- Require stage 2 and stage 3 byte identity and rerun the implicit-transfer
  positive, negative, cleanup, retained-path, and no-fallback evidence.
- Publish only `gust_v4.c`; if it is already byte-identical, record the checked
  no-diff fixed point rather than manufacture a commit.

**Exit Gate:** bootstrap reaches a byte-identical fixed point; a changed seed is
the sole PR path; the generic transfer contract remains green through both
retained paths; and no Stdlib or Phase 24.3 work is introduced.

## Patch 24.2h — S1.9 Prerequisite Closure and Stdlib Handoff

**Purpose:** close only the compiler-owned implicit Resource-transfer correction
and issue the checked handoff that permits the Stdlib lane to resume S1.9.

**Steps:**

- Re-derive the implementation and seed state from exact current main and rerun
  focused generic transfer, cleanup, retained-path, registry, predecessor, and
  no-fallback authority.
- Record exact PR heads, merge mains, workflow populations, review state, and
  the bootstrap fixed-point result, then mark Patches 24.2f–24.2h DONE.
- Notify Stdlib only after this closure merges; keep Patch 24.3 paused until
  Stdlib S1.12 reaches its checked terminal handoff.

**Exit Gate:** exact current main rejects source reuse after implicit linear
Resource transfer, preserves exactly one destination cleanup through both
retained paths, is bootstrap-converged and review-clean, and carries a durable
S1.9 handoff without changing Stdlib-owned files or beginning Patch 24.3.

## Patch 24.3 — Filename-Independent Typechecker Correction

**Purpose:** remove source-filename control over accepted meaning using only the
universal rule selected by Patch 24.1a authority and Patch 24.1 evidence.

**Steps:**

- Replace each filename-substring branch with the already-authorized universal
  semantic rule. Do not introduce an internal compilation profile.
- Do not infer meaning from path, basename, fixture identity, module name,
  source spelling, backend, or environment.
- Require all Patch 24.1 renamed pairs to become outcome-identical while
  preserving the selected diagnostic and both retained compiler paths.
- Add structural falsifiers proving the filename fragments cannot influence
  typechecking and no equivalent filename recognizer has replaced them.

**Exit Gate:** byte-identical programs produce identical acceptance,
diagnostics, artifacts, side effects, and cleanup under arbitrary filenames;
the old branches and equivalent path-selected meaning are absent; native and
retained compatibility paths agree; explicit no-fallback remains; `make gust`
passes; and no new semantic choice, MIR/ABI/runtime change, or broader refactor
was required. If this cannot be satisfied from existing authority, stop rather
than publish a rule.

## Patch 24.3a — Preflight Bootstrap Seed Reconvergence

**Purpose:** reconverge the generated bootstrap seed after the final
self-hosted typechecker correction, in an isolated seed-only publication.

**Steps:**

- Start from exact merged Patch 24.3 main and run the repository bootstrap entry
  point without hand-editing generated output.
- Require stage 2 and stage 3 byte identity and re-run the characterized
  filename-invariance cases through the rebuilt compiler.
- Publish only `gust_v4.c`. If the seed is already byte-identical, record the
  checked no-diff fixed point in preflight authority rather than manufacture a
  seed commit.

**Exit Gate:** bootstrap reaches a byte-identical fixed point; the rebuilt
compiler preserves both supported paths and Patch 24.3 behaviour; a changed
seed is the sole PR path; and no Phase 25 bootstrap-route work is introduced.

## Patch 24.4 — Opening-Preflight Closure

**Purpose:** close only the make-compiler-meaning-explicit preflight and leave
all later architecture phases inactive.

**Steps:**

- Re-run characterization, rename-invariance, spelling inventory,
  registry/schema/projection, predecessor closure, no-fallback, both retained
  compiler paths, bootstrap, consumer, guard, fixture, and workflow-reachability
  authority.
- Dispatch and independently qualify one authoritative Historical Full on exact
  merged final preflight implementation main; reject incomplete or stale job
  populations and unresolved material findings.
- Generate the preflight closure from registry source, replace evidence
  placeholders, mark every preflight row DONE, publish the atomic closure PR,
  and write a terminal lane state after merge.

**Exit Gate:** no accepted or rejected Gust meaning depends on a filename
substring; both former branch behaviours were characterized before correction;
the concrete spelling inventory is complete and report-only; bootstrap is
converged; the exact-main Historical population and closure PR are fully green;
all review threads are resolved; CR-15 remains complete and handed off; and
Phase 24 backend retirement, Phase 24.5, Phase 25, Stdlib implementation, and
Web Slice 1 remain inactive.

## Recommended Implementation Order

24.0 roadmap activation
→ 24.0a CR-15 sequencing amendment
→ 24.0b CR-15 opening and inert derivation contract
→ 24.0c protected-Resource guard derivation
→ 24.0d cross-path and adversarial qualification
→ 24.0e isolated seed reconvergence
→ 24.0f CR-15 closure and checked Stdlib handoff
→ 24.1 filename-selected behaviour characterization
→ 24.1a universal TCS semantic decision authority
→ 24.2 concrete semantic spelling inventory
→ 24.2e S1.9 Resource-assignment prerequisite amendment
→ 24.2f generic implicit linear-Resource assignment transfer
→ 24.2g conditional isolated seed reconvergence
→ 24.2h S1.9 prerequisite closure and checked Stdlib handoff
→ Stdlib S1.9–S1.12
→ 24.3 filename-independent correction
→ 24.3a isolated seed reconvergence
→ 24.4 opening-preflight closure.

CR-15 must close and hand off before Patch 24.1 begins. Characterization and its
operator-selected decision successor must merge before the inventory. The
S1.9 Resource-assignment prerequisite and its checked handoff then complete
before Stdlib S1.9 resumes; Patch 24.3 remains paused through Stdlib S1.12. A
seed cannot share a PR with compiler-source changes. Each Historical
qualification runs only after its corresponding final implementation/seed main
exists. No later phase is activated by completing this sequence.

## Opening-Preflight Success Criteria

The bounded preflight succeeds when:

- every filename-dependent typechecker branch has paired pre-change evidence;
- renaming a byte-identical source file no longer changes acceptance,
  diagnostics, artifacts, side effects, or cleanup;
- the generic correction is directly entailed by existing semantic authority,
  or the lane stopped before choosing an unresolved rule;
- every compiler-recognized concrete stdlib/runtime decision site is classified
  with owner, later phase, reason, and falsifier, while intrinsic IDs remain
  unimplemented;
- default/explicit native, retained explicit compatibility, no-fallback,
  bootstrap, package/install, diagnostic, cleanup, and artifact authority stay
  green;
- the bootstrap seed is current and stage 2/stage 3 are byte-identical;
- one authoritative Historical Full succeeds with its complete expected job
  population on exact merged final preflight implementation main; and
- generated closure authority and the terminal lane record cite exact PR head,
  merge main, workflow population, review state, Historical run, event, full
  SHA, job population, conclusion, and budgets.

This preflight may say **source filename no longer selects accepted Gust
meaning, and compiler-recognized concrete semantic spellings are completely
classified**. It may not say the generated-C backend is removed, the compiler
is consolidated, intrinsic IDs exist, the bootstrap is native, or Phase 24 is
otherwise complete.

---

# Immutable Phase 23 Completion Record — MIR-to-C Deprecation

**Lane:** Cranelift. Branches follow the existing
`codex/phase<N>-<patch>-<slug>` pattern.

Workflow, Monitoring, Merge, Phase Completion, Runner, Issue Intake, and Git
Authorization policies are defined in `AGENTS.md`. Shared semantic ownership is
defined in `docs/SHARED_SEMANTIC_ZONE.md`. This section is the immutable Phase
23 completion record; the opening preflight above is the active Cranelift
roadmap.

Phase 23 stops presenting MIR-to-C as a normal supported production backend
while preserving one frozen, explicit, live compatibility and differential lane
as a temporary semantic oracle. It does not remove the generated-C backend, the
explicit `--backend mir-to-c` / `--backend c` route, the C bootstrap seed, the
host-C bootstrap chain, retained C runtime components, or historical evidence.
Those are separately bounded Phase 24 and Phase 25 outcomes.

Before deprecation work begins, this phase completes the mandatory
post-Phase-22 assurance and issue-health checkpoint from
`docs/ROADMAP_TAIL.md`: current-main repair or retirement of stale evidence for
issues #110 and #240; the explicitly report-only Semantic Change Assurance
Phases A and B pilot using those real failures; and the bounded #105
same-lexical-scope declaration diagnostic with isolated bootstrap
reconvergence. No MIR-to-C support reduction begins until that checkpoint is
closed.

## Roadmap Activation

Phase 22 formally closed on 2026-08-30. Its closure PR #268 completed **113/113**
strict exact-head `pull_request` workflows and **262/262** job checks, including
`Codex / Trusted actor`, with zero review threads. Exact head
`9186804ad88b87d4a95f42098b5a2474a34b2fde` merged as exact main
`2664f4a349bfc0a0f9de3a1ed691254cc85f9d55`.

The Phase 22 closure authority cites `Cranelift Historical Full` run
`33303824486`, event `schedule`, completed `success` with **18/18** jobs on exact
final post-flip implementation main
`a7adbcd186512a3b4fd99b953bb2bc30f6838c52`. The latest run was independently
re-derived before this roadmap was written; its success is predecessor evidence,
not Phase 23 closure evidence.

On 2026-08-30 the operator explicitly authorized Phase 23 roadmap preparation
and activated the Cranelift Phase Completion Loop through Phase 23 closure. The
same instruction requires the post-Phase-22 assurance/issue-health checkpoint
to complete before deprecation patches. This activation authorizes only the
report-only Semantic Change Assurance Phase A/B pilot described below. It does
not authorize Assurance Phases C–E, a protected publisher, a new required
status, repository-rule changes, or model review as merge authority.

Activation is Cranelift-only. It does not authorize Phase 24 generated-C
removal, Phase 25 bootstrap-C removal, edits to `TASK_STDLIB.md`, Stdlib work,
CR-15, or an operator-owned semantic/product decision.

## Phase Boundary

In scope:

- current-main repair or principled retirement of issues #110 and #240's stale
  control-plane evidence, with retained invariants reachable and green;
- one generic Patch 23.3a source-admission handoff for already-defined
  full-program `GuardUnwrap` and `ScheduleDefer` canonical operations, so an
  earlier bounded structured-CFG probe cannot preempt that existing native
  route;
- Semantic Change Assurance Phase A authority/trigger inventory and Phase B
  deterministic evaluator in report-only mode, using #110 and #240 as concrete
  stale-evidence inputs and preparing #105 as the selected current pilot;
- rejection of only a second local declaration in the same lexical scope for
  #105, while preserving parent-scope shadowing, disjoint-block reuse,
  assignment/rebinding, parameters, globals, and same-named locals in different
  functions;
- an exact inventory of MIR-to-C CLI spellings, implementation entry points,
  accepted capabilities, active callers, workflows, packages, release paths,
  bootstrap use, fixtures, downstream dependencies, and generated artifacts;
- deprecation marking in compiler help, root user documentation, generated
  authority, and compatibility contracts without removing either explicit C
  spelling or changing its generated bytes;
- a frozen accepted MIR-to-C feature surface and a guard forbidding new
  C-only feature implementation;
- removal of MIR-to-C from default CI matrices while retaining one focused live
  explicit-C compatibility/differential lane with complete expected inventory;
- a frozen archived reference corpus carrying expected output, exit status,
  diagnostics, filesystem effects, resource effects, artifact identity, and
  provenance for cases no longer requiring live C execution;
- a production, release, package/install, and downstream audit proving no
  supported production or release workflow requires MIR-to-C;
- exact native no-fallback, default/explicit Cranelift identity, retained-C
  compatibility, bootstrap, package/install, exact-head PR, review, and
  exact-final-implementation-main Historical Full qualification;
- generated Phase 23 closure authority and a terminal lane record.

Out of scope:

- deleting, disabling, or making either explicit C backend spelling fail;
- deleting MIR-to-C implementation, generated-C publication code, C compiler
  discovery, C-specific errors, temporary C files, or historical C fixtures;
- replacing live MIR-to-C with archived expectations everywhere; one focused
  live oracle lane remains until Phase 24;
- removing or replacing `gust_v4.c`, changing `make gust` / `make bootstrap`
  away from explicit MIR-to-C, removing the host C compiler from bootstrap, or
  claiming a native bootstrap seed;
- changing accepted Gust meaning except the exact roadmap-authorized #105
  rejection; adding or changing canonical MIR operations or their meaning,
  except for Patch 23.3a's generic source-admission handoff to the existing
  full-program `GuardUnwrap` and `ScheduleDefer` lowering; changing ABI/layout,
  runtime symbols, target/linker policy, resource/move/provenance
  semantics, or Phase 9G ownership;
- adding a fallback, retry-through-C, environment-selected route, feature
  exception, compiler-module exception, stdlib-type exception, or backend-only
  semantics;
- implementing Assurance Phases C–E, independent model review, protected
  publication, repository-rule changes, or a new required check;
- editing Stdlib-owned sources, `TASK_STDLIB.md`, CR-15, or beginning Phase 24
  or Phase 25.

## Status

- [x] Patch 23.0 — Phase 23 Roadmap Activation — DONE
- [x] Patch 23.1 — Post-Phase-22 Assurance and Issue-Health Opening — DONE
- [x] Patch 23.2 — MIR Evidence-Owner Repair and Retirement (#110) — DONE
- [x] Patch 23.3 — Resource-Acquisition Parity Evidence Repair (#240) — DONE
- [x] Patch 23.3a — Structured Guard/Defer Native Admission — DONE
- [x] Patch 23.4 — Assurance Phase A Authority and Trigger Inventory — DONE
- [x] Patch 23.5 — Assurance Phase B Deterministic Report-Only Evaluator — DONE
- [x] Patch 23.6 — Same-Scope Declaration Diagnostic (#105) — DONE
- [x] Patch 23.6a — Diagnostic Bootstrap Seed Reconvergence — DONE
- [x] Patch 23.7 — MIR-to-C Deprecation Opening and Consumer Inventory — DONE
- [x] Patch 23.8 — User-Facing MIR-to-C Deprecation Contract — DONE
- [x] Patch 23.8a — Deprecation Bootstrap Seed Reconvergence — DONE
- [x] Patch 23.9 — Frozen MIR-to-C Feature Surface — DONE
- [x] Patch 23.10 — Focused Live Compatibility Lane and Default-CI Retirement — DONE
- [x] Patch 23.11 — Archived MIR-to-C Reference Corpus — DONE
- [x] Patch 23.12 — Production, Release, Package, and Downstream Audit — DONE
- [x] Patch 23.13 — Cross-Feature Qualification and Residue Audit — DONE
- [x] Patch 23.14 — Exact-Main Historical Full Qualification — DONE
- [x] Patch 23.15 — Phase 23 Closure — DONE

Status rows are machine-parsed. Keep each row as
`- [ ] Patch 23.N — <Title>` or `- [x] Patch 23.N — <Title> — DONE`; an
inserted amendment may append one lowercase letter to `N`.

## Immutable Contracts

- Cranelift remains the default production backend. Bare Gust and explicit
  `--backend cranelift` use the same shared post-semantic-pipeline route and
  remain observably identical.
- Cranelift never falls back to MIR-to-C. Unsupported native behaviour remains
  an explicit compilation failure with Phase 9G output preservation and cleanup.
- `--backend mir-to-c` and `--backend c` remain accepted, byte-identical
  spellings of the same generated-C route throughout Phase 23. Deprecation is
  not removal.
- MIR-to-C remains the temporary semantic oracle only through one focused live
  compatibility/differential lane and the exact bootstrap callers that Phase 25
  owns. Other parity moves to frozen reference evidence; absence never counts as
  success.
- The accepted MIR-to-C feature surface is frozen. A new feature may not be
  implemented only in MIR-to-C, and no registry, fixture, or workflow may
  classify fallback, unsupported, empty, stale, wrong-event, or wrong-SHA
  evidence as parity.
- `make gust`, `make bootstrap`, and `gust_v4.c` retain their explicit
  MIR-to-C/host-C chain. Seed regeneration remains isolated and stage 2/stage 3
  must be byte-identical.
- Phase 23 changes no canonical MIR, ABI/layout, runtime symbols, target/linker
  policy, resource/move/provenance semantics, or Phase 9G artifact ownership.
- The #105 correction rejects only a second declaration in the current lexical
  scope. Parent-scope shadowing and disjoint lexical block reuse remain legal.
- Assurance is report-only. Its evaluator may fail loudly as a command on
  malformed input, but no new required status, repository rule, privileged
  publisher, or candidate-controlled approval path is introduced.
- Production/release independence from MIR-to-C does not imply bootstrap
  independence from C, removal of retained C runtime objects, or repository-wide
  C absence.
- No compiler-module, fixture-name, source-spelling, or stdlib-type exception is
  permitted.

## Validation Model

**Level 1 — fast authority and contract checks:** exact roadmap/status parsing,
issue/evidence ownership, assurance schema and loss taxonomy, deprecation
spelling/help, frozen-surface inventory, workflow reachability, package/release
classification, generated projection freshness, explicit-C spelling identity,
no-fallback, and closure guards.

**Level 2 — focused behavioural evidence:** #105 positive/negative scope cases;
#240 positive executable and negative diagnostic parity; the frozen live
compatibility corpus through explicit C and Cranelift; archived-reference
replay; default/explicit native identity; explicit-C byte identity; package,
install, cleanup, side-effect, diagnostic, and artifact comparisons.

**Level 3 — exact final implementation evidence:** one authoritative
`Cranelift Historical Full` run on the exact merged final Phase 23
implementation main, with its complete registry-derived job population
successful and zero unresolved material review findings. The run ID, full SHA,
event, status, conclusion, job population, and budgets are recorded in generated
authority before closure publication. A stale, red, partial, wrong-event, or
wrong-SHA run cannot close the phase.

Every PR is qualified only by the complete workflow population filtered to its
exact full 40-character head SHA and `event == "pull_request"`, plus current-main
ancestry and zero unresolved non-outdated review threads. Local validation is
advisory; GitHub Actions is authoritative.

## Patch 23.0 — Phase 23 Roadmap Activation

**Purpose:** activate a bounded MIR-to-C deprecation sequence from exact Phase
22 closure without changing compiler, backend, route, CI, package, bootstrap, or
user-visible behaviour.

**Steps:**

- Replace the active Phase 22 roadmap with this Phase 23 roadmap while
  preserving Phase 22 as an immutable completion record.
- Record the operator activation, exact Phase 22 closure PR/head/merge,
  pull-request population, review state, and predecessor Historical Full.
- Preserve Phase 21 and Phase 22 guards by retargeting only their `TASK.md`
  lookups to immutable predecessor sections.
- Define the mandatory checkpoint, patch order, invariants, stop boundaries,
  validation levels, Historical authority, and Phase 24/25 exclusions.

**Exit Gate:** `TASK.md` opens Phase 23, the complete roadmap is mechanically
reviewable, Phase 22 closure remains green from its immutable record, no
behavioural file changes, and the roadmap PR's exact-head workflows and review
gates pass.

## Patch 23.1 — Post-Phase-22 Assurance and Issue-Health Opening

Build a current-main generated inventory for issues #110, #240, and #105. Re-run
each named reproduction from its authoritative entry point; classify current
owner, invariant, reachability, expected result, actual result, superseding
authority, semantic effect, bootstrap effect, and closure falsifier. Record the
live open-issue set, exact Level 3 baseline, workflow/ruleset facts, and the
Assurance Phase A/B report-only authorization boundary. Change no guard,
compiler behaviour, backend route, or issue state.

**Exit Gate:** every checkpoint issue has a current-main reproduction and one
bounded successor patch; no stale issue prose is treated as evidence; and no
deprecation patch may start before Patches 23.2–23.6a are DONE.

## Patch 23.2 — MIR Evidence-Owner Repair and Retirement (#110)

Repair `guard-mir-lower-tiny-function-surface` against the complete live
fixture-only lowering cohort, state its retained invariant, make it reachable in
the normal guard topology, and add a falsifier proving production lowering use
still rejects. Retire `guard-mir-to-c-tiny-surface` rather than growing the
obsolete location allowlist: remove its recipe, reachability exemption, stale
references, and ownership claims, while preserving all executable MIR-to-C
behavioural guards. Record the retirement reason and prove the name has no live
caller. Close issue #110 only after the merged current-main guard passes and the
issue and routing ledger cite the exact PR/merge evidence.

**Exit Gate:** the retained lowering-surface invariant is reachable, green, and
mutation-sensitive; the obsolete guard is absent with zero dangling references;
no production MIR/MIR-to-C capability or semantics changed; and #110 has
current-main closure evidence.

## Patch 23.3 — Resource-Acquisition Parity Evidence Repair (#240)

Preserve #106 acquisition, leak, transfer, destructor, and negative-diagnostic
semantics. Replace only the pre-migration positive native deferral assertions
with the current registry-owned supported route: build/discover the explicit
native driver, require successful executable publication, run the selected
positive user and directory cases, and compare exit status, streams, cleanup,
and registered observables with MIR-to-C. Retain explicit no-fallback and all
negative diagnostic parity. Make the complete Level 2 guard reachable. Close
#240 only after merged current-main evidence and update the routing ledger.

**Exit Gate:** every positive case exercises the real driver and matches its
oracle observables; every negative case retains its compiler-owned diagnostic;
the guard rejects missing driver, fallback, missing artifact, stale deferral,
and empty selection; no resource semantics changed; and #240 has current-main
closure evidence.

## Patch 23.3a — Structured Guard/Defer Native Admission

On 2026-08-30 the operator authorized this inserted Cranelift-owned
prerequisite after Patch 23.3 re-derived that a valid directory acquisition
program is preempted before driver discovery by the bounded structured-CFG
probe. Make the generic source-admission handoff route typed `guard` and
`defer` statements to the existing full-program canonical-MIR operations
`GuardUnwrap` and `ScheduleDefer`. Preserve their existing validation and
Cranelift lowering. The handoff must be based on typed AST operation kind, not
on a resource, directory, fixture, module, or source-path exception.

This patch does not add a MIR operation, change the meaning of an existing MIR
operation, change resource acquisition, cleanup, destructor, move, provenance,
ABI, layout, runtime, target, linker, fallback, or publication semantics. It
does not widen the earlier bounded structured-CFG subset: loop/backedge,
short-circuit, and unsupported condition deferrals remain explicit. MIR-to-C
remains the semantic oracle.

**Exit Gate:** the generic handoff is registry-owned and schema-validated;
positive guard/defer source reaches the existing native full-program driver and
matches MIR-to-C exit status, streams, artifact policy, and registered cleanup
observables; retained unsupported structured-CFG categories remain deferred
before driver discovery; mutation-sensitive tests reject restoration of the
preempting deferral or a fixture/path-specific exception; and no canonical MIR
operation, semantic authority, ABI/layout/runtime symbol, bootstrap seed, or
Stdlib/CR-15 authority changes.

## Patch 23.4 — Assurance Phase A Authority and Trigger Inventory

Implement only `docs/SEMANTIC_CHANGE_ASSURANCE.md` Phase A under the operator's
report-only authorization. Define one versioned envelope schema and generated
human rendering. Use #110 and #240 as the two historical stale-evidence inputs,
and select #105 as the upcoming R1 pilot. Map each to current TASK, VISION,
shared-zone, issue, registry, fixture, workflow, bootstrap, and Level 3
authorities. Record exact source/base identities, expected inventories, loss
states, current ruleset/workflow facts, assumptions, non-goals, and authority
classification. Add no workflow, required status, reviewer role, publisher, or
repository-rule change.

**Exit Gate:** a cold reader can classify #110, #240, and planned #105; name
their authoritative evidence without manually reading every workflow; and
distinguish operator authority, inherited contracts, assumptions, parked scope,
candidate evidence, and closure evidence.

## Patch 23.5 — Assurance Phase B Deterministic Report-Only Evaluator

Implement a deterministic evaluator for the Phase A envelope. It validates
schema/version, full candidate/base identities, expected versus observed
inventories, exact `pull_request` event/full-SHA populations, artifact digests,
and the common loss taxonomy. It must distinguish passed, failed, unsupported,
skipped-with-reason, not-applicable, not-executed, empty, fallback, malformed,
stale, and unresolved evidence. Exercise the evaluator on the merged #110 and
#240 records, a closed historical patch, and focused wrong-SHA, wrong-event,
cancelled, red, missing, empty, malformed, forged-digest, and
candidate-policy-change fixtures. It remains report-only and consumes captured
deterministic manifests; no privileged workflow executes candidate code.

**Exit Gate:** the evaluator accepts the complete qualified fixtures and rejects
every loss/identity falsifier; generated reports are deterministic; #105 has a
valid pre-implementation envelope; and no existing merge/closure policy or
required status changed. Assurance Phases C–E remain inactive.

## Patch 23.6 — Same-Scope Declaration Diagnostic (#105)

Reproduce same-scope duplicate declaration, disjoint-block reuse, parent-scope
shadowing, assignment, and different-function reuse through the live compiler.
Add current-lexical-scope duplicate detection at declaration insertion with one
stable Gust diagnostic. Do not walk parent scopes for this check. Add focused
negative and positive fixtures, default Cranelift behaviour, explicit MIR-to-C
diagnostic evidence, and a report-only #105 assurance envelope/result. Correct
`GEMINI.md` §C so it states the lexical rule rather than the false whole-function
rule. Close #105 only after merged current-main semantic and bootstrap-sensitive
evidence and update the routing ledger.

**Exit Gate:** exactly same-scope redeclaration rejects before either backend;
all valid shadowing/reuse/assignment cases remain accepted; both backend routes
agree on acceptance and diagnostics; `make gust` passes; #105 is closed with
current-main evidence; and the only expected seed change is deferred to 23.6a.

## Patch 23.6a — Diagnostic Bootstrap Seed Reconvergence

On 2026-08-31 the operator authorized the measured seed-attribution correction:
the last committed seed predates both the already-merged Patch 23.3a generic
guard/defer native-admission handoff and Patch 23.6's #105 current-scope
diagnostic. This changes only which already-merged compiler-source deltas the
generated seed is authorized to serialize; it adds no semantic or backend
authority.

From exact merged 23.6 main, run the isolated bootstrap sequence, require stage
2/stage 3 byte identity, account for every generated difference as either Patch
23.3a's generic guard/defer admission or #105's current-scope diagnostic, and
publish `gust_v4.c` alone. Do not fold roadmap, guard, fixture, registry, or
documentation changes into the seed PR.

**Exit Gate:** the seed-only diff is fully explained by exactly those two
already-merged compiler-source authorities, `make bootstrap` reaches the fixed
point, all exact-head workflows pass, reviews are resolved, and the mandatory
post-Phase-22 checkpoint is formally DONE before Patch 23.7 begins.

## Patch 23.7 — MIR-to-C Deprecation Opening and Consumer Inventory

Inventory every explicit-C spelling, parser/help branch, generated-C entry
point, accepted capability, runtime/compiler dependency, bootstrap caller,
workflow, matrix cell, guard, fixture, script, package/install/release path,
documentation claim, downstream consumer, output artifact, and temporary file.
Classify each as `bootstrap_phase25`, `focused_live_oracle`,
`archive_candidate`, `production_or_release_migration`, `historical_only`, or
`unclassified`, with owner, current route, deprecation action, removal phase,
and falsifier. Record the exact pre-deprecation C surface and bytes. Change no
route or presentation.

**Exit Gate:** the registry-derived inventory is complete with zero unclassified
consumer or artifact; every live C dependency has one Phase 23/24/25 owner; the
pre-deprecation bytes and observables are reproducible; and partial inventory or
same-count substitution fails.

## Patch 23.8 — User-Facing MIR-to-C Deprecation Contract

Mark both explicit C spellings deprecated in compiler help, root user-facing
documentation, and generated authority, with removal scheduled for Phase 24 and
bootstrap retirement explicitly deferred to Phase 25. Keep both spellings
accepted and byte-identical. Convey deprecation through help/documentation and
do not add stdout/stderr noise to ordinary compilation, bootstrap, or focused
oracle execution. Preserve explicit native/default identity and no fallback.

**Exit Gate:** users can discover the deprecation and timeline without invoking
a failing route; explicit C output is byte-identical to the Patch 23.7 baseline;
default/explicit Cranelift remains identical; no compilation diagnostic or
accepted-program meaning changed; and all active claims distinguish backend
retirement from bootstrap-C retirement.

## Patch 23.8a — Deprecation Bootstrap Seed Reconvergence

After compiler help/source reaches its final Phase 23 deprecation form,
regenerate `gust_v4.c` in a seed-only PR. Require stage 2/stage 3 byte identity
and account for every diff as the 23.8 presentation change. Do not change CLI
routing, generated program C, tests, registries, or guards in the seed patch.

**Exit Gate:** bootstrap converges, the seed-only diff is explained, both
explicit C spellings still emit the same bytes, and no further Phase 23 patch
requires a compiler-source or seed change.

## Patch 23.9 — Frozen MIR-to-C Feature Surface

Freeze the accepted MIR-to-C capability and fixture surface from Patch 23.7 in
canonical registry/schema authority. Classify maintenance as compatibility
correction only. Add guards that reject a new C-only capability, added accepted
feature, omitted existing frozen case, feature-name substitution, backend-only
semantic claim, fallback, or weakened expected inventory. A new Gust feature
must first have an authorized shared semantic definition and supported
Cranelift path; Phase 23 may not expand C to lead it.

**Exit Gate:** every accepted live-C case is frozen by complete identity and
observable contract; mutation fixtures prove additions, omissions, and
same-count substitutions reject; existing explicit-C output is unchanged; and
no backend capability changed.

## Patch 23.10 — Focused Live Compatibility Lane and Default-CI Retirement

Create one registry-derived focused live compatibility/differential lane over a
representative frozen cohort spanning success, rejection, resources, modules,
typed queries, output artifacts, and side effects. Remove MIR-to-C cells from
default production/native CI matrices and route every remaining live C
execution to the focused lane or the explicit bootstrap classification. Preserve
Level 1 semantic guards and native tests. Require exact non-empty inventory,
explicit backend selection, no fallback, time/memory budgets, and path-filter
coverage for every authority input.

**Exit Gate:** exactly one non-bootstrap live compatibility lane owns the
registered C differential cohort; default CI matrices contain no MIR-to-C cell;
all removed coverage is mapped to the focused lane or archived successor; and
the focused lane passes with zero unexplained difference.

## Patch 23.11 — Archived MIR-to-C Reference Corpus

Generate a versioned, immutable reference corpus from the complete registered
archive-candidate set on one exact source/compiler/toolchain environment. Record
source identity, oracle route, output/diagnostic/side-effect/artifact contract,
digests, provenance, supersession policy, and loss state for every case. Replay
default/explicit Cranelift against those references. Do not hand-author expected
bytes, silently refresh a mismatch, or replace the focused live lane.

**Exit Gate:** every archived case has complete provenance and deterministic
replay; missing, stale, malformed, empty, wrong-source, wrong-toolchain, and
digest-substituted references fail; Cranelift matches every applicable expected
observable; and the live-C population remains exactly the focused cohort.

## Patch 23.12 — Production, Release, Package, and Downstream Audit

Re-scan build, package, install, release, examples, scripts, tests, workflows,
documentation, and known downstream consumers. Migrate supported production and
release paths to default/explicit Cranelift. Keep only classified Phase 25
bootstrap callers and the Patch 23.10 focused oracle lane live. Record the Phase
24 backend-removal and Phase 25 bootstrap-removal timelines without promising
repository-wide C absence. Validate package contents, installed/relocated use,
cleanup, failure diagnostics, and no-fallback from a clean environment.

**Exit Gate:** no supported production or release workflow requires MIR-to-C;
every remaining explicit-C invocation is exactly classified as focused oracle
or Phase 25 bootstrap; package/install/release paths are native; downstream
unknown count is zero; and explicit C remains available for its temporary role.

## Patch 23.13 — Cross-Feature Qualification and Residue Audit

Run the complete Phase 23 Level 1/2 authority, issue-health, assurance,
deprecation, frozen-surface, focused-live, archive-replay, package/install,
bootstrap, default/explicit-native, explicit-C identity, cleanup, side-effect,
diagnostic, target, and no-fallback gates. Re-run the consumer scanner and
workflow reachability audit. Classify every residue with owner, phase, reason,
and falsifier; reject any per-module/per-fixture exception or unexplained
difference. This is the final implementation patch.

**Exit Gate:** the complete declared Phase 23 corpus is green; #105, #110, and
#240 are closed on current main; Assurance A/B is report-only and complete; no
production/release C requirement or unclassified caller remains; bootstrap and
the focused oracle lane remain healthy; and zero unexplained divergence or
material finding remains.

## Patch 23.14 — Exact-Main Historical Full Qualification

After Patch 23.13 merges, dispatch one authoritative `Cranelift Historical Full`
on that exact final implementation main. Require the complete registry-derived
job population, including the focused MIR-to-C compatibility successor,
assurance/issue-health owners, native default/package/bootstrap coverage, and
all retained historical shards. Record exact run ID, full SHA, event, status,
conclusion, job population, elapsed budgets, and zero unresolved material review
findings in generated Phase 23 authority. If an applicable Phase 23 input lands
on main before closure publication, rebase, requalify, and replace stale Level 3
evidence.

**Exit Gate:** the authoritative run is complete success on the exact merged
final implementation main, every expected job is present exactly once, zero
unfinished/non-success job or unresolved material finding exists, and no pulse,
registrar relay, stale run, or partial artifact is used as evidence.

## Patch 23.15 — Phase 23 Closure

Re-run the opening inventory, checkpoint issue closures, Assurance A/B,
deprecation, frozen surface, focused live lane, archived corpus, production and
release audit, package/install, bootstrap, no-fallback, exact-C spelling
identity, cross-feature, and Historical authority guards. Generate closure from
registry source, replace all placeholders with checked evidence, mark every row
DONE, publish the atomic closure PR, and write the terminal lane state only after
merge.

**Exit Gate:** every Phase 23 row is DONE; all Success Criteria below pass; the
latest applicable exact-final-implementation-main Historical Full is green with
its complete job population; every exact-head closure workflow succeeds; review
threads are resolved; and no supported production or release workflow requires
MIR-to-C. Phase 24 and Phase 25 remain inactive.

## Phase 23 Closure Record

Phase 23 closes with explicit `--backend mir-to-c` and `--backend c` accepted,
byte-identical, and deprecated for Phase 24 backend removal. Cranelift remains
the default and explicit native route with no C fallback. Exactly one focused
non-bootstrap live compatibility lane remains, all other selected parity uses
the versioned archived corpus, and no supported production, package/install,
or release workflow requires MIR-to-C. The five explicit bootstrap callers and
`gust_v4.c` fixed-point chain remain owned by Phase 25.

Authoritative `Cranelift Historical Full` run **33584176425**, event
`workflow_dispatch`, completed `success` on exact final implementation main
**fee6600d86f85f8a0a0da94211ae89895869187e** with **18/18** jobs successful,
zero unfinished/non-success jobs, and recorded run/max-job/aggregate budgets of
5414/4286/22697 seconds. Patch 23.14 PR #297 merged from exact head
`b646bd4b84b8b804910880c4efed8b7831d31e87` as exact main
`8985a3d09b1f119accd12cd952940ef019d6a698` after 124/124 exact-head
`pull_request` workflows succeeded and all review conversations were resolved.
The generated closure record is `docs/PHASE23_CLOSURE.md`; the terminal lane
record is written only after the closure PR merges. Phase 24 and Phase 25
remain inactive.

## Recommended Implementation Order

23.0 roadmap activation
→ 23.1 checkpoint opening
→ 23.2 #110 evidence health
→ 23.3a generic guard/defer native admission
→ 23.3 #240 parity health
→ 23.4 Assurance A
→ 23.5 Assurance B report-only evaluator
→ 23.6 #105 lexical diagnostic
→ 23.6a diagnostic seed reconvergence
→ 23.7 deprecation inventory
→ 23.8 user-facing marking
→ 23.8a deprecation seed reconvergence
→ 23.9 frozen C surface
→ 23.10 focused live lane/default-CI retirement
→ 23.11 archived corpus
→ 23.12 production/release/downstream audit
→ 23.13 complete qualification
→ 23.14 Historical Full
→ 23.15 closure.

Patches 23.1–23.6a are a hard predecessor gate. Patch 23.7 may not begin while
any of #105, #110, or #240 lacks current-main closure evidence. Patch 23.9 must
freeze the complete inventory before 23.10 reduces live matrices. Patch 23.11
must archive and validate coverage before 23.12 can claim no production/release
dependency. Patch 23.14 runs only after the final implementation patch merges.

## Phase 23 Success Criteria

Phase 23 succeeds when:

- issues #105, #110, and #240 are closed with exact current-main evidence and
  moved from the issue roadmap's open register to its closed ledger;
- every retained guard states a live invariant, is reachable, passes, and has a
  falsifier; no obsolete guard remains merely because it once existed;
- Semantic Change Assurance Phases A/B produce a versioned envelope and
  deterministic report-only evaluator that detects the required identity,
  inventory, loss-state, and candidate-policy falsifiers without becoming merge
  authority;
- only same-current-lexical-scope duplicate declarations reject, while
  parent-scope shadowing and disjoint-block reuse remain accepted;
- Cranelift remains the default and explicit native route with no C fallback;
- explicit `mir-to-c` and `c` remain accepted, byte-identical, and clearly
  marked deprecated for Phase 24 removal;
- the accepted MIR-to-C feature surface is frozen and a new C-only feature is
  mechanically rejected;
- exactly one focused non-bootstrap live-C compatibility/differential lane
  remains, with complete non-empty registry-derived inventory;
- all other selected differential evidence uses the versioned archived
  reference corpus with complete identity and digest validation;
- no supported production, package/install, or release workflow requires
  MIR-to-C;
- `make gust`, `make bootstrap`, and `gust_v4.c` remain explicitly owned by the
  Phase 25 C-bootstrap boundary and bootstrap reaches its fixed point;
- package/install, default/explicit native identity, diagnostics, side effects,
  cleanup, artifacts, target/linker, and no-fallback evidence remain green;
- one authoritative Historical Full succeeds with its complete expected job
  population on exact merged final Phase 23 implementation main; and
- generated closure authority and the terminal lane record cite exact PR head,
  merge main, workflow population, review state, Historical run, event, full
  SHA, job population, conclusion, and budgets.

Phase 23 closure may say **MIR-to-C is deprecated and no supported production or
release workflow requires it**. It may not say Gust no longer emits C, the
generated-C backend is removed, the repository contains no C, the bootstrap is
native, or a host C compiler is unnecessary. Those are Phase 24 and Phase 25
claims.

---

# Immutable Phase 22 Completion Record — Cranelift Default Backend Transition

**Lane:** Cranelift. Branches follow the existing
`codex/phase<N>-<patch>-<slug>` pattern.

Workflow, Monitoring, Merge, Phase Completion, Runner, and Git Authorization
policies are defined in `AGENTS.md`. Shared semantic ownership is defined in
`docs/SHARED_SEMANTIC_ZONE.md`. This section is the immutable Phase 22 record;
the opening preflight above is the active Cranelift roadmap.

Phase 22 changes the compiler's default route from MIR-to-C to Cranelift while
retaining MIR-to-C as the semantic oracle and an explicit supported backend.
The transition is deliberately staged: first inventory every implicit backend
consumer, then make C-dependent repository callers explicit while the default
is still C, then establish native output and package contracts, and only then
flip the default. The phase does not delete, deprecate, or weaken MIR-to-C.

The phase adds no Gust source semantics, canonical-MIR operation, ABI/layout
rule, runtime symbol, target, linker, or native capability. If the live default
cohort exposes such a requirement, that work is outside this phase and must be
reported under the shared-zone stop conditions rather than hidden in routing.

## Roadmap Activation

Phase 21 formally closed on 2026-08-29. `Cranelift Historical Full` run
`33216889936`, event `workflow_dispatch`, completed `success` with 18/18 jobs on
exact corrected implementation main
`acd9e13841215d3c1aaf6e56589d6bacd45c6d4e`. The generated closure PR #247
then completed 103/103 strict exact-head `pull_request` workflows with zero
unresolved non-outdated review threads and merged as exact main
`e0951f1fbe1bcb8720b948c0aa97639068f35d95`.

On 2026-08-29 the operator explicitly activated Phase 22 roadmap authoring from
that exact main and directed the lane to qualify and merge the atomic roadmap
PR before continuing through the activated Phase Completion Loop. This roadmap
records that activation through Patch 22.9.

On 2026-08-29 the operator replaced Patch 22.8's repeated daily stability
window with one authoritative `Cranelift Historical Full` qualification on the
exact merged final post-flip implementation main. The complete registry-derived
job population must succeed and zero material review findings may remain
unresolved. This amendment changes only the stability evidence cardinality and
calendar policy. Patch 22.2 was the active implementation boundary when the
amendment was recorded; subsequent completion is governed by the live Status.

Activation is Cranelift-only. It does not authorize Phase 23, MIR-to-C
deprecation or removal, edits to `TASK_STDLIB.md`, Stdlib implementation, or
compiler-owned CR-15 work.

## Phase Boundary

In scope:

- the backend-selection default and its CLI/help/documentation contract;
- the retained `mir-to-c` spelling plus an additive `c` alias for the retained
  oracle route described by `docs/ROADMAP_TAIL.md`;
- a deterministic compiler-owned executable-output intent when Cranelift is
  selected without `-o`, with explicit `-o` remaining authoritative;
- complete classification and migration of repository callers that currently
  depend on an implicit C-emission default;
- native worker/runtime packaging, installation, discovery, failure
  diagnostics, cleanup, and atomic output preservation for the default route;
- default-versus-explicit Cranelift identity and pre-flip-versus-explicit-C
  byte identity;
- CI and release qualification, an exact post-flip stability qualification,
  and a generated closure record backed by successful Level 3 evidence;
- one isolated bootstrap-seed reconvergence after the compiler entry source has
  reached its final Phase 22 form.

Out of scope:

- deleting, freezing, or deprecating MIR-to-C, or reducing its focused
  differential coverage;
- changing accepted Gust-program meaning, diagnostics from the shared semantic
  pipeline, canonical MIR, Cranelift lowering, ABI/layout, runtime symbols,
  target policy, linker policy, or Phase 9G artifact ownership;
- adding fallback, retry-through-C, environment-selected backend routing,
  worker PATH search, auto-build, download, or shell-command execution;
- making the native compiler the bootstrap seed or claiming that Gust no longer
  requires C to build itself; those are later roadmap phases;
- editing Stdlib-owned roadmaps, guards, workflows, registries, APIs, or CR-15;
- beginning Phase 23.

## Status

- [x] Patch 22.0 — Phase 22 Roadmap Activation — DONE
- [x] Patch 22.1 — Opening Default-Route and Consumer Inventory — DONE
- [x] Patch 22.2 — Explicit C Route and No-op Consumer Migration — DONE
- [x] Patch 22.2a — Cross-Lane Explicit-C Relay Publication Authority — DONE
- [x] Patch 22.2b — Post-Relay Prerequisite Reconciliation — DONE
- [x] Patch 22.3 — Native Implicit-Output Contract — DONE
- [x] Patch 22.4 — Default-Native Package and Install Qualification — DONE
- [x] Patch 22.5 — Pre-flip Default-Cohort Qualification — DONE
- [x] Patch 22.6 — Cranelift Default Route Flip — DONE
- [x] Patch 22.6a — Default-Route Bootstrap Seed Reconvergence — DONE
- [x] Patch 22.7 — Post-flip CI, Documentation, and Rollback Qualification — DONE
- [x] Patch 22.7a — Post-Merge Review Corrections — DONE
- [x] Patch 22.7b — Exact Six-Site Relay Transition Authority — DONE
- [x] Patch 22.8 — One-Time Default-Native Stability Qualification — DONE
- [x] Patch 22.9 — Phase 22 Closure — DONE

Status rows are machine-parsed. Keep each row as
`- [ ] Patch 22.N — <Title>` or `- [x] Patch 22.N — <Title> — DONE`; an
inserted amendment may append one lowercase letter to `N`.

## Immutable Contracts

- MIR-to-C remains the semantic oracle throughout Phase 22. Explicit
  `--backend mir-to-c` and `--backend c` select the same retained code-generation
  path and remain byte-identical for accepted source.
- Cranelift never falls back to MIR-to-C. Default-native and explicit-native
  failure have the same classification, diagnostic, cleanup, and output
  preservation behavior.
- Bare default-native and explicit `--backend cranelift` use the same shared
  resolver, parser, typechecker, canonical-MIR, worker, runtime-package, target,
  linker, and Phase 9G publication route.
- The backend is selected only after the shared semantic pipeline. The default
  flip changes routing policy, not the meaning or validity of a Gust program.
- A pre-existing output survives every rejection or failed native build
  byte-for-byte. Transient requests, bundles, objects, and temporary executables
  are cleaned under existing Phase 9G authority.
- The repository's C-dependent bootstrap and oracle callers become explicit
  while C is still the default. No compiler-owned consumer is migrated in the
  same patch that changes the default.
- A consumer owned by the Stdlib lane is classified and relayed, not edited by
  the Cranelift lane. The default flip cannot land with an unclassified or
  unmigrated required consumer.
- `make gust` and `make bootstrap` retain their C bootstrap chain. Phase 22 does
  not claim the Phase 25 native bootstrap-seed outcome.
- `gust_v4.c` is generated only in the isolated 22.6a patch after stage-2 and
  stage-3 C are byte-identical.
- No compiler-module, fixture-name, source-spelling, or stdlib-type exception is
  permitted.

## Patch 22.0 — Phase 22 Roadmap Activation

**Purpose**

Activate a bootstrap-safe, evidence-gated default-backend transition from the
exact Phase 21 closure without changing compiler behavior.

**Steps**

- Replace the active Phase 21 roadmap with this Phase 22 roadmap while
  preserving Phase 21 as an immutable completion record.
- Record the exact predecessor Historical Full, closure PR head, strict
  pull-request population, review state, and merge commit.
- Preserve prior-phase roadmap and closure guards by retargeting only their
  `TASK.md` lookup to the immutable Phase 21 section.
- Make no compiler, MIR, backend, ABI/layout, runtime-symbol, target, linker,
  package, default-route, seed, Stdlib, or CR-15 change.

**Test Level:** Level 1 roadmap and predecessor-closure compatibility.

**Exit Gate**

The active roadmap begins with Phase 22, every Phase 21 status and closure fact
remains mechanically valid in its immutable record, the exact Phase 22 patch
order and exclusions are reviewable, and all exact-head pull-request workflows
for the roadmap PR succeed with no unresolved review conversation.

## Patch 22.1 — Opening Default-Route and Consumer Inventory

Build a registry-owned opening inventory from the live compiler and repository.
Classify the CLI parser and help text; bare, explicit C, and explicit Cranelift
routes; `-o` handling; Phase 9G output ownership; worker/runtime discovery;
package/install contents; bootstrap stages; CI workflows; documentation; and
every executable repository invocation that omits `--backend`. Each invocation
records its owner, whether it expects C source, a native executable, diagnostics
only, or intentionally exercises the user default, the patch that may migrate
it, and a falsifier. Record the exact one-run stability qualification
used by Patch 22.8. Add a generated review and focused Level 1 guard. Change no
route or observable behavior.

**Exit Gate:** every implicit backend consumer is classified with zero unknown
owner or expected artifact, the current default/explicit behavior is reproduced
from the lane's own evidence, and all Phase 22 transitions have one registry
owner and falsifier.

## Patch 22.2 — Explicit C Route and No-op Consumer Migration

While MIR-to-C is still the default, add `--backend c` as an exact alias of the
retained `--backend mir-to-c` path. Migrate every Cranelift-owned bootstrap,
generated-C, oracle, and differential consumer that requires C output to an
explicit C selection. Preserve invocations whose purpose is to observe the
user default and mark them as such. Relay rather than edit any Stdlib-owned
consumer; no later flip patch may begin until every required owning correction
is merged. Add a guard that rejects a new unclassified implicit dependency.

**Exit Gate:** bare invocation still emits the pre-patch C bytes; both explicit
C spellings emit byte-identical bytes; bootstrap stage 2/stage 3 C identity
passes; every required repository consumer is explicit or deliberately
default-observing; and zero cross-lane consumer remains unresolved.

## Patch 22.2a — Cross-Lane Explicit-C Relay Publication Authority

Record the checked owning-lane 15-site routing correction without editing its
Stdlib surfaces or pretending that an unmerged worktree is already repository
state. The Cranelift-owned invocation authority admits exactly two transition
states: the current pre-relay inventory and the exact post-relay inventory in
which those 15 calls select explicit MIR-to-C. Any partial relay, additional
implicit dependency, path-set change, or unrelated invocation drift rejects.

**Exit Gate:** the unchanged Cranelift branch validates against the exact
pre-relay inventory, the checked owning-lane correction is authorized to
validate against the exact post-relay inventory after rebase, generated
authority distinguishes authorization from merge completion, and Patch 22.2
and the default flip remain open until the owning Stdlib PR actually merges.

## Patch 22.2b — Post-Relay Prerequisite Reconciliation

After the owning Stdlib relay merges, replace the transition authority's
two-state acceptance with the exact merged post-relay inventory. Record the
owning PR head, merged-main commit, complete pull-request workflow population,
and review-thread result. Reconcile the generated Patch 22.2–22.5 authorities
and roadmap status without changing compiler routing or beginning the flip.

**Exit Gate:** the live invocation scan equals the exact authorized post-relay
inventory; zero Stdlib-owned C-dependent consumer remains implicit; the owning
relay evidence is recorded; Patches 22.2–22.5 are complete; Patch 22.6 remains
unchecked; and every affected generated projection is current.

## Patch 22.3 — Native Implicit-Output Contract

Under the still-unchanged MIR-to-C default, define and implement one
deterministic source-derived final-executable intent for explicit Cranelift when
`-o` is omitted. Freeze suffix, directory, collision, invalid-source-name,
target-executable-suffix, and existing-output rules in compiler-owned authority.
An explicit `-o` remains opaque and authoritative. Both forms must enter the
same native source route; neither may create directories or publish partial
output. Do not change target/linker or Phase 9G publication semantics.

**Exit Gate:** omitted-output and equivalent explicit-output invocations produce
byte-identical executables and behavior; malformed or colliding intents reject
before driver/artifact access; every failure preserves an existing output; and
bare invocation still emits C.

## Patch 22.4 — Default-Native Package and Install Qualification

Qualify the existing three-artifact package (`gust`, `gust-native-backend`, and
`gust-runtime-package.a`) as the minimum default-native installation. Exercise
repository package output and a clean temporary-prefix install without ambient
worker overrides. Prove executable-relative worker/runtime discovery, file
modes, relocation behavior, missing/incompatible component diagnostics,
cleanup, and explicit-C independence. Update package authority and focused CI;
do not add a dependency, runtime symbol, PATH search, auto-build, download, or
fallback.

**Exit Gate:** a clean installed package compiles and runs the selected native
cohort with no environment override, explicit C remains usable if native
components are absent, and default-candidate native failures are deterministic
and preserve output.

## Patch 22.5 — Pre-flip Default-Cohort Qualification

Run the release-representative positive, negative, resource, module,
typed-query, full-compiler, and complete 326-case guard cohorts through explicit
Cranelift and the explicit MIR-to-C oracle before the default changes. Record
accepted behavior, rejected diagnostics, resource and filesystem effects,
artifacts, cleanup, compile memory/time, and package origin. Reconcile every
required default-program deferral generically or stop under the shared-zone
rules; do not shrink the cohort, add an exception, or weaken a gate.

**Exit Gate:** the registered default cohort has zero unclassified result,
zero required native deferral, exact oracle parity for observable behavior, and
all inherited budgets pass with explicit no-fallback.

## Patch 22.6 — Cranelift Default Route Flip

Change the compiler invocation default to Cranelift only after Patches 22.1–22.5
are complete. Remove experimental wording from the active native route and make
help identify Cranelift as default, explicit C as the retained oracle, the
implicit-output rule, and the package requirement. Keep backend selection after
the shared semantic pipeline. Default-native and explicit-native calls must
construct one identical invocation and reach one identical route. Explicit C
must bypass native discovery and emit the exact frozen pre-flip C bytes.

**Exit Gate:** bare and explicit Cranelift compile to byte-identical native
artifacts with identical execution and failure behavior; both explicit C
spellings reproduce the frozen pre-flip C corpus byte-for-byte; unsupported or
unavailable native builds fail clearly without C output or fallback; and the
compiler still builds itself through the explicitly selected bootstrap route.

## Patch 22.6a — Default-Route Bootstrap Seed Reconvergence

Regenerate `gust_v4.c` alone from the final Patch 22.6 compiler sources. Keep
all seed-producing compiler invocations explicitly on MIR-to-C, require
stage-2/stage-3 C byte identity, and prove the rebuilt seed exposes the new
default/native help while explicit C still drives the C bootstrap fixed point.
Publish only the generated seed and seed-specific authority.

**Exit Gate:** `make bootstrap` converges byte-for-byte, the committed seed is
exactly the converged generated C, `make gust` succeeds from that seed, and no
non-seed capability change is present.

## Patch 22.7 — Post-flip CI, Documentation, and Rollback Qualification

Move user-facing examples, README/ledger statements, release checks, package
smokes, install flows, and relevant CI matrices to the Cranelift default.
Retain focused explicit-C oracle and bootstrap lanes and ensure all native
compiler/worker/runtime/normalizer inputs appear in workflow path filters.
Exercise rollback only as an explicit `--backend c` or `--backend mir-to-c`
choice; never as automatic recovery. Preserve Stdlib-owned surfaces and use a
checked cross-lane relay if one needs an owning update.

**Exit Gate:** documentation, help, package/install behavior, PR CI, push CI,
and release-shaped smokes agree that Cranelift is default; explicit C remains a
working named oracle; and dependency/path-filter falsifiers trigger every
owning qualification workflow.

## Patch 22.7a — Post-Merge Review Corrections

Correct the Cranelift-owned post-merge findings before the stability authority
is published. Extend the executable-invocation inventory to root shell scripts,
imported justfiles, and test-owned compiler invocations; project each expected
artifact into the generated review; validate the Patch 22.6 implementation
range from its immutable reviewed manifest rather than the mutable worktree;
and make aggregate default initialization recursively preserve the existing
MIR-to-C `Index` sentinel semantics in Cranelift. Record, but do not edit, the
six Stdlib-owned test invocations that require an explicit MIR-to-C route.

**Exit Gate:** the live inventory has zero unclassified rows and its generated
projection includes every expected artifact; the immutable Patch 22.6 manifest
proves that its implementation PR did not carry the bootstrap seed; direct and
nested `Index` defaults have identical MIR-to-C and Cranelift behavior; and the
exact six-site Stdlib relay is registered as required before Patch 22.8
publication. No test-owned source, accepted Gust meaning, canonical MIR,
ABI/layout/runtime symbol, default route, fallback, bootstrap seed, Stdlib API,
CR-15, or Phase 23 work is changed.

## Patch 22.7b — Exact Six-Site Relay Transition Authority

Authorize the checked owning Stdlib PR #264 without editing or merging its two
test-owned paths. The executable-invocation authority admits exactly two
repository states: the frozen post-22.7a inventory on main, or the exact
two-path/six-site route-only transition in which the registered calls select
`--backend mir-to-c`. Freeze both exact summaries, the all-or-nothing site
manifest, and one state-independent generated projection so partial relays,
added or removed sites, path or line drift, same-count substitutions, and
unrelated invocation changes reject. Keep the authorization separate from
pending owning-merge evidence; a later
Cranelift-owned follow-up records the merge and collapses the transition before
Patch 22.8 publication.

**Exit Gate:** the unchanged exact main manifest validates as the pre-relay
state; PR #264's exact full head is the sole admitted post-relay manifest; the
opening, explicit-C migration, default-route, and successor route guards accept
both complete states but no mixed or substituted state; generated projections
are identical in either authorized state; landed merge evidence remains
explicitly pending; and no Stdlib source, accepted Gust meaning, canonical MIR,
ABI/layout/runtime symbol, route/default/fallback behavior, bootstrap seed,
Patch 22.8 evidence, CR-15, or Phase 23 work changes.

## Patch 22.8 — One-Time Default-Native Stability Qualification

The owning six-site Stdlib relay PR #264 merged from exact head
`3ada756e209bfa0556895169870ae00f96d94022` as exact main
`a7adbcd186512a3b4fd99b953bb2bc30f6838c52`. Its complete exact-head
`pull_request` population is 6/6 successful with zero review threads, and the
relayed PR #251 thread `PRRT_kwDOS1ExJc6dYPJO` is resolved and non-outdated.
The Cranelift invocation authority is therefore collapsed from the temporary
two-state transition to the exact landed post-relay inventory before this
patch's stability evidence is published.

Run one authoritative `Cranelift Historical Full` qualification on the exact
merged final post-flip implementation main. The run must expose the complete
registry-derived job population and every job must complete successfully. The
qualification is valid only with zero unresolved material review findings.
Record the run ID, full SHA, event, job population, conclusion, and elapsed
budgets in generated authority. Preserve the explicit-C oracle and rollback,
package/install, bootstrap, PR-CI, exact-SHA, and no-fallback gates.

Historical Full run `33274538693` is retained as failed diagnostic evidence,
not stability evidence: on exact post-flip main it completed 16/18 jobs
successfully, while the Phase 10 shard still asserted the retired pre-flip
selection/output state and the final aggregation was consequently skipped.
The narrow successor correction must merge and a replacement run must succeed
on exact corrected main before this patch may be marked DONE.

Authoritative replacement run `33298850155`, event `workflow_dispatch`,
completed `success` on exact final post-flip implementation main
`a7adbcd186512a3b4fd99b953bb2bc30f6838c52` with the complete 18/18 job
population successful and zero unfinished/non-success jobs.

**Exit Gate:** the single exact-final-main Historical Full run is a complete
success, zero material review findings remain unresolved, and explicit-C
rollback/oracle evidence remains green.

## Patch 22.9 — Phase 22 Closure

Re-run the opening inventory, default-route identity, explicit-C byte identity,
package/install, complete-corpus, bootstrap, documentation/CI, and stability
guards from their authoritative entry points. Dispatch a final Historical Full
on exact merged implementation main if the Patch 22.8 exact-head evidence does
not name that exact final implementation main. Generate the closure record from
registry authority, replace all placeholders with checked evidence, mark every
row DONE, and write the terminal lane state only after the closure PR merges.

**Exit Gate:** every Phase 22 row is DONE; bare Gust uses Cranelift; explicit
Cranelift is identical; explicit C is retained and byte-identical to the
pre-flip default; no silent fallback exists; package/install and bootstrap gates
pass; the one-time stability qualification and latest exact-main Historical
Full are green; all exact-head pull-request workflows succeed; and no review
conversation is unresolved. Phase 23 remains inactive.

## Phase 22 Closure Record

Phase 22 closes with Cranelift as the default backend while explicit
`--backend cranelift` remains identical, explicit `--backend mir-to-c` and
`--backend c` remain the byte-identical semantic oracle and rollback route,
fallback remains forbidden, and the three-artifact package/install plus
explicit-MIR-to-C bootstrap contracts remain qualified.

Authoritative `Cranelift Historical Full` run **33303824486**, event
`schedule`, completed `success` on exact final implementation main
**a7adbcd186512a3b4fd99b953bb2bc30f6838c52** with **18/18** jobs successful
and zero unfinished/non-success jobs. The generated closure record is
`docs/PHASE22_CLOSURE.md`; the terminal lane record is written only after the
closure PR merges. Phase 23 remains inactive.

---

# Immutable Phase 21 Completion Record — Tenant-Scoped Typed Queries and Cranelift Self-Hosting Qualification

**Lane:** Cranelift. Branches follow the existing
`codex/phase<N>-<patch>-<slug>` pattern.

Workflow, Monitoring, Merge, Phase Completion, Runner, and Git Authorization
policies were defined in `AGENTS.md`. Shared semantic ownership was defined in
`docs/SHARED_SEMANTIC_ZONE.md`. This section is the immutable Phase 21 record;
the opening preflight above is the active Cranelift roadmap.

Phase 21 has two serial tracks because both require the single compiler-semantic
writer. Track A implements and attacks the operator-selected OD-8 provenance
model over the compiler-owned typed-query path. Track B then migrates the six
explicit Phase 20 residues needed for native compiler compilation and qualifies
a Cranelift-built Gust compiler through a native rebuild. Work from one track is
not folded into a patch from the other.

The phase does not implement Postgres, HTTP, authentication, request-context
establishment, caches, non-query reads, multi-step data-flow isolation, or a
general authorization platform. It does not claim that unsafe/raw SQL receives
typed-query guarantees. It does not flip the default backend, deprecate
MIR-to-C, replace the bootstrap seed policy, or edit a Stdlib API.

## Roadmap Activation

Phase 20 formally closed on 2026-08-24. `Cranelift Historical Full` run
`32772996884`, event `workflow_dispatch`, completed `success` with 18/18 jobs on
exact merged `main` `6e54e3cc6fa8fc44e5df7a67624bb183b01b2258`.
The generated closure PR #207 then completed 81/81 strict exact-head
`pull_request` workflows with zero review threads and merged as exact main
`da18ab2ba3307c24ffabdc510fd0583f9a75e22b`.

On 2026-08-24 the operator conditionally authorized Phase 21 roadmap authoring
and continuation after formal Phase 20 closure. That condition is satisfied.
The operator also settled OD-8's design direction in favour of
`docs/VISION.md` §56.2's provenance model while explicitly leaving the
thesis-invalidating soundness verdict evidence-open. This roadmap records both
facts and activates the Phase Completion Loop through Patch 21.18 after the
roadmap PR merges.

Activation is Cranelift-only. It does not authorize edits to `TASK_STDLIB.md`,
does not begin Phase 22, and does not permit OD-8 to be marked fully resolved
until the predefined adversarial suite has run against the implemented
analysis.

## Phase Boundary

In scope:

- a non-forgeable typed `Scope[Workspace]` provenance category whose trusted origin
  is compiler-owned and whose establishment by the request host is outside the
  query-analysis guarantee;
- compiler-owned typed-query structure sufficient to represent scoped roots,
  predicates, joins, nesting, and explicit cross-tenant markers without a
  database runtime;
- one compile-time obligation per scoped root, including every joined root and
  nested query;
- discharge only from matching typed Scope provenance, never from predicate
  spelling or arbitrary user-controlled values;
- explicit, capability-gated cross-tenant access visible at the call site;
- rejection at the query and a predefined adversarial verdict suite bounded to
  the compiler-owned typed-query path;
- the six Phase 20 residue categories: collections, strings, filesystem,
  allocation, resources, and threading/synchronization;
- Cranelift compilation of compiler support libraries, selected compiler
  modules, the full compiler, selected programs through the Cranelift-built
  compiler, and a native compiler rebuild;
- an explicitly registered decision on native-stage reproducibility before the
  closure criterion depends on it.

Out of scope:

- caches, non-query reads, multi-step flows, stored procedures, triggers,
  supplier surfaces, raw connections, and unsafe/raw SQL;
- proving or implementing the trusted request-context establishment path;
- full policy translation, Postgres execution, transactions, migrations, or a
  public database library;
- general lifetime algebra, arbitrary brand relationships, a second semantic
  authority, backend-specific source meaning, or silent Cranelift fallback;
- the default-backend flip and every Phase 22–25 retirement action.

## Status

- [x] Patch 21.0 — Roadmap and OD-8 Design Authority — DONE
- [x] Patch 21.1 — Opening Evidence and Dual-Track Baseline — DONE
- [x] Patch 21.2 — Inert Scoped-Query Semantic Records — DONE
- [x] Patch 21.3 — Typed-Query Surface Under the No-op — DONE
- [x] Patch 21.4 — Trusted Scope Provenance Enforcement — DONE
- [x] Patch 21.5 — Per-Root Join and Nested-Query Obligations — DONE
- [x] Patch 21.6 — Explicit Cross-Tenant Capability Boundary — DONE
- [x] Patch 21.7 — OD-8 Adversarial Soundness Verdict — DONE
- [x] Patch 21.7a — Tenant-Scope Bootstrap Seed Reconvergence — DONE
- [x] Patch 21.7b — Cross-Tenant Predicate Validation Reconciliation — DONE
- [x] Patch 21.8 — Phase 20 Residue Migration Authority — DONE
- [x] Patch 21.9 — Collections and Strings Native Source Migration — DONE
- [x] Patch 21.10 — Filesystem and Allocation Native Source Migration — DONE
- [x] Patch 21.11 — Resources and Synchronization Native Source Migration — DONE
- [x] Patch 21.12 — Compiler Support-Library Native Qualification — DONE
- [x] Patch 21.13 — Selected Compiler-Module Native Qualification — DONE
- [x] Patch 21.13a — Native-Feature Bootstrap Seed Reconvergence — DONE
- [x] Patch 21.14 — Full Compiler Canonical-MIR and Native Object Qualification — DONE
- [x] Patch 21.15 — Cranelift-Built Compiler Program Compilation — DONE
- [x] Patch 21.16 — Native Rebuild Reproducibility Authority — DONE
- [x] Patch 21.16a — Native Rebuild Workflow Dependency Correction — DONE
- [x] Patch 21.16b — Native Compiler Large-Function Allocation Scaling — DONE
- [x] Patch 21.17a — Scheduler Main-Result Completion — DONE
- [x] Patch 21.17 — Complete Guard Suite and Resource Budgets — DONE
- [x] Patch 21.17b — Historical Beachhead Prose-Scope Correction — DONE
- [x] Patch 21.17c — Historical Driver-Handshake Fixture Reconciliation — DONE
- [x] Patch 21.17d — Historical Phase 9F ABI Fixture Reconciliation — DONE
- [x] Patch 21.17e — Historical Driver-Handshake Inventory Reconciliation — DONE
- [x] Patch 21.17f — Historical Driver-Handshake Manifest Freeze — DONE
- [x] Patch 21.18 — Phase 21 Closure — DONE

Status rows are machine-parsed. Keep each row as
`- [ ] Patch 21.N — <Title>` or `- [x] Patch 21.N — <Title> — DONE`; an
inserted amendment may append one lowercase letter to `N`.

## Immutable Contracts

- MIR-to-C remains the semantic oracle for accepted source until a later
  roadmap deliberately changes that policy.
- Explicit Cranelift never falls back to C. Unsupported typed-query or compiler
  source fails before driver discovery and artifact publication.
- Tenant-scope authority is generic compiler semantics, never a backend rule or
  a special case for one entity or library.
- A syntactically present tenant predicate is not evidence. Only matching,
  non-forgeable typed Scope provenance discharges an obligation.
- Each scoped join root and nested query carries its own obligation. Outer or
  sibling discharge never clears it.
- Cross-tenant access is explicit, capability-gated, non-ambient, and visible at
  the call site. Raw SQL is a separate unsafe/privileged boundary outside the
  guarantee.
- The external claim is limited to compiler-owned typed queries. No closure
  wording silently includes caches, non-query reads, multi-step flows, unsafe
  SQL, or establishment of trusted request context.
- Compiler syntax follows the bootstrap-safe sequence: inert support, complete
  migration under the no-op, then enforcement. Generated `gust_v4.c` changes
  only in isolated seed patches.
- Phase 21 self-hosting does not change the default backend and does not replace
  the Phase 25 native bootstrap-seed decision.

## Patch 21.0 — Roadmap and OD-8 Design Authority

**Purpose**

Activate the phase from the exact Phase 20 closure and turn the operator's OD-8
choice into one checked, non-overclaiming source of authority.

**Steps**

- Update `docs/VISION.md` §0.15 and §56.2 to say `DESIGN SET / EVIDENCE OPEN`,
  preserving the adversarial soundness verdict as thesis-invalidating.
- Add the tenant-scope obligation/provenance row to
  `docs/SHARED_SEMANTIC_ZONE.md` with Cranelift as the only semantic writer.
- Register this roadmap and its exact predecessor closure in the Cranelift
  registry; generate a review artifact and add a focused Level 1 guard.
- Register the native-stage reproducibility criterion as an open decision-tree
  node rather than choosing it implicitly during implementation.
- Make no parser, typechecker, MIR, backend, ABI/layout, runtime-symbol, target,
  linker, seed, or Stdlib capability change.

**Test Level:** Level 1 documentation/authority contract.

**Exit Gate**

The operator decision, bounded claim, evidence-open verdict, phase ordering,
predecessor closure, and successor Patch 21.1 are represented identically in
VISION, the shared-zone map, TASK, the registry, and the generated review.

## Patch 21.1 — Opening Evidence and Dual-Track Baseline

Inventory the absent typed-query/effect surface, preserve executable positive
and negative query-shaped witnesses, re-derive the six Phase 20 residues, and
measure the current full-compiler explicit-Cranelift failure stage. Record every
case with an owner, stable reason, expected transition, and falsifier. Do not
add syntax or change accepted-program meaning.

**Exit Gate:** the opening registry accounts for every Track A construct, every
inherited residue, and the complete compiler self-hosting baseline with zero
unclassified failure.

## Patch 21.2 — Inert Scoped-Query Semantic Records

Add compiler-owned records for scoped-entity declarations, canonical query
roots, per-root obligations, predicate provenance, nested query identity,
cross-tenant markers, and trusted Scope origin. Keep them unreachable from
normal source typechecking and lowering. Add no MIR operation, runtime symbol,
ABI/layout rule, or rejection.

**Exit Gate:** the inert records round-trip through focused self-hosted compiler
tests, are not forgeable through ordinary type construction, and change no
existing program's diagnostics or generated C.

## Patch 21.3 — Typed-Query Surface Under the No-op

Add the minimum compiler-owned declaration/query syntax needed by the attack
suite and typed derivation (`scoped entity`, root, predicate, join, nesting,
terminal query, and explicit cross-tenant marker) as a semantic no-op. Migrate
all newly introduced fixtures and any compiler-owned consumers while the new
surface is inert. Do not enable enforcement in this patch.

**Exit Gate:** the checked-in seed builds the complete new syntax and the entire
classified source inventory is migrated under the no-op.

## Patch 21.4 — Trusted Scope Provenance Enforcement

Enable one generic rule: a scoped root creates an obligation discharged only by
a matching non-forgeable `Scope[Workspace]` provenance derived from the trusted
context boundary. Arbitrary values, casts, copied predicate spelling, and
user-controlled request fields cannot establish the provenance. Reject at the
query with the registered diagnostic; keep the trusted-context establishment
mechanism outside the guarantee.

**Exit Gate:** positive trusted provenance and negative absent, forged,
wrong-scope, arbitrary-value, and syntax-only programs agree through the
semantic oracle and supported native cohort.

## Patch 21.5 — Per-Root Join and Nested-Query Obligations

Extend the generic analysis so every scoped join root and every subquery,
aggregate, or `EXISTS` node owns an independent obligation. Define conservative
query-as-value joins: preserve the complete obligation set or reject when it
cannot be represented. Do not let outer, sibling, or earlier discharge clear a
different root.

**Exit Gate:** scoped/unscoped joins, multiple scoped joins, nesting, query
values, branches, returns, aggregates, and aliasing have deterministic joined
obligation sets and exact failure locations.

## Patch 21.6 — Explicit Cross-Tenant Capability Boundary

Add the smallest generic non-ambient capability check needed by the named
cross-tenant marker. The capability is non-forgeable and non-transitive, must be
visible at the query call site, and cannot be hidden behind an ordinary helper.
Keep privileged raw SQL an explicit separate unsafe boundary outside typed-query
guarantees; do not implement a database runtime or broader effect system here.

**Exit Gate:** deliberate cross-tenant typed queries require the registered
capability at the call site, laundering/re-export is rejected, ordinary scoped
queries remain unchanged, and raw SQL cannot be presented as covered.

## Patch 21.7 — OD-8 Adversarial Soundness Verdict

Freeze and execute the §56.1 attack list against the implemented typed-query
path: raw-boundary transitivity, joins, nesting, queries as values, dynamic
shape, forged/untrusted tenant inputs, and the legitimate cross-tenant path.
Record caches, non-query reads, multi-step flows, and trusted-context
establishment as explicit out-of-scope probes rather than false passes.

If any in-scope program compiles and leaks, record OD-8 negative and stop or
rescope the thesis. Only if the complete predefined in-scope suite produces no
counterexample may §0.15 move from `EVIDENCE OPEN` to a bounded resolved verdict.

**Exit Gate:** the registry-generated attack report names every attempted class,
witness, outcome, and claim boundary; OD-8 status follows evidence rather than
roadmap completion.

## Patch 21.7a — Tenant-Scope Bootstrap Seed Reconvergence

Regenerate `gust_v4.c` alone after Track A compiler changes, require byte-
identical stage 2/stage 3 output, and publish seed-specific authority in its own
commit and PR. Add no semantics.

## Patch 21.7b — Cross-Tenant Predicate Validation Reconciliation

Correct the post-merge Patch 21.6 discrepancy without changing the selected
capability contract: a valid direct cross-tenant marker bypasses only unresolved
scope-obligation reporting. It does not bypass predicate traversal or the
compiler-owned intrinsic boundary diagnostics applicable to predicates. Add
the exact negative compile-fail witness to both the cross-tenant and bounded
OD-8 evidence populations; preserve every existing positive capability and
trusted-scope outcome.

**Exit Gate:** the invalid compiler-owned capability use inside a marked query
predicate rejects identically before native driver discovery through both
backend commands, the existing legitimate cross-tenant path remains accepted,
and the generated OD-8 attempt count and bounded verdict match the corrected
evidence.

## Patch 21.8 — Phase 20 Residue Migration Authority

Re-derive the Phase 20 final residues from current compiler output, split each
broad category into the smallest generic source-to-canonical-MIR capabilities,
and order them by the compiler self-hosting dependency graph. Preserve explicit
early rejection for every not-yet-migrated row.

**Exit Gate:** all six inherited fixtures and the full compiler reproduce their
registered pre-driver rejection with no artifact; every residue maps only to
generic capability slices owned by Patches 21.9–21.11; and the complete
transitive compiler module graph is partitioned into a dependency-respecting
qualification order with no unclassified module or import edge.

## Patch 21.9 — Collections and Strings Native Source Migration

Migrate the generic structured-control-flow and condition shapes needed by
compiler-owned collection and string sources. Use canonical MIR, not source
recognizers, and prove representative source differentials with no fallback.

The implemented boundary is the bounded typed-AST cohort recorded by
`phase21_collection_string_native_source_v2`. Renamed semantic variants prove
that neither source paths nor fixture names select lowering; unrepresented
collection or string shapes continue to reject before driver discovery. The
worker consumes only canonical CFG, imported void calls, string data symbols,
and the compiler-selected retained runtime archive.

**Exit Gate:** all five registered source cases agree with MIR-to-C on stdout,
stderr, and exit status; captured requests and bundles contain canonical MIR
with no generated C or fallback; the retained archive adds no runtime symbol;
both extra-effect probes reject before driver discovery rather than silently
dropping behavior; and filesystem/allocation/resources/synchronization remain
in their later roadmap patches.

Post-merge correction (2026-08-25): constant evaluators now carry explicit
represented state, so unhandled integer or string log expressions reject before
driver discovery instead of manufacturing `0` or an empty string. Canonical
string call arguments use byte-preserving hexadecimal transport, so embedded
line breaks cannot corrupt the line-oriented MIR bundle. The two rejection
witnesses retain their measured MIR-to-C behavior, the embedded-newline witness
agrees with MIR-to-C through explicit Cranelift, and the correction adds no
fallback, ABI/layout authority, runtime symbol, bootstrap seed, or Stdlib
change.

## Patch 21.10 — Filesystem and Allocation Native Source Migration

Add generic canonical-MIR representation and lowering for the exact filesystem
and arena allocation/write operations required by compiler support code. Reuse
Phase 14 layout and Phase 17 runtime authorities; add or change a runtime symbol
only in an explicitly separated authority patch if evidence requires it.

The implemented boundary is the bounded typed-AST cohort recorded by
`phase21_filesystem_allocation_native_source_v1`. Filesystem lowering represents
paired arena lifetime, literal-path WriteFile/ReadFile calls, integer/string
results, and observable effect order. Allocation lowering represents the
one-int-field aggregate cohort through arena allocation, write, indexed read,
and field projection. Renamed sources prove that paths, fixture names, local
names, and declared type names do not select lowering. Computed write contents
and computed stored values remain conservatively rejected before driver
discovery.

Post-merge correction (2026-08-26): canonical arena load/store validation now
requires the index local to come from an earlier same-block imported
`os_ArenaAlloc` call for the same arena with a literal size. Integer-local
reassignment clears that provenance, and the complete four-byte `i32` access
must have a non-negative offset and fit the recorded allocation. Malformed MIR
therefore rejects before native lowering; the admitted source cohort,
MIR-to-C oracle, lowering, ABI/layout, and runtime symbols are unchanged.

Second post-merge correction (2026-08-26): allocation provenance is now
invalidated when its arena is freed or reinitialized, and literal allocation
sizes must fit the native `size_t` while leaving room for the runtime's
seven-byte alignment addition. Malformed canonical MIR covers both lifetime
reset forms and alignment overflow; lowering and the admitted source cohort are
unchanged.

**Exit Gate:** all four registered source cases agree with MIR-to-C on stdout,
stderr, exit status, and filesystem effects where applicable; the two
unrepresented expression cases retain measured MIR-to-C behavior while
rejecting before driver discovery with no artifact; captured requests contain
canonical MIR and registry-validated runtime-boundary metadata with no generated
C or fallback; the retained runtime archive adds only the existing `file_io.c`
component and no new or changed symbol; Phase 21.9 hexadecimal string transport
is preserved; and resources/synchronization remain Patch 21.11.

## Patch 21.11 — Resources and Synchronization Native Source Migration

Carry Phase 15/20 resource state, automatic cleanup, approved runtime imports,
and selected Mutex/Channel ABI through generic source-to-MIR and Cranelift
lowering. Preserve protected-access liveness and unsafe raw boundaries; no
Stdlib-specific backend path.

**Exit Gate:** the registered resource cleanup cases and deterministic,
arena-live Mutex/scheduler case agree with MIR-to-C on stdout, stderr, and exit
status; the computed resource-token case still rejects before driver discovery;
generic raw-pointer parameter/result, validated i32 load/store, pointer-offset,
function-address, and arena-allocation-address MIR operations reject malformed
types, offsets, locals, and ranges; every approved runtime call carries
registry-validated native-boundary metadata; the retained archive adds only the
existing scratch/fiber components and changes no runtime symbol; generated C,
fallback, Stdlib edits, ABI/layout changes, CR-15, and Patch 21.12 remain out of
scope.

## Patch 21.12 — Compiler Support-Library Native Qualification

Compile the compiler's dependency modules through explicit Cranelift in
topological slices. Each slice records canonical MIR, diagnostics, output or
library artifact properties, resource state, and memory/time budgets while
MIR-to-C remains the oracle.

The implemented qualification starts from the 38-module/116-edge Patch 21.8
graph authority, reconciles the three successor lowering modules and nine edges
added by Patches 21.9–21.11, and derives 34 support modules with 87 dependency
edges from the resulting live 41-module/125-edge graph. It excludes only the six
representative compiler modules named by Patch 21.13 and the full compiler entry
reserved for Patch 21.14, then probes the four remaining nonempty graph slices
in their existing topological order. Every support root is accepted by
MIR-to-C, links, and exits zero with empty output. Explicit Cranelift currently
rejects every slice before driver discovery at the generic unsupported
top-level-statement boundary, so canonical MIR and native artifacts are
recorded as absent rather than manufactured. Fixed elapsed/RSS budgets and the
no-driver/no-artifact resource state are registry-owned. The remaining generic
capability is assigned to Patch 21.13 with an explicit ban on module-specific
exceptions.

**Exit Gate:** all 34 support modules and all 87 of their live graph dependency
edges are present in exactly one registry-derived topological qualification
slice; every slice's MIR-to-C C output links and runs with the recorded empty
stdout/stderr and zero exit; every explicit-Cranelift attempt reproduces the
registered source/type classification before driver discovery with canonical
MIR absent and no artifact; elapsed time and peak RSS remain within fixed
registry budgets; the selected lexer/parser/resolver/typechecker/MIR/codegen
modules, full compiler entry, generic capability implementation, source
semantics, MIR operations, ABI/layout/runtime symbols, bootstrap seed, default
backend, fallback, Stdlib, CR-15, and Patch 21.13 remain unchanged.

## Patch 21.13 — Selected Compiler-Module Native Qualification

Compile representative lexer, parser, resolver, typechecker, MIR, and codegen
modules through the native path, expanding only after the prior slice is fully
classified. Large-function or registry failures receive generic capability rows
rather than per-module exceptions.

The implemented qualification admits ordinary imported struct and enum
declarations as compile-time metadata that owns no executable MIR. A generic
positive witness containing both declaration kinds still sends every function
through the existing signature and body lowerers and exits 42 with empty output
through MIR-to-C and explicit Cranelift. This is module-generic admission, not a
selected-module exception.

The lexer, parser, resolver, typechecker, MIR, and codegen representatives were
then expanded in that order, only after the preceding slice was fully
classified. All six MIR-to-C oracle programs emit nonempty C, link, and exit
zero with empty output. Each explicit-Cranelift attempt rejects before driver
discovery at the same generic unsupported non-scalar-signature boundary, with
canonical MIR and artifacts absent. The registry owns the reachable graph
counts, diagnostics, artifact/resource state, and fixed elapsed/RSS budgets.
One generic capability row assigns non-scalar compiler-module signature
lowering to Patch 21.14; no module-specific exception is admitted. Large-
function and registry behavior is recorded as unobservable until that earlier
generic boundary advances.

**Exit Gate:** all six selected modules appear exactly once in the registered
lexer/parser/resolver/typechecker/MIR/codegen order with live reachable graph
counts; every slice's MIR-to-C C output links and runs with empty stdout/stderr
and zero exit; every explicit-Cranelift attempt reproduces the registered
generic pre-driver diagnostic with canonical MIR and native artifact absent;
the generic declaration witness exits 42 with empty output through both
backends; elapsed time and peak RSS remain within fixed registry budgets; all
remaining capability failures have one generic destination and no per-module
exception; source semantics, canonical MIR operations, ABI/layout/runtime
symbols, bootstrap seed, default backend, fallback, Stdlib, CR-15, and Patch
21.13a remain unchanged.

## Patch 21.13a — Native-Feature Bootstrap Seed Reconvergence

Regenerate `gust_v4.c` alone after the compiler-source/native-feature migration,
require stage 2/stage 3 byte identity, and publish only the generated seed plus
seed-specific authority.

## Patch 21.14 — Full Compiler Canonical-MIR and Native Object Qualification

Produce canonical MIR and a linked native compiler object for the full compiler
with no generated C in the qualified native route. Verify target/layout/ABI,
runtime package, linker, object publication, failure cleanup, and deterministic
diagnostics under the existing authorities.

The implemented generic source projection serializes the typed full-program
graph as strict `gust.compiler_executable_mir.v1`: module identities, retained-C
layout and enum authority, function signatures, post-order executable nodes,
target/object policy, and one entry identity. The worker independently parses
and validates that payload before using the existing Phase 14–16 layout,
aggregate-transport, function-ABI, native-boundary, object, runtime-package,
and linker authorities. The compact outer program bundle publishes only
`main`; it does not duplicate the payload-owned symbol index. No selected
compiler module receives an exception and explicit Cranelift never falls back.

The qualified full compiler reaches the driver, emits and links an ELF64 PIE,
exports `main`, and produces byte-identical help output to the MIR-to-C-built
compiler. The runtime package contains the eight existing registered object
members, with no symbol or ABI change. A minimal strict full-program fixture
proves relocatable-object publication; its generic unknown-operation mutation
proves byte-identical diagnostics across repeated attempts and leaves no failed
object. The production route leaves no generated C, request, bundle, or
intermediate object. Registry-owned elapsed/RSS and artifact-size budgets bound
the authoritative environment.

**Exit Gate:** the full compiler is represented by one strict generic canonical
payload and reaches the explicit native driver without fallback or generated C;
the worker revalidates target, object, layout, enum, function, operation, and
entry authority before emission; the linked compiler satisfies the registered
ELF, symbol, runtime-package, linker-log, cleanup, deterministic-diagnostic,
artifact-size, elapsed-time, and peak-memory contracts; the minimal positive and
malformed canonical-MIR witnesses pass; MIR-to-C remains the oracle; accepted
Gust meaning, module-specific behavior, ABI/layout/runtime symbols, bootstrap
seed, default backend, Stdlib, CR-15, Patch 21.15, and OD-15 remain unchanged.

## Patch 21.15 — Cranelift-Built Compiler Program Compilation

Use the Cranelift-built compiler to compile the selected positive, negative,
resource, module, and typed-query programs. Compare accepted behaviour,
diagnostics, side effects, and artifacts to the semantic oracle without hiding
unsupported paths behind C.

## Patch 21.16 — Native Rebuild Reproducibility Authority

Resolve the registered native-stage reproducibility decision with measured
evidence, then use the Cranelift-built compiler to rebuild the compiler again.
Require the selected criterion—binary identity or a precisely bounded semantic
reproducibility contract—across independently produced native stages.

**Resolved criterion (operator, 2026-08-27):** under an identical pinned
authoritative environment—exact source commit, Cranelift and toolchain
versions, target, flags, runtime package, linker, and normalized environment—
independently produced native compiler stages must be byte-identical. A
separately registered bounded semantic-reproducibility contract may govern
cross-machine or cross-toolchain comparisons, but it cannot weaken this Phase
21 closure gate.

The registered N1a/N1b/N2/N3 evidence uses two independent publications by the
MIR-to-C-built compiler followed by successive rebuilds through N1a and N2.
Every stage uses explicit Cranelift with no fallback, emits the same ELF
artifact bytes, produces the same `--help` behaviour, and leaves only the
registered empty Phase 9G linker logs. The dedicated guard checks the live exact
workflow-head commit rather than pinning legitimate future source revisions to
one historical compiler hash.

**Exit Gate:** OD-15 is resolved in `docs/VISION.md` and registry authority;
the exact-head authoritative workflow pins and validates every environment
input named above; N1a, N1b, N2, and N3 are byte-identical; help output and
linker side effects agree; no generated C, request, bundle, object, or fallback
appears; measured elapsed, memory, and artifact bounds hold; Patch 21.17,
Stdlib, CR-15, accepted Gust meaning, MIR, ABI/layout/runtime symbols, default
backend, and bootstrap seed remain unchanged.

## Patch 21.16a — Native Rebuild Workflow Dependency Correction

Correct the Patch 21.16 workflow dependency surface after post-merge review
proved that `tools/normalize_generated_arena_offsets.py` participates in
compiler production but did not trigger native-rebuild requalification. PR
#234 added the tool to both workflow path filters and to the authoritative
clean-source set, then merged from exact head
`6191dfe77dd3c827be2da5908af40534f3cd9acd` as
`df8a7861b3f78e604e4f64519e785245ea801125` after 5/5 exact-head
`pull_request` workflows succeeded and all review threads were resolved.

## Patch 21.16b — Native Compiler Large-Function Allocation Scaling

Correct the generic Cranelift-built compiler allocation growth exposed by the
unchanged Phase 20 generated large-function authority. The Patch 21.17 entry
point completed and classified all 326 derived corpus cases, then the inherited
large-function replay passed at 64, 128, and 256 operations with peak RSS of
224,768, 638,208, and 2,289,536 KiB before aborting by signal 6 at 512, 768,
and 1,024 operations near 4.2 GiB without an artifact or diagnostic. Partial
Patch 21.17 artifacts are not evidence.

The correction must be generic compiler implementation work using existing
Gust, MIR, ABI/layout, and runtime-symbol authority. It must not reduce the
1,024-operation cohort, raise the fixed arena capacity as an evidence bypass,
weaken a budget, add a compiler-module exception, or route through MIR-to-C.
If the smallest faithful correction requires a MIR meaning change, ABI/layout
change, runtime-symbol change, or bootstrap seed update, stop and register that
separate boundary before implementation.

**Exit Gate:** the Cranelift-built compiler completes the unchanged inherited
1,024-operation generated large-function cohort through explicit Cranelift
with MIR-to-C parity, no fallback, bounded allocation growth, and no failed
artifact residue; focused scale evidence covers the observed pass/fail
threshold; Patch 21.17 remains the owner of the complete 326-case and inherited
budget replay; accepted Gust meaning, MIR operations, ABI/layout/runtime
symbols, bootstrap seed, default backend, Stdlib, CR-15, and Patch 21.18 remain
unchanged.

Post-merge correction (2026-08-28): the first evidence recipe exported the
Cranelift-built compiler path, but the inherited scale harness ignored it and
silently invoked `./gust`; it therefore exercised the C-built compiler. Once
the harness was corrected to consume `GUST_COMPILER`, the unchanged 1,024
operation case reproduced the signal-6 abort near 4.2 GiB in the local-state
canonical emitter rather than the scalar emitter changed by the first patch.

The bounded local-state canonical-transport builder replaces retained prefix
chains with one capacity-checked linear buffer while preserving the exact
canonical MIR bytes and the structured-CFG helper contract. The corrected
compiler-origin guard now passes all 34 unchanged Phase 20 cases through the
actual Cranelift-built compiler, including the 1,024-operation large function,
whose Cranelift replay peaks at 95,488 KiB. MIR-to-C parity, no-fallback,
failure cleanup, and the existing time/memory budgets remain enforced by the
inherited profile. The pre-correction and corrected Cranelift-built compilers
also emit byte-identical canonical bundles and native artifacts for the largest
previously passing 256-operation threshold witness.

## Patch 21.17a — Scheduler Main-Result Completion

Operator-authorized on 2026-08-28 after the unchanged Patch 21.17 inherited
long-lived/concurrent replay exposed nondeterministic host-main completion. The
MIR-to-C program sometimes returned `0` while the same canonical MIR through
Cranelift reliably returned the user main result `47`, with identical empty
streams. Correct the generic scheduler completion contract so every successfully
queued fiber remains scheduler-owned until its terminal context switch has
returned and its writes are published to host main.

Exit gate: the existing Phase 20 full long-lived/concurrent replay passes without
normalization or fallback, and repeated MIR-to-C and Cranelift executions both
return `47` with byte-identical stdout/stderr. The correction adds no runtime
symbol, ABI/layout change, fixture exception, gate weakening, or other runtime
semantic expansion; Stdlib, CR-15, and Patch 21.18 remain untouched. After this
atomic correction merges, rebase and resume Patch 21.17 from exact main.

## Patch 21.17 — Complete Guard Suite and Resource Budgets

Run the Cranelift-built compiler through the complete required guard suite and
registered long-lived, concurrency, large-function, compile-time, peak-memory,
diagnostic, and failure-cleanup budgets. Classify every skip or deferral; zero
unexplained failure is permitted.

The self-hosted runner is the source authority for 326 cases: 216 positive,
104 compile-fail, and six expected runtime-failure cases. The registered
qualification derives that inventory rather than copying a partial list. A
Cranelift-built full compiler drives both the explicit Cranelift target leg and
the explicit MIR-to-C oracle leg. Of those cases, 192 are required native
passes and 134 are owned, reason-coded deferrals with falsifiers: 121 compiler-
reported native capability or validation limitations, ten fixtures whose
positive or diagnostic premise is stale against the oracle, and three admitted
native executables whose observables still diverge. No case is omitted or left
in an unnamed bucket.

The same compiler origin replays the full registered generated-MIR/large-
function and large-module budgets, long-lived/concurrent resource profile, and
cross-feature profile. Corpus cases run across two serial, detached-worktree
shards so root volatiles and relative fixture paths remain isolated while the
two-CPU authoritative runner is used fully; no shared fixed-`/tmp` guard family
runs inside the sharded corpus. Every child is bounded by the
remaining suite deadline; compile time is monotonic and peak RSS is the sampled
aggregate live process-tree total. Failed native cases leave no output,
request, bundle, object, or generated C, and the target route never falls back.
These classifications do not resolve the deferrals or authorize Phase 22
implementation.

Patch 21.16b resolved the inherited generated-scale blocker generically. Its
unchanged full 34-case profile now passes through the Cranelift-built compiler,
including the required 1,024-operation large function at an observed peak of
95,488 KiB instead of aborting near 4.2 GiB. Its post-merge correction makes
the inherited harness consume the requested compiler origin and applies linear
canonical transport to the actual local-state emitter. Patch 21.17 retains the
complete cohort and fixed budgets and replays that corrected authority from the
same compiler origin; it does not weaken the cohort or alter runtime, layout,
MIR, or accepted Gust meaning.

**Exit Gate:** all 326 runner cases are derived and classified exactly once;
all 192 required native cases match the MIR-to-C oracle and runner
expectations; all 134 deferrals retain an owner, reason, destination, and
falsifier; compile-fail diagnostics and failed-artifact cleanup pass; the full
generated scale, long-lived/concurrent, and cross-feature budget replays pass
through the Cranelift-built compiler origin; elapsed and peak-memory bounds
hold; accepted Gust meaning, MIR operations, ABI/layout/runtime symbols,
bootstrap seed, default backend/fallback, Stdlib, CR-15, and Patch 21.18 remain
unchanged.

## Patch 21.17b — Historical Beachhead Prose-Scope Correction

**Purpose**

Correct the Phase 9 dependency-beachhead guard after authoritative Historical
Full run 33171071194 proved that it classified generated compiler review
Markdown as production code. Preserve the production scan over compiler source,
runtime source, tests, root manifests, and the Makefile; exclude only
`compiler/CRANELIFT_*.md` review authority from that production-reference
population. Make no compiler, MIR, backend, ABI/layout, runtime-symbol,
bootstrap-seed, default-backend, Stdlib, or CR-15 change.

**Exit Gate:** the focused dependency-beachhead guard passes with generated
Phase 21 review authority present, its production-source population remains
unchanged, and replacement authoritative Historical Full evidence owns final
qualification.

## Patch 21.17c — Historical Driver-Handshake Fixture Reconciliation

**Purpose**

Reconcile the Phase 10 positive driver-handshake smoke with the existing Patch
21.14 full-program canonical-MIR format authority. The worker and validator
already require exactly v1, v2, and `gust.compiler_executable_mir.v1`; update
the stale positive and protocol-mismatch fixture handshakes to advertise that
same three-format contract. Change no parser, validator, worker, compiler, MIR,
backend, ABI/layout, runtime symbol, bootstrap seed, default backend, Stdlib, or
CR-15 behavior.

**Exit Gate:** the focused Phase 10 driver-handshake contract passes; the
positive fixture classifies compatible, the negative fixture remains a protocol
mismatch rather than failing an unrelated precondition, and replacement
authoritative Historical Full evidence owns final qualification.

## Patch 21.17d — Historical Phase 9F ABI Fixture Reconciliation

**Purpose**

Reconcile the Phase 9F unsupported-import-ABI negative witness with the live
canonical-MIR import allowlist and the existing Patch 21.9 call-result type
validation. `void` is an admitted imported return ABI, so mutate the fixture to
the genuinely unsupported `usize` return ABI and keep the diagnostic assertion
on `uses an unsupported scalar ABI`. Change no validator, compiler, MIR,
backend, ABI/layout policy, runtime symbol, bootstrap seed, default backend,
Stdlib, or CR-15 behavior.

**Exit Gate:** the focused Phase 9F schema validator rejects the renamed
unsupported-return fixture at import ABI validation, every other Phase 9F
positive and negative case remains unchanged, and replacement authoritative
Historical Full evidence owns final qualification.

## Patch 21.17e — Historical Driver-Handshake Inventory Reconciliation

**Purpose**

Reconcile the Phase 10 worker-handshake inventory guard with the existing Patch
21.14 full-program canonical-MIR authority. The worker already advertises the
authoritative `3/28/16/19/3` canonical-format, operation, type/ABI,
runtime-import, and target-requirement inventory; update the stale pre-21.14
`2/15/6/5/3` guard expectation and explicitly require
`gust.compiler_executable_mir.v1`. Change no worker, validator, compiler, MIR,
backend, ABI/layout, runtime symbol, bootstrap seed, default backend, Stdlib, or
CR-15 behavior.

**Exit Gate:** the focused Phase 10 driver-handshake contract accepts the exact
Patch 21.14 worker inventory, still rejects any count drift, and replacement
authoritative Historical Full evidence owns final qualification.

## Patch 21.17f — Historical Driver-Handshake Manifest Freeze

**Purpose**

Correct the Phase 10 handshake guard after post-merge review of Patch 21.17e
proved that category counts alone do not freeze the existing Patch 21.14 worker
manifest. Compare the complete ordered canonical-format, operation, type/ABI,
runtime-import, and target-requirement lines against an explicit expected
manifest, and prove that one-for-one same-count substitutions in every category
reject. Change no worker, validator, compiler, MIR, backend, ABI/layout, runtime
symbol, bootstrap seed, default backend, Stdlib, CR-15, or accepted Gust
meaning.

**Exit Gate:** the focused Phase 10 driver-handshake contract accepts the exact
Patch 21.14 worker manifest and rejects same-count substitutions in every
advertised category; replacement authoritative Historical Full evidence owns
final qualification.

## Patch 21.18 — Phase 21 Closure

Require every Phase 21 row DONE, the OD-8 verdict recorded exactly as evidence
supports, the native self-rebuild criterion satisfied, the full required guard
suite green under the Cranelift-built compiler, all review threads resolved, and
an authoritative Historical Full success on the exact merged Phase 21 head.
Generate the closure record from registry authority and write a terminal lane
state. Do not begin Phase 22 from a running or merely available Level 3 suite.

## Recommended Implementation Order

21.0 decision/roadmap authority
→ 21.1 opening evidence
→ 21.2 inert records
→ 21.3 no-op surface/migration
→ 21.4 provenance enforcement
→ 21.5 join/nesting obligations
→ 21.6 cross-tenant boundary
→ 21.7 adversarial verdict
→ 21.7a seed
→ 21.8 residue authority
→ 21.9–21.11 generic native migrations
→ 21.12 support libraries
→ 21.13 selected compiler modules
→ 21.13a seed
→ 21.14 full compiler native artifact
→ 21.15 native compiler compiles programs
→ 21.16 native rebuild criterion
→ 21.16a native-rebuild workflow dependency correction
→ 21.16b native compiler large-function allocation scaling
→ 21.17a scheduler main-result completion
→ 21.17 guard suite/budgets
→ 21.17b historical beachhead prose-scope correction
→ 21.17c historical driver-handshake fixture reconciliation
→ 21.17d historical Phase 9F ABI fixture reconciliation
→ 21.17e historical driver-handshake inventory reconciliation
→ 21.17f historical driver-handshake manifest freeze
→ 21.18 closure.

## Phase 21 Success Criteria

Phase 21 succeeds when:

- only trusted non-forgeable matching Scope provenance discharges a scoped-root
  obligation in the compiler-owned typed-query path;
- every scoped join root and nested query carries its own obligation, and
  cross-tenant access is explicit, capability-gated, and visible at the call
  site;
- rejection is a compiler error at the query, while raw SQL and all named
  non-query boundaries remain explicitly outside the claim;
- OD-8's status is supported by the complete predefined adversarial evidence,
  not by design prose or ordinary positive tests;
- all six inherited Phase 20 residue categories have final registry-owned
  dispositions with zero fallback and zero unexplained divergence;
- a Cranelift-built Gust compiler compiles the selected program corpus and
  rebuilds the compiler under the explicitly resolved reproducibility criterion;
- the complete required guard suite and resource budgets pass through the
  qualified native compiler route without generated C for those stages;
- bootstrap-sensitive compiler changes are represented by isolated converged
  seed commits; and
- an authoritative Historical Full run succeeds on exact merged Phase 21 main
  and is cited by generated closure and terminal records.

Phase 21 does not flip the default backend, retire MIR-to-C, establish a native
bootstrap seed, implement a database/runtime platform, or claim isolation
outside compiler-owned typed queries.

## Phase 21 Closure Record

Phase 21 closed on 2026-08-29 after `Cranelift Historical Full` run
**33216889936** completed successfully for event `workflow_dispatch` on exact
merged Phase 21 `main` **acd9e13841215d3c1aaf6e56589d6bacd45c6d4e**.
The complete job population was **18/18** jobs completed successfully, with zero
unfinished and zero non-success jobs. The authoritative Phase 21 complete-suite
run **33166864658** also completed successfully with **2/2** jobs on exact
pull-request head **8037c0091cdb389f19c1fcda7e5e156a78b82029**.
`scripts/cranelift_feature_registry.json` is the source authority for this
record and generates `docs/PHASE21_CLOSURE.md`.

OD-8 closes only with the evidence-supported bounded positive verdict for the
compiler-owned typed-query path and retains every named exclusion. OD-15 closes
under strict binary identity in its pinned authoritative environment. The
complete Cranelift-built-compiler suite accounts for all 326 cases as 192
required native passes and 134 owned, reason-coded deferrals. Phase 21 does not
flip the default backend, retire MIR-to-C, establish the trusted request
context, broaden the typed-query claim, implement Stdlib/CR-15, or begin Phase
22.

---

# Immutable Phase 20 Completion Record — Whole-Program Differential Qualification

**Lane:** Cranelift. Branches follow the existing `codex/phase<N>-<patch>-<slug>` pattern.

Workflow, Monitoring, Merge, Phase Completion, Runner, and Git Authorization
policies are defined once in `AGENTS.md`. Ownership boundaries and the shared
coordination zone are defined in `AGENTS.md` and
`docs/SHARED_SEMANTIC_ZONE.md`. This document defines only what is specific to
Phase 20.

Phase 20 closes the known compiler-owned semantic blockers that prevent a
representative whole program from entering the differential cohort, then
qualifies that cohort through MIR-to-C and Cranelift. The prerequisites are
bounded to CR-11/#158, CR-12/#159, CR-13/#160, the checked contextual generic
constructor-result gap blocking Stdlib S1.4, and the generic
resource/destructor/scope/construction requirements represented by CR-5 and
#106. They come before qualification because a corpus that cannot express safe
library resources, whose constructor changes type at a contextual boundary, or
whose meaning changes with a brand annotation is not representative evidence.

The phase does not adopt a general lifetime algebra, arbitrary brand
relationships, async destructors, fallible implicit cleanup, a complete
package/application visibility system, new smart-pointer families, or any
backend-specific stdlib rule. It does not change a stdlib API. Those remain
separate decisions and separate lane work.

## Roadmap Activation

Phase 19 is fully closed. Its authoritative Historical Full run was
`32586399260`, event `workflow_dispatch`, completed `success` with 17/17 jobs on
exact merged `main` `a95e40d8f1cd4e6d31212e98105026d38b488c9b`. The generated
closure record correction subsequently merged, and the operator independently
verified `origin/main` at
`f9c1cf412f9705519fe78ac8fea174c7e75c3bc2`, with no open pull request.

On 2026-08-22 the operator explicitly activated this Phase 20 roadmap and its
implementation loop. After the roadmap pull request merges, the Phase
Completion Loop in `AGENTS.md` authorizes autonomous work through Patch 20.17,
subject to the patch boundaries, validation requirements, shared-zone rules,
and stop conditions below.

On 2026-08-23, after Patch 20.3 merged as
`3aa27d4fd6618293ecd3942f251f0e8b576e5280`, a checked Stdlib S1.4 seven-point
report established a new compiler-owned contextual generic constructor-result
gap. The operator directed Cranelift to triage it at this clean patch boundary
without folding it into Patch 20.3. This amendment inserts it as Patch 20.3a,
using the established lettered-patch convention and leaving every untouched
20.4–20.17 identity unchanged; the existing Phase 20 activation and completion
loop continue through closure.

Later on 2026-08-23, two P1 review threads filed after Patch 20.9 had already
merged demonstrated that conditional obligation state was not joined and that
by-value transfer did not establish the callee's obligation. The operator
directed Cranelift to verify and correct both findings before Patch 20.10. This
amendment inserts Patch 20.9a without widening it into the automatic cleanup
work reserved for Patch 20.10.

On 2026-08-24, after Patch 20.13, the preserved Stdlib S1.8 probe exposed two
generic compiler defects and one separate open design question: branded generic
Resource destructors fail declaration validation, a direct safe same-brand
reference parameter is misclassified as raw-derived when stored in an
aggregate, and `Mutex.Lock()` still has the compiler-owned
`RawPointer(T)`/explicit-`Unlock()` contract. The operator directed Cranelift to
record and triage the handoff without widening Patch 20.14 or deciding the
Stdlib API. This amendment inserts Patch 20.14a for only the two generic
compiler defects and registers the protected-access choice as OD-13 in
`docs/VISION.md` §0.15. Patch 20.14 remains unchanged.

On 2026-08-24, after Patch 20.16 merged as
`65bbc59b7b2f4ffe5e4134b7835803275c9a6aba`, the operator resolved OD-13 in
favour of one move-only linear guard carrying safe context-branded protected
access and owning automatic exactly-once unlock. This amendment inserts Patches
20.16a–20.16e before closure. They preserve the required inert-support,
whole-tree-migration, then enforcement sequence; keep raw access only as an
explicit unsafe/internal primitive; and leave the Stdlib type, spelling,
representation, re-entrancy, and accessor ergonomics to the Stdlib lane.

Activation is Cranelift-only. It does not authorize edits to `TASK_STDLIB.md`,
does not activate another lane, and does not authorize Phase 21.

## Status

- [x] Patch 20.0 — Opening Evidence and Qualification Authority — DONE
- [x] Patch 20.1 — Canonical Brand-Matching Primitives — DONE
- [x] Patch 20.2 — Nested Brand Annotation Correction (CR-11/#158) — DONE
- [x] Patch 20.3 — Exact Branded Assignment and Annotation (CR-12/#159) — DONE
- [x] Patch 20.3a — Contextual Generic Constructor Result Authority — DONE
- [x] Patch 20.4 — Arena Lifecycle State Authority — DONE
- [x] Patch 20.5 — Arena.Free Receiver Invalidation (CR-13/#160) — DONE
- [x] Patch 20.6 — Inert Resource Declaration and Visibility Surface — DONE
- [x] Patch 20.7 — Resource Declaration Migration Under the No-op — DONE
- [x] Patch 20.8 — Resource Declaration and Construction Enforcement — DONE
- [x] Patch 20.9 — Acquisition-Site Resource Obligations (#106) — DONE
- [x] Patch 20.9a — Obligation Path Join and Callee Ownership Correction — DONE
- [x] Patch 20.10 — Generic Scope and Destructor Enforcement (CR-5) — DONE
- [x] Patch 20.11 — Bootstrap Seed Regeneration and Fixed-Point Convergence — DONE
- [x] Patch 20.12 — Whole-Program Corpus and Observable Contract — DONE
- [x] Patch 20.13 — Stdlib and Runtime Component Differential — DONE
- [x] Patch 20.14 — Generated-MIR, Scale, and Resource-Use Qualification — DONE
- [x] Patch 20.14h — Phase-Frozen Historical Accounting — DONE
- [x] Patch 20.14a — Generic Guard Prerequisite Corrections — DONE
- [x] Patch 20.14b — Post-Prerequisite Bootstrap Seed Reconvergence — DONE
- [x] Patch 20.15 — Long-Lived and Concurrent Resource Differential — DONE
- [x] Patch 20.16 — Cross-Feature Qualification and Residue Audit — DONE
- [x] Patch 20.16a — Mutex Guard Decision and Implementation Authority — DONE
- [x] Patch 20.16b — Inert Resource-Rooted Access Authority — DONE
- [x] Patch 20.16c — Explicit-Unsafe Mutex Primitive Migration — DONE
- [x] Patch 20.16d — Protected-Access Liveness Enforcement — DONE
- [x] Patch 20.16e — Protected-Access Bootstrap Seed Reconvergence — DONE
- [x] Patch 20.17 — Phase 20 Closure — DONE

Status rows are machine-parsed in the same form the Phase 15–19 close guards
parse `TASK.md`. Keep each row as `- [ ] Patch 20.N — <Title>` or
`- [x] Patch 20.N — <Title> — DONE`, with no trailing annotation. An inserted
amendment may append one lowercase letter to `N`, as Patch 20.3a does here.

## Immutable Phase 19 Completion Record

These rows describe the closed parent phase and are not active Phase 20 work.
They remain in `TASK.md` because historical guards consume them.

- [x] Patch 19.0 — Opening Inventory and Phase 18 Residual Rebase — DONE
- [x] Patch 19.1 — Identifier-Spelling Decision Inventory — DONE
- [x] Patch 19.2 — Compiler-Owned Brand Identity Authority — DONE
- [x] Patch 19.3 — Canonical Branded Type Naming Without a Brand Vocabulary — DONE
- [x] Patch 19.4 — Type-Derived Container and Arena Classification — DONE
- [x] Patch 19.5 — Argument and Index Representation From the Type System — DONE
- [x] Patch 19.6 — Self-Hosted Rule Convergence — DONE
- [x] Patch 19.7 — Retired Prototype Absence Contract — DONE
- [x] Patch 19.8 — Name-List Removal From the Self-Hosted Compiler — DONE
- [x] Patch 19.9 — Seed Regeneration and Fixed-Point Convergence — DONE
- [x] Patch 19.10 — Generated-C Equivalence Over the Compiler's Own Sources — DONE
- [x] Patch 19.11 — Cross-Feature Composition and Complete Differential — DONE
- [x] Patch 19.12 — Phase 19 Closure — DONE

## Immutable Phase 18 Completion Record

The Phase 19 opening and closure guards consume this historical record. These rows describe the already-closed parent phase and are not active Phase 19 work.

- [x] Patch 18.0 — Opening Inventory and Phase 17 Residual Rebase — DONE
- [x] Patch 18.1 — Compiler-Owned Target Authority and Declared Target Triples — DONE
- [x] Patch 18.2 — Complete Target Support Tuple and Support Decisions — DONE
- [x] Patch 18.3 — Object Format, Section, and Symbol Binding Authority — DONE
- [x] Patch 18.4 — Relocation Model and Validation — DONE
- [x] Patch 18.5 — Target-Specific ABI Selection — DONE
- [x] Patch 18.6 — Target-Specific Runtime Package Selection — DONE
- [x] Patch 18.7 — Linker Discovery, Selection, and Invocation Policy — DONE
- [x] Patch 18.8 — Static and Dynamic Runtime Linking Modes — DONE
- [x] Patch 18.9 — Cross-Compilation Policy and Host/Target Separation — DONE
- [x] Patch 18.10 — Unsupported-Target Detection and Diagnostics — DONE
- [x] Patch 18.11 — Symbol and Relocation Inspection Evidence — DONE
- [x] Patch 18.12 — Debug Information Strategy — DONE
- [x] Patch 18.13 — Source-Location Preservation — DONE
- [x] Patch 18.14 — Optimisation-Level Policy — DONE
- [x] Patch 18.15 — Reproducible Object and Artifact Output — DONE
- [x] Patch 18.16 — Atomic Executable Publication Under Phase 9G — DONE
- [x] Patch 18.17 — Cross-Target Composition and Complete Per-Target Evidence — DONE
- [x] Patch 18.18 — Deferred Residue and Target-Coverage Audit — DONE
- [x] Patch 18.19 — Phase 18 Closure — DONE

## Immutable Phase 17 Completion Record

The Phase 18 opening and closure guards consume this historical record. These rows describe the already-closed parent phase and are not active Phase 18 work.

- [x] Patch 17.0 — Opening Inventory and Phase 16 Residual Rebase — DONE
- [x] Patch 17.1 — Compiler-Owned Runtime Boundary and Helper Classification Authority — DONE
- [x] Patch 17.2 — Supported Runtime ABI, Symbol Identity, and Versioning — DONE
- [x] Patch 17.3 — Runtime Requirements in Canonical MIR and Native Requests — DONE
- [x] Patch 17.4 — Explicit Runtime Packages and Target-Specific Selection — DONE
- [x] Patch 17.5 — Stable Runtime-Library Imports for Cranelift — DONE
- [x] Patch 17.6 — Rust Runtime Components and Native Object Integration — DONE
- [x] Patch 17.7 — Explicit Retained C Runtime Objects — DONE
- [x] Patch 17.8 — Pure Gust Runtime Modules Compiled Through MIR — DONE
- [x] Patch 17.9 — Generated C Shim Elimination and Obsolete Helper Removal — DONE
- [x] Patch 17.10 — Allocation, String, and Core Memory Runtime Audit — DONE
- [x] Patch 17.11 — I/O, Filesystem, and Resource Runtime Audit — DONE
- [x] Patch 17.12 — Threading and Synchronization Runtime Audit — DONE
- [x] Patch 17.13 — Runtime Availability, Compatibility, and Diagnostic Enforcement — DONE
- [x] Patch 17.14 — Cross-Feature Runtime Composition and Complete Differential — DONE
- [x] Patch 17.15 — Deferred Residue and Runtime-Coverage Audit — DONE
- [x] Patch 17.16 — Phase 17 Closure — DONE

## Immutable Phase 16 Completion Record

The Phase 18 closure guard consumes this historical record transitively. These rows describe the already-closed Phase 16 parent and are not active Phase 18 work.

- [x] Patch 16.0 — Opening Inventory and Phase 15 Residual Rebase — DONE
- [x] Patch 16.1 — Compiler-Owned Function ABI Authority — DONE
- [x] Patch 16.2 — Canonical MIR Signature, Call, and Result Transport — DONE
- [x] Patch 16.3 — Aggregate Parameter Classification and Passing — DONE
- [x] Patch 16.4 — Aggregate Return Classification and Hidden Result Transport — DONE
- [x] Patch 16.5 — Caller/Callee Placement and Direct-Call Agreement — DONE
- [x] Patch 16.6 — Typed Indirect Calls and Function-Value ABI — DONE
- [x] Patch 16.7 — Fat-Pointer and Selected Trait-Object Call ABI — DONE
- [x] Patch 16.8 — Unsized Value Parameter, Return, and Storage Contract — DONE
- [x] Patch 16.9 — Bounded Dynamic Stack Frames and Variable-Sized Storage — DONE
- [x] Patch 16.10 — Resource-Bearing Aggregate Call ABI — DONE
- [x] Patch 16.11 — Selected Cross-Module Aggregate and Resource ABI — DONE
- [x] Patch 16.12 — ABI Metadata and Native Request Validation — DONE
- [x] Patch 16.13 — Cross-Feature ABI Composition and Complete Differential — DONE
- [x] Patch 16.14 — Deferred Residue and ABI-Coverage Audit — DONE
- [x] Patch 16.15 — Phase 16 Closure — DONE

## Immutable Phase 15 Completion Record

The Phase 16 closure guard consumes this historical record transitively. These rows describe the already-closed Phase 15 parent and are not active Phase 18 work.

- [x] Patch 15.0 — Opening Inventory and Phase 14 Residual Rebase — DONE
- [x] Patch 15.1 — Compiler-Owned Resource and Lifetime Authority — DONE
- [x] Patch 15.2 — Resource Values in Canonical MIR — DONE
- [x] Patch 15.3 — Move-State Transitions and Use-After-Move Enforcement — DONE
- [x] Patch 15.4 — Resource Reassignment Semantics — DONE
- [x] Patch 15.5 — Cleanup Insertion at Normal Scope Exits — DONE
- [x] Patch 15.6 — Cleanup at Early Returns and Structured Exits — DONE
- [x] Patch 15.7 — Destructor Scheduling and Exactly-Once Destruction — DONE
- [x] Patch 15.8 — Manual Close Versus Deferred Cleanup — DONE
- [x] Patch 15.9 — Conditional and Loop-Carried Resource States — DONE
- [x] Patch 15.10 — Resource Metadata and Request Validation — DONE
- [x] Patch 15.11 — Directory and Selected Specialized Resource Kinds — DONE
- [x] Patch 15.12 — Panic and Failure Cleanup Policy — DONE
- [x] Patch 15.13 — Cross-Feature Resource Composition and Complete Differential — DONE
- [x] Patch 15.14 — Deferred Residue and Resource-Coverage Audit — DONE
- [x] Patch 15.15 — Phase 15 Closure — DONE

---

## Purpose

Phase 20 turns backend parity from a collection of feature witnesses into a
qualification claim about representative Gust software. It first removes the
six known compiler-owned reasons that the required corpus cannot yet be
expressed faithfully:

- CR-11/#158: explicit Graph annotations use spelling-derived nesting checks,
  reject valid nested brands, and lose the intended type after the diagnostic;
- CR-12/#159: assignment and annotation matching erase exact brand identity, so
  a destination branded for one arena can accept a value from another;
- the Stdlib S1.4 constructor-result gap: a contextual generic constructor can
  typecheck as its declared result while MIR-to-C reconstructs an `_Any`
  aggregate from the constructor spelling;
- CR-13/#160: `Arena.Free` returns `Void` but does not invalidate the live arena
  identity, so later allocation into the freed receiver type-checks;
- CR-5: user-defined linear resources lack source-declared destructor identity,
  general construction opacity, and complete generic scope enforcement; and
- #106: resource obligations begin at a named binding rather than at the
  acquisition expression, so an ignored `os.OpenDir(...)` leaks without a
  diagnostic.

The phase then exercises multi-file programs, existing stdlib and runtime
components, nested and mixed features, generated canonical MIR, large
functions/modules, long-lived processes, and concurrent resource use. For each
supported cohort, MIR-to-C remains the semantic oracle and Cranelift remains an
explicit no-fallback backend.

## Live Starting State

The roadmap was derived from exact `main`
`f9c1cf412f9705519fe78ac8fea174c7e75c3bc2`, not from issue summaries alone.
Focused compiler-backed probes on 2026-08-22 established:

- the CR-11 fixture exits 1 with three `Brand Nesting Restriction` diagnostics
  followed by the secondary `Declared Void` annotation mismatch;
- the CR-12 wrong-brand Clone destination exits 0;
- paired inferred and explicit Stdlib S1.4 witnesses typecheck and emit
  byte-identical MIR-to-C, but host C rejects `std_Channel_Any` returned from a
  helper whose canonical signature is `std_Channel_int`;
- the CR-13 allocation through a freed arena receiver exits 0;
- an ignored `os.OpenDir(...)` acquisition exits 0; and
- the same directory value assigned to a local exits 1 with the existing
  resource-leak diagnostic.

The compiler already has canonical `BrandIdentity` records, but
`env_check_brand_nesting`, `env_is_element_allowed_in_brand`, and portions of
`types_match` still reconstruct identity through stripped type-name strings.
`Arena.Free` has no live-state transition. The Step 5.1 status matrix confirms
that compiler-backed provenance and focused non-laundering coverage are green.
The Step 5.2 matrix confirms real Resource declaration/assignment registration,
move transitions, defer scheduling, cleanup-boundary validation, and directory
parity routing; its own report still classifies generalized lifecycle
enforcement as deferred. Phase 20 extends those paths rather than creating a
second resource system.

## Semantic Decisions Made by This Roadmap

These are Cranelift-lane decisions under `docs/VISION.md` §0.15. They are
recorded here so implementation does not reopen them patch by patch.

### Exact brands

Brand equality and legal nesting compare resolved `BrandIdentity` values.
Canonical printed type names remain diagnostics/code-generation material, not
semantic keys. A failed match preserves both resolved operand types so later
diagnostics cannot convert the expression to an unrelated `Void` mismatch.

### Contextual generic constructors

A generic constructor expression uses an already-resolved, structurally
compatible contextual result type at annotation, assignment, argument, and
return boundaries. That resolved semantic type is the single authority for
MIR-to-C and Cranelift lowering; a backend may not reconstruct a different
`Any` specialization from the constructor spelling. Context does not permit a
cross-template conversion, a brand cast, or a type-specific constructor rule.

### Arena liveness

Arena liveness belongs to the resolved arena identity, not a local spelling.
`Arena.Free` consumes that live identity. Every alias and field path resolving
to it observes the same terminal state. A second free and an allocation, clone,
or write through a freed identity are rejected before backend selection.

### User-declared resources

The additive source surface is:

```gust
#[linear]
#[destructor(close_guard)]
#[opaque]
type Guard {
    token: int,
}

#[private]
func close_guard(value: Guard) Void {
    // synchronous, infallible cleanup
}
```

`#[destructor(name)]` registers one same-module destructor for a linear type.
It must accept exactly one owned value of that type and return `Void`; it cannot
be extern, unsafe, generic over a different resource, asynchronous, or fallible.
`#[opaque]` makes construction and direct representation access module-owned.
`#[private]` makes a declaration callable only from its defining module, except
for the compiler's validated cleanup invocation. These are opt-in module
boundaries, not a default-visibility change and not the full package/application
visibility system described elsewhere.

The syntax lands inert, every compiler-owned in-scope declaration and use is
migrated under that no-op, and only then does enforcement turn on. No patch may
combine those three stages.

### Acquisition and cleanup

A resource obligation begins when a tracking-eligible value is acquired, even
if it is never bound. Binding, assignment, return, aggregate transport, and
payload extraction transfer the same obligation; they do not create an
unrelated one. A discarded temporary must be consumed or scheduled by the end
of its full expression. Lexical automatic cleanup is synchronous and
infallible, runs once in reverse declaration order, and recursively cleans
resource fields in reverse field order. Existing explicit close, move, defer,
return, and failure policies remain authoritative.

## Scope Boundary

Included:

- exact brand nesting/matching and diagnostic type preservation for CR-11;
- exact branded assignment/annotation/call boundaries for CR-12;
- generic contextual constructor results across annotations, assignments,
  arguments, and returns, including the checked S1.4 helper witness;
- identity-keyed arena liveness and `Arena.Free` invalidation for CR-13;
- the inert/migrate/enforce sequence for destructor declaration, type opacity,
  and private cleanup declarations;
- acquisition-time resource identity, generic transfer, lexical scope cleanup,
  and nested resource-field destruction for CR-5/#106;
- representative multi-file, stdlib/runtime, generated-MIR, scale,
  long-lived, concurrent, and cross-feature differential qualification; and
- explicit registry decisions for every selected, deferred, or unsupported
  cohort, with zero unexplained divergence.

Excluded:

- edits to `TASK_STDLIB.md` or implementation of a stdlib-owned patch;
- general lifetime syntax, brand algebra, arbitrary casts, or escape hatches;
- async or fallible implicit destructors;
- default-private modules or package/application visibility tiers;
- a new MIR instruction or a change to existing MIR meaning;
- ABI, layout, runtime-symbol, target, or linker changes not forced by a
  separately registered decision; and
- Phase 21 self-hosting work.

If implementation proves that one of the included behaviours requires an
excluded semantic expansion, register the decision-tree node and follow the
shared-zone authority process. Difficulty or patch size alone is not a stop
condition.

## Validation Model

- Level 1 guards validate source authority, registry/schema consistency,
  diagnostic identity, deterministic fixtures, and absence of fallback.
- Level 2 differentials compile the same canonical MIR through MIR-to-C and
  Cranelift and compare the observables selected by each patch.
- Level 3 remains `Cranelift Historical Full`; it is run separately and is
  required green on exact merged `main` before Phase 20 closure.
- Bootstrap-sensitive patches run `make gust` and the focused semantic tests.
  Patch 20.11 alone owns the generated `gust_v4.c` seed update and proves the
  three-stage fixed point with `make bootstrap`.
- Local validation uses focused guards. The broad historical suite is not a
  substitute for exact-head pull-request CI and is not run locally by default.

Each new guard must be registered at its real test level. Level 1 and selected
Level 2 guards enter normal pull-request workflows. Costly stress, generated
corpus, and long-lived cases remain Level 3 where the registry says so; no
closure text may claim that merely being runnable means they pass.

---

## Patch 20.0 — Opening Evidence and Qualification Authority

**Purpose**

Freeze the verified starting state and define one compiler-owned manifest for
the Phase 20 qualification cohort before changing semantics.

**Steps**

- Add a Phase 20 opening guard and registry/schema rows.
- Encode the five focused starting probes above as stable negative/positive
  evidence without altering their current verdicts.
- Inventory every existing whole-program, composition, deferred-source, and
  Historical Full pair by feature owner and test level.
- Define the qualification-observable vocabulary: compile result, exit status,
  stdout, stderr/diagnostic code and span, resource terminal state, and
  sandboxed filesystem effects.
- Record selected, deferred, and unsupported cohorts with owner, reason, and
  falsifier; no unnamed bucket is permitted.

**Test Level:** Level 1.

**Exit Gate**

The live baseline is reproducible, the qualification cohort is generated from
one authority, and this patch changes no Gust program meaning.

## Patch 20.1 — Canonical Brand-Matching Primitives

**Purpose**

Provide one resolved-identity comparison path before changing CR-11 or CR-12
behaviour.

**Steps**

- Centralize equality, nesting-membership, and mismatch-description operations
  over `BrandIdentity`.
- Route shadow/instrumentation checks through the new operations while leaving
  current acceptance and diagnostics authoritative.
- Prove nested identities, distinct same-shaped arenas, fields, aliases, and
  generic substitutions retain their identity through resolution.
- Freeze the remaining string-cleaning callers so later patches remove rather
  than duplicate them.

**Test Level:** Level 1.

**Exit Gate**

All inputs needed by CR-11 and CR-12 have a canonical identity comparison, and
the patch is behaviour-neutral.

## Patch 20.2 — Nested Brand Annotation Correction (CR-11/#158)

**Purpose**

Make explicit nested Graph annotations use the same resolved brand identities
as inference.

**Steps**

- Replace spelling/stripping decisions in brand nesting with Patch 20.1
  identity operations.
- Preserve the resolved expression and declared types after a primary nesting
  diagnostic; do not synthesize the secondary `Void` mismatch.
- Cover two and three nested brands, explicit and inferred declarations,
  aliases, fields, and a genuinely illegal escape.
- Run the same accepted program through MIR-to-C and Cranelift.

**Test Level:** Levels 1 and 2.

**Exit Gate**

Issue #158's valid explicit Graph annotation compiles with the same meaning as
the inferred form; invalid nesting still fails once with the intended code.

## Patch 20.3 — Exact Branded Assignment and Annotation (CR-12/#159)

**Purpose**

Reject values whose structure matches but whose resolved brand identity does
not.

**Steps**

- Make assignment, annotation, argument, return, and relevant generic matching
  compare exact identities after normal substitution.
- Keep wildcard/unbranded compatibility only where the existing type rule
  explicitly authorizes it.
- Add the wrong-brand Clone destination from #159 plus direct assignment,
  Index, field, alias, and call-boundary variants.
- Do not special-case Clone, Index, Graph, or an individual stdlib type.

**Test Level:** Levels 1 and 2.

**Exit Gate**

The #159 program is rejected by the generic type boundary, same-brand programs
remain accepted, and both backends receive identical canonical MIR.

## Patch 20.3a — Contextual Generic Constructor Result Authority

**Purpose**

Make a generic constructor consume the already-resolved contextual result type
instead of allowing code generation to reconstruct an unrelated `Any`
specialization.

**Steps**

- Carry expected result context generically through annotation, assignment,
  argument, and return expression checking without a Channel-specific branch.
- Accept context only when normal template, payload, and brand compatibility
  holds; do not introduce a cast or relax Patch 20.3 exact-brand boundaries.
- Preserve the resolved constructor result for MIR-to-C lowering so emitted
  expression type, function ABI, and registered aggregate layout agree.
- Add inferred/explicit paired witnesses, including a helper return and at
  least one non-Channel generic constructor control.
- Keep the direct Cranelift source route as an explicit pre-driver deferral with
  no C fallback, and compare supported canonical MIR through both backends.
- Treat the compiler change as bootstrap-sensitive, but leave generated seed
  publication to the isolated Patch 20.11 seed patch.

**Test Level:** Levels 1 and 2 plus `make gust`.

**Exit Gate**

The checked S1.4 helper emits host-compilable MIR-to-C with one canonical
constructor/result type, inferred and explicit forms agree, no individual
stdlib type is special-cased, and backend policy remains explicit.

## Patch 20.4 — Arena Lifecycle State Authority

**Purpose**

Represent arena liveness by canonical identity before rejecting new programs.

**Steps**

- Add live/freed lifecycle state keyed by resolved arena identity.
- Propagate the identity through locals, aliases, fields, parameters, and
  generic substitutions.
- Instrument allocation, clone, write, and free sites against the state while
  preserving current acceptance.
- Prove two distinct arenas and multiple aliases do not collapse into one
  spelling-derived state.

**Test Level:** Level 1.

**Exit Gate**

Every CR-13 operation resolves to one arena identity and lifecycle state, with
no behavioural enforcement yet.

## Patch 20.5 — Arena.Free Receiver Invalidation (CR-13/#160)

**Purpose**

Make `Arena.Free` consume the receiver's live arena identity.

**Steps**

- Transition the Patch 20.4 identity to freed on `Arena.Free`.
- Reject later allocation, Clone destination use, write, and repeated Free
  through any alias or field resolving to that identity.
- Preserve other independently live arenas.
- Emit one stable semantic diagnostic before either backend and add accepted
  and rejected differential fixtures.

**Test Level:** Levels 1 and 2.

**Exit Gate**

Issue #160 is rejected, alias laundering cannot revive the receiver, and the
accepted live-arena cohort remains backend-identical.

## Patch 20.6 — Inert Resource Declaration and Visibility Surface

**Purpose**

Add the source vocabulary required for user resources without changing any
program's permissions or cleanup behaviour.

**Steps**

- Parse and preserve `#[destructor(name)]`, `#[opaque]`, and `#[private]`.
- Store the declarations in AST and type metadata, but deliberately do not
  enforce signature, access, construction, or cleanup rules.
- Add parser round-trip, malformed-attribute, duplicate/conflict, and metadata
  tests.
- Add a guard proving all three attributes are still semantic no-ops in this
  patch.

**Test Level:** Level 1 plus `make gust`.

**Exit Gate**

The checked-in seed can compile the extended self-hosted parser/typechecker,
the new surface is inert, and no enforcement is enabled early.

## Patch 20.7 — Resource Declaration Migration Under the No-op

**Purpose**

Migrate the complete compiler-owned in-scope resource cohort while the new
surface remains inert.

**Steps**

- Annotate compiler-owned linear-resource fixtures with their destructor,
  opacity, and private cleanup declarations.
- Represent the directory parity resource through the same canonical metadata
  bridge while preserving its existing source compatibility and diagnostics.
- Update every compiler-owned construction, field access, explicit close, and
  defer site that enforcement will affect.
- Add an inventory guard proving no in-scope declaration or use remains on an
  unclassified migration path.

**Test Level:** Level 1 plus `make gust` and focused existing Resource guards.

**Exit Gate**

The entire compiler-owned cohort builds under the no-op syntax and behaviour is
unchanged. Enforcement is still off.

## Patch 20.8 — Resource Declaration and Construction Enforcement

**Purpose**

Enable the declaration, destructor-signature, opacity, and private-call rules
only after the migration is complete.

**Steps**

- Validate destructor existence, same-module ownership, exact owned parameter,
  `Void` result, and synchronous/infallible/non-extern status.
- Reject construction or direct representation access to an opaque type outside
  its defining module.
- Reject ordinary calls/references to private declarations outside that module,
  while allowing the compiler's validated cleanup invocation.
- Cover same-module success, cross-module construction/field/call failures,
  forged resource rejection, and backend-neutral diagnostics.

**Test Level:** Levels 1 and 2 plus `make gust`.

**Exit Gate**

A library can expose an acquirer and safe methods without exposing a forgeable
constructor or cleanup primitive, using generic type/module rules.

## Patch 20.9 — Acquisition-Site Resource Obligations (#106)

**Purpose**

Attach linear-resource ownership to acquisition rather than to a later local
binding.

**Steps**

- Allocate a stable expression/resource identity when a tracking-eligible
  acquisition succeeds.
- Transfer that identity through binding, assignment, return, aggregate
  transport, and payload extraction.
- Require an ignored temporary acquisition to be consumed or scheduled by the
  end of its full expression.
- Cover both #106 variants, conditional acquisition, returned resources,
  payloads, aliases, and a non-resource temporary control.
- Use the same path for directory and user-declared resources.

**Test Level:** Levels 1 and 2.

**Exit Gate**

Both bound and unbound leaking acquisitions fail through one generic obligation
path, while valid transfers do not acquire duplicate obligations.

## Patch 20.9a — Obligation Path Join and Callee Ownership Correction

**Purpose**

Correct the two post-merge Patch 20.9 ownership gaps before automatic cleanup
is introduced.

**Steps**

- Join acquisition-obligation terminal state across `if`, `match`, and
  zero-iteration loop paths so one consuming branch cannot discharge another
  reachable path.
- Establish a pending callee obligation for every owned resource parameter,
  while treating the validated destructor itself as the terminal operation.
- Preserve valid all-path consumption, by-value pass-through, return transfer,
  diagnostic deduplication, and backend-neutral rejection.
- Do not insert destructor calls or change cleanup order; those remain Patch
  20.10.

**Test Level:** Levels 1 and 2 plus `make gust`.

**Exit Gate**

A one-branch or loop-only close and an empty by-value callee reject through the
generic acquisition-obligation path, while all-path close and callee return or
consumption remain accepted.

## Patch 20.10 — Generic Scope and Destructor Enforcement (CR-5)

**Purpose**

Complete generic exactly-once resource cleanup across lexical scopes and
resource-bearing aggregates.

**Steps**

- Invoke registered destructors for owned resources on normal scope exit and
  preserve the established return, structured-exit, and failure policies.
- Run cleanup in reverse declaration order and resource-field cleanup in reverse
  field order.
- Preserve explicit close/defer interactions, move terminal states,
  reassignment rules, and diagnostic deduplication.
- Generalize directory parity fully; retain compatibility storage only where a
  guard proves it has no enforcement read.
- Add nested scopes, branches, loops, early returns, aggregates, manual close,
  scheduled cleanup, double close, use-after-move, and constructor-opacity
  composition fixtures through both backends.

**Test Level:** Levels 1 and 2 plus focused Resource suites.

**Exit Gate**

CR-5's compiler prerequisites are available generically: source-declared
destructor identity, non-forgeable construction, acquisition-time ownership,
scope cleanup, and exactly-once destruction all agree through MIR-to-C and
Cranelift.

## Patch 20.11 — Bootstrap Seed Regeneration and Fixed-Point Convergence

**Purpose**

Regenerate the C bootstrap seed after the self-hosted semantic cluster, in an
isolated seed-only patch.

**Steps**

- Start from merged Patch 20.10.
- Run `make bootstrap` and require stage 2 and stage 3 byte identity.
- Commit only the generated `gust_v4.c` change and seed-specific authority.
- Re-run the focused Phase 20 semantic guards with the converged seed.

**Test Level:** Level 1 plus bootstrap convergence.

**Exit Gate**

The seed is generated, not hand-edited; the patch contains no capability
change; and the three-stage compiler is at a fixed point.

## Patch 20.12 — Whole-Program Corpus and Observable Contract

**Purpose**

Define representative programs and a reproducible comparison contract before
claiming whole-program parity.

**Steps**

- Add selected multi-file programs combining modules, generics, brands,
  resources, aggregates, control flow, I/O, and failure diagnostics.
- Capture compile result, process exit status, stdout, stderr/diagnostics,
  resource terminal state, and sandboxed filesystem effects.
- Normalize only explicitly declared environmental noise; never normalize a
  semantic difference.
- Run each selected program from the same canonical MIR through MIR-to-C and
  Cranelift with no fallback.

**Test Level:** Level 2, with costly cases registered Level 3.

**Exit Gate**

The corpus and observable contract are registry-derived, deterministic, and
produce no unexplained difference for the selected initial cohort.

## Patch 20.13 — Stdlib and Runtime Component Differential

**Purpose**

Qualify existing safe library and runtime components as program building blocks
without changing their APIs.

**Steps**

- Select currently implemented collection, string, filesystem, allocation,
  threading/synchronization, and runtime-boundary components whose Cranelift
  routes are declared supported.
- Exercise them across module boundaries and in resource-bearing programs.
- Compare outputs, status, cleanup, filesystem effects, and diagnostics.
- Declare every excluded component with its existing owner/reason/falsifier;
  do not silently shrink the cohort or use C fallback.

**Test Level:** Levels 2 and 3 according to cost.

**Exit Gate**

Every selected component has a whole-program differential, and every excluded
component is an explicit registry decision rather than an unexplained hole.

## Patch 20.14 — Generated-MIR, Scale, and Resource-Use Qualification

**Purpose**

Test canonical MIR combinations and compiler scale beyond hand-written source
fixtures.

**Steps**

- Add a deterministic, dependency-free generator for valid canonical MIR
  combinations within declared feature constraints.
- Compare both backends over a recorded seed set and preserve minimized failing
  cases as fixtures.
- Add large-function and large-module cohorts.
- Record compile time and peak memory with a reproducible measurement protocol,
  baseline, sample count, and explicit threshold policy.

**Test Level:** Level 2 for small deterministic samples; Level 3 for the full
generated and scale cohorts.

**Exit Gate**

The bounded generated set has zero unexplained divergence, stress cases finish
inside their declared resource budgets, and no threshold can drift silently.

## Patch 20.14h — Phase-Frozen Historical Accounting

**Purpose**

Keep the closed Phase 19 self-compilation differential reproducible after
later phases legitimately change compiler sources and regenerate the bootstrap
seed.

**Steps**

- Freeze the final Phase 19 comparison at the registry-named Phase 19.11 seed
  commit instead of repository `HEAD`.
- Continue reconstructing and attributing every Phase 19 compiler-changing
  boundary with the existing full-history fetch requirement.
- Record that Phase 20 and later compiler changes and seeds belong to their own
  phase history and do not retroactively alter Phase 19 evidence.
- Preserve the existing baseline-to-Phase-19 insertion/deletion totals and zero
  unexplained-difference requirement.

**Test Level:** Level 1 for registry/generated contract; Level 3 for the frozen
historical reconstruction.

**Exit Gate**

The Phase 19 Historical Full shard reconstructs the named Phase 19 boundaries,
matches the named Phase 19.11 seed, and remains green when later-phase compiler
sources or seeds differ from that frozen result.

## Patch 20.14a — Generic Guard Prerequisite Corrections

**Purpose**

Correct the two generic frontend defects independently blocking a branded
Resource guard, without choosing or changing the Mutex protected-access API.

**Steps**

- Match a declared Resource destructor's single owned parameter against the
  canonical generic/template type after brand substitution, not against an
  unsubstituted struct-name spelling.
- Preserve the existing non-laundering boundary while carrying safe-reference
  parameter provenance through a same-brand aggregate field assignment and
  return.
- Add positive generic/branded witnesses and negative wrong-type,
  wrong-brand, raw-derived, and sandbox-derived witnesses; prove accepted
  programs retain identical MIR-to-C and supported Cranelift meaning.
- At this patch's historical boundary, keep `Mutex.Lock() -> RawPointer(T)` and
  explicit `Unlock()` unchanged while OD-13 is open. Do not add a Mutex-specific
  destructor exception, raw-pointer
  wrapper, Stdlib API, MIR instruction, ABI/layout change, or runtime symbol.

**Test Level:** Levels 1 and 2.

**Exit Gate**

Generic/branded Resource destructor validation and safe same-brand reference
capture work through canonical type/provenance authority, all unsafe-derived
negative cases remain rejected, and OD-13 remains an explicit shared-zone
block at this patch's historical boundary rather than an implicit API choice.

Because this correction changes the self-hosted typechecker after the earlier
Patch 20.11 fixed point, generated seed publication remains isolated. Patch
20.14b is the required seed-only follow-up; it is not part of this capability
patch.

## Patch 20.14b — Post-Prerequisite Bootstrap Seed Reconvergence

**Purpose**

Restore the checked-in bootstrap fixed point after Patch 20.14a without hiding
generated seed churn inside the semantic correction.

**Steps**

- Start from merged Patch 20.14a and run `make bootstrap`, requiring stage 2 and
  stage 3 byte identity.
- Commit only the generated `gust_v4.c` change and seed-specific authority.
- Re-run the Patch 20.14a Level 1 contract with the converged seed.
- Preserve OD-13 and all compiler, MIR, ABI, layout, runtime-symbol, and Stdlib
  semantics unchanged.

**Test Level:** Level 1 plus bootstrap convergence.

**Exit Gate**

The seed-only diff reaches a three-stage fixed point, accounts for Patch
20.14a, and contains no capability or API change.

## Patch 20.15 — Long-Lived and Concurrent Resource Differential

**Purpose**

Qualify lifecycle semantics where bugs appear only after repetition or across
threads.

**Steps**

- Exercise repeated acquire/transfer/close cycles, nested resource aggregates,
  and bounded long-lived allocation.
- Exercise selected threading and synchronization paths with deterministic
  invariants rather than scheduler-order output.
- Compare exactly-once cleanup, terminal states, exit status, and externally
  visible effects across both backends.
- Keep unsupported concurrency/resource combinations explicit and diagnostic;
  do not weaken them into backend-specific behaviour.

**Test Level:** Level 3, with small deterministic smoke cases at Level 2.

**Exit Gate**

The selected long-lived and concurrent cohort completes without leak,
double-destruction, deadlock, fallback, or unexplained backend divergence.

## Patch 20.16 — Cross-Feature Qualification and Residue Audit

**Purpose**

Compose the full Phase 20 cohort and make every remaining difference explicit.

**Steps**

- Run brand identity/liveness, user resources, modules, stdlib/runtime, scale,
  and concurrency in mixed programs.
- Audit source-to-MIR and canonical-MIR-to-backend registries for stale,
  duplicated, orphaned, or unowned rows.
- Resolve every selected-cohort divergence or register a bounded deferral with
  owner, reason, diagnostic, and falsifier.
- Prove no selected route falls back from Cranelift to generated C.
- Generate the Phase 20 readiness record from its compiler-owned source.

**Test Level:** Levels 1, 2, and the registered Level 3 composition cohort.

**Exit Gate**

All selected pairs pass, all exclusions are explained and owned, there are zero
unexplained divergences, and the generated record says Phase 20 is ready for an
authoritative Historical Full run.

## Patch 20.16a — Mutex Guard Decision and Implementation Authority

**Purpose**

Record the operator's OD-13 decision and establish the smallest generic,
bootstrap-safe implementation sequence without changing compiler behaviour.

**Steps**

- Make `docs/VISION.md` §26.1 normative: safe lock acquisition returns one
  move-only linear guard carrying context-branded protected access and owning
  automatic exactly-once unlock on every scope exit.
- Record that raw-pointer/manual unlock may remain only explicit unsafe or
  compiler-internal machinery and that no separate compiler-owned access token
  is introduced.
- Assign generic resource-rooted access provenance and liveness to Cranelift
  while leaving guard spelling, representation, re-entrancy, and accessor
  ergonomics to Stdlib.
- Update the compiler-owned registry and generated review so the former OD-13
  open state remains identifiable as Patch 20.14a history but cannot be mistaken
  for current authority.

**Test Level:** Level 1 registry/generated contract.

**Exit Gate**

OD-13 is resolved coherently in the decision register, normative section,
shared-zone map, roadmap, registry, and generated review; no compiler, MIR,
ABI, layout, runtime-symbol, bootstrap-seed, or Stdlib behaviour changes.

## Patch 20.16b — Inert Resource-Rooted Access Authority

**Purpose**

Add the generic compiler representation needed to associate protected access
with a live linear Resource guard, while preserving all accepted and rejected
source behaviour.

**Steps**

- Add canonical frontend state and queries for a reference whose access
  authority is rooted in one linear Resource value; do not add a Mutex-specific
  typechecker or backend path.
- Carry the root identity through bindings and guard moves without enforcing a
  new rejection yet. Moving the guard transfers the one identity; close and
  destruction identify its terminal state.
- Add inert positive witnesses and inventory guards proving the new authority
  is recorded but cannot change program meaning in this patch.
- Preserve canonical MIR meaning, MIR-to-C parity, explicit Cranelift
  no-fallback, runtime symbols, ABI, and layout.

**Test Level:** Level 1 contract and Level 2 unchanged-meaning differential.

**Exit Gate**

The self-hosted compiler and seed accept the inert authority, the full selected
source cohort retains its declared observable, and no protected-access
rejection is enabled.

## Patch 20.16c — Explicit-Unsafe Mutex Primitive Migration

**Purpose**

Migrate every existing compiler-owned use of raw Mutex lock/unlock primitives
under the still-inert rule before safe-call enforcement changes.

**Steps**

- Inventory every Gust call to the compiler-owned raw `Lock()` and `Unlock()`
  primitives, including compiler fixtures, bootstrap targets, and tests.
- Place the whole inventory behind the language's existing explicit unsafe
  boundary while safe calls remain temporarily accepted, so this patch is a
  semantic no-op.
- Add an exhaustive migration guard that rejects unclassified raw primitive
  call sites and records which ones are transitional test coverage.
- Do not add the Stdlib guard API or choose its naming, representation,
  re-entrancy, or accessor form.

**Test Level:** Levels 1 and 2 plus bootstrap buildability.

**Exit Gate**

Every compiler-owned raw lock/unlock call site is classified and explicitly
unsafe, all previous observables and backend parity remain unchanged, and the
compiler still builds itself before enforcement is enabled.

## Patch 20.16d — Protected-Access Liveness Enforcement

**Purpose**

Enable the resolved generic safe contract after the inert authority and
whole-tree migration are complete.

**Steps**

- Make a live move-only Resource guard the sole safe authority for its rooted
  context-branded protected access; moving the guard transfers both authority
  and its acquisition obligation.
- Reject access detached from the guard, escape or storage beyond the guard,
  and use after guard move, explicit close, destructor, or any scope exit.
- Require the existing raw Mutex lock/unlock primitives to be called only from
  an explicit unsafe boundary; keep their runtime ABI internal and unchanged.
- Prove automatic cleanup unlocks exactly once on normal, early-return,
  conditional, and failure exits, with positive and negative source tests,
  MIR-to-C tests, and supported Cranelift differential tests.
- Preserve non-laundering, use no separate access token, add no Mutex-specific
  Resource exception, and add no new MIR operation, ABI/layout rule, or runtime
  symbol.
- Publish checked implementation authority and notify the registrar so Stdlib
  S1.8 may re-derive its blocked work without prescribing its API ergonomics.

**Test Level:** Levels 1 and 2, with the registered lifecycle composition at
Level 3.

**Exit Gate**

Safe access is possible exactly while its live guard exists, cannot escape or
survive it, raw/manual access is explicit unsafe only, exactly-once cleanup and
backend parity hold, and the generated handoff says implementation authority
has landed.

## Patch 20.16e — Protected-Access Bootstrap Seed Reconvergence

**Purpose**

Restore the checked-in bootstrap fixed point after the protected-access
compiler changes without hiding generated seed churn in a semantic patch.

**Steps**

- Start from merged Patch 20.16d and run `make bootstrap`, requiring stage 2 and
  stage 3 byte identity.
- Commit only generated `gust_v4.c` and seed-specific authority.
- Re-run the Patch 20.16d Level 1 contract with the converged seed.
- Preserve the resolved contract and all runtime, ABI, layout, MIR, and Stdlib
  boundaries unchanged.

**Test Level:** Level 1 plus bootstrap convergence.

**Exit Gate**

The seed-only diff reaches a three-stage fixed point, accounts for Patch
20.16d, and contains no capability or API change.

## Patch 20.17 — Phase 20 Closure

**Purpose**

Close the phase only after exact merged-main authoritative evidence exists.

**Steps**

- Confirm every Phase 20 Status row is `DONE` and every criterion below is met.
- Confirm all compiler-owned issue scenarios are resolved by focused guards;
  issue/coordination bookkeeping follows its owning lane and is not simulated by
  editing `TASK_STDLIB.md`.
- Run `Cranelift Historical Full` against the exact merged `main` containing
  Patch 20.16e.
- Require the full run to complete successfully, cite run ID, event, exact
  40-character head SHA, and job population, then update the generated closure
  source and artifact coherently.
- Add and pass the Phase 20 closure guard and record terminal lane state.

**Test Level:** Level 1 closure guard plus authoritative Level 3.

**Exit Gate**

The most recent applicable Historical Full run on exact merged `main` is green,
the generated closure record agrees with the terminal record, all review
conversations are resolved, and Phase 20 is closed. A merely available or still
running Level 3 suite does not satisfy this gate.

## Recommended Implementation Order

20.0 evidence/authority
→ 20.1 inert brand primitives
→ 20.2 CR-11
→ 20.3 CR-12
→ 20.3a contextual generic constructor results
→ 20.4 inert arena lifecycle authority
→ 20.5 CR-13
→ 20.6 inert declaration surface
→ 20.7 full no-op migration
→ 20.8 declaration/visibility enforcement
→ 20.9 acquisition identity
→ 20.9a path join and callee ownership correction
→ 20.10 generic cleanup
→ 20.11 seed convergence
→ 20.12 observable corpus
→ 20.13 stdlib/runtime components
→ 20.14 generated MIR and scale
→ 20.14h phase-frozen historical accounting
→ 20.14a generic guard prerequisites
→ 20.14b post-prerequisite seed reconvergence
→ 20.15 long-lived/concurrent resources
→ 20.16 complete qualification
→ 20.16a Mutex guard decision authority
→ 20.16b inert resource-rooted access authority
→ 20.16c explicit-unsafe raw primitive migration
→ 20.16d protected-access liveness enforcement
→ 20.16e protected-access seed reconvergence
→ 20.17 closure.

The no-op boundaries at 20.1/20.2, 20.4/20.5, and especially
20.6/20.7/20.8 are load-bearing. They prevent the self-hosted compiler from
having to understand and enforce a new idiom in the same bootstrap step.

## Phase 20 Success Criteria

Phase 20 succeeds when:

- explicit and inferred nested brand forms have identical meaning;
- wrong-brand assignments, annotations, arguments, and returns are rejected by
  exact resolved identity rather than by callee-specific checks;
- contextual generic constructors retain one resolved type through typechecking,
  MIR-to-C, and supported Cranelift lowering without an `_Any` reconstruction;
- `Arena.Free` invalidates its canonical receiver identity through all aliases;
- user-defined linear resources declare a validated destructor and can keep
  construction, representation, and cleanup authority inside their module;
- resource obligations begin at acquisition and transfer exactly once through
  binding, aggregates, returns, close, defer, and lexical cleanup;
- automatic cleanup is synchronous, infallible, deterministic, reverse-order,
  and backend-identical;
- representative multi-file software and selected existing stdlib/runtime
  components match in outputs, status, diagnostics, resource state, and
  sandboxed filesystem effects;
- generated canonical MIR, large functions/modules, and bounded resource-use
  cohorts pass their declared budgets;
- long-lived and concurrent selected programs have deterministic invariants and
  no leak, double destruction, deadlock, fallback, or unexplained divergence;
- safe Mutex acquisition is represented by one move-only linear guard whose
  live resource identity authorizes context-branded protected access and whose
  cleanup unlocks exactly once on every scope exit;
- protected access cannot detach from, escape, or survive its guard, while raw
  lock/unlock primitives are available only behind an explicit unsafe/internal
  boundary and have identical meaning through both backends;
- every unsupported or deferred cohort is registry-owned with a reason and
  falsifier, and the selected cohort has zero unexplained differences;
- the bootstrap seed is regenerated alone and reaches a three-stage fixed
  point; and
- an authoritative `Cranelift Historical Full` run completes successfully on
  the exact merged Phase 20 head and is cited in both closure and terminal
  records.

Phase 20 does not claim universal language coverage or Phase 21 self-hosting.
It claims that the declared representative cohort is semantically coherent,
fully explained, and differentially qualified.

## Phase 20 Closure Record

Phase 20 closed on 2026-08-24 after `Cranelift Historical Full` run
**32772996884** completed successfully for event `workflow_dispatch` on exact
merged `main` **6e54e3cc6fa8fc44e5df7a67624bb183b01b2258**. The complete job
population was **18/18** jobs completed successfully, with zero unfinished and
zero non-success jobs. `scripts/cranelift_feature_registry.json` is the source
authority for this record and generates `docs/PHASE20_CLOSURE.md`.

The selected cohort has zero unexplained differences; all six remaining
cross-feature residues have explicit owners, reason codes, failure stages,
destinations, and falsifiers, with explicit Cranelift no-fallback preserved.
Patch 20.16d's generic protected-access implementation authority remains the
Stdlib handoff; Phase 20 does not select the library's public Mutex API.

---

## Immutable Phase 19 Detailed Record

The remaining sections are the detailed record of the closed parent phase.
They are retained because Phase 19 guards consume its exact closure evidence.

## Phase 19 Purpose

Phase 19 makes brand identity and value representation follow from the type
system rather than from how a variable happens to be spelled.

Today the self-hosted compiler carries a hardcoded list of identifier names
treated as arena brands. The generated inventory is authoritative; representative
sites are:

```text
compiler/codegen.gst:658,762,896,1101,1851
compiler/typechecker.gst:159,2279,4975,5172
```

The list serves two distinct purposes, and the phase must separate them before it
can remove either:

**Type-name erasure.** Generated C type names such as
`std_Vector_lib_module__ctx` are reduced to a canonical form by stripping known
brand suffixes. This is canonical type identity expressed through string
surgery on a fixed vocabulary.

**Classification override.** At index and call sites, the compiler derives
`is_slice`, `is_ptr`, `is_vector`, `is_hashmap`, and `is_pool` from the resolved
type and the struct registry — and then `is_arena_override`, computed purely
from the identifier's spelling, forcibly clears all five
(`compiler/codegen.gst:1851-1863`).

That second one is the important discovery. **The type system already computes
the classification; a name check overrules it.** The override exists because the
type-derived path is not trusted in some cases. Making it trustworthy is the
work of this phase; deleting the override is the consequence.

The user-visible defect this produces:

```gust
func probe(s: str) int { return std.str_byte_at(s, 0); }
func main() {
    mut a: str := "PING";      // name is in brand_bases
    os.LogInt(probe(a));       // emits probe(&a) — rejected by cc
}
```

Renaming `a` to `b` fixes the program. Nothing about the type changed.

## Starting State

Verified 2026-08-19. Evidence: `docs/STDLIB_SURFACE_FINDINGS.md`, findings F3,
F3a, F3b.

- The generated `compiler/CRANELIFT_PHASE19_SPELLING_INVENTORY.md` records nine
  live decision sites: five in `compiler/codegen.gst` and four in
  `compiler/typechecker.gst`.
- The former Rust/self-hosted rule divergence was D-2. It closed on 2026-08-21
  when the deprecated Rust prototype was removed; it is historical evidence,
  not a second implementation Phase 19 must preserve or reconcile.
- **The blast radius is the compiler itself.** `compiler/*.gst` contains roughly
  2,312 declarations named `ctx`, `arena`, `a`, or `connCtx`, and roughly 2,183
  `ctx[...]` index sites. Every one is currently classified by name. A
  type-derived replacement must produce identical output for all of them or the
  compiler will not bootstrap.
- `gust_v4.c` encodes the current behaviour. Phase 19 cannot land without a seed
  regeneration.
- A converged seed regeneration was performed 2026-08-19 and is append-only
  relative to the committed seed (1,920 insertions, 0 deletions), confirming the
  bootstrap chain is healthy before this phase begins.

Contracts Phase 19 consumes and must not redefine:

- Phase 14 owns type layout, target layout, and memory-access validation.
- Phase 15 owns resource identity, move state, cleanup, destruction.
- Phase 16 owns signatures, parameter and result placement, and call plans.
  **Argument representation is Phase 16 territory**; Phase 19 makes the compiler
  ask Phase 16 rather than guess from a name.
- Phase 17 owns runtime ABI and symbol identity.
- Phase 18 owns target, object format, relocation, linker, and link mode.
- MIR-to-C remains the default backend and differential oracle.
- Explicit Cranelift selection has no fallback.

## Phase Boundary

Phase 19 may implement:

- a compiler-owned brand identity record derived from resolved types;
- canonical branded type naming that does not depend on a brand-word vocabulary;
- type-derived container and arena classification sufficient to retire the
  spelling override;
- argument and index representation decisions sourced from Phase 16;
- convergence of the self-hosted compiler's spelling consumers on one rule
  before the rule is removed;
- removal of the hardcoded name list from the self-hosted compiler;
- a seed regeneration proving fixed-point convergence under the new rules;
- byte-level generated-C equivalence evidence over the compiler's own sources.

Phase 19 must not silently absorb:

- new lifetime syntax, lifetime relations, or lifetime casts;
- arbitrary brand relationships, brand casts, or brand escape hatches;
- new ABI classification rules — Phase 19 selects, Phase 16 defines;
- new MIR operations, or changed meaning for existing ones;
- resource, drop, or move semantics changes;
- changes to layout or the runtime ABI;
- stdlib API design — that is `TASK_STDLIB.md`;
- renaming variables in `compiler/*.gst` to work around the defect;
- any change that makes the compiler's generated C differ without an explained,
  evidenced reason.

## Compiler-Owned Brand and Representation Authority

- The compiler produces a brand identity record for every branded type: brand
  origin, arena identity, and whether the value denotes an arena.
- Arena-ness is a property of the resolved type. It is never inferred from an
  identifier, a field name, or a substring of a generated expression.
- Canonical branded type identity is produced once by type resolution and
  consumed unchanged by both backends. Neither backend reconstructs branding.
- Container classification is produced from the resolved type and the struct
  registry, with no spelling-derived override.
- Argument representation — by value or by address — is a Phase 16 ABI decision
  recorded in canonical MIR, not a codegen-time string transformation.

## Architectural Invariants

- Renaming a local variable never changes generated code.
- Every self-hosted spelling consumer applies one classification rule until the
  spelling rule is removed.
- No component decides arena-ness, container kind, or argument representation
  from an identifier spelling, a substring, or a generated expression's text.
- Canonical MIR carries the representation decision; codegen consumes it.
- The bootstrap seed compiles the post-change compiler sources, and the compiler
  reaches a three-stage fixed point.
- MIR-to-C remains an independent differential oracle.
- Explicit Cranelift has no fallback.
- No exact-source, fixture-name, or identifier-name recognizer is introduced to
  replace the one being removed.

## Verification Policy

### Level 1 — Fast contracts

Level 1 guards may validate:

- the Phase 18 closure record and Phase 19 opening traceability;
- absence of the brand-name list in each compiler as its removal patch lands;
- absence of any spelling-derived classification override;
- brand identity record schemas;
- canonical branded type identity for paired inferred and explicit programs;
- agreement among the self-hosted compiler's classification consumers;
- representation decisions present in canonical MIR;
- generated projection freshness.

### Level 2 — Focused differential families

Proposed family vocabulary:

- `brand-identity`;
- `branded-type-naming`;
- `container-classification`;
- `argument-representation`;
- `rename-invariance`.

`rename-invariance` is the family that would have caught this defect. For a
fixture, compile it, rename every local to a fresh name, compile again, and
require byte-identical generated C. Add it early — Patch 19.1 — so it is
measuring throughout the phase rather than confirming at the end.

### Level 3 — Historical and complete evidence

Cranelift Historical Full remains the sole Level 3 owner. Phase 19 adds the
compiler-self-compilation differential described in Patch 19.10 to that suite;
it does not create a second historical suite.

## Standard Definition of Done for Every Phase 19 Capability Patch

- The supported source shape is precisely bounded.
- The decision it changes is sourced from a resolved type, never a spelling.
- The self-hosted type authority and both backends agree, and a guard proves it.
- Canonical MIR carries the decision where the decision is semantic.
- Paired programs differing only in variable names produce byte-identical C.
- Paired inferred-type and explicit-type programs produce the same canonical
  type, ABI, layout, and behaviour.
- MIR-to-C output is byte-identical to the pre-patch output, or every difference
  is enumerated with a reason.
- Cranelift behaviour is compared where the feature is in the supported cohort,
  and explicitly deferred where it is not.
- `make bootstrap` reaches a three-stage fixed point.
- The seed is regenerated only by Patch 19.9, never as a side effect.
- Brand misuse is still rejected: wrong arena, moved arena, incompatible region.
- No identifier-, fixture-, or substring-based recognizer was introduced.
- The owning CI family contains focused evidence.
- New guards are assigned to the correct test level.

## Patch Sequence

### Patch 19.0 — Opening Inventory and Phase 18 Residual Rebase

**Purpose**

Establish the exact Phase 19 input from the closed Phase 18 state without
changing behaviour.

**Steps**

- Add a semantic Phase 19 opening snapshot to the canonical registry.
- Preserve parent traceability to Phase 18 migrated and deferred rows.
- Inventory every host assumption reachable from brand resolution, type naming,
  container classification, and argument representation.
- Record CR-2 and D-1 as owned rows, with D-2 retained as historical opening
  evidence until its removal closure is recorded.
- Add `guard-cranelift-phase19-opening-contract`.

**Test Level**

Level 1.

**Exit Gate**

The opening snapshot exists, is registry-derived, and traces to Phase 18
closure. No behaviour changes.

### Patch 19.1 — Identifier-Spelling Decision Inventory

**Purpose**

Enumerate every decision currently made from a spelling, before changing any of
them. Report-only.

**Steps**

- Enumerate each site in the self-hosted compiler, classified as type-name
  erasure or classification override.
- For each, record what type information is available at that point and whether
  it is sufficient.
- Record the historical Rust/self-hosted divergence separately from the live
  self-hosted inventory.
- Count affected declarations and index sites in `compiler/*.gst` so the
  regression surface is a measured number, not an estimate.
- Add the `rename-invariance` Level 2 family and record its current failures as
  the phase's baseline.
- Add `guard-cranelift-phase19-spelling-inventory`.

**Test Level**

Level 1, with a Level 2 family.

**Exit Gate**

A generated inventory names every spelling-derived decision, states whether type
information suffices to replace it, and `rename-invariance` runs with its
current failures recorded as a baseline. No behaviour changes.

### Patch 19.2 — Compiler-Owned Brand Identity Authority

**Purpose**

Give the compiler one authoritative answer to "is this value an arena, and which
one?", derived from the resolved type.

**Steps**

- Add the brand identity record: brand origin, arena identity, arena-ness.
- Populate it during type resolution for every branded type.
- Require public API boundaries to carry explicit brands, per `VISION.md` §26.
- Compare the record against the existing spelling rule on the whole compiler
  source and enumerate every disagreement.
- Change no codegen yet.
- Add `guard-cranelift-phase19-brand-authority-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Every branded type has a brand identity record, and the disagreements between
the record and the spelling rule are enumerated with a reason for each. Behaviour
is unchanged.

### Patch 19.3 — Canonical Branded Type Naming Without a Brand Vocabulary

**Purpose**

Produce canonical branded type names from the brand identity record rather than
by stripping known brand words from a string.

**Steps**

- Replace suffix-stripping with construction from the record.
- Preserve the existing generated names exactly, or enumerate each change.
- Cover the namespaced forms the current code special-cases, such as
  `std_Vector_lib_module__ctx`.
- Require paired inferred and explicit programs to produce the same name.
- Add `guard-cranelift-phase19-type-naming-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Canonical branded type names are constructed from brand identity, not string
surgery, and generated C type names are byte-identical or every change is
enumerated.

### Patch 19.4 — Type-Derived Container and Arena Classification

**Purpose**

Make the type-derived classification correct enough that the spelling override
becomes redundant. This is the load-bearing patch of the phase.

**Steps**

- Establish that `is_slice`, `is_ptr`, `is_vector`, `is_hashmap`, `is_pool`, and
  arena-ness are decided from the resolved type and the struct registry.
- For every case where the override currently changes the answer, determine why
  the type-derived path was wrong and fix the type-derived path.
- Keep the override in place and assert it never fires — a guard that fails if
  the override would have changed a classification.
- Add `guard-cranelift-phase19-classification-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

The spelling override is provably redundant: across the compiler's own sources
and every fixture, it never changes a classification. It is still present, and
still asserted never to fire.

### Patch 19.5 — Argument and Index Representation From the Type System

**Purpose**

Make by-value versus by-address a recorded decision rather than a codegen-time
string edit.

**Steps**

- Source the decision from the Phase 16 ABI authority.
- Record it in canonical MIR.
- Forbid codegen from prepending an address-of to a source expression.
- Cover the failing case directly: a local `str` named `a` passed to a by-value
  `str` parameter must compile and behave identically to one named `b`.
- Add `guard-cranelift-phase19-representation-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Argument and index representation is carried in canonical MIR and consumed by
both backends. `rename-invariance` passes for every fixture in the family.

### Patch 19.6 — Self-Hosted Rule Convergence

**Purpose**

Eliminate disagreement among the self-hosted spelling consumers before removing
the rule.

**Steps**

- Make the self-hosted codegen and typechecker consumers identical, or prove the
  concept is unnecessary at every site.
- Add a guard comparing every consumer against a shared case table, including
  suffix, substring, `->ctx`, and `->a` forms.
- Add `guard-cranelift-phase19-rule-convergence`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Every live consumer classifies every case in the shared table identically.

### Patch 19.7 — Retired Prototype Absence Contract

**Purpose**

Make the one-compiler repository shape an enforced input to the remaining phase.

**Steps**

- Assert the removed root Rust package and its thirteen prototype compiler
  sources cannot return.
- Explicitly preserve `src/runtime.c`, `src/runtime/*.c`, `src/runtime/rust/`,
  and `compiler/experiments/cranelift/`.
- Require Phase 19 projections and documentation to cite only live compiler
  sources for current semantics.
- Add `guard-cranelift-phase19-retired-prototype-absent`.

**Test Level**

Level 1.

**Exit Gate**

The deprecated prototype cannot silently return, and the active runtime and
Cranelift Rust crates remain explicitly outside the removal boundary.

### Patch 19.8 — Name-List Removal From the Self-Hosted Compiler

**Purpose**

Delete the list from `compiler/*.gst`.

**Steps**

- Remove the list and its consumers, including the substring forms.
- Compile the compiler with the committed seed and require success — this is the
  bootstrap-safety gate.
- Require generated C for the compiler's own sources to be byte-identical to the
  pre-removal output, or enumerate each difference.
- Add `guard-cranelift-phase19-gust-name-list-removed`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

No spelling-derived decision remains in `compiler/*.gst`, the committed seed
still compiles the compiler, and generated C is unchanged or every change is
enumerated.

### Patch 19.9 — Seed Regeneration and Fixed-Point Convergence

**Purpose**

Move the corrected behaviour into the bootstrap seed, in its own commit, per the
Bootstrap seed rule in `AGENTS.md`.

**Steps**

- Run `make bootstrap` and require the three-stage fixed point.
- Commit `gust_v4.c` with no other change in the same commit.
- Record the diff size and confirm every change is explained by Patches 19.3
  through 19.8.
- Add `guard-cranelift-phase19-seed-convergence`.

**Test Level**

Level 1.

**Exit Gate**

`make bootstrap` reports fixed-point convergence, the seed is committed alone,
and its diff is accounted for.

### Patch 19.10 — Generated-C Equivalence Over the Compiler's Own Sources

**Purpose**

Prove the change is safe at the scale that matters: roughly 2,183 index sites in
the compiler itself.

**Steps**

- Compile every `compiler/*.gst` before and after and compare generated C.
- Enumerate every difference with the patch that caused it.
- Require zero unexplained differences.
- Hand this evidence to Cranelift Historical Full as the Level 3 owner.
- Add `guard-cranelift-phase19-self-compilation-differential`.

**Test Level**

Level 3, invoked by Historical Full.

**Exit Gate**

Generated C for the compiler's own sources has no unexplained difference, and
the evidence lives in the Level 3 suite.

### Patch 19.11 — Cross-Feature Composition and Complete Differential

**Purpose**

Prove brands, containers, resources, ABI, and targets still compose.

**Steps**

- Compose branded collections, arena clones, references, resources, and calls in
  one fixture.
- Compare MIR-to-C and explicit Cranelift.
- Confirm Phase 14–18 authorities are unaffected.
- Add `guard-cranelift-phase19-composition-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

The composition fixture behaves identically on both backends, or the Cranelift
half is explicitly deferred.

### Patch 19.12 — Phase 19 Closure

**Purpose**

Close brand identity and value representation.

**Steps**

- Confirm every Status row is `DONE` or explicitly deferred with an owner.
- Confirm no spelling-derived decision remains in the self-hosted compiler.
- Confirm `rename-invariance` passes for every family.
- Remove D-1 from `docs/SHARED_SEMANTIC_ZONE.md` and record the fix; preserve the
  earlier D-2 closure record.
- Mark CR-2 resolved in `TASK_STDLIB.md`, releasing S1.4, S1.5, and S1.6
  specifically from CR-2 while preserving any newer blockers.
- Record the residue.
- Add `guard-cranelift-phase19-close`.

**Test Level**

Level 1.

**Exit Gate**

The repository closure artifacts are complete, CR-2 is resolved, the Stdlib
patches are released specifically from CR-2, and the shared-zone defects are
removed rather than merely documented. Authoritative Historical Full run
**32586399260** passed on exact merged `main`
**a95e40d8f1cd4e6d31212e98105026d38b488c9b**, with **17/17** jobs completed
successfully; Phase 19 is closed.

## Phase 19 Recommended Implementation Order

Patch 19.0 opening inventory
→ 19.1 spelling inventory and the `rename-invariance` baseline
→ 19.2 brand identity authority
→ 19.3 canonical branded type naming
→ 19.4 type-derived classification
→ 19.5 argument and index representation
→ 19.6 self-hosted rule convergence
→ 19.7 retired-prototype absence contract
→ 19.8 self-hosted name-list removal
→ 19.9 seed regeneration
→ 19.10 self-compilation differential
→ 19.11 cross-feature composition
→ 19.12 closure.

19.4 is the load-bearing patch. If the type-derived classification cannot be made
correct without new lifetime or brand machinery, stop there and report — that is
a shared-zone escalation, not a licence to expand the phase.

## Phase 19 Success Criteria

Phase 19 succeeds when:

- Renaming a local variable cannot change generated code.
- Arena-ness follows from the resolved type, never from a spelling.
- Canonical branded type identity is produced once and reconstructed by neither
  backend.
- Container classification is type-derived with no override.
- Argument representation is a Phase 16 decision recorded in canonical MIR.
- The self-hosted type authority and both backends apply the same decided rule,
  and a guard proves it.
- The bootstrap seed reaches a three-stage fixed point under the new rules.
- Generated C for the compiler's own sources has no unexplained difference.
- MIR-to-C remains an independent differential oracle, and Cranelift has no
  fallback.
- CR-2 is resolved and `TASK_STDLIB.md` records S1.4, S1.5, and S1.6 as released
  from CR-2; their current CR-11, CR-12, and CR-13 blockers are preserved.
- D-1 is removed from the shared semantic zone; D-2 remains recorded as closed
  by prototype removal.
- Authoritative Historical Full run **32586399260** passes all **17/17** jobs on
  exact merged `main` **a95e40d8f1cd4e6d31212e98105026d38b488c9b**.

Phase 19 closure does not claim a general lifetime system, a brand algebra, or
any expansion of what brands can express. It claims only that the existing model
is decided by types instead of by names.

## Phase 19 Closure Record

- D-1 fix: identifier spelling is no longer semantic authority. Canonical
  branded identity, arena and container classification, and call argument
  representation follow compiler-owned type records. The defect row is removed
  from `docs/SHARED_SEMANTIC_ZONE.md`; the historical D-2 closure record remains.
- CR-2 release: the compiler prerequisite is resolved, and the Stdlib-owned
  roadmap records S1.4, S1.5, and S1.6 as released specifically from CR-2.
  S1.4 remains blocked by CR-11, S1.5 remains blocked by CR-12 and CR-13, and
  S1.6 has been delivered.
- Rename invariance is registered across brand identity, canonical type naming,
  type-derived classification, argument representation, and name-list removal.
  The broad brand-identity pair remains Level 3 evidence owned by Cranelift
  Historical Full.
- Residue: explicit Cranelift lowering of the generic-source composition fixture
  remains owned by `phase13_generic_source_to_mir`, deferred before driver
  discovery with reason
  `deferred_p13_parameter_argument_target_dependent_abi`. There is no C fallback.
- Phase 19 adds no lifetime syntax, brand algebra, MIR operation, ABI or layout
  meaning, runtime symbol, target policy, linker policy, or backend-specific
  semantics.
- The authoritative closure gate is satisfied: Historical Full run
  **32586399260**, event `workflow_dispatch`, completed `success` on exact merged
  `main` **a95e40d8f1cd4e6d31212e98105026d38b488c9b**, with **17/17** successful
  jobs. The matching terminal state is recorded in `GUST_LANE_STATE.md`.
