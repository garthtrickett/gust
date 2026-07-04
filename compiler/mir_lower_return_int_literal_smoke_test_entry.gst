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

    if len(ctx[program.functions]) != 1 {
        fail("MIR lower return int literal: program should contain exactly one function");
    }

    mut functions_return: std.Vector[mir.MirFunction[ctx], ctx] := ctx[program.functions];
    mut function := functions_return[0];
    expect_str_eq(function.name, "tiny_return_int", "MIR lower return int literal: function name drifted");
    expect_str_eq(function.return_type, "int", "MIR lower return int literal: return type drifted");

    if len(ctx[function.params]) != 0 {
        fail("MIR lower return int literal: function should not lower params yet");
    }
    if len(ctx[function.locals]) != 0 {
        fail("MIR lower return int literal: function should not lower locals yet");
    }
    if function.entry_block != 0 {
        fail("MIR lower return int literal: entry block should be zero");
    }
    if len(ctx[function.blocks]) != 1 {
        fail("MIR lower return int literal: function should contain exactly one block");
    }

    mut blocks_return: std.Vector[mir.MirBlock[ctx], ctx] := ctx[function.blocks];
    mut block := blocks_return[0];
    if block.id != 0 {
        fail("MIR lower return int literal: block id should be zero");
    }
    if len(ctx[block.statements]) != 0 {
        fail("MIR lower return int literal: return should lower as a terminator, not a statement yet");
    }

    mut terminator: mir.MirTerminator[ctx] := ctx[block.terminator];
    expect_str_eq(mir.mir_debug_terminator_kind(terminator), "MirTerminator.Return", "MIR lower return int literal: terminator kind drifted");

    unsafe {
        mut return_value: mir.MirValue[ctx] := ctx[terminator.Return.value];
        expect_str_eq(mir.mir_debug_value_kind(return_value), "MirValue.IntLiteral", "MIR lower return int literal: return value kind drifted");
        if return_value.IntLiteral.val != 1 {
            fail("MIR lower return int literal: literal value drifted");
        }
        expect_str_eq(return_value.IntLiteral.value_type, "int", "MIR lower return int literal: literal value_type drifted");
    }

    mir.mir_debug_print_program(program);
    mir.mir_debug_print_function(function);
    mir.mir_debug_print_block(block, ctx);
    mir.mir_debug_print_terminator(terminator);

    os.LogStr("SUCCESS: mir lower return int literal smoke");
}