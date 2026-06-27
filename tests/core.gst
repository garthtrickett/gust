type CoreNode[ctx] struct {
    id: int
}
func make_core_node(ctx: &Arena) Index[CoreNode, ctx] {
    mut n: Index[CoreNode, ctx] := os.ArenaAlloc(ctx);
    mut node_ref := ctx.get_ref(n);
    node_ref.id = 100;
    return n;
}
