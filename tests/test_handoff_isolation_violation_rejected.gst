type Packet[ctx] struct {
    data: []byte
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut local := os.MockPayload();
    mut p: Packet[ctx];
    p.data = local;
    mut movedCtx := move ctx;
}