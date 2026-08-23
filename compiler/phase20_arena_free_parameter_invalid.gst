// Patch 20.5: an arena parameter is one alias inside its function body.
func consume_then_reuse(ctx: Arena) {
    ctx.Free();
    mut copied := std.Clone(ctx, "freed");
}

func main() {}
