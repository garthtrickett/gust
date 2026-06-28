import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_int_stdgetrefprov := typechecker.make_type_int();
    mut t_idx_stdgetrefprov := typechecker.make_type_index("StdVectorGetRefProvenanceNode", "ctx", ctx);
    mut t_ptr_idx_stdgetrefprov := typechecker.make_type_pointer(t_idx_stdgetrefprov, ctx);

    mut vector_layout_stdgetrefprov: typechecker.StructLayout[ctx];
    unsafe {
        vector_layout_stdgetrefprov.brand = empty[Index[str, ctx]];
        vector_layout_stdgetrefprov.fields = std.HashMapNew(ctx);
    }
    vector_layout_stdgetrefprov.fields.Insert("data", t_ptr_idx_stdgetrefprov);

    mut t_vector_stdgetrefprov := typechecker.make_type_struct("Vector_StdVectorGetRefProvenanceNode", "", ctx);

    mut env_stdgetrefprov := typechecker.env_new(ctx);
    mut scope_stdgetrefprov := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_stdgetrefprov, "Vector_StdVectorGetRefProvenanceNode", vector_layout_stdgetrefprov, ctx);

    typechecker.scope_insert(scope_stdgetrefprov, "values_stdgetrefprov", t_vector_stdgetrefprov, ctx);
    env_stdgetrefprov.variable_types.Insert("values_stdgetrefprov", t_vector_stdgetrefprov);

    typechecker.scope_insert(scope_stdgetrefprov, "i_stdgetrefprov", t_int_stdgetrefprov, ctx);
    env_stdgetrefprov.variable_types.Insert("i_stdgetrefprov", t_int_stdgetrefprov);

    typechecker.scope_insert(scope_stdgetrefprov, "safe_idx_stdgetrefprov", t_idx_stdgetrefprov, ctx);
    env_stdgetrefprov.variable_types.Insert("safe_idx_stdgetrefprov", t_idx_stdgetrefprov);

    mut safe_origins_stdgetrefprov := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_stdgetrefprov, "safe_std_vector_getref_root", ctx);
    env_stdgetrefprov.variable_origins.Insert("safe_idx_stdgetrefprov", safe_origins_stdgetrefprov);

    mut safe_prov_stdgetrefprov := typechecker.expression_provenance_safe_arena(t_idx_stdgetrefprov, ctx);
    safe_prov_stdgetrefprov.legacy_origins = safe_origins_stdgetrefprov;
    typechecker.env_record_variable_provenance(&env_stdgetrefprov, "safe_idx_stdgetrefprov", safe_prov_stdgetrefprov, ctx);

    mut lex_vector_set_stdgetrefprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_vector_set_stdgetrefprov, "values_stdgetrefprov.Set(i_stdgetrefprov, safe_idx_stdgetrefprov);");
    mut parser_vector_set_stdgetrefprov: parser.Parser[ctx];
    parser.init_parser(&parser_vector_set_stdgetrefprov, &lex_vector_set_stdgetrefprov, ctx);
    mut stmt_vector_set_stdgetrefprov := parser.parse_statement(&parser_vector_set_stdgetrefprov, ctx);
    typechecker.check_statement(stmt_vector_set_stdgetrefprov, &env_stdgetrefprov, scope_stdgetrefprov, ctx);

    if len(env_stdgetrefprov.errors) != 0 {
        os.LogStr("Error: Vector.Set setup for std.VectorGetRef provenance produced unexpected typechecker error");
        os.LogStr(env_stdgetrefprov.errors[0].message);
        os.Exit(1);
    }

    mut lex_std_vector_getref_stdgetrefprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_std_vector_getref_stdgetrefprov, "std.VectorGetRef(values_stdgetrefprov, i_stdgetrefprov)");
    mut parser_std_vector_getref_stdgetrefprov: parser.Parser[ctx];
    parser.init_parser(&parser_std_vector_getref_stdgetrefprov, &lex_std_vector_getref_stdgetrefprov, ctx);
    mut expr_std_vector_getref_stdgetrefprov := parser.parse_expression(&parser_std_vector_getref_stdgetrefprov, 1, ctx);

    mut std_vector_getref_prov_stdgetrefprov := typechecker.check_expression_with_provenance(expr_std_vector_getref_stdgetrefprov, &env_stdgetrefprov, scope_stdgetrefprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(std_vector_getref_prov_stdgetrefprov) != 1 {
        os.LogStr("Error: std.VectorGetRef did not preserve safe container-cell provenance");
        os.Exit(1);
    }
    if typechecker.set_contains(std_vector_getref_prov_stdgetrefprov.legacy_origins, "safe_std_vector_getref_root", ctx) != 1 {
        os.LogStr("Error: std.VectorGetRef did not preserve safe container-cell legacy origin");
        os.Exit(1);
    }

    typechecker.scope_insert(scope_stdgetrefprov, "values_raw_stdgetrefprov", t_vector_stdgetrefprov, ctx);
    env_stdgetrefprov.variable_types.Insert("values_raw_stdgetrefprov", t_vector_stdgetrefprov);

    typechecker.scope_insert(scope_stdgetrefprov, "i_raw_stdgetrefprov", t_int_stdgetrefprov, ctx);
    env_stdgetrefprov.variable_types.Insert("i_raw_stdgetrefprov", t_int_stdgetrefprov);

    mut raw_origins_stdgetrefprov := typechecker.set_init(ctx);
    typechecker.set_add(raw_origins_stdgetrefprov, "raw_std_vector_getref_root", ctx);
    mut raw_cell_prov_stdgetrefprov := typechecker.expression_provenance_raw_derived(t_idx_stdgetrefprov, ctx);
    raw_cell_prov_stdgetrefprov.legacy_origins = raw_origins_stdgetrefprov;
    typechecker.env_record_container_provenance(&env_stdgetrefprov, "values_raw_stdgetrefprov[i_raw_stdgetrefprov]", raw_cell_prov_stdgetrefprov, ctx);

    mut lex_raw_std_vector_getref_stdgetrefprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_raw_std_vector_getref_stdgetrefprov, "std.VectorGetRef(values_raw_stdgetrefprov, i_raw_stdgetrefprov)");
    mut parser_raw_std_vector_getref_stdgetrefprov: parser.Parser[ctx];
    parser.init_parser(&parser_raw_std_vector_getref_stdgetrefprov, &lex_raw_std_vector_getref_stdgetrefprov, ctx);
    mut expr_raw_std_vector_getref_stdgetrefprov := parser.parse_expression(&parser_raw_std_vector_getref_stdgetrefprov, 1, ctx);

    mut raw_std_vector_getref_prov_stdgetrefprov := typechecker.check_expression_with_provenance(expr_raw_std_vector_getref_stdgetrefprov, &env_stdgetrefprov, scope_stdgetrefprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(raw_std_vector_getref_prov_stdgetrefprov) == 1 {
        os.LogStr("Error: std.VectorGetRef incorrectly allowed safe branding from raw-derived container-cell provenance");
        os.Exit(1);
    }
    if typechecker.expression_provenance_is_raw_or_sandbox_derived(raw_std_vector_getref_prov_stdgetrefprov) != 1 {
        os.LogStr("Error: std.VectorGetRef did not preserve raw-derived container-cell provenance");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: std.VectorGetRef provenance metadata verified!");
}