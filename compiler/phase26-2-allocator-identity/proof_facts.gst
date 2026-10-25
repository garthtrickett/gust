// Internal proof metadata, not a new public mixed-origin source construction.
import "../typechecker.gst" as checker;
import "../ast.gst" as ast;
import "../token.gst" as token;
func main() int {
    mut ctx := os.Arena.New();
    unsafe {
        mut env := checker.env_new(&ctx);
        mut scope := checker.scope_new(empty[Index[checker.Scope[ctx], ctx]], &ctx);
        env.current_allocator_scope = scope;
        mut root_type := checker.make_type_struct("Root", "brand", &ctx);
        mut field_type := checker.make_type_struct("Field", "brand", &ctx);
        mut root_layout: checker.StructLayout[ctx];
        root_layout.brand = root_type.Struct.brand;
        root_layout.fields = std.HashMapNew(&ctx);
        root_layout.fields.Insert("owner", field_type);
        mut field_layout: checker.StructLayout[ctx];
        field_layout.brand = field_type.Struct.brand;
        field_layout.fields = std.HashMapNew(&ctx);
        env.struct_registry.Insert("Root", root_layout);
        env.struct_registry.Insert("Field", field_layout);
        ctx[scope].bindings.Insert("source", root_type);
        ctx[scope].bindings.Insert("absent", root_type);
        ctx[scope].allocator_bindings.Insert("source.owner",
            checker.allocator_identity_proof("", 1, &ctx));
        mut root := checker.allocator_identity_proof("known-root", 0, &ctx);
        ctx[scope].allocator_bindings.Insert("source", root);
        ctx[scope].allocator_bindings.Insert("absent", root);
        ctx[scope].allocator_brands.Insert("brand", root);
        mut visited: std.HashMap[str, int, ctx] := std.HashMapNew(&ctx);
        mut copied := checker.env_capture_resource_field_allocator_constraints(
            &env, scope, "copy", "source", root_type, "brand", root, root,
            1, visited, &ctx);
        guard present := ctx[scope].allocator_bindings.Get("copy.owner") else { return 1; }
        if present.unresolved != 1 { return 2; }
        if len(present.identity) != 0 { return 3; }
        os.LogInt(1);
        mut fallback := checker.env_capture_resource_field_allocator_constraints(
            &env, scope, "fallback", "absent", root_type, "brand", root, root,
            1, visited, &ctx);
        guard missing := ctx[scope].allocator_bindings.Get("fallback.owner") else { return 4; }
        if missing.unresolved != 0 { return 5; }
        if std.str_eq(missing.identity, "known-root") == 0 { return 6; }
        os.LogInt(1);
        mut span: token.Span;
        span.start.line = 1;
        span.start.column = 1;
        span.start.offset = 0;
        span.end = span.start;
        mut identifier: ast.Expression[ctx];
        identifier.tag = 0;
        identifier.Identifier.name = "source";
        identifier.Identifier.span = span;
        mut base: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(&ctx);
        ctx.Set(base, identifier);
        mut selector: ast.Expression[ctx];
        selector.tag = 11;
        selector.Selector.left = base;
        selector.Selector.right = "owner";
        selector.Selector.span = span;
        mut expression: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(&ctx);
        ctx.Set(expression, selector);
        mut observed := checker.env_allocator_expression_proof(expression, &env, &ctx);
        if observed.present != 1 || observed.unresolved != 1 || len(observed.identity) != 0 { return 7; }
        os.LogInt(1);
        mut declared := checker.env_allocator_declaration_proof(expression, field_type, &env, &ctx);
        if declared.present != 1 || declared.unresolved != 1 || len(declared.identity) != 0 { return 8; }
        os.LogInt(1);
        identifier.Identifier.name = "absent";
        ctx.Set(base, identifier);
        mut absent_observed := checker.env_allocator_expression_proof(expression, &env, &ctx);
        if absent_observed.unresolved != 0 || std.str_eq(absent_observed.identity, "known-root") == 0 { return 9; }
        os.LogInt(1);
        mut absent_declared := checker.env_allocator_declaration_proof(
            empty[Index[ast.Expression[ctx], ctx]], field_type, &env, &ctx);
        if absent_declared.unresolved != 0 || std.str_eq(absent_declared.identity, "known-root") == 0 { return 10; }
        os.LogInt(1);

        // A lexical dependency lookup must preserve explicit unknown facts.
        env.struct_linear_resource.Insert("Field", 1);
        mut substitutions: std.HashMap[str, checker.AllocatorIdentityProof[ctx], ctx] := std.HashMapNew(&ctx);
        ctx[scope].bindings.Insert("brand", field_type);
        ctx[scope].allocator_bindings.Insert("brand", checker.allocator_identity_proof("", 1, &ctx));
        mut explicit_unknown := checker.env_resource_allocator_dependencies(&env, field_type, substitutions, 1, &ctx);
        if explicit_unknown.unresolved != 1 || len(explicit_unknown.identities.Keys(&ctx)) != 0 { return 11; }
        os.LogInt(1);
        ctx[scope].allocator_bindings.Insert("brand", checker.allocator_identity_proof("known-origin", 0, &ctx));
        mut known := checker.env_resource_allocator_dependencies(&env, field_type, substitutions, 1, &ctx);
        guard known_identity := known.identities.Get("known-origin") else { return 12; }
        if known.unresolved != 0 || len(known.identities.Keys(&ctx)) != 1 || known_identity != 1 { return 12; }
        os.LogInt(1);
        // Preserve the existing absent-formal convention independently.
        mut absent_scope := checker.scope_new(empty[Index[checker.Scope[ctx], ctx]], &ctx);
        env.current_allocator_scope = absent_scope;
        mut absent_proof := checker.env_allocator_binding_proof(&env, "brand", &ctx);
        if absent_proof.present != 0 { return 13; }
        mut formal := checker.env_resource_allocator_dependencies(&env, field_type, substitutions, 1, &ctx);
        guard formal_identity := formal.identities.Get(checker.arena_lifecycle_identity_for_binding(&env, "brand", &ctx)) else { return 14; }
        if formal.unresolved != 0 || len(formal.identities.Keys(&ctx)) != 1 || formal_identity != 1 { return 14; }
        os.LogInt(1);
        ctx[absent_scope].bindings.Insert("brand", field_type);
        mut shadowed := checker.env_resource_allocator_dependencies(&env, field_type, substitutions, 1, &ctx);
        if shadowed.unresolved != 1 || len(shadowed.identities.Keys(&ctx)) != 0 { return 15; }
        os.LogInt(1);
    }
    return 0;
}
