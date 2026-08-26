# Cranelift Phase 21 Compiler Support-Library Native Qualification

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_compiler_support_native_qualification.py project`. Do not edit by hand.

- Contract: `phase21_compiler_support_native_qualification_v1`
- Status: `patch21_12_complete`
- Next patch: `21.13`
- Observed main: `302c902e69112a510543ff6c5d720d39872f02ea`
- Patch 21.8 graph authority: `38` modules / `116` import edges
- Current graph after Patches 21.9–21.11: `41` modules / `125` import edges
- Successor migration modules: `mir_native_backend_collection_string_source.gst, mir_native_backend_filesystem_allocation_source.gst, mir_native_backend_resource_sync_source.gst`
- Qualified support population: `34` modules / `87` dependency edges (`72` support-to-support)

## Topological support slices

1. `lexical_ast_foundations` — `3` modules / `2` dependency edges
   - Root: `compiler/phase21_support_lexical_ast_slice.gst`
   - Modules: `token.gst, errors.gst, ast.gst`
   - MIR-to-C: accepted; linked executable exits 0 with empty stdout/stderr
   - Explicit Cranelift: `source_or_type_failure` at `before_driver_discovery`; canonical MIR `absent_before_driver_discovery`; artifact `absent`
   - Diagnostic: `Native backend canonical MIR verification failed: unsupported top-level statement in module/import cohort`
   - Local baselines: MIR-to-C `40ms` / `21376KiB`; Cranelift `30ms` / `17024KiB`
2. `canonical_mir_authorities` — `14` modules / `22` dependency edges
   - Root: `compiler/phase21_support_canonical_mir_slice.gst`
   - Modules: `mir_layout.gst, mir_resource_authority.gst, mir_function_abi_authority.gst, mir_function_call.gst, mir_integer_conversion.gst, mir_pointer.gst, mir_stack_slot.gst, mir_memory_access.gst, mir_string_view.gst, mir_array_slice.gst, mir_struct_layout.gst, mir_enum.gst, mir_aggregate_transport.gst, mir_resource_value.gst`
   - MIR-to-C: accepted; linked executable exits 0 with empty stdout/stderr
   - Explicit Cranelift: `source_or_type_failure` at `before_driver_discovery`; canonical MIR `absent_before_driver_discovery`; artifact `absent`
   - Diagnostic: `Native backend canonical MIR verification failed: unsupported top-level statement in module/import cohort`
   - Local baselines: MIR-to-C `2340ms` / `464128KiB`; Cranelift `1610ms` / `381056KiB`
3. `native_source_lowering` — `14` modules / `44` dependency edges
   - Root: `compiler/phase21_support_native_source_slice.gst`
   - Modules: `mir_native_backend_capability.gst, mir_native_backend_driver.gst, mir_native_backend_block_parameter_loop_source.gst, mir_native_backend_metadata_source.gst, mir_native_backend_direct_call_source.gst, mir_native_backend_local_state_source.gst, mir_native_backend_module_import_source.gst, mir_native_backend_parameter_argument_source.gst, mir_native_backend_structured_cfg_source.gst, mir_native_backend_scalar_expression_source.gst, mir_native_backend_collection_string_source.gst, mir_native_backend_filesystem_allocation_source.gst, mir_native_backend_resource_sync_source.gst, mir_native_backend_generic_source.gst`
   - MIR-to-C: accepted; linked executable exits 0 with empty stdout/stderr
   - Explicit Cranelift: `source_or_type_failure` at `before_driver_discovery`; canonical MIR `absent_before_driver_discovery`; artifact `absent`
   - Diagnostic: `Native backend canonical MIR verification failed: unsupported top-level statement in module/import cohort`
   - Local baselines: MIR-to-C `11310ms` / `1702144KiB`; Cranelift `7300ms` / `1375488KiB`
4. `native_request_route_and_entry` — `3` modules / `19` dependency edges
   - Root: `compiler/phase21_support_native_request_slice.gst`
   - Modules: `mir_primitive_layout.gst, mir_native_backend_request.gst, mir_native_backend_source_route.gst`
   - MIR-to-C: accepted; linked executable exits 0 with empty stdout/stderr
   - Explicit Cranelift: `source_or_type_failure` at `before_driver_discovery`; canonical MIR `absent_before_driver_discovery`; artifact `absent`
   - Diagnostic: `Native backend canonical MIR verification failed: unsupported top-level statement in module/import cohort`
   - Local baselines: MIR-to-C `12590ms` / `1760128KiB`; Cranelift `7490ms` / `1419520KiB`

## Classification

- Resource state: `compiler_process_only_no_native_program_or_runtime_resource_acquisition`
- Remaining generic capability: `generic_compiler_module_top_level_declaration_lowering`
- Destination: Patch `21.13`
- Policy: `generic_capability_row_required_no_module_specific_exception`
- Selected modules reserved for Patch 21.13: `lexer.gst, parser.gst, resolver.gst, typechecker.gst, mir.gst, codegen.gst`
- Full compiler entry reserved for Patch 21.14: `test_runner_entry.gst`

Patch 21.12 is qualification evidence only. It adds no accepted source
meaning, canonical MIR operation, backend capability, ABI/layout or runtime
symbol, bootstrap seed, fallback, default-backend change, or Stdlib work.
