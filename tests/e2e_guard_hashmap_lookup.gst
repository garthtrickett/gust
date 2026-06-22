func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut map: std.HashMap[int, int, ctx] := os.HashMapNew(ctx);
    map.Insert(42, 100);

    guard val := map.Get(42) else {
        os.LogInt(0);
        return;
    }

    os.LogInt(val);
}