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
    mut n_ref_scratch_clone := ctx.get_ref(n);
    n_ref_scratch_clone.data = cloned;
}
