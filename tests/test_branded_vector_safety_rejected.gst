type Node[ctx] struct { val: int }
func main() {
    mut ctx1 := os.Arena.New();
    defer ctx1.Free();
    mut ctx2 := os.Arena.New();
    defer ctx2.Free();
    mut vec: Vector[Index[Node, ctx1], ctx1] := os.VectorNew(ctx1);
    mut n: Index[Node, ctx1] := os.ArenaAlloc(ctx1);
    vec.Push(n);
    mut bad_ref_vector_brand := ctx2.get_ref(vec[0]);
    bad_ref_vector_brand.val = 100;
}
