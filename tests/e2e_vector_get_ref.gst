func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut vec_ref: std.Vector[int, ctx] := std.VectorNew(ctx);
    vec_ref.Push(10);
    vec_ref.Push(20);
    vec_ref.Push(30);

    mut elem_ref := vec_ref.GetRef(1);
    os.LogInt(*elem_ref);

    *elem_ref = 42;
    os.LogInt(vec_ref[1]);

    // Runtime negative half: this should trip the generated bounds check.
    vec_ref.GetRef(99);
}