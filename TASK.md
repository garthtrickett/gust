# Phase 19 — Brand Identity and Value Representation

**Lane:** Cranelift. Branches follow the existing `codex/phase<N>-<patch>-<slug>` pattern.

Workflow, Monitoring, Merge, Phase Completion, Runner, and Git Authorization
policies are defined once in `AGENTS.md` and apply to both lanes. Ownership
boundaries and the shared coordination zone are defined in `AGENTS.md` and
`docs/SHARED_SEMANTIC_ZONE.md`. This document defines only what is specific to
Phase 19.

Phase 19 exists to resolve **CR-2** from `TASK_STDLIB.md` and **D-1** from
`docs/SHARED_SEMANTIC_ZONE.md`. D-2 was an opening input but closed when the
deprecated Rust prototype was removed; Phase 19 owns the surviving brand
identity and value-representation defect, and nothing else.

It is also the first prerequisite of the demo deliverable. `docs/DEMO_TARGET_PROGRAM.md`
lists ten things that must be true before `VISION.md` §0.7's artifact compiles,
and brand identity is row 1 — because until it lands, whether a value is treated
as an arena depends on what the variable is called, and the memory model the
demo is meant to demonstrate is approximated by string matching. That does not
widen Phase 19's boundary; it is recorded so the phase's priority is legible
from outside the Cranelift lane.

## Roadmap Activation

Phase 18 closed on 2026-08-20 — Patch 18.19 merged as `ccacc1db` — and the
operator activated Phase 19 the same day. The Phase Completion Loop in
`AGENTS.md` authorizes autonomous work through Patch 19.12, subject to the
patch boundaries, validation requirements, and stop conditions below.

Phase 19 did not begin while Phase 18 was open. Both change the compiler, both
are bootstrap-sensitive, and interleaving them would have made a bootstrap
failure ambiguous between two causes.

Activating Phase 19 does not activate the Stdlib lane, and vice versa. Each lane
is activated separately.

## Status

- [x] Patch 19.0 — Opening Inventory and Phase 18 Residual Rebase — DONE
- [x] Patch 19.1 — Identifier-Spelling Decision Inventory — DONE
- [x] Patch 19.2 — Compiler-Owned Brand Identity Authority — DONE
- [x] Patch 19.3 — Canonical Branded Type Naming Without a Brand Vocabulary — DONE
- [x] Patch 19.4 — Type-Derived Container and Arena Classification — DONE
- [ ] Patch 19.5 — Argument and Index Representation From the Type System
- [ ] Patch 19.6 — Self-Hosted Rule Convergence
- [ ] Patch 19.7 — Retired Prototype Absence Contract
- [ ] Patch 19.8 — Name-List Removal From the Self-Hosted Compiler
- [ ] Patch 19.9 — Seed Regeneration and Fixed-Point Convergence
- [ ] Patch 19.10 — Generated-C Equivalence Over the Compiler's Own Sources
- [ ] Patch 19.11 — Cross-Feature Composition and Complete Differential
- [ ] Patch 19.12 — Phase 19 Closure

Status rows are machine-parsed in the same form the Phase 15–18 close guards
parse `TASK.md`. Keep each row as `- [ ] Patch 19.N — <Title>` or
`- [x] Patch 19.N — <Title> — DONE`, with no trailing annotation.

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
- Mark CR-2 resolved in `TASK_STDLIB.md`, unblocking S1.4, S1.5, and S1.6.
- Record the residue.
- Add `guard-cranelift-phase19-close`.

**Test Level**

Level 1.

**Exit Gate**

Phase 19 is closed, CR-2 is resolved, the Stdlib lane's blocked patches are
released, and the shared-zone defects are removed rather than merely documented.

## Recommended Implementation Order

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
- CR-2 is resolved and `TASK_STDLIB.md` S1.4, S1.5, and S1.6 are unblocked.
- D-1 is removed from the shared semantic zone; D-2 remains recorded as closed
  by prototype removal.

Phase 19 closure does not claim a general lifetime system, a brand algebra, or
any expansion of what brands can express. It claims only that the existing model
is decided by types instead of by names.
