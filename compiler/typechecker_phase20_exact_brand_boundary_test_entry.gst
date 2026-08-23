import "ast.gst" as ast;
import "typechecker.gst" as typechecker;

func assert_match(actual: int, expected: int, label: str) {
    if actual != expected {
        os.LogStr(std.Concat("Error: exact brand-boundary result drifted for ", label));
        os.Exit(1);
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    mut env := typechecker.env_new(ctx);

    mut node_layout: typechecker.StructLayout[ctx];
    node_layout.brand = empty[Index[str, ctx]];
    node_layout.fields = std.HashMapNew(ctx);
    node_layout.fields.Insert("value", typechecker.make_type_int());
    typechecker.env_register_struct(&env, "Node", node_layout, ctx);

    mut alpha := typechecker.env_resolve_type(
        &env, typechecker.make_type_index("Node", "alpha", ctx), ctx
    );
    mut beta := typechecker.env_resolve_type(
        &env, typechecker.make_type_index("Node", "beta", ctx), ctx
    );
    mut same_alpha := typechecker.env_resolve_type(
        &env, typechecker.make_type_index("Node", "alpha", ctx), ctx
    );

    // The legacy structural matcher deliberately ignores brands. Patch 20.3
    // makes the environment-aware boundary the authority once both identities
    // are resolved.
    assert_match(typechecker.types_match(alpha, beta, ctx), 1, "legacy structural observation");
    assert_match(typechecker.env_types_match_at_brand_boundary(&env, alpha, beta, ctx), 0, "distinct identities");
    assert_match(typechecker.env_types_match_at_brand_boundary(&env, alpha, same_alpha, ctx), 1, "same identity");

    mut any_brand := typechecker.env_resolve_type(
        &env, typechecker.make_type_index("Node", "Any", ctx), ctx
    );
    mut unbranded := typechecker.env_resolve_type(
        &env, typechecker.make_type_index("Node", "", ctx), ctx
    );
    assert_match(typechecker.env_types_match_at_brand_boundary(&env, alpha, any_brand, ctx), 1, "authorized Any wildcard");
    assert_match(typechecker.env_types_match_at_brand_boundary(&env, alpha, unbranded, ctx), 1, "existing unbranded compatibility");

    env.imports.Insert(std.Clone(ctx, "model"), std.Clone(ctx, "model_module__"));
    typechecker.env_register_struct(&env, "model_module__Node", node_layout, ctx);
    mut imported_alpha := typechecker.env_resolve_type(
        &env, typechecker.make_type_index("model.Node", "alpha", ctx), ctx
    );
    mut imported_beta := typechecker.env_resolve_type(
        &env, typechecker.make_type_index("model.Node", "beta", ctx), ctx
    );
    assert_match(typechecker.env_types_match_at_brand_boundary(&env, imported_alpha, imported_beta, ctx), 0, "import alias");

    mut substitutions: std.HashMap[str, ast.Type[ctx], ctx] := std.HashMapNew(ctx);
    substitutions.Insert(std.Clone(ctx, "T"), imported_alpha);
    mut substituted := typechecker.substitute_generics(
        &env, typechecker.make_type_struct("T", "", ctx), substitutions, ctx
    );
    mut substituted_resolved := typechecker.env_resolve_type(&env, substituted, ctx);
    assert_match(typechecker.env_types_match_at_brand_boundary(&env, imported_alpha, substituted_resolved, ctx), 1, "generic substitution");

    os.LogStr("SUCCESS: Phase 20 exact branded boundary verified");
}
