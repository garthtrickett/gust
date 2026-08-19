// Stdlib S1.3: a helper taking a collection by reference resolves the same
// methods a value receiver resolves, and mutation through the reference is
// visible to the caller.
//
// Before this, every method call on a `&std.HashMap[...]` receiver failed with
// "Undefined function 'm.Get'", which is what GEMINI.md section D deferred.

func lookup(m: &std.HashMap[str, int, ctx]) int {
    mut r := m.Get("k");
    if r.Ok {
        return r.Val;
    }
    return 0;
}

func add(m: &std.HashMap[str, int, ctx], v: int) {
    m.Insert("added", v);
}

func size(m: &std.HashMap[str, int, ctx]) int {
    return len(m);
}

func main() {
    mut arena := os.Arena.New();
    defer arena.Free();
    mut m: std.HashMap[str, int, arena] := std.HashMapNew(arena);
    m.Insert("k", 7);

    os.LogInt(lookup(&m));
    add(&m, 5);
    os.LogInt(size(&m));

    mut r2 := m.Get("added");
    if r2.Ok {
        os.LogInt(r2.Val);
    }
    os.LogStr("SUCCESS: HashMap reference receiver");
}
