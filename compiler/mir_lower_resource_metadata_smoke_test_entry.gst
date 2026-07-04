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

    mut program := mir.mir_lower_resource_metadata_fixture(ctx);

    if len(ctx[program.functions]) != 1 {
        fail("MIR lower resource metadata: program should contain exactly one function");
    }
    if len(ctx[program.resource_metadata]) != 1 {
        fail("MIR lower resource metadata: program should contain exactly one resource metadata record");
    }
    if len(ctx[program.provenance_metadata]) != 0 {
        fail("MIR lower resource metadata: provenance metadata side table should stay empty");
    }
    if len(ctx[program.native_boundary_metadata]) != 0 {
        fail("MIR lower resource metadata: native-boundary metadata side table should stay empty");
    }

    mut functions_resource: std.Vector[mir.MirFunction[ctx], ctx] := ctx[program.functions];
    mut function := functions_resource[0];
    expect_str_eq(function.name, "tiny_resource_metadata_local", "MIR lower resource metadata: function name drifted");
    expect_str_eq(function.return_type, "int", "MIR lower resource metadata: return type drifted");

    if len(ctx[function.params]) != 0 {
        fail("MIR lower resource metadata: function should not lower params yet");
    }
    if len(ctx[function.locals]) != 1 {
        fail("MIR lower resource metadata: function should contain exactly one local");
    }
    if function.entry_block != 0 {
        fail("MIR lower resource metadata: entry block should be zero");
    }
    if len(ctx[function.blocks]) != 1 {
        fail("MIR lower resource metadata: function should contain exactly one block");
    }

    mut locals_resource: std.Vector[mir.MirLocal[ctx], ctx] := ctx[function.locals];
    mut local := locals_resource[0];
    if local.id != 0 {
        fail("MIR lower resource metadata: local id drifted");
    }
    expect_str_eq(local.name, "value", "MIR lower resource metadata: local name drifted");
    expect_str_eq(local.local_type, "int", "MIR lower resource metadata: local type drifted");

    mut metadata_records: std.Vector[mir.MirResourceMetadata[ctx], ctx] := ctx[program.resource_metadata];
    mut metadata := metadata_records[0];
    if metadata.local_id != 0 {
        fail("MIR lower resource metadata: metadata local_id drifted");
    }
    expect_str_eq(mir.mir_debug_resource_kind(metadata.resource_kind), "MirResourceKind.LinearResource", "MIR lower resource metadata: resource kind drifted");
    expect_str_eq(mir.mir_debug_resource_state(metadata.resource_state), "MirResourceState.Owned", "MIR lower resource metadata: resource state drifted");

    mut blocks_resource: std.Vector[mir.MirBlock[ctx], ctx] := ctx[function.blocks];
    mut entry_block := blocks_resource[0];
    if entry_block.id != 0 {
        fail("MIR lower resource metadata: entry block id should be zero");
    }
    if len(ctx[entry_block.statements]) != 1 {
        fail("MIR lower resource metadata: entry block should contain exactly one statement");
    }

    mut statements_resource: std.Vector[mir.MirStmt[ctx], ctx] := ctx[entry_block.statements];
    mut stmt := statements_resource[0];
    expect_str_eq(mir.mir_debug_stmt_kind(stmt), "MirStmt.LocalSet", "MIR lower resource metadata: statement kind drifted");
    unsafe {
        if stmt.LocalSet.local_id != 0 {
            fail("MIR lower resource metadata: local set target drifted");
        }
        mut initial_value: mir.MirValue[ctx] := ctx[stmt.LocalSet.value];
        expect_str_eq(mir.mir_debug_value_kind(initial_value), "MirValue.IntLiteral", "MIR lower resource metadata: initial value kind drifted");
        if initial_value.IntLiteral.val != 2 {
            fail("MIR lower resource metadata: initial literal value drifted");
        }
        expect_str_eq(initial_value.IntLiteral.value_type, "int", "MIR lower resource metadata: initial literal type drifted");
    }

    mut terminator: mir.MirTerminator[ctx] := ctx[entry_block.terminator];
    expect_str_eq(mir.mir_debug_terminator_kind(terminator), "MirTerminator.Return", "MIR lower resource metadata: terminator kind drifted");
    unsafe {
        mut return_value: mir.MirValue[ctx] := ctx[terminator.Return.value];
        expect_str_eq(mir.mir_debug_value_kind(return_value), "MirValue.LocalRead", "MIR lower resource metadata: return value kind drifted");
        if return_value.LocalRead.local_id != 0 {
            fail("MIR lower resource metadata: return local read target drifted");
        }
        expect_str_eq(return_value.LocalRead.value_type, "int", "MIR lower resource metadata: return local read type drifted");
    }

    mir.mir_debug_print_program(program);
    mir.mir_debug_print_function(function);
    mir.mir_debug_print_block(entry_block, ctx);
    mir.mir_debug_print_stmt(stmt);
    mir.mir_debug_print_terminator(terminator);

    os.LogStr("SUCCESS: mir lower resource metadata smoke");
}
