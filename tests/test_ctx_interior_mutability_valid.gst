type Node[ctx] struct {
    val: int
}

func allocate_node(ctx: Arena) Index[Node, ctx] {
    mut n: Index[Node, ctx] := os.ArenaAlloc(ctx);
    ctx[n].val = 42;
    return n;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut n := allocate_node(ctx);
    os.LogInt(ctx[n].val);
}
type Node[ctx] struct {
    val: int
}

func allocate_node(ctx: Arena) Index[Node, ctx] {
    mut n: Index[Node, ctx] := os.ArenaAlloc(ctx);
    ctx[n].val = 42;
    return n;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut n := allocate_node(ctx);
    os.LogInt(ctx[n].val);
}
