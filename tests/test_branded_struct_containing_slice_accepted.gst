type CustomNode[ctx] struct {
    name: str,
    data: []byte
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut n: Index[CustomNode, ctx] := os.ArenaAlloc(ctx);
    ctx[n].name = "Hello";
}