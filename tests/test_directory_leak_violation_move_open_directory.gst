func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut opt_dir := os.OpenDir(ctx, "src");
    if opt_dir.Ok {
        mut d := opt_dir.Val;
        mut d2 := move d;
        os.CloseDir(d2);
    }
}