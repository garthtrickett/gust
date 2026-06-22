func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut vec: Vector[int, ctx] := os.VectorNew(ctx);
    vec.Push(10);
    mut movedCtx := move ctx;
    vec.Push(20);
}