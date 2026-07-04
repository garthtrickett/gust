import "mir.gst" as mir;

func fail(msg: str) {
    os.LogStr(msg);
    os.Exit(1);
}

func expect_str_eq(actual: str, expected: str, msg: str) {
    if std.str_eq(actual, expected) == 0 {
        fail(msg);
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut program := mir.mir_lower_native_boundary_metadata_fixture(ctx);

    if len(ctx[program.functions]) != 1 {
        fail("MIR lower native-boundary metadata: program should contain exactly one function");
    }
    if len(ctx[program.resource_metadata]) != 0 {
        fail("MIR lower native-boundary metadata: resource metadata side table should stay empty");
    }
    if len(ctx[program.provenance_metadata]) != 0 {
        fail("MIR lower native-boundary metadata: provenance metadata side table should stay empty");
    }
    if len(ctx[program.native_boundary_metadata]) != 1 {
        fail("MIR lower native-boundary metadata: program should contain exactly one native-boundary metadata record");
    }

    mut functions_native_boundary: std.Vector[mir.MirFunction[ctx], ctx] := ctx[program.functions];
    mut function := functions_native_boundary[0];
    expect_str_eq(function.name, "tiny_native_boundary_metadata_function", "MIR lower native-boundary metadata: function name drifted");
    expect_str_eq(function.return_type, "void", "MIR lower native-boundary metadata: return type drifted");

    if len(ctx[function.params]) != 0 {
        fail("MIR lower native-boundary metadata: function should not lower params yet");
    }
    if len(ctx[function.locals]) != 0 {
        fail("MIR lower native-boundary metadata: function should not contain locals");
    }
    if function.entry_block != 0 {
        fail("MIR lower native-boundary metadata: entry block should be zero");
    }
    if len(ctx[function.blocks]) != 1 {
        fail("MIR lower native-boundary metadata: function should contain exactly one block");
    }

    mut blocks_native_boundary: std.Vector[mir.MirBlock[ctx], ctx] := ctx[function.blocks];
    mut entry_block := blocks_native_boundary[0];
    if entry_block.id != 0 {
        fail("MIR lower native-boundary metadata: entry block id should be zero");
    }
    if len(ctx[entry_block.statements]) != 0 {
        fail("MIR lower native-boundary metadata: entry block should contain zero statements");
    }

    mut terminator: mir.MirTerminator[ctx] := ctx[entry_block.terminator];
    expect_str_eq(mir.mir_debug_terminator_kind(terminator), "MirTerminator.ReturnVoid", "MIR lower native-boundary metadata: terminator kind drifted");

    mut metadata_records: std.Vector[mir.MirNativeBoundaryMetadata[ctx], ctx] := ctx[program.native_boundary_metadata];
    mut metadata := metadata_records[0];
    expect_str_eq(metadata.function_name, "tiny_native_boundary_metadata_function", "MIR lower native-boundary metadata: function_name drifted");
    expect_str_eq(mir.mir_debug_native_boundary_kind(metadata.boundary_kind), "MirNativeBoundaryKind.RuntimeCall", "MIR lower native-boundary metadata: boundary kind drifted");

    mir.mir_debug_print_program(program);
    mir.mir_debug_print_function(function);
    mir.mir_debug_print_block(entry_block, ctx);
    mir.mir_debug_print_terminator(terminator);

    os.LogStr("SUCCESS: mir lower native boundary metadata smoke");
}