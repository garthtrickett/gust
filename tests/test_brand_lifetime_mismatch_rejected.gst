type CustomNode[ctx] struct { SessionID: int }
func main() {
    mut ctx1 := os.Arena.New();
    defer ctx1.Free();
    mut ctx2 := os.Arena.New();
    defer ctx2.Free();
    mut node: Index[CustomNode, ctx1] := os.ArenaAlloc(ctx1);
    ctx2[node].SessionID = 42;
}