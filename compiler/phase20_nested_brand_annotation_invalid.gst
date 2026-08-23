// Patch 20.2 negative: a nested linear value from a distinct arena must be
// rejected exactly once without replacing the resolved declaration with Void.
func main() {
    mut inner_arena := os.Arena.New();
    defer inner_arena.Free();
    mut outer_arena := os.Arena.New();
    defer outer_arena.Free();
    mut values: std.Vector[std.Vector[str, inner_arena], outer_arena] := std.VectorNew(outer_arena);
}
