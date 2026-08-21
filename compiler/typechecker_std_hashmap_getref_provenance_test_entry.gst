import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_int_stdhashgetrefprov := typechecker.make_type_int();
    mut t_idx_stdhashgetrefprov := typechecker.make_type_index("StdHashMapGetRefProvenanceNode", "ctx", ctx);
    mut t_ptr_int_stdhashgetrefprov := typechecker.make_type_pointer(t_int_stdhashgetrefprov, ctx);
    mut t_ptr_idx_stdhashgetrefprov := typechecker.make_type_pointer(t_idx_stdhashgetrefprov, ctx);

    mut map_layout_stdhashgetrefprov: typechecker.StructLayout[ctx];
    unsafe {
        map_layout_stdhashgetrefprov.brand = empty[Index[str, ctx]];
        map_layout_stdhashgetrefprov.fields = std.HashMapNew(ctx);
    }
    map_layout_stdhashgetrefprov.fields.Insert("keys", t_ptr_int_stdhashgetrefprov);
    map_layout_stdhashgetrefprov.fields.Insert("values", t_ptr_idx_stdhashgetrefprov);

    mut t_map_stdhashgetrefprov := typechecker.make_type_struct("HashMap_Int_StdHashMapGetRefProvenanceNode", "", ctx);

    mut env_stdhashgetrefprov := typechecker.env_new(ctx);
    mut scope_stdhashgetrefprov := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_stdhashgetrefprov, "HashMap_Int_StdHashMapGetRefProvenanceNode", map_layout_stdhashgetrefprov, ctx);
    typechecker.env_record_struct_container_kind(&env_stdhashgetrefprov, "HashMap_Int_StdHashMapGetRefProvenanceNode", typechecker.typechecker_container_kind_hashmap(), ctx);

    typechecker.scope_insert(scope_stdhashgetrefprov, "map_stdhashgetrefprov", t_map_stdhashgetrefprov, ctx);
    env_stdhashgetrefprov.variable_types.Insert("map_stdhashgetrefprov", t_map_stdhashgetrefprov);

    typechecker.scope_insert(scope_stdhashgetrefprov, "key_stdhashgetrefprov", t_int_stdhashgetrefprov, ctx);
    env_stdhashgetrefprov.variable_types.Insert("key_stdhashgetrefprov", t_int_stdhashgetrefprov);

    typechecker.scope_insert(scope_stdhashgetrefprov, "safe_idx_stdhashgetrefprov", t_idx_stdhashgetrefprov, ctx);
    env_stdhashgetrefprov.variable_types.Insert("safe_idx_stdhashgetrefprov", t_idx_stdhashgetrefprov);

    mut safe_origins_stdhashgetrefprov := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_stdhashgetrefprov, "safe_std_hashmap_getref_root", ctx);
    env_stdhashgetrefprov.variable_origins.Insert("safe_idx_stdhashgetrefprov", safe_origins_stdhashgetrefprov);

    mut safe_prov_stdhashgetrefprov := typechecker.expression_provenance_safe_arena(t_idx_stdhashgetrefprov, ctx);
    safe_prov_stdhashgetrefprov.legacy_origins = safe_origins_stdhashgetrefprov;
    typechecker.env_record_variable_provenance(&env_stdhashgetrefprov, "safe_idx_stdhashgetrefprov", safe_prov_stdhashgetrefprov, ctx);

    mut lex_map_set_stdhashgetrefprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_map_set_stdhashgetrefprov, "map_stdhashgetrefprov.Set(key_stdhashgetrefprov, safe_idx_stdhashgetrefprov);");
    mut parser_map_set_stdhashgetrefprov: parser.Parser[ctx];
    parser.init_parser(&parser_map_set_stdhashgetrefprov, &lex_map_set_stdhashgetrefprov, ctx);
    mut stmt_map_set_stdhashgetrefprov := parser.parse_statement(&parser_map_set_stdhashgetrefprov, ctx);
    typechecker.check_statement(stmt_map_set_stdhashgetrefprov, &env_stdhashgetrefprov, scope_stdhashgetrefprov, ctx);

    if len(env_stdhashgetrefprov.errors) != 0 {
        os.LogStr("Error: HashMap.Set setup for std.HashMapGetRef provenance produced unexpected typechecker error");
        os.LogStr(env_stdhashgetrefprov.errors[0].message);
        os.Exit(1);
    }

    mut lex_std_hashmap_getref_stdhashgetrefprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_std_hashmap_getref_stdhashgetrefprov, "std.HashMapGetRef(map_stdhashgetrefprov, key_stdhashgetrefprov)");
    mut parser_std_hashmap_getref_stdhashgetrefprov: parser.Parser[ctx];
    parser.init_parser(&parser_std_hashmap_getref_stdhashgetrefprov, &lex_std_hashmap_getref_stdhashgetrefprov, ctx);
    mut expr_std_hashmap_getref_stdhashgetrefprov := parser.parse_expression(&parser_std_hashmap_getref_stdhashgetrefprov, 1, ctx);

    mut std_hashmap_getref_prov_stdhashgetrefprov := typechecker.check_expression_with_provenance(expr_std_hashmap_getref_stdhashgetrefprov, &env_stdhashgetrefprov, scope_stdhashgetrefprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(std_hashmap_getref_prov_stdhashgetrefprov) != 1 {
        os.LogStr("Error: std.HashMapGetRef did not preserve safe container-cell provenance");
        os.Exit(1);
    }
    if typechecker.set_contains(std_hashmap_getref_prov_stdhashgetrefprov.legacy_origins, "safe_std_hashmap_getref_root", ctx) != 1 {
        os.LogStr("Error: std.HashMapGetRef did not preserve safe container-cell legacy origin");
        os.Exit(1);
    }

    typechecker.scope_insert(scope_stdhashgetrefprov, "map_raw_stdhashgetrefprov", t_map_stdhashgetrefprov, ctx);
    env_stdhashgetrefprov.variable_types.Insert("map_raw_stdhashgetrefprov", t_map_stdhashgetrefprov);

    typechecker.scope_insert(scope_stdhashgetrefprov, "key_raw_stdhashgetrefprov", t_int_stdhashgetrefprov, ctx);
    env_stdhashgetrefprov.variable_types.Insert("key_raw_stdhashgetrefprov", t_int_stdhashgetrefprov);

    mut raw_origins_stdhashgetrefprov := typechecker.set_init(ctx);
    typechecker.set_add(raw_origins_stdhashgetrefprov, "raw_std_hashmap_getref_root", ctx);
    mut raw_cell_prov_stdhashgetrefprov := typechecker.expression_provenance_raw_derived(t_idx_stdhashgetrefprov, ctx);
    raw_cell_prov_stdhashgetrefprov.legacy_origins = raw_origins_stdhashgetrefprov;
    typechecker.env_record_container_provenance(&env_stdhashgetrefprov, "map_raw_stdhashgetrefprov[key_raw_stdhashgetrefprov]", raw_cell_prov_stdhashgetrefprov, ctx);

    mut lex_raw_std_hashmap_getref_stdhashgetrefprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_raw_std_hashmap_getref_stdhashgetrefprov, "std.HashMapGetRef(map_raw_stdhashgetrefprov, key_raw_stdhashgetrefprov)");
    mut parser_raw_std_hashmap_getref_stdhashgetrefprov: parser.Parser[ctx];
    parser.init_parser(&parser_raw_std_hashmap_getref_stdhashgetrefprov, &lex_raw_std_hashmap_getref_stdhashgetrefprov, ctx);
    mut expr_raw_std_hashmap_getref_stdhashgetrefprov := parser.parse_expression(&parser_raw_std_hashmap_getref_stdhashgetrefprov, 1, ctx);

    mut raw_std_hashmap_getref_prov_stdhashgetrefprov := typechecker.check_expression_with_provenance(expr_raw_std_hashmap_getref_stdhashgetrefprov, &env_stdhashgetrefprov, scope_stdhashgetrefprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(raw_std_hashmap_getref_prov_stdhashgetrefprov) == 1 {
        os.LogStr("Error: std.HashMapGetRef incorrectly allowed safe branding from raw-derived container-cell provenance");
        os.Exit(1);
    }
    if typechecker.expression_provenance_is_raw_or_sandbox_derived(raw_std_hashmap_getref_prov_stdhashgetrefprov) != 1 {
        os.LogStr("Error: std.HashMapGetRef did not preserve raw-derived container-cell provenance");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: std.HashMapGetRef provenance metadata verified!");
}
