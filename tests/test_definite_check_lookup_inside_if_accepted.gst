func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut map: std.HashMap[int, int, ctx] := os.HashMapNew(ctx);
    map.Insert(42, 100);
    mut lookup := map.Get(42);
    if lookup.Ok {
        os.LogInt(lookup.Val);
    }
}