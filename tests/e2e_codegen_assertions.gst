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

    // Test 1: POD Move
    os.System("./gust tests/codegen_helper_pod_move.gst > build/codegen_helper_pod_move_temp.log 2>&1");
    os.System("grep -v -E \"^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)\" build/codegen_helper_pod_move_temp.log > build/codegen_helper_pod_move.c");
    mut c_pod := os.ReadFile(ctx, "build/codegen_helper_pod_move.c");
    assert_not_contains(c_pod, "memset(&p1", "POD move should not generate memset");

    // Test 2: Linear Move
    os.System("./gust tests/codegen_helper_linear_move.gst > build/codegen_helper_linear_move_temp.log 2>&1");
    os.System("grep -v -E \"^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)\" build/codegen_helper_linear_move_temp.log > build/codegen_helper_linear_move.c");
    mut c_linear := os.ReadFile(ctx, "build/codegen_helper_linear_move.c");
    assert_contains(c_linear, "memset(&p1", "Linear move should generate memset");

    // Test 3: Take Ops
    os.System("./gust tests/codegen_helper_take_ops.gst > build/codegen_helper_take_ops_temp.log 2>&1");
    os.System("grep -v -E \"^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)\" build/codegen_helper_take_ops_temp.log > build/codegen_helper_take_ops.c");
    mut c_take := os.ReadFile(ctx, "build/codegen_helper_take_ops.c");
    assert_contains(c_take, "memset(&l1", "Linear take should generate memset");
    assert_not_contains(c_take, "memset(&p1", "POD take should not generate memset");

    // Test 4: Match Destructure
    os.System("./gust tests/codegen_helper_match_destructure.gst > build/codegen_helper_match_destructure_temp.log 2>&1");
    os.System("grep -v -E \"^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)\" build/codegen_helper_match_destructure_temp.log > build/codegen_helper_match_destructure.c");
    mut c_match := os.ReadFile(ctx, "build/codegen_helper_match_destructure.c");
    assert_contains(c_match, "int val = e.VariantA.val;", "Match destructure should declare and bind val");
    assert_contains(c_match, "int x = e.VariantB.x;", "Match destructure should declare and bind x");
    assert_contains(c_match, "int y = e.VariantB.y;", "Match destructure should declare and bind y");

    // Cleanup
    os.System("rm -f build/codegen_helper_*");

    os.LogStr("ALL SELF-HOSTED CODEGEN ASSERTIONS PASSED!");
}