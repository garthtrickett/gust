func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut values: std.Vector[int, ctx] := std.VectorNew(ctx);
    values.len = 4;
}
