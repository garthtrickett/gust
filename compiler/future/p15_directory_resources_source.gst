// Positive source fixture: the selected directory resource opens, observes an
// entry, and closes through the generic Phase 15 resource authority contract.
func main() int {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut opened := os.OpenDir(ctx, "compiler");
    if opened.Ok {
        mut directory := opened.Val;
        mut entry := os.ReadDir(ctx, directory);
        os.CloseDir(directory);
        if entry.Ok {
            os.LogStr("SUCCESS: Phase 15.11 directory source fixture passed");
            return 0;
        }
    }
    return 15;
}
