type Node struct {
    val: int
}
func main() {
    mut ctx1 := os.Arena.New();
    defer ctx1.Free();
    mut ctx2 := os.Arena.New();
    defer ctx2.Free();
    mut pool1: std.Pool[std.RcNode[Node], ctx1] := std.PoolNew(ctx1);
    mut item: Node;
    mut rc: std.Rc[Node, ctx2] := std.RcNew(&pool1, item); 
}