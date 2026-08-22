// Phase 20.0 control for issue #106.
// current_result: rejects_named_open_directory_with_existing_resource_leak_diagnostic
// next_patch: 20.9

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut opt_dir := os.OpenDir(ctx, "src");
    if opt_dir.Ok {
        mut d := opt_dir.Val;
        os.LogStr("opened and never closed");
    }
}
