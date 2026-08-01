// Phase 14.8 compiler-owned fixed-array and bounded-slice authority.
//
// Selected fixed arrays use compiler-owned element count, stride, total size,
// and alignment. Selected slices use a compiler-owned pointer-plus-usize
// layout, checked bounds, explicit lifetime identity, and a canonical
// null-pointer/zero-length empty representation. Variable-length stack arrays,
// unsized aggregate storage, heap ownership, resizing, and arbitrary element
// inventories remain deferred.

import "mir_layout.gst" as layout;

type MirArrayLayout[ctx] struct {
    array_type_id: str,
    layout_id: str,
    target_id: str,
    target_triple: str,
    element_type_id: str,
    element_layout_id: str,
    element_count: int,
    element_stride: int,
    total_size: int,
    alignment: int,
    nesting_depth: int,
    representation_kind: str
}

type MirArrayValue[ctx] struct {
    array_id: str,
    array_layout_id: str,
    element_type_id: str,
    elements: Index[std.Vector[int, ctx], ctx],
    lifetime_region: str
}

type MirSliceLayout[ctx] struct {
    slice_type_id: str,
    layout_id: str,
    target_id: str,
    target_triple: str,
    element_type_id: str,
    element_layout_id: str,
    pointer_size: int,
    pointer_alignment: int,
    size: int,
    alignment: int,
    data_pointer_offset: int,
    length_offset: int,
    length_type_id: str,
    representation_kind: str,
    empty_representation: str,
    nullability_policy: str,
    lifetime_policy: str
}

type MirSliceValue[ctx] struct {
    slice_id: str,
    source_array_id: str,
    slice_layout_id: str,
    element_type_id: str,
    start: int,
    length: int,
    data_known_null: int,
    lifetime_region: str,
    source_lifetime_region: str,
    flow_origin: str
}

type MirArraySliceOperation[ctx] struct {
    operation_id: str,
    operation_name: str,
    target_id: str,
    kind: str,
    array_id: str,
    slice_id: str,
    result_slice_id: str,
    element_type_id: str,
    index: int,
    start: int,
    length: int,
    stored_value: int,
    expect_success: int,
    expected_value: int,
    expected_address_offset: int,
    expected_result_start: int,
    expected_result_length: int,
    expected_reason_code: str
}

type MirArraySliceTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    bounds_policy: str,
    empty_slice_policy: str,
    stride_authority: str,
    lifetime_policy: str,
    variable_length_array_policy: str,
    unsized_storage_policy: str,
    array_layouts: Index[std.Vector[MirArrayLayout[ctx], ctx], ctx],
    arrays: Index[std.Vector[MirArrayValue[ctx], ctx], ctx],
    slice_layouts: Index[std.Vector[MirSliceLayout[ctx], ctx], ctx],
    slices: Index[std.Vector[MirSliceValue[ctx], ctx], ctx],
    operations: Index[std.Vector[MirArraySliceOperation[ctx], ctx], ctx]
}

type MirArrayLayoutQuery[ctx] struct {
    found: int,
    array_layout: MirArrayLayout[ctx]
}

type MirArrayValueQuery[ctx] struct {
    found: int,
    array_value: MirArrayValue[ctx]
}

type MirSliceLayoutQuery[ctx] struct {
    found: int,
    slice_layout: MirSliceLayout[ctx]
}

type MirSliceValueQuery[ctx] struct {
    found: int,
    slice_value: MirSliceValue[ctx]
}

type MirArraySliceOperationQuery[ctx] struct {
    found: int,
    operation: MirArraySliceOperation[ctx]
}

type MirArraySliceElementLayoutQuery struct {
    found: int,
    size: int,
    alignment: int
}

type MirArraySliceEvaluation[ctx] struct {
    success: int,
    value: int,
    address_offset: int,
    result_start: int,
    result_length: int,
    reason_code: str
}

func mir_array_slice_empty_array_layout_vector(ctx: &Arena) Index[std.Vector[MirArrayLayout[ctx], ctx], ctx] {
    mut values: std.Vector[MirArrayLayout[ctx], ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[MirArrayLayout[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_array_slice_empty_array_vector(ctx: &Arena) Index[std.Vector[MirArrayValue[ctx], ctx], ctx] {
    mut values: std.Vector[MirArrayValue[ctx], ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[MirArrayValue[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_array_slice_empty_slice_layout_vector(ctx: &Arena) Index[std.Vector[MirSliceLayout[ctx], ctx], ctx] {
    mut values: std.Vector[MirSliceLayout[ctx], ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[MirSliceLayout[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_array_slice_empty_slice_vector(ctx: &Arena) Index[std.Vector[MirSliceValue[ctx], ctx], ctx] {
    mut values: std.Vector[MirSliceValue[ctx], ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[MirSliceValue[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_array_slice_empty_operation_vector(ctx: &Arena) Index[std.Vector[MirArraySliceOperation[ctx], ctx], ctx] {
    mut values: std.Vector[MirArraySliceOperation[ctx], ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[MirArraySliceOperation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_array_slice_empty_int_vector(ctx: &Arena) Index[std.Vector[int, ctx], ctx] {
    mut values: std.Vector[int, ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[int, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_array_slice_make_empty_table(target_triple: str, ctx: &Arena) MirArraySliceTable[ctx] {
    mut table: MirArraySliceTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_array_slice_table.v1");
    table.target_id = std.Clone(ctx, "");
    table.target_triple = std.Clone(ctx, target_triple);
    table.bounds_policy = std.Clone(ctx, "checked_before_address_calculation");
    table.empty_slice_policy = std.Clone(ctx, "null_pointer_with_zero_length");
    table.stride_authority = std.Clone(ctx, "compiler_owned_element_stride_no_backend_inference");
    table.lifetime_policy = std.Clone(ctx, "borrowed_slice_must_not_outlive_source_array");
    table.variable_length_array_policy = std.Clone(ctx, "deferred_variable_length_stack_arrays");
    table.unsized_storage_policy = std.Clone(ctx, "deferred_unsized_aggregate_storage");
    table.array_layouts = mir_array_slice_empty_array_layout_vector(ctx);
    table.arrays = mir_array_slice_empty_array_vector(ctx);
    table.slice_layouts = mir_array_slice_empty_slice_layout_vector(ctx);
    table.slices = mir_array_slice_empty_slice_vector(ctx);
    table.operations = mir_array_slice_empty_operation_vector(ctx);
    return table;
}

func mir_array_slice_table_is_legacy_empty(table: MirArraySliceTable[ctx], ctx: &Arena) int {
    mut array_layouts: std.Vector[MirArrayLayout[ctx], ctx] := ctx[table.array_layouts];
    mut arrays: std.Vector[MirArrayValue[ctx], ctx] := ctx[table.arrays];
    mut slice_layouts: std.Vector[MirSliceLayout[ctx], ctx] := ctx[table.slice_layouts];
    mut slices: std.Vector[MirSliceValue[ctx], ctx] := ctx[table.slices];
    mut operations: std.Vector[MirArraySliceOperation[ctx], ctx] := ctx[table.operations];
    if len(table.target_id) == 0 &&
       len(array_layouts) == 0 && len(arrays) == 0 &&
       len(slice_layouts) == 0 && len(slices) == 0 &&
       len(operations) == 0
    {
        return 1;
    }
    return 0;
}

func mir_array_slice_field_is_safe(value: str, allow_empty: int) int {
    if allow_empty == 0 && len(value) == 0 { return 0; }
    if std.str_find(value, "\n") != 0 - 1 { return 0; }
    if std.str_find(value, "\r") != 0 - 1 { return 0; }
    return 1;
}

func mir_array_slice_align_up(value: int, alignment: int) int {
    if alignment <= 0 { return 0; }
    mut remainder := value % alignment;
    if remainder == 0 { return value; }
    return value + alignment - remainder;
}

func mir_array_slice_operation_kind_is_valid(kind: str) int {
    if std.str_eq(kind, "array_init") == 1 { return 1; }
    if std.str_eq(kind, "element_address") == 1 { return 1; }
    if std.str_eq(kind, "element_load") == 1 { return 1; }
    if std.str_eq(kind, "element_store") == 1 { return 1; }
    if std.str_eq(kind, "array_to_slice") == 1 { return 1; }
    if std.str_eq(kind, "slice_length") == 1 { return 1; }
    if std.str_eq(kind, "bounded_index") == 1 { return 1; }
    if std.str_eq(kind, "subslice") == 1 { return 1; }
    return 0;
}

func mir_array_slice_array_layout_identity(target_id: str, array_type_id: str, element_layout_id: str, element_count: int, element_stride: int, total_size: int, alignment: int, ctx: &Arena) str {
    mut identity := "array_layout:v1:target=";
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":type=");
    identity = std.Concat(identity, array_type_id);
    identity = std.Concat(identity, ":element_layout=");
    identity = std.Concat(identity, element_layout_id);
    identity = std.Concat(identity, ":count=");
    identity = std.Concat(identity, std.FormatInt(element_count));
    identity = std.Concat(identity, ":stride=");
    identity = std.Concat(identity, std.FormatInt(element_stride));
    identity = std.Concat(identity, ":size=");
    identity = std.Concat(identity, std.FormatInt(total_size));
    identity = std.Concat(identity, ":align=");
    identity = std.Concat(identity, std.FormatInt(alignment));
    return std.Clone(ctx, identity);
}

func mir_array_slice_slice_layout_identity(target_id: str, slice_type_id: str, element_layout_id: str, pointer_size: int, pointer_alignment: int, ctx: &Arena) str {
    mut identity := "slice_layout:v1:target=";
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":type=");
    identity = std.Concat(identity, slice_type_id);
    identity = std.Concat(identity, ":element_layout=");
    identity = std.Concat(identity, element_layout_id);
    identity = std.Concat(identity, ":pointer_size=");
    identity = std.Concat(identity, std.FormatInt(pointer_size));
    identity = std.Concat(identity, ":pointer_align=");
    identity = std.Concat(identity, std.FormatInt(pointer_alignment));
    return std.Clone(ctx, identity);
}

func mir_array_slice_slice_identity(source_array_id: str, slice_layout_id: str, start: int, length: int, data_known_null: int, lifetime_region: str, flow_origin: str, ctx: &Arena) str {
    mut identity := "slice:v1:array=";
    identity = std.Concat(identity, source_array_id);
    identity = std.Concat(identity, ":layout=");
    identity = std.Concat(identity, slice_layout_id);
    identity = std.Concat(identity, ":start=");
    identity = std.Concat(identity, std.FormatInt(start));
    identity = std.Concat(identity, ":length=");
    identity = std.Concat(identity, std.FormatInt(length));
    identity = std.Concat(identity, ":known_null=");
    identity = std.Concat(identity, std.FormatInt(data_known_null));
    identity = std.Concat(identity, ":lifetime=");
    identity = std.Concat(identity, lifetime_region);
    identity = std.Concat(identity, ":flow=");
    identity = std.Concat(identity, flow_origin);
    return std.Clone(ctx, identity);
}

func mir_array_slice_operation_identity(target_id: str, operation_name: str, kind: str, ctx: &Arena) str {
    mut identity := "array_slice_operation:v1:target=";
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":name=");
    identity = std.Concat(identity, operation_name);
    identity = std.Concat(identity, ":kind=");
    identity = std.Concat(identity, kind);
    return std.Clone(ctx, identity);
}

func mir_array_slice_make_array_layout(target_id: str, target_triple: str, array_type_id: str, element_type_id: str, element_layout_id: str, element_size: int, element_alignment: int, element_count: int, nesting_depth: int, ctx: &Arena) MirArrayLayout[ctx] {
    mut result: MirArrayLayout[ctx];
    result.array_type_id = std.Clone(ctx, array_type_id);
    result.target_id = std.Clone(ctx, target_id);
    result.target_triple = std.Clone(ctx, target_triple);
    result.element_type_id = std.Clone(ctx, element_type_id);
    result.element_layout_id = std.Clone(ctx, element_layout_id);
    result.element_count = element_count;
    result.element_stride = mir_array_slice_align_up(element_size, element_alignment);
    result.total_size = result.element_count * result.element_stride;
    result.alignment = element_alignment;
    result.nesting_depth = nesting_depth;
    result.representation_kind = std.Clone(ctx, "fixed_contiguous_compiler_stride");
    result.layout_id = mir_array_slice_array_layout_identity(
        result.target_id,
        result.array_type_id,
        result.element_layout_id,
        result.element_count,
        result.element_stride,
        result.total_size,
        result.alignment,
        ctx
    );
    return result;
}

func mir_array_slice_make_array_value(array_id: str, array_layout: MirArrayLayout[ctx], elements: Index[std.Vector[int, ctx], ctx], lifetime_region: str, ctx: &Arena) MirArrayValue[ctx] {
    mut result: MirArrayValue[ctx];
    result.array_id = std.Clone(ctx, array_id);
    result.array_layout_id = std.Clone(ctx, array_layout.layout_id);
    result.element_type_id = std.Clone(ctx, array_layout.element_type_id);
    result.elements = elements;
    result.lifetime_region = std.Clone(ctx, lifetime_region);
    return result;
}

func mir_array_slice_make_slice_layout(target_id: str, target_triple: str, slice_type_id: str, element_type_id: str, element_layout_id: str, pointer_size: int, pointer_alignment: int, ctx: &Arena) MirSliceLayout[ctx] {
    mut result: MirSliceLayout[ctx];
    result.slice_type_id = std.Clone(ctx, slice_type_id);
    result.target_id = std.Clone(ctx, target_id);
    result.target_triple = std.Clone(ctx, target_triple);
    result.element_type_id = std.Clone(ctx, element_type_id);
    result.element_layout_id = std.Clone(ctx, element_layout_id);
    result.pointer_size = pointer_size;
    result.pointer_alignment = pointer_alignment;
    result.size = pointer_size * 2;
    result.alignment = pointer_alignment;
    result.data_pointer_offset = 0;
    result.length_offset = pointer_size;
    result.length_type_id = std.Clone(ctx, "type:gust:usize");
    result.representation_kind = std.Clone(ctx, "data_pointer_and_usize_length");
    result.empty_representation = std.Clone(ctx, "null_pointer_with_zero_length");
    result.nullability_policy = std.Clone(ctx, "null_pointer_permitted_only_when_length_zero");
    result.lifetime_policy = std.Clone(ctx, "borrowed_slice_must_not_outlive_source_array");
    result.layout_id = mir_array_slice_slice_layout_identity(
        result.target_id,
        result.slice_type_id,
        result.element_layout_id,
        result.pointer_size,
        result.pointer_alignment,
        ctx
    );
    return result;
}

func mir_array_slice_make_slice(source_array: MirArrayValue[ctx], slice_layout: MirSliceLayout[ctx], start: int, length: int, data_known_null: int, lifetime_region: str, flow_origin: str, ctx: &Arena) MirSliceValue[ctx] {
    mut result: MirSliceValue[ctx];
    result.source_array_id = std.Clone(ctx, source_array.array_id);
    result.slice_layout_id = std.Clone(ctx, slice_layout.layout_id);
    result.element_type_id = std.Clone(ctx, slice_layout.element_type_id);
    result.start = start;
    result.length = length;
    result.data_known_null = data_known_null;
    result.lifetime_region = std.Clone(ctx, lifetime_region);
    result.source_lifetime_region = std.Clone(ctx, source_array.lifetime_region);
    result.flow_origin = std.Clone(ctx, flow_origin);
    result.slice_id = mir_array_slice_slice_identity(
        result.source_array_id,
        result.slice_layout_id,
        result.start,
        result.length,
        result.data_known_null,
        result.lifetime_region,
        result.flow_origin,
        ctx
    );
    return result;
}

func mir_array_slice_make_operation(table: MirArraySliceTable[ctx], operation_name: str, kind: str, array_id: str, slice_id: str, result_slice_id: str, element_type_id: str, index: int, start: int, length: int, stored_value: int, expected_value: int, expected_address_offset: int, expected_result_start: int, expected_result_length: int, ctx: &Arena) MirArraySliceOperation[ctx] {
    mut result: MirArraySliceOperation[ctx];
    result.operation_name = std.Clone(ctx, operation_name);
    result.target_id = std.Clone(ctx, table.target_id);
    result.kind = std.Clone(ctx, kind);
    result.array_id = std.Clone(ctx, array_id);
    result.slice_id = std.Clone(ctx, slice_id);
    result.result_slice_id = std.Clone(ctx, result_slice_id);
    result.element_type_id = std.Clone(ctx, element_type_id);
    result.index = index;
    result.start = start;
    result.length = length;
    result.stored_value = stored_value;
    result.expect_success = 1;
    result.expected_value = expected_value;
    result.expected_address_offset = expected_address_offset;
    result.expected_result_start = expected_result_start;
    result.expected_result_length = expected_result_length;
    result.expected_reason_code = std.Clone(ctx, "array_slice_valid");
    result.operation_id = mir_array_slice_operation_identity(
        result.target_id,
        result.operation_name,
        result.kind,
        ctx
    );
    return result;
}

func mir_array_slice_table_with_array_layout(table: MirArraySliceTable[ctx], value: MirArrayLayout[ctx], ctx: &Arena) MirArraySliceTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirArrayLayout[ctx], ctx] := ctx[updated.array_layouts];
    values.Push(value);
    ctx.Set(updated.array_layouts, values);
    return updated;
}

func mir_array_slice_table_with_array(table: MirArraySliceTable[ctx], value: MirArrayValue[ctx], ctx: &Arena) MirArraySliceTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirArrayValue[ctx], ctx] := ctx[updated.arrays];
    values.Push(value);
    ctx.Set(updated.arrays, values);
    return updated;
}

func mir_array_slice_table_with_slice_layout(table: MirArraySliceTable[ctx], value: MirSliceLayout[ctx], ctx: &Arena) MirArraySliceTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirSliceLayout[ctx], ctx] := ctx[updated.slice_layouts];
    values.Push(value);
    ctx.Set(updated.slice_layouts, values);
    return updated;
}

func mir_array_slice_table_with_slice(table: MirArraySliceTable[ctx], value: MirSliceValue[ctx], ctx: &Arena) MirArraySliceTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirSliceValue[ctx], ctx] := ctx[updated.slices];
    values.Push(value);
    ctx.Set(updated.slices, values);
    return updated;
}

func mir_array_slice_table_with_operation(table: MirArraySliceTable[ctx], value: MirArraySliceOperation[ctx], ctx: &Arena) MirArraySliceTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirArraySliceOperation[ctx], ctx] := ctx[updated.operations];
    values.Push(value);
    ctx.Set(updated.operations, values);
    return updated;
}

func mir_array_slice_array_layout(table: MirArraySliceTable[ctx], layout_id: str, ctx: &Arena) MirArrayLayoutQuery[ctx] {
    mut result: MirArrayLayoutQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirArrayLayout[ctx], ctx] := ctx[table.array_layouts];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].layout_id, layout_id) == 1 {
            result.found = 1;
            result.array_layout = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_array_slice_array(table: MirArraySliceTable[ctx], array_id: str, ctx: &Arena) MirArrayValueQuery[ctx] {
    mut result: MirArrayValueQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirArrayValue[ctx], ctx] := ctx[table.arrays];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].array_id, array_id) == 1 {
            result.found = 1;
            result.array_value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_array_slice_slice_layout(table: MirArraySliceTable[ctx], layout_id: str, ctx: &Arena) MirSliceLayoutQuery[ctx] {
    mut result: MirSliceLayoutQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirSliceLayout[ctx], ctx] := ctx[table.slice_layouts];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].layout_id, layout_id) == 1 {
            result.found = 1;
            result.slice_layout = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_array_slice_slice(table: MirArraySliceTable[ctx], slice_id: str, ctx: &Arena) MirSliceValueQuery[ctx] {
    mut result: MirSliceValueQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirSliceValue[ctx], ctx] := ctx[table.slices];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].slice_id, slice_id) == 1 {
            result.found = 1;
            result.slice_value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_array_slice_operation(table: MirArraySliceTable[ctx], operation_name: str, ctx: &Arena) MirArraySliceOperationQuery[ctx] {
    mut result: MirArraySliceOperationQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirArraySliceOperation[ctx], ctx] := ctx[table.operations];
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

func mir_array_slice_element_layout(table: MirArraySliceTable[ctx], layout_table: layout.MirLayoutTable[ctx], type_id: str, layout_id: str, ctx: &Arena) MirArraySliceElementLayoutQuery {
    mut result: MirArraySliceElementLayoutQuery;
    result.found = 0;
    mut base := layout.mir_layout_of(layout_table, type_id, layout_table.target.target_id, ctx);
    if base.found == 1 && std.str_eq(base.layout.layout_id, layout_id) == 1 {
        result.found = 1;
        result.size = base.layout.size;
        result.alignment = base.layout.alignment;
        return result;
    }
    mut nested := mir_array_slice_array_layout(table, layout_id, ctx);
    if nested.found == 1 && std.str_eq(nested.array_layout.array_type_id, type_id) == 1 {
        result.found = 1;
        result.size = nested.array_layout.total_size;
        result.alignment = nested.array_layout.alignment;
    }
    return result;
}

func mir_array_slice_evaluation(success: int, value: int, address_offset: int, result_start: int, result_length: int, reason_code: str, ctx: &Arena) MirArraySliceEvaluation[ctx] {
    mut result: MirArraySliceEvaluation[ctx];
    result.success = success;
    result.value = value;
    result.address_offset = address_offset;
    result.result_start = result_start;
    result.result_length = result_length;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_array_slice_rejection(kind: str, ctx: &Arena) MirArraySliceEvaluation[ctx] {
    if std.str_eq(kind, "count_overflow") == 1 {
        return mir_array_slice_evaluation(0, 0, 0, 0, 0, "array_count_overflow", ctx);
    }
    if std.str_eq(kind, "total_size_overflow") == 1 {
        return mir_array_slice_evaluation(0, 0, 0, 0, 0, "array_total_size_overflow", ctx);
    }
    if std.str_eq(kind, "invalid_stride") == 1 {
        return mir_array_slice_evaluation(0, 0, 0, 0, 0, "array_stride_mismatch", ctx);
    }
    if std.str_eq(kind, "out_of_bounds_access") == 1 {
        return mir_array_slice_evaluation(0, 0, 0, 0, 0, "array_slice_index_out_of_bounds", ctx);
    }
    if std.str_eq(kind, "wrong_element_type") == 1 {
        return mir_array_slice_evaluation(0, 0, 0, 0, 0, "array_slice_element_type_mismatch", ctx);
    }
    if std.str_eq(kind, "invalid_slice_pointer_length_pair") == 1 {
        return mir_array_slice_evaluation(0, 0, 0, 0, 0, "slice_null_nonempty", ctx);
    }
    if std.str_eq(kind, "lifetime_escape") == 1 {
        return mir_array_slice_evaluation(0, 0, 0, 0, 0, "slice_lifetime_escape", ctx);
    }
    return mir_array_slice_evaluation(0, 0, 0, 0, 0, "array_slice_request_invalid", ctx);
}

func mir_array_slice_evaluate(table: MirArraySliceTable[ctx], operation: MirArraySliceOperation[ctx], ctx: &Arena) MirArraySliceEvaluation[ctx] {
    if std.str_eq(operation.kind, "array_init") == 1 {
        mut array_query := mir_array_slice_array(table, operation.array_id, ctx);
        if array_query.found == 0 { return mir_array_slice_rejection("wrong_element_type", ctx); }
        mut elements: std.Vector[int, ctx] := ctx[array_query.array_value.elements];
        return mir_array_slice_evaluation(1, len(elements), 0, 0, len(elements), "array_slice_valid", ctx);
    }

    if std.str_eq(operation.kind, "element_address") == 1 ||
       std.str_eq(operation.kind, "element_load") == 1 ||
       std.str_eq(operation.kind, "element_store") == 1 ||
       std.str_eq(operation.kind, "array_to_slice") == 1
    {
        mut array_query := mir_array_slice_array(table, operation.array_id, ctx);
        if array_query.found == 0 { return mir_array_slice_rejection("wrong_element_type", ctx); }
        mut array_layout_query := mir_array_slice_array_layout(table, array_query.array_value.array_layout_id, ctx);
        if array_layout_query.found == 0 { return mir_array_slice_rejection("wrong_element_type", ctx); }
        mut array_layout := array_layout_query.array_layout;
        if std.str_eq(operation.element_type_id, array_layout.element_type_id) == 0 {
            return mir_array_slice_rejection("wrong_element_type", ctx);
        }
        if std.str_eq(operation.kind, "array_to_slice") == 1 {
            return mir_array_slice_evaluation(1, array_layout.element_count, 0, 0, array_layout.element_count, "array_slice_valid", ctx);
        }
        if operation.index < 0 || operation.index >= array_layout.element_count {
            return mir_array_slice_rejection("out_of_bounds_access", ctx);
        }
        mut offset := operation.index * array_layout.element_stride;
        if std.str_eq(operation.kind, "element_address") == 1 {
            return mir_array_slice_evaluation(1, offset, offset, 0, 0, "array_slice_valid", ctx);
        }
        if std.str_eq(operation.kind, "element_store") == 1 {
            return mir_array_slice_evaluation(1, operation.stored_value, offset, 0, 0, "array_slice_valid", ctx);
        }
        mut elements: std.Vector[int, ctx] := ctx[array_query.array_value.elements];
        return mir_array_slice_evaluation(1, elements[operation.index], offset, 0, 0, "array_slice_valid", ctx);
    }

    mut slice_query := mir_array_slice_slice(table, operation.slice_id, ctx);
    if slice_query.found == 0 { return mir_array_slice_rejection("invalid_slice_pointer_length_pair", ctx); }
    mut slice_value := slice_query.slice_value;
    if std.str_eq(operation.element_type_id, slice_value.element_type_id) == 0 {
        return mir_array_slice_rejection("wrong_element_type", ctx);
    }
    if std.str_eq(operation.kind, "slice_length") == 1 {
        return mir_array_slice_evaluation(1, slice_value.length, 0, slice_value.start, slice_value.length, "array_slice_valid", ctx);
    }
    if std.str_eq(operation.kind, "subslice") == 1 {
        if operation.start < 0 || operation.length < 0 || operation.start + operation.length > slice_value.length {
            return mir_array_slice_rejection("out_of_bounds_access", ctx);
        }
        return mir_array_slice_evaluation(1, operation.length, 0, slice_value.start + operation.start, operation.length, "array_slice_valid", ctx);
    }
    if std.str_eq(operation.kind, "bounded_index") == 1 {
        if operation.index < 0 || operation.index >= slice_value.length {
            return mir_array_slice_rejection("out_of_bounds_access", ctx);
        }
        mut array_query := mir_array_slice_array(table, slice_value.source_array_id, ctx);
        if array_query.found == 0 { return mir_array_slice_rejection("wrong_element_type", ctx); }
        mut array_layout_query := mir_array_slice_array_layout(table, array_query.array_value.array_layout_id, ctx);
        if array_layout_query.found == 0 { return mir_array_slice_rejection("wrong_element_type", ctx); }
        mut absolute_index := slice_value.start + operation.index;
        mut elements: std.Vector[int, ctx] := ctx[array_query.array_value.elements];
        return mir_array_slice_evaluation(
            1,
            elements[absolute_index],
            absolute_index * array_layout_query.array_layout.element_stride,
            slice_value.start,
            slice_value.length,
            "array_slice_valid",
            ctx
        );
    }
    return mir_array_slice_evaluation(0, 0, 0, 0, 0, "array_slice_operation_unsupported", ctx);
}

func mir_array_slice_table_is_valid(table: MirArraySliceTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if std.str_eq(table.format, "gust.compiler_array_slice_table.v1") == 0 { return 0; }
    if mir_array_slice_table_is_legacy_empty(table, ctx) == 1 { return 1; }
    if std.str_eq(table.target_id, layout_table.target.target_id) == 0 ||
       std.str_eq(table.target_triple, layout_table.target.target_triple) == 0 ||
       std.str_eq(table.bounds_policy, "checked_before_address_calculation") == 0 ||
       std.str_eq(table.empty_slice_policy, "null_pointer_with_zero_length") == 0 ||
       std.str_eq(table.stride_authority, "compiler_owned_element_stride_no_backend_inference") == 0 ||
       std.str_eq(table.lifetime_policy, "borrowed_slice_must_not_outlive_source_array") == 0 ||
       std.str_eq(table.variable_length_array_policy, "deferred_variable_length_stack_arrays") == 0 ||
       std.str_eq(table.unsized_storage_policy, "deferred_unsized_aggregate_storage") == 0
    {
        return 0;
    }

    mut array_layouts: std.Vector[MirArrayLayout[ctx], ctx] := ctx[table.array_layouts];
    mut arrays: std.Vector[MirArrayValue[ctx], ctx] := ctx[table.arrays];
    mut slice_layouts: std.Vector[MirSliceLayout[ctx], ctx] := ctx[table.slice_layouts];
    mut slices: std.Vector[MirSliceValue[ctx], ctx] := ctx[table.slices];
    mut operations: std.Vector[MirArraySliceOperation[ctx], ctx] := ctx[table.operations];
    if len(array_layouts) != 4 || len(arrays) != 4 || len(slice_layouts) != 2 || len(slices) != 5 || len(operations) != 17 {
        return 0;
    }

    mut layout_index := 0;
    while layout_index < len(array_layouts) {
        mut value := array_layouts[layout_index];
        mut element := mir_array_slice_element_layout(table, layout_table, value.element_type_id, value.element_layout_id, ctx);
        if element.found == 0 || value.element_count <= 0 || value.element_count > 1024 ||
           value.element_stride != mir_array_slice_align_up(element.size, element.alignment) ||
           value.total_size != value.element_count * value.element_stride ||
           value.alignment != element.alignment ||
           value.total_size <= 0 ||
           std.str_eq(value.target_id, table.target_id) == 0 ||
           std.str_eq(value.target_triple, table.target_triple) == 0 ||
           std.str_eq(value.representation_kind, "fixed_contiguous_compiler_stride") == 0
        {
            return 0;
        }
        mut expected_id := mir_array_slice_array_layout_identity(
            value.target_id,
            value.array_type_id,
            value.element_layout_id,
            value.element_count,
            value.element_stride,
            value.total_size,
            value.alignment,
            ctx
        );
        if std.str_eq(value.layout_id, expected_id) == 0 { return 0; }
        layout_index = layout_index + 1;
    }

    mut array_index := 0;
    while array_index < len(arrays) {
        mut value := arrays[array_index];
        mut array_layout := mir_array_slice_array_layout(table, value.array_layout_id, ctx);
        mut elements: std.Vector[int, ctx] := ctx[value.elements];
        if array_layout.found == 0 ||
           std.str_eq(value.element_type_id, array_layout.array_layout.element_type_id) == 0 ||
           len(elements) != array_layout.array_layout.element_count ||
           std.str_eq(value.lifetime_region, "function:main") == 0 ||
           mir_array_slice_field_is_safe(value.array_id, 0) == 0
        {
            return 0;
        }
        array_index = array_index + 1;
    }

    mut slice_layout_index := 0;
    while slice_layout_index < len(slice_layouts) {
        mut value := slice_layouts[slice_layout_index];
        mut element := mir_array_slice_element_layout(table, layout_table, value.element_type_id, value.element_layout_id, ctx);
        if element.found == 0 ||
           std.str_eq(value.target_id, table.target_id) == 0 ||
           std.str_eq(value.target_triple, table.target_triple) == 0 ||
           value.pointer_size != layout_table.target.pointer_size ||
           value.pointer_alignment != layout_table.target.pointer_alignment ||
           value.size != value.pointer_size * 2 ||
           value.alignment != value.pointer_alignment ||
           value.data_pointer_offset != 0 || value.length_offset != value.pointer_size ||
           std.str_eq(value.length_type_id, "type:gust:usize") == 0 ||
           std.str_eq(value.representation_kind, "data_pointer_and_usize_length") == 0 ||
           std.str_eq(value.empty_representation, "null_pointer_with_zero_length") == 0 ||
           std.str_eq(value.nullability_policy, "null_pointer_permitted_only_when_length_zero") == 0 ||
           std.str_eq(value.lifetime_policy, table.lifetime_policy) == 0
        {
            return 0;
        }
        mut expected_id := mir_array_slice_slice_layout_identity(
            value.target_id,
            value.slice_type_id,
            value.element_layout_id,
            value.pointer_size,
            value.pointer_alignment,
            ctx
        );
        if std.str_eq(value.layout_id, expected_id) == 0 { return 0; }
        slice_layout_index = slice_layout_index + 1;
    }

    mut slice_index := 0;
    while slice_index < len(slices) {
        mut value := slices[slice_index];
        mut source := mir_array_slice_array(table, value.source_array_id, ctx);
        mut slice_layout := mir_array_slice_slice_layout(table, value.slice_layout_id, ctx);
        mut source_elements: std.Vector[int, ctx] := ctx[source.array_value.elements];
        if source.found == 0 || slice_layout.found == 0 ||
           std.str_eq(value.element_type_id, slice_layout.slice_layout.element_type_id) == 0 ||
           std.str_eq(value.element_type_id, source.array_value.element_type_id) == 0 ||
           value.start < 0 || value.length < 0 ||
           value.start + value.length > len(source_elements) ||
           (value.data_known_null == 1 && value.length != 0) ||
           (value.length == 0 && value.data_known_null != 1) ||
           (value.length > 0 && value.data_known_null != 0) ||
           std.str_eq(value.lifetime_region, source.array_value.lifetime_region) == 0 ||
           std.str_eq(value.source_lifetime_region, source.array_value.lifetime_region) == 0
        {
            return 0;
        }
        mut expected_id := mir_array_slice_slice_identity(
            value.source_array_id,
            value.slice_layout_id,
            value.start,
            value.length,
            value.data_known_null,
            value.lifetime_region,
            value.flow_origin,
            ctx
        );
        if std.str_eq(value.slice_id, expected_id) == 0 { return 0; }
        slice_index = slice_index + 1;
    }

    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        if mir_array_slice_operation_kind_is_valid(operation.kind) == 0 ||
           std.str_eq(operation.target_id, table.target_id) == 0 ||
           operation.expect_success != 1 ||
           std.str_eq(operation.expected_reason_code, "array_slice_valid") == 0
        {
            return 0;
        }
        mut expected_id := mir_array_slice_operation_identity(
            operation.target_id,
            operation.operation_name,
            operation.kind,
            ctx
        );
        if std.str_eq(operation.operation_id, expected_id) == 0 { return 0; }
        mut evaluation := mir_array_slice_evaluate(table, operation, ctx);
        if evaluation.success != operation.expect_success ||
           evaluation.value != operation.expected_value ||
           evaluation.address_offset != operation.expected_address_offset ||
           evaluation.result_start != operation.expected_result_start ||
           evaluation.result_length != operation.expected_result_length ||
           std.str_eq(evaluation.reason_code, operation.expected_reason_code) == 0
        {
            return 0;
        }
        operation_index = operation_index + 1;
    }
    return 1;
}

func mir_array_slice_values1(a: int, ctx: &Arena) Index[std.Vector[int, ctx], ctx] {
    mut values := mir_array_slice_empty_int_vector(ctx);
    mut vector: std.Vector[int, ctx] := ctx[values];
    vector.Push(a);
    ctx.Set(values, vector);
    return values;
}

func mir_array_slice_values2(a: int, b: int, ctx: &Arena) Index[std.Vector[int, ctx], ctx] {
    mut values := mir_array_slice_empty_int_vector(ctx);
    mut vector: std.Vector[int, ctx] := ctx[values];
    vector.Push(a); vector.Push(b);
    ctx.Set(values, vector);
    return values;
}

func mir_array_slice_values3(a: int, b: int, c: int, ctx: &Arena) Index[std.Vector[int, ctx], ctx] {
    mut values := mir_array_slice_empty_int_vector(ctx);
    mut vector: std.Vector[int, ctx] := ctx[values];
    vector.Push(a); vector.Push(b); vector.Push(c);
    ctx.Set(values, vector);
    return values;
}

func mir_array_slice_values4(a: int, b: int, c: int, d: int, ctx: &Arena) Index[std.Vector[int, ctx], ctx] {
    mut values := mir_array_slice_empty_int_vector(ctx);
    mut vector: std.Vector[int, ctx] := ctx[values];
    vector.Push(a); vector.Push(b); vector.Push(c); vector.Push(d);
    ctx.Set(values, vector);
    return values;
}

func mir_array_slice_table_for_layout(layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) MirArraySliceTable[ctx] {
    mut table := mir_array_slice_make_empty_table(layout_table.target.target_triple, ctx);
    table.target_id = std.Clone(ctx, layout_table.target.target_id);

    mut i32_layout := layout.mir_layout_of(layout_table, "type:gust:i32", layout_table.target.target_id, ctx);
    mut u8_layout := layout.mir_layout_of(layout_table, "type:gust:u8", layout_table.target.target_id, ctx);

    mut i32_4_layout := mir_array_slice_make_array_layout(
        table.target_id, table.target_triple, "type:gust:array:i32:4",
        "type:gust:i32", i32_layout.layout.layout_id,
        i32_layout.layout.size, i32_layout.layout.alignment, 4, 1, ctx
    );
    mut u8_3_layout := mir_array_slice_make_array_layout(
        table.target_id, table.target_triple, "type:gust:array:u8:3",
        "type:gust:u8", u8_layout.layout.layout_id,
        u8_layout.layout.size, u8_layout.layout.alignment, 3, 1, ctx
    );
    mut i32_2_layout := mir_array_slice_make_array_layout(
        table.target_id, table.target_triple, "type:gust:array:i32:2",
        "type:gust:i32", i32_layout.layout.layout_id,
        i32_layout.layout.size, i32_layout.layout.alignment, 2, 1, ctx
    );
    mut nested_layout := mir_array_slice_make_array_layout(
        table.target_id, table.target_triple, "type:gust:array:array_i32_2:2",
        i32_2_layout.array_type_id, i32_2_layout.layout_id,
        i32_2_layout.total_size, i32_2_layout.alignment, 2, 2, ctx
    );
    table = mir_array_slice_table_with_array_layout(table, i32_4_layout, ctx);
    table = mir_array_slice_table_with_array_layout(table, u8_3_layout, ctx);
    table = mir_array_slice_table_with_array_layout(table, i32_2_layout, ctx);
    table = mir_array_slice_table_with_array_layout(table, nested_layout, ctx);

    mut i32_array := mir_array_slice_make_array_value(
        "array_i32_4", i32_4_layout, mir_array_slice_values4(11, 22, 33, 44, ctx), "function:main", ctx
    );
    mut u8_array := mir_array_slice_make_array_value(
        "array_u8_3", u8_3_layout, mir_array_slice_values3(97, 0, 98, ctx), "function:main", ctx
    );
    mut i32_2_array := mir_array_slice_make_array_value(
        "array_i32_2", i32_2_layout, mir_array_slice_values2(1, 2, ctx), "function:main", ctx
    );
    mut nested_array := mir_array_slice_make_array_value(
        "array_nested_i32_2x2", nested_layout, mir_array_slice_values2(1, 3, ctx), "function:main", ctx
    );
    table = mir_array_slice_table_with_array(table, i32_array, ctx);
    table = mir_array_slice_table_with_array(table, u8_array, ctx);
    table = mir_array_slice_table_with_array(table, i32_2_array, ctx);
    table = mir_array_slice_table_with_array(table, nested_array, ctx);

    mut i32_slice_layout := mir_array_slice_make_slice_layout(
        table.target_id, table.target_triple, "type:gust:slice:i32",
        "type:gust:i32", i32_layout.layout.layout_id,
        layout_table.target.pointer_size, layout_table.target.pointer_alignment, ctx
    );
    mut u8_slice_layout := mir_array_slice_make_slice_layout(
        table.target_id, table.target_triple, "type:gust:slice:u8",
        "type:gust:u8", u8_layout.layout.layout_id,
        layout_table.target.pointer_size, layout_table.target.pointer_alignment, ctx
    );
    table = mir_array_slice_table_with_slice_layout(table, i32_slice_layout, ctx);
    table = mir_array_slice_table_with_slice_layout(table, u8_slice_layout, ctx);

    mut full_i32 := mir_array_slice_make_slice(i32_array, i32_slice_layout, 0, 4, 0, "function:main", "direct", ctx);
    mut middle_i32 := mir_array_slice_make_slice(i32_array, i32_slice_layout, 1, 2, 0, "function:main", "subslice", ctx);
    mut empty_i32 := mir_array_slice_make_slice(i32_array, i32_slice_layout, 0, 0, 1, "function:main", "canonical_empty", ctx);
    mut joined_i32 := mir_array_slice_make_slice(i32_array, i32_slice_layout, 1, 2, 0, "function:main", "branch_join:block1:block2:block3", ctx);
    mut full_u8 := mir_array_slice_make_slice(u8_array, u8_slice_layout, 0, 3, 0, "function:main", "direct", ctx);
    table = mir_array_slice_table_with_slice(table, full_i32, ctx);
    table = mir_array_slice_table_with_slice(table, middle_i32, ctx);
    table = mir_array_slice_table_with_slice(table, empty_i32, ctx);
    table = mir_array_slice_table_with_slice(table, joined_i32, ctx);
    table = mir_array_slice_table_with_slice(table, full_u8, ctx);

    table = mir_array_slice_table_with_operation(table, mir_array_slice_make_operation(table, "array_init_i32_4", "array_init", i32_array.array_id, "", "", "type:gust:i32", 0, 0, 0, 0, 4, 0, 0, 4, ctx), ctx);
    table = mir_array_slice_table_with_operation(table, mir_array_slice_make_operation(table, "address_i32_first", "element_address", i32_array.array_id, "", "", "type:gust:i32", 0, 0, 0, 0, 0, 0, 0, 0, ctx), ctx);
    table = mir_array_slice_table_with_operation(table, mir_array_slice_make_operation(table, "address_i32_middle", "element_address", i32_array.array_id, "", "", "type:gust:i32", 2, 0, 0, 0, 8, 8, 0, 0, ctx), ctx);
    table = mir_array_slice_table_with_operation(table, mir_array_slice_make_operation(table, "address_i32_last", "element_address", i32_array.array_id, "", "", "type:gust:i32", 3, 0, 0, 0, 12, 12, 0, 0, ctx), ctx);
    table = mir_array_slice_table_with_operation(table, mir_array_slice_make_operation(table, "load_i32_first", "element_load", i32_array.array_id, "", "", "type:gust:i32", 0, 0, 0, 0, 11, 0, 0, 0, ctx), ctx);
    table = mir_array_slice_table_with_operation(table, mir_array_slice_make_operation(table, "load_i32_middle", "element_load", i32_array.array_id, "", "", "type:gust:i32", 2, 0, 0, 0, 33, 8, 0, 0, ctx), ctx);
    table = mir_array_slice_table_with_operation(table, mir_array_slice_make_operation(table, "load_i32_last", "element_load", i32_array.array_id, "", "", "type:gust:i32", 3, 0, 0, 0, 44, 12, 0, 0, ctx), ctx);
    table = mir_array_slice_table_with_operation(table, mir_array_slice_make_operation(table, "store_i32_middle", "element_store", i32_array.array_id, "", "", "type:gust:i32", 1, 0, 0, 29, 29, 4, 0, 0, ctx), ctx);
    table = mir_array_slice_table_with_operation(table, mir_array_slice_make_operation(table, "array_to_slice_i32", "array_to_slice", i32_array.array_id, "", full_i32.slice_id, "type:gust:i32", 0, 0, 4, 0, 4, 0, 0, 4, ctx), ctx);
    table = mir_array_slice_table_with_operation(table, mir_array_slice_make_operation(table, "slice_length_i32", "slice_length", "", full_i32.slice_id, "", "type:gust:i32", 0, 0, 0, 0, 4, 0, 0, 4, ctx), ctx);
    table = mir_array_slice_table_with_operation(table, mir_array_slice_make_operation(table, "slice_index_i32_middle", "bounded_index", "", full_i32.slice_id, "", "type:gust:i32", 2, 0, 0, 0, 33, 8, 0, 4, ctx), ctx);
    table = mir_array_slice_table_with_operation(table, mir_array_slice_make_operation(table, "subslice_i32_1_2", "subslice", "", full_i32.slice_id, middle_i32.slice_id, "type:gust:i32", 0, 1, 2, 0, 2, 0, 1, 2, ctx), ctx);
    table = mir_array_slice_table_with_operation(table, mir_array_slice_make_operation(table, "slice_length_empty", "slice_length", "", empty_i32.slice_id, "", "type:gust:i32", 0, 0, 0, 0, 0, 0, 0, 0, ctx), ctx);
    table = mir_array_slice_table_with_operation(table, mir_array_slice_make_operation(table, "nested_address_second", "element_address", nested_array.array_id, "", "", nested_layout.element_type_id, 1, 0, 0, 0, 8, 8, 0, 0, ctx), ctx);
    table = mir_array_slice_table_with_operation(table, mir_array_slice_make_operation(table, "branch_join_index", "bounded_index", "", joined_i32.slice_id, "", "type:gust:i32", 1, 0, 0, 0, 33, 8, 1, 2, ctx), ctx);
    table = mir_array_slice_table_with_operation(table, mir_array_slice_make_operation(table, "slice_index_u8_middle", "bounded_index", "", full_u8.slice_id, "", "type:gust:u8", 1, 0, 0, 0, 0, 1, 0, 3, ctx), ctx);
    table = mir_array_slice_table_with_operation(table, mir_array_slice_make_operation(table, "address_u8_last", "element_address", u8_array.array_id, "", "", "type:gust:u8", 2, 0, 0, 0, 2, 2, 0, 0, ctx), ctx);
    return table;
}

func mir_array_slice_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut updated := std.Concat(output, key);
    updated = std.Concat(updated, ": ");
    updated = std.Concat(updated, value);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

func mir_serialize_array_slice_table_for_request(table: MirArraySliceTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_array_slice_table_is_legacy_empty(table, ctx) == 1 {
        return "array_slice_table_format: gust.compiler_array_slice_table.v1\narray_slice_target_id: \narray_slice_target_triple: legacy-empty\narray_slice_array_layout_count: 0\narray_slice_array_count: 0\narray_slice_slice_layout_count: 0\narray_slice_slice_count: 0\narray_slice_operation_count: 0\n";
    }
    if mir_array_slice_table_is_valid(table, layout_table, ctx) == 0 {
        return "array_slice_table_format: invalid\n";
    }
    mut output := "";
    output = mir_array_slice_append_field(output, "array_slice_table_format", table.format, ctx);
    output = mir_array_slice_append_field(output, "array_slice_target_id", table.target_id, ctx);
    output = mir_array_slice_append_field(output, "array_slice_target_triple", table.target_triple, ctx);
    output = mir_array_slice_append_field(output, "array_slice_bounds_policy", table.bounds_policy, ctx);
    output = mir_array_slice_append_field(output, "array_slice_empty_slice_policy", table.empty_slice_policy, ctx);
    output = mir_array_slice_append_field(output, "array_slice_stride_authority", table.stride_authority, ctx);
    output = mir_array_slice_append_field(output, "array_slice_lifetime_policy", table.lifetime_policy, ctx);
    output = mir_array_slice_append_field(output, "array_slice_variable_length_array_policy", table.variable_length_array_policy, ctx);
    output = mir_array_slice_append_field(output, "array_slice_unsized_storage_policy", table.unsized_storage_policy, ctx);

    mut array_layouts: std.Vector[MirArrayLayout[ctx], ctx] := ctx[table.array_layouts];
    output = mir_array_slice_append_field(output, "array_slice_array_layout_count", std.FormatInt(len(array_layouts)), ctx);
    mut array_layout_index := 0;
    while array_layout_index < len(array_layouts) {
        mut prefix := std.Concat("array_layout_", std.FormatInt(array_layout_index));
        mut value := array_layouts[array_layout_index];
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_id"), value.layout_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_type_id"), value.array_type_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_target_id"), value.target_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_element_type_id"), value.element_type_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_element_layout_id"), value.element_layout_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_element_count"), std.FormatInt(value.element_count), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_element_stride"), std.FormatInt(value.element_stride), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_total_size"), std.FormatInt(value.total_size), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_alignment"), std.FormatInt(value.alignment), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_nesting_depth"), std.FormatInt(value.nesting_depth), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_representation_kind"), value.representation_kind, ctx);
        array_layout_index = array_layout_index + 1;
    }

    mut arrays: std.Vector[MirArrayValue[ctx], ctx] := ctx[table.arrays];
    output = mir_array_slice_append_field(output, "array_slice_array_count", std.FormatInt(len(arrays)), ctx);
    mut array_index := 0;
    while array_index < len(arrays) {
        mut prefix := std.Concat("array_", std.FormatInt(array_index));
        mut value := arrays[array_index];
        mut elements: std.Vector[int, ctx] := ctx[value.elements];
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_id"), value.array_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_layout_id"), value.array_layout_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_element_type_id"), value.element_type_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_element_count"), std.FormatInt(len(elements)), ctx);
        mut element_index := 0;
        while element_index < len(elements) {
            mut element_key := std.Concat(prefix, std.Concat("_element_", std.FormatInt(element_index)));
            output = mir_array_slice_append_field(output, std.Concat(element_key, "_value"), std.FormatInt(elements[element_index]), ctx);
            element_index = element_index + 1;
        }
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_lifetime_region"), value.lifetime_region, ctx);
        array_index = array_index + 1;
    }

    mut slice_layouts: std.Vector[MirSliceLayout[ctx], ctx] := ctx[table.slice_layouts];
    output = mir_array_slice_append_field(output, "array_slice_slice_layout_count", std.FormatInt(len(slice_layouts)), ctx);
    mut slice_layout_index := 0;
    while slice_layout_index < len(slice_layouts) {
        mut prefix := std.Concat("slice_layout_", std.FormatInt(slice_layout_index));
        mut value := slice_layouts[slice_layout_index];
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_id"), value.layout_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_type_id"), value.slice_type_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_target_id"), value.target_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_element_type_id"), value.element_type_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_element_layout_id"), value.element_layout_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_pointer_size"), std.FormatInt(value.pointer_size), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_pointer_alignment"), std.FormatInt(value.pointer_alignment), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_size"), std.FormatInt(value.size), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_alignment"), std.FormatInt(value.alignment), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_data_pointer_offset"), std.FormatInt(value.data_pointer_offset), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_length_offset"), std.FormatInt(value.length_offset), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_length_type_id"), value.length_type_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_representation_kind"), value.representation_kind, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_empty_representation"), value.empty_representation, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_nullability_policy"), value.nullability_policy, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_lifetime_policy"), value.lifetime_policy, ctx);
        slice_layout_index = slice_layout_index + 1;
    }

    mut slices: std.Vector[MirSliceValue[ctx], ctx] := ctx[table.slices];
    output = mir_array_slice_append_field(output, "array_slice_slice_count", std.FormatInt(len(slices)), ctx);
    mut slice_index := 0;
    while slice_index < len(slices) {
        mut prefix := std.Concat("slice_", std.FormatInt(slice_index));
        mut value := slices[slice_index];
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_id"), value.slice_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_source_array_id"), value.source_array_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_layout_id"), value.slice_layout_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_element_type_id"), value.element_type_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_start"), std.FormatInt(value.start), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_length"), std.FormatInt(value.length), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_data_known_null"), std.FormatInt(value.data_known_null), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_lifetime_region"), value.lifetime_region, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_source_lifetime_region"), value.source_lifetime_region, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_flow_origin"), value.flow_origin, ctx);
        slice_index = slice_index + 1;
    }

    mut operations: std.Vector[MirArraySliceOperation[ctx], ctx] := ctx[table.operations];
    output = mir_array_slice_append_field(output, "array_slice_operation_count", std.FormatInt(len(operations)), ctx);
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut prefix := std.Concat("array_slice_operation_", std.FormatInt(operation_index));
        mut value := operations[operation_index];
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_id"), value.operation_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_name"), value.operation_name, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_target_id"), value.target_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_kind"), value.kind, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_array_id"), value.array_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_slice_id"), value.slice_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_result_slice_id"), value.result_slice_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_element_type_id"), value.element_type_id, ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_index"), std.FormatInt(value.index), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_start"), std.FormatInt(value.start), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_length"), std.FormatInt(value.length), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_stored_value"), std.FormatInt(value.stored_value), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_expect_success"), std.FormatInt(value.expect_success), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_expected_value"), std.FormatInt(value.expected_value), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_expected_address_offset"), std.FormatInt(value.expected_address_offset), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_expected_result_start"), std.FormatInt(value.expected_result_start), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_expected_result_length"), std.FormatInt(value.expected_result_length), ctx);
        output = mir_array_slice_append_field(output, std.Concat(prefix, "_expected_reason_code"), value.expected_reason_code, ctx);
        operation_index = operation_index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_array_slice_witness(table: MirArraySliceTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_array_slice_table_is_valid(table, layout_table, ctx) == 0 ||
       mir_array_slice_table_is_legacy_empty(table, ctx) == 1
    {
        return "";
    }
    mut output := "array_slice_status: valid\n";
    output = mir_array_slice_append_field(output, "array_slice_target", table.target_triple, ctx);
    output = mir_array_slice_append_field(output, "array_slice_target_id", table.target_id, ctx);
    output = mir_array_slice_append_field(output, "array_slice_bounds_policy", table.bounds_policy, ctx);
    output = mir_array_slice_append_field(output, "array_slice_empty_slice_policy", table.empty_slice_policy, ctx);
    output = mir_array_slice_append_field(output, "array_slice_stride_authority", table.stride_authority, ctx);
    output = mir_array_slice_append_field(output, "array_slice_lifetime_policy", table.lifetime_policy, ctx);

    mut array_layouts: std.Vector[MirArrayLayout[ctx], ctx] := ctx[table.array_layouts];
    mut array_layout_index := 0;
    while array_layout_index < len(array_layouts) {
        mut value := array_layouts[array_layout_index];
        mut line := "array_layout: ";
        line = std.Concat(line, value.layout_id);
        line = std.Concat(line, " type="); line = std.Concat(line, value.array_type_id);
        line = std.Concat(line, " element_type="); line = std.Concat(line, value.element_type_id);
        line = std.Concat(line, " element_layout="); line = std.Concat(line, value.element_layout_id);
        line = std.Concat(line, " count="); line = std.Concat(line, std.FormatInt(value.element_count));
        line = std.Concat(line, " stride="); line = std.Concat(line, std.FormatInt(value.element_stride));
        line = std.Concat(line, " size="); line = std.Concat(line, std.FormatInt(value.total_size));
        line = std.Concat(line, " alignment="); line = std.Concat(line, std.FormatInt(value.alignment));
        line = std.Concat(line, " nesting="); line = std.Concat(line, std.FormatInt(value.nesting_depth));
        line = std.Concat(line, "\n");
        output = std.Concat(output, line);
        array_layout_index = array_layout_index + 1;
    }

    mut slice_layouts: std.Vector[MirSliceLayout[ctx], ctx] := ctx[table.slice_layouts];
    mut slice_layout_index := 0;
    while slice_layout_index < len(slice_layouts) {
        mut value := slice_layouts[slice_layout_index];
        mut line := "slice_layout: ";
        line = std.Concat(line, value.layout_id);
        line = std.Concat(line, " type="); line = std.Concat(line, value.slice_type_id);
        line = std.Concat(line, " element_type="); line = std.Concat(line, value.element_type_id);
        line = std.Concat(line, " size="); line = std.Concat(line, std.FormatInt(value.size));
        line = std.Concat(line, " alignment="); line = std.Concat(line, std.FormatInt(value.alignment));
        line = std.Concat(line, " data_offset="); line = std.Concat(line, std.FormatInt(value.data_pointer_offset));
        line = std.Concat(line, " length_offset="); line = std.Concat(line, std.FormatInt(value.length_offset));
        line = std.Concat(line, "\n");
        output = std.Concat(output, line);
        slice_layout_index = slice_layout_index + 1;
    }

    mut slices: std.Vector[MirSliceValue[ctx], ctx] := ctx[table.slices];
    mut slice_index := 0;
    while slice_index < len(slices) {
        mut value := slices[slice_index];
        mut line := "slice: ";
        line = std.Concat(line, value.slice_id);
        line = std.Concat(line, " source="); line = std.Concat(line, value.source_array_id);
        line = std.Concat(line, " start="); line = std.Concat(line, std.FormatInt(value.start));
        line = std.Concat(line, " length="); line = std.Concat(line, std.FormatInt(value.length));
        line = std.Concat(line, " known_null="); line = std.Concat(line, std.FormatInt(value.data_known_null));
        line = std.Concat(line, " lifetime="); line = std.Concat(line, value.lifetime_region);
        line = std.Concat(line, " flow="); line = std.Concat(line, value.flow_origin);
        line = std.Concat(line, "\n");
        output = std.Concat(output, line);
        slice_index = slice_index + 1;
    }

    mut operations: std.Vector[MirArraySliceOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        mut evaluation := mir_array_slice_evaluate(table, operation, ctx);
        mut line := "array_slice_operation: ";
        line = std.Concat(line, operation.operation_name);
        line = std.Concat(line, " kind="); line = std.Concat(line, operation.kind);
        line = std.Concat(line, " status=");
        if evaluation.success == 1 { line = std.Concat(line, "success"); }
        else { line = std.Concat(line, "failure"); }
        line = std.Concat(line, " value="); line = std.Concat(line, std.FormatInt(evaluation.value));
        line = std.Concat(line, " address_offset="); line = std.Concat(line, std.FormatInt(evaluation.address_offset));
        line = std.Concat(line, " result_start="); line = std.Concat(line, std.FormatInt(evaluation.result_start));
        line = std.Concat(line, " result_length="); line = std.Concat(line, std.FormatInt(evaluation.result_length));
        line = std.Concat(line, " reason="); line = std.Concat(line, evaluation.reason_code);
        line = std.Concat(line, "\n");
        output = std.Concat(output, line);
        operation_index = operation_index + 1;
    }
    return std.Clone(ctx, output);
}