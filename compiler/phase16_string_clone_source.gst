// The native std.Clone runtime entry point is qualified for Str values.
func clone_text(destination: &Arena) {
    mut cloned := std.Clone(destination, "native string clone");
    os.LogStr(cloned);
}

func main() {
    mut arena := os.Arena.New();
    defer arena.Free();
    clone_text(&arena);
    os.LogStr("SUCCESS: native string clone");
}
