func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut values: std.Vector[int, ctx];
    values.Push(1);
}
