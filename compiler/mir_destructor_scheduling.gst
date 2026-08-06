// Phase 15.7 compiler-owned destructor scheduling and exactly-once destruction
// authority.
//
// The compiler owns every destructor identity, every scheduling point, every
// cleanup reason, and the destruction order. Selected resources carry one
// compiler-owned schedule and one execution: schedule destructor, cancel an
// obsolete schedule after ownership transfer, execute destructor, and mark the
// resource destroyed. Two live schedules for one resource, execution without a
// schedule, scheduling after destruction, destructor mismatch, skipped
// destruction of a live resource, destruction of moved ownership, and
// destruction-order drift are rejected before any backend discovery.
// Asynchronous destruction, finalizers, garbage collection, and concurrent
// cancellation remain deferred.

import "mir_layout.gst" as layout;

type MirScheduledResource[ctx] struct {
    resource_id: str,
    resource_type_id: str,
    destructor_id: str,
    cleanup_reason: str,
    execution_point: str,
    destruction_order: int,
    lifetime_region: str
}

type MirDestructorSchedulingOperation[ctx] struct {
    operation_id: str,
    operation_name: str,
    target_id: str,
    kind: str,
    resource_id: str,
    destructor_id: str,
    cleanup_reason: str,
    execution_point: str,
    expect_success: int,
    expected_state: str,
    expected_schedule_count: int,
    expected_execution_count: int,
    expected_order: int,
    expected_reason_code: str
}

type MirDestructorSchedulingTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    schedule_authority: str,
    duplicate_policy: str,
    execution_policy: str,
    move_policy: str,
    order_policy: str,
    async_destruction_policy: str,
    finalizer_policy: str,
    gc_policy: str,
    cancellation_policy: str,
    resources: Index[std.Vector[MirScheduledResource[ctx], ctx], ctx],
    operations: Index[std.Vector[MirDestructorSchedulingOperation[ctx], ctx], ctx]
}

type MirDestructorSchedulingResourceQuery[ctx] struct {
    found: int,
    resource: MirScheduledResource[ctx]
}

type MirDestructorSchedulingOperationQuery[ctx] struct {
    found: int,
    operation: MirDestructorSchedulingOperation[ctx]
}

type MirDestructorSchedulingState[ctx] struct {
    resource_id: str,
    state: str,
    schedule_count: int,
    execution_count: int,
    destruction_order: int
}

type MirDestructorSchedulingEvaluation[ctx] struct {
    success: int,
    state: str,
    schedule_count: int,
    execution_count: int,
    destruction_order: int,
    reason_code: str
}

func mir_destructor_scheduling_empty_resource_vector(ctx: &Arena) Index[std.Vector[MirScheduledResource[ctx], ctx], ctx] {
    mut values: std.Vector[MirScheduledResource[ctx], ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[MirScheduledResource[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_destructor_scheduling_empty_operation_vector(ctx: &Arena) Index[std.Vector[MirDestructorSchedulingOperation[ctx], ctx], ctx] {
    mut values: std.Vector[MirDestructorSchedulingOperation[ctx], ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[MirDestructorSchedulingOperation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_destructor_scheduling_make_empty_table(target_triple: str, ctx: &Arena) MirDestructorSchedulingTable[ctx] {
    mut table: MirDestructorSchedulingTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_destructor_scheduling_table.v1");
    table.target_id = std.Clone(ctx, "");
    table.target_triple = std.Clone(ctx, target_triple);
    table.schedule_authority = std.Clone(ctx, "compiler_owned_destructor_scheduling_no_backend_decision");
    table.duplicate_policy = std.Clone(ctx, "reject_two_live_schedules_for_one_resource");
    table.execution_policy = std.Clone(ctx, "execute_only_with_compiler_schedule");
    table.move_policy = std.Clone(ctx, "cancel_obsolete_schedule_after_ownership_transfer");
    table.order_policy = std.Clone(ctx, "compiler_owned_destruction_order");
    table.async_destruction_policy = std.Clone(ctx, "deferred_asynchronous_destruction");
    table.finalizer_policy = std.Clone(ctx, "deferred_finalizers");
    table.gc_policy = std.Clone(ctx, "deferred_garbage_collection");
    table.cancellation_policy = std.Clone(ctx, "deferred_concurrent_cancellation");
    table.resources = mir_destructor_scheduling_empty_resource_vector(ctx);
    table.operations = mir_destructor_scheduling_empty_operation_vector(ctx);
    return table;
}

func mir_destructor_scheduling_table_is_legacy_empty(table: MirDestructorSchedulingTable[ctx], ctx: &Arena) int {
    mut resources: std.Vector[MirScheduledResource[ctx], ctx] := ctx[table.resources];
    mut operations: std.Vector[MirDestructorSchedulingOperation[ctx], ctx] := ctx[table.operations];
    if len(table.target_id) == 0 &&
       len(resources) == 0 && len(operations) == 0
    {
        return 1;
    }
    return 0;
}

func mir_destructor_scheduling_field_is_safe(value: str, allow_empty: int) int {
    if allow_empty == 0 && len(value) == 0 { return 0; }
    if std.str_find(value, "\n") != 0 - 1 { return 0; }
    if std.str_find(value, "\r") != 0 - 1 { return 0; }
    return 1;
}

func mir_destructor_scheduling_operation_kind_is_valid(kind: str) int {
    if std.str_eq(kind, "schedule_destructor") == 1 { return 1; }
    if std.str_eq(kind, "cancel_schedule") == 1 { return 1; }
    if std.str_eq(kind, "execute_destructor") == 1 { return 1; }
    if std.str_eq(kind, "mark_destroyed") == 1 { return 1; }
    return 0;
}

func mir_destructor_scheduling_state_is_valid(state: str) int {
    if std.str_eq(state, "unscheduled") == 1 { return 1; }
    if std.str_eq(state, "scheduled") == 1 { return 1; }
    if std.str_eq(state, "cancelled") == 1 { return 1; }
    if std.str_eq(state, "executed") == 1 { return 1; }
    if std.str_eq(state, "destroyed") == 1 { return 1; }
    return 0;
}

func mir_destructor_scheduling_resource_identity(target_id: str, resource_id: str, destructor_id: str, cleanup_reason: str, execution_point: str, destruction_order: int, ctx: &Arena) str {
    mut identity := "destructor_resource:v1:target=";
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":resource=");
    identity = std.Concat(identity, resource_id);
    identity = std.Concat(identity, ":destructor=");
    identity = std.Concat(identity, destructor_id);
    identity = std.Concat(identity, ":reason=");
    identity = std.Concat(identity, cleanup_reason);
    identity = std.Concat(identity, ":point=");
    identity = std.Concat(identity, execution_point);
    identity = std.Concat(identity, ":order=");
    identity = std.Concat(identity, std.FormatInt(destruction_order));
    return std.Clone(ctx, identity);
}

func mir_destructor_scheduling_operation_identity(target_id: str, operation_name: str, kind: str, ctx: &Arena) str {
    mut identity := "destructor_scheduling_operation:v1:target=";
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":name=");
    identity = std.Concat(identity, operation_name);
    identity = std.Concat(identity, ":kind=");
    identity = std.Concat(identity, kind);
    return std.Clone(ctx, identity);
}

func mir_destructor_scheduling_make_resource(target_id: str, resource_id: str, resource_type_id: str, destructor_id: str, cleanup_reason: str, execution_point: str, destruction_order: int, lifetime_region: str, ctx: &Arena) MirScheduledResource[ctx] {
    mut result: MirScheduledResource[ctx];
    result.resource_id = std.Clone(ctx, resource_id);
    result.resource_type_id = std.Clone(ctx, resource_type_id);
    result.destructor_id = std.Clone(ctx, destructor_id);
    result.cleanup_reason = std.Clone(ctx, cleanup_reason);
    result.execution_point = std.Clone(ctx, execution_point);
    result.destruction_order = destruction_order;
    result.lifetime_region = std.Clone(ctx, lifetime_region);
    // The resource identity is compiler-owned; the target is part of the
    // canonical identity so no backend can reinterpret the resource.
    return result;
}

func mir_destructor_scheduling_make_operation(table: MirDestructorSchedulingTable[ctx], operation_name: str, kind: str, resource_id: str, destructor_id: str, cleanup_reason: str, execution_point: str, expected_state: str, expected_schedule_count: int, expected_execution_count: int, expected_order: int, ctx: &Arena) MirDestructorSchedulingOperation[ctx] {
    mut result: MirDestructorSchedulingOperation[ctx];
    result.operation_name = std.Clone(ctx, operation_name);
    result.target_id = std.Clone(ctx, table.target_id);
    result.kind = std.Clone(ctx, kind);
    result.resource_id = std.Clone(ctx, resource_id);
    result.destructor_id = std.Clone(ctx, destructor_id);
    result.cleanup_reason = std.Clone(ctx, cleanup_reason);
    result.execution_point = std.Clone(ctx, execution_point);
    result.expect_success = 1;
    result.expected_state = std.Clone(ctx, expected_state);
    result.expected_schedule_count = expected_schedule_count;
    result.expected_execution_count = expected_execution_count;
    result.expected_order = expected_order;
    result.expected_reason_code = std.Clone(ctx, "destructor_scheduling_valid");
    result.operation_id = mir_destructor_scheduling_operation_identity(
        result.target_id,
        result.operation_name,
        result.kind,
        ctx
    );
    return result;
}

func mir_destructor_scheduling_table_with_resource(table: MirDestructorSchedulingTable[ctx], value: MirScheduledResource[ctx], ctx: &Arena) MirDestructorSchedulingTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirScheduledResource[ctx], ctx] := ctx[updated.resources];
    values.Push(value);
    ctx.Set(updated.resources, values);
    return updated;
}

func mir_destructor_scheduling_table_with_operation(table: MirDestructorSchedulingTable[ctx], value: MirDestructorSchedulingOperation[ctx], ctx: &Arena) MirDestructorSchedulingTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirDestructorSchedulingOperation[ctx], ctx] := ctx[updated.operations];
    values.Push(value);
    ctx.Set(updated.operations, values);
    return updated;
}

func mir_destructor_scheduling_resource(table: MirDestructorSchedulingTable[ctx], resource_id: str, ctx: &Arena) MirDestructorSchedulingResourceQuery[ctx] {
    mut result: MirDestructorSchedulingResourceQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirScheduledResource[ctx], ctx] := ctx[table.resources];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].resource_id, resource_id) == 1 {
            result.found = 1;
            result.resource = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_destructor_scheduling_operation(table: MirDestructorSchedulingTable[ctx], operation_name: str, ctx: &Arena) MirDestructorSchedulingOperationQuery[ctx] {
    mut result: MirDestructorSchedulingOperationQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirDestructorSchedulingOperation[ctx], ctx] := ctx[table.operations];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].operation_name, operation_name) == 1 {
            result.found = 1;
            result.operation = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_destructor_scheduling_evaluation(success: int, state: str, schedule_count: int, execution_count: int, destruction_order: int, reason_code: str, ctx: &Arena) MirDestructorSchedulingEvaluation[ctx] {
    mut result: MirDestructorSchedulingEvaluation[ctx];
    result.success = success;
    result.state = std.Clone(ctx, state);
    result.schedule_count = schedule_count;
    result.execution_count = execution_count;
    result.destruction_order = destruction_order;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_destructor_scheduling_rejection(kind: str, ctx: &Arena) MirDestructorSchedulingEvaluation[ctx] {
    if std.str_eq(kind, "duplicate_schedule") == 1 {
        return mir_destructor_scheduling_evaluation(0, "unscheduled", 0, 0, 0, "duplicate_schedule", ctx);
    }
    if std.str_eq(kind, "execute_without_schedule") == 1 {
        return mir_destructor_scheduling_evaluation(0, "unscheduled", 0, 0, 0, "execute_without_schedule", ctx);
    }
    if std.str_eq(kind, "schedule_after_destruction") == 1 {
        return mir_destructor_scheduling_evaluation(0, "unscheduled", 0, 0, 0, "schedule_after_destruction", ctx);
    }
    if std.str_eq(kind, "destructor_mismatch") == 1 {
        return mir_destructor_scheduling_evaluation(0, "unscheduled", 0, 0, 0, "destructor_mismatch", ctx);
    }
    if std.str_eq(kind, "skipped_destruction") == 1 {
        return mir_destructor_scheduling_evaluation(0, "unscheduled", 0, 0, 0, "skipped_destruction", ctx);
    }
    if std.str_eq(kind, "destruction_after_move") == 1 {
        return mir_destructor_scheduling_evaluation(0, "unscheduled", 0, 0, 0, "destruction_after_move", ctx);
    }
    if std.str_eq(kind, "destruction_order_drift") == 1 {
        return mir_destructor_scheduling_evaluation(0, "unscheduled", 0, 0, 0, "destruction_order_drift", ctx);
    }
    if std.str_eq(kind, "cancel_without_schedule") == 1 {
        return mir_destructor_scheduling_evaluation(0, "unscheduled", 0, 0, 0, "cancel_without_schedule", ctx);
    }
    return mir_destructor_scheduling_evaluation(0, "unscheduled", 0, 0, 0, "destructor_scheduling_request_invalid", ctx);
}

func mir_destructor_scheduling_evaluate(table: MirDestructorSchedulingTable[ctx], operation: MirDestructorSchedulingOperation[ctx], current: MirDestructorSchedulingState[ctx], next_order: int, ctx: &Arena) MirDestructorSchedulingEvaluation[ctx] {
    if std.str_eq(operation.kind, "schedule_destructor") == 1 {
        if std.str_eq(current.state, "unscheduled") == 1 || std.str_eq(current.state, "cancelled") == 1 {
            return mir_destructor_scheduling_evaluation(
                1,
                "scheduled",
                current.schedule_count + 1,
                current.execution_count,
                0,
                "destructor_scheduling_valid",
                ctx
            );
        }
        if std.str_eq(current.state, "scheduled") == 1 {
            return mir_destructor_scheduling_rejection("duplicate_schedule", ctx);
        }
        return mir_destructor_scheduling_rejection("schedule_after_destruction", ctx);
    }
    if std.str_eq(operation.kind, "cancel_schedule") == 1 {
        if std.str_eq(current.state, "scheduled") == 1 {
            mut cancelled_count := current.schedule_count - 1;
            if cancelled_count < 0 { cancelled_count = 0; }
            return mir_destructor_scheduling_evaluation(
                1,
                "cancelled",
                cancelled_count,
                current.execution_count,
                0,
                "destructor_scheduling_valid",
                ctx
            );
        }
        return mir_destructor_scheduling_rejection("cancel_without_schedule", ctx);
    }
    if std.str_eq(operation.kind, "execute_destructor") == 1 {
        // Cancelled schedules are the ownership-transfer record: executing a
        // destructor on a transferred resource destroys moved ownership.
        if std.str_eq(current.state, "cancelled") == 1 {
            return mir_destructor_scheduling_rejection("destruction_after_move", ctx);
        }
        if std.str_eq(current.state, "scheduled") == 0 {
            return mir_destructor_scheduling_rejection("execute_without_schedule", ctx);
        }
        mut resource_query := mir_destructor_scheduling_resource(table, operation.resource_id, ctx);
        if resource_query.found == 0 {
            return mir_destructor_scheduling_rejection("destructor_scheduling_request_invalid", ctx);
        }
        if std.str_eq(operation.destructor_id, resource_query.resource.destructor_id) == 0 {
            return mir_destructor_scheduling_rejection("destructor_mismatch", ctx);
        }
        return mir_destructor_scheduling_evaluation(
            1,
            "executed",
            current.schedule_count,
            current.execution_count + 1,
            next_order,
            "destructor_scheduling_valid",
            ctx
        );
    }
    if std.str_eq(operation.kind, "mark_destroyed") == 1 {
        if std.str_eq(current.state, "cancelled") == 1 {
            return mir_destructor_scheduling_rejection("destruction_after_move", ctx);
        }
        if std.str_eq(current.state, "executed") == 1 {
            return mir_destructor_scheduling_evaluation(
                1,
                "destroyed",
                current.schedule_count,
                current.execution_count,
                current.destruction_order,
                "destructor_scheduling_valid",
                ctx
            );
        }
        if std.str_eq(current.state, "destroyed") == 1 {
            return mir_destructor_scheduling_rejection("destructor_scheduling_request_invalid", ctx);
        }
        return mir_destructor_scheduling_rejection("skipped_destruction", ctx);
    }
    return mir_destructor_scheduling_evaluation(0, "unscheduled", 0, 0, 0, "destructor_scheduling_operation_unsupported", ctx);
}

func mir_destructor_scheduling_empty_state_vector(ctx: &Arena) Index[std.Vector[MirDestructorSchedulingState[ctx], ctx], ctx] {
    mut values: std.Vector[MirDestructorSchedulingState[ctx], ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[MirDestructorSchedulingState[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_destructor_scheduling_state_vector_for_table(table: MirDestructorSchedulingTable[ctx], ctx: &Arena) Index[std.Vector[MirDestructorSchedulingState[ctx], ctx], ctx] {
    mut states_idx := mir_destructor_scheduling_empty_state_vector(ctx);
    mut states: std.Vector[MirDestructorSchedulingState[ctx], ctx] := ctx[states_idx];
    mut resources: std.Vector[MirScheduledResource[ctx], ctx] := ctx[table.resources];
    mut index := 0;
    while index < len(resources) {
        mut state: MirDestructorSchedulingState[ctx];
        state.resource_id = std.Clone(ctx, resources[index].resource_id);
        state.state = std.Clone(ctx, "unscheduled");
        state.schedule_count = 0;
        state.execution_count = 0;
        state.destruction_order = 0;
        states.Push(state);
        index = index + 1;
    }
    ctx.Set(states_idx, states);
    return states_idx;
}

func mir_destructor_scheduling_state_index(states_idx: Index[std.Vector[MirDestructorSchedulingState[ctx], ctx], ctx], resource_id: str, ctx: &Arena) int {
    mut states: std.Vector[MirDestructorSchedulingState[ctx], ctx] := ctx[states_idx];
    mut index := 0;
    while index < len(states) {
        if std.str_eq(states[index].resource_id, resource_id) == 1 { return index; }
        index = index + 1;
    }
    return 0 - 1;
}

func mir_destructor_scheduling_state_vector_with_updated(states_idx: Index[std.Vector[MirDestructorSchedulingState[ctx], ctx], ctx], state_position: int, updated: MirDestructorSchedulingState[ctx], ctx: &Arena) Index[std.Vector[MirDestructorSchedulingState[ctx], ctx], ctx] {
    mut previous: std.Vector[MirDestructorSchedulingState[ctx], ctx] := ctx[states_idx];
    mut rebuilt_idx := mir_destructor_scheduling_empty_state_vector(ctx);
    mut rebuilt: std.Vector[MirDestructorSchedulingState[ctx], ctx] := ctx[rebuilt_idx];
    mut index := 0;
    while index < len(previous) {
        if index == state_position {
            rebuilt.Push(updated);
        } else {
            rebuilt.Push(previous[index]);
        }
        index = index + 1;
    }
    ctx.Set(rebuilt_idx, rebuilt);
    return rebuilt_idx;
}

func mir_destructor_scheduling_exactly_once_is_satisfied(table: MirDestructorSchedulingTable[ctx], states_idx: Index[std.Vector[MirDestructorSchedulingState[ctx], ctx], ctx], ctx: &Arena) int {
    mut states: std.Vector[MirDestructorSchedulingState[ctx], ctx] := ctx[states_idx];
    mut resources: std.Vector[MirScheduledResource[ctx], ctx] := ctx[table.resources];
    if len(states) != len(resources) { return 0; }
    mut index := 0;
    while index < len(states) {
        if std.str_eq(states[index].state, "destroyed") == 0 ||
           states[index].schedule_count != 1 ||
           states[index].execution_count != 1 ||
           states[index].destruction_order != resources[index].destruction_order
        {
            return 0;
        }
        index = index + 1;
    }
    return 1;
}

func mir_destructor_scheduling_table_is_valid(table: MirDestructorSchedulingTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if std.str_eq(table.format, "gust.compiler_destructor_scheduling_table.v1") == 0 { return 0; }
    if mir_destructor_scheduling_table_is_legacy_empty(table, ctx) == 1 { return 1; }
    if std.str_eq(table.target_id, layout_table.target.target_id) == 0 ||
       std.str_eq(table.target_triple, layout_table.target.target_triple) == 0 ||
       std.str_eq(table.schedule_authority, "compiler_owned_destructor_scheduling_no_backend_decision") == 0 ||
       std.str_eq(table.duplicate_policy, "reject_two_live_schedules_for_one_resource") == 0 ||
       std.str_eq(table.execution_policy, "execute_only_with_compiler_schedule") == 0 ||
       std.str_eq(table.move_policy, "cancel_obsolete_schedule_after_ownership_transfer") == 0 ||
       std.str_eq(table.order_policy, "compiler_owned_destruction_order") == 0 ||
       std.str_eq(table.async_destruction_policy, "deferred_asynchronous_destruction") == 0 ||
       std.str_eq(table.finalizer_policy, "deferred_finalizers") == 0 ||
       std.str_eq(table.gc_policy, "deferred_garbage_collection") == 0 ||
       std.str_eq(table.cancellation_policy, "deferred_concurrent_cancellation") == 0
    {
        return 0;
    }

    mut resources: std.Vector[MirScheduledResource[ctx], ctx] := ctx[table.resources];
    mut operations: std.Vector[MirDestructorSchedulingOperation[ctx], ctx] := ctx[table.operations];
    if len(resources) != 4 || len(operations) != 14 {
        return 0;
    }

    mut resource_index := 0;
    while resource_index < len(resources) {
        mut value := resources[resource_index];
        if mir_destructor_scheduling_field_is_safe(value.resource_id, 0) == 0 ||
           mir_destructor_scheduling_field_is_safe(value.resource_type_id, 0) == 0 ||
           mir_destructor_scheduling_field_is_safe(value.destructor_id, 0) == 0 ||
           mir_destructor_scheduling_field_is_safe(value.cleanup_reason, 0) == 0 ||
           mir_destructor_scheduling_field_is_safe(value.execution_point, 0) == 0 ||
           mir_destructor_scheduling_field_is_safe(value.lifetime_region, 0) == 0 ||
           value.destruction_order < 1 || value.destruction_order > 4
        {
            return 0;
        }
        resource_index = resource_index + 1;
    }

    // One destructor identity per resource: resource ID, destructor ID, cleanup
    // reason, execution point, and declared order must all be unambiguous.
    resource_index = 0;
    while resource_index < len(resources) {
        mut value := resources[resource_index];
        mut probe_index := 0;
        while probe_index < len(resources) {
            if probe_index != resource_index &&
               std.str_eq(resources[probe_index].resource_id, value.resource_id) == 1
            {
                return 0;
            }
            probe_index = probe_index + 1;
        }
        resource_index = resource_index + 1;
    }

    mut states_idx := mir_destructor_scheduling_state_vector_for_table(table, ctx);
    mut next_order := 1;
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        if mir_destructor_scheduling_operation_kind_is_valid(operation.kind) == 0 ||
           std.str_eq(operation.target_id, table.target_id) == 0 ||
           operation.expect_success != 1 ||
           std.str_eq(operation.expected_reason_code, "destructor_scheduling_valid") == 0 ||
           mir_destructor_scheduling_state_is_valid(operation.expected_state) == 0
        {
            return 0;
        }
        mut expected_id := mir_destructor_scheduling_operation_identity(
            operation.target_id,
            operation.operation_name,
            operation.kind,
            ctx
        );
        if std.str_eq(operation.operation_id, expected_id) == 0 { return 0; }
        mut resource_query := mir_destructor_scheduling_resource(table, operation.resource_id, ctx);
        if resource_query.found == 0 { return 0; }
        if std.str_eq(operation.destructor_id, resource_query.resource.destructor_id) == 0 ||
           std.str_eq(operation.cleanup_reason, resource_query.resource.cleanup_reason) == 0 ||
           std.str_eq(operation.execution_point, resource_query.resource.execution_point) == 0
        {
            return 0;
        }
        if std.str_eq(operation.kind, "execute_destructor") == 1 ||
           std.str_eq(operation.kind, "mark_destroyed") == 1
        {
            if operation.expected_order != resource_query.resource.destruction_order {
                return 0;
            }
        } else if operation.expected_order != 0 {
            return 0;
        }
        mut state_position := mir_destructor_scheduling_state_index(states_idx, operation.resource_id, ctx);
        if state_position < 0 { return 0; }
        mut states: std.Vector[MirDestructorSchedulingState[ctx], ctx] := ctx[states_idx];
        mut current := states[state_position];
        mut evaluation := mir_destructor_scheduling_evaluate(table, operation, current, next_order, ctx);
        if evaluation.success != operation.expect_success ||
           std.str_eq(evaluation.state, operation.expected_state) == 0 ||
           evaluation.schedule_count != operation.expected_schedule_count ||
           evaluation.execution_count != operation.expected_execution_count ||
           evaluation.destruction_order != operation.expected_order ||
           std.str_eq(evaluation.reason_code, operation.expected_reason_code) == 0
        {
            return 0;
        }
        if std.str_eq(operation.kind, "execute_destructor") == 1 {
            next_order = next_order + 1;
        }
        current.state = std.Clone(ctx, evaluation.state);
        current.schedule_count = evaluation.schedule_count;
        current.execution_count = evaluation.execution_count;
        current.destruction_order = evaluation.destruction_order;
        states_idx = mir_destructor_scheduling_state_vector_with_updated(states_idx, state_position, current, ctx);
        operation_index = operation_index + 1;
    }
    if mir_destructor_scheduling_exactly_once_is_satisfied(table, states_idx, ctx) == 0 {
        return 0;
    }
    return 1;
}

func mir_destructor_scheduling_table_for_layout(layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) MirDestructorSchedulingTable[ctx] {
    mut table := mir_destructor_scheduling_make_empty_table(layout_table.target.target_triple, ctx);
    table.target_id = std.Clone(ctx, layout_table.target.target_id);

    mut log_resource := mir_destructor_scheduling_make_resource(
        table.target_id, "resource_log_handle", "type:gust:resource:log_handle",
        "destructor_close_log", "release_os_handle", "scope_exit_main", 1, "function:main", ctx
    );
    mut config_resource := mir_destructor_scheduling_make_resource(
        table.target_id, "resource_config_buffer", "type:gust:resource:config_buffer",
        "destructor_free_config", "release_arena_buffer", "scope_exit_main", 2, "function:main", ctx
    );
    mut net_resource := mir_destructor_scheduling_make_resource(
        table.target_id, "resource_net_connection", "type:gust:resource:net_connection",
        "destructor_disconnect_net", "close_network_session", "scope_exit_main", 3, "function:main", ctx
    );
    mut scratch_resource := mir_destructor_scheduling_make_resource(
        table.target_id, "resource_temp_scratch", "type:gust:resource:temp_scratch",
        "destructor_release_scratch", "release_stack_buffer", "scope_exit_main", 4, "function:main", ctx
    );
    table = mir_destructor_scheduling_table_with_resource(table, log_resource, ctx);
    table = mir_destructor_scheduling_table_with_resource(table, config_resource, ctx);
    table = mir_destructor_scheduling_table_with_resource(table, net_resource, ctx);
    table = mir_destructor_scheduling_table_with_resource(table, scratch_resource, ctx);

    table = mir_destructor_scheduling_table_with_operation(table, mir_destructor_scheduling_make_operation(table, "schedule_log", "schedule_destructor", "resource_log_handle", "destructor_close_log", "release_os_handle", "scope_exit_main", "scheduled", 1, 0, 0, ctx), ctx);
    table = mir_destructor_scheduling_table_with_operation(table, mir_destructor_scheduling_make_operation(table, "schedule_config", "schedule_destructor", "resource_config_buffer", "destructor_free_config", "release_arena_buffer", "scope_exit_main", "scheduled", 1, 0, 0, ctx), ctx);
    table = mir_destructor_scheduling_table_with_operation(table, mir_destructor_scheduling_make_operation(table, "schedule_net", "schedule_destructor", "resource_net_connection", "destructor_disconnect_net", "close_network_session", "scope_exit_main", "scheduled", 1, 0, 0, ctx), ctx);
    table = mir_destructor_scheduling_table_with_operation(table, mir_destructor_scheduling_make_operation(table, "schedule_scratch", "schedule_destructor", "resource_temp_scratch", "destructor_release_scratch", "release_stack_buffer", "scope_exit_main", "scheduled", 1, 0, 0, ctx), ctx);
    // Ownership transfer cancels the obsolete schedule for the network
    // connection; the new owner schedules its own destructor later.
    table = mir_destructor_scheduling_table_with_operation(table, mir_destructor_scheduling_make_operation(table, "transfer_net", "cancel_schedule", "resource_net_connection", "destructor_disconnect_net", "close_network_session", "scope_exit_main", "cancelled", 0, 0, 0, ctx), ctx);
    table = mir_destructor_scheduling_table_with_operation(table, mir_destructor_scheduling_make_operation(table, "reschedule_net", "schedule_destructor", "resource_net_connection", "destructor_disconnect_net", "close_network_session", "scope_exit_main", "scheduled", 1, 0, 0, ctx), ctx);
    table = mir_destructor_scheduling_table_with_operation(table, mir_destructor_scheduling_make_operation(table, "execute_log", "execute_destructor", "resource_log_handle", "destructor_close_log", "release_os_handle", "scope_exit_main", "executed", 1, 1, 1, ctx), ctx);
    table = mir_destructor_scheduling_table_with_operation(table, mir_destructor_scheduling_make_operation(table, "execute_config", "execute_destructor", "resource_config_buffer", "destructor_free_config", "release_arena_buffer", "scope_exit_main", "executed", 1, 1, 2, ctx), ctx);
    table = mir_destructor_scheduling_table_with_operation(table, mir_destructor_scheduling_make_operation(table, "execute_net", "execute_destructor", "resource_net_connection", "destructor_disconnect_net", "close_network_session", "scope_exit_main", "executed", 1, 1, 3, ctx), ctx);
    table = mir_destructor_scheduling_table_with_operation(table, mir_destructor_scheduling_make_operation(table, "execute_scratch", "execute_destructor", "resource_temp_scratch", "destructor_release_scratch", "release_stack_buffer", "scope_exit_main", "executed", 1, 1, 4, ctx), ctx);
    table = mir_destructor_scheduling_table_with_operation(table, mir_destructor_scheduling_make_operation(table, "mark_log", "mark_destroyed", "resource_log_handle", "destructor_close_log", "release_os_handle", "scope_exit_main", "destroyed", 1, 1, 1, ctx), ctx);
    table = mir_destructor_scheduling_table_with_operation(table, mir_destructor_scheduling_make_operation(table, "mark_config", "mark_destroyed", "resource_config_buffer", "destructor_free_config", "release_arena_buffer", "scope_exit_main", "destroyed", 1, 1, 2, ctx), ctx);
    table = mir_destructor_scheduling_table_with_operation(table, mir_destructor_scheduling_make_operation(table, "mark_net", "mark_destroyed", "resource_net_connection", "destructor_disconnect_net", "close_network_session", "scope_exit_main", "destroyed", 1, 1, 3, ctx), ctx);
    table = mir_destructor_scheduling_table_with_operation(table, mir_destructor_scheduling_make_operation(table, "mark_scratch", "mark_destroyed", "resource_temp_scratch", "destructor_release_scratch", "release_stack_buffer", "scope_exit_main", "destroyed", 1, 1, 4, ctx), ctx);
    return table;
}

func mir_destructor_scheduling_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut updated := std.Concat(output, key);
    updated = std.Concat(updated, ": ");
    updated = std.Concat(updated, value);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

func mir_serialize_destructor_scheduling_table_for_request(table: MirDestructorSchedulingTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_destructor_scheduling_table_is_legacy_empty(table, ctx) == 1 {
        return "destructor_scheduling_table_format: gust.compiler_destructor_scheduling_table.v1\ndestructor_scheduling_target_id: \ndestructor_scheduling_target_triple: legacy-empty\ndestructor_scheduling_resource_count: 0\ndestructor_scheduling_operation_count: 0\n";
    }
    if mir_destructor_scheduling_table_is_valid(table, layout_table, ctx) == 0 {
        return "destructor_scheduling_table_format: invalid\n";
    }
    mut output := "";
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_table_format", table.format, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_target_id", table.target_id, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_target_triple", table.target_triple, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_schedule_authority", table.schedule_authority, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_duplicate_policy", table.duplicate_policy, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_execution_policy", table.execution_policy, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_move_policy", table.move_policy, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_order_policy", table.order_policy, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_async_policy", table.async_destruction_policy, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_finalizer_policy", table.finalizer_policy, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_gc_policy", table.gc_policy, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_cancellation_policy", table.cancellation_policy, ctx);

    mut resources: std.Vector[MirScheduledResource[ctx], ctx] := ctx[table.resources];
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_resource_count", std.FormatInt(len(resources)), ctx);
    mut resource_index := 0;
    while resource_index < len(resources) {
        mut prefix := std.Concat("destructor_resource_", std.FormatInt(resource_index));
        mut value := resources[resource_index];
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_id"), value.resource_id, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_type_id"), value.resource_type_id, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_destructor_id"), value.destructor_id, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_cleanup_reason"), value.cleanup_reason, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_execution_point"), value.execution_point, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_destruction_order"), std.FormatInt(value.destruction_order), ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_lifetime_region"), value.lifetime_region, ctx);
        resource_index = resource_index + 1;
    }

    mut operations: std.Vector[MirDestructorSchedulingOperation[ctx], ctx] := ctx[table.operations];
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_operation_count", std.FormatInt(len(operations)), ctx);
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut prefix := std.Concat("destructor_operation_", std.FormatInt(operation_index));
        mut value := operations[operation_index];
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_id"), value.operation_id, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_name"), value.operation_name, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_target_id"), value.target_id, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_kind"), value.kind, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_resource_id"), value.resource_id, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_destructor_id"), value.destructor_id, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_cleanup_reason"), value.cleanup_reason, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_execution_point"), value.execution_point, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_expect_success"), std.FormatInt(value.expect_success), ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_expected_state"), value.expected_state, ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_expected_schedule_count"), std.FormatInt(value.expected_schedule_count), ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_expected_execution_count"), std.FormatInt(value.expected_execution_count), ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_expected_order"), std.FormatInt(value.expected_order), ctx);
        output = mir_destructor_scheduling_append_field(output, std.Concat(prefix, "_expected_reason_code"), value.expected_reason_code, ctx);
        operation_index = operation_index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_destructor_scheduling_witness(table: MirDestructorSchedulingTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_destructor_scheduling_table_is_valid(table, layout_table, ctx) == 0 ||
       mir_destructor_scheduling_table_is_legacy_empty(table, ctx) == 1
    {
        return "";
    }
    mut output := "destructor_scheduling_status: valid\n";
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_target", table.target_triple, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_target_id", table.target_id, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_schedule_authority", table.schedule_authority, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_duplicate_policy", table.duplicate_policy, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_execution_policy", table.execution_policy, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_move_policy", table.move_policy, ctx);
    output = mir_destructor_scheduling_append_field(output, "destructor_scheduling_order_policy", table.order_policy, ctx);

    mut resources: std.Vector[MirScheduledResource[ctx], ctx] := ctx[table.resources];
    mut resource_index := 0;
    while resource_index < len(resources) {
        mut value := resources[resource_index];
        mut line := "destructor_resource: ";
        line = std.Concat(line, value.resource_id);
        line = std.Concat(line, " type="); line = std.Concat(line, value.resource_type_id);
        line = std.Concat(line, " destructor="); line = std.Concat(line, value.destructor_id);
        line = std.Concat(line, " reason="); line = std.Concat(line, value.cleanup_reason);
        line = std.Concat(line, " point="); line = std.Concat(line, value.execution_point);
        line = std.Concat(line, " order="); line = std.Concat(line, std.FormatInt(value.destruction_order));
        line = std.Concat(line, "\n");
        output = std.Concat(output, line);
        resource_index = resource_index + 1;
    }

    mut states_idx := mir_destructor_scheduling_state_vector_for_table(table, ctx);
    mut next_order := 1;
    mut operations: std.Vector[MirDestructorSchedulingOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        mut state_position := mir_destructor_scheduling_state_index(states_idx, operation.resource_id, ctx);
        mut states: std.Vector[MirDestructorSchedulingState[ctx], ctx] := ctx[states_idx];
        mut current := states[state_position];
        mut evaluation := mir_destructor_scheduling_evaluate(table, operation, current, next_order, ctx);
        mut line := "destructor_operation: ";
        line = std.Concat(line, operation.operation_name);
        line = std.Concat(line, " kind="); line = std.Concat(line, operation.kind);
        line = std.Concat(line, " status=");
        if evaluation.success == 1 { line = std.Concat(line, "success"); }
        else { line = std.Concat(line, "failure"); }
        line = std.Concat(line, " resource="); line = std.Concat(line, operation.resource_id);
        line = std.Concat(line, " state="); line = std.Concat(line, evaluation.state);
        line = std.Concat(line, " schedule_count="); line = std.Concat(line, std.FormatInt(evaluation.schedule_count));
        line = std.Concat(line, " execution_count="); line = std.Concat(line, std.FormatInt(evaluation.execution_count));
        line = std.Concat(line, " order="); line = std.Concat(line, std.FormatInt(evaluation.destruction_order));
        line = std.Concat(line, " reason="); line = std.Concat(line, evaluation.reason_code);
        line = std.Concat(line, "\n");
        output = std.Concat(output, line);
        if std.str_eq(operation.kind, "execute_destructor") == 1 {
            next_order = next_order + 1;
        }
        current.state = std.Clone(ctx, evaluation.state);
        current.schedule_count = evaluation.schedule_count;
        current.execution_count = evaluation.execution_count;
        current.destruction_order = evaluation.destruction_order;
        states_idx = mir_destructor_scheduling_state_vector_with_updated(states_idx, state_position, current, ctx);
        operation_index = operation_index + 1;
    }

    mut final_states: std.Vector[MirDestructorSchedulingState[ctx], ctx] := ctx[states_idx];
    mut final_index := 0;
    while final_index < len(final_states) {
        mut value := final_states[final_index];
        mut line := "destructor_exactly_once: ";
        line = std.Concat(line, value.resource_id);
        line = std.Concat(line, " status=exactly_once");
        line = std.Concat(line, " schedule_count="); line = std.Concat(line, std.FormatInt(value.schedule_count));
        line = std.Concat(line, " execution_count="); line = std.Concat(line, std.FormatInt(value.execution_count));
        line = std.Concat(line, " order="); line = std.Concat(line, std.FormatInt(value.destruction_order));
        line = std.Concat(line, "\n");
        output = std.Concat(output, line);
        final_index = final_index + 1;
    }
    return std.Clone(ctx, output);
}
