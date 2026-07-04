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

    mut program := mir.mir_lower_tiny_function_fixture(ctx);

    if len(ctx[program.functions]) != 1 {
        fail("MIR lower function shell: program should contain exactly one function");
    }

    mut function := ctx[program.functions][0];
    expect_str_eq(function.name, "tiny_shell", "MIR lower function shell: function name drifted");
    expect_str_eq(function.return_type, "void", "MIR lower function shell: return type drifted");

    if len(ctx[function.params]) != 0 {
        fail("MIR lower function shell: function should not lower params yet");
    }
    if len(ctx[function.locals]) != 0 {
        fail("MIR lower function shell: function should not lower locals yet");
    }
    if function.entry_block != 0 {
        fail("MIR lower function shell: entry block should be zero");
    }
    if len(ctx[function.blocks]) != 1 {
        fail("MIR lower function shell: function should contain exactly one block");
    }

    mut blocks_shell: std.Vector[mir.MirBlock[ctx], ctx] := ctx[function.blocks];
    mut block := blocks_shell[0];
    if block.id != 0 {
        fail("MIR lower function shell: block id should be zero");
    }
    if len(ctx[block.statements]) != 0 {
        fail("MIR lower function shell: entry block should not lower statements yet");
    }

    mut terminator := ctx[block.terminator];
    expect_str_eq(mir.mir_debug_terminator_kind(terminator), "MirTerminator.ReturnVoid", "MIR lower function shell: terminator kind drifted");

    mir.mir_debug_print_program(program);
    mir.mir_debug_print_function(function);
    mir.mir_debug_print_block(block, ctx);

    os.LogStr("SUCCESS: mir lower function shell smoke");
}
