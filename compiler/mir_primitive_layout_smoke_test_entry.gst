import "mir.gst" as mir;
import "mir_layout.gst" as layout;
import "mir_layout_mir_to_c.gst" as layout_c;
import "mir_primitive_layout.gst" as primitive;
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
        "phase14_primitive_layout.gst",
        "",
        "phase14_primitive_layout.o",
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

func verify_scalar_reference_program(table: layout.MirLayoutTable[ctx], ctx: &Arena) {
    mut program := mir.mir_make_program(ctx);
    mut layouts: std.Vector[layout.MirTypeLayout[ctx], ctx] := ctx[table.layouts];
    mut index := 0;
    while index < len(layouts) {
        mut item := layouts[index];
        program = mir.mir_program_with_type_layout_reference(
            program,
            mir.mir_make_type_layout_reference(
                item.type_id,
                item.layout_id,
                ctx
            ),
            ctx
        );
        program = mir.mir_program_with_primitive_scalar_reference(
            program,
            mir.mir_make_primitive_scalar_reference(
                item.type_id,
                item.layout_id,
                item.target_id,
                item.bit_width,
                item.signedness,
                ctx
            ),
            ctx
        );
        index = index + 1;
    }
    if mir.mir_program_layout_reference_is_valid(program, table, ctx) == 0 ||
       mir.mir_program_primitive_scalar_references_are_valid(program, table, ctx) == 0
    {
        fail("Primitive layout smoke: canonical MIR scalar identities drifted");
    }
}

func write_target_artifacts(target_triple: str, table: layout.MirLayoutTable[ctx], object_format: str, ctx: &Arena) {
    mut safe_target := target_triple;
    mut root := std.Concat("build/guards/phase14_primitive_layout/", safe_target);
    mut expected_path := std.Concat(root, "/expected.witness");
    mut c_path := std.Concat(root, "/mir-to-c-witness.c");
    mut request_path := std.Concat(root, "/primitive-layout.request");

    mut witness := primitive.mir_primitive_layout_witness(table, ctx);
    mut c_source := layout_c.mir_layout_primitive_witness_c_source(table, ctx);
    if len(witness) == 0 || len(c_source) == 0 {
        fail("Primitive layout smoke: witness generation failed");
    }
    if os.WriteFile(expected_path, witness) == 0 ||
       os.WriteFile(c_path, c_source) == 0
    {
        fail("Primitive layout smoke: could not write witness artifacts");
    }

    mut bundle := make_bundle(ctx);
    mut output_path := std.Concat("/tmp/gust-phase14-primitive-layout-", target_triple);
    mut bundle_path := std.Concat(output_path, ".bundle");
    mut backend_request := request.mir_native_backend_make_request_with_layout_table(
        target_triple,
        object_format,
        output_path,
        bundle_path,
        bundle,
        table,
        ctx
    );
    mut serialized := request.mir_serialize_native_backend_request(
        backend_request,
        ctx
    );
    if std.str_find(serialized, "layout_table_format: gust.compiler_layout_table.v2\n") == 0 - 1 ||
       std.str_find(serialized, "layout_count: 7\n") == 0 - 1
    {
        fail("Primitive layout smoke: request serialization lost primitive layouts");
    }
    if os.WriteFile(request_path, serialized) == 0 {
        fail("Primitive layout smoke: could not write compiler request");
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    if len(primitive.mir_primitive_layout_normalize_target_triple(
        "unknown-unknown-none",
        ctx
    )) != 0
    {
        fail("Primitive layout smoke: unknown target normalized");
    }
    mut unknown := primitive.mir_primitive_layout_target(
        "unknown-unknown-none",
        ctx
    );
    if unknown.found != 0 {
        fail("Primitive layout smoke: unsupported target was declared");
    }

    mut unknown_request := request.mir_native_backend_make_request(
        "unknown-unknown-none",
        "Elf",
        "/tmp/gust-phase14-unknown-target",
        "/tmp/gust-phase14-unknown-target.bundle",
        make_bundle(ctx),
        ctx
    );
    if request.mir_native_backend_request_is_valid(unknown_request, ctx) != 0 {
        fail("Primitive layout smoke: unknown target request was accepted");
    }

    mut target_triples: std.Vector[str, ctx] := ctx[
        primitive.mir_primitive_layout_declared_target_triples(ctx)
    ];
    mut target_index := 0;
    while target_index < len(target_triples) {
        mut target_triple := target_triples[target_index];
        mut target_query := primitive.mir_primitive_layout_target(
            target_triple,
            ctx
        );
        if target_query.found == 0 ||
           std.str_eq(target_query.target.target_triple, target_triple) == 0
        {
            fail("Primitive layout smoke: declared target lookup failed");
        }
        mut table := primitive.mir_primitive_layout_table_for_target(
            target_triple,
            ctx
        );
        if layout.mir_layout_table_is_valid(table, ctx) == 0 ||
           std.str_eq(table.format, "gust.compiler_layout_table.v2") == 0
        {
            fail("Primitive layout smoke: declared primitive table rejected");
        }
        mut layouts: std.Vector[layout.MirTypeLayout[ctx], ctx] := ctx[table.layouts];
        if len(layouts) != 7 {
            fail("Primitive layout smoke: primitive inventory drifted");
        }
        mut bool_query := layout.mir_layout_of(
            table,
            "type:gust:bool",
            table.target.target_id,
            ctx
        );
        mut i32_query := layout.mir_layout_of(
            table,
            "type:gust:i32",
            table.target.target_id,
            ctx
        );
        mut i64_query := layout.mir_layout_of(
            table,
            "type:gust:i64",
            table.target.target_id,
            ctx
        );
        mut isize_query := layout.mir_layout_of(
            table,
            "type:gust:isize",
            table.target.target_id,
            ctx
        );
        if bool_query.found == 0 || bool_query.layout.size != 1 ||
           i32_query.found == 0 || i32_query.layout.size != 4 ||
           i64_query.found == 0 || i64_query.layout.size != 8 ||
           isize_query.found == 0 ||
           isize_query.layout.size != table.target.pointer_size
        {
            fail("Primitive layout smoke: target-aware primitive sizes drifted");
        }
        mut bool_zero := layout.mir_layout_validate_scalar_value(
            table,
            "type:gust:bool",
            0,
            table.target.target_id,
            ctx
        );
        mut bool_one := layout.mir_layout_validate_scalar_value(
            table,
            "type:gust:bool",
            1,
            table.target.target_id,
            ctx
        );
        mut bool_two := layout.mir_layout_validate_scalar_value(
            table,
            "type:gust:bool",
            2,
            table.target.target_id,
            ctx
        );
        if bool_zero.valid == 0 || bool_one.valid == 0 || bool_two.valid != 0 ||
           std.str_eq(bool_two.reason_code, "invalid_boolean_memory_value") == 0
        {
            fail("Primitive layout smoke: canonical boolean validity drifted");
        }
        verify_scalar_reference_program(table, ctx);
        write_target_artifacts(
            target_triple,
            table,
            target_query.object_format,
            ctx
        );
        target_index = target_index + 1;
    }

    mut primary := primitive.mir_primitive_layout_target(
        primitive.mir_primitive_layout_primary_level2_target(ctx),
        ctx
    );
    mut bad_alignment_table := layout.mir_layout_make_table(primary.target, ctx);
    bad_alignment_table = layout.mir_layout_table_with_layout(
        bad_alignment_table,
        layout.mir_layout_make_scalar_type_layout(
            "type:gust:i32",
            primary.target.target_id,
            "scalar_integer",
            4,
            3,
            32,
            "signed",
            "any_bit_pattern",
            ctx
        ),
        ctx
    );
    if layout.mir_layout_table_is_valid(bad_alignment_table, ctx) != 0 {
        fail("Primitive layout smoke: invalid scalar alignment was accepted");
    }

    mut primary_table := primitive.mir_primitive_layout_table_for_target(
        primary.target.target_triple,
        ctx
    );
    mut wrong_request := request.mir_native_backend_make_request_with_layout_table(
        "aarch64-unknown-linux-gnu",
        "Elf",
        "/tmp/gust-phase14-primitive-layout-mismatch",
        "/tmp/gust-phase14-primitive-layout-mismatch.bundle",
        make_bundle(ctx),
        primary_table,
        ctx
    );
    if request.mir_native_backend_request_is_valid(wrong_request, ctx) != 0 {
        fail("Primitive layout smoke: request target/layout disagreement was accepted");
    }

    os.LogStr("SUCCESS: Phase 14 declared targets and primitive scalar layouts");
}