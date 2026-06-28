import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_arena_awprov := typechecker.make_type_arena();
    mut t_idx_awprov := typechecker.make_type_index("ArenaWriteProvenanceNode", "ctx", ctx);
    mut t_struct_awprov := typechecker.make_type_struct("ArenaWriteProvenanceNode", "ctx", ctx);

    mut env_set_awprov := typechecker.env_new(ctx);
    mut scope_set_awprov := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.scope_insert(scope_set_awprov, "ctx", t_arena_awprov, ctx);
    env_set_awprov.variable_types.Insert("ctx", t_arena_awprov);

    typechecker.scope_insert(scope_set_awprov, "target_idx_set_awprov", t_idx_awprov, ctx);
    env_set_awprov.variable_types.Insert("target_idx_set_awprov", t_idx_awprov);

    typechecker.scope_insert(scope_set_awprov, "safe_node_set_awprov", t_struct_awprov, ctx);
    env_set_awprov.variable_types.Insert("safe_node_set_awprov", t_struct_awprov);

    mut safe_origins_set_awprov := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_set_awprov, "safe_arena_set_root", ctx);
    env_set_awprov.variable_origins.Insert("safe_node_set_awprov", safe_origins_set_awprov);

    mut safe_prov_set_awprov := typechecker.expression_provenance_safe_arena(t_struct_awprov, ctx);
    safe_prov_set_awprov.legacy_origins = safe_origins_set_awprov;
    typechecker.env_record_variable_provenance(&env_set_awprov, "safe_node_set_awprov", safe_prov_set_awprov, ctx);

    mut lex_set_awprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_set_awprov, "ctx.Set(target_idx_set_awprov, safe_node_set_awprov);");
    mut parser_set_awprov: parser.Parser[ctx];
    parser.init_parser(&parser_set_awprov, &lex_set_awprov, ctx);
    mut stmt_set_awprov := parser.parse_statement(&parser_set_awprov, ctx);

    typechecker.check_statement(stmt_set_awprov, &env_set_awprov, scope_set_awprov, ctx);

    if len(env_set_awprov.errors) != 0 {
        os.LogStr("Error: Arena.Set provenance fixture produced unexpected typechecker error");
        os.LogStr(env_set_awprov.errors[0].message);
        os.Exit(1);
    }

    mut lex_read_set_awprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_read_set_awprov, "ctx[target_idx_set_awprov]");
    mut parser_read_set_awprov: parser.Parser[ctx];
    parser.init_parser(&parser_read_set_awprov, &lex_read_set_awprov, ctx);
    mut expr_read_set_awprov := parser.parse_expression(&parser_read_set_awprov, 1, ctx);

    mut read_prov_set_awprov := typechecker.check_expression_with_provenance(expr_read_set_awprov, &env_set_awprov, scope_set_awprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(read_prov_set_awprov) != 1 {
        os.LogStr("Error: Arena.Set did not record safe-arena slot provenance for indexed readback");
        os.Exit(1);
    }
    if typechecker.set_contains(read_prov_set_awprov.legacy_origins, "safe_arena_set_root", ctx) != 1 {
        os.LogStr("Error: Arena.Set did not preserve value legacy origin for indexed readback");
        os.Exit(1);
    }

    mut env_write_awprov := typechecker.env_new(ctx);
    mut scope_write_awprov := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.scope_insert(scope_write_awprov, "ctx", t_arena_awprov, ctx);
    env_write_awprov.variable_types.Insert("ctx", t_arena_awprov);

    typechecker.scope_insert(scope_write_awprov, "target_idx_write_awprov", t_idx_awprov, ctx);
    env_write_awprov.variable_types.Insert("target_idx_write_awprov", t_idx_awprov);

    typechecker.scope_insert(scope_write_awprov, "safe_node_write_awprov", t_struct_awprov, ctx);
    env_write_awprov.variable_types.Insert("safe_node_write_awprov", t_struct_awprov);

    mut safe_origins_write_awprov := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_write_awprov, "safe_arena_write_root", ctx);
    env_write_awprov.variable_origins.Insert("safe_node_write_awprov", safe_origins_write_awprov);

    mut safe_prov_write_awprov := typechecker.expression_provenance_safe_arena(t_struct_awprov, ctx);
    safe_prov_write_awprov.legacy_origins = safe_origins_write_awprov;
    typechecker.env_record_variable_provenance(&env_write_awprov, "safe_node_write_awprov", safe_prov_write_awprov, ctx);

    mut lex_write_awprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_write_awprov, "ctx.Write(target_idx_write_awprov, safe_node_write_awprov);");
    mut parser_write_awprov: parser.Parser[ctx];
    parser.init_parser(&parser_write_awprov, &lex_write_awprov, ctx);
    mut stmt_write_awprov := parser.parse_statement(&parser_write_awprov, ctx);

    typechecker.check_statement(stmt_write_awprov, &env_write_awprov, scope_write_awprov, ctx);

    if len(env_write_awprov.errors) != 0 {
        os.LogStr("Error: Arena.Write provenance fixture produced unexpected typechecker error");
        os.LogStr(env_write_awprov.errors[0].message);
        os.Exit(1);
    }

    mut lex_read_write_awprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_read_write_awprov, "ctx[target_idx_write_awprov]");
    mut parser_read_write_awprov: parser.Parser[ctx];
    parser.init_parser(&parser_read_write_awprov, &lex_read_write_awprov, ctx);
    mut expr_read_write_awprov := parser.parse_expression(&parser_read_write_awprov, 1, ctx);

    mut read_prov_write_awprov := typechecker.check_expression_with_provenance(expr_read_write_awprov, &env_write_awprov, scope_write_awprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(read_prov_write_awprov) != 1 {
        os.LogStr("Error: Arena.Write did not record safe-arena slot provenance for indexed readback");
        os.Exit(1);
    }
    if typechecker.set_contains(read_prov_write_awprov.legacy_origins, "safe_arena_write_root", ctx) != 1 {
        os.LogStr("Error: Arena.Write did not preserve value legacy origin for indexed readback");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: Arena.Set/Write provenance metadata verified!");
}