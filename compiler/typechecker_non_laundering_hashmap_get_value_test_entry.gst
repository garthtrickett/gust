import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_int_hgv_nlaunder := typechecker.make_type_int();
    mut t_idx_hgv_nlaunder := typechecker.make_type_index("HashMapGetValueNlaunderNode", "ctx", ctx);
    mut t_ptr_int_hgv_nlaunder := typechecker.make_type_pointer(t_int_hgv_nlaunder, ctx);
    mut t_ptr_idx_hgv_nlaunder := typechecker.make_type_pointer(t_idx_hgv_nlaunder, ctx);

    mut map_layout_hgv_nlaunder: typechecker.StructLayout[ctx];
    unsafe {
        map_layout_hgv_nlaunder.brand = empty[Index[str, ctx]];
        map_layout_hgv_nlaunder.fields = std.HashMapNew(ctx);
    }
    map_layout_hgv_nlaunder.fields.Insert("keys", t_ptr_int_hgv_nlaunder);
    map_layout_hgv_nlaunder.fields.Insert("values", t_ptr_idx_hgv_nlaunder);

    mut t_map_hgv_nlaunder := typechecker.make_type_struct("HashMap_Int_HashMapGetValueNlaunderNode", "", ctx);

    mut env_raw_hgv_nlaunder := typechecker.env_new(ctx);
    mut scope_raw_hgv_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_raw_hgv_nlaunder, "HashMap_Int_HashMapGetValueNlaunderNode", map_layout_hgv_nlaunder, ctx);

    typechecker.scope_insert(scope_raw_hgv_nlaunder, "map_raw_hgv_nlaunder", t_map_hgv_nlaunder, ctx);
    env_raw_hgv_nlaunder.variable_types.Insert("map_raw_hgv_nlaunder", t_map_hgv_nlaunder);

    typechecker.scope_insert(scope_raw_hgv_nlaunder, "key_raw_hgv_nlaunder", t_int_hgv_nlaunder, ctx);
    env_raw_hgv_nlaunder.variable_types.Insert("key_raw_hgv_nlaunder", t_int_hgv_nlaunder);

    mut raw_origins_hgv_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(raw_origins_hgv_nlaunder, "raw_hashmap_get_value_nlaunder_root", ctx);
    mut raw_cell_prov_hgv_nlaunder := typechecker.expression_provenance_raw_derived(t_idx_hgv_nlaunder, ctx);
    raw_cell_prov_hgv_nlaunder.legacy_origins = raw_origins_hgv_nlaunder;
    typechecker.env_record_container_provenance(&env_raw_hgv_nlaunder, "map_raw_hgv_nlaunder[key_raw_hgv_nlaunder]", raw_cell_prov_hgv_nlaunder, ctx);
    env_raw_hgv_nlaunder.checked_results.Insert("map_raw_hgv_nlaunder.Get(key_raw_hgv_nlaunder)", 1);

    mut lex_raw_bind_hgv_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_raw_bind_hgv_nlaunder, "mut alias_raw_hgv_nlaunder := map_raw_hgv_nlaunder.Get(key_raw_hgv_nlaunder).Val;");
    mut parser_raw_bind_hgv_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_raw_bind_hgv_nlaunder, &lex_raw_bind_hgv_nlaunder, ctx);
    mut stmt_raw_bind_hgv_nlaunder := parser.parse_statement(&parser_raw_bind_hgv_nlaunder, ctx);

    typechecker.check_statement(stmt_raw_bind_hgv_nlaunder, &env_raw_hgv_nlaunder, scope_raw_hgv_nlaunder, ctx);

    if len(env_raw_hgv_nlaunder.errors) == 0 {
        os.LogStr("Error: expected raw-derived HashMap.Get(key).Val binding non-laundering rejection");
        os.Exit(1);
    }
    if std.str_find(env_raw_hgv_nlaunder.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: HashMap.Get(key).Val raw binding emitted wrong diagnostic");
        os.LogStr(env_raw_hgv_nlaunder.errors[0].message);
        os.Exit(1);
    }

    mut env_raw_assign_hgv_nlaunder := typechecker.env_new(ctx);
    mut scope_raw_assign_hgv_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_raw_assign_hgv_nlaunder, "HashMap_Int_HashMapGetValueNlaunderNode", map_layout_hgv_nlaunder, ctx);

    typechecker.scope_insert(scope_raw_assign_hgv_nlaunder, "map_raw_assign_hgv_nlaunder", t_map_hgv_nlaunder, ctx);
    env_raw_assign_hgv_nlaunder.variable_types.Insert("map_raw_assign_hgv_nlaunder", t_map_hgv_nlaunder);

    typechecker.scope_insert(scope_raw_assign_hgv_nlaunder, "key_raw_assign_hgv_nlaunder", t_int_hgv_nlaunder, ctx);
    env_raw_assign_hgv_nlaunder.variable_types.Insert("key_raw_assign_hgv_nlaunder", t_int_hgv_nlaunder);

    typechecker.scope_insert(scope_raw_assign_hgv_nlaunder, "target_raw_assign_hgv_nlaunder", t_idx_hgv_nlaunder, ctx);
    env_raw_assign_hgv_nlaunder.variable_types.Insert("target_raw_assign_hgv_nlaunder", t_idx_hgv_nlaunder);

    mut raw_assign_origins_hgv_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(raw_assign_origins_hgv_nlaunder, "raw_hashmap_get_value_assignment_nlaunder_root", ctx);
    mut raw_assign_cell_prov_hgv_nlaunder := typechecker.expression_provenance_raw_derived(t_idx_hgv_nlaunder, ctx);
    raw_assign_cell_prov_hgv_nlaunder.legacy_origins = raw_assign_origins_hgv_nlaunder;
    typechecker.env_record_container_provenance(&env_raw_assign_hgv_nlaunder, "map_raw_assign_hgv_nlaunder[key_raw_assign_hgv_nlaunder]", raw_assign_cell_prov_hgv_nlaunder, ctx);
    env_raw_assign_hgv_nlaunder.checked_results.Insert("map_raw_assign_hgv_nlaunder.Get(key_raw_assign_hgv_nlaunder)", 1);

    mut lex_raw_assign_hgv_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_raw_assign_hgv_nlaunder, "target_raw_assign_hgv_nlaunder = map_raw_assign_hgv_nlaunder.Get(key_raw_assign_hgv_nlaunder).Val;");
    mut parser_raw_assign_hgv_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_raw_assign_hgv_nlaunder, &lex_raw_assign_hgv_nlaunder, ctx);
    mut stmt_raw_assign_hgv_nlaunder := parser.parse_statement(&parser_raw_assign_hgv_nlaunder, ctx);

    typechecker.check_statement(stmt_raw_assign_hgv_nlaunder, &env_raw_assign_hgv_nlaunder, scope_raw_assign_hgv_nlaunder, ctx);

    if len(env_raw_assign_hgv_nlaunder.errors) == 0 {
        os.LogStr("Error: expected raw-derived HashMap.Get(key).Val assignment non-laundering rejection");
        os.Exit(1);
    }
    if std.str_find(env_raw_assign_hgv_nlaunder.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: HashMap.Get(key).Val raw assignment emitted wrong diagnostic");
        os.LogStr(env_raw_assign_hgv_nlaunder.errors[0].message);
        os.Exit(1);
    }

    mut env_sandbox_hgv_nlaunder := typechecker.env_new(ctx);
    mut scope_sandbox_hgv_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_sandbox_hgv_nlaunder, "HashMap_Int_HashMapGetValueNlaunderNode", map_layout_hgv_nlaunder, ctx);

    typechecker.scope_insert(scope_sandbox_hgv_nlaunder, "map_sandbox_hgv_nlaunder", t_map_hgv_nlaunder, ctx);
    env_sandbox_hgv_nlaunder.variable_types.Insert("map_sandbox_hgv_nlaunder", t_map_hgv_nlaunder);

    typechecker.scope_insert(scope_sandbox_hgv_nlaunder, "key_sandbox_hgv_nlaunder", t_int_hgv_nlaunder, ctx);
    env_sandbox_hgv_nlaunder.variable_types.Insert("key_sandbox_hgv_nlaunder", t_int_hgv_nlaunder);

    typechecker.scope_insert(scope_sandbox_hgv_nlaunder, "target_sandbox_hgv_nlaunder", t_idx_hgv_nlaunder, ctx);
    env_sandbox_hgv_nlaunder.variable_types.Insert("target_sandbox_hgv_nlaunder", t_idx_hgv_nlaunder);

    mut sandbox_origins_hgv_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(sandbox_origins_hgv_nlaunder, "sandbox_hashmap_get_value_nlaunder_root", ctx);
    mut sandbox_cell_prov_hgv_nlaunder := typechecker.expression_provenance_sandbox_derived(t_idx_hgv_nlaunder, ctx);
    sandbox_cell_prov_hgv_nlaunder.legacy_origins = sandbox_origins_hgv_nlaunder;
    typechecker.env_record_container_provenance(&env_sandbox_hgv_nlaunder, "map_sandbox_hgv_nlaunder[key_sandbox_hgv_nlaunder]", sandbox_cell_prov_hgv_nlaunder, ctx);
    env_sandbox_hgv_nlaunder.checked_results.Insert("map_sandbox_hgv_nlaunder.Get(key_sandbox_hgv_nlaunder)", 1);

    mut lex_sandbox_assign_hgv_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_sandbox_assign_hgv_nlaunder, "target_sandbox_hgv_nlaunder = map_sandbox_hgv_nlaunder.Get(key_sandbox_hgv_nlaunder).Val;");
    mut parser_sandbox_assign_hgv_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_sandbox_assign_hgv_nlaunder, &lex_sandbox_assign_hgv_nlaunder, ctx);
    mut stmt_sandbox_assign_hgv_nlaunder := parser.parse_statement(&parser_sandbox_assign_hgv_nlaunder, ctx);

    typechecker.check_statement(stmt_sandbox_assign_hgv_nlaunder, &env_sandbox_hgv_nlaunder, scope_sandbox_hgv_nlaunder, ctx);

    if len(env_sandbox_hgv_nlaunder.errors) == 0 {
        os.LogStr("Error: expected sandbox-derived HashMap.Get(key).Val assignment non-laundering rejection");
        os.Exit(1);
    }
    if std.str_find(env_sandbox_hgv_nlaunder.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: HashMap.Get(key).Val sandbox assignment emitted wrong diagnostic");
        os.LogStr(env_sandbox_hgv_nlaunder.errors[0].message);
        os.Exit(1);
    }

    mut env_safe_hgv_nlaunder := typechecker.env_new(ctx);
    mut scope_safe_hgv_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_safe_hgv_nlaunder, "HashMap_Int_HashMapGetValueNlaunderNode", map_layout_hgv_nlaunder, ctx);

    typechecker.scope_insert(scope_safe_hgv_nlaunder, "map_safe_hgv_nlaunder", t_map_hgv_nlaunder, ctx);
    env_safe_hgv_nlaunder.variable_types.Insert("map_safe_hgv_nlaunder", t_map_hgv_nlaunder);

    typechecker.scope_insert(scope_safe_hgv_nlaunder, "key_safe_hgv_nlaunder", t_int_hgv_nlaunder, ctx);
    env_safe_hgv_nlaunder.variable_types.Insert("key_safe_hgv_nlaunder", t_int_hgv_nlaunder);

    mut safe_origins_hgv_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_hgv_nlaunder, "safe_hashmap_get_value_nlaunder_root", ctx);
    mut safe_cell_prov_hgv_nlaunder := typechecker.expression_provenance_safe_arena(t_idx_hgv_nlaunder, ctx);
    safe_cell_prov_hgv_nlaunder.legacy_origins = safe_origins_hgv_nlaunder;
    typechecker.env_record_container_provenance(&env_safe_hgv_nlaunder, "map_safe_hgv_nlaunder[key_safe_hgv_nlaunder]", safe_cell_prov_hgv_nlaunder, ctx);
    env_safe_hgv_nlaunder.checked_results.Insert("map_safe_hgv_nlaunder.Get(key_safe_hgv_nlaunder)", 1);

    mut lex_safe_bind_hgv_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_safe_bind_hgv_nlaunder, "mut alias_safe_hgv_nlaunder := map_safe_hgv_nlaunder.Get(key_safe_hgv_nlaunder).Val;");
    mut parser_safe_bind_hgv_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_safe_bind_hgv_nlaunder, &lex_safe_bind_hgv_nlaunder, ctx);
    mut stmt_safe_bind_hgv_nlaunder := parser.parse_statement(&parser_safe_bind_hgv_nlaunder, ctx);

    typechecker.check_statement(stmt_safe_bind_hgv_nlaunder, &env_safe_hgv_nlaunder, scope_safe_hgv_nlaunder, ctx);

    if len(env_safe_hgv_nlaunder.errors) != 0 {
        os.LogStr("Error: safe HashMap.Get(key).Val binding unexpectedly rejected");
        os.LogStr(env_safe_hgv_nlaunder.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: HashMap.Get value non-laundering enforcement verified!");
}
