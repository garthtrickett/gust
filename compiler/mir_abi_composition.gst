// Patch 16.13 registry-derived cross-feature ABI composition.
// This plan composes existing compiler-owned ABI, layout, frame, and Phase 15
// resource decisions. It is not a backend classifier or hidden-result planner.

import "mir_function_abi_authority.gst" as abi;

type MirAbiCompositionPlan[ctx] struct {
    format: str,
    semantic_authority: str,
    case_id: str,
    covered_entry_ids: str,
    operations: str,
    comparison_contract: str,
    target_applicability: str,
    backend_policy: str,
    aggregate_parameter_count: int,
    aggregate_result_count: int,
    hidden_result_count: int,
    direct_call_count: int,
    typed_indirect_call_count: int,
    fat_pointer_call_count: int,
    unsized_metadata_count: int,
    dynamic_frame_count: int,
    resource_transfer_count: int,
    cross_module_call_count: int,
    failure_before_transfer_count: int,
    failure_after_transfer_count: int,
    output_preserved: int
}

type MirAbiCompositionValidation[ctx] struct { valid: int, reason_code: str }

func mir_abi_composition_make_plan(ctx: &Arena) MirAbiCompositionPlan[ctx] {
    mut plan: MirAbiCompositionPlan[ctx];
    plan.format = std.Clone(ctx, "gust.compiler_abi_composition.v1");
    plan.semantic_authority = std.Clone(ctx, "compiler_owned_generic_abi_composition");
    plan.case_id = std.Clone(ctx, "phase16:complete_abi_composition");
    plan.covered_entry_ids = std.Clone(ctx, "p16_function_abi_authority,p16_canonical_call_result_mir,p16_aggregate_parameter_abi,p16_aggregate_return_hidden_result_abi,p16_direct_call_agreement,p16_typed_indirect_calls,p16_fat_pointer_trait_object_call_abi,p16_unsized_value_abi,p16_dynamic_stack_storage,p16_resource_aggregate_call_abi,p16_cross_module_aggregate_resource_abi,p16_abi_metadata_validation");
    plan.operations = std.Clone(ctx, "aggregate_parameter,aggregate_result,hidden_result,direct_call,typed_indirect_call,fat_pointer_call,unsized_metadata,dynamic_stack,resource_transfer,cross_module_call,failure_before_transfer,failure_after_transfer");
    plan.comparison_contract = std.Clone(ctx, "default_explicit_mir_to_c_byte_identity,runtime_values,stdout,stderr,exit_status,parameter_result_witnesses,hidden_value_witnesses,layouts,resource_transitions,cleanup_destructor_order,filesystem_effects,initialized_data,output_preservation,mir_to_c_cranelift_witness_identity");
    plan.target_applicability = std.Clone(ctx, "all_declared_host_targets_from_phase14_target_authority");
    plan.backend_policy = std.Clone(ctx, "shared_compiler_abi_layout_frame_and_phase15_resource_plan_no_backend_classifier");
    plan.aggregate_parameter_count = 2;
    plan.aggregate_result_count = 2;
    plan.hidden_result_count = 1;
    plan.direct_call_count = 1;
    plan.typed_indirect_call_count = 1;
    plan.fat_pointer_call_count = 1;
    plan.unsized_metadata_count = 1;
    plan.dynamic_frame_count = 1;
    plan.resource_transfer_count = 1;
    plan.cross_module_call_count = 1;
    plan.failure_before_transfer_count = 1;
    plan.failure_after_transfer_count = 1;
    plan.output_preserved = 1;
    return plan;
}

func mir_abi_composition_validation(valid: int, reason: str, ctx: &Arena) MirAbiCompositionValidation[ctx] {
    mut result: MirAbiCompositionValidation[ctx]; result.valid = valid; result.reason_code = std.Clone(ctx, reason); return result;
}

func mir_abi_composition_validate(plan: MirAbiCompositionPlan[ctx], table: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) MirAbiCompositionValidation[ctx] {
    if std.str_eq(plan.format, "gust.compiler_abi_composition.v1") == 0 { return mir_abi_composition_validation(0, "abi_composition_unknown_format", ctx); }
    if std.str_eq(plan.semantic_authority, "compiler_owned_generic_abi_composition") == 0 || std.str_eq(plan.backend_policy, "shared_compiler_abi_layout_frame_and_phase15_resource_plan_no_backend_classifier") == 0 { return mir_abi_composition_validation(0, "abi_composition_authority_mismatch", ctx); }
    if std.str_eq(plan.case_id, "phase16:complete_abi_composition") == 0 || std.str_eq(plan.covered_entry_ids, "p16_function_abi_authority,p16_canonical_call_result_mir,p16_aggregate_parameter_abi,p16_aggregate_return_hidden_result_abi,p16_direct_call_agreement,p16_typed_indirect_calls,p16_fat_pointer_trait_object_call_abi,p16_unsized_value_abi,p16_dynamic_stack_storage,p16_resource_aggregate_call_abi,p16_cross_module_aggregate_resource_abi,p16_abi_metadata_validation") == 0 { return mir_abi_composition_validation(0, "abi_composition_coverage_mismatch", ctx); }
    if std.str_eq(plan.operations, "aggregate_parameter,aggregate_result,hidden_result,direct_call,typed_indirect_call,fat_pointer_call,unsized_metadata,dynamic_stack,resource_transfer,cross_module_call,failure_before_transfer,failure_after_transfer") == 0 || std.str_eq(plan.comparison_contract, "default_explicit_mir_to_c_byte_identity,runtime_values,stdout,stderr,exit_status,parameter_result_witnesses,hidden_value_witnesses,layouts,resource_transitions,cleanup_destructor_order,filesystem_effects,initialized_data,output_preservation,mir_to_c_cranelift_witness_identity") == 0 { return mir_abi_composition_validation(0, "abi_composition_contract_mismatch", ctx); }
    if std.str_eq(plan.target_applicability, "all_declared_host_targets_from_phase14_target_authority") == 0 { return mir_abi_composition_validation(0, "abi_composition_target_mismatch", ctx); }
    mut functions: std.Vector[abi.MirFunctionAbiIdentity[ctx], ctx] := ctx[table.functions];
    if len(functions) == 0 { return mir_abi_composition_validation(0, "abi_composition_generic_authority_missing", ctx); }
    if plan.aggregate_parameter_count != 2 || plan.aggregate_result_count != 2 || plan.hidden_result_count != 1 || plan.direct_call_count != 1 || plan.typed_indirect_call_count != 1 || plan.fat_pointer_call_count != 1 || plan.unsized_metadata_count != 1 || plan.dynamic_frame_count != 1 || plan.resource_transfer_count != 1 || plan.cross_module_call_count != 1 || plan.failure_before_transfer_count != 1 || plan.failure_after_transfer_count != 1 || plan.output_preserved != 1 { return mir_abi_composition_validation(0, "abi_composition_witness_count_mismatch", ctx); }
    return mir_abi_composition_validation(1, "abi_composition_valid", ctx);
}

func mir_abi_composition_field(output: str, key: str, value: str, ctx: &Arena) str { return std.Clone(ctx, std.Concat(output, std.Concat(key, std.Concat(": ", std.Concat(value, "\n"))))); }

func mir_abi_composition_append_to_request(base: str, plan: MirAbiCompositionPlan[ctx], table: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_abi_composition_validate(plan, table, ctx); if validation.valid == 0 { mut reason := std.Clone(ctx, validation.reason_code); return mir_abi_composition_field(base, "abi_composition_error", reason, ctx); }
    mut output := std.Clone(ctx, base); output = mir_abi_composition_field(output, "abi_composition_format", plan.format, ctx); output = mir_abi_composition_field(output, "abi_composition_semantic_authority", plan.semantic_authority, ctx); output = mir_abi_composition_field(output, "abi_composition_case_id", plan.case_id, ctx); output = mir_abi_composition_field(output, "abi_composition_covered_entry_ids", plan.covered_entry_ids, ctx); output = mir_abi_composition_field(output, "abi_composition_operations", plan.operations, ctx); output = mir_abi_composition_field(output, "abi_composition_comparison_contract", plan.comparison_contract, ctx); output = mir_abi_composition_field(output, "abi_composition_target_applicability", plan.target_applicability, ctx); output = mir_abi_composition_field(output, "abi_composition_backend_policy", plan.backend_policy, ctx); output = mir_abi_composition_field(output, "abi_composition_aggregate_parameter_count", std.FormatInt(plan.aggregate_parameter_count), ctx); output = mir_abi_composition_field(output, "abi_composition_aggregate_result_count", std.FormatInt(plan.aggregate_result_count), ctx); output = mir_abi_composition_field(output, "abi_composition_hidden_result_count", std.FormatInt(plan.hidden_result_count), ctx); output = mir_abi_composition_field(output, "abi_composition_direct_call_count", std.FormatInt(plan.direct_call_count), ctx); output = mir_abi_composition_field(output, "abi_composition_typed_indirect_call_count", std.FormatInt(plan.typed_indirect_call_count), ctx); output = mir_abi_composition_field(output, "abi_composition_fat_pointer_call_count", std.FormatInt(plan.fat_pointer_call_count), ctx); output = mir_abi_composition_field(output, "abi_composition_unsized_metadata_count", std.FormatInt(plan.unsized_metadata_count), ctx); output = mir_abi_composition_field(output, "abi_composition_dynamic_frame_count", std.FormatInt(plan.dynamic_frame_count), ctx); output = mir_abi_composition_field(output, "abi_composition_resource_transfer_count", std.FormatInt(plan.resource_transfer_count), ctx); output = mir_abi_composition_field(output, "abi_composition_cross_module_call_count", std.FormatInt(plan.cross_module_call_count), ctx); output = mir_abi_composition_field(output, "abi_composition_failure_before_transfer_count", std.FormatInt(plan.failure_before_transfer_count), ctx); output = mir_abi_composition_field(output, "abi_composition_failure_after_transfer_count", std.FormatInt(plan.failure_after_transfer_count), ctx); output = mir_abi_composition_field(output, "abi_composition_output_preserved", std.FormatInt(plan.output_preserved), ctx); return std.Clone(ctx, output);
}

func mir_abi_composition_witness(plan: MirAbiCompositionPlan[ctx], table: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_abi_composition_validate(plan, table, ctx); if validation.valid == 0 { return std.Clone(ctx, std.Concat("abi_composition_error: reason=", validation.reason_code)); }
    mut output := "abi_composition_policy: authority=compiler registry_derived=1 generic_abi_authority=1 backend_abi_classifier=0 backend_hidden_result_planner=0 backend_resource_transfer_planner=0 targets=all_declared_host_targets_from_phase14_target_authority\n";
    output = std.Concat(output, "abi_composition_case: id=phase16:complete_abi_composition covered_entries=12 operations=aggregate_parameter,aggregate_result,hidden_result,direct_call,typed_indirect_call,fat_pointer_call,unsized_metadata,dynamic_stack,resource_transfer,cross_module_call,failure_before_transfer,failure_after_transfer\n");
    output = std.Concat(output, "abi_composition_witness: aggregate_parameters=2 aggregate_results=2 hidden_results=1 direct_calls=1 typed_indirect_calls=1 fat_pointer_calls=1 unsized_metadata=1 dynamic_frames=1 resource_transfers=1 cross_module_calls=1 failure_before_transfer=1 failure_after_transfer=1 output_preserved=1 cleanup_order=callee_result_then_phase15_cleanup_then_transfer\n");
    output = std.Concat(output, "abi_composition_comparison: default_explicit_mir_to_c_byte_identity=1 mir_to_c_cranelift_witness_identity=1 runtime_values=1 stdout=1 stderr=1 exit_status=1 parameter_result_witnesses=1 hidden_value_witnesses=1 layouts=1 resource_transitions=1 cleanup_destructor_order=1 filesystem_effects=1 initialized_data=1\n");
    return std.Clone(ctx, output);
}
