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
import "mir_aggregate_transport.gst" as aggregate;
import "mir_aggregate_transport_mir_to_c.gst" as aggregate_c;
import "mir_aggregate_transport_diagnostics.gst" as diagnostics;
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
    canonical_record = std.Concat(canonical_record, "block_0_terminator_value: 65\n");
    canonical_record = std.Concat(canonical_record, "metadata_count: 0\n");
    canonical_record = std.Concat(canonical_record, "expected_exit: 65\n");
    mut module := mir.mir_make_program_bundle_module(
        "phase14_aggregate_transport_source.gst",
        "",
        "phase14_aggregate_transport.o",
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

func verify_canonical_mir(table: aggregate.MirAggregateTransportTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) {
    mut program := mir.mir_make_program(ctx);
    mut values: std.Vector[aggregate.MirAggregateValue[ctx], ctx] := ctx[table.values];
    mut value_index := 0;
    while value_index < len(values) {
        program = mir.mir_program_with_aggregate_value_reference(
            program,
            mir.mir_make_aggregate_value_reference(values[value_index], ctx),
            ctx
        );
        value_index = value_index + 1;
    }
    mut blocks: std.Vector[aggregate.MirAggregateBlock[ctx], ctx] := ctx[table.blocks];
    mut block_index := 0;
    while block_index < len(blocks) {
        program = mir.mir_program_with_aggregate_block_reference(
            program,
            mir.mir_make_aggregate_block_reference(blocks[block_index], ctx),
            ctx
        );
        block_index = block_index + 1;
    }
    mut operations: std.Vector[aggregate.MirAggregateOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        program = mir.mir_program_with_aggregate_transport_operation_reference(
            program,
            mir.mir_make_aggregate_transport_operation_reference(operations[operation_index], ctx),
            ctx
        );
        operation_index = operation_index + 1;
    }
    if mir.mir_program_aggregate_references_are_valid(program, table, layout_table, ctx) == 0 {
        fail("Aggregate smoke: canonical MIR references drifted");
    }
}

func verify_negatives(table: aggregate.MirAggregateTransportTable[ctx], ctx: &Arena) {
    mut classes: std.Vector[str, ctx] := std.VectorNew(ctx);
    classes.Push(std.Clone(ctx, "join_layout_mismatch"));
    classes.Push(std.Clone(ctx, "field_count_mismatch"));
    classes.Push(std.Clone(ctx, "variant_mismatch"));
    classes.Push(std.Clone(ctx, "invalid_lifetime"));
    classes.Push(std.Clone(ctx, "use_after_move"));
    classes.Push(std.Clone(ctx, "resource_bearing_copy"));
    mut class_index := 0;
    while class_index < len(classes) {
        mut result := aggregate.mir_aggregate_rejection(classes[class_index], ctx);
        if result.success != 0 {
            fail("Aggregate smoke: invalid transport escaped compiler rejection");
        }
        mut diagnostic := diagnostics.mir_aggregate_diagnostic_for_rejection(
            table,
            classes[class_index],
            "compiler/phase14_aggregate_transport_source.gst",
            1,
            1,
            "agg_array",
            "loop_header",
            ctx
        );
        // A stable diagnostic always names the compiler-owned transport plan.
        if std.str_find(diagnostic, "taxonomy=gust.aggregate_transport.diagnostic.v1") == 0 - 1 ||
           std.str_find(diagnostic, result.reason_code) == 0 - 1 ||
           std.str_find(diagnostic, "value=agg_array") == 0 - 1 ||
           std.str_find(diagnostic, "transport=layout_backed_stack_copy") == 0 - 1 ||
           std.str_find(diagnostic, "arity=1") == 0 - 1 ||
           std.str_find(diagnostic, "block_arguments=3") == 0 - 1
        {
            fail("Aggregate smoke: stable diagnostic drifted");
        }
        class_index = class_index + 1;
    }
}

func write_target_artifacts(target_triple: str, object_format: str, layout_table: layout.MirLayoutTable[ctx], conversion_table: conversion.MirIntegerConversionTable[ctx], pointer_table: pointer.MirPointerTable[ctx], stack_slot_table: stack_slot.MirStackSlotTable[ctx], memory_table: memory_access.MirMemoryAccessTable[ctx], string_table: string_view.MirStringViewTable[ctx], array_table: array_slice.MirArraySliceTable[ctx], struct_table: structs.MirStructTable[ctx], enum_table: enums.MirEnumTable[ctx], table: aggregate.MirAggregateTransportTable[ctx], ctx: &Arena) {
    mut root := std.Concat("build/guards/phase14_aggregate_transport/", target_triple);
    mut expected_path := std.Concat(root, "/expected.witness");
    mut c_path := std.Concat(root, "/mir-to-c-aggregate.c");
    mut request_path := std.Concat(root, "/aggregate.request");
    mut expected := aggregate.mir_aggregate_witness(table, layout_table, ctx);
    mut c_source := aggregate_c.mir_aggregate_c_source(table, layout_table, ctx);
    if len(expected) == 0 || len(c_source) == 0 ||
       os.WriteFile(expected_path, expected) == 0 ||
       os.WriteFile(c_path, c_source) == 0
    {
        fail("Aggregate smoke: could not write backend witnesses");
    }

    mut output_path := std.Concat("/tmp/gust-phase14-aggregate-", target_triple);
    mut backend_request := request.mir_native_backend_make_request_with_aggregate_table(
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
        struct_table,
        enum_table,
        table,
        ctx
    );
    mut serialized := request.mir_serialize_native_backend_request(backend_request, ctx);
    if std.str_find(serialized, "aggregate_table_format: gust.compiler_aggregate_transport_table.v1\n") == 0 - 1 ||
       std.str_find(serialized, "aggregate_class_count: 6\n") == 0 - 1 ||
       std.str_find(serialized, "aggregate_value_count: 8\n") == 0 - 1 ||
       std.str_find(serialized, "aggregate_block_count: 8\n") == 0 - 1 ||
       std.str_find(serialized, "aggregate_edge_count: 9\n") == 0 - 1 ||
       std.str_find(serialized, "aggregate_operation_count: 18\n") == 0 - 1
    {
        fail("Aggregate smoke: request serialization lost transport identity");
    }
    if os.WriteFile(request_path, serialized) == 0 {
        fail("Aggregate smoke: could not write compiler request");
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
        mut struct_table := structs.mir_struct_table_for_layout(layout_table, ctx);
        mut enum_table := enums.mir_enum_table_for_layout(layout_table, ctx);
        mut table := aggregate.mir_aggregate_table_for_layout(
            layout_table, string_table, array_table, struct_table, enum_table, ctx
        );
        if target.found == 0 || aggregate.mir_aggregate_table_is_valid(table, layout_table, ctx) == 0 {
            fail("Aggregate smoke: declared target table rejected");
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
            struct_table,
            enum_table,
            table,
            ctx
        );
        target_index = target_index + 1;
    }

    os.LogStr("SUCCESS: Phase 14 aggregate transport across basic blocks");
}
