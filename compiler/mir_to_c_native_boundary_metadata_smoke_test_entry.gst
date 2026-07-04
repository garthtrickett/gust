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

    mut program := mir.mir_lower_native_boundary_metadata_fixture(ctx);
    mut c_source := mir.mir_to_c_tiny_fixture(program, ctx);

    expect_str_eq(c_source, "void tiny_native_boundary_metadata_function(void) { return; }", "MIR-to-C native-boundary metadata smoke: metadata perturbed C source");

    if len(ctx[program.functions]) != 1 {
        fail("MIR-to-C native-boundary metadata smoke: source MIR fixture should contain one function");
    }
    if len(ctx[program.resource_metadata]) != 0 {
        fail("MIR-to-C native-boundary metadata smoke: resource metadata side table should stay empty");
    }
    if len(ctx[program.provenance_metadata]) != 0 {
        fail("MIR-to-C native-boundary metadata smoke: provenance metadata side table should stay empty");
    }
    if len(ctx[program.native_boundary_metadata]) != 1 {
        fail("MIR-to-C native-boundary metadata smoke: native-boundary metadata side table should contain one record");
    }

    mut functions_native_boundary: std.Vector[mir.MirFunction[ctx], ctx] := ctx[program.functions];
    mut function := functions_native_boundary[0];
    expect_str_eq(function.name, "tiny_native_boundary_metadata_function", "MIR-to-C native-boundary metadata smoke: source function name drifted");
    expect_str_eq(function.return_type, "void", "MIR-to-C native-boundary metadata smoke: source return type drifted");

    mut metadata_records: std.Vector[mir.MirNativeBoundaryMetadata[ctx], ctx] := ctx[program.native_boundary_metadata];
    mut metadata := metadata_records[0];
    expect_str_eq(metadata.function_name, "tiny_native_boundary_metadata_function", "MIR-to-C native-boundary metadata smoke: function_name drifted");
    expect_str_eq(mir.mir_debug_native_boundary_kind(metadata.boundary_kind), "MirNativeBoundaryKind.RuntimeCall", "MIR-to-C native-boundary metadata smoke: boundary kind drifted");

    os.LogStr(c_source);
    os.LogStr("SUCCESS: mir to c native boundary metadata smoke");
}