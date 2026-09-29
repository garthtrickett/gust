import "ast.gst" as ast;
import "typechecker.gst" as typechecker;

func expect_brand(label: str, t: ast.Type[ctx], expected: str, ctx: &Arena) {
    mut observed := typechecker.get_explicit_type_brand(t, ctx);
    if std.str_eq(observed, expected) == 0 {
        os.LogStr("Error: explicit brand traversal drifted");
        os.LogStr(label);
        os.LogStr(observed);
        os.Exit(1);
    }
}

func expect_match(label: str, left: ast.Type[ctx], right: ast.Type[ctx], expected: int, ctx: &Arena) {
    mut observed := typechecker.types_match(left, right, ctx);
    if observed != expected {
        os.LogStr("Error: explicit-brand type matching drifted");
        os.LogStr(label);
        os.LogInt(observed);
        os.Exit(1);
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut plain := typechecker.make_type_struct("Node", "", ctx);
    mut branded := typechecker.make_type_struct("Node", "arenaA", ctx);
    mut other := typechecker.make_type_struct("Node", "arenaB", ctx);
    mut index_a := typechecker.make_type_index("Node", "arenaA", ctx);
    mut index_b := typechecker.make_type_index("Node", "arenaB", ctx);
    mut pointer := typechecker.make_type_pointer(branded, ctx);
    mut reference_a := typechecker.make_type_reference(branded, "arenaA", ctx);
    mut reference_b := typechecker.make_type_reference(branded, "arenaB", ctx);
    mut reference_inner := typechecker.make_type_reference(branded, "", ctx);
    mut slice: ast.Type[ctx];
    unsafe {
        slice.tag = 6;
        slice.Slice.inner = os.ArenaAlloc(ctx);
        ctx.Set(slice.Slice.inner, branded);
    }

    expect_brand("plain struct", plain, "", ctx);
    expect_brand("branded struct", branded, "arenaA", ctx);
    expect_brand("index", index_a, "arenaA", ctx);
    expect_brand("pointer recursion", pointer, "arenaA", ctx);
    expect_brand("slice recursion", slice, "arenaA", ctx);
    expect_brand("reference explicit", reference_b, "arenaB", ctx);
    expect_brand("reference recursion", reference_inner, "arenaA", ctx);

    mut env := typechecker.env_new(ctx);
    mut layout: typechecker.StructLayout[ctx];
    layout.fields = std.HashMapNew(ctx);
    unsafe {
        layout.brand = os.ArenaAlloc(ctx) as Index[str, ctx];
        ctx.Set(layout.brand, "registered");
    }
    typechecker.env_register_struct(&env, "Node", layout, ctx);
    if std.str_eq(typechecker.get_type_brand(plain, &env, ctx), "registered") == 0 ||
       std.str_eq(typechecker.get_explicit_type_brand(plain, ctx), "") == 0 {
        os.LogStr("Error: environment-aware registered brand lookup changed");
        os.Exit(1);
    }

    expect_match("index same", index_a, index_a, 1, ctx);
    // Structural Index matching keeps its historical same-name wildcard.
    expect_match("index other", index_a, index_b, 1, ctx);
    expect_match("struct same", branded, branded, 1, ctx);
    expect_match("struct name same despite brand", branded, other, 1, ctx);
    expect_match("reference same", reference_a, reference_a, 1, ctx);
    expect_match("reference other", reference_a, reference_b, 0, ctx);
    os.LogStr("SUCCESS: explicit-only type brands preserve nil-environment matching");
}
