type Phase20ComponentNode struct {
    value: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut node: Index[Phase20ComponentNode, ctx] := os.ArenaAlloc(ctx);
    mut initial: Phase20ComponentNode;
    initial.value = 49;
    ctx.Set(node, initial);
    os.LogInt(ctx[node].value);
}
