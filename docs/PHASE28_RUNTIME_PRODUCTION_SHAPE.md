# Phase 28 — Runtime Production Shape

**Status:** recorded future Cranelift work; inactive. Recording this phase does
not activate it or change the active Phase 24 opening-preflight Status.

**Lane and ownership:** Cranelift. Arena representation and brands, resource and
drop semantics, ABI representation, native runtime ABI and symbol identity, and
the mutex/synchronization runtime contract are Cranelift-owned shared-zone
authority under `docs/SHARED_SEMANTIC_ZONE.md`. The Stdlib lane owns safe API
ergonomics after a checked compiler/runtime handoff. A new or changed `std_*`
symbol, public failure form, resource lifetime, drop rule, or ABI therefore
requires the applicable shared-zone authority before implementation; this phase
does not preselect any of those decisions.

**Placement and dependency:** Phase 28 follows the existing post-Phase-27
technical-launch checkpoint recorded in `docs/ROADMAP_TAIL.md`. That Level-3
compiler launch explicitly does not claim production readiness, and this future
record neither delays nor authorizes it. Phase 28 begins only after Phase 24
opening preflight, Phase 24 backend retirement, Phase 24.5, Phase 25, Phase 26,
and Phase 27 close on merged `main`. The active Phase 24 order remains
24.2f → 24.2g → 24.2h → Stdlib S1.9–S1.12 → 24.3 → 24.3a → 24.4. This future
record neither bypasses that order nor authorizes Stdlib S1.9–S1.12, Phase 24
backend retirement, or any later phase. Phase 28 must re-derive the then-current
runtime after Phase 25 because residual C components may have been rewritten or
separately packaged, and it consumes the generalized resource/drop authority
settled by Phase 26 rather than inventing a mutex- or channel-specific lifetime.
It also depends on the separately routed structured-runtime work in issue #101
and the subsequent containment correction in issue #91. It neither absorbs nor
reorders those issue scopes; if either remains open after Phase 27, Phase 28
waits for its authority before opening.

## Verified Current Production-Shape Gaps

Verified directly against the live source at `origin/main`
`6e5aaa671b705c71866cc30d719c70d5cd316b59` on 2026-09-04. Line citations are
exact at that commit; Patch 28.0 re-derives them rather than trusting them
after the tree moves. Where this record and the source disagree, the source
wins:

- `os_Arena_New` sets `Capacity` to `4294967296ULL`, passes that size to a
  single `malloc`, and `os_ArenaAlloc` advances one bump offset
  (`src/runtime/arena.c:30`, `src/runtime/arena.c:31`, `src/runtime/arena.c:57`,
  `src/runtime/arena.c:79`, `src/runtime/arena.c:91`). This requests one
  contiguous 4 GiB allocation. On systems with lazy page backing or memory
  overcommit, a successful call may reserve virtual address space without 4 GiB
  of immediate resident commitment; the repository currently neither measures
  nor guarantees the resident-memory consequence.
- Arena references retain the historical 32-bit offset ABI. Both `os_ArenaAlloc`
  return paths narrow an offset through `uint32_t` (`src/runtime/arena.c:80`,
  `src/runtime/arena.c:92`), and `GUST_ARENA_OFFSET` zero-extends that bit
  pattern before pointer arithmetic (`src/runtime/core_headers.h:37`). The
  arena's 4 GiB capacity and its reference representation therefore cannot be
  changed independently without an explicit compatibility decision.
- The cooperative runtime stores mutexes in a static 1,024-entry array and
  channels in a static 256-entry array (`src/runtime/fiber.c:473`,
  `src/runtime/fiber.c:474`, `src/runtime/fiber.c:561`,
  `src/runtime/fiber.c:576`). `gust_mutex_count` and `gust_channel_count` only
  increase (`src/runtime/fiber.c:484`, `src/runtime/fiber.c:586`); no runtime
  path returns either slot to a reusable pool.
- Every channel allocation separately allocates its payload ring with `malloc`
  (`src/runtime/fiber.c:591`). No channel destruction path frees that buffer or
  destroys its internal `pthread_mutex_t`; the runtime's only
  `pthread_mutex_destroy` tears down scheduler shards
  (`src/runtime/fiber.c:450`), not pool entries. The mutex pool likewise has no
  per-slot destruction path.
- Exhausting either static pool prints a message and calls `exit(1)`
  (`src/runtime/fiber.c:481`, `src/runtime/fiber.c:482`,
  `src/runtime/fiber.c:583`, `src/runtime/fiber.c:584`), while arena capacity
  exhaustion calls `abort()` and scratch exhaustion calls `exit(1)`
  (`src/runtime/arena.c:84`, `src/runtime/scratch.c:34`). The Phase 17
  thread-runtime authority still records both pool allocation helpers as
  `failure_form: returns_explicit_error`
  (`scripts/cranelift_feature_registry.json:12395`,
  `scripts/cranelift_feature_registry.json:12398`), so the source behaviour and
  the recorded failure form must be reconciled before choosing a replacement.
- The default packaged runtime is compiled with `-O2 -Wall -pthread` and does
  not define `GUST_DEBUG` (`scripts/phase22_explicit_c_migration.sh:58`,
  `scripts/phase21_native_rebuild_reproducibility.py:174`); `-DGUST_DEBUG` is
  added only by the sanitizer guard suite
  (`scripts/phase21_complete_guard_suite.py:432`). Arena allocation metadata,
  pre/post canaries, `os_Arena_Validate`, and scratch-reset poisoning are
  therefore debug-only (`src/runtime/arena.c:6`, `src/runtime/arena.c:60`,
  `src/runtime/scratch.c:42`). Capacity bounds are not debug-only: arena and
  scratch allocation retain their bounds checks in the default build
  (`src/runtime/arena.c:82`, `src/runtime/scratch.c:32`). Phase 28 must not
  describe release validation as wholly absent.

These are production-shape limitations, not authorization to change Gust
meaning. In particular, this record does not choose a smaller or growable arena,
an operating-system reservation primitive, a wider or segmented reference, a
generation-bearing pool handle, a destructor spelling, or a `Result`, trap,
panic, or process-exit failure contract.

## Purpose

Make the runtime suitable for bounded, long-lived native processes by replacing
unmeasured fixed-capacity assumptions with explicit capacity contracts,
reclaiming synchronization resources and their owned storage, making ordinary
resource exhaustion follow an approved and testable failure contract, and
preserving a defined integrity floor in the default packaged build. The result
must remain generic, bootstrap-safe, target-qualified, and consistent with the
then-current native runtime package and canonical resource/ABI authority.

## Required Decision Checkpoints

| Decision | Authority required before implementation | This record leaves open |
| --- | --- | --- |
| Arena capacity and reservation | Cranelift arena/layout and target-runtime authority | fixed, configurable, segmented, or growable capacity; allocation or virtual-reservation mechanism; commit policy and supported-host behaviour |
| Arena reference representation | Cranelift ABI and arena-brand authority | preserve/version/replace the historical 32-bit offset; compatibility and migration boundary |
| Mutex/channel lifetime | Phase 26 generalized resource/drop authority plus Cranelift synchronization-runtime authority; checked Stdlib handoff for any safe API | owning scope, exact destruction point, waiter handling, stale-handle rejection, and whether generations are required |
| Exhaustion and allocation failure | Existing language error authority plus Phase 17 runtime ABI authority | explicit error, trap/panic, or another approved form; which failures are recoverable; diagnostic and cleanup obligations |
| Default-build integrity floor | Cranelift runtime/package and target authority | which canaries, poisoning, metadata, or cheaper integrity checks remain enabled; their performance budget and failure form |

If the then-current authority does not already decide one of these questions,
the owning patch records the decision requirement and stops before changing
semantics or ABI. A technical implementation choice that satisfies all existing
constraints records its rationale and falsifier; it is not silently promoted to
a language rule.

## Ordered Future Patch Boundaries

| Patch | Atomic boundary | Exit gate |
| --- | --- | --- |
| 28.0 — Opening inventory and authority re-derivation | Re-audit the post-Phase-27 runtime package, source language, runtime symbols, ABI/version, target support, Phase 17 failure records, allocation sites, destruction paths, current limits, default/debug build flags, and applicable issue rows. Establish measurement baselines for virtual address reservation, resident memory, steady-state allocation, and long-lived synchronization churn. Make no semantic or ABI change. | One generated or mechanically checked inventory names every arena/mutex/channel allocation and release owner, reconciles source against registry evidence, identifies every unresolved decision above, and proves the phase can open without stale Phase 24–27 assumptions. |
| 28.1 — Arena capacity and reference decision authority | Measure representative supported hosts and select or escalate the capacity/reservation and historical 32-bit-offset contract. Specify overflow, alignment, zero-extension, configuration, compatibility/versioning, allocation-failure, and target behaviour. Do not implement a new representation in the authority patch. | The approved contract has a named owner, rationale, falsifier, migration/compatibility rule, resident-versus-virtual evidence, and exact implementation boundary; unresolved ABI or language choices remain explicit stop conditions. |
| 28.2 — Arena capacity and representation implementation | Implement only the Patch 28.1 contract across the runtime, canonical ABI metadata, native lowering/package surface, and supported targets. Do not change mutex/channel lifecycle or general failure semantics. Any seed regeneration remains isolated under `AGENTS.md`. | Boundary tests cover zero, alignment, near-capacity, `INT_MAX`, `UINT32_MAX`, overflow and allocation failure as applicable; target/package evidence proves the selected reservation and commitment contract; canonical and runtime ABI versions agree; no fallback exists. |
| 28.3 — Mutex/channel lifecycle and reclamation | Using Phase 26's generic resource/drop rules and issue #101's structured-runtime authority, add exactly-once teardown and reusable storage for mutex/channel runtime state, including channel payload buffers and internal synchronization objects. Define behaviour for live waiters, in-flight send/receive, stale handles, scheduler shutdown, partial construction, and repeated teardown before implementation. Do not special-case a stdlib type in backend lowering. | A bounded-live-set stress witness performs more than 1,024 mutex and 256 channel create/destroy cycles without exhausting cumulative counters; concurrent positive and misuse cases prove no reuse-before-destroy, stale-handle access, waiter loss, double destruction, buffer leak, or target/package-specific semantic exception. |
| 28.4 — Exhaustion and allocation-failure decision authority | Using issue #91's process-containment authority, reconcile the Phase 17 `returns_explicit_error` records with current `exit(1)`/`abort()` behaviour and decide the public/canonical failure forms for arena reservation, arena capacity, mutex/channel slots, channel payload allocation, and integrity failure. This patch changes no runtime behaviour. | Every failure site is classified as recoverable or fatal with cleanup, diagnostic, ABI, source-surface, and Stdlib-handoff consequences. Any new language error semantics, runtime symbol, MIR meaning, or ABI remains blocked until separately approved. |
| 28.5 — Exhaustion and error-path implementation | Implement only the approved Patch 28.4 contracts, after reclamation exists, so routine capacity pressure is not confused with permanently leaked slots. Preserve Phase 9G artifact ownership and explicit Cranelift no-fallback behaviour. | Deterministic fault injection covers each allocation and exhaustion site; observed exit/error/trap, diagnostic, unwinding or cleanup, and artifact preservation exactly match authority, with no undocumented process termination or null dereference. |
| 28.6 — Default-build integrity hardening | Establish the approved default-build integrity floor independently of optional `GUST_DEBUG` diagnostics. Keep capacity checks explicit in all configurations; qualify any retained canary, poison, metadata, handle-validation, or lower-cost alternative against a recorded performance and memory budget. | Default-package and debug-package tests separately prove which checks run, corrupt metadata/handles fail in the approved form, capacity bounds remain active, release flags cannot silently remove the declared floor, and overhead stays within the recorded budget. |
| 28.7 — Long-lived qualification and closure | Compose the arena, reclamation, exhaustion, scheduler, and integrity changes in long-lived and concurrent native workloads across the supported target/package matrix. Update user/runtime documentation and authority generated by the implementation patches; do not resurrect a retired backend as an oracle. | Exact merged-main stress evidence shows bounded live resources do not grow from cumulative creation, channel buffers and runtime slots return to their owner, virtual and resident memory observations match the declared contract, all required exact-head checks and reviews close, and `Cranelift Historical Full` succeeds with its complete registry-derived population before Phase 28 closure. |

## Phase 28 Success Criteria

Phase 28 succeeds when:

- the then-current arena capacity, reservation/commitment behaviour, reference
  representation, ABI version and supported-target constraints are explicit and
  mechanically checked;
- documentation and evidence distinguish requested virtual address space from
  measured or guaranteed resident commitment;
- mutex and channel storage is governed by an approved lifecycle, and bounded
  live use can exceed the old cumulative 1,024/256 creation counts without
  exhaustion or stale reuse;
- channel payload storage and internal synchronization objects are reclaimed
  exactly once on every approved normal, failure and shutdown path;
- every allocation, capacity and integrity failure matches the approved public
  and runtime contract, and source, registry, generated witness, package and
  documentation authority agree;
- the default build retains capacity bounds and the separately declared
  integrity floor, while debug-only checks and their additional cost remain
  accurately documented;
- deterministic fault injection, sanitizer or equivalent memory evidence where
  applicable, long-lived concurrency stress, supported-target/package tests,
  bootstrap convergence, no-fallback checks and `git diff --check` pass;
- implementation remains atomic by the boundaries above, generated bootstrap
  changes remain isolated, and no backend-specific stdlib meaning or individual
  stdlib-type lowering is introduced; and
- the exact final implementation on merged `main` has a complete successful
  `Cranelift Historical Full` run, resolved review conversations, a generated
  closure record, and no unresolved production-shape decision hidden as an
  implementation detail.

Phase 28 may claim only the measured capacity, lifecycle, failure, and integrity
contracts it proves. It does not by itself establish application-level
availability, graceful drain, sandbox containment, universal target support, or
general “production ready” status.
