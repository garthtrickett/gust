func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut map_missing_ref: std.HashMap[int, int, ctx] := std.HashMapNew(ctx);
    map_missing_ref.Insert(1, 100);

    mut missing_ref := map_missing_ref.GetRef(2);
    os.LogInt(*missing_ref);
}