type InnerNode struct {
    val: int
}
type OuterNode struct {
    inner: LookupResult_InnerNode
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut map: HashMap[int, OuterNode, ctx] := os.HashMapNew(ctx);
    mut outer := map.Get(42);
    if outer.Ok {
        os.LogInt(outer.Val.inner.Val.val);
    }
}