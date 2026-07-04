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

    expect_str_eq(c_source, "/* gust MIR-to-C tiny fixture */", "MIR-to-C entry smoke: banner drifted");

    if len(ctx[program.functions]) != 1 {
        fail("MIR-to-C entry smoke: source MIR fixture should still contain one function");
    }

    os.LogStr(c_source);
    os.LogStr("SUCCESS: mir to c entry smoke");
}