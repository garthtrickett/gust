func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.ArenaValidate(ctx);
}