import "mir.gst" as mir;

func fail(msg: str) {
    os.LogStr(msg);
    os.Exit(1);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut program := mir.mir_lower_tiny_function_fixture(ctx);

    if len(ctx[program.functions]) != 0 {
        fail("MIR lower tiny fixture Step 1: entry point should not lower functions yet");
    }

    mir.mir_debug_print_program(program);
    os.LogStr("SUCCESS: mir lower tiny function fixture entry");
}