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
    mut c_source := mir.mir_to_c_tiny_fixture(program, ctx);

    expect_str_eq(c_source, "void tiny_shell(void) { return; }", "MIR-to-C function shell smoke: C source drifted");

    if len(ctx[program.functions]) != 1 {
        fail("MIR-to-C function shell smoke: source MIR fixture should contain one function");
    }

    mut functions_shell: std.Vector[mir.MirFunction[ctx], ctx] := ctx[program.functions];
    mut function := functions_shell[0];
    if len(ctx[function.blocks]) != 1 {
        fail("MIR-to-C function shell smoke: source MIR function should contain one block");
    }

    mut blocks_shell: std.Vector[mir.MirBlock[ctx], ctx] := ctx[function.blocks];
    mut block := blocks_shell[0];
    mut terminator: mir.MirTerminator[ctx] := ctx[block.terminator];
    expect_str_eq(mir.mir_debug_terminator_kind(terminator), "MirTerminator.ReturnVoid", "MIR-to-C function shell smoke: source terminator kind drifted");

    os.LogStr(c_source);
    os.LogStr("SUCCESS: mir to c function shell smoke");
}