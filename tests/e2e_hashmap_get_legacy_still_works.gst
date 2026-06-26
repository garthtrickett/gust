func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut map: std.HashMap[int, int, ctx] := std.HashMapNew(ctx);
    map.Insert(5, 555);

    mut legacy_hit := map.Get(5);
    if legacy_hit.Ok {
        os.LogInt(legacy_hit.Val);
    } else {
        os.LogStr("legacy miss");
    }

    mut legacy_miss := map.Get(99);
    if legacy_miss.Ok {
        os.LogInt(legacy_miss.Val);
    } else {
        os.LogStr("legacy miss");
    }
}