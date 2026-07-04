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

    mut program := mir.mir_lower_block_jump_fixture(ctx);

    if len(ctx[program.functions]) != 1 {
        fail("MIR lower block jump: program should contain exactly one function");
    }

    mut functions_jump: std.Vector[mir.MirFunction[ctx], ctx] := ctx[program.functions];
    mut function := functions_jump[0];
    expect_str_eq(function.name, "tiny_block_jump", "MIR lower block jump: function name drifted");
    expect_str_eq(function.return_type, "int", "MIR lower block jump: return type drifted");

    if len(ctx[function.params]) != 0 {
        fail("MIR lower block jump: function should not lower params yet");
    }
    if len(ctx[function.locals]) != 0 {
        fail("MIR lower block jump: function should not lower locals yet");
    }
    if function.entry_block != 0 {
        fail("MIR lower block jump: entry block should be zero");
    }
    if len(ctx[function.blocks]) != 2 {
        fail("MIR lower block jump: function should contain exactly two blocks");
    }

    mut blocks_jump: std.Vector[mir.MirBlock[ctx], ctx] := ctx[function.blocks];
    mut entry_block := blocks_jump[0];
    mut return_block := blocks_jump[1];

    if entry_block.id != 0 {
        fail("MIR lower block jump: entry block id should be zero");
    }
    if len(ctx[entry_block.statements]) != 0 {
        fail("MIR lower block jump: entry block should contain no statements yet");
    }

    mut entry_terminator: mir.MirTerminator[ctx] := ctx[entry_block.terminator];
    expect_str_eq(mir.mir_debug_terminator_kind(entry_terminator), "MirTerminator.Jump", "MIR lower block jump: entry terminator kind drifted");
    unsafe {
        if entry_terminator.Jump.target_block != 1 {
            fail("MIR lower block jump: jump target block drifted");
        }
    }

    if return_block.id != 1 {
        fail("MIR lower block jump: return block id should be one");
    }
    if len(ctx[return_block.statements]) != 0 {
        fail("MIR lower block jump: return block should contain no statements yet");
    }

    mut return_terminator: mir.MirTerminator[ctx] := ctx[return_block.terminator];
    expect_str_eq(mir.mir_debug_terminator_kind(return_terminator), "MirTerminator.Return", "MIR lower block jump: return terminator kind drifted");
    unsafe {
        mut return_value: mir.MirValue[ctx] := ctx[return_terminator.Return.value];
        expect_str_eq(mir.mir_debug_value_kind(return_value), "MirValue.IntLiteral", "MIR lower block jump: return value kind drifted");
        if return_value.IntLiteral.val != 1 {
            fail("MIR lower block jump: return literal value drifted");
        }
        expect_str_eq(return_value.IntLiteral.value_type, "int", "MIR lower block jump: return literal value_type drifted");
    }

    mir.mir_debug_print_program(program);
    mir.mir_debug_print_function(function);
    mir.mir_debug_print_block(entry_block, ctx);
    mir.mir_debug_print_terminator(entry_terminator);
    mir.mir_debug_print_block(return_block, ctx);
    mir.mir_debug_print_terminator(return_terminator);

    os.LogStr("SUCCESS: mir lower block jump smoke");
}