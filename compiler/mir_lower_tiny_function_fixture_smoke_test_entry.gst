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

    if len(ctx[program.functions]) != 1 {
        fail("MIR lower tiny fixture Step 2: entry point should lower exactly one function shell");
    }

    mut functions_fixture: std.Vector[mir.MirFunction[ctx], ctx] := ctx[program.functions];
    mut function := functions_fixture[0];
    if std.str_eq(function.name, "tiny_shell") == 0 {
        fail("MIR lower tiny fixture Step 2: lowered function name drifted");
    }
    if std.str_eq(function.return_type, "void") == 0 {
        fail("MIR lower tiny fixture Step 2: lowered function return type drifted");
    }
    if len(ctx[function.blocks]) != 1 {
        fail("MIR lower tiny fixture Step 2: lowered function should have exactly one block");
    }

    mir.mir_debug_print_program(program);
    mir.mir_debug_print_function(function);
    os.LogStr("SUCCESS: mir lower tiny function fixture entry");
}
