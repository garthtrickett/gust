import "mir.gst" as mir;
import "mir_layout.gst" as layout;
import "mir_primitive_layout.gst" as primitive;
import "mir_integer_conversion.gst" as conversion;
import "mir_pointer.gst" as pointer;
import "mir_stack_slot.gst" as stack_slot;
import "mir_memory_access.gst" as memory_access;
import "mir_string_view.gst" as string_view;
import "mir_array_slice.gst" as array_slice;
import "mir_struct_layout.gst" as structs;
import "mir_struct_layout_mir_to_c.gst" as struct_c;
import "mir_struct_layout_diagnostics.gst" as diagnostics;
import "mir_enum.gst" as enums;
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
    canonical_record = std.Concat(canonical_record, "block_0_terminator_value: 59\n");
    canonical_record = std.Concat(canonical_record, "metadata_count: 0\n");
    canonical_record = std.Concat(canonical_record, "expected_exit: 59\n");
    mut module := mir.mir_make_program_bundle_module(
        "phase14_struct_source.gst",
        "",
        "phase14_struct.o",
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

func verify_canonical_mir(table: structs.MirStructTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) {
    mut program := mir.mir_make_program(ctx);
    mut layouts: std.Vector[structs.MirStructLayout[ctx], ctx] := ctx[table.layouts];
    mut layout_index := 0;
    while layout_index < len(layouts) {
        program = mir.mir_program_with_struct_layout_reference(
            program,
            mir.mir_make_struct_layout_reference(layouts[layout_index], ctx),
            ctx
        );
        layout_index = layout_index + 1;
    }
    mut values: std.Vector[structs.MirStructValue[ctx], ctx] := ctx[table.values];
    mut value_index := 0;
    while value_index < len(values) {
        program = mir.mir_program_with_struct_value_reference(
            program,
            mir.mir_make_struct_value_reference(values[value_index], ctx),
            ctx
        );
        value_index = value_index + 1;
    }
    mut operations: std.Vector[structs.MirStructOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        program = mir.mir_program_with_struct_operation_reference(
            program,
            mir.mir_make_struct_operation_reference(operations[operation_index], ctx),
            ctx
        );
        operation_index = operation_index + 1;
    }
    if mir.mir_program_struct_references_are_valid(program, table, layout_table, ctx) == 0 {
        fail("Struct smoke: canonical MIR references drifted");
    }
}

func verify_negatives(table: structs.MirStructTable[ctx], ctx: &Arena) {
    mut classes: std.Vector[str, ctx] := std.VectorNew(ctx);
    classes.Push(std.Clone(ctx, "duplicate_field"));
    classes.Push(std.Clone(ctx, "misaligned_field"));
    classes.Push(std.Clone(ctx, "overlapping_fields"));
    classes.Push(std.Clone(ctx, "wrong_field_type"));
    classes.Push(std.Clone(ctx, "size_alignment_mismatch"));
    classes.Push(std.Clone(ctx, "unknown_field_path"));
    mut layouts: std.Vector[structs.MirStructLayout[ctx], ctx] := ctx[table.layouts];
    mut header_layout_id := layouts[1].layout_id;
    mut class_index := 0;
    while class_index < len(classes) {
        mut result := structs.mir_struct_rejection(classes[class_index], ctx);
        if result.success != 0 {
            fail("Struct smoke: invalid aggregate escaped compiler rejection");
        }
        mut diagnostic := diagnostics.mir_struct_diagnostic_for_rejection(
            table,
            classes[class_index],
            "compiler/phase14_struct_source.gst",
            1,
            1,
            header_layout_id,
            "value",
            ctx
        );
        // A stable diagnostic always names the compiler-owned field and the
        // compiler-owned layout decision.
        if std.str_find(diagnostic, "taxonomy=gust.struct.diagnostic.v1") == 0 - 1 ||
           std.str_find(diagnostic, result.reason_code) == 0 - 1 ||
           std.str_find(diagnostic, "field=value") == 0 - 1 ||
           std.str_find(diagnostic, "field_offset=4") == 0 - 1 ||
           std.str_find(diagnostic, "alignment=") == 0 - 1
        {
            fail("Struct smoke: stable diagnostic drifted");
        }
        class_index = class_index + 1;
    }
}

func write_target_artifacts(target_triple: str, object_format: str, layout_table: layout.MirLayoutTable[ctx], conversion_table: conversion.MirIntegerConversionTable[ctx], pointer_table: pointer.MirPointerTable[ctx], stack_slot_table: stack_slot.MirStackSlotTable[ctx], memory_table: memory_access.MirMemoryAccessTable[ctx], string_table: string_view.MirStringViewTable[ctx], array_table: array_slice.MirArraySliceTable[ctx], table: structs.MirStructTable[ctx], ctx: &Arena) {
    mut root := std.Concat("build/guards/phase14_struct/", target_triple);
    mut expected_path := std.Concat(root, "/expected.witness");
    mut c_path := std.Concat(root, "/mir-to-c-struct.c");
    mut request_path := std.Concat(root, "/struct.request");
    mut expected := structs.mir_struct_witness(table, layout_table, ctx);
    mut c_source := struct_c.mir_struct_c_source(table, layout_table, ctx);
    if len(expected) == 0 || len(c_source) == 0 ||
       os.WriteFile(expected_path, expected) == 0 ||
       os.WriteFile(c_path, c_source) == 0
    {
        fail("Struct smoke: could not write backend witnesses");
    }

    mut output_path := std.Concat("/tmp/gust-phase14-struct-", target_triple);
    mut backend_request := request.mir_native_backend_make_request_with_enum_table(
        target_triple,
        object_format,
        output_path,
        std.Concat(output_path, ".bundle"),
        make_bundle(ctx),
        layout_table,
        conversion_table,
        pointer_table,
        stack_slot_table,
        memory_table,
        string_table,
        array_table,
        table,
        enums.mir_enum_make_empty_table(target_triple, ctx),
        ctx
    );
    mut serialized := request.mir_serialize_native_backend_request(backend_request, ctx);
    if std.str_find(serialized, "struct_table_format: gust.compiler_struct_layout_table.v1\n") == 0 - 1 ||
       std.str_find(serialized, "struct_layout_count: 5\n") == 0 - 1 ||
       std.str_find(serialized, "struct_value_count: 6\n") == 0 - 1 ||
       std.str_find(serialized, "struct_operation_count: 17\n") == 0 - 1
    {
        fail("Struct smoke: request serialization lost struct identity");
    }
    if os.WriteFile(request_path, serialized) == 0 {
        fail("Struct smoke: could not write compiler request");
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
        mut primitive_layout_table := primitive.mir_primitive_layout_table_for_target(target_triple, ctx);
        mut layout_table := memory_access.mir_memory_access_layout_table(primitive_layout_table, ctx);
        layout_table = array_slice.mir_array_slice_layout_table(layout_table, ctx);
        mut conversion_table := conversion.mir_integer_conversion_table_for_layout(layout_table, ctx);
        mut pointer_table := pointer.mir_pointer_table_for_layout(layout_table, ctx);
        mut stack_slot_table := stack_slot.mir_stack_slot_table_for_layout(layout_table, ctx);
        mut memory_table := memory_access.mir_memory_access_table_for_memory_tables(
            layout_table,
            pointer_table,
            stack_slot_table,
            ctx
        );
        mut string_table := string_view.mir_string_view_table_for_layout(layout_table, ctx);
        mut array_table := array_slice.mir_array_slice_table_for_layout(layout_table, ctx);
        mut table := structs.mir_struct_table_for_layout(layout_table, ctx);
        if target.found == 0 || structs.mir_struct_table_is_valid(table, layout_table, ctx) == 0 {
            fail("Struct smoke: declared target table rejected");
        }
        verify_canonical_mir(table, layout_table, ctx);
        verify_negatives(table, ctx);
        write_target_artifacts(
            target_triple,
            target.object_format,
            layout_table,
            conversion_table,
            pointer_table,
            stack_slot_table,
            memory_table,
            string_table,
            array_table,
            table,
            ctx
        );
        target_index = target_index + 1;
    }

    os.LogStr("SUCCESS: Phase 14 declaration-order struct layout");
}
