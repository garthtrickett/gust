type MyNode struct {
    val: int
}

func dummy_test(ctx: &Arena) {
    mut vec: std.Vector[MyNode, ctx] := std.VectorNew(ctx);
    mut idx := 0;

    // Passive syntax validation for explicit reference-access method calls.
    // Since the typechecker does not yet support these selectors, this file
    // is tested as a negative-compilation test verifying it successfully
    // parses but fails with MethodNotFound in the typechecker.
    ctx.get_ref(idx);
    vec.GetRef(idx);
}

func main() {}