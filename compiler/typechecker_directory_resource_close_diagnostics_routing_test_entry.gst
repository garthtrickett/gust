import "token.gst" as token;
import "typechecker.gst" as typechecker;

func env_has_error_containing(env: *typechecker.TypeEnvironment[ctx], needle: str, ctx: &Arena) int {
    unsafe {
        mut i := 0;
        while i < len((*env).errors) {
            mut msg := (*env).errors[i].message;
            if std.str_find(msg, needle) != 0 - 1 {
                return 1;
            }
            i = i + 1;
        }
        return 0;
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut span_close_route: token.Span;

    mut env_double_close_route := typechecker.env_new(ctx);
    env_double_close_route.current_prefix = "main__";
    typechecker.env_register_struct_linear_metadata(&env_double_close_route, "CloseRoutePayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_double_close_route, "CloseRoutePayload", "close_close_route_payload", ctx);
    typechecker.env_register_open_linear_resource(&env_double_close_route, "double_close_route", "CloseRoutePayload", ctx);

    if typechecker.env_open_linear_resource_can_be_closed(&env_double_close_route, "double_close_route", ctx) != 1 {
        os.LogStr("Error: owned Resource should allow close transition through shared helper");
        os.Exit(1);
    }
    if typechecker.env_try_close_open_linear_resource(&env_double_close_route, "double_close_route", ctx) != 1 {
        os.LogStr("Error: initial close should route through shared close transition helper");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_can_be_closed(&env_double_close_route, "double_close_route", ctx) != 0 {
        os.LogStr("Error: closed Resource should reject close transition through shared helper");
        os.Exit(1);
    }
    if typechecker.env_report_linear_resource_close_transition_rejected(&env_double_close_route, "double_close_route", span_close_route, ctx) != 1 {
        os.LogStr("Error: close transition helper should report rejected closed Resource close");
        os.Exit(1);
    }
    if env_has_error_containing(&env_double_close_route, "LinearResourceDoubleClose", ctx) != 1 {
        os.LogStr("Error: close transition helper should preserve LinearResourceDoubleClose diagnostic");
        os.Exit(1);
    }

    mut env_close_after_move_route := typechecker.env_new(ctx);
    env_close_after_move_route.current_prefix = "main__";
    typechecker.env_register_struct_linear_metadata(&env_close_after_move_route, "MoveCloseRoutePayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_close_after_move_route, "MoveCloseRoutePayload", "close_move_close_route_payload", ctx);
    typechecker.env_register_open_linear_resource(&env_close_after_move_route, "move_close_route", "MoveCloseRoutePayload", ctx);
    typechecker.env_try_move_open_linear_resource(&env_close_after_move_route, "move_close_route", ctx);

    if typechecker.env_open_linear_resource_can_be_closed(&env_close_after_move_route, "move_close_route", ctx) != 0 {
        os.LogStr("Error: moved Resource should reject close transition through shared helper");
        os.Exit(1);
    }
    if typechecker.env_report_linear_resource_close_transition_rejected(&env_close_after_move_route, "move_close_route", span_close_route, ctx) != 1 {
        os.LogStr("Error: close transition helper should report rejected moved Resource close");
        os.Exit(1);
    }
    if env_has_error_containing(&env_close_after_move_route, "LinearResourceCloseAfterMove", ctx) != 1 {
        os.LogStr("Error: close transition helper should preserve LinearResourceCloseAfterMove diagnostic");
        os.Exit(1);
    }

    mut env_scheduled_close_route := typechecker.env_new(ctx);
    env_scheduled_close_route.current_prefix = "main__";
    typechecker.env_register_struct_linear_metadata(&env_scheduled_close_route, "ScheduledCloseRoutePayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_scheduled_close_route, "ScheduledCloseRoutePayload", "close_scheduled_close_route_payload", ctx);
    typechecker.env_register_open_linear_resource(&env_scheduled_close_route, "scheduled_close_route", "ScheduledCloseRoutePayload", ctx);
    typechecker.env_try_schedule_open_linear_resource_destructor(&env_scheduled_close_route, "scheduled_close_route", ctx);

    if typechecker.env_open_linear_resource_can_be_closed(&env_scheduled_close_route, "scheduled_close_route", ctx) != 0 {
        os.LogStr("Error: destructor-scheduled Resource should reject close transition through shared helper");
        os.Exit(1);
    }
    if typechecker.env_report_linear_resource_close_transition_rejected(&env_scheduled_close_route, "scheduled_close_route", span_close_route, ctx) != 1 {
        os.LogStr("Error: close transition helper should report rejected scheduled Resource close");
        os.Exit(1);
    }
    if env_has_error_containing(&env_scheduled_close_route, "LinearResourceDestructorAlreadyScheduled", ctx) != 1 {
        os.LogStr("Error: close transition helper should preserve LinearResourceDestructorAlreadyScheduled diagnostic");
        os.Exit(1);
    }

    mut env_directory_close_route := typechecker.env_new(ctx);
    env_directory_close_route.current_prefix = "main__";
    typechecker.env_shadow_track_open_directory_resource(&env_directory_close_route, "directory_close_route", "os_Dir_ctx", ctx);
    if typechecker.env_open_linear_resource_can_be_closed(&env_directory_close_route, "directory_close_route", ctx) != 1 {
        os.LogStr("Error: directory shadow close should allow shared Resource close transition before CloseDir");
        os.Exit(1);
    }
    if typechecker.env_shadow_track_closed_directory_resource(&env_directory_close_route, "directory_close_route", ctx) != 1 {
        os.LogStr("Error: directory close shadow helper should route successful close through shared transfer helper");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_can_be_closed(&env_directory_close_route, "directory_close_route", ctx) != 0 {
        os.LogStr("Error: directory shadow close should reject shared Resource close transition after CloseDir");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: directory Resource close diagnostics route through shared transfer-state helpers!");
}