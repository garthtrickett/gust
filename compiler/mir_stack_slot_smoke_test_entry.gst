import "mir.gst" as mir;
import "mir_layout.gst" as layout;
import "mir_primitive_layout.gst" as primitive;
import "mir_integer_conversion.gst" as conversion;
import "mir_pointer.gst" as pointer;
import "mir_stack_slot.gst" as stack_slot;
import "mir_stack_slot_mir_to_c.gst" as stack_c;
import "mir_stack_slot_diagnostics.gst" as diagnostics;
import "mir_native_backend_request.gst" as request;

func fail(msg: str) {
    os.LogStr(msg);
    os.Exit(1);
}

func make_bundle(ctx: &Arena) mir.MirProgramBundle[ctx] {
    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut canonical_record := "format: gust.compiler_mir_ingestion.v1\n";
    canonical_record = std.Concat(canonical_record, "function: main\n");
    canonical_record = std.Concat(canonical_record, "backend_symbol: main\n");
    canonical_record = std.Concat(canonical_record, "parameter_count: 0\n");
    canonical_record = std.Concat(canonical_record, "return_type: int\n");
    canonical_record = std.Concat(canonical_record, "local_count: 0\n");
    canonical_record = std.Concat(canonical_record, "entry_block: entry\n");
    canonical_record = std.Concat(canonical_record, "block_count: 1\n");
    canonical_record = std.Concat(canonical_record, "block_0_label: entry\n");
    canonical_record = std.Concat(canonical_record, "block_0_statement_count: 0\n");
    canonical_record = std.Concat(canonical_record, "block_0_terminator_kind: ReturnI32\n");
    canonical_record = std.Concat(canonical_record, "block_0_terminator_value: 0\n");
    canonical_record = std.Concat(canonical_record, "metadata_count: 0\n");
    canonical_record = std.Concat(canonical_record, "expected_exit: 0\n");
    mut module := mir.mir_make_program_bundle_module(
        "phase14_stack_slots.gst",
        "",
        "phase14_stack_slots.o",
        "gust.compiler_mir_ingestion.v1",
        canonical_record,
        0,
        0,
        0,
        ctx
    );
    module = mir.mir_program_bundle_module_with_symbol(
        module,
        mir.mir_make_program_bundle_symbol("main", "main", "()->int", 0, ctx),
        ctx
    );
    return mir.mir_program_bundle_with_module(bundle, module, ctx);
}

func verify_canonical_mir(table: stack_slot.MirStackSlotTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) {
    mut program := mir.mir_make_program(ctx);
    mut slots: std.Vector[stack_slot.MirStackSlot[ctx], ctx] := ctx[table.slots];
    mut slot_index := 0;
    while slot_index < len(slots) {
        program = mir.mir_program_with_stack_slot_reference(
            program,
            mir.mir_make_stack_slot_reference(slots[slot_index], ctx),
            ctx
        );
        slot_index = slot_index + 1;
    }
    mut operations: std.Vector[stack_slot.MirStackSlotOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        program = mir.mir_program_with_stack_slot_operation_reference(
            program,
            mir.mir_make_stack_slot_operation_reference(operations[operation_index], ctx),
            ctx
        );
        operation_index = operation_index + 1;
    }
    if mir.mir_program_stack_slot_references_are_valid(program, table, layout_table, ctx) == 0 {
        fail("Stack-slot smoke: canonical MIR references drifted");
    }

    mut operation_query := stack_slot.mir_stack_slot_operation(table, "initialize_addressable_i32", ctx);
    mut span := mir.mir_make_empty_span();
    mut value_idx := mir.mir_alloc_value(
        mir.mir_make_value_int_literal(51, "type:gust:i32", span, ctx),
        ctx
    );
    mut stmt := mir.mir_make_stmt_stack_slot_operation(
        mir.mir_make_stack_slot_operation_reference(operation_query.operation, ctx),
        value_idx,
        span,
        ctx
    );
    if std.str_eq(mir.mir_debug_stmt_kind(stmt), "MirStmt.StackSlotOperation") == 0 {
        fail("Stack-slot smoke: explicit MIR operation drifted");
    }
    unsafe {
        mut reference: mir.MirStackSlotOperationReference[ctx] := ctx[stmt.StackSlotOperation.operation];
        if std.str_eq(
            mir.mir_debug_stack_slot_operation_kind(reference.operation_kind),
            "initialize"
        ) == 0 ||
           std.str_eq(reference.contained_type_id, "type:gust:i32") == 0
        {
            fail("Stack-slot smoke: MIR operation identity drifted");
        }
    }
}

func verify_negatives(ctx: &Arena) {
    mut classes: std.Vector[str, ctx] := std.VectorNew(ctx);
    classes.Push(std.Clone(ctx, "uninitialized_read"));
    classes.Push(std.Clone(ctx, "duplicate_slot"));
    classes.Push(std.Clone(ctx, "wrong_slot_type"));
    classes.Push(std.Clone(ctx, "under_aligned_slot"));
    classes.Push(std.Clone(ctx, "invalid_lifetime"));
    classes.Push(std.Clone(ctx, "escaping_address"));
    classes.Push(std.Clone(ctx, "layout_id_mismatch"));
    classes.Push(std.Clone(ctx, "dynamic_stack_allocation"));
    classes.Push(std.Clone(ctx, "variable_sized_slot"));
    classes.Push(std.Clone(ctx, "resource_bearing_local"));
    classes.Push(std.Clone(ctx, "unsupported_aliasing"));
    mut index := 0;
    while index < len(classes) {
        mut result := stack_slot.mir_stack_slot_rejection(classes[index], ctx);
        if result.valid != 0 || std.str_find(result.reason_code, "stack_slot_") != 0 {
            fail("Stack-slot smoke: unsupported behavior escaped compiler rejection");
        }
        mut diagnostic := diagnostics.mir_stack_slot_diagnostic(
            result.reason_code,
            "compiler/phase14_stack_slot_addressable_source.gst",
            1,
            1,
            ctx
        );
        if std.str_find(diagnostic, "taxonomy=gust.stack_slot.diagnostic.v1") == 0 - 1 ||
           std.str_find(diagnostic, result.reason_code) == 0 - 1
        {
            fail("Stack-slot smoke: stable diagnostic drifted");
        }
        index = index + 1;
    }
}

func write_target_artifacts(target_triple: str, object_format: str, layout_table: layout.MirLayoutTable[ctx], conversion_table: conversion.MirIntegerConversionTable[ctx], pointer_table: pointer.MirPointerTable[ctx], table: stack_slot.MirStackSlotTable[ctx], ctx: &Arena) {
    mut root := std.Concat("build/guards/phase14_stack_slot/", target_triple);
    mut expected_path := std.Concat(root, "/expected.witness");
    mut c_path := std.Concat(root, "/mir-to-c-stack-slots.c");
    mut request_path := std.Concat(root, "/stack-slots.request");
    mut expected := stack_slot.mir_stack_slot_witness(table, layout_table, ctx);
    mut c_source := stack_c.mir_stack_slot_c_source(table, layout_table, ctx);
    if len(expected) == 0 || len(c_source) == 0 ||
       os.WriteFile(expected_path, expected) == 0 ||
       os.WriteFile(c_path, c_source) == 0
    {
        fail("Stack-slot smoke: could not write backend witnesses");
    }

    mut output_path := std.Concat("/tmp/gust-phase14-stack-slot-", target_triple);
    mut backend_request := request.mir_native_backend_make_request_with_memory_tables(
        target_triple,
        object_format,
        output_path,
        std.Concat(output_path, ".bundle"),
        make_bundle(ctx),
        layout_table,
        conversion_table,
        pointer_table,
        table,
        ctx
    );
    mut serialized := request.mir_serialize_native_backend_request(backend_request, ctx);
    if std.str_find(serialized, "stack_slot_table_format: gust.compiler_stack_slot_table.v1\n") == 0 - 1 ||
       std.str_find(serialized, "stack_slot_count: 4\n") == 0 - 1 ||
       std.str_find(serialized, "stack_slot_operation_count: 11\n") == 0 - 1
    {
        fail("Stack-slot smoke: request serialization lost slot identity");
    }
    if os.WriteFile(request_path, serialized) == 0 {
        fail("Stack-slot smoke: could not write compiler request");
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    if std.str_eq(stack_slot.mir_stack_slot_local_storage_class(0, 0), "ssa_only") == 0 ||
       std.str_eq(stack_slot.mir_stack_slot_local_storage_class(1, 0), "addressable_local") == 0 ||
       std.str_eq(stack_slot.mir_stack_slot_local_storage_class(0, 1), "compiler_temporary") == 0
    {
        fail("Stack-slot smoke: local storage classification drifted");
    }

    mut targets: std.Vector[str, ctx] := ctx[
        primitive.mir_primitive_layout_declared_target_triples(ctx)
    ];
    mut index := 0;
    while index < len(targets) {
        mut target_triple := targets[index];
        mut target := primitive.mir_primitive_layout_target(target_triple, ctx);
        mut layout_table := primitive.mir_primitive_layout_table_for_target(target_triple, ctx);
        mut conversion_table := conversion.mir_integer_conversion_table_for_layout(layout_table, ctx);
        mut pointer_table := pointer.mir_pointer_table_for_layout(layout_table, ctx);
        mut table := stack_slot.mir_stack_slot_table_for_layout(layout_table, ctx);
        if target.found == 0 || stack_slot.mir_stack_slot_table_is_valid(table, layout_table, ctx) == 0 {
            fail("Stack-slot smoke: declared target table rejected");
        }
        verify_canonical_mir(table, layout_table, ctx);
        verify_negatives(ctx);
        write_target_artifacts(
            target_triple,
            target.object_format,
            layout_table,
            conversion_table,
            pointer_table,
            table,
            ctx
        );
        index = index + 1;
    }

    os.LogStr("SUCCESS: Phase 14 deterministic stack slots and addressable locals");
}