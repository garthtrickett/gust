# Cranelift Phase 21 Collection and String Native Source Migration

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_collection_string_native_source.py project`. Do not edit by hand.

- Contract: `phase21_collection_string_native_source_v2`
- Status: `patch21_9_complete`
- Next patch: `21.10`
- Scope: `bounded_compiler_owned_collection_and_string_source_cohort_with_conservative_pre_driver_rejection_outside_the_represented_shapes`
- Source route: `typed_AST_operations_lower_to_canonical_MIR_without_source_path_fixture_name_or_generated_C_recognition`

## Generic capability transition

- `scheduled_defer_call_edges`: `represented_for_paired_arena_acquisition_and_scope_exit_source_shape`
  - Canonical evidence: `observable_effect_CFG_preserves_oracle_behavior`
- `call_result_condition_cfg`: `implemented`
  - Canonical evidence: `LocalI32Set_then_BranchLocalI32Positive_then_join`
- `generic_receiver_and_aggregate_result_calls`: `represented_for_typed_Vector_receiver_get_opt_cohort`
  - Canonical evidence: `typed_AST_receiver_and_aggregate_result_are_resolved_before_canonical_CFG_emission`
- `enum_match_payload_cfg`: `implemented_for_Option_payload_match`
  - Canonical evidence: `then_and_else_blocks_join_before_return`
- `string_view_byte_and_cast_operations`: `represented_for_str_slice_str_eq_str_byte_at_and_int_cast_cohort`
  - Canonical evidence: `typed_AST_operations_produce_str_and_int_canonical_call_arguments`

## Source differential cases

- `collections_primary` — `compiler/phase20_component_collections_source.gst`
  - Exit: `0`
  - Stdout: `32300a` (hex)
  - Stderr: empty
- `collections_renamed_variant` — `compiler/phase21_collection_native_source_variant.gst`
  - Exit: `0`
  - Stdout: `34320a` (hex)
  - Stderr: empty
- `strings_primary` — `compiler/phase20_component_strings_source.gst`
  - Exit: `0`
  - Stdout: `48656c6c6f0a310a38370a` (hex)
  - Stderr: empty
- `strings_renamed_variant` — `compiler/phase21_string_native_source_variant.gst`
  - Exit: `0`
  - Stdout: `4e61746976650a370a38320a` (hex)
  - Stderr: empty
- `strings_embedded_newline` — `compiler/phase21_string_native_embedded_newline.gst`
  - Exit: `0`
  - Stdout: `4e61746976650a526f7574650a370a38320a` (hex)
  - Stderr: empty

## Conservative rejection cases

- `collections_extra_effect` — `compiler/phase21_collection_native_source_outside_cohort.gst`
  - Expected failure stage: `before_driver_discovery`
  - MIR-to-C stdout: `32300a3939390a` (hex)
- `strings_extra_effect` — `compiler/phase21_string_native_source_outside_cohort.gst`
  - Expected failure stage: `before_driver_discovery`
  - MIR-to-C stdout: `48656c6c6f0a310a38370a3939390a` (hex)
- `collections_unrepresented_log_expression` — `compiler/phase21_collection_native_unrepresented_log_expression.gst`
  - Expected failure stage: `before_driver_discovery`
  - MIR-to-C stdout: `34330a` (hex)
- `strings_unrepresented_log_expression` — `compiler/phase21_string_native_unrepresented_log_expression.gst`
  - Expected failure stage: `before_driver_discovery`
  - MIR-to-C stdout: `4e6174697665210a370a38320a` (hex)

## Canonical and runtime boundary

- Format: `gust.compiler_mir_ingestion.v2`
- Operations: `LocalI32Set, BranchLocalI32Positive, CallVoid, Jump, ReturnI32`
- Types: `int, str, void`
- Runtime imports: `os_LogInt, os_LogStr`
- Runtime archive: `build/gust-runtime-package.a` from `src/runtime/arena.c, src/runtime/host_io.c`
- Archive-provided symbols: `os_ArenaAlloc, os_Arena_Free, os_Arena_New, os_Arena_Validate, os_Args, os_LogError, os_LogInt, os_LogStr, os_MockPayload, os_argc, os_argv, std_GenerationalSwap`
- New or changed runtime symbols: none
- Generated C or fallback in the qualified route: none

## Remaining boundary

Patch 21.9 is deliberately bounded to the represented compiler-owned
collection/string source cohort. Unrepresented shapes still reject
before driver discovery. Filesystem and allocation remain Patch 21.10;
resources and synchronization remain Patch 21.11.
