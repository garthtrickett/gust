func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut wrong_template: std.Vector[int, ctx] := std.ChannelNew(&ctx);
}
