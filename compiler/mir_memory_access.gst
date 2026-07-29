// Phase 14.6 compiler-owned typed memory-access authority.
//
// This module selects a bounded i32 memory inventory over compiler-owned
// stack-slot and pointer origins. Every operation carries an accessed type,
// layout identity, byte width, alignment, origin, mutability, nullability,
// lifetime, source location, and compiler-derived offset. Naturally aligned
// fixed-size accesses are selected. Unaligned and zero-sized accesses, known
// null dereferences, read-before-write, immutable stores, out-of-lifetime
// origins, and overlapping copies remain rejected before code generation.

import "mir_layout.gst" as layout;
import "mir_pointer.gst" as pointer;
import "mir_stack_slot.gst" as stack_slot;

type MirMemoryAccessOperation[ctx] struct {
    operation_id: str,
    operation_name: str,
    target_id: str,
    kind: str,
    accessed_type_id: str,
    accessed_layout_id: str,
    byte_width: int,
    required_alignment: int,
    origin_kind: str,
    origin_id: str,
    origin_slot_id: str,
    origin_mutability: str,
    origin_nullability: str,
    lifetime_region: str,
    source_file: str,
    source_line: int,
    source_column: int,
    offset_kind: str,
    offset_layout_id: str,
    element_index: int,
    source_offset: int,
    destination_offset: int,
    input_value: int,
    expect_success: int,
    expected_value: int,
    expected_reason_code: str
}

type MirMemoryAccessTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    natural_alignment_policy: str,
    unaligned_policy: str,
    zero_sized_policy: str,
    known_null_policy: str,
    initialization_policy: str,
    overlap_policy: str,
    operations: Index[std.Vector[MirMemoryAccessOperation[ctx], ctx], ctx]
}

type MirMemoryAccessOperationQuery[ctx] struct {
    found: int,
    operation: MirMemoryAccessOperation[ctx]
}

type MirMemoryAccessValidation[ctx] struct {
    valid: int,
    value: int,
    reason_code: str
}

func mir_memory_access_empty_operation_vector(ctx: &Arena) Index[std.Vector[MirMemoryAccessOperation[ctx], ctx], ctx] {
    mut operations: std.Vector[MirMemoryAccessOperation[ctx], ctx] := std.VectorNew(ctx);
    mut operations_idx: Index[std.Vector[MirMemoryAccessOperation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(operations_idx, operations);
    return operations_idx;
}

func mir_memory_access_make_empty_table(target_triple: str, ctx: &Arena) MirMemoryAccessTable[ctx] {
    mut table: MirMemoryAccessTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_memory_access_table.v1");
    table.target_id = std.Clone(ctx, "");
    table.target_triple = std.Clone(ctx, target_triple);
    table.natural_alignment_policy = std.Clone(ctx, "required_exact_compiler_alignment");
    table.unaligned_policy = std.Clone(ctx, "rejected_not_selected");
    table.zero_sized_policy = std.Clone(ctx, "rejected_no_selected_zero_sized_type");
    table.known_null_policy = std.Clone(ctx, "rejected_before_codegen");
    table.initialization_policy = std.Clone(ctx, "loads_require_initialization_or_prior_store");
    table.overlap_policy = std.Clone(ctx, "bounded_copy_requires_non_overlapping_ranges");
    table.operations = mir_memory_access_empty_operation_vector(ctx);
    return table;
}

func mir_memory_access_table_is_legacy_empty(table: MirMemoryAccessTable[ctx], ctx: &Arena) int {
    mut operations: std.Vector[MirMemoryAccessOperation[ctx], ctx] := ctx[table.operations];
    if std.str_eq(table.format, "gust.compiler_memory_access_table.v1") == 1 &&
       len(table.target_id) == 0 && len(operations) == 0
    {
        return 1;
    }
    return 0;
}

func mir_memory_access_kind_is_valid(kind: str) int {
    if std.str_eq(kind, "load") == 1 { return 1; }
    if std.str_eq(kind, "store") == 1 { return 1; }
    if std.str_eq(kind, "aggregate_copy") == 1 { return 1; }
    if std.str_eq(kind, "layout_offset") == 1 { return 1; }
    return 0;
}

func mir_memory_access_origin_kind_is_valid(kind: str) int {
    if std.str_eq(kind, "stack_slot") == 1 { return 1; }
    if std.str_eq(kind, "pointer") == 1 { return 1; }
    return 0;
}

func mir_memory_access_mutability_is_valid(value: str) int {
    if std.str_eq(value, "immutable") == 1 { return 1; }
    if std.str_eq(value, "mutable") == 1 { return 1; }
    return 0;
}

func mir_memory_access_nullability_is_valid(value: str) int {
    if std.str_eq(value, "non_null") == 1 { return 1; }
    if std.str_eq(value, "nullable") == 1 { return 1; }
    if std.str_eq(value, "not_applicable") == 1 { return 1; }
    return 0;
}

func mir_memory_access_offset_kind_is_valid(value: str) int {
    if std.str_eq(value, "none") == 1 { return 1; }
    if std.str_eq(value, "element") == 1 { return 1; }
    return 0;
}

func mir_memory_access_identity(operation: MirMemoryAccessOperation[ctx], ctx: &Arena) str {
    mut identity := "memory_access_operation:v1:target=";
    identity = std.Concat(identity, operation.target_id);
    identity = std.Concat(identity, ":kind=");
    identity = std.Concat(identity, operation.kind);
    identity = std.Concat(identity, ":name=");
    identity = std.Concat(identity, operation.operation_name);
    identity = std.Concat(identity, ":type=");
    identity = std.Concat(identity, operation.accessed_type_id);
    identity = std.Concat(identity, ":layout=");
    identity = std.Concat(identity, operation.accessed_layout_id);
    identity = std.Concat(identity, ":origin=");
    identity = std.Concat(identity, operation.origin_kind);
    identity = std.Concat(identity, ":origin_id=");
    identity = std.Concat(identity, operation.origin_id);
    identity = std.Concat(identity, ":source_offset=");
    identity = std.Concat(identity, std.FormatInt(operation.source_offset));
    identity = std.Concat(identity, ":destination_offset=");
    identity = std.Concat(identity, std.FormatInt(operation.destination_offset));
    return std.Clone(ctx, identity);
}

func mir_memory_access_layout_identity(target_id: str, type_id: str, layout_id: str, ctx: &Arena) str {
    mut identity := "memory_access_layout:v1:target=";
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":type=");
    identity = std.Concat(identity, type_id);
    identity = std.Concat(identity, ":layout=");
    identity = std.Concat(identity, layout_id);
    return std.Clone(ctx, identity);
}

func mir_memory_access_layout_table(layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) layout.MirLayoutTable[ctx] {
    mut updated := layout_table;
    if layout.mir_layout_table_is_valid(layout_table, ctx) == 0 ||
       layout_table.target.decisions_frozen == 0
    {
        return updated;
    }
    mut existing: std.Vector[layout.MirMemoryAccessLayout[ctx], ctx] := ctx[layout_table.memory_accesses];
    if len(existing) != 0 { return updated; }
    mut i32_layout := layout.mir_layout_of(
        layout_table,
        "type:gust:i32",
        layout_table.target.target_id,
        ctx
    );
    if i32_layout.found == 0 { return updated; }
    mut access := layout.mir_layout_make_memory_access(
        mir_memory_access_layout_identity(
            layout_table.target.target_id,
            i32_layout.layout.type_id,
            i32_layout.layout.layout_id,
            ctx
        ),
        i32_layout.layout.type_id,
        i32_layout.layout.layout_id,
        layout_table.target.target_id,
        i32_layout.layout.size,
        i32_layout.layout.alignment,
        1,
        0,
        ctx
    );
    return layout.mir_layout_table_with_memory_access(updated, access, ctx);
}

func mir_memory_access_make_operation(table: MirMemoryAccessTable[ctx], operation_name: str, kind: str, accessed_type_id: str, accessed_layout_id: str, byte_width: int, required_alignment: int, origin_kind: str, origin_id: str, origin_slot_id: str, origin_mutability: str, origin_nullability: str, lifetime_region: str, source_file: str, source_line: int, source_column: int, offset_kind: str, offset_layout_id: str, element_index: int, source_offset: int, destination_offset: int, input_value: int, expect_success: int, expected_value: int, expected_reason_code: str, ctx: &Arena) MirMemoryAccessOperation[ctx] {
    mut operation: MirMemoryAccessOperation[ctx];
    operation.operation_id = std.Clone(ctx, "");
    operation.operation_name = std.Clone(ctx, operation_name);
    operation.target_id = std.Clone(ctx, table.target_id);
    operation.kind = std.Clone(ctx, kind);
    operation.accessed_type_id = std.Clone(ctx, accessed_type_id);
    operation.accessed_layout_id = std.Clone(ctx, accessed_layout_id);
    operation.byte_width = byte_width;
    operation.required_alignment = required_alignment;
    operation.origin_kind = std.Clone(ctx, origin_kind);
    operation.origin_id = std.Clone(ctx, origin_id);
    operation.origin_slot_id = std.Clone(ctx, origin_slot_id);
    operation.origin_mutability = std.Clone(ctx, origin_mutability);
    operation.origin_nullability = std.Clone(ctx, origin_nullability);
    operation.lifetime_region = std.Clone(ctx, lifetime_region);
    operation.source_file = std.Clone(ctx, source_file);
    operation.source_line = source_line;
    operation.source_column = source_column;
    operation.offset_kind = std.Clone(ctx, offset_kind);
    operation.offset_layout_id = std.Clone(ctx, offset_layout_id);
    operation.element_index = element_index;
    operation.source_offset = source_offset;
    operation.destination_offset = destination_offset;
    operation.input_value = input_value;
    operation.expect_success = expect_success;
    operation.expected_value = expected_value;
    operation.expected_reason_code = std.Clone(ctx, expected_reason_code);
    operation.operation_id = mir_memory_access_identity(operation, ctx);
    return operation;
}

func mir_memory_access_table_with_operation(table: MirMemoryAccessTable[ctx], operation: MirMemoryAccessOperation[ctx], ctx: &Arena) MirMemoryAccessTable[ctx] {
    mut updated := table;
    mut operations: std.Vector[MirMemoryAccessOperation[ctx], ctx] := ctx[updated.operations];
    operations.Push(operation);
    ctx.Set(updated.operations, operations);
    return updated;
}

func mir_memory_access_operation(table: MirMemoryAccessTable[ctx], operation_name: str, ctx: &Arena) MirMemoryAccessOperationQuery[ctx] {
    mut query: MirMemoryAccessOperationQuery[ctx];
    query.found = 0;
    mut operations: std.Vector[MirMemoryAccessOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        if std.str_eq(operations[operation_index].operation_name, operation_name) == 1 {
            query.found = 1;
            query.operation = operations[operation_index];
            return query;
        }
        operation_index = operation_index + 1;
    }
    return query;
}

func mir_memory_access_prior_store_exists(table: MirMemoryAccessTable[ctx], operation_index: int, slot_id: str, ctx: &Arena) int {
    mut operations: std.Vector[MirMemoryAccessOperation[ctx], ctx] := ctx[table.operations];
    mut prior_index := 0;
    while prior_index < operation_index {
        mut prior := operations[prior_index];
        if std.str_eq(prior.kind, "store") == 1 &&
           std.str_eq(prior.origin_slot_id, slot_id) == 1
        {
            return 1;
        }
        prior_index = prior_index + 1;
    }
    return 0;
}

func mir_memory_access_ranges_overlap(source_offset: int, destination_offset: int, byte_width: int) int {
    if source_offset + byte_width <= destination_offset { return 0; }
    if destination_offset + byte_width <= source_offset { return 0; }
    return 1;
}

func mir_memory_access_evaluate(operation: MirMemoryAccessOperation[ctx], ctx: &Arena) MirMemoryAccessValidation[ctx] {
    mut result: MirMemoryAccessValidation[ctx];
    result.valid = 0;
    result.value = 0;
    result.reason_code = std.Clone(ctx, "memory_access_operation_unsupported");
    if mir_memory_access_kind_is_valid(operation.kind) == 0 { return result; }
    result.valid = 1;
    result.value = operation.input_value;
    if std.str_eq(operation.kind, "layout_offset") == 1 {
        result.value = operation.destination_offset;
    }
    result.reason_code = std.Clone(ctx, "memory_access_operation_valid");
    return result;
}

func mir_memory_access_rejection(kind: str, ctx: &Arena) MirMemoryAccessValidation[ctx] {
    mut result: MirMemoryAccessValidation[ctx];
    result.valid = 0;
    result.value = 0;
    result.reason_code = std.Clone(ctx, "memory_access_operation_unsupported");
    if std.str_eq(kind, "wrong_width") == 1 { result.reason_code = std.Clone(ctx, "memory_access_width_mismatch"); return result; }
    if std.str_eq(kind, "wrong_alignment") == 1 { result.reason_code = std.Clone(ctx, "memory_access_alignment_mismatch"); return result; }
    if std.str_eq(kind, "wrong_pointee_type") == 1 { result.reason_code = std.Clone(ctx, "memory_access_pointee_type_mismatch"); return result; }
    if std.str_eq(kind, "immutable_store") == 1 { result.reason_code = std.Clone(ctx, "memory_access_store_immutable"); return result; }
    if std.str_eq(kind, "invalid_layout_id") == 1 { result.reason_code = std.Clone(ctx, "memory_access_layout_id_mismatch"); return result; }
    if std.str_eq(kind, "out_of_lifetime") == 1 { result.reason_code = std.Clone(ctx, "memory_access_out_of_lifetime"); return result; }
    if std.str_eq(kind, "unsupported_overlap") == 1 { result.reason_code = std.Clone(ctx, "memory_access_overlap_unsupported"); return result; }
    if std.str_eq(kind, "known_null") == 1 { result.reason_code = std.Clone(ctx, "memory_access_known_null"); return result; }
    if std.str_eq(kind, "read_before_write") == 1 { result.reason_code = std.Clone(ctx, "memory_access_read_before_write"); return result; }
    if std.str_eq(kind, "unaligned") == 1 { result.reason_code = std.Clone(ctx, "memory_access_unaligned_unsupported"); return result; }
    if std.str_eq(kind, "zero_sized") == 1 { result.reason_code = std.Clone(ctx, "memory_access_zero_sized_unsupported"); return result; }
    return result;
}

func mir_memory_access_table_is_valid(table: MirMemoryAccessTable[ctx], layout_table: layout.MirLayoutTable[ctx], pointer_table: pointer.MirPointerTable[ctx], stack_slot_table: stack_slot.MirStackSlotTable[ctx], ctx: &Arena) int {
    if std.str_eq(table.format, "gust.compiler_memory_access_table.v1") == 0 ||
       len(table.target_id) == 0 || len(table.target_triple) == 0 ||
       std.str_eq(table.target_id, layout_table.target.target_id) == 0 ||
       std.str_eq(table.target_triple, layout_table.target.target_triple) == 0 ||
       std.str_eq(table.target_id, pointer_table.target_id) == 0 ||
       std.str_eq(table.target_id, stack_slot_table.target_id) == 0 ||
       std.str_eq(table.natural_alignment_policy, "required_exact_compiler_alignment") == 0 ||
       std.str_eq(table.unaligned_policy, "rejected_not_selected") == 0 ||
       std.str_eq(table.zero_sized_policy, "rejected_no_selected_zero_sized_type") == 0 ||
       std.str_eq(table.known_null_policy, "rejected_before_codegen") == 0 ||
       std.str_eq(table.initialization_policy, "loads_require_initialization_or_prior_store") == 0 ||
       std.str_eq(table.overlap_policy, "bounded_copy_requires_non_overlapping_ranges") == 0
    {
        return 0;
    }
    if layout.mir_layout_table_is_valid(layout_table, ctx) == 0 ||
       pointer.mir_pointer_table_is_valid(pointer_table, layout_table, ctx) == 0 ||
       stack_slot.mir_stack_slot_table_is_valid(stack_slot_table, layout_table, ctx) == 0
    {
        return 0;
    }
    mut operations: std.Vector[MirMemoryAccessOperation[ctx], ctx] := ctx[table.operations];
    if len(operations) != 6 { return 0; }
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        if std.str_eq(operation.operation_id, mir_memory_access_identity(operation, ctx)) == 0 ||
           std.str_eq(operation.target_id, table.target_id) == 0 ||
           mir_memory_access_kind_is_valid(operation.kind) == 0 ||
           mir_memory_access_origin_kind_is_valid(operation.origin_kind) == 0 ||
           mir_memory_access_mutability_is_valid(operation.origin_mutability) == 0 ||
           mir_memory_access_nullability_is_valid(operation.origin_nullability) == 0 ||
           mir_memory_access_offset_kind_is_valid(operation.offset_kind) == 0 ||
           len(operation.source_file) == 0 || operation.source_line <= 0 ||
           operation.source_column <= 0 || len(operation.lifetime_region) == 0 ||
           operation.byte_width <= 0 || operation.required_alignment <= 0 ||
           operation.source_offset < 0 || operation.destination_offset < 0
        {
            return 0;
        }
        mut accessed := layout.mir_layout_of(
            layout_table,
            operation.accessed_type_id,
            table.target_id,
            ctx
        );
        if accessed.found == 0 ||
           std.str_eq(accessed.layout.layout_id, operation.accessed_layout_id) == 0 ||
           accessed.layout.size != operation.byte_width ||
           accessed.layout.alignment != operation.required_alignment
        {
            return 0;
        }
        mut layout_access := layout.mir_layout_validate_memory_access(
            layout_table,
            operation.accessed_type_id,
            operation.byte_width,
            operation.required_alignment,
            table.target_id,
            ctx
        );
        if layout_access.valid == 0 { return 0; }
        mut slot_query := stack_slot.mir_stack_slot(
            stack_slot_table,
            operation.origin_slot_id,
            ctx
        );
        if slot_query.found == 0 ||
           std.str_eq(slot_query.slot.lifetime_region, operation.lifetime_region) == 0 ||
           std.str_eq(slot_query.slot.mutability, operation.origin_mutability) == 0 ||
           operation.source_offset + operation.byte_width > slot_query.slot.size ||
           operation.destination_offset + operation.byte_width > slot_query.slot.size
        {
            return 0;
        }
        if std.str_eq(operation.kind, "store") == 1 &&
           std.str_eq(slot_query.slot.mutability, "mutable") == 0
        {
            return 0;
        }
        if std.str_eq(operation.kind, "load") == 1 &&
           std.str_eq(slot_query.slot.initialization_state, "initialized") == 0 &&
           mir_memory_access_prior_store_exists(
               table,
               operation_index,
               operation.origin_slot_id,
               ctx
           ) == 0
        {
            return 0;
        }
        if std.str_eq(operation.origin_kind, "pointer") == 1 {
            mut pointer_query := pointer.mir_pointer_type(
                pointer_table,
                operation.origin_id,
                ctx
            );
            if pointer_query.found == 0 ||
               std.str_eq(pointer_query.pointer_type.pointee_type_id, operation.accessed_type_id) == 0 ||
               std.str_eq(pointer_query.pointer_type.pointee_layout_id, operation.accessed_layout_id) == 0 ||
               std.str_eq(pointer_query.pointer_type.nullability, "non_null") == 0 ||
               std.str_eq(pointer_query.pointer_type.mutability, operation.origin_mutability) == 0 ||
               std.str_eq(operation.origin_nullability, "non_null") == 0
            {
                return 0;
            }
        } else {
            if std.str_eq(operation.origin_id, operation.origin_slot_id) == 0 ||
               std.str_eq(operation.origin_nullability, "not_applicable") == 0
            {
                return 0;
            }
        }
        if std.str_eq(operation.offset_kind, "element") == 1 {
            mut stride := layout.mir_layout_element_stride(
                layout_table,
                operation.accessed_type_id,
                table.target_id,
                ctx
            );
            if stride.found == 0 ||
               std.str_eq(operation.offset_layout_id, operation.accessed_layout_id) == 0 ||
               operation.element_index < 0 ||
               operation.destination_offset != stride.stride * operation.element_index
            {
                return 0;
            }
        } else if len(operation.offset_layout_id) != 0 || operation.element_index != 0 {
            return 0;
        }
        if std.str_eq(operation.kind, "aggregate_copy") == 1 &&
           mir_memory_access_ranges_overlap(
               operation.source_offset,
               operation.destination_offset,
               operation.byte_width
           ) == 1
        {
            return 0;
        }
        mut evaluation := mir_memory_access_evaluate(operation, ctx);
        if evaluation.valid != operation.expect_success ||
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
            ) == 1
            {
                return 0;
            }
            prior_operation_index = prior_operation_index + 1;
        }
        operation_index = operation_index + 1;
    }
    return 1;
}

func mir_memory_access_table_for_memory_tables(layout_table: layout.MirLayoutTable[ctx], pointer_table: pointer.MirPointerTable[ctx], stack_slot_table: stack_slot.MirStackSlotTable[ctx], ctx: &Arena) MirMemoryAccessTable[ctx] {
    mut table := mir_memory_access_make_empty_table(layout_table.target.target_triple, ctx);
    if layout.mir_layout_table_is_valid(layout_table, ctx) == 0 ||
       pointer.mir_pointer_table_is_valid(pointer_table, layout_table, ctx) == 0 ||
       stack_slot.mir_stack_slot_table_is_valid(stack_slot_table, layout_table, ctx) == 0
    {
        return table;
    }
    table.target_id = std.Clone(ctx, layout_table.target.target_id);
    mut i32_layout := layout.mir_layout_of(
        layout_table,
        "type:gust:i32",
        table.target_id,
        ctx
    );
    if i32_layout.found == 0 { return table; }
    mut slots: std.Vector[stack_slot.MirStackSlot[ctx], ctx] := ctx[stack_slot_table.slots];
    if len(slots) != 4 { return table; }
    mut local0 := slots[0];
    mut local1 := slots[1];
    mut aggregate0 := slots[3];
    mut mutable_pointer := pointer.mir_pointer_select(
        pointer_table,
        "type:gust:i32",
        "mutable",
        "non_null",
        "default",
        ctx
    );
    if mutable_pointer.valid == 0 { return table; }

    table = mir_memory_access_table_with_operation(table, mir_memory_access_make_operation(table, "store_stack_i32", "store", i32_layout.layout.type_id, i32_layout.layout.layout_id, i32_layout.layout.size, i32_layout.layout.alignment, "stack_slot", local0.slot_id, local0.slot_id, local0.mutability, "not_applicable", local0.lifetime_region, "compiler/phase14_typed_memory_access_source.gst", 5, 5, "none", "", 0, 0, 0, 54, 1, 54, "memory_access_operation_valid", ctx), ctx);
    table = mir_memory_access_table_with_operation(table, mir_memory_access_make_operation(table, "load_stack_i32", "load", i32_layout.layout.type_id, i32_layout.layout.layout_id, i32_layout.layout.size, i32_layout.layout.alignment, "stack_slot", local0.slot_id, local0.slot_id, local0.mutability, "not_applicable", local0.lifetime_region, "compiler/phase14_typed_memory_access_source.gst", 6, 12, "none", "", 0, 0, 0, 54, 1, 54, "memory_access_operation_valid", ctx), ctx);
    table = mir_memory_access_table_with_operation(table, mir_memory_access_make_operation(table, "store_pointer_i32", "store", i32_layout.layout.type_id, i32_layout.layout.layout_id, i32_layout.layout.size, i32_layout.layout.alignment, "pointer", mutable_pointer.pointer_type.pointer_type_id, local1.slot_id, local1.mutability, mutable_pointer.pointer_type.nullability, local1.lifetime_region, "compiler/phase14_typed_memory_access_source.gst", 8, 5, "none", "", 0, 0, 0, 55, 1, 55, "memory_access_operation_valid", ctx), ctx);
    table = mir_memory_access_table_with_operation(table, mir_memory_access_make_operation(table, "load_pointer_i32", "load", i32_layout.layout.type_id, i32_layout.layout.layout_id, i32_layout.layout.size, i32_layout.layout.alignment, "pointer", mutable_pointer.pointer_type.pointer_type_id, local1.slot_id, local1.mutability, mutable_pointer.pointer_type.nullability, local1.lifetime_region, "compiler/phase14_typed_memory_access_source.gst", 9, 12, "none", "", 0, 0, 0, 55, 1, 55, "memory_access_operation_valid", ctx), ctx);
    table = mir_memory_access_table_with_operation(table, mir_memory_access_make_operation(table, "offset_aggregate_i32_second", "layout_offset", i32_layout.layout.type_id, i32_layout.layout.layout_id, i32_layout.layout.size, i32_layout.layout.alignment, "stack_slot", aggregate0.slot_id, aggregate0.slot_id, aggregate0.mutability, "not_applicable", aggregate0.lifetime_region, "compiler/phase14_typed_memory_access_composition_source.gst", 7, 9, "element", i32_layout.layout.layout_id, 1, 0, i32_layout.layout.element_stride, 0, 1, i32_layout.layout.element_stride, "memory_access_operation_valid", ctx), ctx);
    table = mir_memory_access_table_with_operation(table, mir_memory_access_make_operation(table, "copy_aggregate_i32_element", "aggregate_copy", i32_layout.layout.type_id, i32_layout.layout.layout_id, i32_layout.layout.size, i32_layout.layout.alignment, "stack_slot", aggregate0.slot_id, aggregate0.slot_id, aggregate0.mutability, "not_applicable", aggregate0.lifetime_region, "compiler/phase14_typed_memory_access_composition_source.gst", 8, 5, "element", i32_layout.layout.layout_id, 1, 0, i32_layout.layout.element_stride, 50, 1, 50, "memory_access_operation_valid", ctx), ctx);
    return table;
}

func mir_serialize_memory_access_table_for_request(table: MirMemoryAccessTable[ctx], layout_table: layout.MirLayoutTable[ctx], pointer_table: pointer.MirPointerTable[ctx], stack_slot_table: stack_slot.MirStackSlotTable[ctx], ctx: &Arena) str {
    if mir_memory_access_table_is_valid(table, layout_table, pointer_table, stack_slot_table, ctx) == 0 {
        if len(table.target_id) == 0 {
            mut empty_output := "memory_access_table_format: gust.compiler_memory_access_table.v1\n";
            empty_output = std.Concat(empty_output, "memory_access_target_id: \n");
            empty_output = std.Concat(empty_output, std.Concat("memory_access_target_triple: ", std.Concat(table.target_triple, "\n")));
            empty_output = std.Concat(empty_output, "memory_access_natural_alignment_policy: required_exact_compiler_alignment\n");
            empty_output = std.Concat(empty_output, "memory_access_unaligned_policy: rejected_not_selected\n");
            empty_output = std.Concat(empty_output, "memory_access_zero_sized_policy: rejected_no_selected_zero_sized_type\n");
            empty_output = std.Concat(empty_output, "memory_access_known_null_policy: rejected_before_codegen\n");
            empty_output = std.Concat(empty_output, "memory_access_initialization_policy: loads_require_initialization_or_prior_store\n");
            empty_output = std.Concat(empty_output, "memory_access_overlap_policy: bounded_copy_requires_non_overlapping_ranges\n");
            empty_output = std.Concat(empty_output, "memory_access_operation_count: 0\n");
            return std.Clone(ctx, empty_output);
        }
        return "memory_access_table_format: invalid\n";
    }
    mut output := "memory_access_table_format: gust.compiler_memory_access_table.v1\n";
    output = std.Concat(output, std.Concat("memory_access_target_id: ", std.Concat(table.target_id, "\n")));
    output = std.Concat(output, std.Concat("memory_access_target_triple: ", std.Concat(table.target_triple, "\n")));
    output = std.Concat(output, std.Concat("memory_access_natural_alignment_policy: ", std.Concat(table.natural_alignment_policy, "\n")));
    output = std.Concat(output, std.Concat("memory_access_unaligned_policy: ", std.Concat(table.unaligned_policy, "\n")));
    output = std.Concat(output, std.Concat("memory_access_zero_sized_policy: ", std.Concat(table.zero_sized_policy, "\n")));
    output = std.Concat(output, std.Concat("memory_access_known_null_policy: ", std.Concat(table.known_null_policy, "\n")));
    output = std.Concat(output, std.Concat("memory_access_initialization_policy: ", std.Concat(table.initialization_policy, "\n")));
    output = std.Concat(output, std.Concat("memory_access_overlap_policy: ", std.Concat(table.overlap_policy, "\n")));
    mut operations: std.Vector[MirMemoryAccessOperation[ctx], ctx] := ctx[table.operations];
    output = std.Concat(output, std.Concat("memory_access_operation_count: ", std.Concat(std.FormatInt(len(operations)), "\n")));
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        mut prefix := std.Concat("memory_access_operation_", std.FormatInt(operation_index));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_id: ", std.Concat(operation.operation_id, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_name: ", std.Concat(operation.operation_name, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_target_id: ", std.Concat(operation.target_id, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_kind: ", std.Concat(operation.kind, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_accessed_type_id: ", std.Concat(operation.accessed_type_id, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_accessed_layout_id: ", std.Concat(operation.accessed_layout_id, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_byte_width: ", std.Concat(std.FormatInt(operation.byte_width), "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_required_alignment: ", std.Concat(std.FormatInt(operation.required_alignment), "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_origin_kind: ", std.Concat(operation.origin_kind, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_origin_id: ", std.Concat(operation.origin_id, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_origin_slot_id: ", std.Concat(operation.origin_slot_id, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_origin_mutability: ", std.Concat(operation.origin_mutability, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_origin_nullability: ", std.Concat(operation.origin_nullability, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_lifetime_region: ", std.Concat(operation.lifetime_region, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_source_file: ", std.Concat(operation.source_file, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_source_line: ", std.Concat(std.FormatInt(operation.source_line), "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_source_column: ", std.Concat(std.FormatInt(operation.source_column), "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_offset_kind: ", std.Concat(operation.offset_kind, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_offset_layout_id: ", std.Concat(operation.offset_layout_id, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_element_index: ", std.Concat(std.FormatInt(operation.element_index), "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_source_offset: ", std.Concat(std.FormatInt(operation.source_offset), "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_destination_offset: ", std.Concat(std.FormatInt(operation.destination_offset), "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_input_value: ", std.Concat(std.FormatInt(operation.input_value), "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_expect_success: ", std.Concat(std.FormatInt(operation.expect_success), "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_expected_value: ", std.Concat(std.FormatInt(operation.expected_value), "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_expected_reason_code: ", std.Concat(operation.expected_reason_code, "\n"))));
        operation_index = operation_index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_memory_access_witness(table: MirMemoryAccessTable[ctx], layout_table: layout.MirLayoutTable[ctx], pointer_table: pointer.MirPointerTable[ctx], stack_slot_table: stack_slot.MirStackSlotTable[ctx], ctx: &Arena) str {
    if mir_memory_access_table_is_valid(table, layout_table, pointer_table, stack_slot_table, ctx) == 0 { return ""; }
    mut output := "memory_access_status: valid\n";
    output = std.Concat(output, std.Concat("memory_access_target: ", std.Concat(table.target_triple, "\n")));
    output = std.Concat(output, std.Concat("memory_access_target_id: ", std.Concat(table.target_id, "\n")));
    output = std.Concat(output, std.Concat("memory_access_natural_alignment_policy: ", std.Concat(table.natural_alignment_policy, "\n")));
    output = std.Concat(output, std.Concat("memory_access_unaligned_policy: ", std.Concat(table.unaligned_policy, "\n")));
    output = std.Concat(output, std.Concat("memory_access_zero_sized_policy: ", std.Concat(table.zero_sized_policy, "\n")));
    output = std.Concat(output, std.Concat("memory_access_known_null_policy: ", std.Concat(table.known_null_policy, "\n")));
    output = std.Concat(output, std.Concat("memory_access_initialization_policy: ", std.Concat(table.initialization_policy, "\n")));
    output = std.Concat(output, std.Concat("memory_access_overlap_policy: ", std.Concat(table.overlap_policy, "\n")));
    mut operations: std.Vector[MirMemoryAccessOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        mut evaluation := mir_memory_access_evaluate(operation, ctx);
        output = std.Concat(output, "memory_access_operation: ");
        output = std.Concat(output, operation.operation_name);
        output = std.Concat(output, " kind="); output = std.Concat(output, operation.kind);
        output = std.Concat(output, " type="); output = std.Concat(output, operation.accessed_type_id);
        output = std.Concat(output, " layout="); output = std.Concat(output, operation.accessed_layout_id);
        output = std.Concat(output, " width="); output = std.Concat(output, std.FormatInt(operation.byte_width));
        output = std.Concat(output, " alignment="); output = std.Concat(output, std.FormatInt(operation.required_alignment));
        output = std.Concat(output, " origin="); output = std.Concat(output, operation.origin_kind);
        output = std.Concat(output, " origin_id="); output = std.Concat(output, operation.origin_id);
        output = std.Concat(output, " slot="); output = std.Concat(output, operation.origin_slot_id);
        output = std.Concat(output, " mutability="); output = std.Concat(output, operation.origin_mutability);
        output = std.Concat(output, " nullability="); output = std.Concat(output, operation.origin_nullability);
        output = std.Concat(output, " lifetime="); output = std.Concat(output, operation.lifetime_region);
        output = std.Concat(output, " source="); output = std.Concat(output, operation.source_file);
        output = std.Concat(output, ":"); output = std.Concat(output, std.FormatInt(operation.source_line));
        output = std.Concat(output, ":"); output = std.Concat(output, std.FormatInt(operation.source_column));
        output = std.Concat(output, " offset_kind="); output = std.Concat(output, operation.offset_kind);
        output = std.Concat(output, " source_offset="); output = std.Concat(output, std.FormatInt(operation.source_offset));
        output = std.Concat(output, " destination_offset="); output = std.Concat(output, std.FormatInt(operation.destination_offset));
        output = std.Concat(output, " status=");
        if evaluation.valid == 1 { output = std.Concat(output, "success"); } else { output = std.Concat(output, "failure"); }
        output = std.Concat(output, " value="); output = std.Concat(output, std.FormatInt(evaluation.value));
        output = std.Concat(output, " reason="); output = std.Concat(output, evaluation.reason_code);
        output = std.Concat(output, "\n");
        operation_index = operation_index + 1;
    }
    return std.Clone(ctx, output);
}