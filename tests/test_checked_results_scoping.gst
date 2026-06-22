type CustomNode[connCtx] struct {
    SessionID: int
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut payload := os.MockPayload();
    mut result := payload as &CustomNode[ctx];
    if result.Ok {
        os.LogInt(result.Val.SessionID);
    }
}