// Phase 14.4 compiler-owned bounded typed-pointer and nullability authority.
//
// The compiler selects pointer identity, pointee layout, mutability,
// nullability, address space, target pointer width/alignment, and the bounded
// operation kind before either backend runs. This module intentionally does
// not introduce dereference, load/store, pointer arithmetic, non-default
// address spaces, unsized pointees, or integer/pointer casts.

import "mir_layout.gst" as layout;

type MirPointerType[ctx] struct {
    pointer_type_id: str,
    target_id: str,
    target_triple: str,
    pointee_type_id: str,
    pointee_layout_id: str,
    mutability: str,
    nullability: str,
    address_space: str,
    pointer_size: int,
    pointer_alignment: int
}

type MirPointerOperation[ctx] struct {
    operation_id: str,
    operation_name: str,
    target_id: str,
    kind: str,
    source_pointer_type_id: str,
    destination_pointer_type_id: str,
    result_type_id: str,
    operand_count: int,
    lhs_known_null: int,
    rhs_known_null: int,
    origin_kind: str,
    origin_local_id: int,
    provenance_id: str,
    context_kind: str,
    expect_success: int,
    expected_value: int,
    expected_reason_code: str
}

type MirPointerTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    default_address_space: str,
    pointer_types: Index[std.Vector[MirPointerType[ctx], ctx], ctx],
    operations: Index[std.Vector[MirPointerOperation[ctx], ctx], ctx]
}

type MirPointerTypeQuery[ctx] struct {
    found: int,
    pointer_type: MirPointerType[ctx]
}

type MirPointerOperationQuery[ctx] struct {
    found: int,
    operation: MirPointerOperation[ctx]
}

type MirPointerSelection[ctx] struct {
    valid: int,
    reason_code: str,
    pointer_type: MirPointerType[ctx]
}

type MirPointerEvaluation[ctx] struct {
    success: int,
    value: int,
    reason_code: str
}

func mir_pointer_empty_type_vector(ctx: &Arena) Index[std.Vector[MirPointerType[ctx], ctx], ctx] {
    mut pointer_types: std.Vector[MirPointerType[ctx], ctx] := std.VectorNew(ctx);
    mut pointer_types_idx: Index[std.Vector[MirPointerType[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(pointer_types_idx, pointer_types);
    return pointer_types_idx;
}

func mir_pointer_empty_operation_vector(ctx: &Arena) Index[std.Vector[MirPointerOperation[ctx], ctx], ctx] {
    mut operations: std.Vector[MirPointerOperation[ctx], ctx] := std.VectorNew(ctx);
    mut operations_idx: Index[std.Vector[MirPointerOperation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(operations_idx, operations);
    return operations_idx;
}

func mir_pointer_make_empty_table(target_triple: str, ctx: &Arena) MirPointerTable[ctx] {
    mut table: MirPointerTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_pointer_table.v1");
    table.target_id = std.Clone(ctx, "");
    table.target_triple = std.Clone(ctx, target_triple);
    table.default_address_space = std.Clone(ctx, "default");
    table.pointer_types = mir_pointer_empty_type_vector(ctx);
    table.operations = mir_pointer_empty_operation_vector(ctx);
    return table;
}

func mir_pointer_mutability_is_valid(mutability: str) int {
    if std.str_eq(mutability, "const") == 1 { return 1; }
    if std.str_eq(mutability, "mutable") == 1 { return 1; }
    return 0;
}

func mir_pointer_nullability_is_valid(nullability: str) int {
    if std.str_eq(nullability, "non_null") == 1 { return 1; }
    if std.str_eq(nullability, "nullable") == 1 { return 1; }
    return 0;
}

func mir_pointer_operation_kind_is_valid(kind: str) int {
    if std.str_eq(kind, "address_of_local") == 1 { return 1; }
    if std.str_eq(kind, "null_pointer") == 1 { return 1; }
    if std.str_eq(kind, "pointer_equal") == 1 { return 1; }
    if std.str_eq(kind, "pointer_not_equal") == 1 { return 1; }
    if std.str_eq(kind, "pointer_null_test") == 1 { return 1; }
    if std.str_eq(kind, "pointer_non_null_test") == 1 { return 1; }
    if std.str_eq(kind, "non_null_to_nullable") == 1 { return 1; }
    if std.str_eq(kind, "nullable_to_non_null_checked") == 1 { return 1; }
    return 0;
}

func mir_pointer_context_is_valid(context_kind: str) int {
    if std.str_eq(context_kind, "local") == 1 { return 1; }
    if std.str_eq(context_kind, "comparison") == 1 { return 1; }
    if std.str_eq(context_kind, "branch") == 1 { return 1; }
    if std.str_eq(context_kind, "aggregate_field") == 1 { return 1; }
    return 0;
}

func mir_pointer_type_identity(pointer_type: MirPointerType[ctx], ctx: &Arena) str {
    mut identity := "pointer:v1:target=";
    identity = std.Concat(identity, pointer_type.target_id);
    identity = std.Concat(identity, ":pointee=");
    identity = std.Concat(identity, pointer_type.pointee_type_id);
    identity = std.Concat(identity, ":layout=");
    identity = std.Concat(identity, pointer_type.pointee_layout_id);
    identity = std.Concat(identity, ":mutability=");
    identity = std.Concat(identity, pointer_type.mutability);
    identity = std.Concat(identity, ":nullability=");
    identity = std.Concat(identity, pointer_type.nullability);
    identity = std.Concat(identity, ":address_space=");
    identity = std.Concat(identity, pointer_type.address_space);
    identity = std.Concat(identity, ":size=");
    identity = std.Concat(identity, std.FormatInt(pointer_type.pointer_size));
    identity = std.Concat(identity, ":align=");
    identity = std.Concat(identity, std.FormatInt(pointer_type.pointer_alignment));
    return std.Clone(ctx, identity);
}

func mir_pointer_operation_identity(operation: MirPointerOperation[ctx], ctx: &Arena) str {
    mut identity := "pointer_operation:v1:target=";
    identity = std.Concat(identity, operation.target_id);
    identity = std.Concat(identity, ":kind=");
    identity = std.Concat(identity, operation.kind);
    identity = std.Concat(identity, ":name=");
    identity = std.Concat(identity, operation.operation_name);
    identity = std.Concat(identity, ":source=");
    identity = std.Concat(identity, operation.source_pointer_type_id);
    identity = std.Concat(identity, ":destination=");
    identity = std.Concat(identity, operation.destination_pointer_type_id);
    identity = std.Concat(identity, ":origin=");
    identity = std.Concat(identity, operation.origin_kind);
    return std.Clone(ctx, identity);
}

func mir_pointer_make_type(layout_table: layout.MirLayoutTable[ctx], pointee_type_id: str, mutability: str, nullability: str, ctx: &Arena) MirPointerType[ctx] {
    mut pointer_type: MirPointerType[ctx];
    mut pointee := layout.mir_layout_of(
        layout_table,
        pointee_type_id,
        layout_table.target.target_id,
        ctx
    );
    pointer_type.pointer_type_id = std.Clone(ctx, "");
    pointer_type.target_id = std.Clone(ctx, layout_table.target.target_id);
    pointer_type.target_triple = std.Clone(ctx, layout_table.target.target_triple);
    pointer_type.pointee_type_id = std.Clone(ctx, pointee_type_id);
    pointer_type.pointee_layout_id = std.Clone(ctx, "");
    if pointee.found == 1 {
        pointer_type.pointee_layout_id = std.Clone(ctx, pointee.layout.layout_id);
    }
    pointer_type.mutability = std.Clone(ctx, mutability);
    pointer_type.nullability = std.Clone(ctx, nullability);
    pointer_type.address_space = std.Clone(ctx, "default");
    pointer_type.pointer_size = layout_table.target.pointer_size;
    pointer_type.pointer_alignment = layout_table.target.pointer_alignment;
    pointer_type.pointer_type_id = mir_pointer_type_identity(pointer_type, ctx);
    return pointer_type;
}

func mir_pointer_table_with_type(table: MirPointerTable[ctx], pointer_type: MirPointerType[ctx], ctx: &Arena) MirPointerTable[ctx] {
    mut updated := table;
    mut pointer_types: std.Vector[MirPointerType[ctx], ctx] := ctx[updated.pointer_types];
    pointer_types.Push(pointer_type);
    ctx.Set(updated.pointer_types, pointer_types);
    return updated;
}

func mir_pointer_type(table: MirPointerTable[ctx], pointer_type_id: str, ctx: &Arena) MirPointerTypeQuery[ctx] {
    mut query: MirPointerTypeQuery[ctx];
    query.found = 0;
    mut pointer_types: std.Vector[MirPointerType[ctx], ctx] := ctx[table.pointer_types];
    mut index := 0;
    while index < len(pointer_types) {
        if std.str_eq(pointer_types[index].pointer_type_id, pointer_type_id) == 1 {
            query.found = 1;
            query.pointer_type = pointer_types[index];
            return query;
        }
        index = index + 1;
    }
    return query;
}

func mir_pointer_find_type(table: MirPointerTable[ctx], pointee_type_id: str, mutability: str, nullability: str, ctx: &Arena) MirPointerTypeQuery[ctx] {
    mut query: MirPointerTypeQuery[ctx];
    query.found = 0;
    mut pointer_types: std.Vector[MirPointerType[ctx], ctx] := ctx[table.pointer_types];
    mut index := 0;
    while index < len(pointer_types) {
        mut pointer_type := pointer_types[index];
        if std.str_eq(pointer_type.pointee_type_id, pointee_type_id) == 1 &&
           std.str_eq(pointer_type.mutability, mutability) == 1 &&
           std.str_eq(pointer_type.nullability, nullability) == 1
        {
            query.found = 1;
            query.pointer_type = pointer_type;
            return query;
        }
        index = index + 1;
    }
    return query;
}

func mir_pointer_make_operation(table: MirPointerTable[ctx], operation_name: str, kind: str, source_pointer_type_id: str, destination_pointer_type_id: str, result_type_id: str, operand_count: int, lhs_known_null: int, rhs_known_null: int, origin_kind: str, origin_local_id: int, provenance_id: str, context_kind: str, expect_success: int, expected_value: int, expected_reason_code: str, ctx: &Arena) MirPointerOperation[ctx] {
    mut operation: MirPointerOperation[ctx];
    operation.operation_id = std.Clone(ctx, "");
    operation.operation_name = std.Clone(ctx, operation_name);
    operation.target_id = std.Clone(ctx, table.target_id);
    operation.kind = std.Clone(ctx, kind);
    operation.source_pointer_type_id = std.Clone(ctx, source_pointer_type_id);
    operation.destination_pointer_type_id = std.Clone(ctx, destination_pointer_type_id);
    operation.result_type_id = std.Clone(ctx, result_type_id);
    operation.operand_count = operand_count;
    operation.lhs_known_null = lhs_known_null;
    operation.rhs_known_null = rhs_known_null;
    operation.origin_kind = std.Clone(ctx, origin_kind);
    operation.origin_local_id = origin_local_id;
    operation.provenance_id = std.Clone(ctx, provenance_id);
    operation.context_kind = std.Clone(ctx, context_kind);
    operation.expect_success = expect_success;
    operation.expected_value = expected_value;
    operation.expected_reason_code = std.Clone(ctx, expected_reason_code);
    operation.operation_id = mir_pointer_operation_identity(operation, ctx);
    return operation;
}

func mir_pointer_table_with_operation(table: MirPointerTable[ctx], operation: MirPointerOperation[ctx], ctx: &Arena) MirPointerTable[ctx] {
    mut updated := table;
    mut operations: std.Vector[MirPointerOperation[ctx], ctx] := ctx[updated.operations];
    operations.Push(operation);
    ctx.Set(updated.operations, operations);
    return updated;
}

func mir_pointer_operation(table: MirPointerTable[ctx], operation_name: str, ctx: &Arena) MirPointerOperationQuery[ctx] {
    mut query: MirPointerOperationQuery[ctx];
    query.found = 0;
    mut operations: std.Vector[MirPointerOperation[ctx], ctx] := ctx[table.operations];
    mut index := 0;
    while index < len(operations) {
        if std.str_eq(operations[index].operation_name, operation_name) == 1 {
            query.found = 1;
            query.operation = operations[index];
            return query;
        }
        index = index + 1;
    }
    return query;
}

func mir_pointer_evaluate(operation: MirPointerOperation[ctx], ctx: &Arena) MirPointerEvaluation[ctx] {
    mut result: MirPointerEvaluation[ctx];
    result.success = 0;
    result.value = 0;
    result.reason_code = std.Clone(ctx, "pointer_operation_not_supported");

    if operation.lhs_known_null < 0 || operation.lhs_known_null > 1 ||
       operation.rhs_known_null < 0 || operation.rhs_known_null > 1
    {
        result.reason_code = std.Clone(ctx, "pointer_known_null_state_invalid");
        return result;
    }

    if std.str_eq(operation.kind, "address_of_local") == 1 {
        result.success = 1;
        result.value = 0;
        result.reason_code = std.Clone(ctx, "pointer_value_valid");
        return result;
    }
    if std.str_eq(operation.kind, "null_pointer") == 1 {
        result.success = 1;
        result.value = 1;
        result.reason_code = std.Clone(ctx, "pointer_value_valid");
        return result;
    }
    if std.str_eq(operation.kind, "pointer_equal") == 1 {
        result.success = 1;
        if operation.lhs_known_null == operation.rhs_known_null {
            result.value = 1;
        }
        result.reason_code = std.Clone(ctx, "pointer_value_valid");
        return result;
    }
    if std.str_eq(operation.kind, "pointer_not_equal") == 1 {
        result.success = 1;
        if operation.lhs_known_null != operation.rhs_known_null {
            result.value = 1;
        }
        result.reason_code = std.Clone(ctx, "pointer_value_valid");
        return result;
    }
    if std.str_eq(operation.kind, "pointer_null_test") == 1 {
        result.success = 1;
        result.value = operation.lhs_known_null;
        result.reason_code = std.Clone(ctx, "pointer_value_valid");
        return result;
    }
    if std.str_eq(operation.kind, "pointer_non_null_test") == 1 {
        result.success = 1;
        result.value = 1 - operation.lhs_known_null;
        result.reason_code = std.Clone(ctx, "pointer_value_valid");
        return result;
    }
    if std.str_eq(operation.kind, "non_null_to_nullable") == 1 {
        if operation.lhs_known_null == 1 {
            result.reason_code = std.Clone(ctx, "pointer_non_null_source_required");
            return result;
        }
        result.success = 1;
        result.value = 0;
        result.reason_code = std.Clone(ctx, "pointer_value_valid");
        return result;
    }
    if std.str_eq(operation.kind, "nullable_to_non_null_checked") == 1 {
        if operation.lhs_known_null == 1 {
            result.reason_code = std.Clone(ctx, "pointer_nullability_check_failed");
            return result;
        }
        result.success = 1;
        result.value = 0;
        result.reason_code = std.Clone(ctx, "pointer_value_valid");
        return result;
    }
    return result;
}

func mir_pointer_select_type(table: MirPointerTable[ctx], pointee_type_id: str, mutability: str, nullability: str, address_space: str, target_id: str, ctx: &Arena) MirPointerSelection[ctx] {
    mut selection: MirPointerSelection[ctx];
    selection.valid = 0;
    selection.reason_code = std.Clone(ctx, "pointer_type_not_declared");

    if len(target_id) == 0 {
        selection.reason_code = std.Clone(ctx, "pointer_target_required");
        return selection;
    }
    if std.str_eq(target_id, table.target_id) == 0 {
        selection.reason_code = std.Clone(ctx, "pointer_target_mismatch");
        return selection;
    }
    if std.str_eq(address_space, "default") == 0 {
        selection.reason_code = std.Clone(ctx, "pointer_address_space_unsupported");
        return selection;
    }
    if mir_pointer_mutability_is_valid(mutability) == 0 {
        selection.reason_code = std.Clone(ctx, "pointer_mutability_unsupported");
        return selection;
    }
    if mir_pointer_nullability_is_valid(nullability) == 0 {
        selection.reason_code = std.Clone(ctx, "pointer_nullability_invalid");
        return selection;
    }
    if std.str_eq(pointee_type_id, "type:gust:i32") == 0 {
        selection.reason_code = std.Clone(ctx, "pointer_pointee_unsized_or_unsupported");
        return selection;
    }
    mut query := mir_pointer_find_type(
        table,
        pointee_type_id,
        mutability,
        nullability,
        ctx
    );
    if query.found == 0 {
        selection.reason_code = std.Clone(ctx, "pointer_pointee_layout_invalid");
        return selection;
    }
    selection.valid = 1;
    selection.reason_code = std.Clone(ctx, "pointer_type_valid");
    selection.pointer_type = query.pointer_type;
    return selection;
}

func mir_pointer_operation_request_is_supported(kind: str, ctx: &Arena) MirPointerEvaluation[ctx] {
    mut result: MirPointerEvaluation[ctx];
    result.success = 0;
    result.value = 0;
    result.reason_code = std.Clone(ctx, "pointer_operation_not_supported");
    if std.str_eq(kind, "pointer_arithmetic") == 1 {
        result.reason_code = std.Clone(ctx, "pointer_arithmetic_unsupported");
        return result;
    }
    if std.str_eq(kind, "integer_to_pointer") == 1 ||
       std.str_eq(kind, "pointer_to_integer") == 1
    {
        result.reason_code = std.Clone(ctx, "pointer_integer_cast_unsupported");
        return result;
    }
    if std.str_eq(kind, "dereference") == 1 ||
       std.str_eq(kind, "load") == 1 ||
       std.str_eq(kind, "store") == 1
    {
        result.reason_code = std.Clone(ctx, "pointer_load_store_contract_deferred");
        return result;
    }
    if mir_pointer_operation_kind_is_valid(kind) == 1 {
        result.success = 1;
        result.reason_code = std.Clone(ctx, "pointer_operation_selected");
    }
    return result;
}

func mir_pointer_table_is_valid(table: MirPointerTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if std.str_eq(table.format, "gust.compiler_pointer_table.v1") == 0 ||
       std.str_eq(table.target_id, layout_table.target.target_id) == 0 ||
       std.str_eq(table.target_triple, layout_table.target.target_triple) == 0 ||
       std.str_eq(table.default_address_space, "default") == 0 ||
       layout.mir_layout_table_is_valid(layout_table, ctx) == 0 ||
       layout_table.target.decisions_frozen == 0
    {
        return 0;
    }

    mut pointer_types: std.Vector[MirPointerType[ctx], ctx] := ctx[table.pointer_types];
    if len(pointer_types) != 4 {
        return 0;
    }
    mut type_index := 0;
    while type_index < len(pointer_types) {
        mut pointer_type := pointer_types[type_index];
        if std.str_eq(pointer_type.pointer_type_id, mir_pointer_type_identity(pointer_type, ctx)) == 0 ||
           std.str_eq(pointer_type.target_id, table.target_id) == 0 ||
           std.str_eq(pointer_type.target_triple, table.target_triple) == 0 ||
           mir_pointer_mutability_is_valid(pointer_type.mutability) == 0 ||
           mir_pointer_nullability_is_valid(pointer_type.nullability) == 0 ||
           std.str_eq(pointer_type.address_space, "default") == 0 ||
           pointer_type.pointer_size != layout_table.target.pointer_size ||
           pointer_type.pointer_alignment != layout_table.target.pointer_alignment
        {
            return 0;
        }
        mut pointee := layout.mir_layout_of(
            layout_table,
            pointer_type.pointee_type_id,
            table.target_id,
            ctx
        );
        if pointee.found == 0 ||
           std.str_eq(pointee.layout.layout_id, pointer_type.pointee_layout_id) == 0 ||
           pointee.layout.size <= 0 ||
           pointee.layout.alignment <= 0
        {
            return 0;
        }
        mut prior_type_index := 0;
        while prior_type_index < type_index {
            if std.str_eq(
                pointer_types[prior_type_index].pointer_type_id,
                pointer_type.pointer_type_id
            ) == 1 {
                return 0;
            }
            prior_type_index = prior_type_index + 1;
        }
        type_index = type_index + 1;
    }

    mut operations: std.Vector[MirPointerOperation[ctx], ctx] := ctx[table.operations];
    if len(operations) != 11 {
        return 0;
    }
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        if std.str_eq(operation.operation_id, mir_pointer_operation_identity(operation, ctx)) == 0 ||
           std.str_eq(operation.target_id, table.target_id) == 0 ||
           mir_pointer_operation_kind_is_valid(operation.kind) == 0 ||
           mir_pointer_context_is_valid(operation.context_kind) == 0 ||
           operation.operand_count < 0 ||
           operation.operand_count > 2 ||
           layout.mir_layout_field_is_safe(operation.provenance_id, 0) == 0
        {
            return 0;
        }
        if len(operation.source_pointer_type_id) > 0 {
            mut source := mir_pointer_type(table, operation.source_pointer_type_id, ctx);
            if source.found == 0 {
                return 0;
            }
        }
        if len(operation.destination_pointer_type_id) > 0 {
            mut destination := mir_pointer_type(table, operation.destination_pointer_type_id, ctx);
            if destination.found == 0 {
                return 0;
            }
        }
        mut evaluation := mir_pointer_evaluate(operation, ctx);
        if evaluation.success != operation.expect_success ||
           evaluation.value != operation.expected_value ||
           std.str_eq(evaluation.reason_code, operation.expected_reason_code) == 0
        {
            return 0;
        }
        mut prior_operation_index := 0;
        while prior_operation_index < operation_index {
            if std.str_eq(
                operations[prior_operation_index].operation_id,
                operation.operation_id
            ) == 1 {
                return 0;
            }
            prior_operation_index = prior_operation_index + 1;
        }
        operation_index = operation_index + 1;
    }
    return 1;
}

func mir_pointer_table_for_layout(layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) MirPointerTable[ctx] {
    mut table := mir_pointer_make_empty_table(
        layout_table.target.target_triple,
        ctx
    );
    if layout.mir_layout_table_is_valid(layout_table, ctx) == 0 ||
       layout_table.target.decisions_frozen == 0
    {
        return table;
    }
    table.target_id = std.Clone(ctx, layout_table.target.target_id);

    mut const_non_null := mir_pointer_make_type(
        layout_table,
        "type:gust:i32",
        "const",
        "non_null",
        ctx
    );
    mut const_nullable := mir_pointer_make_type(
        layout_table,
        "type:gust:i32",
        "const",
        "nullable",
        ctx
    );
    mut mutable_non_null := mir_pointer_make_type(
        layout_table,
        "type:gust:i32",
        "mutable",
        "non_null",
        ctx
    );
    mut mutable_nullable := mir_pointer_make_type(
        layout_table,
        "type:gust:i32",
        "mutable",
        "nullable",
        ctx
    );
    table = mir_pointer_table_with_type(table, const_non_null, ctx);
    table = mir_pointer_table_with_type(table, const_nullable, ctx);
    table = mir_pointer_table_with_type(table, mutable_non_null, ctx);
    table = mir_pointer_table_with_type(table, mutable_nullable, ctx);

    table = mir_pointer_table_with_operation(table, mir_pointer_make_operation(
        table, "address_of_local_i32", "address_of_local", "",
        const_non_null.pointer_type_id, const_non_null.pointer_type_id,
        0, 0, 0, "addressable_local", 0, "pointer-origin:local:0",
        "local", 1, 0, "pointer_value_valid", ctx
    ), ctx);
    table = mir_pointer_table_with_operation(table, mir_pointer_make_operation(
        table, "null_pointer_i32", "null_pointer", "",
        const_nullable.pointer_type_id, const_nullable.pointer_type_id,
        0, 1, 1, "null_literal", 0 - 1, "pointer-origin:null",
        "local", 1, 1, "pointer_value_valid", ctx
    ), ctx);
    table = mir_pointer_table_with_operation(table, mir_pointer_make_operation(
        table, "pointer_equal_null_null", "pointer_equal",
        const_nullable.pointer_type_id, const_nullable.pointer_type_id,
        "type:gust:bool", 2, 1, 1, "comparison", 0 - 1,
        "pointer-origin:comparison:null-null", "comparison",
        1, 1, "pointer_value_valid", ctx
    ), ctx);
    table = mir_pointer_table_with_operation(table, mir_pointer_make_operation(
        table, "pointer_not_equal_address_null", "pointer_not_equal",
        const_nullable.pointer_type_id, const_nullable.pointer_type_id,
        "type:gust:bool", 2, 0, 1, "comparison", 0,
        "pointer-origin:comparison:local-null", "comparison",
        1, 1, "pointer_value_valid", ctx
    ), ctx);
    table = mir_pointer_table_with_operation(table, mir_pointer_make_operation(
        table, "pointer_is_null_null", "pointer_null_test",
        const_nullable.pointer_type_id, "", "type:gust:bool",
        1, 1, 0, "null_test", 0 - 1, "pointer-origin:null-test:null",
        "branch", 1, 1, "pointer_value_valid", ctx
    ), ctx);
    table = mir_pointer_table_with_operation(table, mir_pointer_make_operation(
        table, "pointer_is_null_address", "pointer_null_test",
        const_nullable.pointer_type_id, "", "type:gust:bool",
        1, 0, 0, "null_test", 0, "pointer-origin:null-test:local",
        "branch", 1, 0, "pointer_value_valid", ctx
    ), ctx);
    table = mir_pointer_table_with_operation(table, mir_pointer_make_operation(
        table, "pointer_is_non_null_address", "pointer_non_null_test",
        const_nullable.pointer_type_id, "", "type:gust:bool",
        1, 0, 0, "null_test", 0, "pointer-origin:non-null-test:local",
        "branch", 1, 1, "pointer_value_valid", ctx
    ), ctx);
    table = mir_pointer_table_with_operation(table, mir_pointer_make_operation(
        table, "non_null_to_nullable_i32", "non_null_to_nullable",
        const_non_null.pointer_type_id, const_nullable.pointer_type_id,
        const_nullable.pointer_type_id, 1, 0, 0, "typed_conversion", 0,
        "pointer-origin:conversion:nonnull-nullable", "local",
        1, 0, "pointer_value_valid", ctx
    ), ctx);
    table = mir_pointer_table_with_operation(table, mir_pointer_make_operation(
        table, "nullable_to_non_null_checked_success", "nullable_to_non_null_checked",
        const_nullable.pointer_type_id, const_non_null.pointer_type_id,
        const_non_null.pointer_type_id, 1, 0, 0, "typed_conversion", 0,
        "pointer-origin:conversion:checked-success", "local",
        1, 0, "pointer_value_valid", ctx
    ), ctx);
    table = mir_pointer_table_with_operation(table, mir_pointer_make_operation(
        table, "nullable_to_non_null_checked_null", "nullable_to_non_null_checked",
        const_nullable.pointer_type_id, const_non_null.pointer_type_id,
        const_non_null.pointer_type_id, 1, 1, 0, "typed_conversion", 0 - 1,
        "pointer-origin:conversion:checked-null", "branch",
        0, 0, "pointer_nullability_check_failed", ctx
    ), ctx);
    table = mir_pointer_table_with_operation(table, mir_pointer_make_operation(
        table, "aggregate_pointer_field", "address_of_local", "",
        mutable_non_null.pointer_type_id, mutable_non_null.pointer_type_id,
        0, 0, 0, "addressable_local", 1, "pointer-origin:aggregate:field0",
        "aggregate_field", 1, 0, "pointer_value_valid", ctx
    ), ctx);
    return table;
}

func mir_pointer_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut updated := std.Concat(output, key);
    updated = std.Concat(updated, ": ");
    updated = std.Concat(updated, value);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

func mir_serialize_pointer_table_for_request(table: MirPointerTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_pointer_table_is_valid(table, layout_table, ctx) == 0 {
        return "pointer_table_format: invalid\n";
    }
    mut output := "";
    output = mir_pointer_append_field(output, "pointer_table_format", table.format, ctx);
    output = mir_pointer_append_field(output, "pointer_target_id", table.target_id, ctx);
    output = mir_pointer_append_field(output, "pointer_target_triple", table.target_triple, ctx);
    output = mir_pointer_append_field(output, "pointer_default_address_space", table.default_address_space, ctx);

    mut pointer_types: std.Vector[MirPointerType[ctx], ctx] := ctx[table.pointer_types];
    output = mir_pointer_append_field(output, "pointer_type_count", std.FormatInt(len(pointer_types)), ctx);
    mut type_index := 0;
    while type_index < len(pointer_types) {
        mut prefix := std.Concat("pointer_type_", std.FormatInt(type_index));
        mut pointer_type := pointer_types[type_index];
        output = mir_pointer_append_field(output, std.Concat(prefix, "_id"), pointer_type.pointer_type_id, ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_target_id"), pointer_type.target_id, ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_pointee_type_id"), pointer_type.pointee_type_id, ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_pointee_layout_id"), pointer_type.pointee_layout_id, ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_mutability"), pointer_type.mutability, ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_nullability"), pointer_type.nullability, ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_address_space"), pointer_type.address_space, ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_pointer_size"), std.FormatInt(pointer_type.pointer_size), ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_pointer_alignment"), std.FormatInt(pointer_type.pointer_alignment), ctx);
        type_index = type_index + 1;
    }

    mut operations: std.Vector[MirPointerOperation[ctx], ctx] := ctx[table.operations];
    output = mir_pointer_append_field(output, "pointer_operation_count", std.FormatInt(len(operations)), ctx);
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut prefix := std.Concat("pointer_operation_", std.FormatInt(operation_index));
        mut operation := operations[operation_index];
        output = mir_pointer_append_field(output, std.Concat(prefix, "_id"), operation.operation_id, ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_name"), operation.operation_name, ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_target_id"), operation.target_id, ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_kind"), operation.kind, ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_source_pointer_type_id"), operation.source_pointer_type_id, ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_destination_pointer_type_id"), operation.destination_pointer_type_id, ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_result_type_id"), operation.result_type_id, ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_operand_count"), std.FormatInt(operation.operand_count), ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_lhs_known_null"), std.FormatInt(operation.lhs_known_null), ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_rhs_known_null"), std.FormatInt(operation.rhs_known_null), ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_origin_kind"), operation.origin_kind, ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_origin_local_id"), std.FormatInt(operation.origin_local_id), ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_provenance_id"), operation.provenance_id, ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_context_kind"), operation.context_kind, ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_expect_success"), std.FormatInt(operation.expect_success), ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_expected_value"), std.FormatInt(operation.expected_value), ctx);
        output = mir_pointer_append_field(output, std.Concat(prefix, "_expected_reason_code"), operation.expected_reason_code, ctx);
        operation_index = operation_index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_pointer_witness(table: MirPointerTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_pointer_table_is_valid(table, layout_table, ctx) == 0 {
        return "";
    }
    mut output := "pointer_status: valid\n";
    output = mir_pointer_append_field(output, "pointer_target", table.target_triple, ctx);
    output = mir_pointer_append_field(output, "pointer_target_id", table.target_id, ctx);
    output = mir_pointer_append_field(output, "pointer_default_address_space", table.default_address_space, ctx);
    output = mir_pointer_append_field(output, "pointer_size", std.FormatInt(layout_table.target.pointer_size), ctx);
    output = mir_pointer_append_field(output, "pointer_alignment", std.FormatInt(layout_table.target.pointer_alignment), ctx);

    mut pointer_types: std.Vector[MirPointerType[ctx], ctx] := ctx[table.pointer_types];
    mut type_index := 0;
    while type_index < len(pointer_types) {
        mut pointer_type := pointer_types[type_index];
        mut line := "pointer_type: ";
        line = std.Concat(line, pointer_type.pointer_type_id);
        line = std.Concat(line, " pointee=");
        line = std.Concat(line, pointer_type.pointee_type_id);
        line = std.Concat(line, " layout=");
        line = std.Concat(line, pointer_type.pointee_layout_id);
        line = std.Concat(line, " mutability=");
        line = std.Concat(line, pointer_type.mutability);
        line = std.Concat(line, " nullability=");
        line = std.Concat(line, pointer_type.nullability);
        line = std.Concat(line, " address_space=");
        line = std.Concat(line, pointer_type.address_space);
        line = std.Concat(line, " size=");
        line = std.Concat(line, std.FormatInt(pointer_type.pointer_size));
        line = std.Concat(line, " alignment=");
        line = std.Concat(line, std.FormatInt(pointer_type.pointer_alignment));
        line = std.Concat(line, "\n");
        output = std.Concat(output, line);
        type_index = type_index + 1;
    }

    mut operations: std.Vector[MirPointerOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        mut evaluation := mir_pointer_evaluate(operation, ctx);
        mut line := "pointer_operation: ";
        line = std.Concat(line, operation.operation_name);
        line = std.Concat(line, " kind=");
        line = std.Concat(line, operation.kind);
        line = std.Concat(line, " source=");
        line = std.Concat(line, operation.source_pointer_type_id);
        line = std.Concat(line, " destination=");
        line = std.Concat(line, operation.destination_pointer_type_id);
        line = std.Concat(line, " result_type=");
        line = std.Concat(line, operation.result_type_id);
        line = std.Concat(line, " status=");
        if evaluation.success == 1 {
            line = std.Concat(line, "success");
        } else {
            line = std.Concat(line, "failure");
        }
        line = std.Concat(line, " value=");
        line = std.Concat(line, std.FormatInt(evaluation.value));
        line = std.Concat(line, " reason=");
        line = std.Concat(line, evaluation.reason_code);
        line = std.Concat(line, " origin=");
        line = std.Concat(line, operation.origin_kind);
        line = std.Concat(line, " provenance=");
        line = std.Concat(line, operation.provenance_id);
        line = std.Concat(line, " context=");
        line = std.Concat(line, operation.context_kind);
        line = std.Concat(line, "\n");
        output = std.Concat(output, line);
        operation_index = operation_index + 1;
    }
    return std.Clone(ctx, output);
}