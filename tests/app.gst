import "lib.gst" as lib;
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut c: lib.Container[int, ctx] := lib.make_container(ctx, 42);
    os.LogInt(c.val);
    os.LogInt(ctx[c.node].id);
}