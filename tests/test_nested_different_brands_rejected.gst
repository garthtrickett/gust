func main() {
    mut innerCtx := os.Arena.New();
    defer innerCtx.Free();
    mut outerCtx := os.Arena.New();
    defer outerCtx.Free();
    mut vec: Vector[Vector[str, innerCtx], outerCtx] := os.VectorNew(outerCtx);
}