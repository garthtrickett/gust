import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut span_mixed_boundary: token.Span;

    mut env_mixed_boundary := typechecker.env_new(ctx);
    env_mixed_boundary.current_prefix = "main__";

    typechecker.env_register_struct_linear_metadata(&env_mixed_boundary, "main__ClosedMixedPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_mixed_boundary, "main__ClosedMixedPayload", "main__close_closed_mixed_payload", ctx);
    typechecker.env_register_open_linear_resource(&env_mixed_boundary, "main__closed_mixed_resource", "main__ClosedMixedPayload", ctx);
    if typechecker.env_try_close_open_linear_resource(&env_mixed_boundary, "main__closed_mixed_resource", ctx) != 1 {
        os.LogStr("Error: mixed cleanup boundary fixture failed to close resource");
        os.Exit(1);
    }

    typechecker.env_register_struct_linear_metadata(&env_mixed_boundary, "main__MovedMixedPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_mixed_boundary, "main__MovedMixedPayload", "main__close_moved_mixed_payload", ctx);
    typechecker.env_register_open_linear_resource(&env_mixed_boundary, "main__moved_mixed_resource", "main__MovedMixedPayload", ctx);
    if typechecker.env_try_move_open_linear_resource(&env_mixed_boundary, "main__moved_mixed_resource", ctx) != 1 {
        os.LogStr("Error: mixed cleanup boundary fixture failed to move resource");
        os.Exit(1);
    }

    typechecker.env_register_struct_linear_metadata(&env_mixed_boundary, "main__ScheduledMixedPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_mixed_boundary, "main__ScheduledMixedPayload", "main__close_scheduled_mixed_payload", ctx);
    typechecker.env_register_open_linear_resource(&env_mixed_boundary, "main__scheduled_mixed_resource", "main__ScheduledMixedPayload", ctx);
    if typechecker.env_try_schedule_open_linear_resource_destructor(&env_mixed_boundary, "main__scheduled_mixed_resource", ctx) != 1 {
        os.LogStr("Error: mixed cleanup boundary fixture failed to schedule resource destructor");
        os.Exit(1);
    }

    typechecker.env_register_struct_linear_metadata(&env_mixed_boundary, "main__PendingMixedPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_mixed_boundary, "main__PendingMixedPayload", "main__close_pending_mixed_payload", ctx);
    typechecker.env_register_open_linear_resource(&env_mixed_boundary, "main__pending_mixed_resource", "main__PendingMixedPayload", ctx);

    if typechecker.env_validate_linear_resource_cleanup_boundary(&env_mixed_boundary, span_mixed_boundary, ctx) != 0 {
        os.LogStr("Error: mixed cleanup boundary helper must reject pending cleanup among terminal resources");
        os.Exit(1);
    }
    if len(env_mixed_boundary.errors) != 1 {
        os.LogStr("Error: mixed cleanup boundary helper should record exactly one pending cleanup error");
        os.Exit(1);
    }
    if std.str_find(env_mixed_boundary.errors[0].message, "LinearResourceMissingCleanup") == 0 - 1 {
        os.LogStr("Error: mixed cleanup boundary helper emitted wrong diagnostic");
        os.LogStr(env_mixed_boundary.errors[0].message);
        os.Exit(1);
    }
    if std.str_find(env_mixed_boundary.errors[0].message, "main__pending_mixed_resource") == 0 - 1 {
        os.LogStr("Error: mixed cleanup boundary helper did not report the pending resource name");
        os.LogStr(env_mixed_boundary.errors[0].message);
        os.Exit(1);
    }
    if std.str_find(env_mixed_boundary.errors[0].message, "main__closed_mixed_resource") != 0 - 1 {
        os.LogStr("Error: mixed cleanup boundary helper must ignore closed terminal resources");
        os.LogStr(env_mixed_boundary.errors[0].message);
        os.Exit(1);
    }
    if std.str_find(env_mixed_boundary.errors[0].message, "main__moved_mixed_resource") != 0 - 1 {
        os.LogStr("Error: mixed cleanup boundary helper must ignore moved terminal resources");
        os.LogStr(env_mixed_boundary.errors[0].message);
        os.Exit(1);
    }
    if std.str_find(env_mixed_boundary.errors[0].message, "main__scheduled_mixed_resource") != 0 - 1 {
        os.LogStr("Error: mixed cleanup boundary helper must ignore destructor-scheduled terminal resources");
        os.LogStr(env_mixed_boundary.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource cleanup boundary mixed-state coverage verified!");
}