import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_idx_method_nlaunder := typechecker.make_type_index("SafeCellContainerMethod", "ctx", ctx);
    mut t_int_method_nlaunder := typechecker.make_type_int();
    mut t_ptr_idx_method_nlaunder := typechecker.make_type_pointer(t_idx_method_nlaunder, ctx);
    mut t_ptr_int_method_nlaunder := typechecker.make_type_pointer(t_int_method_nlaunder, ctx);

    mut vector_layout_method_nlaunder: typechecker.StructLayout[ctx];
    unsafe {
        vector_layout_method_nlaunder.brand = empty[Index[str, ctx]];
        vector_layout_method_nlaunder.fields = std.HashMapNew(ctx);
    }
    vector_layout_method_nlaunder.fields.Insert("data", t_ptr_idx_method_nlaunder);
    mut t_vector_method_nlaunder := typechecker.make_type_struct("Vector_SafeCellContainerMethod", "", ctx);

    mut env_raw_method_nlaunder := typechecker.env_new(ctx);
    mut scope_raw_method_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_raw_method_nlaunder, "Vector_SafeCellContainerMethod", vector_layout_method_nlaunder, ctx);

    typechecker.scope_insert(scope_raw_method_nlaunder, "values_raw_method", t_vector_method_nlaunder, ctx);
    env_raw_method_nlaunder.variable_types.Insert("values_raw_method", t_vector_method_nlaunder);

    typechecker.scope_insert(scope_raw_method_nlaunder, "raw_idx_method", t_idx_method_nlaunder, ctx);
    env_raw_method_nlaunder.variable_types.Insert("raw_idx_method", t_idx_method_nlaunder);

    mut raw_origins_method_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(raw_origins_method_nlaunder, "raw_method_root", ctx);
    env_raw_method_nlaunder.variable_origins.Insert("raw_idx_method", raw_origins_method_nlaunder);

    mut raw_prov_method_nlaunder := typechecker.expression_provenance_raw_derived(t_idx_method_nlaunder, ctx);
    raw_prov_method_nlaunder.legacy_origins = raw_origins_method_nlaunder;
    typechecker.env_record_variable_provenance(&env_raw_method_nlaunder, "raw_idx_method", raw_prov_method_nlaunder, ctx);

    mut lex_raw_method_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_raw_method_nlaunder, "values_raw_method.Push(raw_idx_method);");
    mut parser_raw_method_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_raw_method_nlaunder, &lex_raw_method_nlaunder, ctx);
    mut stmt_raw_method_nlaunder := parser.parse_statement(&parser_raw_method_nlaunder, ctx);

    typechecker.check_statement(stmt_raw_method_nlaunder, &env_raw_method_nlaunder, scope_raw_method_nlaunder, ctx);

    if len(env_raw_method_nlaunder.errors) == 0 {
        os.LogStr("Error: non-laundering container method fixture expected raw-derived Vector.Push rejection");
        os.Exit(1);
    }
    if std.str_find(env_raw_method_nlaunder.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: non-laundering container method fixture emitted wrong Vector.Push diagnostic");
        os.LogStr(env_raw_method_nlaunder.errors[0].message);
        os.Exit(1);
    }

    mut errors_before_raw_set_method_nlaunder := len(env_raw_method_nlaunder.errors);
    mut lex_raw_set_method_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_raw_set_method_nlaunder, "values_raw_method.Set(0, raw_idx_method);");
    mut parser_raw_set_method_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_raw_set_method_nlaunder, &lex_raw_set_method_nlaunder, ctx);
    mut stmt_raw_set_method_nlaunder := parser.parse_statement(&parser_raw_set_method_nlaunder, ctx);

    typechecker.check_statement(stmt_raw_set_method_nlaunder, &env_raw_method_nlaunder, scope_raw_method_nlaunder, ctx);

    if len(env_raw_method_nlaunder.errors) == errors_before_raw_set_method_nlaunder {
        os.LogStr("Error: non-laundering container method fixture expected raw-derived Vector.Set rejection");
        os.Exit(1);
    }
    if std.str_find(env_raw_method_nlaunder.errors[errors_before_raw_set_method_nlaunder].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: non-laundering container method fixture emitted wrong Vector.Set diagnostic");
        os.LogStr(env_raw_method_nlaunder.errors[errors_before_raw_set_method_nlaunder].message);
        os.Exit(1);
    }

    mut t_str_method_nlaunder := typechecker.make_type_str();
    mut t_ref_method_nlaunder := typechecker.make_type_reference(t_str_method_nlaunder, "ctx", ctx);
    mut t_ptr_ref_method_nlaunder := typechecker.make_type_pointer(t_ref_method_nlaunder, ctx);

    mut map_layout_method_nlaunder: typechecker.StructLayout[ctx];
    unsafe {
        map_layout_method_nlaunder.brand = empty[Index[str, ctx]];
        map_layout_method_nlaunder.fields = std.HashMapNew(ctx);
    }
    map_layout_method_nlaunder.fields.Insert("keys", t_ptr_int_method_nlaunder);
    map_layout_method_nlaunder.fields.Insert("values", t_ptr_ref_method_nlaunder);
    mut t_map_method_nlaunder := typechecker.make_type_struct("HashMap_Int_SafeRefContainerMethod", "", ctx);

    mut env_sandbox_method_nlaunder := typechecker.env_new(ctx);
    mut scope_sandbox_method_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_sandbox_method_nlaunder, "Vector_SafeCellContainerMethod", vector_layout_method_nlaunder, ctx);
    typechecker.env_register_struct(&env_sandbox_method_nlaunder, "HashMap_Int_SafeRefContainerMethod", map_layout_method_nlaunder, ctx);

    typechecker.scope_insert(scope_sandbox_method_nlaunder, "map_sandbox_method", t_map_method_nlaunder, ctx);
    env_sandbox_method_nlaunder.variable_types.Insert("map_sandbox_method", t_map_method_nlaunder);

    typechecker.scope_insert(scope_sandbox_method_nlaunder, "key_sandbox_method", t_int_method_nlaunder, ctx);
    env_sandbox_method_nlaunder.variable_types.Insert("key_sandbox_method", t_int_method_nlaunder);

    typechecker.scope_insert(scope_sandbox_method_nlaunder, "sandbox_ref_method", t_ref_method_nlaunder, ctx);
    env_sandbox_method_nlaunder.variable_types.Insert("sandbox_ref_method", t_ref_method_nlaunder);

    mut sandbox_origins_method_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(sandbox_origins_method_nlaunder, "sandbox_method_root", ctx);
    env_sandbox_method_nlaunder.variable_origins.Insert("sandbox_ref_method", sandbox_origins_method_nlaunder);

    mut sandbox_prov_method_nlaunder := typechecker.expression_provenance_sandbox_derived(t_ref_method_nlaunder, ctx);
    sandbox_prov_method_nlaunder.legacy_origins = sandbox_origins_method_nlaunder;
    typechecker.env_record_variable_provenance(&env_sandbox_method_nlaunder, "sandbox_ref_method", sandbox_prov_method_nlaunder, ctx);

    mut lex_sandbox_method_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_sandbox_method_nlaunder, "map_sandbox_method.Insert(key_sandbox_method, sandbox_ref_method);");
    mut parser_sandbox_method_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_sandbox_method_nlaunder, &lex_sandbox_method_nlaunder, ctx);
    mut stmt_sandbox_method_nlaunder := parser.parse_statement(&parser_sandbox_method_nlaunder, ctx);

    typechecker.check_statement(stmt_sandbox_method_nlaunder, &env_sandbox_method_nlaunder, scope_sandbox_method_nlaunder, ctx);

    if len(env_sandbox_method_nlaunder.errors) == 0 {
        os.LogStr("Error: non-laundering container method fixture expected sandbox-derived HashMap.Insert rejection");
        os.Exit(1);
    }
    if std.str_find(env_sandbox_method_nlaunder.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: non-laundering container method fixture emitted wrong HashMap.Insert diagnostic");
        os.LogStr(env_sandbox_method_nlaunder.errors[0].message);
        os.Exit(1);
    }

    mut errors_before_sandbox_set_method_nlaunder := len(env_sandbox_method_nlaunder.errors);
    mut lex_sandbox_set_method_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_sandbox_set_method_nlaunder, "map_sandbox_method.Set(key_sandbox_method, sandbox_ref_method);");
    mut parser_sandbox_set_method_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_sandbox_set_method_nlaunder, &lex_sandbox_set_method_nlaunder, ctx);
    mut stmt_sandbox_set_method_nlaunder := parser.parse_statement(&parser_sandbox_set_method_nlaunder, ctx);

    typechecker.check_statement(stmt_sandbox_set_method_nlaunder, &env_sandbox_method_nlaunder, scope_sandbox_method_nlaunder, ctx);

    if len(env_sandbox_method_nlaunder.errors) == errors_before_sandbox_set_method_nlaunder {
        os.LogStr("Error: non-laundering container method fixture expected sandbox-derived HashMap.Set rejection");
        os.Exit(1);
    }
    if std.str_find(env_sandbox_method_nlaunder.errors[errors_before_sandbox_set_method_nlaunder].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: non-laundering container method fixture emitted wrong HashMap.Set diagnostic");
        os.LogStr(env_sandbox_method_nlaunder.errors[errors_before_sandbox_set_method_nlaunder].message);
        os.Exit(1);
    }

    mut env_safe_method_nlaunder := typechecker.env_new(ctx);
    mut scope_safe_method_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_safe_method_nlaunder, "Vector_SafeCellContainerMethod", vector_layout_method_nlaunder, ctx);
    typechecker.env_register_struct(&env_safe_method_nlaunder, "HashMap_Int_SafeRefContainerMethod", map_layout_method_nlaunder, ctx);

    typechecker.scope_insert(scope_safe_method_nlaunder, "values_safe_method", t_vector_method_nlaunder, ctx);
    env_safe_method_nlaunder.variable_types.Insert("values_safe_method", t_vector_method_nlaunder);

    typechecker.scope_insert(scope_safe_method_nlaunder, "safe_idx_method", t_idx_method_nlaunder, ctx);
    env_safe_method_nlaunder.variable_types.Insert("safe_idx_method", t_idx_method_nlaunder);

    mut safe_idx_origins_method_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(safe_idx_origins_method_nlaunder, "safe_idx_method_root", ctx);
    env_safe_method_nlaunder.variable_origins.Insert("safe_idx_method", safe_idx_origins_method_nlaunder);

    mut safe_idx_prov_method_nlaunder := typechecker.expression_provenance_safe_arena(t_idx_method_nlaunder, ctx);
    safe_idx_prov_method_nlaunder.legacy_origins = safe_idx_origins_method_nlaunder;
    typechecker.env_record_variable_provenance(&env_safe_method_nlaunder, "safe_idx_method", safe_idx_prov_method_nlaunder, ctx);

    typechecker.scope_insert(scope_safe_method_nlaunder, "map_safe_method", t_map_method_nlaunder, ctx);
    env_safe_method_nlaunder.variable_types.Insert("map_safe_method", t_map_method_nlaunder);

    typechecker.scope_insert(scope_safe_method_nlaunder, "key_safe_method", t_int_method_nlaunder, ctx);
    env_safe_method_nlaunder.variable_types.Insert("key_safe_method", t_int_method_nlaunder);

    typechecker.scope_insert(scope_safe_method_nlaunder, "safe_ref_method", t_ref_method_nlaunder, ctx);
    env_safe_method_nlaunder.variable_types.Insert("safe_ref_method", t_ref_method_nlaunder);

    mut safe_ref_origins_method_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(safe_ref_origins_method_nlaunder, "safe_ref_method_root", ctx);
    env_safe_method_nlaunder.variable_origins.Insert("safe_ref_method", safe_ref_origins_method_nlaunder);

    mut safe_ref_prov_method_nlaunder := typechecker.expression_provenance_safe_arena(t_ref_method_nlaunder, ctx);
    safe_ref_prov_method_nlaunder.legacy_origins = safe_ref_origins_method_nlaunder;
    typechecker.env_record_variable_provenance(&env_safe_method_nlaunder, "safe_ref_method", safe_ref_prov_method_nlaunder, ctx);

    mut lex_safe_push_method_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_safe_push_method_nlaunder, "values_safe_method.Push(safe_idx_method);");
    mut parser_safe_push_method_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_safe_push_method_nlaunder, &lex_safe_push_method_nlaunder, ctx);
    mut stmt_safe_push_method_nlaunder := parser.parse_statement(&parser_safe_push_method_nlaunder, ctx);
    typechecker.check_statement(stmt_safe_push_method_nlaunder, &env_safe_method_nlaunder, scope_safe_method_nlaunder, ctx);

    mut lex_safe_set_method_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_safe_set_method_nlaunder, "values_safe_method.Set(0, safe_idx_method);");
    mut parser_safe_set_method_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_safe_set_method_nlaunder, &lex_safe_set_method_nlaunder, ctx);
    mut stmt_safe_set_method_nlaunder := parser.parse_statement(&parser_safe_set_method_nlaunder, ctx);
    typechecker.check_statement(stmt_safe_set_method_nlaunder, &env_safe_method_nlaunder, scope_safe_method_nlaunder, ctx);

    mut lex_safe_map_method_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_safe_map_method_nlaunder, "map_safe_method.Set(key_safe_method, safe_ref_method);");
    mut parser_safe_map_method_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_safe_map_method_nlaunder, &lex_safe_map_method_nlaunder, ctx);
    mut stmt_safe_map_method_nlaunder := parser.parse_statement(&parser_safe_map_method_nlaunder, ctx);
    typechecker.check_statement(stmt_safe_map_method_nlaunder, &env_safe_method_nlaunder, scope_safe_method_nlaunder, ctx);

    if len(env_safe_method_nlaunder.errors) != 0 {
        os.LogStr("Error: non-laundering container method fixture rejected safe-arena method storage");
        os.LogStr(env_safe_method_nlaunder.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: non-laundering safe-branded container method Push/Set/Insert storage enforcement verified!");
}
