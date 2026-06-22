type CustomNode[ctx] struct {
    val: int
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut n: Index[CustomNode, ctx] := os.ArenaAlloc(ctx);
    ctx[n].val = 42;
    mut chan: std.Channel[Arena, ctx] := std.ChannelNew(ctx);
    chan.Send(move ctx);
    ctx[n].val = 100;
}