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

    mut program := mir.mir_lower_conditional_branch_fixture(ctx);

    if len(ctx[program.functions]) != 1 {
        fail("MIR lower conditional branch: program should contain exactly one function");
    }

    mut functions_branch: std.Vector[mir.MirFunction[ctx], ctx] := ctx[program.functions];
    mut function := functions_branch[0];
    expect_str_eq(function.name, "tiny_conditional_branch", "MIR lower conditional branch: function name drifted");
    expect_str_eq(function.return_type, "int", "MIR lower conditional branch: return type drifted");

    if len(ctx[function.params]) != 0 {
        fail("MIR lower conditional branch: function should not lower params yet");
    }
    if len(ctx[function.locals]) != 0 {
        fail("MIR lower conditional branch: function should not lower locals yet");
    }
    if function.entry_block != 0 {
        fail("MIR lower conditional branch: entry block should be zero");
    }
    if len(ctx[function.blocks]) != 3 {
        fail("MIR lower conditional branch: function should contain exactly three blocks");
    }

    mut blocks_branch: std.Vector[mir.MirBlock[ctx], ctx] := ctx[function.blocks];
    mut entry_block := blocks_branch[0];
    mut then_block := blocks_branch[1];
    mut else_block := blocks_branch[2];

    if entry_block.id != 0 {
        fail("MIR lower conditional branch: entry block id should be zero");
    }
    if len(ctx[entry_block.statements]) != 0 {
        fail("MIR lower conditional branch: entry block should contain no statements yet");
    }

    mut entry_terminator: mir.MirTerminator[ctx] := ctx[entry_block.terminator];
    expect_str_eq(mir.mir_debug_terminator_kind(entry_terminator), "MirTerminator.Branch", "MIR lower conditional branch: entry terminator kind drifted");
    unsafe {
        mut condition_value: mir.MirValue[ctx] := ctx[entry_terminator.Branch.condition];
        expect_str_eq(mir.mir_debug_value_kind(condition_value), "MirValue.IntLiteral", "MIR lower conditional branch: condition value kind drifted");
        if condition_value.IntLiteral.val != 1 {
            fail("MIR lower conditional branch: condition literal value drifted");
        }
        expect_str_eq(condition_value.IntLiteral.value_type, "bool", "MIR lower conditional branch: condition value_type drifted");
        if entry_terminator.Branch.then_block != 1 {
            fail("MIR lower conditional branch: then block target drifted");
        }
        if entry_terminator.Branch.else_block != 2 {
            fail("MIR lower conditional branch: else block target drifted");
        }
    }

    if then_block.id != 1 {
        fail("MIR lower conditional branch: then block id should be one");
    }
    if len(ctx[then_block.statements]) != 0 {
        fail("MIR lower conditional branch: then block should contain no statements yet");
    }
    mut then_terminator: mir.MirTerminator[ctx] := ctx[then_block.terminator];
    expect_str_eq(mir.mir_debug_terminator_kind(then_terminator), "MirTerminator.Return", "MIR lower conditional branch: then terminator kind drifted");
    unsafe {
        mut then_value: mir.MirValue[ctx] := ctx[then_terminator.Return.value];
        expect_str_eq(mir.mir_debug_value_kind(then_value), "MirValue.IntLiteral", "MIR lower conditional branch: then value kind drifted");
        if then_value.IntLiteral.val != 1 {
            fail("MIR lower conditional branch: then return literal value drifted");
        }
        expect_str_eq(then_value.IntLiteral.value_type, "int", "MIR lower conditional branch: then return value_type drifted");
    }

    if else_block.id != 2 {
        fail("MIR lower conditional branch: else block id should be two");
    }
    if len(ctx[else_block.statements]) != 0 {
        fail("MIR lower conditional branch: else block should contain no statements yet");
    }
    mut else_terminator: mir.MirTerminator[ctx] := ctx[else_block.terminator];
    expect_str_eq(mir.mir_debug_terminator_kind(else_terminator), "MirTerminator.Return", "MIR lower conditional branch: else terminator kind drifted");
    unsafe {
        mut else_value: mir.MirValue[ctx] := ctx[else_terminator.Return.value];
        expect_str_eq(mir.mir_debug_value_kind(else_value), "MirValue.IntLiteral", "MIR lower conditional branch: else value kind drifted");
        if else_value.IntLiteral.val != 2 {
            fail("MIR lower conditional branch: else return literal value drifted");
        }
        expect_str_eq(else_value.IntLiteral.value_type, "int", "MIR lower conditional branch: else return value_type drifted");
    }

    mir.mir_debug_print_program(program);
    mir.mir_debug_print_function(function);
    mir.mir_debug_print_block(entry_block, ctx);
    mir.mir_debug_print_terminator(entry_terminator);
    mir.mir_debug_print_block(then_block, ctx);
    mir.mir_debug_print_terminator(then_terminator);
    mir.mir_debug_print_block(else_block, ctx);
    mir.mir_debug_print_terminator(else_terminator);

    os.LogStr("SUCCESS: mir lower conditional branch smoke");
}