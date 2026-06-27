type UnsafeSubscriptFieldNode struct {
    val: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut node_idx: Index[UnsafeSubscriptFieldNode, ctx] := os.ArenaAlloc(ctx);
    mut node_value: UnsafeSubscriptFieldNode;
    node_value.val = 10;
    ctx.Set(node_idx, node_value);

    // Step 4.5C: explicit unsafe blocks may still perform field writes rooted at arena subscript.
    unsafe {
        ctx[node_idx].val = 99;
    }

    mut got := ctx[node_idx];
    if got.val != 99 {
        os.Exit(1);
    }
}