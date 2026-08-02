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
import "mir_enum.gst" as enums;
import "mir_enum_mir_to_c.gst" as enum_c;
import "mir_enum_diagnostics.gst" as diagnostics;
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
    canonical_record = std.Concat(canonical_record, "block_0_terminator_value: 61\n");
    canonical_record = std.Concat(canonical_record, "metadata_count: 0\n");
    canonical_record = std.Concat(canonical_record, "expected_exit: 61\n");
    mut module := mir.mir_make_program_bundle_module(
        "phase14_enum_source.gst",
        "",
        "phase14_enum.o",
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

func verify_canonical_mir(table: enums.MirEnumTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) {
    mut program := mir.mir_make_program(ctx);
    mut layouts: std.Vector[enums.MirEnumLayout[ctx], ctx] := ctx[table.layouts];
    mut layout_index := 0;
    while layout_index < len(layouts) {
        program = mir.mir_program_with_enum_layout_reference(
            program,
            mir.mir_make_enum_layout_reference(layouts[layout_index], ctx),
            ctx
        );
        layout_index = layout_index + 1;
    }
    mut values: std.Vector[enums.MirEnumValue[ctx], ctx] := ctx[table.values];
    mut value_index := 0;
    while value_index < len(values) {
        program = mir.mir_program_with_enum_value_reference(
            program,
            mir.mir_make_enum_value_reference(values[value_index], ctx),
            ctx
        );
        value_index = value_index + 1;
    }
    mut operations: std.Vector[enums.MirEnumOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        program = mir.mir_program_with_enum_operation_reference(
            program,
            mir.mir_make_enum_operation_reference(operations[operation_index], ctx),
            ctx
        );
        operation_index = operation_index + 1;
    }
    if mir.mir_program_enum_references_are_valid(program, table, layout_table, ctx) == 0 {
        fail("Enum smoke: canonical MIR references drifted");
    }
}

func verify_negatives(table: enums.MirEnumTable[ctx], ctx: &Arena) {
    mut classes: std.Vector[str, ctx] := std.VectorNew(ctx);
    classes.Push(std.Clone(ctx, "duplicate_discriminant"));
    classes.Push(std.Clone(ctx, "discriminant_out_of_range"));
    classes.Push(std.Clone(ctx, "invalid_tag_value"));
    classes.Push(std.Clone(ctx, "wrong_payload_type"));
    classes.Push(std.Clone(ctx, "invalid_payload_projection"));
    classes.Push(std.Clone(ctx, "inconsistent_variant_layout"));
    mut layouts: std.Vector[enums.MirEnumLayout[ctx], ctx] := ctx[table.layouts];
    mut maybe_layout_id := layouts[2].layout_id;
    mut class_index := 0;
    while class_index < len(classes) {
        mut result := enums.mir_enum_rejection(classes[class_index], ctx);
        if result.success != 0 {
            fail("Enum smoke: invalid enum escaped compiler rejection");
        }
        mut diagnostic := diagnostics.mir_enum_diagnostic_for_rejection(
            table,
            classes[class_index],
            "compiler/phase14_enum_source.gst",
            1,
            1,
            maybe_layout_id,
            "Some",
            ctx
        );
        // A stable diagnostic always names the compiler-owned variant and the
        // compiler-owned layout decision.
        if std.str_find(diagnostic, "taxonomy=gust.enum.diagnostic.v1") == 0 - 1 ||
           std.str_find(diagnostic, result.reason_code) == 0 - 1 ||
           std.str_find(diagnostic, "variant=Some") == 0 - 1 ||
           std.str_find(diagnostic, "tag_width=") == 0 - 1 ||
           std.str_find(diagnostic, "payload_offset=") == 0 - 1
        {
            fail("Enum smoke: stable diagnostic drifted");
        }
        class_index = class_index + 1;
    }
}

func write_target_artifacts(target_triple: str, object_format: str, layout_table: layout.MirLayoutTable[ctx], conversion_table: conversion.MirIntegerConversionTable[ctx], pointer_table: pointer.MirPointerTable[ctx], stack_slot_table: stack_slot.MirStackSlotTable[ctx], memory_table: memory_access.MirMemoryAccessTable[ctx], string_table: string_view.MirStringViewTable[ctx], array_table: array_slice.MirArraySliceTable[ctx], table: enums.MirEnumTable[ctx], ctx: &Arena) {
    mut root := std.Concat("build/guards/phase14_enum/", target_triple);
    mut expected_path := std.Concat(root, "/expected.witness");
    mut c_path := std.Concat(root, "/mir-to-c-enum.c");
    mut request_path := std.Concat(root, "/enum.request");
    mut expected := enums.mir_enum_witness(table, layout_table, ctx);
    mut c_source := enum_c.mir_enum_c_source(table, layout_table, ctx);
    if len(expected) == 0 || len(c_source) == 0 ||
       os.WriteFile(expected_path, expected) == 0 ||
       os.WriteFile(c_path, c_source) == 0
    {
        fail("Enum smoke: could not write backend witnesses");
    }

    mut output_path := std.Concat("/tmp/gust-phase14-enum-", target_triple);
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
        structs.mir_struct_make_empty_table(target_triple, ctx),
        table,
        ctx
    );
    mut serialized := request.mir_serialize_native_backend_request(backend_request, ctx);
    if std.str_find(serialized, "enum_table_format: gust.compiler_enum_table.v1\n") == 0 - 1 ||
       std.str_find(serialized, "enum_layout_count: 5\n") == 0 - 1 ||
       std.str_find(serialized, "enum_value_count: 11\n") == 0 - 1 ||
       std.str_find(serialized, "enum_operation_count: 20\n") == 0 - 1
    {
        fail("Enum smoke: request serialization lost enum identity");
    }
    if os.WriteFile(request_path, serialized) == 0 {
        fail("Enum smoke: could not write compiler request");
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
        mut table := enums.mir_enum_table_for_layout(layout_table, ctx);
        if target.found == 0 || enums.mir_enum_table_is_valid(table, layout_table, ctx) == 0 {
            fail("Enum smoke: declared target table rejected");
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

    os.LogStr("SUCCESS: Phase 14 enums and tagged unions");
}
