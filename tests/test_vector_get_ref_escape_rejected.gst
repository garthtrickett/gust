type VecRefNode struct {
    val: int
}

func leak_vector_ref(ctx: &Arena) &VecRefNode[ctx] {
    mut local_vec: std.Vector[VecRefNode, ctx] := std.VectorNew(ctx);

    mut node_val: VecRefNode;
    node_val.val = 77;
    local_vec.Push(node_val);

    mut leaked_ref := local_vec.GetRef(0);
    return leaked_ref;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut bad_ref := leak_vector_ref(&ctx);
    os.LogInt(bad_ref.val);
}