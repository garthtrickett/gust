func main() int {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut forged: os.Dir[ctx];
    os.CloseDir(forged);
    return 0;
}
