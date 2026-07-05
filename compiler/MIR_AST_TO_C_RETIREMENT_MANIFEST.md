# MIR AST-to-C Retirement Manifest

MIR_AST_TO_C_RETIREMENT_MANIFEST_VERSION: 1
MIR_AST_TO_C_RETIREMENT_MANIFEST_PHASE: phase8-if-else-return-int-ast-to-c-retired-entry
MIR_AST_TO_C_RETIREMENT_MANIFEST_ENTRY_COUNT: 4
MIR_FEATURE_MIGRATION_REGISTRY: compiler/MIR_FEATURE_MIGRATION_REGISTRY.md

This manifest is the machine-checkable source of truth for gradually retiring legacy AST-to-C coverage after a feature has enough MIR lowering, MIR-to-C, and native execution validation.

Phase 8 starts with documentation and guard wiring only. No compiler routing changes are made by this manifest.

## Status values

- `still_required`: the legacy AST-to-C behavior check must continue to run for this feature.
- `retirement_candidate`: the feature has MIR-owned validation and is ready for a focused routing-retirement step.
- `retired`: the feature no longer requires the old AST-to-C behavior check as part of the primary migration validation path.

## Entry schema

Each entry must provide these fields:

- `feature_name`
- `source_fixture`
- `old_behavior_guard`
- `mir_lowering_guard`
- `mir_to_c_guard`
- `native_execution_guard`
- `ast_to_c_status`
- `retirement_note`

A feature may also provide these fields once Phase 8 adds MIR-owned validation and MIR-preferred routing for it:

- `mir_owned_validation_guard`
- `preferred_codegen_route`
- `routed_execution_guard`

## Entries

### return_int_literal

feature_name: return_int_literal
source_fixture: compiler/mir_feature_return_int_preservation_source.gst
old_behavior_guard: guard-mir-feature-return-int-preservation
mir_lowering_guard: guard-mir-lower-return-int-literal-smoke
mir_to_c_guard: guard-mir-to-c-return-int-literal-smoke
native_execution_guard: guard-mir-to-c-return-int-literal-native-smoke
mir_owned_validation_guard: guard-mir-owned-return-int-literal-validation
preferred_codegen_route: mir_to_c
routed_execution_guard: guard-mir-feature-return-int-routed-execution
ast_to_c_status: retired
retirement_note: Phase 8 has retired this feature from primary AST-to-C validation because MIR-preferred routed execution passes; the legacy old_behavior_guard remains available for manual compatibility checks.

### local_binding_read

feature_name: local_binding_read
source_fixture: compiler/mir_feature_local_binding_read_preservation_source.gst
old_behavior_guard: guard-mir-feature-local-binding-read-preservation
mir_lowering_guard: guard-mir-lower-local-binding-read-smoke
mir_to_c_guard: guard-mir-to-c-local-binding-read-smoke
native_execution_guard: guard-mir-to-c-local-binding-read-native-smoke
mir_owned_validation_guard: guard-mir-owned-local-binding-read-validation
preferred_codegen_route: mir_to_c
routed_execution_guard: guard-mir-feature-local-binding-read-routed-execution
ast_to_c_status: retired
retirement_note: Phase 8 has retired local_binding_read from primary AST-to-C validation because MIR-preferred routed execution passes; the legacy old_behavior_guard remains available for manual compatibility checks.

### if_else_return_int

feature_name: if_else_return_int
source_fixture: compiler/mir_feature_if_else_return_int_preservation_source.gst
old_behavior_guard: guard-mir-feature-if-else-return-int-preservation
mir_lowering_guard: guard-mir-lower-conditional-branch-smoke
mir_to_c_guard: guard-mir-to-c-conditional-branch-smoke
native_execution_guard: guard-mir-to-c-conditional-branch-native-smoke
mir_owned_validation_guard: guard-mir-owned-if-else-return-int-validation
preferred_codegen_route: mir_to_c
routed_execution_guard: guard-mir-feature-if-else-return-int-routed-execution
ast_to_c_status: retired
retirement_note: Phase 8 has retired if_else_return_int from primary AST-to-C validation because MIR-preferred routed execution passes; the legacy old_behavior_guard remains available for manual compatibility checks.

### local_binding_read_provenance_metadata

feature_name: local_binding_read_provenance_metadata
source_fixture: compiler/mir_feature_local_binding_read_provenance_metadata_preservation_source.gst
old_behavior_guard: guard-mir-feature-local-binding-read-provenance-metadata-preservation
mir_lowering_guard: guard-mir-lower-provenance-metadata-smoke
mir_to_c_guard: guard-mir-to-c-provenance-metadata-smoke
native_execution_guard: guard-mir-to-c-provenance-metadata-native-smoke
ast_to_c_status: still_required
retirement_note: Phase 8 has not added MIR-preferred routing for this metadata-preservation feature yet.
