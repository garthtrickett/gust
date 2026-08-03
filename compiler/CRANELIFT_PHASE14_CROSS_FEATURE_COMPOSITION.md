# Cranelift Phase 14 Cross-Feature Composition and All-Target Differential

<!-- Static contract projection for Patch 14.12. -->

CRANELIFT_PHASE14_COMPOSITION_VIEW_VERSION: 1
CRANELIFT_PHASE14_COMPOSITION_VERSION: phase14_cross_feature_all_target_layout_differential_v1
CRANELIFT_PHASE14_COMPOSITION_STATUS: phase14_closed
CRANELIFT_PHASE14_COMPOSITION_INVENTORY_OWNER: scripts/cranelift_feature_registry.json
CRANELIFT_PHASE14_COMPOSITION_PROJECTOR: scripts/phase14_composition.py
CRANELIFT_PHASE14_COMPOSITION_LEVEL1_GUARD: guard-cranelift-phase14-composition-contract
CRANELIFT_PHASE14_COMPOSITION_LEVEL2_GUARD: guard-cranelift-phase14-composition-differential
CRANELIFT_PHASE14_COMPOSITION_LEVEL3_GUARD: guard-cranelift-phase14-all-target-composition
CRANELIFT_PHASE14_CLOSURE_GUARD: guard-cranelift-phase14-close

## Inventory authority

The active Patch 14.12 inventory is derived from migrated Phase 14 rows in
`scripts/cranelift_feature_registry.json`. CI families come from each row's
`ci_family`; declared targets come from
`phase14_primitive_layout.declared_targets`; the primary Level 2 target comes
from `phase14_primitive_layout.primary_level2_target`.

Patch 14.12 does not own a second feature list, family list, or target list.

Every migrated Phase 14 row must retain:

- a unique individual differential case owner;
- an individual focused evidence guard;
- at least one registry-owned composition relationship;
- a differential failure fixture;
- target applicability through the declared target authority.

## Cross-feature closure case

The registry-owned closure case
`phase14_composition:all_features_nested_aggregate_layout_and_flow` covers
every migrated Phase 14 row. Its semantic composition tags include:

- primitive and pointer-sized integers;
- signed and unsigned conversions;
- bounded pointers;
- deterministic stack slots;
- typed loads and stores;
- strings and borrowed views;
- arrays and slices;
- declaration-order structs;
- enums and tagged unions;
- joins and loop-carried aggregate values;
- structs containing array and slice fields;
- enums carrying struct or string-view payloads;
- arrays and slices of structs;
- nullable pointers inside tagged unions;
- aggregate values updated through branches.

The source fixture is a runtime route sentinel. It does not pretend that a
single surface-syntax fixture is the layout authority. Semantic layout evidence
continues to come from the compiler-owned Phase 14 tables and their focused
MIR-to-C and Cranelift witnesses.

## Comparison contract

For applicable cases, Patch 14.12 compares:

- default and explicit MIR-to-C output bytes;
- MIR-to-C and Cranelift runtime values;
- stable stdout and stderr;
- exit status;
- semantic layout witnesses;
- type size and alignment;
- field offsets and padding ranges;
- array stride;
- slice and view field layout;
- enum tag and payload layout;
- selected initialized memory bytes.

Uninitialized padding is never compared as program data.

## Test-level ownership

### Level 1

`guard-cranelift-phase14-composition-contract` and
`guard-cranelift-phase14-close` validate only registry ownership, fixture
existence, projection, test-level assignment, and workflow wiring. They do not
compile Gust, run native programs, replay Level 2 families, or execute the
Level 3 target matrix.

### Level 2

Each registry-derived Phase 14 family first runs its focused semantic witness
guard on the primary target. It then runs
`guard-cranelift-phase14-composition-differential`, which executes the
registry-owned individual and composition source cases through default
MIR-to-C, explicit MIR-to-C, and explicit Cranelift.

### Level 3

Cranelift Historical Full projects its matrix directly from the declared target
authority. Each target job sets `PHASE14_TARGET` and runs
`guard-cranelift-phase14-all-target-composition`. Feature-specific witness
scripts consume that target selection without maintaining their own target
lists.

The target matrix is semantic target evidence produced on the CI execution
host. It validates compiler-selected target layouts and backend witnesses; it
does not claim that every target triple is natively executed by its matching
operating system runner.

## Closure boundary

Phase 14 closes only the migrated type, layout, memory, aggregate, and
composition inventory. Packed structs, bitfields, niche optimization,
resource-bearing aggregate copies, unrestricted aggregate ABI, unsupported
aliasing, and other explicitly deferred forms remain outside this closure.