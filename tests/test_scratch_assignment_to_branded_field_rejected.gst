type Node[ctx] struct {
    data: *byte
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut n: Index[Node, ctx] := os.ArenaAlloc(ctx);
    mut p := os.ScratchAlloc(10);
    mut n_ref_scratch_rejected := ctx.get_ref(n);
    n_ref_scratch_rejected.data = p;
}
