type CustomNode struct {
    SessionID: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut map: std.HashMap[int, CustomNode, ctx] := std.HashMapNew(ctx);
    
    mut node: CustomNode;
    node.SessionID = 1337;
    map.Insert(42, node);

    mut lookup := map.Get(42);
    mut cond := true;
    if cond && lookup.Ok {
        os.LogInt(lookup.Val.SessionID);
    } else {
        os.LogInt(0);
    }
}
type CustomNode struct {
    SessionID: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut map: std.HashMap[int, CustomNode, ctx] := std.HashMapNew(ctx);
    
    mut node: CustomNode;
    node.SessionID = 1337;
    map.Insert(42, node);

    mut lookup := map.Get(42);
    mut cond := true;
    if cond && lookup.Ok {
        os.LogInt(lookup.Val.SessionID);
    } else {
        os.LogInt(0);
    }
}
