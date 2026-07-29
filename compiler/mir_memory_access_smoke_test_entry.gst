import "mir.gst" as mir;
import "mir_layout.gst" as layout;
import "mir_primitive_layout.gst" as primitive;
import "mir_integer_conversion.gst" as conversion;
import "mir_pointer.gst" as pointer;
import "mir_stack_slot.gst" as stack_slot;
import "mir_memory_access.gst" as memory_access;
import "mir_memory_access_mir_to_c.gst" as memory_c;
import "mir_memory_access_diagnostics.gst" as diagnostics;
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
        "phase14_typed_memory_access.gst",
        "",
        "phase14_typed_memory_access.o",
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

func verify_canonical_mir(table: memory_access.MirMemoryAccessTable[ctx], layout_table: layout.MirLayoutTable[ctx], pointer_table: pointer.MirPointerTable[ctx], stack_slot_table: stack_slot.MirStackSlotTable[ctx], ctx: &Arena) {
    mut program := mir.mir_make_program(ctx);
    mut operations: std.Vector[memory_access.MirMemoryAccessOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        program = mir.mir_program_with_memory_access_reference(
            program,
            mir.mir_make_memory_access_reference(operations[operation_index], ctx),
            ctx
        );
        operation_index = operation_index + 1;
    }
    if mir.mir_program_memory_access_references_are_valid(
        program,
        table,
        layout_table,
        pointer_table,
        stack_slot_table,
        ctx
    ) == 0
    {
        fail("Memory-access smoke: canonical MIR references drifted");
    }

    mut store_query := memory_access.mir_memory_access_operation(table, "store_stack_i32", ctx);
    mut load_query := memory_access.mir_memory_access_operation(table, "load_stack_i32", ctx);
    mut span := mir.mir_make_empty_span();
    mut store_value_idx := mir.mir_alloc_value(
        mir.mir_make_value_int_literal(54, "type:gust:i32", span, ctx),
        ctx
    );
    mut store_stmt := mir.mir_make_stmt_memory_access(
        mir.mir_make_memory_access_reference(store_query.operation, ctx),
        store_value_idx,
        span,
        ctx
    );
    if std.str_eq(mir.mir_debug_stmt_kind(store_stmt), "MirStmt.MemoryAccess") == 0 {
        fail("Memory-access smoke: store MIR kind drifted");
    }
    mut operands: std.Vector[mir.MirValue[ctx], ctx] := std.VectorNew(ctx);
    mut operands_idx: Index[std.Vector[mir.MirValue[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(operands_idx, operands);
    mut load_value := mir.mir_make_value_memory_access(
        operands_idx,
        mir.mir_make_memory_access_reference(load_query.operation, ctx),
        "type:gust:i32",
        span,
        ctx
    );
    if std.str_eq(mir.mir_debug_value_kind(load_value), "MirValue.MemoryAccess") == 0 {
        fail("Memory-access smoke: load MIR kind drifted");
    }
}

func verify_negatives(ctx: &Arena) {
    mut classes: std.Vector[str, ctx] := std.VectorNew(ctx);
    classes.Push(std.Clone(ctx, "wrong_width"));
    classes.Push(std.Clone(ctx, "wrong_alignment"));
    classes.Push(std.Clone(ctx, "wrong_pointee_type"));
    classes.Push(std.Clone(ctx, "immutable_store"));
    classes.Push(std.Clone(ctx, "invalid_layout_id"));
    classes.Push(std.Clone(ctx, "out_of_lifetime"));
    classes.Push(std.Clone(ctx, "unsupported_overlap"));
    classes.Push(std.Clone(ctx, "known_null"));
    classes.Push(std.Clone(ctx, "read_before_write"));
    classes.Push(std.Clone(ctx, "unaligned"));
    classes.Push(std.Clone(ctx, "zero_sized"));
    mut class_index := 0;
    while class_index < len(classes) {
        mut result := memory_access.mir_memory_access_rejection(classes[class_index], ctx);
        if result.valid != 0 || std.str_find(result.reason_code, "memory_access_") != 0 {
            fail("Memory-access smoke: invalid access escaped compiler rejection");
        }
        mut diagnostic := diagnostics.mir_memory_access_diagnostic(
            result.reason_code,
            classes[class_index],
            "type:gust:i32",
            "layout:test",
            4,
            4,
            "stack_slot",
            "mutable",
            "compiler/phase14_typed_memory_access_source.gst",
            1,
            1,
            ctx
        );
        if std.str_find(diagnostic, "taxonomy=gust.memory_access.diagnostic.v1") == 0 - 1 ||
           std.str_find(diagnostic, result.reason_code) == 0 - 1
        {
            fail("Memory-access smoke: stable diagnostic drifted");
        }
        class_index = class_index + 1;
    }
}

func write_target_artifacts(target_triple: str, object_format: str, layout_table: layout.MirLayoutTable[ctx], conversion_table: conversion.MirIntegerConversionTable[ctx], pointer_table: pointer.MirPointerTable[ctx], stack_slot_table: stack_slot.MirStackSlotTable[ctx], table: memory_access.MirMemoryAccessTable[ctx], ctx: &Arena) {
    mut root := std.Concat("build/guards/phase14_memory_access/", target_triple);
    mut expected_path := std.Concat(root, "/expected.witness");
    mut c_path := std.Concat(root, "/mir-to-c-memory-access.c");
    mut request_path := std.Concat(root, "/memory-access.request");
    mut expected := memory_access.mir_memory_access_witness(
        table,
        layout_table,
        pointer_table,
        stack_slot_table,
        ctx
    );
    mut c_source := memory_c.mir_memory_access_c_source(
        table,
        layout_table,
        pointer_table,
        stack_slot_table,
        ctx
    );
    if len(expected) == 0 || len(c_source) == 0 ||
       os.WriteFile(expected_path, expected) == 0 ||
       os.WriteFile(c_path, c_source) == 0
    {
        fail("Memory-access smoke: could not write backend witnesses");
    }

    mut output_path := std.Concat("/tmp/gust-phase14-memory-access-", target_triple);
    mut backend_request := request.mir_native_backend_make_request_with_typed_memory_tables(
        target_triple,
        object_format,
        output_path,
        std.Concat(output_path, ".bundle"),
        make_bundle(ctx),
        layout_table,
        conversion_table,
        pointer_table,
        stack_slot_table,
        table,
        ctx
    );
    mut serialized := request.mir_serialize_native_backend_request(backend_request, ctx);
    if std.str_find(serialized, "memory_access_table_format: gust.compiler_memory_access_table.v1\n") == 0 - 1 ||
       std.str_find(serialized, "memory_access_count: 1\n") == 0 - 1 ||
       std.str_find(serialized, "memory_access_operation_count: 6\n") == 0 - 1
    {
        fail("Memory-access smoke: request serialization lost typed access identity");
    }
    if os.WriteFile(request_path, serialized) == 0 {
        fail("Memory-access smoke: could not write compiler request");
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut targets: std.Vector[str, ctx] := ctx[
        primitive.mir_primitive_layout_declared_target_triples(ctx)
    ];
    mut target_index := 0;
    while target_index < len(targets) {
        mut target_triple := targets[target_index];
        mut target := primitive.mir_primitive_layout_target(target_triple, ctx);
        mut primitive_layout_table := primitive.mir_primitive_layout_table_for_target(
            target_triple,
            ctx
        );
        mut layout_table := memory_access.mir_memory_access_layout_table(
            primitive_layout_table,
            ctx
        );
        mut conversion_table := conversion.mir_integer_conversion_table_for_layout(
            layout_table,
            ctx
        );
        mut pointer_table := pointer.mir_pointer_table_for_layout(layout_table, ctx);
        mut stack_slot_table := stack_slot.mir_stack_slot_table_for_layout(
            layout_table,
            ctx
        );
        mut table := memory_access.mir_memory_access_table_for_memory_tables(
            layout_table,
            pointer_table,
            stack_slot_table,
            ctx
        );
        if target.found == 0 ||
           memory_access.mir_memory_access_table_is_valid(
               table,
               layout_table,
               pointer_table,
               stack_slot_table,
               ctx
           ) == 0
        {
            fail("Memory-access smoke: declared target table rejected");
        }
        verify_canonical_mir(
            table,
            layout_table,
            pointer_table,
            stack_slot_table,
            ctx
        );
        verify_negatives(ctx);
        write_target_artifacts(
            target_triple,
            target.object_format,
            layout_table,
            conversion_table,
            pointer_table,
            stack_slot_table,
            table,
            ctx
        );
        target_index = target_index + 1;
    }

    os.LogStr("SUCCESS: Phase 14 typed loads, stores, and memory-access validation");
}