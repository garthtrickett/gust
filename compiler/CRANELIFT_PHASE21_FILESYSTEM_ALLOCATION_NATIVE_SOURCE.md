# Cranelift Phase 21 Filesystem and Allocation Native Source Migration

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_filesystem_allocation_native_source.py project`. Do not edit by hand.

- Contract: `phase21_filesystem_allocation_native_source_v1`
- Status: `patch21_10_complete`
- Next patch: `21.11`
- Scope: `bounded_compiler_owned_filesystem_and_branded_arena_allocation_source_cohort_with_conservative_pre_driver_rejection_outside_the_represented_shapes`
- Source route: `typed_AST_operations_lower_to_canonical_MIR_without_source_path_fixture_name_type_name_or_generated_C_recognition`

## Generic capability transition

- `scheduled_defer_call_edges`: `reused_for_paired_arena_acquisition_and_scope_exit`
  - Canonical evidence: `ArenaInit_precedes_observable_work_and_os_Arena_Free_is_the_terminal_call`
- `approved_filesystem_runtime_calls`: `implemented_for_WriteFile_and_ReadFile`
  - Canonical evidence: `typed_string_and_arena_arguments_plus_int_and_string_results_are_explicit_canonical_calls`
- `branded_arena_allocation_write_and_index`: `implemented_for_one_int_field_aggregate`
  - Canonical evidence: `ArenaInit_LocalI32SetCall_ArenaStoreI32_LocalI32SetArenaLoad`

## Source differential cases

- `filesystem_primary` — `compiler/phase20_component_filesystem_source.gst`
  - Exit: `0`
  - Stdout: `310a706861736532300a` (hex)
  - Stderr: empty
  - File: `phase20-component-file.txt` = `70686173653230` (hex)
- `filesystem_renamed_variant` — `compiler/phase21_filesystem_native_source_variant.gst`
  - Exit: `0`
  - Stdout: `310a706861736532310a` (hex)
  - Stderr: empty
  - File: `phase21-filesystem-variant.txt` = `70686173653231` (hex)
- `allocation_primary` — `compiler/phase20_component_allocation_source.gst`
  - Exit: `0`
  - Stdout: `34390a` (hex)
  - Stderr: empty
- `allocation_renamed_variant` — `compiler/phase21_allocation_native_source_variant.gst`
  - Exit: `0`
  - Stdout: `37330a` (hex)
  - Stderr: empty

## Conservative rejection cases

- `filesystem_computed_write_contents` — `compiler/phase21_filesystem_native_source_outside_cohort.gst`
  - Expected failure stage: `before_driver_discovery`
  - MIR-to-C stdout: `310a706861736532300a` (hex)
- `allocation_computed_field_value` — `compiler/phase21_allocation_native_source_outside_cohort.gst`
  - Expected failure stage: `before_driver_discovery`
  - MIR-to-C stdout: `34390a` (hex)

## Canonical and runtime boundary

- Format: `gust.compiler_mir_ingestion.v2`
- Operations: `ArenaInit, LocalI32SetCall, LocalStringSetCall, ArenaStoreI32, LocalI32SetArenaLoad, CallVoid, ReturnI32`
- Types: `arena, usize, int, str, void`
- Runtime imports: `os_Arena_New, os_Arena_Free, os_ArenaAlloc, os_WriteFile, os_ReadFile, os_LogInt, os_LogStr`
- Arena allocation provenance: earlier same-block imported `os_ArenaAlloc` link symbol, same arena, literal size
- Arena access range: non-negative byte offset plus the four-byte `i32` width must fit the recorded allocation
- Arena index reassignment clears allocation provenance
- Runtime archive: `build/gust-runtime-package.a` from `src/runtime/arena.c, src/runtime/host_io.c, src/runtime/file_io.c`
- New or changed runtime symbols: none
- Generated C or fallback in the qualified route: none

## Remaining boundary

Patch 21.10 is bounded to the represented filesystem and one-int-field
branded arena allocation cohorts. Computed write contents and computed
stored values still reject before driver discovery. Resources and
synchronization remain Patch 21.11.
