type ArenaExplicitSetNode struct {
    val: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut node_idx: Index[ArenaExplicitSetNode, ctx] := os.ArenaAlloc(ctx);

    mut first_value: ArenaExplicitSetNode;
    first_value.val = 41;
    ctx.Set(node_idx, first_value);
    os.LogInt(ctx[node_idx].val);

    mut second_value: ArenaExplicitSetNode;
    second_value.val = 99;
    ctx.Write(node_idx, second_value);
    os.LogInt(ctx[node_idx].val);
}