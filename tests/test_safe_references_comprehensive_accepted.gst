type MyNode struct {
    val: int
}
func print_val(r: &int) {
    os.LogInt(*r);
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    // 1. Reference to primitive stack variable
    mut x := 42;
    mut rx: &int := &x;
    os.LogInt(*rx);
    print_val(rx);

    // 2. Reference to struct field on stack
    mut n: MyNode;
    n.val = 100;
    mut rn_val: &int := &n.val;
    os.LogInt(*rn_val);

    // 3. Reference to heap-allocated data
    mut n_idx: Index[MyNode, ctx] := os.ArenaAlloc(ctx);
    ctx[n_idx].val = 200;
    mut rn_heap: &MyNode[ctx] := &ctx[n_idx];
    os.LogInt(rn_heap.val);
}