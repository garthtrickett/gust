type UnsafeSubscriptWriteNode struct {
    val: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut node_idx: Index[UnsafeSubscriptWriteNode, ctx] := os.ArenaAlloc(ctx);
    mut node_value: UnsafeSubscriptWriteNode;
    node_value.val = 41;

    // Step 4.5C: explicit unsafe blocks may still perform direct arena slot writes.
    unsafe {
        ctx[node_idx] = node_value;
    }

    mut got := ctx[node_idx];
    if got.val != 41 {
        os.Exit(1);
    }
}