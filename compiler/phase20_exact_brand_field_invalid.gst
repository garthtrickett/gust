type Phase20ExactFieldNode[ctx] struct { value: int }
type Phase20ExactFieldHolder[ctx] struct { node: Index[Phase20ExactFieldNode, ctx] }

func main() {
    mut origin := os.Arena.New();
    defer origin.Free();
    mut destination := os.Arena.New();
    defer destination.Free();
    mut source: Index[Phase20ExactFieldNode, origin] := os.ArenaAlloc(origin);
    mut holder: Phase20ExactFieldHolder[origin];
    holder.node = std.Clone(destination, source);
}
