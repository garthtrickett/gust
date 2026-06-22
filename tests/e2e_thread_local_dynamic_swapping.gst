func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    
    os.LogInt(ctx.Offset);
    mut s := std.FormatInt(123);
    os.LogInt(ctx.Offset);
}