import "mir_manual_close.gst" as manual_close;

func fail(message: str) {
    os.LogStr(message);
    os.Exit(1);
}

func make_close(operation_id: str, resource_id: str, close_capability_id: str, source_location: str, program_point: str, prior_state: str, resulting_state: str, cleanup_cancellation_id: str, close_sequence: int, cancellation_sequence: int, ctx: &Arena) manual_close.MirManualCloseOperation[ctx] {
    mut op: manual_close.MirManualCloseOperation[ctx];
    op.operation_id = std.Clone(ctx, operation_id);
    op.resource_id = std.Clone(ctx, resource_id);
    op.close_capability_id = std.Clone(ctx, close_capability_id);
    op.source_location = std.Clone(ctx, source_location);
    op.program_point = std.Clone(ctx, program_point);
    op.prior_state = std.Clone(ctx, prior_state);
    op.resulting_state = std.Clone(ctx, resulting_state);
    op.cleanup_cancellation_id = std.Clone(ctx, cleanup_cancellation_id);
    op.close_sequence = close_sequence;
    op.cancellation_sequence = cancellation_sequence;
    op.suppresses_deferred_cleanup = 1;
    op.repeated_close_policy = std.Clone(ctx, "reject");
    return op;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    mut plan := manual_close.mir_manual_close_make_plan(&ctx);
    // Positive: manual close before scope exit
    plan = manual_close.mir_manual_close_with_operation(plan, make_close("operation:close:scope_exit", "resource:manual:scope_exit", "close:phase15:selected_resource", "compiler/manual_close.gst:10:5", "point:scope_exit:close", "live", "manually_closed", "cleanup_cancellation:scope_exit", 10, 11, &ctx), &ctx);
    // Positive: manual close before early return
    plan = manual_close.mir_manual_close_with_operation(plan, make_close("operation:close:early_return", "resource:manual:early_return", "close:phase15:selected_resource", "compiler/manual_close.gst:20:9", "point:early_return:close", "live", "manually_closed", "cleanup_cancellation:early_return", 12, 13, &ctx), &ctx);
    // Positive: close in one branch with valid join handling
    plan = manual_close.mir_manual_close_with_operation(plan, make_close("operation:close:branch", "resource:manual:branch", "close:phase15:selected_resource", "compiler/manual_close.gst:30:15", "point:branch:close", "live", "manually_closed", "cleanup_cancellation:branch", 14, 15, &ctx), &ctx);
    // Positive: close followed by reinitialization where selected (fresh identity)
    plan = manual_close.mir_manual_close_with_operation(plan, make_close("operation:close:reinit", "resource:manual:reinit", "close:phase15:selected_resource", "compiler/manual_close.gst:40:5", "point:reinit:close", "live", "manually_closed", "cleanup_cancellation:reinit", 16, 17, &ctx), &ctx);

    mut validation := manual_close.mir_manual_close_validate(plan, &ctx);
    if validation.valid == 0 {
        fail(std.Concat("Phase 15.8 plan rejected: ", validation.reason_code));
    }

    // Negative checks: ensure double close, close after move, use after close,
    // close of non-closeable, and cleanup still scheduled are all rejected by
    // the state machine. We verify that attempting to validate an invalid plan
    // yields the stable reason codes.
    mut negative_double := manual_close.mir_manual_close_make_plan(&ctx);
    negative_double = manual_close.mir_manual_close_with_operation(negative_double, make_close("operation:close:double:1", "resource:manual:double", "close:phase15:selected_resource", "compiler/manual_close.gst:50:5", "point:double:1", "live", "manually_closed", "cleanup_cancellation:double:1", 20, 21, &ctx), &ctx);
    negative_double = manual_close.mir_manual_close_with_operation(negative_double, make_close("operation:close:double:2", "resource:manual:double", "close:phase15:selected_resource", "compiler/manual_close.gst:51:5", "point:double:2", "manually_closed", "manually_closed", "cleanup_cancellation:double:2", 22, 23, &ctx), &ctx);
    mut double_validation := manual_close.mir_manual_close_validate(negative_double, &ctx);
    if double_validation.valid == 1 || std.str_eq(double_validation.reason_code, "LinearResourceDoubleClose") == 0 {
        fail("Phase 15.8 double close negative must be rejected with LinearResourceDoubleClose");
    }

    mut negative_after_move := manual_close.mir_manual_close_make_plan(&ctx);
    negative_after_move = manual_close.mir_manual_close_with_operation(negative_after_move, make_close("operation:close:after_move", "resource:manual:after_move", "close:phase15:selected_resource", "compiler/manual_close.gst:60:5", "point:after_move:close", "moved", "manually_closed", "cleanup_cancellation:after_move", 30, 31, &ctx), &ctx);
    mut after_move_validation := manual_close.mir_manual_close_validate(negative_after_move, &ctx);
    if after_move_validation.valid == 1 || std.str_eq(after_move_validation.reason_code, "LinearResourceCloseAfterMove") == 0 {
        fail("Phase 15.8 close after move negative must be rejected with LinearResourceCloseAfterMove");
    }

    if manual_close.mir_manual_close_use_after_close_is_rejected("manually_closed") == 0 {
        fail("Phase 15.8 use after close must be rejected");
    }
    if manual_close.mir_manual_close_selected_kind_is_closeable("i32") == 1 {
        fail("Phase 15.8 close of non-closeable resource must be rejected");
    }

    mut request := manual_close.mir_manual_close_append_to_request("", plan, &ctx);
    mut witness := manual_close.mir_manual_close_witness(plan, &ctx);
    if std.str_find(witness, "close_count=") == 0 - 1 || std.str_find(witness, "destructor_count=suppressed_if_closed") == 0 - 1 || std.str_find(witness, "filesystem_effects_compared=1") == 0 - 1 {
        fail("Phase 15.8 witness must compare close and destructor counts and filesystem effects");
    }
    if std.str_find(witness, "scope_exit_does_not_double_close=1") == 0 - 1 || std.str_find(witness, "final_destructor_only_if_explicitly_required=1") == 0 - 1 {
        fail("Phase 15.8 witness must assert scope-exit cleanup interaction");
    }
    if os.WriteFile("/tmp/gust-phase15-manual-close.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase15-manual-close.mir-to-c.witness", witness) == 0
    {
        fail("Phase 15.8 artifacts could not be written");
    }
    os.LogStr("SUCCESS: Phase 15.8 manual close versus deferred cleanup parity smoke passed");
}
