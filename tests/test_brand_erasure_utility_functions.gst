type Node[ctx] struct {
    name: str
}
func process(s: str) int {
    return std.str_eq(s, "test");
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut n: Index[Node, ctx] := os.ArenaAlloc(ctx);
    mut n_ref_brand_erasure := ctx.get_ref(n);
    n_ref_brand_erasure.name = "test";
    mut res := process(ctx[n].name);
    os.LogInt(res);
}
