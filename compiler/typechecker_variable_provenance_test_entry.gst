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

    mut t_str_src: ast.Type[ctx];
    unsafe {
        t_str_src.tag = 5; // Str
    }

    typechecker.scope_insert(scope, "source_view", t_str_src, ctx);
    env.variable_types.Insert("source_view", t_str_src);

    mut source_origins_varprov := typechecker.set_init(ctx);
    typechecker.set_add(source_origins_varprov, "root_ctx", ctx);
    env.variable_origins.Insert("source_view", source_origins_varprov);

    mut lex_decl_varprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_decl_varprov, "mut alias_view: str := source_view;");
    mut parser_decl_varprov: parser.Parser[ctx];
    parser.init_parser(&parser_decl_varprov, &lex_decl_varprov, ctx);
    mut stmt_decl_varprov := parser.parse_statement(&parser_decl_varprov, ctx);

    typechecker.check_statement(stmt_decl_varprov, &env, scope, ctx);

    if len(env.errors) != 0 {
        os.LogStr("Error: variable provenance declaration fixture produced unexpected typechecker errors");
        os.Exit(1);
    }

    mut lookup_alias_varprov := env.variable_provenance.Get("alias_view");
    if lookup_alias_varprov.Ok == false {
        os.LogStr("Error: declaration did not record alias_view provenance");
        os.Exit(1);
    }
    mut alias_prov_varprov := lookup_alias_varprov.Val;
    if typechecker.set_contains(alias_prov_varprov.legacy_origins, "root_ctx", ctx) != 1 {
        os.LogStr("Error: declaration provenance did not preserve source legacy origin");
        os.Exit(1);
    }
    if alias_prov_varprov.address_origin.is_unknown != 1 {
        os.LogStr("Error: declaration provenance should keep inert unknown address origin");
        os.Exit(1);
    }

    typechecker.scope_insert(scope, "target_view", t_str_src, ctx);
    env.variable_types.Insert("target_view", t_str_src);

    mut target_origins_varprov := typechecker.set_init(ctx);
    typechecker.set_add(target_origins_varprov, "target_view", ctx);
    env.variable_origins.Insert("target_view", target_origins_varprov);

    mut lex_assign_varprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_assign_varprov, "target_view = alias_view;");
    mut parser_assign_varprov: parser.Parser[ctx];
    parser.init_parser(&parser_assign_varprov, &lex_assign_varprov, ctx);
    mut stmt_assign_varprov := parser.parse_statement(&parser_assign_varprov, ctx);

    typechecker.check_statement(stmt_assign_varprov, &env, scope, ctx);

    if len(env.errors) != 0 {
        os.LogStr("Error: variable provenance assignment fixture produced unexpected typechecker errors");
        os.Exit(1);
    }

    mut lookup_target_varprov := env.variable_provenance.Get("target_view");
    if lookup_target_varprov.Ok == false {
        os.LogStr("Error: assignment did not record target_view provenance");
        os.Exit(1);
    }
    mut target_prov_varprov := lookup_target_varprov.Val;
    if typechecker.set_contains(target_prov_varprov.legacy_origins, "root_ctx", ctx) != 1 {
        os.LogStr("Error: assignment provenance did not preserve source legacy origin");
        os.Exit(1);
    }
    if target_prov_varprov.address_origin.is_unknown != 1 {
        os.LogStr("Error: assignment provenance should keep inert unknown address origin");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert variable provenance binding/assignment metadata verified!");
}