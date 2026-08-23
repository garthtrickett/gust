// Patch 20.9 issue #106 evidence: a bound successful acquisition retains the
// acquisition identity and rejects if no consumer receives it.
// current_result: rejects_bound_directory_through_acquisition_identity
// fixed_by: 20.9

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut opt_dir := os.OpenDir(ctx, "src");
    if opt_dir.Ok {
        mut d := opt_dir.Val;
        os.LogStr("opened and never closed");
    }
}
