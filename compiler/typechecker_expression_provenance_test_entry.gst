import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_int: ast.Type[ctx];
    unsafe {
        t_int.tag = 0; // Int
    }

    mut safe_prov := typechecker.expression_provenance_safe_arena(t_int, ctx);
    if typechecker.expression_provenance_allows_safe_branding(safe_prov) != 1 {
        os.LogStr("Error: safe expression provenance must allow safe branding");
        os.Exit(1);
    }
    if typechecker.expression_provenance_requires_unsafe_boundary(safe_prov) != 0 {
        os.LogStr("Error: safe expression provenance must not require unsafe boundaries");
        os.Exit(1);
    }

    mut raw_prov := typechecker.expression_provenance_raw_derived(t_int, ctx);
    if typechecker.expression_provenance_allows_safe_branding(raw_prov) != 0 {
        os.LogStr("Error: raw-derived expression provenance must not allow safe branding");
        os.Exit(1);
    }
    if typechecker.expression_provenance_requires_unsafe_boundary(raw_prov) != 1 {
        os.LogStr("Error: raw-derived expression provenance must require unsafe boundaries");
        os.Exit(1);
    }

    mut sandbox_prov := typechecker.expression_provenance_sandbox_derived(t_int, ctx);
    if typechecker.expression_provenance_is_raw_or_sandbox_derived(sandbox_prov) != 1 {
        os.LogStr("Error: sandbox-derived expression provenance must classify as unsafe-derived");
        os.Exit(1);
    }

    mut unknown_prov := typechecker.expression_provenance_unknown(t_int, ctx);
    if typechecker.expression_provenance_allows_safe_branding(unknown_prov) != 0 {
        os.LogStr("Error: unknown expression provenance must not allow safe branding");
        os.Exit(1);
    }
    if typechecker.expression_provenance_requires_unsafe_boundary(unknown_prov) != 0 {
        os.LogStr("Error: unknown expression provenance remains inert and must not require unsafe boundaries yet");
        os.Exit(1);
    }

    typechecker.set_add(safe_prov.legacy_origins, "safe_root", ctx);
    typechecker.set_add(raw_prov.legacy_origins, "raw_root", ctx);
    mut joined_prov := typechecker.expression_provenance_join(safe_prov, raw_prov, ctx);
    if joined_prov.address_origin.is_raw_derived != 1 {
        os.LogStr("Error: joining safe and raw-derived provenance must preserve raw-derived origin");
        os.Exit(1);
    }
    if typechecker.set_contains(joined_prov.legacy_origins, "safe_root", ctx) != 1 {
        os.LogStr("Error: joined expression provenance lost safe legacy origin");
        os.Exit(1);
    }
    if typechecker.set_contains(joined_prov.legacy_origins, "raw_root", ctx) != 1 {
        os.LogStr("Error: joined expression provenance lost raw legacy origin");
        os.Exit(1);
    }

    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    mut t_str: ast.Type[ctx];
    unsafe {
        t_str.tag = 5; // Str
    }
    typechecker.scope_insert(scope, "my_view", t_str, ctx);
    env.variable_types.Insert("my_view", t_str);

    mut view_origins := typechecker.set_init(ctx);
    typechecker.set_add(view_origins, "root_ctx", ctx);
    env.variable_origins.Insert("my_view", view_origins);

    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, "my_view");
    mut par: parser.Parser[ctx];
    parser.init_parser(&par, &lex, ctx);
    mut expr_idx := parser.parse_expression(&par, 1, ctx);

    mut checked_prov := typechecker.check_expression_with_provenance(expr_idx, &env, scope, ctx);
    if typechecker.set_contains(checked_prov.legacy_origins, "root_ctx", ctx) != 1 {
        os.LogStr("Error: expression provenance carrier failed to preserve legacy origin set");
        os.Exit(1);
    }
    if checked_prov.address_origin.is_unknown != 1 {
        os.LogStr("Error: expression provenance carrier should default address origin to unknown until propagation enforcement lands");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert expression provenance carrier verified!");
}