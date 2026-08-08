// Patch 15.12 bounded panic and failure cleanup policy.
// Failure edges consume MirResourceAuthorityTable cleanup obligations. The
// backends serialize and lower this plan; neither backend reconstructs which
// resources are live, their destructor identity, or cleanup order.

import "mir_resource_authority.gst" as authority;

type MirFailureCleanupForm[ctx] struct {
    form_id: str,
    failure_stage: str,
    terminal_kind: str,
    stable_authority: str,
    cleanup_policy: str,
    resource_id: str,
    scope_exit_id: str,
    final_state: str,
    cleanup_count: int,
    destructor_count: int,
    exit_status: int,
    output_preserved: int
}

type MirFailureCleanupPlan[ctx] struct {
    format: str,
    semantic_authority: str,
    selected_forms: str,
    deferred_forms: str,
    order_policy: str,
    backend_policy: str,
    target_applicability: str,
    forms: Index[std.Vector[MirFailureCleanupForm[ctx], ctx], ctx]
}

type MirFailureCleanupValidation[ctx] struct { valid: int, reason_code: str }

func mir_failure_cleanup_empty_forms(ctx: &Arena) Index[std.Vector[MirFailureCleanupForm[ctx], ctx], ctx] {
    mut values: std.Vector[MirFailureCleanupForm[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirFailureCleanupForm[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_failure_cleanup_make_plan(ctx: &Arena) MirFailureCleanupPlan[ctx] {
    mut plan: MirFailureCleanupPlan[ctx];
    plan.format = std.Clone(ctx, "gust.compiler_failure_cleanup.v1");
    plan.semantic_authority = std.Clone(ctx, "compiler_owned_failure_cleanup_policy");
    plan.selected_forms = std.Clone(ctx, "trap_before_exec,runtime_failure_return,selected_panic,native_op_failure_edge");
    plan.deferred_forms = std.Clone(ctx, "async_unwind,foreign_exception,cancellation");
    plan.order_policy = std.Clone(ctx, "reverse_declaration_inner_before_outer");
    plan.backend_policy = std.Clone(ctx, "shared_canonical_mir_failure_edges_no_backend_cleanup_planner");
    plan.target_applicability = std.Clone(ctx, "all_declared_host_targets_from_phase14_target_authority");
    plan.forms = mir_failure_cleanup_empty_forms(ctx);
    return plan;
}

func mir_failure_cleanup_with_form(plan: MirFailureCleanupPlan[ctx], form: MirFailureCleanupForm[ctx], ctx: &Arena) MirFailureCleanupPlan[ctx] {
    mut updated := plan;
    mut values: std.Vector[MirFailureCleanupForm[ctx], ctx] := ctx[updated.forms];
    values.Push(form);
    ctx.Set(updated.forms, values);
    return updated;
}

func mir_failure_cleanup_validation(valid: int, reason: str, ctx: &Arena) MirFailureCleanupValidation[ctx] {
    mut result: MirFailureCleanupValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason);
    return result;
}

func mir_failure_cleanup_form_shape_valid(form: MirFailureCleanupForm[ctx]) int {
    if std.str_eq(form.form_id, "trap_before_exec") == 1 {
        if std.str_eq(form.failure_stage, "before_driver_discovery") == 0 ||
           std.str_eq(form.terminal_kind, "compiler_rejection") == 0 ||
           std.str_eq(form.stable_authority, "compiler_resource_cleanup_verifier") == 0 ||
           std.str_eq(form.cleanup_policy, "no_cleanup_resource_not_initialized") == 0 ||
           std.str_eq(form.resource_id, "none") == 0 || std.str_eq(form.scope_exit_id, "none") == 0 ||
           std.str_eq(form.final_state, "uninitialized") == 0 || form.cleanup_count != 0 ||
           form.destructor_count != 0 || form.exit_status != 65 || form.output_preserved != 1
        { return 0; }
        return 1;
    }
    if std.str_eq(form.form_id, "runtime_failure_return") == 1 {
        if std.str_eq(form.failure_stage, "runtime_failure_status_edge") == 0 ||
           std.str_eq(form.terminal_kind, "failure_return") == 0 ||
           std.str_eq(form.stable_authority, "canonical_mir_failure_return.v1") == 0 ||
           form.exit_status != 82
        { return 0; }
    } else if std.str_eq(form.form_id, "selected_panic") == 1 {
        if std.str_eq(form.failure_stage, "compiler_selected_panic_edge") == 0 ||
           std.str_eq(form.terminal_kind, "trap_after_cleanup") == 0 ||
           std.str_eq(form.stable_authority, "gust.compiler_panic.v1") == 0 ||
           form.exit_status != 101
        { return 0; }
    } else if std.str_eq(form.form_id, "native_op_failure_edge") == 1 {
        if std.str_eq(form.failure_stage, "canonical_mir_native_failure_edge") == 0 ||
           std.str_eq(form.terminal_kind, "propagate_native_status") == 0 ||
           std.str_eq(form.stable_authority, "gust.compiler_native_failure.v1") == 0 ||
           form.exit_status != 74
        { return 0; }
    } else {
        return 0;
    }
    if std.str_eq(form.cleanup_policy, "cleanup_live_resources_then_terminate") == 0 ||
       std.str_eq(form.resource_id, "none") == 1 || std.str_eq(form.scope_exit_id, "none") == 1 ||
       std.str_eq(form.final_state, "destroyed") == 0 || form.cleanup_count != 1 ||
       form.destructor_count != 1 || form.output_preserved != 1
    { return 0; }
    return 1;
}

func mir_failure_cleanup_validate(plan: MirFailureCleanupPlan[ctx], table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) MirFailureCleanupValidation[ctx] {
    if std.str_eq(plan.format, "gust.compiler_failure_cleanup.v1") == 0 {
        return mir_failure_cleanup_validation(0, "failure_cleanup_unknown_format", ctx);
    }
    if std.str_eq(plan.semantic_authority, "compiler_owned_failure_cleanup_policy") == 0 ||
       std.str_eq(plan.backend_policy, "shared_canonical_mir_failure_edges_no_backend_cleanup_planner") == 0
    { return mir_failure_cleanup_validation(0, "failure_cleanup_authority_mismatch", ctx); }
    if std.str_eq(plan.selected_forms, "trap_before_exec,runtime_failure_return,selected_panic,native_op_failure_edge") == 0 {
        return mir_failure_cleanup_validation(0, "failure_cleanup_inventory_unfrozen", ctx);
    }
    if std.str_eq(plan.deferred_forms, "async_unwind,foreign_exception,cancellation") == 0 {
        return mir_failure_cleanup_validation(0, "failure_cleanup_deferred_boundary_mismatch", ctx);
    }
    if std.str_eq(plan.order_policy, "reverse_declaration_inner_before_outer") == 0 ||
       std.str_eq(plan.target_applicability, "all_declared_host_targets_from_phase14_target_authority") == 0
    { return mir_failure_cleanup_validation(0, "failure_cleanup_policy_mismatch", ctx); }
    mut forms: std.Vector[MirFailureCleanupForm[ctx], ctx] := ctx[plan.forms];
    if len(forms) != 4 { return mir_failure_cleanup_validation(0, "failure_cleanup_form_count_mismatch", ctx); }
    mut index := 0;
    while index < len(forms) {
        mut form := forms[index];
        if mir_failure_cleanup_form_shape_valid(form) == 0 {
            return mir_failure_cleanup_validation(0, "failure_cleanup_form_policy_mismatch", ctx);
        }
        mut duplicate_index := index + 1;
        while duplicate_index < len(forms) {
            if std.str_eq(form.form_id, forms[duplicate_index].form_id) == 1 {
                return mir_failure_cleanup_validation(0, "failure_cleanup_duplicate_form", ctx);
            }
            duplicate_index = duplicate_index + 1;
        }
        if form.cleanup_count == 1 {
            mut resource := authority.mir_resource_by_id(table, form.resource_id, ctx);
            if resource.found == 0 { return mir_failure_cleanup_validation(0, "failure_cleanup_unknown_resource", ctx); }
            mut cleanup := authority.mir_cleanup_obligation_for_resource_scope(table, form.resource_id, form.scope_exit_id, ctx);
            if cleanup.found == 0 { return mir_failure_cleanup_validation(0, "failure_cleanup_obligation_missing", ctx); }
            if cleanup.value.exactly_once != 1 || cleanup.value.execution_order != 1 ||
               std.str_eq(cleanup.value.failure_policy, "selected_failure_cleanup") == 0 ||
               std.str_eq(cleanup.value.destructor_id, resource.value.destructor_id) == 0
            { return mir_failure_cleanup_validation(0, "failure_cleanup_obligation_mismatch", ctx); }
            mut state := authority.mir_resource_latest_state(table, form.resource_id, ctx);
            if state.found == 0 || std.str_eq(state.value.state, form.final_state) == 0 {
                return mir_failure_cleanup_validation(0, "failure_cleanup_terminal_state_mismatch", ctx);
            }
        }
        index = index + 1;
    }
    return mir_failure_cleanup_validation(1, "failure_cleanup_valid", ctx);
}

func mir_failure_cleanup_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(output, std.Concat(key, std.Concat(": ", std.Concat(value, "\n")))));
}

func mir_failure_cleanup_append_to_request(base: str, plan: MirFailureCleanupPlan[ctx], table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_failure_cleanup_validate(plan, table, ctx);
    if validation.valid == 0 {
        mut stable_reason := std.Clone(ctx, validation.reason_code);
        return mir_failure_cleanup_append_field(base, "failure_cleanup_error", stable_reason, ctx);
    }
    mut output := std.Clone(ctx, base);
    output = mir_failure_cleanup_append_field(output, "failure_cleanup_format", plan.format, ctx);
    output = mir_failure_cleanup_append_field(output, "failure_cleanup_semantic_authority", plan.semantic_authority, ctx);
    output = mir_failure_cleanup_append_field(output, "failure_cleanup_selected_forms", plan.selected_forms, ctx);
    output = mir_failure_cleanup_append_field(output, "failure_cleanup_deferred_forms", plan.deferred_forms, ctx);
    output = mir_failure_cleanup_append_field(output, "failure_cleanup_order_policy", plan.order_policy, ctx);
    output = mir_failure_cleanup_append_field(output, "failure_cleanup_backend_policy", plan.backend_policy, ctx);
    output = mir_failure_cleanup_append_field(output, "failure_cleanup_target_applicability", plan.target_applicability, ctx);
    mut forms: std.Vector[MirFailureCleanupForm[ctx], ctx] := ctx[plan.forms];
    output = mir_failure_cleanup_append_field(output, "failure_cleanup_form_count", std.FormatInt(len(forms)), ctx);
    mut index := 0;
    while index < len(forms) {
        mut prefix := std.Concat("failure_cleanup_form_", std.FormatInt(index));
        output = mir_failure_cleanup_append_field(output, std.Concat(prefix, "_id"), forms[index].form_id, ctx);
        output = mir_failure_cleanup_append_field(output, std.Concat(prefix, "_failure_stage"), forms[index].failure_stage, ctx);
        output = mir_failure_cleanup_append_field(output, std.Concat(prefix, "_terminal_kind"), forms[index].terminal_kind, ctx);
        output = mir_failure_cleanup_append_field(output, std.Concat(prefix, "_stable_authority"), forms[index].stable_authority, ctx);
        output = mir_failure_cleanup_append_field(output, std.Concat(prefix, "_cleanup_policy"), forms[index].cleanup_policy, ctx);
        output = mir_failure_cleanup_append_field(output, std.Concat(prefix, "_resource_id"), forms[index].resource_id, ctx);
        output = mir_failure_cleanup_append_field(output, std.Concat(prefix, "_scope_exit_id"), forms[index].scope_exit_id, ctx);
        output = mir_failure_cleanup_append_field(output, std.Concat(prefix, "_final_state"), forms[index].final_state, ctx);
        output = mir_failure_cleanup_append_field(output, std.Concat(prefix, "_cleanup_count"), std.FormatInt(forms[index].cleanup_count), ctx);
        output = mir_failure_cleanup_append_field(output, std.Concat(prefix, "_destructor_count"), std.FormatInt(forms[index].destructor_count), ctx);
        output = mir_failure_cleanup_append_field(output, std.Concat(prefix, "_exit_status"), std.FormatInt(forms[index].exit_status), ctx);
        output = mir_failure_cleanup_append_field(output, std.Concat(prefix, "_output_preserved"), std.FormatInt(forms[index].output_preserved), ctx);
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_failure_cleanup_witness(plan: MirFailureCleanupPlan[ctx], table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_failure_cleanup_validate(plan, table, ctx);
    if validation.valid == 0 { return std.Clone(ctx, std.Concat("failure_cleanup_error: reason=", validation.reason_code)); }
    mut output := "failure_cleanup_policy: authority=compiler selected_forms=trap_before_exec,runtime_failure_return,selected_panic,native_op_failure_edge deferred_forms=async_unwind,foreign_exception,cancellation order=reverse_declaration_inner_before_outer exactly_once=1 backend_cleanup_planner=0\n";
    mut forms: std.Vector[MirFailureCleanupForm[ctx], ctx] := ctx[plan.forms];
    mut total_cleanup := 0;
    mut total_destructor := 0;
    mut index := 0;
    while index < len(forms) {
        mut form := forms[index];
        mut line := std.Concat("failure_cleanup: form=", form.form_id);
        line = std.Concat(line, std.Concat(" stage=", form.failure_stage));
        line = std.Concat(line, std.Concat(" terminal=", form.terminal_kind));
        line = std.Concat(line, std.Concat(" stable_authority=", form.stable_authority));
        line = std.Concat(line, std.Concat(" cleanup_policy=", form.cleanup_policy));
        line = std.Concat(line, std.Concat(" final_state=", form.final_state));
        line = std.Concat(line, std.Concat(" cleanup_count=", std.FormatInt(form.cleanup_count)));
        line = std.Concat(line, std.Concat(" destructor_count=", std.FormatInt(form.destructor_count)));
        line = std.Concat(line, std.Concat(" exit_status=", std.FormatInt(form.exit_status)));
        line = std.Concat(line, std.Concat(" output_preserved=", std.Concat(std.FormatInt(form.output_preserved), "\n")));
        output = std.Concat(output, line);
        total_cleanup = total_cleanup + form.cleanup_count;
        total_destructor = total_destructor + form.destructor_count;
        index = index + 1;
    }
    output = std.Concat(output, "failure_cleanup_witness: selected_form_count=4 cleanup_count=");
    output = std.Concat(output, std.FormatInt(total_cleanup));
    output = std.Concat(output, " destructor_count=");
    output = std.Concat(output, std.FormatInt(total_destructor));
    output = std.Concat(output, " exactly_once=1 order=reverse_declaration_inner_before_outer output_preserved=1 generic_authority=1\n");
    return std.Clone(ctx, output);
}
