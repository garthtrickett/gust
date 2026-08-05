import "mir_resource_reassignment.gst" as reassignment;

func expect_transition(policy: str, mutable_storage: int, old_prior: str, old_result: str, replacement_prior: str, replacement_result: str, replacement_source: str, destructor_id: str, transfer_destination: str, order: int, expected_valid: int, expected_reason: str, ctx: &Arena) {
    mut validation := reassignment.mir_validate_resource_reassignment_transition(
        policy,
        mutable_storage,
        old_prior,
        old_result,
        replacement_prior,
        replacement_result,
        replacement_source,
        destructor_id,
        transfer_destination,
        order,
        ctx
    );
    if validation.valid != expected_valid || std.str_eq(validation.reason_code, expected_reason) == 0 {
        os.LogStr("Phase 15.4 reassignment transition mismatch");
        os.LogStr(validation.reason_code);
        os.Exit(1);
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    expect_transition("immediate_destroy", 1, "live", "destroyed", "uninitialized", "live", "fresh_initialize", "destructor:phase15:reassignment", "", 1, 1, "resource_reassignment_transition_valid", ctx);
    expect_transition("scheduled_cleanup", 1, "live", "cleanup_scheduled", "uninitialized", "live", "move", "destructor:phase15:reassignment", "", 2, 1, "resource_reassignment_transition_valid", ctx);
    expect_transition("transfer_before_replacement", 1, "live", "moved", "uninitialized", "live", "fresh_initialize", "", "carrier:transfer", 0, 1, "resource_reassignment_transition_valid", ctx);

    expect_transition("silent_replace", 1, "live", "destroyed", "uninitialized", "live", "fresh_initialize", "destructor:phase15:reassignment", "", 1, 0, "resource_reassignment_old_live_unresolved", ctx);
    expect_transition("immediate_destroy", 0, "live", "destroyed", "uninitialized", "live", "fresh_initialize", "destructor:phase15:reassignment", "", 1, 0, "resource_reassignment_immutable_storage", ctx);
    expect_transition("immediate_destroy", 1, "destroyed", "destroyed", "uninitialized", "live", "fresh_initialize", "destructor:phase15:reassignment", "", 1, 0, "resource_reassignment_after_destroy_without_reinitialization", ctx);
    expect_transition("immediate_destroy", 1, "live", "destroyed", "uninitialized", "live", "copy", "destructor:phase15:reassignment", "", 1, 0, "resource_reassignment_copy_move_only", ctx);
    expect_transition("immediate_destroy", 1, "live", "destroyed", "uninitialized", "moved", "fresh_initialize", "destructor:phase15:reassignment", "", 1, 0, "resource_reassignment_replacement_state_invalid", ctx);
    expect_transition("immediate_destroy", 1, "live", "destroyed", "uninitialized", "live", "fresh_initialize", "", "", 1, 0, "resource_reassignment_old_destroy_resolution_invalid", ctx);
    expect_transition("immediate_destroy", 1, "live", "destroyed", "uninitialized", "live", "fresh_initialize", "destructor:phase15:reassignment", "", 0, 0, "resource_reassignment_destruction_order_invalid", ctx);
    expect_transition("scheduled_cleanup", 1, "live", "destroyed", "uninitialized", "live", "fresh_initialize", "destructor:phase15:reassignment", "", 1, 0, "resource_reassignment_old_schedule_resolution_invalid", ctx);
    expect_transition("transfer_before_replacement", 1, "live", "moved", "uninitialized", "live", "fresh_initialize", "", "", 0, 0, "resource_reassignment_transfer_resolution_invalid", ctx);

    os.LogStr("SUCCESS: Phase 15.4 resource reassignment transitions passed");
}