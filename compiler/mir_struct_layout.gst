// Phase 14.9 compiler-owned declaration-order struct layout authority.
//
// This table is deliberately bounded to in-memory non-packed structs. The
// compiler selects field offsets, padding, alignment, and nested layouts;
// consumers validate and execute that decision without recomputing it.
//
// Field storage is modelled as a compiler-derived list of scalar leaves in
// offset order. A leaf is what actually occupies bytes, so a nested field path
// resolves to a real stored scalar instead of echoing its own expectation.

import "mir_layout.gst" as layout;

type MirStructField[ctx] struct {
    field_id: str,
    field_name: str,
    type_id: str,
    layout_id: str,
    declaration_index: int,
    offset: int,
    size: int,
    alignment: int,
    is_aggregate: int
}

type MirStructLeaf[ctx] struct {
    path: str,
    type_id: str,
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
    scalar_values: Index[std.Vector[int, ctx], ctx],
    storage_region: str,
    flow_origin: str
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
type MirStructOperationQuery[ctx] struct { found: int, value: MirStructOperation[ctx] }
type MirStructFieldLayoutQuery struct { found: int, size: int, alignment: int, is_aggregate: int }
type MirStructLeafQuery[ctx] struct { found: int, index: int, value: MirStructLeaf[ctx] }

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

func mir_struct_empty_leaf_vector(ctx: &Arena) Index[std.Vector[MirStructLeaf[ctx], ctx], ctx] {
    mut values: std.Vector[MirStructLeaf[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirStructLeaf[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
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

func mir_struct_field_is_safe(value: str, allow_empty: int) int {
    if allow_empty == 0 && len(value) == 0 { return 0; }
    if std.str_find(value, "\n") != 0 - 1 { return 0; }
    if std.str_find(value, "\r") != 0 - 1 { return 0; }
    return 1;
}

func mir_struct_align_up(value: int, alignment: int) int {
    if alignment <= 0 { return 0 - 1; }
    mut quotient := value / alignment;
    mut remainder := value - quotient * alignment;
    if remainder == 0 { return value; }
    return value + alignment - remainder;
}

func mir_struct_operation_kind_is_valid(kind: str) int {
    if std.str_eq(kind, "construct") == 1 { return 1; }
    if std.str_eq(kind, "field_address") == 1 { return 1; }
    if std.str_eq(kind, "field_load") == 1 { return 1; }
    if std.str_eq(kind, "field_store") == 1 { return 1; }
    return 0;
}

func mir_struct_field_identity(struct_type_id: str, field_name: str, declaration_index: int, ctx: &Arena) str {
    mut identity := "struct_field:v1:type=";
    identity = std.Concat(identity, struct_type_id);
    identity = std.Concat(identity, ":name=");
    identity = std.Concat(identity, field_name);
    identity = std.Concat(identity, ":index=");
    identity = std.Concat(identity, std.FormatInt(declaration_index));
    return std.Clone(ctx, identity);
}

func mir_struct_layout_identity(target_id: str, struct_type_id: str, size: int, alignment: int, field_count: int, ctx: &Arena) str {
    mut identity := "struct_layout:v1:target=";
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":type=");
    identity = std.Concat(identity, struct_type_id);
    identity = std.Concat(identity, ":size=");
    identity = std.Concat(identity, std.FormatInt(size));
    identity = std.Concat(identity, ":align=");
    identity = std.Concat(identity, std.FormatInt(alignment));
    identity = std.Concat(identity, ":fields=");
    identity = std.Concat(identity, std.FormatInt(field_count));
    return std.Clone(ctx, identity);
}

func mir_struct_operation_identity(target_id: str, operation_name: str, kind: str, ctx: &Arena) str {
    mut identity := "struct_operation:v1:target=";
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":name=");
    identity = std.Concat(identity, operation_name);
    identity = std.Concat(identity, ":kind=");
    identity = std.Concat(identity, kind);
    return std.Clone(ctx, identity);
}

func mir_struct_make_field(struct_type_id: str, field_name: str, type_id: str, layout_id: str, size: int, alignment: int, is_aggregate: int, ctx: &Arena) MirStructField[ctx] {
    mut field: MirStructField[ctx];
    field.field_name = std.Clone(ctx, field_name);
    field.type_id = std.Clone(ctx, type_id);
    field.layout_id = std.Clone(ctx, layout_id);
    field.declaration_index = 0;
    field.offset = 0;
    field.size = size;
    field.alignment = alignment;
    field.is_aggregate = is_aggregate;
    field.field_id = mir_struct_field_identity(struct_type_id, field_name, 0, ctx);
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
    value.field_count = len(field_values);
    value.nesting_depth = nesting_depth;
    value.representation_kind = std.Clone(ctx, "declaration_order_struct");
    value.fields = fields;
    return value;
}

// Canonical constructor for compiler-selected layouts. Callers provide fields
// in source declaration order with their type layout size/alignment; this
// function owns declaration indexes, offsets, inter-field padding, aggregate
// alignment, and tail padding.
func mir_struct_layout_declared_fields(struct_type_id: str, target_id: str, target_triple: str, nesting_depth: int, declared_fields: Index[std.Vector[MirStructField[ctx], ctx], ctx], ctx: &Arena) MirStructLayout[ctx] {
    mut fields: std.Vector[MirStructField[ctx], ctx] := ctx[declared_fields];
    mut offset := 0;
    mut aggregate_alignment := 1;
    mut index := 0;
    while index < len(fields) {
        mut field := fields[index];
        field.declaration_index = index;
        field.field_id = mir_struct_field_identity(struct_type_id, field.field_name, index, ctx);
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
    mut layout_id := mir_struct_layout_identity(target_id, struct_type_id, size, aggregate_alignment, len(fields), ctx);
    return mir_struct_make_layout(struct_type_id, layout_id, target_id, target_triple, size, aggregate_alignment, nesting_depth, declared_fields, ctx);
}

func mir_struct_make_value(value_id: str, struct_layout: MirStructLayout[ctx], scalar_values: Index[std.Vector[int, ctx], ctx], storage_region: str, flow_origin: str, ctx: &Arena) MirStructValue[ctx] {
    mut value: MirStructValue[ctx];
    value.value_id = std.Clone(ctx, value_id);
    value.layout_id = std.Clone(ctx, struct_layout.layout_id);
    value.scalar_values = scalar_values;
    value.storage_region = std.Clone(ctx, storage_region);
    value.flow_origin = std.Clone(ctx, flow_origin);
    return value;
}

func mir_struct_make_operation(table: MirStructTable[ctx], operation_name: str, kind: str, value_id: str, field_path: str, stored_value: int, expected_value: int, expected_offset: int, ctx: &Arena) MirStructOperation[ctx] {
    mut value: MirStructOperation[ctx];
    value.operation_name = std.Clone(ctx, operation_name);
    value.target_id = std.Clone(ctx, table.target_id);
    value.kind = std.Clone(ctx, kind);
    value.value_id = std.Clone(ctx, value_id);
    value.field_path = std.Clone(ctx, field_path);
    value.stored_value = stored_value;
    value.expect_success = 1;
    value.expected_value = expected_value;
    value.expected_offset = expected_offset;
    value.expected_reason_code = std.Clone(ctx, "struct_operation_valid");
    value.operation_id = mir_struct_operation_identity(value.target_id, operation_name, kind, ctx);
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

func mir_struct_layout(table: MirStructTable[ctx], layout_id: str, ctx: &Arena) MirStructLayoutQuery[ctx] {
    mut result: MirStructLayoutQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirStructLayout[ctx], ctx] := ctx[table.layouts];
    mut index := 0;
    while index < len(values) {
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
    while index < len(fields) {
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
    while index < len(values) {
        if std.str_eq(values[index].value_id, value_id) == 1 {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_struct_operation(table: MirStructTable[ctx], operation_name: str, ctx: &Arena) MirStructOperationQuery[ctx] {
    mut result: MirStructOperationQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirStructOperation[ctx], ctx] := ctx[table.operations];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].operation_name, operation_name) == 1 {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

// Field storage identity comes from the layout authority for scalars and from
// this table for a selected nested struct. Nothing else is a legal field type.
func mir_struct_field_layout(table: MirStructTable[ctx], layout_table: layout.MirLayoutTable[ctx], type_id: str, layout_id: str, ctx: &Arena) MirStructFieldLayoutQuery {
    mut result: MirStructFieldLayoutQuery;
    result.found = 0;
    result.is_aggregate = 0;
    mut base := layout.mir_layout_of(layout_table, type_id, layout_table.target.target_id, ctx);
    if base.found == 1 && std.str_eq(base.layout.layout_id, layout_id) == 1 {
        result.found = 1;
        result.size = base.layout.size;
        result.alignment = base.layout.alignment;
        return result;
    }
    mut nested := mir_struct_layout(table, layout_id, ctx);
    if nested.found == 1 && std.str_eq(nested.value.struct_type_id, type_id) == 1 {
        result.found = 1;
        result.size = nested.value.size;
        result.alignment = nested.value.alignment;
        result.is_aggregate = 1;
    }
    return result;
}

// Compiler-derived scalar leaves in offset order. Patch 14.9 selects one
// bounded level of nesting; a deeper aggregate field is rejected rather than
// partly flattened.
func mir_struct_leaves(table: MirStructTable[ctx], layout_id: str, ctx: &Arena) Index[std.Vector[MirStructLeaf[ctx], ctx], ctx] {
    mut leaves := mir_struct_empty_leaf_vector(ctx);
    mut vector: std.Vector[MirStructLeaf[ctx], ctx] := ctx[leaves];
    mut layout_query := mir_struct_layout(table, layout_id, ctx);
    if layout_query.found == 0 {
        ctx.Set(leaves, vector);
        return leaves;
    }
    mut fields: std.Vector[MirStructField[ctx], ctx] := ctx[layout_query.value.fields];
    mut index := 0;
    while index < len(fields) {
        mut field := fields[index];
        if field.is_aggregate == 0 {
            mut leaf: MirStructLeaf[ctx];
            leaf.path = std.Clone(ctx, field.field_name);
            leaf.type_id = std.Clone(ctx, field.type_id);
            leaf.offset = field.offset;
            leaf.size = field.size;
            leaf.alignment = field.alignment;
            vector.Push(leaf);
        } else {
            mut inner_query := mir_struct_layout(table, field.layout_id, ctx);
            if inner_query.found == 1 {
                mut inner_fields: std.Vector[MirStructField[ctx], ctx] := ctx[inner_query.value.fields];
                mut inner_index := 0;
                while inner_index < len(inner_fields) {
                    mut inner := inner_fields[inner_index];
                    if inner.is_aggregate == 0 {
                        mut leaf: MirStructLeaf[ctx];
                        leaf.path = std.Clone(ctx, std.Concat(field.field_name, std.Concat(".", inner.field_name)));
                        leaf.type_id = std.Clone(ctx, inner.type_id);
                        leaf.offset = field.offset + inner.offset;
                        leaf.size = inner.size;
                        leaf.alignment = inner.alignment;
                        vector.Push(leaf);
                    }
                    inner_index = inner_index + 1;
                }
            }
        }
        index = index + 1;
    }
    ctx.Set(leaves, vector);
    return leaves;
}

func mir_struct_leaf_at_offset(table: MirStructTable[ctx], layout_id: str, offset: int, ctx: &Arena) MirStructLeafQuery[ctx] {
    mut result: MirStructLeafQuery[ctx];
    result.found = 0;
    result.index = 0 - 1;
    mut leaves: std.Vector[MirStructLeaf[ctx], ctx] := ctx[mir_struct_leaves(table, layout_id, ctx)];
    mut index := 0;
    while index < len(leaves) {
        if leaves[index].offset == offset {
            result.found = 1;
            result.index = index;
            result.value = leaves[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_struct_evaluation(success: int, value: int, offset: int, reason_code: str, ctx: &Arena) MirStructEvaluation[ctx] {
    mut result: MirStructEvaluation[ctx];
    result.success = success;
    result.value = value;
    result.offset = offset;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_struct_rejection(kind: str, ctx: &Arena) MirStructEvaluation[ctx] {
    if std.str_eq(kind, "duplicate_field") == 1 {
        return mir_struct_evaluation(0, 0, 0, "struct_duplicate_field", ctx);
    }
    if std.str_eq(kind, "misaligned_field") == 1 {
        return mir_struct_evaluation(0, 0, 0, "struct_field_misaligned", ctx);
    }
    if std.str_eq(kind, "overlapping_fields") == 1 {
        return mir_struct_evaluation(0, 0, 0, "struct_field_overlap", ctx);
    }
    if std.str_eq(kind, "wrong_field_type") == 1 {
        return mir_struct_evaluation(0, 0, 0, "struct_field_type_mismatch", ctx);
    }
    if std.str_eq(kind, "size_alignment_mismatch") == 1 {
        return mir_struct_evaluation(0, 0, 0, "struct_size_alignment_mismatch", ctx);
    }
    if std.str_eq(kind, "unknown_field_path") == 1 {
        return mir_struct_evaluation(0, 0, 0, "struct_field_unknown", ctx);
    }
    return mir_struct_evaluation(0, 0, 0, "struct_request_invalid", ctx);
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
    if outer.found == 0 || outer.value.is_aggregate == 0 { return direct; }
    mut inner := mir_struct_field(table, outer.value.layout_id, inner_name, ctx);
    if inner.found == 0 { return direct; }
    inner.value.offset = outer.value.offset + inner.value.offset;
    return inner;
}

func mir_struct_evaluate(table: MirStructTable[ctx], operation: MirStructOperation[ctx], ctx: &Arena) MirStructEvaluation[ctx] {
    mut value_query := mir_struct_value(table, operation.value_id, ctx);
    if value_query.found == 0 { return mir_struct_rejection("unknown_field_path", ctx); }
    mut layout_query := mir_struct_layout(table, value_query.value.layout_id, ctx);
    if layout_query.found == 0 { return mir_struct_rejection("size_alignment_mismatch", ctx); }

    if std.str_eq(operation.kind, "construct") == 1 {
        return mir_struct_evaluation(1, layout_query.value.field_count, 0, "struct_operation_valid", ctx);
    }

    mut field_query := mir_struct_resolve_field_path(table, value_query.value.layout_id, operation.field_path, ctx);
    if field_query.found == 0 { return mir_struct_rejection("unknown_field_path", ctx); }
    mut offset := field_query.value.offset;

    if std.str_eq(operation.kind, "field_address") == 1 {
        return mir_struct_evaluation(1, offset, offset, "struct_operation_valid", ctx);
    }

    // Loads and stores address a real stored scalar, so a nested field path is
    // resolved through the compiler-owned leaf map rather than trusted.
    if field_query.value.is_aggregate == 1 {
        return mir_struct_rejection("wrong_field_type", ctx);
    }
    mut leaf_query := mir_struct_leaf_at_offset(table, value_query.value.layout_id, offset, ctx);
    if leaf_query.found == 0 { return mir_struct_rejection("unknown_field_path", ctx); }
    if std.str_eq(leaf_query.value.type_id, field_query.value.type_id) == 0 {
        return mir_struct_rejection("wrong_field_type", ctx);
    }
    mut scalars: std.Vector[int, ctx] := ctx[value_query.value.scalar_values];
    if leaf_query.index >= len(scalars) { return mir_struct_rejection("wrong_field_type", ctx); }

    if std.str_eq(operation.kind, "field_store") == 1 {
        return mir_struct_evaluation(1, operation.stored_value, offset, "struct_operation_valid", ctx);
    }
    if std.str_eq(operation.kind, "field_load") == 1 {
        return mir_struct_evaluation(1, scalars[leaf_query.index], offset, "struct_operation_valid", ctx);
    }
    return mir_struct_evaluation(0, 0, 0, "struct_operation_unsupported", ctx);
}

func mir_struct_table_is_legacy_empty(table: MirStructTable[ctx], ctx: &Arena) int {
    mut layouts: std.Vector[MirStructLayout[ctx], ctx] := ctx[table.layouts];
    mut values: std.Vector[MirStructValue[ctx], ctx] := ctx[table.values];
    mut operations: std.Vector[MirStructOperation[ctx], ctx] := ctx[table.operations];
    if len(table.target_id) == 0 && len(layouts) == 0 && len(values) == 0 && len(operations) == 0 { return 1; }
    return 0;
}

func mir_struct_layout_is_valid(table: MirStructTable[ctx], layout_table: layout.MirLayoutTable[ctx], value: MirStructLayout[ctx], ctx: &Arena) int {
    if value.size <= 0 || value.alignment <= 0 || value.field_count <= 0 || value.nesting_depth < 0 { return 0; }
    if mir_struct_align_up(value.size, value.alignment) != value.size { return 0; }
    if std.str_eq(value.target_id, table.target_id) == 0 || std.str_eq(value.target_triple, table.target_triple) == 0 { return 0; }
    if std.str_eq(value.representation_kind, "declaration_order_struct") == 0 { return 0; }
    if mir_struct_field_is_safe(value.struct_type_id, 0) == 0 { return 0; }
    mut fields: std.Vector[MirStructField[ctx], ctx] := ctx[value.fields];
    if len(fields) != value.field_count { return 0; }

    mut index := 0;
    mut previous_end := 0;
    mut offset := 0;
    mut expected_alignment := 1;
    while index < len(fields) {
        mut field := fields[index];
        if field.declaration_index != index || field.size <= 0 || field.alignment <= 0 || field.alignment > value.alignment { return 0; }
        if mir_struct_field_is_safe(field.field_id, 0) == 0 || mir_struct_field_is_safe(field.field_name, 0) == 0 ||
           mir_struct_field_is_safe(field.type_id, 0) == 0 || mir_struct_field_is_safe(field.layout_id, 0) == 0 { return 0; }
        if std.str_eq(field.field_id, mir_struct_field_identity(value.struct_type_id, field.field_name, index, ctx)) == 0 { return 0; }

        // Field storage must be exactly what the layout authority owns.
        mut field_layout := mir_struct_field_layout(table, layout_table, field.type_id, field.layout_id, ctx);
        if field_layout.found == 0 || field_layout.size != field.size ||
           field_layout.alignment != field.alignment || field_layout.is_aggregate != field.is_aggregate
        {
            return 0;
        }

        // Declaration order, natural alignment, and no overlap are compiler-owned.
        if mir_struct_align_up(field.offset, field.alignment) != field.offset { return 0; }
        if field.offset != mir_struct_align_up(offset, field.alignment) { return 0; }
        if field.offset < previous_end || field.offset + field.size > value.size { return 0; }
        if field.alignment > expected_alignment { expected_alignment = field.alignment; }
        previous_end = field.offset + field.size;
        offset = field.offset + field.size;

        mut duplicate := index + 1;
        while duplicate < len(fields) {
            if std.str_eq(fields[index].field_name, fields[duplicate].field_name) == 1 { return 0; }
            duplicate = duplicate + 1;
        }
        index = index + 1;
    }

    if value.alignment != expected_alignment { return 0; }
    if value.size != mir_struct_align_up(previous_end, expected_alignment) { return 0; }
    if std.str_eq(value.layout_id, mir_struct_layout_identity(value.target_id, value.struct_type_id, value.size, value.alignment, value.field_count, ctx)) == 0 { return 0; }
    return 1;
}

func mir_struct_table_is_valid(table: MirStructTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if std.str_eq(table.format, "gust.compiler_struct_layout_table.v1") == 0 { return 0; }
    if mir_struct_table_is_legacy_empty(table, ctx) == 1 { return 1; }
    if std.str_eq(table.target_id, layout_table.target.target_id) == 0 ||
       std.str_eq(table.target_triple, layout_table.target.target_triple) == 0 ||
       std.str_eq(table.field_order_policy, "declaration_order_preserved") == 0 ||
       std.str_eq(table.offset_authority, "compiler_owned_offsets_no_backend_relayout") == 0 ||
       std.str_eq(table.padding_policy, "natural_alignment_with_tail_padding") == 0 ||
       std.str_eq(table.aggregate_abi_policy, "deferred_aggregate_parameter_and_return_abi") == 0 ||
       std.str_eq(table.packed_struct_policy, "deferred_packed_structs_and_bitfields") == 0
    {
        return 0;
    }

    mut layouts: std.Vector[MirStructLayout[ctx], ctx] := ctx[table.layouts];
    mut values: std.Vector[MirStructValue[ctx], ctx] := ctx[table.values];
    mut operations: std.Vector[MirStructOperation[ctx], ctx] := ctx[table.operations];
    if len(layouts) != 5 || len(values) != 6 || len(operations) != 17 { return 0; }

    mut index := 0;
    while index < len(layouts) {
        if mir_struct_layout_is_valid(table, layout_table, layouts[index], ctx) == 0 { return 0; }
        mut duplicate := index + 1;
        while duplicate < len(layouts) {
            if std.str_eq(layouts[index].layout_id, layouts[duplicate].layout_id) == 1 { return 0; }
            if std.str_eq(layouts[index].struct_type_id, layouts[duplicate].struct_type_id) == 1 { return 0; }
            duplicate = duplicate + 1;
        }
        index = index + 1;
    }

    index = 0;
    while index < len(values) {
        mut value := values[index];
        mut layout_query := mir_struct_layout(table, value.layout_id, ctx);
        if layout_query.found == 0 { return 0; }
        mut leaves: std.Vector[MirStructLeaf[ctx], ctx] := ctx[mir_struct_leaves(table, value.layout_id, ctx)];
        mut scalars: std.Vector[int, ctx] := ctx[value.scalar_values];
        if len(scalars) != len(leaves) || len(leaves) == 0 { return 0; }
        if mir_struct_field_is_safe(value.value_id, 0) == 0 ||
           mir_struct_field_is_safe(value.flow_origin, 0) == 0 ||
           std.str_eq(value.storage_region, "function:main") == 0
        {
            return 0;
        }
        mut leaf_index := 1;
        while leaf_index < len(leaves) {
            if leaves[leaf_index].offset <= leaves[leaf_index - 1].offset { return 0; }
            leaf_index = leaf_index + 1;
        }
        mut duplicate := index + 1;
        while duplicate < len(values) {
            if std.str_eq(values[index].value_id, values[duplicate].value_id) == 1 { return 0; }
            duplicate = duplicate + 1;
        }
        index = index + 1;
    }

    index = 0;
    while index < len(operations) {
        mut operation := operations[index];
        if mir_struct_operation_kind_is_valid(operation.kind) == 0 ||
           std.str_eq(operation.target_id, table.target_id) == 0 ||
           operation.expect_success != 1 ||
           std.str_eq(operation.expected_reason_code, "struct_operation_valid") == 0 ||
           mir_struct_field_is_safe(operation.operation_name, 0) == 0 ||
           mir_struct_field_is_safe(operation.value_id, 0) == 0
        {
            return 0;
        }
        if std.str_eq(operation.operation_id, mir_struct_operation_identity(operation.target_id, operation.operation_name, operation.kind, ctx)) == 0 { return 0; }
        mut duplicate := index + 1;
        while duplicate < len(operations) {
            if std.str_eq(operations[index].operation_id, operations[duplicate].operation_id) == 1 { return 0; }
            duplicate = duplicate + 1;
        }
        mut evaluation := mir_struct_evaluate(table, operation, ctx);
        if evaluation.success != operation.expect_success ||
           evaluation.value != operation.expected_value ||
           evaluation.offset != operation.expected_offset ||
           std.str_eq(evaluation.reason_code, operation.expected_reason_code) == 0
        {
            return 0;
        }
        index = index + 1;
    }
    return 1;
}

func mir_struct_fields_of(ctx: &Arena) Index[std.Vector[MirStructField[ctx], ctx], ctx] {
    return mir_struct_empty_field_vector(ctx);
}

func mir_struct_push_field(target: Index[std.Vector[MirStructField[ctx], ctx], ctx], value: MirStructField[ctx], ctx: &Arena) Index[std.Vector[MirStructField[ctx], ctx], ctx] {
    mut vector: std.Vector[MirStructField[ctx], ctx] := ctx[target];
    vector.Push(value);
    ctx.Set(target, vector);
    return target;
}

func mir_struct_scalars2(a: int, b: int, ctx: &Arena) Index[std.Vector[int, ctx], ctx] {
    mut values := mir_struct_empty_int_vector(ctx);
    mut vector: std.Vector[int, ctx] := ctx[values];
    vector.Push(a); vector.Push(b);
    ctx.Set(values, vector);
    return values;
}

func mir_struct_scalars3(a: int, b: int, c: int, ctx: &Arena) Index[std.Vector[int, ctx], ctx] {
    mut values := mir_struct_empty_int_vector(ctx);
    mut vector: std.Vector[int, ctx] := ctx[values];
    vector.Push(a); vector.Push(b); vector.Push(c);
    ctx.Set(values, vector);
    return values;
}

func mir_struct_table_for_layout(layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) MirStructTable[ctx] {
    mut table := mir_struct_make_empty_table(layout_table.target.target_triple, ctx);
    table.target_id = std.Clone(ctx, layout_table.target.target_id);

    mut i32_layout := layout.mir_layout_of(layout_table, "type:gust:i32", layout_table.target.target_id, ctx);
    mut u8_layout := layout.mir_layout_of(layout_table, "type:gust:u8", layout_table.target.target_id, ctx);
    mut i32_size := i32_layout.layout.size;
    mut i32_align := i32_layout.layout.alignment;
    mut i32_id := i32_layout.layout.layout_id;
    mut u8_size := u8_layout.layout.size;
    mut u8_align := u8_layout.layout.alignment;
    mut u8_id := u8_layout.layout.layout_id;

    // 1. Two equally sized scalar fields: no padding anywhere.
    mut point_fields := mir_struct_fields_of(ctx);
    point_fields = mir_struct_push_field(point_fields, mir_struct_make_field("type:gust:struct:Point", "x", "type:gust:i32", i32_id, i32_size, i32_align, 0, ctx), ctx);
    point_fields = mir_struct_push_field(point_fields, mir_struct_make_field("type:gust:struct:Point", "y", "type:gust:i32", i32_id, i32_size, i32_align, 0, ctx), ctx);
    mut point := mir_struct_layout_declared_fields("type:gust:struct:Point", table.target_id, table.target_triple, 1, point_fields, ctx);

    // 2. Narrow field before a wider one: compiler-owned inter-field padding.
    mut header_fields := mir_struct_fields_of(ctx);
    header_fields = mir_struct_push_field(header_fields, mir_struct_make_field("type:gust:struct:Header", "tag", "type:gust:u8", u8_id, u8_size, u8_align, 0, ctx), ctx);
    header_fields = mir_struct_push_field(header_fields, mir_struct_make_field("type:gust:struct:Header", "value", "type:gust:i32", i32_id, i32_size, i32_align, 0, ctx), ctx);
    mut header := mir_struct_layout_declared_fields("type:gust:struct:Header", table.target_id, table.target_triple, 1, header_fields, ctx);

    // 3. All byte-sized fields: densely packed without padding.
    mut flags_fields := mir_struct_fields_of(ctx);
    flags_fields = mir_struct_push_field(flags_fields, mir_struct_make_field("type:gust:struct:Flags", "a", "type:gust:u8", u8_id, u8_size, u8_align, 0, ctx), ctx);
    flags_fields = mir_struct_push_field(flags_fields, mir_struct_make_field("type:gust:struct:Flags", "b", "type:gust:u8", u8_id, u8_size, u8_align, 0, ctx), ctx);
    flags_fields = mir_struct_push_field(flags_fields, mir_struct_make_field("type:gust:struct:Flags", "c", "type:gust:u8", u8_id, u8_size, u8_align, 0, ctx), ctx);
    mut flags := mir_struct_layout_declared_fields("type:gust:struct:Flags", table.target_id, table.target_triple, 1, flags_fields, ctx);

    // 4. Wide field before a narrow one: compiler-owned tail padding.
    mut padded_fields := mir_struct_fields_of(ctx);
    padded_fields = mir_struct_push_field(padded_fields, mir_struct_make_field("type:gust:struct:Padded", "id", "type:gust:i32", i32_id, i32_size, i32_align, 0, ctx), ctx);
    padded_fields = mir_struct_push_field(padded_fields, mir_struct_make_field("type:gust:struct:Padded", "flag", "type:gust:u8", u8_id, u8_size, u8_align, 0, ctx), ctx);
    mut padded := mir_struct_layout_declared_fields("type:gust:struct:Padded", table.target_id, table.target_triple, 1, padded_fields, ctx);

    table = mir_struct_table_with_layout(table, point, ctx);
    table = mir_struct_table_with_layout(table, header, ctx);
    table = mir_struct_table_with_layout(table, flags, ctx);
    table = mir_struct_table_with_layout(table, padded, ctx);

    // 5. One bounded level of nesting over an already-frozen layout.
    mut nested_fields := mir_struct_fields_of(ctx);
    nested_fields = mir_struct_push_field(nested_fields, mir_struct_make_field("type:gust:struct:Nested", "head", header.struct_type_id, header.layout_id, header.size, header.alignment, 1, ctx), ctx);
    nested_fields = mir_struct_push_field(nested_fields, mir_struct_make_field("type:gust:struct:Nested", "extra", "type:gust:i32", i32_id, i32_size, i32_align, 0, ctx), ctx);
    mut nested := mir_struct_layout_declared_fields("type:gust:struct:Nested", table.target_id, table.target_triple, 2, nested_fields, ctx);
    table = mir_struct_table_with_layout(table, nested, ctx);

    table = mir_struct_table_with_value(table, mir_struct_make_value("struct_point", point, mir_struct_scalars2(3, 4, ctx), "function:main", "direct", ctx), ctx);
    table = mir_struct_table_with_value(table, mir_struct_make_value("struct_header", header, mir_struct_scalars2(7, 1000, ctx), "function:main", "direct", ctx), ctx);
    table = mir_struct_table_with_value(table, mir_struct_make_value("struct_flags", flags, mir_struct_scalars3(1, 2, 3, ctx), "function:main", "direct", ctx), ctx);
    table = mir_struct_table_with_value(table, mir_struct_make_value("struct_padded", padded, mir_struct_scalars2(55, 9, ctx), "function:main", "direct", ctx), ctx);
    table = mir_struct_table_with_value(table, mir_struct_make_value("struct_nested", nested, mir_struct_scalars3(11, 2200, 42, ctx), "function:main", "direct", ctx), ctx);
    // Struct value held in an addressable local and observed after a join.
    table = mir_struct_table_with_value(table, mir_struct_make_value("struct_local_point", point, mir_struct_scalars2(64, 91, ctx), "function:main", "branch_join:block1:block2:block3", ctx), ctx);

    table = mir_struct_table_with_operation(table, mir_struct_make_operation(table, "construct_point", "construct", "struct_point", "", 0, 2, 0, ctx), ctx);
    table = mir_struct_table_with_operation(table, mir_struct_make_operation(table, "address_point_x", "field_address", "struct_point", "x", 0, 0, 0, ctx), ctx);
    table = mir_struct_table_with_operation(table, mir_struct_make_operation(table, "address_point_y", "field_address", "struct_point", "y", 0, 4, 4, ctx), ctx);
    table = mir_struct_table_with_operation(table, mir_struct_make_operation(table, "load_point_x", "field_load", "struct_point", "x", 0, 3, 0, ctx), ctx);
    table = mir_struct_table_with_operation(table, mir_struct_make_operation(table, "load_point_y", "field_load", "struct_point", "y", 0, 4, 4, ctx), ctx);
    table = mir_struct_table_with_operation(table, mir_struct_make_operation(table, "store_point_y", "field_store", "struct_point", "y", 21, 21, 4, ctx), ctx);
    table = mir_struct_table_with_operation(table, mir_struct_make_operation(table, "address_header_value", "field_address", "struct_header", "value", 0, 4, 4, ctx), ctx);
    table = mir_struct_table_with_operation(table, mir_struct_make_operation(table, "load_header_tag", "field_load", "struct_header", "tag", 0, 7, 0, ctx), ctx);
    table = mir_struct_table_with_operation(table, mir_struct_make_operation(table, "load_header_value", "field_load", "struct_header", "value", 0, 1000, 4, ctx), ctx);
    table = mir_struct_table_with_operation(table, mir_struct_make_operation(table, "address_flags_c", "field_address", "struct_flags", "c", 0, 2, 2, ctx), ctx);
    table = mir_struct_table_with_operation(table, mir_struct_make_operation(table, "load_flags_b", "field_load", "struct_flags", "b", 0, 2, 1, ctx), ctx);
    table = mir_struct_table_with_operation(table, mir_struct_make_operation(table, "construct_padded", "construct", "struct_padded", "", 0, 2, 0, ctx), ctx);
    table = mir_struct_table_with_operation(table, mir_struct_make_operation(table, "load_padded_flag", "field_load", "struct_padded", "flag", 0, 9, 4, ctx), ctx);
    table = mir_struct_table_with_operation(table, mir_struct_make_operation(table, "address_nested_head_tag", "field_address", "struct_nested", "head.tag", 0, 0, 0, ctx), ctx);
    table = mir_struct_table_with_operation(table, mir_struct_make_operation(table, "load_nested_head_value", "field_load", "struct_nested", "head.value", 0, 2200, 4, ctx), ctx);
    table = mir_struct_table_with_operation(table, mir_struct_make_operation(table, "load_nested_extra", "field_load", "struct_nested", "extra", 0, 42, 8, ctx), ctx);
    table = mir_struct_table_with_operation(table, mir_struct_make_operation(table, "load_local_point_y", "field_load", "struct_local_point", "y", 0, 91, 4, ctx), ctx);
    return table;
}

func mir_struct_append_field(output: str, name: str, value: str, ctx: &Arena) str {
    mut updated := std.Concat(output, name);
    updated = std.Concat(updated, ": ");
    updated = std.Concat(updated, value);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

func mir_serialize_struct_table_for_request(table: MirStructTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_struct_table_is_legacy_empty(table, ctx) == 1 {
        return "struct_table_format: gust.compiler_struct_layout_table.v1\nstruct_target_id: \nstruct_target_triple: legacy-empty\nstruct_layout_count: 0\nstruct_value_count: 0\nstruct_operation_count: 0\n";
    }
    if mir_struct_table_is_valid(table, layout_table, ctx) == 0 {
        return "struct_table_format: invalid\n";
    }
    mut output := "";
    output = mir_struct_append_field(output, "struct_table_format", table.format, ctx);
    output = mir_struct_append_field(output, "struct_target_id", table.target_id, ctx);
    output = mir_struct_append_field(output, "struct_target_triple", table.target_triple, ctx);
    output = mir_struct_append_field(output, "struct_field_order_policy", table.field_order_policy, ctx);
    output = mir_struct_append_field(output, "struct_offset_authority", table.offset_authority, ctx);
    output = mir_struct_append_field(output, "struct_padding_policy", table.padding_policy, ctx);
    output = mir_struct_append_field(output, "struct_aggregate_abi_policy", table.aggregate_abi_policy, ctx);
    output = mir_struct_append_field(output, "struct_packed_struct_policy", table.packed_struct_policy, ctx);

    mut layouts: std.Vector[MirStructLayout[ctx], ctx] := ctx[table.layouts];
    output = mir_struct_append_field(output, "struct_layout_count", std.FormatInt(len(layouts)), ctx);
    mut index := 0;
    while index < len(layouts) {
        mut prefix := std.Concat("struct_layout_", std.FormatInt(index));
        mut value := layouts[index];
        output = mir_struct_append_field(output, std.Concat(prefix, "_id"), value.layout_id, ctx);
        output = mir_struct_append_field(output, std.Concat(prefix, "_type_id"), value.struct_type_id, ctx);
        output = mir_struct_append_field(output, std.Concat(prefix, "_target_id"), value.target_id, ctx);
        output = mir_struct_append_field(output, std.Concat(prefix, "_size"), std.FormatInt(value.size), ctx);
        output = mir_struct_append_field(output, std.Concat(prefix, "_alignment"), std.FormatInt(value.alignment), ctx);
        output = mir_struct_append_field(output, std.Concat(prefix, "_nesting_depth"), std.FormatInt(value.nesting_depth), ctx);
        output = mir_struct_append_field(output, std.Concat(prefix, "_representation_kind"), value.representation_kind, ctx);
        mut fields: std.Vector[MirStructField[ctx], ctx] := ctx[value.fields];
        output = mir_struct_append_field(output, std.Concat(prefix, "_field_count"), std.FormatInt(len(fields)), ctx);
        mut field_index := 0;
        while field_index < len(fields) {
            mut field_prefix := std.Concat(prefix, std.Concat("_field_", std.FormatInt(field_index)));
            output = mir_struct_append_field(output, std.Concat(field_prefix, "_id"), fields[field_index].field_id, ctx);
            output = mir_struct_append_field(output, std.Concat(field_prefix, "_name"), fields[field_index].field_name, ctx);
            output = mir_struct_append_field(output, std.Concat(field_prefix, "_type_id"), fields[field_index].type_id, ctx);
            output = mir_struct_append_field(output, std.Concat(field_prefix, "_layout_id"), fields[field_index].layout_id, ctx);
            output = mir_struct_append_field(output, std.Concat(field_prefix, "_declaration_index"), std.FormatInt(fields[field_index].declaration_index), ctx);
            output = mir_struct_append_field(output, std.Concat(field_prefix, "_offset"), std.FormatInt(fields[field_index].offset), ctx);
            output = mir_struct_append_field(output, std.Concat(field_prefix, "_size"), std.FormatInt(fields[field_index].size), ctx);
            output = mir_struct_append_field(output, std.Concat(field_prefix, "_alignment"), std.FormatInt(fields[field_index].alignment), ctx);
            output = mir_struct_append_field(output, std.Concat(field_prefix, "_is_aggregate"), std.FormatInt(fields[field_index].is_aggregate), ctx);
            field_index = field_index + 1;
        }
        mut leaves: std.Vector[MirStructLeaf[ctx], ctx] := ctx[mir_struct_leaves(table, value.layout_id, ctx)];
        output = mir_struct_append_field(output, std.Concat(prefix, "_leaf_count"), std.FormatInt(len(leaves)), ctx);
        mut leaf_index := 0;
        while leaf_index < len(leaves) {
            mut leaf_prefix := std.Concat(prefix, std.Concat("_leaf_", std.FormatInt(leaf_index)));
            output = mir_struct_append_field(output, std.Concat(leaf_prefix, "_path"), leaves[leaf_index].path, ctx);
            output = mir_struct_append_field(output, std.Concat(leaf_prefix, "_type_id"), leaves[leaf_index].type_id, ctx);
            output = mir_struct_append_field(output, std.Concat(leaf_prefix, "_offset"), std.FormatInt(leaves[leaf_index].offset), ctx);
            output = mir_struct_append_field(output, std.Concat(leaf_prefix, "_size"), std.FormatInt(leaves[leaf_index].size), ctx);
            output = mir_struct_append_field(output, std.Concat(leaf_prefix, "_alignment"), std.FormatInt(leaves[leaf_index].alignment), ctx);
            leaf_index = leaf_index + 1;
        }
        index = index + 1;
    }

    mut values: std.Vector[MirStructValue[ctx], ctx] := ctx[table.values];
    output = mir_struct_append_field(output, "struct_value_count", std.FormatInt(len(values)), ctx);
    index = 0;
    while index < len(values) {
        mut value_prefix := std.Concat("struct_value_", std.FormatInt(index));
        output = mir_struct_append_field(output, std.Concat(value_prefix, "_id"), values[index].value_id, ctx);
        output = mir_struct_append_field(output, std.Concat(value_prefix, "_layout_id"), values[index].layout_id, ctx);
        mut scalars: std.Vector[int, ctx] := ctx[values[index].scalar_values];
        output = mir_struct_append_field(output, std.Concat(value_prefix, "_scalar_count"), std.FormatInt(len(scalars)), ctx);
        mut scalar_index := 0;
        while scalar_index < len(scalars) {
            output = mir_struct_append_field(output, std.Concat(value_prefix, std.Concat("_scalar_", std.FormatInt(scalar_index))), std.FormatInt(scalars[scalar_index]), ctx);
            scalar_index = scalar_index + 1;
        }
        output = mir_struct_append_field(output, std.Concat(value_prefix, "_storage_region"), values[index].storage_region, ctx);
        output = mir_struct_append_field(output, std.Concat(value_prefix, "_flow_origin"), values[index].flow_origin, ctx);
        index = index + 1;
    }

    mut operations: std.Vector[MirStructOperation[ctx], ctx] := ctx[table.operations];
    output = mir_struct_append_field(output, "struct_operation_count", std.FormatInt(len(operations)), ctx);
    index = 0;
    while index < len(operations) {
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

func mir_struct_witness(table: MirStructTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_struct_table_is_valid(table, layout_table, ctx) == 0 || mir_struct_table_is_legacy_empty(table, ctx) == 1 { return ""; }
    mut output := "struct_layout_status: valid\n";
    output = mir_struct_append_field(output, "struct_target", table.target_triple, ctx);
    output = mir_struct_append_field(output, "struct_target_id", table.target_id, ctx);
    output = mir_struct_append_field(output, "struct_field_order_policy", table.field_order_policy, ctx);
    output = mir_struct_append_field(output, "struct_offset_authority", table.offset_authority, ctx);
    output = mir_struct_append_field(output, "struct_padding_policy", table.padding_policy, ctx);

    mut layouts: std.Vector[MirStructLayout[ctx], ctx] := ctx[table.layouts];
    mut index := 0;
    while index < len(layouts) {
        mut value := layouts[index];
        mut line := "struct_layout: ";
        line = std.Concat(line, value.layout_id);
        line = std.Concat(line, " type="); line = std.Concat(line, value.struct_type_id);
        line = std.Concat(line, " size="); line = std.Concat(line, std.FormatInt(value.size));
        line = std.Concat(line, " alignment="); line = std.Concat(line, std.FormatInt(value.alignment));
        line = std.Concat(line, " nesting="); line = std.Concat(line, std.Concat(std.FormatInt(value.nesting_depth), "\n"));
        output = std.Concat(output, line);
        mut fields: std.Vector[MirStructField[ctx], ctx] := ctx[value.fields];
        mut field_index := 0;
        while field_index < len(fields) {
            mut field := fields[field_index];
            mut field_line := "struct_field: ";
            field_line = std.Concat(field_line, std.Concat(value.struct_type_id, std.Concat(".", field.field_name)));
            field_line = std.Concat(field_line, " declaration_index="); field_line = std.Concat(field_line, std.FormatInt(field.declaration_index));
            field_line = std.Concat(field_line, " type="); field_line = std.Concat(field_line, field.type_id);
            field_line = std.Concat(field_line, " offset="); field_line = std.Concat(field_line, std.FormatInt(field.offset));
            field_line = std.Concat(field_line, " size="); field_line = std.Concat(field_line, std.FormatInt(field.size));
            field_line = std.Concat(field_line, " alignment="); field_line = std.Concat(field_line, std.FormatInt(field.alignment));
            field_line = std.Concat(field_line, " aggregate="); field_line = std.Concat(field_line, std.Concat(std.FormatInt(field.is_aggregate), "\n"));
            output = std.Concat(output, field_line);
            field_index = field_index + 1;
        }
        mut leaves: std.Vector[MirStructLeaf[ctx], ctx] := ctx[mir_struct_leaves(table, value.layout_id, ctx)];
        mut leaf_index := 0;
        while leaf_index < len(leaves) {
            mut leaf := leaves[leaf_index];
            mut leaf_line := "struct_leaf: ";
            leaf_line = std.Concat(leaf_line, std.Concat(value.struct_type_id, std.Concat(".", leaf.path)));
            leaf_line = std.Concat(leaf_line, " type="); leaf_line = std.Concat(leaf_line, leaf.type_id);
            leaf_line = std.Concat(leaf_line, " offset="); leaf_line = std.Concat(leaf_line, std.FormatInt(leaf.offset));
            leaf_line = std.Concat(leaf_line, " size="); leaf_line = std.Concat(leaf_line, std.Concat(std.FormatInt(leaf.size), "\n"));
            output = std.Concat(output, leaf_line);
            leaf_index = leaf_index + 1;
        }
        index = index + 1;
    }

    mut values: std.Vector[MirStructValue[ctx], ctx] := ctx[table.values];
    index = 0;
    while index < len(values) {
        mut value := values[index];
        mut line := "struct_value: ";
        line = std.Concat(line, value.value_id);
        line = std.Concat(line, " layout="); line = std.Concat(line, value.layout_id);
        line = std.Concat(line, " storage="); line = std.Concat(line, value.storage_region);
        line = std.Concat(line, " flow="); line = std.Concat(line, std.Concat(value.flow_origin, "\n"));
        output = std.Concat(output, line);
        index = index + 1;
    }

    mut operations: std.Vector[MirStructOperation[ctx], ctx] := ctx[table.operations];
    index = 0;
    while index < len(operations) {
        mut operation := operations[index];
        mut evaluation := mir_struct_evaluate(table, operation, ctx);
        mut line := "struct_operation: ";
        line = std.Concat(line, operation.operation_name);
        line = std.Concat(line, " kind="); line = std.Concat(line, operation.kind);
        mut status := "failure";
        if evaluation.success == 1 { status = "success"; }
        line = std.Concat(line, " status="); line = std.Concat(line, status);
        line = std.Concat(line, " value="); line = std.Concat(line, std.FormatInt(evaluation.value));
        line = std.Concat(line, " offset="); line = std.Concat(line, std.FormatInt(evaluation.offset));
        line = std.Concat(line, " reason="); line = std.Concat(line, std.Concat(evaluation.reason_code, "\n"));
        output = std.Concat(output, line);
        index = index + 1;
    }
    return std.Clone(ctx, output);
}
