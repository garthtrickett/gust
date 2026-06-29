import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut span_first_cleanup: token.Span;

    mut env_empty_cleanup := typechecker.env_new(ctx);
    if typechecker.env_report_first_linear_resource_missing_cleanup(&env_empty_cleanup, span_first_cleanup, ctx) != 0 {
        os.LogStr("Error: first missing-cleanup helper must ignore empty environments");
        os.Exit(1);
    }
    if len(env_empty_cleanup.errors) != 0 {
        os.LogStr("Error: empty first missing-cleanup helper recorded an unexpected error");
        os.Exit(1);
    }

    mut env_first_cleanup := typechecker.env_new(ctx);
    env_first_cleanup.current_prefix = "main__";

    typechecker.env_register_struct_linear_metadata(&env_first_cleanup, "main__FirstCleanupPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_first_cleanup, "main__FirstCleanupPayload", "main__close_first_cleanup_payload", ctx);
    typechecker.env_register_open_linear_resource(&env_first_cleanup, "main__first_cleanup_resource", "main__FirstCleanupPayload", ctx);

    if typechecker.env_open_linear_resources_have_pending_cleanup(&env_first_cleanup, ctx) != 1 {
        os.LogStr("Error: first missing-cleanup fixture must have pending cleanup");
        os.Exit(1);
    }
    if typechecker.env_report_first_linear_resource_missing_cleanup(&env_first_cleanup, span_first_cleanup, ctx) != 1 {
        os.LogStr("Error: first missing-cleanup helper must report the pending resource");
        os.Exit(1);
    }
    if len(env_first_cleanup.errors) == 0 {
        os.LogStr("Error: first missing-cleanup helper did not record an error");
        os.Exit(1);
    }
    if std.str_find(env_first_cleanup.errors[0].message, "LinearResourceMissingCleanup") == 0 - 1 {
        os.LogStr("Error: first missing-cleanup helper emitted wrong diagnostic");
        os.LogStr(env_first_cleanup.errors[0].message);
        os.Exit(1);
    }
    if std.str_find(env_first_cleanup.errors[0].message, "main__first_cleanup_resource") == 0 - 1 {
        os.LogStr("Error: first missing-cleanup helper did not report the pending resource name");
        os.LogStr(env_first_cleanup.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource first pending cleanup report helper verified!");
}