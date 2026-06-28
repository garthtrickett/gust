import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_idx_unknown_nlaunder := typechecker.make_type_index("SafeCellUnknown", "ctx", ctx);

    mut env_unknown_binding_nlaunder := typechecker.env_new(ctx);
    mut scope_unknown_binding_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.scope_insert(scope_unknown_binding_nlaunder, "unknown_idx_source", t_idx_unknown_nlaunder, ctx);
    env_unknown_binding_nlaunder.variable_types.Insert("unknown_idx_source", t_idx_unknown_nlaunder);

    mut unknown_origins_binding_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(unknown_origins_binding_nlaunder, "unknown_binding_root", ctx);
    env_unknown_binding_nlaunder.variable_origins.Insert("unknown_idx_source", unknown_origins_binding_nlaunder);

    mut unknown_prov_binding_nlaunder := typechecker.expression_provenance_unknown(t_idx_unknown_nlaunder, ctx);
    unknown_prov_binding_nlaunder.legacy_origins = unknown_origins_binding_nlaunder;
    typechecker.env_record_variable_provenance(&env_unknown_binding_nlaunder, "unknown_idx_source", unknown_prov_binding_nlaunder, ctx);

    mut lex_unknown_binding_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_unknown_binding_nlaunder, "mut alias_unknown_idx := unknown_idx_source;");
    mut parser_unknown_binding_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_unknown_binding_nlaunder, &lex_unknown_binding_nlaunder, ctx);
    mut stmt_unknown_binding_nlaunder := parser.parse_statement(&parser_unknown_binding_nlaunder, ctx);

    typechecker.check_statement(stmt_unknown_binding_nlaunder, &env_unknown_binding_nlaunder, scope_unknown_binding_nlaunder, ctx);

    if len(env_unknown_binding_nlaunder.errors) == 0 {
        os.LogStr("Error: non-laundering unknown fixture expected unknown-origin safe-branded binding rejection");
        os.Exit(1);
    }
    if std.str_find(env_unknown_binding_nlaunder.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: non-laundering unknown binding fixture emitted wrong diagnostic");
        os.LogStr(env_unknown_binding_nlaunder.errors[0].message);
        os.Exit(1);
    }

    mut env_unknown_return_nlaunder := typechecker.env_new(ctx);
    mut scope_unknown_return_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.scope_insert(scope_unknown_return_nlaunder, "unknown_idx_return", t_idx_unknown_nlaunder, ctx);
    env_unknown_return_nlaunder.variable_types.Insert("unknown_idx_return", t_idx_unknown_nlaunder);

    mut unknown_origins_return_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(unknown_origins_return_nlaunder, "unknown_return_root", ctx);
    env_unknown_return_nlaunder.variable_origins.Insert("unknown_idx_return", unknown_origins_return_nlaunder);

    mut unknown_prov_return_nlaunder := typechecker.expression_provenance_unknown(t_idx_unknown_nlaunder, ctx);
    unknown_prov_return_nlaunder.legacy_origins = unknown_origins_return_nlaunder;
    typechecker.env_record_variable_provenance(&env_unknown_return_nlaunder, "unknown_idx_return", unknown_prov_return_nlaunder, ctx);

    mut ret_idx_unknown_nlaunder: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(ret_idx_unknown_nlaunder, t_idx_unknown_nlaunder);
    env_unknown_return_nlaunder.expected_return_type = ret_idx_unknown_nlaunder;
    env_unknown_return_nlaunder.current_function_return_origins = typechecker.set_init(ctx);
    env_unknown_return_nlaunder.current_function_return_provenance = typechecker.expression_provenance_unknown(t_idx_unknown_nlaunder, ctx);

    mut lex_unknown_return_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_unknown_return_nlaunder, "return unknown_idx_return;");
    mut parser_unknown_return_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_unknown_return_nlaunder, &lex_unknown_return_nlaunder, ctx);
    mut stmt_unknown_return_nlaunder := parser.parse_statement(&parser_unknown_return_nlaunder, ctx);

    typechecker.check_statement(stmt_unknown_return_nlaunder, &env_unknown_return_nlaunder, scope_unknown_return_nlaunder, ctx);

    if len(env_unknown_return_nlaunder.errors) == 0 {
        os.LogStr("Error: non-laundering unknown fixture expected unknown-origin safe-branded return rejection");
        os.Exit(1);
    }
    if std.str_find(env_unknown_return_nlaunder.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: non-laundering unknown return fixture emitted wrong diagnostic");
        os.LogStr(env_unknown_return_nlaunder.errors[0].message);
        os.Exit(1);
    }

    mut env_safe_unknown_nlaunder := typechecker.env_new(ctx);
    mut scope_safe_unknown_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.scope_insert(scope_safe_unknown_nlaunder, "safe_idx_unknown_source", t_idx_unknown_nlaunder, ctx);
    env_safe_unknown_nlaunder.variable_types.Insert("safe_idx_unknown_source", t_idx_unknown_nlaunder);

    mut safe_origins_unknown_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_unknown_nlaunder, "safe_unknown_root", ctx);
    env_safe_unknown_nlaunder.variable_origins.Insert("safe_idx_unknown_source", safe_origins_unknown_nlaunder);

    mut safe_prov_unknown_nlaunder := typechecker.expression_provenance_safe_arena(t_idx_unknown_nlaunder, ctx);
    safe_prov_unknown_nlaunder.legacy_origins = safe_origins_unknown_nlaunder;
    typechecker.env_record_variable_provenance(&env_safe_unknown_nlaunder, "safe_idx_unknown_source", safe_prov_unknown_nlaunder, ctx);

    mut lex_safe_unknown_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_safe_unknown_nlaunder, "mut safe_idx_unknown_alias := safe_idx_unknown_source;");
    mut parser_safe_unknown_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_safe_unknown_nlaunder, &lex_safe_unknown_nlaunder, ctx);
    mut stmt_safe_unknown_nlaunder := parser.parse_statement(&parser_safe_unknown_nlaunder, ctx);

    typechecker.check_statement(stmt_safe_unknown_nlaunder, &env_safe_unknown_nlaunder, scope_safe_unknown_nlaunder, ctx);

    if len(env_safe_unknown_nlaunder.errors) != 0 {
        os.LogStr("Error: non-laundering unknown fixture rejected safe-arena branded binding");
        os.LogStr(env_safe_unknown_nlaunder.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: non-laundering unknown safe-branded provenance enforcement verified!");
}