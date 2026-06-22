func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut vec: Vector[Vector[str, ctx], ctx] := os.VectorNew(ctx);
}