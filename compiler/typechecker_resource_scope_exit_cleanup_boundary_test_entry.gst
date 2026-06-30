import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut span_scope_exit_cleanup: token.Span;

    mut env_clean_scope_exit := typechecker.env_new(ctx);
    if typechecker.env_validate_linear_resource_scope_exit_cleanup(&env_clean_scope_exit, span_scope_exit_cleanup, ctx) != 1 {
        os.LogStr("Error: scope-exit cleanup helper must accept a clean environment");
        os.Exit(1);
    }
    if len(env_clean_scope_exit.errors) != 0 {
        os.LogStr("Error: clean scope-exit cleanup helper recorded an unexpected error");
        os.Exit(1);
    }

    mut env_pending_scope_exit := typechecker.env_new(ctx);
    env_pending_scope_exit.current_prefix = "main__";
    typechecker.env_register_struct_linear_metadata(&env_pending_scope_exit, "main__ScopeExitPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_pending_scope_exit, "main__ScopeExitPayload", "main__close_scope_exit_payload", ctx);
    typechecker.env_register_open_linear_resource(&env_pending_scope_exit, "main__scope_exit_resource", "main__ScopeExitPayload", ctx);

    if typechecker.env_validate_linear_resource_scope_exit_cleanup(&env_pending_scope_exit, span_scope_exit_cleanup, ctx) != 0 {
        os.LogStr("Error: scope-exit cleanup helper must reject pending cleanup");
        os.Exit(1);
    }
    if len(env_pending_scope_exit.errors) != 1 {
        os.LogStr("Error: scope-exit cleanup helper should record exactly one pending cleanup error");
        os.Exit(1);
    }
    if std.str_find(env_pending_scope_exit.errors[0].message, "LinearResourceMissingCleanup") == 0 - 1 {
        os.LogStr("Error: scope-exit cleanup helper emitted wrong diagnostic");
        os.LogStr(env_pending_scope_exit.errors[0].message);
        os.Exit(1);
    }
    if std.str_find(env_pending_scope_exit.errors[0].message, "main__scope_exit_resource") == 0 - 1 {
        os.LogStr("Error: scope-exit cleanup helper did not report the pending resource name");
        os.LogStr(env_pending_scope_exit.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource scope-exit cleanup boundary helper verified!");
}