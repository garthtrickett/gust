import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut span_defer_close: token.Span;
    mut payload_defer_close := typechecker.make_type_struct("main__DeferClosePayload", "", ctx);
    mut resource_defer_close := typechecker.make_type_resource(payload_defer_close, ctx);
    mut resource_type_idx_defer_close: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_defer_close, resource_defer_close);

    mut env_schedule_then_close := typechecker.env_new(ctx);
    env_schedule_then_close.current_prefix = "main__";
    mut scope_schedule_then_close := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct_linear_metadata(&env_schedule_then_close, "main__DeferClosePayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_schedule_then_close, "main__DeferClosePayload", "close_defer_close_payload", ctx);

    mut decl_schedule_then_close: ast.Statement[ctx];
    unsafe {
        decl_schedule_then_close.tag = 4; // VarDecl
        decl_schedule_then_close.VarDecl.name = "scheduled_then_closed_resource";
        decl_schedule_then_close.VarDecl.is_mut = 1;
        decl_schedule_then_close.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        decl_schedule_then_close.VarDecl.var_type = resource_type_idx_defer_close;
        decl_schedule_then_close.VarDecl.span = span_defer_close;
    }
    mut decl_idx_schedule_then_close: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(decl_idx_schedule_then_close, decl_schedule_then_close);
    typechecker.check_statement(decl_idx_schedule_then_close, &env_schedule_then_close, scope_schedule_then_close, ctx);

    mut lex_defer_schedule_then_close: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_defer_schedule_then_close, "defer close_defer_close_payload(scheduled_then_closed_resource);");
    mut parser_defer_schedule_then_close: parser.Parser[ctx];
    parser.init_parser(&parser_defer_schedule_then_close, &lex_defer_schedule_then_close, ctx);
    mut stmt_defer_schedule_then_close := parser.parse_statement(&parser_defer_schedule_then_close, ctx);
    typechecker.check_statement(stmt_defer_schedule_then_close, &env_schedule_then_close, scope_schedule_then_close, ctx);

    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_schedule_then_close, "scheduled_then_closed_resource", ctx) != 1 {
        os.LogStr("Error: setup defer should schedule Resource before manual close interaction check");
        os.Exit(1);
    }

    mut lex_manual_close_after_defer: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_manual_close_after_defer, "close_defer_close_payload(scheduled_then_closed_resource);");
    mut parser_manual_close_after_defer: parser.Parser[ctx];
    parser.init_parser(&parser_manual_close_after_defer, &lex_manual_close_after_defer, ctx);
    mut stmt_manual_close_after_defer := parser.parse_statement(&parser_manual_close_after_defer, ctx);
    typechecker.check_statement(stmt_manual_close_after_defer, &env_schedule_then_close, scope_schedule_then_close, ctx);

    if len(env_schedule_then_close.errors) == 0 {
        os.LogStr("Error: manual close after real defer scheduling should be rejected");
        os.Exit(1);
    }

    mut found_manual_close_scheduled_diag := 0;
    mut err_idx_manual_close := 0;
    while err_idx_manual_close < len(env_schedule_then_close.errors) {
        mut err_manual_close := env_schedule_then_close.errors[err_idx_manual_close];
        if std.str_find(err_manual_close.message, "LinearResourceDestructorAlreadyScheduled") != 0 - 1 {
            found_manual_close_scheduled_diag = 1;
        }
        err_idx_manual_close = err_idx_manual_close + 1;
    }
    if found_manual_close_scheduled_diag == 0 {
        os.LogStr("Error: manual close after scheduling should emit LinearResourceDestructorAlreadyScheduled");
        os.LogStr(env_schedule_then_close.errors[0].message);
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_schedule_then_close, "scheduled_then_closed_resource", ctx) != 1 {
        os.LogStr("Error: rejected manual close after scheduling should leave Resource destructor_scheduled");
        os.Exit(1);
    }

    mut env_close_then_schedule := typechecker.env_new(ctx);
    env_close_then_schedule.current_prefix = "main__";
    mut scope_close_then_schedule := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct_linear_metadata(&env_close_then_schedule, "main__DeferClosePayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_close_then_schedule, "main__DeferClosePayload", "close_defer_close_payload", ctx);

    mut decl_close_then_schedule: ast.Statement[ctx];
    unsafe {
        decl_close_then_schedule.tag = 4; // VarDecl
        decl_close_then_schedule.VarDecl.name = "closed_then_scheduled_resource";
        decl_close_then_schedule.VarDecl.is_mut = 1;
        decl_close_then_schedule.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        decl_close_then_schedule.VarDecl.var_type = resource_type_idx_defer_close;
        decl_close_then_schedule.VarDecl.span = span_defer_close;
    }
    mut decl_idx_close_then_schedule: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(decl_idx_close_then_schedule, decl_close_then_schedule);
    typechecker.check_statement(decl_idx_close_then_schedule, &env_close_then_schedule, scope_close_then_schedule, ctx);
    typechecker.env_mark_open_linear_resource_closed(&env_close_then_schedule, "closed_then_scheduled_resource", ctx);

    mut lex_defer_after_manual_close: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_defer_after_manual_close, "defer close_defer_close_payload(closed_then_scheduled_resource);");
    mut parser_defer_after_manual_close: parser.Parser[ctx];
    parser.init_parser(&parser_defer_after_manual_close, &lex_defer_after_manual_close, ctx);
    mut stmt_defer_after_manual_close := parser.parse_statement(&parser_defer_after_manual_close, ctx);
    typechecker.check_statement(stmt_defer_after_manual_close, &env_close_then_schedule, scope_close_then_schedule, ctx);

    if len(env_close_then_schedule.errors) == 0 {
        os.LogStr("Error: defer scheduling after manual close should be rejected");
        os.Exit(1);
    }

    mut found_defer_after_close_invalid_transfer := 0;
    mut err_idx_defer_after_close := 0;
    while err_idx_defer_after_close < len(env_close_then_schedule.errors) {
        mut err_defer_after_close := env_close_then_schedule.errors[err_idx_defer_after_close];
        if std.str_find(err_defer_after_close.message, "LinearResourceInvalidTransfer") != 0 - 1 {
            found_defer_after_close_invalid_transfer = 1;
        }
        err_idx_defer_after_close = err_idx_defer_after_close + 1;
    }
    if found_defer_after_close_invalid_transfer == 0 {
        os.LogStr("Error: defer scheduling after manual close should emit LinearResourceInvalidTransfer");
        os.LogStr(env_close_then_schedule.errors[0].message);
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_closed(&env_close_then_schedule, "closed_then_scheduled_resource", ctx) != 1 {
        os.LogStr("Error: rejected defer scheduling after manual close should leave Resource closed");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_close_then_schedule, "closed_then_scheduled_resource", ctx) != 0 {
        os.LogStr("Error: rejected defer scheduling after manual close must not schedule Resource destructor");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: real Resource defer/manual-close interaction verified!");
}