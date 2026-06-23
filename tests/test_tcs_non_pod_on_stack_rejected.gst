type NonPod[ctx] struct {
    vec: std.Vector[int, ctx]
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut x: NonPod[ctx];
}