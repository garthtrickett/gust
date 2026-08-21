import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_int_hashgetvalprov := typechecker.make_type_int();
    mut t_idx_hashgetvalprov := typechecker.make_type_index("HashMapGetValueProvenanceNode", "ctx", ctx);
    mut t_ptr_int_hashgetvalprov := typechecker.make_type_pointer(t_int_hashgetvalprov, ctx);
    mut t_ptr_idx_hashgetvalprov := typechecker.make_type_pointer(t_idx_hashgetvalprov, ctx);

    mut map_layout_hashgetvalprov: typechecker.StructLayout[ctx];
    unsafe {
        map_layout_hashgetvalprov.brand = empty[Index[str, ctx]];
        map_layout_hashgetvalprov.fields = std.HashMapNew(ctx);
    }
    map_layout_hashgetvalprov.fields.Insert("keys", t_ptr_int_hashgetvalprov);
    map_layout_hashgetvalprov.fields.Insert("values", t_ptr_idx_hashgetvalprov);

    mut t_map_hashgetvalprov := typechecker.make_type_struct("HashMap_Int_HashMapGetValueProvenanceNode", "", ctx);

    mut env_hashgetvalprov := typechecker.env_new(ctx);
    mut scope_hashgetvalprov := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_hashgetvalprov, "HashMap_Int_HashMapGetValueProvenanceNode", map_layout_hashgetvalprov, ctx);
    typechecker.env_record_struct_container_kind(&env_hashgetvalprov, "HashMap_Int_HashMapGetValueProvenanceNode", typechecker.typechecker_container_kind_hashmap(), ctx);

    typechecker.scope_insert(scope_hashgetvalprov, "map_hashgetvalprov", t_map_hashgetvalprov, ctx);
    env_hashgetvalprov.variable_types.Insert("map_hashgetvalprov", t_map_hashgetvalprov);

    typechecker.scope_insert(scope_hashgetvalprov, "key_hashgetvalprov", t_int_hashgetvalprov, ctx);
    env_hashgetvalprov.variable_types.Insert("key_hashgetvalprov", t_int_hashgetvalprov);

    typechecker.scope_insert(scope_hashgetvalprov, "safe_idx_hashgetvalprov", t_idx_hashgetvalprov, ctx);
    env_hashgetvalprov.variable_types.Insert("safe_idx_hashgetvalprov", t_idx_hashgetvalprov);

    mut safe_origins_hashgetvalprov := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_hashgetvalprov, "safe_hashmap_get_value_root", ctx);
    env_hashgetvalprov.variable_origins.Insert("safe_idx_hashgetvalprov", safe_origins_hashgetvalprov);

    mut safe_prov_hashgetvalprov := typechecker.expression_provenance_safe_arena(t_idx_hashgetvalprov, ctx);
    safe_prov_hashgetvalprov.legacy_origins = safe_origins_hashgetvalprov;
    typechecker.env_record_variable_provenance(&env_hashgetvalprov, "safe_idx_hashgetvalprov", safe_prov_hashgetvalprov, ctx);

    mut lex_map_set_hashgetvalprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_map_set_hashgetvalprov, "map_hashgetvalprov.Set(key_hashgetvalprov, safe_idx_hashgetvalprov);");
    mut parser_map_set_hashgetvalprov: parser.Parser[ctx];
    parser.init_parser(&parser_map_set_hashgetvalprov, &lex_map_set_hashgetvalprov, ctx);
    mut stmt_map_set_hashgetvalprov := parser.parse_statement(&parser_map_set_hashgetvalprov, ctx);
    typechecker.check_statement(stmt_map_set_hashgetvalprov, &env_hashgetvalprov, scope_hashgetvalprov, ctx);

    if len(env_hashgetvalprov.errors) != 0 {
        os.LogStr("Error: HashMap.Set setup for HashMap.Get().Val provenance produced unexpected typechecker error");
        os.LogStr(env_hashgetvalprov.errors[0].message);
        os.Exit(1);
    }

    mut lex_get_val_hashgetvalprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_get_val_hashgetvalprov, "map_hashgetvalprov.Get(key_hashgetvalprov).Val");
    mut parser_get_val_hashgetvalprov: parser.Parser[ctx];
    parser.init_parser(&parser_get_val_hashgetvalprov, &lex_get_val_hashgetvalprov, ctx);
    mut expr_get_val_hashgetvalprov := parser.parse_expression(&parser_get_val_hashgetvalprov, 1, ctx);

    mut get_val_prov_hashgetvalprov := typechecker.check_expression_with_provenance(expr_get_val_hashgetvalprov, &env_hashgetvalprov, scope_hashgetvalprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(get_val_prov_hashgetvalprov) != 1 {
        os.LogStr("Error: HashMap.Get(key).Val did not preserve safe container-cell provenance");
        os.Exit(1);
    }
    if typechecker.set_contains(get_val_prov_hashgetvalprov.legacy_origins, "safe_hashmap_get_value_root", ctx) != 1 {
        os.LogStr("Error: HashMap.Get(key).Val did not preserve safe container-cell legacy origin");
        os.Exit(1);
    }

    typechecker.scope_insert(scope_hashgetvalprov, "map_raw_hashgetvalprov", t_map_hashgetvalprov, ctx);
    env_hashgetvalprov.variable_types.Insert("map_raw_hashgetvalprov", t_map_hashgetvalprov);

    typechecker.scope_insert(scope_hashgetvalprov, "key_raw_hashgetvalprov", t_int_hashgetvalprov, ctx);
    env_hashgetvalprov.variable_types.Insert("key_raw_hashgetvalprov", t_int_hashgetvalprov);

    mut raw_origins_hashgetvalprov := typechecker.set_init(ctx);
    typechecker.set_add(raw_origins_hashgetvalprov, "raw_hashmap_get_value_root", ctx);
    mut raw_cell_prov_hashgetvalprov := typechecker.expression_provenance_raw_derived(t_idx_hashgetvalprov, ctx);
    raw_cell_prov_hashgetvalprov.legacy_origins = raw_origins_hashgetvalprov;
    typechecker.env_record_container_provenance(&env_hashgetvalprov, "map_raw_hashgetvalprov[key_raw_hashgetvalprov]", raw_cell_prov_hashgetvalprov, ctx);

    mut lex_raw_get_val_hashgetvalprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_raw_get_val_hashgetvalprov, "map_raw_hashgetvalprov.Get(key_raw_hashgetvalprov).Val");
    mut parser_raw_get_val_hashgetvalprov: parser.Parser[ctx];
    parser.init_parser(&parser_raw_get_val_hashgetvalprov, &lex_raw_get_val_hashgetvalprov, ctx);
    mut expr_raw_get_val_hashgetvalprov := parser.parse_expression(&parser_raw_get_val_hashgetvalprov, 1, ctx);

    mut raw_get_val_prov_hashgetvalprov := typechecker.check_expression_with_provenance(expr_raw_get_val_hashgetvalprov, &env_hashgetvalprov, scope_hashgetvalprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(raw_get_val_prov_hashgetvalprov) == 1 {
        os.LogStr("Error: HashMap.Get(key).Val incorrectly allowed safe branding from raw-derived container-cell provenance");
        os.Exit(1);
    }
    if typechecker.expression_provenance_is_raw_or_sandbox_derived(raw_get_val_prov_hashgetvalprov) != 1 {
        os.LogStr("Error: HashMap.Get(key).Val did not preserve raw-derived container-cell provenance");
        os.Exit(1);
    }

    typechecker.scope_insert(scope_hashgetvalprov, "map_sandbox_hashgetvalprov", t_map_hashgetvalprov, ctx);
    env_hashgetvalprov.variable_types.Insert("map_sandbox_hashgetvalprov", t_map_hashgetvalprov);

    typechecker.scope_insert(scope_hashgetvalprov, "key_sandbox_hashgetvalprov", t_int_hashgetvalprov, ctx);
    env_hashgetvalprov.variable_types.Insert("key_sandbox_hashgetvalprov", t_int_hashgetvalprov);

    mut sandbox_origins_hashgetvalprov := typechecker.set_init(ctx);
    typechecker.set_add(sandbox_origins_hashgetvalprov, "sandbox_hashmap_get_value_root", ctx);
    mut sandbox_cell_prov_hashgetvalprov := typechecker.expression_provenance_sandbox_derived(t_idx_hashgetvalprov, ctx);
    sandbox_cell_prov_hashgetvalprov.legacy_origins = sandbox_origins_hashgetvalprov;
    typechecker.env_record_container_provenance(&env_hashgetvalprov, "map_sandbox_hashgetvalprov[key_sandbox_hashgetvalprov]", sandbox_cell_prov_hashgetvalprov, ctx);

    mut lex_sandbox_get_val_hashgetvalprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_sandbox_get_val_hashgetvalprov, "map_sandbox_hashgetvalprov.Get(key_sandbox_hashgetvalprov).Val");
    mut parser_sandbox_get_val_hashgetvalprov: parser.Parser[ctx];
    parser.init_parser(&parser_sandbox_get_val_hashgetvalprov, &lex_sandbox_get_val_hashgetvalprov, ctx);
    mut expr_sandbox_get_val_hashgetvalprov := parser.parse_expression(&parser_sandbox_get_val_hashgetvalprov, 1, ctx);

    mut sandbox_get_val_prov_hashgetvalprov := typechecker.check_expression_with_provenance(expr_sandbox_get_val_hashgetvalprov, &env_hashgetvalprov, scope_hashgetvalprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(sandbox_get_val_prov_hashgetvalprov) == 1 {
        os.LogStr("Error: HashMap.Get(key).Val incorrectly allowed safe branding from sandbox-derived container-cell provenance");
        os.Exit(1);
    }
    if typechecker.expression_provenance_is_raw_or_sandbox_derived(sandbox_get_val_prov_hashgetvalprov) != 1 {
        os.LogStr("Error: HashMap.Get(key).Val did not preserve sandbox-derived container-cell provenance");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: HashMap.Get value provenance metadata verified!");
}
