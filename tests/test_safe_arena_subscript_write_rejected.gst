type SafeSubscriptWriteNode struct {
    val: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut node_idx: Index[SafeSubscriptWriteNode, ctx] := os.ArenaAlloc(ctx);
    mut node_value: SafeSubscriptWriteNode;
    node_value.val = 41;

    // Step 4.5C: safe direct arena slot writes must use ctx.Set/Write.
    ctx[node_idx] = node_value;
}