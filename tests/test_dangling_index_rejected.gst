type CustomNode[ctx] struct { SessionID: int }

func main() { 
    mut ctx := os.Arena.New();
    mut node: Index[CustomNode, ctx] := os.ArenaAlloc(ctx);
    mut movedCtx := move ctx;
    os.LogInt(node);
}