type VectorReadCopyNode struct {
    val: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut nodes: std.Vector[VectorReadCopyNode, ctx] := std.VectorNew(ctx);

    mut stored_node: VectorReadCopyNode;
    stored_node.val = 22;
    nodes.Push(stored_node);

    mut local_copy := nodes[0];
    local_copy.val = 77;

    // Vector subscript read is copy-by-default: local mutation should not affect storage.
    os.LogInt(nodes[0].val);

    nodes.Set(0, local_copy);

    // Explicit write-back is required to update vector storage.
    os.LogInt(nodes[0].val);
}