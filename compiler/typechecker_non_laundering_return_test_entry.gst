import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_idx_nlr := typechecker.make_type_index("SafeCellNonLaundry", "ctx", ctx);

    mut env_raw_nlr := typechecker.env_new(ctx);
    mut scope_raw_nlr := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.scope_insert(scope_raw_nlr, "raw_idx", t_idx_nlr, ctx);
    env_raw_nlr.variable_types.Insert("raw_idx", t_idx_nlr);

    mut raw_origins_nlr := typechecker.set_init(ctx);
    typechecker.set_add(raw_origins_nlr, "raw_root", ctx);
    env_raw_nlr.variable_origins.Insert("raw_idx", raw_origins_nlr);

    mut raw_prov_nlr := typechecker.expression_provenance_raw_derived(t_idx_nlr, ctx);
    raw_prov_nlr.legacy_origins = raw_origins_nlr;
    typechecker.env_record_variable_provenance(&env_raw_nlr, "raw_idx", raw_prov_nlr, ctx);

    mut ret_idx_raw_nlr: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(ret_idx_raw_nlr, t_idx_nlr);
    env_raw_nlr.expected_return_type = ret_idx_raw_nlr;
    env_raw_nlr.current_function_return_origins = typechecker.set_init(ctx);
    env_raw_nlr.current_function_return_provenance = typechecker.expression_provenance_unknown(t_idx_nlr, ctx);

    mut lex_raw_nlr: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_raw_nlr, "return raw_idx;");
    mut parser_raw_nlr: parser.Parser[ctx];
    parser.init_parser(&parser_raw_nlr, &lex_raw_nlr, ctx);
    mut stmt_raw_nlr := parser.parse_statement(&parser_raw_nlr, ctx);

    typechecker.check_statement(stmt_raw_nlr, &env_raw_nlr, scope_raw_nlr, ctx);

    if len(env_raw_nlr.errors) == 0 {
        os.LogStr("Error: non-laundering return fixture expected raw-derived branded return rejection");
        os.Exit(1);
    }
    if std.str_find(env_raw_nlr.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: non-laundering return fixture emitted wrong diagnostic");
        os.LogStr(env_raw_nlr.errors[0].message);
        os.Exit(1);
    }

    mut t_str_nlr := typechecker.make_type_str();
    mut t_ref_nlr := typechecker.make_type_reference(t_str_nlr, "ctx", ctx);

    mut env_sandbox_nlr := typechecker.env_new(ctx);
    mut scope_sandbox_nlr := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.scope_insert(scope_sandbox_nlr, "sandbox_ref", t_ref_nlr, ctx);
    env_sandbox_nlr.variable_types.Insert("sandbox_ref", t_ref_nlr);

    mut sandbox_origins_nlr := typechecker.set_init(ctx);
    typechecker.set_add(sandbox_origins_nlr, "sandbox_root", ctx);
    env_sandbox_nlr.variable_origins.Insert("sandbox_ref", sandbox_origins_nlr);

    mut sandbox_prov_nlr := typechecker.expression_provenance_sandbox_derived(t_ref_nlr, ctx);
    sandbox_prov_nlr.legacy_origins = sandbox_origins_nlr;
    typechecker.env_record_variable_provenance(&env_sandbox_nlr, "sandbox_ref", sandbox_prov_nlr, ctx);

    mut ret_ref_sandbox_nlr: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(ret_ref_sandbox_nlr, t_ref_nlr);
    env_sandbox_nlr.expected_return_type = ret_ref_sandbox_nlr;
    env_sandbox_nlr.current_function_return_origins = typechecker.set_init(ctx);
    env_sandbox_nlr.current_function_return_provenance = typechecker.expression_provenance_unknown(t_ref_nlr, ctx);

    mut lex_sandbox_nlr: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_sandbox_nlr, "return sandbox_ref;");
    mut parser_sandbox_nlr: parser.Parser[ctx];
    parser.init_parser(&parser_sandbox_nlr, &lex_sandbox_nlr, ctx);
    mut stmt_sandbox_nlr := parser.parse_statement(&parser_sandbox_nlr, ctx);

    typechecker.check_statement(stmt_sandbox_nlr, &env_sandbox_nlr, scope_sandbox_nlr, ctx);

    if len(env_sandbox_nlr.errors) == 0 {
        os.LogStr("Error: non-laundering return fixture expected sandbox-derived branded reference rejection");
        os.Exit(1);
    }
    if std.str_find(env_sandbox_nlr.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: non-laundering sandbox return fixture emitted wrong diagnostic");
        os.LogStr(env_sandbox_nlr.errors[0].message);
        os.Exit(1);
    }

    mut env_safe_nlr := typechecker.env_new(ctx);
    mut scope_safe_nlr := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.scope_insert(scope_safe_nlr, "safe_idx", t_idx_nlr, ctx);
    env_safe_nlr.variable_types.Insert("safe_idx", t_idx_nlr);

    mut safe_origins_nlr := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_nlr, "safe_root", ctx);
    env_safe_nlr.variable_origins.Insert("safe_idx", safe_origins_nlr);

    mut safe_prov_nlr := typechecker.expression_provenance_safe_arena(t_idx_nlr, ctx);
    safe_prov_nlr.legacy_origins = safe_origins_nlr;
    typechecker.env_record_variable_provenance(&env_safe_nlr, "safe_idx", safe_prov_nlr, ctx);

    mut ret_idx_safe_nlr: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(ret_idx_safe_nlr, t_idx_nlr);
    env_safe_nlr.expected_return_type = ret_idx_safe_nlr;
    env_safe_nlr.current_function_return_origins = typechecker.set_init(ctx);
    env_safe_nlr.current_function_return_provenance = typechecker.expression_provenance_unknown(t_idx_nlr, ctx);

    mut lex_safe_nlr: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_safe_nlr, "return safe_idx;");
    mut parser_safe_nlr: parser.Parser[ctx];
    parser.init_parser(&parser_safe_nlr, &lex_safe_nlr, ctx);
    mut stmt_safe_nlr := parser.parse_statement(&parser_safe_nlr, ctx);

    typechecker.check_statement(stmt_safe_nlr, &env_safe_nlr, scope_safe_nlr, ctx);

    if len(env_safe_nlr.errors) != 0 {
        os.LogStr("Error: non-laundering return fixture rejected safe-arena branded return");
        os.LogStr(env_safe_nlr.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: non-laundering branded return enforcement verified!");
}