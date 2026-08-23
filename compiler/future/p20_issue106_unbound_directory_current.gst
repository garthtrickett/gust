// Patch 20.9 issue #106 evidence: the successful acquisition obligation exists
// even when its payload is never extracted into a later local binding.
// current_result: rejects_unbound_directory_through_acquisition_identity
// fixed_by: 20.9

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut opt_dir := os.OpenDir(ctx, "src");
    if opt_dir.Ok {
        os.LogStr("opened, never bound, never closed");
    }
}
