func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
    mut keys := map.Keys(42);
}