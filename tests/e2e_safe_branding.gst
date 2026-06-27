type CustomNode[connCtx] struct {
    SessionID: int,
    Active: int
}

func updateNode(ctx: &Arena, node: Index[CustomNode, ctx]) {
    mut node_ref_update := ctx.get_ref(node);
    node_ref_update.SessionID = 100;
}

func main() {
    mut connCtx := os.Arena.New();
    defer connCtx.Free();
    
    mut node: Index[CustomNode, connCtx] := os.ArenaAlloc(connCtx);
    mut node_ref_main := connCtx.get_ref(node);
    node_ref_main.SessionID = 42;
    
    updateNode(connCtx, node);
    
    os.LogInt(connCtx[node].SessionID);

    mut msg := "Hello Arena";
    os.LogStr(msg);
    os.LogInt(len(msg));
}
