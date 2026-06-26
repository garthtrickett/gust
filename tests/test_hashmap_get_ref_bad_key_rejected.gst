func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut map_bad_key_ref: std.HashMap[int, int, ctx] := std.HashMapNew(ctx);
    map_bad_key_ref.Insert(1, 10);

    mut bad_key_ref := map_bad_key_ref.GetRef("not an int key");
    os.LogInt(*bad_key_ref);
}