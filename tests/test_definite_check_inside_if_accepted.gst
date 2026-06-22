type CustomNode struct {
    SessionID: int
}
func main() {
    mut payload := os.MockPayload();
    mut result := payload as &CustomNode;
    if result.Ok {
        os.LogInt(result.Val.SessionID);
    }
}