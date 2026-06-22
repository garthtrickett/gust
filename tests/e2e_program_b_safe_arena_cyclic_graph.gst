type GraphNode[ctx] struct {
    Value: int,
    Next: Index[GraphNode, ctx]
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut nodeA: Index[GraphNode, ctx] := os.ArenaAlloc(ctx);
    mut nodeB: Index[GraphNode, ctx] := os.ArenaAlloc(ctx);
    mut nodeC: Index[GraphNode, ctx] := os.ArenaAlloc(ctx);

    ctx[nodeA].Value = 10;
    ctx[nodeB].Value = 20;
    ctx[nodeC].Value = 30;

    ctx[nodeA].Next = nodeB;
    ctx[nodeB].Next = nodeC;
    ctx[nodeC].Next = nodeA;

    mut curr := nodeA;
    mut count := 0;
    while count < 6 {
        os.LogInt(ctx[curr].Value);
        curr = ctx[curr].Next;
        count = count + 1;
    }
}