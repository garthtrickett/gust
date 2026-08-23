type Phase20ExactAssignmentNode[ctx] struct { value: int }

func main() {
    mut origin := os.Arena.New();
    defer origin.Free();
    mut destination := os.Arena.New();
    defer destination.Free();
    mut source: Index[Phase20ExactAssignmentNode, origin] := os.ArenaAlloc(origin);
    mut wrong: Index[Phase20ExactAssignmentNode, origin] := source;
    wrong = std.Clone(destination, source);
}
