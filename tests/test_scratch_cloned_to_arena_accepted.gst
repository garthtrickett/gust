type Node[ctx] struct {
    data: Index[Any, ctx]
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut n: Index[Node, ctx] := os.ArenaAlloc(ctx);
    mut p: Index[Any, ctx] := os.ArenaAlloc(ctx);
    mut cloned := std.Clone(ctx, p);
    ctx[n].data = cloned;
}