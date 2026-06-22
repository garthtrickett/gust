type Node[ctx] struct {
    val: int
}

func main() {
    mut current_ctx := os.Arena.New();
    defer current_ctx.Free();
    mut next_ctx := os.Arena.New();
    defer next_ctx.Free();

    mut survivor: Index[Node, current_ctx] := os.ArenaAlloc(current_ctx);
    current_ctx[survivor].val = 0;

    mut i := 0;
    while i < 1000 {
        mut temp: Index[Node, current_ctx] := os.ArenaAlloc(current_ctx);
        current_ctx[temp].val = i;

        mut cloned_survivor: Index[Node, next_ctx] := std.Clone(next_ctx, survivor);
        next_ctx[cloned_survivor].val = next_ctx[cloned_survivor].val + current_ctx[temp].val;

        std.GenerationalSwap(current_ctx, next_ctx);

        survivor = cloned_survivor;

        i = i + 1;
    }

    os.LogInt(current_ctx[survivor].val);
}