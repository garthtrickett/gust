import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_ctorprov := typechecker.env_new(ctx);
    mut scope_ctorprov := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    mut t_arena_ctorprov := typechecker.make_type_arena();
    typechecker.scope_insert(scope_ctorprov, "ctx", t_arena_ctorprov, ctx);
    env_ctorprov.variable_types.Insert("ctx", t_arena_ctorprov);

    mut t_idx_ctorprov := typechecker.make_type_index("SafeConstructorNodeCtorProv", "ctx", ctx);

    mut lex_alloc_ctorprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_alloc_ctorprov, "os.ArenaAlloc(ctx)");
    mut parser_alloc_ctorprov: parser.Parser[ctx];
    parser.init_parser(&parser_alloc_ctorprov, &lex_alloc_ctorprov, ctx);
    mut expr_alloc_ctorprov := parser.parse_expression(&parser_alloc_ctorprov, 1, ctx);

    mut alloc_prov_ctorprov := typechecker.check_expression_with_provenance(expr_alloc_ctorprov, &env_ctorprov, scope_ctorprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(alloc_prov_ctorprov) != 1 {
        os.LogStr("Error: os.ArenaAlloc(ctx) did not produce safe-arena provenance");
        os.Exit(1);
    }
    if typechecker.expression_provenance_is_raw_or_sandbox_derived(alloc_prov_ctorprov) != 0 {
        os.LogStr("Error: os.ArenaAlloc(ctx) was classified as unsafe-derived provenance");
        os.Exit(1);
    }

    typechecker.scope_insert(scope_ctorprov, "safe_idx_ctorprov", t_idx_ctorprov, ctx);
    env_ctorprov.variable_types.Insert("safe_idx_ctorprov", t_idx_ctorprov);

    mut safe_origins_ctorprov := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_ctorprov, "safe_ctor_root", ctx);
    env_ctorprov.variable_origins.Insert("safe_idx_ctorprov", safe_origins_ctorprov);

    mut safe_idx_prov_ctorprov := typechecker.expression_provenance_safe_arena(t_idx_ctorprov, ctx);
    safe_idx_prov_ctorprov.legacy_origins = safe_origins_ctorprov;
    typechecker.env_record_variable_provenance(&env_ctorprov, "safe_idx_ctorprov", safe_idx_prov_ctorprov, ctx);

    mut lex_safe_ref_ctorprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_safe_ref_ctorprov, "ctx.get_ref(safe_idx_ctorprov)");
    mut parser_safe_ref_ctorprov: parser.Parser[ctx];
    parser.init_parser(&parser_safe_ref_ctorprov, &lex_safe_ref_ctorprov, ctx);
    mut expr_safe_ref_ctorprov := parser.parse_expression(&parser_safe_ref_ctorprov, 1, ctx);

    mut safe_ref_prov_ctorprov := typechecker.check_expression_with_provenance(expr_safe_ref_ctorprov, &env_ctorprov, scope_ctorprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(safe_ref_prov_ctorprov) != 1 {
        os.LogStr("Error: ctx.get_ref(safe index) did not preserve safe-arena provenance");
        os.Exit(1);
    }
    if typechecker.set_contains(safe_ref_prov_ctorprov.legacy_origins, "safe_ctor_root", ctx) != 1 {
        os.LogStr("Error: ctx.get_ref(safe index) did not preserve index legacy origin");
        os.Exit(1);
    }

    typechecker.scope_insert(scope_ctorprov, "raw_idx_ctorprov", t_idx_ctorprov, ctx);
    env_ctorprov.variable_types.Insert("raw_idx_ctorprov", t_idx_ctorprov);

    mut raw_origins_ctorprov := typechecker.set_init(ctx);
    typechecker.set_add(raw_origins_ctorprov, "raw_ctor_root", ctx);
    env_ctorprov.variable_origins.Insert("raw_idx_ctorprov", raw_origins_ctorprov);

    mut raw_idx_prov_ctorprov := typechecker.expression_provenance_raw_derived(t_idx_ctorprov, ctx);
    raw_idx_prov_ctorprov.legacy_origins = raw_origins_ctorprov;
    typechecker.env_record_variable_provenance(&env_ctorprov, "raw_idx_ctorprov", raw_idx_prov_ctorprov, ctx);

    mut lex_raw_ref_ctorprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_raw_ref_ctorprov, "ctx.get_ref(raw_idx_ctorprov)");
    mut parser_raw_ref_ctorprov: parser.Parser[ctx];
    parser.init_parser(&parser_raw_ref_ctorprov, &lex_raw_ref_ctorprov, ctx);
    mut expr_raw_ref_ctorprov := parser.parse_expression(&parser_raw_ref_ctorprov, 1, ctx);

    mut raw_ref_prov_ctorprov := typechecker.check_expression_with_provenance(expr_raw_ref_ctorprov, &env_ctorprov, scope_ctorprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(raw_ref_prov_ctorprov) == 1 {
        os.LogStr("Error: ctx.get_ref(raw-derived index) incorrectly allowed safe branding");
        os.Exit(1);
    }

    if len(env_ctorprov.errors) != 0 {
        os.LogStr("Error: safe constructor provenance fixture produced unexpected typechecker errors");
        os.LogStr(env_ctorprov.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: safe constructor provenance metadata verified!");
}