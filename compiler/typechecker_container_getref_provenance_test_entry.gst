import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_int_cgetrefprov := typechecker.make_type_int();
    mut t_idx_cgetrefprov := typechecker.make_type_index("ContainerGetRefProvenanceNode", "ctx", ctx);
    mut t_ptr_idx_cgetrefprov := typechecker.make_type_pointer(t_idx_cgetrefprov, ctx);
    mut t_ptr_int_cgetrefprov := typechecker.make_type_pointer(t_int_cgetrefprov, ctx);

    mut vector_layout_cgetrefprov: typechecker.StructLayout[ctx];
    unsafe {
        vector_layout_cgetrefprov.brand = empty[Index[str, ctx]];
        vector_layout_cgetrefprov.fields = std.HashMapNew(ctx);
    }
    vector_layout_cgetrefprov.fields.Insert("data", t_ptr_idx_cgetrefprov);

    mut map_layout_cgetrefprov: typechecker.StructLayout[ctx];
    unsafe {
        map_layout_cgetrefprov.brand = empty[Index[str, ctx]];
        map_layout_cgetrefprov.fields = std.HashMapNew(ctx);
    }
    map_layout_cgetrefprov.fields.Insert("keys", t_ptr_int_cgetrefprov);
    map_layout_cgetrefprov.fields.Insert("values", t_ptr_idx_cgetrefprov);

    mut t_vector_cgetrefprov := typechecker.make_type_struct("Vector_ContainerGetRefProvenanceNode", "", ctx);
    mut t_map_cgetrefprov := typechecker.make_type_struct("HashMap_Int_ContainerGetRefProvenanceNode", "", ctx);

    mut env_cgetrefprov := typechecker.env_new(ctx);
    mut scope_cgetrefprov := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_cgetrefprov, "Vector_ContainerGetRefProvenanceNode", vector_layout_cgetrefprov, ctx);
    typechecker.env_register_struct(&env_cgetrefprov, "HashMap_Int_ContainerGetRefProvenanceNode", map_layout_cgetrefprov, ctx);
    typechecker.env_record_struct_container_kind(&env_cgetrefprov, "Vector_ContainerGetRefProvenanceNode", typechecker.typechecker_container_kind_vector(), ctx);
    typechecker.env_record_struct_container_kind(&env_cgetrefprov, "HashMap_Int_ContainerGetRefProvenanceNode", typechecker.typechecker_container_kind_hashmap(), ctx);

    typechecker.scope_insert(scope_cgetrefprov, "values_cgetrefprov", t_vector_cgetrefprov, ctx);
    env_cgetrefprov.variable_types.Insert("values_cgetrefprov", t_vector_cgetrefprov);

    typechecker.scope_insert(scope_cgetrefprov, "i_cgetrefprov", t_int_cgetrefprov, ctx);
    env_cgetrefprov.variable_types.Insert("i_cgetrefprov", t_int_cgetrefprov);

    typechecker.scope_insert(scope_cgetrefprov, "safe_idx_cgetrefprov", t_idx_cgetrefprov, ctx);
    env_cgetrefprov.variable_types.Insert("safe_idx_cgetrefprov", t_idx_cgetrefprov);

    mut safe_origins_cgetrefprov := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_cgetrefprov, "safe_container_getref_root", ctx);
    env_cgetrefprov.variable_origins.Insert("safe_idx_cgetrefprov", safe_origins_cgetrefprov);

    mut safe_prov_cgetrefprov := typechecker.expression_provenance_safe_arena(t_idx_cgetrefprov, ctx);
    safe_prov_cgetrefprov.legacy_origins = safe_origins_cgetrefprov;
    typechecker.env_record_variable_provenance(&env_cgetrefprov, "safe_idx_cgetrefprov", safe_prov_cgetrefprov, ctx);

    mut lex_vector_set_cgetrefprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_vector_set_cgetrefprov, "values_cgetrefprov.Set(i_cgetrefprov, safe_idx_cgetrefprov);");
    mut parser_vector_set_cgetrefprov: parser.Parser[ctx];
    parser.init_parser(&parser_vector_set_cgetrefprov, &lex_vector_set_cgetrefprov, ctx);
    mut stmt_vector_set_cgetrefprov := parser.parse_statement(&parser_vector_set_cgetrefprov, ctx);
    typechecker.check_statement(stmt_vector_set_cgetrefprov, &env_cgetrefprov, scope_cgetrefprov, ctx);

    if len(env_cgetrefprov.errors) != 0 {
        os.LogStr("Error: Vector.Set setup for GetRef provenance produced unexpected typechecker error");
        os.LogStr(env_cgetrefprov.errors[0].message);
        os.Exit(1);
    }

    mut lex_vector_getref_cgetrefprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_vector_getref_cgetrefprov, "values_cgetrefprov.GetRef(i_cgetrefprov)");
    mut parser_vector_getref_cgetrefprov: parser.Parser[ctx];
    parser.init_parser(&parser_vector_getref_cgetrefprov, &lex_vector_getref_cgetrefprov, ctx);
    mut expr_vector_getref_cgetrefprov := parser.parse_expression(&parser_vector_getref_cgetrefprov, 1, ctx);

    mut vector_getref_prov_cgetrefprov := typechecker.check_expression_with_provenance(expr_vector_getref_cgetrefprov, &env_cgetrefprov, scope_cgetrefprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(vector_getref_prov_cgetrefprov) != 1 {
        os.LogStr("Error: Vector.GetRef did not preserve safe container-cell provenance");
        os.Exit(1);
    }
    if typechecker.set_contains(vector_getref_prov_cgetrefprov.legacy_origins, "safe_container_getref_root", ctx) != 1 {
        os.LogStr("Error: Vector.GetRef did not preserve safe container-cell legacy origin");
        os.Exit(1);
    }

    typechecker.scope_insert(scope_cgetrefprov, "map_cgetrefprov", t_map_cgetrefprov, ctx);
    env_cgetrefprov.variable_types.Insert("map_cgetrefprov", t_map_cgetrefprov);

    typechecker.scope_insert(scope_cgetrefprov, "key_cgetrefprov", t_int_cgetrefprov, ctx);
    env_cgetrefprov.variable_types.Insert("key_cgetrefprov", t_int_cgetrefprov);

    mut lex_map_set_cgetrefprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_map_set_cgetrefprov, "map_cgetrefprov.Set(key_cgetrefprov, safe_idx_cgetrefprov);");
    mut parser_map_set_cgetrefprov: parser.Parser[ctx];
    parser.init_parser(&parser_map_set_cgetrefprov, &lex_map_set_cgetrefprov, ctx);
    mut stmt_map_set_cgetrefprov := parser.parse_statement(&parser_map_set_cgetrefprov, ctx);
    typechecker.check_statement(stmt_map_set_cgetrefprov, &env_cgetrefprov, scope_cgetrefprov, ctx);

    if len(env_cgetrefprov.errors) != 0 {
        os.LogStr("Error: HashMap.Set setup for GetRef provenance produced unexpected typechecker error");
        os.LogStr(env_cgetrefprov.errors[0].message);
        os.Exit(1);
    }

    mut lex_map_getref_cgetrefprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_map_getref_cgetrefprov, "map_cgetrefprov.GetRef(key_cgetrefprov)");
    mut parser_map_getref_cgetrefprov: parser.Parser[ctx];
    parser.init_parser(&parser_map_getref_cgetrefprov, &lex_map_getref_cgetrefprov, ctx);
    mut expr_map_getref_cgetrefprov := parser.parse_expression(&parser_map_getref_cgetrefprov, 1, ctx);

    mut map_getref_prov_cgetrefprov := typechecker.check_expression_with_provenance(expr_map_getref_cgetrefprov, &env_cgetrefprov, scope_cgetrefprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(map_getref_prov_cgetrefprov) != 1 {
        os.LogStr("Error: HashMap.GetRef did not preserve safe container-cell provenance");
        os.Exit(1);
    }
    if typechecker.set_contains(map_getref_prov_cgetrefprov.legacy_origins, "safe_container_getref_root", ctx) != 1 {
        os.LogStr("Error: HashMap.GetRef did not preserve safe container-cell legacy origin");
        os.Exit(1);
    }

    typechecker.scope_insert(scope_cgetrefprov, "values_raw_cgetrefprov", t_vector_cgetrefprov, ctx);
    env_cgetrefprov.variable_types.Insert("values_raw_cgetrefprov", t_vector_cgetrefprov);

    typechecker.scope_insert(scope_cgetrefprov, "i_raw_cgetrefprov", t_int_cgetrefprov, ctx);
    env_cgetrefprov.variable_types.Insert("i_raw_cgetrefprov", t_int_cgetrefprov);

    mut raw_origins_cgetrefprov := typechecker.set_init(ctx);
    typechecker.set_add(raw_origins_cgetrefprov, "raw_container_getref_root", ctx);
    mut raw_cell_prov_cgetrefprov := typechecker.expression_provenance_raw_derived(t_idx_cgetrefprov, ctx);
    raw_cell_prov_cgetrefprov.legacy_origins = raw_origins_cgetrefprov;
    typechecker.env_record_container_provenance(&env_cgetrefprov, "values_raw_cgetrefprov[i_raw_cgetrefprov]", raw_cell_prov_cgetrefprov, ctx);

    mut lex_raw_vector_getref_cgetrefprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_raw_vector_getref_cgetrefprov, "values_raw_cgetrefprov.GetRef(i_raw_cgetrefprov)");
    mut parser_raw_vector_getref_cgetrefprov: parser.Parser[ctx];
    parser.init_parser(&parser_raw_vector_getref_cgetrefprov, &lex_raw_vector_getref_cgetrefprov, ctx);
    mut expr_raw_vector_getref_cgetrefprov := parser.parse_expression(&parser_raw_vector_getref_cgetrefprov, 1, ctx);

    mut raw_vector_getref_prov_cgetrefprov := typechecker.check_expression_with_provenance(expr_raw_vector_getref_cgetrefprov, &env_cgetrefprov, scope_cgetrefprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(raw_vector_getref_prov_cgetrefprov) == 1 {
        os.LogStr("Error: Vector.GetRef incorrectly allowed safe branding from raw-derived container-cell provenance");
        os.Exit(1);
    }
    if typechecker.expression_provenance_is_raw_or_sandbox_derived(raw_vector_getref_prov_cgetrefprov) != 1 {
        os.LogStr("Error: Vector.GetRef did not preserve raw-derived container-cell provenance");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: container GetRef provenance metadata verified!");
}
