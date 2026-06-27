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

    mut nodeA_ref_program_b := ctx.get_ref(nodeA);
    mut nodeB_ref_program_b := ctx.get_ref(nodeB);
    mut nodeC_ref_program_b := ctx.get_ref(nodeC);

    nodeA_ref_program_b.Value = 10;
    nodeB_ref_program_b.Value = 20;
    nodeC_ref_program_b.Value = 30;

    nodeA_ref_program_b.Next = nodeB;
    nodeB_ref_program_b.Next = nodeC;
    nodeC_ref_program_b.Next = nodeA;

    mut curr := nodeA;
    mut count := 0;
    while count < 6 {
        os.LogInt(ctx[curr].Value);
        curr = ctx[curr].Next;
        count = count + 1;
    }
}
