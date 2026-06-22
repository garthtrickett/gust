type Holder[T, ctx] struct {
    val: T
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut h: Holder[str, ctx];
}