// Patch 20.10 issue #106 evidence: an unbound successful acquisition is
// conditionally destroyed at scope exit through its stored fallible wrapper.
// current_result: accepts_unbound_directory_with_conditional_scope_cleanup
// fixed_by: 20.10

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut opt_dir := os.OpenDir(ctx, "src");
    if opt_dir.Ok {
        os.LogStr("opened, never bound, never closed");
    }
}
