import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_missing_cleanup := typechecker.env_new(ctx);
    env_missing_cleanup.current_prefix = "main__";

    typechecker.env_register_struct_linear_metadata(&env_missing_cleanup, "main__MissingCleanupPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_missing_cleanup, "main__MissingCleanupPayload", "main__close_missing_cleanup_payload", ctx);
    typechecker.env_register_open_linear_resource(&env_missing_cleanup, "main__missing_cleanup_resource", "main__MissingCleanupPayload", ctx);

    if typechecker.env_open_linear_resource_requires_cleanup(&env_missing_cleanup, "main__missing_cleanup_resource", ctx) != 1 {
        os.LogStr("Error: missing-cleanup fixture resource must require cleanup while owned");
        os.Exit(1);
    }
    if typechecker.env_count_open_linear_resources_requiring_cleanup(&env_missing_cleanup, ctx) != 1 {
        os.LogStr("Error: missing-cleanup fixture must have exactly one pending cleanup resource");
        os.Exit(1);
    }

    mut span_missing_cleanup: token.Span;
    if typechecker.env_report_linear_resource_missing_cleanup(&env_missing_cleanup, "main__missing_cleanup_resource", span_missing_cleanup, ctx) != 1 {
        os.LogStr("Error: missing-cleanup diagnostic helper must report an owned tracked resource");
        os.Exit(1);
    }
    if len(env_missing_cleanup.errors) == 0 {
        os.LogStr("Error: missing-cleanup diagnostic helper did not record an error");
        os.Exit(1);
    }
    if std.str_find(env_missing_cleanup.errors[0].message, "LinearResourceMissingCleanup") == 0 - 1 {
        os.LogStr("Error: missing-cleanup diagnostic helper emitted wrong diagnostic");
        os.LogStr(env_missing_cleanup.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource missing-cleanup diagnostic helper verified!");
}