# Phase 18 — Target, Object, and Linker Hardening

## Workflow Policy

Flow: start one patch → run the related `just`/`make`/`cargo`/`scripts/*` checks locally → once local checks pass, publish through a `codex/**` branch and pull request to trigger GitHub runners. If a GitHub runner fails, cancel superseded runs on that branch, reproduce the first failing guard locally from the smallest useful log excerpt, fix it, rerun the focused local guard, push, and monitor the new `HEAD` until green. Do not poll GitHub while an unchanged local failure remains.

When a local or GitHub runner fails, do not prompt for permission when this document defines the next step. Fix forward within the current patch, preserve the patch boundary, and stop only when the correction would materially expand scope or no policy defines the next action.

### Roadmap Publication and Activation

The current task authorizes writing, validating, committing, pushing, and opening or updating the pull request for this Phase 18 roadmap. It does **not** by itself activate implementation of Patch 18.0 or any later capability patch.

Phase 18 implementation begins only after an explicit operator request to start Phase 18. Once activated, the Phase Completion Loop below authorizes autonomous work through Patch 18.19, subject to the patch boundaries, validation requirements, and stop conditions in this document.

### Git Authorization

This file is the explicit authorization for `git commit`, `git push`, `gh pr create`/`update`, `gh run cancel`, and `gh pr merge` on `codex/**` branches for the roadmap publication and, once Phase 18 is explicitly activated, for the Phase 18 implementation loop. Never push directly to `main`. Do not self-approve.

General rule: when Workflow, Monitoring, Merge, Phase Completion, or Runner Policy defines the next step, continue without a permission prompt. Ask only when the next action falls outside those policies or requires a material scope expansion.

## Monitoring Policy

When monitoring GitHub Actions or long-running local guard runs:

- State it explicitly in chat as `Monitoring <branch> <SHA> via c2eab010 every 2m`.
- Use `gh run list --branch <branch> --limit 100` and, where necessary, the paginated Actions API filtered to the exact `head_sha`.
- Report each poll as `SHA | workflow | event | status | conclusion` and distinguish the owning Phase 18 guard failure from unrelated or superseded runs.
- Keep monitor `c2eab010` visible; after each poll say `Monitoring continues` or `All green — proceeding`.
- Do not silently poll.
- Always set a 5 minute pulse when monitoring local tests or GitHub CI/CD, and message a status update on every pulse. This applies to long-running local guard families as well as cloud runs; silence during a long wait is not acceptable even when nothing has changed.

## Merge Policy

Once every required `pull_request` workflow for the exact PR `HEAD` is `completed success`, all review conversations are resolved, and repository rules permit the operation, autonomously merge the agent's own `codex/**` pull request without prompting. After a capability patch merges, proceed to the next Phase 18 patch only when Phase 18 implementation has been explicitly activated.

## Phase Completion Loop

After explicit Phase 18 activation, do not stop after one capability merge. Phase 18 is complete only when Status shows every patch 18.0–18.19 `DONE`, every Phase 18 Success Criterion is satisfied, all review conversations are resolved, and `guard-cranelift-phase18-close` passes in the authoritative GitHub environment.

After merging one patch, update local `main`, create `codex/phase18-<next>` from that `main`, implement the next patch's full Purpose and Exit Gate, validate locally, publish, monitor, fix forward if needed, and merge when green. Stop only when the operator explicitly says stop, repository policy blocks progress, or the required correction would materially expand the selected patch.

**Atomic per-patch commits and PRs:** Each initial publication must contain one complete patch such as 18.3 or 18.4, with its owning focused checks green before push. Do not combine planned patches into one PR and do not split a patch across multiple initial PRs unless its Exit Gate explicitly requires that split. Narrow corrective commits on the same PR are allowed when CI or review identifies a defect; reproduce and validate each correction locally before republishing.

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

- [x] Patch 18.0 — Opening Inventory and Phase 17 Residual Rebase — DONE
- [x] Patch 18.1 — Compiler-Owned Target Authority and Declared Target Triples — DONE
- [x] Patch 18.2 — Complete Target Support Tuple and Support Decisions — DONE
- [x] Patch 18.3 — Object Format, Section, and Symbol Binding Authority — DONE
- [x] Patch 18.4 — Relocation Model and Validation — DONE
- [ ] Patch 18.5 — Target-Specific ABI Selection
- [ ] Patch 18.6 — Target-Specific Runtime Package Selection
- [ ] Patch 18.7 — Linker Discovery, Selection, and Invocation Policy
- [ ] Patch 18.8 — Static and Dynamic Runtime Linking Modes
- [ ] Patch 18.9 — Cross-Compilation Policy and Host/Target Separation
- [ ] Patch 18.10 — Unsupported-Target Detection and Diagnostics
- [ ] Patch 18.11 — Symbol and Relocation Inspection Evidence
- [ ] Patch 18.12 — Debug Information Strategy
- [ ] Patch 18.13 — Source-Location Preservation
- [ ] Patch 18.14 — Optimisation-Level Policy
- [ ] Patch 18.15 — Reproducible Object and Artifact Output
- [ ] Patch 18.16 — Atomic Executable Publication Under Phase 9G
- [ ] Patch 18.17 — Cross-Target Composition and Complete Per-Target Evidence
- [ ] Patch 18.18 — Deferred Residue and Target-Coverage Audit
- [ ] Patch 18.19 — Phase 18 Closure

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

Phase 18 turns the host-only native path into a supported compiler backend.

Phase 17 proved that a migrated program can be compiled to native objects and linked against an explicit runtime package without generated C glue. It proved this on the host. Phase 18 makes target support an explicit, declared, and evidenced property rather than an accident of the machine the compiler happens to run on.

The central rule of this phase is that **a target is not supported because Cranelift can emit code for its architecture**. A declared supported target requires the complete combination of:

- a compiler able to produce correct native objects for the target;
- a runtime package built for and compatible with the target;
- a linker that can be discovered and invoked for the target;
- an ABI selection valid for the target.

All four must hold simultaneously, be validated together, and carry evidence together. Any target missing any element is unsupported and must be diagnosed as unsupported rather than attempted.

The phase covers the declared inventory for:

- explicit target selection and declared architecture and operating-system triples;
- object-format handling, section naming, and symbol binding;
- relocation model selection and relocation validation;
- target-specific ABI selection consuming the Phase 16 authority;
- target-specific runtime package selection consuming the Phase 17 authority;
- linker discovery, selection, and invocation policy;
- static versus dynamic runtime linking;
- reproducible object and artifact output;
- atomic executable publication under existing Phase 9G ownership;
- cross-compilation policy and host/target separation;
- unsupported-target detection and stable diagnostics;
- symbol and relocation inspection evidence;
- debug information strategy;
- source-location preservation;
- optimisation-level policy.

The initial declared supported target set must remain narrow and explicit. Breadth is not a goal of this phase; a small number of completely supported targets is the goal. Adding a target is a deliberate, evidenced act, not a consequence of a backend capability table.

Phase 18 closes only the declared target, object, and linker inventory. It does not claim complete platform coverage, complete cross-compilation, complete debug-information fidelity, complete optimisation support, a stable public target-triple vocabulary, distribution or packaging policy, retirement of the MIR-to-C oracle, or production readiness.

## Starting State

The expected starting state is:

- Phase 17 is closed with status `phase17_closed_native_runtime_boundary`.
- The canonical feature registry remains the only active feature-state authority.
- The Phase 17 semantic closure snapshot remains immutable.
- The Phase 17 deferred residue snapshot contains concrete capabilities assigned to later phases.
- Phase 14 remains the compiler-owned authority for type layout, target layout, and memory-access validation.
- Phase 15 remains the compiler-owned authority for resource identity, move state, cleanup obligations, and destruction.
- Phase 16 remains the compiler-owned authority for signatures, parameter and result placement, call plans, frame plans, and compatibility.
- Phase 17 remains the compiler-owned authority for runtime ABI identity, helper classification, runtime symbol identity and version, runtime components, runtime packages, runtime requirements, and pre-link availability and compatibility decisions.
- MIR-to-C remains the default backend and differential oracle unless a later explicit roadmap patch changes that ownership.
- Explicit Cranelift selection has no fallback.
- The compiler owns source interpretation and canonical MIR production.
- The worker receives only request data, canonical MIR, and compiler-produced layout, resource, ABI, and runtime metadata.
- Phase 9G owns object handling, linking, cleanup of owned temporary artifacts, and atomic publication.
- Registry-derived CI families own focused differential evidence.
- Cranelift Historical Full remains the sole Level 3 historical owner.

Phase 18 must consume those contracts rather than recreate them. In particular, Phase 18 selects an ABI for a target; it does not define ABI semantics. It selects a runtime package for a target; it does not define runtime symbol identity. It plans and validates a link; it does not take link execution or publication ownership from Phase 9G.

## Phase Boundary

Phase 18 may implement:

- a compiler-owned target authority and declared target triple vocabulary;
- explicit target selection from the request and from a declared default;
- the complete target support tuple and its support decision;
- object-format descriptors covering section naming, symbol binding, and visibility;
- relocation kind vocabularies per target and object format;
- relocation validation before object publication;
- target-specific ABI selection consuming Phase 16 records;
- target-specific runtime package selection consuming Phase 17 records;
- linker discovery, selection, and a declared invocation policy;
- static and dynamic runtime link modes;
- deterministic and reproducible object and artifact bytes;
- atomic executable publication integrated with Phase 9G ownership;
- host and target separation for cross-compilation;
- unsupported-target detection with stable diagnostics at a declared early stage;
- symbol table and relocation inspection witnesses;
- a declared debug-information strategy and level;
- source-location preservation from source through canonical MIR to emitted debug records;
- a declared optimisation-level vocabulary and its effect on emitted code.

Phase 18 must not silently absorb:

- complete platform or architecture coverage;
- a stable, publicly committed target-triple vocabulary;
- complete cross-compilation including sysroot acquisition and management;
- toolchain distribution, installation, or package-manager design;
- complete debug-information fidelity or debugger integration;
- complete optimisation pipelines or performance guarantees;
- profile-guided or link-time optimisation;
- position-independent executable, address-space-layout, or hardening policy unless separately selected;
- code signing, notarisation, or platform attestation;
- shared-library authoring or plugin loading;
- dynamic loader design;
- removal of MIR-to-C as the default differential oracle;
- linker implementation;
- object-format writing beyond what the declared targets require;
- arbitrary foreign-function interfaces;
- capabilities already deferred by Phase 17 to later phases;
- full Gust language parity or production readiness.

Out-of-scope Phase 17 residual rows must remain deferred, be reassigned to a later phase, or be split into narrower rows. They must not be marked migrated merely because Phase 18 introduces a target, object format, or linker policy.

## Compiler-Owned Target and Artifact Authority

Phase 18 must establish one compiler-owned target service with semantic records equivalent to the following concepts. No backend, worker, linker driver, or diagnostic path may derive these independently.

### Target Identity

- stable target ID;
- architecture;
- vendor;
- operating system;
- environment or ABI suffix where the target requires one;
- pointer width;
- endianness;
- declared source of the triple.

Target identity is the only authority for what a target is. A backend capability table is not a target identity.

### Complete Target Support Tuple

- target ID;
- compiler support record;
- runtime package support record;
- linker support record;
- ABI support record;
- resulting support decision.

A target is declared supported only when all four support records are present, mutually compatible, and evidenced. The tuple is the phase's central invariant.

### Object Format Descriptor

- object format;
- section naming rules;
- symbol binding vocabulary;
- symbol visibility vocabulary;
- alignment requirements;
- permitted section kinds.

### Relocation Model

- relocation kind vocabulary for the target and object format;
- permitted relocation kinds per section kind;
- addend policy;
- validation rules applied before an object is published.

### Target ABI Selection

- target ID;
- selected Phase 16 ABI identity;
- selection reason;
- compatibility decision.

Phase 18 selects an existing ABI. It does not define ABI placement, classification, or transport.

### Target Runtime Package Selection

- target ID;
- selected Phase 17 runtime package identity;
- link mode;
- compatibility decision.

Phase 18 selects an existing package. It does not define runtime symbol identity or version.

### Linker Descriptor

- linker ID;
- discovery method;
- discovery result;
- invocation policy;
- permitted argument vocabulary;
- supported object formats;
- supported targets.

### Link Mode Decision

- target ID;
- static or dynamic runtime linking;
- decision reason;
- required runtime package form;
- rejection reason where the requested mode is unavailable.

### Reproducibility Contract

- declared reproducible fields;
- excluded non-deterministic inputs;
- normalisation rules for paths, timestamps, and ordering;
- comparison method for repeated builds.

### Publication Plan

- temporary artifact ownership;
- publication order;
- atomicity method;
- preservation guarantee on failure and deferral.

Publication remains owned by Phase 9G. Phase 18 supplies the plan; it does not perform or reassign publication.

### Host and Target Separation

- host identity;
- target identity;
- whether the build is native or cross;
- permitted host-dependent inputs;
- rejection rules for host leakage into target artifacts.

### Debug Information Plan

- debug information format;
- debug level;
- included record kinds;
- excluded record kinds;
- target applicability.

### Source Location Record

- source file identity;
- source span;
- canonical MIR association;
- emitted debug association;
- preservation guarantee through lowering.

### Optimisation Level Decision

- declared optimisation level vocabulary;
- selected level;
- permitted transformations at that level;
- guarantees preserved across levels;
- observable-behaviour equivalence requirement.

### Target Support Decision

- target ID;
- supported or unsupported;
- missing tuple elements where unsupported;
- stable diagnostic reason code;
- declared failure stage.

## Request and MIR Ownership

- The compiler selects the target and produces the target identity, support decision, ABI selection, runtime package selection, link mode, debug plan, and optimisation level.
- The native request carries the selected target identity and the compiler-produced target records it depends on.
- Canonical MIR references compiler-produced target and source-location identities rather than backend-inferred ones.
- The worker receives only request data, canonical MIR, and compiler-produced layout, resource, ABI, runtime, and target metadata.
- Request validation rejects missing, duplicate, conflicting, unknown, or target-incompatible target metadata.
- The worker does not choose a target, an object format, a relocation kind, a linker, a link mode, a debug level, or an optimisation level.

## Architectural Invariants

- A target is supported only as a complete compiler, runtime, linker, and ABI combination.
- The declared supported target set is explicit, narrow, and registry-owned.
- Backend architecture capability is necessary but never sufficient for target support.
- No component infers a target from the host environment when an explicit target is selected.
- No component infers an object format, relocation kind, or linker from an unresolved symbol, a file extension, or a probe of the output.
- Unsupported targets stop at a declared early failure stage before native driver access, object creation, linker invocation, or output replacement.
- Object bytes for a fixed input, target, and level are reproducible.
- Existing output is preserved on failure and deferral.
- Phase 9G retains object handling, linking, temporary cleanup, and atomic publication ownership.
- Phase 14, 15, 16, and 17 authorities remain the owners of layout, resource, ABI, and runtime decisions respectively.
- MIR-to-C remains an independent default differential oracle and never acts as an implementation intermediary for a native artifact.
- Explicit Cranelift has no fallback to MIR-to-C.
- Source locations survive lowering wherever the declared debug plan requires them.
- Optimisation level changes emitted code but never observable program behaviour where the contract requires equivalence.
- No exact-source, fixture-name, object-output, archive-output, linker-output, or debug-output recognizer exists.
- No exact target, format, relocation, or linker count is treated as backend correctness.

## Verification Policy

### Level 1 — Fast Contracts

Level 1 guards may validate:

- Phase 17 semantic closure availability;
- Phase 18 opening and parent traceability;
- canonical registry schema and semantic state;
- compiler-owned target identity and triple vocabulary;
- complete target support tuple records and support decisions;
- object format descriptor schemas;
- relocation kind vocabularies and validation rules;
- target ABI selection records consuming Phase 16;
- target runtime package selection records consuming Phase 17;
- linker descriptor and invocation policy schemas;
- link mode decisions;
- reproducibility contract declarations;
- publication plan handoff to Phase 9G;
- host and target separation rules;
- unsupported-target diagnostics;
- debug information plan schemas;
- source-location record ownership in canonical MIR;
- optimisation level vocabularies and permitted transformations;
- generated projection freshness;
- no backend-local target, format, relocation, linker, or level selector;
- no host inference when an explicit target is selected;
- no fallback;
- worker isolation;
- early deferral;
- output preservation;
- manifest and route architecture;
- CI-family projection;
- test-level and workflow ownership;
- residue and closure summaries.

Level 1 guards must not build every declared target, invoke every linker, produce every object, run every target runner, inspect every emitted artifact, or execute the full historical suite.

### Level 2 — Focused Differential Families

Level 2 evidence validates bounded migrated behavior on the primary PR host through registry-derived families.

A proposed initial family vocabulary is:

- `target-identity`;
- `target-support-tuple`;
- `object-format`;
- `relocations`;
- `target-abi-selection`;
- `target-runtime-packages`;
- `linker-policy`;
- `link-modes`;
- `reproducibility`;
- `publication`;
- `cross-compilation`;
- `target-diagnostics`;
- `object-inspection`;
- `debug-info`;
- `source-locations`;
- `optimisation-levels`.

The active family set and count must be derived from the canonical registry. The workflow must not hard-code one matrix row per patch, target, object format, relocation kind, linker, or level.

For each applicable case, Level 2 should compare:

- default MIR-to-C;
- explicit MIR-to-C;
- explicit Cranelift using native program objects and an explicit runtime package;
- runtime values;
- stdout and stderr where declared stable;
- exit status;
- target identity and support decision witnesses;
- object format and section witnesses;
- relocation validation witnesses;
- selected ABI and runtime package witnesses;
- linker discovery and invocation-plan witnesses;
- link mode witnesses;
- repeated-build byte comparison for reproducible outputs;
- symbol table and relocation inspection witnesses;
- debug record presence and source-location association where declared;
- stable unsupported-target diagnostics;
- preservation of sentinel output on failure.

Default and explicit MIR-to-C output should remain byte-identical for the same target and source where the existing differential contract requires it. Level 2 runs on the primary PR host; it validates target decisions and plans for non-host targets rather than executing non-host binaries.

### Level 3 — Historical and Complete Target Evidence

Cranelift Historical Full remains the sole Level 3 owner.

It owns:

- complete Phase 9–18 historical replay;
- the complete registry-derived Phase 18 differential inventory;
- native compile, object inspection, link, execution, diagnostic, and reproducibility evidence for every declared supported target;
- cross-compilation evidence for every declared cross pair;
- linker discovery and invocation evidence per target;
- static and dynamic link mode evidence where both are declared;
- repeated-build reproducibility evidence;
- debug information and source-location evidence where declared;
- optimisation-level equivalence evidence;
- unsupported-target diagnostic matrices;
- complete object, link, cleanup, and publication failure matrices owned by Phase 9G;
- all historical native fixtures.

Phase 18 opening and closure guards validate that the Level 3 suite remains available, registry-derived, and separately runnable. They do not execute it.

## Standard Definition of Done for Every Phase 18 Capability Patch

A Phase 18 capability is migrated only when all of the following are true:

- The supported source shape is precisely bounded.
- The supported canonical-MIR shape is precisely bounded.
- The owning canonical registry row is identified.
- The owning declared target set is explicit or derived.
- Every declared supported target has a complete support tuple.
- Every support tuple element names its owning authority.
- Every target has a compiler-owned target identity.
- Every emitted object has a compiler-selected object format and section plan.
- Every emitted relocation is a declared kind permitted for its section.
- Every target names a selected Phase 16 ABI and a compatibility decision.
- Every target names a selected Phase 17 runtime package, link mode, and compatibility decision.
- Every link names a discovered linker and a declared invocation policy.
- A real source fixture lowers through the generic producer.
- A compiler-owned canonical-MIR fixture exists where applicable.
- The compiler target service returns the required identity, tuple, format, relocation, ABI, package, linker, mode, debug, and level records.
- The compiler layout, resource, ABI, and runtime services return the required dependent records.
- Canonical MIR references compiler-produced target and source-location identities rather than backend guesses.
- The native request carries the required deduplicated target metadata.
- Request validation rejects missing, duplicate, conflicting, unknown, or target-incompatible target metadata.
- Explicit Cranelift emits for the compiler-selected target using the compiler-selected format, ABI, and level.
- The explicit native link path uses native program objects plus an explicit runtime package for the selected target.
- No component infers the target, format, relocation kind, linker, mode, or level from the host or from output inspection.
- Repeated builds of the same input, target, and level produce identical declared reproducible bytes.
- Diagnostics report the same target support and compatibility decisions used by lowering and linking.
- Unsupported targets are diagnosed as unsupported and never attempted.
- Default and explicit MIR-to-C remain equivalent where the existing contract applies.
- MIR-to-C and explicit Cranelift native behavior are compared.
- Target, format, relocation, ABI, package, linker, mode, debug, and level witnesses are compared where observable.
- Malformed and unsupported cases have stable diagnostics.
- Unsupported cases remain explicitly deferred.
- Deferred and invalid cases stop at their declared early failure stage before prohibited native-driver, object, linker, or artifact access.
- Missing or incompatible targets, packages, or linkers stop before linker invocation and output replacement.
- Existing output survives deferral and failure.
- Phase 9G still owns object handling, linking, temporary cleanup, and atomic publication.
- The worker still receives only request data, canonical MIR, and compiler-produced layout, resource, ABI, runtime, and target metadata.
- The registry row is updated using the existing status vocabulary.
- Generated projections are refreshed.
- The owning CI family contains focused evidence.
- At least one appropriate composition relationship exists.
- No exact-source, fixture-name, object-output, archive-output, linker-output, or debug-output recognizer was introduced.
- No exact target, format, relocation, or linker count is treated as backend correctness.
- Explicit Cranelift still cannot fall back to MIR-to-C.
- The new guards are assigned to the correct test level.

## Patch Sequence

### Patch 18.0 — Opening Inventory and Phase 17 Residual Rebase

**Purpose**

Establish the exact Phase 18 input from the closed Phase 17 state without changing compiler, backend, runtime, object, linker, or artifact behavior.

**Steps**

- Add a semantic Phase 18 opening snapshot to the canonical registry.
- Preserve parent traceability to:
  - Phase 17 migrated target-related and package-related rows;
  - Phase 17 narrow deferred rows assigned to a later phase;
  - explicit Phase 18 planning categories.
- Inventory every existing host assumption reachable from compiler target selection, Cranelift lowering, object emission, runtime package selection, link planning, and publication.
- Select only target, object-format, relocation, linker, link-mode, reproducibility, cross-compilation, diagnostic, debug, source-location, and optimisation rows owned by this phase.
- Split broad residuals where one Phase 17 row contains both:
  - target, object, or linker work owned by Phase 18; and
  - runtime capability work owned by a later phase.
- Keep out-of-scope rows deferred and explicitly assign their destination phases.
- Add stable Phase 18 rows for:
  - target authority and declared triples;
  - complete target support tuple;
  - object format and section binding;
  - relocation model and validation;
  - target ABI selection;
  - target runtime package selection;
  - linker discovery and invocation policy;
  - static and dynamic link modes;
  - reproducible object output;
  - atomic executable publication;
  - cross-compilation policy;
  - unsupported-target diagnostics;
  - symbol and relocation inspection;
  - debug information strategy;
  - source-location preservation;
  - optimisation-level policy;
  - complete per-target evidence.
- Require each opening row to contain:
  - stable ID;
  - parent;
  - feature family;
  - CI family;
  - capability owner;
  - diagnostic owner;
  - target applicability;
  - status;
  - current failure stage;
  - positive future fixture;
  - negative current fixture.
- Declare the initial candidate target set and mark every candidate unsupported until its tuple is proven.
- Freeze the initial registry-derived Phase 18 CI-family projection.
- Generate the Phase 18 opening review view.
- Add `guard-cranelift-phase18-opening-contract`.

**Test Level**

Level 1.

**Exit Gate**

Every declared Phase 18 row has a stable parent, owner, target scope, failure stage, fixture pair, and initial disposition. Every host assumption has an inventory owner. Every candidate target is recorded as unsupported pending tuple evidence, and non-target Phase 17 residuals remain explicitly outside Phase 18.

### Patch 18.1 — Compiler-Owned Target Authority and Declared Target Triples

**Purpose**

Create the single target-identity decision path consumed by canonical MIR, Cranelift, runtime package selection, link planning, diagnostics, and Phase 9G publication.

**Steps**

- Add a compiler-owned target authority module.
- Define the target identity record: stable ID, architecture, vendor, operating system, environment, pointer width, endianness, and declared triple source.
- Define the declared triple vocabulary and reject any triple outside it.
- Make target selection explicit: a requested target, or a declared default when none is requested.
- Forbid inferring a target from the host environment when an explicit target is selected.
- Require the target identity to agree with the Phase 14 target layout authority for pointer width and endianness.
- Reject unknown, malformed, ambiguous, and duplicate triples with stable reasons.
- Add the target identity to the native request and validate it.
- Generate the target authority review view.
- Add `guard-cranelift-phase18-target-authority-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Exactly one compiler-owned authority produces target identity. Every declared triple is registry-owned and agrees with the Phase 14 target layout authority. No consumer infers a target independently, and unknown or malformed triples are rejected with stable diagnostics.

### Patch 18.2 — Complete Target Support Tuple and Support Decisions

**Purpose**

Make target support mean the complete compiler, runtime, linker, and ABI combination rather than backend architecture capability.

**Steps**

- Add the complete target support tuple record: target ID plus compiler, runtime package, linker, and ABI support records.
- Require every element to name its owning authority and its evidence.
- Produce a support decision that is supported only when all four elements are present, mutually compatible, and evidenced.
- Record missing elements explicitly when the decision is unsupported.
- Reject any attempt to declare a target supported from backend architecture capability alone.
- Forbid a partial tuple from reaching lowering, object emission, or link planning.
- Require the declared supported target set to remain narrow and registry-derived.
- Freeze the ordering of tuple validation so a partial or reordered sequence is rejected.
- Accept that the declared supported set may be empty at this patch, because the ABI, runtime package, and linker elements are not supplied until Patch 18.5, Patch 18.6, and Patch 18.7. A target becomes supported only as later patches supply its elements.
- Generate the target support review view.
- Add `guard-cranelift-phase18-target-support-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

The tuple record, its validation order, and the support decision rule exist and are registry-owned. Backend architecture capability alone never yields support, and every unsupported target names its missing tuple elements. The declared supported set may still be empty at this patch; it becomes non-empty only as later patches supply ABI, runtime package, and linker elements.

### Patch 18.3 — Object Format, Section, and Symbol Binding Authority

**Purpose**

Give each declared target one compiler-owned object format plan covering sections, symbol binding, and visibility.

**Steps**

- Add the object format descriptor record for each declared target.
- Define the permitted section kinds, section naming rules, and alignment requirements.
- Define the symbol binding and visibility vocabularies.
- Select the object format from the target identity, never from a file extension, probe, or host default.
- Require emitted program objects to use only declared section kinds and symbol bindings.
- Reject unknown formats, unknown sections, unknown bindings, and misaligned sections with stable reasons.
- Compare emitted section and symbol plans against the compiler-produced descriptor.
- Generate the object format review view.
- Add `guard-cranelift-phase18-object-format-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Every declared target has exactly one compiler-owned object format descriptor. Emitted objects use only declared sections, bindings, and visibilities, and no consumer infers the format from the host or from output inspection.

### Patch 18.4 — Relocation Model and Validation

**Purpose**

Make relocations a validated compiler-owned decision rather than an emitted side effect.

**Steps**

- Add the relocation model record: relocation kind vocabulary per target and object format.
- Declare which relocation kinds are permitted per section kind.
- Declare the addend policy.
- Validate every emitted relocation against the model before the object is published.
- Reject unknown relocation kinds, relocations in disallowed sections, and malformed addends with stable reasons.
- Ensure relocation validation runs before object publication and before linker invocation.
- Preserve existing output when relocation validation fails.
- Generate the relocation review view.
- Add `guard-cranelift-phase18-relocation-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Every emitted relocation is a declared kind permitted for its section and target. Invalid relocations are rejected before object publication and before linker invocation, with existing output preserved.

### Patch 18.5 — Target-Specific ABI Selection

**Purpose**

Select an existing Phase 16 ABI per target without redefining ABI semantics.

**Steps**

- Add the target ABI selection record: target ID, selected Phase 16 ABI identity, selection reason, and compatibility decision.
- Consume the Phase 16 function ABI authority as the sole owner of placement, classification, and transport.
- Reject a target whose required ABI is undeclared or incompatible.
- Forbid Phase 18 from introducing new ABI classification rules.
- Require the selected ABI to appear in the native request and in link planning.
- Compare selected ABI witnesses against the Phase 16 authority records.
- Generate the target ABI selection review view.
- Add `guard-cranelift-phase18-target-abi-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Every declared supported target names exactly one selected Phase 16 ABI with a compatibility decision. Phase 18 selects but never defines ABI semantics, and an undeclared or incompatible ABI makes the target unsupported.

### Patch 18.6 — Target-Specific Runtime Package Selection

**Purpose**

Select an existing Phase 17 runtime package per target without redefining runtime symbol identity.

**Steps**

- Add the target runtime package selection record: target ID, selected Phase 17 package identity, link mode, and compatibility decision.
- Consume the Phase 17 runtime package authority as the sole owner of component and symbol identity.
- Require the selected package to be built for the selected target.
- Reject a target whose runtime package is missing, unbuilt, or incompatible, before linker invocation.
- Forbid Phase 18 from introducing new runtime symbols, versions, or components.
- Compare selected package witnesses against the Phase 17 authority records.
- Generate the target runtime package review view.
- Add `guard-cranelift-phase18-target-package-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Every declared supported target names exactly one compatible Phase 17 runtime package built for that target. Missing or incompatible packages make the target unsupported and stop before linker invocation and output replacement.

### Patch 18.7 — Linker Discovery, Selection, and Invocation Policy

**Purpose**

Make linker choice and invocation an explicit compiler-owned policy rather than an environment accident.

**Steps**

- Add the linker descriptor record: linker ID, discovery method, discovery result, invocation policy, permitted argument vocabulary, supported object formats, and supported targets.
- Declare the discovery order and make it deterministic.
- Select a linker from the target identity and the descriptor, never from an unvalidated environment variable alone.
- Restrict invocation arguments to the declared vocabulary.
- Reject a target whose linker is undiscovered, unsupported, or incompatible with the object format, before invocation.
- Record the planned invocation as a witness without executing it at Level 1.
- Keep linker execution under Phase 9G ownership.
- Generate the linker policy review view.
- Add `guard-cranelift-phase18-linker-policy-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Every declared supported target names a discovered linker and a declared invocation policy using only permitted arguments. An undiscovered or incompatible linker makes the target unsupported, and Phase 9G still executes the link.

### Patch 18.8 — Static and Dynamic Runtime Linking Modes

**Purpose**

Make the runtime link mode an explicit per-target decision with declared consequences.

**Steps**

- Add the link mode decision record: target ID, static or dynamic, reason, required runtime package form, and rejection reason where unavailable.
- Declare which modes each target supports.
- Require the selected mode to match a runtime package form that actually exists for the target.
- Reject a requested mode that the target or package does not provide, before linker invocation.
- Record the resulting link plan differences between modes as witnesses.
- Forbid silently substituting one mode for another.
- Generate the link mode review view.
- Add `guard-cranelift-phase18-link-mode-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Every declared supported target declares its available link modes, and the selected mode matches an existing runtime package form. An unavailable mode is rejected with a stable diagnostic and is never silently substituted.

### Patch 18.9 — Cross-Compilation Policy and Host/Target Separation

**Purpose**

Separate host identity from target identity so a cross build never absorbs host state.

**Steps**

- Add the host and target separation record: host identity, target identity, native or cross classification, permitted host-dependent inputs, and host leakage rejection rules.
- Declare which cross pairs are supported, and keep the set narrow.
- Forbid host paths, host libraries, host headers, and host runtime packages from entering a cross artifact.
- Require a cross build to select the target runtime package and linker for the target, never for the host.
- Reject a cross pair whose target support tuple is incomplete.
- Record native and cross classification as a witness.
- Generate the cross-compilation review view.
- Add `guard-cranelift-phase18-cross-compilation-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Host and target identities are distinct and explicit. Declared cross pairs are narrow and registry-owned, host state cannot leak into a cross artifact, and an incomplete tuple rejects the cross pair.

### Patch 18.10 — Unsupported-Target Detection and Diagnostics

**Purpose**

Make an unsupported target a stable, early, diagnosed outcome rather than a late failure.

**Steps**

- Add the target support decision diagnostic path.
- Emit a stable diagnostic naming the target and every missing tuple element.
- Declare the failure stage and require rejection before native driver access, object creation, linker invocation, and output replacement.
- Freeze the rejection class vocabulary for unknown triple, unsupported architecture, missing runtime package, missing linker, incompatible ABI, unavailable link mode, and incomplete tuple.
- Require diagnostics to consume the same support decision used by lowering and linking.
- Forbid attempting an unsupported target and failing later.
- Prove sentinel output preservation for every rejection class.
- Generate the target diagnostic review view.
- Add `guard-cranelift-phase18-target-diagnostic-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Every unsupported target is diagnosed early with a stable reason naming its missing tuple elements. No unsupported target is attempted, and sentinel output survives every rejection class.

### Patch 18.11 — Symbol and Relocation Inspection Evidence

**Purpose**

Make emitted objects inspectable so target evidence is observed rather than assumed.

**Steps**

- Add an object inspection witness covering the symbol table and relocation table.
- Record symbol names, bindings, visibilities, and section associations.
- Record relocation kinds, offsets, and targets.
- Compare inspected symbols against the compiler-produced runtime symbol and ABI records.
- Compare inspected relocations against the declared relocation model.
- Reject an object whose inspected contents disagree with the compiler-produced plan.
- Forbid inspection from becoming a semantic authority; it observes and compares, and never decides.
- Generate the object inspection review view.
- Add `guard-cranelift-phase18-object-inspection-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Every declared supported target has symbol and relocation inspection evidence that agrees with the compiler-produced plan. Inspection compares and rejects but never decides, and disagreement fails the build.

### Patch 18.12 — Debug Information Strategy

**Purpose**

Declare what debug information the native path emits, for which targets, at which level.

**Steps**

- Add the debug information plan record: format, level, included record kinds, excluded record kinds, and target applicability.
- Declare the debug format per target and object format.
- Declare the debug levels and what each includes.
- Emit only declared record kinds, and reject undeclared ones.
- Require debug emission to be selected by the compiler, never inferred by the backend.
- Record the emitted debug plan as a witness.
- Declare explicitly what debug fidelity this phase does not claim.
- Generate the debug information review view.
- Add `guard-cranelift-phase18-debug-info-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Every declared supported target has a compiler-owned debug information plan naming its format, level, and record kinds. Only declared records are emitted, and the phase's fidelity limits are explicit.

### Patch 18.13 — Source-Location Preservation

**Purpose**

Preserve source locations from source through canonical MIR to emitted debug records.

**Steps**

- Add the source location record: source file identity, source span, canonical MIR association, and emitted debug association.
- Require canonical MIR to carry compiler-produced source locations rather than backend-reconstructed ones.
- Require lowering to preserve the association through to emitted debug records where the debug plan requires it.
- Reject a lost, duplicated, or fabricated source association with a stable reason.
- Compare emitted source locations against the compiler-produced records.
- Declare where source locations are deliberately not preserved.
- Generate the source location review view.
- Add `guard-cranelift-phase18-source-location-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Source locations survive from source through canonical MIR to emitted debug records wherever the debug plan requires. Lost, duplicated, or fabricated associations are rejected, and deliberate gaps are declared.

### Patch 18.14 — Optimisation-Level Policy

**Purpose**

Declare optimisation levels and bound what they may change.

**Steps**

- Add the optimisation level decision record: declared level vocabulary, selected level, permitted transformations, and preserved guarantees.
- Declare the level vocabulary and reject any level outside it.
- Select the level in the compiler and carry it in the native request.
- Declare which transformations each level permits.
- Require observable program behaviour to remain equivalent across levels where the contract applies.
- Compare program results across declared levels for representative programs.
- Declare where a level may change resource usage, code size, or debug fidelity but not observable behaviour.
- Reject an undeclared level and a level incompatible with the selected debug plan.
- Generate the optimisation level review view.
- Add `guard-cranelift-phase18-optimisation-level-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Every declared level is registry-owned with declared permitted transformations. Observable behaviour is equivalent across levels where the contract applies, and undeclared or debug-incompatible levels are rejected.

### Patch 18.15 — Reproducible Object and Artifact Output

**Purpose**

Make emitted objects and artifacts byte-reproducible for a fixed input, target, and level.

**Steps**

- Add the reproducibility contract record: declared reproducible fields, excluded non-deterministic inputs, and normalisation rules.
- Normalise embedded paths, timestamps, symbol ordering, and section ordering.
- Exclude host-specific and time-specific inputs from declared reproducible bytes.
- Compare two builds of the same input, target, and level byte-for-byte.
- Reject non-determinism in declared reproducible fields with a stable reason.
- Record which fields are deliberately excluded from the guarantee.
- Generate the reproducibility review view.
- Add `guard-cranelift-phase18-reproducibility-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Repeated builds of the same input, target, and level produce identical declared reproducible bytes. Every excluded field is declared, and non-determinism in a guaranteed field is rejected rather than tolerated.

### Patch 18.16 — Atomic Executable Publication Under Phase 9G

**Purpose**

Give publication an explicit compiler-owned plan while leaving execution and ownership with Phase 9G.

**Steps**

- Add the publication plan record: temporary artifact ownership, publication order, atomicity method, and preservation guarantee.
- Require publication to be atomic so a partially written executable never replaces a valid one.
- Require every temporary artifact to have a declared owner and cleanup rule.
- Require existing output to survive failure, deferral, and unsupported-target rejection.
- Validate that publication occurs only after object emission, relocation validation, availability validation, and link success.
- Keep publication execution, temporary cleanup, and artifact ownership with Phase 9G.
- Prove with a sentinel that no output is replaced before a rejection.
- Generate the publication review view.
- Add `guard-cranelift-phase18-publication-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Publication is atomic, ordered after every validation stage, and owned by Phase 9G. Sentinel output survives every failure, deferral, and unsupported-target rejection.

### Patch 18.17 — Cross-Target Composition and Complete Per-Target Evidence

**Purpose**

Prove that the migrated Phase 18 capabilities compose, and that every declared supported target carries the complete evidence set.

**Steps**

- Add cross-target composition cases combining target identity, object format, relocations, ABI selection, package selection, linker policy, link mode, reproducibility, debug plan, and optimisation level.
- Derive the composition inventory from canonical registry ownership rather than a hand-written list.
- Require every Phase 18 authority with migrated rows to participate in at least one composition case.
- Require every declared supported target to carry all six evidence kinds: native compile, object inspection, link, execution, diagnostic, and reproducibility.
- Derive the per-target evidence matrix from the declared supported target set.
- Require execution evidence for a target to come from that target's own runner.
- Require a target with no available runner to remain undeclared rather than supported, because execution evidence is part of the phase exit gate. Such a target stays a narrow deferred row naming the missing runner.
- Prove that a target missing any evidence kind is not declared supported.
- Add `guard-cranelift-phase18-composition-contract` at Level 1.
- Add `guard-cranelift-phase18-composition-differential` at Level 2.
- Add `guard-cranelift-phase18-complete-target-evidence` at Level 3, owned solely by Cranelift Historical Full.

**Test Level**

Level 1 contract, Level 2 differential, Level 3 complete evidence.

**Exit Gate**

Every Phase 18 authority participates in at least one composition case, and every declared supported target carries native compile, object inspection, link, execution, diagnostic, and reproducibility evidence from its own runner. A target missing any evidence kind, including a target with no available runner, is not declared supported.

### Patch 18.18 — Deferred Residue and Target-Coverage Audit

**Purpose**

Eliminate broad or ambiguous target, object, linker, debug, and optimisation deferrals before Phase 18 closure.

**Steps**

- Audit every Phase 18 opening row and every inventoried host assumption.
- Require every row and assumption to finish as one of:
  - migrated under exactly one Phase 18 classification;
  - explicitly excluded;
  - removed as obsolete;
  - replaced by one or more narrower deferred rows.
- Reject broad residual descriptions such as more targets, more platforms, more formats, more linkers, better debug info, more optimisation, or cross-compilation later.
- Replace broad residue with concrete capabilities such as:
  - named additional target triples;
  - shared library and dynamic loader support;
  - position-independent executable and hardening policy;
  - link-time and profile-guided optimisation;
  - complete debug-information fidelity and debugger integration;
  - sysroot acquisition and management;
  - code signing and platform attestation;
  - toolchain distribution and installation.
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
  - source Phase 18 row IDs.
- Confirm no Phase 17 residual assigned to Phase 18 remains unchanged and ambiguous.
- Confirm every candidate target from Patch 18.0 is either declared supported with a complete tuple, or explicitly deferred with the missing elements named.
- Confirm no declared supported target depends on an undeclared host assumption.
- Derive final totals from the registry.
- Generate the final Phase 18 review view.
- Freeze the residual inventory semantically as input to later phases.
- Add `guard-cranelift-phase18-deferred-residue-audit`.

**Test Level**

Level 1.

**Exit Gate**

Every Phase 18 row and inventoried host assumption has migrated, been excluded or removed with justification, or become a smaller actionable future-phase entry. Every candidate target is either supported with a complete tuple or deferred with its missing elements named.

### Patch 18.19 — Phase 18 Closure

**Purpose**

Close only the declared Phase 18 target, object, and linker inventory.

The closure must not claim complete platform coverage, complete cross-compilation, complete debug fidelity, complete optimisation support, a stable public target vocabulary, or production readiness.

**Closure Guard**

Add `guard-cranelift-phase18-close` and register it as a Level 1 guard.

**Required Contracts**

The closure guard must require:

- the semantic Phase 17 closure summary;
- the Phase 18 opening contract;
- the canonical registry schema;
- the canonical registry projection guard;
- the Phase 18 parent-traceability contract;
- the compiler-owned target authority contract;
- the complete target support tuple contract;
- the object format, section, and symbol binding contract;
- the relocation model and validation contract;
- the target-specific ABI selection contract;
- the target-specific runtime package selection contract;
- the linker discovery and invocation policy contract;
- the static and dynamic link mode contract;
- the cross-compilation and host/target separation contract;
- the unsupported-target diagnostic contract;
- the symbol and relocation inspection contract;
- the debug information contract;
- the source-location preservation contract;
- the optimisation-level contract;
- the reproducibility contract;
- the atomic publication contract;
- the cross-target composition contract;
- the deferred residue audit;
- the registry-derived Phase 18 CI-family projection;
- the semantic route architecture contract;
- the reduced manifest architecture contract through its canonical validator;
- the three-level test mapping and workflow ownership checks;
- the Phase 18 generated-view projection;
- the Phase 18 registry differential wiring;
- the separately runnable Level 3 historical and complete target suite;
- the Phase 14 layout ownership contract;
- the Phase 15 resource ownership contract;
- the Phase 16 function ABI ownership contract;
- the Phase 17 runtime boundary ownership contract;
- the Phase 9G artifact ownership contract;
- MIR-to-C default ownership;
- explicit Cranelift no-fallback policy;
- worker request isolation;
- early deferral and output-preservation contracts.

**Closure Assertions**

The closure guard must prove:

- every Phase 18 opening row has a valid final disposition;
- every inventoried host assumption has exactly one final disposition;
- every declared supported target has a complete support tuple;
- no target is declared supported from backend architecture capability alone;
- every declared supported target has native compile, object inspection, link, execution, diagnostic, and reproducibility evidence;
- every emitted object uses a compiler-selected format, section plan, and symbol binding;
- every emitted relocation is validated against the declared model before publication;
- every target names a selected Phase 16 ABI and a compatibility decision;
- every target names a selected Phase 17 runtime package, link mode, and compatibility decision;
- every link names a discovered linker and a declared invocation policy;
- declared reproducible bytes are identical across repeated builds;
- publication is atomic and owned by Phase 9G;
- host state cannot leak into a cross artifact;
- unsupported targets are diagnosed early and never attempted;
- source locations survive lowering where the debug plan requires;
- observable behaviour is equivalent across declared optimisation levels where the contract applies;
- no component infers target, format, relocation, linker, mode, or level from the host or from output inspection;
- no backend-local target, format, relocation, linker, or level authority exists;
- explicit Cranelift cannot fall back to MIR-to-C;
- MIR-to-C remains the default oracle and is not part of the explicit Cranelift link path;
- unsupported cases stop at their declared early failure stage;
- existing output is preserved on failure and deferral;
- the worker receives only request data, canonical MIR, and compiler-produced metadata;
- Phase 9G still owns object handling, linking, temporary cleanup, and publication;
- active totals, targets, formats, relocations, linkers, modes, and families are registry-derived;
- generated views are current;
- CI families remain registry-derived;
- no raw registry, object, archive, linker-command, debug-output, or Markdown hash contract exists;
- no exact target, format, relocation, linker, or matrix total is treated as backend correctness;
- Cranelift Historical Full remains separately runnable and owns complete historical and per-target evidence.

**What the Closure Guard Must Not Run**

It must not directly replay every Phase 18 differential family, every target build, every target runner, every linker invocation, the full Phase 9–18 historical suite, complete object or link failure matrices, complete reproducibility matrices, or cross-compilation matrices. It validates ownership and wiring for those suites.

**CI Wiring**

- Replace the direct PR Fast invocation of the preceding Phase 18 Level 1 owner with `guard-cranelift-phase18-close`.
- Invoke the closure guard exactly once as the Level 1 phase-closure owner.
- Keep registry-derived Level 2 family jobs unchanged.
- Keep Heavy Guards focused on expensive primary-host native, object, link, and artifact evidence.
- Keep Cranelift Historical Full as the sole Level 3 historical and complete-target owner.
- Do not introduce a Phase 18 closure matrix family.
- Do not hard-code an exact target, format, relocation, linker, mode, level, or family count as a correctness claim.

**Suggested Status**

`phase18_closed_target_object_and_linker_boundary`

**Suggested Closure Wording**

The declared Phase 18 target, object, and linker inventory is complete. Every declared supported target holds a complete compiler, runtime, linker, and ABI combination and carries native compile, object inspection, link, execution, diagnostic, and reproducibility evidence, while remaining unsupported targets and capabilities are represented by narrower, explicitly owned future-phase deferrals.

**It Must Not Say**

- Gust supports every platform or architecture.
- Cross-compilation is complete.
- The target triple vocabulary is stable or public.
- Debug information is complete or debugger-ready.
- Optimisation is complete or performance-competitive.
- Link-time or profile-guided optimisation is supported.
- Shared libraries, dynamic loading, or plugins are supported.
- Position-independent executables or hardening are complete.
- Code signing or platform attestation is supported.
- Sysroot management is handled.
- Toolchain distribution is solved.
- The MIR-to-C backend has been retired.
- The experimental backend is production complete.

**Final Exit Gate**

Phase 18 is closed when every declared Phase 18 row and inventoried host assumption has migrated, been explicitly excluded or removed with justification, or been replaced by narrower deferred rows assigned to later phases; and every declared supported target holds a complete compiler, runtime, linker, and ABI combination with native compile, object inspection, link, execution, diagnostic, and reproducibility evidence.

## Recommended Implementation Order

Patch 18.0 opening inventory and Phase 17 residual rebase
→ Patch 18.1 compiler-owned target authority and declared triples
→ Patch 18.2 complete target support tuple and support decisions
→ Patch 18.3 object format, section, and symbol binding authority
→ Patch 18.4 relocation model and validation
→ Patch 18.5 target-specific ABI selection
→ Patch 18.6 target-specific runtime package selection
→ Patch 18.7 linker discovery, selection, and invocation policy
→ Patch 18.8 static and dynamic runtime linking modes
→ Patch 18.9 cross-compilation policy and host/target separation
→ Patch 18.10 unsupported-target detection and diagnostics
→ Patch 18.11 symbol and relocation inspection evidence
→ Patch 18.12 debug information strategy
→ Patch 18.13 source-location preservation
→ Patch 18.14 optimisation-level policy
→ Patch 18.15 reproducible object and artifact output
→ Patch 18.16 atomic executable publication under Phase 9G
→ Patch 18.17 cross-target composition and complete per-target evidence
→ Patch 18.18 deferred residue and target-coverage audit
→ Patch 18.19 closure.

## Phase 18 Success Criteria

Phase 18 succeeds when:

- Target selection is explicit and compiler-owned.
- Declared target triples are registry-owned and agree with the Phase 14 target layout authority.
- A target is supported only as a complete compiler, runtime, linker, and ABI combination.
- The declared supported target set is narrow, explicit, and registry-derived.
- Backend architecture capability is never sufficient for target support.
- Every emitted object uses a compiler-selected format, section plan, symbol binding, and visibility.
- Every emitted relocation is a declared kind permitted for its section and is validated before publication.
- Every target selects an existing Phase 16 ABI without redefining ABI semantics.
- Every target selects an existing Phase 17 runtime package without redefining runtime symbol identity.
- Every link uses a discovered linker under a declared invocation policy.
- Static and dynamic link modes are declared per target and never silently substituted.
- Declared reproducible bytes are identical across repeated builds of the same input, target, and level.
- Executable publication is atomic and remains owned by Phase 9G.
- Host and target identities are separate, and host state cannot leak into a cross artifact.
- Unsupported targets are diagnosed early with stable reasons naming the missing tuple elements.
- Unsupported targets are never attempted.
- Symbol and relocation inspection evidence agrees with the compiler-produced plan.
- Debug information is emitted under a declared per-target plan.
- Source locations survive from source through canonical MIR to emitted debug records where required.
- Observable behaviour is equivalent across declared optimisation levels where the contract applies.
- Deferred input stops before prohibited native-driver, object, linker, and artifact access.
- Existing output is preserved on failure and deferral.
- Phase 9G retains object, link, temporary cleanup, and publication ownership.
- Phase 14, 15, 16, and 17 authorities remain the owners of layout, resource, ABI, and runtime decisions.
- MIR-to-C remains an independent default differential oracle and is never an implementation intermediary.
- No explicit Cranelift fallback exists.
- Registry-derived Level 2 families own focused differential evidence.
- Cranelift Historical Full remains the sole Level 3 owner.
- Every declared supported target has native compile, object inspection, link, execution, diagnostic, and reproducibility evidence.
- Every residual deferral is narrow, actionable, target-scoped where necessary, and assigned to a later phase.
- Phase 18 closure does not claim complete platform coverage, complete cross-compilation, complete debug fidelity, complete optimisation support, a stable public target vocabulary, or production readiness.
