func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut vec: std.Vector[int, ctx] := std.VectorNew(ctx);
    vec.Push(10);
    unsafe {
        mut ptr: *int := vec.Back();
        *ptr = 20;
    }
    os.LogInt(vec[0]);
}