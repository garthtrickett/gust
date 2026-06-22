type Packet[ctx] struct {
    data: str
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut p: Packet[ctx];
    p.data = std.Format("Item %d", 1);
    std.Yield();
}