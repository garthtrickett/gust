type MyNode[ctx] struct {
    val: int
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut n1: Index[MyNode, ctx] := os.ArenaAlloc(ctx);
    mut n2: Index[MyNode, ctx] := os.ArenaAlloc(ctx);
    ctx[n1].val = 42;
    ctx[n2].val = 84;
    
    os.ArenaValidate(ctx);
    os.LogInt(ctx[n1].val);
    os.LogInt(ctx[n2].val);
}