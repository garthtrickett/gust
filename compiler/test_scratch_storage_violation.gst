type BrandedNode[ctx] struct {
    name: str
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut n: BrandedNode[ctx];
    n.name = std.Format("Item %d", 1);
}
