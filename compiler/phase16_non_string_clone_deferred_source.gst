// Cloning an arena index needs generic deep-copy semantics that the native
// std_Clone_str runtime entry point cannot provide.
type Phase16CloneNode[ctx] struct { value: int }

func clone_node(destination: &Arena) {
    mut source_arena := os.Arena.New();
    defer source_arena.Free();
    mut source: Index[Phase16CloneNode[source_arena], source_arena] :=
        os.ArenaAlloc(&source_arena);
    mut cloned := std.Clone(destination, source);
    mut value := destination.get_ref(cloned);
    os.LogInt(value.value);
}

func main() {
    mut destination_arena := os.Arena.New();
    defer destination_arena.Free();
    clone_node(&destination_arena);
}
