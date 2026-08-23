# Cranelift Phase 20 Opening Evidence

Generated from `scripts/cranelift_feature_registry.json` and
`scripts/cranelift_test_levels.json` by `scripts/phase20_opening.py`.
Do not edit by hand.

- Opening version: `phase20_opening_evidence_and_qualification_authority_v1`
- Status: `ready_for_patch20_10`
- Roadmap merge: `1cfab1344b24ffefc72b4d752ead3eb17c6719c6`
- Baseline probes: `5`
- Canonical feature entries: `95`
- Composition links: `71`
- Deferred-source links: `82`
- Historical Full Level 3 guards: `160`

## Baseline probes

| ID | Requirement | Fixture | Current exit | Current verdict | Owner patch |
| --- | --- | --- | ---: | --- | --- |
| `cr11_explicit_graph_annotation` | CR-11/#158 | `compiler/future/p20_cr11_explicit_graph_annotation_current.gst` | 0 | accepts_explicit_graph_annotation_with_resolved_nested_brand_identity | 20.2 |
| `cr12_wrong_brand_clone_destination` | CR-12/#159 | `compiler/future/p20_cr12_wrong_brand_clone_current.gst` | 1 | rejects_distinct_destination_brand_at_generic_type_boundary | 20.3 |
| `cr13_freed_receiver_reuse` | CR-13/#160 | `compiler/future/p20_cr13_free_receiver_reuse_current.gst` | 1 | rejects_clone_through_freed_arena_receiver | 20.5 |
| `issue106_unbound_directory_payload` | CR-5/#106 | `compiler/future/p20_issue106_unbound_directory_current.gst` | 1 | rejects_unbound_directory_through_acquisition_identity | 20.9 |
| `issue106_bound_directory_control` | CR-5/#106 | `compiler/future/p20_issue106_bound_directory_current.gst` | 1 | rejects_bound_directory_through_acquisition_identity | 20.9 |

The current verdict is evidence. CR-11, CR-12, CR-13, and the two
#106 acquisition probes are enabled by Patches 20.2, 20.3, 20.5,
and 20.9 respectively.

## Qualification decisions

| Registry status | Phase 20 decision | Entries |
| --- | --- | ---: |
| `migrated` | `selected` | 34 |
| `candidate_deferred` | `deferred` | 43 |
| `deferred` | `deferred` | 7 |
| `replaced` | `unsupported_historical_replaced` | 11 |

## Canonical source/differential inventory

| Entry | Status | Decision | Route owner | Worker owner | Diagnostic owner | Source | Differential case |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `return_int` | `migrated` | `selected` | `generic_canonical_mir` | `worker_scalar_expression_lowering` | `canonical_mir_scalar_verifier` | `compiler/phase11_scalar_literal_source.gst` | `phase11_registry_differential:return_int` |
| `local_binding_read` | `migrated` | `selected` | `generic_canonical_mir` | `worker_local_state_lowering` | `canonical_mir_scalar_verifier` | `compiler/phase11_local_state_read_after_write_source.gst` | `phase11_registry_differential:local_binding_read` |
| `add_i32` | `migrated` | `selected` | `generic_canonical_mir` | `worker_scalar_expression_lowering` | `canonical_mir_scalar_verifier` | `compiler/phase11_scalar_add_source.gst` | `phase11_registry_differential:add_i32` |
| `conditional_branch` | `migrated` | `selected` | `generic_canonical_mir` | `worker_structured_cfg_lowering` | `canonical_mir_cfg_verifier` | `compiler/phase11_structured_cfg_nested_source.gst` | `phase11_registry_differential:conditional_branch` |
| `block_jump` | `migrated` | `selected` | `generic_canonical_mir` | `worker_structured_cfg_lowering` | `canonical_mir_cfg_verifier` | `compiler/phase11_structured_cfg_independent_jumps_source.gst` | `phase11_registry_differential:block_jump` |
| `positive_i32_branch` | `migrated` | `selected` | `generic_canonical_mir` | `worker_structured_cfg_lowering` | `canonical_mir_cfg_verifier` | `compiler/phase11_scalar_positive_predicate_source.gst` | `phase11_registry_differential:positive_i32_branch` |
| `block_local_branch_join` | `migrated` | `selected` | `generic_canonical_mir` | `worker_structured_cfg_lowering` | `canonical_mir_cfg_verifier` | `compiler/phase11_structured_cfg_three_predecessor_join_source.gst` | `phase11_registry_differential:block_local_branch_join` |
| `block_param_update_branch` | `migrated` | `selected` | `generic_canonical_mir` | `worker_block_parameter_loop_lowering` | `canonical_mir_cfg_verifier` | `compiler/phase11_block_parameter_countdown_loop_source.gst` | `phase11_registry_differential:block_param_update_branch` |
| `block_param_merge_update_branch` | `migrated` | `selected` | `generic_canonical_mir` | `worker_block_parameter_loop_lowering` | `canonical_mir_cfg_verifier` | `compiler/phase11_block_parameter_non_final_join_source.gst` | `phase11_registry_differential:block_param_merge_update_branch` |
| `provenance_metadata` | `migrated` | `selected` | `generic_canonical_mir` | `worker_metadata_lowering` | `canonical_mir_metadata_verifier` | `compiler/phase11_local_state_straight_line_source.gst` | `phase11_registry_differential:provenance_metadata` |
| `resource_metadata` | `deferred` | `deferred` | `deferred` | `worker_metadata_lowering` | `canonical_mir_metadata_verifier` | `compiler/mir_feature_local_binding_read_preservation_source.gst` | `phase11_canonical_oracle:resource_metadata` |
| `native_boundary_metadata` | `deferred` | `deferred` | `deferred` | `worker_metadata_lowering` | `canonical_mir_metadata_verifier` | `compiler/mir_to_c_native_boundary_metadata_smoke_test_entry.gst` | `phase11_canonical_oracle:native_boundary_metadata` |
| `block_param_merge_imported_call_return` | `deferred` | `deferred` | `deferred` | `worker_module_import_lowering` | `resolver_signature_and_canonical_mir_verifier` | `compiler/mir_feature_block_param_merge_imported_call_return_preservation_source.gst` | `phase11_canonical_oracle:block_param_merge_imported_call_return` |
| `block_param_merge_arm_update_imported_call_return` | `deferred` | `deferred` | `deferred` | `worker_module_import_lowering` | `resolver_signature_and_canonical_mir_verifier` | `compiler/mir_feature_block_param_merge_arm_update_imported_call_return_preservation_source.gst` | `phase11_canonical_oracle:block_param_merge_arm_update_imported_call_return` |
| `block_param_merge_arm_update_imported_call_branch` | `deferred` | `deferred` | `deferred` | `worker_module_import_lowering` | `resolver_signature_and_canonical_mir_verifier` | `compiler/mir_feature_block_param_merge_arm_update_imported_call_branch_preservation_source.gst` | `phase11_canonical_oracle:block_param_merge_arm_update_imported_call_branch` |
| `block_param_merge_imported_branch_joined_return` | `deferred` | `deferred` | `deferred` | `worker_module_import_lowering` | `resolver_signature_and_canonical_mir_verifier` | `compiler/mir_feature_block_param_merge_imported_branch_joined_return_preservation_source.gst` | `phase11_canonical_oracle:block_param_merge_imported_branch_joined_return` |
| `block_param_merge_dual_imported_joined_return` | `deferred` | `deferred` | `deferred` | `worker_module_import_lowering` | `resolver_signature_and_canonical_mir_verifier` | `compiler/mir_feature_block_param_merge_dual_imported_joined_return_preservation_source.gst` | `phase11_canonical_oracle:block_param_merge_dual_imported_joined_return` |
| `direct_call_i32` | `migrated` | `selected` | `generic_canonical_mir` | `worker_direct_call_lowering` | `source_signature_and_call_graph_verifier` | `compiler/phase11_direct_call_nested_source.gst` | `phase11_registry_differential:direct_call_i32` |
| `imported_runtime_call_i32` | `migrated` | `selected` | `generic_canonical_mir` | `worker_module_import_lowering` | `resolver_signature_and_canonical_mir_verifier` | `compiler/phase11_declared_external_import_source.gst` | `phase11_registry_differential:imported_runtime_call_i32` |
| `p13_resource_metadata_source_route` | `migrated` | `selected` | `generic_canonical_mir` | `worker_metadata_lowering` | `canonical_mir_metadata_verifier` | `compiler/phase13_source_resource_metadata_source.gst` | `phase13_registry_differential:p13_resource_metadata_source_route` |
| `p13_native_boundary_metadata_source_route` | `migrated` | `selected` | `generic_canonical_mir` | `worker_metadata_lowering` | `canonical_mir_metadata_verifier` | `compiler/phase13_runtime_multiple_calls_source.gst` | `phase13_registry_differential:p13_native_boundary_metadata_source_route` |
| `p13_imported_call_return_source_route` | `replaced` | `unsupported_historical_replaced` | `deferred` | `worker_module_import_lowering` | `resolver_signature_and_canonical_mir_verifier` | `compiler/mir_feature_block_param_merge_imported_call_return_preservation_source.gst` | `phase13_opening:p13_imported_call_return_source_route` |
| `p13_imported_arm_update_return_source_route` | `replaced` | `unsupported_historical_replaced` | `deferred` | `worker_module_import_lowering` | `resolver_signature_and_canonical_mir_verifier` | `compiler/mir_feature_block_param_merge_arm_update_imported_call_return_preservation_source.gst` | `phase13_opening:p13_imported_arm_update_return_source_route` |
| `p13_imported_arm_update_branch_source_route` | `replaced` | `unsupported_historical_replaced` | `deferred` | `worker_module_import_lowering` | `resolver_signature_and_canonical_mir_verifier` | `compiler/mir_feature_block_param_merge_arm_update_imported_call_branch_preservation_source.gst` | `phase13_opening:p13_imported_arm_update_branch_source_route` |
| `p13_imported_branch_joined_return_source_route` | `replaced` | `unsupported_historical_replaced` | `deferred` | `worker_module_import_lowering` | `resolver_signature_and_canonical_mir_verifier` | `compiler/mir_feature_block_param_merge_imported_branch_joined_return_preservation_source.gst` | `phase13_opening:p13_imported_branch_joined_return_source_route` |
| `p13_dual_imported_joined_return_source_route` | `replaced` | `unsupported_historical_replaced` | `deferred` | `worker_module_import_lowering` | `resolver_signature_and_canonical_mir_verifier` | `compiler/mir_feature_block_param_merge_dual_imported_joined_return_preservation_source.gst` | `phase13_opening:p13_dual_imported_joined_return_source_route` |
| `p13_scalar_multiply_i32` | `migrated` | `selected` | `generic_canonical_mir` | `worker_scalar_expression_lowering` | `canonical_mir_scalar_verifier` | `compiler/phase11_scalar_unsupported_multiply_source.gst` | `phase13_registry_differential:p13_scalar_multiply_i32` |
| `p13_two_local_update_branch_source_route` | `migrated` | `selected` | `generic_canonical_mir` | `worker_local_state_lowering` | `canonical_mir_scalar_verifier` | `compiler/phase13_multiple_locals_assignments_source.gst` | `phase13_registry_differential:p13_two_local_update_branch_source_route` |
| `p13_nested_local_update_branch_source_route` | `migrated` | `selected` | `generic_canonical_mir` | `worker_structured_cfg_lowering` | `canonical_mir_cfg_verifier` | `compiler/phase13_nested_structured_cfg_source.gst` | `phase13_registry_differential:p13_nested_local_update_branch_source_route` |
| `p13_general_loop_backedge_source_route` | `migrated` | `selected` | `generic_canonical_mir` | `worker_block_parameter_loop_lowering` | `canonical_mir_cfg_verifier` | `compiler/phase11_structured_cfg_deferred_loop_source.gst` | `phase13_registry_differential:p13_general_loop_backedge_source_route` |
| `p13_parameterized_local_call_branch_source_route` | `migrated` | `selected` | `generic_canonical_mir` | `worker_direct_call_lowering` | `source_signature_and_call_graph_verifier` | `compiler/phase13_parameter_argument_branch_source.gst` | `phase13_registry_differential:p13_parameterized_local_call_branch_source_route` |
| `p13_multi_function_direct_call_graph_source_route` | `migrated` | `selected` | `generic_canonical_mir` | `worker_direct_call_lowering` | `source_signature_and_call_graph_verifier` | `compiler/phase13_direct_call_graph_source.gst` | `phase13_registry_differential:p13_multi_function_direct_call_graph_source_route` |
| `p13_recursive_direct_call_policy` | `replaced` | `unsupported_historical_replaced` | `deferred` | `worker_direct_call_lowering` | `source_signature_and_call_graph_verifier` | `compiler/phase11_direct_call_recursion_source.gst` | `phase13_opening:p13_recursive_direct_call_policy` |
| `p13_mutual_recursive_direct_call_policy` | `replaced` | `unsupported_historical_replaced` | `deferred` | `worker_direct_call_lowering` | `source_signature_and_call_graph_verifier` | `compiler/phase13_direct_call_mutual_recursion_source.gst` | `phase13_opening:p13_mutual_recursive_direct_call_policy` |
| `p13_indirect_direct_call_policy` | `replaced` | `unsupported_historical_replaced` | `deferred` | `worker_direct_call_lowering` | `source_signature_and_call_graph_verifier` | `none_policy_only_indirect_call` | `phase13_opening:p13_indirect_direct_call_policy` |
| `p13_function_value_call_policy` | `replaced` | `unsupported_historical_replaced` | `deferred` | `worker_direct_call_lowering` | `source_signature_and_call_graph_verifier` | `none_policy_only_function_value` | `phase13_opening:p13_function_value_call_policy` |
| `p13_multi_module_bundle_composition` | `replaced` | `unsupported_historical_replaced` | `deferred` | `worker_module_import_lowering` | `resolver_signature_and_canonical_mir_verifier` | `compiler/phase11_module_import_main_source.gst` | `phase13_opening:p13_multi_module_bundle_composition` |
| `p13_imported_predicate_update_branch_source_route` | `migrated` | `selected` | `generic_canonical_mir` | `worker_module_import_lowering` | `resolver_signature_and_canonical_mir_verifier` | `compiler/phase13_runtime_predicate_branch_source.gst` | `phase13_registry_differential:p13_imported_predicate_update_branch_source_route` |
| `p13_unapproved_host_symbol_policy` | `replaced` | `unsupported_historical_replaced` | `deferred` | `worker_module_import_lowering` | `approved_host_registry_verifier` | `compiler/phase11_module_import_forbidden_runtime_source.gst` | `phase13_opening:p13_unapproved_host_symbol_policy` |
| `p14_primitive_scalar_layout` | `migrated` | `selected` | `generic_canonical_mir` | `worker_primitive_layout_lowering` | `compiler_layout_verifier` | `compiler/phase14_primitive_scalar_layout_source.gst` | `phase14_registry_differential:p14_primitive_scalar_layout` |
| `p14_pointer_sized_integer_layout` | `migrated` | `selected` | `generic_canonical_mir` | `worker_primitive_layout_lowering` | `compiler_layout_verifier` | `compiler/phase14_pointer_sized_integer_layout_source.gst` | `phase14_registry_differential:p14_pointer_sized_integer_layout` |
| `p14_target_dependent_conversions` | `migrated` | `selected` | `generic_canonical_mir` | `worker_conversion_lowering` | `canonical_mir_conversion_verifier` | `compiler/phase14_integer_conversion_source.gst` | `phase14_registry_differential:p14_target_dependent_conversions` |
| `p14_pointer_nullability_model` | `migrated` | `selected` | `generic_canonical_mir` | `worker_pointer_memory_lowering` | `canonical_mir_memory_verifier` | `compiler/phase14_pointer_nullability_source.gst` | `phase14_registry_differential:p14_pointer_nullability_model` |
| `p14_stack_slot_addressable_locals` | `migrated` | `selected` | `generic_canonical_mir` | `worker_pointer_memory_lowering` | `canonical_mir_memory_verifier` | `compiler/phase14_stack_slot_addressable_source.gst` | `phase14_registry_differential:p14_stack_slot_addressable_locals` |
| `p14_typed_load_store_memory_access` | `migrated` | `selected` | `generic_canonical_mir` | `worker_pointer_memory_lowering` | `canonical_mir_memory_verifier` | `compiler/phase14_typed_memory_access_source.gst` | `phase14_registry_differential:p14_typed_load_store_memory_access` |
| `p14_string_and_string_view_layout` | `migrated` | `selected` | `generic_canonical_mir` | `worker_string_view_lowering` | `canonical_mir_string_view_verifier` | `compiler/phase14_string_view_source.gst` | `phase14_registry_differential:p14_string_and_string_view_layout` |
| `p14_array_and_slice_layout` | `migrated` | `selected` | `generic_canonical_mir` | `worker_array_slice_lowering` | `canonical_mir_array_slice_verifier` | `compiler/phase14_array_slice_source.gst` | `phase14_registry_differential:p14_array_and_slice_layout` |
| `p14_struct_field_layout` | `migrated` | `selected` | `generic_canonical_mir` | `worker_aggregate_layout_lowering` | `canonical_mir_aggregate_layout_verifier` | `compiler/phase14_struct_source.gst` | `phase14_registry_differential:p14_struct_field_layout` |
| `p14_enum_tagged_union_layout` | `migrated` | `selected` | `generic_canonical_mir` | `worker_aggregate_layout_lowering` | `canonical_mir_aggregate_layout_verifier` | `compiler/phase14_enum_source.gst` | `phase14_registry_differential:p14_enum_tagged_union_layout` |
| `p14_aggregate_basic_block_transport` | `migrated` | `selected` | `generic_canonical_mir` | `worker_aggregate_layout_lowering` | `canonical_mir_aggregate_layout_verifier` | `compiler/phase14_aggregate_transport_source.gst` | `phase14_registry_differential:p14_aggregate_basic_block_transport` |
| `p14_target_layout_model` | `migrated` | `selected` | `generic_canonical_mir` | `worker_target_layout_lowering` | `target_layout_registry_verifier` | `compiler/phase14_target_layout_model_source.gst` | `phase14_registry_differential:p14_target_layout_model` |
| `p14_all_target_layout_evidence` | `migrated` | `selected` | `generic_canonical_mir` | `worker_target_layout_lowering` | `target_layout_registry_verifier` | `compiler/phase14_all_target_layout_evidence_source.gst` | `phase14_registry_differential:p14_all_target_layout_evidence` |
| `p15_resource_value_representation` | `candidate_deferred` | `deferred` | `deferred` | `worker_resource_value_lowering` | `canonical_mir_resource_verifier` | `compiler/p15_resource_value_representation_deferred_source.gst` | `phase15_opening:p15_resource_value_representation` |
| `p15_move_state_transitions` | `candidate_deferred` | `deferred` | `deferred` | `worker_resource_state_lowering` | `canonical_mir_resource_verifier` | `compiler/p15_move_state_transitions_deferred_source.gst` | `phase15_opening:p15_move_state_transitions` |
| `p15_use_after_move_enforcement` | `candidate_deferred` | `deferred` | `deferred` | `worker_resource_state_lowering` | `canonical_mir_resource_verifier` | `compiler/p15_use_after_move_enforcement_deferred_source.gst` | `phase15_opening:p15_use_after_move_enforcement` |
| `p15_reassignment_cleanup` | `candidate_deferred` | `deferred` | `deferred` | `worker_resource_cleanup_lowering` | `compiler_resource_cleanup_verifier` | `compiler/p15_reassignment_cleanup_deferred_source.gst` | `phase15_opening:p15_reassignment_cleanup` |
| `p15_scope_exit_cleanup` | `candidate_deferred` | `deferred` | `deferred` | `worker_resource_cleanup_lowering` | `compiler_resource_cleanup_verifier` | `compiler/p15_scope_exit_cleanup_deferred_source.gst` | `phase15_opening:p15_scope_exit_cleanup` |
| `p15_early_return_cleanup` | `candidate_deferred` | `deferred` | `deferred` | `worker_resource_cleanup_lowering` | `compiler_resource_cleanup_verifier` | `compiler/p15_early_return_cleanup_deferred_source.gst` | `phase15_opening:p15_early_return_cleanup` |
| `p15_destructor_scheduling` | `candidate_deferred` | `deferred` | `deferred` | `worker_resource_cleanup_lowering` | `compiler_resource_cleanup_verifier` | `compiler/p15_destructor_scheduling_deferred_source.gst` | `phase15_opening:p15_destructor_scheduling` |
| `p15_manual_close_interaction` | `candidate_deferred` | `deferred` | `deferred` | `worker_resource_cleanup_lowering` | `compiler_resource_cleanup_verifier` | `compiler/p15_manual_close_interaction_deferred_source.gst` | `phase15_opening:p15_manual_close_interaction` |
| `p15_conditional_loop_resource_state` | `candidate_deferred` | `deferred` | `deferred` | `worker_resource_state_lowering` | `canonical_mir_resource_verifier` | `compiler/p15_conditional_loop_resource_state_deferred_source.gst` | `phase15_opening:p15_conditional_loop_resource_state` |
| `p15_resource_metadata_validation` | `candidate_deferred` | `deferred` | `deferred` | `worker_resource_metadata_lowering` | `canonical_mir_resource_verifier` | `compiler/p15_resource_metadata_validation_deferred_source.gst` | `phase15_opening:p15_resource_metadata_validation` |
| `p15_directory_resources` | `candidate_deferred` | `deferred` | `deferred` | `worker_specialized_resource_lowering` | `resource_runtime_contract_verifier` | `compiler/p15_directory_resources_deferred_source.gst` | `phase15_opening:p15_directory_resources` |
| `p15_selected_failure_cleanup` | `candidate_deferred` | `deferred` | `deferred` | `worker_resource_cleanup_lowering` | `compiler_resource_cleanup_verifier` | `compiler/p15_selected_failure_cleanup_deferred_source.gst` | `phase15_opening:p15_selected_failure_cleanup` |
| `p15_complete_resource_differential` | `candidate_deferred` | `deferred` | `deferred` | `worker_resource_state_lowering` | `canonical_mir_resource_verifier` | `compiler/p15_complete_resource_differential_deferred_source.gst` | `phase15_opening:p15_complete_resource_differential` |
| `p16_function_abi_authority` | `candidate_deferred` | `deferred` | `deferred` | `compiler_function_abi_planner` | `compiler_abi_verifier` | `compiler/p16_function_abi_authority_deferred_source.gst` | `phase16_opening:p16_function_abi_authority` |
| `p16_canonical_call_result_mir` | `candidate_deferred` | `deferred` | `deferred` | `compiler_call_mir_planner` | `canonical_mir_call_verifier` | `compiler/p16_canonical_call_result_mir_deferred_source.gst` | `phase16_opening:p16_canonical_call_result_mir` |
| `p16_aggregate_parameter_abi` | `candidate_deferred` | `deferred` | `deferred` | `compiler_aggregate_parameter_classifier` | `compiler_aggregate_abi_verifier` | `compiler/p16_aggregate_parameter_abi_deferred_source.gst` | `phase16_opening:p16_aggregate_parameter_abi` |
| `p16_aggregate_return_hidden_result_abi` | `candidate_deferred` | `deferred` | `deferred` | `compiler_aggregate_result_classifier` | `compiler_aggregate_abi_verifier` | `compiler/p16_aggregate_return_hidden_result_abi_deferred_source.gst` | `phase16_opening:p16_aggregate_return_hidden_result_abi` |
| `p16_direct_call_agreement` | `candidate_deferred` | `deferred` | `deferred` | `compiler_call_compatibility_verifier` | `compiler_call_compatibility_diagnostic` | `compiler/p16_direct_call_agreement_deferred_source.gst` | `phase16_opening:p16_direct_call_agreement` |
| `p16_typed_indirect_calls` | `candidate_deferred` | `deferred` | `deferred` | `compiler_typed_indirect_call_planner` | `compiler_typed_call_verifier` | `compiler/p16_typed_indirect_calls_deferred_source.gst` | `phase16_opening:p16_typed_indirect_calls` |
| `p16_fat_pointer_trait_object_call_abi` | `candidate_deferred` | `deferred` | `deferred` | `compiler_fat_pointer_call_planner` | `compiler_fat_pointer_abi_verifier` | `compiler/p16_fat_pointer_trait_object_call_abi_deferred_source.gst` | `phase16_opening:p16_fat_pointer_trait_object_call_abi` |
| `p16_unsized_value_abi` | `candidate_deferred` | `deferred` | `deferred` | `compiler_unsized_abi_planner` | `compiler_unsized_abi_verifier` | `compiler/p16_unsized_value_abi_deferred_source.gst` | `phase16_opening:p16_unsized_value_abi` |
| `p16_dynamic_stack_storage` | `candidate_deferred` | `deferred` | `deferred` | `compiler_dynamic_frame_planner` | `compiler_dynamic_frame_verifier` | `compiler/p16_dynamic_stack_storage_deferred_source.gst` | `phase16_opening:p16_dynamic_stack_storage` |
| `p16_resource_aggregate_call_abi` | `candidate_deferred` | `deferred` | `deferred` | `compiler_resource_call_transfer_planner` | `compiler_resource_abi_verifier` | `compiler/p16_resource_aggregate_call_abi_deferred_source.gst` | `phase16_opening:p16_resource_aggregate_call_abi` |
| `p16_cross_module_aggregate_resource_abi` | `candidate_deferred` | `deferred` | `deferred` | `compiler_cross_module_abi_planner` | `compiler_cross_module_abi_verifier` | `compiler/p16_cross_module_aggregate_resource_abi_deferred_source.gst` | `phase16_opening:p16_cross_module_aggregate_resource_abi` |
| `p16_abi_metadata_validation` | `candidate_deferred` | `deferred` | `deferred` | `compiler_abi_request_validator` | `worker_abi_request_verifier` | `compiler/p16_abi_metadata_validation_deferred_source.gst` | `phase16_opening:p16_abi_metadata_validation` |
| `p16_complete_abi_differential` | `candidate_deferred` | `deferred` | `deferred` | `compiler_abi_evidence_planner` | `compiler_abi_verifier` | `compiler/p16_complete_abi_differential_deferred_source.gst` | `phase16_opening:p16_complete_abi_differential` |
| `p17_runtime_abi_authority` | `candidate_deferred` | `deferred` | `deferred` | `compiler_runtime_abi_planner` | `compiler_runtime_abi_verifier` | `compiler/p17_runtime_abi_authority_deferred_source.gst` | `phase17_opening:p17_runtime_abi_authority` |
| `p17_helper_classification_authority` | `candidate_deferred` | `deferred` | `deferred` | `compiler_runtime_helper_classifier` | `compiler_runtime_helper_classification_verifier` | `compiler/p17_helper_classification_authority_deferred_source.gst` | `phase17_opening:p17_helper_classification_authority` |
| `p17_runtime_symbol_versioning` | `candidate_deferred` | `deferred` | `deferred` | `compiler_runtime_symbol_planner` | `compiler_runtime_symbol_verifier` | `compiler/p17_runtime_symbol_versioning_deferred_source.gst` | `phase17_opening:p17_runtime_symbol_versioning` |
| `p17_runtime_requirement_transport` | `candidate_deferred` | `deferred` | `deferred` | `compiler_runtime_requirement_planner` | `worker_runtime_requirement_verifier` | `compiler/p17_runtime_requirement_transport_deferred_source.gst` | `phase17_opening:p17_runtime_requirement_transport` |
| `p17_target_runtime_packages` | `candidate_deferred` | `deferred` | `deferred` | `compiler_runtime_package_planner` | `compiler_runtime_package_verifier` | `compiler/p17_target_runtime_packages_deferred_source.gst` | `phase17_opening:p17_target_runtime_packages` |
| `p17_stable_runtime_imports` | `candidate_deferred` | `deferred` | `deferred` | `compiler_runtime_import_planner` | `compiler_runtime_import_verifier` | `compiler/p17_stable_runtime_imports_deferred_source.gst` | `phase17_opening:p17_stable_runtime_imports` |
| `p17_rust_runtime_components` | `candidate_deferred` | `deferred` | `deferred` | `compiler_rust_runtime_component_planner` | `compiler_rust_runtime_component_verifier` | `compiler/p17_rust_runtime_components_deferred_source.gst` | `phase17_opening:p17_rust_runtime_components` |
| `p17_retained_c_runtime_components` | `candidate_deferred` | `deferred` | `deferred` | `compiler_retained_c_runtime_component_planner` | `compiler_retained_c_runtime_component_verifier` | `compiler/p17_retained_c_runtime_components_deferred_source.gst` | `phase17_opening:p17_retained_c_runtime_components` |
| `p17_gust_runtime_components` | `candidate_deferred` | `deferred` | `deferred` | `compiler_gust_runtime_component_planner` | `compiler_gust_runtime_component_verifier` | `compiler/p17_gust_runtime_components_deferred_source.gst` | `phase17_opening:p17_gust_runtime_components` |
| `p17_obsolete_helper_removal` | `candidate_deferred` | `deferred` | `deferred` | `compiler_obsolete_runtime_helper_planner` | `compiler_obsolete_runtime_helper_verifier` | `compiler/p17_obsolete_helper_removal_deferred_source.gst` | `phase17_opening:p17_obsolete_helper_removal` |
| `p17_generated_c_shim_elimination` | `candidate_deferred` | `deferred` | `deferred` | `compiler_generated_c_shim_elimination_planner` | `compiler_generated_c_shim_verifier` | `compiler/p17_generated_c_shim_elimination_deferred_source.gst` | `phase17_opening:p17_generated_c_shim_elimination` |
| `p17_allocation_string_runtime` | `candidate_deferred` | `deferred` | `deferred` | `compiler_allocation_string_runtime_planner` | `compiler_allocation_string_runtime_verifier` | `compiler/p17_allocation_string_runtime_deferred_source.gst` | `phase17_opening:p17_allocation_string_runtime` |
| `p17_io_filesystem_runtime` | `candidate_deferred` | `deferred` | `deferred` | `compiler_io_filesystem_runtime_planner` | `compiler_io_filesystem_runtime_verifier` | `compiler/p17_io_filesystem_runtime_deferred_source.gst` | `phase17_opening:p17_io_filesystem_runtime` |
| `p17_resource_runtime` | `candidate_deferred` | `deferred` | `deferred` | `compiler_resource_runtime_planner` | `compiler_resource_runtime_verifier` | `compiler/p17_resource_runtime_deferred_source.gst` | `phase17_opening:p17_resource_runtime` |
| `p17_threading_runtime` | `candidate_deferred` | `deferred` | `deferred` | `compiler_threading_runtime_planner` | `compiler_threading_runtime_verifier` | `compiler/p17_threading_runtime_deferred_source.gst` | `phase17_opening:p17_threading_runtime` |
| `p17_runtime_availability_compatibility` | `candidate_deferred` | `deferred` | `deferred` | `compiler_runtime_compatibility_planner` | `compiler_runtime_compatibility_verifier` | `compiler/p17_runtime_availability_compatibility_deferred_source.gst` | `phase17_opening:p17_runtime_availability_compatibility` |
| `p17_complete_runtime_differential` | `candidate_deferred` | `deferred` | `deferred` | `compiler_runtime_evidence_planner` | `compiler_runtime_evidence_verifier` | `compiler/p17_complete_runtime_differential_deferred_source.gst` | `phase17_opening:p17_complete_runtime_differential` |

## Composition links

| Entry | Composition case |
| --- | --- |
| `return_int` | `phase13_composition:scalars_locals_cfg` |
| `local_binding_read` | `phase13_composition:locals_direct_call` |
| `add_i32` | `phase13_composition:scalars_locals_cfg` |
| `conditional_branch` | `phase13_composition:nested_cfg_locals` |
| `block_jump` | `phase13_composition:nested_cfg_locals` |
| `positive_i32_branch` | `phase13_composition:scalars_locals_cfg` |
| `block_local_branch_join` | `phase13_composition:nested_cfg_locals` |
| `block_param_update_branch` | `phase13_composition:loop_parameters_direct_call` |
| `block_param_merge_update_branch` | `phase13_composition:loop_parameters_direct_call` |
| `provenance_metadata` | `phase13_composition:resource_metadata_scalar` |
| `direct_call_i32` | `phase13_composition:locals_direct_call` |
| `direct_call_i32` | `phase13_composition:direct_call_graph_parameters` |
| `imported_runtime_call_i32` | `phase13_composition:source_import_runtime` |
| `imported_runtime_call_i32` | `phase13_composition:native_metadata_runtime` |
| `p13_resource_metadata_source_route` | `phase13_composition:resource_metadata_scalar` |
| `p13_native_boundary_metadata_source_route` | `phase13_composition:native_metadata_runtime` |
| `p13_scalar_multiply_i32` | `phase13_composition:scalars_locals_cfg` |
| `p13_two_local_update_branch_source_route` | `phase13_composition:scalars_locals_cfg` |
| `p13_two_local_update_branch_source_route` | `phase13_composition:locals_direct_call` |
| `p13_two_local_update_branch_source_route` | `phase13_composition:nested_cfg_locals` |
| `p13_nested_local_update_branch_source_route` | `phase13_composition:scalars_locals_cfg` |
| `p13_nested_local_update_branch_source_route` | `phase13_composition:nested_cfg_locals` |
| `p13_general_loop_backedge_source_route` | `phase13_composition:loop_parameters_direct_call` |
| `p13_parameterized_local_call_branch_source_route` | `phase13_composition:locals_direct_call` |
| `p13_parameterized_local_call_branch_source_route` | `phase13_composition:loop_parameters_direct_call` |
| `p13_parameterized_local_call_branch_source_route` | `phase13_composition:direct_call_graph_parameters` |
| `p13_multi_function_direct_call_graph_source_route` | `phase13_composition:direct_call_graph_parameters` |
| `p13_imported_predicate_update_branch_source_route` | `phase13_composition:source_import_runtime` |
| `p13_imported_predicate_update_branch_source_route` | `phase13_composition:native_metadata_runtime` |
| `p14_primitive_scalar_layout` | `phase14_composition:declared_targets_primitive_layout` |
| `p14_primitive_scalar_layout` | `phase14_composition:integer_conversions_with_layout_and_control_flow` |
| `p14_primitive_scalar_layout` | `phase14_composition:bounded_pointers_with_layout_conversion_and_control_flow` |
| `p14_primitive_scalar_layout` | `phase14_composition:stack_slots_with_branches_loops_and_aggregate_copy` |
| `p14_primitive_scalar_layout` | `phase14_composition:typed_memory_with_stack_pointer_offset_and_copy` |
| `p14_primitive_scalar_layout` | `phase14_composition:arrays_slices_with_layout_pointer_memory_and_branch_join` |
| `p14_primitive_scalar_layout` | `phase14_composition:enums_with_layout_array_payload_locals_and_branch_join` |
| `p14_primitive_scalar_layout` | `phase14_composition:structs_with_layout_padding_nesting_and_branch_join` |
| `p14_primitive_scalar_layout` | `phase14_composition:aggregates_across_joins_loops_and_early_return` |
| `p14_pointer_sized_integer_layout` | `phase14_composition:declared_targets_primitive_layout` |
| `p14_pointer_sized_integer_layout` | `phase14_composition:integer_conversions_with_layout_and_control_flow` |
| `p14_pointer_sized_integer_layout` | `phase14_composition:bounded_pointers_with_layout_conversion_and_control_flow` |
| `p14_pointer_sized_integer_layout` | `phase14_composition:string_views_with_static_literals_pointer_layout_and_slices` |
| `p14_target_dependent_conversions` | `phase14_composition:integer_conversions_with_layout_and_control_flow` |
| `p14_target_dependent_conversions` | `phase14_composition:bounded_pointers_with_layout_conversion_and_control_flow` |
| `p14_pointer_nullability_model` | `phase14_composition:bounded_pointers_with_layout_conversion_and_control_flow` |
| `p14_pointer_nullability_model` | `phase14_composition:stack_slots_with_branches_loops_and_aggregate_copy` |
| `p14_pointer_nullability_model` | `phase14_composition:typed_memory_with_stack_pointer_offset_and_copy` |
| `p14_stack_slot_addressable_locals` | `phase14_composition:stack_slots_with_branches_loops_and_aggregate_copy` |
| `p14_stack_slot_addressable_locals` | `phase14_composition:typed_memory_with_stack_pointer_offset_and_copy` |
| `p14_typed_load_store_memory_access` | `phase14_composition:typed_memory_with_stack_pointer_offset_and_copy` |
| `p14_string_and_string_view_layout` | `phase14_composition:string_views_with_static_literals_pointer_layout_and_slices` |
| `p14_string_and_string_view_layout` | `phase14_composition:aggregates_across_joins_loops_and_early_return` |
| `p14_array_and_slice_layout` | `phase14_composition:arrays_slices_with_layout_pointer_memory_and_branch_join` |
| `p14_array_and_slice_layout` | `phase14_composition:enums_with_layout_array_payload_locals_and_branch_join` |
| `p14_array_and_slice_layout` | `phase14_composition:aggregates_across_joins_loops_and_early_return` |
| `p14_struct_field_layout` | `phase14_composition:structs_with_layout_padding_nesting_and_branch_join` |
| `p14_struct_field_layout` | `phase14_composition:aggregates_across_joins_loops_and_early_return` |
| `p14_enum_tagged_union_layout` | `phase14_composition:enums_with_layout_array_payload_locals_and_branch_join` |
| `p14_enum_tagged_union_layout` | `phase14_composition:aggregates_across_joins_loops_and_early_return` |
| `p14_aggregate_basic_block_transport` | `phase14_composition:aggregates_across_joins_loops_and_early_return` |
| `p14_target_layout_model` | `phase14_composition:declared_targets_primitive_layout` |
| `p14_target_layout_model` | `phase14_composition:integer_conversions_with_layout_and_control_flow` |
| `p14_target_layout_model` | `phase14_composition:bounded_pointers_with_layout_conversion_and_control_flow` |
| `p14_target_layout_model` | `phase14_composition:stack_slots_with_branches_loops_and_aggregate_copy` |
| `p14_target_layout_model` | `phase14_composition:typed_memory_with_stack_pointer_offset_and_copy` |
| `p14_target_layout_model` | `phase14_composition:string_views_with_static_literals_pointer_layout_and_slices` |
| `p14_target_layout_model` | `phase14_composition:arrays_slices_with_layout_pointer_memory_and_branch_join` |
| `p14_target_layout_model` | `phase14_composition:enums_with_layout_array_payload_locals_and_branch_join` |
| `p14_target_layout_model` | `phase14_composition:structs_with_layout_padding_nesting_and_branch_join` |
| `p14_target_layout_model` | `phase14_composition:aggregates_across_joins_loops_and_early_return` |
| `p14_all_target_layout_evidence` | `phase14_composition:declared_targets_primitive_layout` |

## Deferred-source links

| Entry | Deferred evidence |
| --- | --- |
| `return_int` | `compiler/phase11_scalar_unsupported_multiply_source.gst` |
| `local_binding_read` | `compiler/phase11_local_state_uninitialized_read_source.gst` |
| `add_i32` | `compiler/phase11_scalar_unsupported_multiply_source.gst` |
| `conditional_branch` | `compiler/phase11_structured_cfg_deferred_loop_source.gst` |
| `block_jump` | `compiler/phase11_structured_cfg_deferred_loop_source.gst` |
| `positive_i32_branch` | `compiler/mir_feature_block_local_branch_join_preservation_source.gst` |
| `block_local_branch_join` | `compiler/phase11_structured_cfg_deferred_loop_source.gst` |
| `block_param_update_branch` | `none_malformed_backedge_matrix_in_guard` |
| `block_param_merge_update_branch` | `none_malformed_edge_matrix_in_guard` |
| `provenance_metadata` | `compiler/phase11_local_state_uninitialized_read_source.gst` |
| `resource_metadata` | `compiler/mir_feature_local_binding_read_preservation_source.gst` |
| `native_boundary_metadata` | `compiler/mir_to_c_native_boundary_metadata_smoke_test_entry.gst` |
| `block_param_merge_imported_call_return` | `compiler/mir_feature_block_param_merge_imported_call_return_preservation_source.gst` |
| `block_param_merge_arm_update_imported_call_return` | `compiler/mir_feature_block_param_merge_arm_update_imported_call_return_preservation_source.gst` |
| `block_param_merge_arm_update_imported_call_branch` | `compiler/mir_feature_block_param_merge_arm_update_imported_call_branch_preservation_source.gst` |
| `block_param_merge_imported_branch_joined_return` | `compiler/mir_feature_block_param_merge_imported_branch_joined_return_preservation_source.gst` |
| `block_param_merge_dual_imported_joined_return` | `compiler/mir_feature_block_param_merge_dual_imported_joined_return_preservation_source.gst` |
| `direct_call_i32` | `compiler/phase11_direct_call_recursion_source.gst` |
| `imported_runtime_call_i32` | `compiler/phase11_module_import_forbidden_runtime_source.gst` |
| `p13_scalar_multiply_i32` | `compiler/phase13_scalar_unsupported_divide_source.gst` |
| `p13_two_local_update_branch_source_route` | `compiler/phase11_local_state_uninitialized_read_source.gst` |
| `p13_nested_local_update_branch_source_route` | `compiler/phase13_structured_cfg_short_circuit_deferred_source.gst` |
| `p13_general_loop_backedge_source_route` | `compiler/phase13_loop_early_return_deferred_source.gst` |
| `p13_parameterized_local_call_branch_source_route` | `compiler/phase13_parameter_argument_aggregate_parameter_source.gst` |
| `p13_multi_function_direct_call_graph_source_route` | `compiler/phase11_direct_call_recursion_source.gst` |
| `p13_imported_predicate_update_branch_source_route` | `compiler/phase11_module_import_forbidden_runtime_source.gst` |
| `p14_primitive_scalar_layout` | `compiler/p14_primitive_scalar_layout_deferred_source.gst` |
| `p14_pointer_sized_integer_layout` | `compiler/p14_pointer_sized_integer_layout_deferred_source.gst` |
| `p14_target_dependent_conversions` | `compiler/p14_target_dependent_conversions_deferred_source.gst` |
| `p14_pointer_nullability_model` | `compiler/p14_pointer_nullability_model_deferred_source.gst` |
| `p14_stack_slot_addressable_locals` | `compiler/p14_stack_slot_uninitialized_read_source.gst` |
| `p14_typed_load_store_memory_access` | `compiler/p14_memory_access_wrong_width_source.gst` |
| `p14_string_and_string_view_layout` | `compiler/p14_string_view_invalid_pointer_length_source.gst` |
| `p14_array_and_slice_layout` | `compiler/p14_array_slice_out_of_bounds_source.gst` |
| `p14_struct_field_layout` | `compiler/p14_struct_field_overlap_source.gst` |
| `p14_enum_tagged_union_layout` | `compiler/p14_enum_invalid_tag_value_source.gst` |
| `p14_aggregate_basic_block_transport` | `compiler/p14_aggregate_join_layout_mismatch_source.gst` |
| `p14_target_layout_model` | `compiler/p14_target_layout_model_deferred_source.gst` |
| `p14_all_target_layout_evidence` | `compiler/p14_all_target_layout_evidence_deferred_source.gst` |
| `p15_resource_value_representation` | `compiler/p15_resource_value_representation_deferred_source.gst` |
| `p15_move_state_transitions` | `compiler/p15_move_state_transitions_deferred_source.gst` |
| `p15_use_after_move_enforcement` | `compiler/p15_use_after_move_enforcement_deferred_source.gst` |
| `p15_reassignment_cleanup` | `compiler/p15_reassignment_cleanup_deferred_source.gst` |
| `p15_scope_exit_cleanup` | `compiler/p15_scope_exit_cleanup_deferred_source.gst` |
| `p15_early_return_cleanup` | `compiler/p15_early_return_cleanup_deferred_source.gst` |
| `p15_destructor_scheduling` | `compiler/p15_destructor_scheduling_deferred_source.gst` |
| `p15_manual_close_interaction` | `compiler/p15_manual_close_interaction_deferred_source.gst` |
| `p15_conditional_loop_resource_state` | `compiler/p15_conditional_loop_resource_state_deferred_source.gst` |
| `p15_resource_metadata_validation` | `compiler/p15_resource_metadata_validation_deferred_source.gst` |
| `p15_directory_resources` | `compiler/p15_directory_resources_deferred_source.gst` |
| `p15_selected_failure_cleanup` | `compiler/p15_selected_failure_cleanup_deferred_source.gst` |
| `p15_complete_resource_differential` | `compiler/p15_complete_resource_differential_deferred_source.gst` |
| `p16_function_abi_authority` | `compiler/p16_function_abi_authority_deferred_source.gst` |
| `p16_canonical_call_result_mir` | `compiler/p16_canonical_call_result_mir_deferred_source.gst` |
| `p16_aggregate_parameter_abi` | `compiler/p16_aggregate_parameter_abi_deferred_source.gst` |
| `p16_aggregate_return_hidden_result_abi` | `compiler/p16_aggregate_return_hidden_result_abi_deferred_source.gst` |
| `p16_direct_call_agreement` | `compiler/p16_direct_call_agreement_deferred_source.gst` |
| `p16_typed_indirect_calls` | `compiler/p16_typed_indirect_calls_deferred_source.gst` |
| `p16_fat_pointer_trait_object_call_abi` | `compiler/p16_fat_pointer_trait_object_call_abi_deferred_source.gst` |
| `p16_unsized_value_abi` | `compiler/p16_unsized_value_abi_deferred_source.gst` |
| `p16_dynamic_stack_storage` | `compiler/p16_dynamic_stack_storage_deferred_source.gst` |
| `p16_resource_aggregate_call_abi` | `compiler/p16_resource_aggregate_call_abi_deferred_source.gst` |
| `p16_cross_module_aggregate_resource_abi` | `compiler/p16_cross_module_aggregate_resource_abi_deferred_source.gst` |
| `p16_abi_metadata_validation` | `compiler/p16_abi_metadata_validation_deferred_source.gst` |
| `p16_complete_abi_differential` | `compiler/p16_complete_abi_differential_deferred_source.gst` |
| `p17_runtime_abi_authority` | `compiler/p17_runtime_abi_authority_deferred_source.gst` |
| `p17_helper_classification_authority` | `compiler/p17_helper_classification_authority_deferred_source.gst` |
| `p17_runtime_symbol_versioning` | `compiler/p17_runtime_symbol_versioning_deferred_source.gst` |
| `p17_runtime_requirement_transport` | `compiler/p17_runtime_requirement_transport_deferred_source.gst` |
| `p17_target_runtime_packages` | `compiler/p17_target_runtime_packages_deferred_source.gst` |
| `p17_stable_runtime_imports` | `compiler/p17_stable_runtime_imports_deferred_source.gst` |
| `p17_rust_runtime_components` | `compiler/p17_rust_runtime_components_deferred_source.gst` |
| `p17_retained_c_runtime_components` | `compiler/p17_retained_c_runtime_components_deferred_source.gst` |
| `p17_gust_runtime_components` | `compiler/p17_gust_runtime_components_deferred_source.gst` |
| `p17_obsolete_helper_removal` | `compiler/p17_obsolete_helper_removal_deferred_source.gst` |
| `p17_generated_c_shim_elimination` | `compiler/p17_generated_c_shim_elimination_deferred_source.gst` |
| `p17_allocation_string_runtime` | `compiler/p17_allocation_string_runtime_deferred_source.gst` |
| `p17_io_filesystem_runtime` | `compiler/p17_io_filesystem_runtime_deferred_source.gst` |
| `p17_resource_runtime` | `compiler/p17_resource_runtime_deferred_source.gst` |
| `p17_threading_runtime` | `compiler/p17_threading_runtime_deferred_source.gst` |
| `p17_runtime_availability_compatibility` | `compiler/p17_runtime_availability_compatibility_deferred_source.gst` |
| `p17_complete_runtime_differential` | `compiler/p17_complete_runtime_differential_deferred_source.gst` |

## Observable vocabulary

| Observable | Comparison | Owner |
| --- | --- | --- |
| `compile_result` | exact_success_or_failure | `compiler_frontend` |
| `process_exit_status` | exact_integer | `native_driver` |
| `stdout` | exact_bytes_unless_case_declares_environment_normalization | `differential_harness` |
| `stderr` | exact_bytes_unless_case_declares_environment_normalization | `differential_harness` |
| `diagnostic_code_and_span` | exact_semantic_code_and_source_span | `compiler_diagnostic_verifier` |
| `resource_terminal_state` | exact_owned_moved_closed_or_destructor_scheduled_state | `compiler_linear_resource_verifier` |
| `sandboxed_filesystem_effects` | exact_relative_tree_kind_and_bytes | `differential_harness` |

## Historical Full Level 3 inventory

- `guard-cranelift-add-i32-native-smoke`
- `guard-cranelift-branch-native-smoke`
- `guard-cranelift-call-helper-i32-native-smoke`
- `guard-cranelift-compiler-mir-add-i32-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-jump-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-local-branch-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-local-branch-join-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-local-update-branch-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-dual-materialize-return-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-imported-call-branch-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-imported-call-return-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-imported-materialize-branch-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-imported-materialize-return-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-imported-predicate-update-branch-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-local-call-branch-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-local-first-dual-materialize-return-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-local-materialize-branch-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-local-materialize-return-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-merge-arm-update-imported-call-branch-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-merge-arm-update-imported-call-return-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-merge-dual-imported-joined-return-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-merge-imported-branch-joined-return-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-merge-imported-call-return-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-merge-update-branch-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-quad-materialize-return-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-quint-materialize-return-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-triple-materialize-return-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-param-update-branch-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-block-two-local-update-branch-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-conditional-branch-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-ingestion-invalid-fixtures-native-rejection`
- `guard-cranelift-compiler-mir-ingestion-strict-rejection-contract`
- `guard-cranelift-compiler-mir-local-binding-read-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-native-boundary-metadata-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-positive-i32-branch-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-provenance-metadata-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-resource-metadata-ingestion-native-smoke`
- `guard-cranelift-compiler-mir-return-int-ingestion-native-smoke`
- `guard-cranelift-conditional-branch-native-smoke`
- `guard-cranelift-core-mir-basic-suite-shard`
- `guard-cranelift-dependency-beachhead`
- `guard-cranelift-differential-native-smoke`
- `guard-cranelift-experimental-backend-suite`
- `guard-cranelift-experimental-backend-suite-parallel`
- `guard-cranelift-experimental-backend-suite-shard`
- `guard-cranelift-extern-add-i32-native-smoke`
- `guard-cranelift-extern-call-i32-native-smoke`
- `guard-cranelift-extern-predicate-branch-i32-native-smoke`
- `guard-cranelift-historical-full`
- `guard-cranelift-identity-i32-native-smoke`
- `guard-cranelift-increment-local-i32-native-smoke`
- `guard-cranelift-local-binding-native-smoke`
- `guard-cranelift-local-binding-read-native-smoke`
- `guard-cranelift-mir-add-i32-native-smoke`
- `guard-cranelift-mir-arithmetic-i32-bundle-native-smoke`
- `guard-cranelift-mir-block-graph-i32-bundle-native-smoke`
- `guard-cranelift-mir-block-graph-local-i32-bundle-native-smoke`
- `guard-cranelift-mir-block-graph-local-update-i32-bundle-native-smoke`
- `guard-cranelift-mir-block-graph-param-call-i32-bundle-native-smoke`
- `guard-cranelift-mir-block-graph-param-extern-add-i32-bundle-native-smoke`
- `guard-cranelift-mir-block-graph-param-extern-i32-bundle-native-smoke`
- `guard-cranelift-mir-block-graph-param-extern-predicate-i32-bundle-native-smoke`
- `guard-cranelift-mir-block-graph-param-i32-bundle-native-smoke`
- `guard-cranelift-mir-block-graph-param-merge-call-i32-bundle-native-smoke`
- `guard-cranelift-mir-block-graph-param-merge-i32-bundle-native-smoke`
- `guard-cranelift-mir-call-helper-i32-native-smoke`
- `guard-cranelift-mir-comparison-branch-i32-bundle-native-smoke`
- `guard-cranelift-mir-comparison-i32-bundle-native-smoke`
- `guard-cranelift-mir-conditional-branch-native-smoke`
- `guard-cranelift-mir-extern-add-i32-native-smoke`
- `guard-cranelift-mir-extern-call-i32-native-smoke`
- `guard-cranelift-mir-extern-predicate-branch-i32-native-smoke`
- `guard-cranelift-mir-increment-local-i32-native-smoke`
- `guard-cranelift-mir-local-binding-read-native-smoke`
- `guard-cranelift-mir-positive-i32-branch-native-smoke`
- `guard-cranelift-mir-return-int-native-smoke`
- `guard-cranelift-mir-to-c-differential-native-smoke`
- `guard-cranelift-mir-to-cranelift-add-i32-translator-native-smoke`
- `guard-cranelift-mir-to-cranelift-block-jump-translator-native-smoke`
- `guard-cranelift-mir-to-cranelift-block-local-branch-join-translator-native-smoke`
- `guard-cranelift-mir-to-cranelift-block-param-merge-arm-update-imported-call-branch-translator-native-smoke`
- `guard-cranelift-mir-to-cranelift-block-param-merge-arm-update-imported-call-return-translator-native-smoke`
- `guard-cranelift-mir-to-cranelift-block-param-merge-dual-imported-joined-return-translator-native-smoke`
- `guard-cranelift-mir-to-cranelift-block-param-merge-imported-branch-joined-return-translator-native-smoke`
- `guard-cranelift-mir-to-cranelift-block-param-merge-imported-call-return-translator-native-smoke`
- `guard-cranelift-mir-to-cranelift-block-param-merge-update-branch-translator-native-smoke`
- `guard-cranelift-mir-to-cranelift-block-param-update-branch-translator-native-smoke`
- `guard-cranelift-mir-to-cranelift-conditional-branch-translator-native-smoke`
- `guard-cranelift-mir-to-cranelift-local-binding-read-translator-native-smoke`
- `guard-cranelift-mir-to-cranelift-native-boundary-metadata-translator-native-smoke`
- `guard-cranelift-mir-to-cranelift-positive-i32-branch-translator-native-smoke`
- `guard-cranelift-mir-to-cranelift-provenance-metadata-translator-native-smoke`
- `guard-cranelift-mir-to-cranelift-resource-metadata-translator-native-smoke`
- `guard-cranelift-mir-to-cranelift-return-int-translator-native-smoke`
- `guard-cranelift-mir-to-cranelift-translator-seed-suite`
- `guard-cranelift-mir-to-cranelift-translator-seed-suite-shard`
- `guard-cranelift-no-fixture-regression`
- `guard-cranelift-phase10-backend-request-contract`
- `guard-cranelift-phase10-backend-selection-contract`
- `guard-cranelift-phase10-call-import-runtime-source-route`
- `guard-cranelift-phase10-capability-contract`
- `guard-cranelift-phase10-cfg-block-parameter-source-route`
- `guard-cranelift-phase10-close`
- `guard-cranelift-phase10-driver-handshake-contract`
- `guard-cranelift-phase10-opening-contract`
- `guard-cranelift-phase10-output-contract`
- `guard-cranelift-phase10-packaging-help-ci`
- `guard-cranelift-phase10-program-mir-contract`
- `guard-cranelift-phase10-scalar-source-route`
- `guard-cranelift-phase11-generic-canonical-mir-route`
- `guard-cranelift-phase14-all-target-composition`
- `guard-cranelift-phase15-complete-resource-evidence`
- `guard-cranelift-phase16-complete-abi-evidence`
- `guard-cranelift-phase17-complete-runtime-evidence`
- `guard-cranelift-phase18-complete-target-evidence`
- `guard-cranelift-phase19-rename-invariance`
- `guard-cranelift-phase19-self-compilation-differential`
- `guard-cranelift-phase9b-close`
- `guard-cranelift-phase9c-close`
- `guard-cranelift-phase9c-differential-ladder-native-shard`
- `guard-cranelift-phase9c-differential-ladder-native-smoke`
- `guard-cranelift-phase9d-close`
- `guard-cranelift-phase9d-first-post9c-cohort-bypass-freeze`
- `guard-cranelift-phase9d-generic-ingestion-command`
- `guard-cranelift-phase9d-ingestion-inventory-architecture`
- `guard-cranelift-phase9d-opening-contract`
- `guard-cranelift-phase9d-phase9c-rebase-metadata`
- `guard-cranelift-phase9d-schema-parser-validator`
- `guard-cranelift-phase9e-block-parameter-schema-validator`
- `guard-cranelift-phase9e-block-parameter-to-local-materialization-cohort`
- `guard-cranelift-phase9e-cfg-completeness-rejection-phase9f-freeze`
- `guard-cranelift-phase9e-close`
- `guard-cranelift-phase9e-local-cfg-cohort`
- `guard-cranelift-phase9e-opening-contract`
- `guard-cranelift-phase9e-shared-block-parameter-lowering-core`
- `guard-cranelift-phase9e-single-parameter-cfg-cohort`
- `guard-cranelift-phase9e-variable-arity-block-parameter-cohort`
- `guard-cranelift-phase9f-call-import-completeness-rejection`
- `guard-cranelift-phase9f-call-import-schema-validator`
- `guard-cranelift-phase9f-close`
- `guard-cranelift-phase9f-direct-imported-call-cohort`
- `guard-cranelift-phase9f-imported-materialization-predicate-cohort`
- `guard-cranelift-phase9f-joined-imported-call-cohort`
- `guard-cranelift-phase9f-merge-arm-imported-call-cohort`
- `guard-cranelift-phase9f-module-emitter-local-call-cohort`
- `guard-cranelift-phase9f-opening-contract`
- `guard-cranelift-phase9g-close`
- `guard-cranelift-phase9g-link-bypass-retirement`
- `guard-cranelift-phase9g-link-driver-contract`
- `guard-cranelift-phase9g-negative-link-matrix`
- `guard-cranelift-phase9g-object-artifact-contract`
- `guard-cranelift-phase9g-object-inspection-contract`
- `guard-cranelift-phase9g-object-reproducibility`
- `guard-cranelift-phase9g-opening-contract`
- `guard-cranelift-phase9g-phase9c-phase9e-link-migration`
- `guard-cranelift-phase9g-pipeline-failure-classification`
- `guard-cranelift-phase9g-positive-link-matrix`
- `guard-cranelift-phase9g-target-relocation-contract`
- `guard-cranelift-positive-i32-branch-native-smoke`
- `guard-cranelift-return-int-native-smoke`

Registration is not a pass claim. Phase 20 closure requires a successful
authoritative Historical Full run on exact merged main.
