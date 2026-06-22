type Node struct {
    val: int
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut graph: std.Graph[Node, ctx] := std.GraphNew(ctx);
    
    mut item1: Node; item1.val = 10;
    mut item2: Node; item2.val = 20;
    mut item3: Node; item3.val = 30;

    mut n1 := graph.AddNode(item1);
    mut n2 := graph.AddNode(item2);
    mut n3 := graph.AddNode(item3);

    graph.AddEdge(n1, n2);
    graph.AddEdge(n2, n3);
    graph.AddEdge(n3, n1);

    mut curr := n1;
    mut i := 0;
    while i < 6 {
        unsafe {
            mut val_ptr := graph.GetNode(curr);
            os.LogInt((*val_ptr).val);
        }
        curr = graph.nodes[curr].edges[0];
        i = i + 1;
    }
}