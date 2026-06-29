import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut span_cleanup_boundary: token.Span;

    mut env_clean_boundary := typechecker.env_new(ctx);
    if typechecker.env_validate_linear_resource_cleanup_boundary(&env_clean_boundary, span_cleanup_boundary, ctx) != 1 {
        os.LogStr("Error: cleanup boundary helper must accept an environment without pending cleanup");
        os.Exit(1);
    }
    if len(env_clean_boundary.errors) != 0 {
        os.LogStr("Error: clean cleanup boundary helper recorded an unexpected error");
        os.Exit(1);
    }

    mut env_closed_boundary := typechecker.env_new(ctx);
    env_closed_boundary.current_prefix = "main__";
    typechecker.env_register_struct_linear_metadata(&env_closed_boundary, "main__ClosedBoundaryPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_closed_boundary, "main__ClosedBoundaryPayload", "main__close_closed_boundary_payload", ctx);
    typechecker.env_register_open_linear_resource(&env_closed_boundary, "main__closed_boundary_resource", "main__ClosedBoundaryPayload", ctx);
    typechecker.env_try_close_open_linear_resource(&env_closed_boundary, "main__closed_boundary_resource", ctx);
    if typechecker.env_validate_linear_resource_cleanup_boundary(&env_closed_boundary, span_cleanup_boundary, ctx) != 1 {
        os.LogStr("Error: cleanup boundary helper must accept terminal closed resources");
        os.Exit(1);
    }
    if len(env_closed_boundary.errors) != 0 {
        os.LogStr("Error: closed cleanup boundary helper recorded an unexpected error");
        os.Exit(1);
    }

    mut env_pending_boundary := typechecker.env_new(ctx);
    env_pending_boundary.current_prefix = "main__";
    typechecker.env_register_struct_linear_metadata(&env_pending_boundary, "main__PendingBoundaryPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_pending_boundary, "main__PendingBoundaryPayload", "main__close_pending_boundary_payload", ctx);
    typechecker.env_register_open_linear_resource(&env_pending_boundary, "main__pending_boundary_resource", "main__PendingBoundaryPayload", ctx);

    if typechecker.env_open_linear_resources_have_pending_cleanup(&env_pending_boundary, ctx) != 1 {
        os.LogStr("Error: pending cleanup boundary fixture must have pending cleanup");
        os.Exit(1);
    }
    if typechecker.env_validate_linear_resource_cleanup_boundary(&env_pending_boundary, span_cleanup_boundary, ctx) != 0 {
        os.LogStr("Error: cleanup boundary helper must reject pending cleanup");
        os.Exit(1);
    }
    if len(env_pending_boundary.errors) == 0 {
        os.LogStr("Error: cleanup boundary helper did not record pending cleanup error");
        os.Exit(1);
    }
    if std.str_find(env_pending_boundary.errors[0].message, "LinearResourceMissingCleanup") == 0 - 1 {
        os.LogStr("Error: cleanup boundary helper emitted wrong diagnostic");
        os.LogStr(env_pending_boundary.errors[0].message);
        os.Exit(1);
    }
    if std.str_find(env_pending_boundary.errors[0].message, "main__pending_boundary_resource") == 0 - 1 {
        os.LogStr("Error: cleanup boundary helper did not report the pending resource name");
        os.LogStr(env_pending_boundary.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource cleanup boundary validation helper verified!");
}