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
    mut c_source := mir.mir_to_c_tiny_fixture(program, ctx);

    expect_str_eq(c_source, "int tiny_local_binding_read(void) { int value = 2; return value; }", "MIR-to-C local binding/read smoke: C source drifted");

    if len(ctx[program.functions]) != 1 {
        fail("MIR-to-C local binding/read smoke: source MIR fixture should contain one function");
    }

    mut functions_local: std.Vector[mir.MirFunction[ctx], ctx] := ctx[program.functions];
    mut function := functions_local[0];
    expect_str_eq(function.name, "tiny_local_binding_read", "MIR-to-C local binding/read smoke: source function name drifted");
    expect_str_eq(function.return_type, "int", "MIR-to-C local binding/read smoke: source return type drifted");

    if len(ctx[function.locals]) != 1 {
        fail("MIR-to-C local binding/read smoke: source MIR function should contain one local");
    }
    if len(ctx[function.blocks]) != 1 {
        fail("MIR-to-C local binding/read smoke: source MIR function should contain one block");
    }

    mut blocks_local: std.Vector[mir.MirBlock[ctx], ctx] := ctx[function.blocks];
    mut block := blocks_local[0];
    if len(ctx[block.statements]) != 1 {
        fail("MIR-to-C local binding/read smoke: source MIR block should contain one local set statement");
    }

    mut statements_local: std.Vector[mir.MirStmt[ctx], ctx] := ctx[block.statements];
    mut stmt := statements_local[0];
    expect_str_eq(mir.mir_debug_stmt_kind(stmt), "MirStmt.LocalSet", "MIR-to-C local binding/read smoke: source statement kind drifted");

    mut terminator: mir.MirTerminator[ctx] := ctx[block.terminator];
    expect_str_eq(mir.mir_debug_terminator_kind(terminator), "MirTerminator.Return", "MIR-to-C local binding/read smoke: source terminator kind drifted");

    unsafe {
        mut return_value: mir.MirValue[ctx] := ctx[terminator.Return.value];
        expect_str_eq(mir.mir_debug_value_kind(return_value), "MirValue.LocalRead", "MIR-to-C local binding/read smoke: source return value kind drifted");
        if return_value.LocalRead.local_id != 0 {
            fail("MIR-to-C local binding/read smoke: source local read target drifted");
        }
        expect_str_eq(return_value.LocalRead.value_type, "int", "MIR-to-C local binding/read smoke: source local read type drifted");
    }

    os.LogStr(c_source);
    os.LogStr("SUCCESS: mir to c local binding/read smoke");
}