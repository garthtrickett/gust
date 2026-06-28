import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_lifecycle_ops := typechecker.env_new(ctx);

    typechecker.env_register_struct_linear_metadata(&env_lifecycle_ops, "main__LifecyclePayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_lifecycle_ops, "main__LifecyclePayload", "close_lifecycle_payload", ctx);
    typechecker.env_register_struct_linear_metadata(&env_lifecycle_ops, "main__LifecycleNoDestructorPayload", 1, ctx);

    typechecker.env_register_open_linear_resource(&env_lifecycle_ops, "close_ops_resource", "main__LifecyclePayload", ctx);
    if typechecker.env_try_close_open_linear_resource(&env_lifecycle_ops, "close_ops_resource", ctx) != 1 {
        os.LogStr("Error: lifecycle close helper did not close owned resource");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_closed(&env_lifecycle_ops, "close_ops_resource", ctx) != 1 {
        os.LogStr("Error: lifecycle close helper did not set closed state");
        os.Exit(1);
    }
    if typechecker.env_try_close_open_linear_resource(&env_lifecycle_ops, "close_ops_resource", ctx) != 0 {
        os.LogStr("Error: lifecycle close helper allowed double close");
        os.Exit(1);
    }
    if typechecker.env_try_move_open_linear_resource(&env_lifecycle_ops, "close_ops_resource", ctx) != 0 {
        os.LogStr("Error: lifecycle move helper allowed moving closed resource");
        os.Exit(1);
    }

    typechecker.env_register_open_linear_resource(&env_lifecycle_ops, "move_ops_resource", "main__LifecyclePayload", ctx);
    if typechecker.env_try_move_open_linear_resource(&env_lifecycle_ops, "move_ops_resource", ctx) != 1 {
        os.LogStr("Error: lifecycle move helper did not move owned resource");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_moved(&env_lifecycle_ops, "move_ops_resource", ctx) != 1 {
        os.LogStr("Error: lifecycle move helper did not set moved state");
        os.Exit(1);
    }
    if typechecker.env_try_move_open_linear_resource(&env_lifecycle_ops, "move_ops_resource", ctx) != 0 {
        os.LogStr("Error: lifecycle move helper allowed double move");
        os.Exit(1);
    }
    if typechecker.env_try_close_open_linear_resource(&env_lifecycle_ops, "move_ops_resource", ctx) != 0 {
        os.LogStr("Error: lifecycle close helper allowed closing moved resource");
        os.Exit(1);
    }

    typechecker.env_register_open_linear_resource(&env_lifecycle_ops, "borrow_ops_resource", "main__LifecyclePayload", ctx);
    if typechecker.env_try_borrow_open_linear_resource(&env_lifecycle_ops, "borrow_ops_resource", ctx) != 1 {
        os.LogStr("Error: lifecycle borrow helper did not borrow owned resource");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_borrowed(&env_lifecycle_ops, "borrow_ops_resource", ctx) != 1 {
        os.LogStr("Error: lifecycle borrow helper did not set borrowed state");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_can_be_used(&env_lifecycle_ops, "borrow_ops_resource", ctx) != 1 {
        os.LogStr("Error: borrowed resource should remain usable through validation predicate");
        os.Exit(1);
    }
    if typechecker.env_try_close_open_linear_resource(&env_lifecycle_ops, "borrow_ops_resource", ctx) != 0 {
        os.LogStr("Error: lifecycle close helper allowed owner-only close on borrowed resource");
        os.Exit(1);
    }
    if typechecker.env_try_move_open_linear_resource(&env_lifecycle_ops, "borrow_ops_resource", ctx) != 0 {
        os.LogStr("Error: lifecycle move helper allowed owner-only move on borrowed resource");
        os.Exit(1);
    }
    if typechecker.env_try_schedule_open_linear_resource_destructor(&env_lifecycle_ops, "borrow_ops_resource", ctx) != 0 {
        os.LogStr("Error: lifecycle destructor helper allowed owner-only schedule on borrowed resource");
        os.Exit(1);
    }

    typechecker.env_register_open_linear_resource(&env_lifecycle_ops, "scheduled_ops_resource", "main__LifecyclePayload", ctx);
    if typechecker.env_try_schedule_open_linear_resource_destructor(&env_lifecycle_ops, "scheduled_ops_resource", ctx) != 1 {
        os.LogStr("Error: lifecycle destructor helper did not schedule owned resource");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_lifecycle_ops, "scheduled_ops_resource", ctx) != 1 {
        os.LogStr("Error: lifecycle destructor helper did not set scheduled state");
        os.Exit(1);
    }
    if typechecker.env_try_schedule_open_linear_resource_destructor(&env_lifecycle_ops, "scheduled_ops_resource", ctx) != 0 {
        os.LogStr("Error: lifecycle destructor helper allowed double schedule");
        os.Exit(1);
    }
    if typechecker.env_try_close_open_linear_resource(&env_lifecycle_ops, "scheduled_ops_resource", ctx) != 0 {
        os.LogStr("Error: lifecycle close helper allowed closing destructor-scheduled resource");
        os.Exit(1);
    }

    typechecker.env_register_open_linear_resource(&env_lifecycle_ops, "no_destructor_ops_resource", "main__LifecycleNoDestructorPayload", ctx);
    if typechecker.env_try_schedule_open_linear_resource_destructor(&env_lifecycle_ops, "no_destructor_ops_resource", ctx) != 0 {
        os.LogStr("Error: lifecycle destructor helper allowed scheduling resource without destructor");
        os.Exit(1);
    }
    if typechecker.env_try_close_open_linear_resource(&env_lifecycle_ops, "no_destructor_ops_resource", ctx) != 1 {
        os.LogStr("Error: lifecycle close helper should still close owned resource without destructor identity");
        os.Exit(1);
    }

    if typechecker.env_try_close_open_linear_resource(&env_lifecycle_ops, "missing_ops_resource", ctx) != 0 {
        os.LogStr("Error: lifecycle close helper allowed missing resource");
        os.Exit(1);
    }
    if typechecker.env_try_move_open_linear_resource(&env_lifecycle_ops, "missing_ops_resource", ctx) != 0 {
        os.LogStr("Error: lifecycle move helper allowed missing resource");
        os.Exit(1);
    }
    if typechecker.env_try_borrow_open_linear_resource(&env_lifecycle_ops, "missing_ops_resource", ctx) != 0 {
        os.LogStr("Error: lifecycle borrow helper allowed missing resource");
        os.Exit(1);
    }
    if typechecker.env_try_schedule_open_linear_resource_destructor(&env_lifecycle_ops, "missing_ops_resource", ctx) != 0 {
        os.LogStr("Error: lifecycle destructor helper allowed missing resource");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert linear resource lifecycle operation helpers verified!");
}