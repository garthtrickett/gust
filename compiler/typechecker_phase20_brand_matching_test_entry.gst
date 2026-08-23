import "ast.gst" as ast;
import "typechecker.gst" as typechecker;

func require_identity(identity: typechecker.BrandIdentity[ctx], expected: str, label: str) {
    if std.str_eq(identity.arena_identity, expected) == 0 {
        os.LogStr(std.Concat("Error: brand identity drifted for ", label));
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
    node_layout.fields.Insert("payload", typechecker.make_type_str());
    typechecker.env_register_struct(&env, "Node", node_layout, ctx);

    // Same-shaped values from distinct arenas retain distinct identities.
    mut alpha_t := typechecker.make_type_struct("Node", "alpha", ctx);
    mut beta_t := typechecker.make_type_struct("Node", "beta", ctx);
    mut alpha_resolved := typechecker.env_resolve_type(&env, alpha_t, ctx);
    mut beta_resolved := typechecker.env_resolve_type(&env, beta_t, ctx);
    mut alpha_identity := typechecker.env_get_brand_identity(&env, alpha_resolved, ctx);
    mut beta_identity := typechecker.env_get_brand_identity(&env, beta_resolved, ctx);
    require_identity(alpha_identity, "alpha", "alpha value");
    require_identity(beta_identity, "beta", "beta value");
    if typechecker.brand_identity_exact_match(alpha_identity, beta_identity) != 0 {
        os.LogStr("Error: distinct same-shaped arena values matched");
        os.Exit(1);
    }
    mut alternate_origin := typechecker.brand_identity_make("field", "alpha", 0, ctx);
    if typechecker.brand_identity_exact_match(alpha_identity, alternate_origin) != 1 {
        os.LogStr("Error: identity origin metadata changed exact matching");
        os.Exit(1);
    }

    // Pointer/reference nesting keeps the inner resolved arena identity.
    mut nested_t := typechecker.make_type_pointer(
        typechecker.make_type_reference(alpha_t, "", ctx),
        ctx
    );
    mut nested_resolved := typechecker.env_resolve_type(&env, nested_t, ctx);
    mut nested_identity := typechecker.typechecker_brand_identity_from_resolved_type(
        nested_resolved,
        &env,
        ctx
    );
    require_identity(nested_identity, "alpha", "nested pointer/reference");

    // Field extraction preserves the field type's identity after resolution.
    mut holder_layout: typechecker.StructLayout[ctx];
    holder_layout.brand = empty[Index[str, ctx]];
    holder_layout.fields = std.HashMapNew(ctx);
    holder_layout.fields.Insert("child", alpha_t);
    typechecker.env_register_struct(&env, "Holder", holder_layout, ctx);
    mut holder_lookup := env.struct_registry.Get("Holder");
    mut child_field_t: ast.Type[ctx];
    if holder_lookup.Ok {
        mut registered_holder := holder_lookup.Val;
        mut child_lookup := registered_holder.fields.Get("child");
        if child_lookup.Ok {
            child_field_t = child_lookup.Val;
        } else {
            os.LogStr("Error: branded field was not registered");
            os.Exit(1);
        }
    } else {
        os.LogStr("Error: holder layout was not registered");
        os.Exit(1);
    }
    mut child_resolved := typechecker.env_resolve_type(&env, child_field_t, ctx);
    require_identity(
        typechecker.env_get_brand_identity(&env, child_resolved, ctx),
        "alpha",
        "resolved field"
    );

    // Import aliases change the canonical type name, not its arena identity.
    env.imports.Insert(std.Clone(ctx, "lib"), std.Clone(ctx, "lib_module__"));
    typechecker.env_register_struct(&env, "lib_module__Node", node_layout, ctx);
    mut alias_t := typechecker.make_type_struct("lib.Node", "alpha", ctx);
    mut alias_resolved := typechecker.env_resolve_type(&env, alias_t, ctx);
    require_identity(
        typechecker.env_get_brand_identity(&env, alias_resolved, ctx),
        "alpha",
        "resolved import alias"
    );

    // Generic substitution carries the substituted type's identity.
    mut substitutions: std.HashMap[str, ast.Type[ctx], ctx] := std.HashMapNew(ctx);
    substitutions.Insert(std.Clone(ctx, "T"), alias_t);
    mut placeholder := typechecker.make_type_struct("T", "", ctx);
    mut substituted := typechecker.substitute_generics(&env, placeholder, substitutions, ctx);
    mut substituted_resolved := typechecker.env_resolve_type(&env, substituted, ctx);
    require_identity(
        typechecker.env_get_brand_identity(&env, substituted_resolved, ctx),
        "alpha",
        "generic substitution"
    );

    mut any_identity := typechecker.brand_identity_make("test", "Any", 0, ctx);
    if typechecker.brand_identity_nesting_membership(alpha_identity, any_identity) != 1 ||
       typechecker.brand_identity_nesting_membership(alpha_identity, beta_identity) != 0 {
        os.LogStr("Error: canonical nesting membership drifted");
        os.Exit(1);
    }
    mut mismatch := typechecker.brand_identity_mismatch_description(alpha_identity, beta_identity, ctx);
    if std.str_eq(mismatch, "expected arena identity 'alpha' but found 'beta'") == 0 {
        os.LogStr("Error: canonical brand mismatch description drifted");
        os.Exit(1);
    }

    // The old string cleaner remains authoritative in Patch 20.1. These two
    // observations prove both agreement and disagreement are recorded without
    // changing the old return value.
    mut prefixed_alpha_t := typechecker.make_type_struct("Node", "module__alpha", ctx);
    if typechecker.env_is_element_allowed_in_brand(&env, prefixed_alpha_t, "alpha", ctx) != 1 ||
       typechecker.env_is_element_allowed_in_brand(&env, alpha_t, "alpha", ctx) != 1 {
        os.LogStr("Error: Patch 20.1 changed legacy brand nesting acceptance");
        os.Exit(1);
    }
    if env.brand_match_shadow_checks != 2 ||
       env.brand_match_shadow_agreements != 1 ||
       env.brand_match_shadow_disagreements != 1 {
        os.LogStr("Error: resolved brand shadow observations were not recorded");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: Phase 20 canonical brand matching primitives verified");
}
