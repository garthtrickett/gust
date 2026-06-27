type SafeSubscriptFieldNode struct {
    val: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut node_idx: Index[SafeSubscriptFieldNode, ctx] := os.ArenaAlloc(ctx);
    mut node_value: SafeSubscriptFieldNode;
    node_value.val = 10;
    ctx.Set(node_idx, node_value);

    // Step 4.5C: safe field writes rooted at arena subscript must use get_ref.
    ctx[node_idx].val = 99;
}