// Phase 19.8 structural brand-role parity, legacy-spelling arm.
type Phase19NameListHolder[ctx] struct {
    values: std.Vector[int, ctx]
}

func phase19_name_list_mutable_spelling() int {
    mut ctx: str := "x";
    ctx = "y";
    return len(ctx);
}

func phase19_name_list_value(ctx: &Arena) int {
    mut values: std.Vector[int, ctx] := std.VectorNew(ctx);
    values.Push(19);
    mut holder: Phase19NameListHolder[ctx];
    holder.values = values;
    return holder.values[0];
}

func main() int {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    if phase19_name_list_mutable_spelling() != 1 {
        return 1;
    }
    return phase19_name_list_value(&ctx);
}
