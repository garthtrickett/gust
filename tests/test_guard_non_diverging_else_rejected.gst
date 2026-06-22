func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
    mut dummy := 0;
    guard val := map.Get(42) else {
        dummy = 100;
    }
}