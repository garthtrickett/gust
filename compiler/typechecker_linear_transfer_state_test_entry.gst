import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_transfer_meta := typechecker.env_new(ctx);

    typechecker.env_register_struct_linear_metadata(&env_transfer_meta, "main__TransferStateResource", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_transfer_meta, "main__TransferStateResource", "close_transfer_state_resource", ctx);

    mut owned_registered_transfer_meta := typechecker.env_register_open_linear_resource(&env_transfer_meta, "owned_transfer_resource", "main__TransferStateResource", ctx);
    if owned_registered_transfer_meta != 1 {
        os.LogStr("Error: owned transfer-state resource did not enter open_linear_resources registry");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_owned(&env_transfer_meta, "owned_transfer_resource", ctx) != 1 {
        os.LogStr("Error: newly registered resource must start in owned transfer state");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_borrowed(&env_transfer_meta, "owned_transfer_resource", ctx) != 0 {
        os.LogStr("Error: newly registered resource must not start borrowed");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_transfer_meta, "owned_transfer_resource", ctx) != 0 {
        os.LogStr("Error: newly registered resource must not start destructor-scheduled");
        os.Exit(1);
    }

    if typechecker.env_mark_open_linear_resource_borrowed(&env_transfer_meta, "owned_transfer_resource", ctx) != 1 {
        os.LogStr("Error: borrowing tracked linear resource failed");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_owned(&env_transfer_meta, "owned_transfer_resource", ctx) != 0 {
        os.LogStr("Error: borrowed resource must no longer report owned state");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_open(&env_transfer_meta, "owned_transfer_resource", ctx) != 1 {
        os.LogStr("Error: borrowed resource should remain open in inert transfer-state metadata");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_borrowed(&env_transfer_meta, "owned_transfer_resource", ctx) != 1 {
        os.LogStr("Error: borrowed resource state was not recorded");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_closed(&env_transfer_meta, "owned_transfer_resource", ctx) != 0 {
        os.LogStr("Error: borrowed resource must not also be marked closed");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_moved(&env_transfer_meta, "owned_transfer_resource", ctx) != 0 {
        os.LogStr("Error: borrowed resource must not also be marked moved");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_transfer_meta, "owned_transfer_resource", ctx) != 0 {
        os.LogStr("Error: borrowed resource must not also be destructor-scheduled");
        os.Exit(1);
    }

    mut scheduled_registered_transfer_meta := typechecker.env_register_open_linear_resource(&env_transfer_meta, "scheduled_transfer_resource", "main__TransferStateResource", ctx);
    if scheduled_registered_transfer_meta != 1 {
        os.LogStr("Error: scheduled transfer-state resource did not enter open_linear_resources registry");
        os.Exit(1);
    }
    if typechecker.env_mark_open_linear_resource_destructor_scheduled(&env_transfer_meta, "scheduled_transfer_resource", ctx) != 1 {
        os.LogStr("Error: scheduling destructor for tracked linear resource failed");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_open(&env_transfer_meta, "scheduled_transfer_resource", ctx) != 0 {
        os.LogStr("Error: destructor-scheduled resource must no longer report open state");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_transfer_meta, "scheduled_transfer_resource", ctx) != 1 {
        os.LogStr("Error: destructor-scheduled resource state was not recorded");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_owned(&env_transfer_meta, "scheduled_transfer_resource", ctx) != 0 {
        os.LogStr("Error: destructor-scheduled resource must not report owned state");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_borrowed(&env_transfer_meta, "scheduled_transfer_resource", ctx) != 0 {
        os.LogStr("Error: destructor-scheduled resource must not also be borrowed");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_closed(&env_transfer_meta, "scheduled_transfer_resource", ctx) != 0 {
        os.LogStr("Error: destructor-scheduled resource must not also be closed");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_moved(&env_transfer_meta, "scheduled_transfer_resource", ctx) != 0 {
        os.LogStr("Error: destructor-scheduled resource must not also be moved");
        os.Exit(1);
    }

    mut moved_registered_transfer_meta := typechecker.env_register_open_linear_resource(&env_transfer_meta, "moved_transfer_resource", "main__TransferStateResource", ctx);
    if moved_registered_transfer_meta != 1 {
        os.LogStr("Error: moved transfer-state resource did not enter open_linear_resources registry");
        os.Exit(1);
    }
    if typechecker.env_mark_open_linear_resource_moved(&env_transfer_meta, "moved_transfer_resource", ctx) != 1 {
        os.LogStr("Error: moving tracked linear resource failed in transfer-state fixture");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_moved(&env_transfer_meta, "moved_transfer_resource", ctx) != 1 {
        os.LogStr("Error: moved transfer-state resource state was not recorded");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_borrowed(&env_transfer_meta, "moved_transfer_resource", ctx) != 0 {
        os.LogStr("Error: moved resource must not also be borrowed");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_transfer_meta, "moved_transfer_resource", ctx) != 0 {
        os.LogStr("Error: moved resource must not also be destructor-scheduled");
        os.Exit(1);
    }

    if typechecker.env_mark_open_linear_resource_borrowed(&env_transfer_meta, "missing_transfer_resource", ctx) != 0 {
        os.LogStr("Error: borrowing missing linear resource must be a no-op failure");
        os.Exit(1);
    }
    if typechecker.env_mark_open_linear_resource_destructor_scheduled(&env_transfer_meta, "missing_transfer_resource", ctx) != 0 {
        os.LogStr("Error: scheduling destructor for missing linear resource must be a no-op failure");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_owned(&env_transfer_meta, "missing_transfer_resource", ctx) != 0 {
        os.LogStr("Error: missing linear resource must not report owned state");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_borrowed(&env_transfer_meta, "missing_transfer_resource", ctx) != 0 {
        os.LogStr("Error: missing linear resource must not report borrowed state");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_transfer_meta, "missing_transfer_resource", ctx) != 0 {
        os.LogStr("Error: missing linear resource must not report destructor-scheduled state");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert linear transfer-state metadata verified!");
}