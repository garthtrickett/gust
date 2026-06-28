import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_idx_field_nlaunder := typechecker.make_type_index("SafeCellField", "ctx", ctx);

    mut holder_idx_layout_field_nlaunder: typechecker.StructLayout[ctx];
    unsafe {
        holder_idx_layout_field_nlaunder.brand = empty[Index[str, ctx]];
        holder_idx_layout_field_nlaunder.fields = std.HashMapNew(ctx);
    }
    holder_idx_layout_field_nlaunder.fields.Insert("idx", t_idx_field_nlaunder);

    mut t_holder_idx_field_nlaunder := typechecker.make_type_struct("HolderIdxFieldNlaunder", "", ctx);

    mut env_raw_field_nlaunder := typechecker.env_new(ctx);
    mut scope_raw_field_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_raw_field_nlaunder, "HolderIdxFieldNlaunder", holder_idx_layout_field_nlaunder, ctx);

    typechecker.scope_insert(scope_raw_field_nlaunder, "holder_idx_field", t_holder_idx_field_nlaunder, ctx);
    env_raw_field_nlaunder.variable_types.Insert("holder_idx_field", t_holder_idx_field_nlaunder);

    typechecker.scope_insert(scope_raw_field_nlaunder, "raw_idx_field", t_idx_field_nlaunder, ctx);
    env_raw_field_nlaunder.variable_types.Insert("raw_idx_field", t_idx_field_nlaunder);

    mut raw_origins_field_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(raw_origins_field_nlaunder, "raw_field_root", ctx);
    env_raw_field_nlaunder.variable_origins.Insert("raw_idx_field", raw_origins_field_nlaunder);

    mut raw_prov_field_nlaunder := typechecker.expression_provenance_raw_derived(t_idx_field_nlaunder, ctx);
    raw_prov_field_nlaunder.legacy_origins = raw_origins_field_nlaunder;
    typechecker.env_record_variable_provenance(&env_raw_field_nlaunder, "raw_idx_field", raw_prov_field_nlaunder, ctx);

    mut lex_raw_field_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_raw_field_nlaunder, "holder_idx_field.idx = raw_idx_field;");
    mut parser_raw_field_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_raw_field_nlaunder, &lex_raw_field_nlaunder, ctx);
    mut stmt_raw_field_nlaunder := parser.parse_statement(&parser_raw_field_nlaunder, ctx);

    typechecker.check_statement(stmt_raw_field_nlaunder, &env_raw_field_nlaunder, scope_raw_field_nlaunder, ctx);

    if len(env_raw_field_nlaunder.errors) == 0 {
        os.LogStr("Error: non-laundering field fixture expected raw-derived safe-branded field rejection");
        os.Exit(1);
    }
    if std.str_find(env_raw_field_nlaunder.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: non-laundering field fixture emitted wrong diagnostic");
        os.LogStr(env_raw_field_nlaunder.errors[0].message);
        os.Exit(1);
    }

    mut t_str_field_nlaunder := typechecker.make_type_str();
    mut t_ref_field_nlaunder := typechecker.make_type_reference(t_str_field_nlaunder, "ctx", ctx);

    mut holder_ref_layout_field_nlaunder: typechecker.StructLayout[ctx];
    unsafe {
        holder_ref_layout_field_nlaunder.brand = empty[Index[str, ctx]];
        holder_ref_layout_field_nlaunder.fields = std.HashMapNew(ctx);
    }
    holder_ref_layout_field_nlaunder.fields.Insert("view", t_ref_field_nlaunder);

    mut t_holder_ref_field_nlaunder := typechecker.make_type_struct("HolderRefFieldNlaunder", "", ctx);

    mut env_sandbox_field_nlaunder := typechecker.env_new(ctx);
    mut scope_sandbox_field_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_sandbox_field_nlaunder, "HolderRefFieldNlaunder", holder_ref_layout_field_nlaunder, ctx);

    typechecker.scope_insert(scope_sandbox_field_nlaunder, "holder_ref_field", t_holder_ref_field_nlaunder, ctx);
    env_sandbox_field_nlaunder.variable_types.Insert("holder_ref_field", t_holder_ref_field_nlaunder);

    typechecker.scope_insert(scope_sandbox_field_nlaunder, "sandbox_ref_field", t_ref_field_nlaunder, ctx);
    env_sandbox_field_nlaunder.variable_types.Insert("sandbox_ref_field", t_ref_field_nlaunder);

    mut sandbox_origins_field_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(sandbox_origins_field_nlaunder, "sandbox_field_root", ctx);
    env_sandbox_field_nlaunder.variable_origins.Insert("sandbox_ref_field", sandbox_origins_field_nlaunder);

    mut sandbox_prov_field_nlaunder := typechecker.expression_provenance_sandbox_derived(t_ref_field_nlaunder, ctx);
    sandbox_prov_field_nlaunder.legacy_origins = sandbox_origins_field_nlaunder;
    typechecker.env_record_variable_provenance(&env_sandbox_field_nlaunder, "sandbox_ref_field", sandbox_prov_field_nlaunder, ctx);

    mut lex_sandbox_field_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_sandbox_field_nlaunder, "holder_ref_field.view = sandbox_ref_field;");
    mut parser_sandbox_field_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_sandbox_field_nlaunder, &lex_sandbox_field_nlaunder, ctx);
    mut stmt_sandbox_field_nlaunder := parser.parse_statement(&parser_sandbox_field_nlaunder, ctx);

    typechecker.check_statement(stmt_sandbox_field_nlaunder, &env_sandbox_field_nlaunder, scope_sandbox_field_nlaunder, ctx);

    if len(env_sandbox_field_nlaunder.errors) == 0 {
        os.LogStr("Error: non-laundering field fixture expected sandbox-derived safe-branded field rejection");
        os.Exit(1);
    }
    if std.str_find(env_sandbox_field_nlaunder.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: non-laundering sandbox field fixture emitted wrong diagnostic");
        os.LogStr(env_sandbox_field_nlaunder.errors[0].message);
        os.Exit(1);
    }

    mut env_safe_field_nlaunder := typechecker.env_new(ctx);
    mut scope_safe_field_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_safe_field_nlaunder, "HolderIdxFieldNlaunder", holder_idx_layout_field_nlaunder, ctx);

    typechecker.scope_insert(scope_safe_field_nlaunder, "holder_safe_field", t_holder_idx_field_nlaunder, ctx);
    env_safe_field_nlaunder.variable_types.Insert("holder_safe_field", t_holder_idx_field_nlaunder);

    typechecker.scope_insert(scope_safe_field_nlaunder, "safe_idx_field", t_idx_field_nlaunder, ctx);
    env_safe_field_nlaunder.variable_types.Insert("safe_idx_field", t_idx_field_nlaunder);

    mut safe_origins_field_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_field_nlaunder, "safe_field_root", ctx);
    env_safe_field_nlaunder.variable_origins.Insert("safe_idx_field", safe_origins_field_nlaunder);

    mut safe_prov_field_nlaunder := typechecker.expression_provenance_safe_arena(t_idx_field_nlaunder, ctx);
    safe_prov_field_nlaunder.legacy_origins = safe_origins_field_nlaunder;
    typechecker.env_record_variable_provenance(&env_safe_field_nlaunder, "safe_idx_field", safe_prov_field_nlaunder, ctx);

    mut lex_safe_field_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_safe_field_nlaunder, "holder_safe_field.idx = safe_idx_field;");
    mut parser_safe_field_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_safe_field_nlaunder, &lex_safe_field_nlaunder, ctx);
    mut stmt_safe_field_nlaunder := parser.parse_statement(&parser_safe_field_nlaunder, ctx);

    typechecker.check_statement(stmt_safe_field_nlaunder, &env_safe_field_nlaunder, scope_safe_field_nlaunder, ctx);

    if len(env_safe_field_nlaunder.errors) != 0 {
        os.LogStr("Error: non-laundering field fixture rejected safe-arena field assignment");
        os.LogStr(env_safe_field_nlaunder.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: non-laundering safe-branded aggregate field enforcement verified!");
}