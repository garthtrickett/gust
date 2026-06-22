type Container[T, ctx] struct {
    value: T
}

func main() {
    mut innerCtx := os.Arena.New();
    defer innerCtx.Free();
    mut outerCtx := os.Arena.New();
    defer outerCtx.Free();
    mut vec: Container[std.Vector[str, innerCtx], outerCtx] := empty[Container[std.Vector[str, innerCtx], outerCtx]];
}