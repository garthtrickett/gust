func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut map: std.HashMap[int, int, ctx] := std.HashMapNew(ctx);
    map.Insert(42, 100);
    mut lookup := map.Get(42);
    
    mut is_ok: bool := lookup.Ok;
    if is_ok == true {
        os.LogInt(lookup.Val);
    }
}