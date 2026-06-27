type MyNode struct {
    val: int
}
func main() {
    mut ctx1 := os.Arena.New();
    defer ctx1.Free();
    mut ctx2 := os.Arena.New();
    defer ctx2.Free();

    mut n1: Index[MyNode, ctx1] := os.ArenaAlloc(ctx1);
    unsafe {
        mut r_ctx1: &MyNode[ctx1] := &ctx1[n1];

        // Reject: Assigning a reference branded with ctx1 to a reference branded with ctx2
        mut r_ctx2: &MyNode[ctx2] := r_ctx1;
    }
}
