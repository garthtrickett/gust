import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_void_call_nlaunder: ast.Type[ctx];
    unsafe {
        t_void_call_nlaunder.tag = 3; // Void
    }

    mut t_idx_call_nlaunder := typechecker.make_type_index("SafeCellCall", "ctx", ctx);

    mut sig_idx_call_nlaunder: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&sig_idx_call_nlaunder);
    sig_idx_call_nlaunder.param_names = std.VectorNew(ctx);
    sig_idx_call_nlaunder.params = std.VectorNew(ctx);
    sig_idx_call_nlaunder.return_type = t_void_call_nlaunder;
    sig_idx_call_nlaunder.return_origins = typechecker.set_init(ctx);
    sig_idx_call_nlaunder.is_unsafe = 0;
    sig_idx_call_nlaunder.param_names.Push("idx");
    sig_idx_call_nlaunder.params.Push(t_idx_call_nlaunder);

    mut env_raw_call_nlaunder := typechecker.env_new(ctx);
    mut scope_raw_call_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_function(&env_raw_call_nlaunder, "accept_safe_idx_call", sig_idx_call_nlaunder, ctx);

    typechecker.scope_insert(scope_raw_call_nlaunder, "raw_idx_call", t_idx_call_nlaunder, ctx);
    env_raw_call_nlaunder.variable_types.Insert("raw_idx_call", t_idx_call_nlaunder);

    mut raw_origins_call_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(raw_origins_call_nlaunder, "raw_call_root", ctx);
    env_raw_call_nlaunder.variable_origins.Insert("raw_idx_call", raw_origins_call_nlaunder);

    mut raw_prov_call_nlaunder := typechecker.expression_provenance_raw_derived(t_idx_call_nlaunder, ctx);
    raw_prov_call_nlaunder.legacy_origins = raw_origins_call_nlaunder;
    typechecker.env_record_variable_provenance(&env_raw_call_nlaunder, "raw_idx_call", raw_prov_call_nlaunder, ctx);

    mut lex_raw_call_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_raw_call_nlaunder, "accept_safe_idx_call(raw_idx_call);");
    mut parser_raw_call_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_raw_call_nlaunder, &lex_raw_call_nlaunder, ctx);
    mut stmt_raw_call_nlaunder := parser.parse_statement(&parser_raw_call_nlaunder, ctx);

    typechecker.check_statement(stmt_raw_call_nlaunder, &env_raw_call_nlaunder, scope_raw_call_nlaunder, ctx);

    if len(env_raw_call_nlaunder.errors) == 0 {
        os.LogStr("Error: non-laundering call fixture expected raw-derived argument rejection");
        os.Exit(1);
    }
    if std.str_find(env_raw_call_nlaunder.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: non-laundering call fixture emitted wrong diagnostic");
        os.LogStr(env_raw_call_nlaunder.errors[0].message);
        os.Exit(1);
    }

    mut t_str_call_nlaunder := typechecker.make_type_str();
    mut t_ref_call_nlaunder := typechecker.make_type_reference(t_str_call_nlaunder, "ctx", ctx);

    mut sig_ref_call_nlaunder: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&sig_ref_call_nlaunder);
    sig_ref_call_nlaunder.param_names = std.VectorNew(ctx);
    sig_ref_call_nlaunder.params = std.VectorNew(ctx);
    sig_ref_call_nlaunder.return_type = t_void_call_nlaunder;
    sig_ref_call_nlaunder.return_origins = typechecker.set_init(ctx);
    sig_ref_call_nlaunder.is_unsafe = 0;
    sig_ref_call_nlaunder.param_names.Push("ref_arg");
    sig_ref_call_nlaunder.params.Push(t_ref_call_nlaunder);

    mut env_sandbox_call_nlaunder := typechecker.env_new(ctx);
    mut scope_sandbox_call_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_function(&env_sandbox_call_nlaunder, "accept_safe_ref_call", sig_ref_call_nlaunder, ctx);

    typechecker.scope_insert(scope_sandbox_call_nlaunder, "sandbox_ref_call", t_ref_call_nlaunder, ctx);
    env_sandbox_call_nlaunder.variable_types.Insert("sandbox_ref_call", t_ref_call_nlaunder);

    mut sandbox_origins_call_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(sandbox_origins_call_nlaunder, "sandbox_call_root", ctx);
    env_sandbox_call_nlaunder.variable_origins.Insert("sandbox_ref_call", sandbox_origins_call_nlaunder);

    mut sandbox_prov_call_nlaunder := typechecker.expression_provenance_sandbox_derived(t_ref_call_nlaunder, ctx);
    sandbox_prov_call_nlaunder.legacy_origins = sandbox_origins_call_nlaunder;
    typechecker.env_record_variable_provenance(&env_sandbox_call_nlaunder, "sandbox_ref_call", sandbox_prov_call_nlaunder, ctx);

    mut lex_sandbox_call_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_sandbox_call_nlaunder, "accept_safe_ref_call(sandbox_ref_call);");
    mut parser_sandbox_call_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_sandbox_call_nlaunder, &lex_sandbox_call_nlaunder, ctx);
    mut stmt_sandbox_call_nlaunder := parser.parse_statement(&parser_sandbox_call_nlaunder, ctx);

    typechecker.check_statement(stmt_sandbox_call_nlaunder, &env_sandbox_call_nlaunder, scope_sandbox_call_nlaunder, ctx);

    if len(env_sandbox_call_nlaunder.errors) == 0 {
        os.LogStr("Error: non-laundering call fixture expected sandbox-derived argument rejection");
        os.Exit(1);
    }
    if std.str_find(env_sandbox_call_nlaunder.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: non-laundering sandbox call fixture emitted wrong diagnostic");
        os.LogStr(env_sandbox_call_nlaunder.errors[0].message);
        os.Exit(1);
    }

    mut env_safe_call_nlaunder := typechecker.env_new(ctx);
    mut scope_safe_call_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_function(&env_safe_call_nlaunder, "accept_safe_idx_call", sig_idx_call_nlaunder, ctx);

    typechecker.scope_insert(scope_safe_call_nlaunder, "safe_idx_call", t_idx_call_nlaunder, ctx);
    env_safe_call_nlaunder.variable_types.Insert("safe_idx_call", t_idx_call_nlaunder);

    mut safe_origins_call_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_call_nlaunder, "safe_call_root", ctx);
    env_safe_call_nlaunder.variable_origins.Insert("safe_idx_call", safe_origins_call_nlaunder);

    mut safe_prov_call_nlaunder := typechecker.expression_provenance_safe_arena(t_idx_call_nlaunder, ctx);
    safe_prov_call_nlaunder.legacy_origins = safe_origins_call_nlaunder;
    typechecker.env_record_variable_provenance(&env_safe_call_nlaunder, "safe_idx_call", safe_prov_call_nlaunder, ctx);

    mut lex_safe_call_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_safe_call_nlaunder, "accept_safe_idx_call(safe_idx_call);");
    mut parser_safe_call_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_safe_call_nlaunder, &lex_safe_call_nlaunder, ctx);
    mut stmt_safe_call_nlaunder := parser.parse_statement(&parser_safe_call_nlaunder, ctx);

    typechecker.check_statement(stmt_safe_call_nlaunder, &env_safe_call_nlaunder, scope_safe_call_nlaunder, ctx);

    if len(env_safe_call_nlaunder.errors) != 0 {
        os.LogStr("Error: non-laundering call fixture rejected safe-arena argument");
        os.LogStr(env_safe_call_nlaunder.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: non-laundering safe-branded call argument enforcement verified!");
}