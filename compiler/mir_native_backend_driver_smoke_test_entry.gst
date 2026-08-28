import "mir_native_backend_capability.gst" as capability;
import "mir_native_backend_driver.gst" as driver;

func fail(msg: str) {
    os.LogStr(msg);
    os.Exit(1);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut explicit_result := driver.mir_native_backend_discover_driver(
        "/opt/gust/bin/gust-native-backend",
        1,
        1,
        "/opt/gust/bin/gust-native-backend-sibling",
        1,
        1,
        ctx
    );
    if explicit_result.classification.tag != 0 {
        fail("Driver smoke: explicit absolute path must win");
    }
    if std.str_eq(
        explicit_result.path,
        "/opt/gust/bin/gust-native-backend"
    ) == 0 {
        fail("Driver smoke: explicit driver path drifted");
    }

    mut explicit_unavailable := driver.mir_native_backend_discover_driver(
        "/missing/gust-native-backend",
        0,
        0,
        "/opt/gust/bin/gust-native-backend-sibling",
        1,
        1,
        ctx
    );
    if explicit_unavailable.classification.tag != 3 {
        fail("Driver smoke: unavailable explicit path must not fall back");
    }

    mut relative_explicit := driver.mir_native_backend_discover_driver(
        "gust-native-backend --flag",
        1,
        1,
        "/opt/gust/bin/gust-native-backend-sibling",
        1,
        1,
        ctx
    );
    if relative_explicit.classification.tag != 2 {
        fail("Driver smoke: explicit driver path must be absolute");
    }

    mut sibling_result := driver.mir_native_backend_discover_driver(
        "",
        0,
        0,
        "/opt/gust/bin/gust-native-backend-sibling",
        1,
        1,
        ctx
    );
    if sibling_result.classification.tag != 1 {
        fail("Driver smoke: sibling driver must be selected when no explicit path exists");
    }

    mut missing_result := driver.mir_native_backend_discover_driver(
        "",
        0,
        0,
        "/opt/gust/bin/gust-native-backend-sibling",
        0,
        0,
        ctx
    );
    if missing_result.classification.tag != 4 {
        fail("Driver smoke: missing sibling driver classification drifted");
    }

    mut handshake_text := "protocol: gust.native_backend.driver.v1\n";
    handshake_text = std.Concat(handshake_text, "driver_name: gust-native-backend-worker\n");
    handshake_text = std.Concat(handshake_text, "driver_version: 0.0.0\n");
    handshake_text = std.Concat(handshake_text, "program_mir_bundle_format: gust.compiler_program_mir_bundle.v1\n");
    handshake_text = std.Concat(handshake_text, "canonical_mir_format: gust.compiler_mir_ingestion.v1\n");
    handshake_text = std.Concat(handshake_text, "canonical_mir_format: gust.compiler_mir_ingestion.v2\n");
    handshake_text = std.Concat(handshake_text, "canonical_mir_format: gust.compiler_executable_mir.v1\n");
    handshake_text = std.Concat(handshake_text, "target_triple: x86_64-unknown-linux-gnu\n");
    handshake_text = std.Concat(handshake_text, "object_format: Elf\n");
    handshake_text = std.Concat(handshake_text, "link_capability: native_executable\n");
    handshake_text = std.Concat(handshake_text, "pipeline_taxonomy: gust.phase9g.pipeline.v1\n");
    handshake_text = std.Concat(handshake_text, "operation: ReturnI32\n");
    handshake_text = std.Concat(handshake_text, "operation: LocalI32Set\n");
    handshake_text = std.Concat(handshake_text, "operation: LocalI32Read\n");
    handshake_text = std.Concat(handshake_text, "operation: AddI32\n");
    handshake_text = std.Concat(handshake_text, "operation: Jump\n");
    handshake_text = std.Concat(handshake_text, "operation: Branch\n");
    handshake_text = std.Concat(handshake_text, "operation: BlockParam\n");
    handshake_text = std.Concat(handshake_text, "operation: LocalCallI32\n");
    handshake_text = std.Concat(handshake_text, "operation: ImportedCallI32\n");
    handshake_text = std.Concat(handshake_text, "type_or_abi: int\n");
    handshake_text = std.Concat(handshake_text, "type_or_abi: bool\n");
    handshake_text = std.Concat(handshake_text, "type_or_abi: ()->int\n");
    handshake_text = std.Concat(handshake_text, "type_or_abi: (int)->int\n");
    handshake_text = std.Concat(handshake_text, "type_or_abi: (int,int)->int\n");
    handshake_text = std.Concat(handshake_text, "runtime_import: tiny_host_add_one_i32\n");
    handshake_text = std.Concat(handshake_text, "runtime_import: tiny_host_add_i32\n");
    handshake_text = std.Concat(handshake_text, "runtime_import: tiny_host_is_positive_i32\n");
    handshake_text = std.Concat(handshake_text, "target_requirement: native_host\n");
    handshake_text = std.Concat(handshake_text, "target_requirement: position_independent_code\n");
    handshake_text = std.Concat(handshake_text, "target_requirement: native_executable_link\n");

    mut handshake := driver.mir_native_backend_parse_driver_handshake(
        handshake_text,
        ctx
    );
    mut handshake_result := driver.mir_native_backend_validate_driver_handshake(
        handshake,
        "x86_64-unknown-linux-gnu",
        "Elf",
        ctx
    );
    if handshake_result.classification.tag != 0 {
        fail("Driver smoke: valid handshake must be compatible");
    }
    if std.str_eq(
        driver.mir_native_backend_driver_handshake_diagnostic(
            handshake_result,
            ctx
        ),
        "Native backend driver handshake [compatible]: compatible"
    ) == 0 {
        fail("Driver smoke: compatible diagnostic drifted");
    }

    mut advertised_capabilities :=
        driver.mir_native_backend_driver_capability_set(handshake, ctx);
    if capability.mir_native_backend_capability_set_is_valid(
        advertised_capabilities,
        ctx
    ) == 0 {
        fail("Driver smoke: advertised capability inventory must feed the compiler validator");
    }

    mut target_mismatch := driver.mir_native_backend_validate_driver_handshake(
        handshake,
        "aarch64-unknown-linux-gnu",
        "Elf",
        ctx
    );
    if target_mismatch.classification.tag != 5 {
        fail("Driver smoke: target mismatch classification drifted");
    }

    mut object_mismatch := driver.mir_native_backend_validate_driver_handshake(
        handshake,
        "x86_64-unknown-linux-gnu",
        "Macho",
        ctx
    );
    if object_mismatch.classification.tag != 6 {
        fail("Driver smoke: object format mismatch classification drifted");
    }

    mut malformed := driver.mir_native_backend_parse_driver_handshake(
        "protocol gust.native_backend.driver.v1\n",
        ctx
    );
    mut malformed_result := driver.mir_native_backend_validate_driver_handshake(
        malformed,
        "x86_64-unknown-linux-gnu",
        "Elf",
        ctx
    );
    if malformed_result.classification.tag != 1 {
        fail("Driver smoke: malformed handshake classification drifted");
    }

    mut bad_protocol_text := "protocol: gust.native_backend.driver.v2\n";
    bad_protocol_text = std.Concat(bad_protocol_text, "driver_name: gust-native-backend-worker\n");
    bad_protocol_text = std.Concat(bad_protocol_text, "driver_version: 0.0.0\n");
    bad_protocol_text = std.Concat(bad_protocol_text, "program_mir_bundle_format: gust.compiler_program_mir_bundle.v1\n");
    bad_protocol_text = std.Concat(bad_protocol_text, "canonical_mir_format: gust.compiler_mir_ingestion.v1\n");
    bad_protocol_text = std.Concat(bad_protocol_text, "canonical_mir_format: gust.compiler_mir_ingestion.v2\n");
    bad_protocol_text = std.Concat(bad_protocol_text, "canonical_mir_format: gust.compiler_executable_mir.v1\n");
    bad_protocol_text = std.Concat(bad_protocol_text, "target_triple: x86_64-unknown-linux-gnu\n");
    bad_protocol_text = std.Concat(bad_protocol_text, "object_format: Elf\n");
    bad_protocol_text = std.Concat(bad_protocol_text, "link_capability: native_executable\n");
    bad_protocol_text = std.Concat(bad_protocol_text, "pipeline_taxonomy: gust.phase9g.pipeline.v1\n");
    bad_protocol_text = std.Concat(bad_protocol_text, "operation: ReturnI32\n");
    bad_protocol_text = std.Concat(bad_protocol_text, "type_or_abi: int\n");
    bad_protocol_text = std.Concat(bad_protocol_text, "runtime_import: tiny_host_add_i32\n");
    bad_protocol_text = std.Concat(bad_protocol_text, "target_requirement: native_host\n");
    mut bad_protocol := driver.mir_native_backend_parse_driver_handshake(
        bad_protocol_text,
        ctx
    );
    mut bad_protocol_result :=
        driver.mir_native_backend_validate_driver_handshake(
            bad_protocol,
            "x86_64-unknown-linux-gnu",
            "Elf",
            ctx
        );
    if bad_protocol_result.classification.tag != 2 {
        fail("Driver smoke: protocol mismatch classification drifted");
    }

    os.LogStr("SUCCESS: MIR native backend driver discovery and handshake smoke");
}
