// Phase 16.4 compiler-owned aggregate result classification and transport.
//
// Selected direct, split, and hidden-pointer aggregate results are described
// by immutable compiler records. Hidden storage ownership, initialization,
// callee writes, Phase 15 cleanup ordering, publication, and caller extraction
// are explicit; backends consume the plan and never invent result storage.

import "mir_layout.gst" as layout;
import "mir_function_abi_authority.gst" as abi;

type MirAggregateResultFieldWrite[ctx] struct {
    write_id: str,
    plan_id: str,
    field_ordinal: int,
    byte_offset: int,
    byte_size: int,
    required_alignment: int,
    initialized: int,
    field_value: int
}

type MirAggregateResultOperation[ctx] struct {
    operation_id: str,
    plan_id: str,
    operation_kind: str,
    sequence: int,
    storage_id: str,
    terminal_control_flow: int
}

type MirAggregateResultPlan[ctx] struct {
    plan_id: str,
    function_abi_id: str,
    result_placement_id: str,
    result_id: str,
    result_ordinal: int,
    canonical_type_id: str,
    layout_id: str,
    abi_value_id: str,
    shape: str,
    result_mode: str,
    size_bytes: int,
    align_bytes: int,
    storage_owner: str,
    storage_id: str,
    initialization_point: str,
    hidden_parameter_placement: str,
    callee_write_obligation: str,
    caller_extraction: str,
    failure_behavior: str,
    evaluation_cleanup_order: str,
    padding_policy: str,
    publication_initialized: int,
    resource_disposition: str,
    resource_transition_id: str,
    target_id: str,
    target_triple: str
}

type MirAggregateResultTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    semantic_authority: str,
    selected_inventory: str,
    storage_policy: str,
    cleanup_policy: str,
    resource_policy: str,
    plans: Index[std.Vector[MirAggregateResultPlan[ctx], ctx], ctx],
    writes: Index[std.Vector[MirAggregateResultFieldWrite[ctx], ctx], ctx],
    operations: Index[std.Vector[MirAggregateResultOperation[ctx], ctx], ctx]
}

type MirAggregateResultValidation[ctx] struct { valid: int, reason_code: str }

func mir_aggregate_result_empty_plans(ctx: &Arena) Index[std.Vector[MirAggregateResultPlan[ctx], ctx], ctx] {
    mut values: std.Vector[MirAggregateResultPlan[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirAggregateResultPlan[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_aggregate_result_empty_writes(ctx: &Arena) Index[std.Vector[MirAggregateResultFieldWrite[ctx], ctx], ctx] {
    mut values: std.Vector[MirAggregateResultFieldWrite[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirAggregateResultFieldWrite[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_aggregate_result_empty_operations(ctx: &Arena) Index[std.Vector[MirAggregateResultOperation[ctx], ctx], ctx] {
    mut values: std.Vector[MirAggregateResultOperation[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirAggregateResultOperation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_aggregate_result_make_empty_table(target_id: str, target_triple: str, ctx: &Arena) MirAggregateResultTable[ctx] {
    mut table: MirAggregateResultTable[ctx];
    table.format = "gust.compiler_aggregate_result_abi.v1";
    table.target_id = std.Clone(ctx, target_id);
    table.target_triple = std.Clone(ctx, target_triple);
    table.semantic_authority = "compiler_owned_aggregate_result_classifier";
    table.selected_inventory = "non_resource_struct_single_i32_direct_pair_i32_split_triple_i64_hidden_pointer";
    table.storage_policy = "compiler_selected_storage_identity_no_backend_invention";
    table.cleanup_policy = "return_evaluation_then_phase15_cleanup_then_result_transfer";
    table.resource_policy = "non_resource_results_only_resource_bearing_results_deferred_to_phase16_10";
    table.plans = mir_aggregate_result_empty_plans(ctx);
    table.writes = mir_aggregate_result_empty_writes(ctx);
    table.operations = mir_aggregate_result_empty_operations(ctx);
    return table;
}

func mir_aggregate_result_table_with_plan(table: MirAggregateResultTable[ctx], value: MirAggregateResultPlan[ctx], ctx: &Arena) MirAggregateResultTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirAggregateResultPlan[ctx], ctx] := ctx[updated.plans];
    values.Push(value);
    ctx.Set(updated.plans, values);
    return updated;
}

func mir_aggregate_result_table_with_write(table: MirAggregateResultTable[ctx], value: MirAggregateResultFieldWrite[ctx], ctx: &Arena) MirAggregateResultTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirAggregateResultFieldWrite[ctx], ctx] := ctx[updated.writes];
    values.Push(value);
    ctx.Set(updated.writes, values);
    return updated;
}

func mir_aggregate_result_table_with_operation(table: MirAggregateResultTable[ctx], value: MirAggregateResultOperation[ctx], ctx: &Arena) MirAggregateResultTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirAggregateResultOperation[ctx], ctx] := ctx[updated.operations];
    values.Push(value);
    ctx.Set(updated.operations, values);
    return updated;
}

func mir_aggregate_result_validation(valid: int, reason_code: str, ctx: &Arena) MirAggregateResultValidation[ctx] {
    mut result: MirAggregateResultValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_aggregate_result_shape_mode_valid(shape: str, mode: str, size: int, alignment: int) int {
    if std.str_eq(shape, "struct_single_i32") == 1 && std.str_eq(mode, "direct") == 1 && size == 4 && alignment == 4 { return 1; }
    if std.str_eq(shape, "struct_pair_i32") == 1 && std.str_eq(mode, "split") == 1 && size == 8 && alignment == 4 { return 1; }
    if std.str_eq(shape, "struct_triple_i64") == 1 && std.str_eq(mode, "hidden_pointer") == 1 && size == 24 && alignment == 8 { return 1; }
    return 0;
}

func mir_aggregate_result_layout_by_id(table: layout.MirLayoutTable[ctx], layout_id: str, ctx: &Arena) layout.MirTypeLayoutQuery[ctx] {
    mut result: layout.MirTypeLayoutQuery[ctx];
    result.found = 0;
    mut values: std.Vector[layout.MirTypeLayout[ctx], ctx] := ctx[table.layouts];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].layout_id, layout_id) == 1 { result.found = 1; result.layout = values[index]; return result; }
        index = index + 1;
    }
    return result;
}

func mir_aggregate_result_placement_by_id(table: abi.MirFunctionAbiAuthorityTable[ctx], placement_id: str, ctx: &Arena) abi.MirAbiResultPlacement[ctx] {
    mut result: abi.MirAbiResultPlacement[ctx];
    result.placement_id = "";
    mut values: std.Vector[abi.MirAbiResultPlacement[ctx], ctx] := ctx[table.result_placements];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].placement_id, placement_id) == 1 { return values[index]; }
        index = index + 1;
    }
    return result;
}

func mir_aggregate_result_operation_kind_valid(kind: str) int {
    if std.str_eq(kind, "allocate_hidden_storage") == 1 { return 1; }
    if std.str_eq(kind, "evaluate_return_value") == 1 { return 1; }
    if std.str_eq(kind, "write_result_field") == 1 { return 1; }
    if std.str_eq(kind, "phase15_cleanup") == 1 { return 1; }
    if std.str_eq(kind, "publish_result") == 1 { return 1; }
    if std.str_eq(kind, "extract_result") == 1 { return 1; }
    return 0;
}

func mir_aggregate_result_table_validate(table: MirAggregateResultTable[ctx], layouts: layout.MirLayoutTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) MirAggregateResultValidation[ctx] {
    if std.str_eq(table.format, "gust.compiler_aggregate_result_abi.v1") == 0 { return mir_aggregate_result_validation(0, "aggregate_result_unknown_format", ctx); }
    if std.str_eq(table.target_id, layouts.target.target_id) == 0 || std.str_eq(table.target_triple, layouts.target.target_triple) == 0 || std.str_eq(table.target_id, authority.target_id) == 0 || std.str_eq(table.target_triple, authority.target_triple) == 0 { return mir_aggregate_result_validation(0, "aggregate_result_target_mismatch", ctx); }
    if layout.mir_layout_table_is_valid(layouts, ctx) == 0 || std.str_eq(table.semantic_authority, "compiler_owned_aggregate_result_classifier") == 0 || std.str_eq(table.storage_policy, "compiler_selected_storage_identity_no_backend_invention") == 0 || std.str_eq(table.cleanup_policy, "return_evaluation_then_phase15_cleanup_then_result_transfer") == 0 { return mir_aggregate_result_validation(0, "aggregate_result_authority_mismatch", ctx); }
    mut plans: std.Vector[MirAggregateResultPlan[ctx], ctx] := ctx[table.plans];
    mut writes: std.Vector[MirAggregateResultFieldWrite[ctx], ctx] := ctx[table.writes];
    mut operations: std.Vector[MirAggregateResultOperation[ctx], ctx] := ctx[table.operations];
    mut index := 0;
    while index < len(plans) {
        mut plan := plans[index];
        if mir_aggregate_result_shape_mode_valid(plan.shape, plan.result_mode, plan.size_bytes, plan.align_bytes) == 0 { return mir_aggregate_result_validation(0, "aggregate_result_unsupported_shape", ctx); }
        mut type_layout := mir_aggregate_result_layout_by_id(layouts, plan.layout_id, ctx);
        if type_layout.found == 0 || std.str_eq(type_layout.layout.type_id, plan.canonical_type_id) == 0 || type_layout.layout.size != plan.size_bytes || type_layout.layout.alignment != plan.align_bytes { return mir_aggregate_result_validation(0, "aggregate_result_wrong_layout_or_alignment", ctx); }
        mut classification := abi.mir_abi_classification_by_id(authority, plan.abi_value_id, ctx);
        mut placement := mir_aggregate_result_placement_by_id(authority, plan.result_placement_id, ctx);
        if classification.found == 0 || len(placement.placement_id) == 0 || std.str_eq(placement.abi_id, plan.function_abi_id) == 0 || std.str_eq(placement.classification_id, plan.abi_value_id) == 0 || std.str_eq(placement.layout_id, plan.layout_id) == 0 || std.str_eq(placement.passing_mode, plan.result_mode) == 0 || placement.ordinal != plan.result_ordinal { return mir_aggregate_result_validation(0, "aggregate_result_caller_callee_disagreement", ctx); }
        if std.str_eq(plan.result_mode, "hidden_pointer") == 1 {
            if placement.hidden != 1 || std.str_eq(classification.value.position, "hidden_result") == 0 || len(plan.storage_id) == 0 || len(plan.hidden_parameter_placement) == 0 { return mir_aggregate_result_validation(0, "aggregate_result_missing_hidden_storage", ctx); }
            if std.str_eq(plan.storage_owner, "caller_compiler_plan") == 0 || std.str_eq(plan.initialization_point, "before_call") == 0 || std.str_eq(plan.callee_write_obligation, "write_all_initialized_fields_before_return") == 0 || std.str_eq(plan.caller_extraction, "after_successful_publication") == 0 || std.str_eq(plan.failure_behavior, "do_not_publish_uninitialized_storage") == 0 { return mir_aggregate_result_validation(0, "aggregate_result_backend_invented_storage", ctx); }
        } else if placement.hidden != 0 || std.str_eq(classification.value.position, "result") == 0 || len(plan.storage_id) != 0 || len(plan.hidden_parameter_placement) != 0 { return mir_aggregate_result_validation(0, "aggregate_result_caller_callee_disagreement", ctx); }
        if std.str_eq(plan.evaluation_cleanup_order, table.cleanup_policy) == 0 || std.str_eq(plan.resource_disposition, "non_resource") == 0 || len(plan.resource_transition_id) != 0 { return mir_aggregate_result_validation(0, "aggregate_result_caller_callee_disagreement", ctx); }
        if plan.publication_initialized != 1 { return mir_aggregate_result_validation(0, "aggregate_result_uninitialized_publication", ctx); }
        mut write_count := 0;
        mut write_index := 0;
        while write_index < len(writes) {
            mut write := writes[write_index];
            if std.str_eq(write.plan_id, plan.plan_id) == 1 {
                if write.field_ordinal != write_count || write.initialized != 1 { return mir_aggregate_result_validation(0, "aggregate_result_uninitialized_publication", ctx); }
                if write.byte_size <= 0 || write.byte_offset < 0 || write.byte_offset + write.byte_size > plan.size_bytes || write.required_alignment < plan.align_bytes { return mir_aggregate_result_validation(0, "aggregate_result_wrong_layout_or_alignment", ctx); }
                write_count = write_count + 1;
            }
            write_index = write_index + 1;
        }
        mut expected_writes := 1;
        if std.str_eq(plan.result_mode, "split") == 1 { expected_writes = 2; }
        if std.str_eq(plan.result_mode, "hidden_pointer") == 1 { expected_writes = 3; }
        if write_count != expected_writes { return mir_aggregate_result_validation(0, "aggregate_result_uninitialized_publication", ctx); }
        mut sequence := 0;
        mut saw_publish := 0;
        mut operation_index := 0;
        while operation_index < len(operations) {
            mut operation := operations[operation_index];
            if std.str_eq(operation.plan_id, plan.plan_id) == 1 {
                if mir_aggregate_result_operation_kind_valid(operation.operation_kind) == 0 || operation.sequence != sequence { return mir_aggregate_result_validation(0, "aggregate_result_caller_callee_disagreement", ctx); }
                if std.str_eq(operation.operation_kind, "write_result_field") == 1 && operation.terminal_control_flow == 1 { return mir_aggregate_result_validation(0, "aggregate_result_written_after_terminal", ctx); }
                if std.str_eq(operation.operation_kind, "publish_result") == 1 { saw_publish = 1; }
                sequence = sequence + 1;
            }
            operation_index = operation_index + 1;
        }
        if saw_publish == 0 { return mir_aggregate_result_validation(0, "aggregate_result_uninitialized_publication", ctx); }
        mut duplicate := index + 1;
        while duplicate < len(plans) {
            if std.str_eq(plans[duplicate].plan_id, plan.plan_id) == 1 || std.str_eq(plans[duplicate].result_id, plan.result_id) == 1 { return mir_aggregate_result_validation(0, "aggregate_result_duplicate_identity", ctx); }
            if len(plan.storage_id) != 0 && std.str_eq(plans[duplicate].storage_id, plan.storage_id) == 1 { return mir_aggregate_result_validation(0, "aggregate_result_duplicate_hidden_identity", ctx); }
            duplicate = duplicate + 1;
        }
        index = index + 1;
    }
    return mir_aggregate_result_validation(1, "aggregate_result_table_valid", ctx);
}

func mir_aggregate_result_row_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut result := std.Concat(output, key); result = std.Concat(result, "="); result = std.Concat(result, value); return std.Clone(ctx, result);
}

func mir_serialize_aggregate_result_for_request(table: MirAggregateResultTable[ctx], layouts: layout.MirLayoutTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_aggregate_result_table_validate(table, layouts, authority, ctx);
    if validation.valid == 0 { mut error := std.Concat("aggregate_result_error: ", validation.reason_code); return std.Clone(ctx, error); }
    mut plans: std.Vector[MirAggregateResultPlan[ctx], ctx] := ctx[table.plans];
    mut writes: std.Vector[MirAggregateResultFieldWrite[ctx], ctx] := ctx[table.writes];
    mut operations: std.Vector[MirAggregateResultOperation[ctx], ctx] := ctx[table.operations];
    mut output := "aggregate_result_format: gust.compiler_aggregate_result_abi.v1\n";
    output = std.Concat(output, std.Concat("aggregate_result_target_id: ", std.Concat(table.target_id, "\n")));
    output = std.Concat(output, std.Concat("aggregate_result_target_triple: ", std.Concat(table.target_triple, "\n")));
    output = std.Concat(output, std.Concat("aggregate_result_plan_count: ", std.Concat(std.FormatInt(len(plans)), "\n")));
    output = std.Concat(output, std.Concat("aggregate_result_write_count: ", std.Concat(std.FormatInt(len(writes)), "\n")));
    output = std.Concat(output, std.Concat("aggregate_result_operation_count: ", std.Concat(std.FormatInt(len(operations)), "\n")));
    mut index := 0;
    while index < len(plans) {
        mut v := plans[index]; mut row := "aggregate_result_plan:";
        row = mir_aggregate_result_row_field(row, "id", v.plan_id, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "abi", v.function_abi_id, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "placement", v.result_placement_id, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "result", v.result_id, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "ordinal", std.FormatInt(v.result_ordinal), ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "type", v.canonical_type_id, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "layout", v.layout_id, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "abi_value", v.abi_value_id, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "shape", v.shape, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "mode", v.result_mode, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "size", std.FormatInt(v.size_bytes), ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "align", std.FormatInt(v.align_bytes), ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "owner", v.storage_owner, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "storage", v.storage_id, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "init_point", v.initialization_point, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "hidden_parameter", v.hidden_parameter_placement, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "callee_write", v.callee_write_obligation, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "caller_extract", v.caller_extraction, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "failure", v.failure_behavior, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "cleanup", v.evaluation_cleanup_order, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "padding", v.padding_policy, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "published", std.FormatInt(v.publication_initialized), ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "resource", v.resource_disposition, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "transition", v.resource_transition_id, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "target", v.target_id, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "triple", v.target_triple, ctx); output = std.Concat(output, std.Concat(row, "\n")); index = index + 1;
    }
    index = 0;
    while index < len(writes) {
        mut v := writes[index]; mut row := "aggregate_result_write:";
        row = mir_aggregate_result_row_field(row, "id", v.write_id, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "plan", v.plan_id, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "ordinal", std.FormatInt(v.field_ordinal), ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "offset", std.FormatInt(v.byte_offset), ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "size", std.FormatInt(v.byte_size), ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "align", std.FormatInt(v.required_alignment), ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "initialized", std.FormatInt(v.initialized), ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "value", std.FormatInt(v.field_value), ctx); output = std.Concat(output, std.Concat(row, "\n")); index = index + 1;
    }
    index = 0;
    while index < len(operations) {
        mut v := operations[index]; mut row := "aggregate_result_operation:";
        row = mir_aggregate_result_row_field(row, "id", v.operation_id, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "plan", v.plan_id, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "kind", v.operation_kind, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "sequence", std.FormatInt(v.sequence), ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "storage", v.storage_id, ctx); row = mir_aggregate_result_row_field(std.Concat(row, ";"), "terminal", std.FormatInt(v.terminal_control_flow), ctx); output = std.Concat(output, std.Concat(row, "\n")); index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_aggregate_result_witness(table: MirAggregateResultTable[ctx], layouts: layout.MirLayoutTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) str {
    mut witness := mir_serialize_aggregate_result_for_request(table, layouts, authority, ctx);
    return std.Clone(ctx, witness);
}
