// Compile-fail: resolving methods through a reference must not weaken move
// tracking. The map is moved into consume, then used through a reference.
func consume(m: std.HashMap[str, int, ctx]) int { return len(m); }
func work(m: &std.HashMap[str, int, ctx]) int { return len(m); }
func main() {
    mut arena := os.Arena.New();
    defer arena.Free();
    mut m: std.HashMap[str, int, arena] := std.HashMapNew(arena);
    m.Insert("k", 1);
    os.LogInt(consume(move m));
    os.LogInt(work(&m));
}
