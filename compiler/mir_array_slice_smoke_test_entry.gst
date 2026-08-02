import "mir.gst" as mir;
import "mir_layout.gst" as layout;
import "mir_primitive_layout.gst" as primitive;
import "mir_integer_conversion.gst" as conversion;
import "mir_pointer.gst" as pointer;
import "mir_stack_slot.gst" as stack_slot;
import "mir_memory_access.gst" as memory_access;
import "mir_string_view.gst" as string_view;
import "mir_array_slice.gst" as array_slice;
import "mir_array_slice_mir_to_c.gst" as array_c;
import "mir_array_slice_diagnostics.gst" as diagnostics;
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
    canonical_record = std.Concat(canonical_record, "block_0_terminator_value: 58\n");
    canonical_record = std.Concat(canonical_record, "metadata_count: 0\n");
    canonical_record = std.Concat(canonical_record, "expected_exit: 58\n");
    mut module := mir.mir_make_program_bundle_module(
        "phase14_array_slice_source.gst",
        "",
        "phase14_array_slice.o",
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

func verify_canonical_mir(table: array_slice.MirArraySliceTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) {
    mut program := mir.mir_make_program(ctx);
    mut array_layouts: std.Vector[array_slice.MirArrayLayout[ctx], ctx] := ctx[table.array_layouts];
    mut array_layout_index := 0;
    while array_layout_index < len(array_layouts) {
        program = mir.mir_program_with_array_layout_reference(
            program,
            mir.mir_make_array_layout_reference(array_layouts[array_layout_index], ctx),
            ctx
        );
        array_layout_index = array_layout_index + 1;
    }
    mut arrays: std.Vector[array_slice.MirArrayValue[ctx], ctx] := ctx[table.arrays];
    mut array_index := 0;
    while array_index < len(arrays) {
        program = mir.mir_program_with_array_value_reference(
            program,
            mir.mir_make_array_value_reference(arrays[array_index], ctx),
            ctx
        );
        array_index = array_index + 1;
    }
    mut slices: std.Vector[array_slice.MirSliceValue[ctx], ctx] := ctx[table.slices];
    mut slice_index := 0;
    while slice_index < len(slices) {
        program = mir.mir_program_with_slice_reference(
            program,
            mir.mir_make_slice_reference(slices[slice_index], ctx),
            ctx
        );
        slice_index = slice_index + 1;
    }
    mut operations: std.Vector[array_slice.MirArraySliceOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        program = mir.mir_program_with_array_slice_operation_reference(
            program,
            mir.mir_make_array_slice_operation_reference(operations[operation_index], ctx),
            ctx
        );
        operation_index = operation_index + 1;
    }
    if mir.mir_program_array_slice_references_are_valid(program, table, layout_table, ctx) == 0 {
        fail("Array/slice smoke: canonical MIR references drifted");
    }
}

func verify_negatives(ctx: &Arena) {
    mut classes: std.Vector[str, ctx] := std.VectorNew(ctx);
    classes.Push(std.Clone(ctx, "count_overflow"));
    classes.Push(std.Clone(ctx, "total_size_overflow"));
    classes.Push(std.Clone(ctx, "invalid_stride"));
    classes.Push(std.Clone(ctx, "out_of_bounds_access"));
    classes.Push(std.Clone(ctx, "wrong_element_type"));
    classes.Push(std.Clone(ctx, "invalid_slice_pointer_length_pair"));
    classes.Push(std.Clone(ctx, "lifetime_escape"));
    mut class_index := 0;
    while class_index < len(classes) {
        mut result := array_slice.mir_array_slice_rejection(classes[class_index], ctx);
        if result.success != 0 {
            fail("Array/slice smoke: invalid aggregate escaped compiler rejection");
        }
        mut diagnostic := diagnostics.mir_array_slice_diagnostic_for_rejection(
            classes[class_index],
            "compiler/phase14_array_slice_source.gst",
            1,
            1,
            ctx
        );
        if std.str_find(diagnostic, "taxonomy=gust.array_slice.diagnostic.v1") == 0 - 1 ||
           std.str_find(diagnostic, result.reason_code) == 0 - 1
        {
            fail("Array/slice smoke: stable diagnostic drifted");
        }
        class_index = class_index + 1;
    }
}

func write_target_artifacts(target_triple: str, object_format: str, layout_table: layout.MirLayoutTable[ctx], conversion_table: conversion.MirIntegerConversionTable[ctx], pointer_table: pointer.MirPointerTable[ctx], stack_slot_table: stack_slot.MirStackSlotTable[ctx], memory_table: memory_access.MirMemoryAccessTable[ctx], string_table: string_view.MirStringViewTable[ctx], table: array_slice.MirArraySliceTable[ctx], ctx: &Arena) {
    mut root := std.Concat("build/guards/phase14_array_slice/", target_triple);
    mut expected_path := std.Concat(root, "/expected.witness");
    mut c_path := std.Concat(root, "/mir-to-c-array-slice.c");
    mut request_path := std.Concat(root, "/array-slice.request");
    mut expected := array_slice.mir_array_slice_witness(table, layout_table, ctx);
    mut c_source := array_c.mir_array_slice_c_source(table, layout_table, ctx);
    if len(expected) == 0 || len(c_source) == 0 ||
       os.WriteFile(expected_path, expected) == 0 ||
       os.WriteFile(c_path, c_source) == 0
    {
        fail("Array/slice smoke: could not write backend witnesses");
    }

    mut output_path := std.Concat("/tmp/gust-phase14-array-slice-", target_triple);
    mut backend_request := request.mir_native_backend_make_request_with_array_slice_table(
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
        table,
        ctx
    );
    mut serialized := request.mir_serialize_native_backend_request(backend_request, ctx);
    if std.str_find(serialized, "array_slice_table_format: gust.compiler_array_slice_table.v1\n") == 0 - 1 ||
       std.str_find(serialized, "array_slice_array_layout_count: 4\n") == 0 - 1 ||
       std.str_find(serialized, "array_slice_array_count: 4\n") == 0 - 1 ||
       std.str_find(serialized, "array_slice_slice_layout_count: 2\n") == 0 - 1 ||
       std.str_find(serialized, "array_slice_slice_count: 5\n") == 0 - 1 ||
       std.str_find(serialized, "array_slice_operation_count: 17\n") == 0 - 1
    {
        fail("Array/slice smoke: request serialization lost aggregate identity");
    }
    if os.WriteFile(request_path, serialized) == 0 {
        fail("Array/slice smoke: could not write compiler request");
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
        mut table := array_slice.mir_array_slice_table_for_layout(layout_table, ctx);
        if target.found == 0 || array_slice.mir_array_slice_table_is_valid(table, layout_table, ctx) == 0 {
            fail("Array/slice smoke: declared target table rejected");
        }
        verify_canonical_mir(table, layout_table, ctx);
        verify_negatives(ctx);
        write_target_artifacts(
            target_triple,
            target.object_format,
            layout_table,
            conversion_table,
            pointer_table,
            stack_slot_table,
            memory_table,
            string_table,
            table,
            ctx
        );
        target_index = target_index + 1;
    }

    os.LogStr("SUCCESS: Phase 14 fixed arrays and bounded slices");
}
