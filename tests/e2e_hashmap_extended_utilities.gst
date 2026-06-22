func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
    map.Insert(10, 100);
    map.Insert(20, 200);
    map.Insert(30, 300);

    mut keys: std.Vector[int, ctx] := map.Keys(ctx);
    os.LogInt(len(keys));

    mut sum := 0;
    mut i := 0;
    while i < len(keys) {
        mut key := keys[i];
        mut lookup := map.Get(key);
        if lookup.Ok {
            sum = sum + lookup.Val;
        }
        i = i + 1;
    }
    os.LogInt(sum);

    map.Remove(20);
    os.LogInt(len(map));

    mut lookup_removed := map.Get(20);
    if lookup_removed.Ok {
        os.LogInt(1);
    }
    else {
        os.LogInt(0);
    }

    map.Clear();
    os.LogInt(len(map));
}