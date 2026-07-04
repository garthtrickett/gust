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

    mut program := mir.mir_lower_return_int_literal_fixture(ctx);
    mut c_source := mir.mir_to_c_tiny_fixture(program, ctx);

    expect_str_eq(c_source, "int tiny_return_int(void) { return 1; }", "MIR-to-C return int literal smoke: C source drifted");

    if len(ctx[program.functions]) != 1 {
        fail("MIR-to-C return int literal smoke: source MIR fixture should contain one function");
    }

    mut functions_return: std.Vector[mir.MirFunction[ctx], ctx] := ctx[program.functions];
    mut function := functions_return[0];
    expect_str_eq(function.name, "tiny_return_int", "MIR-to-C return int literal smoke: source function name drifted");
    expect_str_eq(function.return_type, "int", "MIR-to-C return int literal smoke: source return type drifted");

    if len(ctx[function.blocks]) != 1 {
        fail("MIR-to-C return int literal smoke: source MIR function should contain one block");
    }

    mut blocks_return: std.Vector[mir.MirBlock[ctx], ctx] := ctx[function.blocks];
    mut block := blocks_return[0];
    mut terminator: mir.MirTerminator[ctx] := ctx[block.terminator];
    expect_str_eq(mir.mir_debug_terminator_kind(terminator), "MirTerminator.Return", "MIR-to-C return int literal smoke: source terminator kind drifted");

    unsafe {
        mut return_value: mir.MirValue[ctx] := ctx[terminator.Return.value];
        expect_str_eq(mir.mir_debug_value_kind(return_value), "MirValue.IntLiteral", "MIR-to-C return int literal smoke: source value kind drifted");
        if return_value.IntLiteral.val != 1 {
            fail("MIR-to-C return int literal smoke: source literal value drifted");
        }
        expect_str_eq(return_value.IntLiteral.value_type, "int", "MIR-to-C return int literal smoke: source literal value_type drifted");
    }

    os.LogStr(c_source);
    os.LogStr("SUCCESS: mir to c return int literal smoke");
}