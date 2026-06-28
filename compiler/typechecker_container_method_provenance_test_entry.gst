import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_arena_methodprov := typechecker.make_type_arena();
    mut t_int_methodprov := typechecker.make_type_int();
    mut t_idx_methodprov := typechecker.make_type_index("SafeMethodProvenanceNode", "ctx", ctx);
    mut t_ptr_idx_methodprov := typechecker.make_type_pointer(t_idx_methodprov, ctx);
    mut t_ptr_int_methodprov := typechecker.make_type_pointer(t_int_methodprov, ctx);

    mut vector_layout_methodprov: typechecker.StructLayout[ctx];
    unsafe {
        vector_layout_methodprov.brand = empty[Index[str, ctx]];
        vector_layout_methodprov.fields = std.HashMapNew(ctx);
    }
    vector_layout_methodprov.fields.Insert("data", t_ptr_idx_methodprov);

    mut map_layout_methodprov: typechecker.StructLayout[ctx];
    unsafe {
        map_layout_methodprov.brand = empty[Index[str, ctx]];
        map_layout_methodprov.fields = std.HashMapNew(ctx);
    }
    map_layout_methodprov.fields.Insert("keys", t_ptr_int_methodprov);
    map_layout_methodprov.fields.Insert("values", t_ptr_idx_methodprov);

    mut t_vector_methodprov := typechecker.make_type_struct("Vector_SafeMethodProvenanceNode", "", ctx);
    mut t_map_methodprov := typechecker.make_type_struct("HashMap_Int_SafeMethodProvenanceNode", "", ctx);

    mut env_methodprov := typechecker.env_new(ctx);
    mut scope_methodprov := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_methodprov, "Vector_SafeMethodProvenanceNode", vector_layout_methodprov, ctx);
    typechecker.env_register_struct(&env_methodprov, "HashMap_Int_SafeMethodProvenanceNode", map_layout_methodprov, ctx);

    typechecker.scope_insert(scope_methodprov, "ctx", t_arena_methodprov, ctx);
    env_methodprov.variable_types.Insert("ctx", t_arena_methodprov);

    typechecker.scope_insert(scope_methodprov, "values_methodprov", t_vector_methodprov, ctx);
    env_methodprov.variable_types.Insert("values_methodprov", t_vector_methodprov);

    typechecker.scope_insert(scope_methodprov, "i_methodprov", t_int_methodprov, ctx);
    env_methodprov.variable_types.Insert("i_methodprov", t_int_methodprov);

    typechecker.scope_insert(scope_methodprov, "safe_idx_methodprov", t_idx_methodprov, ctx);
    env_methodprov.variable_types.Insert("safe_idx_methodprov", t_idx_methodprov);

    mut safe_origins_methodprov := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_methodprov, "safe_methodprov_root", ctx);
    env_methodprov.variable_origins.Insert("safe_idx_methodprov", safe_origins_methodprov);

    mut safe_prov_methodprov := typechecker.expression_provenance_safe_arena(t_idx_methodprov, ctx);
    safe_prov_methodprov.legacy_origins = safe_origins_methodprov;
    typechecker.env_record_variable_provenance(&env_methodprov, "safe_idx_methodprov", safe_prov_methodprov, ctx);

    mut lex_vector_set_methodprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_vector_set_methodprov, "values_methodprov.Set(i_methodprov, safe_idx_methodprov);");
    mut parser_vector_set_methodprov: parser.Parser[ctx];
    parser.init_parser(&parser_vector_set_methodprov, &lex_vector_set_methodprov, ctx);
    mut stmt_vector_set_methodprov := parser.parse_statement(&parser_vector_set_methodprov, ctx);
    typechecker.check_statement(stmt_vector_set_methodprov, &env_methodprov, scope_methodprov, ctx);

    if len(env_methodprov.errors) != 0 {
        os.LogStr("Error: Vector.Set provenance fixture produced unexpected typechecker error");
        os.LogStr(env_methodprov.errors[0].message);
        os.Exit(1);
    }

    mut lex_vector_ref_methodprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_vector_ref_methodprov, "ctx.get_ref(values_methodprov[i_methodprov])");
    mut parser_vector_ref_methodprov: parser.Parser[ctx];
    parser.init_parser(&parser_vector_ref_methodprov, &lex_vector_ref_methodprov, ctx);
    mut expr_vector_ref_methodprov := parser.parse_expression(&parser_vector_ref_methodprov, 1, ctx);

    mut vector_ref_prov_methodprov := typechecker.check_expression_with_provenance(expr_vector_ref_methodprov, &env_methodprov, scope_methodprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(vector_ref_prov_methodprov) != 1 {
        os.LogStr("Error: Vector.Set did not record safe-arena container cell provenance");
        os.Exit(1);
    }
    if typechecker.set_contains(vector_ref_prov_methodprov.legacy_origins, "safe_methodprov_root", ctx) != 1 {
        os.LogStr("Error: Vector.Set did not preserve value legacy origin in container cell provenance");
        os.Exit(1);
    }

    typechecker.scope_insert(scope_methodprov, "map_methodprov", t_map_methodprov, ctx);
    env_methodprov.variable_types.Insert("map_methodprov", t_map_methodprov);

    typechecker.scope_insert(scope_methodprov, "key_methodprov", t_int_methodprov, ctx);
    env_methodprov.variable_types.Insert("key_methodprov", t_int_methodprov);

    mut lex_map_set_methodprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_map_set_methodprov, "map_methodprov.Set(key_methodprov, safe_idx_methodprov);");
    mut parser_map_set_methodprov: parser.Parser[ctx];
    parser.init_parser(&parser_map_set_methodprov, &lex_map_set_methodprov, ctx);
    mut stmt_map_set_methodprov := parser.parse_statement(&parser_map_set_methodprov, ctx);
    typechecker.check_statement(stmt_map_set_methodprov, &env_methodprov, scope_methodprov, ctx);

    if len(env_methodprov.errors) != 0 {
        os.LogStr("Error: HashMap.Set provenance fixture produced unexpected typechecker error");
        os.LogStr(env_methodprov.errors[0].message);
        os.Exit(1);
    }

    mut lex_map_ref_methodprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_map_ref_methodprov, "ctx.get_ref(map_methodprov[key_methodprov])");
    mut parser_map_ref_methodprov: parser.Parser[ctx];
    parser.init_parser(&parser_map_ref_methodprov, &lex_map_ref_methodprov, ctx);
    mut expr_map_ref_methodprov := parser.parse_expression(&parser_map_ref_methodprov, 1, ctx);

    mut map_ref_prov_methodprov := typechecker.check_expression_with_provenance(expr_map_ref_methodprov, &env_methodprov, scope_methodprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(map_ref_prov_methodprov) != 1 {
        os.LogStr("Error: HashMap.Set did not record safe-arena container cell provenance");
        os.Exit(1);
    }
    if typechecker.set_contains(map_ref_prov_methodprov.legacy_origins, "safe_methodprov_root", ctx) != 1 {
        os.LogStr("Error: HashMap.Set did not preserve value legacy origin in container cell provenance");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: container method write provenance metadata verified!");
}