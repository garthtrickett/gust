import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_arena_aw_nlaunder := typechecker.make_type_arena();
    mut t_idx_aw_nlaunder := typechecker.make_type_index("SafeArenaWriteNode", "ctx", ctx);

    mut env_raw_aw_nlaunder := typechecker.env_new(ctx);
    mut scope_raw_aw_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.scope_insert(scope_raw_aw_nlaunder, "ctx", t_arena_aw_nlaunder, ctx);
    env_raw_aw_nlaunder.variable_types.Insert("ctx", t_arena_aw_nlaunder);

    typechecker.scope_insert(scope_raw_aw_nlaunder, "target_idx_aw_nlaunder", t_idx_aw_nlaunder, ctx);
    env_raw_aw_nlaunder.variable_types.Insert("target_idx_aw_nlaunder", t_idx_aw_nlaunder);

    typechecker.scope_insert(scope_raw_aw_nlaunder, "raw_idx_aw_nlaunder", t_idx_aw_nlaunder, ctx);
    env_raw_aw_nlaunder.variable_types.Insert("raw_idx_aw_nlaunder", t_idx_aw_nlaunder);

    mut raw_origins_aw_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(raw_origins_aw_nlaunder, "raw_arena_write_root", ctx);
    env_raw_aw_nlaunder.variable_origins.Insert("raw_idx_aw_nlaunder", raw_origins_aw_nlaunder);

    mut raw_prov_aw_nlaunder := typechecker.expression_provenance_raw_derived(t_idx_aw_nlaunder, ctx);
    raw_prov_aw_nlaunder.legacy_origins = raw_origins_aw_nlaunder;
    typechecker.env_record_variable_provenance(&env_raw_aw_nlaunder, "raw_idx_aw_nlaunder", raw_prov_aw_nlaunder, ctx);

    mut lex_raw_aw_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_raw_aw_nlaunder, "ctx.Set(target_idx_aw_nlaunder, raw_idx_aw_nlaunder);");
    mut parser_raw_aw_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_raw_aw_nlaunder, &lex_raw_aw_nlaunder, ctx);
    mut stmt_raw_aw_nlaunder := parser.parse_statement(&parser_raw_aw_nlaunder, ctx);

    typechecker.check_statement(stmt_raw_aw_nlaunder, &env_raw_aw_nlaunder, scope_raw_aw_nlaunder, ctx);

    if len(env_raw_aw_nlaunder.errors) == 0 {
        os.LogStr("Error: non-laundering arena write fixture expected raw-derived Arena.Set rejection");
        os.Exit(1);
    }
    if std.str_find(env_raw_aw_nlaunder.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: non-laundering arena write fixture emitted wrong diagnostic");
        os.LogStr(env_raw_aw_nlaunder.errors[0].message);
        os.Exit(1);
    }

    mut env_safe_aw_nlaunder := typechecker.env_new(ctx);
    mut scope_safe_aw_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.scope_insert(scope_safe_aw_nlaunder, "ctx", t_arena_aw_nlaunder, ctx);
    env_safe_aw_nlaunder.variable_types.Insert("ctx", t_arena_aw_nlaunder);

    typechecker.scope_insert(scope_safe_aw_nlaunder, "target_idx_safe_aw_nlaunder", t_idx_aw_nlaunder, ctx);
    env_safe_aw_nlaunder.variable_types.Insert("target_idx_safe_aw_nlaunder", t_idx_aw_nlaunder);

    typechecker.scope_insert(scope_safe_aw_nlaunder, "safe_idx_aw_nlaunder", t_idx_aw_nlaunder, ctx);
    env_safe_aw_nlaunder.variable_types.Insert("safe_idx_aw_nlaunder", t_idx_aw_nlaunder);

    mut safe_origins_aw_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_aw_nlaunder, "safe_arena_write_root", ctx);
    env_safe_aw_nlaunder.variable_origins.Insert("safe_idx_aw_nlaunder", safe_origins_aw_nlaunder);

    mut safe_prov_aw_nlaunder := typechecker.expression_provenance_safe_arena(t_idx_aw_nlaunder, ctx);
    safe_prov_aw_nlaunder.legacy_origins = safe_origins_aw_nlaunder;
    typechecker.env_record_variable_provenance(&env_safe_aw_nlaunder, "safe_idx_aw_nlaunder", safe_prov_aw_nlaunder, ctx);

    mut lex_safe_aw_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_safe_aw_nlaunder, "ctx.Write(target_idx_safe_aw_nlaunder, safe_idx_aw_nlaunder);");
    mut parser_safe_aw_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_safe_aw_nlaunder, &lex_safe_aw_nlaunder, ctx);
    mut stmt_safe_aw_nlaunder := parser.parse_statement(&parser_safe_aw_nlaunder, ctx);

    typechecker.check_statement(stmt_safe_aw_nlaunder, &env_safe_aw_nlaunder, scope_safe_aw_nlaunder, ctx);

    if len(env_safe_aw_nlaunder.errors) != 0 {
        os.LogStr("Error: non-laundering arena write fixture rejected safe-arena Arena.Write value");
        os.LogStr(env_safe_aw_nlaunder.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: non-laundering Arena.Set/Write enforcement verified!");
}