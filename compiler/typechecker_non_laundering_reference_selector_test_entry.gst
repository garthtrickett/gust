import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_arena_refsel_nlaunder := typechecker.make_type_arena();
    mut t_int_refsel_nlaunder := typechecker.make_type_int();
    mut t_idx_refsel_nlaunder := typechecker.make_type_index("ReferenceSelectorNlaunderNode", "ctx", ctx);
    mut t_holder_struct_refsel_nlaunder := typechecker.make_type_struct("ReferenceSelectorNlaunderHolder", "ctx", ctx);
    mut t_holder_idx_refsel_nlaunder := typechecker.make_type_index("ReferenceSelectorNlaunderHolder", "ctx", ctx);
    mut t_ptr_int_refsel_nlaunder := typechecker.make_type_pointer(t_int_refsel_nlaunder, ctx);
    mut t_ptr_holder_refsel_nlaunder := typechecker.make_type_pointer(t_holder_struct_refsel_nlaunder, ctx);

    mut holder_layout_refsel_nlaunder: typechecker.StructLayout[ctx];
    unsafe {
        holder_layout_refsel_nlaunder.brand = empty[Index[str, ctx]];
        holder_layout_refsel_nlaunder.fields = std.HashMapNew(ctx);
    }
    holder_layout_refsel_nlaunder.fields.Insert("idx", t_idx_refsel_nlaunder);

    mut vector_layout_refsel_nlaunder: typechecker.StructLayout[ctx];
    unsafe {
        vector_layout_refsel_nlaunder.brand = empty[Index[str, ctx]];
        vector_layout_refsel_nlaunder.fields = std.HashMapNew(ctx);
    }
    vector_layout_refsel_nlaunder.fields.Insert("data", t_ptr_holder_refsel_nlaunder);

    mut map_layout_refsel_nlaunder: typechecker.StructLayout[ctx];
    unsafe {
        map_layout_refsel_nlaunder.brand = empty[Index[str, ctx]];
        map_layout_refsel_nlaunder.fields = std.HashMapNew(ctx);
    }
    map_layout_refsel_nlaunder.fields.Insert("keys", t_ptr_int_refsel_nlaunder);
    map_layout_refsel_nlaunder.fields.Insert("values", t_ptr_holder_refsel_nlaunder);

    mut t_vector_refsel_nlaunder := typechecker.make_type_struct("Vector_ReferenceSelectorNlaunderHolder", "", ctx);
    mut t_map_refsel_nlaunder := typechecker.make_type_struct("HashMap_Int_ReferenceSelectorNlaunderHolder", "", ctx);

    mut env_refsel_nlaunder := typechecker.env_new(ctx);
    mut scope_refsel_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_refsel_nlaunder, "ReferenceSelectorNlaunderHolder", holder_layout_refsel_nlaunder, ctx);
    typechecker.env_register_struct(&env_refsel_nlaunder, "Vector_ReferenceSelectorNlaunderHolder", vector_layout_refsel_nlaunder, ctx);
    typechecker.env_register_struct(&env_refsel_nlaunder, "HashMap_Int_ReferenceSelectorNlaunderHolder", map_layout_refsel_nlaunder, ctx);

    typechecker.scope_insert(scope_refsel_nlaunder, "ctx", t_arena_refsel_nlaunder, ctx);
    env_refsel_nlaunder.variable_types.Insert("ctx", t_arena_refsel_nlaunder);

    typechecker.scope_insert(scope_refsel_nlaunder, "holder_idx_refsel_nlaunder", t_holder_idx_refsel_nlaunder, ctx);
    env_refsel_nlaunder.variable_types.Insert("holder_idx_refsel_nlaunder", t_holder_idx_refsel_nlaunder);

    typechecker.scope_insert(scope_refsel_nlaunder, "values_refsel_nlaunder", t_vector_refsel_nlaunder, ctx);
    env_refsel_nlaunder.variable_types.Insert("values_refsel_nlaunder", t_vector_refsel_nlaunder);

    typechecker.scope_insert(scope_refsel_nlaunder, "map_refsel_nlaunder", t_map_refsel_nlaunder, ctx);
    env_refsel_nlaunder.variable_types.Insert("map_refsel_nlaunder", t_map_refsel_nlaunder);

    typechecker.scope_insert(scope_refsel_nlaunder, "i_refsel_nlaunder", t_int_refsel_nlaunder, ctx);
    env_refsel_nlaunder.variable_types.Insert("i_refsel_nlaunder", t_int_refsel_nlaunder);

    typechecker.scope_insert(scope_refsel_nlaunder, "key_refsel_nlaunder", t_int_refsel_nlaunder, ctx);
    env_refsel_nlaunder.variable_types.Insert("key_refsel_nlaunder", t_int_refsel_nlaunder);

    typechecker.scope_insert(scope_refsel_nlaunder, "raw_idx_refsel_nlaunder", t_idx_refsel_nlaunder, ctx);
    env_refsel_nlaunder.variable_types.Insert("raw_idx_refsel_nlaunder", t_idx_refsel_nlaunder);

    mut raw_origins_refsel_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(raw_origins_refsel_nlaunder, "raw_reference_selector_nlaunder_root", ctx);
    env_refsel_nlaunder.variable_origins.Insert("raw_idx_refsel_nlaunder", raw_origins_refsel_nlaunder);

    mut raw_prov_refsel_nlaunder := typechecker.expression_provenance_raw_derived(t_idx_refsel_nlaunder, ctx);
    raw_prov_refsel_nlaunder.legacy_origins = raw_origins_refsel_nlaunder;
    typechecker.env_record_variable_provenance(&env_refsel_nlaunder, "raw_idx_refsel_nlaunder", raw_prov_refsel_nlaunder, ctx);

    typechecker.scope_insert(scope_refsel_nlaunder, "sandbox_idx_refsel_nlaunder", t_idx_refsel_nlaunder, ctx);
    env_refsel_nlaunder.variable_types.Insert("sandbox_idx_refsel_nlaunder", t_idx_refsel_nlaunder);

    mut sandbox_origins_refsel_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(sandbox_origins_refsel_nlaunder, "sandbox_reference_selector_nlaunder_root", ctx);
    env_refsel_nlaunder.variable_origins.Insert("sandbox_idx_refsel_nlaunder", sandbox_origins_refsel_nlaunder);

    mut sandbox_prov_refsel_nlaunder := typechecker.expression_provenance_sandbox_derived(t_idx_refsel_nlaunder, ctx);
    sandbox_prov_refsel_nlaunder.legacy_origins = sandbox_origins_refsel_nlaunder;
    typechecker.env_record_variable_provenance(&env_refsel_nlaunder, "sandbox_idx_refsel_nlaunder", sandbox_prov_refsel_nlaunder, ctx);

    mut errors_before_arena_refsel_nlaunder := len(env_refsel_nlaunder.errors);
    mut lex_arena_refsel_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_arena_refsel_nlaunder, "ctx.get_ref(holder_idx_refsel_nlaunder).idx = raw_idx_refsel_nlaunder;");
    mut parser_arena_refsel_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_arena_refsel_nlaunder, &lex_arena_refsel_nlaunder, ctx);
    mut stmt_arena_refsel_nlaunder := parser.parse_statement(&parser_arena_refsel_nlaunder, ctx);
    typechecker.check_statement(stmt_arena_refsel_nlaunder, &env_refsel_nlaunder, scope_refsel_nlaunder, ctx);
    if len(env_refsel_nlaunder.errors) == errors_before_arena_refsel_nlaunder {
        os.LogStr("Error: expected ctx.get_ref(...).field raw-derived non-laundering rejection");
        os.Exit(1);
    }
    if std.str_find(env_refsel_nlaunder.errors[errors_before_arena_refsel_nlaunder].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: ctx.get_ref(...).field emitted wrong diagnostic");
        os.LogStr(env_refsel_nlaunder.errors[errors_before_arena_refsel_nlaunder].message);
        os.Exit(1);
    }

    mut errors_before_vector_refsel_nlaunder := len(env_refsel_nlaunder.errors);
    mut lex_vector_refsel_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_vector_refsel_nlaunder, "values_refsel_nlaunder.GetRef(i_refsel_nlaunder).idx = raw_idx_refsel_nlaunder;");
    mut parser_vector_refsel_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_vector_refsel_nlaunder, &lex_vector_refsel_nlaunder, ctx);
    mut stmt_vector_refsel_nlaunder := parser.parse_statement(&parser_vector_refsel_nlaunder, ctx);
    typechecker.check_statement(stmt_vector_refsel_nlaunder, &env_refsel_nlaunder, scope_refsel_nlaunder, ctx);
    if len(env_refsel_nlaunder.errors) == errors_before_vector_refsel_nlaunder {
        os.LogStr("Error: expected Vector.GetRef(...).field raw-derived non-laundering rejection");
        os.Exit(1);
    }
    if std.str_find(env_refsel_nlaunder.errors[errors_before_vector_refsel_nlaunder].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: Vector.GetRef(...).field emitted wrong diagnostic");
        os.LogStr(env_refsel_nlaunder.errors[errors_before_vector_refsel_nlaunder].message);
        os.Exit(1);
    }

    mut errors_before_map_refsel_nlaunder := len(env_refsel_nlaunder.errors);
    mut lex_map_refsel_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_map_refsel_nlaunder, "map_refsel_nlaunder.GetRef(key_refsel_nlaunder).idx = raw_idx_refsel_nlaunder;");
    mut parser_map_refsel_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_map_refsel_nlaunder, &lex_map_refsel_nlaunder, ctx);
    mut stmt_map_refsel_nlaunder := parser.parse_statement(&parser_map_refsel_nlaunder, ctx);
    typechecker.check_statement(stmt_map_refsel_nlaunder, &env_refsel_nlaunder, scope_refsel_nlaunder, ctx);
    if len(env_refsel_nlaunder.errors) == errors_before_map_refsel_nlaunder {
        os.LogStr("Error: expected HashMap.GetRef(...).field raw-derived non-laundering rejection");
        os.Exit(1);
    }
    if std.str_find(env_refsel_nlaunder.errors[errors_before_map_refsel_nlaunder].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: HashMap.GetRef(...).field emitted wrong diagnostic");
        os.LogStr(env_refsel_nlaunder.errors[errors_before_map_refsel_nlaunder].message);
        os.Exit(1);
    }

    mut errors_before_std_vector_refsel_nlaunder := len(env_refsel_nlaunder.errors);
    mut lex_std_vector_refsel_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_std_vector_refsel_nlaunder, "std.VectorGetRef(values_refsel_nlaunder, i_refsel_nlaunder).idx = raw_idx_refsel_nlaunder;");
    mut parser_std_vector_refsel_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_std_vector_refsel_nlaunder, &lex_std_vector_refsel_nlaunder, ctx);
    mut stmt_std_vector_refsel_nlaunder := parser.parse_statement(&parser_std_vector_refsel_nlaunder, ctx);
    typechecker.check_statement(stmt_std_vector_refsel_nlaunder, &env_refsel_nlaunder, scope_refsel_nlaunder, ctx);
    if len(env_refsel_nlaunder.errors) == errors_before_std_vector_refsel_nlaunder {
        os.LogStr("Error: expected std.VectorGetRef(...).field raw-derived non-laundering rejection");
        os.Exit(1);
    }
    if std.str_find(env_refsel_nlaunder.errors[errors_before_std_vector_refsel_nlaunder].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: std.VectorGetRef(...).field emitted wrong diagnostic");
        os.LogStr(env_refsel_nlaunder.errors[errors_before_std_vector_refsel_nlaunder].message);
        os.Exit(1);
    }

    mut errors_before_std_map_refsel_nlaunder := len(env_refsel_nlaunder.errors);
    mut lex_std_map_refsel_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_std_map_refsel_nlaunder, "std.HashMapGetRef(map_refsel_nlaunder, key_refsel_nlaunder).idx = raw_idx_refsel_nlaunder;");
    mut parser_std_map_refsel_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_std_map_refsel_nlaunder, &lex_std_map_refsel_nlaunder, ctx);
    mut stmt_std_map_refsel_nlaunder := parser.parse_statement(&parser_std_map_refsel_nlaunder, ctx);
    typechecker.check_statement(stmt_std_map_refsel_nlaunder, &env_refsel_nlaunder, scope_refsel_nlaunder, ctx);
    if len(env_refsel_nlaunder.errors) == errors_before_std_map_refsel_nlaunder {
        os.LogStr("Error: expected std.HashMapGetRef(...).field raw-derived non-laundering rejection");
        os.Exit(1);
    }
    if std.str_find(env_refsel_nlaunder.errors[errors_before_std_map_refsel_nlaunder].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: std.HashMapGetRef(...).field emitted wrong diagnostic");
        os.LogStr(env_refsel_nlaunder.errors[errors_before_std_map_refsel_nlaunder].message);
        os.Exit(1);
    }

    mut errors_before_sandbox_arena_refsel_nlaunder := len(env_refsel_nlaunder.errors);
    mut lex_sandbox_arena_refsel_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_sandbox_arena_refsel_nlaunder, "ctx.get_ref(holder_idx_refsel_nlaunder).idx = sandbox_idx_refsel_nlaunder;");
    mut parser_sandbox_arena_refsel_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_sandbox_arena_refsel_nlaunder, &lex_sandbox_arena_refsel_nlaunder, ctx);
    mut stmt_sandbox_arena_refsel_nlaunder := parser.parse_statement(&parser_sandbox_arena_refsel_nlaunder, ctx);
    typechecker.check_statement(stmt_sandbox_arena_refsel_nlaunder, &env_refsel_nlaunder, scope_refsel_nlaunder, ctx);
    if len(env_refsel_nlaunder.errors) == errors_before_sandbox_arena_refsel_nlaunder {
        os.LogStr("Error: expected ctx.get_ref(...).field sandbox-derived non-laundering rejection");
        os.Exit(1);
    }
    if std.str_find(env_refsel_nlaunder.errors[errors_before_sandbox_arena_refsel_nlaunder].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: sandbox ctx.get_ref(...).field emitted wrong diagnostic");
        os.LogStr(env_refsel_nlaunder.errors[errors_before_sandbox_arena_refsel_nlaunder].message);
        os.Exit(1);
    }

    mut errors_before_sandbox_vector_refsel_nlaunder := len(env_refsel_nlaunder.errors);
    mut lex_sandbox_vector_refsel_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_sandbox_vector_refsel_nlaunder, "values_refsel_nlaunder.GetRef(i_refsel_nlaunder).idx = sandbox_idx_refsel_nlaunder;");
    mut parser_sandbox_vector_refsel_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_sandbox_vector_refsel_nlaunder, &lex_sandbox_vector_refsel_nlaunder, ctx);
    mut stmt_sandbox_vector_refsel_nlaunder := parser.parse_statement(&parser_sandbox_vector_refsel_nlaunder, ctx);
    typechecker.check_statement(stmt_sandbox_vector_refsel_nlaunder, &env_refsel_nlaunder, scope_refsel_nlaunder, ctx);
    if len(env_refsel_nlaunder.errors) == errors_before_sandbox_vector_refsel_nlaunder {
        os.LogStr("Error: expected Vector.GetRef(...).field sandbox-derived non-laundering rejection");
        os.Exit(1);
    }
    if std.str_find(env_refsel_nlaunder.errors[errors_before_sandbox_vector_refsel_nlaunder].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: sandbox Vector.GetRef(...).field emitted wrong diagnostic");
        os.LogStr(env_refsel_nlaunder.errors[errors_before_sandbox_vector_refsel_nlaunder].message);
        os.Exit(1);
    }

    mut errors_before_sandbox_map_refsel_nlaunder := len(env_refsel_nlaunder.errors);
    mut lex_sandbox_map_refsel_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_sandbox_map_refsel_nlaunder, "map_refsel_nlaunder.GetRef(key_refsel_nlaunder).idx = sandbox_idx_refsel_nlaunder;");
    mut parser_sandbox_map_refsel_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_sandbox_map_refsel_nlaunder, &lex_sandbox_map_refsel_nlaunder, ctx);
    mut stmt_sandbox_map_refsel_nlaunder := parser.parse_statement(&parser_sandbox_map_refsel_nlaunder, ctx);
    typechecker.check_statement(stmt_sandbox_map_refsel_nlaunder, &env_refsel_nlaunder, scope_refsel_nlaunder, ctx);
    if len(env_refsel_nlaunder.errors) == errors_before_sandbox_map_refsel_nlaunder {
        os.LogStr("Error: expected HashMap.GetRef(...).field sandbox-derived non-laundering rejection");
        os.Exit(1);
    }
    if std.str_find(env_refsel_nlaunder.errors[errors_before_sandbox_map_refsel_nlaunder].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: sandbox HashMap.GetRef(...).field emitted wrong diagnostic");
        os.LogStr(env_refsel_nlaunder.errors[errors_before_sandbox_map_refsel_nlaunder].message);
        os.Exit(1);
    }

    mut errors_before_sandbox_std_vector_refsel_nlaunder := len(env_refsel_nlaunder.errors);
    mut lex_sandbox_std_vector_refsel_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_sandbox_std_vector_refsel_nlaunder, "std.VectorGetRef(values_refsel_nlaunder, i_refsel_nlaunder).idx = sandbox_idx_refsel_nlaunder;");
    mut parser_sandbox_std_vector_refsel_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_sandbox_std_vector_refsel_nlaunder, &lex_sandbox_std_vector_refsel_nlaunder, ctx);
    mut stmt_sandbox_std_vector_refsel_nlaunder := parser.parse_statement(&parser_sandbox_std_vector_refsel_nlaunder, ctx);
    typechecker.check_statement(stmt_sandbox_std_vector_refsel_nlaunder, &env_refsel_nlaunder, scope_refsel_nlaunder, ctx);
    if len(env_refsel_nlaunder.errors) == errors_before_sandbox_std_vector_refsel_nlaunder {
        os.LogStr("Error: expected std.VectorGetRef(...).field sandbox-derived non-laundering rejection");
        os.Exit(1);
    }
    if std.str_find(env_refsel_nlaunder.errors[errors_before_sandbox_std_vector_refsel_nlaunder].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: sandbox std.VectorGetRef(...).field emitted wrong diagnostic");
        os.LogStr(env_refsel_nlaunder.errors[errors_before_sandbox_std_vector_refsel_nlaunder].message);
        os.Exit(1);
    }

    mut errors_before_sandbox_std_map_refsel_nlaunder := len(env_refsel_nlaunder.errors);
    mut lex_sandbox_std_map_refsel_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_sandbox_std_map_refsel_nlaunder, "std.HashMapGetRef(map_refsel_nlaunder, key_refsel_nlaunder).idx = sandbox_idx_refsel_nlaunder;");
    mut parser_sandbox_std_map_refsel_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_sandbox_std_map_refsel_nlaunder, &lex_sandbox_std_map_refsel_nlaunder, ctx);
    mut stmt_sandbox_std_map_refsel_nlaunder := parser.parse_statement(&parser_sandbox_std_map_refsel_nlaunder, ctx);
    typechecker.check_statement(stmt_sandbox_std_map_refsel_nlaunder, &env_refsel_nlaunder, scope_refsel_nlaunder, ctx);
    if len(env_refsel_nlaunder.errors) == errors_before_sandbox_std_map_refsel_nlaunder {
        os.LogStr("Error: expected std.HashMapGetRef(...).field sandbox-derived non-laundering rejection");
        os.Exit(1);
    }
    if std.str_find(env_refsel_nlaunder.errors[errors_before_sandbox_std_map_refsel_nlaunder].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: sandbox std.HashMapGetRef(...).field emitted wrong diagnostic");
        os.LogStr(env_refsel_nlaunder.errors[errors_before_sandbox_std_map_refsel_nlaunder].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: reference selector raw/sandbox non-laundering enforcement verified!");
}
