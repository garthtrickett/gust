type Node[ctx] struct {
    data: *byte
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut n: Index[Node, ctx] := os.ArenaAlloc(ctx);
    mut p := os.ScratchAlloc(10);
    ctx[n].data = p;
}