import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_return_scheduled_terminal := typechecker.env_new(ctx);
    env_return_scheduled_terminal.current_prefix = "main__";
    mut scope_return_scheduled_terminal := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_return_scheduled_terminal, "main__ReturnScheduledPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_return_scheduled_terminal, "main__ReturnScheduledPayload", "main__close_return_scheduled_payload", ctx);

    mut span_return_scheduled_terminal: token.Span;

    mut payload_return_scheduled_terminal := typechecker.make_type_struct("main__ReturnScheduledPayload", "", ctx);
    mut resource_return_scheduled_terminal := typechecker.make_type_resource(payload_return_scheduled_terminal, ctx);
    mut resource_type_idx_return_scheduled_terminal: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_return_scheduled_terminal, resource_return_scheduled_terminal);

    mut decl_return_scheduled_terminal: ast.Statement[ctx];
    unsafe {
        decl_return_scheduled_terminal.tag = 4; // VarDecl
        decl_return_scheduled_terminal.VarDecl.name = "return_scheduled_resource";
        decl_return_scheduled_terminal.VarDecl.is_mut = 1;
        decl_return_scheduled_terminal.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        decl_return_scheduled_terminal.VarDecl.var_type = resource_type_idx_return_scheduled_terminal;
        decl_return_scheduled_terminal.VarDecl.span = span_return_scheduled_terminal;
    }
    mut decl_idx_return_scheduled_terminal: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(decl_idx_return_scheduled_terminal, decl_return_scheduled_terminal);

    typechecker.check_statement(decl_idx_return_scheduled_terminal, &env_return_scheduled_terminal, scope_return_scheduled_terminal, ctx);

    if typechecker.env_try_schedule_open_linear_resource_destructor(&env_return_scheduled_terminal, "return_scheduled_resource", ctx) != 1 {
        os.LogStr("Error: return scheduled terminal fixture failed to schedule destructor");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_return_scheduled_terminal, "return_scheduled_resource", ctx) != 1 {
        os.LogStr("Error: return scheduled terminal fixture must start destructor-scheduled before return cleanup");
        os.Exit(1);
    }

    mut return_type_return_scheduled_terminal: ast.Type[ctx];
    unsafe {
        return_type_return_scheduled_terminal.tag = 3; // Void
    }
    mut return_type_idx_return_scheduled_terminal: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(return_type_idx_return_scheduled_terminal, return_type_return_scheduled_terminal);
    env_return_scheduled_terminal.expected_return_type = return_type_idx_return_scheduled_terminal;

    mut return_stmt_return_scheduled_terminal: ast.Statement[ctx];
    unsafe {
        return_stmt_return_scheduled_terminal.tag = 12; // Return
        return_stmt_return_scheduled_terminal.Return.expr = empty[Index[ast.Expression[ctx], ctx]];
        return_stmt_return_scheduled_terminal.Return.span = span_return_scheduled_terminal;
    }
    mut return_stmt_idx_return_scheduled_terminal: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(return_stmt_idx_return_scheduled_terminal, return_stmt_return_scheduled_terminal);

    typechecker.check_statement(return_stmt_idx_return_scheduled_terminal, &env_return_scheduled_terminal, scope_return_scheduled_terminal, ctx);

    mut return_scheduled_missing_cleanup_count := 0;
    mut error_idx_return_scheduled_terminal := 0;
    while error_idx_return_scheduled_terminal < len(env_return_scheduled_terminal.errors) {
        mut msg_return_scheduled_terminal := env_return_scheduled_terminal.errors[error_idx_return_scheduled_terminal].message;
        if std.str_find(msg_return_scheduled_terminal, "LinearResourceMissingCleanup") != 0 - 1 {
            if std.str_find(msg_return_scheduled_terminal, "return_scheduled_resource") != 0 - 1 {
                return_scheduled_missing_cleanup_count = return_scheduled_missing_cleanup_count + 1;
            }
        }
        error_idx_return_scheduled_terminal = error_idx_return_scheduled_terminal + 1;
    }

    if return_scheduled_missing_cleanup_count != 0 {
        os.LogStr("Error: return cleanup integration should not report destructor-scheduled terminal resource cleanup");
        if len(env_return_scheduled_terminal.errors) > 0 {
            os.LogStr(env_return_scheduled_terminal.errors[0].message);
        }
        os.Exit(1);
    }
    if len(env_return_scheduled_terminal.errors) != 0 {
        os.LogStr("Error: return scheduled terminal fixture emitted an unexpected diagnostic");
        os.LogStr(env_return_scheduled_terminal.errors[0].message);
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_return_scheduled_terminal, "return_scheduled_resource", ctx) != 1 {
        os.LogStr("Error: return cleanup should preserve destructor-scheduled terminal state");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource return cleanup destructor-scheduled terminal-state integration verified!");
}
