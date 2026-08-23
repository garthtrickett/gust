// Compile-fail: a collection branded for one arena cannot accept an element
// whose value identity belongs to another arena.
type S1ForeignItem[ctx] struct {
    value: int
}

func main() {
    mut collection_arena := os.Arena.New();
    defer collection_arena.Free();
    mut foreign_arena := os.Arena.New();
    defer foreign_arena.Free();

    mut values: std.Vector[Index[S1ForeignItem, collection_arena], collection_arena] := std.VectorNew(collection_arena);
    mut foreign_value: Index[S1ForeignItem, foreign_arena] := os.ArenaAlloc(foreign_arena);
    values.Push(foreign_value);
}
