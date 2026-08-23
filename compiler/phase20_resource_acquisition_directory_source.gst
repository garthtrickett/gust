func main() int {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    guard directory := os.OpenDir(ctx, "compiler") else {
        return 1;
    }
    os.CloseDir(directory);
    return 0;
}
