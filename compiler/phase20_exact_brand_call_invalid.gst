type Phase20ExactCallNode[ctx] struct { value: int }

func accept_same_brand(first: Index[Phase20ExactCallNode, ctx], second: Index[Phase20ExactCallNode, ctx]) {}

func main() {
    mut origin := os.Arena.New();
    defer origin.Free();
    mut destination := os.Arena.New();
    defer destination.Free();
    mut source: Index[Phase20ExactCallNode, origin] := os.ArenaAlloc(origin);
    accept_same_brand(source, std.Clone(destination, source));
}
