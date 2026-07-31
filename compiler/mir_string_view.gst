// Phase 14.7 compiler-owned string-literal and borrowed string-view authority.
//
// This patch selects immutable UTF-8 literal storage and borrowed views only.
// Semantic length is always the explicit byte length, never NUL termination.
// Embedded NUL bytes are valid data. Dynamic owning strings, heap allocation,
// mutation, concatenation, and views escaping their source lifetime remain
// explicitly deferred until a runtime allocation authority is selected.

import "mir_layout.gst" as layout;

type MirStringLiteralStorage[ctx] struct {
    literal_id: str,
    symbol_name: str,
    encoding: str,
    bytes_hex: str,
    byte_length: int,
    storage_kind: str,
    lifetime_region: str,
    semantic_length_authority: str,
    embedded_nul_policy: str
}

type MirStringViewLayout[ctx] struct {
    view_type_id: str,
    layout_id: str,
    target_id: str,
    target_triple: str,
    pointer_size: int,
    pointer_alignment: int,
    size: int,
    alignment: int,
    data_pointer_offset: int,
    length_offset: int,
    length_type_id: str,
    representation_kind: str
}

type MirStringView[ctx] struct {
    view_id: str,
    source_literal_id: str,
    start: int,
    length: int,
    data_known_null: int,
    lifetime_region: str,
    source_lifetime_region: str
}

type MirStringViewOperation[ctx] struct {
    operation_id: str,
    operation_name: str,
    target_id: str,
    kind: str,
    literal_id: str,
    view_id: str,
    rhs_view_id: str,
    index: int,
    start: int,
    length: int,
    expect_success: int,
    expected_value: int,
    expected_result_start: int,
    expected_result_length: int,
    expected_reason_code: str
}

type MirStringViewTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    source_encoding: str,
    literal_encoding: str,
    embedded_nul_policy: str,
    empty_string_policy: str,
    semantic_length_authority: str,
    owning_string_policy: str,
    mutation_policy: str,
    concatenation_policy: str,
    allocation_policy: str,
    view_layout: MirStringViewLayout[ctx],
    literals: Index[std.Vector[MirStringLiteralStorage[ctx], ctx], ctx],
    views: Index[std.Vector[MirStringView[ctx], ctx], ctx],
    operations: Index[std.Vector[MirStringViewOperation[ctx], ctx], ctx]
}

type MirStringLiteralQuery[ctx] struct {
    found: int,
    literal: MirStringLiteralStorage[ctx]
}

type MirStringViewQuery[ctx] struct {
    found: int,
    view: MirStringView[ctx]
}

type MirStringViewOperationQuery[ctx] struct {
    found: int,
    operation: MirStringViewOperation[ctx]
}

type MirStringViewEvaluation[ctx] struct {
    success: int,
    value: int,
    result_start: int,
    result_length: int,
    reason_code: str
}

func mir_string_view_empty_literal_vector(ctx: &Arena) Index[std.Vector[MirStringLiteralStorage[ctx], ctx], ctx] {
    mut values: std.Vector[MirStringLiteralStorage[ctx], ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[MirStringLiteralStorage[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_string_view_empty_view_vector(ctx: &Arena) Index[std.Vector[MirStringView[ctx], ctx], ctx] {
    mut values: std.Vector[MirStringView[ctx], ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[MirStringView[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_string_view_empty_operation_vector(ctx: &Arena) Index[std.Vector[MirStringViewOperation[ctx], ctx], ctx] {
    mut values: std.Vector[MirStringViewOperation[ctx], ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[MirStringViewOperation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_string_view_make_empty_layout(target_triple: str, ctx: &Arena) MirStringViewLayout[ctx] {
    mut result: MirStringViewLayout[ctx];
    result.view_type_id = std.Clone(ctx, "type:gust:str_view");
    result.layout_id = std.Clone(ctx, "");
    result.target_id = std.Clone(ctx, "");
    result.target_triple = std.Clone(ctx, target_triple);
    result.pointer_size = 0;
    result.pointer_alignment = 0;
    result.size = 0;
    result.alignment = 0;
    result.data_pointer_offset = 0;
    result.length_offset = 0;
    result.length_type_id = std.Clone(ctx, "type:gust:usize");
    result.representation_kind = std.Clone(ctx, "data_pointer_and_usize_length");
    return result;
}

func mir_string_view_make_empty_table(target_triple: str, ctx: &Arena) MirStringViewTable[ctx] {
    mut table: MirStringViewTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_string_view_table.v1");
    table.target_id = std.Clone(ctx, "");
    table.target_triple = std.Clone(ctx, target_triple);
    table.source_encoding = std.Clone(ctx, "utf8");
    table.literal_encoding = std.Clone(ctx, "utf8");
    table.embedded_nul_policy = std.Clone(ctx, "valid_data_byte_not_terminator");
    table.empty_string_policy = std.Clone(ctx, "non_null_static_empty_storage_with_zero_length");
    table.semantic_length_authority = std.Clone(ctx, "explicit_byte_length_not_nul_termination");
    table.owning_string_policy = std.Clone(ctx, "deferred_no_heap_allocation_authority");
    table.mutation_policy = std.Clone(ctx, "deferred_immutable_literal_backed_views");
    table.concatenation_policy = std.Clone(ctx, "deferred_requires_owning_allocation");
    table.allocation_policy = std.Clone(ctx, "deferred_no_runtime_heap_authority");
    table.view_layout = mir_string_view_make_empty_layout(target_triple, ctx);
    table.literals = mir_string_view_empty_literal_vector(ctx);
    table.views = mir_string_view_empty_view_vector(ctx);
    table.operations = mir_string_view_empty_operation_vector(ctx);
    return table;
}

func mir_string_view_table_is_legacy_empty(table: MirStringViewTable[ctx], ctx: &Arena) int {
    mut literals: std.Vector[MirStringLiteralStorage[ctx], ctx] := ctx[table.literals];
    mut views: std.Vector[MirStringView[ctx], ctx] := ctx[table.views];
    mut operations: std.Vector[MirStringViewOperation[ctx], ctx] := ctx[table.operations];
    if len(table.target_id) == 0 &&
       len(table.view_layout.layout_id) == 0 &&
       len(literals) == 0 && len(views) == 0 && len(operations) == 0
    {
        return 1;
    }
    return 0;
}

func mir_string_view_field_is_safe(value: str, allow_empty: int) int {
    if allow_empty == 0 && len(value) == 0 { return 0; }
    if std.str_find(value, "\n") != 0 - 1 { return 0; }
    if std.str_find(value, "\r") != 0 - 1 { return 0; }
    return 1;
}

func mir_string_view_hex_nibble(value: int) int {
    if value >= 48 && value <= 57 { return value - 48; }
    if value >= 65 && value <= 70 { return value - 65 + 10; }
    if value >= 97 && value <= 102 { return value - 97 + 10; }
    return 0 - 1;
}

func mir_string_view_hex_is_valid(value: str) int {
    mut half := len(value) / 2;
    if half * 2 != len(value) { return 0; }
    mut index := 0;
    while index < len(value) {
        if mir_string_view_hex_nibble(std.str_byte_at(value, index)) < 0 {
            return 0;
        }
        index = index + 1;
    }
    return 1;
}

func mir_string_view_hex_byte(value: str, byte_index: int) int {
    mut first_index := byte_index * 2;
    mut high := mir_string_view_hex_nibble(std.str_byte_at(value, first_index));
    mut low := mir_string_view_hex_nibble(std.str_byte_at(value, first_index + 1));
    return high * 16 + low;
}

func mir_string_view_operation_kind_is_valid(kind: str) int {
    if std.str_eq(kind, "literal_create") == 1 { return 1; }
    if std.str_eq(kind, "view_create") == 1 { return 1; }
    if std.str_eq(kind, "length") == 1 { return 1; }
    if std.str_eq(kind, "is_empty") == 1 { return 1; }
    if std.str_eq(kind, "byte_at") == 1 { return 1; }
    if std.str_eq(kind, "slice") == 1 { return 1; }
    if std.str_eq(kind, "byte_equal") == 1 { return 1; }
    return 0;
}

func mir_string_literal_identity(encoding: str, bytes_hex: str, ctx: &Arena) str {
    mut identity := "string_literal:v1:encoding=";
    identity = std.Concat(identity, encoding);
    identity = std.Concat(identity, ":bytes=");
    identity = std.Concat(identity, bytes_hex);
    return std.Clone(ctx, identity);
}

func mir_string_view_layout_identity(target_id: str, pointer_size: int, pointer_alignment: int, ctx: &Arena) str {
    mut identity := "string_view_layout:v1:target=";
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":pointer_size=");
    identity = std.Concat(identity, std.FormatInt(pointer_size));
    identity = std.Concat(identity, ":pointer_align=");
    identity = std.Concat(identity, std.FormatInt(pointer_alignment));
    identity = std.Concat(identity, ":data_offset=0:length_offset=");
    identity = std.Concat(identity, std.FormatInt(pointer_size));
    identity = std.Concat(identity, ":size=");
    identity = std.Concat(identity, std.FormatInt(pointer_size * 2));
    return std.Clone(ctx, identity);
}

func mir_string_view_identity(source_literal_id: str, start: int, length: int, lifetime_region: str, ctx: &Arena) str {
    mut identity := "string_view:v1:literal=";
    identity = std.Concat(identity, source_literal_id);
    identity = std.Concat(identity, ":start=");
    identity = std.Concat(identity, std.FormatInt(start));
    identity = std.Concat(identity, ":length=");
    identity = std.Concat(identity, std.FormatInt(length));
    identity = std.Concat(identity, ":lifetime=");
    identity = std.Concat(identity, lifetime_region);
    return std.Clone(ctx, identity);
}

func mir_string_view_operation_identity(target_id: str, operation_name: str, kind: str, ctx: &Arena) str {
    mut identity := "string_view_operation:v1:target=";
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":name=");
    identity = std.Concat(identity, operation_name);
    identity = std.Concat(identity, ":kind=");
    identity = std.Concat(identity, kind);
    return std.Clone(ctx, identity);
}

func mir_string_view_make_layout(layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) MirStringViewLayout[ctx] {
    mut result: MirStringViewLayout[ctx];
    result.view_type_id = std.Clone(ctx, "type:gust:str_view");
    result.target_id = std.Clone(ctx, layout_table.target.target_id);
    result.target_triple = std.Clone(ctx, layout_table.target.target_triple);
    result.pointer_size = layout_table.target.pointer_size;
    result.pointer_alignment = layout_table.target.pointer_alignment;
    result.size = layout_table.target.pointer_size * 2;
    result.alignment = layout_table.target.pointer_alignment;
    result.data_pointer_offset = 0;
    result.length_offset = layout_table.target.pointer_size;
    result.length_type_id = std.Clone(ctx, "type:gust:usize");
    result.representation_kind = std.Clone(ctx, "data_pointer_and_usize_length");
    result.layout_id = mir_string_view_layout_identity(
        result.target_id,
        result.pointer_size,
        result.pointer_alignment,
        ctx
    );
    return result;
}

func mir_string_view_make_literal(symbol_name: str, bytes_hex: str, ctx: &Arena) MirStringLiteralStorage[ctx] {
    mut literal: MirStringLiteralStorage[ctx];
    literal.encoding = std.Clone(ctx, "utf8");
    literal.bytes_hex = std.Clone(ctx, bytes_hex);
    literal.byte_length = len(bytes_hex) / 2;
    literal.literal_id = mir_string_literal_identity(literal.encoding, bytes_hex, ctx);
    literal.symbol_name = std.Clone(ctx, symbol_name);
    literal.storage_kind = std.Clone(ctx, "static_read_only_literal");
    literal.lifetime_region = std.Clone(ctx, "static_program");
    literal.semantic_length_authority = std.Clone(ctx, "explicit_byte_length_not_nul_termination");
    literal.embedded_nul_policy = std.Clone(ctx, "valid_data_byte_not_terminator");
    return literal;
}

func mir_string_view_make_view(literal: MirStringLiteralStorage[ctx], start: int, length: int, ctx: &Arena) MirStringView[ctx] {
    mut view: MirStringView[ctx];
    view.source_literal_id = std.Clone(ctx, literal.literal_id);
    view.start = start;
    view.length = length;
    view.data_known_null = 0;
    view.lifetime_region = std.Clone(ctx, "static_program");
    view.source_lifetime_region = std.Clone(ctx, literal.lifetime_region);
    view.view_id = mir_string_view_identity(
        view.source_literal_id,
        view.start,
        view.length,
        view.lifetime_region,
        ctx
    );
    return view;
}

func mir_string_view_make_operation(table: MirStringViewTable[ctx], operation_name: str, kind: str, literal_id: str, view_id: str, rhs_view_id: str, index: int, start: int, length: int, expect_success: int, expected_value: int, expected_result_start: int, expected_result_length: int, expected_reason_code: str, ctx: &Arena) MirStringViewOperation[ctx] {
    mut operation: MirStringViewOperation[ctx];
    operation.operation_name = std.Clone(ctx, operation_name);
    operation.target_id = std.Clone(ctx, table.target_id);
    operation.kind = std.Clone(ctx, kind);
    operation.literal_id = std.Clone(ctx, literal_id);
    operation.view_id = std.Clone(ctx, view_id);
    operation.rhs_view_id = std.Clone(ctx, rhs_view_id);
    operation.index = index;
    operation.start = start;
    operation.length = length;
    operation.expect_success = expect_success;
    operation.expected_value = expected_value;
    operation.expected_result_start = expected_result_start;
    operation.expected_result_length = expected_result_length;
    operation.expected_reason_code = std.Clone(ctx, expected_reason_code);
    operation.operation_id = mir_string_view_operation_identity(
        operation.target_id,
        operation.operation_name,
        operation.kind,
        ctx
    );
    return operation;
}

func mir_string_view_table_with_literal(table: MirStringViewTable[ctx], literal: MirStringLiteralStorage[ctx], ctx: &Arena) MirStringViewTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirStringLiteralStorage[ctx], ctx] := ctx[updated.literals];
    values.Push(literal);
    ctx.Set(updated.literals, values);
    return updated;
}

func mir_string_view_table_with_view(table: MirStringViewTable[ctx], view: MirStringView[ctx], ctx: &Arena) MirStringViewTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirStringView[ctx], ctx] := ctx[updated.views];
    values.Push(view);
    ctx.Set(updated.views, values);
    return updated;
}

func mir_string_view_table_with_operation(table: MirStringViewTable[ctx], operation: MirStringViewOperation[ctx], ctx: &Arena) MirStringViewTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirStringViewOperation[ctx], ctx] := ctx[updated.operations];
    values.Push(operation);
    ctx.Set(updated.operations, values);
    return updated;
}

func mir_string_view_literal(table: MirStringViewTable[ctx], literal_id: str, ctx: &Arena) MirStringLiteralQuery[ctx] {
    mut result: MirStringLiteralQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirStringLiteralStorage[ctx], ctx] := ctx[table.literals];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].literal_id, literal_id) == 1 {
            result.found = 1;
            result.literal = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_string_view_view(table: MirStringViewTable[ctx], view_id: str, ctx: &Arena) MirStringViewQuery[ctx] {
    mut result: MirStringViewQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirStringView[ctx], ctx] := ctx[table.views];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].view_id, view_id) == 1 {
            result.found = 1;
            result.view = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_string_view_operation(table: MirStringViewTable[ctx], operation_name: str, ctx: &Arena) MirStringViewOperationQuery[ctx] {
    mut result: MirStringViewOperationQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirStringViewOperation[ctx], ctx] := ctx[table.operations];
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

func mir_string_view_evaluation(success: int, value: int, result_start: int, result_length: int, reason_code: str, ctx: &Arena) MirStringViewEvaluation[ctx] {
    mut result: MirStringViewEvaluation[ctx];
    result.success = success;
    result.value = value;
    result.result_start = result_start;
    result.result_length = result_length;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_string_view_rejection(kind: str, ctx: &Arena) MirStringViewEvaluation[ctx] {
    if std.str_eq(kind, "invalid_pointer_length_pair") == 1 {
        return mir_string_view_evaluation(0, 0, 0, 0, "string_view_null_nonempty", ctx);
    }
    if std.str_eq(kind, "lifetime_escape") == 1 {
        return mir_string_view_evaluation(0, 0, 0, 0, "string_view_lifetime_escape", ctx);
    }
    if std.str_eq(kind, "unsupported_mutation") == 1 {
        return mir_string_view_evaluation(0, 0, 0, 0, "string_mutation_unsupported", ctx);
    }
    if std.str_eq(kind, "unsupported_allocation") == 1 {
        return mir_string_view_evaluation(0, 0, 0, 0, "string_allocation_unsupported", ctx);
    }
    if std.str_eq(kind, "unsupported_concatenation") == 1 {
        return mir_string_view_evaluation(0, 0, 0, 0, "string_concatenation_unsupported", ctx);
    }
    if std.str_eq(kind, "invalid_encoding") == 1 {
        return mir_string_view_evaluation(0, 0, 0, 0, "string_encoding_invalid", ctx);
    }
    if std.str_eq(kind, "out_of_bounds_view") == 1 {
        return mir_string_view_evaluation(0, 0, 0, 0, "string_view_out_of_bounds", ctx);
    }
    if std.str_eq(kind, "null_empty_view") == 1 {
        return mir_string_view_evaluation(0, 0, 0, 0, "string_view_empty_pointer_must_be_non_null", ctx);
    }
    if std.str_eq(kind, "literal_identity_mismatch") == 1 {
        return mir_string_view_evaluation(0, 0, 0, 0, "string_literal_identity_mismatch", ctx);
    }
    return mir_string_view_evaluation(0, 0, 0, 0, "string_view_request_invalid", ctx);
}

func mir_string_view_operation_request_is_supported(kind: str, ctx: &Arena) MirStringViewEvaluation[ctx] {
    if mir_string_view_operation_kind_is_valid(kind) == 1 {
        return mir_string_view_evaluation(1, 0, 0, 0, "string_view_valid", ctx);
    }
    if std.str_eq(kind, "mutation") == 1 {
        return mir_string_view_rejection("unsupported_mutation", ctx);
    }
    if std.str_eq(kind, "allocation") == 1 || std.str_eq(kind, "owning_string_create") == 1 {
        return mir_string_view_rejection("unsupported_allocation", ctx);
    }
    if std.str_eq(kind, "concatenation") == 1 {
        return mir_string_view_rejection("unsupported_concatenation", ctx);
    }
    return mir_string_view_evaluation(0, 0, 0, 0, "string_operation_unsupported", ctx);
}

func mir_string_view_byte_equal(lhs_literal: MirStringLiteralStorage[ctx], lhs: MirStringView[ctx], rhs_literal: MirStringLiteralStorage[ctx], rhs: MirStringView[ctx]) int {
    if lhs.length != rhs.length { return 0; }
    mut index := 0;
    while index < lhs.length {
        mut lhs_byte := mir_string_view_hex_byte(lhs_literal.bytes_hex, lhs.start + index);
        mut rhs_byte := mir_string_view_hex_byte(rhs_literal.bytes_hex, rhs.start + index);
        if lhs_byte != rhs_byte { return 0; }
        index = index + 1;
    }
    return 1;
}

func mir_string_view_evaluate(table: MirStringViewTable[ctx], operation: MirStringViewOperation[ctx], ctx: &Arena) MirStringViewEvaluation[ctx] {
    if std.str_eq(operation.kind, "literal_create") == 1 {
        mut literal := mir_string_view_literal(table, operation.literal_id, ctx);
        if literal.found == 0 { return mir_string_view_rejection("literal_identity_mismatch", ctx); }
        return mir_string_view_evaluation(1, literal.literal.byte_length, 0, literal.literal.byte_length, "string_view_valid", ctx);
    }

    if std.str_eq(operation.kind, "view_create") == 1 {
        mut literal := mir_string_view_literal(table, operation.literal_id, ctx);
        if literal.found == 0 { return mir_string_view_rejection("literal_identity_mismatch", ctx); }
        if operation.start < 0 || operation.length < 0 ||
           operation.start + operation.length > literal.literal.byte_length
        {
            return mir_string_view_rejection("out_of_bounds_view", ctx);
        }
        return mir_string_view_evaluation(1, operation.length, operation.start, operation.length, "string_view_valid", ctx);
    }

    mut view_query := mir_string_view_view(table, operation.view_id, ctx);
    if view_query.found == 0 {
        return mir_string_view_evaluation(0, 0, 0, 0, "string_view_unknown", ctx);
    }
    mut view := view_query.view;
    mut literal_query := mir_string_view_literal(table, view.source_literal_id, ctx);
    if literal_query.found == 0 { return mir_string_view_rejection("literal_identity_mismatch", ctx); }

    if std.str_eq(operation.kind, "length") == 1 {
        return mir_string_view_evaluation(1, view.length, view.start, view.length, "string_view_valid", ctx);
    }
    if std.str_eq(operation.kind, "is_empty") == 1 {
        mut value := 0;
        if view.length == 0 { value = 1; }
        return mir_string_view_evaluation(1, value, view.start, view.length, "string_view_valid", ctx);
    }
    if std.str_eq(operation.kind, "byte_at") == 1 {
        if operation.index < 0 || operation.index >= view.length {
            return mir_string_view_rejection("out_of_bounds_view", ctx);
        }
        mut value := mir_string_view_hex_byte(
            literal_query.literal.bytes_hex,
            view.start + operation.index
        );
        return mir_string_view_evaluation(1, value, view.start, view.length, "string_view_valid", ctx);
    }
    if std.str_eq(operation.kind, "slice") == 1 {
        if operation.start < 0 || operation.length < 0 ||
           operation.start + operation.length > view.length
        {
            return mir_string_view_rejection("out_of_bounds_view", ctx);
        }
        return mir_string_view_evaluation(
            1,
            operation.length,
            view.start + operation.start,
            operation.length,
            "string_view_valid",
            ctx
        );
    }
    if std.str_eq(operation.kind, "byte_equal") == 1 {
        mut rhs_query := mir_string_view_view(table, operation.rhs_view_id, ctx);
        if rhs_query.found == 0 {
            return mir_string_view_evaluation(0, 0, 0, 0, "string_view_unknown", ctx);
        }
        mut rhs_literal_query := mir_string_view_literal(table, rhs_query.view.source_literal_id, ctx);
        if rhs_literal_query.found == 0 { return mir_string_view_rejection("literal_identity_mismatch", ctx); }
        mut value := mir_string_view_byte_equal(
            literal_query.literal,
            view,
            rhs_literal_query.literal,
            rhs_query.view
        );
        return mir_string_view_evaluation(1, value, view.start, view.length, "string_view_valid", ctx);
    }
    return mir_string_view_operation_request_is_supported(operation.kind, ctx);
}

func mir_string_view_table_is_valid(table: MirStringViewTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if std.str_eq(table.format, "gust.compiler_string_view_table.v1") == 0 { return 0; }
    if mir_string_view_table_is_legacy_empty(table, ctx) == 1 { return 1; }
    if layout.mir_layout_table_is_valid(layout_table, ctx) == 0 { return 0; }
    if std.str_eq(table.target_id, layout_table.target.target_id) == 0 ||
       std.str_eq(table.target_triple, layout_table.target.target_triple) == 0
    {
        return 0;
    }
    if std.str_eq(table.source_encoding, "utf8") == 0 ||
       std.str_eq(table.literal_encoding, "utf8") == 0 ||
       std.str_eq(table.embedded_nul_policy, "valid_data_byte_not_terminator") == 0 ||
       std.str_eq(table.empty_string_policy, "non_null_static_empty_storage_with_zero_length") == 0 ||
       std.str_eq(table.semantic_length_authority, "explicit_byte_length_not_nul_termination") == 0 ||
       std.str_eq(table.owning_string_policy, "deferred_no_heap_allocation_authority") == 0 ||
       std.str_eq(table.mutation_policy, "deferred_immutable_literal_backed_views") == 0 ||
       std.str_eq(table.concatenation_policy, "deferred_requires_owning_allocation") == 0 ||
       std.str_eq(table.allocation_policy, "deferred_no_runtime_heap_authority") == 0
    {
        return 0;
    }

    mut view_layout := table.view_layout;
    if std.str_eq(view_layout.view_type_id, "type:gust:str_view") == 0 ||
       std.str_eq(view_layout.target_id, table.target_id) == 0 ||
       std.str_eq(view_layout.target_triple, table.target_triple) == 0 ||
       view_layout.pointer_size != layout_table.target.pointer_size ||
       view_layout.pointer_alignment != layout_table.target.pointer_alignment ||
       view_layout.size != view_layout.pointer_size * 2 ||
       view_layout.alignment != view_layout.pointer_alignment ||
       view_layout.data_pointer_offset != 0 ||
       view_layout.length_offset != view_layout.pointer_size ||
       std.str_eq(view_layout.length_type_id, "type:gust:usize") == 0 ||
       std.str_eq(view_layout.representation_kind, "data_pointer_and_usize_length") == 0
    {
        return 0;
    }
    mut expected_layout_id := mir_string_view_layout_identity(
        view_layout.target_id,
        view_layout.pointer_size,
        view_layout.pointer_alignment,
        ctx
    );
    if std.str_eq(view_layout.layout_id, expected_layout_id) == 0 { return 0; }

    mut literals: std.Vector[MirStringLiteralStorage[ctx], ctx] := ctx[table.literals];
    mut views: std.Vector[MirStringView[ctx], ctx] := ctx[table.views];
    mut operations: std.Vector[MirStringViewOperation[ctx], ctx] := ctx[table.operations];
    if len(literals) != 4 || len(views) != 4 || len(operations) != 13 { return 0; }

    mut literal_index := 0;
    while literal_index < len(literals) {
        mut literal := literals[literal_index];
        if mir_string_view_field_is_safe(literal.literal_id, 0) == 0 ||
           mir_string_view_field_is_safe(literal.symbol_name, 0) == 0 ||
           std.str_eq(literal.encoding, "utf8") == 0 ||
           mir_string_view_hex_is_valid(literal.bytes_hex) == 0 ||
           literal.byte_length != len(literal.bytes_hex) / 2 ||
           std.str_eq(literal.storage_kind, "static_read_only_literal") == 0 ||
           std.str_eq(literal.lifetime_region, "static_program") == 0 ||
           std.str_eq(literal.semantic_length_authority, table.semantic_length_authority) == 0 ||
           std.str_eq(literal.embedded_nul_policy, table.embedded_nul_policy) == 0
        {
            return 0;
        }
        mut expected_literal_id := mir_string_literal_identity(literal.encoding, literal.bytes_hex, ctx);
        if std.str_eq(literal.literal_id, expected_literal_id) == 0 { return 0; }
        mut prior_literal_index := 0;
        while prior_literal_index < literal_index {
            if std.str_eq(literals[prior_literal_index].literal_id, literal.literal_id) == 1 ||
               std.str_eq(literals[prior_literal_index].symbol_name, literal.symbol_name) == 1
            {
                return 0;
            }
            prior_literal_index = prior_literal_index + 1;
        }
        literal_index = literal_index + 1;
    }

    mut view_index := 0;
    while view_index < len(views) {
        mut view := views[view_index];
        mut source := mir_string_view_literal(table, view.source_literal_id, ctx);
        if source.found == 0 || view.start < 0 || view.length < 0 ||
           view.start + view.length > source.literal.byte_length ||
           view.data_known_null != 0 ||
           std.str_eq(view.lifetime_region, source.literal.lifetime_region) == 0 ||
           std.str_eq(view.source_lifetime_region, source.literal.lifetime_region) == 0
        {
            return 0;
        }
        mut expected_view_id := mir_string_view_identity(
            view.source_literal_id,
            view.start,
            view.length,
            view.lifetime_region,
            ctx
        );
        if std.str_eq(view.view_id, expected_view_id) == 0 { return 0; }
        mut prior_view_index := 0;
        while prior_view_index < view_index {
            if std.str_eq(views[prior_view_index].view_id, view.view_id) == 1 { return 0; }
            prior_view_index = prior_view_index + 1;
        }
        view_index = view_index + 1;
    }

    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        if mir_string_view_operation_kind_is_valid(operation.kind) == 0 ||
           std.str_eq(operation.target_id, table.target_id) == 0 ||
           operation.expect_success != 1 ||
           std.str_eq(operation.expected_reason_code, "string_view_valid") == 0
        {
            return 0;
        }
        mut expected_operation_id := mir_string_view_operation_identity(
            operation.target_id,
            operation.operation_name,
            operation.kind,
            ctx
        );
        if std.str_eq(operation.operation_id, expected_operation_id) == 0 { return 0; }
        mut evaluation := mir_string_view_evaluate(table, operation, ctx);
        if evaluation.success != operation.expect_success ||
           evaluation.value != operation.expected_value ||
           evaluation.result_start != operation.expected_result_start ||
           evaluation.result_length != operation.expected_result_length ||
           std.str_eq(evaluation.reason_code, operation.expected_reason_code) == 0
        {
            return 0;
        }
        mut prior_operation_index := 0;
        while prior_operation_index < operation_index {
            if std.str_eq(operations[prior_operation_index].operation_id, operation.operation_id) == 1 ||
               std.str_eq(operations[prior_operation_index].operation_name, operation.operation_name) == 1
            {
                return 0;
            }
            prior_operation_index = prior_operation_index + 1;
        }
        operation_index = operation_index + 1;
    }
    return 1;
}

func mir_string_view_table_for_layout(layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) MirStringViewTable[ctx] {
    mut table := mir_string_view_make_empty_table(layout_table.target.target_triple, ctx);
    table.target_id = std.Clone(ctx, layout_table.target.target_id);
    table.view_layout = mir_string_view_make_layout(layout_table, ctx);

    mut empty_literal := mir_string_view_make_literal("gust_string_literal_empty", "", ctx);
    mut gust := mir_string_view_make_literal("gust_string_literal_gust", "67757374", ctx);
    mut embedded := mir_string_view_make_literal("gust_string_literal_embedded_nul", "610062", ctx);
    mut rust := mir_string_view_make_literal("gust_string_literal_rust", "72757374", ctx);
    table = mir_string_view_table_with_literal(table, empty_literal, ctx);
    table = mir_string_view_table_with_literal(table, gust, ctx);
    table = mir_string_view_table_with_literal(table, embedded, ctx);
    table = mir_string_view_table_with_literal(table, rust, ctx);

    mut empty_view := mir_string_view_make_view(empty_literal, 0, 0, ctx);
    mut gust_view := mir_string_view_make_view(gust, 0, 4, ctx);
    mut embedded_view := mir_string_view_make_view(embedded, 0, 3, ctx);
    mut rust_view := mir_string_view_make_view(rust, 0, 4, ctx);
    table = mir_string_view_table_with_view(table, empty_view, ctx);
    table = mir_string_view_table_with_view(table, gust_view, ctx);
    table = mir_string_view_table_with_view(table, embedded_view, ctx);
    table = mir_string_view_table_with_view(table, rust_view, ctx);

    table = mir_string_view_table_with_operation(table, mir_string_view_make_operation(
        table, "literal_create_empty", "literal_create", empty_literal.literal_id, "", "", 0, 0, 0,
        1, 0, 0, 0, "string_view_valid", ctx
    ), ctx);
    table = mir_string_view_table_with_operation(table, mir_string_view_make_operation(
        table, "literal_create_gust", "literal_create", gust.literal_id, "", "", 0, 0, 0,
        1, 4, 0, 4, "string_view_valid", ctx
    ), ctx);
    table = mir_string_view_table_with_operation(table, mir_string_view_make_operation(
        table, "literal_create_embedded_nul", "literal_create", embedded.literal_id, "", "", 0, 0, 0,
        1, 3, 0, 3, "string_view_valid", ctx
    ), ctx);
    table = mir_string_view_table_with_operation(table, mir_string_view_make_operation(
        table, "view_create_gust", "view_create", gust.literal_id, "", "", 0, 0, 4,
        1, 4, 0, 4, "string_view_valid", ctx
    ), ctx);
    table = mir_string_view_table_with_operation(table, mir_string_view_make_operation(
        table, "length_empty", "length", "", empty_view.view_id, "", 0, 0, 0,
        1, 0, 0, 0, "string_view_valid", ctx
    ), ctx);
    table = mir_string_view_table_with_operation(table, mir_string_view_make_operation(
        table, "length_gust", "length", "", gust_view.view_id, "", 0, 0, 0,
        1, 4, 0, 4, "string_view_valid", ctx
    ), ctx);
    table = mir_string_view_table_with_operation(table, mir_string_view_make_operation(
        table, "is_empty_empty", "is_empty", "", empty_view.view_id, "", 0, 0, 0,
        1, 1, 0, 0, "string_view_valid", ctx
    ), ctx);
    table = mir_string_view_table_with_operation(table, mir_string_view_make_operation(
        table, "is_empty_gust", "is_empty", "", gust_view.view_id, "", 0, 0, 0,
        1, 0, 0, 4, "string_view_valid", ctx
    ), ctx);
    table = mir_string_view_table_with_operation(table, mir_string_view_make_operation(
        table, "byte_at_gust_1", "byte_at", "", gust_view.view_id, "", 1, 0, 0,
        1, 117, 0, 4, "string_view_valid", ctx
    ), ctx);
    table = mir_string_view_table_with_operation(table, mir_string_view_make_operation(
        table, "byte_at_embedded_nul_1", "byte_at", "", embedded_view.view_id, "", 1, 0, 0,
        1, 0, 0, 3, "string_view_valid", ctx
    ), ctx);
    table = mir_string_view_table_with_operation(table, mir_string_view_make_operation(
        table, "slice_gust_1_2", "slice", "", gust_view.view_id, "", 0, 1, 2,
        1, 2, 1, 2, "string_view_valid", ctx
    ), ctx);
    table = mir_string_view_table_with_operation(table, mir_string_view_make_operation(
        table, "byte_equal_gust_gust", "byte_equal", "", gust_view.view_id, gust_view.view_id, 0, 0, 0,
        1, 1, 0, 4, "string_view_valid", ctx
    ), ctx);
    table = mir_string_view_table_with_operation(table, mir_string_view_make_operation(
        table, "byte_equal_gust_rust", "byte_equal", "", gust_view.view_id, rust_view.view_id, 0, 0, 0,
        1, 0, 0, 4, "string_view_valid", ctx
    ), ctx);
    return table;
}

func mir_string_view_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut updated := std.Concat(output, key);
    updated = std.Concat(updated, ": ");
    updated = std.Concat(updated, value);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

func mir_serialize_string_view_table_for_request(table: MirStringViewTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_string_view_table_is_legacy_empty(table, ctx) == 1 {
        return "string_view_table_format: gust.compiler_string_view_table.v1\nstring_view_target_id: \nstring_view_target_triple: legacy-empty\nstring_view_literal_count: 0\nstring_view_view_count: 0\nstring_view_operation_count: 0\n";
    }
    if mir_string_view_table_is_valid(table, layout_table, ctx) == 0 {
        return "string_view_table_format: invalid\n";
    }
    mut output := "";
    output = mir_string_view_append_field(output, "string_view_table_format", table.format, ctx);
    output = mir_string_view_append_field(output, "string_view_target_id", table.target_id, ctx);
    output = mir_string_view_append_field(output, "string_view_target_triple", table.target_triple, ctx);
    output = mir_string_view_append_field(output, "string_view_source_encoding", table.source_encoding, ctx);
    output = mir_string_view_append_field(output, "string_view_literal_encoding", table.literal_encoding, ctx);
    output = mir_string_view_append_field(output, "string_view_embedded_nul_policy", table.embedded_nul_policy, ctx);
    output = mir_string_view_append_field(output, "string_view_empty_string_policy", table.empty_string_policy, ctx);
    output = mir_string_view_append_field(output, "string_view_semantic_length_authority", table.semantic_length_authority, ctx);
    output = mir_string_view_append_field(output, "string_view_owning_string_policy", table.owning_string_policy, ctx);
    output = mir_string_view_append_field(output, "string_view_mutation_policy", table.mutation_policy, ctx);
    output = mir_string_view_append_field(output, "string_view_concatenation_policy", table.concatenation_policy, ctx);
    output = mir_string_view_append_field(output, "string_view_allocation_policy", table.allocation_policy, ctx);

    mut view_layout := table.view_layout;
    output = mir_string_view_append_field(output, "string_view_layout_type_id", view_layout.view_type_id, ctx);
    output = mir_string_view_append_field(output, "string_view_layout_id", view_layout.layout_id, ctx);
    output = mir_string_view_append_field(output, "string_view_layout_target_id", view_layout.target_id, ctx);
    output = mir_string_view_append_field(output, "string_view_layout_pointer_size", std.FormatInt(view_layout.pointer_size), ctx);
    output = mir_string_view_append_field(output, "string_view_layout_pointer_alignment", std.FormatInt(view_layout.pointer_alignment), ctx);
    output = mir_string_view_append_field(output, "string_view_layout_size", std.FormatInt(view_layout.size), ctx);
    output = mir_string_view_append_field(output, "string_view_layout_alignment", std.FormatInt(view_layout.alignment), ctx);
    output = mir_string_view_append_field(output, "string_view_layout_data_pointer_offset", std.FormatInt(view_layout.data_pointer_offset), ctx);
    output = mir_string_view_append_field(output, "string_view_layout_length_offset", std.FormatInt(view_layout.length_offset), ctx);
    output = mir_string_view_append_field(output, "string_view_layout_length_type_id", view_layout.length_type_id, ctx);
    output = mir_string_view_append_field(output, "string_view_layout_representation_kind", view_layout.representation_kind, ctx);

    mut literals: std.Vector[MirStringLiteralStorage[ctx], ctx] := ctx[table.literals];
    output = mir_string_view_append_field(output, "string_view_literal_count", std.FormatInt(len(literals)), ctx);
    mut literal_index := 0;
    while literal_index < len(literals) {
        mut prefix := std.Concat("string_view_literal_", std.FormatInt(literal_index));
        mut literal := literals[literal_index];
        output = mir_string_view_append_field(output, std.Concat(prefix, "_id"), literal.literal_id, ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_symbol_name"), literal.symbol_name, ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_encoding"), literal.encoding, ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_bytes_hex"), literal.bytes_hex, ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_byte_length"), std.FormatInt(literal.byte_length), ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_storage_kind"), literal.storage_kind, ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_lifetime_region"), literal.lifetime_region, ctx);
        literal_index = literal_index + 1;
    }

    mut views: std.Vector[MirStringView[ctx], ctx] := ctx[table.views];
    output = mir_string_view_append_field(output, "string_view_view_count", std.FormatInt(len(views)), ctx);
    mut view_index := 0;
    while view_index < len(views) {
        mut prefix := std.Concat("string_view_view_", std.FormatInt(view_index));
        mut view := views[view_index];
        output = mir_string_view_append_field(output, std.Concat(prefix, "_id"), view.view_id, ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_source_literal_id"), view.source_literal_id, ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_start"), std.FormatInt(view.start), ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_length"), std.FormatInt(view.length), ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_data_known_null"), std.FormatInt(view.data_known_null), ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_lifetime_region"), view.lifetime_region, ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_source_lifetime_region"), view.source_lifetime_region, ctx);
        view_index = view_index + 1;
    }

    mut operations: std.Vector[MirStringViewOperation[ctx], ctx] := ctx[table.operations];
    output = mir_string_view_append_field(output, "string_view_operation_count", std.FormatInt(len(operations)), ctx);
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut prefix := std.Concat("string_view_operation_", std.FormatInt(operation_index));
        mut operation := operations[operation_index];
        output = mir_string_view_append_field(output, std.Concat(prefix, "_id"), operation.operation_id, ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_name"), operation.operation_name, ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_target_id"), operation.target_id, ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_kind"), operation.kind, ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_literal_id"), operation.literal_id, ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_view_id"), operation.view_id, ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_rhs_view_id"), operation.rhs_view_id, ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_index"), std.FormatInt(operation.index), ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_start"), std.FormatInt(operation.start), ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_length"), std.FormatInt(operation.length), ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_expect_success"), std.FormatInt(operation.expect_success), ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_expected_value"), std.FormatInt(operation.expected_value), ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_expected_result_start"), std.FormatInt(operation.expected_result_start), ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_expected_result_length"), std.FormatInt(operation.expected_result_length), ctx);
        output = mir_string_view_append_field(output, std.Concat(prefix, "_expected_reason_code"), operation.expected_reason_code, ctx);
        operation_index = operation_index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_string_view_witness(table: MirStringViewTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_string_view_table_is_valid(table, layout_table, ctx) == 0 ||
       mir_string_view_table_is_legacy_empty(table, ctx) == 1
    {
        return "";
    }
    mut output := "string_view_status: valid\n";
    output = mir_string_view_append_field(output, "string_view_target", table.target_triple, ctx);
    output = mir_string_view_append_field(output, "string_view_target_id", table.target_id, ctx);
    output = mir_string_view_append_field(output, "string_view_source_encoding", table.source_encoding, ctx);
    output = mir_string_view_append_field(output, "string_view_literal_encoding", table.literal_encoding, ctx);
    output = mir_string_view_append_field(output, "string_view_embedded_nul_policy", table.embedded_nul_policy, ctx);
    output = mir_string_view_append_field(output, "string_view_empty_string_policy", table.empty_string_policy, ctx);
    output = mir_string_view_append_field(output, "string_view_semantic_length_authority", table.semantic_length_authority, ctx);
    output = mir_string_view_append_field(output, "string_view_owning_string_policy", table.owning_string_policy, ctx);
    output = mir_string_view_append_field(output, "string_view_mutation_policy", table.mutation_policy, ctx);
    output = mir_string_view_append_field(output, "string_view_concatenation_policy", table.concatenation_policy, ctx);
    output = mir_string_view_append_field(output, "string_view_allocation_policy", table.allocation_policy, ctx);

    mut view_layout := table.view_layout;
    mut layout_line := "string_view_layout: ";
    layout_line = std.Concat(layout_line, view_layout.layout_id);
    layout_line = std.Concat(layout_line, " type=");
    layout_line = std.Concat(layout_line, view_layout.view_type_id);
    layout_line = std.Concat(layout_line, " size=");
    layout_line = std.Concat(layout_line, std.FormatInt(view_layout.size));
    layout_line = std.Concat(layout_line, " alignment=");
    layout_line = std.Concat(layout_line, std.FormatInt(view_layout.alignment));
    layout_line = std.Concat(layout_line, " data_offset=");
    layout_line = std.Concat(layout_line, std.FormatInt(view_layout.data_pointer_offset));
    layout_line = std.Concat(layout_line, " length_offset=");
    layout_line = std.Concat(layout_line, std.FormatInt(view_layout.length_offset));
    layout_line = std.Concat(layout_line, " pointer_size=");
    layout_line = std.Concat(layout_line, std.FormatInt(view_layout.pointer_size));
    layout_line = std.Concat(layout_line, "\n");
    output = std.Concat(output, layout_line);

    mut literals: std.Vector[MirStringLiteralStorage[ctx], ctx] := ctx[table.literals];
    mut literal_index := 0;
    while literal_index < len(literals) {
        mut literal := literals[literal_index];
        mut line := "string_literal: ";
        line = std.Concat(line, literal.literal_id);
        line = std.Concat(line, " symbol=");
        line = std.Concat(line, literal.symbol_name);
        line = std.Concat(line, " encoding=");
        line = std.Concat(line, literal.encoding);
        line = std.Concat(line, " length=");
        line = std.Concat(line, std.FormatInt(literal.byte_length));
        line = std.Concat(line, " bytes=");
        line = std.Concat(line, literal.bytes_hex);
        line = std.Concat(line, " storage=");
        line = std.Concat(line, literal.storage_kind);
        line = std.Concat(line, " lifetime=");
        line = std.Concat(line, literal.lifetime_region);
        line = std.Concat(line, "\n");
        output = std.Concat(output, line);
        literal_index = literal_index + 1;
    }

    mut views: std.Vector[MirStringView[ctx], ctx] := ctx[table.views];
    mut view_index := 0;
    while view_index < len(views) {
        mut view := views[view_index];
        mut line := "string_view: ";
        line = std.Concat(line, view.view_id);
        line = std.Concat(line, " source=");
        line = std.Concat(line, view.source_literal_id);
        line = std.Concat(line, " start=");
        line = std.Concat(line, std.FormatInt(view.start));
        line = std.Concat(line, " length=");
        line = std.Concat(line, std.FormatInt(view.length));
        line = std.Concat(line, " known_null=");
        line = std.Concat(line, std.FormatInt(view.data_known_null));
        line = std.Concat(line, " lifetime=");
        line = std.Concat(line, view.lifetime_region);
        line = std.Concat(line, "\n");
        output = std.Concat(output, line);
        view_index = view_index + 1;
    }

    mut operations: std.Vector[MirStringViewOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        mut evaluation := mir_string_view_evaluate(table, operation, ctx);
        mut line := "string_operation: ";
        line = std.Concat(line, operation.operation_name);
        line = std.Concat(line, " kind=");
        line = std.Concat(line, operation.kind);
        line = std.Concat(line, " status=");
        if evaluation.success == 1 { line = std.Concat(line, "success"); }
        else { line = std.Concat(line, "failure"); }
        line = std.Concat(line, " value=");
        line = std.Concat(line, std.FormatInt(evaluation.value));
        line = std.Concat(line, " result_start=");
        line = std.Concat(line, std.FormatInt(evaluation.result_start));
        line = std.Concat(line, " result_length=");
        line = std.Concat(line, std.FormatInt(evaluation.result_length));
        line = std.Concat(line, " reason=");
        line = std.Concat(line, evaluation.reason_code);
        line = std.Concat(line, "\n");
        output = std.Concat(output, line);
        operation_index = operation_index + 1;
    }
    return std.Clone(ctx, output);
}
