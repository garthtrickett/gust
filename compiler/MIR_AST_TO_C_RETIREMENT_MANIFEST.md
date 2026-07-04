# MIR AST-to-C Retirement Manifest

MIR_AST_TO_C_RETIREMENT_MANIFEST_VERSION: 1
MIR_AST_TO_C_RETIREMENT_MANIFEST_PHASE: phase8-return-int-retirement-candidate-entry
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

A feature may also provide this field once Phase 8 adds a MIR-owned validation lane for it:

- `mir_owned_validation_guard`

## Entries

### return_int_literal

feature_name: return_int_literal
source_fixture: compiler/mir_feature_return_int_preservation_source.gst
old_behavior_guard: guard-mir-feature-return-int-preservation
mir_lowering_guard: guard-mir-lower-return-int-literal-smoke
mir_to_c_guard: guard-mir-to-c-return-int-literal-smoke
native_execution_guard: guard-mir-to-c-return-int-literal-native-smoke
mir_owned_validation_guard: guard-mir-owned-return-int-literal-validation
ast_to_c_status: retirement_candidate
retirement_note: Phase 8 has marked this feature as the first retirement candidate because MIR-owned validation passes; legacy AST-to-C behavior validation remains required until MIR-preferred routing lands.

### local_binding_read

feature_name: local_binding_read
source_fixture: compiler/mir_feature_local_binding_read_preservation_source.gst
old_behavior_guard: guard-mir-feature-local-binding-read-preservation
mir_lowering_guard: guard-mir-lower-local-binding-read-smoke
mir_to_c_guard: guard-mir-to-c-local-binding-read-smoke
native_execution_guard: guard-mir-to-c-local-binding-read-native-smoke
ast_to_c_status: still_required
retirement_note: Phase 8 has not added MIR-preferred routing for this feature yet.

### if_else_return_int

feature_name: if_else_return_int
source_fixture: compiler/mir_feature_if_else_return_int_preservation_source.gst
old_behavior_guard: guard-mir-feature-if-else-return-int-preservation
mir_lowering_guard: guard-mir-lower-conditional-branch-smoke
mir_to_c_guard: guard-mir-to-c-conditional-branch-smoke
native_execution_guard: guard-mir-to-c-conditional-branch-native-smoke
ast_to_c_status: still_required
retirement_note: Phase 8 has not added MIR-preferred routing for this feature yet.

### local_binding_read_provenance_metadata

feature_name: local_binding_read_provenance_metadata
source_fixture: compiler/mir_feature_local_binding_read_provenance_metadata_preservation_source.gst
old_behavior_guard: guard-mir-feature-local-binding-read-provenance-metadata-preservation
mir_lowering_guard: guard-mir-lower-provenance-metadata-smoke
mir_to_c_guard: guard-mir-to-c-provenance-metadata-smoke
native_execution_guard: guard-mir-to-c-provenance-metadata-native-smoke
ast_to_c_status: still_required
retirement_note: Phase 8 has not added MIR-preferred routing for this metadata-preservation feature yet.
