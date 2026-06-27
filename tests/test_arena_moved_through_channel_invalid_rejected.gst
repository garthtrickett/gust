type CustomNode[ctx] struct {
    val: int
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut n: Index[CustomNode, ctx] := os.ArenaAlloc(ctx);
    mut n_ref_before_move := ctx.get_ref(n);
    n_ref_before_move.val = 42;
    mut chan: std.Channel[Arena, ctx] := std.ChannelNew(ctx);
    chan.Send(move ctx);
    mut n_ref_after_move := ctx.get_ref(n);
    n_ref_after_move.val = 100;
}
