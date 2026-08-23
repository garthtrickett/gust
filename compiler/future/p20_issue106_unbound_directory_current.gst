// Phase 20.0 baseline for issue #106 acquisition-before-binding.
// current_result: incorrectly_accepts_unextracted_open_directory_payload
// next_patch: 20.9

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut opt_dir := os.OpenDir(ctx, "src");
    if opt_dir.Ok {
        os.LogStr("opened, never bound, never closed");
    }
}
