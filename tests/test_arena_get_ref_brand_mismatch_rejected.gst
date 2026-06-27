type BrandNode struct {
    val: int
}

func main() {
    mut ctx_left := os.Arena.New();
    defer ctx_left.Free();

    mut ctx_right := os.Arena.New();
    defer ctx_right.Free();

    mut left_idx: Index[BrandNode, ctx_left] := os.ArenaAlloc(ctx_left);
    mut left_ref_brand_setup := ctx_left.get_ref(left_idx);
    left_ref_brand_setup.val = 7;

    // Reject: left_idx is branded with ctx_left, but receiver is ctx_right.
    mut wrong_ref := ctx_right.get_ref(left_idx);
    os.LogInt(wrong_ref.val);
}
