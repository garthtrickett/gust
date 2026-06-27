type Node[ctx] struct { val: int }
func main() {
    mut ctx1 := os.Arena.New();
    defer ctx1.Free();
    mut ctx2 := os.Arena.New();
    defer ctx2.Free();
    mut n1: Index[Node, ctx1] := os.ArenaAlloc(ctx1);
    mut n1_ref_brand_crossing := ctx1.get_ref(n1);
    n1_ref_brand_crossing.val = 42;
    mut n2: Index[Node, ctx2] := std.Clone(ctx2, n1);
    mut n2_ref_brand_crossing := ctx2.get_ref(n2);
    n2_ref_brand_crossing.val = 100;
}
