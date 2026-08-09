// Phase 16.3 compiler-owned aggregate parameter classification and passing.
//
// The compiler selects direct, split, or indirect-by-value transport from a
// bounded inventory of non-resource struct layouts. MIR-to-C and Cranelift
// consume these plans and logical locations; neither backend may reclassify an
// aggregate from host ABI rules, generated C, source spelling, or object code.

import "mir_layout.gst" as layout;
import "mir_function_abi_authority.gst" as abi;

type MirAggregateParameterLocation[ctx] struct {
    location_id: str,
    plan_id: str,
    logical_ordinal: int,
    logical_location: str,
    byte_offset: int,
    byte_size: int,
    required_alignment: int,
    initialized_value: int
}

type MirAggregateParameterPlan[ctx] struct {
    plan_id: str,
    function_abi_id: str,
    parameter_placement_id: str,
    parameter_id: str,
    argument_ordinal: int,
    canonical_type_id: str,
    layout_id: str,
    abi_value_id: str,
    shape: str,
    passing_mode: str,
    size_bytes: int,
    align_bytes: int,
    caller_materialization: str,
    callee_materialization: str,
    padding_policy: str,
    resource_disposition: str,
    transfer_disposition: str,
    resource_id: str,
    initialized_byte_ranges: str,
    target_id: str,
    target_triple: str
}

type MirAggregateParameterTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    semantic_authority: str,
    selected_inventory: str,
    classification_policy: str,
    padding_policy: str,
    resource_policy: str,
    composition_policy: str,
    plans: Index[std.Vector[MirAggregateParameterPlan[ctx], ctx], ctx],
    locations: Index[std.Vector[MirAggregateParameterLocation[ctx], ctx], ctx]
}

type MirAggregateParameterValidation[ctx] struct { valid: int, reason_code: str }

func mir_aggregate_parameter_empty_plans(ctx: &Arena) Index[std.Vector[MirAggregateParameterPlan[ctx], ctx], ctx] {
    mut values: std.Vector[MirAggregateParameterPlan[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirAggregateParameterPlan[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_aggregate_parameter_empty_locations(ctx: &Arena) Index[std.Vector[MirAggregateParameterLocation[ctx], ctx], ctx] {
    mut values: std.Vector[MirAggregateParameterLocation[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirAggregateParameterLocation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_aggregate_parameter_make_empty_table(target_id: str, target_triple: str, ctx: &Arena) MirAggregateParameterTable[ctx] {
    mut table: MirAggregateParameterTable[ctx];
    table.format = "gust.compiler_aggregate_parameter_abi.v1";
    table.target_id = std.Clone(ctx, target_id);
    table.target_triple = std.Clone(ctx, target_triple);
    table.semantic_authority = "compiler_owned_aggregate_parameter_classifier";
    table.selected_inventory = "non_resource_struct_single_i32_direct_pair_i32_split_triple_i64_indirect_by_value";
    table.classification_policy = "compiler_plan_only_no_backend_calling_convention_reclassification";
    table.padding_policy = "initialized_fields_only_padding_not_semantic";
    table.resource_policy = "non_resource_copy_only_resource_bearing_aggregate_calls_deferred_to_phase16_10";
    table.composition_policy = "source_order_scalar_then_multiple_aggregate_parameters";
    table.plans = mir_aggregate_parameter_empty_plans(ctx);
    table.locations = mir_aggregate_parameter_empty_locations(ctx);
    return table;
}

func mir_aggregate_parameter_table_with_plan(table: MirAggregateParameterTable[ctx], value: MirAggregateParameterPlan[ctx], ctx: &Arena) MirAggregateParameterTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirAggregateParameterPlan[ctx], ctx] := ctx[updated.plans];
    values.Push(value);
    ctx.Set(updated.plans, values);
    return updated;
}

func mir_aggregate_parameter_table_with_location(table: MirAggregateParameterTable[ctx], value: MirAggregateParameterLocation[ctx], ctx: &Arena) MirAggregateParameterTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirAggregateParameterLocation[ctx], ctx] := ctx[updated.locations];
    values.Push(value);
    ctx.Set(updated.locations, values);
    return updated;
}

func mir_aggregate_parameter_validation(valid: int, reason_code: str, ctx: &Arena) MirAggregateParameterValidation[ctx] {
    mut result: MirAggregateParameterValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_aggregate_parameter_field_safe(value: str, allow_empty: int) int {
    if allow_empty == 0 && len(value) == 0 { return 0; }
    if std.str_find(value, "\n") != 0 - 1 || std.str_find(value, "\r") != 0 - 1 || std.str_find(value, ";") != 0 - 1 { return 0; }
    return 1;
}

func mir_aggregate_parameter_shape_mode_valid(shape: str, mode: str, size: int, alignment: int) int {
    if std.str_eq(shape, "struct_single_i32") == 1 && std.str_eq(mode, "direct") == 1 && size == 4 && alignment == 4 { return 1; }
    if std.str_eq(shape, "struct_pair_i32") == 1 && std.str_eq(mode, "split") == 1 && size == 8 && alignment == 4 { return 1; }
    if std.str_eq(shape, "struct_triple_i64") == 1 && std.str_eq(mode, "indirect_by_value") == 1 && size == 24 && alignment == 8 { return 1; }
    return 0;
}

func mir_aggregate_parameter_layout_by_id(table: layout.MirLayoutTable[ctx], layout_id: str, ctx: &Arena) layout.MirTypeLayoutQuery[ctx] {
    mut result: layout.MirTypeLayoutQuery[ctx];
    result.found = 0;
    mut values: std.Vector[layout.MirTypeLayout[ctx], ctx] := ctx[table.layouts];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].layout_id, layout_id) == 1 {
            result.found = 1;
            result.layout = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_aggregate_parameter_placement_by_id(table: abi.MirFunctionAbiAuthorityTable[ctx], placement_id: str, ctx: &Arena) abi.MirAbiParameterPlacement[ctx] {
    mut result: abi.MirAbiParameterPlacement[ctx];
    result.placement_id = "";
    mut values: std.Vector[abi.MirAbiParameterPlacement[ctx], ctx] := ctx[table.parameter_placements];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].placement_id, placement_id) == 1 { return values[index]; }
        index = index + 1;
    }
    return result;
}

func mir_aggregate_parameter_table_validate(table: MirAggregateParameterTable[ctx], layouts: layout.MirLayoutTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) MirAggregateParameterValidation[ctx] {
    if std.str_eq(table.format, "gust.compiler_aggregate_parameter_abi.v1") == 0 { return mir_aggregate_parameter_validation(0, "aggregate_parameter_unknown_format", ctx); }
    if std.str_eq(table.target_id, layouts.target.target_id) == 0 || std.str_eq(table.target_triple, layouts.target.target_triple) == 0 || std.str_eq(table.target_id, authority.target_id) == 0 || std.str_eq(table.target_triple, authority.target_triple) == 0 { return mir_aggregate_parameter_validation(0, "aggregate_parameter_target_mismatch", ctx); }
    if layout.mir_layout_table_is_valid(layouts, ctx) == 0 { return mir_aggregate_parameter_validation(0, "aggregate_parameter_invalid_layout_identity", ctx); }
    if std.str_eq(table.semantic_authority, "compiler_owned_aggregate_parameter_classifier") == 0 || std.str_eq(table.classification_policy, "compiler_plan_only_no_backend_calling_convention_reclassification") == 0 || std.str_eq(table.padding_policy, "initialized_fields_only_padding_not_semantic") == 0 { return mir_aggregate_parameter_validation(0, "aggregate_parameter_authority_mismatch", ctx); }

    mut plans: std.Vector[MirAggregateParameterPlan[ctx], ctx] := ctx[table.plans];
    mut locations: std.Vector[MirAggregateParameterLocation[ctx], ctx] := ctx[table.locations];
    mut index := 0;
    while index < len(plans) {
        mut plan := plans[index];
        if mir_aggregate_parameter_field_safe(plan.plan_id, 0) == 0 || mir_aggregate_parameter_field_safe(plan.parameter_id, 0) == 0 || plan.argument_ordinal < 0 { return mir_aggregate_parameter_validation(0, "aggregate_parameter_invalid_record", ctx); }
        if mir_aggregate_parameter_shape_mode_valid(plan.shape, plan.passing_mode, plan.size_bytes, plan.align_bytes) == 0 { return mir_aggregate_parameter_validation(0, "aggregate_parameter_unsupported_shape", ctx); }
        mut type_layout := mir_aggregate_parameter_layout_by_id(layouts, plan.layout_id, ctx);
        if type_layout.found == 0 || std.str_eq(type_layout.layout.type_id, plan.canonical_type_id) == 0 || type_layout.layout.size != plan.size_bytes || type_layout.layout.alignment != plan.align_bytes { return mir_aggregate_parameter_validation(0, "aggregate_parameter_invalid_layout_identity", ctx); }
        mut classification := abi.mir_abi_classification_by_id(authority, plan.abi_value_id, ctx);
        if classification.found == 0 || std.str_eq(classification.value.type_id, plan.canonical_type_id) == 0 || std.str_eq(classification.value.layout_id, plan.layout_id) == 0 || std.str_eq(classification.value.position, "parameter") == 0 || std.str_eq(classification.value.value_class, "aggregate") == 0 || classification.value.size_bytes != plan.size_bytes || classification.value.align_bytes != plan.align_bytes { return mir_aggregate_parameter_validation(0, "aggregate_parameter_invalid_abi_value", ctx); }
        mut placement := mir_aggregate_parameter_placement_by_id(authority, plan.parameter_placement_id, ctx);
        if len(placement.placement_id) == 0 || std.str_eq(placement.abi_id, plan.function_abi_id) == 0 || std.str_eq(placement.classification_id, plan.abi_value_id) == 0 || std.str_eq(placement.layout_id, plan.layout_id) == 0 || std.str_eq(placement.passing_mode, plan.passing_mode) == 0 || placement.ordinal != plan.argument_ordinal { return mir_aggregate_parameter_validation(0, "aggregate_parameter_caller_callee_disagreement", ctx); }
        if std.str_eq(plan.resource_disposition, "non_resource") == 0 || std.str_eq(plan.transfer_disposition, "copy") == 0 || len(plan.resource_id) != 0 { return mir_aggregate_parameter_validation(0, "aggregate_parameter_move_only_copy_rejected", ctx); }
        if std.str_eq(plan.padding_policy, table.padding_policy) == 0 || len(plan.initialized_byte_ranges) == 0 { return mir_aggregate_parameter_validation(0, "aggregate_parameter_padding_policy_mismatch", ctx); }
        if std.str_eq(plan.passing_mode, "direct") == 1 && (std.str_eq(plan.caller_materialization, "canonical_value") == 0 || std.str_eq(plan.callee_materialization, "canonical_value") == 0) { return mir_aggregate_parameter_validation(0, "aggregate_parameter_caller_callee_disagreement", ctx); }
        if std.str_eq(plan.passing_mode, "split") == 1 && (std.str_eq(plan.caller_materialization, "split_initialized_fields") == 0 || std.str_eq(plan.callee_materialization, "join_initialized_fields") == 0) { return mir_aggregate_parameter_validation(0, "aggregate_parameter_caller_callee_disagreement", ctx); }
        if std.str_eq(plan.passing_mode, "indirect_by_value") == 1 && (std.str_eq(plan.caller_materialization, "caller_owned_readonly_slot") == 0 || std.str_eq(plan.callee_materialization, "read_indirect_by_value") == 0) { return mir_aggregate_parameter_validation(0, "aggregate_parameter_caller_callee_disagreement", ctx); }

        mut location_count := 0;
        mut location_index := 0;
        while location_index < len(locations) {
            mut current := locations[location_index];
            if std.str_eq(current.plan_id, plan.plan_id) == 1 {
                if current.logical_ordinal != location_count || current.byte_offset < 0 || current.byte_size <= 0 || current.byte_offset + current.byte_size > plan.size_bytes || current.byte_offset / plan.align_bytes * plan.align_bytes != current.byte_offset { return mir_aggregate_parameter_validation(0, "aggregate_parameter_illegal_split_boundary", ctx); }
                if current.required_alignment < plan.align_bytes { return mir_aggregate_parameter_validation(0, "aggregate_parameter_insufficient_alignment", ctx); }
                mut prior := 0;
                while prior < location_index {
                    if std.str_eq(locations[prior].plan_id, plan.plan_id) == 1 && current.byte_offset < locations[prior].byte_offset + locations[prior].byte_size && locations[prior].byte_offset < current.byte_offset + current.byte_size { return mir_aggregate_parameter_validation(0, "aggregate_parameter_overlapping_placements", ctx); }
                    prior = prior + 1;
                }
                location_count = location_count + 1;
            }
            location_index = location_index + 1;
        }
        if std.str_eq(plan.passing_mode, "split") == 1 && location_count != 2 { return mir_aggregate_parameter_validation(0, "aggregate_parameter_illegal_split_boundary", ctx); }
        if std.str_eq(plan.passing_mode, "split") == 0 && location_count != 1 { return mir_aggregate_parameter_validation(0, "aggregate_parameter_caller_callee_disagreement", ctx); }
        mut duplicate := index + 1;
        while duplicate < len(plans) {
            if std.str_eq(plans[duplicate].plan_id, plan.plan_id) == 1 { return mir_aggregate_parameter_validation(0, "aggregate_parameter_duplicate_plan", ctx); }
            if plans[duplicate].argument_ordinal == plan.argument_ordinal { return mir_aggregate_parameter_validation(0, "aggregate_parameter_argument_order_mismatch", ctx); }
            duplicate = duplicate + 1;
        }
        index = index + 1;
    }
    return mir_aggregate_parameter_validation(1, "aggregate_parameter_table_valid", ctx);
}

func mir_aggregate_parameter_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut result := std.Concat(output, key);
    result = std.Concat(result, "=");
    result = std.Concat(result, value);
    return std.Clone(ctx, result);
}

func mir_serialize_aggregate_parameter_for_request(table: MirAggregateParameterTable[ctx], layouts: layout.MirLayoutTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_aggregate_parameter_table_validate(table, layouts, authority, ctx);
    if validation.valid == 0 {
        mut error := std.Concat("aggregate_parameter_error: ", validation.reason_code);
        return std.Clone(ctx, error);
    }
    mut plans: std.Vector[MirAggregateParameterPlan[ctx], ctx] := ctx[table.plans];
    mut locations: std.Vector[MirAggregateParameterLocation[ctx], ctx] := ctx[table.locations];
    mut output := "aggregate_parameter_format: gust.compiler_aggregate_parameter_abi.v1\n";
    output = std.Concat(output, std.Concat("aggregate_parameter_target_id: ", std.Concat(table.target_id, "\n")));
    output = std.Concat(output, std.Concat("aggregate_parameter_target_triple: ", std.Concat(table.target_triple, "\n")));
    output = std.Concat(output, std.Concat("aggregate_parameter_plan_count: ", std.Concat(std.FormatInt(len(plans)), "\n")));
    output = std.Concat(output, std.Concat("aggregate_parameter_location_count: ", std.Concat(std.FormatInt(len(locations)), "\n")));
    mut index := 0;
    while index < len(plans) {
        mut value := plans[index];
        mut row := "aggregate_parameter_plan:";
        row = mir_aggregate_parameter_append_field(row, "id", value.plan_id, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "abi", value.function_abi_id, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "placement", value.parameter_placement_id, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "parameter", value.parameter_id, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "ordinal", std.FormatInt(value.argument_ordinal), ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "type", value.canonical_type_id, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "layout", value.layout_id, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "abi_value", value.abi_value_id, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "shape", value.shape, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "mode", value.passing_mode, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "size", std.FormatInt(value.size_bytes), ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "align", std.FormatInt(value.align_bytes), ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "caller", value.caller_materialization, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "callee", value.callee_materialization, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "padding", value.padding_policy, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "resource", value.resource_disposition, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "transfer", value.transfer_disposition, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "resource_id", value.resource_id, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "initialized", value.initialized_byte_ranges, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "target", value.target_id, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "triple", value.target_triple, ctx);
        output = std.Concat(output, std.Concat(row, "\n"));
        index = index + 1;
    }
    index = 0;
    while index < len(locations) {
        mut value := locations[index];
        mut row := "aggregate_parameter_location:";
        row = mir_aggregate_parameter_append_field(row, "id", value.location_id, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "plan", value.plan_id, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "ordinal", std.FormatInt(value.logical_ordinal), ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "location", value.logical_location, ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "offset", std.FormatInt(value.byte_offset), ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "size", std.FormatInt(value.byte_size), ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "align", std.FormatInt(value.required_alignment), ctx);
        row = mir_aggregate_parameter_append_field(std.Concat(row, ";"), "value", std.FormatInt(value.initialized_value), ctx);
        output = std.Concat(output, std.Concat(row, "\n"));
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_aggregate_parameter_witness(table: MirAggregateParameterTable[ctx], layouts: layout.MirLayoutTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) str {
    mut request := mir_serialize_aggregate_parameter_for_request(table, layouts, authority, ctx);
    return std.Clone(ctx, request);
}
