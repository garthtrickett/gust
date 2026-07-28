import "mir.gst" as mir;
import "mir_layout.gst" as layout;
import "mir_primitive_layout.gst" as primitive;
import "mir_integer_conversion.gst" as conversion;
import "mir_pointer.gst" as pointer;
import "mir_pointer_mir_to_c.gst" as pointer_c;
import "mir_pointer_diagnostics.gst" as diagnostics;
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
        "phase14_pointer_nullability.gst",
        "",
        "phase14_pointer_nullability.o",
        "gust.compiler_mir_ingestion.v1",
        canonical_record,
        0,
        0,
        0,
        ctx
    );
    module = mir.mir_program_bundle_module_with_symbol(
        module,
        mir.mir_make_program_bundle_symbol(
            "main",
            "main",
            "()->int",
            0,
            ctx
        ),
        ctx
    );
    return mir.mir_program_bundle_with_module(bundle, module, ctx);
}

func verify_canonical_mir(pointer_table: pointer.MirPointerTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) {
    mut program := mir.mir_make_program(ctx);
    mut pointer_types: std.Vector[pointer.MirPointerType[ctx], ctx] := ctx[pointer_table.pointer_types];
    mut type_index := 0;
    while type_index < len(pointer_types) {
        program = mir.mir_program_with_pointer_type_reference(
            program,
            mir.mir_make_pointer_type_reference(pointer_types[type_index], ctx),
            ctx
        );
        type_index = type_index + 1;
    }
    mut operations: std.Vector[pointer.MirPointerOperation[ctx], ctx] := ctx[pointer_table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        program = mir.mir_program_with_pointer_operation_reference(
            program,
            mir.mir_make_pointer_operation_reference(operations[operation_index], ctx),
            ctx
        );
        operation_index = operation_index + 1;
    }
    if mir.mir_program_pointer_references_are_valid(
        program,
        pointer_table,
        layout_table,
        ctx
    ) == 0 {
        fail("Pointer smoke: canonical MIR pointer references drifted");
    }

    mut operation_query := pointer.mir_pointer_operation(
        pointer_table,
        "address_of_local_i32",
        ctx
    );
    mut operands := mir.mir_empty_value_vector(ctx);
    mut span := mir.mir_make_empty_span();
    mut pointer_value := mir.mir_make_value_pointer_operation(
        operands,
        mir.mir_make_pointer_operation_reference(operation_query.operation, ctx),
        operation_query.operation.destination_pointer_type_id,
        span,
        ctx
    );
    if std.str_eq(
        mir.mir_debug_value_kind(pointer_value),
        "MirValue.PointerOperation"
    ) == 0
    {
        fail("Pointer smoke: explicit MIR pointer operation drifted");
    }
    unsafe {
        mut reference: mir.MirPointerOperationReference[ctx] := ctx[pointer_value.PointerOperation.operation];
        if std.str_eq(
            mir.mir_debug_pointer_operation_kind(reference.operation_kind),
            "address_of_local"
        ) == 0 ||
           std.str_eq(reference.provenance_id, "pointer-origin:local:0") == 0
        {
            fail("Pointer smoke: operation kind or provenance drifted");
        }
    }
}

func write_target_artifacts(target_triple: str, object_format: str, layout_table: layout.MirLayoutTable[ctx], conversion_table: conversion.MirIntegerConversionTable[ctx], pointer_table: pointer.MirPointerTable[ctx], ctx: &Arena) {
    mut root := std.Concat("build/guards/phase14_pointer/", target_triple);
    mut expected_path := std.Concat(root, "/expected.witness");
    mut c_path := std.Concat(root, "/mir-to-c-pointers.c");
    mut request_path := std.Concat(root, "/pointers.request");
    mut expected := pointer.mir_pointer_witness(
        pointer_table,
        layout_table,
        ctx
    );
    mut c_source := pointer_c.mir_pointer_c_source(
        pointer_table,
        layout_table,
        ctx
    );
    if len(expected) == 0 || len(c_source) == 0 ||
       os.WriteFile(expected_path, expected) == 0 ||
       os.WriteFile(c_path, c_source) == 0
    {
        fail("Pointer smoke: could not write backend witnesses");
    }

    mut output_path := std.Concat("/tmp/gust-phase14-pointer-", target_triple);
    mut backend_request := request.mir_native_backend_make_request_with_all_tables(
        target_triple,
        object_format,
        output_path,
        std.Concat(output_path, ".bundle"),
        make_bundle(ctx),
        layout_table,
        conversion_table,
        pointer_table,
        ctx
    );
    mut serialized := request.mir_serialize_native_backend_request(
        backend_request,
        ctx
    );
    if std.str_find(
        serialized,
        "pointer_table_format: gust.compiler_pointer_table.v1\n"
    ) == 0 - 1 ||
       std.str_find(serialized, "pointer_type_count: 4\n") == 0 - 1 ||
       std.str_find(serialized, "pointer_operation_count: 11\n") == 0 - 1
    {
        fail("Pointer smoke: request serialization lost pointer identity");
    }
    if os.WriteFile(request_path, serialized) == 0 {
        fail("Pointer smoke: could not write compiler request");
    }
}

func verify_negatives(pointer_table: pointer.MirPointerTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) {
    mut unsupported_address_space := pointer.mir_pointer_select_type(
        pointer_table,
        "type:gust:i32",
        "const",
        "nullable",
        "address_space:1",
        layout_table.target.target_id,
        ctx
    );
    if unsupported_address_space.valid != 0 ||
       std.str_eq(
           unsupported_address_space.reason_code,
           "pointer_address_space_unsupported"
       ) == 0
    {
        fail("Pointer smoke: unsupported address space accepted");
    }

    mut unsized := pointer.mir_pointer_select_type(
        pointer_table,
        "type:gust:slice:i32",
        "const",
        "nullable",
        "default",
        layout_table.target.target_id,
        ctx
    );
    if unsized.valid != 0 ||
       std.str_eq(
           unsized.reason_code,
           "pointer_pointee_unsized_or_unsupported"
       ) == 0
    {
        fail("Pointer smoke: unsized pointee accepted");
    }

    mut missing_target := pointer.mir_pointer_select_type(
        pointer_table,
        "type:gust:i32",
        "const",
        "nullable",
        "default",
        "",
        ctx
    );
    if missing_target.valid != 0 ||
       std.str_eq(missing_target.reason_code, "pointer_target_required") == 0
    {
        fail("Pointer smoke: target-dependent pointer lacked target");
    }

    mut arithmetic := pointer.mir_pointer_operation_request_is_supported(
        "pointer_arithmetic",
        ctx
    );
    if arithmetic.success != 0 ||
       std.str_eq(arithmetic.reason_code, "pointer_arithmetic_unsupported") == 0
    {
        fail("Pointer smoke: pointer arithmetic escaped boundary");
    }

    mut integer_cast := pointer.mir_pointer_operation_request_is_supported(
        "pointer_to_integer",
        ctx
    );
    if integer_cast.success != 0 ||
       std.str_eq(
           integer_cast.reason_code,
           "pointer_integer_cast_unsupported"
       ) == 0
    {
        fail("Pointer smoke: unrestricted pointer/integer cast escaped boundary");
    }

    mut dereference := pointer.mir_pointer_operation_request_is_supported(
        "dereference",
        ctx
    );
    if dereference.success != 0 ||
       std.str_eq(
           dereference.reason_code,
           "pointer_load_store_contract_deferred"
       ) == 0
    {
        fail("Pointer smoke: dereference escaped the later load/store contract");
    }

    mut checked := pointer.mir_pointer_operation(
        pointer_table,
        "nullable_to_non_null_checked_null",
        ctx
    );
    mut checked_result := pointer.mir_pointer_evaluate(checked.operation, ctx);
    if checked_result.success != 0 ||
       std.str_eq(
           checked_result.reason_code,
           "pointer_nullability_check_failed"
       ) == 0
    {
        fail("Pointer smoke: known-null checked promotion was not rejected");
    }

    mut pointer_type := pointer.mir_pointer_find_type(
        pointer_table,
        "type:gust:i32",
        "const",
        "nullable",
        ctx
    );
    mut diagnostic := diagnostics.mir_pointer_diagnostic(
        pointer_type.pointer_type,
        "nullable_to_non_null_checked",
        checked_result.reason_code,
        ctx
    );
    if std.str_find(diagnostic, "pointee_type=type:gust:i32") == 0 - 1 ||
       std.str_find(diagnostic, "nullability=nullable") == 0 - 1 ||
       std.str_find(diagnostic, "address_space=default") == 0 - 1 ||
       std.str_find(
           diagnostic,
           "reason_code=pointer_nullability_check_failed"
       ) == 0 - 1
    {
        fail("Pointer smoke: stable pointer diagnostic drifted");
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut targets: std.Vector[str, ctx] := ctx[
        primitive.mir_primitive_layout_declared_target_triples(ctx)
    ];
    mut index := 0;
    while index < len(targets) {
        mut target_triple := targets[index];
        mut target := primitive.mir_primitive_layout_target(target_triple, ctx);
        mut layout_table := primitive.mir_primitive_layout_table_for_target(
            target_triple,
            ctx
        );
        mut conversion_table := conversion.mir_integer_conversion_table_for_layout(
            layout_table,
            ctx
        );
        mut pointer_table := pointer.mir_pointer_table_for_layout(
            layout_table,
            ctx
        );
        if target.found == 0 ||
           pointer.mir_pointer_table_is_valid(
               pointer_table,
               layout_table,
               ctx
           ) == 0
        {
            fail("Pointer smoke: declared target pointer table rejected");
        }
        verify_canonical_mir(pointer_table, layout_table, ctx);
        verify_negatives(pointer_table, layout_table, ctx);
        write_target_artifacts(
            target_triple,
            target.object_format,
            layout_table,
            conversion_table,
            pointer_table,
            ctx
        );
        index = index + 1;
    }

    os.LogStr("SUCCESS: Phase 14 bounded typed pointers and nullability");
}
