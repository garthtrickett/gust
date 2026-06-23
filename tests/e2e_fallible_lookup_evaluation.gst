func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
    map.Insert(100, 42);
    map.Insert(200, 84);

    // Existing key
    mut lookup1 := map.Get(100);
    mut ok1 := 0;
    if lookup1.Ok {
        ok1 = 1;
    }
    os.LogInt(ok1);
    if lookup1.Ok {
        os.LogInt(lookup1.Val);
    }

    // Non-existent key
    mut lookup2 := map.Get(300);
    mut ok2 := 0;
    if lookup2.Ok {
        ok2 = 1;
    }
    os.LogInt(ok2);
    if lookup2.Ok {
        os.LogInt(lookup2.Val);
    } else {
        os.LogInt(0);
    }
}
