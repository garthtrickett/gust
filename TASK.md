# Phase 15 — Resource and Lifetime Semantics

## Status

- [x] Patch 15.0 — Opening Inventory and Phase 14 Residual Rebase — DONE
- [x] Patch 15.1 — Compiler-Owned Resource and Lifetime Authority — DONE
- [x] Patch 15.2 — Resource Values in Canonical MIR — DONE
- [x] Patch 15.3 — Move-State Transitions and Use-After-Move Enforcement — DONE
- [x] Patch 15.4 — Resource Reassignment Semantics — DONE
- [x] Patch 15.5 — Cleanup Insertion at Normal Scope Exits — DONE
- [x] Patch 15.6 — Cleanup at Early Returns and Structured Exits — DONE
- [x] Patch 15.7 — Destructor Scheduling and Exactly-Once Destruction — DONE
- [x] Patch 15.8 — Manual Close Versus Deferred Cleanup — DONE
- [ ] Patch 15.9 — Conditional and Loop-Carried Resource States — IN PROGRESS
- [ ] Patch 15.10 — Resource Metadata and Request Validation
- [ ] Patch 15.11 — Directory and Selected Specialized Resource Kinds
- [ ] Patch 15.12 — Panic and Failure Cleanup Policy
- [ ] Patch 15.13 — Cross-Feature Resource Composition and Complete Differential
- [ ] Patch 15.14 — Deferred Residue and Resource-Coverage Audit
- [ ] Patch 15.15 — Phase 15 Closure

---

## Purpose

Phase 15 preserves Gust's ownership, move, cleanup, and resource rules without relying on generated C structure or backend-specific reconstruction.

The phase covers the declared inventory for:
- resource values in canonical MIR;
- move-state transitions;
- use-after-move enforcement;
- resource reassignment semantics;
- cleanup insertion at normal scope exits;
- cleanup insertion at early returns;
- destructor scheduling;
- manual close versus deferred cleanup;
- conditional and loop-carried resource states;
- resource metadata validation;
- directory and other explicitly selected resource kinds;
- panic or failure cleanup policy where the current runtime model provides a stable authority;
- prevention of duplicated, skipped, or reordered destruction.

The compiler must own resource meaning. Canonical MIR must contain the operations, state transitions, cleanup obligations, and metadata required for faithful lowering. MIR-to-C and Cranelift must consume the same compiler-produced resource and cleanup decisions.

Phase 15 closes only the declared resource and lifetime inventory. It does not claim complete borrow checking, complete alias safety, complete exception safety, complete concurrency safety, complete runtime support, complete ABI support, or production readiness.

### Starting State

The expected starting state is:
- Phase 14 is closed with status: `phase14_closed_type_layout_and_memory_model`.
- The canonical feature registry remains the only active feature-state authority.
- The Phase 14 semantic closure snapshot remains immutable.
- The Phase 14 deferred residue snapshot contains concrete, explicitly owned future capabilities.
- MIR-to-C remains the default backend and differential oracle.
- Explicit Cranelift selection has no fallback.
- The compiler owns source interpretation, canonical MIR production, type layout, target layout, and memory-access validation.
- The worker receives only request data, canonical MIR, compiler-produced layout data, and compiler-produced resource metadata.
- Phase 9G owns object handling, linking, cleanup of owned temporary artifacts, and atomic publication.
- Registry-derived CI families own focused differential evidence.
- Cranelift Historical Full remains the sole Level 3 historical owner.
- Phase 15 must consume those contracts rather than recreate them.

### Phase Boundary

Phase 15 may implement:
- compiler-owned resource identity;
- resource-bearing local values;
- explicit move operations;
- move-state transitions;
- use-after-move validation;
- exactly-once destruction obligations;
- resource reassignment with explicit replacement cleanup;
- cleanup insertion at ordinary scope exits;
- cleanup insertion on early return;
- destructor scheduling;
- explicit manual close;
- interaction between manual close and deferred cleanup;
- conditional resource-state joins;
- selected loop-carried resource states;
- resource metadata validation;
- directory resources and other explicitly selected resource kinds;
- selected failure cleanup where a stable runtime contract already exists;
- resource-state witnesses and diagnostics.

Phase 15 must not silently absorb:
- aggregate parameter ABI;
- aggregate return ABI;
- hidden return pointers;
- general calling-convention classification;
- cross-module ABI expansion;
- variadic calls;
- indirect calls or general function values;
- closures;
- general borrow checking;
- unrestricted alias analysis;
- arbitrary shared ownership;
- reference counting unless separately selected;
- garbage collection;
- heap-allocation policy unless an existing runtime authority is explicitly selected;
- atomics or concurrency semantics;
- thread cancellation;
- asynchronous unwinding;
- foreign exception interoperability;
- complete panic unwinding;
- complete platform ABI classification;
- runtime package retirement;
- linker or publication ownership;
- full Gust language parity.

Out-of-scope Phase 14 residual rows must remain deferred, be reassigned to a later phase, or be split into narrower rows. They must not be marked migrated merely because Phase 15 introduces resource state.

### Compiler-Owned Resource and Lifetime Authority

Phase 15 must establish one compiler-owned resource and lifetime service with semantic records equivalent to the following concepts.

**Resource Identity:** Every resource-bearing value has a compiler-produced identity containing: stable resource ID; resource type identity; source declaration identity; source location; owning function; owning scope; resource kind; destructor identity; close capability where applicable; copy policy; move policy; cleanup policy; target applicability; layout identity where memory-representable.

**Resource State:** Every resource identity has an explicit semantic state equivalent to a bounded set such as: uninitialized; live; moved; manually closed; cleanup scheduled; destroyed. The implementation may use different internal names, but the state transitions must be explicit, validated, deterministic, and compiler-owned. No backend may infer resource state from source text, variable names, generated C structure, stack-slot lifetime, or emitted control-flow shape.

**Resource Transition:** Every resource transition record contains: resource ID; prior state; operation; resulting state; source location; control-flow edge; cleanup obligation; diagnostic reason code on rejection. Selected operations include: initialize; move; use; assign replacement; schedule cleanup; cancel redundant cleanup after manual close; invoke destructor; mark destroyed; join states at a control-flow merge.

**Cleanup Obligation:** Every cleanup obligation contains: resource ID; destructor identity; cleanup reason; insertion scope; execution order; source location; target block or cleanup edge; exactly-once policy; interaction with manual close; interaction with move; interaction with early return; interaction with selected failure paths.

**Resource Join:** Every conditional or loop join records: incoming resource IDs; incoming states; resulting state; whether all paths agree; whether a cleanup obligation remains live; whether the join is valid; stable diagnostic ownership for invalid joins.

**Request and MIR Ownership:** Canonical MIR must refer to compiler-owned resource identities and cleanup obligations. The native request must carry an immutable, deduplicated resource table or equivalent compiler-produced representation containing only the resource and cleanup data required by the worker. The consumers must behave as follows: MIR-to-C emits moves, cleanup blocks, destructor calls, and close suppression from compiler-produced MIR and resource metadata. Cranelift lowers the same operations and cleanup plan. Neither backend may independently decide when a destructor is needed. Neither backend may independently decide whether a value is live, moved, closed, scheduled, or destroyed. Runtime-facing operations consume compiler-emitted destructor identities, close operations, or descriptors. Diagnostics query the compiler resource service and report the same state transition that code generation consumes. Generated views derive active rows, resource kinds, totals, families, and dispositions from structured authorities. No raw registry hash, MIR hash, generated-C hash, Markdown hash, or emitted-cleanup hash becomes a semantic contract.

### Architectural Invariants

Every Phase 15 patch must preserve:
- MIR-to-C as the default backend and differential oracle;
- explicit Cranelift selection with no fallback;
- generic source-to-canonical-MIR routing;
- no exact-source, filename, fixture-name, literal, or cleanup-output recognizer;
- compiler-owned source interpretation;
- compiler-owned type and target layout authority from Phase 14;
- one compiler-owned resource and lifetime authority;
- no backend-local move-state table;
- no backend-local cleanup planner;
- worker input limited to request data, canonical MIR, compiler-produced layout data, and compiler-produced resource data;
- capability and deferral decisions before driver or artifact access;
- Phase 9G ownership of object handling, linking, temporary cleanup, and atomic publication;
- preservation of an existing output on deferral or failure;
- deterministic registry and generated projections;
- registry-derived CI families;
- separate Level 1, Level 2, and Level 3 ownership;
- no exact CI matrix total treated as backend correctness;
- no claim that Phase 15 completes general borrowing, ABI, runtime, or production support.

### Verification Policy

**Level 1 — Fast Contracts:** Level 1 guards may validate Phase 14 semantic closure availability; Phase 15 opening and parent traceability; canonical registry schema and semantic state; compiler-owned resource and cleanup APIs; resource-state transition tables; cleanup insertion ownership; destructor identity ownership; generated projection freshness; resource metadata uniqueness; no backend-local cleanup planner; no fallback; worker isolation; early deferral; output preservation; manifest and route architecture; CI-family projection; test-level and workflow ownership; residue and closure summaries. Level 1 guards must not replay all resource programs, all cleanup paths, every target runner, or the full historical suite.

**Level 2 — Focused Differential Families:** Level 2 evidence validates bounded migrated behavior on the primary PR host through registry-derived families. A proposed initial family vocabulary is: resource-values; move-state; reassignment-cleanup; scope-exit-cleanup; early-return-cleanup; manual-close; resource-cfg; specialized-resources; failure-cleanup. The active family set and count must be derived from the canonical registry. The workflow must not hard-code one matrix row per patch. For each applicable case, Level 2 should compare: default MIR-to-C; explicit MIR-to-C; explicit Cranelift; runtime values; stdout and stderr where declared stable; exit status; destructor and close call counts; destructor and close ordering; selected filesystem effects; resource-state witnesses; cleanup-edge witnesses; stable diagnostics; preservation of sentinel outputs on failure. Default and explicit MIR-to-C output should remain byte-identical for the same target and source where the existing differential contract requires it.

**Level 3 — Historical and Complete Resource Evidence:** Cranelift Historical Full remains the sole Level 3 owner. It owns: complete Phase 9–15 historical replay; the complete registry-derived Phase 15 differential inventory; representative resource programs across every declared target where the selected resource and runtime contract is applicable; platform-specific resource evidence where behavior differs; all historical resource fixtures; complete object, link, cleanup, and publication failure matrices owned by Phase 9G; packaging and reproducibility evidence; long cleanup chains and representative nested resource programs. Phase 15 opening and closure guards validate that the Level 3 suite remains available, registry-derived, and separately runnable. They do not execute it.

### Standard Definition of Done for Every Phase 15 Capability Patch

A Phase 15 capability is migrated only when all of the following are true: The supported source shape is precisely bounded. The supported canonical-MIR shape is precisely bounded. The owning canonical registry row is identified. The owning target set is explicit or derived. A real source fixture lowers through the generic producer. A compiler-owned canonical-MIR fixture exists where applicable. The compiler resource service returns the required resource identity, transition, and cleanup records. The compiler layout service returns the required layout records for memory-representable resources. MIR-to-C consumes the compiler-produced resource and cleanup decisions. Cranelift consumes the same decisions. Runtime-facing code consumes compiler-produced destructor identities or descriptors. Diagnostics report the same transition decision used by code generation. No consumer independently guesses move state, cleanup need, destructor identity, close suppression, or cleanup order. Default and explicit MIR-to-C remain equivalent. MIR-to-C and Cranelift native behavior are compared. Resource-state and cleanup witnesses are compared where observable. Destructor and close counts are deterministic for the selected inventory. Duplicate or skipped destruction is rejected. Malformed cases have stable diagnostics. Unsupported cases remain explicitly deferred. Deferred and invalid cases stop before: native-driver discovery; request publication; temporary object creation; linker access; output replacement. Existing output survives deferral and failure. The worker still receives only request data, canonical MIR, compiler-produced layout data, and compiler-produced resource metadata. The registry row is updated using the existing status vocabulary. Generated projections are refreshed. The owning CI family contains focused evidence. At least one appropriate composition relationship exists. No exact-source or exact-cleanup-output recognizer was introduced. Explicit Cranelift still cannot fall back to MIR-to-C. The new guards are assigned to the correct test level.

---

## Patch Sequence

### Patch 15.0 — Opening Inventory and Phase 14 Residual Rebase — DONE
Purpose: Establish the exact Phase 15 input from the closed Phase 14 state without changing compiler, backend, runtime, or artifact behavior. Steps: Add semantic Phase 15 opening snapshot to canonical registry. Preserve parent traceability to Phase 14 migrated rows, residual IDs, planning categories. Split broad residuals. Keep out-of-scope rows deferred. Add stable rows for resource values, move-state, reassignment, scope-exit, early-return, destructor scheduling, manual close, conditional/loop-carried state, metadata validation, directory resources, failure cleanup, differential evidence. Each row: stable ID, parent, family, CI family, owner, diagnostic owner, target applicability, status, failure stage, fixture pair. Freeze CI-family projection. Generate opening review view. Guard: `guard-cranelift-phase15-opening-contract` (Level 1). Exit: Every declared row has parent, owner, target, fixture pair, disposition.

### Patch 15.1 — Compiler-Owned Resource and Lifetime Authority — DONE
Purpose: Create single resource-state and cleanup-decision path. Steps: Add types: resource identity, state, transition, cleanup obligation, destructor identity, close capability, resource-state join. Add queries: `resource_of(value)`, `resource_state_at(value, point)`, `validate_resource_transition`, `cleanup_obligations(scope_exit)`, `destructor_for`, `join_resource_states`. Deterministic IDs, transport via resource table in native request, deserialization rejects unknown/inconsistent metadata. Guard: `guard-cranelift-phase15-resource-authority-contract` (Level 1). Exit: Later patches extend authority without backend ownership.

### Patch 15.2 — Resource Values in Canonical MIR — DONE
Purpose: Represent resource-bearing values explicitly in canonical MIR. Steps: Freeze inventory, add MIR forms: declaration, initialization, read, move, explicit close, cleanup scheduling, destructor invocation, destroyed marker. Require resource ID, type, layout, scope, location, state, policy. Preserve identity through assignment, slots, branches, loops, aggregates. Reject missing/inconsistent metadata. Guards: resource-MIR contract (L1) + parity (L2). Exit: One compiler-owned identity consumed equivalently by MIR-to-C and Cranelift.

### Patch 15.3 — Move-State Transitions and Use-After-Move Enforcement — DONE
Purpose: Define explicit move semantics and reject invalid use. Steps: Freeze move forms (local→local, aggregate field, branch edge, loop-carried). Define transitions: live→moved, moved→reinitialized, live→closed, closed→destroyed, etc. Reject use-after-move, close-after-move, second move, etc. before driver discovery. Guards: `guard-cranelift-phase15-move-state-contract/parity`. Exit: Every selected move has one compiler-owned transition, use-after-move rejected consistently.

### Patch 15.4 — Resource Reassignment Semantics — DONE
Purpose: Define replacement without leaking/duplicating. Steps: Freeze reassignment forms (live local, moved→reinit, aggregate field, conditional). MIR identifies old/new IDs, cleanup obligation, order. Reject missing resolution, duplicate cleanup, immutable storage, layout mismatch. Guards: reassignment contract/parity. Exit: Replaced value destroyed/transferred exactly once.

### Patch 15.5 — Cleanup Insertion at Normal Scope Exits — DONE
Purpose: Insert compiler-owned cleanup at ordinary lexical scope exits. Steps: Scope identities, compute obligations from live state, insert at block/function/nested scope ends, reverse declaration order, witnesses. Guards: scope-exit contract/parity. Exit: Every live resource has exactly one deterministic cleanup via both backends.

### Patch 15.6 — Cleanup at Early Returns and Structured Exits — DONE
Purpose: Preserve cleanup when control leaves scopes early. Steps: Inventory direct return, nested conditional return, loop body return, selected break/continue. Compute exited scope chain, insert inner-before-outer cleanup, preserve moved/closed/return evaluation. Guards: early-return contract/parity. Exit: Early exits execute exactly exited scope obligations.

### Patch 15.7 — Destructor Scheduling and Exactly-Once Destruction — DONE
Purpose: Freeze scheduling preventing duplicated/skipped destruction. Steps: Define destructor identity, scheduling points, MIR ops: schedule, cancel, execute, mark destroyed. Require one resource/destructor/reason/point. Reject two schedules, skipped, drift. Guards: destructor-scheduling contract/parity. Exit: One schedule and one execution, no duplicate/skipped.

### Patch 15.8 — Manual Close Versus Deferred Cleanup — DONE
Purpose: Define how explicit close interacts with deferred cleanup. Steps: Freeze close-capable kinds, close suppresses destructor, transitions to closed, rejects double close/close-after-move/use-after-close. Cleanup does not double-close. Guards: manual-close contract/parity. Exit: One state machine prevents duplicate close/destruction.

### Patch 15.9 — Conditional and Loop-Carried Resource States — IN PROGRESS
Purpose: Allow selected resource states to cross branches, joins, and supported loops without backend-specific state reconstruction. Steps: Freeze supported joins (valid: live/live, moved/moved, closed/closed, reinitialized/reinitialized; invalid: live/moved, live/closed, destroyed/live, incompatible identities). Add canonical MIR block parameters / join records. Define loop-carried policies: live across iterations, move exactly once before exit, replace each iteration with prior cleanup, closed on all exiting paths. Reject path-dependent liveness without policy, cleanup mismatch, backedge mismatch, use-after-conditionally-moved, destructor disagreement. Add positives/negatives for nested branches/loops, compare witnesses after joins/exits. Guards: `guard-cranelift-phase15-resource-cfg-contract` (L1) and `guard-cranelift-phase15-resource-cfg-parity` (L2). Boundary: Irreducible CFG, exception edges, unrestricted merging deferred. Exit: Selected states cross branches/loops through one compiler-owned join policy with equivalent cleanup via MIR-to-C and Cranelift.

### Patch 15.10 — Resource Metadata and Request Validation
Purpose: Make resource metadata a validated compiler-produced request contract. Steps: Freeze schema, require identity/kind/declaration/location/scope/type/layout/state/destructor/close/cleanup/join records, deterministic ordering. Reject malformed requests before worker execution. Guard: `guard-cranelift-phase15-resource-metadata-contract` (L1). Exit: Worker receives validated contract, malformed stops before driver.

### Patch 15.11 — Directory and Selected Specialized Resource Kinds
Purpose: Migrate directory and other selected specialized kinds through generic authority. Scope-Selection Rule: Freeze inventory per kind (constructor, identity, destructor/close, move/copy/close policy, cleanup effects, runtime symbol, target). Steps: Registry rows per kind, map onto generic state, no specialized backend state machine. Guards: specialized-resource contract/parity. Exit: Every selected kind uses generic path equivalently.

### Patch 15.12 — Panic and Failure Cleanup Policy
Purpose: Define bounded cleanup for selected failure paths. Scope-Selection Rule: Freeze in-scope failure forms (trap before exec, runtime failure return, selected panic with stable authority, native op failure edge); async unwind/foreign/cancellation deferred. Steps: Define cleanup policy per form, represent in MIR, preserve order/exactly-once. Guards: failure-cleanup contract/parity. Exit: Every selected failure form has explicit policy lowered equivalently.

### Patch 15.13 — Cross-Feature Resource Composition and Complete Differential
Purpose: Prove migrated capabilities compose and agree through both backends. Steps: Generate differential inventory from registry, no hand-written lists. Add composed programs (init, moves, reassignment, scope/early-return cleanup, destructor scheduling, manual close, joins, loop-carried, directory, failure). Run default MIR-to-C, explicit MIR-to-C, explicit Cranelift and compare values, witnesses, counts, order, effects. Guards: composition contract (L1), focused differential (L2), complete evidence (L3). Exit: Every migrated row has individual and composed evidence with equivalent effects.

### Patch 15.14 — Deferred Residue and Resource-Coverage Audit
Purpose: Eliminate broad/ambiguous deferrals. Steps: Audit every opening row → migrated/excluded/replaced by narrower deferred rows. Reject broad residues, require stable ID, owner, reason, destination phase, prerequisite, failure stage, applicability, fixtures, diagnostic code. Guard: `guard-cranelift-phase15-deferred-residue-audit` (L1). Exit: Every item migrated or narrower actionable deferral, coverage explicit.

### Patch 15.15 — Phase 15 Closure
Purpose: Close only declared Phase 15 inventory. Closure guard `guard-cranelift-phase15-close` (L1) requires semantic Phase 14 closure, opening contract, registry schema, projections, authority contracts, all Phase 15 contracts, residue audit, route/manifest architecture, three-level mapping, Level 3 suite, Phase 14 layout, Phase 9G ownership, default oracle, no-fallback, isolation, deferral, preservation. Must not replay full families/historical suite. Suggested status `phase15_closed_resource_and_lifetime_semantics`. Exit: Every declared row migrated/excluded/replaced via generic route with equivalent state/cleanup/diagnostics via both backends.

## Phase 15 Success Criteria

Phase 15 succeeds when:
- Phase 14 closure remains semantically intact.
- One canonical registry owns active feature state.
- One compiler-owned resource service owns ownership, move, cleanup, and destruction decisions.
- All generated views, active families, targets, resource kinds, and totals come from structured authorities.
- Canonical MIR refers to compiler-owned resource identities and cleanup obligations.
- Native requests carry compiler-produced resource data.
- MIR-to-C does not independently select resource state or cleanup.
- Cranelift does not independently select resource state or cleanup.
- Runtime-facing resource operations use compiler-produced identities or descriptors.
- Diagnostics report the same transitions used by code generation.
- Selected resource values are explicit in canonical MIR.
- Selected move-state transitions are explicit and backend-independent.
- Use after move is rejected before worker and artifact access.
- Reassignment resolves the old live resource exactly once.
- Normal scope exits run compiler-owned cleanup.
- Early returns run the cleanup obligations of exited scopes.
- Destructor scheduling is explicit and exactly once.
- Manual close suppresses duplicate deferred cleanup.
- Selected resource states cross supported branches and loops.
- Resource metadata is validated before worker execution.
- Directory and selected specialized resources use the generic resource path.
- Selected failure cleanup is explicit and bounded.
- No exact-source or cleanup-output recognizer exists.
- No explicit Cranelift fallback exists.
- Deferred input stops before driver and artifact access.
- Existing output is preserved on failure and deferral.
- Phase 9G retains artifact ownership.
- MIR-to-C remains the default oracle.
- Registry-derived Level 2 families own focused differential evidence.
- Cranelift Historical Full remains the sole Level 3 owner.
- Representative resource programs agree through both backends.
- Every residual deferral is narrow, actionable, target-scoped where necessary, and assigned to a later phase.
- Phase 15 closure does not claim complete borrowing, ABI, runtime, exception, concurrency, or production parity.
