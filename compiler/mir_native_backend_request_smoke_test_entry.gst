import "mir.gst" as mir;
import "mir_native_backend_request.gst" as request;

func fail(msg: str) {
    os.LogStr(msg);
    os.Exit(1);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

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
    canonical_record = std.Concat(canonical_record, "block_0_terminator_value: 7\n");
    canonical_record = std.Concat(canonical_record, "metadata_count: 0\n");
    canonical_record = std.Concat(canonical_record, "expected_exit: 7\n");

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

    mut valid_request := request.mir_native_backend_make_request(
        "x86_64-unknown-linux-gnu",
        "Elf",
        "/tmp/gust-phase10-program",
        "/tmp/gust-phase10-program.bundle",
        bundle,
        ctx
    );
    if request.mir_native_backend_request_is_valid(valid_request, ctx) == 0 {
        fail("Backend request smoke: valid request should pass");
    }

    mut serialized_a :=
        request.mir_serialize_native_backend_request(valid_request, ctx);
    mut serialized_b :=
        request.mir_serialize_native_backend_request(valid_request, ctx);
    if std.str_eq(serialized_a, serialized_b) == 0 {
        fail("Backend request smoke: repeated serialization must be byte-identical");
    }
    if std.str_find(
        serialized_a,
        "format: gust.native_backend.request.v1\n"
    ) != 0 {
        fail("Backend request smoke: request format header drifted");
    }
    if std.str_find(
        serialized_a,
        "driver_protocol: gust.native_backend.driver.v1\n"
    ) == 0 - 1 {
        fail("Backend request smoke: driver protocol missing");
    }
    if std.str_find(
        serialized_a,
        "artifact_kind: native_executable\n"
    ) == 0 - 1 {
        fail("Backend request smoke: artifact kind missing");
    }
    if std.str_find(
        serialized_a,
        "output_path: /tmp/gust-phase10-program\n"
    ) == 0 - 1 {
        fail("Backend request smoke: output intent missing");
    }
    if std.str_find(
        serialized_a,
        "program_mir_bundle_path: /tmp/gust-phase10-program.bundle\n"
    ) == 0 - 1 {
        fail("Backend request smoke: bundle path missing");
    }
    if std.str_find(
        serialized_a,
        "layout_table_format: gust.compiler_layout_table.v1\n"
    ) == 0 - 1 {
        fail("Backend request smoke: compiler-owned layout table format missing");
    }
    if std.str_find(
        serialized_a,
        "layout_target_id: phase14-target:unfrozen:x86_64-unknown-linux-gnu\n"
    ) == 0 - 1 {
        fail("Backend request smoke: deterministic unfrozen target identity missing");
    }
    if std.str_find(
        serialized_a,
        "layout_target_decisions_frozen: 0\nlayout_count: 0\nmemory_access_count: 0\n"
    ) == 0 - 1 {
        fail("Backend request smoke: empty Phase 14 layout transport drifted");
    }

    mut relative_output := request.mir_native_backend_make_request(
        "x86_64-unknown-linux-gnu",
        "Elf",
        "program",
        "/tmp/gust-phase10-program.bundle",
        bundle,
        ctx
    );
    if request.mir_native_backend_request_is_valid(relative_output, ctx) == 1 {
        fail("Backend request smoke: relative output paths must reject");
    }

    mut relative_bundle := request.mir_native_backend_make_request(
        "x86_64-unknown-linux-gnu",
        "Elf",
        "/tmp/gust-phase10-program",
        "program.bundle",
        bundle,
        ctx
    );
    if request.mir_native_backend_request_is_valid(relative_bundle, ctx) == 1 {
        fail("Backend request smoke: relative bundle paths must reject");
    }

    mut aliasing_paths := request.mir_native_backend_make_request(
        "x86_64-unknown-linux-gnu",
        "Elf",
        "/tmp/gust-phase10-program",
        "/tmp/gust-phase10-program",
        bundle,
        ctx
    );
    if request.mir_native_backend_request_is_valid(aliasing_paths, ctx) == 1 {
        fail("Backend request smoke: bundle and executable paths must differ");
    }

    if std.str_eq(
        request.mir_serialize_native_backend_request(relative_output, ctx),
        "format: invalid\n"
    ) == 0 {
        fail("Backend request smoke: invalid serialization must be stable");
    }

    os.LogStr("SUCCESS: MIR native backend generic request protocol smoke");
}
