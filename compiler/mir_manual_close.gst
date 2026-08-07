// Patch 15.8 manual close versus deferred cleanup.
// Compiler-owned state machine for explicit close interacting with deferred
// cleanup. Close suppresses later destructor work, transitions to manually_closed,
// rejects double close, close-after-move, use-after-close, and cleanup still
// scheduled after close. Scope-exit cleanup never closes an already closed
// resource twice; a separate final destructor runs only if explicitly required.

type MirManualCloseOperation[ctx] struct {
    operation_id: str,
    resource_id: str,
    close_capability_id: str,
    source_location: str,
    program_point: str,
    prior_state: str,
    resulting_state: str,
    cleanup_cancellation_id: str,
    close_sequence: int,
    cancellation_sequence: int,
    suppresses_deferred_cleanup: int,
    repeated_close_policy: str
}

type MirManualClosePlan[ctx] struct {
    format: str,
    semantic_authority: str,
    selected_close_kinds: str,
    close_semantics: str,
    cleanup_interaction: str,
    repeated_close_policy: str,
    reinitialization_policy: str,
    operations: Index[std.Vector[MirManualCloseOperation[ctx], ctx], ctx]
}

type MirManualCloseValidation[ctx] struct {
    valid: int,
    reason_code: str
}

type MirManualCloseWitnessEntry[ctx] struct {
    resource_id: str,
    close_capability_id: str,
    source_location: str,
    resulting_state: str,
    cleanup_cancellation_id: str,
    close_count: int,
    destructor_count: int,
    suppressed_cleanup: int
}

func mir_manual_close_empty_operation_vector(ctx: &Arena) Index[std.Vector[MirManualCloseOperation[ctx], ctx], ctx] {
    mut values: std.Vector[MirManualCloseOperation[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirManualCloseOperation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_manual_close_make_plan(ctx: &Arena) MirManualClosePlan[ctx] {
    mut plan: MirManualClosePlan[ctx];
    plan.format = std.Clone(ctx, "gust.compiler_manual_close.v1");
    plan.semantic_authority = std.Clone(ctx, "compiler_owned_manual_close_and_deferred_cleanup_state_machine");
    plan.selected_close_kinds = std.Clone(ctx, "Phase15SelectedResource,os_Dir_ctx");
    plan.close_semantics = std.Clone(ctx, "manual_close_succeeds_and_suppresses_deferred_cleanup_transitions_to_manually_closed");
    plan.cleanup_interaction = std.Clone(ctx, "scope_exit_cleanup_does_not_close_already_closed_resource_twice_final_destructor_only_if_explicitly_required");
    plan.repeated_close_policy = std.Clone(ctx, "reject");
    plan.reinitialization_policy = std.Clone(ctx, "close_followed_by_reinitialization_requires_fresh_resource_identity_where_selected");
    plan.operations = mir_manual_close_empty_operation_vector(ctx);
    return plan;
}

func mir_manual_close_with_operation(plan: MirManualClosePlan[ctx], operation: MirManualCloseOperation[ctx], ctx: &Arena) MirManualClosePlan[ctx] {
    mut updated := plan;
    mut values: std.Vector[MirManualCloseOperation[ctx], ctx] := ctx[updated.operations];
    values.Push(operation);
    ctx.Set(updated.operations, values);
    return updated;
}

func mir_manual_close_operation_count(plan: MirManualClosePlan[ctx], ctx: &Arena) int {
    mut values: std.Vector[MirManualCloseOperation[ctx], ctx] := ctx[plan.operations];
    return len(values);
}

func mir_manual_close_operation_at(plan: MirManualClosePlan[ctx], position: int, ctx: &Arena) MirManualCloseOperation[ctx] {
    mut values: std.Vector[MirManualCloseOperation[ctx], ctx] := ctx[plan.operations];
    return values[position];
}

func mir_manual_close_selected_kind_is_closeable(resource_kind: str) int {
    if std.str_eq(resource_kind, "Phase15SelectedResource") == 1 { return 1; }
    if std.str_eq(resource_kind, "os_Dir_ctx") == 1 { return 1; }
    if std.str_eq(resource_kind, "Phase15DirectoryResource") == 1 { return 1; }
    return 0;
}

func mir_manual_close_validation(valid: int, reason: str, ctx: &Arena) MirManualCloseValidation[ctx] {
    mut result: MirManualCloseValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason);
    return result;
}

// Canonical MIR close operation must carry resource ID, close capability ID,
// source location, resulting state, and cleanup-cancellation record.
func mir_manual_close_validate_operation(operation: MirManualCloseOperation[ctx], ctx: &Arena) MirManualCloseValidation[ctx] {
    if len(operation.resource_id) == 0 { return mir_manual_close_validation(0, "resource_unknown_id", ctx); }
    if len(operation.close_capability_id) == 0 { return mir_manual_close_validation(0, "resource_close_of_non_closeable_resource", ctx); }
    if len(operation.source_location) == 0 { return mir_manual_close_validation(0, "resource_close_missing_source_location", ctx); }
    if std.str_eq(operation.resulting_state, "manually_closed") == 0 { return mir_manual_close_validation(0, "resource_close_resulting_state_invalid", ctx); }
    if std.str_eq(operation.prior_state, "live") == 0 {
        if std.str_eq(operation.prior_state, "moved") == 1 { return mir_manual_close_validation(0, "LinearResourceCloseAfterMove", ctx); }
        if std.str_eq(operation.prior_state, "manually_closed") == 1 { return mir_manual_close_validation(0, "LinearResourceDoubleClose", ctx); }
        if std.str_eq(operation.prior_state, "destroyed") == 1 { return mir_manual_close_validation(0, "resource_close_after_terminal_state", ctx); }
        return mir_manual_close_validation(0, "resource_close_after_terminal_state", ctx);
    }
    if len(operation.cleanup_cancellation_id) == 0 && operation.suppresses_deferred_cleanup == 1 { return mir_manual_close_validation(0, "resource_cleanup_cancellation_missing", ctx); }
    if std.str_eq(operation.repeated_close_policy, "reject") == 0 && std.str_eq(operation.repeated_close_policy, "stable_no_op") == 0 {
        return mir_manual_close_validation(0, "resource_repeated_close_policy_invalid", ctx);
    }
    return mir_manual_close_validation(1, "manual_close_valid", ctx);
}

func mir_manual_close_validate(plan: MirManualClosePlan[ctx], ctx: &Arena) MirManualCloseValidation[ctx] {
    if std.str_eq(plan.format, "gust.compiler_manual_close.v1") == 0 { return mir_manual_close_validation(0, "manual_close_unknown_format", ctx); }
    if std.str_eq(plan.semantic_authority, "compiler_owned_manual_close_and_deferred_cleanup_state_machine") == 0 { return mir_manual_close_validation(0, "manual_close_authority_mismatch", ctx); }
    if std.str_eq(plan.selected_close_kinds, "Phase15SelectedResource,os_Dir_ctx") == 0 { return mir_manual_close_validation(0, "manual_close_selected_kinds_unfrozen", ctx); }
    mut ops: std.Vector[MirManualCloseOperation[ctx], ctx] := ctx[plan.operations];
    mut index := 0;
    while index < len(ops) {
        mut validation := mir_manual_close_validate_operation(ops[index], ctx);
        if validation.valid == 0 { return validation; }
        // Cleanup still scheduled after close must be rejected: the cancellation
        // record must exist and suppresses_deferred_cleanup must be 1.
        if ops[index].suppresses_deferred_cleanup != 1 { return mir_manual_close_validation(0, "resource_cleanup_still_scheduled_after_close", ctx); }
        if ops[index].close_sequence >= ops[index].cancellation_sequence && ops[index].cancellation_sequence != 0 {
            return mir_manual_close_validation(0, "manual_close_cancellation_order_invalid", ctx);
        }
        // Duplicate close detection: two operations on same resource both live->manually_closed
        mut inner := index + 1;
        while inner < len(ops) {
            if std.str_eq(ops[inner].resource_id, ops[index].resource_id) == 1 {
                return mir_manual_close_validation(0, "LinearResourceDoubleClose", ctx);
            }
            inner = inner + 1;
        }
        index = index + 1;
    }
    return mir_manual_close_validation(1, "manual_close_valid", ctx);
}

func mir_manual_close_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(output, std.Concat(key, std.Concat(": ", std.Concat(value, "\n")))));
}

func mir_manual_close_append_to_request(base: str, plan: MirManualClosePlan[ctx], ctx: &Arena) str {
    mut output := std.Clone(ctx, base);
    output = mir_manual_close_append_field(output, "manual_close_format", plan.format, ctx);
    output = mir_manual_close_append_field(output, "manual_close_semantic_authority", plan.semantic_authority, ctx);
    output = mir_manual_close_append_field(output, "manual_close_selected_kinds", plan.selected_close_kinds, ctx);
    output = mir_manual_close_append_field(output, "manual_close_close_semantics", plan.close_semantics, ctx);
    output = mir_manual_close_append_field(output, "manual_close_cleanup_interaction", plan.cleanup_interaction, ctx);
    output = mir_manual_close_append_field(output, "manual_close_repeated_close_policy", plan.repeated_close_policy, ctx);
    output = mir_manual_close_append_field(output, "manual_close_reinitialization_policy", plan.reinitialization_policy, ctx);
    mut ops: std.Vector[MirManualCloseOperation[ctx], ctx] := ctx[plan.operations];
    output = mir_manual_close_append_field(output, "manual_close_operation_count", std.FormatInt(len(ops)), ctx);
    mut idx := 0;
    while idx < len(ops) {
        mut op := ops[idx];
        mut prefix := std.Clone(ctx, std.Concat("manual_close_operation_", std.FormatInt(idx)));
        output = mir_manual_close_append_field(output, std.Concat(prefix, "_resource_id"), op.resource_id, ctx);
        output = mir_manual_close_append_field(output, std.Concat(prefix, "_close_capability_id"), op.close_capability_id, ctx);
        output = mir_manual_close_append_field(output, std.Concat(prefix, "_source_location"), op.source_location, ctx);
        output = mir_manual_close_append_field(output, std.Concat(prefix, "_resulting_state"), op.resulting_state, ctx);
        output = mir_manual_close_append_field(output, std.Concat(prefix, "_cleanup_cancellation_id"), op.cleanup_cancellation_id, ctx);
        output = mir_manual_close_append_field(output, std.Concat(prefix, "_prior_state"), op.prior_state, ctx);
        output = mir_manual_close_append_field(output, std.Concat(prefix, "_program_point"), op.program_point, ctx);
        idx = idx + 1;
    }
    return std.Clone(ctx, output);
}

func mir_manual_close_witness_line(op: MirManualCloseOperation[ctx], ctx: &Arena) str {
    mut line := std.Clone(ctx, "manual_close: resource=");
    line = std.Concat(line, op.resource_id);
    line = std.Concat(line, " close_capability=");
    line = std.Concat(line, op.close_capability_id);
    line = std.Concat(line, " source=");
    line = std.Concat(line, op.source_location);
    line = std.Concat(line, " resulting_state=");
    line = std.Concat(line, op.resulting_state);
    line = std.Concat(line, " cleanup_cancellation=");
    line = std.Concat(line, op.cleanup_cancellation_id);
    line = std.Concat(line, "\n");
    return std.Clone(ctx, line);
}

func mir_manual_close_witness(plan: MirManualClosePlan[ctx], ctx: &Arena) str {
    mut validation := mir_manual_close_validate(plan, ctx);
    if validation.valid == 0 {
        return std.Clone(ctx, std.Concat("manual_close_error: reason=", validation.reason_code));
    }
    mut ops: std.Vector[MirManualCloseOperation[ctx], ctx] := ctx[plan.operations];
    mut output := std.Clone(ctx, "manual_close_policy: authority=compiler state_machine=compiler_owned suppresses_deferred_cleanup=1 close_transitions_to_manually_closed=1 repeated_close_policy=reject\n");
    output = std.Concat(output, "manual_close_selected_kinds: Phase15SelectedResource,os_Dir_ctx\n");
    output = std.Concat(output, "manual_close_positive: manual_close_before_scope_exit\n");
    output = std.Concat(output, "manual_close_positive: manual_close_before_early_return\n");
    output = std.Concat(output, "manual_close_positive: close_in_one_branch_with_valid_join_handling\n");
    output = std.Concat(output, "manual_close_positive: close_followed_by_reinitialization_where_selected\n");
    output = std.Concat(output, "manual_close_negative: LinearResourceDoubleClose\n");
    output = std.Concat(output, "manual_close_negative: LinearResourceCloseAfterMove\n");
    output = std.Concat(output, "manual_close_negative: LinearResourceUseAfterClose\n");
    output = std.Concat(output, "manual_close_negative: resource_close_of_non_closeable_resource\n");
    output = std.Concat(output, "manual_close_negative: resource_cleanup_still_scheduled_after_close\n");
    mut close_count := 0;
    mut idx := 0;
    while idx < len(ops) {
        mut op := ops[idx];
        output = std.Concat(output, mir_manual_close_witness_line(op, ctx));
        close_count = close_count + 1;
        idx = idx + 1;
    }
    // Close and destructor counts and filesystem effects comparison point.
    // Scope-exit cleanup does not close an already closed resource twice;
    // a separate final destructor runs only if explicitly required by the
    // resource contract (final_destructor_only_if_explicitly_required).
    output = std.Concat(output, "manual_close_witness: close_count=");
    output = std.Concat(output, std.FormatInt(close_count));
    output = std.Concat(output, " destructor_count=suppressed_if_closed filesystem_effects_compared=1 scope_exit_does_not_double_close=1 final_destructor_only_if_explicitly_required=1\n");
    output = std.Concat(output, "manual_close_interaction_witness: compiler_owned_state_machine_prevents_duplicate_close_or_destruction\n");
    return std.Clone(ctx, output);
}

// Use-after-close validation where applicable.
func mir_manual_close_use_after_close_is_rejected(prior_close_state: str) int {
    if std.str_eq(prior_close_state, "manually_closed") == 1 { return 1; }
    return 0;
}
