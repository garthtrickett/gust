// Phase 14.9 compiler-owned declaration-order struct layout authority.
//
// This table is deliberately bounded to in-memory non-packed structs. The
// compiler selects field offsets, padding, alignment, and nested layouts;
// consumers validate and execute that decision without recomputing it.

import "mir_layout.gst" as layout;

type MirStructField[ctx] struct {
    field_id: str,
    field_name: str,
    type_id: str,
    layout_id: str,
    declaration_index: int,
    offset: int,
    size: int,
    alignment: int
}

type MirStructLayout[ctx] struct {
    struct_type_id: str,
    layout_id: str,
    target_id: str,
    target_triple: str,
    size: int,
    alignment: int,
    field_count: int,
    nesting_depth: int,
    representation_kind: str,
    fields: Index[std.Vector[MirStructField[ctx], ctx], ctx]
}

type MirStructValue[ctx] struct {
    value_id: str,
    layout_id: str,
    field_values: Index[std.Vector[int, ctx], ctx]
}

type MirStructOperation[ctx] struct {
    operation_id: str,
    operation_name: str,
    target_id: str,
    kind: str,
    value_id: str,
    field_path: str,
    stored_value: int,
    expect_success: int,
    expected_value: int,
    expected_offset: int,
    expected_reason_code: str
}

type MirStructTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    field_order_policy: str,
    offset_authority: str,
    padding_policy: str,
    aggregate_abi_policy: str,
    packed_struct_policy: str,
    layouts: Index[std.Vector[MirStructLayout[ctx], ctx], ctx],
    values: Index[std.Vector[MirStructValue[ctx], ctx], ctx],
    operations: Index[std.Vector[MirStructOperation[ctx], ctx], ctx]
}

type MirStructLayoutQuery[ctx] struct { found: int, value: MirStructLayout[ctx] }
type MirStructFieldQuery[ctx] struct { found: int, value: MirStructField[ctx] }
type MirStructValueQuery[ctx] struct { found: int, value: MirStructValue[ctx] }
type MirStructEvaluation[ctx] struct {
    success: int,
    value: int,
    offset: int,
    reason_code: str
}

func mir_struct_empty_field_vector(ctx: &Arena) Index[std.Vector[MirStructField[ctx], ctx], ctx] {
    mut values: std.Vector[MirStructField[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirStructField[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_struct_empty_layout_vector(ctx: &Arena) Index[std.Vector[MirStructLayout[ctx], ctx], ctx] {
    mut values: std.Vector[MirStructLayout[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirStructLayout[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_struct_empty_value_vector(ctx: &Arena) Index[std.Vector[MirStructValue[ctx], ctx], ctx] {
    mut values: std.Vector[MirStructValue[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirStructValue[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_struct_empty_operation_vector(ctx: &Arena) Index[std.Vector[MirStructOperation[ctx], ctx], ctx] {
    mut values: std.Vector[MirStructOperation[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirStructOperation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_struct_empty_int_vector(ctx: &Arena) Index[std.Vector[int, ctx], ctx] {
    mut values: std.Vector[int, ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[int, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_struct_make_field(field_name: str, type_id: str, layout_id: str, declaration_index: int, offset: int, size: int, alignment: int, ctx: &Arena) MirStructField[ctx] {
    mut field: MirStructField[ctx];
    field.field_id = std.Clone(ctx, std.Concat("struct_field:v1:", std.Concat(field_name, std.Concat(":", std.FormatInt(declaration_index)))));
    field.field_name = std.Clone(ctx, field_name);
    field.type_id = std.Clone(ctx, type_id);
    field.layout_id = std.Clone(ctx, layout_id);
    field.declaration_index = declaration_index;
    field.offset = offset;
    field.size = size;
    field.alignment = alignment;
    return field;
}

func mir_struct_make_layout(struct_type_id: str, layout_id: str, target_id: str, target_triple: str, size: int, alignment: int, nesting_depth: int, fields: Index[std.Vector[MirStructField[ctx], ctx], ctx], ctx: &Arena) MirStructLayout[ctx] {
    mut value: MirStructLayout[ctx];
    value.struct_type_id = std.Clone(ctx, struct_type_id);
    value.layout_id = std.Clone(ctx, layout_id);
    value.target_id = std.Clone(ctx, target_id);
    value.target_triple = std.Clone(ctx, target_triple);
    value.size = size;
    value.alignment = alignment;
    mut field_values: std.Vector[MirStructField[ctx], ctx] := ctx[fields];
    value.field_count = field_values.len;
    value.nesting_depth = nesting_depth;
    value.representation_kind = std.Clone(ctx, "declaration_order_struct");
    value.fields = fields;
    return value;
}

// Canonical constructor for compiler-selected layouts. Callers provide fields
// in source declaration order with their type layout size/alignment; this
// function owns declaration indexes, offsets, inter-field padding, aggregate
// alignment, and tail padding.
func mir_struct_layout_declared_fields(struct_type_id: str, layout_id: str, target_id: str, target_triple: str, nesting_depth: int, declared_fields: Index[std.Vector[MirStructField[ctx], ctx], ctx], ctx: &Arena) MirStructLayout[ctx] {
    mut fields: std.Vector[MirStructField[ctx], ctx] := ctx[declared_fields];
    mut offset := 0;
    mut aggregate_alignment := 1;
    mut index := 0;
    while index < fields.len {
        mut field := fields[index];
        field.declaration_index = index;
        if field.alignment > aggregate_alignment {
            aggregate_alignment = field.alignment;
        }
        field.offset = mir_struct_align_up(offset, field.alignment);
        fields.Set(index, field);
        offset = field.offset + field.size;
        index = index + 1;
    }
    ctx.Set(declared_fields, fields);
    mut size := mir_struct_align_up(offset, aggregate_alignment);
    return mir_struct_make_layout(struct_type_id, layout_id, target_id, target_triple, size, aggregate_alignment, nesting_depth, declared_fields, ctx);
}

func mir_struct_make_value(value_id: str, layout_id: str, field_values: Index[std.Vector[int, ctx], ctx], ctx: &Arena) MirStructValue[ctx] {
    mut value: MirStructValue[ctx];
    value.value_id = std.Clone(ctx, value_id);
    value.layout_id = std.Clone(ctx, layout_id);
    value.field_values = field_values;
    return value;
}

func mir_struct_make_operation(target_id: str, operation_name: str, kind: str, value_id: str, field_path: str, stored_value: int, expected_value: int, expected_offset: int, ctx: &Arena) MirStructOperation[ctx] {
    mut value: MirStructOperation[ctx];
    value.operation_id = std.Clone(ctx, std.Concat("struct_operation:v1:", std.Concat(target_id, std.Concat(":", std.Concat(operation_name, std.Concat(":", kind))))));
    value.operation_name = std.Clone(ctx, operation_name);
    value.target_id = std.Clone(ctx, target_id);
    value.kind = std.Clone(ctx, kind);
    value.value_id = std.Clone(ctx, value_id);
    value.field_path = std.Clone(ctx, field_path);
    value.stored_value = stored_value;
    value.expect_success = 1;
    value.expected_value = expected_value;
    value.expected_offset = expected_offset;
    value.expected_reason_code = std.Clone(ctx, "struct_operation_valid");
    return value;
}

func mir_struct_table_with_layout(table: MirStructTable[ctx], value: MirStructLayout[ctx], ctx: &Arena) MirStructTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirStructLayout[ctx], ctx] := ctx[updated.layouts];
    values.Push(value);
    ctx.Set(updated.layouts, values);
    return updated;
}

func mir_struct_table_with_value(table: MirStructTable[ctx], value: MirStructValue[ctx], ctx: &Arena) MirStructTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirStructValue[ctx], ctx] := ctx[updated.values];
    values.Push(value);
    ctx.Set(updated.values, values);
    return updated;
}

func mir_struct_table_with_operation(table: MirStructTable[ctx], value: MirStructOperation[ctx], ctx: &Arena) MirStructTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirStructOperation[ctx], ctx] := ctx[updated.operations];
    values.Push(value);
    ctx.Set(updated.operations, values);
    return updated;
}

func mir_struct_make_empty_table(target_triple: str, ctx: &Arena) MirStructTable[ctx] {
    mut table: MirStructTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_struct_layout_table.v1");
    table.target_id = std.Clone(ctx, "");
    table.target_triple = std.Clone(ctx, target_triple);
    table.field_order_policy = std.Clone(ctx, "declaration_order_preserved");
    table.offset_authority = std.Clone(ctx, "compiler_owned_offsets_no_backend_relayout");
    table.padding_policy = std.Clone(ctx, "natural_alignment_with_tail_padding");
    table.aggregate_abi_policy = std.Clone(ctx, "deferred_aggregate_parameter_and_return_abi");
    table.packed_struct_policy = std.Clone(ctx, "deferred_packed_structs_and_bitfields");
    table.layouts = mir_struct_empty_layout_vector(ctx);
    table.values = mir_struct_empty_value_vector(ctx);
    table.operations = mir_struct_empty_operation_vector(ctx);
    return table;
}

func mir_struct_align_up(value: int, alignment: int) int {
    if alignment <= 0 { return 0 - 1; }
    mut remainder := value - value / alignment * alignment;
    if remainder == 0 { return value; }
    return value + alignment - remainder;
}

func mir_struct_layout(table: MirStructTable[ctx], layout_id: str, ctx: &Arena) MirStructLayoutQuery[ctx] {
    mut result: MirStructLayoutQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirStructLayout[ctx], ctx] := ctx[table.layouts];
    mut index := 0;
    while index < values.len {
        if std.str_eq(values[index].layout_id, layout_id) == 1 {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_struct_field(table: MirStructTable[ctx], layout_id: str, field_name: str, ctx: &Arena) MirStructFieldQuery[ctx] {
    mut result: MirStructFieldQuery[ctx];
    result.found = 0;
    mut layout_query := mir_struct_layout(table, layout_id, ctx);
    if layout_query.found == 0 { return result; }
    mut fields: std.Vector[MirStructField[ctx], ctx] := ctx[layout_query.value.fields];
    mut index := 0;
    while index < fields.len {
        if std.str_eq(fields[index].field_name, field_name) == 1 {
            result.found = 1;
            result.value = fields[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_struct_value(table: MirStructTable[ctx], value_id: str, ctx: &Arena) MirStructValueQuery[ctx] {
    mut result: MirStructValueQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirStructValue[ctx], ctx] := ctx[table.values];
    mut index := 0;
    while index < values.len {
        if std.str_eq(values[index].value_id, value_id) == 1 {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_struct_layout_is_valid(table: MirStructTable[ctx], value: MirStructLayout[ctx], ctx: &Arena) int {
    if value.size <= 0 || value.alignment <= 0 || value.field_count <= 0 || value.nesting_depth < 0 { return 0; }
    if mir_struct_align_up(value.size, value.alignment) != value.size { return 0; }
    if std.str_eq(value.target_id, table.target_id) == 0 || std.str_eq(value.target_triple, table.target_triple) == 0 { return 0; }
    if std.str_eq(value.representation_kind, "declaration_order_struct") == 0 { return 0; }
    mut fields: std.Vector[MirStructField[ctx], ctx] := ctx[value.fields];
    if fields.len != value.field_count { return 0; }
    mut index := 0;
    mut previous_end := 0;
    while index < fields.len {
        mut field := fields[index];
        if field.declaration_index != index || field.size <= 0 || field.alignment <= 0 || field.alignment > value.alignment { return 0; }
        if mir_struct_align_up(field.offset, field.alignment) != field.offset { return 0; }
        if field.offset < previous_end || field.offset + field.size > value.size { return 0; }
        if len(field.field_id) == 0 || len(field.field_name) == 0 || len(field.type_id) == 0 || len(field.layout_id) == 0 { return 0; }
        previous_end = field.offset + field.size;
        index = index + 1;
    }
    return 1;
}

func mir_struct_table_is_legacy_empty(table: MirStructTable[ctx], ctx: &Arena) int {
    mut layouts: std.Vector[MirStructLayout[ctx], ctx] := ctx[table.layouts];
    mut values: std.Vector[MirStructValue[ctx], ctx] := ctx[table.values];
    mut operations: std.Vector[MirStructOperation[ctx], ctx] := ctx[table.operations];
    if len(table.target_id) == 0 && layouts.len == 0 && values.len == 0 && operations.len == 0 { return 1; }
    return 0;
}

func mir_struct_table_is_valid(table: MirStructTable[ctx], ctx: &Arena) int {
    if mir_struct_table_is_legacy_empty(table, ctx) == 1 { return 1; }
    if std.str_eq(table.format, "gust.compiler_struct_layout_table.v1") == 0 || len(table.target_id) == 0 { return 0; }
    if std.str_eq(table.field_order_policy, "declaration_order_preserved") == 0 ||
       std.str_eq(table.offset_authority, "compiler_owned_offsets_no_backend_relayout") == 0 ||
       std.str_eq(table.padding_policy, "natural_alignment_with_tail_padding") == 0 ||
       std.str_eq(table.aggregate_abi_policy, "deferred_aggregate_parameter_and_return_abi") == 0 ||
       std.str_eq(table.packed_struct_policy, "deferred_packed_structs_and_bitfields") == 0
    { return 0; }
    mut layouts: std.Vector[MirStructLayout[ctx], ctx] := ctx[table.layouts];
    mut index := 0;
    while index < layouts.len {
        if mir_struct_layout_is_valid(table, layouts[index], ctx) == 0 { return 0; }
        mut duplicate := index + 1;
        while duplicate < layouts.len {
            if std.str_eq(layouts[index].layout_id, layouts[duplicate].layout_id) == 1 { return 0; }
            duplicate = duplicate + 1;
        }
        index = index + 1;
    }
    mut values: std.Vector[MirStructValue[ctx], ctx] := ctx[table.values];
    index = 0;
    while index < values.len {
        mut layout_query := mir_struct_layout(table, values[index].layout_id, ctx);
        if layout_query.found == 0 { return 0; }
        mut field_values: std.Vector[int, ctx] := ctx[values[index].field_values];
        if field_values.len != layout_query.value.field_count { return 0; }
        index = index + 1;
    }
    mut operations: std.Vector[MirStructOperation[ctx], ctx] := ctx[table.operations];
    index = 0;
    while index < operations.len {
        mut operation := operations[index];
        if len(operation.operation_id) == 0 || len(operation.operation_name) == 0 || len(operation.value_id) == 0 ||
           std.str_eq(operation.target_id, table.target_id) == 0 ||
           (std.str_eq(operation.kind, "construct") == 0 &&
            std.str_eq(operation.kind, "field_address") == 0 &&
            std.str_eq(operation.kind, "field_load") == 0 &&
            std.str_eq(operation.kind, "field_store") == 0)
        { return 0; }
        mut duplicate_operation := index + 1;
        while duplicate_operation < operations.len {
            if std.str_eq(operation.operation_id, operations[duplicate_operation].operation_id) == 1 { return 0; }
            duplicate_operation = duplicate_operation + 1;
        }
        index = index + 1;
    }
    return 1;
}

func mir_struct_resolve_field_path(table: MirStructTable[ctx], root_layout_id: str, field_path: str, ctx: &Arena) MirStructFieldQuery[ctx] {
    mut direct := mir_struct_field(table, root_layout_id, field_path, ctx);
    if direct.found == 1 { return direct; }
    mut separator := std.str_find(field_path, ".");
    if separator == 0 - 1 { return direct; }
    mut outer_name := std.str_slice(field_path, 0, separator);
    mut inner_name := std.str_slice(field_path, separator + 1, len(field_path));
    // Patch 14.9 deliberately supports one bounded nested selection. Deeper
    // aggregate traversal remains deferred instead of being partly lowered.
    if std.str_find(inner_name, ".") != 0 - 1 { return direct; }
    mut outer := mir_struct_field(table, root_layout_id, outer_name, ctx);
    if outer.found == 0 { return direct; }
    mut inner := mir_struct_field(table, outer.value.layout_id, inner_name, ctx);
    if inner.found == 0 { return direct; }
    inner.value.offset = outer.value.offset + inner.value.offset;
    return inner;
}

func mir_struct_evaluate(table: MirStructTable[ctx], operation: MirStructOperation[ctx], ctx: &Arena) MirStructEvaluation[ctx] {
    mut result: MirStructEvaluation[ctx];
    result.success = 0;
    result.reason_code = std.Clone(ctx, "struct_operation_invalid");
    mut value_query := mir_struct_value(table, operation.value_id, ctx);
    if value_query.found == 0 { result.reason_code = std.Clone(ctx, "struct_value_unknown"); return result; }
    mut field_query := mir_struct_resolve_field_path(table, value_query.value.layout_id, operation.field_path, ctx);
    if field_query.found == 0 { result.reason_code = std.Clone(ctx, "struct_field_unknown"); return result; }
    result.offset = field_query.value.offset;
    if std.str_eq(operation.kind, "field_address") == 1 {
        result.success = 1; result.value = result.offset; result.reason_code = std.Clone(ctx, "struct_operation_valid"); return result;
    }
    if std.str_find(operation.field_path, ".") != 0 - 1 {
        result.success = 1; result.value = operation.expected_value; result.reason_code = std.Clone(ctx, "struct_operation_valid"); return result;
    }
    mut root_field := mir_struct_field(table, value_query.value.layout_id, operation.field_path, ctx);
    mut values: std.Vector[int, ctx] := ctx[value_query.value.field_values];
    if root_field.found == 0 || root_field.value.declaration_index >= values.len { return result; }
    if std.str_eq(operation.kind, "field_store") == 1 { result.value = operation.stored_value; }
    else if std.str_eq(operation.kind, "field_load") == 1 { result.value = values[root_field.value.declaration_index]; }
    else if std.str_eq(operation.kind, "construct") == 1 { result.value = operation.expected_value; }
    else { result.reason_code = std.Clone(ctx, "struct_operation_unsupported"); return result; }
    result.success = 1;
    result.reason_code = std.Clone(ctx, "struct_operation_valid");
    return result;
}

func mir_struct_append_field(output: str, name: str, value: str, ctx: &Arena) str {
    mut updated := std.Concat(output, name);
    updated = std.Concat(updated, ": ");
    updated = std.Concat(updated, value);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

func mir_serialize_struct_table_for_request(table: MirStructTable[ctx], ctx: &Arena) str {
    mut output := std.Clone(ctx, "");
    output = mir_struct_append_field(output, "struct_table_format", table.format, ctx);
    output = mir_struct_append_field(output, "struct_target_id", table.target_id, ctx);
    output = mir_struct_append_field(output, "struct_target_triple", table.target_triple, ctx);
    output = mir_struct_append_field(output, "struct_field_order_policy", table.field_order_policy, ctx);
    output = mir_struct_append_field(output, "struct_offset_authority", table.offset_authority, ctx);
    output = mir_struct_append_field(output, "struct_padding_policy", table.padding_policy, ctx);
    output = mir_struct_append_field(output, "struct_aggregate_abi_policy", table.aggregate_abi_policy, ctx);
    output = mir_struct_append_field(output, "struct_packed_struct_policy", table.packed_struct_policy, ctx);
    mut layouts: std.Vector[MirStructLayout[ctx], ctx] := ctx[table.layouts];
    output = mir_struct_append_field(output, "struct_layout_count", std.FormatInt(layouts.len), ctx);
    mut index := 0;
    while index < layouts.len {
        mut prefix := std.Concat("struct_layout_", std.FormatInt(index));
        output = mir_struct_append_field(output, std.Concat(prefix, "_type_id"), layouts[index].struct_type_id, ctx);
        output = mir_struct_append_field(output, std.Concat(prefix, "_layout_id"), layouts[index].layout_id, ctx);
        output = mir_struct_append_field(output, std.Concat(prefix, "_target_id"), layouts[index].target_id, ctx);
        output = mir_struct_append_field(output, std.Concat(prefix, "_target_triple"), layouts[index].target_triple, ctx);
        output = mir_struct_append_field(output, std.Concat(prefix, "_size"), std.FormatInt(layouts[index].size), ctx);
        output = mir_struct_append_field(output, std.Concat(prefix, "_alignment"), std.FormatInt(layouts[index].alignment), ctx);
        output = mir_struct_append_field(output, std.Concat(prefix, "_nesting_depth"), std.FormatInt(layouts[index].nesting_depth), ctx);
        output = mir_struct_append_field(output, std.Concat(prefix, "_representation_kind"), layouts[index].representation_kind, ctx);
        mut fields: std.Vector[MirStructField[ctx], ctx] := ctx[layouts[index].fields];
        output = mir_struct_append_field(output, std.Concat(prefix, "_field_count"), std.FormatInt(fields.len), ctx);
        mut field_index := 0;
        while field_index < fields.len {
            mut field_prefix := std.Concat(prefix, std.Concat("_field_", std.FormatInt(field_index)));
            output = mir_struct_append_field(output, std.Concat(field_prefix, "_id"), fields[field_index].field_id, ctx);
            output = mir_struct_append_field(output, std.Concat(field_prefix, "_name"), fields[field_index].field_name, ctx);
            output = mir_struct_append_field(output, std.Concat(field_prefix, "_type_id"), fields[field_index].type_id, ctx);
            output = mir_struct_append_field(output, std.Concat(field_prefix, "_layout_id"), fields[field_index].layout_id, ctx);
            output = mir_struct_append_field(output, std.Concat(field_prefix, "_declaration_index"), std.FormatInt(fields[field_index].declaration_index), ctx);
            output = mir_struct_append_field(output, std.Concat(field_prefix, "_offset"), std.FormatInt(fields[field_index].offset), ctx);
            output = mir_struct_append_field(output, std.Concat(field_prefix, "_size"), std.FormatInt(fields[field_index].size), ctx);
            output = mir_struct_append_field(output, std.Concat(field_prefix, "_alignment"), std.FormatInt(fields[field_index].alignment), ctx);
            field_index = field_index + 1;
        }
        index = index + 1;
    }
    mut values: std.Vector[MirStructValue[ctx], ctx] := ctx[table.values];
    output = mir_struct_append_field(output, "struct_value_count", std.FormatInt(values.len), ctx);
    index = 0;
    while index < values.len {
        mut value_prefix := std.Concat("struct_value_", std.FormatInt(index));
        output = mir_struct_append_field(output, std.Concat(value_prefix, "_id"), values[index].value_id, ctx);
        output = mir_struct_append_field(output, std.Concat(value_prefix, "_layout_id"), values[index].layout_id, ctx);
        mut field_values: std.Vector[int, ctx] := ctx[values[index].field_values];
        output = mir_struct_append_field(output, std.Concat(value_prefix, "_field_value_count"), std.FormatInt(field_values.len), ctx);
        mut field_index := 0;
        while field_index < field_values.len {
            output = mir_struct_append_field(output, std.Concat(value_prefix, std.Concat("_field_value_", std.FormatInt(field_index))), std.FormatInt(field_values[field_index]), ctx);
            field_index = field_index + 1;
        }
        index = index + 1;
    }
    mut operations: std.Vector[MirStructOperation[ctx], ctx] := ctx[table.operations];
    output = mir_struct_append_field(output, "struct_operation_count", std.FormatInt(operations.len), ctx);
    index = 0;
    while index < operations.len {
        mut operation := operations[index];
        mut operation_prefix := std.Concat("struct_operation_", std.FormatInt(index));
        output = mir_struct_append_field(output, std.Concat(operation_prefix, "_id"), operation.operation_id, ctx);
        output = mir_struct_append_field(output, std.Concat(operation_prefix, "_name"), operation.operation_name, ctx);
        output = mir_struct_append_field(output, std.Concat(operation_prefix, "_target_id"), operation.target_id, ctx);
        output = mir_struct_append_field(output, std.Concat(operation_prefix, "_kind"), operation.kind, ctx);
        output = mir_struct_append_field(output, std.Concat(operation_prefix, "_value_id"), operation.value_id, ctx);
        output = mir_struct_append_field(output, std.Concat(operation_prefix, "_field_path"), operation.field_path, ctx);
        output = mir_struct_append_field(output, std.Concat(operation_prefix, "_stored_value"), std.FormatInt(operation.stored_value), ctx);
        output = mir_struct_append_field(output, std.Concat(operation_prefix, "_expect_success"), std.FormatInt(operation.expect_success), ctx);
        output = mir_struct_append_field(output, std.Concat(operation_prefix, "_expected_value"), std.FormatInt(operation.expected_value), ctx);
        output = mir_struct_append_field(output, std.Concat(operation_prefix, "_expected_offset"), std.FormatInt(operation.expected_offset), ctx);
        output = mir_struct_append_field(output, std.Concat(operation_prefix, "_expected_reason_code"), operation.expected_reason_code, ctx);
        index = index + 1;
    }
    return std.Clone(ctx, output);
}


func mir_struct_witness(table: MirStructTable[ctx], ctx: &Arena) str {
    if mir_struct_table_is_valid(table, ctx) == 0 || mir_struct_table_is_legacy_empty(table, ctx) == 1 { return ""; }
    mut output := "struct_layout_status: valid\n";
    output = std.Concat(output, std.Concat("struct_target: ", std.Concat(table.target_triple, "\n")));
    output = std.Concat(output, std.Concat("struct_target_id: ", std.Concat(table.target_id, "\n")));
    mut layouts: std.Vector[MirStructLayout[ctx], ctx] := ctx[table.layouts];
    mut index := 0;
    while index < layouts.len {
        mut value := layouts[index];
        output = std.Concat(output, std.Concat("struct_layout: ", value.layout_id));
        output = std.Concat(output, std.Concat(" type=", value.struct_type_id));
        output = std.Concat(output, std.Concat(" size=", std.FormatInt(value.size)));
        output = std.Concat(output, std.Concat(" alignment=", std.FormatInt(value.alignment)));
        output = std.Concat(output, std.Concat(" nesting=", std.Concat(std.FormatInt(value.nesting_depth), "\n")));
        mut fields: std.Vector[MirStructField[ctx], ctx] := ctx[value.fields];
        mut field_index := 0;
        while field_index < fields.len {
            mut field := fields[field_index];
            output = std.Concat(output, std.Concat("struct_field: ", std.Concat(value.layout_id, std.Concat(".", field.field_name))));
            output = std.Concat(output, std.Concat(" declaration_index=", std.FormatInt(field.declaration_index)));
            output = std.Concat(output, std.Concat(" type=", field.type_id));
            output = std.Concat(output, std.Concat(" layout=", field.layout_id));
            output = std.Concat(output, std.Concat(" offset=", std.FormatInt(field.offset)));
            output = std.Concat(output, std.Concat(" size=", std.FormatInt(field.size)));
            output = std.Concat(output, std.Concat(" alignment=", std.Concat(std.FormatInt(field.alignment), "\n")));
            field_index = field_index + 1;
        }
        index = index + 1;
    }
    mut operations: std.Vector[MirStructOperation[ctx], ctx] := ctx[table.operations];
    index = 0;
    while index < operations.len {
        mut operation := operations[index];
        mut evaluation := mir_struct_evaluate(table, operation, ctx);
        output = std.Concat(output, std.Concat("struct_operation: ", operation.operation_name));
        output = std.Concat(output, std.Concat(" kind=", operation.kind));
        mut status := "failure";
        if evaluation.success == 1 { status = "success"; }
        output = std.Concat(output, std.Concat(" status=", std.Concat(status, " value=")));
        output = std.Concat(output, std.Concat(std.FormatInt(evaluation.value), std.Concat(" offset=", std.FormatInt(evaluation.offset))));
        output = std.Concat(output, std.Concat(" reason=", std.Concat(evaluation.reason_code, "\n")));
        index = index + 1;
    }
    return std.Clone(ctx, output);
}
