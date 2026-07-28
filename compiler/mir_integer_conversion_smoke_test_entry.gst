import "mir.gst" as mir;
import "mir_layout.gst" as layout;
import "mir_primitive_layout.gst" as primitive;
import "mir_integer_conversion.gst" as conversion;
import "mir_integer_conversion_mir_to_c.gst" as conversion_c;
import "mir_integer_conversion_diagnostics.gst" as diagnostics;
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
        "phase14_integer_conversion.gst",
        "",
        "phase14_integer_conversion.o",
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

func verify_canonical_mir(conversion_table: conversion.MirIntegerConversionTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) {
    mut program := mir.mir_make_program(ctx);
    mut rules: std.Vector[conversion.MirIntegerConversionRule[ctx], ctx] := ctx[conversion_table.rules];
    mut index := 0;
    while index < len(rules) {
        program = mir.mir_program_with_integer_conversion_reference(
            program,
            mir.mir_make_integer_conversion_reference(rules[index], ctx),
            ctx
        );
        index = index + 1;
    }
    if mir.mir_program_integer_conversion_references_are_valid(
        program,
        conversion_table,
        layout_table,
        ctx
    ) == 0 {
        fail("Integer conversion smoke: canonical MIR conversion references drifted");
    }

    mut query := conversion.mir_integer_conversion_rule(
        conversion_table,
        "sign_extend_i32_i64",
        ctx
    );
    mut span := mir.mir_make_empty_span();
    mut literal := mir.mir_alloc_value(
        mir.mir_make_value_int_literal(7, "i32", span, ctx),
        ctx
    );
    mut converted := mir.mir_make_value_integer_convert(
        literal,
        mir.mir_make_integer_conversion_reference(query.rule, ctx),
        "i64",
        span,
        ctx
    );
    if std.str_eq(mir.mir_debug_value_kind(converted), "MirValue.IntegerConvert") == 0 {
        fail("Integer conversion smoke: explicit MIR conversion operation drifted");
    }
    unsafe {
        mut converted_reference: mir.MirIntegerConversionReference[ctx] := ctx[converted.IntegerConvert.conversion];
        if std.str_eq(
            mir.mir_debug_integer_conversion_kind(converted_reference.conversion_kind),
            "sign_extend"
        ) == 0
        {
            fail("Integer conversion smoke: explicit MIR conversion operation drifted");
        }
    }
}

func write_target_artifacts(target_triple: str, object_format: str, layout_table: layout.MirLayoutTable[ctx], conversion_table: conversion.MirIntegerConversionTable[ctx], ctx: &Arena) {
    mut root := std.Concat("build/guards/phase14_integer_conversion/", target_triple);
    mut expected_path := std.Concat(root, "/expected.witness");
    mut c_path := std.Concat(root, "/mir-to-c-conversions.c");
    mut request_path := std.Concat(root, "/integer-conversions.request");
    mut expected := conversion.mir_integer_conversion_witness(
        conversion_table,
        layout_table,
        ctx
    );
    mut c_source := conversion_c.mir_integer_conversion_c_source(
        conversion_table,
        layout_table,
        ctx
    );
    if len(expected) == 0 || len(c_source) == 0 ||
       os.WriteFile(expected_path, expected) == 0 ||
       os.WriteFile(c_path, c_source) == 0
    {
        fail("Integer conversion smoke: could not write backend witnesses");
    }

    mut output_path := std.Concat("/tmp/gust-phase14-integer-conversion-", target_triple);
    mut backend_request := request.mir_native_backend_make_request_with_layout_and_conversion_tables(
        target_triple,
        object_format,
        output_path,
        std.Concat(output_path, ".bundle"),
        make_bundle(ctx),
        layout_table,
        conversion_table,
        ctx
    );
    mut serialized := request.mir_serialize_native_backend_request(
        backend_request,
        ctx
    );
    if std.str_find(
        serialized,
        "conversion_table_format: gust.compiler_integer_conversion_table.v1\n"
    ) == 0 - 1 ||
       std.str_find(serialized, "conversion_rule_count: 18\n") == 0 - 1 ||
       std.str_find(serialized, "conversion_sample_count: ") == 0 - 1
    {
        fail("Integer conversion smoke: request serialization lost conversion identity");
    }
    if os.WriteFile(request_path, serialized) == 0 {
        fail("Integer conversion smoke: could not write compiler request");
    }
}

func verify_negatives(conversion_table: conversion.MirIntegerConversionTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) {
    mut implicit := conversion.mir_integer_conversion_select(
        conversion_table,
        "type:gust:i32",
        "type:gust:i64",
        "implicit",
        "",
        layout_table.target.target_id,
        ctx
    );
    if implicit.valid != 0 ||
       std.str_eq(implicit.reason_code, "conversion_unsupported_implicit") == 0
    {
        fail("Integer conversion smoke: unsupported implicit conversion accepted");
    }

    mut narrowing := conversion.mir_integer_conversion_select(
        conversion_table,
        "type:gust:i64",
        "type:gust:i32",
        "truncate",
        "",
        layout_table.target.target_id,
        ctx
    );
    if narrowing.valid != 0 ||
       std.str_eq(narrowing.reason_code, "conversion_narrowing_policy_required") == 0
    {
        fail("Integer conversion smoke: narrowing without policy accepted");
    }

    mut pointer := conversion.mir_integer_conversion_select(
        conversion_table,
        "type:gust:pointer",
        "type:gust:usize",
        "bit_reinterpret",
        "explicit_same_width_bit_reinterpretation",
        layout_table.target.target_id,
        ctx
    );
    if pointer.valid != 0 ||
       std.str_eq(pointer.reason_code, "conversion_pointer_integer_deferred") == 0
    {
        fail("Integer conversion smoke: pointer/integer conversion escaped boundary");
    }

    mut missing_target := conversion.mir_integer_conversion_select(
        conversion_table,
        "type:gust:i32",
        "type:gust:isize",
        "sign_extend",
        "target_width_sign_extension",
        "",
        ctx
    );
    if missing_target.valid != 0 ||
       std.str_eq(missing_target.reason_code, "conversion_target_required") == 0
    {
        fail("Integer conversion smoke: target-dependent conversion lacked target");
    }

    mut bool_query := conversion.mir_integer_conversion_rule(
        conversion_table,
        "i32_to_bool",
        ctx
    );
    mut bad_bool := conversion.mir_integer_conversion_evaluate(
        bool_query.rule,
        2,
        ctx
    );
    if bad_bool.success != 0 ||
       std.str_eq(bad_bool.reason_code, "conversion_invalid_boolean_value") == 0
    {
        fail("Integer conversion smoke: invalid boolean conversion accepted");
    }

    mut diagnostic := diagnostics.mir_integer_conversion_diagnostic(
        bool_query.rule,
        bad_bool.reason_code,
        ctx
    );
    if std.str_find(diagnostic, "source_type=type:gust:i32") == 0 - 1 ||
       std.str_find(diagnostic, "destination_type=type:gust:bool") == 0 - 1 ||
       std.str_find(diagnostic, "conversion_kind=integer_to_bool") == 0 - 1 ||
       std.str_find(diagnostic, "reason_code=conversion_invalid_boolean_value") == 0 - 1
    {
        fail("Integer conversion smoke: diagnostic contract drifted");
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
        if target.found == 0 ||
           conversion.mir_integer_conversion_table_is_valid(
               conversion_table,
               layout_table,
               ctx
           ) == 0
        {
            fail("Integer conversion smoke: declared target conversion table rejected");
        }
        verify_canonical_mir(conversion_table, layout_table, ctx);
        verify_negatives(conversion_table, layout_table, ctx);
        write_target_artifacts(
            target_triple,
            target.object_format,
            layout_table,
            conversion_table,
            ctx
        );
        index = index + 1;
    }

    os.LogStr("SUCCESS: Phase 14 signed unsigned and width conversion rules");
}
