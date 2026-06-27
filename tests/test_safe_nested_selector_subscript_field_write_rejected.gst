type NestedSubscriptWriteNode struct {
    val: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut arena: std.GenerationalArena[NestedSubscriptWriteNode, ctx];
    arena.current_ctx = os.Arena.New();
    defer arena.current_ctx.Free();
    arena.next_ctx = os.Arena.New();
    defer arena.next_ctx.Free();

    arena.survivor = os.ArenaAlloc(arena.current_ctx);
    mut survivor_ref := arena.current_ctx.get_ref(arena.survivor);
    survivor_ref.val = 1;

    // Step 4.5C: selector-rooted arena subscript writes are still direct subscript writes.
    arena.current_ctx[arena.survivor].val = 2;
}