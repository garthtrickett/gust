import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_idx_bind_nlaunder := typechecker.make_type_index("SafeCellBinding", "ctx", ctx);

    mut env_bind_raw_nlaunder := typechecker.env_new(ctx);
    mut scope_bind_raw_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.scope_insert(scope_bind_raw_nlaunder, "raw_idx_bind", t_idx_bind_nlaunder, ctx);
    env_bind_raw_nlaunder.variable_types.Insert("raw_idx_bind", t_idx_bind_nlaunder);

    mut raw_origins_bind_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(raw_origins_bind_nlaunder, "raw_bind_root", ctx);
    env_bind_raw_nlaunder.variable_origins.Insert("raw_idx_bind", raw_origins_bind_nlaunder);

    mut raw_prov_bind_nlaunder := typechecker.expression_provenance_raw_derived(t_idx_bind_nlaunder, ctx);
    raw_prov_bind_nlaunder.legacy_origins = raw_origins_bind_nlaunder;
    typechecker.env_record_variable_provenance(&env_bind_raw_nlaunder, "raw_idx_bind", raw_prov_bind_nlaunder, ctx);

    mut lex_bind_raw_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_bind_raw_nlaunder, "mut alias_idx_bind := raw_idx_bind;");
    mut parser_bind_raw_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_bind_raw_nlaunder, &lex_bind_raw_nlaunder, ctx);
    mut stmt_bind_raw_nlaunder := parser.parse_statement(&parser_bind_raw_nlaunder, ctx);

    typechecker.check_statement(stmt_bind_raw_nlaunder, &env_bind_raw_nlaunder, scope_bind_raw_nlaunder, ctx);

    if len(env_bind_raw_nlaunder.errors) == 0 {
        os.LogStr("Error: non-laundering binding fixture expected raw-derived binding rejection");
        os.Exit(1);
    }
    if std.str_find(env_bind_raw_nlaunder.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: non-laundering binding fixture emitted wrong diagnostic");
        os.LogStr(env_bind_raw_nlaunder.errors[0].message);
        os.Exit(1);
    }

    mut t_str_bind_nlaunder := typechecker.make_type_str();
    mut t_ref_bind_nlaunder := typechecker.make_type_reference(t_str_bind_nlaunder, "ctx", ctx);

    mut env_assign_sandbox_nlaunder := typechecker.env_new(ctx);
    mut scope_assign_sandbox_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.scope_insert(scope_assign_sandbox_nlaunder, "safe_ref_assign", t_ref_bind_nlaunder, ctx);
    env_assign_sandbox_nlaunder.variable_types.Insert("safe_ref_assign", t_ref_bind_nlaunder);

    mut safe_ref_origins_assign_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(safe_ref_origins_assign_nlaunder, "safe_ref_assignment_root", ctx);
    env_assign_sandbox_nlaunder.variable_origins.Insert("safe_ref_assign", safe_ref_origins_assign_nlaunder);

    mut safe_ref_prov_assign_nlaunder := typechecker.expression_provenance_safe_arena(t_ref_bind_nlaunder, ctx);
    safe_ref_prov_assign_nlaunder.legacy_origins = safe_ref_origins_assign_nlaunder;
    typechecker.env_record_variable_provenance(&env_assign_sandbox_nlaunder, "safe_ref_assign", safe_ref_prov_assign_nlaunder, ctx);

    typechecker.scope_insert(scope_assign_sandbox_nlaunder, "sandbox_ref_assign", t_ref_bind_nlaunder, ctx);
    env_assign_sandbox_nlaunder.variable_types.Insert("sandbox_ref_assign", t_ref_bind_nlaunder);

    mut sandbox_ref_origins_assign_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(sandbox_ref_origins_assign_nlaunder, "sandbox_ref_assignment_root", ctx);
    env_assign_sandbox_nlaunder.variable_origins.Insert("sandbox_ref_assign", sandbox_ref_origins_assign_nlaunder);

    mut sandbox_ref_prov_assign_nlaunder := typechecker.expression_provenance_sandbox_derived(t_ref_bind_nlaunder, ctx);
    sandbox_ref_prov_assign_nlaunder.legacy_origins = sandbox_ref_origins_assign_nlaunder;
    typechecker.env_record_variable_provenance(&env_assign_sandbox_nlaunder, "sandbox_ref_assign", sandbox_ref_prov_assign_nlaunder, ctx);

    mut lex_assign_sandbox_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_assign_sandbox_nlaunder, "safe_ref_assign = sandbox_ref_assign;");
    mut parser_assign_sandbox_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_assign_sandbox_nlaunder, &lex_assign_sandbox_nlaunder, ctx);
    mut stmt_assign_sandbox_nlaunder := parser.parse_statement(&parser_assign_sandbox_nlaunder, ctx);

    typechecker.check_statement(stmt_assign_sandbox_nlaunder, &env_assign_sandbox_nlaunder, scope_assign_sandbox_nlaunder, ctx);

    if len(env_assign_sandbox_nlaunder.errors) == 0 {
        os.LogStr("Error: non-laundering assignment fixture expected sandbox-derived assignment rejection");
        os.Exit(1);
    }
    if std.str_find(env_assign_sandbox_nlaunder.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: non-laundering assignment fixture emitted wrong diagnostic");
        os.LogStr(env_assign_sandbox_nlaunder.errors[0].message);
        os.Exit(1);
    }

    mut env_assign_safe_nlaunder := typechecker.env_new(ctx);
    mut scope_assign_safe_nlaunder := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.scope_insert(scope_assign_safe_nlaunder, "safe_idx_dst_bind", t_idx_bind_nlaunder, ctx);
    env_assign_safe_nlaunder.variable_types.Insert("safe_idx_dst_bind", t_idx_bind_nlaunder);

    mut safe_dst_origins_bind_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(safe_dst_origins_bind_nlaunder, "safe_dst_bind_root", ctx);
    env_assign_safe_nlaunder.variable_origins.Insert("safe_idx_dst_bind", safe_dst_origins_bind_nlaunder);

    mut safe_dst_prov_bind_nlaunder := typechecker.expression_provenance_safe_arena(t_idx_bind_nlaunder, ctx);
    safe_dst_prov_bind_nlaunder.legacy_origins = safe_dst_origins_bind_nlaunder;
    typechecker.env_record_variable_provenance(&env_assign_safe_nlaunder, "safe_idx_dst_bind", safe_dst_prov_bind_nlaunder, ctx);

    typechecker.scope_insert(scope_assign_safe_nlaunder, "safe_idx_src_bind", t_idx_bind_nlaunder, ctx);
    env_assign_safe_nlaunder.variable_types.Insert("safe_idx_src_bind", t_idx_bind_nlaunder);

    mut safe_src_origins_bind_nlaunder := typechecker.set_init(ctx);
    typechecker.set_add(safe_src_origins_bind_nlaunder, "safe_src_bind_root", ctx);
    env_assign_safe_nlaunder.variable_origins.Insert("safe_idx_src_bind", safe_src_origins_bind_nlaunder);

    mut safe_src_prov_bind_nlaunder := typechecker.expression_provenance_safe_arena(t_idx_bind_nlaunder, ctx);
    safe_src_prov_bind_nlaunder.legacy_origins = safe_src_origins_bind_nlaunder;
    typechecker.env_record_variable_provenance(&env_assign_safe_nlaunder, "safe_idx_src_bind", safe_src_prov_bind_nlaunder, ctx);

    mut lex_assign_safe_nlaunder: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_assign_safe_nlaunder, "safe_idx_dst_bind = safe_idx_src_bind;");
    mut parser_assign_safe_nlaunder: parser.Parser[ctx];
    parser.init_parser(&parser_assign_safe_nlaunder, &lex_assign_safe_nlaunder, ctx);
    mut stmt_assign_safe_nlaunder := parser.parse_statement(&parser_assign_safe_nlaunder, ctx);

    typechecker.check_statement(stmt_assign_safe_nlaunder, &env_assign_safe_nlaunder, scope_assign_safe_nlaunder, ctx);

    if len(env_assign_safe_nlaunder.errors) != 0 {
        os.LogStr("Error: non-laundering assignment fixture rejected safe-arena assignment");
        os.LogStr(env_assign_safe_nlaunder.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: non-laundering safe-branded binding enforcement verified!");
}