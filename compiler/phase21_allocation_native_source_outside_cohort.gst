type Phase21OutsideCell struct {
    value: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut node: Index[Phase21OutsideCell, ctx] := os.ArenaAlloc(ctx);
    mut initial: Phase21OutsideCell;
    initial.value = 48 + 1;
    ctx.Set(node, initial);
    os.LogInt(ctx[node].value);
}
