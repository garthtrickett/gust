import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env := typechecker.env_new(ctx);

    // An explicit brand is authoritative even when its spelling is not in the
    // legacy brand vocabulary.
    mut explicit_t := typechecker.make_type_struct("Holder", "scratch", ctx);
    mut explicit_resolved := typechecker.env_resolve_type(&env, explicit_t, ctx);
    mut explicit_identity := typechecker.env_get_brand_identity(&env, explicit_resolved, ctx);
    if std.str_eq(explicit_identity.brand_origin, "resolved_struct") == 0 {
        os.LogStr("Error: resolved brand origin was not recorded");
        os.Exit(1);
    }
    if std.str_eq(explicit_identity.arena_identity, "scratch") == 0 {
        os.LogStr("Error: explicit arena identity was not preserved");
        os.Exit(1);
    }
    if explicit_identity.is_arena != 0 {
        os.LogStr("Error: branded Holder was incorrectly classified as an arena value");
        os.Exit(1);
    }
    if typechecker.brand_identity_has_explicit_public_origin(explicit_t, explicit_identity, ctx) != 1 {
        os.LogStr("Error: explicit brand was rejected at a public boundary");
        os.Exit(1);
    }

    // A registry-owned brand is recorded, but is not accepted as an implicit
    // substitute for spelling the brand at a public boundary.
    mut layout: typechecker.StructLayout[ctx];
    mut layout_brand: Index[str, ctx] := os.ArenaAlloc(ctx) as Index[str, ctx];
    unsafe {
        ctx.Set(layout_brand, "storage");
    }
    layout.brand = layout_brand;
    layout.fields = std.HashMapNew(ctx);
    typechecker.env_register_struct(&env, "RegisteredNode", layout, ctx);

    mut registry_t := typechecker.make_type_struct("RegisteredNode", "", ctx);
    mut registry_resolved := typechecker.env_resolve_type(&env, registry_t, ctx);
    mut registry_identity := typechecker.env_get_brand_identity(&env, registry_resolved, ctx);
    if std.str_eq(registry_identity.brand_origin, "resolved_struct_layout") == 0 ||
       std.str_eq(registry_identity.arena_identity, "storage") == 0 {
        os.LogStr("Error: struct-layout brand identity was not recorded");
        os.Exit(1);
    }
    if typechecker.brand_identity_has_explicit_public_origin(registry_t, registry_identity, ctx) != 0 {
        os.LogStr("Error: implicit registry brand was accepted at a public boundary");
        os.Exit(1);
    }

    // A suffix alone is not semantic brand evidence. Patch 19.8 removed the
    // compatibility spelling rule, so both APIs report no brand here.
    mut suffix_t := typechecker.make_type_struct("LegacyNode_ctx", "", ctx);
    mut suffix_resolved := typechecker.env_resolve_type(&env, suffix_t, ctx);
    mut suffix_identity := typechecker.env_get_brand_identity(&env, suffix_resolved, ctx);
    mut suffix_brand := typechecker.get_type_brand(suffix_resolved, &env, ctx);
    if std.str_eq(suffix_identity.arena_identity, "") == 0 ||
       std.str_eq(suffix_brand, "") == 0 {
        os.LogStr("Error: identifier suffix was treated as brand evidence");
        os.Exit(1);
    }

    mut arena_t := typechecker.make_type_pointer(typechecker.make_type_arena(), ctx);
    mut arena_resolved := typechecker.env_resolve_type(&env, arena_t, ctx);
    mut arena_identity := typechecker.env_get_brand_identity(&env, arena_resolved, ctx);
    if arena_identity.is_arena != 1 || std.str_eq(arena_identity.brand_origin, "arena_type") == 0 {
        os.LogStr("Error: resolved arena pointer was not classified from its type");
        os.Exit(1);
    }

    mut boundary_env := typechecker.env_new(ctx);
    typechecker.env_register_struct(&boundary_env, "RegisteredNode", layout, ctx);
    mut boundary_lexer: lexer.Lexer[ctx];
    lexer.init_lexer(&boundary_lexer, "func expose(node: RegisteredNode) int { return 0; }");
    mut boundary_parser: parser.Parser[ctx];
    parser.init_parser(&boundary_parser, &boundary_lexer, ctx);
    mut boundary_program := parser.parse_program(&boundary_parser, ctx);
    unsafe {
        mut boundary_statements: std.Vector[ast.Statement[ctx], ctx] := ctx[boundary_program.statements];
        typechecker.env_pre_register_statement(&boundary_env, boundary_statements[0], ctx);
    }
    if len(boundary_env.errors) != 1 ||
       std.str_find(boundary_env.errors[0].message, "[ImplicitPublicBrand]") == 0 - 1 {
        os.LogStr("Error: implicit public brand boundary was not rejected");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-owned brand identity records verified");
}
