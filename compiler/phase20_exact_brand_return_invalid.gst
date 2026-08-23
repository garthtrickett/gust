type Phase20ExactReturnNode[ctx] struct { value: int }

func wrong_return(origin: &Arena, destination: &Arena) Index[Phase20ExactReturnNode, origin] {
    mut source: Index[Phase20ExactReturnNode, origin] := os.ArenaAlloc(origin);
    return std.Clone(destination, source);
}

func main() {}
