func assert_contains(c_content: str, substring: str, msg: str) {
    mut idx := std.str_find(c_content, substring);
    if idx == 0 - 1 {
        mut err := std.Concat("FAIL: ", msg);
        err = std.Concat(err, " (substring not found: ");
        err = std.Concat(err, substring);
        err = std.Concat(err, ")");
        os.LogStr(err);
        os.Exit(1);
    }
}

func assert_not_contains(c_content: str, substring: str, msg: str) {
    mut idx := std.str_find(c_content, substring);
    if idx != 0 - 1 {
        mut err := std.Concat("FAIL: ", msg);
        err = std.Concat(err, " (unexpected substring found: ");
        err = std.Concat(err, substring);
        err = std.Concat(err, ")");
        os.LogStr(err);
        os.Exit(1);
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    os.System("mkdir -p build");

    // Issue #398: these four assert on the CONTENT of the emitted C, so they
    // are served from the frozen corpus rather than by invoking the retired
    // spelling. The recorded stdout needs no emoji filtering -- the capture
    // took the emission itself, not a mixed log -- so the grep each case ran
    // is gone with the invocation that made it necessary.

    // Test 1: POD Move
    os.System("python3 scripts/phase24_frozen_oracle.py materialize tests/codegen_helper_pod_move.gst build/codegen_helper_pod_move --kind compile_only");
    mut c_pod := os.ReadFile(ctx, "build/codegen_helper_pod_move.compile.stdout");
    assert_not_contains(c_pod, "memset(&p1", "POD move should not generate memset");

    // Test 2: Linear Move
    os.System("python3 scripts/phase24_frozen_oracle.py materialize tests/codegen_helper_linear_move.gst build/codegen_helper_linear_move --kind compile_only");
    mut c_linear := os.ReadFile(ctx, "build/codegen_helper_linear_move.compile.stdout");
    assert_contains(c_linear, "memset(&p1", "Linear move should generate memset");

    // Test 3: Take Ops
    os.System("python3 scripts/phase24_frozen_oracle.py materialize tests/codegen_helper_take_ops.gst build/codegen_helper_take_ops --kind compile_only");
    mut c_take := os.ReadFile(ctx, "build/codegen_helper_take_ops.compile.stdout");
    assert_contains(c_take, "memset(&l1", "Linear take should generate memset");
    assert_not_contains(c_take, "memset(&p1", "POD take should not generate memset");

    // Test 4: Match Destructure
    os.System("python3 scripts/phase24_frozen_oracle.py materialize tests/codegen_helper_match_destructure.gst build/codegen_helper_match_destructure --kind compile_only");
    mut c_match := os.ReadFile(ctx, "build/codegen_helper_match_destructure.compile.stdout");
    assert_contains(c_match, "int* val = &(e.VariantA.val);", "Match destructure should declare and bind val");
    assert_contains(c_match, "int* x = &(e.VariantB.x);", "Match destructure should declare and bind x");
    assert_contains(c_match, "int* y = &(e.VariantB.y);", "Match destructure should declare and bind y");

    // Cleanup
    os.System("rm -f build/codegen_helper_*");

    os.LogStr("ALL SELF-HOSTED CODEGEN ASSERTIONS PASSED!");
}
