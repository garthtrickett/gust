func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut vec_alias_bad_index: std.Vector[int, ctx] := std.VectorNew(ctx);
    vec_alias_bad_index.Push(1);

    mut bad_ref := std.VectorGetRef(vec_alias_bad_index, "not an index");
    unsafe {
        os.LogInt(*bad_ref);
    }
}
