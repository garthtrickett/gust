type Node[ctx] struct {
    val: int
}

func allocate_node(ctx: Arena) Index[Node, ctx] {
    mut n: Index[Node, ctx] := os.ArenaAlloc(ctx);
    mut n_ref_ctx_interior := ctx.get_ref(n);
    n_ref_ctx_interior.val = 42;
    return n;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut n := allocate_node(ctx);
    os.LogInt(ctx[n].val);
}
