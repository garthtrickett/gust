# Phase 17 — Native Runtime Boundary

## Workflow Policy

Flow: start one patch → run the related `just`/`make`/`cargo`/`scripts/*` checks locally → once local checks pass, publish through a `codex/**` branch and pull request to trigger GitHub runners. If a GitHub runner fails, cancel superseded runs on that branch, reproduce the first failing guard locally from the smallest useful log excerpt, fix it, rerun the focused local guard, push, and monitor the new `HEAD` until green. Do not poll GitHub while an unchanged local failure remains.

When a local or GitHub runner fails, do not prompt for permission when this document defines the next step. Fix forward within the current patch, preserve the patch boundary, and stop only when the correction would materially expand scope or no policy defines the next action.

### Roadmap Publication and Activation

The current task authorizes writing, validating, committing, pushing, and opening or updating the pull request for this Phase 17 roadmap. It does **not** by itself activate implementation of Patch 17.0 or any later capability patch.

Phase 17 implementation begins only after an explicit operator request to start Phase 17. Once activated, the Phase Completion Loop below authorizes autonomous work through Patch 17.16, subject to the patch boundaries, validation requirements, and stop conditions in this document.

### Git Authorization

This file is the explicit authorization for `git commit`, `git push`, `gh pr create`/`update`, `gh run cancel`, and `gh pr merge` on `codex/**` branches for the roadmap publication and, once Phase 17 is explicitly activated, for the Phase 17 implementation loop. Never push directly to `main`. Do not self-approve.

General rule: when Workflow, Monitoring, Merge, Phase Completion, or Runner Policy defines the next step, continue without a permission prompt. Ask only when the next action falls outside those policies or requires a material scope expansion.

## Monitoring Policy

When monitoring GitHub Actions:

- State it explicitly in chat as `Monitoring <branch> <SHA> via c2eab010 every 2m`.
- Use `gh run list --branch <branch> --limit 100` and, where necessary, the paginated Actions API filtered to the exact `head_sha`.
- Report each poll as `SHA | workflow | event | status | conclusion` and distinguish the owning Phase 17 guard failure from unrelated or superseded runs.
- Keep monitor `c2eab010` visible; after each poll say `Monitoring continues` or `All green — proceeding`.
- Do not silently poll.

## Merge Policy

Once every required `pull_request` workflow for the exact PR `HEAD` is `completed success`, all review conversations are resolved, and repository rules permit the operation, autonomously merge the agent's own `codex/**` pull request without prompting. After a capability patch merges, proceed to the next Phase 17 patch only when Phase 17 implementation has been explicitly activated.

## Phase Completion Loop

After explicit Phase 17 activation, do not stop after one capability merge. Phase 17 is complete only when Status shows every patch 17.0–17.16 `DONE`, every Phase 17 Success Criterion is satisfied, all review conversations are resolved, and `guard-cranelift-phase17-close` passes in the authoritative GitHub environment.

After merging one patch, update local `main`, create `codex/phase17-<next>` from that `main`, implement the next patch's full Purpose and Exit Gate, validate locally, publish, monitor, fix forward if needed, and merge when green. Stop only when the operator explicitly says stop, repository policy blocks progress, or the required correction would materially expand the selected patch.

**Atomic per-patch commits and PRs:** Each initial publication must contain one complete patch such as 17.3 or 17.4, with its owning focused checks green before push. Do not combine planned patches into one PR and do not split a patch across multiple initial PRs unless its Exit Gate explicitly requires that split. Narrow corrective commits on the same PR are allowed when CI or review identifies a defect; reproduce and validate each correction locally before republishing.

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
- [ ] Patch 17.11 — I/O, Filesystem, and Resource Runtime Audit
- [ ] Patch 17.12 — Threading and Synchronization Runtime Audit
- [ ] Patch 17.13 — Runtime Availability, Compatibility, and Diagnostic Enforcement
- [ ] Patch 17.14 — Cross-Feature Runtime Composition and Complete Differential
- [ ] Patch 17.15 — Deferred Residue and Runtime-Coverage Audit
- [ ] Patch 17.16 — Phase 17 Closure

## Immutable Phase 16 Completion Record

The Phase 17 opening and closure guards consume this historical record. These rows describe the already-closed parent phase and are not active Phase 17 work.

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

The Phase 16 closure guard consumes this historical record transitively. These rows describe the already-closed Phase 15 parent and are not active Phase 17 work.

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

Phase 17 removes generated C glue as an implicit implementation layer between compiler-produced native code and the Gust runtime.

Every existing C-dependent helper selected by this phase must be classified as exactly one of:

- a stable runtime-library function imported by Cranelift;
- a Rust implementation compiled into the runtime;
- a separately compiled C runtime object retained temporarily;
- pure Gust runtime code compiled through canonical MIR;
- an obsolete helper to remove.

The phase covers the declared inventory for:

- a compiler-owned supported runtime ABI;
- stable runtime symbol identities and versions;
- separation of compiler-generated program code from runtime implementation;
- explicit runtime package manifests;
- target-specific runtime objects or libraries;
- runtime requirement transport in canonical MIR and native requests;
- runtime availability and compatibility validation before linking;
- stable diagnostics for missing, unknown, or incompatible runtime symbols;
- elimination of generated ad hoc C wrappers and shims from the native path;
- allocation, core memory, string, I/O, filesystem, resource, threading, and synchronization helper audits;
- native linking of migrated programs from native program objects plus an explicit runtime package.

Retiring generated C as the native intermediary does not require every runtime implementation to be rewritten in Rust or Gust during this phase. A separately compiled C runtime component is valid only when it is explicit, versioned, target-scoped, built independently of the source program, and selected through the same runtime package authority as every other component.

MIR-to-C may remain the default backend and differential oracle during Phase 17. Its generated C output is an independent comparison route and must not be used as a shim, wrapper source, or hidden runtime implementation in an explicit Cranelift/native artifact.

Phase 17 closes only the declared native runtime-boundary inventory. It does not claim complete runtime reimplementation, complete standard-library coverage, complete foreign-function interoperability, complete threading semantics, complete allocation policy, complete filesystem portability, complete platform ABI coverage, retirement of the MIR-to-C oracle, or production readiness.

## Starting State

The expected starting state is:

- Phase 16 is closed with status `phase16_closed_function_abi_and_aggregate_call_semantics`.
- The canonical feature registry remains the only active feature-state authority.
- The Phase 16 semantic closure snapshot remains immutable.
- The Phase 16 deferred residue snapshot contains concrete capabilities assigned to later phases.
- Phase 14 remains the compiler-owned authority for type layout, target layout, and memory-access validation.
- Phase 15 remains the compiler-owned authority for resource identity, move state, cleanup obligations, and destruction.
- Phase 16 remains the compiler-owned authority for signatures, parameter and result placement, call plans, frame plans, and compatibility.
- MIR-to-C remains the default backend and differential oracle unless a later explicit roadmap patch changes that ownership.
- Explicit Cranelift selection has no fallback.
- The compiler owns source interpretation and canonical MIR production.
- The worker receives only request data, canonical MIR, and compiler-produced layout, resource, ABI, and selected runtime-boundary metadata.
- Phase 9G owns object handling, linking, cleanup of owned temporary artifacts, and atomic publication.
- Registry-derived CI families own focused differential evidence.
- Cranelift Historical Full remains the sole Level 3 historical owner.

Phase 17 must consume those contracts rather than recreate them.

## Phase Boundary

Phase 17 may implement:

- compiler-owned runtime ABI identity;
- deterministic helper classification;
- stable runtime symbol identity and versioning;
- runtime component and package manifests;
- target-specific runtime package selection;
- compiler-produced runtime requirements;
- stable Cranelift imports of runtime-library symbols;
- Rust runtime components compiled into explicit runtime packages;
- separately compiled C runtime components retained under explicit policy;
- pure Gust runtime modules compiled through canonical MIR;
- removal of obsolete helpers;
- elimination of generated per-program C wrappers and shims;
- selected allocation and core-memory runtime operations;
- selected string runtime operations;
- selected I/O runtime operations;
- selected filesystem and resource runtime operations;
- selected threading and synchronization runtime operations where an existing semantic authority is stable;
- pre-link runtime availability and compatibility validation;
- stable runtime-boundary witnesses and diagnostics;
- target-specific runtime object or library production;
- deterministic runtime link-plan integration under Phase 9G artifact ownership.

Phase 17 must not silently absorb:

- complete replacement of every C runtime implementation;
- removal of MIR-to-C as the default differential oracle;
- arbitrary foreign-function interfaces;
- unversioned or dynamically guessed runtime imports;
- general dynamic loading or plugin discovery;
- package-manager design or distribution policy unrelated to native runtime artifacts;
- complete platform calling-convention classification;
- complete libc replacement;
- allocator design beyond explicitly selected operations;
- garbage collection;
- unrestricted shared ownership or reference counting;
- general borrow checking or alias analysis;
- complete Unicode or locale semantics;
- complete asynchronous I/O;
- sockets, processes, signals, terminals, or other OS services unless separately selected;
- complete filesystem portability;
- general atomics or concurrency semantics;
- thread cancellation or asynchronous unwinding;
- complete panic unwinding or foreign exceptions;
- linker or atomic-publication ownership already assigned to Phase 9G;
- full Gust language parity or production readiness.

Out-of-scope Phase 16 residual rows must remain deferred, be reassigned to a later phase, or be split into narrower rows. They must not be marked migrated merely because Phase 17 introduces a runtime symbol or package.

## Compiler-Owned Native Runtime Authority

Phase 17 must establish one compiler-owned native runtime service with semantic records equivalent to the following concepts.

### Runtime ABI Identity

Every selected runtime ABI has a compiler-produced identity containing:

- stable runtime ABI ID;
- ABI version;
- target triple or target class;
- data layout identity;
- calling-convention identity;
- symbol naming and versioning policy;
- compatibility policy;
- package format identity;
- minimum required component set;
- source registry row;
- diagnostic owner.

### Runtime Helper Classification

Every selected helper has exactly one compiler-owned classification record containing:

- stable helper ID;
- semantic operation identity;
- source declaration or intrinsic identity;
- helper family;
- one classification from the five Phase 17 categories;
- runtime symbol identity where retained;
- implementation component identity;
- ABI identity and version range;
- target applicability;
- side-effect and failure policy;
- resource, layout, and call-ABI dependencies;
- replacement or removal disposition;
- owning registry row;
- stable diagnostic reason codes.

No helper may be classified simultaneously as generated glue and an explicit runtime component. A retained C implementation is a separately built runtime component, never program-specific generated source.

### Runtime Symbol Identity

Every imported or exported runtime symbol has a compiler-produced identity containing:

- stable runtime symbol ID;
- semantic operation identity;
- external symbol spelling;
- symbol version;
- function ABI identity;
- parameter and result ABI records;
- linkage and visibility policy;
- defining component;
- target applicability;
- compatibility range;
- optionality policy;
- diagnostic ownership.

Raw symbol strings in backend code, generated C templates, linker command fragments, or fixture names are not semantic authority.

### Runtime Component

Every runtime component has a compiler-owned record containing:

- stable component ID;
- implementation language or form;
- source ownership;
- produced object or library kind;
- runtime ABI identity and version;
- exported symbol IDs;
- imported symbol IDs;
- target applicability;
- build authority;
- reproducibility inputs;
- compatibility constraints;
- temporary-retention policy where the component is C;
- owning registry rows.

### Runtime Package Manifest

Every explicit runtime package manifest contains:

- stable package ID;
- package format version;
- runtime ABI identity and version;
- exact target identity;
- component IDs;
- provided symbol IDs and versions;
- required external system symbols where permitted;
- object or library members;
- deterministic ordering;
- compatibility and rejection rules;
- provenance sufficient for reproducible selection;
- ownership handoff to the Phase 9G link plan.

The semantic contract is the structured manifest and compiler-owned records, not a raw file hash, archive hash, directory name, or emitted linker command.

### Runtime Requirement

Every compiled program has a compiler-produced runtime requirement set containing:

- requirement ID;
- source operation or canonical MIR operation;
- required helper ID;
- required symbol ID and accepted version range;
- required runtime ABI identity;
- target applicability;
- optional or mandatory status;
- resource, layout, and function-ABI dependencies;
- failure stage and stable diagnostic reason code.

Requirements must be deduplicated and deterministically ordered. Neither backend nor the linker driver may infer requirements by scanning generated code or unresolved symbols.

### Runtime Compatibility Decision

Every package selection records:

- requirement set identity;
- candidate package identity;
- target identity;
- compiler-required ABI version;
- package-provided ABI version;
- required and provided symbol versions;
- component availability;
- validity result;
- rejection reason;
- stable diagnostic owner.

### Runtime Link Plan

Every migrated native link plan records:

- compiler-produced program object identities;
- selected runtime package identity;
- selected runtime component objects or libraries;
- deterministic link ordering;
- required system libraries already authorized by the package manifest;
- target identity;
- compatibility decision identity;
- Phase 9G artifact and publication ownership.

The runtime service selects semantic requirements and compatible package components. Phase 9G remains responsible for executing object handling, linking, temporary cleanup, and atomic output publication.

## Request and MIR Ownership

Canonical MIR must refer to compiler-owned runtime helper and symbol identities for selected runtime-facing operations.

The native request must carry an immutable, deduplicated runtime requirement table or equivalent compiler-produced representation containing only the runtime data required by the worker.

The consumers must behave as follows:

- MIR-to-C remains an independent differential oracle and emits its own comparison artifact from compiler-produced semantics.
- Explicit Cranelift lowers runtime-facing operations to compiler-selected runtime symbol IDs and ABI records.
- The native link path combines compiler-produced native objects with an explicitly selected compatible runtime package.
- No Cranelift/native request may trigger generation or compilation of an ad hoc C wrapper or shim.
- Rust runtime code is compiled as a declared runtime component, not embedded into compiler-generated program code.
- Retained C runtime code is compiled separately as a declared runtime component, not synthesized from the input program.
- Pure Gust runtime code is compiled through the generic source-to-canonical-MIR route and packaged as a declared runtime component.
- Neither backend may independently choose a helper classification, symbol spelling, version, package, compatibility policy, or link order.
- Diagnostics query the compiler runtime service and report the same requirement or compatibility decision consumed by native lowering and linking.
- Generated views derive active rows, helper categories, symbol versions, component kinds, targets, totals, families, and dispositions from structured authorities.

No raw registry hash, MIR hash, generated-C hash, object hash, archive hash, Markdown hash, or emitted-link-command hash becomes a semantic contract.

## Architectural Invariants

Every Phase 17 patch must preserve:

- MIR-to-C as the default backend and differential oracle until a separate roadmap patch explicitly changes that role;
- explicit Cranelift selection with no fallback;
- generic source-to-canonical-MIR routing;
- no exact-source, filename, fixture-name, literal, symbol-output, object-output, or linker-output recognizer;
- compiler-owned source interpretation;
- compiler-owned type and target layout authority from Phase 14;
- compiler-owned resource and cleanup authority from Phase 15;
- compiler-owned function ABI and call-plan authority from Phase 16;
- one compiler-owned native runtime authority;
- exactly one Phase 17 classification for every selected C-dependent helper;
- no backend-local runtime ABI table;
- no backend-local runtime package selector;
- no linker-driven discovery of semantic runtime requirements;
- no generated per-program C shim in an explicit Cranelift/native link path;
- worker input limited to request data, canonical MIR, and compiler-produced layout, resource, ABI, and runtime data;
- capability and deferral decisions before native driver or artifact access;
- runtime package compatibility validation before linker invocation and output replacement;
- Phase 9G ownership of object handling, linking, temporary cleanup, and atomic publication;
- preservation of an existing output on deferral, incompatibility, or failure;
- deterministic registry and generated projections;
- registry-derived CI families;
- separate Level 1, Level 2, and Level 3 ownership;
- no exact CI matrix total treated as backend correctness;
- no claim that Phase 17 completes the runtime, FFI, allocation, concurrency, platform, or production inventory.

## Verification Policy

### Level 1 — Fast Contracts

Level 1 guards may validate:

- Phase 16 semantic closure availability;
- Phase 17 opening and parent traceability;
- canonical registry schema and semantic state;
- compiler-owned runtime ABI and helper-classification APIs;
- runtime symbol identity and version records;
- runtime component and package manifest schemas;
- canonical MIR runtime operation ownership;
- native request runtime requirement ownership;
- deterministic requirement deduplication and ordering;
- target-specific package selection rules;
- runtime compatibility decisions;
- stable missing or incompatible runtime diagnostics;
- generated projection freshness;
- no generated C shim in the explicit Cranelift/native path;
- no backend-local runtime package selector;
- no fallback;
- worker isolation;
- early deferral;
- output preservation;
- Phase 9G link-plan handoff;
- manifest and route architecture;
- CI-family projection;
- test-level and workflow ownership;
- residue and closure summaries.

Level 1 guards must not build every target runtime package, replay every helper program, run every target runner, inspect every archive member, or execute the full historical suite.

### Level 2 — Focused Differential Families

Level 2 evidence validates bounded migrated behavior on the primary PR host through registry-derived families.

A proposed initial family vocabulary is:

- `runtime-abi`;
- `runtime-symbols`;
- `runtime-packages`;
- `runtime-imports`;
- `runtime-rust-components`;
- `runtime-c-components`;
- `runtime-gust-components`;
- `runtime-allocation-strings`;
- `runtime-io-filesystem`;
- `runtime-resources`;
- `runtime-threading`;
- `runtime-diagnostics`.

The active family set and count must be derived from the canonical registry. The workflow must not hard-code one matrix row per patch, helper, symbol, component, or target.

For each applicable case, Level 2 should compare:

- default MIR-to-C;
- explicit MIR-to-C;
- explicit Cranelift using native program objects and an explicit runtime package;
- runtime values;
- stdout and stderr where declared stable;
- exit status;
- selected memory, filesystem, resource, and thread effects;
- runtime requirement witnesses;
- selected package and component witnesses;
- symbol identity and version witnesses;
- link-plan witnesses;
- stable missing or incompatible runtime diagnostics;
- preservation of sentinel output on failure.

Default and explicit MIR-to-C output should remain byte-identical for the same target and source where the existing differential contract requires it. The explicit Cranelift result must not include or depend on a program-generated C shim.

### Level 3 — Historical and Complete Runtime Evidence

Cranelift Historical Full remains the sole Level 3 owner.

It owns:

- complete Phase 9–17 historical replay;
- the complete registry-derived Phase 17 differential inventory;
- representative runtime-boundary programs across every declared applicable target;
- target-specific runtime package build and selection evidence;
- runtime package reproducibility evidence;
- complete selected helper-domain evidence;
- platform-specific runtime symbol and package evidence where behavior differs;
- all historical native runtime fixtures;
- complete object, link, cleanup, and publication failure matrices owned by Phase 9G;
- packaging and reproducibility evidence;
- representative long-running I/O, filesystem, resource, and threading programs where selected.

Phase 17 opening and closure guards validate that the Level 3 suite remains available, registry-derived, and separately runnable. They do not execute it.

## Standard Definition of Done for Every Phase 17 Capability Patch

A Phase 17 capability is migrated only when all of the following are true:

- The supported source shape is precisely bounded.
- The supported canonical-MIR shape is precisely bounded.
- The owning canonical registry row is identified.
- The owning target set is explicit or derived.
- Every selected helper has exactly one Phase 17 classification.
- Every retained helper has a compiler-owned semantic operation identity.
- Every imported or exported helper has a compiler-owned symbol ID and version.
- Every implementation belongs to an explicit runtime component.
- Every component belongs to a compatible target-specific runtime package.
- A real source fixture lowers through the generic producer.
- A compiler-owned canonical-MIR fixture exists where applicable.
- The compiler runtime service returns the required helper, symbol, component, package, requirement, and compatibility records.
- The compiler layout, resource, and function ABI services return the required dependent records.
- Canonical MIR references compiler-produced runtime identities rather than raw backend symbol guesses.
- The native request carries the required deduplicated runtime requirements.
- Request validation rejects missing, duplicate, conflicting, unknown, or target-incompatible runtime metadata.
- Explicit Cranelift imports the compiler-selected symbol using the compiler-selected ABI.
- The explicit native link path uses native program objects plus an explicit runtime package.
- No program-specific C wrapper or shim is generated, compiled, or linked for the migrated capability.
- Any retained C implementation is separately compiled as a declared runtime component.
- Any Rust implementation is compiled as a declared runtime component.
- Any pure Gust implementation passes through generic canonical MIR and is packaged as a declared runtime component.
- Any obsolete helper is removed from producers, consumers, package manifests, and generated views.
- Diagnostics report the same runtime requirement and compatibility decisions used by lowering and linking.
- No consumer independently guesses helper classification, symbol spelling, symbol version, package, component, compatibility, or link order.
- Default and explicit MIR-to-C remain equivalent where the existing contract applies.
- MIR-to-C and explicit Cranelift native behavior are compared.
- Runtime requirement, package, symbol, and link-plan witnesses are compared where observable.
- Malformed and unavailable cases have stable diagnostics.
- Unsupported cases remain explicitly deferred.
- Deferred and invalid cases stop at their declared early failure stage before prohibited native-driver or artifact access.
- Missing or incompatible runtime packages stop before linker invocation and output replacement.
- Existing output survives deferral and failure.
- Phase 9G still owns object handling, linking, temporary cleanup, and atomic publication.
- The worker still receives only request data, canonical MIR, and compiler-produced layout, resource, ABI, and runtime metadata.
- The registry row is updated using the existing status vocabulary.
- Generated projections are refreshed.
- The owning CI family contains focused evidence.
- At least one appropriate composition relationship exists.
- No exact-source, generated-wrapper, object-output, or linker-output recognizer was introduced.
- Explicit Cranelift still cannot fall back to MIR-to-C.
- The new guards are assigned to the correct test level.

## Patch Sequence

### Patch 17.0 — Opening Inventory and Phase 16 Residual Rebase

**Purpose**

Establish the exact Phase 17 input from the closed Phase 16 state without changing compiler, backend, runtime, or artifact behavior.

**Steps**

- Add a semantic Phase 17 opening snapshot to the canonical registry.
- Preserve parent traceability to:
  - Phase 16 migrated runtime-related rows;
  - Phase 16 residual capability IDs;
  - explicit Phase 17 planning categories.
- Inventory every C-dependent helper reachable from compiler-generated code, Cranelift lowering, native runtime code, and link plans.
- Select only runtime-boundary, helper-classification, symbol-versioning, package, and generated-shim rows owned by this phase.
- Split broad residuals where one Phase 16 row contains both:
  - runtime ABI or runtime-package work owned by Phase 17; and
  - FFI, dynamic loading, allocator policy, GC, concurrency semantics, platform ABI, distribution, or linker work owned later.
- Keep out-of-scope rows deferred and explicitly assign their destination phases.
- Add stable Phase 17 rows for:
  - runtime ABI authority;
  - helper classification;
  - runtime symbols and versions;
  - runtime requirement transport;
  - target-specific runtime packages;
  - stable runtime-library imports;
  - Rust runtime components;
  - retained C runtime components;
  - pure Gust runtime components;
  - obsolete helper removal;
  - generated C shim elimination;
  - allocation and string helpers;
  - I/O, filesystem, and resource helpers;
  - threading and synchronization helpers;
  - runtime availability and compatibility diagnostics;
  - complete runtime differential evidence.
- Require each opening row to contain:
  - stable ID;
  - parent;
  - feature family;
  - CI family;
  - capability owner;
  - diagnostic owner;
  - helper category where applicable;
  - target applicability;
  - status;
  - current failure stage;
  - positive future fixture;
  - negative current fixture.
- Freeze the initial registry-derived Phase 17 CI-family projection.
- Generate the Phase 17 opening review view.
- Add `guard-cranelift-phase17-opening-contract`.

**Test Level**

Level 1.

**Exit Gate**

Every declared Phase 17 row has a stable parent, owner, target scope, failure stage, fixture pair, and initial disposition. Every selected C-dependent helper has an inventory owner, and non-runtime Phase 16 residuals remain explicitly outside Phase 17.

### Patch 17.1 — Compiler-Owned Runtime Boundary and Helper Classification Authority

**Purpose**

Create the single runtime-boundary decision path consumed by canonical MIR, Cranelift, runtime packaging, diagnostics, and Phase 9G link planning.

**Steps**

- Add compiler-owned semantic types equivalent to:
  - runtime ABI identity;
  - runtime helper identity;
  - helper classification;
  - runtime component identity;
  - runtime package identity;
  - runtime requirement;
  - runtime compatibility decision;
  - runtime link-plan handoff.
- Freeze the five legal helper classifications.
- Require exactly one classification for every selected helper.
- Give each request-local requirement and compatibility decision a deterministic identity derived from compiler state rather than raw hashes.
- Add compiler-owned queries equivalent to:
  - `runtime_helper_of(operation)`;
  - `classify_runtime_helper(helper)`;
  - `runtime_requirements(program)`;
  - `runtime_component_for(helper, target)`;
  - `select_runtime_package(requirements, target)`;
  - `validate_runtime_compatibility(requirements, package)`;
  - `runtime_link_plan(program, package)`.
- Require conflicting, missing, or multi-category classifications to reject with stable diagnostics.
- Add a reduced generated runtime-boundary review view.
- Add hard bans proving:
  - Cranelift does not own a separate helper-classification table;
  - the worker does not invent runtime requirements;
  - the native driver does not select packages from unresolved symbols;
  - diagnostics do not recompute runtime compatibility independently.
- Add `guard-cranelift-phase17-runtime-authority-contract`.

**Test Level**

Level 1.

**Boundary**

This patch establishes authority and classification. It does not by itself migrate every helper implementation.

**Exit Gate**

Every later Phase 17 patch can migrate one bounded helper or runtime component by extending the compiler-owned authority and existing request path without adding backend-local or linker-local runtime semantics.

### Patch 17.2 — Supported Runtime ABI, Symbol Identity, and Versioning

**Purpose**

Define the supported native runtime ABI and make runtime symbols stable, versioned compiler-owned identities.

**Steps**

- Freeze the selected runtime ABI inventory by target.
- Define:
  - runtime ABI IDs and versions;
  - symbol naming and versioning rules;
  - calling-convention linkage to Phase 16;
  - layout linkage to Phase 14;
  - resource-operation linkage to Phase 15;
  - compatibility ranges;
  - required versus optional symbols;
  - visibility and linkage policy.
- Add compiler-owned symbol records for every selected imported or exported runtime operation.
- Require each symbol to identify:
  - semantic helper operation;
  - external spelling;
  - symbol version;
  - defining component;
  - function ABI identity;
  - target applicability;
  - compatibility policy.
- Reject:
  - unknown runtime ABI IDs;
  - unversioned selected symbols;
  - duplicate conflicting symbol records;
  - symbol spelling reused for incompatible ABIs;
  - incompatible calling conventions;
  - target or layout mismatches;
  - backend-local raw symbol substitutions.
- Add stable witnesses for runtime ABI and symbol decisions.
- Add `guard-cranelift-phase17-runtime-symbol-version-contract`.

**Test Level**

Level 1.

**Exit Gate**

Every selected runtime call resolves to one compiler-owned, versioned symbol whose target, layout, and function ABI are explicit and compatible.

### Patch 17.3 — Runtime Requirements in Canonical MIR and Native Requests

**Purpose**

Carry compiler-produced runtime requirements through canonical MIR and the native request without backend or linker inference.

**Steps**

- Add canonical MIR runtime operations or associated metadata referencing:
  - helper ID;
  - symbol ID;
  - runtime ABI ID;
  - required version range;
  - target applicability;
  - relevant layout, resource, and call-ABI identities.
- Extend the native request with a deterministic, deduplicated runtime requirement table.
- Preserve requirement identity through:
  - direct calls;
  - selected indirect runtime calls already supported by Phase 16;
  - cleanup and destructor operations;
  - cross-module composition;
  - selected runtime module calls.
- Require request deserialization to reject:
  - unknown helper or symbol IDs;
  - duplicate conflicting requirements;
  - MIR runtime operations missing requirements;
  - requirements unused by canonical MIR unless explicitly package-mandatory;
  - incompatible symbol versions;
  - target, layout, resource, or ABI mismatches;
  - helper classification inconsistent with the selected symbol or component.
- Prove the worker validates consistency but cannot invent missing runtime ownership semantics.
- Add `guard-cranelift-phase17-runtime-requirement-contract`.

**Test Level**

Level 1.

**Exit Gate**

Every selected runtime-facing MIR operation carries one validated compiler-produced requirement, and malformed runtime metadata is rejected without backend or linker inference.

### Patch 17.4 — Explicit Runtime Packages and Target-Specific Selection

**Purpose**

Produce and select explicit target-specific runtime packages containing the declared runtime components needed by migrated native programs.

**Steps**

- Freeze the runtime package manifest schema.
- Define package identities by runtime ABI version and exact target applicability.
- Define supported package forms such as:
  - static archive;
  - deterministic object set;
  - another explicitly selected native library form.
- Require every package to enumerate:
  - components;
  - provided symbols and versions;
  - permitted system imports;
  - target identity;
  - runtime ABI identity;
  - deterministic link order;
  - compatibility constraints.
- Produce target-specific runtime objects or libraries through a declared build authority.
- Make package selection a compiler-owned compatibility decision.
- Keep execution of the selected link plan under Phase 9G.
- Reject:
  - ambiguous package selection;
  - packages for the wrong target;
  - duplicate conflicting components;
  - missing mandatory symbols;
  - incompatible runtime ABI versions;
  - undeclared archive members or system imports;
  - non-deterministic component ordering.
- Add generated package and target review views.
- Add `guard-cranelift-phase17-runtime-package-contract`.

**Test Level**

Level 1.

**Exit Gate**

Every migrated native target has an explicit, deterministic runtime package selection whose manifest satisfies the compiler-produced runtime requirements before the link plan is executed.

### Patch 17.5 — Stable Runtime-Library Imports for Cranelift

**Purpose**

Migrate helpers classified as stable runtime-library functions to direct, versioned Cranelift imports.

**Steps**

- Freeze the selected stable-import helper inventory.
- For each selected helper, define:
  - helper ID;
  - symbol ID and version;
  - Phase 16 function ABI identity;
  - defining runtime component;
  - target applicability;
  - side-effect and failure policy.
- Make Cranelift declare and call the compiler-selected external symbol directly.
- Prohibit raw backend-maintained symbol spelling or signature tables.
- Ensure the runtime package exports the required symbol and version.
- Add positives for representative stable imports.
- Add negatives for:
  - missing symbols;
  - incompatible versions;
  - ABI mismatch;
  - wrong target component;
  - undeclared imports.
- Compare runtime behavior and symbol/package witnesses with MIR-to-C.
- Add:
  - `guard-cranelift-phase17-runtime-import-contract`;
  - `guard-cranelift-phase17-runtime-import-parity`.

**Test Levels**

Contract: Level 1.

Parity: Level 2.

**Exit Gate**

Every selected stable runtime-library helper is called by Cranelift through its compiler-owned versioned symbol and explicit runtime package, without generated C glue.

### Patch 17.6 — Rust Runtime Components and Native Object Integration

**Purpose**

Support selected runtime helpers implemented in Rust as explicit, versioned runtime package components.

**Steps**

- Freeze the selected Rust runtime component inventory.
- Define each Rust component's:
  - component ID;
  - source ownership;
  - exported and imported symbol IDs;
  - runtime ABI version;
  - target applicability;
  - object or library form;
  - panic and failure boundary;
  - allocation and ownership boundary.
- Compile Rust runtime components independently from program compilation.
- Require stable ABI-facing exports; Rust-internal symbol mangling is not a runtime contract.
- Package produced objects or libraries through the Phase 17 manifest.
- Hand the selected component to Phase 9G without bypassing artifact ownership.
- Reject:
  - undeclared Rust exports;
  - unwinding across an unsupported runtime boundary;
  - ABI or target mismatch;
  - duplicate symbol providers;
  - hidden dependency on generated C glue.
- Add focused runtime and failure parity evidence.
- Add:
  - `guard-cranelift-phase17-rust-runtime-contract`;
  - `guard-cranelift-phase17-rust-runtime-parity`.

**Test Levels**

Contract: Level 1.

Parity: Level 2.

**Exit Gate**

Every selected Rust runtime helper is supplied by an explicit compatible runtime component and linked into migrated native programs without source-specific C generation.

### Patch 17.7 — Explicit Retained C Runtime Objects

**Purpose**

Retain selected C runtime implementations temporarily without allowing C generation to remain an implicit per-program implementation layer.

**Steps**

- Freeze the exact retained C helper and component inventory.
- Require each retained C component to have:
  - a stable component ID;
  - explicit owned source files;
  - exported and imported versioned symbol IDs;
  - runtime ABI identity;
  - target applicability;
  - independent build inputs;
  - a concrete retention reason;
  - a destination phase or removal criterion.
- Compile retained C components independently of user-program compilation.
- Prohibit generated headers, wrapper bodies, or source fragments derived from a program's canonical MIR.
- Package retained C objects or libraries through the same manifest path as Rust and Gust components.
- Reject:
  - anonymous or unclassified C objects;
  - program-specific C source generation;
  - unversioned exports;
  - hidden target assumptions;
  - duplicate providers;
  - direct linker inclusion outside the selected runtime package.
- Compare observable behavior through MIR-to-C and explicit Cranelift.
- Add:
  - `guard-cranelift-phase17-retained-c-runtime-contract`;
  - `guard-cranelift-phase17-retained-c-runtime-parity`.

**Test Levels**

Contract: Level 1.

Parity: Level 2.

**Exit Gate**

Every selected retained C implementation is a separately compiled, versioned, target-scoped runtime component; no retained C source is generated from the compiled program or used as an implicit Cranelift shim.

### Patch 17.8 — Pure Gust Runtime Modules Compiled Through MIR

**Purpose**

Support selected runtime helpers written in Gust and compiled through the same generic canonical-MIR route as other Gust code.

**Steps**

- Freeze the selected pure Gust runtime module inventory.
- Require each module to declare:
  - component ID;
  - exported and imported helper and symbol IDs;
  - runtime ABI version;
  - target applicability;
  - allowed dependencies;
  - initialization and failure policy.
- Compile runtime Gust source through generic parsing, typechecking, canonical MIR, ABI, and Cranelift lowering.
- Prohibit exact-source or runtime-module-name recognition in the compiler or backend.
- Package the resulting native objects as explicit runtime components.
- Prevent recursive dependence on an unavailable version of the same runtime component.
- Reject:
  - non-generic lowering paths;
  - missing runtime requirements;
  - circular component dependencies without an explicit selected policy;
  - ABI or target mismatch;
  - hidden generated C compilation.
- Compare behavior against MIR-to-C where the oracle route supports the selected module.
- Add:
  - `guard-cranelift-phase17-gust-runtime-contract`;
  - `guard-cranelift-phase17-gust-runtime-parity`.

**Test Levels**

Contract: Level 1.

Parity: Level 2.

**Exit Gate**

Every selected pure Gust runtime helper is compiled through generic canonical MIR and supplied as an explicit native runtime package component, without bespoke compiler recognition or generated C glue.

### Patch 17.9 — Generated C Shim Elimination and Obsolete Helper Removal

**Purpose**

Remove generated ad hoc C wrappers from the migrated native path and remove helpers classified as obsolete.

**Steps**

- Inventory every path that can emit, compile, or link C during explicit Cranelift/native compilation.
- Distinguish:
  - independent MIR-to-C oracle output;
  - separately compiled retained C runtime components;
  - forbidden program-specific C wrappers or shims.
- Remove native-path generation of:
  - runtime call wrappers;
  - ABI adaptation wrappers;
  - resource or cleanup wrappers;
  - allocation or string helper wrappers;
  - I/O, filesystem, or threading wrappers;
  - target-selection wrapper fragments.
- Replace each removed wrapper with a compiler-owned direct import, explicit runtime component, or narrower deferral.
- Remove obsolete helpers from:
  - canonical producers;
  - Cranelift lowering;
  - runtime manifests;
  - link plans;
  - generated views;
  - focused fixtures.
- Add hard bans against native request fields or worker code that transport or synthesize C wrapper source.
- Add evidence that explicit Cranelift succeeds with the C compiler unavailable when all selected package components are already built.
- Preserve MIR-to-C as a separately invoked oracle path.
- Add:
  - `guard-cranelift-phase17-no-generated-c-shim-contract`;
  - `guard-cranelift-phase17-no-generated-c-shim-parity`.

**Test Levels**

Contract: Level 1.

Parity: Level 2.

**Exit Gate**

Migrated explicit Cranelift programs generate and link no program-specific C source. The only permitted C is independently built, explicitly manifested runtime code, and every obsolete helper has been removed from active ownership paths.

### Patch 17.10 — Allocation, String, and Core Memory Runtime Audit

**Purpose**

Classify and migrate the selected allocation, core-memory, and string helper inventory through the explicit native runtime boundary.

**Scope-Selection Rule**

Before implementation, freeze the exact selected operations and distinguish semantic compiler intrinsics from runtime calls. General allocator policy, garbage collection, complete Unicode, and locale behavior remain deferred unless separately selected.

**Steps**

- Audit selected helpers for:
  - allocation and deallocation;
  - reallocation where already supported;
  - memory copy, move, set, and comparison;
  - bounds or failure reporting;
  - string creation, length, comparison, concatenation, conversion, and destruction where supported.
- Classify every selected helper into exactly one Phase 17 category.
- Define symbol, ABI, ownership, allocation-domain, failure, and target contracts.
- Preserve Phase 14 layout and Phase 15 resource obligations.
- Prevent allocation or ownership from crossing incompatible runtime component boundaries.
- Add positives for selected ordinary and failure behavior.
- Add negatives for:
  - missing allocation helpers;
  - incompatible allocator domains;
  - invalid string layout;
  - wrong symbol versions;
  - unsupported target operations;
  - hidden generated C wrappers.
- Compare values, memory effects, diagnostics, and cleanup where stable.
- Keep unselected helper kinds as concrete deferred rows.
- Add:
  - `guard-cranelift-phase17-allocation-string-runtime-contract`;
  - `guard-cranelift-phase17-allocation-string-runtime-parity`.

**Test Levels**

Contract: Level 1.

Parity: Level 2.

**Exit Gate**

Every selected allocation, core-memory, and string operation uses its classified explicit runtime path with compatible ABI, layout, ownership, and observable behavior through both backends.

### Patch 17.11 — I/O, Filesystem, and Resource Runtime Audit

**Purpose**

Classify and migrate selected I/O, filesystem, directory, and resource helpers through explicit runtime packages.

**Scope-Selection Rule**

Before implementation, freeze the exact selected operations, resource kinds, error forms, filesystem effects, and target applicability. Sockets, processes, terminals, and unrelated OS resources remain deferred unless explicitly selected.

**Steps**

- Audit selected helpers for:
  - standard input, output, and error;
  - file or stream operations already supported;
  - path and filesystem operations;
  - directory acquisition, iteration, close, and cleanup;
  - Phase 15 selected specialized resources;
  - stable error reporting.
- Classify every selected helper into exactly one Phase 17 category.
- Map resource-bearing helpers to Phase 15 identities, transitions, close capabilities, and cleanup obligations.
- Define symbol, ABI, failure, target, and filesystem-effect contracts.
- Ensure manual close and deferred cleanup call the same compiler-selected runtime operations.
- Add positives for acquisition, use, move, close, normal cleanup, and early cleanup where applicable.
- Add negatives for:
  - missing or incompatible runtime symbols;
  - wrong resource kind;
  - destructor or close mismatch;
  - duplicate close;
  - unsupported target or runtime availability;
  - hidden generated C wrappers.
- Compare stable stdout, stderr, exit status, close/destructor counts, and selected filesystem effects.
- Keep unselected helper and resource kinds as concrete deferred rows.
- Add:
  - `guard-cranelift-phase17-io-filesystem-resource-runtime-contract`;
  - `guard-cranelift-phase17-io-filesystem-resource-runtime-parity`.

**Test Levels**

Contract: Level 1.

Parity: Level 2.

**Exit Gate**

Every selected I/O, filesystem, directory, and resource helper uses an explicit classified runtime component while preserving compiler-owned resource semantics and equivalent observable behavior.

### Patch 17.12 — Threading and Synchronization Runtime Audit

**Purpose**

Classify and migrate the bounded threading and synchronization helper inventory for which the current compiler and runtime provide stable semantic authority.

**Scope-Selection Rule**

Before implementation, freeze the selected operations, memory-order assumptions, lifetime constraints, failure policy, and target applicability. This patch does not claim complete concurrency, atomics, cancellation, scheduling, or race-safety semantics.

**Steps**

- Audit selected helpers for:
  - thread creation and join where already supported;
  - mutex or lock operations where already supported;
  - thread-local or synchronization helpers already represented by stable compiler semantics;
  - selected failure and cleanup operations.
- Classify every selected helper into exactly one Phase 17 category.
- Define symbol, ABI, resource-lifetime, failure, and target contracts.
- Preserve Phase 15 ownership and cleanup for selected thread or lock resources.
- Require explicit runtime package dependencies for platform thread libraries where permitted.
- Reject:
  - unsupported targets;
  - missing thread runtime components;
  - ABI or symbol-version mismatch;
  - undeclared system-library dependencies;
  - unsupported cancellation or unwind behavior;
  - hidden generated C wrappers.
- Compare bounded deterministic effects and diagnostics; do not make scheduler ordering a stable oracle unless explicitly selected.
- Keep atomics, unrestricted sharing, cancellation, and broader concurrency semantics deferred as concrete rows.
- Add:
  - `guard-cranelift-phase17-threading-runtime-contract`;
  - `guard-cranelift-phase17-threading-runtime-parity`.

**Test Levels**

Contract: Level 1.

Parity: Level 2.

**Exit Gate**

Every selected threading or synchronization helper uses a classified, versioned, target-compatible runtime component without generated C glue, while broader concurrency semantics remain explicitly deferred.

### Patch 17.13 — Runtime Availability, Compatibility, and Diagnostic Enforcement

**Purpose**

Validate runtime package availability and compatibility before linking, with stable diagnostics and output preservation.

**Steps**

- Freeze the runtime availability and compatibility decision order.
- Validate:
  - package manifest format;
  - runtime ABI identity and version;
  - target identity;
  - required component presence;
  - required symbol presence and version;
  - function ABI, layout, and resource compatibility;
  - declared system-library requirements;
  - deterministic component and link ordering.
- Distinguish stable rejection classes for:
  - runtime package missing;
  - manifest malformed;
  - wrong target;
  - runtime ABI incompatible;
  - component missing;
  - symbol missing;
  - symbol version incompatible;
  - helper classification inconsistent;
  - link-plan dependency undeclared.
- Require compiler-semantic requirement validation before worker execution.
- Require package availability and compatibility validation after target selection but before linker invocation, temporary link output creation, or output replacement.
- Ensure the worker and Phase 9G code validate supplied decisions without inventing replacement packages or fallback helpers.
- Add malformed and unavailable package fixtures for every rejection class.
- Add poisoned-linker and sentinel-output evidence.
- Preserve stable diagnostic reason codes and relevant requirement, symbol, expected-version, provided-version, target, and package identities.
- Add:
  - `guard-cranelift-phase17-runtime-availability-contract`;
  - `guard-cranelift-phase17-runtime-availability-parity`.

**Test Levels**

Contract: Level 1.

Focused failure evidence: Level 2.

**Exit Gate**

Missing, malformed, or incompatible runtime packages and symbols fail with compiler-owned stable diagnostics before linker invocation and output replacement, without fallback or loss of an existing output.

### Patch 17.14 — Cross-Feature Runtime Composition and Complete Differential

**Purpose**

Prove that migrated Phase 17 runtime capabilities compose and that native program objects plus explicit runtime packages agree with the MIR-to-C oracle.

**Steps**

- Generate the active Phase 17 differential inventory from canonical registry ownership.
- Do not maintain an unrelated hand-written helper, symbol, component, target, or family list.
- Add representative composed programs combining:
  - versioned stable runtime imports;
  - Rust runtime components;
  - retained C runtime components;
  - pure Gust runtime components;
  - allocation and strings;
  - I/O and filesystem operations;
  - resource move, close, and cleanup;
  - selected threading operations;
  - aggregate and resource-bearing calls from Phase 16;
  - runtime availability and compatibility failures.
- Include nested combinations such as:
  - allocation followed by string formatting and output;
  - a resource-bearing aggregate passed across a runtime call;
  - directory acquisition, branch use, early return, and cleanup;
  - a pure Gust runtime helper calling a stable imported symbol;
  - Rust and retained C components in one package without duplicate providers;
  - a selected thread helper using resource cleanup;
  - a compatible package chosen from target-specific candidates;
  - an incompatible symbol version preserving sentinel output.
- For each applicable case on the primary Level 2 host, run:
  - default MIR-to-C;
  - explicit MIR-to-C;
  - explicit Cranelift with native objects plus the selected runtime package.
- Require default and explicit MIR-to-C output to remain byte-identical where the existing contract applies.
- Prove the explicit Cranelift link plan contains no generated C shim artifact.
- Compare:
  - runtime values;
  - stdout and stderr where stable;
  - exit status;
  - runtime requirements;
  - selected helper classifications;
  - symbol IDs and versions;
  - package and component identities;
  - link ordering;
  - selected memory, filesystem, resource, and thread effects;
  - preservation of sentinel output on failure.
- Add at least one composition case per active Phase 17 CI family.
- Ensure every migrated Phase 17 row has:
  - individual focused evidence;
  - at least one composition relationship;
  - a differential case owner;
  - target applicability.
- Keep the Phase 17 closure guard static and lightweight.
- Assign:
  - primary-host focused composition to Level 2;
  - complete historical and applicable-target runtime evidence to Level 3.
- Add:
  - `guard-cranelift-phase17-composition-contract`;
  - `guard-cranelift-phase17-composition-differential`;
  - `guard-cranelift-phase17-complete-runtime-evidence`.

**Test Levels**

Composition contract: Level 1.

Focused composition differential: Level 2.

Complete historical/applicable-target evidence: Level 3.

**Exit Gate**

Every migrated Phase 17 row has individual and composed evidence, and representative programs link from native program objects plus an explicit runtime package with behavior equivalent to MIR-to-C and no generated C shim.

### Patch 17.15 — Deferred Residue and Runtime-Coverage Audit

**Purpose**

Eliminate broad or ambiguous runtime, helper, symbol, package, and generated-C deferrals before Phase 17 closure.

**Steps**

- Audit every Phase 17 opening row and every inventoried C-dependent helper.
- Require every row and helper to finish as one of:
  - migrated under exactly one Phase 17 classification;
  - explicitly excluded;
  - removed as obsolete;
  - replaced by one or more narrower deferred rows.
- Reject broad residual descriptions such as:
  - more runtime work;
  - more C helpers;
  - more native libraries;
  - more ABI work;
  - more I/O;
  - more threading;
  - wrappers later;
  - platform support later.
- Replace broad residue with concrete capabilities such as:
  - complete C backend retirement;
  - remaining named C runtime component retirement;
  - shared or dynamically loaded runtime libraries;
  - runtime package distribution and installation;
  - runtime package signing or provenance verification;
  - foreign-function ABI adapters;
  - foreign callbacks;
  - allocator replacement or multiple allocator domains;
  - garbage collection;
  - complete Unicode and locale runtime;
  - asynchronous I/O;
  - sockets;
  - subprocesses;
  - signals and terminal control;
  - file-handle resources;
  - socket resources;
  - process resources;
  - atomics and memory ordering;
  - lock-guard semantics;
  - thread cancellation cleanup;
  - complete panic unwinding;
  - foreign exception boundaries;
  - platform-specific runtime helpers for named targets.
- Require every remaining deferred row to contain:
  - stable ID;
  - specific capability owner;
  - diagnostic owner;
  - concrete reason;
  - destination phase;
  - prerequisite capability;
  - current failure stage;
  - target applicability;
  - positive future fixture;
  - negative current fixture;
  - stable diagnostic reason code;
  - source Phase 17 row IDs and helper IDs.
- Confirm no Phase 16 residual assigned to Phase 17 remains unchanged and ambiguous.
- Confirm every inherited row has migrated, been excluded with justification, been removed as obsolete, or been replaced by smaller actionable rows.
- Confirm every selected helper domain and applicable target is supported, explicitly excluded with justification, or represented by a narrower deferred row.
- Confirm every retained C component has a concrete removal or reassessment destination.
- Derive final totals from the registry.
- Generate the final Phase 17 review view.
- Freeze the residual inventory semantically as input to later phases.
- Add `guard-cranelift-phase17-deferred-residue-audit`.

**Test Level**

Level 1.

**Exit Gate**

Every Phase 17 item and inventoried C-dependent helper has migrated, been excluded or removed with justification, or become a smaller actionable future-phase entry; runtime component and target coverage is explicit.

### Patch 17.16 — Phase 17 Closure

**Purpose**

Close only the declared Phase 17 native runtime-boundary inventory.

The closure must not claim complete runtime reimplementation, complete standard-library support, complete C removal, complete FFI, complete allocation, complete concurrency, complete platform support, or production readiness.

**Closure Guard**

Add `guard-cranelift-phase17-close` and register it as a Level 1 guard.

**Required Contracts**

The closure guard must require:

- the semantic Phase 16 closure summary;
- the Phase 17 opening contract;
- the canonical registry schema;
- the canonical registry projection guard;
- the Phase 17 parent-traceability contract;
- the compiler-owned runtime authority contract;
- the runtime ABI and symbol-version contract;
- the canonical MIR and native-request runtime requirement contract;
- the explicit runtime package contract;
- the stable runtime-import contract;
- the Rust runtime component contract;
- the retained C runtime component contract;
- the pure Gust runtime component contract;
- the no-generated-C-shim contract;
- the allocation, string, and core-memory runtime contract;
- the I/O, filesystem, and resource runtime contract;
- the threading and synchronization runtime contract;
- the runtime availability and compatibility contract;
- the deferred residue audit;
- the registry-derived Phase 17 CI-family projection;
- the semantic route architecture contract;
- the reduced manifest architecture contract through its canonical validator;
- the three-level test mapping and workflow ownership checks;
- the Phase 17 generated-view projection;
- the Phase 17 registry differential wiring;
- the separately runnable Level 3 historical and complete runtime suite;
- the Phase 14 layout ownership contract;
- the Phase 15 resource ownership contract;
- the Phase 16 function ABI ownership contract;
- the Phase 9G artifact ownership contract;
- MIR-to-C default ownership;
- explicit Cranelift no-fallback policy;
- worker request isolation;
- early deferral and output-preservation contracts.

**Closure Assertions**

The closure guard must prove:

- every Phase 17 opening row has a valid final disposition;
- every selected C-dependent helper has exactly one final classification or an explicit obsolete/excluded disposition;
- every migrated helper uses generic canonical-MIR routing and compiler-owned runtime requirements;
- every migrated runtime call has a compiler-owned ABI, symbol identity, and version;
- every migrated runtime implementation belongs to an explicit component and package;
- every runtime package is target-specific and compatibility-validated;
- explicit Cranelift consumes the compiler-produced runtime requirement and symbol data;
- diagnostics consume the same runtime availability and compatibility decisions;
- no exact-source, helper-name, fixture-name, generated-wrapper, object-output, or linker-output recognizer was introduced;
- no backend-local runtime ABI or package authority exists;
- no native linker step infers semantic requirements from unresolved symbols;
- no migrated explicit Cranelift program generates or links an ad hoc C shim;
- retained C implementations are separately built explicit runtime components;
- Rust implementations are separately built explicit runtime components;
- pure Gust runtime implementations pass through generic canonical MIR;
- obsolete helpers are absent from active producers, consumers, packages, and views;
- explicit Cranelift cannot fall back to MIR-to-C;
- unsupported cases stop at their declared early failure stage;
- missing or incompatible runtime packages stop before linker invocation and output replacement;
- MIR-to-C remains the default oracle and is not part of the explicit Cranelift link path;
- default and explicit MIR-to-C remain equivalent where required;
- the worker receives only request data, canonical MIR, and compiler-produced layout, resource, ABI, and runtime data;
- Phase 9G still owns object handling, linking, temporary cleanup, and publication;
- active totals, helper categories, symbols, versions, components, packages, targets, and families are registry-derived;
- generated views are current;
- CI families remain registry-derived;
- no raw registry, MIR, generated-C, object, archive, linker-command, or Markdown hash contract exists;
- no exact matrix total is treated as backend correctness;
- Cranelift Historical Full remains separately runnable and owns complete historical evidence;
- representative runtime-package evidence is assigned to every applicable declared target;
- no selected helper is supplied by two incompatible runtime components;
- runtime symbol and package incompatibility cannot silently fall back to generated C.

**What the Closure Guard Must Not Run**

It must not directly replay:

- every Phase 17 differential family;
- every target runtime package build;
- every target runner;
- the full Phase 9–17 historical suite;
- every historical native fixture;
- complete object/link failure matrices;
- complete packaging and reproducibility matrices;
- long-running I/O, filesystem, resource, or threading stress suites.

It validates ownership and wiring for those suites.

**CI Wiring**

At closure:

- Replace the direct PR Fast invocation of the preceding Phase 17 Level 1 owner with `guard-cranelift-phase17-close`.
- Invoke the closure guard exactly once as the Level 1 phase-closure owner.
- Keep registry-derived Level 2 family jobs unchanged.
- Keep Heavy Guards focused on expensive primary-host native runtime, package, filesystem, resource, thread, and artifact evidence.
- Keep Cranelift Historical Full as the sole Level 3 historical and complete-runtime owner.
- Do not introduce a Phase 17 closure matrix family.
- Do not hard-code an exact target, helper-category, symbol, component, package, or family count as a correctness claim.

**Suggested Status**

`phase17_closed_native_runtime_boundary`

**Suggested Closure Wording**

The declared Phase 17 native runtime-boundary inventory is complete. Migrated programs use compiler-owned runtime requirements, versioned runtime symbols, native program objects, and explicit target-compatible runtime packages without generated C shims, while remaining unsupported runtime capabilities are represented by narrower, explicitly owned future-phase deferrals.

**It Must Not Say**

- The entire Gust runtime has been rewritten in Rust or Gust.
- All C runtime code has been removed.
- The MIR-to-C backend has been retired.
- Cranelift has complete Gust runtime support.
- Every standard-library helper is native.
- Every target has complete runtime support.
- Gust has complete C or foreign-function interoperability.
- All allocation strategies are supported.
- Garbage collection is complete.
- Unicode and locale support are complete.
- All I/O, filesystem, socket, process, signal, or terminal operations are supported.
- All threading, atomics, cancellation, or concurrency semantics are correct.
- All panic and exception paths unwind safely.
- The experimental backend is production complete.

**Final Exit Gate**

Phase 17 is closed when every declared Phase 17 row and selected C-dependent helper has migrated through the generic canonical-MIR and compiler-owned runtime path; been explicitly excluded or removed with justification; or been replaced by one or more narrower deferred rows assigned to later phases; and all migrated programs link using native objects plus an explicit compatible runtime package, with no generated C shim, for every applicable declared target.

## Recommended Implementation Order

Patch 17.0 opening inventory and Phase 16 residual rebase
→ Patch 17.1 compiler-owned runtime boundary and helper classification authority
→ Patch 17.2 supported runtime ABI, symbol identity, and versioning
→ Patch 17.3 runtime requirements in canonical MIR and native requests
→ Patch 17.4 explicit runtime packages and target-specific selection
→ Patch 17.5 stable runtime-library imports for Cranelift
→ Patch 17.6 Rust runtime components and native object integration
→ Patch 17.7 explicit retained C runtime objects
→ Patch 17.8 pure Gust runtime modules compiled through MIR
→ Patch 17.9 generated C shim elimination and obsolete helper removal
→ Patch 17.10 allocation, string, and core-memory runtime audit
→ Patch 17.11 I/O, filesystem, and resource runtime audit
→ Patch 17.12 threading and synchronization runtime audit
→ Patch 17.13 runtime availability, compatibility, and diagnostic enforcement
→ Patch 17.14 cross-feature runtime composition and complete differential
→ Patch 17.15 deferred residue and runtime-coverage audit
→ Patch 17.16 closure.

## Phase 17 Success Criteria

Phase 17 succeeds when:

- Phase 16 closure remains semantically intact.
- One canonical registry owns active feature state.
- One compiler-owned runtime service owns runtime ABI, helper classification, symbol identity and version, requirements, component selection, package compatibility, and link-plan handoff.
- Every selected C-dependent helper has exactly one Phase 17 classification.
- All generated views, active families, helper categories, symbols, versions, components, packages, targets, and totals come from structured authorities.
- Canonical MIR refers to compiler-owned runtime helper and symbol identities.
- Native requests carry deterministic compiler-produced runtime requirements.
- Explicit Cranelift imports compiler-selected versioned runtime symbols with Phase 16 ABI records.
- Runtime implementations are separate from compiler-generated program code.
- Selected Rust implementations are explicit runtime package components.
- Selected retained C implementations are separately compiled explicit runtime package components.
- Selected pure Gust runtime implementations compile through generic canonical MIR into explicit runtime package components.
- Obsolete helpers are removed from active producers, consumers, packages, and views.
- Target-specific runtime objects or libraries are produced through declared build authorities.
- Runtime package availability and compatibility are validated before linking and output replacement.
- Missing or incompatible symbols produce stable compiler-owned diagnostics.
- No generated ad hoc C wrapper or shim participates in an explicit Cranelift/native link path.
- Every migrated program links from native program objects plus an explicit compatible runtime package.
- MIR-to-C remains an independent default differential oracle unless a later roadmap phase explicitly retires it.
- MIR-to-C generated output is never used as the implementation intermediary for an explicit Cranelift artifact.
- Selected allocation, core-memory, and string helpers use the explicit classified runtime path.
- Selected I/O, filesystem, directory, and resource helpers use the explicit classified runtime path.
- Selected threading and synchronization helpers use the explicit classified runtime path.
- Phase 14 layout decisions remain compiler-owned.
- Phase 15 resource, move, cleanup, and destruction decisions remain compiler-owned.
- Phase 16 call and ABI decisions remain compiler-owned.
- No backend independently chooses helper classification, symbol spelling, symbol version, component, package, compatibility, or link order.
- No exact-source, generated-wrapper, object-output, archive-output, or linker-output recognizer exists.
- No explicit Cranelift fallback exists.
- Deferred input stops before prohibited native-driver and artifact access.
- Missing or incompatible runtime packages stop before linker invocation and output replacement.
- Existing output is preserved on failure and deferral.
- Phase 9G retains object, link, temporary cleanup, and publication ownership.
- Registry-derived Level 2 families own focused differential evidence.
- Cranelift Historical Full remains the sole Level 3 owner.
- Representative runtime-boundary programs agree through MIR-to-C and explicit Cranelift for every applicable declared target.
- Every residual deferral is narrow, actionable, target-scoped where necessary, and assigned to a later phase.
- Phase 17 closure does not claim complete runtime rewriting, complete C removal, complete FFI, allocation, I/O, filesystem, concurrency, platform, or production parity.
