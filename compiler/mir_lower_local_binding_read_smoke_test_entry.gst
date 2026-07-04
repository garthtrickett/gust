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

    mut program := mir.mir_lower_local_binding_read_fixture(ctx);

    if len(ctx[program.functions]) != 1 {
        fail("MIR lower local binding/read: program should contain exactly one function");
    }

    mut functions_local: std.Vector[mir.MirFunction[ctx], ctx] := ctx[program.functions];
    mut function := functions_local[0];
    expect_str_eq(function.name, "tiny_local_binding_read", "MIR lower local binding/read: function name drifted");
    expect_str_eq(function.return_type, "int", "MIR lower local binding/read: return type drifted");

    if len(ctx[function.params]) != 0 {
        fail("MIR lower local binding/read: function should not lower params yet");
    }
    if len(ctx[function.locals]) != 1 {
        fail("MIR lower local binding/read: function should contain one local");
    }

    mut locals_local: std.Vector[mir.MirLocal[ctx], ctx] := ctx[function.locals];
    mut local := locals_local[0];
    if local.id != 0 {
        fail("MIR lower local binding/read: local id drifted");
    }
    expect_str_eq(local.name, "value", "MIR lower local binding/read: local name drifted");
    expect_str_eq(local.local_type, "int", "MIR lower local binding/read: local type drifted");

    if function.entry_block != 0 {
        fail("MIR lower local binding/read: entry block should be zero");
    }
    if len(ctx[function.blocks]) != 1 {
        fail("MIR lower local binding/read: function should contain exactly one block");
    }

    mut blocks_local: std.Vector[mir.MirBlock[ctx], ctx] := ctx[function.blocks];
    mut block := blocks_local[0];
    if block.id != 0 {
        fail("MIR lower local binding/read: block id should be zero");
    }
    if len(ctx[block.statements]) != 1 {
        fail("MIR lower local binding/read: entry block should contain one local set statement");
    }

    mut statements_local: std.Vector[mir.MirStmt[ctx], ctx] := ctx[block.statements];
    mut stmt := statements_local[0];
    expect_str_eq(mir.mir_debug_stmt_kind(stmt), "MirStmt.LocalSet", "MIR lower local binding/read: statement kind drifted");

    unsafe {
        if stmt.LocalSet.local_id != 0 {
            fail("MIR lower local binding/read: local set target drifted");
        }
        mut set_value: mir.MirValue[ctx] := ctx[stmt.LocalSet.value];
        expect_str_eq(mir.mir_debug_value_kind(set_value), "MirValue.IntLiteral", "MIR lower local binding/read: local set value kind drifted");
        if set_value.IntLiteral.val != 2 {
            fail("MIR lower local binding/read: local set literal value drifted");
        }
        expect_str_eq(set_value.IntLiteral.value_type, "int", "MIR lower local binding/read: local set value type drifted");
    }

    mut terminator: mir.MirTerminator[ctx] := ctx[block.terminator];
    expect_str_eq(mir.mir_debug_terminator_kind(terminator), "MirTerminator.Return", "MIR lower local binding/read: terminator kind drifted");

    unsafe {
        mut return_value: mir.MirValue[ctx] := ctx[terminator.Return.value];
        expect_str_eq(mir.mir_debug_value_kind(return_value), "MirValue.LocalRead", "MIR lower local binding/read: return value kind drifted");
        if return_value.LocalRead.local_id != 0 {
            fail("MIR lower local binding/read: return local read target drifted");
        }
        expect_str_eq(return_value.LocalRead.value_type, "int", "MIR lower local binding/read: return local read type drifted");
    }

    mir.mir_debug_print_program(program);
    mir.mir_debug_print_function(function);
    mir.mir_debug_print_block(block, ctx);
    mir.mir_debug_print_stmt(stmt);
    mir.mir_debug_print_terminator(terminator);

    os.LogStr("SUCCESS: mir lower local binding/read smoke");
}