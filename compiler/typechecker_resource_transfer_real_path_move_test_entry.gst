import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_real_path_move := typechecker.env_new(ctx);
    env_real_path_move.current_prefix = "main__";
    mut scope_real_path_move := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_real_path_move, "main__TransferRealPathMovePayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_real_path_move, "main__TransferRealPathMovePayload", "close_transfer_real_path_move_payload", ctx);

    mut span_real_path_move: token.Span;

    mut payload_real_path_move := typechecker.make_type_struct("main__TransferRealPathMovePayload", "", ctx);
    mut resource_real_path_move := typechecker.make_type_resource(payload_real_path_move, ctx);
    mut resource_type_idx_real_path_move: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_real_path_move, resource_real_path_move);

    mut source_decl_real_path_move: ast.Statement[ctx];
    unsafe {
        source_decl_real_path_move.tag = 4; // VarDecl
        source_decl_real_path_move.VarDecl.name = "source_real_path_move_resource";
        source_decl_real_path_move.VarDecl.is_mut = 1;
        source_decl_real_path_move.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        source_decl_real_path_move.VarDecl.var_type = resource_type_idx_real_path_move;
        source_decl_real_path_move.VarDecl.span = span_real_path_move;
    }
    mut source_decl_idx_real_path_move: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(source_decl_idx_real_path_move, source_decl_real_path_move);
    typechecker.check_statement(source_decl_idx_real_path_move, &env_real_path_move, scope_real_path_move, ctx);

    mut target_decl_real_path_move: ast.Statement[ctx];
    unsafe {
        target_decl_real_path_move.tag = 4; // VarDecl
        target_decl_real_path_move.VarDecl.name = "target_real_path_move_resource";
        target_decl_real_path_move.VarDecl.is_mut = 1;
        target_decl_real_path_move.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        target_decl_real_path_move.VarDecl.var_type = resource_type_idx_real_path_move;
        target_decl_real_path_move.VarDecl.span = span_real_path_move;
    }
    mut target_decl_idx_real_path_move: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(target_decl_idx_real_path_move, target_decl_real_path_move);
    typechecker.check_statement(target_decl_idx_real_path_move, &env_real_path_move, scope_real_path_move, ctx);

    typechecker.env_mark_open_linear_resource_closed(&env_real_path_move, "target_real_path_move_resource", ctx);
    typechecker.env_mark_open_linear_resource_destructor_scheduled(&env_real_path_move, "source_real_path_move_resource", ctx);

    mut lex_real_path_move: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_real_path_move, "target_real_path_move_resource = source_real_path_move_resource;");
    mut parser_real_path_move: parser.Parser[ctx];
    parser.init_parser(&parser_real_path_move, &lex_real_path_move, ctx);
    mut stmt_real_path_move := parser.parse_statement(&parser_real_path_move, ctx);

    typechecker.check_statement(stmt_real_path_move, &env_real_path_move, scope_real_path_move, ctx);

    if len(env_real_path_move.errors) == 0 {
        os.LogStr("Error: real move-assignment path should reject move-after-scheduled Resource source");
        os.Exit(1);
    }

    mut found_invalid_transfer_real_path_move := 0;
    mut err_idx_real_path_move := 0;
    while err_idx_real_path_move < len(env_real_path_move.errors) {
        mut err_real_path_move := env_real_path_move.errors[err_idx_real_path_move];
        if std.str_find(err_real_path_move.message, "LinearResourceInvalidTransfer") != 0 - 1 {
            found_invalid_transfer_real_path_move = 1;
        }
        err_idx_real_path_move = err_idx_real_path_move + 1;
    }

    if found_invalid_transfer_real_path_move == 0 {
        os.LogStr("Error: move-after-scheduled Resource source emitted wrong diagnostic");
        os.LogStr(env_real_path_move.errors[0].message);
        os.Exit(1);
    }

    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_real_path_move, "source_real_path_move_resource", ctx) != 1 {
        os.LogStr("Error: rejected move-after-scheduled path should leave source scheduled");
        os.Exit(1);
    }

    if typechecker.env_open_linear_resource_is_closed(&env_real_path_move, "target_real_path_move_resource", ctx) != 1 {
        os.LogStr("Error: rejected move-after-scheduled path should not reopen the target resource");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: real move-assignment path transfer-state validation verified!");
}