// Patch 19.11 composes the Phase 19 brand and representation work with the
// collection, arena, reference, resource, call, ABI, and target authorities
// closed by Phases 14 through 18.
type Phase19CompositionNode[ctx] struct {
    value: int
}

func phase19_composed_call(origin: &Arena, destination: &Arena) int {
    guard directory := os.OpenDir(origin, ".") else { return 1; }

    mut nodes: std.Vector[Index[Phase19CompositionNode, origin], origin] := std.VectorNew(origin);
    mut source: Index[Phase19CompositionNode, origin] := os.ArenaAlloc(origin);
    mut source_ref := origin.get_ref(source);
    source_ref.value = 40;
    nodes.Push(source);

    mut cloned: Index[Phase19CompositionNode, destination] := std.Clone(destination, nodes[0]);
    mut cloned_ref := destination.get_ref(cloned);
    cloned_ref.value = cloned_ref.value + 2;

    os.CloseDir(directory);
    return cloned_ref.value;
}

func main() int {
    mut origin := os.Arena.New();
    defer origin.Free();
    mut destination := os.Arena.New();
    defer destination.Free();

    mut result := phase19_composed_call(&origin, &destination);
    if result != 42 { return 2; }
    return 91;
}
