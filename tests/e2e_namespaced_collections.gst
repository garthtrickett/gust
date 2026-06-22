func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut v: std.Vector[int, ctx] := std.VectorNew(ctx);
    v.Push(111);
    v.Push(222);

    os.LogInt(len(v));
    os.LogInt(v[0]);
    os.LogInt(v[1]);

    mut m: std.HashMap[int, int, ctx] := std.HashMapNew(ctx);
    m.Insert(10, 888);
    m.Insert(20, 999);

    os.LogInt(len(m));
    os.LogInt(m[10]);
    os.LogInt(m[20]);
}