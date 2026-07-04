# MIR Feature Migration Registry

MIR_FEATURE_MIGRATION_REGISTRY_VERSION: 1
MIR_FEATURE_MIGRATION_REGISTRY_PHASE: second-preservation-entry
MIR_FEATURE_MIGRATION_REGISTRY_ENTRY_COUNT: 2

This registry is the machine-checkable source of truth for migrated MIR feature preservation entries.

The harness contract describes the required preservation shape. This registry records the concrete feature entries that must preserve old AST-to-C behavior while proving the MIR lowering, MIR-to-C, and native-execution path.

## Entry schema

Each entry must provide these fields:

- `feature_name`
- `source_fixture`
- `old_behavior_guard`
- `mir_lowering_guard`
- `mir_verifier_guard`
- `mir_to_c_guard`
- `native_execution_guard`
- `expected_behavior`

## Entries

### return_int_literal

feature_name: return_int_literal
source_fixture: compiler/mir_feature_return_int_preservation_source.gst
old_behavior_guard: guard-mir-feature-return-int-preservation
mir_lowering_guard: guard-mir-lower-return-int-literal-smoke
mir_verifier_guard: guard-mir-lower-return-int-literal-smoke
mir_to_c_guard: guard-mir-to-c-return-int-literal-smoke
native_execution_guard: guard-mir-to-c-return-int-literal-native-smoke
expected_behavior: native executable exits with status 1

### local_binding_read

feature_name: local_binding_read
source_fixture: compiler/mir_feature_local_binding_read_preservation_source.gst
old_behavior_guard: guard-mir-feature-local-binding-read-preservation
mir_lowering_guard: guard-mir-lower-local-binding-read-smoke
mir_verifier_guard: guard-mir-lower-local-binding-read-smoke
mir_to_c_guard: guard-mir-to-c-local-binding-read-smoke
native_execution_guard: guard-mir-to-c-local-binding-read-native-smoke
expected_behavior: native executable exits with status 2

feature_name: local_binding_read_provenance_metadata
source_fixture: compiler/mir_feature_local_binding_read_provenance_metadata_preservation_source.gst
old_behavior_guard: guard-mir-feature-local-binding-read-provenance-metadata-preservation
mir_lowering_guard: guard-mir-lower-provenance-metadata-smoke
mir_verifier_guard: guard-mir-lower-provenance-metadata-smoke
mir_to_c_guard: guard-mir-to-c-provenance-metadata-smoke
native_execution_guard: guard-mir-to-c-provenance-metadata-native-smoke
expected_behavior: native executable exits with status 2

### if_else_return_int

feature_name: if_else_return_int
source_fixture: compiler/mir_feature_if_else_return_int_preservation_source.gst
old_behavior_guard: guard-mir-feature-if-else-return-int-preservation
mir_lowering_guard: guard-mir-lower-conditional-branch-smoke
mir_verifier_guard: guard-mir-lower-conditional-branch-smoke
mir_to_c_guard: guard-mir-to-c-conditional-branch-smoke
native_execution_guard: guard-mir-to-c-conditional-branch-native-smoke
expected_behavior: native executable exits with status 1

### local_binding_read

feature_name: local_binding_read
source_fixture: compiler/mir_feature_local_binding_read_preservation_source.gst
old_behavior_guard: guard-mir-feature-local-binding-read-preservation
mir_lowering_guard: guard-mir-lower-local-binding-read-smoke
mir_verifier_guard: guard-mir-lower-local-binding-read-smoke
mir_to_c_guard: guard-mir-to-c-local-binding-read-smoke
native_execution_guard: guard-mir-to-c-local-binding-read-native-smoke
expected_behavior: native executable exits with status 2
# MIR Feature Migration Registry

MIR_FEATURE_MIGRATION_REGISTRY_VERSION: 1
MIR_FEATURE_MIGRATION_REGISTRY_PHASE: phase7-provenance-metadata-preservation-entry
MIR_FEATURE_MIGRATION_REGISTRY_ENTRY_COUNT: 4

This registry is the machine-checkable source of truth for migrated MIR feature preservation entries.

The harness contract describes the required preservation shape. This registry records the concrete feature entries that must preserve old AST-to-C behavior while proving the MIR lowering, MIR-to-C, and native-execution path.

## Entry schema

Each entry must provide these fields:

- `feature_name`
- `source_fixture`
- `old_behavior_guard`
- `mir_lowering_guard`
- `mir_verifier_guard`
- `mir_to_c_guard`
- `native_execution_guard`
- `expected_behavior`

## Entries

### return_int_literal

feature_name: return_int_literal
source_fixture: compiler/mir_feature_return_int_preservation_source.gst
old_behavior_guard: guard-mir-feature-return-int-preservation
mir_lowering_guard: guard-mir-lower-return-int-literal-smoke
mir_verifier_guard: guard-mir-lower-return-int-literal-smoke
mir_to_c_guard: guard-mir-to-c-return-int-literal-smoke
native_execution_guard: guard-mir-to-c-return-int-literal-native-smoke
expected_behavior: native executable exits with status 1
