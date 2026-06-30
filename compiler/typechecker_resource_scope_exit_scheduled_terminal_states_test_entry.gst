import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_scope_scheduled_terminal := typechecker.env_new(ctx);
    env_scope_scheduled_terminal.current_prefix = "main__";
    mut scope_scope_scheduled_terminal := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_scope_scheduled_terminal, "main__ScopeScheduledPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_scope_scheduled_terminal, "main__ScopeScheduledPayload", "main__close_scope_scheduled_payload", ctx);

    mut span_scope_scheduled_terminal: token.Span;

    mut payload_scope_scheduled_terminal := typechecker.make_type_struct("main__ScopeScheduledPayload", "", ctx);
    mut resource_scope_scheduled_terminal := typechecker.make_type_resource(payload_scope_scheduled_terminal, ctx);
    mut resource_type_idx_scope_scheduled_terminal: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_scope_scheduled_terminal, resource_scope_scheduled_terminal);

    mut decl_scope_scheduled_terminal: ast.Statement[ctx];
    unsafe {
        decl_scope_scheduled_terminal.tag = 4; // VarDecl
        decl_scope_scheduled_terminal.VarDecl.name = "scope_scheduled_resource";
        decl_scope_scheduled_terminal.VarDecl.is_mut = 1;
        decl_scope_scheduled_terminal.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        decl_scope_scheduled_terminal.VarDecl.var_type = resource_type_idx_scope_scheduled_terminal;
        decl_scope_scheduled_terminal.VarDecl.span = span_scope_scheduled_terminal;
    }
    mut decl_idx_scope_scheduled_terminal: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(decl_idx_scope_scheduled_terminal, decl_scope_scheduled_terminal);

    typechecker.check_statement(decl_idx_scope_scheduled_terminal, &env_scope_scheduled_terminal, scope_scope_scheduled_terminal, ctx);

    if typechecker.env_try_schedule_open_linear_resource_destructor(&env_scope_scheduled_terminal, "scope_scheduled_resource", ctx) != 1 {
        os.LogStr("Error: scope scheduled terminal fixture failed to schedule destructor");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_scope_scheduled_terminal, "scope_scheduled_resource", ctx) != 1 {
        os.LogStr("Error: scope scheduled terminal fixture must start destructor-scheduled before scope-exit cleanup");
        os.Exit(1);
    }

    typechecker.env_validate_linear_resource_scope_exit_cleanup(&env_scope_scheduled_terminal, span_scope_scheduled_terminal, ctx);

    mut scope_scheduled_missing_cleanup_count := 0;
    mut error_idx_scope_scheduled_terminal := 0;
    while error_idx_scope_scheduled_terminal < len(env_scope_scheduled_terminal.errors) {
        mut msg_scope_scheduled_terminal := env_scope_scheduled_terminal.errors[error_idx_scope_scheduled_terminal].message;
        if std.str_find(msg_scope_scheduled_terminal, "LinearResourceMissingCleanup") != 0 - 1 {
            if std.str_find(msg_scope_scheduled_terminal, "scope_scheduled_resource") != 0 - 1 {
                scope_scheduled_missing_cleanup_count = scope_scheduled_missing_cleanup_count + 1;
            }
        }
        error_idx_scope_scheduled_terminal = error_idx_scope_scheduled_terminal + 1;
    }

    if scope_scheduled_missing_cleanup_count != 0 {
        os.LogStr("Error: scope-exit cleanup integration should not report destructor-scheduled terminal resource cleanup");
        if len(env_scope_scheduled_terminal.errors) > 0 {
            os.LogStr(env_scope_scheduled_terminal.errors[0].message);
        }
        os.Exit(1);
    }
    if len(env_scope_scheduled_terminal.errors) != 0 {
        os.LogStr("Error: scope scheduled terminal fixture emitted an unexpected diagnostic");
        os.LogStr(env_scope_scheduled_terminal.errors[0].message);
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_scope_scheduled_terminal, "scope_scheduled_resource", ctx) != 1 {
        os.LogStr("Error: scope-exit cleanup should preserve destructor-scheduled terminal state");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource scope-exit destructor-scheduled terminal-state integration verified!");
}