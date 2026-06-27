type Node[ctx] struct {
    val: int
}

func main() {
    mut current_ctx := os.Arena.New();
    defer current_ctx.Free();
    mut next_ctx := os.Arena.New();
    defer next_ctx.Free();

    mut survivor: Index[Node, current_ctx] := os.ArenaAlloc(current_ctx);
    mut survivor_ref_loop := current_ctx.get_ref(survivor);
    survivor_ref_loop.val = 0;

    mut i := 0;
    while i < 1000 {
        mut temp: Index[Node, current_ctx] := os.ArenaAlloc(current_ctx);
        mut temp_ref_loop := current_ctx.get_ref(temp);
        temp_ref_loop.val = i;

        mut cloned_survivor: Index[Node, next_ctx] := std.Clone(next_ctx, survivor);
        mut cloned_survivor_ref_loop := next_ctx.get_ref(cloned_survivor);
        cloned_survivor_ref_loop.val = cloned_survivor_ref_loop.val + current_ctx[temp].val;

        std.GenerationalSwap(current_ctx, next_ctx);

        survivor = cloned_survivor;

        i = i + 1;
    }

    os.LogInt(current_ctx[survivor].val);
}
