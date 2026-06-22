type Node struct {
    val: int
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut pool: std.Pool[Node, ctx] := std.PoolNew(ctx);
    mut item: Node;
    item.val = 42;
    mut idx := pool.Alloc(item);
    pool.Free(idx);
}