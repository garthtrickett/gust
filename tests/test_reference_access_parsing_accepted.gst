type MyNode struct {
    val: int
}

func dummy_test(ctx: &Arena) {
    // Positive smoke coverage for explicit reference-access method calls.
    // These selectors are now parsed, typechecked, and code-generated as safe
    // branded references, so this test should compile and run cleanly.
    mut node_idx: Index[MyNode, ctx] := os.ArenaAlloc(ctx);
    mut node_ref := ctx.get_ref(node_idx);
    node_ref.val = 41;
    node_ref.val = node_ref.val + 1;

    mut vec: std.Vector[MyNode, ctx] := std.VectorNew(ctx);
    mut item: MyNode;
    item.val = 7;
    vec.Push(item);
    mut vec_ref := vec.GetRef(0);
    vec_ref.val = vec_ref.val + 1;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    dummy_test(ctx);
}
