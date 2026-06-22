type CustomNode struct {
    SessionID: int
}
func main() {
    mut payload := os.MockPayload();
    mut result := payload as &CustomNode;
    mut cond := true;
    if cond {
        if result.Ok {
            os.LogInt(result.Val.SessionID);
        }
        os.LogInt(result.Val.SessionID);
    }
}