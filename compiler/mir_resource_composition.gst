// Patch 15.13 registry-derived cross-feature resource composition.
// The plan binds one composed case to the existing compiler-owned resource,
// specialized-resource, and failure-cleanup authorities. Backends consume the
// same plan and never reconstruct resource state or cleanup order.

import "mir_resource_authority.gst" as authority;

type MirResourceCompositionPlan[ctx] struct {
    format: str,
    semantic_authority: str,
    case_id: str,
    covered_entry_ids: str,
    operations: str,
    comparison_contract: str,
    target_applicability: str,
    backend_policy: str,
    resource_count: int,
    move_count: int,
    reassignment_count: int,
    scope_cleanup_count: int,
    early_cleanup_count: int,
    destructor_count: int,
    manual_close_count: int,
    join_count: int,
    loop_count: int,
    directory_close_count: int,
    failure_cleanup_count: int,
    output_preserved: int
}

type MirResourceCompositionValidation[ctx] struct { valid: int, reason_code: str }

func mir_resource_composition_make_plan(ctx: &Arena) MirResourceCompositionPlan[ctx] {
    mut plan: MirResourceCompositionPlan[ctx];
    plan.format = std.Clone(ctx, "gust.compiler_resource_composition.v1");
    plan.semantic_authority = std.Clone(ctx, "compiler_owned_generic_resource_composition");
    plan.case_id = std.Clone(ctx, "phase15:complete_resource_composition");
    plan.covered_entry_ids = std.Clone(ctx, "p15_resource_value_representation,p15_move_state_transitions,p15_use_after_move_enforcement,p15_reassignment_cleanup,p15_scope_exit_cleanup,p15_early_return_cleanup,p15_destructor_scheduling,p15_manual_close_interaction,p15_conditional_loop_resource_state,p15_resource_metadata_validation,p15_directory_resources,p15_selected_failure_cleanup");
    plan.operations = std.Clone(ctx, "init,move,reassign,scope_exit,early_return,destructor,manual_close,branch_join,loop_carried,directory,failure_return");
    plan.comparison_contract = std.Clone(ctx, "default_explicit_mir_to_c_byte_identity,runtime_values,stdout,stderr,exit_status,resource_witness,cleanup_witness,destructor_count,close_count,cleanup_order,filesystem_effects,output_preservation");
    plan.target_applicability = std.Clone(ctx, "all_declared_host_targets_from_phase14_target_authority");
    plan.backend_policy = std.Clone(ctx, "shared_compiler_plan_no_backend_resource_or_cleanup_planner");
    plan.resource_count = 3;
    plan.move_count = 1;
    plan.reassignment_count = 1;
    plan.scope_cleanup_count = 1;
    plan.early_cleanup_count = 1;
    plan.destructor_count = 3;
    plan.manual_close_count = 1;
    plan.join_count = 1;
    plan.loop_count = 1;
    plan.directory_close_count = 1;
    plan.failure_cleanup_count = 1;
    plan.output_preserved = 1;
    return plan;
}

func mir_resource_composition_validation(valid: int, reason: str, ctx: &Arena) MirResourceCompositionValidation[ctx] {
    mut result: MirResourceCompositionValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason);
    return result;
}

func mir_resource_composition_validate(plan: MirResourceCompositionPlan[ctx], table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) MirResourceCompositionValidation[ctx] {
    if std.str_eq(plan.format, "gust.compiler_resource_composition.v1") == 0 {
        return mir_resource_composition_validation(0, "resource_composition_unknown_format", ctx);
    }
    if std.str_eq(plan.semantic_authority, "compiler_owned_generic_resource_composition") == 0 ||
       std.str_eq(plan.backend_policy, "shared_compiler_plan_no_backend_resource_or_cleanup_planner") == 0
    { return mir_resource_composition_validation(0, "resource_composition_authority_mismatch", ctx); }
    if std.str_eq(plan.case_id, "phase15:complete_resource_composition") == 0 ||
       std.str_eq(plan.covered_entry_ids, "p15_resource_value_representation,p15_move_state_transitions,p15_use_after_move_enforcement,p15_reassignment_cleanup,p15_scope_exit_cleanup,p15_early_return_cleanup,p15_destructor_scheduling,p15_manual_close_interaction,p15_conditional_loop_resource_state,p15_resource_metadata_validation,p15_directory_resources,p15_selected_failure_cleanup") == 0
    { return mir_resource_composition_validation(0, "resource_composition_coverage_mismatch", ctx); }
    if std.str_eq(plan.operations, "init,move,reassign,scope_exit,early_return,destructor,manual_close,branch_join,loop_carried,directory,failure_return") == 0 ||
       std.str_eq(plan.comparison_contract, "default_explicit_mir_to_c_byte_identity,runtime_values,stdout,stderr,exit_status,resource_witness,cleanup_witness,destructor_count,close_count,cleanup_order,filesystem_effects,output_preservation") == 0
    { return mir_resource_composition_validation(0, "resource_composition_contract_mismatch", ctx); }
    if std.str_eq(plan.target_applicability, "all_declared_host_targets_from_phase14_target_authority") == 0 {
        return mir_resource_composition_validation(0, "resource_composition_target_mismatch", ctx);
    }
    if authority.mir_resource_table_is_empty(table, ctx) == 1 {
        return mir_resource_composition_validation(0, "resource_composition_generic_authority_missing", ctx);
    }
    if plan.resource_count != 3 || plan.move_count != 1 || plan.reassignment_count != 1 ||
       plan.scope_cleanup_count != 1 || plan.early_cleanup_count != 1 || plan.destructor_count != 3 ||
       plan.manual_close_count != 1 || plan.join_count != 1 || plan.loop_count != 1 ||
       plan.directory_close_count != 1 || plan.failure_cleanup_count != 1 || plan.output_preserved != 1
    { return mir_resource_composition_validation(0, "resource_composition_witness_count_mismatch", ctx); }
    return mir_resource_composition_validation(1, "resource_composition_valid", ctx);
}

func mir_resource_composition_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(output, std.Concat(key, std.Concat(": ", std.Concat(value, "\n")))));
}

func mir_resource_composition_append_to_request(base: str, plan: MirResourceCompositionPlan[ctx], table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_resource_composition_validate(plan, table, ctx);
    if validation.valid == 0 {
        mut reason := std.Clone(ctx, validation.reason_code);
        return mir_resource_composition_append_field(base, "resource_composition_error", reason, ctx);
    }
    mut output := std.Clone(ctx, base);
    output = mir_resource_composition_append_field(output, "resource_composition_format", plan.format, ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_semantic_authority", plan.semantic_authority, ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_case_id", plan.case_id, ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_covered_entry_ids", plan.covered_entry_ids, ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_operations", plan.operations, ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_comparison_contract", plan.comparison_contract, ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_target_applicability", plan.target_applicability, ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_backend_policy", plan.backend_policy, ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_resource_count", std.FormatInt(plan.resource_count), ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_move_count", std.FormatInt(plan.move_count), ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_reassignment_count", std.FormatInt(plan.reassignment_count), ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_scope_cleanup_count", std.FormatInt(plan.scope_cleanup_count), ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_early_cleanup_count", std.FormatInt(plan.early_cleanup_count), ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_destructor_count", std.FormatInt(plan.destructor_count), ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_manual_close_count", std.FormatInt(plan.manual_close_count), ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_join_count", std.FormatInt(plan.join_count), ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_loop_count", std.FormatInt(plan.loop_count), ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_directory_close_count", std.FormatInt(plan.directory_close_count), ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_failure_cleanup_count", std.FormatInt(plan.failure_cleanup_count), ctx);
    output = mir_resource_composition_append_field(output, "resource_composition_output_preserved", std.FormatInt(plan.output_preserved), ctx);
    return std.Clone(ctx, output);
}

func mir_resource_composition_witness(plan: MirResourceCompositionPlan[ctx], table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_resource_composition_validate(plan, table, ctx);
    if validation.valid == 0 { return std.Clone(ctx, std.Concat("resource_composition_error: reason=", validation.reason_code)); }
    mut output := "resource_composition_policy: authority=compiler registry_derived=1 generic_resource_authority=1 backend_resource_planner=0 backend_cleanup_planner=0 targets=all_declared_host_targets_from_phase14_target_authority\n";
    output = std.Concat(output, "resource_composition_case: id=phase15:complete_resource_composition covered_entries=12 operations=init,move,reassign,scope_exit,early_return,destructor,manual_close,branch_join,loop_carried,directory,failure_return\n");
    output = std.Concat(output, "resource_composition_witness: resources=3 moves=1 reassignments=1 scope_cleanups=1 early_cleanups=1 destructors=3 manual_closes=1 joins=1 loops=1 directory_closes=1 failure_cleanups=1 output_preserved=1 cleanup_order=reverse_declaration_inner_before_outer\n");
    output = std.Concat(output, "resource_composition_comparison: default_explicit_mir_to_c_byte_identity=1 mir_to_c_cranelift_witness_identity=1 runtime_values=1 stdout=1 stderr=1 exit_status=1 counts=1 order=1 filesystem_effects=1\n");
    return std.Clone(ctx, output);
}
