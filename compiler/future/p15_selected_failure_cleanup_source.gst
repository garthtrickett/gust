// Patch 15.12 real source fixture: a selected runtime failure return crosses a
// live directory cleanup. The bounded selected edge closes the handle exactly
// once before the failure status is observed by main.
func selected_runtime_failure(ctx: &Arena) int {
    guard dir := os.OpenDir(ctx, ".") else {
        return 1;
    }
    mut entry := os.ReadDir(ctx, dir);
    if entry.Ok {
        os.CloseDir(dir);
        return 82;
    }
    os.CloseDir(dir);
    return 82;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    mut status := selected_runtime_failure(&ctx);
    if status != 82 {
        os.LogStr("Phase 15.12 selected runtime failure status drifted");
        os.Exit(1);
    }
    os.LogStr("SUCCESS: Phase 15.12 selected failure cleanup source passed");
}
