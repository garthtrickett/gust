func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut tl: std.ThreadLocalContext[ctx];
}