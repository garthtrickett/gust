type MyLinear struct {
    ptr: *int
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut vec: Vector[MyLinear, ctx] := os.VectorNew(ctx);
}