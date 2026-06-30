import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut span_dedup_cleanup: token.Span;

    mut env_dedup_cleanup := typechecker.env_new(ctx);
    env_dedup_cleanup.current_prefix = "main__";
    typechecker.env_register_struct_linear_metadata(&env_dedup_cleanup, "main__DedupCleanupPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_dedup_cleanup, "main__DedupCleanupPayload", "main__close_dedup_cleanup_payload", ctx);
    typechecker.env_register_open_linear_resource(&env_dedup_cleanup, "main__dedup_cleanup_resource", "main__DedupCleanupPayload", ctx);

    if typechecker.env_report_linear_resource_missing_cleanup(&env_dedup_cleanup, "main__dedup_cleanup_resource", span_dedup_cleanup, ctx) != 1 {
        os.LogStr("Error: first missing-cleanup report should emit a diagnostic");
        os.Exit(1);
    }
    if len(env_dedup_cleanup.errors) != 1 {
        os.LogStr("Error: first missing-cleanup report should record exactly one diagnostic");
        os.Exit(1);
    }

    if typechecker.env_report_linear_resource_missing_cleanup(&env_dedup_cleanup, "main__dedup_cleanup_resource", span_dedup_cleanup, ctx) != 0 {
        os.LogStr("Error: duplicate missing-cleanup report should be suppressed");
        os.Exit(1);
    }
    if len(env_dedup_cleanup.errors) != 1 {
        os.LogStr("Error: duplicate missing-cleanup report should not append another diagnostic");
        os.Exit(1);
    }

    if typechecker.env_validate_linear_resource_scope_exit_cleanup(&env_dedup_cleanup, span_dedup_cleanup, ctx) != 0 {
        os.LogStr("Error: scope-exit cleanup validation should still reject pending cleanup");
        os.Exit(1);
    }
    if len(env_dedup_cleanup.errors) != 1 {
        os.LogStr("Error: scope-exit cleanup validation should reuse the existing pending cleanup diagnostic");
        os.Exit(1);
    }

    if std.str_find(env_dedup_cleanup.errors[0].message, "LinearResourceMissingCleanup") == 0 - 1 {
        os.LogStr("Error: dedup cleanup fixture emitted wrong diagnostic");
        os.LogStr(env_dedup_cleanup.errors[0].message);
        os.Exit(1);
    }
    if std.str_find(env_dedup_cleanup.errors[0].message, "main__dedup_cleanup_resource") == 0 - 1 {
        os.LogStr("Error: dedup cleanup fixture did not report the pending resource name");
        os.LogStr(env_dedup_cleanup.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource missing-cleanup dedup verified!");
}