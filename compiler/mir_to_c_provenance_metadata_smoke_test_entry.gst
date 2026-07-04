import "mir.gst" as mir;

func fail(msg: str) {
    os.LogStr(msg);
    os.Exit(1);
}

func expect_str_eq(actual: str, expected: str, label: str) {
    if std.str_eq(actual, expected) == 0 {
        os.LogStr(label);
        os.LogStr("expected:");
        os.LogStr(expected);
        os.LogStr("actual:");
        os.LogStr(actual);
        os.Exit(1);
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut program := mir.mir_lower_provenance_metadata_fixture(ctx);
    mut c_source := mir.mir_to_c_tiny_fixture(program, ctx);

    expect_str_eq(c_source, "int tiny_provenance_metadata_local_read(void) { int value = 2; return value; }", "MIR-to-C provenance metadata smoke: metadata perturbed C source");

    if len(ctx[program.functions]) != 1 {
        fail("MIR-to-C provenance metadata smoke: source MIR fixture should contain one function");
    }
    if len(ctx[program.resource_metadata]) != 0 {
        fail("MIR-to-C provenance metadata smoke: resource metadata side table should stay empty");
    }
    if len(ctx[program.provenance_metadata]) != 1 {
        fail("MIR-to-C provenance metadata smoke: provenance metadata side table should contain one record");
    }
    if len(ctx[program.native_boundary_metadata]) != 0 {
        fail("MIR-to-C provenance metadata smoke: native-boundary metadata side table should stay empty");
    }

    mut functions_provenance: std.Vector[mir.MirFunction[ctx], ctx] := ctx[program.functions];
    mut function := functions_provenance[0];
    expect_str_eq(function.name, "tiny_provenance_metadata_local_read", "MIR-to-C provenance metadata smoke: source function name drifted");
    expect_str_eq(function.return_type, "int", "MIR-to-C provenance metadata smoke: source return type drifted");

    mut metadata_records: std.Vector[mir.MirProvenanceMetadata[ctx], ctx] := ctx[program.provenance_metadata];
    mut metadata := metadata_records[0];
    expect_str_eq(mir.mir_debug_provenance_kind(metadata.provenance_kind), "MirProvenanceKind.LocalBinding", "MIR-to-C provenance metadata smoke: provenance kind drifted");
    expect_str_eq(metadata.origin_name, "value", "MIR-to-C provenance metadata smoke: origin_name drifted");

    os.LogStr(c_source);
    os.LogStr("SUCCESS: mir to c provenance metadata smoke");
}