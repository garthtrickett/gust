type CustomNode struct {
    SessionID: int
}

func main() {
    mut payload := os.MockPayload();
    mut result := payload as &CustomNode;
    os.LogInt(result.Val.SessionID);
}