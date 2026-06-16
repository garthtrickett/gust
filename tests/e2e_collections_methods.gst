func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    // Vector checks
    mut vec: std.Vector[int, ctx] := std.VectorNew(ctx);
    vec.Push(10);
    vec.Push(20);
    vec.Push(30);

    os.LogInt(len(vec)); // Expected: 3

    unsafe {
        mut back := vec.Back();
        os.LogInt(*back); // Expected: 30
    }

    os.LogInt(vec.Pop()); // Expected: 30
    os.LogInt(len(vec)); // Expected: 2

    vec.Clear();
    os.LogInt(len(vec)); // Expected: 0

    // HashMap checks
    mut map: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
    map.Insert("apple", 100);
    map.Insert("banana", 200);

    os.LogInt(len(map)); // Expected: 2

    mut lookup1 := map.Get("apple");
    if lookup1.Ok {
        os.LogInt(lookup1.Val); // Expected: 100
    }

    mut lookup2 := map.Get("banana");
    if lookup2.Ok {
        os.LogInt(lookup2.Val); // Expected: 200
    }

    mut lookup3 := map.Get("cherry");
    if lookup3.Ok {
        os.LogInt(lookup3.Val);
    } else {
        os.LogInt(0); // Expected: 0
    }

    // Keys collection check
    mut keys := map.Keys(ctx);
    os.LogInt(len(keys)); // Expected: 2

    mut k1 := keys[0];
    mut k2 := keys[1];
    if std.str_eq(k1, "apple") {
        os.LogStr(k1);
        os.LogStr(k2);
    } else {
        os.LogStr(k2);
        os.LogStr(k1);
    }

    map.Remove("apple");
    os.LogInt(len(map)); // Expected: 1

    map.Clear();
    os.LogInt(len(map)); // Expected: 0
}