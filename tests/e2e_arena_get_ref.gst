type ArenaRefNode struct {
    val: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut node_idx: Index[ArenaRefNode, ctx] := os.ArenaAlloc(ctx);
    ctx[node_idx].val = 41;

    mut node_ref := ctx.get_ref(node_idx);
    os.LogInt(node_ref.val);

    node_ref.val = node_ref.val + 1;
    os.LogInt(ctx[node_idx].val);
}