type Node struct {
    val: int
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut pool: std.Pool[std.RcNode[Node], ctx] := std.PoolNew(ctx);
    mut item: Node;
    mut rc := std.RcNew(&pool, item);
}
