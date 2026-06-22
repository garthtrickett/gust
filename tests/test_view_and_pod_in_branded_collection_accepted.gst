func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut v1: Vector[str, ctx] := os.VectorNew(ctx);
    mut v2: Vector[int, ctx] := os.VectorNew(ctx);
}