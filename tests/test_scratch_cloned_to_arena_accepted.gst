type Dummy struct {
    val: int
}
type Node[ctx] struct {
    data: Index[Dummy, ctx]
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut n: Index[Node, ctx] := os.ArenaAlloc(ctx);
    mut p: Index[Dummy, ctx] := os.ArenaAlloc(ctx);
    mut cloned := std.Clone(ctx, p);
    ctx[n].data = cloned;
}
