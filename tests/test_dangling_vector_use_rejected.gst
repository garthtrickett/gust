func main() {
    mut ctx := os.Arena.New();
    mut vec: Vector[int, ctx] := os.VectorNew(ctx);
    mut movedCtx := move ctx;
    vec.Push(10);
}