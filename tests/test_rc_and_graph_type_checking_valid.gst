type Node struct {
    val: int
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut pool: std.Pool[std.RcNode[Node], ctx] := std.PoolNew(ctx);
    mut item: Node;
    item.val = 42;
    mut rc1: std.Rc[Node, ctx] := std.RcNew(&pool, item);
    mut rc2 := rc1.Clone();
    unsafe {
        mut val_ptr := rc1.Get();
    }
    rc2.Release();
    rc1.Release();
    mut graph: std.Graph[Node, ctx] := std.GraphNew(ctx);
    mut n1 := graph.AddNode(item);
    mut n2 := graph.AddNode(item);
    graph.AddEdge(n1, n2);
}