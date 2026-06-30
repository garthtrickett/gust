import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_use_after_move_pass := typechecker.env_new(ctx);
    env_use_after_move_pass.current_prefix = "main__";
    mut scope_use_after_move_pass := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_use_after_move_pass, "main__UseAfterMovePassPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_use_after_move_pass, "main__UseAfterMovePassPayload", "close_use_after_move_pass_payload", ctx);

    mut span_use_after_move_pass: token.Span;

    mut payload_use_after_move_pass := typechecker.make_type_struct("main__UseAfterMovePassPayload", "", ctx);
    mut resource_use_after_move_pass := typechecker.make_type_resource(payload_use_after_move_pass, ctx);
    mut resource_type_idx_use_after_move_pass: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_use_after_move_pass, resource_use_after_move_pass);

    mut source_decl_use_after_move_pass: ast.Statement[ctx];
    unsafe {
        source_decl_use_after_move_pass.tag = 4; // VarDecl
        source_decl_use_after_move_pass.VarDecl.name = "source_pass_resource";
        source_decl_use_after_move_pass.VarDecl.is_mut = 1;
        source_decl_use_after_move_pass.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        source_decl_use_after_move_pass.VarDecl.var_type = resource_type_idx_use_after_move_pass;
        source_decl_use_after_move_pass.VarDecl.span = span_use_after_move_pass;
    }
    mut source_decl_idx_use_after_move_pass: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(source_decl_idx_use_after_move_pass, source_decl_use_after_move_pass);
    typechecker.check_statement(source_decl_idx_use_after_move_pass, &env_use_after_move_pass, scope_use_after_move_pass, ctx);

    mut target_decl_use_after_move_pass: ast.Statement[ctx];
    unsafe {
        target_decl_use_after_move_pass.tag = 4; // VarDecl
        target_decl_use_after_move_pass.VarDecl.name = "target_pass_resource";
        target_decl_use_after_move_pass.VarDecl.is_mut = 1;
        target_decl_use_after_move_pass.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        target_decl_use_after_move_pass.VarDecl.var_type = resource_type_idx_use_after_move_pass;
        target_decl_use_after_move_pass.VarDecl.span = span_use_after_move_pass;
    }
    mut target_decl_idx_use_after_move_pass: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(target_decl_idx_use_after_move_pass, target_decl_use_after_move_pass);
    typechecker.check_statement(target_decl_idx_use_after_move_pass, &env_use_after_move_pass, scope_use_after_move_pass, ctx);
    typechecker.env_mark_open_linear_resource_closed(&env_use_after_move_pass, "target_pass_resource", ctx);

    mut lex_move_pass: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_move_pass, "target_pass_resource = source_pass_resource;");
    mut parser_move_pass: parser.Parser[ctx];
    parser.init_parser(&parser_move_pass, &lex_move_pass, ctx);
    mut stmt_move_pass := parser.parse_statement(&parser_move_pass, ctx);

    typechecker.check_statement(stmt_move_pass, &env_use_after_move_pass, scope_use_after_move_pass, ctx);

    if typechecker.env_open_linear_resource_is_moved(&env_use_after_move_pass, "source_pass_resource", ctx) != 1 {
        os.LogStr("Error: pass fixture setup did not move source resource");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_owned(&env_use_after_move_pass, "target_pass_resource", ctx) != 1 {
        os.LogStr("Error: pass fixture target resource should remain owned after first move");
        os.Exit(1);
    }
    if len(env_use_after_move_pass.errors) != 0 {
        os.LogStr("Error: first Resource move assignment should not reject before moved-source reuse");
        os.LogStr(env_use_after_move_pass.errors[0].message);
        os.Exit(1);
    }


    os.LogStr("SUCCESS: compiler-backed Resource use-after-move pass path verified!");
}
