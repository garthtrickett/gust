func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut opt_dir := os.OpenDir_Invalid(ctx, "src");
}