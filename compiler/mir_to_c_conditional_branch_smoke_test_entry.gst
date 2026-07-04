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

    mut program := mir.mir_lower_conditional_branch_fixture(ctx);
    mut c_source := mir.mir_to_c_tiny_fixture(program, ctx);

    expect_str_eq(c_source, "int tiny_conditional_branch(void) { if (1) goto block_1; goto block_2; block_1: return 1; block_2: return 2; }", "MIR-to-C conditional branch smoke: C source drifted");

    if len(ctx[program.functions]) != 1 {
        fail("MIR-to-C conditional branch smoke: source MIR fixture should contain one function");
    }

    mut functions_branch: std.Vector[mir.MirFunction[ctx], ctx] := ctx[program.functions];
    mut function := functions_branch[0];
    expect_str_eq(function.name, "tiny_conditional_branch", "MIR-to-C conditional branch smoke: source function name drifted");
    expect_str_eq(function.return_type, "int", "MIR-to-C conditional branch smoke: source return type drifted");

    if len(ctx[function.locals]) != 0 {
        fail("MIR-to-C conditional branch smoke: source MIR function should contain no locals");
    }
    if len(ctx[function.blocks]) != 3 {
        fail("MIR-to-C conditional branch smoke: source MIR function should contain three blocks");
    }

    mut blocks_branch: std.Vector[mir.MirBlock[ctx], ctx] := ctx[function.blocks];
    mut entry_block := blocks_branch[0];
    mut then_block := blocks_branch[1];
    mut else_block := blocks_branch[2];

    if entry_block.id != 0 {
        fail("MIR-to-C conditional branch smoke: source entry block id drifted");
    }
    if then_block.id != 1 {
        fail("MIR-to-C conditional branch smoke: source then block id drifted");
    }
    if else_block.id != 2 {
        fail("MIR-to-C conditional branch smoke: source else block id drifted");
    }

    mut entry_terminator: mir.MirTerminator[ctx] := ctx[entry_block.terminator];
    expect_str_eq(mir.mir_debug_terminator_kind(entry_terminator), "MirTerminator.Branch", "MIR-to-C conditional branch smoke: source entry terminator kind drifted");
    unsafe {
        mut condition_value: mir.MirValue[ctx] := ctx[entry_terminator.Branch.condition];
        expect_str_eq(mir.mir_debug_value_kind(condition_value), "MirValue.IntLiteral", "MIR-to-C conditional branch smoke: source condition kind drifted");
        if condition_value.IntLiteral.val != 1 {
            fail("MIR-to-C conditional branch smoke: source condition literal drifted");
        }
        expect_str_eq(condition_value.IntLiteral.value_type, "bool", "MIR-to-C conditional branch smoke: source condition type drifted");
        if entry_terminator.Branch.then_block != 1 {
            fail("MIR-to-C conditional branch smoke: source then target drifted");
        }
        if entry_terminator.Branch.else_block != 2 {
            fail("MIR-to-C conditional branch smoke: source else target drifted");
        }
    }

    mut then_terminator: mir.MirTerminator[ctx] := ctx[then_block.terminator];
    expect_str_eq(mir.mir_debug_terminator_kind(then_terminator), "MirTerminator.Return", "MIR-to-C conditional branch smoke: source then terminator kind drifted");
    unsafe {
        mut then_value: mir.MirValue[ctx] := ctx[then_terminator.Return.value];
        expect_str_eq(mir.mir_debug_value_kind(then_value), "MirValue.IntLiteral", "MIR-to-C conditional branch smoke: source then value kind drifted");
        if then_value.IntLiteral.val != 1 {
            fail("MIR-to-C conditional branch smoke: source then literal drifted");
        }
    }

    mut else_terminator: mir.MirTerminator[ctx] := ctx[else_block.terminator];
    expect_str_eq(mir.mir_debug_terminator_kind(else_terminator), "MirTerminator.Return", "MIR-to-C conditional branch smoke: source else terminator kind drifted");
    unsafe {
        mut else_value: mir.MirValue[ctx] := ctx[else_terminator.Return.value];
        expect_str_eq(mir.mir_debug_value_kind(else_value), "MirValue.IntLiteral", "MIR-to-C conditional branch smoke: source else value kind drifted");
        if else_value.IntLiteral.val != 2 {
            fail("MIR-to-C conditional branch smoke: source else literal drifted");
        }
    }

    os.LogStr(c_source);
    os.LogStr("SUCCESS: mir to c conditional branch smoke");
}