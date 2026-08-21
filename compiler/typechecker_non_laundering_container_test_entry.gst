import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_idx_container_nlaunder := typechecker.make_type_index("SafeCellContainer", "ctx", ctx);
    mut t_int_container_nlaunder := typechecker.make_type_int();
    mut t_ptr_idx_container_nlaunder := typechecker.make_type_pointer(t_idx_container_nlaunder, ctx);

    mut vector_idx_layout_container_nlaunder: typechecker.StructLayout[ctx];
    unsafe {
        vector_idx_layout_container_nlaunder.brand = empty[Index[str, ctx]];
        vector_idx_layout_container_nlaunder.fields = std.HashMapNew(ctx);
    }
    vector_idx_layout_container_nlaunder.fields.Insert("data", t_ptr_idx_container_nlaunder);

    mut t_vector_idx_container_nlaunder := typechecker.make_type_struct("MockVectorIdxContainerNlaunder", "", ctx);

    mut env_raw_container_nlaunder := typechecker.env_new(ctx);
    mut scope_raw_container_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_raw_container_nlaunder, "MockVectorIdxContainerNlaunder", vector_idx_layout_container_nlaunder, ctx);
    typechecker.env_record_struct_container_kind(&env_raw_container_nlaunder, "MockVectorIdxContainerNlaunder", typechecker.typechecker_container_kind_vector(), ctx);

    typechecker.scope_insert(scope_raw_container_nlaunder, "values_raw_container", t_vector_idx_container_nlaunder, ctx);
    env_raw_container_nlaunder.variable_types.Insert("values_raw_container", t_vector_idx_container_nlaunder);

    typechecker.scope_insert(scope_raw_container_nlaunder, "i_raw_container", t_int_container_nlaunder, ctx);
    env_raw_container_nlaunder.variable_types.Insert("i_raw_container", t_int_container_nlaunder);

    typechecker.scope_insert(scope_raw_container_nlaunder, "raw_idx_container", t_idx_container_nlaunder, ctx);
    env_raw_container_nlaunder.variable_types.Insert("raw_idx_container", t_idx_container_nlaunder);

    mut raw_origins_container_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(raw_origins_container_nlaunder, "raw_container_root", ctx);
    env_raw_container_nlaunder.variable_origins.Insert("raw_idx_container", raw_origins_container_nlaunder);

    mut raw_prov_container_nlaunder := typechecker.expression_provenance_raw_derived(t_idx_container_nlaunder, ctx);
    raw_prov_container_nlaunder.legacy_origins = raw_origins_container_nlaunder;
    typechecker.env_record_variable_provenance(&env_raw_container_nlaunder, "raw_idx_container", raw_prov_container_nlaunder, ctx);

    mut lex_raw_container_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_raw_container_nlaunder, "unsafe { values_raw_container[i_raw_container] = raw_idx_container; }");
    mut parser_raw_container_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_raw_container_nlaunder, &lex_raw_container_nlaunder, ctx);
    mut stmt_raw_container_nlaunder := parser.parse_statement(&parser_raw_container_nlaunder, ctx);

    typechecker.check_statement(stmt_raw_container_nlaunder, &env_raw_container_nlaunder, scope_raw_container_nlaunder, ctx);

    if len(env_raw_container_nlaunder.errors) == 0 {
        os.LogStr("Error: non-laundering container fixture expected raw-derived safe-branded element rejection");
        os.Exit(1);
    }
    if std.str_find(env_raw_container_nlaunder.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: non-laundering container fixture emitted wrong diagnostic");
        os.LogStr(env_raw_container_nlaunder.errors[0].message);
        os.Exit(1);
    }

    mut t_str_container_nlaunder := typechecker.make_type_str();
    mut t_ref_container_nlaunder := typechecker.make_type_reference(t_str_container_nlaunder, "ctx", ctx);
    mut t_ptr_ref_container_nlaunder := typechecker.make_type_pointer(t_ref_container_nlaunder, ctx);

    mut vector_ref_layout_container_nlaunder: typechecker.StructLayout[ctx];
    unsafe {
        vector_ref_layout_container_nlaunder.brand = empty[Index[str, ctx]];
        vector_ref_layout_container_nlaunder.fields = std.HashMapNew(ctx);
    }
    vector_ref_layout_container_nlaunder.fields.Insert("data", t_ptr_ref_container_nlaunder);

    mut t_vector_ref_container_nlaunder := typechecker.make_type_struct("MockVectorRefContainerNlaunder", "", ctx);

    mut env_sandbox_container_nlaunder := typechecker.env_new(ctx);
    mut scope_sandbox_container_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_sandbox_container_nlaunder, "MockVectorRefContainerNlaunder", vector_ref_layout_container_nlaunder, ctx);
    typechecker.env_record_struct_container_kind(&env_sandbox_container_nlaunder, "MockVectorRefContainerNlaunder", typechecker.typechecker_container_kind_vector(), ctx);

    typechecker.scope_insert(scope_sandbox_container_nlaunder, "values_sandbox_container", t_vector_ref_container_nlaunder, ctx);
    env_sandbox_container_nlaunder.variable_types.Insert("values_sandbox_container", t_vector_ref_container_nlaunder);

    typechecker.scope_insert(scope_sandbox_container_nlaunder, "i_sandbox_container", t_int_container_nlaunder, ctx);
    env_sandbox_container_nlaunder.variable_types.Insert("i_sandbox_container", t_int_container_nlaunder);

    typechecker.scope_insert(scope_sandbox_container_nlaunder, "sandbox_ref_container", t_ref_container_nlaunder, ctx);
    env_sandbox_container_nlaunder.variable_types.Insert("sandbox_ref_container", t_ref_container_nlaunder);

    mut sandbox_origins_container_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(sandbox_origins_container_nlaunder, "sandbox_container_root", ctx);
    env_sandbox_container_nlaunder.variable_origins.Insert("sandbox_ref_container", sandbox_origins_container_nlaunder);

    mut sandbox_prov_container_nlaunder := typechecker.expression_provenance_sandbox_derived(t_ref_container_nlaunder, ctx);
    sandbox_prov_container_nlaunder.legacy_origins = sandbox_origins_container_nlaunder;
    typechecker.env_record_variable_provenance(&env_sandbox_container_nlaunder, "sandbox_ref_container", sandbox_prov_container_nlaunder, ctx);

    mut lex_sandbox_container_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_sandbox_container_nlaunder, "unsafe { values_sandbox_container[i_sandbox_container] = sandbox_ref_container; }");
    mut parser_sandbox_container_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_sandbox_container_nlaunder, &lex_sandbox_container_nlaunder, ctx);
    mut stmt_sandbox_container_nlaunder := parser.parse_statement(&parser_sandbox_container_nlaunder, ctx);

    typechecker.check_statement(stmt_sandbox_container_nlaunder, &env_sandbox_container_nlaunder, scope_sandbox_container_nlaunder, ctx);

    if len(env_sandbox_container_nlaunder.errors) == 0 {
        os.LogStr("Error: non-laundering container fixture expected sandbox-derived safe-branded element rejection");
        os.Exit(1);
    }
    if std.str_find(env_sandbox_container_nlaunder.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: non-laundering sandbox container fixture emitted wrong diagnostic");
        os.LogStr(env_sandbox_container_nlaunder.errors[0].message);
        os.Exit(1);
    }

    mut env_safe_container_nlaunder := typechecker.env_new(ctx);
    mut scope_safe_container_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_safe_container_nlaunder, "MockVectorIdxContainerNlaunder", vector_idx_layout_container_nlaunder, ctx);
    typechecker.env_record_struct_container_kind(&env_safe_container_nlaunder, "MockVectorIdxContainerNlaunder", typechecker.typechecker_container_kind_vector(), ctx);

    typechecker.scope_insert(scope_safe_container_nlaunder, "values_safe_container", t_vector_idx_container_nlaunder, ctx);
    env_safe_container_nlaunder.variable_types.Insert("values_safe_container", t_vector_idx_container_nlaunder);

    typechecker.scope_insert(scope_safe_container_nlaunder, "i_safe_container", t_int_container_nlaunder, ctx);
    env_safe_container_nlaunder.variable_types.Insert("i_safe_container", t_int_container_nlaunder);

    typechecker.scope_insert(scope_safe_container_nlaunder, "safe_idx_container", t_idx_container_nlaunder, ctx);
    env_safe_container_nlaunder.variable_types.Insert("safe_idx_container", t_idx_container_nlaunder);

    mut safe_origins_container_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_container_nlaunder, "safe_container_root", ctx);
    env_safe_container_nlaunder.variable_origins.Insert("safe_idx_container", safe_origins_container_nlaunder);

    mut safe_prov_container_nlaunder := typechecker.expression_provenance_safe_arena(t_idx_container_nlaunder, ctx);
    safe_prov_container_nlaunder.legacy_origins = safe_origins_container_nlaunder;
    typechecker.env_record_variable_provenance(&env_safe_container_nlaunder, "safe_idx_container", safe_prov_container_nlaunder, ctx);

    mut lex_safe_container_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_safe_container_nlaunder, "unsafe { values_safe_container[i_safe_container] = safe_idx_container; }");
    mut parser_safe_container_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_safe_container_nlaunder, &lex_safe_container_nlaunder, ctx);
    mut stmt_safe_container_nlaunder := parser.parse_statement(&parser_safe_container_nlaunder, ctx);

    typechecker.check_statement(stmt_safe_container_nlaunder, &env_safe_container_nlaunder, scope_safe_container_nlaunder, ctx);

    if len(env_safe_container_nlaunder.errors) != 0 {
        os.LogStr("Error: non-laundering container fixture rejected safe-arena element assignment");
        os.LogStr(env_safe_container_nlaunder.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: non-laundering safe-branded container element enforcement verified!");
}
