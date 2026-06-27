type MyNode[ctx] struct {
    id: int,
    name: str,
    next: Index[MyNode, ctx]
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    // 1. Format nested strings inside a loop
    mut i := 0;
    while i < 3 {
        mut s_num := std.FormatInt(i);
        mut greeting := std.Concat("Num: ", s_num);
        mut formatted := std.Format("Loop %s - %s", greeting, "ok");
        os.LogStr(formatted);
        os.ScratchReset();
        i = i + 1;
    }

    // 2. Clone an AST node between two different arenas
    mut current_ctx := os.Arena.New();
    defer current_ctx.Free();
    mut next_ctx := os.Arena.New();
    defer next_ctx.Free();

    mut node: Index[MyNode, current_ctx] := os.ArenaAlloc(current_ctx);
    mut node_ref_formatting := current_ctx.get_ref(node);
    node_ref_formatting.id = 42;
    node_ref_formatting.name = "root_node";
    node_ref_formatting.next = null;

    mut cloned: Index[MyNode, next_ctx] := std.Clone(next_ctx, node);
    os.LogInt(next_ctx[cloned].id);
    os.LogStr(next_ctx[cloned].name);

    // 3. Generational swap test
    std.GenerationalSwap(current_ctx, next_ctx);
    os.LogInt(current_ctx[cloned].id);
    os.LogStr(current_ctx[cloned].name);
}
