func main() {
    mut arena := os.Arena.New();
    defer arena.Free();
    mut m: std.HashMap[str, int, arena] := std.HashMapNew(arena);
    m.Insert("k", 7);
    mut r := m.Get("k");
    if r.Ok { os.LogInt(r.Val); }
    os.LogInt(len(m));
}
