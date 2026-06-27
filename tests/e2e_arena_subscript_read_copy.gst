type ArenaReadCopyNode struct {
    val: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut node_idx: Index[ArenaReadCopyNode, ctx] := os.ArenaAlloc(ctx);

    mut stored_node: ArenaReadCopyNode;
    stored_node.val = 11;
    ctx.Set(node_idx, stored_node);

    mut local_copy := ctx[node_idx];
    local_copy.val = 99;

    // Subscript read is copy-by-default: local mutation should not affect arena storage.
    os.LogInt(ctx[node_idx].val);

    ctx.Set(node_idx, local_copy);

    // Explicit write-back is required to update arena storage.
    os.LogInt(ctx[node_idx].val);
}