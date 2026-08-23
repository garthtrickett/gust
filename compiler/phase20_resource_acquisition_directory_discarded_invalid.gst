func main() int {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.OpenDir(ctx, "compiler");
    return 0;
}
