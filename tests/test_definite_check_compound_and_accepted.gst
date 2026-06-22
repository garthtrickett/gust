type CustomNode struct {
    SessionID: int
}
func main() {
    mut payload := os.MockPayload();
    mut result := payload as &CustomNode;
    mut cond := true;
    if cond && result.Ok {
        os.LogInt(result.Val.SessionID);
    }
}