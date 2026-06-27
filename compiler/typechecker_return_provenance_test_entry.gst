import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    mut t_str_retprov: ast.Type[ctx];
    unsafe {
        t_str_retprov.tag = 5; // Str
    }

    typechecker.scope_insert(scope, "source_view", t_str_retprov, ctx);
    env.variable_types.Insert("source_view", t_str_retprov);

    mut source_origins_retprov := typechecker.set_init(ctx);
    typechecker.set_add(source_origins_retprov, "root_ctx", ctx);
    env.variable_origins.Insert("source_view", source_origins_retprov);

    mut source_prov_retprov := typechecker.expression_provenance_raw_derived(t_str_retprov, ctx);
    source_prov_retprov.legacy_origins = source_origins_retprov;
    typechecker.env_record_variable_provenance(&env, "source_view", source_prov_retprov, ctx);

    mut return_type_idx_retprov: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(return_type_idx_retprov, t_str_retprov);
    env.expected_return_type = return_type_idx_retprov;
    env.current_function_return_origins = typechecker.set_init(ctx);
    env.current_function_return_provenance = typechecker.expression_provenance_unknown(t_str_retprov, ctx);

    mut lex_return_retprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_return_retprov, "return source_view;");
    mut parser_return_retprov: parser.Parser[ctx];
    parser.init_parser(&parser_return_retprov, &lex_return_retprov, ctx);
    mut stmt_return_retprov := parser.parse_statement(&parser_return_retprov, ctx);

    typechecker.check_statement(stmt_return_retprov, &env, scope, ctx);

    if len(env.errors) != 0 {
        os.LogStr("Error: return provenance fixture produced unexpected typechecker errors");
        os.Exit(1);
    }

    if typechecker.set_contains(env.current_function_return_origins, "root_ctx", ctx) != 1 {
        os.LogStr("Error: return legacy origins did not preserve source root");
        os.Exit(1);
    }

    mut captured_prov_retprov := env.current_function_return_provenance;
    if typechecker.set_contains(captured_prov_retprov.legacy_origins, "root_ctx", ctx) != 1 {
        os.LogStr("Error: return expression provenance did not preserve source legacy origin");
        os.Exit(1);
    }
    if captured_prov_retprov.address_origin.is_raw_derived != 1 {
        os.LogStr("Error: return expression provenance did not preserve raw-derived address origin");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert return expression provenance metadata verified!");
}