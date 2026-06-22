type Packet struct {
    val: int
}
func main() {
    mut payload := os.MockPayload();
    guard result := payload as &Packet else {
        return;
    }
    mut moved_payload := move payload;
    os.LogInt(result.val);
}