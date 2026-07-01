import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_defer_candidate := typechecker.env_new(ctx);
    env_defer_candidate.current_prefix = "main__";
    mut scope_defer_candidate := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_defer_candidate, "main__DeferCandidatePayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_defer_candidate, "main__DeferCandidatePayload", "close_defer_candidate_payload", ctx);

    mut span_defer_candidate: token.Span;
    mut payload_defer_candidate := typechecker.make_type_struct("main__DeferCandidatePayload", "", ctx);
    mut resource_defer_candidate := typechecker.make_type_resource(payload_defer_candidate, ctx);
    mut resource_type_idx_defer_candidate: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_defer_candidate, resource_defer_candidate);

    mut decl_defer_candidate: ast.Statement[ctx];
    unsafe {
        decl_defer_candidate.tag = 4; // VarDecl
        decl_defer_candidate.VarDecl.name = "candidate_resource";
        decl_defer_candidate.VarDecl.is_mut = 1;
        decl_defer_candidate.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        decl_defer_candidate.VarDecl.var_type = resource_type_idx_defer_candidate;
        decl_defer_candidate.VarDecl.span = span_defer_candidate;
    }
    mut decl_idx_defer_candidate: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(decl_idx_defer_candidate, decl_defer_candidate);
    typechecker.check_statement(decl_idx_defer_candidate, &env_defer_candidate, scope_defer_candidate, ctx);

    if typechecker.env_open_linear_resource_is_tracked(&env_defer_candidate, "candidate_resource", ctx) != 1 {
        os.LogStr("Error: setup Resource declaration should be tracked before defer recognizer checks");
        os.Exit(1);
    }

    mut lex_valid_defer_candidate: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_valid_defer_candidate, "defer close_defer_candidate_payload(candidate_resource);");
    mut parser_valid_defer_candidate: parser.Parser[ctx];
    parser.init_parser(&parser_valid_defer_candidate, &lex_valid_defer_candidate, ctx);
    mut stmt_valid_defer_candidate := parser.parse_statement(&parser_valid_defer_candidate, ctx);

    if typechecker.env_defer_statement_is_resource_destructor_candidate(&env_defer_candidate, stmt_valid_defer_candidate, ctx) != 1 {
        os.LogStr("Error: canonical defer destructor candidate should be recognized");
        os.Exit(1);
    }

    mut candidate_name_defer_candidate := typechecker.env_defer_statement_resource_destructor_candidate_name(&env_defer_candidate, stmt_valid_defer_candidate, ctx);
    if std.str_eq(candidate_name_defer_candidate, "candidate_resource") == 0 {
        os.LogStr("Error: defer destructor candidate recognizer returned wrong Resource name");
        os.Exit(1);
    }

    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_defer_candidate, "candidate_resource", ctx) != 0 {
        os.LogStr("Error: defer destructor candidate recognition must not schedule the Resource yet");
        os.Exit(1);
    }

    mut lex_wrong_destructor_defer_candidate: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_wrong_destructor_defer_candidate, "defer close_wrong_payload(candidate_resource);");
    mut parser_wrong_destructor_defer_candidate: parser.Parser[ctx];
    parser.init_parser(&parser_wrong_destructor_defer_candidate, &lex_wrong_destructor_defer_candidate, ctx);
    mut stmt_wrong_destructor_defer_candidate := parser.parse_statement(&parser_wrong_destructor_defer_candidate, ctx);
    if typechecker.env_defer_statement_is_resource_destructor_candidate(&env_defer_candidate, stmt_wrong_destructor_defer_candidate, ctx) != 0 {
        os.LogStr("Error: defer with the wrong destructor must not be a Resource destructor candidate");
        os.Exit(1);
    }

    mut lex_untracked_arg_defer_candidate: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_untracked_arg_defer_candidate, "defer close_defer_candidate_payload(untracked_resource);");
    mut parser_untracked_arg_defer_candidate: parser.Parser[ctx];
    parser.init_parser(&parser_untracked_arg_defer_candidate, &lex_untracked_arg_defer_candidate, ctx);
    mut stmt_untracked_arg_defer_candidate := parser.parse_statement(&parser_untracked_arg_defer_candidate, ctx);
    if typechecker.env_defer_statement_is_resource_destructor_candidate(&env_defer_candidate, stmt_untracked_arg_defer_candidate, ctx) != 0 {
        os.LogStr("Error: defer with an untracked first argument must not be a Resource destructor candidate");
        os.Exit(1);
    }

    mut lex_non_defer_candidate: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_non_defer_candidate, "close_defer_candidate_payload(candidate_resource);");
    mut parser_non_defer_candidate: parser.Parser[ctx];
    parser.init_parser(&parser_non_defer_candidate, &lex_non_defer_candidate, ctx);
    mut stmt_non_defer_candidate := parser.parse_statement(&parser_non_defer_candidate, ctx);
    if typechecker.env_defer_statement_is_resource_destructor_candidate(&env_defer_candidate, stmt_non_defer_candidate, ctx) != 0 {
        os.LogStr("Error: non-defer destructor call must not be a defer destructor candidate");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: semantic defer destructor candidate recognizer verified!");
}