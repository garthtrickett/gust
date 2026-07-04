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

    mut program := mir.mir_lower_resource_metadata_fixture(ctx);
    mut c_source := mir.mir_to_c_tiny_fixture(program, ctx);

    expect_str_eq(c_source, "int tiny_resource_metadata_local(void) { int value = 2; return value; }", "MIR-to-C resource metadata smoke: metadata perturbed C source");

    if len(ctx[program.functions]) != 1 {
        fail("MIR-to-C resource metadata smoke: source MIR fixture should contain one function");
    }
    if len(ctx[program.resource_metadata]) != 1 {
        fail("MIR-to-C resource metadata smoke: resource metadata side table should contain one record");
    }
    if len(ctx[program.provenance_metadata]) != 0 {
        fail("MIR-to-C resource metadata smoke: provenance metadata side table should stay empty");
    }
    if len(ctx[program.native_boundary_metadata]) != 0 {
        fail("MIR-to-C resource metadata smoke: native-boundary metadata side table should stay empty");
    }

    mut functions_resource: std.Vector[mir.MirFunction[ctx], ctx] := ctx[program.functions];
    mut function := functions_resource[0];
    expect_str_eq(function.name, "tiny_resource_metadata_local", "MIR-to-C resource metadata smoke: source function name drifted");
    expect_str_eq(function.return_type, "int", "MIR-to-C resource metadata smoke: source return type drifted");

    mut metadata_records: std.Vector[mir.MirResourceMetadata[ctx], ctx] := ctx[program.resource_metadata];
    mut metadata := metadata_records[0];
    if metadata.local_id != 0 {
        fail("MIR-to-C resource metadata smoke: metadata local_id drifted");
    }
    expect_str_eq(mir.mir_debug_resource_kind(metadata.resource_kind), "MirResourceKind.LinearResource", "MIR-to-C resource metadata smoke: resource kind drifted");
    expect_str_eq(mir.mir_debug_resource_state(metadata.resource_state), "MirResourceState.Owned", "MIR-to-C resource metadata smoke: resource state drifted");

    os.LogStr(c_source);
    os.LogStr("SUCCESS: mir to c resource metadata smoke");
}