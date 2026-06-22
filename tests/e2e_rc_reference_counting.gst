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
    os.LogInt(rc1.node_index);
    
    unsafe {
        mut val_ptr := rc1.Get();
        os.LogInt((*val_ptr).val);
    }

    mut rc2 := rc1.Clone();
    os.LogInt(rc2.node_index);
    
    rc1.Release();
    
    mut item2: Node;
    item2.val = 100;
    
    mut rc3: std.Rc[Node, ctx] := std.RcNew(&pool, item2);
    os.LogInt(rc3.node_index);
    
    rc2.Release();
    
    mut rc4: std.Rc[Node, ctx] := std.RcNew(&pool, item2);
    os.LogInt(rc4.node_index);

    rc3.Release();
    rc4.Release();
}
