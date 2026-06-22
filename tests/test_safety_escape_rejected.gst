type CustomNode[ctx] struct {
    val: int
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut payload := os.MockPayload();
    mut result := payload as &CustomNode[ctx];
    mut movedPayload := move payload;
    if result.Ok {
        os.LogInt(result.Val.val);
    }
}