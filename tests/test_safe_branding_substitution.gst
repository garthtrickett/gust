type Node[ctx] struct { val: int }
func update(ctx: &Arena, n: Index[Node, ctx]) {
    mut n_ref_brand_substitution := ctx.get_ref(n);
    n_ref_brand_substitution.val = 100;
}
func main() {
    mut c := os.Arena.New();
    defer c.Free();
    mut n: Index[Node, c] := os.ArenaAlloc(c);
    update(c, n);
}
