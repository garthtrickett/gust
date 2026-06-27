type MyNode[ctx] struct {
    val: int
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut n1: Index[MyNode, ctx] := os.ArenaAlloc(ctx);
    mut n2: Index[MyNode, ctx] := os.ArenaAlloc(ctx);
    mut n1_ref := ctx.get_ref(n1);
    n1_ref.val = 42;
    mut n2_ref := ctx.get_ref(n2);
    n2_ref.val = 84;
    
    os.ArenaValidate(ctx);
    os.LogInt(ctx[n1].val);
    os.LogInt(ctx[n2].val);
}
