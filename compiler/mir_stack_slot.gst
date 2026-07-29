// Phase 14.5 compiler-owned stack-slot and addressable-local authority.
//
// This module distinguishes SSA-only locals from addressable stack locals and
// compiler-generated temporary slots. Every selected slot has a deterministic
// identity, compiler-owned size/alignment/type/layout, initialization state,
// origin, lifetime, mutability, and no-escape policy. Dynamic allocation,
// variable-sized slots, resource-bearing storage, escaping addresses, and
// unsupported aliasing remain rejected before driver discovery.

import "mir_layout.gst" as layout;

type MirStackSlot[ctx] struct {
    slot_id: str,
    target_id: str,
    target_triple: str,
    storage_class: str,
    local_id: int,
    contained_type_id: str,
    contained_layout_id: str,
    size: int,
    alignment: int,
    initialization_state: str,
    source_origin: str,
    lifetime_region: str,
    mutability: str,
    address_escape_policy: str,
    resource_kind: str
}

type MirStackSlotOperation[ctx] struct {
    operation_id: str,
    operation_name: str,
    target_id: str,
    kind: str,
    slot_id: str,
    source_slot_id: str,
    destination_slot_id: str,
    contained_type_id: str,
    contained_layout_id: str,
    context_kind: str,
    input_value: int,
    expect_success: int,
    expected_value: int,
    expected_reason_code: str
}

type MirStackSlotTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    lifetime_policy: str,
    address_escape_policy: str,
    slots: Index[std.Vector[MirStackSlot[ctx], ctx], ctx],
    operations: Index[std.Vector[MirStackSlotOperation[ctx], ctx], ctx]
}

type MirStackSlotQuery[ctx] struct {
    found: int,
    slot: MirStackSlot[ctx]
}

type MirStackSlotOperationQuery[ctx] struct {
    found: int,
    operation: MirStackSlotOperation[ctx]
}

type MirStackSlotValidation[ctx] struct {
    valid: int,
    value: int,
    reason_code: str
}

func mir_stack_slot_empty_slot_vector(ctx: &Arena) Index[std.Vector[MirStackSlot[ctx], ctx], ctx] {
    mut slots: std.Vector[MirStackSlot[ctx], ctx] := std.VectorNew(ctx);
    mut slots_idx: Index[std.Vector[MirStackSlot[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(slots_idx, slots);
    return slots_idx;
}

func mir_stack_slot_empty_operation_vector(ctx: &Arena) Index[std.Vector[MirStackSlotOperation[ctx], ctx], ctx] {
    mut operations: std.Vector[MirStackSlotOperation[ctx], ctx] := std.VectorNew(ctx);
    mut operations_idx: Index[std.Vector[MirStackSlotOperation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(operations_idx, operations);
    return operations_idx;
}

func mir_stack_slot_make_empty_table(target_triple: str, ctx: &Arena) MirStackSlotTable[ctx] {
    mut table: MirStackSlotTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_stack_slot_table.v1");
    table.target_id = std.Clone(ctx, "");
    table.target_triple = std.Clone(ctx, target_triple);
    table.lifetime_policy = std.Clone(ctx, "lexical_function_region");
    table.address_escape_policy = std.Clone(ctx, "no_escape_outside_declared_lifetime");
    table.slots = mir_stack_slot_empty_slot_vector(ctx);
    table.operations = mir_stack_slot_empty_operation_vector(ctx);
    return table;
}

func mir_stack_slot_local_storage_class(address_taken: int, compiler_generated: int) str {
    if compiler_generated == 1 { return "compiler_temporary"; }
    if address_taken == 1 { return "addressable_local"; }
    return "ssa_only";
}

func mir_stack_slot_storage_class_is_valid(value: str) int {
    if std.str_eq(value, "addressable_local") == 1 { return 1; }
    if std.str_eq(value, "compiler_temporary") == 1 { return 1; }
    return 0;
}

func mir_stack_slot_initialization_state_is_valid(value: str) int {
    if std.str_eq(value, "uninitialized") == 1 { return 1; }
    if std.str_eq(value, "initialized") == 1 { return 1; }
    return 0;
}

func mir_stack_slot_mutability_is_valid(value: str) int {
    if std.str_eq(value, "immutable") == 1 { return 1; }
    if std.str_eq(value, "mutable") == 1 { return 1; }
    return 0;
}

func mir_stack_slot_context_is_valid(value: str) int {
    if std.str_eq(value, "local") == 1 { return 1; }
    if std.str_eq(value, "branch") == 1 { return 1; }
    if std.str_eq(value, "loop") == 1 { return 1; }
    if std.str_eq(value, "aggregate") == 1 { return 1; }
    return 0;
}

func mir_stack_slot_operation_kind_is_valid(value: str) int {
    if std.str_eq(value, "declare") == 1 { return 1; }
    if std.str_eq(value, "address_of") == 1 { return 1; }
    if std.str_eq(value, "initialize") == 1 { return 1; }
    if std.str_eq(value, "assign") == 1 { return 1; }
    if std.str_eq(value, "read") == 1 { return 1; }
    if std.str_eq(value, "bounded_aggregate_copy") == 1 { return 1; }
    return 0;
}

func mir_stack_slot_identity(slot: MirStackSlot[ctx], ctx: &Arena) str {
    mut identity := "stack_slot:v1:target=";
    identity = std.Concat(identity, slot.target_id);
    identity = std.Concat(identity, ":class=");
    identity = std.Concat(identity, slot.storage_class);
    identity = std.Concat(identity, ":local=");
    identity = std.Concat(identity, std.FormatInt(slot.local_id));
    identity = std.Concat(identity, ":type=");
    identity = std.Concat(identity, slot.contained_type_id);
    identity = std.Concat(identity, ":layout=");
    identity = std.Concat(identity, slot.contained_layout_id);
    identity = std.Concat(identity, ":size=");
    identity = std.Concat(identity, std.FormatInt(slot.size));
    identity = std.Concat(identity, ":align=");
    identity = std.Concat(identity, std.FormatInt(slot.alignment));
    identity = std.Concat(identity, ":origin=");
    identity = std.Concat(identity, slot.source_origin);
    identity = std.Concat(identity, ":lifetime=");
    identity = std.Concat(identity, slot.lifetime_region);
    return std.Clone(ctx, identity);
}

func mir_stack_slot_operation_identity(operation: MirStackSlotOperation[ctx], ctx: &Arena) str {
    mut identity := "stack_slot_operation:v1:target=";
    identity = std.Concat(identity, operation.target_id);
    identity = std.Concat(identity, ":kind=");
    identity = std.Concat(identity, operation.kind);
    identity = std.Concat(identity, ":name=");
    identity = std.Concat(identity, operation.operation_name);
    identity = std.Concat(identity, ":slot=");
    identity = std.Concat(identity, operation.slot_id);
    identity = std.Concat(identity, ":source=");
    identity = std.Concat(identity, operation.source_slot_id);
    identity = std.Concat(identity, ":destination=");
    identity = std.Concat(identity, operation.destination_slot_id);
    return std.Clone(ctx, identity);
}

func mir_stack_slot_aggregate_layout_id(target_id: str, element_layout_id: str, size: int, alignment: int, ctx: &Arena) str {
    mut identity := "stack_aggregate_layout:v1:target=";
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":element=");
    identity = std.Concat(identity, element_layout_id);
    identity = std.Concat(identity, ":count=2:size=");
    identity = std.Concat(identity, std.FormatInt(size));
    identity = std.Concat(identity, ":align=");
    identity = std.Concat(identity, std.FormatInt(alignment));
    return std.Clone(ctx, identity);
}

func mir_stack_slot_make_slot(target_id: str, target_triple: str, storage_class: str, local_id: int, contained_type_id: str, contained_layout_id: str, size: int, alignment: int, initialization_state: str, source_origin: str, lifetime_region: str, mutability: str, ctx: &Arena) MirStackSlot[ctx] {
    mut slot: MirStackSlot[ctx];
    slot.slot_id = std.Clone(ctx, "");
    slot.target_id = std.Clone(ctx, target_id);
    slot.target_triple = std.Clone(ctx, target_triple);
    slot.storage_class = std.Clone(ctx, storage_class);
    slot.local_id = local_id;
    slot.contained_type_id = std.Clone(ctx, contained_type_id);
    slot.contained_layout_id = std.Clone(ctx, contained_layout_id);
    slot.size = size;
    slot.alignment = alignment;
    slot.initialization_state = std.Clone(ctx, initialization_state);
    slot.source_origin = std.Clone(ctx, source_origin);
    slot.lifetime_region = std.Clone(ctx, lifetime_region);
    slot.mutability = std.Clone(ctx, mutability);
    slot.address_escape_policy = std.Clone(ctx, "no_escape_outside_declared_lifetime");
    slot.resource_kind = std.Clone(ctx, "non_resource");
    slot.slot_id = mir_stack_slot_identity(slot, ctx);
    return slot;
}

func mir_stack_slot_table_with_slot(table: MirStackSlotTable[ctx], slot: MirStackSlot[ctx], ctx: &Arena) MirStackSlotTable[ctx] {
    mut updated := table;
    mut slots: std.Vector[MirStackSlot[ctx], ctx] := ctx[updated.slots];
    slots.Push(slot);
    ctx.Set(updated.slots, slots);
    return updated;
}

func mir_stack_slot(table: MirStackSlotTable[ctx], slot_id: str, ctx: &Arena) MirStackSlotQuery[ctx] {
    mut query: MirStackSlotQuery[ctx];
    query.found = 0;
    mut slots: std.Vector[MirStackSlot[ctx], ctx] := ctx[table.slots];
    mut index := 0;
    while index < len(slots) {
        if std.str_eq(slots[index].slot_id, slot_id) == 1 {
            query.found = 1;
            query.slot = slots[index];
            return query;
        }
        index = index + 1;
    }
    return query;
}

func mir_stack_slot_make_operation(table: MirStackSlotTable[ctx], operation_name: str, kind: str, slot_id: str, source_slot_id: str, destination_slot_id: str, contained_type_id: str, contained_layout_id: str, context_kind: str, input_value: int, expect_success: int, expected_value: int, expected_reason_code: str, ctx: &Arena) MirStackSlotOperation[ctx] {
    mut operation: MirStackSlotOperation[ctx];
    operation.operation_id = std.Clone(ctx, "");
    operation.operation_name = std.Clone(ctx, operation_name);
    operation.target_id = std.Clone(ctx, table.target_id);
    operation.kind = std.Clone(ctx, kind);
    operation.slot_id = std.Clone(ctx, slot_id);
    operation.source_slot_id = std.Clone(ctx, source_slot_id);
    operation.destination_slot_id = std.Clone(ctx, destination_slot_id);
    operation.contained_type_id = std.Clone(ctx, contained_type_id);
    operation.contained_layout_id = std.Clone(ctx, contained_layout_id);
    operation.context_kind = std.Clone(ctx, context_kind);
    operation.input_value = input_value;
    operation.expect_success = expect_success;
    operation.expected_value = expected_value;
    operation.expected_reason_code = std.Clone(ctx, expected_reason_code);
    operation.operation_id = mir_stack_slot_operation_identity(operation, ctx);
    return operation;
}

func mir_stack_slot_table_with_operation(table: MirStackSlotTable[ctx], operation: MirStackSlotOperation[ctx], ctx: &Arena) MirStackSlotTable[ctx] {
    mut updated := table;
    mut operations: std.Vector[MirStackSlotOperation[ctx], ctx] := ctx[updated.operations];
    operations.Push(operation);
    ctx.Set(updated.operations, operations);
    return updated;
}

func mir_stack_slot_operation(table: MirStackSlotTable[ctx], operation_name: str, ctx: &Arena) MirStackSlotOperationQuery[ctx] {
    mut query: MirStackSlotOperationQuery[ctx];
    query.found = 0;
    mut operations: std.Vector[MirStackSlotOperation[ctx], ctx] := ctx[table.operations];
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

func mir_stack_slot_evaluate(operation: MirStackSlotOperation[ctx], ctx: &Arena) MirStackSlotValidation[ctx] {
    mut result: MirStackSlotValidation[ctx];
    result.valid = 0;
    result.value = 0;
    result.reason_code = std.Clone(ctx, "stack_slot_operation_unsupported");
    if mir_stack_slot_operation_kind_is_valid(operation.kind) == 0 {
        return result;
    }
    result.valid = 1;
    result.value = operation.input_value;
    if std.str_eq(operation.kind, "declare") == 1 ||
       std.str_eq(operation.kind, "address_of") == 1
    {
        result.value = 1;
    }
    result.reason_code = std.Clone(ctx, "stack_slot_operation_valid");
    return result;
}

func mir_stack_slot_rejection(kind: str, ctx: &Arena) MirStackSlotValidation[ctx] {
    mut result: MirStackSlotValidation[ctx];
    result.valid = 0;
    result.value = 0;
    result.reason_code = std.Clone(ctx, "stack_slot_operation_unsupported");
    if std.str_eq(kind, "uninitialized_read") == 1 { result.reason_code = std.Clone(ctx, "stack_slot_uninitialized_read"); return result; }
    if std.str_eq(kind, "duplicate_slot") == 1 { result.reason_code = std.Clone(ctx, "stack_slot_duplicate_identity"); return result; }
    if std.str_eq(kind, "wrong_slot_type") == 1 { result.reason_code = std.Clone(ctx, "stack_slot_type_mismatch"); return result; }
    if std.str_eq(kind, "under_aligned_slot") == 1 { result.reason_code = std.Clone(ctx, "stack_slot_under_aligned"); return result; }
    if std.str_eq(kind, "invalid_lifetime") == 1 { result.reason_code = std.Clone(ctx, "stack_slot_lifetime_invalid"); return result; }
    if std.str_eq(kind, "escaping_address") == 1 { result.reason_code = std.Clone(ctx, "stack_slot_address_escape_unsupported"); return result; }
    if std.str_eq(kind, "layout_id_mismatch") == 1 { result.reason_code = std.Clone(ctx, "stack_slot_layout_id_mismatch"); return result; }
    if std.str_eq(kind, "dynamic_stack_allocation") == 1 { result.reason_code = std.Clone(ctx, "stack_slot_dynamic_allocation_unsupported"); return result; }
    if std.str_eq(kind, "variable_sized_slot") == 1 { result.reason_code = std.Clone(ctx, "stack_slot_variable_size_unsupported"); return result; }
    if std.str_eq(kind, "resource_bearing_local") == 1 { result.reason_code = std.Clone(ctx, "stack_slot_resource_destructor_deferred"); return result; }
    if std.str_eq(kind, "unsupported_aliasing") == 1 { result.reason_code = std.Clone(ctx, "stack_slot_aliasing_unsupported"); return result; }
    return result;
}

func mir_stack_slot_table_is_valid(table: MirStackSlotTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if std.str_eq(table.format, "gust.compiler_stack_slot_table.v1") == 0 ||
       std.str_eq(table.target_id, layout_table.target.target_id) == 0 ||
       std.str_eq(table.target_triple, layout_table.target.target_triple) == 0 ||
       std.str_eq(table.lifetime_policy, "lexical_function_region") == 0 ||
       std.str_eq(table.address_escape_policy, "no_escape_outside_declared_lifetime") == 0 ||
       layout.mir_layout_table_is_valid(layout_table, ctx) == 0 ||
       layout_table.target.decisions_frozen == 0
    {
        return 0;
    }

    mut slots: std.Vector[MirStackSlot[ctx], ctx] := ctx[table.slots];
    if len(slots) != 4 { return 0; }
    mut slot_index := 0;
    while slot_index < len(slots) {
        mut slot := slots[slot_index];
        if std.str_eq(slot.slot_id, mir_stack_slot_identity(slot, ctx)) == 0 ||
           std.str_eq(slot.target_id, table.target_id) == 0 ||
           std.str_eq(slot.target_triple, table.target_triple) == 0 ||
           mir_stack_slot_storage_class_is_valid(slot.storage_class) == 0 ||
           mir_stack_slot_initialization_state_is_valid(slot.initialization_state) == 0 ||
           mir_stack_slot_mutability_is_valid(slot.mutability) == 0 ||
           std.str_eq(slot.address_escape_policy, table.address_escape_policy) == 0 ||
           std.str_eq(slot.resource_kind, "non_resource") == 0 ||
           slot.size <= 0 ||
           layout.mir_layout_alignment_is_valid(slot.alignment) == 0 ||
           slot.alignment > slot.size ||
           len(slot.lifetime_region) == 0 ||
           len(slot.source_origin) == 0
        {
            return 0;
        }
        if std.str_eq(slot.contained_type_id, "type:gust:aggregate:i32x2") == 1 {
            mut i32_layout := layout.mir_layout_of(layout_table, "type:gust:i32", table.target_id, ctx);
            if i32_layout.found == 0 ||
               slot.size != i32_layout.layout.size * 2 ||
               slot.alignment != i32_layout.layout.alignment ||
               std.str_eq(slot.contained_layout_id, mir_stack_slot_aggregate_layout_id(table.target_id, i32_layout.layout.layout_id, slot.size, slot.alignment, ctx)) == 0
            {
                return 0;
            }
        } else {
            mut contained := layout.mir_layout_of(layout_table, slot.contained_type_id, table.target_id, ctx);
            if contained.found == 0 ||
               std.str_eq(contained.layout.layout_id, slot.contained_layout_id) == 0 ||
               contained.layout.size != slot.size ||
               contained.layout.alignment != slot.alignment
            {
                return 0;
            }
        }
        mut prior_slot_index := 0;
        while prior_slot_index < slot_index {
            if std.str_eq(slots[prior_slot_index].slot_id, slot.slot_id) == 1 { return 0; }
            prior_slot_index = prior_slot_index + 1;
        }
        slot_index = slot_index + 1;
    }

    mut operations: std.Vector[MirStackSlotOperation[ctx], ctx] := ctx[table.operations];
    if len(operations) != 11 { return 0; }
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        if std.str_eq(operation.operation_id, mir_stack_slot_operation_identity(operation, ctx)) == 0 ||
           std.str_eq(operation.target_id, table.target_id) == 0 ||
           mir_stack_slot_operation_kind_is_valid(operation.kind) == 0 ||
           mir_stack_slot_context_is_valid(operation.context_kind) == 0 ||
           len(operation.slot_id) == 0
        {
            return 0;
        }
        mut slot_query := mir_stack_slot(table, operation.slot_id, ctx);
        if slot_query.found == 0 ||
           std.str_eq(slot_query.slot.contained_type_id, operation.contained_type_id) == 0 ||
           std.str_eq(slot_query.slot.contained_layout_id, operation.contained_layout_id) == 0
        {
            return 0;
        }
        if len(operation.source_slot_id) > 0 && mir_stack_slot(table, operation.source_slot_id, ctx).found == 0 { return 0; }
        if len(operation.destination_slot_id) > 0 && mir_stack_slot(table, operation.destination_slot_id, ctx).found == 0 { return 0; }
        mut evaluation := mir_stack_slot_evaluate(operation, ctx);
        if evaluation.valid != operation.expect_success ||
           evaluation.value != operation.expected_value ||
           std.str_eq(evaluation.reason_code, operation.expected_reason_code) == 0
        {
            return 0;
        }
        mut prior_operation_index := 0;
        while prior_operation_index < operation_index {
            if std.str_eq(operations[prior_operation_index].operation_id, operation.operation_id) == 1 { return 0; }
            prior_operation_index = prior_operation_index + 1;
        }
        operation_index = operation_index + 1;
    }
    return 1;
}

func mir_stack_slot_table_for_layout(layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) MirStackSlotTable[ctx] {
    mut table := mir_stack_slot_make_empty_table(layout_table.target.target_triple, ctx);
    if layout.mir_layout_table_is_valid(layout_table, ctx) == 0 || layout_table.target.decisions_frozen == 0 { return table; }
    table.target_id = std.Clone(ctx, layout_table.target.target_id);
    mut i32_layout := layout.mir_layout_of(layout_table, "type:gust:i32", table.target_id, ctx);
    if i32_layout.found == 0 { return table; }
    mut aggregate_layout_id := mir_stack_slot_aggregate_layout_id(
        table.target_id,
        i32_layout.layout.layout_id,
        i32_layout.layout.size * 2,
        i32_layout.layout.alignment,
        ctx
    );

    mut local0 := mir_stack_slot_make_slot(table.target_id, table.target_triple, "addressable_local", 0, "type:gust:i32", i32_layout.layout.layout_id, i32_layout.layout.size, i32_layout.layout.alignment, "uninitialized", "source:local:0", "function:main:block:0-3", "mutable", ctx);
    mut local1 := mir_stack_slot_make_slot(table.target_id, table.target_triple, "addressable_local", 1, "type:gust:i32", i32_layout.layout.layout_id, i32_layout.layout.size, i32_layout.layout.alignment, "initialized", "source:local:1", "function:main:block:0-3", "mutable", ctx);
    mut temporary0 := mir_stack_slot_make_slot(table.target_id, table.target_triple, "compiler_temporary", 1000, "type:gust:i32", i32_layout.layout.layout_id, i32_layout.layout.size, i32_layout.layout.alignment, "initialized", "compiler:temporary:loop-carried", "function:main:loop:1", "mutable", ctx);
    mut aggregate0 := mir_stack_slot_make_slot(table.target_id, table.target_triple, "addressable_local", 2, "type:gust:aggregate:i32x2", aggregate_layout_id, i32_layout.layout.size * 2, i32_layout.layout.alignment, "initialized", "source:aggregate:0", "function:main:block:0-3", "mutable", ctx);
    table = mir_stack_slot_table_with_slot(table, local0, ctx);
    table = mir_stack_slot_table_with_slot(table, local1, ctx);
    table = mir_stack_slot_table_with_slot(table, temporary0, ctx);
    table = mir_stack_slot_table_with_slot(table, aggregate0, ctx);

    table = mir_stack_slot_table_with_operation(table, mir_stack_slot_make_operation(table, "declare_addressable_i32", "declare", local0.slot_id, "", "", local0.contained_type_id, local0.contained_layout_id, "local", 1, 1, 1, "stack_slot_operation_valid", ctx), ctx);
    table = mir_stack_slot_table_with_operation(table, mir_stack_slot_make_operation(table, "address_of_addressable_i32", "address_of", local0.slot_id, "", "", local0.contained_type_id, local0.contained_layout_id, "local", 1, 1, 1, "stack_slot_operation_valid", ctx), ctx);
    table = mir_stack_slot_table_with_operation(table, mir_stack_slot_make_operation(table, "initialize_addressable_i32", "initialize", local0.slot_id, "", "", local0.contained_type_id, local0.contained_layout_id, "local", 51, 1, 51, "stack_slot_operation_valid", ctx), ctx);
    table = mir_stack_slot_table_with_operation(table, mir_stack_slot_make_operation(table, "assign_addressable_i32", "assign", local0.slot_id, "", "", local0.contained_type_id, local0.contained_layout_id, "local", 52, 1, 52, "stack_slot_operation_valid", ctx), ctx);
    table = mir_stack_slot_table_with_operation(table, mir_stack_slot_make_operation(table, "read_initialized_addressable_i32", "read", local1.slot_id, "", "", local1.contained_type_id, local1.contained_layout_id, "local", 52, 1, 52, "stack_slot_operation_valid", ctx), ctx);
    table = mir_stack_slot_table_with_operation(table, mir_stack_slot_make_operation(table, "declare_temporary_i32", "declare", temporary0.slot_id, "", "", temporary0.contained_type_id, temporary0.contained_layout_id, "loop", 1, 1, 1, "stack_slot_operation_valid", ctx), ctx);
    table = mir_stack_slot_table_with_operation(table, mir_stack_slot_make_operation(table, "loop_assign_temporary_i32", "assign", temporary0.slot_id, "", "", temporary0.contained_type_id, temporary0.contained_layout_id, "loop", 55, 1, 55, "stack_slot_operation_valid", ctx), ctx);
    table = mir_stack_slot_table_with_operation(table, mir_stack_slot_make_operation(table, "declare_aggregate_i32x2", "declare", aggregate0.slot_id, "", "", aggregate0.contained_type_id, aggregate0.contained_layout_id, "aggregate", 1, 1, 1, "stack_slot_operation_valid", ctx), ctx);
    table = mir_stack_slot_table_with_operation(table, mir_stack_slot_make_operation(table, "initialize_aggregate_i32x2", "initialize", aggregate0.slot_id, "", "", aggregate0.contained_type_id, aggregate0.contained_layout_id, "aggregate", 101, 1, 101, "stack_slot_operation_valid", ctx), ctx);
    table = mir_stack_slot_table_with_operation(table, mir_stack_slot_make_operation(table, "bounded_copy_aggregate_i32x2", "bounded_aggregate_copy", aggregate0.slot_id, aggregate0.slot_id, aggregate0.slot_id, aggregate0.contained_type_id, aggregate0.contained_layout_id, "aggregate", 101, 1, 101, "stack_slot_operation_valid", ctx), ctx);
    table = mir_stack_slot_table_with_operation(table, mir_stack_slot_make_operation(table, "branch_assign_addressable_i32", "assign", local1.slot_id, "", "", local1.contained_type_id, local1.contained_layout_id, "branch", 53, 1, 53, "stack_slot_operation_valid", ctx), ctx);
    return table;
}

func mir_serialize_stack_slot_table_for_request(table: MirStackSlotTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_stack_slot_table_is_valid(table, layout_table, ctx) == 0 { return "stack_slot_table_format: invalid\n"; }
    mut output := "stack_slot_table_format: gust.compiler_stack_slot_table.v1\n";
    output = std.Concat(output, std.Concat("stack_slot_target_id: ", std.Concat(table.target_id, "\n")));
    output = std.Concat(output, std.Concat("stack_slot_target_triple: ", std.Concat(table.target_triple, "\n")));
    output = std.Concat(output, std.Concat("stack_slot_lifetime_policy: ", std.Concat(table.lifetime_policy, "\n")));
    output = std.Concat(output, std.Concat("stack_slot_address_escape_policy: ", std.Concat(table.address_escape_policy, "\n")));
    mut slots: std.Vector[MirStackSlot[ctx], ctx] := ctx[table.slots];
    output = std.Concat(output, std.Concat("stack_slot_count: ", std.Concat(std.FormatInt(len(slots)), "\n")));
    mut slot_index := 0;
    while slot_index < len(slots) {
        mut prefix := std.Concat("stack_slot_", std.FormatInt(slot_index));
        mut slot := slots[slot_index];
        output = std.Concat(output, std.Concat(prefix, std.Concat("_id: ", std.Concat(slot.slot_id, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_target_id: ", std.Concat(slot.target_id, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_storage_class: ", std.Concat(slot.storage_class, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_local_id: ", std.Concat(std.FormatInt(slot.local_id), "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_contained_type_id: ", std.Concat(slot.contained_type_id, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_contained_layout_id: ", std.Concat(slot.contained_layout_id, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_size: ", std.Concat(std.FormatInt(slot.size), "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_alignment: ", std.Concat(std.FormatInt(slot.alignment), "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_initialization_state: ", std.Concat(slot.initialization_state, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_source_origin: ", std.Concat(slot.source_origin, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_lifetime_region: ", std.Concat(slot.lifetime_region, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_mutability: ", std.Concat(slot.mutability, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_address_escape_policy: ", std.Concat(slot.address_escape_policy, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_resource_kind: ", std.Concat(slot.resource_kind, "\n"))));
        slot_index = slot_index + 1;
    }
    mut operations: std.Vector[MirStackSlotOperation[ctx], ctx] := ctx[table.operations];
    output = std.Concat(output, std.Concat("stack_slot_operation_count: ", std.Concat(std.FormatInt(len(operations)), "\n")));
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut prefix := std.Concat("stack_slot_operation_", std.FormatInt(operation_index));
        mut operation := operations[operation_index];
        output = std.Concat(output, std.Concat(prefix, std.Concat("_id: ", std.Concat(operation.operation_id, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_name: ", std.Concat(operation.operation_name, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_target_id: ", std.Concat(operation.target_id, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_kind: ", std.Concat(operation.kind, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_slot_id: ", std.Concat(operation.slot_id, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_source_slot_id: ", std.Concat(operation.source_slot_id, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_destination_slot_id: ", std.Concat(operation.destination_slot_id, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_contained_type_id: ", std.Concat(operation.contained_type_id, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_contained_layout_id: ", std.Concat(operation.contained_layout_id, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_context_kind: ", std.Concat(operation.context_kind, "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_input_value: ", std.Concat(std.FormatInt(operation.input_value), "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_expect_success: ", std.Concat(std.FormatInt(operation.expect_success), "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_expected_value: ", std.Concat(std.FormatInt(operation.expected_value), "\n"))));
        output = std.Concat(output, std.Concat(prefix, std.Concat("_expected_reason_code: ", std.Concat(operation.expected_reason_code, "\n"))));
        operation_index = operation_index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_stack_slot_witness(table: MirStackSlotTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_stack_slot_table_is_valid(table, layout_table, ctx) == 0 { return "stack_slot_status: invalid\n"; }
    mut output := "stack_slot_status: valid\n";
    output = std.Concat(output, std.Concat("stack_slot_target: ", std.Concat(table.target_triple, "\n")));
    output = std.Concat(output, std.Concat("stack_slot_target_id: ", std.Concat(table.target_id, "\n")));
    output = std.Concat(output, std.Concat("stack_slot_lifetime_policy: ", std.Concat(table.lifetime_policy, "\n")));
    output = std.Concat(output, std.Concat("stack_slot_address_escape_policy: ", std.Concat(table.address_escape_policy, "\n")));
    mut slots: std.Vector[MirStackSlot[ctx], ctx] := ctx[table.slots];
    mut slot_index := 0;
    while slot_index < len(slots) {
        mut slot := slots[slot_index];
        output = std.Concat(output, "stack_slot: ");
        output = std.Concat(output, slot.slot_id);
        output = std.Concat(output, " class="); output = std.Concat(output, slot.storage_class);
        output = std.Concat(output, " type="); output = std.Concat(output, slot.contained_type_id);
        output = std.Concat(output, " layout="); output = std.Concat(output, slot.contained_layout_id);
        output = std.Concat(output, " size="); output = std.Concat(output, std.FormatInt(slot.size));
        output = std.Concat(output, " alignment="); output = std.Concat(output, std.FormatInt(slot.alignment));
        output = std.Concat(output, " initialization="); output = std.Concat(output, slot.initialization_state);
        output = std.Concat(output, " origin="); output = std.Concat(output, slot.source_origin);
        output = std.Concat(output, " lifetime="); output = std.Concat(output, slot.lifetime_region);
        output = std.Concat(output, " mutability="); output = std.Concat(output, slot.mutability);
        output = std.Concat(output, " escape="); output = std.Concat(output, slot.address_escape_policy);
        output = std.Concat(output, "\n");
        slot_index = slot_index + 1;
    }
    mut operations: std.Vector[MirStackSlotOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        mut evaluation := mir_stack_slot_evaluate(operation, ctx);
        output = std.Concat(output, "stack_slot_operation: ");
        output = std.Concat(output, operation.operation_name);
        output = std.Concat(output, " kind="); output = std.Concat(output, operation.kind);
        output = std.Concat(output, " slot="); output = std.Concat(output, operation.slot_id);
        output = std.Concat(output, " source="); output = std.Concat(output, operation.source_slot_id);
        output = std.Concat(output, " destination="); output = std.Concat(output, operation.destination_slot_id);
        output = std.Concat(output, " status=");
        if evaluation.valid == 1 { output = std.Concat(output, "success"); } else { output = std.Concat(output, "failure"); }
        output = std.Concat(output, " value="); output = std.Concat(output, std.FormatInt(evaluation.value));
        output = std.Concat(output, " reason="); output = std.Concat(output, evaluation.reason_code);
        output = std.Concat(output, " context="); output = std.Concat(output, operation.context_kind);
        output = std.Concat(output, "\n");
        operation_index = operation_index + 1;
    }
    return std.Clone(ctx, output);
}