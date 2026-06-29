import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_use_after_move_reject := typechecker.env_new(ctx);
    env_use_after_move_reject.current_prefix = "main__";
    mut scope_use_after_move_reject := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_use_after_move_reject, "main__UseAfterMoveRejectPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_use_after_move_reject, "main__UseAfterMoveRejectPayload", "close_use_after_move_reject_payload", ctx);

    mut span_use_after_move_reject: token.Span;

    mut payload_use_after_move_reject := typechecker.make_type_struct("main__UseAfterMoveRejectPayload", "", ctx);
    mut resource_use_after_move_reject := typechecker.make_type_resource(payload_use_after_move_reject, ctx);
    mut resource_type_idx_use_after_move_reject: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_use_after_move_reject, resource_use_after_move_reject);

    mut source_decl_use_after_move_reject: ast.Statement[ctx];
    unsafe {
        source_decl_use_after_move_reject.tag = 4; // VarDecl
        source_decl_use_after_move_reject.VarDecl.name = "source_reject_resource";
        source_decl_use_after_move_reject.VarDecl.is_mut = 1;
        source_decl_use_after_move_reject.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        source_decl_use_after_move_reject.VarDecl.var_type = resource_type_idx_use_after_move_reject;
        source_decl_use_after_move_reject.VarDecl.span = span_use_after_move_reject;
    }
    mut source_decl_idx_use_after_move_reject: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(source_decl_idx_use_after_move_reject, source_decl_use_after_move_reject);
    typechecker.check_statement(source_decl_idx_use_after_move_reject, &env_use_after_move_reject, scope_use_after_move_reject, ctx);

    mut target_decl_use_after_move_reject: ast.Statement[ctx];
    unsafe {
        target_decl_use_after_move_reject.tag = 4; // VarDecl
        target_decl_use_after_move_reject.VarDecl.name = "target_reject_resource";
        target_decl_use_after_move_reject.VarDecl.is_mut = 1;
        target_decl_use_after_move_reject.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        target_decl_use_after_move_reject.VarDecl.var_type = resource_type_idx_use_after_move_reject;
        target_decl_use_after_move_reject.VarDecl.span = span_use_after_move_reject;
    }
    mut target_decl_idx_use_after_move_reject: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(target_decl_idx_use_after_move_reject, target_decl_use_after_move_reject);
    typechecker.check_statement(target_decl_idx_use_after_move_reject, &env_use_after_move_reject, scope_use_after_move_reject, ctx);

    mut lex_move_reject: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_move_reject, "target_reject_resource = source_reject_resource;");
    mut parser_move_reject: parser.Parser[ctx];
    parser.init_parser(&parser_move_reject, &lex_move_reject, ctx);
    mut stmt_move_reject := parser.parse_statement(&parser_move_reject, ctx);

    typechecker.check_statement(stmt_move_reject, &env_use_after_move_reject, scope_use_after_move_reject, ctx);

    if typechecker.env_open_linear_resource_is_moved(&env_use_after_move_reject, "source_reject_resource", ctx) != 1 {
        os.LogStr("Error: rejection fixture setup did not move source resource");
        os.Exit(1);
    }
    if len(env_use_after_move_reject.errors) != 0 {
        os.LogStr("Error: first Resource move assignment should not reject before moved-source reuse");
        os.LogStr(env_use_after_move_reject.errors[0].message);
        os.Exit(1);
    }

    mut lex_second_reject: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_second_reject, "target_reject_resource = source_reject_resource;");
    mut parser_second_reject: parser.Parser[ctx];
    parser.init_parser(&parser_second_reject, &lex_second_reject, ctx);
    mut stmt_second_reject := parser.parse_statement(&parser_second_reject, ctx);

    typechecker.check_statement(stmt_second_reject, &env_use_after_move_reject, scope_use_after_move_reject, ctx);

    if len(env_use_after_move_reject.errors) == 0 {
        os.LogStr("Error: moved tracked Resource reuse must be rejected");
        os.Exit(1);
    }

    mut found_use_after_move_reject := 0;
    mut err_idx_use_after_move_reject := 0;
    while err_idx_use_after_move_reject < len(env_use_after_move_reject.errors) {
        mut err_use_after_move_reject := env_use_after_move_reject.errors[err_idx_use_after_move_reject];
        if std.str_find(err_use_after_move_reject.message, "LinearResourceUseAfterMove") != 0 - 1 {
            found_use_after_move_reject = 1;
        }
        err_idx_use_after_move_reject = err_idx_use_after_move_reject + 1;
    }

    if found_use_after_move_reject == 0 {
        os.LogStr("Error: moved tracked Resource reuse emitted wrong diagnostic");
        os.LogStr(env_use_after_move_reject.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource use-after-move rejection verified!");
}