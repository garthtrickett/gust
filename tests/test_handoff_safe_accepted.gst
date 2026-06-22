type Packet[ctx] struct {
    val: int
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut p: Packet[ctx];
    p.val = 42;
    mut movedCtx := move ctx;
}