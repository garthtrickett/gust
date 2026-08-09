# Phase 16 — Function ABI and Aggregate Call Semantics

## Workflow Policy

Flow: start one patch → run the related `just`/`make`/`cargo`/`scripts/*` checks locally → once local checks pass, publish through a `codex/**` branch and pull request to trigger GitHub runners. If a GitHub runner fails, cancel superseded runs on that branch, reproduce the first failing guard locally from the smallest useful log excerpt, fix it, rerun the focused local guard, push, and monitor the new `HEAD` until green. Do not poll GitHub while an unchanged local failure remains.

When a local or GitHub runner fails, do not prompt for permission when this document defines the next step. Fix forward within the current patch, preserve the patch boundary, and stop only when the correction would materially expand scope or no policy defines the next action.

### Roadmap Publication and Activation

The current task authorizes writing, validating, committing, pushing, and opening or updating the pull request for this Phase 16 roadmap. It does **not** by itself activate implementation of Patch 16.0 or any later capability patch.

Phase 16 implementation begins only after an explicit operator request to start Phase 16. Once activated, the Phase Completion Loop below authorizes autonomous work through Patch 16.15, subject to the patch boundaries, validation requirements, and stop conditions in this document.

### Git Authorization

This file is the explicit authorization for `git commit`, `git push`, `gh pr create`/`update`, `gh run cancel`, and `gh pr merge` on `codex/**` branches for the roadmap publication and, once Phase 16 is explicitly activated, for the Phase 16 implementation loop. Never push directly to `main`. Do not self-approve.

General rule: when Workflow, Monitoring, Merge, Phase Completion, or Runner Policy defines the next step, continue without a permission prompt. Ask only when the next action falls outside those policies or requires a material scope expansion.

## Monitoring Policy

When monitoring GitHub Actions:

- State it explicitly in chat as `Monitoring <branch> <SHA> via c2eab010 every 2m`.
- Use `gh run list --branch <branch> --limit 100` and, where necessary, the paginated Actions API filtered to the exact `head_sha`.
- Report each poll as `SHA | workflow | event | status | conclusion` and distinguish the owning Phase 16 guard failure from unrelated or superseded runs.
- Keep monitor `c2eab010` visible; after each poll say `Monitoring continues` or `All green — proceeding`.
- Do not silently poll.

## Merge Policy

Once every required `pull_request` workflow for the exact PR `HEAD` is `completed success`, all review conversations are resolved, and repository rules permit the operation, autonomously merge the agent's own `codex/**` pull request without prompting. After a capability patch merges, proceed to the next Phase 16 patch only when Phase 16 implementation has been explicitly activated.

## Phase Completion Loop

After explicit Phase 16 activation, do not stop after one capability merge. Phase 16 is complete only when Status shows every patch 16.0–16.15 `DONE`, every Phase 16 Success Criterion is satisfied, all review conversations are resolved, and `guard-cranelift-phase16-close` passes in the authoritative GitHub environment.

After merging one patch, update local `main`, create `codex/phase16-<next>` from that `main`, implement the next patch's full Purpose and Exit Gate, validate locally, publish, monitor, fix forward if needed, and merge when green. Stop only when the operator explicitly says stop, repository policy blocks progress, or the required correction would materially expand the selected patch.

**Atomic per-patch commits and PRs:** Each initial publication must contain one complete patch such as 16.3 or 16.4, with its owning focused checks green before push. Do not combine planned patches into one PR and do not split a patch across multiple initial PRs unless its Exit Gate explicitly requires that split. Narrow corrective commits on the same PR are allowed when CI or review identifies a defect; reproduce and validate each correction locally before republishing.

## Runner Policy

If a GitHub runner fails, cancel other queued or in-progress runs on that branch that are superseded by the fix. Before a new push, cancel runs whose `headSha` is not the current `HEAD` so obsolete jobs do not consume runner capacity. Never cancel a current-`HEAD` run merely because it is slow.

```bash
BRANCH=$(git branch --show-current)
PATCH_HEAD=$(git rev-parse HEAD)
export PATCH_HEAD
gh run list --branch "$BRANCH" --limit 100 --json databaseId,headSha,status,name | python3 -c "
import json, os, subprocess, sys
head = os.environ['PATCH_HEAD']
runs = json.load(sys.stdin)
seen = set()
cancelled = 0
for run in runs:
    run_id = run['databaseId']
    if run['headSha'] != head and run['status'] != 'completed' and run_id not in seen:
        seen.add(run_id)
        print(f\"cancel {run_id} {run['headSha'][:7]} {run['name']} {run['status']}\")
        subprocess.run(['gh', 'run', 'cancel', str(run_id), '--repo', 'garthtrickett/gust'], check=False)
        cancelled += 1
print(f\"cancelled {cancelled} superseded (limit 100)\")
"
```

If more than 100 runs exist, use the paginated Actions API and apply the same exact branch, non-completed, and non-current-`HEAD` filters.

## Status

- [x] Patch 16.0 — Opening Inventory and Phase 15 Residual Rebase — DONE
- [x] Patch 16.1 — Compiler-Owned Function ABI Authority — DONE
- [x] Patch 16.2 — Canonical MIR Signature, Call, and Result Transport — DONE
- [ ] Patch 16.3 — Aggregate Parameter Classification and Passing
- [ ] Patch 16.4 — Aggregate Return Classification and Hidden Result Transport
- [ ] Patch 16.5 — Caller/Callee Placement and Direct-Call Agreement
- [ ] Patch 16.6 — Typed Indirect Calls and Function-Value ABI
- [ ] Patch 16.7 — Fat-Pointer and Selected Trait-Object Call ABI
- [ ] Patch 16.8 — Unsized Value Parameter, Return, and Storage Contract
- [ ] Patch 16.9 — Bounded Dynamic Stack Frames and Variable-Sized Storage
- [ ] Patch 16.10 — Resource-Bearing Aggregate Call ABI
- [ ] Patch 16.11 — Selected Cross-Module Aggregate and Resource ABI
- [ ] Patch 16.12 — ABI Metadata and Native Request Validation
- [ ] Patch 16.13 — Cross-Feature ABI Composition and Complete Differential
- [ ] Patch 16.14 — Deferred Residue and ABI-Coverage Audit
- [ ] Patch 16.15 — Phase 16 Closure

## Immutable Phase 15 Completion Record

The Phase 15 closure guard consumes this historical record. These rows describe the already-closed parent phase and are not active Phase 16 work.

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

Phase 16 preserves Gust function-call, parameter, result, frame, and selected cross-module ABI semantics without relying on generated C declarations, host compiler classification, or backend-specific reconstruction.

The phase covers the declared inventory for:

- compiler-owned function signature and calling-convention identity;
- canonical MIR call and result transport;
- aggregate parameter classification and placement;
- aggregate return classification and hidden result transport;
- caller/callee agreement for direct calls;
- bounded typed indirect calls and function values;
- fat-pointer and selected trait-object call ABI;
- unsized parameter, return, and storage contracts;
- bounded dynamic stack frames and variable-sized storage;
- resource-bearing aggregate parameters and returns;
- selected cross-module aggregate and resource ABI;
- ABI metadata validation;
- prevention of duplicated, omitted, misclassified, or reordered value transport.

The compiler must own ABI meaning. Canonical MIR and compiler-produced ABI records must contain the signature classifications, placements, copy or move obligations, hidden values, frame requirements, and compatibility decisions required for faithful lowering. MIR-to-C and Cranelift must consume the same decisions.

Phase 16 closes only the declared function ABI and aggregate call inventory. It does not claim complete platform ABI coverage, complete foreign-function interoperability, complete dynamic dispatch, complete trait-object semantics, complete unsized-type support, complete runtime support, or production readiness.

## Starting State

The expected starting state is:

- Phase 15 is closed with status `phase15_closed_resource_and_lifetime_semantics`.
- The canonical feature registry remains the only active feature-state authority.
- The Phase 15 semantic closure snapshot remains immutable.
- The Phase 15 deferred residue snapshot contains concrete capabilities assigned to later phases.
- Phase 14 remains the compiler-owned authority for type layout, target layout, and memory-access validation.
- Phase 15 remains the compiler-owned authority for resource identity, move state, cleanup obligations, and destruction.
- MIR-to-C remains the default backend and differential oracle.
- Explicit Cranelift selection has no fallback.
- The compiler owns source interpretation and canonical MIR production.
- The worker receives only request data, canonical MIR, compiler-produced layout data, compiler-produced resource data, and the compiler-produced ABI data selected by this phase.
- Phase 9G owns object handling, linking, cleanup of owned temporary artifacts, and atomic publication.
- Registry-derived CI families own focused differential evidence.
- Cranelift Historical Full remains the sole Level 3 historical owner.
- Phase 16 must consume those contracts rather than recreate them.

The concrete inherited Phase 16 inputs are the registry-owned residual capability groups:

- `p15_unsized_types` → `unsized_value_parameter_return_and_storage_contract`;
- `p15_trait_object_fat_pointers` → `trait_object_fat_pointer_and_indirect_call_ABI`;
- `p16_dynamic_stack_allocation` → `dynamic_stack_frame_and_variable_sized_storage_ABI`;
- `p15_aggregate_parameter_abi` → `aggregate_parameter_ABI`;
- `p15_aggregate_return_abi` → `aggregate_return_ABI`;
- `p16_resource_bearing_aggregate_moves` → `resource_bearing_aggregate_parameter_return_and_cross_module_ABI`.

## Phase Boundary

Phase 16 may implement:

- compiler-owned function ABI identities;
- compiler-owned parameter and result classifications;
- compiler-owned calling-convention selection for explicitly selected Gust calls;
- canonical MIR direct-call and bounded typed-indirect-call forms;
- selected aggregate parameter placement;
- selected aggregate result placement;
- hidden result storage where required by a selected ABI plan;
- deterministic caller/callee placement agreement;
- bounded function values with a complete compiler-known signature;
- fat-pointer transport and selected trait-object call ABI;
- explicit metadata transport for selected unsized values;
- bounded dynamic stack allocation with compiler-produced size and alignment plans;
- resource-bearing aggregate parameter and return transfer;
- selected cross-module calls under an explicitly frozen Gust ABI contract;
- ABI compatibility witnesses and stable diagnostics.

Phase 16 must not silently absorb:

- variadic calls;
- untyped or signature-erased indirect calls;
- closures or captured environments;
- unrestricted virtual dispatch;
- complete trait-object semantics;
- arbitrary foreign-function interfaces;
- complete C, C++, platform, or vendor ABI classification;
- every target-specific calling convention;
- tail-call optimization or guaranteed tail calls;
- setjmp/longjmp semantics;
- asynchronous unwinding;
- foreign exception interoperability;
- complete panic unwinding;
- heap-allocation policy;
- garbage collection;
- reference counting unless separately selected;
- general borrow checking or unrestricted alias analysis;
- atomics or concurrency semantics;
- thread cancellation;
- dynamic symbol loading;
- linker or publication ownership;
- runtime package retirement;
- full Gust language parity.

Out-of-scope Phase 15 residual rows must remain deferred, be reassigned to a later phase, or be split into narrower rows. They must not be marked migrated merely because Phase 16 transports aggregates or resources across a call.

## Compiler-Owned Function ABI Authority

Phase 16 must establish one compiler-owned function ABI service with semantic records equivalent to the following concepts.

### Function ABI Identity

Every selected callable has a compiler-produced identity containing:

- stable function ABI ID;
- source declaration identity and source location;
- canonical function signature identity;
- calling-convention identity;
- owning module and linkage class;
- target applicability;
- parameter and result ABI IDs;
- variadic policy, which must be false for migrated Phase 16 rows unless separately selected;
- unwind and failure policy;
- resource-transfer policy;
- compatibility version or semantic schema identity.

### ABI Value Classification

Every parameter, result, hidden value, and selected frame value has a compiler-produced classification containing:

- stable ABI value ID;
- canonical type identity;
- compiler-owned layout identity;
- size and alignment where statically known;
- scalar, aggregate, fat-pointer, unsized, resource-bearing, or hidden-value class;
- direct, split, indirect, ignored, or explicitly unsupported transport policy;
- extension, truncation, padding, and normalization policy where applicable;
- copy, move, or borrow disposition;
- target-specific placement inputs selected by compiler policy;
- stable diagnostic reason on rejection.

### Parameter Placement

Every selected parameter has a compiler-produced placement containing:

- function ABI ID and parameter index;
- source and canonical-MIR value identities;
- one or more logical locations;
- register class or stack area where selected;
- offset, size, and alignment;
- indirect pointer metadata where used;
- caller copy or move obligation;
- callee materialization obligation;
- resource ownership transfer point;
- source location and diagnostic ownership.

### Result Placement

Every selected result has a compiler-produced placement containing:

- function ABI ID and result index;
- direct, split, or indirect transport policy;
- logical result locations;
- hidden result parameter identity where required;
- result storage layout and alignment;
- initialization and publication point;
- caller-owned and callee-owned obligations;
- resource ownership transfer point;
- failure and cleanup interaction;
- source location and diagnostic ownership.

### Call-Site Plan

Every selected call has a compiler-produced plan containing:

- stable call-site ABI ID;
- callee ABI identity or complete expected signature identity;
- direct or typed-indirect call kind;
- ordered argument mappings;
- ordered result mappings;
- hidden arguments and hidden results;
- pre-call copies, moves, and materializations;
- post-call extraction and normalization;
- resource-state transitions from Phase 15;
- selected cleanup obligations on normal and bounded failure edges;
- caller/callee compatibility decision;
- target applicability and source location.

### Dynamic Frame and Variable Storage Plan

Every selected dynamic stack or variable-sized value has a compiler-produced plan containing:

- stable frame-plan ID;
- owning function and scope;
- size expression represented in canonical MIR;
- compiler-approved alignment;
- overflow and bounds policy;
- lifetime start and end points;
- stack restoration point for every selected exit;
- interaction with resource cleanup;
- target availability;
- stable rejection reason for unsupported or unsafe shapes.

### ABI Compatibility Decision

Every direct cross-module or typed-indirect call compatibility record contains:

- expected and actual function ABI identities;
- expected and actual canonical signature identities;
- target and calling-convention identity;
- parameter and result classification agreement;
- layout agreement;
- resource-transfer agreement;
- compatibility result;
- stable diagnostic reason when incompatible.

The implementation may use different internal names, but all decisions must be explicit, validated, deterministic, and compiler-owned. No backend may infer ABI meaning from source text, generated C prototypes, host compiler behavior, local names, stack-slot shape, Cranelift signatures, object symbols, or fixture names.

## Request and MIR Ownership

Canonical MIR must refer to compiler-owned function ABI, ABI value, call-site, hidden-result, compatibility, and dynamic-frame identities where applicable.

The native request must carry an immutable, deterministically ordered, deduplicated ABI table or equivalent compiler-produced representation containing only the ABI data required by the worker.

Consumers must behave as follows:

- MIR-to-C emits prototypes, argument transport, hidden result storage, aggregate copies, typed indirect calls, and selected frame operations from canonical MIR and compiler-produced ABI data.
- Cranelift lowers the same canonical operations and ABI plan.
- Neither backend may independently classify an aggregate parameter or result.
- Neither backend may independently invent a hidden return pointer.
- Neither backend may independently decide resource ownership transfer across a call.
- The worker may validate consistency but may not invent missing ABI classifications or placements.
- Runtime-facing operations consume compiler-selected symbol identities and descriptors.
- Diagnostics query the compiler ABI service and report the same classification or compatibility decision consumed by code generation.
- Generated views derive active rows, ABI families, targets, dispositions, and totals from structured authorities.
- No raw registry hash, MIR hash, generated-C hash, object hash, Markdown hash, or emitted-signature hash becomes a semantic contract.

## Architectural Invariants

Every Phase 16 patch must preserve:

- MIR-to-C as the default backend and differential oracle;
- explicit Cranelift selection with no fallback;
- generic source-to-canonical-MIR routing;
- no exact-source, filename, fixture-name, literal, generated-prototype, object-byte, or diagnostic-output recognizer;
- compiler-owned source interpretation;
- compiler-owned type and target layout authority from Phase 14;
- compiler-owned resource and cleanup authority from Phase 15;
- one compiler-owned function ABI authority;
- no backend-local aggregate classifier;
- no backend-local hidden-result planner;
- no backend-local resource-transfer policy;
- worker input limited to request data, canonical MIR, compiler-produced layout data, compiler-produced resource data, and compiler-produced ABI data;
- capability and deferral decisions before driver or artifact access;
- Phase 9G ownership of object handling, linking, temporary cleanup, and atomic publication;
- preservation of an existing output on deferral or failure;
- deterministic registry and generated projections;
- registry-derived CI families;
- separate Level 1, Level 2, and Level 3 ownership;
- no exact CI matrix total treated as backend correctness;
- no claim that Phase 16 completes platform ABI, FFI, dynamic dispatch, runtime, or production support.

## Verification Policy

### Level 1 — Fast Contracts

Level 1 guards may validate:

- Phase 15 semantic closure availability;
- Phase 16 opening and parent traceability;
- canonical registry schema and semantic state;
- compiler-owned function ABI APIs;
- signature and placement schema;
- canonical call and result MIR ownership;
- aggregate classification ownership;
- hidden-result ownership;
- resource-transfer integration;
- ABI metadata uniqueness and consistency;
- generated projection freshness;
- no backend-local aggregate classifier or hidden-result planner;
- no fallback;
- worker isolation;
- early deferral;
- output preservation;
- manifest and route architecture;
- CI-family projection;
- test-level and workflow ownership;
- residue and closure summaries.

Level 1 guards must not replay all ABI programs, every target runner, the full historical suite, complete object matrices, or every cross-module fixture.

### Level 2 — Focused Differential Families

Level 2 evidence validates bounded migrated behavior on the primary PR host through registry-derived families.

A proposed initial family vocabulary is:

- `call-mir`;
- `aggregate-parameters`;
- `aggregate-returns`;
- `direct-call-agreement`;
- `typed-indirect-calls`;
- `fat-pointer-abi`;
- `unsized-abi`;
- `dynamic-stack`;
- `resource-aggregate-abi`;
- `cross-module-abi`.

The active family set and count must be derived from the canonical registry. Workflows must not hard-code one matrix row per patch.

For each applicable case, Level 2 should compare:

- default MIR-to-C;
- explicit MIR-to-C;
- explicit Cranelift;
- runtime values;
- stdout and stderr where declared stable;
- exit status;
- parameter and result ABI witnesses;
- hidden argument and result witnesses;
- aggregate byte and field preservation;
- resource-state and cleanup witnesses;
- selected cross-module effects;
- stable diagnostics;
- preservation of sentinel outputs on failure.

Default and explicit MIR-to-C output should remain byte-identical for the same target and source where the existing differential contract requires it.

### Level 3 — Historical and Complete ABI Evidence

Cranelift Historical Full remains the sole Level 3 owner. It owns:

- complete Phase 9–16 historical replay;
- the complete registry-derived Phase 16 differential inventory;
- representative function ABI programs across every declared target where the selected ABI contract applies;
- target-specific parameter, result, stack, and cross-module evidence;
- all historical aggregate call fixtures;
- complete object, link, cleanup, and publication failure matrices owned by Phase 9G;
- packaging and reproducibility evidence;
- long argument lists and representative nested aggregate/resource call graphs.

Phase 16 opening and closure guards validate that the Level 3 suite remains available, registry-derived, and separately runnable. They do not execute it.

## Standard Definition of Done for Every Phase 16 Capability Patch

A Phase 16 capability is migrated only when all of the following are true:

- The supported source shape is precisely bounded.
- The supported canonical-MIR shape is precisely bounded.
- The owning canonical registry row is identified.
- The owning target set is explicit or registry-derived.
- A real source fixture lowers through the generic producer.
- A compiler-owned canonical-MIR fixture exists where applicable.
- The compiler ABI service returns the required identities, classifications, placements, call plans, frame plans, and compatibility decisions.
- The compiler layout service returns every required type and target layout record.
- The compiler resource service returns every required move, transfer, cleanup, and destruction decision for resource-bearing values.
- MIR-to-C consumes the compiler-produced ABI decisions.
- Cranelift consumes the same decisions.
- Runtime-facing code consumes compiler-produced symbol identities or descriptors.
- Diagnostics report the same ABI decision used by code generation.
- No consumer independently guesses aggregate classification, hidden results, placement, frame shape, signature compatibility, or resource transfer.
- Default and explicit MIR-to-C remain equivalent.
- MIR-to-C and Cranelift native behavior are compared.
- ABI, resource-state, and cleanup witnesses are compared where observable.
- Aggregate padding and initialized data are preserved for the selected inventory.
- Malformed cases have stable diagnostics.
- Unsupported cases remain explicitly deferred.
- Deferred and invalid cases stop before native-driver discovery, request publication, temporary object creation, linker access, or output replacement.
- Existing output survives deferral and failure.
- The worker receives only request data, canonical MIR, compiler-produced layout data, compiler-produced resource data, and compiler-produced ABI data.
- The registry row is updated using the existing status vocabulary.
- Generated projections are refreshed.
- The owning CI family contains focused evidence.
- At least one appropriate composition relationship exists.
- No exact-source, exact-prototype, or exact-object recognizer was introduced.
- Explicit Cranelift still cannot fall back to MIR-to-C.
- New guards are assigned to the correct test level.

## Patch Sequence

### Patch 16.0 — Opening Inventory and Phase 15 Residual Rebase

**Purpose**

Establish the exact Phase 16 input from the closed Phase 15 state without changing compiler, backend, runtime, ABI, or artifact behavior.

**Steps**

- Add a semantic Phase 16 opening snapshot to the canonical registry.
- Preserve parent traceability to Phase 15 migrated rows, the six Phase 16 residual capability groups, and explicit Phase 16 planning categories.
- Select only function ABI, aggregate transport, typed call, unsized transport, dynamic frame, and resource-bearing call rows owned by this phase.
- Split broad residuals where one inherited row contains both a selected Phase 16 ABI capability and later FFI, closure, exception, allocation, runtime, concurrency, linker, or target-extension work.
- Keep out-of-scope rows deferred and explicitly assign their destination phases.
- Add stable Phase 16 rows for:
  - function ABI authority;
  - canonical signature, call, and result MIR;
  - aggregate parameter ABI;
  - aggregate return and hidden-result ABI;
  - direct caller/callee agreement;
  - typed indirect calls and bounded function values;
  - fat-pointer and selected trait-object call ABI;
  - unsized value parameter, return, and storage contracts;
  - bounded dynamic stack and variable-sized storage;
  - resource-bearing aggregate parameters and returns;
  - selected cross-module aggregate and resource ABI;
  - ABI metadata validation;
  - complete ABI differential evidence.
- Require each opening row to contain stable ID, parent, feature family, CI family, capability owner, diagnostic owner, target applicability, status, current failure stage, positive future fixture, and negative current fixture.
- Freeze the initial registry-derived Phase 16 CI-family projection.
- Generate the Phase 16 opening review view.
- Add `guard-cranelift-phase16-opening-contract`.

**Test Level**

Level 1.

**Exit Gate**

Every declared Phase 16 row has a stable parent, owner, target scope, failure stage, fixture pair, and initial disposition. Non-ABI Phase 15 residue remains explicitly outside Phase 16.

### Patch 16.1 — Compiler-Owned Function ABI Authority

**Purpose**

Create the single signature-classification and call-placement path consumed by canonical MIR, MIR-to-C, Cranelift, runtime-facing call operations, and diagnostics.

**Steps**

- Add compiler-owned semantic types equivalent to function ABI identity, ABI value classification, parameter placement, result placement, call-site plan, dynamic frame plan, and ABI compatibility decision.
- Add compiler-owned queries equivalent to:
  - `function_abi(function, target)`;
  - `classify_abi_value(type, position, target)`;
  - `parameter_placements(function_abi)`;
  - `result_placements(function_abi)`;
  - `call_plan(call_site, expected_abi)`;
  - `frame_plan(function, target)`;
  - `validate_abi_compatibility(expected, actual)`.
- Give request-local ABI values, placements, call sites, and frame plans deterministic semantic identities.
- Ensure semantic identity derives from compiler state rather than raw file or emitted-code hashes.
- Extend canonical MIR or associated program metadata to reference ABI identities.
- Extend native request serialization with a compiler-produced ABI table.
- Require request deserialization to reject unknown ABI IDs, duplicate conflicting records, unknown layout or resource IDs, impossible placements, invalid hidden results, signature mismatches, target mismatches, and ABI metadata inconsistent with canonical MIR.
- Add a reduced generated ABI review view.
- Add hard bans proving MIR-to-C does not own a separate aggregate classifier, the worker does not own a separate call planner, Cranelift signatures are not semantic authority, and diagnostics do not recompute ABI decisions independently.
- Add `guard-cranelift-phase16-abi-authority-contract`.

**Test Level**

Level 1.

**Boundary**

This patch establishes authority and transport. It does not migrate every parameter, result, call, or frame form.

**Exit Gate**

Every later Phase 16 patch can add one bounded ABI capability by extending the compiler-owned authority and existing request path without adding backend-specific classification or placement semantics.

### Patch 16.2 — Canonical MIR Signature, Call, and Result Transport

**Purpose**

Represent selected function signatures, call operands, hidden values, and results explicitly in canonical MIR without relying on generated C prototypes or backend reconstruction.

**Steps**

- Freeze the selected direct-call signature and scalar or already-layout-supported value inventory.
- Add or extend canonical MIR forms equivalent to function ABI declaration, argument materialization, direct call, result extraction, hidden argument, hidden result storage, and post-call normalization.
- Require each call-bearing MIR operation to carry or resolve function ABI ID, call-site ABI ID, ordered argument ABI IDs, ordered result ABI IDs, target identity, calling convention, and source location.
- Preserve evaluation order and Phase 15 resource-state transitions around calls.
- Reject missing ABI metadata, argument count or order disagreement, result count disagreement, unknown hidden values, unsupported calling convention, target mismatch, and call metadata that disagrees with the canonical signature.
- Make MIR-to-C emit only from canonical call operations and compiler ABI data.
- Make Cranelift lower the same operations and data.
- Prove the worker cannot derive signature identity from source text, symbols, C prototypes, or fixture names.
- Add `guard-cranelift-phase16-call-mir-contract` and `guard-cranelift-phase16-call-mir-parity`.

**Test Levels**

Contract: Level 1. Parity: Level 2.

**Exit Gate**

Selected calls have one compiler-owned signature and canonical MIR transport representation consumed equivalently by MIR-to-C and Cranelift.

### Patch 16.3 — Aggregate Parameter Classification and Passing

**Purpose**

Classify and transport selected aggregate parameters without delegating semantic decisions to generated C or backend-local calling-convention logic.

**Steps**

- Freeze the selected aggregate parameter inventory by type shape, size, alignment, target, and resource disposition.
- Define compiler-owned classifications for selected direct, split, and indirect aggregate parameter forms.
- Require each aggregate parameter plan to identify canonical type, layout ID, ABI value ID, logical locations, caller materialization, callee materialization, padding policy, and copy or move disposition.
- Preserve initialized fields and padding policy without reading uninitialized bytes as semantic values.
- Reject unsupported aggregate shapes, invalid layout identity, illegal split boundaries, insufficient alignment, overlapping placements, caller/callee disagreement, and silent copy of a move-only aggregate.
- Compare field values, byte-preservation witnesses where stable, argument order, and resource-state transitions through both backends.
- Add composition with multiple scalar and aggregate parameters.
- Add `guard-cranelift-phase16-aggregate-parameter-contract` and `guard-cranelift-phase16-aggregate-parameter-parity`.

**Test Levels**

Contract: Level 1. Parity: Level 2.

**Exit Gate**

Every selected aggregate parameter has one compiler-owned classification and placement that agrees at caller and callee through both backends.

### Patch 16.4 — Aggregate Return Classification and Hidden Result Transport

**Purpose**

Return selected aggregate values through explicit compiler-owned result plans, including hidden result storage where selected.

**Steps**

- Freeze the selected aggregate result inventory by type shape, size, alignment, target, and resource disposition.
- Define compiler-owned direct, split, and indirect result classifications.
- Represent selected hidden-result transport explicitly in function ABI records and canonical MIR.
- Require hidden result plans to identify storage owner, layout, alignment, initialization point, hidden parameter placement, callee write obligation, caller extraction, and failure behavior.
- Preserve ordinary return evaluation and Phase 15 cleanup ordering.
- Reject missing hidden storage, duplicate hidden result identities, wrong layout or alignment, result written after terminal control flow, caller/callee result disagreement, uninitialized publication, and backend-invented result storage.
- Compare returned fields, nested aggregates, initialized data, result witnesses, and resource-state witnesses through both backends.
- Add `guard-cranelift-phase16-aggregate-return-contract` and `guard-cranelift-phase16-aggregate-return-parity`.

**Test Levels**

Contract: Level 1. Parity: Level 2.

**Boundary**

Only explicitly selected return shapes and targets migrate. Complete platform aggregate-return classification remains deferred.

**Exit Gate**

Every selected aggregate result has one compiler-owned placement, and any hidden result storage is explicit and equivalent through MIR-to-C and Cranelift.

### Patch 16.5 — Caller/Callee Placement and Direct-Call Agreement

**Purpose**

Prove that selected direct-call callers and callees consume one compatible compiler-produced ABI plan.

**Steps**

- Freeze compatibility rules for selected direct calls within one module.
- Define agreement across calling convention, target, ordered parameters, results, hidden values, layout identities, placement classes, extensions, and resource-transfer policy.
- Add canonical compatibility witnesses at call sites.
- Validate both declaration and definition against the same function ABI identity.
- Reject signature drift, stale call plans, parameter or result permutation, incompatible layouts, calling-convention mismatch, target mismatch, hidden-result mismatch, and resource-transfer disagreement before driver discovery.
- Add positives for nested calls, recursion where already supported, mixed scalar/aggregate arguments, and aggregate return consumed by another call.
- Add poisoned-driver and sentinel-output evidence for invalid calls.
- Add `guard-cranelift-phase16-direct-call-agreement-contract` and `guard-cranelift-phase16-direct-call-agreement-parity`.

**Test Levels**

Contract: Level 1. Parity: Level 2.

**Exit Gate**

Every selected direct call has one compiler-owned compatibility decision, and caller/callee ABI drift is rejected before worker or artifact access.

### Patch 16.6 — Typed Indirect Calls and Function-Value ABI

**Purpose**

Support a bounded inventory of function values and indirect calls whose complete ABI signature is known to the compiler.

**Steps**

- Freeze the selected function-value forms and prohibit signature-erased calls.
- Require each function value to carry or resolve a canonical function signature and function ABI identity.
- Add canonical MIR typed function-value and typed-indirect-call operations.
- Define nullability, target applicability, calling-convention, and compatibility policies.
- Require the call-site plan to validate the expected ABI against the function value's actual ABI before lowering.
- Preserve ordered parameter/result transport and resource-transfer decisions.
- Reject unknown signatures, signature erasure, incompatible function values, null calls where invalid, unsupported calling conventions, variadic targets, and unvalidated pointer casts.
- Add positives for selection between ABI-compatible functions and passing a typed function value where already source-supported.
- Add negatives for every compatibility class.
- Add `guard-cranelift-phase16-typed-indirect-call-contract` and `guard-cranelift-phase16-typed-indirect-call-parity`.

**Test Levels**

Contract: Level 1. Parity: Level 2.

**Boundary**

Closures, captured environments, arbitrary code pointers, dynamic symbol lookup, signature-erased dispatch, and unrestricted virtual calls remain deferred.

**Exit Gate**

Every selected indirect call uses a complete compiler-owned function ABI identity and is lowered equivalently without backend-specific signature reconstruction.

### Patch 16.7 — Fat-Pointer and Selected Trait-Object Call ABI

**Purpose**

Define transport and call ABI for an explicitly selected fat-pointer and trait-object inventory without claiming complete trait-object semantics.

**Steps**

- Freeze the selected fat-pointer representation and trait-object call shapes.
- Define compiler-owned identities for data component, metadata or vtable component, method signature, selected slot identity, and call ABI.
- Require compiler-owned layouts and placements for every fat-pointer component.
- Represent selected method extraction and typed indirect call in canonical MIR.
- Validate data/metadata pairing, method signature compatibility, target availability, slot identity, alignment, and resource disposition.
- Reject missing metadata, mismatched components, unknown method signatures, invalid slot identities, untyped dispatch, unsupported target representation, and backend-local vtable interpretation.
- Compare component transport, selected method results, diagnostics, and resource-state witnesses.
- Add `guard-cranelift-phase16-fat-pointer-abi-contract` and `guard-cranelift-phase16-fat-pointer-abi-parity`.

**Test Levels**

Contract: Level 1. Parity: Level 2.

**Boundary**

General trait resolution, arbitrary object safety, downcasting, complete vtable generation, multiple inheritance, closure objects, and foreign object models remain deferred.

**Exit Gate**

Every selected fat-pointer call uses compiler-owned component layouts and a typed call ABI shared by MIR-to-C and Cranelift.

### Patch 16.8 — Unsized Value Parameter, Return, and Storage Contract

**Purpose**

Define a bounded ABI contract for selected unsized values using explicit compiler-produced metadata and storage ownership.

**Steps**

- Freeze the selected unsized value forms and their metadata representation.
- Define which forms may appear as parameters, results, local views, or variable-sized storage.
- Require each selected unsized value to carry data identity, metadata identity, element or tail layout, alignment, bounds policy, storage owner, and lifetime.
- Represent unsized transport and metadata flow explicitly in canonical MIR.
- Define when transport is by fat pointer, indirect storage, or another selected compiler-owned form.
- Reject by-value unsized forms without an explicit storage plan, missing metadata, inconsistent length or layout, overflow, insufficient alignment, invalid result ownership, and backend-invented size calculations.
- Compare metadata, element values, bounds diagnostics, and output preservation.
- Add `guard-cranelift-phase16-unsized-abi-contract` and `guard-cranelift-phase16-unsized-abi-parity`.

**Test Levels**

Contract: Level 1. Parity: Level 2.

**Boundary**

Arbitrary dynamically sized types, unsized aggregate fields beyond selected tail forms, general heap allocation, and complete trait-object semantics remain deferred.

**Exit Gate**

Every selected unsized value has explicit compiler-owned data, metadata, storage, and call transport decisions consumed equivalently by both backends.

### Patch 16.9 — Bounded Dynamic Stack Frames and Variable-Sized Storage

**Purpose**

Support selected variable-sized stack storage from an explicit compiler-owned frame plan without transferring frame semantics to a backend.

**Steps**

- Freeze the selected dynamic stack allocation forms, size expressions, targets, and maximum or overflow policies.
- Add canonical MIR operations equivalent to checked dynamic size computation, aligned stack allocation, lifetime start, lifetime end, and stack restoration.
- Require each operation to reference a compiler-produced dynamic frame plan.
- Define deterministic alignment, overflow, zero-size, nesting, and exit-edge behavior.
- Integrate stack restoration with normal return, selected early returns, and Phase 15 cleanup ordering.
- Reject non-dominating sizes, unchecked overflow, unsupported alignment, use outside lifetime, missing restoration, restoration before resource cleanup, target unavailability, and backend-local frame-size invention.
- Compare runtime values, frame witnesses, cleanup ordering, and stable failure behavior.
- Add `guard-cranelift-phase16-dynamic-stack-contract` and `guard-cranelift-phase16-dynamic-stack-parity`.

**Test Levels**

Contract: Level 1. Parity: Level 2.

**Boundary**

Unbounded stack growth, arbitrary stack probing policy, coroutine frames, asynchronous frames, and heap fallback remain deferred.

**Exit Gate**

Every selected dynamic stack value uses one checked compiler-owned frame plan and restores storage in the declared order through both backends.

### Patch 16.10 — Resource-Bearing Aggregate Call ABI

**Purpose**

Carry selected resource-bearing aggregates across parameter and result boundaries without weakening Phase 15 ownership, move, cleanup, or exactly-once destruction rules.

**Steps**

- Freeze selected resource-bearing aggregate parameter and result forms.
- Define compiler-owned ownership transfer points for by-value parameters, indirect parameters, direct results, and hidden results.
- Require each ABI plan to reference Phase 15 resource identities, transitions, cleanup obligations, and destructor identities.
- Preserve field layout and aggregate ABI classification from the compiler layout and ABI services.
- Cancel old-owner cleanup only at the validated transfer point and create destination obligations explicitly.
- Define failure-before-transfer and failure-after-transfer behavior for selected call edges.
- Reject silent copies of move-only resources, two live owners, missing destination identity, stale source cleanup, hidden-result publication before initialization, destructor mismatch, and caller/callee transfer disagreement.
- Add positives for move into a call, aggregate returned to a new owner, nested resource aggregates where selected, early return after receipt, and reassignment of a returned aggregate.
- Compare resource-state, cleanup, destructor order, runtime values, and selected filesystem effects.
- Add `guard-cranelift-phase16-resource-aggregate-abi-contract` and `guard-cranelift-phase16-resource-aggregate-abi-parity`.

**Test Levels**

Contract: Level 1. Parity: Level 2.

**Exit Gate**

Every selected resource-bearing aggregate parameter and return has one compiler-owned ABI and ownership-transfer plan, with exactly one live owner and exactly-once cleanup through both backends.

### Patch 16.11 — Selected Cross-Module Aggregate and Resource ABI

**Purpose**

Extend the selected aggregate and resource call contracts across an explicitly bounded module boundary without claiming general foreign ABI support.

**Steps**

- Freeze the selected same-version Gust cross-module inventory, linkage classes, targets, and symbol authority.
- Require exported and imported declarations to carry compatible compiler-produced function ABI identities or semantic descriptors.
- Validate canonical signature, target, calling convention, layouts, placements, hidden results, and resource-transfer policy across the boundary.
- Define deterministic symbol identity without using object bytes or raw emitted-name hashes as semantic authority.
- Preserve Phase 9G ownership of object production, linking, temporary artifacts, and publication.
- Reject missing ABI descriptors, stale imports, incompatible layouts, target disagreement, calling-convention mismatch, hidden-result mismatch, resource-policy mismatch, and unsupported foreign symbols before artifact mutation where possible.
- Add positives for aggregate parameter, aggregate result, resource-bearing aggregate transfer, and multiple selected modules.
- Add negatives with poisoned linker or driver access and sentinel-output preservation.
- Add `guard-cranelift-phase16-cross-module-abi-contract` and `guard-cranelift-phase16-cross-module-abi-parity`.

**Test Levels**

Contract: Level 1. Parity: Level 2.

**Boundary**

Arbitrary C or foreign ABI, dynamic libraries, symbol version negotiation, independent compiler-version compatibility, variadics, and cross-language exceptions remain deferred.

**Exit Gate**

Every selected cross-module call has one compatible compiler-produced ABI contract and preserves aggregate and resource semantics through both backends without taking artifact ownership from Phase 9G.

### Patch 16.12 — ABI Metadata and Native Request Validation

**Purpose**

Make ABI metadata a validated compiler-produced request contract rather than advisory backend data.

**Steps**

- Freeze the ABI metadata schema.
- Require records for function ABI identity, canonical signature, target, calling convention, ABI value classifications, parameter placements, result placements, hidden values, call-site plans, compatibility decisions, dynamic frame plans, layout references, and resource-transfer references where applicable.
- Require deterministic ordering and deduplication.
- Reject before worker execution unknown ABI IDs, duplicate conflicting records, unknown layout or resource IDs, MIR calls missing metadata, metadata without MIR owners, impossible placements, overlapping stack areas, invalid hidden results, signature mismatch, target mismatch, invalid frame restoration, and resource-transfer inconsistency.
- Preserve stable diagnostic reason codes.
- Add malformed request fixtures for every rejection class.
- Add poisoned-driver and sentinel-output evidence.
- Prove the worker performs consistency validation but does not invent missing ABI classifications, placements, signatures, or ownership transfers.
- Add `guard-cranelift-phase16-abi-metadata-contract`.

**Test Level**

Level 1.

**Exit Gate**

The worker receives one validated compiler-produced ABI contract, and malformed call data stops before driver and artifact access.

### Patch 16.13 — Cross-Feature ABI Composition and Complete Differential

**Purpose**

Prove that migrated Phase 16 capabilities compose and that value transport, ownership transfer, cleanup, and observable behavior agree through both backends.

**Steps**

- Generate the active Phase 16 differential inventory from canonical registry ownership.
- Do not maintain an unrelated hand-written feature, ABI family, target, aggregate-shape, or resource-kind list.
- Add representative composed programs combining aggregate parameters, aggregate returns, hidden results, direct caller/callee agreement, typed indirect calls, fat-pointer transport, unsized metadata, dynamic stack storage, resource-bearing aggregates, and selected cross-module calls.
- Include nested combinations such as:
  - an aggregate returned and immediately passed to another function;
  - mixed scalar and aggregate parameters with a hidden aggregate result;
  - a typed indirect call returning an aggregate;
  - a selected fat-pointer call receiving aggregate data;
  - unsized metadata transported through a selected call;
  - dynamic stack storage used as selected indirect result storage;
  - a resource moved into an aggregate parameter and returned to a new owner;
  - a resource-bearing hidden result followed by early return cleanup;
  - selected cross-module aggregate parameter and return composition;
  - failure before and after a selected ownership-transfer point.
- For each applicable primary-host case, run default MIR-to-C, explicit MIR-to-C, and explicit Cranelift.
- Require default and explicit MIR-to-C output to remain byte-identical where the existing contract applies.
- Compare runtime values, stdout and stderr where stable, exit status, parameter/result witnesses, hidden-value witnesses, layouts, resource transitions, cleanup and destructor order, selected filesystem effects, initialized data, and sentinel-output preservation.
- Add at least one composition case per active Phase 16 CI family.
- Ensure every migrated row has individual evidence, at least one composition relationship, a differential case owner, and target applicability.
- Keep the Phase 16 closure guard static and lightweight.
- Assign focused primary-host composition to Level 2 and complete historical/applicable-target evidence to Level 3.
- Add `guard-cranelift-phase16-composition-contract`, `guard-cranelift-phase16-composition-differential`, and `guard-cranelift-phase16-complete-abi-evidence`.

**Test Levels**

Composition contract: Level 1. Focused composition differential: Level 2. Complete historical/applicable-target evidence: Level 3.

**Exit Gate**

Every migrated Phase 16 row has individual and composed evidence, and representative calls produce equivalent value transport, ownership transfer, cleanup, and observable behavior through MIR-to-C and Cranelift.

### Patch 16.14 — Deferred Residue and ABI-Coverage Audit

**Purpose**

Eliminate broad or ambiguous function ABI, aggregate transport, dynamic frame, and cross-module deferrals before Phase 16 closure.

**Steps**

- Audit every Phase 16 opening row.
- Require every row to finish as migrated, explicitly excluded, or replaced by one or more narrower deferred rows.
- Reject broad residual descriptions such as `more ABI`, `more calling conventions`, `more aggregates`, `more indirect calls`, `more unsized types`, `more stack allocation`, `FFI later`, or `runtime work later`.
- Replace broad residue with concrete capabilities such as:
  - variadic Gust calls;
  - C variadic calls;
  - target-specific homogeneous aggregate classification;
  - vector and SIMD calling-convention classes;
  - complete Windows aggregate ABI;
  - complete SysV aggregate ABI;
  - complete AArch64 procedure-call standard classification;
  - closure environment ABI;
  - signature-erased function pointers;
  - complete trait-object vtable generation;
  - arbitrary unsized aggregate fields;
  - coroutine or asynchronous frame ABI;
  - unbounded dynamic stack allocation and stack probing;
  - foreign aggregate parameters and returns;
  - foreign resource ownership transfer;
  - cross-version module ABI compatibility;
  - dynamic library and symbol-version ABI;
  - tail-call eligibility and guaranteed tail calls;
  - unwind and exception personality ABI.
- Require every remaining deferred row to contain stable ID, specific capability owner, diagnostic owner, concrete reason, destination phase, prerequisite capability, current failure stage, target applicability, positive future fixture, negative current fixture, stable diagnostic reason code, and source Phase 16 row IDs.
- Confirm no Phase 15 residual assigned to Phase 16 remains unchanged and ambiguous.
- Confirm every inherited row has migrated, been excluded with justification, or been replaced by smaller actionable rows.
- Confirm every declared ABI class and applicable target is supported for the selected inventory, explicitly excluded with justification, or represented by a narrower deferred row.
- Derive final totals from the registry.
- Generate the final Phase 16 review view.
- Freeze the residual inventory semantically as input to later phases.
- Add `guard-cranelift-phase16-deferred-residue-audit`.

**Test Level**

Level 1.

**Exit Gate**

Every Phase 16 item has migrated or become a smaller, actionable, explicitly owned future-phase entry, and ABI-class and target coverage is explicit.

### Patch 16.15 — Phase 16 Closure

**Purpose**

Close only the declared Phase 16 function ABI and aggregate call inventory.

The closure must not claim complete platform ABI, complete foreign interoperability, complete dynamic dispatch, complete unsized support, complete runtime support, or production readiness.

**Closure Guard**

Add `guard-cranelift-phase16-close` and register it as a Level 1 guard.

**Required Contracts**

The closure guard must require:

- the semantic Phase 15 closure summary;
- the Phase 16 opening contract;
- the canonical registry schema;
- the canonical registry projection guard;
- the Phase 16 parent-traceability contract;
- the compiler-owned function ABI authority contract;
- the canonical call MIR contract;
- the aggregate parameter contract;
- the aggregate return and hidden-result contract;
- the direct caller/callee agreement contract;
- the typed indirect call contract;
- the fat-pointer ABI contract;
- the unsized ABI contract;
- the dynamic stack contract;
- the resource-bearing aggregate ABI contract;
- the selected cross-module ABI contract;
- the ABI metadata contract;
- the deferred residue audit;
- the registry-derived Phase 16 CI-family projection;
- the semantic route architecture contract;
- the reduced manifest architecture contract through its canonical validator;
- the three-level test mapping and workflow ownership checks;
- the Phase 16 generated-view projection;
- the Phase 16 registry differential wiring;
- the separately runnable Level 3 historical and complete ABI suite;
- the Phase 14 layout ownership contract;
- the Phase 15 resource and lifetime ownership contract;
- the Phase 9G artifact ownership contract;
- MIR-to-C default ownership;
- explicit Cranelift no-fallback policy;
- worker request isolation;
- early deferral and output-preservation contracts.

**Closure Assertions**

The closure guard must prove:

- every Phase 16 opening row has a valid final disposition;
- every migrated row uses generic canonical-MIR routing;
- every migrated callable has a compiler-owned function ABI identity;
- every migrated parameter and result has a compiler-produced classification and placement;
- every hidden result is compiler-produced and explicit;
- every typed indirect call has a complete compiler-known signature;
- every selected dynamic frame has a compiler-produced plan;
- MIR-to-C and Cranelift consume the same compiler-produced ABI data;
- resource-bearing call transport consumes Phase 15 resource decisions;
- runtime-facing call operations use compiler-produced identities or descriptors;
- diagnostics consume the same ABI decisions as code generation;
- every remaining deferral is concrete, target-scoped where necessary, and owned;
- no exact-source, exact-prototype, exact-object, or exact-diagnostic recognizer was introduced;
- no backend-local aggregate classifier exists;
- no backend-local hidden-result planner exists;
- no backend-local resource-transfer authority exists;
- generated C declarations are not the semantic ABI authority;
- Cranelift signatures or block structure are not the semantic ABI authority;
- explicit Cranelift cannot fall back to MIR-to-C;
- unsupported cases stop before driver and artifact access;
- MIR-to-C remains the default oracle;
- default and explicit MIR-to-C remain equivalent;
- the worker receives only request data, canonical MIR, compiler-produced layout data, compiler-produced resource data, and compiler-produced ABI data;
- Phase 9G still owns object handling, linking, temporary cleanup, and publication;
- active totals, ABI classes, targets, and families are registry-derived;
- generated views are current;
- CI families remain registry-derived;
- no raw registry, MIR, emitted-signature, object, or Markdown hash contract exists;
- no exact matrix total is treated as backend correctness;
- Cranelift Historical Full remains separately runnable and owns complete historical evidence;
- representative ABI evidence is assigned to every applicable declared target;
- caller and callee classification disagreement is rejected;
- hidden result storage cannot be duplicated or omitted;
- resource ownership cannot remain live in both caller and callee after transfer;
- moved ownership cannot be destroyed by the old owner.

**What the Closure Guard Must Not Run**

It must not directly replay:

- every Phase 16 differential family;
- every target runner;
- the full Phase 9–16 historical suite;
- every historical native fixture;
- complete object/link failure matrices;
- complete packaging matrices;
- long-running cross-module or dynamic-frame stress suites.

It validates ownership and wiring for those suites.

**CI Wiring**

At closure:

- Replace the direct PR Fast invocation of the preceding Phase 16 Level 1 owner with `guard-cranelift-phase16-close`.
- Invoke the closure guard exactly once as the Level 1 phase-closure owner.
- Keep registry-derived Level 2 family jobs unchanged.
- Keep Heavy Guards focused on expensive primary-host native, ABI, cross-module, resource, and artifact evidence.
- Keep Cranelift Historical Full as the sole Level 3 historical and complete-ABI owner.
- Do not introduce a Phase 16 closure matrix family.
- Do not hard-code an exact target, ABI-class, aggregate-shape, or family count as a correctness claim.

**Suggested Status**

`phase16_closed_function_abi_and_aggregate_call_semantics`

**Suggested Closure Wording**

The declared Phase 16 function ABI and aggregate call inventory is complete. Migrated rows use compiler-owned signature classifications, parameter and result placements, call plans, frame plans, and resource-transfer decisions through generic canonical MIR, MIR-to-C, and Cranelift, while unsupported ABI capabilities are represented by narrower, explicitly owned future-phase deferrals.

**It Must Not Say**

- Cranelift has complete Gust ABI support.
- Gust implements every platform calling convention.
- Gust has complete C or foreign-function interoperability.
- All aggregate parameter and return forms are supported.
- All indirect calls or function values are supported.
- All trait objects or dynamic dispatch are supported.
- All unsized types are supported.
- All resource-bearing foreign calls are safe.
- All exceptions or unwinding paths preserve ABI state.
- All targets implement identical calling conventions.
- Dynamic allocation is complete.
- The experimental backend is production complete.

**Final Exit Gate**

Phase 16 is closed when every declared Phase 16 row has migrated through the generic canonical-MIR route using compiler-owned ABI, layout, and resource data; been explicitly excluded with justification; or been replaced by one or more narrower deferred rows assigned to later phases; and representative call programs have produced equivalent parameter transport, result transport, resource ownership, cleanup behavior, diagnostics, and observable effects through MIR-to-C and Cranelift for every applicable declared target.

## Recommended Implementation Order

Patch 16.0 opening inventory and Phase 15 residual rebase
→ Patch 16.1 compiler-owned function ABI authority
→ Patch 16.2 canonical MIR signature, call, and result transport
→ Patch 16.3 aggregate parameter classification and passing
→ Patch 16.4 aggregate return classification and hidden result transport
→ Patch 16.5 caller/callee placement and direct-call agreement
→ Patch 16.6 typed indirect calls and function-value ABI
→ Patch 16.7 fat-pointer and selected trait-object call ABI
→ Patch 16.8 unsized value parameter, return, and storage contract
→ Patch 16.9 bounded dynamic stack frames and variable-sized storage
→ Patch 16.10 resource-bearing aggregate call ABI
→ Patch 16.11 selected cross-module aggregate and resource ABI
→ Patch 16.12 ABI metadata and native request validation
→ Patch 16.13 cross-feature ABI composition and complete differential
→ Patch 16.14 deferred residue and ABI-coverage audit
→ Patch 16.15 closure.

## Phase 16 Success Criteria

Phase 16 succeeds when:

- Phase 15 closure remains semantically intact.
- One canonical registry owns active feature state.
- One compiler-owned function ABI service owns signature classification, parameter and result placement, call plans, compatibility, and selected frame decisions.
- All generated views, active families, targets, ABI classes, and totals come from structured authorities.
- Canonical MIR refers to compiler-owned function ABI, call-site, hidden-result, compatibility, and frame identities.
- Native requests carry compiler-produced ABI data.
- MIR-to-C does not independently classify aggregates, create hidden results, or select ownership transfer.
- Cranelift does not independently classify aggregates, create hidden results, or select ownership transfer.
- Runtime-facing call operations use compiler-produced identities or descriptors.
- Diagnostics report the same ABI decisions used by code generation.
- Selected aggregate parameters have explicit compiler-owned classification and placement.
- Selected aggregate returns have explicit compiler-owned classification and placement.
- Hidden result transport is explicit and backend-independent.
- Selected callers and callees agree through one compatibility decision.
- Selected typed indirect calls carry a complete compiler-known signature.
- Selected fat-pointer and trait-object calls use compiler-owned component layouts and call ABI.
- Selected unsized values have explicit data, metadata, storage, and transport contracts.
- Selected dynamic stack storage uses checked compiler-owned frame plans.
- Selected resource-bearing aggregate calls preserve Phase 15 exactly-once ownership and cleanup.
- Selected cross-module calls use compatible compiler-produced ABI records.
- ABI metadata is validated before worker execution.
- No exact-source, generated-prototype, object-output, or fixture recognizer exists.
- No explicit Cranelift fallback exists.
- Deferred input stops before driver and artifact access.
- Existing output is preserved on failure and deferral.
- Phase 9G retains artifact ownership.
- MIR-to-C remains the default oracle.
- Registry-derived Level 2 families own focused differential evidence.
- Cranelift Historical Full remains the sole Level 3 owner.
- Representative call programs agree through both backends.
- Every residual deferral is narrow, actionable, target-scoped where necessary, and assigned to a later phase.
- Phase 16 closure does not claim complete platform ABI, FFI, dynamic dispatch, unsized, runtime, or production parity.
