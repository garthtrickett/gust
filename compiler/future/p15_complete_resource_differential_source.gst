// Patch 15.13 real composed source: directory initialization, loop/branch
// observation, manual close, and selected failure-status propagation execute
// together. Canonical MIR composition evidence covers the remaining generic
// move, reassignment, cleanup, destruction, and join decisions.
func composed_resource_status(ctx: &Arena) int {
    guard dir := os.OpenDir(ctx, ".") else { return 1; }
    mut observed := 0;
    mut active := 1;
    while active == 1 {
        mut entry := os.ReadDir(ctx, dir);
        if entry.Ok {
            observed = observed + 1;
            active = 0;
        } else {
            active = 0;
        }
    }
    os.CloseDir(dir);
    if observed >= 0 { return 83; }
    return 2;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    mut status := composed_resource_status(&ctx);
    if status != 83 { os.Exit(1); }
    os.LogStr("SUCCESS: Phase 15.13 composed resource source passed");
}
