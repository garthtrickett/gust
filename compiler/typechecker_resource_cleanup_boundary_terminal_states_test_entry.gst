import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut span_terminal_boundary: token.Span;

    mut env_moved_boundary := typechecker.env_new(ctx);
    env_moved_boundary.current_prefix = "main__";
    typechecker.env_register_struct_linear_metadata(&env_moved_boundary, "main__MovedBoundaryPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_moved_boundary, "main__MovedBoundaryPayload", "main__close_moved_boundary_payload", ctx);
    typechecker.env_register_open_linear_resource(&env_moved_boundary, "main__moved_boundary_resource", "main__MovedBoundaryPayload", ctx);
    if typechecker.env_try_move_open_linear_resource(&env_moved_boundary, "main__moved_boundary_resource", ctx) != 1 {
        os.LogStr("Error: cleanup boundary terminal-state fixture failed to move resource");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_moved(&env_moved_boundary, "main__moved_boundary_resource", ctx) != 1 {
        os.LogStr("Error: cleanup boundary terminal-state fixture must start moved");
        os.Exit(1);
    }
    if typechecker.env_validate_linear_resource_cleanup_boundary(&env_moved_boundary, span_terminal_boundary, ctx) != 1 {
        os.LogStr("Error: cleanup boundary helper must accept moved terminal resources");
        os.Exit(1);
    }
    if len(env_moved_boundary.errors) != 0 {
        os.LogStr("Error: moved terminal cleanup boundary helper recorded an unexpected error");
        os.Exit(1);
    }

    mut env_scheduled_boundary := typechecker.env_new(ctx);
    env_scheduled_boundary.current_prefix = "main__";
    typechecker.env_register_struct_linear_metadata(&env_scheduled_boundary, "main__ScheduledBoundaryPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_scheduled_boundary, "main__ScheduledBoundaryPayload", "main__close_scheduled_boundary_payload", ctx);
    typechecker.env_register_open_linear_resource(&env_scheduled_boundary, "main__scheduled_boundary_resource", "main__ScheduledBoundaryPayload", ctx);
    if typechecker.env_try_schedule_open_linear_resource_destructor(&env_scheduled_boundary, "main__scheduled_boundary_resource", ctx) != 1 {
        os.LogStr("Error: cleanup boundary terminal-state fixture failed to schedule destructor");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_scheduled_boundary, "main__scheduled_boundary_resource", ctx) != 1 {
        os.LogStr("Error: cleanup boundary terminal-state fixture must start destructor-scheduled");
        os.Exit(1);
    }
    if typechecker.env_validate_linear_resource_cleanup_boundary(&env_scheduled_boundary, span_terminal_boundary, ctx) != 1 {
        os.LogStr("Error: cleanup boundary helper must accept destructor-scheduled terminal resources");
        os.Exit(1);
    }
    if len(env_scheduled_boundary.errors) != 0 {
        os.LogStr("Error: destructor-scheduled terminal cleanup boundary helper recorded an unexpected error");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource cleanup boundary terminal-state coverage verified!");
}