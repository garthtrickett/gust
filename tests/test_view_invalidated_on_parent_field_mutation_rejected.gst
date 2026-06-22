type Packet[ctx] struct {
    val: int
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut payload: Packet[ctx];
    payload.val = 42;
    mut view := &payload;
    payload.val = 100;
    unsafe {
        mut deref := *view;
        os.LogInt(deref.val);
    }
}