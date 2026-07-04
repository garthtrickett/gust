# MIR Feature Migration Harness

MIR_FEATURE_MIGRATION_HARNESS_VERSION: 1
MIR_FEATURE_MIGRATION_PHASE: second-preservation-entry
MIR_FEATURE_MIGRATION_NO_FEATURES_MIGRATED: false
MIR_FEATURE_MIGRATION_REGISTRY: compiler/MIR_FEATURE_MIGRATION_REGISTRY.md
MIR_FEATURE_MIGRATION_REGISTRY: compiler/MIR_FEATURE_MIGRATION_REGISTRY.md

This file defines the Phase 5 feature migration harness contract.

Each migrated feature must get a preservation entry that proves this shape:

```text
source Gust fixture
  -> old AST-to-C expected behavior
  -> MIR lowering
  -> MIR verifier or focused MIR structural invariant guard
  -> MIR-to-C
  -> native execution
  -> same expected behavior
```

## Required preservation fields for future entries

Every migrated feature entry must name:

- `feature_name`
- `source_fixture`
- `old_behavior_guard`
- `mir_lowering_guard`
- `mir_verifier_guard`
- `mir_to_c_guard`
- `native_execution_guard`
- `expected_behavior`

## Registry

The machine-checkable registry lives at `compiler/MIR_FEATURE_MIGRATION_REGISTRY.md`.

The entries below mirror the registry for human review, but guard wiring should validate the registry file directly.

## Registry

The machine-checkable registry lives at `compiler/MIR_FEATURE_MIGRATION_REGISTRY.md`.

The entries below mirror the registry for human review, but guard wiring should validate the registry file directly.

## Registered preservation entries

### return_int_literal

- `feature_name`: `return_int_literal`
- `source_fixture`: `compiler/mir_feature_return_int_preservation_source.gst`
- `old_behavior_guard`: `guard-mir-feature-return-int-preservation`
- `mir_lowering_guard`: `guard-mir-lower-return-int-literal-smoke`
- `mir_verifier_guard`: `guard-mir-lower-return-int-literal-smoke`
- `mir_to_c_guard`: `guard-mir-to-c-return-int-literal-smoke`
- `native_execution_guard`: `guard-mir-to-c-return-int-literal-native-smoke`
- `expected_behavior`: native executable exits with status `1`

### local_binding_read

- `feature_name`: `local_binding_read`
- `source_fixture`: `compiler/mir_feature_local_binding_read_preservation_source.gst`
- `old_behavior_guard`: `guard-mir-feature-local-binding-read-preservation`
- `mir_lowering_guard`: `guard-mir-lower-local-binding-read-smoke`
- `mir_verifier_guard`: `guard-mir-lower-local-binding-read-smoke`
- `mir_to_c_guard`: `guard-mir-to-c-local-binding-read-smoke`
- `native_execution_guard`: `guard-mir-to-c-local-binding-read-native-smoke`
- `expected_behavior`: native executable exits with status `2`

### if_else_return_int

- `feature_name`: `if_else_return_int`
- `source_fixture`: `compiler/mir_feature_if_else_return_int_preservation_source.gst`
- `old_behavior_guard`: `guard-mir-feature-if-else-return-int-preservation`
- `mir_lowering_guard`: `guard-mir-lower-conditional-branch-smoke`
- `mir_verifier_guard`: `guard-mir-lower-conditional-branch-smoke`
- `mir_to_c_guard`: `guard-mir-to-c-conditional-branch-smoke`
- `native_execution_guard`: `guard-mir-to-c-conditional-branch-native-smoke`
- `expected_behavior`: native executable exits with status `1`

### local_binding_read

- `feature_name`: `local_binding_read`
- `source_fixture`: `compiler/mir_feature_local_binding_read_preservation_source.gst`
- `old_behavior_guard`: `guard-mir-feature-local-binding-read-preservation`
- `mir_lowering_guard`: `guard-mir-lower-local-binding-read-smoke`
- `mir_verifier_guard`: `guard-mir-lower-local-binding-read-smoke`
- `mir_to_c_guard`: `guard-mir-to-c-local-binding-read-smoke`
- `native_execution_guard`: `guard-mir-to-c-local-binding-read-native-smoke`
- `expected_behavior`: native executable exits with status `2`

Phase 7 first metadata-preservation feature:

feature_name: local_binding_read_provenance_metadata
source_fixture: compiler/mir_feature_local_binding_read_provenance_metadata_preservation_source.gst
old_behavior_guard: guard-mir-feature-local-binding-read-provenance-metadata-preservation
mir_lowering_guard: guard-mir-lower-provenance-metadata-smoke
mir_verifier_guard: guard-mir-lower-provenance-metadata-smoke
mir_to_c_guard: guard-mir-to-c-provenance-metadata-smoke
native_execution_guard: guard-mir-to-c-provenance-metadata-native-smoke
expected_behavior: native executable exits with status 2
native executable exits with status `2`

The current verifier slot is backed by focused MIR structural invariant guards until a dedicated MIR verifier target exists.
# MIR Feature Migration Harness

MIR_FEATURE_MIGRATION_HARNESS_VERSION: 1
MIR_FEATURE_MIGRATION_PHASE: phase6-branch-preservation-entry
MIR_FEATURE_MIGRATION_NO_FEATURES_MIGRATED: false

This file defines the Phase 5 feature migration harness contract without migrating any additional AST-to-C feature yet.

Each migrated feature must eventually get a preservation entry that proves this shape:

```text
source Gust fixture
  -> old AST-to-C expected behavior
  -> MIR lowering
  -> MIR verifier or focused MIR structural invariant guard
  -> MIR-to-C
  -> native execution
  -> same expected behavior
```

## Required preservation fields for future entries

Every migrated feature entry must name:

- `feature_name`
- `source_fixture`
- `old_behavior_guard`
- `mir_lowering_guard`
- `mir_verifier_guard`
- `mir_to_c_guard`
- `native_execution_guard`
- `expected_behavior`

## Registered preservation entries

### return_int_literal

- `feature_name`: `return_int_literal`
- `source_fixture`: `compiler/mir_feature_return_int_preservation_source.gst`
- `old_behavior_guard`: `guard-mir-feature-return-int-preservation`
- `mir_lowering_guard`: `guard-mir-lower-return-int-literal-smoke`
- `mir_verifier_guard`: `guard-mir-lower-return-int-literal-smoke`
- `mir_to_c_guard`: `guard-mir-to-c-return-int-literal-smoke`
- `native_execution_guard`: `guard-mir-to-c-return-int-literal-native-smoke`
- `expected_behavior`: native executable exits with status `1`

The current verifier slot is backed by the focused return-int MIR structural invariant guard until a dedicated MIR verifier target exists.
