import "mir.gst" as mir;
import "mir_layout.gst" as layout;
import "mir_layout_mir_to_c.gst" as mir_to_c_layout;
import "mir_layout_runtime_descriptor.gst" as runtime_layout;
import "mir_layout_diagnostics.gst" as layout_diagnostics;
import "mir_native_backend_request.gst" as request;

func fail(msg: str) {
    os.LogStr(msg);
    os.Exit(1);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut target := layout.mir_layout_make_target(
        "target:test:x86_64",
        "x86_64-unknown-linux-gnu",
        8,
        8,
        1,
        ctx
    );
    mut table := layout.mir_layout_make_table(target, ctx);

    mut i32_layout := layout.mir_layout_make_type_layout(
        "type:gust:i32",
        target.target_id,
        "scalar_integer",
        4,
        4,
        4,
        ctx
    );
    table = layout.mir_layout_table_with_layout(table, i32_layout, ctx);

    mut pair_layout := layout.mir_layout_make_type_layout(
        "type:test:Pair",
        target.target_id,
        "struct",
        8,
        4,
        0,
        ctx
    );
    pair_layout = layout.mir_layout_type_with_field(
        pair_layout,
        layout.mir_layout_make_field(
            "field:test:Pair:left",
            "left",
            i32_layout.type_id,
            i32_layout.layout_id,
            0,
            4,
            4,
            ctx
        ),
        ctx
    );
    pair_layout = layout.mir_layout_type_with_field(
        pair_layout,
        layout.mir_layout_make_field(
            "field:test:Pair:right",
            "right",
            i32_layout.type_id,
            i32_layout.layout_id,
            4,
            4,
            4,
            ctx
        ),
        ctx
    );
    table = layout.mir_layout_table_with_layout(table, pair_layout, ctx);

    mut enum_layout := layout.mir_layout_make_type_layout(
        "type:test:MaybePair",
        target.target_id,
        "tagged_union",
        12,
        4,
        0,
        ctx
    );
    enum_layout = layout.mir_layout_type_with_variant(
        enum_layout,
        layout.mir_layout_make_variant(
            "variant:test:MaybePair:none",
            "none",
            0,
            "",
            0,
            4,
            ctx
        ),
        ctx
    );
    enum_layout = layout.mir_layout_type_with_variant(
        enum_layout,
        layout.mir_layout_make_variant(
            "variant:test:MaybePair:some",
            "some",
            1,
            pair_layout.layout_id,
            0,
            4,
            ctx
        ),
        ctx
    );
    table = layout.mir_layout_table_with_layout(table, enum_layout, ctx);

    mut access := layout.mir_layout_make_memory_access(
        "access:test:i32:load",
        i32_layout.type_id,
        i32_layout.layout_id,
        target.target_id,
        4,
        4,
        0,
        0,
        ctx
    );
    table = layout.mir_layout_table_with_memory_access(table, access, ctx);

    if layout.mir_layout_table_is_valid(table, ctx) == 0 {
        fail("Layout authority smoke: valid table rejected");
    }

    mut i32_query := layout.mir_layout_of(
        table,
        i32_layout.type_id,
        target.target_id,
        ctx
    );
    if i32_query.found == 0 || i32_query.layout.size != 4 {
        fail("Layout authority smoke: layout_of drifted");
    }

    mut field_query := layout.mir_layout_field_layout(
        table,
        pair_layout.type_id,
        "right",
        target.target_id,
        ctx
    );
    if field_query.found == 0 || field_query.field.offset != 4 {
        fail("Layout authority smoke: field_layout drifted");
    }

    mut variant_query := layout.mir_layout_variant_layout(
        table,
        enum_layout.type_id,
        "some",
        target.target_id,
        ctx
    );
    if variant_query.found == 0 || variant_query.variant.payload_offset != 4 {
        fail("Layout authority smoke: variant_layout drifted");
    }

    mut stride_query := layout.mir_layout_element_stride(
        table,
        i32_layout.type_id,
        target.target_id,
        ctx
    );
    if stride_query.found == 0 || stride_query.stride != 4 {
        fail("Layout authority smoke: element_stride drifted");
    }

    mut access_result := layout.mir_layout_validate_memory_access(
        table,
        i32_layout.type_id,
        4,
        4,
        target.target_id,
        ctx
    );
    if access_result.valid == 0 ||
       std.str_eq(access_result.reason_code, "layout_access_valid") == 0
    {
        fail("Layout authority smoke: memory-access validation drifted");
    }

    mut mir_to_c_query := mir_to_c_layout.mir_layout_for_mir_to_c(
        table,
        pair_layout.type_id,
        target.target_id,
        ctx
    );
    if mir_to_c_query.found == 0 || mir_to_c_query.layout.size != 8 {
        fail("Layout authority smoke: MIR-to-C adapter did not consume authority");
    }

    mut descriptor := runtime_layout.mir_layout_runtime_descriptor(
        table,
        pair_layout.type_id,
        target.target_id,
        ctx
    );
    if std.str_find(descriptor, "size=8 alignment=4") == 0 - 1 {
        fail("Layout authority smoke: runtime descriptor drifted");
    }

    mut diagnostic := layout_diagnostics.mir_layout_diagnostic(
        table,
        enum_layout.type_id,
        target.target_id,
        ctx
    );
    if std.str_find(diagnostic, "size=12 alignment=4") == 0 - 1 {
        fail("Layout authority smoke: diagnostic adapter drifted");
    }

    mut program := mir.mir_make_program(ctx);
    program = mir.mir_program_with_type_layout_reference(
        program,
        mir.mir_make_type_layout_reference(
            pair_layout.type_id,
            pair_layout.layout_id,
            ctx
        ),
        ctx
    );
    if mir.mir_program_layout_reference_is_valid(program, table, ctx) == 0 {
        fail("Layout authority smoke: canonical MIR layout reference rejected");
    }

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
        "app.gst",
        "",
        "app.o",
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
    bundle = mir.mir_program_bundle_with_module(bundle, module, ctx);

    mut backend_request := request.mir_native_backend_make_request_with_layout_table(
        target.target_triple,
        "Elf",
        "/tmp/gust-phase14-layout-authority",
        "/tmp/gust-phase14-layout-authority.bundle",
        bundle,
        table,
        ctx
    );
    mut serialized_request := request.mir_serialize_native_backend_request(
        backend_request,
        ctx
    );
    if std.str_find(serialized_request, "layout_count: 3\n") == 0 - 1 ||
       std.str_find(serialized_request, "memory_access_count: 1\n") == 0 - 1
    {
        fail("Layout authority smoke: native request lost compiler layout table");
    }

    mut duplicate_table := layout.mir_layout_table_with_layout(
        table,
        i32_layout,
        ctx
    );
    if layout.mir_layout_table_is_valid(duplicate_table, ctx) == 1 {
        fail("Layout authority smoke: duplicate layout ID must reject");
    }

    mut invalid_struct := layout.mir_layout_make_type_layout(
        "type:test:Invalid",
        target.target_id,
        "struct",
        4,
        4,
        0,
        ctx
    );
    invalid_struct = layout.mir_layout_type_with_field(
        invalid_struct,
        layout.mir_layout_make_field(
            "field:test:Invalid:value",
            "value",
            i32_layout.type_id,
            "layout:unknown",
            4,
            4,
            4,
            ctx
        ),
        ctx
    );
    mut invalid_table := layout.mir_layout_make_table(target, ctx);
    invalid_table = layout.mir_layout_table_with_layout(
        invalid_table,
        invalid_struct,
        ctx
    );
    if layout.mir_layout_table_is_valid(invalid_table, ctx) == 1 {
        fail("Layout authority smoke: unknown layout IDs and invalid offsets must reject");
    }

    os.LogStr("SUCCESS: Phase 14 compiler-owned layout authority smoke");
}