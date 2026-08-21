import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_arena_cont_ctorprov := typechecker.make_type_arena();
    mut t_int_cont_ctorprov := typechecker.make_type_int();
    mut t_idx_cont_ctorprov := typechecker.make_type_index("SafeContainerConstructorNode", "ctx", ctx);
    mut t_ptr_idx_cont_ctorprov := typechecker.make_type_pointer(t_idx_cont_ctorprov, ctx);

    mut vector_layout_cont_ctorprov: typechecker.StructLayout[ctx];
    unsafe {
        vector_layout_cont_ctorprov.brand = empty[Index[str, ctx]];
        vector_layout_cont_ctorprov.fields = std.HashMapNew(ctx);
    }
    vector_layout_cont_ctorprov.fields.Insert("data", t_ptr_idx_cont_ctorprov);

    mut t_vector_cont_ctorprov := typechecker.make_type_struct("MockVectorSafeContainerCtorProv", "", ctx);

    mut env_cont_ctorprov := typechecker.env_new(ctx);
    mut scope_cont_ctorprov := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_cont_ctorprov, "MockVectorSafeContainerCtorProv", vector_layout_cont_ctorprov, ctx);
    typechecker.env_record_struct_container_kind(&env_cont_ctorprov, "MockVectorSafeContainerCtorProv", typechecker.typechecker_container_kind_vector(), ctx);

    typechecker.scope_insert(scope_cont_ctorprov, "ctx", t_arena_cont_ctorprov, ctx);
    env_cont_ctorprov.variable_types.Insert("ctx", t_arena_cont_ctorprov);

    typechecker.scope_insert(scope_cont_ctorprov, "values_safe_cont_ctorprov", t_vector_cont_ctorprov, ctx);
    env_cont_ctorprov.variable_types.Insert("values_safe_cont_ctorprov", t_vector_cont_ctorprov);

    typechecker.scope_insert(scope_cont_ctorprov, "i_safe_cont_ctorprov", t_int_cont_ctorprov, ctx);
    env_cont_ctorprov.variable_types.Insert("i_safe_cont_ctorprov", t_int_cont_ctorprov);

    mut lex_assign_safe_cont_ctorprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_assign_safe_cont_ctorprov, "unsafe { values_safe_cont_ctorprov[i_safe_cont_ctorprov] = os.ArenaAlloc(ctx); }");
    mut parser_assign_safe_cont_ctorprov: parser.Parser[ctx];
    parser.init_parser(&parser_assign_safe_cont_ctorprov, &lex_assign_safe_cont_ctorprov, ctx);
    mut stmt_assign_safe_cont_ctorprov := parser.parse_statement(&parser_assign_safe_cont_ctorprov, ctx);

    typechecker.check_statement(stmt_assign_safe_cont_ctorprov, &env_cont_ctorprov, scope_cont_ctorprov, ctx);

    if len(env_cont_ctorprov.errors) != 0 {
        os.LogStr("Error: container safe constructor assignment produced unexpected typechecker error");
        os.LogStr(env_cont_ctorprov.errors[0].message);
        os.Exit(1);
    }

    mut lex_safe_ref_cont_ctorprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_safe_ref_cont_ctorprov, "ctx.get_ref(values_safe_cont_ctorprov[i_safe_cont_ctorprov])");
    mut parser_safe_ref_cont_ctorprov: parser.Parser[ctx];
    parser.init_parser(&parser_safe_ref_cont_ctorprov, &lex_safe_ref_cont_ctorprov, ctx);
    mut expr_safe_ref_cont_ctorprov := parser.parse_expression(&parser_safe_ref_cont_ctorprov, 1, ctx);

    mut safe_ref_prov_cont_ctorprov := typechecker.check_expression_with_provenance(expr_safe_ref_cont_ctorprov, &env_cont_ctorprov, scope_cont_ctorprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(safe_ref_prov_cont_ctorprov) != 1 {
        os.LogStr("Error: ctx.get_ref(container cell with safe constructor provenance) did not preserve safe-arena provenance");
        os.Exit(1);
    }

    typechecker.scope_insert(scope_cont_ctorprov, "values_raw_cont_ctorprov", t_vector_cont_ctorprov, ctx);
    env_cont_ctorprov.variable_types.Insert("values_raw_cont_ctorprov", t_vector_cont_ctorprov);

    typechecker.scope_insert(scope_cont_ctorprov, "i_raw_cont_ctorprov", t_int_cont_ctorprov, ctx);
    env_cont_ctorprov.variable_types.Insert("i_raw_cont_ctorprov", t_int_cont_ctorprov);

    mut raw_origins_cont_ctorprov := typechecker.set_init(ctx);
    typechecker.set_add(raw_origins_cont_ctorprov, "raw_container_ctor_root", ctx);

    mut raw_cell_prov_cont_ctorprov := typechecker.expression_provenance_raw_derived(t_idx_cont_ctorprov, ctx);
    raw_cell_prov_cont_ctorprov.legacy_origins = raw_origins_cont_ctorprov;
    typechecker.env_record_container_provenance(&env_cont_ctorprov, "values_raw_cont_ctorprov[i_raw_cont_ctorprov]", raw_cell_prov_cont_ctorprov, ctx);

    mut lex_raw_ref_cont_ctorprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_raw_ref_cont_ctorprov, "ctx.get_ref(values_raw_cont_ctorprov[i_raw_cont_ctorprov])");
    mut parser_raw_ref_cont_ctorprov: parser.Parser[ctx];
    parser.init_parser(&parser_raw_ref_cont_ctorprov, &lex_raw_ref_cont_ctorprov, ctx);
    mut expr_raw_ref_cont_ctorprov := parser.parse_expression(&parser_raw_ref_cont_ctorprov, 1, ctx);

    mut raw_ref_prov_cont_ctorprov := typechecker.check_expression_with_provenance(expr_raw_ref_cont_ctorprov, &env_cont_ctorprov, scope_cont_ctorprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(raw_ref_prov_cont_ctorprov) == 1 {
        os.LogStr("Error: ctx.get_ref(container cell with raw-derived provenance) incorrectly allowed safe branding");
        os.Exit(1);
    }
    if typechecker.expression_provenance_is_raw_or_sandbox_derived(raw_ref_prov_cont_ctorprov) != 1 {
        os.LogStr("Error: ctx.get_ref(container cell with raw-derived provenance) did not preserve unsafe-derived metadata");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: container safe constructor provenance metadata verified!");
}
