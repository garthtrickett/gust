type Node struct {
    val: int
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut pool: std.Pool[Node, ctx] := std.PoolNew(ctx);
    pool.Free(42);
}