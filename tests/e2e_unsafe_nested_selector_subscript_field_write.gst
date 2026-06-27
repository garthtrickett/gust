type UnsafeNestedSubscriptWriteNode struct {
    val: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut arena: std.GenerationalArena[UnsafeNestedSubscriptWriteNode, ctx];
    arena.current_ctx = os.Arena.New();
    defer arena.current_ctx.Free();
    arena.next_ctx = os.Arena.New();
    defer arena.next_ctx.Free();

    arena.survivor = os.ArenaAlloc(arena.current_ctx);
    mut survivor_ref := arena.current_ctx.get_ref(arena.survivor);
    survivor_ref.val = 1;

    // Step 4.5C: selector-rooted arena subscript writes remain legal inside unsafe blocks.
    unsafe {
        arena.current_ctx[arena.survivor].val = 2;
    }

    mut got := arena.current_ctx[arena.survivor];
    if got.val != 2 {
        os.Exit(1);
    }
}