type ArenaRefNode struct {
    val: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut node_idx: Index[ArenaRefNode, ctx] := os.ArenaAlloc(ctx);
    mut node_ref := ctx.get_ref(node_idx);
    node_ref.val = 41;
    os.LogInt(node_ref.val);

    node_ref.val = node_ref.val + 1;
    os.LogInt(ctx[node_idx].val);
}
