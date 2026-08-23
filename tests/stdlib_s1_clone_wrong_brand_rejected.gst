// Compile-fail: Clone's result belongs to the destination arena and cannot be
// assigned back to an Index branded for the source arena.
type S1CloneWrongBrandNode[ctx] struct {
    value: int
}

func main() {
    mut source_arena := os.Arena.New();
    defer source_arena.Free();
    mut destination_arena := os.Arena.New();
    defer destination_arena.Free();

    mut source: Index[S1CloneWrongBrandNode, source_arena] := os.ArenaAlloc(source_arena);
    mut wrong: Index[S1CloneWrongBrandNode, source_arena] := std.Clone(destination_arena, source);
}
