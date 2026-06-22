type CustomNode[connCtx] struct {
    SessionID: int,
    Active: int
}

func updateNode(ctx: &Arena, node: Index[CustomNode, ctx]) {
    ctx[node].SessionID = 100;
}

func main() {
    mut connCtx := os.Arena.New();
    defer connCtx.Free();
    
    mut node: Index[CustomNode, connCtx] := os.ArenaAlloc(connCtx);
    connCtx[node].SessionID = 42;
    
    updateNode(connCtx, node);
    
    os.LogInt(connCtx[node].SessionID);

    mut msg := "Hello Arena";
    os.LogStr(msg);
    os.LogInt(len(msg));
}