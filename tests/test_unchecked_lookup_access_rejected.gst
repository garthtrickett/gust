func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
    mut lookup := map.Get(42);
    os.LogInt(lookup.Val);
}