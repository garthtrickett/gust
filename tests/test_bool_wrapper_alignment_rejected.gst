func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut map: std.HashMap[int, int, ctx] := std.HashMapNew(ctx);
    mut lookup := map.Get(42);
    if lookup.Ok == 0 {
        os.LogInt(1);
    }
}