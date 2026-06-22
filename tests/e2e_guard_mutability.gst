func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut map: std.HashMap[int, int, ctx] := os.HashMapNew(ctx);
    map.Insert(10, 50);

    guard mut val := map.Get(10) else {
        return;
    }

    val = val + 50;
    os.LogInt(val);
}