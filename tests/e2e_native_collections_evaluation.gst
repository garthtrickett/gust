func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut vec: Vector[int, ctx] := os.VectorNew(ctx);
    vec.Push(10);
    vec.Push(20);
    vec.Push(30);

    os.LogInt(len(vec));
    os.LogInt(vec[0]);
    os.LogInt(vec[1]);
    os.LogInt(vec[2]);

    mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
    map.Insert(100, 42);
    map.Insert(200, 84);

    os.LogInt(len(map));
    os.LogInt(map[100]);
    os.LogInt(map[200]);

    // Explicit write API replacement for legacy subscript assignment.
    map.Set(100, 999);
    os.LogInt(map[100]);
}
