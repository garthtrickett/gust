# Cranelift Phase 21 Residue Migration Authority

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_residue_migration_authority.py project`. Do not edit by hand.

- Contract: `phase21_residue_migration_authority_v1`
- Status: `patch21_8_complete`
- Next patch: `21.9`
- Observed main: `59ae01923a157b7b6e7a74c1b50499ef9c597f36`
- Early rejection: `every_unimplemented_residue_and_the_full_compiler_reject_before_driver_discovery_without_an_artifact`

## Residue ownership

- `collections` → Patch `21.9`
  - Fixture: `compiler/phase20_component_collections_source.gst`
  - Current: `deferred` / `deferred_p13_structured_cfg_non_reducible_shape` at `before_driver_discovery`
  - Capabilities: `scheduled_defer_call_edges, generic_receiver_and_aggregate_result_calls, enum_match_payload_cfg`
- `strings` → Patch `21.9`
  - Fixture: `compiler/phase20_component_strings_source.gst`
  - Current: `deferred` / `deferred_p13_structured_cfg_condition_shape` at `before_driver_discovery`
  - Capabilities: `call_result_condition_cfg, string_view_byte_and_cast_operations`
- `filesystem` → Patch `21.10`
  - Fixture: `compiler/phase20_component_filesystem_source.gst`
  - Current: `deferred` / `source_feature_not_represented` at `before_driver_discovery`
  - Capabilities: `scheduled_defer_call_edges, approved_filesystem_runtime_calls`
- `allocation` → Patch `21.10`
  - Fixture: `compiler/phase20_component_allocation_source.gst`
  - Current: `deferred` / `source_feature_not_represented` at `before_driver_discovery`
  - Capabilities: `scheduled_defer_call_edges, branded_arena_allocation_write_and_index`
- `resources` → Patch `21.11`
  - Fixture: `compiler/phase20_resource_scope_cleanup_source.gst`
  - Current: `source_or_type_failure` / `source_or_type_failure` at `before_driver_discovery`
  - Capabilities: `resource_declaration_module_inventory, resource_terminal_state_cleanup_edges`
- `threading_synchronization` → Patch `21.11`
  - Fixture: `compiler/phase20_component_threading_source.gst`
  - Current: `deferred` / `deferred_p13_parameter_argument_target_dependent_abi` at `before_driver_discovery`
  - Capabilities: `scheduled_defer_call_edges, branded_arena_allocation_write_and_index, function_reference_parameter_call_abi, synchronization_protected_access_and_runtime_calls`

## Generic capability order

1. `scheduled_defer_call_edges` — Patch `21.9`
   - Surface: `generic_deferred_call_scheduling_and_exactly_once_scope_exit_edges`
   - Depends on: `none`
   - First compiler consumers: `test_runner_entry.gst`
   - State: `planned_early_rejection_preserved`
2. `call_result_condition_cfg` — Patch `21.9`
   - Surface: `generic_boolean_call_results_as_if_and_loop_conditions_with_join_consistency`
   - Depends on: `none`
   - First compiler consumers: `lexer.gst, parser.gst`
   - State: `planned_early_rejection_preserved`
3. `generic_receiver_and_aggregate_result_calls` — Patch `21.9`
   - Surface: `generic_selector_receiver_calls_with_branded_arguments_and_aggregate_results`
   - Depends on: `none`
   - First compiler consumers: `lexer.gst, ast.gst`
   - State: `planned_early_rejection_preserved`
4. `enum_match_payload_cfg` — Patch `21.9`
   - Surface: `generic_enum_match_discriminant_payload_binding_and_branch_join_lowering`
   - Depends on: `generic_receiver_and_aggregate_result_calls`
   - First compiler consumers: `parser.gst, typechecker.gst`
   - State: `planned_early_rejection_preserved`
5. `string_view_byte_and_cast_operations` — Patch `21.9`
   - Surface: `generic_string_view_return_byte_projection_and_integer_cast_operations`
   - Depends on: `call_result_condition_cfg`
   - First compiler consumers: `lexer.gst, test_runner_entry.gst`
   - State: `planned_early_rejection_preserved`
6. `approved_filesystem_runtime_calls` — Patch `21.10`
   - Surface: `approved_filesystem_runtime_calls_with_arena_and_string_arguments_results_and_effect_order`
   - Depends on: `scheduled_defer_call_edges, string_view_byte_and_cast_operations`
   - First compiler consumers: `resolver.gst, test_runner_entry.gst`
   - State: `planned_early_rejection_preserved`
7. `branded_arena_allocation_write_and_index` — Patch `21.10`
   - Surface: `generic_branded_arena_allocation_aggregate_write_index_read_and_field_projection`
   - Depends on: `scheduled_defer_call_edges`
   - First compiler consumers: `ast.gst, parser.gst, typechecker.gst`
   - State: `planned_early_rejection_preserved`
8. `resource_declaration_module_inventory` — Patch `21.11`
   - Surface: `generic_module_inventory_for_resource_attributes_types_destructors_and_function_signatures`
   - Depends on: `none`
   - First compiler consumers: `mir_resource_authority.gst, typechecker.gst`
   - State: `planned_early_rejection_preserved`
9. `resource_terminal_state_cleanup_edges` — Patch `21.11`
   - Surface: `generic_resource_move_manual_close_scheduled_close_and_automatic_cleanup_on_all_cfg_exits`
   - Depends on: `scheduled_defer_call_edges, call_result_condition_cfg, enum_match_payload_cfg, branded_arena_allocation_write_and_index, resource_declaration_module_inventory`
   - First compiler consumers: `typechecker.gst, mir_resource_value.gst`
   - State: `planned_early_rejection_preserved`
10. `function_reference_parameter_call_abi` — Patch `21.11`
   - Surface: `generic_function_reference_pointer_parameter_argument_and_target_abi_call_lowering`
   - Depends on: `branded_arena_allocation_write_and_index`
   - First compiler consumers: `codegen.gst, mir_native_backend_source_route.gst`
   - State: `planned_early_rejection_preserved`
11. `synchronization_protected_access_and_runtime_calls` — Patch `21.11`
   - Surface: `generic_resource_guarded_protected_access_and_approved_spawn_yield_synchronization_calls`
   - Depends on: `resource_terminal_state_cleanup_edges, function_reference_parameter_call_abi`
   - First compiler consumers: `qualification tail`
   - State: `planned_qualification_tail_not_required_by_current_compiler_graph`

## Compiler qualification order

The live transitive graph rooted at `test_runner_entry.gst` contains
`38` modules and `116` import edges.

1. `lexical_ast_foundations`
   - Depends on: `none`
   - Modules: `token.gst, lexer.gst, errors.gst, ast.gst`
2. `parser_type_resolver`
   - Depends on: `lexical_ast_foundations`
   - Modules: `parser.gst, typechecker.gst, resolver.gst`
3. `canonical_mir_authorities`
   - Depends on: `lexical_ast_foundations`
   - Modules: `mir_layout.gst, mir_resource_authority.gst, mir_function_abi_authority.gst, mir_function_call.gst, mir_integer_conversion.gst, mir_pointer.gst, mir_stack_slot.gst, mir_memory_access.gst, mir_string_view.gst, mir_array_slice.gst, mir_struct_layout.gst, mir_enum.gst, mir_aggregate_transport.gst, mir_resource_value.gst, mir.gst`
4. `code_generation`
   - Depends on: `parser_type_resolver, canonical_mir_authorities`
   - Modules: `codegen.gst`
5. `native_source_lowering`
   - Depends on: `lexical_ast_foundations, canonical_mir_authorities`
   - Modules: `mir_native_backend_capability.gst, mir_native_backend_driver.gst, mir_native_backend_block_parameter_loop_source.gst, mir_native_backend_metadata_source.gst, mir_native_backend_direct_call_source.gst, mir_native_backend_local_state_source.gst, mir_native_backend_module_import_source.gst, mir_native_backend_parameter_argument_source.gst, mir_native_backend_structured_cfg_source.gst, mir_native_backend_scalar_expression_source.gst, mir_native_backend_generic_source.gst`
6. `native_request_route_and_entry`
   - Depends on: `parser_type_resolver, canonical_mir_authorities, code_generation, native_source_lowering`
   - Modules: `mir_primitive_layout.gst, mir_native_backend_request.gst, mir_native_backend_source_route.gst, test_runner_entry.gst`

## Preserved full-compiler baseline

- Fixture: `compiler/test_runner_entry.gst`
- Current: exit `1`, `source_or_type_failure` / `source_or_type_failure`
- Diagnostic: `Native backend canonical MIR verification failed: unsupported top-level statement in module/import cohort`
- Failure stage: `before_driver_discovery`; artifact: `absent`

Patch 21.8 classifies and orders work only. It changes no accepted
program meaning, MIR/backend behavior, ABI/layout, runtime symbol,
bootstrap seed, or Stdlib surface, and implements no Patch 21.9+ row.
