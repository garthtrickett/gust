type CustomNode[ctx] struct { SessionID: int }
func main() {
    mut ctx1 := os.Arena.New();
    defer ctx1.Free();
    mut ctx2 := os.Arena.New();
    defer ctx2.Free();
    mut node: Index[CustomNode, ctx1] := os.ArenaAlloc(ctx1);
    mut bad_ref_lifetime := ctx2.get_ref(node);
    bad_ref_lifetime.SessionID = 42;
}
