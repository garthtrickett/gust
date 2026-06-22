func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut c: std.Channel[str, ctx] := std.ChannelNew(ctx);
    c.Send(42);
}