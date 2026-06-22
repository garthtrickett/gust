func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
    map.Insert(100, 42);
    map.Insert(200, 84);

    // Existing key
    mut lookup1 := map.Get(100);
    os.LogInt(lookup1.Ok);
    if lookup1.Ok {
        os.LogInt(lookup1.Val);
    }

    // Non-existent key
    mut lookup2 := map.Get(300);
    os.LogInt(lookup2.Ok);
    if lookup2.Ok {
        os.LogInt(lookup2.Val);
    } else {
        os.LogInt(0);
    }
}
