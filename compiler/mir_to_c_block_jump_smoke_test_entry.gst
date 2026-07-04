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

    mut program := mir.mir_lower_block_jump_fixture(ctx);
    mut c_source := mir.mir_to_c_tiny_fixture(program, ctx);

    expect_str_eq(c_source, "int tiny_block_jump(void) { goto block_1; block_1: return 1; }", "MIR-to-C block jump smoke: C source drifted");

    if len(ctx[program.functions]) != 1 {
        fail("MIR-to-C block jump smoke: source MIR fixture should contain one function");
    }

    mut functions_jump: std.Vector[mir.MirFunction[ctx], ctx] := ctx[program.functions];
    mut function := functions_jump[0];
    expect_str_eq(function.name, "tiny_block_jump", "MIR-to-C block jump smoke: source function name drifted");
    expect_str_eq(function.return_type, "int", "MIR-to-C block jump smoke: source return type drifted");

    if len(ctx[function.locals]) != 0 {
        fail("MIR-to-C block jump smoke: source MIR function should contain no locals");
    }
    if len(ctx[function.blocks]) != 2 {
        fail("MIR-to-C block jump smoke: source MIR function should contain two blocks");
    }

    mut blocks_jump: std.Vector[mir.MirBlock[ctx], ctx] := ctx[function.blocks];
    mut entry_block := blocks_jump[0];
    mut return_block := blocks_jump[1];

    if entry_block.id != 0 {
        fail("MIR-to-C block jump smoke: source entry block id drifted");
    }
    if return_block.id != 1 {
        fail("MIR-to-C block jump smoke: source return block id drifted");
    }
    if len(ctx[entry_block.statements]) != 0 {
        fail("MIR-to-C block jump smoke: entry block should contain no statements");
    }
    if len(ctx[return_block.statements]) != 0 {
        fail("MIR-to-C block jump smoke: return block should contain no statements");
    }

    mut entry_terminator: mir.MirTerminator[ctx] := ctx[entry_block.terminator];
    expect_str_eq(mir.mir_debug_terminator_kind(entry_terminator), "MirTerminator.Jump", "MIR-to-C block jump smoke: source entry terminator kind drifted");
    unsafe {
        if entry_terminator.Jump.target_block != 1 {
            fail("MIR-to-C block jump smoke: source jump target drifted");
        }
    }

    mut return_terminator: mir.MirTerminator[ctx] := ctx[return_block.terminator];
    expect_str_eq(mir.mir_debug_terminator_kind(return_terminator), "MirTerminator.Return", "MIR-to-C block jump smoke: source return terminator kind drifted");
    unsafe {
        mut return_value: mir.MirValue[ctx] := ctx[return_terminator.Return.value];
        expect_str_eq(mir.mir_debug_value_kind(return_value), "MirValue.IntLiteral", "MIR-to-C block jump smoke: source return value kind drifted");
        if return_value.IntLiteral.val != 1 {
            fail("MIR-to-C block jump smoke: source return literal value drifted");
        }
        expect_str_eq(return_value.IntLiteral.value_type, "int", "MIR-to-C block jump smoke: source return literal type drifted");
    }

    os.LogStr(c_source);
    os.LogStr("SUCCESS: mir to c block jump smoke");
}