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
    mut survivor_ref_wrapper_initial := arena.current_ctx.get_ref(arena.survivor);
    survivor_ref_wrapper_initial.val = 0;
    survivor_ref_wrapper_initial.next = null;

    mut i := 0;
    while i < 1000 {
        mut temp: Index[Node, arena.current_ctx] := os.ArenaAlloc(arena.current_ctx);
        mut temp_ref_wrapper_loop := arena.current_ctx.get_ref(temp);
        temp_ref_wrapper_loop.val = i;

        mut new_child: Index[Node, arena.current_ctx] := os.ArenaAlloc(arena.current_ctx);
        mut new_child_ref_wrapper_loop := arena.current_ctx.get_ref(new_child);
        new_child_ref_wrapper_loop.val = i * 2;
        new_child_ref_wrapper_loop.next = null;

        mut survivor_ref_wrapper_loop := arena.current_ctx.get_ref(arena.survivor);
        survivor_ref_wrapper_loop.next = new_child;
        survivor_ref_wrapper_loop.val = survivor_ref_wrapper_loop.val + temp_ref_wrapper_loop.val;

        arena.Step();

        i = i + 1;
    }

    os.LogInt(arena.current_ctx[arena.survivor].val);
    mut child_idx := arena.current_ctx[arena.survivor].next;
    os.LogInt(arena.current_ctx[child_idx].val);
}
