// Patch 15.7 compiler-owned destructor scheduling and exactly-once destruction.
// Selected synchronous semantics only. Async destruction, finalizers, GC, and
// concurrent cancellation remain deferred.

type MirDestructorScheduleEntry[ctx] struct {
    resource_id: str,
    destructor_id: str,
    execution_destructor_id: str,
    cleanup_reason: str,
    owning_declaration: str,
    source_location: str,
    schedule_operation_id: str,
    cancel_operation_id: str,
    execute_operation_id: str,
    mark_destroyed_operation_id: str,
    schedule_point: str,
    cancel_point: str,
    execution_point: str,
    mark_destroyed_point: str,
    schedule_sequence: int,
    cancel_sequence: int,
    execution_sequence: int,
    mark_destroyed_sequence: int,
    schedule_count: int,
    cancel_count: int,
    execution_count: int,
    execution_order: int,
    ownership_state: str,
    canceled_for_transfer: int,
    observable_effect: str
}

type MirDestructorSchedulingPlan[ctx] struct {
    format: str,
    semantic_authority: str,
    operation_policy: str,
    exactly_once_policy: str,
    deferred_features: str,
    entries: Index[std.Vector[MirDestructorScheduleEntry[ctx], ctx], ctx]
}

type MirDestructorSchedulingValidation[ctx] struct {
    valid: int,
    reason_code: str
}

func mir_destructor_scheduling_empty_entry_vector(ctx: &Arena) Index[std.Vector[MirDestructorScheduleEntry[ctx], ctx], ctx] {
    mut values: std.Vector[MirDestructorScheduleEntry[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirDestructorScheduleEntry[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_destructor_scheduling_make_plan(ctx: &Arena) MirDestructorSchedulingPlan[ctx] {
    mut plan: MirDestructorSchedulingPlan[ctx];
    plan.format = std.Clone(ctx, "gust.compiler_destructor_scheduling.v1");
    plan.semantic_authority = std.Clone(ctx, "compiler_owned_destructor_identity_and_schedule");
    plan.operation_policy = std.Clone(ctx, "schedule_destructor,cancel_obsolete_schedule,execute_destructor,mark_resource_destroyed");
    plan.exactly_once_policy = std.Clone(ctx, "one_live_schedule_one_execution_deterministic_order");
    plan.deferred_features = std.Clone(ctx, "async_destruction,finalizers,gc,concurrent_cancellation");
    plan.entries = mir_destructor_scheduling_empty_entry_vector(ctx);
    return plan;
}

func mir_destructor_scheduling_with_entry(plan: MirDestructorSchedulingPlan[ctx], entry: MirDestructorScheduleEntry[ctx], ctx: &Arena) MirDestructorSchedulingPlan[ctx] {
    mut updated := plan;
    mut values: std.Vector[MirDestructorScheduleEntry[ctx], ctx] := ctx[updated.entries];
    values.Push(entry);
    ctx.Set(updated.entries, values);
    return updated;
}

func mir_destructor_scheduling_entry_count(plan: MirDestructorSchedulingPlan[ctx], ctx: &Arena) int {
    mut values: std.Vector[MirDestructorScheduleEntry[ctx], ctx] := ctx[plan.entries];
    return len(values);
}

func mir_destructor_scheduling_entry_at(plan: MirDestructorSchedulingPlan[ctx], position: int, ctx: &Arena) MirDestructorScheduleEntry[ctx] {
    mut values: std.Vector[MirDestructorScheduleEntry[ctx], ctx] := ctx[plan.entries];
    return values[position];
}

func mir_destructor_scheduling_validation(valid: int, reason: str, ctx: &Arena) MirDestructorSchedulingValidation[ctx] {
    mut result: MirDestructorSchedulingValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason);
    return result;
}

func mir_destructor_scheduling_validate(plan: MirDestructorSchedulingPlan[ctx], ctx: &Arena) MirDestructorSchedulingValidation[ctx] {
    mut entries: std.Vector[MirDestructorScheduleEntry[ctx], ctx] := ctx[plan.entries];
    mut expected_execution_order := 1;
    mut entry_index := 0;
    while entry_index < len(entries) {
        mut entry := entries[entry_index];
        if len(entry.resource_id) == 0 || len(entry.destructor_id) == 0 || len(entry.cleanup_reason) == 0 || len(entry.schedule_operation_id) == 0 || len(entry.schedule_point) == 0 {
            return mir_destructor_scheduling_validation(0, "destructor_schedule_resolution_invalid", ctx);
        }
        if entry.mark_destroyed_sequence > 0 && entry.schedule_sequence >= entry.mark_destroyed_sequence {
            return mir_destructor_scheduling_validation(0, "destructor_schedule_after_destroy", ctx);
        }
        if entry.schedule_count > 1 && std.str_eq(entry.ownership_state, "live") == 1 {
            return mir_destructor_scheduling_validation(0, "destructor_duplicate_live_schedule", ctx);
        }
        if entry.execution_count > 0 && entry.schedule_count == 0 {
            return mir_destructor_scheduling_validation(0, "destructor_execution_without_schedule", ctx);
        }
        if entry.execution_count > 0 && std.str_eq(entry.execution_destructor_id, entry.destructor_id) == 0 {
            return mir_destructor_scheduling_validation(0, "destructor_identity_mismatch", ctx);
        }
        if std.str_eq(entry.ownership_state, "moved") == 1 {
            if entry.execution_count != 0 {
                return mir_destructor_scheduling_validation(0, "destructor_moved_ownership_destroyed", ctx);
            }
            if entry.canceled_for_transfer != 1 || entry.cancel_count != 1 || len(entry.cancel_operation_id) == 0 || len(entry.cancel_point) == 0 {
                return mir_destructor_scheduling_validation(0, "destructor_transfer_schedule_not_canceled", ctx);
            }
            if entry.schedule_count != 1 || entry.cancel_sequence <= entry.schedule_sequence {
                return mir_destructor_scheduling_validation(0, "destructor_transfer_schedule_not_canceled", ctx);
            }
        } else if std.str_eq(entry.ownership_state, "live") == 1 {
            if entry.schedule_count != 1 || entry.execution_count != 1 || len(entry.execute_operation_id) == 0 || len(entry.execution_point) == 0 {
                return mir_destructor_scheduling_validation(0, "destructor_live_resource_skipped", ctx);
            }
            if len(entry.mark_destroyed_operation_id) == 0 || len(entry.mark_destroyed_point) == 0 || entry.mark_destroyed_sequence <= entry.execution_sequence {
                return mir_destructor_scheduling_validation(0, "destructor_mark_destroyed_missing", ctx);
            }
            if entry.execution_sequence <= entry.schedule_sequence {
                return mir_destructor_scheduling_validation(0, "destructor_execution_order_invalid", ctx);
            }
            if entry.execution_order != expected_execution_order {
                return mir_destructor_scheduling_validation(0, "destructor_order_drift", ctx);
            }
            expected_execution_order = expected_execution_order + 1;
        } else {
            return mir_destructor_scheduling_validation(0, "destructor_ownership_state_invalid", ctx);
        }
        entry_index = entry_index + 1;
    }

    mut duplicate_left := 0;
    while duplicate_left < len(entries) {
        mut duplicate_right := duplicate_left + 1;
        while duplicate_right < len(entries) {
            if std.str_eq(entries[duplicate_left].resource_id, entries[duplicate_right].resource_id) == 1 {
                return mir_destructor_scheduling_validation(0, "destructor_duplicate_resource_schedule", ctx);
            }
            duplicate_right = duplicate_right + 1;
        }
        duplicate_left = duplicate_left + 1;
    }
    return mir_destructor_scheduling_validation(1, "destructor_scheduling_valid", ctx);
}

func mir_destructor_scheduling_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(output, std.Concat(key, std.Concat(": ", std.Concat(value, "\n")))));
}

func mir_destructor_scheduling_append_to_request(base: str, plan: MirDestructorSchedulingPlan[ctx], ctx: &Arena) str {
    mut output := std.Clone(ctx, base);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_format", plan.format, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_semantic_authority", plan.semantic_authority, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_operation_policy", plan.operation_policy, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_exactly_once_policy", plan.exactly_once_policy, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_deferred_features", plan.deferred_features, ctx);
    mut entries: std.Vector[MirDestructorScheduleEntry[ctx], ctx] := ctx[plan.entries];
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_entry_count", std.FormatInt(len(entries)), ctx);
    mut entry_index := 0;
    while entry_index < len(entries) {
        mut entry := entries[entry_index];
        mut prefix := std.Clone(ctx, std.Concat("destructor_scheduling_entry_", std.FormatInt(entry_index)));
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_resource_id"), entry.resource_id, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_destructor_id"), entry.destructor_id, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_execution_destructor_id"), entry.execution_destructor_id, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_cleanup_reason"), entry.cleanup_reason, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_owning_declaration"), entry.owning_declaration, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_source_location"), entry.source_location, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_schedule_operation_id"), entry.schedule_operation_id, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_cancel_operation_id"), entry.cancel_operation_id, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_execute_operation_id"), entry.execute_operation_id, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_mark_destroyed_operation_id"), entry.mark_destroyed_operation_id, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_schedule_point"), entry.schedule_point, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_cancel_point"), entry.cancel_point, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_execution_point"), entry.execution_point, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_mark_destroyed_point"), entry.mark_destroyed_point, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_schedule_sequence"), std.FormatInt(entry.schedule_sequence), ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_cancel_sequence"), std.FormatInt(entry.cancel_sequence), ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_execution_sequence"), std.FormatInt(entry.execution_sequence), ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_mark_destroyed_sequence"), std.FormatInt(entry.mark_destroyed_sequence), ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_schedule_count"), std.FormatInt(entry.schedule_count), ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_cancel_count"), std.FormatInt(entry.cancel_count), ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_execution_count"), std.FormatInt(entry.execution_count), ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_execution_order"), std.FormatInt(entry.execution_order), ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_ownership_state"), entry.ownership_state, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_canceled_for_transfer"), std.FormatInt(entry.canceled_for_transfer), ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_observable_effect"), entry.observable_effect, ctx);
        entry_index = entry_index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_destructor_scheduling_witness_line(entry: MirDestructorScheduleEntry[ctx], ctx: &Arena) str {
    mut line := std.Clone(ctx, "destructor_schedule: resource=");
    line = std.Concat(line, entry.resource_id);
    line = std.Concat(line, " destructor=");
    line = std.Concat(line, entry.destructor_id);
    line = std.Concat(line, " reason=");
    line = std.Concat(line, entry.cleanup_reason);
    line = std.Concat(line, " schedule_count=");
    line = std.Concat(line, std.FormatInt(entry.schedule_count));
    line = std.Concat(line, " cancel_count=");
    line = std.Concat(line, std.FormatInt(entry.cancel_count));
    line = std.Concat(line, " execution_count=");
    line = std.Concat(line, std.FormatInt(entry.execution_count));
    line = std.Concat(line, " order=");
    line = std.Concat(line, std.FormatInt(entry.execution_order));
    line = std.Concat(line, " schedule_point=");
    line = std.Concat(line, entry.schedule_point);
    line = std.Concat(line, " execution_point=");
    line = std.Concat(line, entry.execution_point);
    line = std.Concat(line, " effect=");
    line = std.Concat(line, entry.observable_effect);
    line = std.Concat(line, "\n");
    return std.Clone(ctx, line);
}

func mir_destructor_scheduling_mir_to_c_witness(plan: MirDestructorSchedulingPlan[ctx], ctx: &Arena) str {
    mut validation := mir_destructor_scheduling_validate(plan, ctx);
    if validation.valid == 0 {
        return std.Clone(ctx, std.Concat("destructor_scheduling_error: reason=", validation.reason_code));
    }
    mut entries: std.Vector[MirDestructorScheduleEntry[ctx], ctx] := ctx[plan.entries];
    mut output := std.Clone(ctx, "destructor_scheduling_policy: authority=compiler exactly_once=1 operations=schedule_destructor,cancel_obsolete_schedule,execute_destructor,mark_resource_destroyed\n");
    mut scheduled := 0;
    mut canceled := 0;
    mut executed := 0;
    mut entry_index := 0;
    while entry_index < len(entries) {
        mut entry := entries[entry_index];
        output = std.Concat(output, mir_destructor_scheduling_witness_line(entry, ctx));
        scheduled = scheduled + entry.schedule_count;
        canceled = canceled + entry.cancel_count;
        executed = executed + entry.execution_count;
        entry_index = entry_index + 1;
    }
    output = std.Concat(output, "destructor_scheduling_exactly_once_witness: schedule_count=");
    output = std.Concat(output, std.FormatInt(scheduled));
    output = std.Concat(output, " cancel_count=");
    output = std.Concat(output, std.FormatInt(canceled));
    output = std.Concat(output, " execution_count=");
    output = std.Concat(output, std.FormatInt(executed));
    output = std.Concat(output, " order_preserved=1 observable_effects_preserved=1 exactly_once=1\n");
    return std.Clone(ctx, output);
}
