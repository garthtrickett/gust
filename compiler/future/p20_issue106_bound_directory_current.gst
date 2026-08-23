// Patch 20.10 issue #106 evidence: a bound successful acquisition transports
// its identity to the payload and is destroyed at the payload's scope exit.
// current_result: accepts_bound_directory_with_payload_scope_cleanup
// fixed_by: 20.10

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut opt_dir := os.OpenDir(ctx, "src");
    if opt_dir.Ok {
        mut d := opt_dir.Val;
        os.LogStr("opened and never closed");
    }
}
