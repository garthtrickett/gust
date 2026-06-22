type Node struct {
    val: int
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut graph: std.Graph[Node, ctx] := std.GraphNew(ctx);
    mut item: Node;
    mut n1 := graph.AddNode(item);
    graph.AddEdge(n1, "not_an_int");
}