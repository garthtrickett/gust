type Node struct {
    val: int,
    next: Index[Node, ctx]
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut arena: std.GenerationalArena[Node, ctx];
    arena.current_ctx = os.Arena.New();
    defer arena.current_ctx.Free();
    arena.next_ctx = os.Arena.New();
    defer arena.next_ctx.Free();

    arena.survivor = os.ArenaAlloc(arena.current_ctx);
    arena.current_ctx[arena.survivor].val = 0;
    arena.current_ctx[arena.survivor].next = null;

    mut i := 0;
    while i < 1000 {
        mut temp: Index[Node, arena.current_ctx] := os.ArenaAlloc(arena.current_ctx);
        arena.current_ctx[temp].val = i;

        mut new_child: Index[Node, arena.current_ctx] := os.ArenaAlloc(arena.current_ctx);
        arena.current_ctx[new_child].val = i * 2;
        arena.current_ctx[new_child].next = null;

        arena.current_ctx[arena.survivor].next = new_child;
        arena.current_ctx[arena.survivor].val = arena.current_ctx[arena.survivor].val + arena.current_ctx[temp].val;

        arena.Step();

        i = i + 1;
    }

    os.LogInt(arena.current_ctx[arena.survivor].val);
    mut child_idx := arena.current_ctx[arena.survivor].next;
    os.LogInt(arena.current_ctx[child_idx].val);
}