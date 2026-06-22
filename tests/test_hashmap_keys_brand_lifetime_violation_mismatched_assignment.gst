func main() {
    mut ctx1 := os.Arena.New();
    defer ctx1.Free();
    mut ctx2 := os.Arena.New();
    defer ctx2.Free();
    mut map: HashMap[int, int, ctx1] := os.HashMapNew(ctx1);
    mut keys: std.Vector[int, ctx2] := map.Keys(ctx1); 
}