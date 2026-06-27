type CustomNode[ctx] struct {
    name: str,
    data: []byte
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut n: Index[CustomNode, ctx] := os.ArenaAlloc(ctx);
    mut n_ref_branded_slice := ctx.get_ref(n);
    n_ref_branded_slice.name = "Hello";
}
