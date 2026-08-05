import "mir_resource_authority.gst" as authority;
import "mir_resource_value.gst" as resource_mir;

func fail(message: str) {
    os.LogStr(message);
    os.Exit(1);
}

func expect_transition(prior_state: str, operation: str, expected_valid: int, expected_result: str, expected_reason: str, ctx: &Arena) {
    mut validation := authority.mir_validate_resource_transition_from_state(
        "resource:v1:phase15.3:smoke",
        prior_state,
        operation,
        ctx
    );
    if validation.valid != expected_valid ||
       std.str_eq(validation.resulting_state, expected_result) == 0 ||
       std.str_eq(validation.reason_code, expected_reason) == 0
    {
        fail(std.Concat("Phase 15.3 transition mismatch: ", operation));
    }
}

func make_carrier_kind(tag: int) resource_mir.MirResourceCarrierKind {
    mut kind: resource_mir.MirResourceCarrierKind;
    unsafe { kind.tag = tag; }
    return kind;
}

func expect_move_form(source_tag: int, destination_tag: int, expected: str) {
    mut source_kind := make_carrier_kind(source_tag);
    mut destination_kind := make_carrier_kind(destination_tag);
    mut actual := resource_mir.mir_resource_move_form_name(source_kind, destination_kind);
    if std.str_eq(actual, expected) == 0 {
        fail(std.Concat("Phase 15.3 move form mismatch: ", expected));
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    expect_transition("live", "move", 1, "moved", "resource_transition_valid", ctx);
    expect_transition("moved", "initialize", 0, "", "resource_reinitialize_requires_fresh_identity", ctx);
    mut reinitialization := authority.mir_validate_resource_reinitialization(
        "resource:v1:phase15.3:moved",
        "resource:v1:phase15.3:fresh",
        "moved",
        ctx
    );
    if reinitialization.valid != 1 ||
       std.str_eq(reinitialization.resulting_state, "live") == 0 ||
       std.str_eq(reinitialization.reason_code, "resource_reinitialization_valid") == 0
    {
        fail("Phase 15.3 fresh-identity reinitialization was rejected");
    }
    mut same_identity_reinitialization := authority.mir_validate_resource_reinitialization(
        "resource:v1:phase15.3:moved",
        "resource:v1:phase15.3:moved",
        "moved",
        ctx
    );
    if same_identity_reinitialization.valid != 0 ||
       std.str_eq(same_identity_reinitialization.reason_code, "resource_reinitialize_requires_fresh_identity") == 0
    {
        fail("Phase 15.3 same-identity reinitialization was accepted");
    }
    expect_transition("live", "manual_close", 1, "manually_closed", "resource_transition_valid", ctx);
    expect_transition("manually_closed", "mark_destroyed", 1, "destroyed", "resource_transition_valid", ctx);
    expect_transition("cleanup_scheduled", "invoke_destructor", 1, "destroyed", "resource_transition_valid", ctx);

    expect_transition("moved", "use", 0, "", "resource_use_after_move", ctx);
    expect_transition("moved", "manual_close", 0, "", "resource_close_after_move", ctx);
    expect_transition("moved", "move", 0, "", "resource_second_move", ctx);
    expect_transition("moved", "schedule_cleanup", 0, "", "resource_cleanup_after_move", ctx);
    expect_transition("moved", "invoke_destructor", 0, "", "resource_destructor_after_move", ctx);
    expect_transition("uninitialized", "move", 0, "", "resource_move_from_uninitialized", ctx);
    expect_transition("live", "copy", 0, "", "resource_copy_of_move_only", ctx);

    expect_move_form(0, 0, "local_to_local");
    expect_move_form(0, 4, "local_to_aggregate_field");
    expect_move_form(4, 0, "aggregate_field_to_local");
    expect_move_form(0, 2, "branch_edge_move");
    expect_move_form(2, 0, "branch_edge_move");
    expect_move_form(0, 3, "selected_loop_carried_move");
    expect_move_form(3, 0, "selected_loop_carried_move");

    mut incoming_states := authority.mir_resource_empty_str_vector(ctx);
    incoming_states = authority.mir_resource_push_str(incoming_states, "live", ctx);
    incoming_states = authority.mir_resource_push_str(incoming_states, "moved", ctx);
    mut join_result := authority.mir_join_resource_states(incoming_states, ctx);
    if join_result.valid != 0 ||
       std.str_eq(join_result.reason_code, "resource_move_join_state_inconsistent") == 0
    {
        fail("Phase 15.3 inconsistent move join was not rejected");
    }

    mut diagnostic := resource_mir.mir_resource_move_diagnostic(
        "resource:v1:phase15.3:diagnostic",
        "compiler/p15_move_source.gst:4:5",
        "compiler/p15_move_source.gst:8:5",
        "compiler/p15_move_source.gst:12:5",
        "moved",
        "use",
        "resource_use_after_move",
        ctx
    );
    mut diagnostic_validation := resource_mir.mir_resource_move_validation(0, "", diagnostic, ctx);
    mut diagnostic_text := resource_mir.mir_resource_move_diagnostic_text(diagnostic_validation, ctx);
    if std.str_find(diagnostic_text, "resource_use_after_move") == 0 - 1 {
        fail("Phase 15.3 diagnostic missing reason code");
    }
    if std.str_find(diagnostic_text, "compiler/p15_move_source.gst:4:5") == 0 - 1 {
        fail("Phase 15.3 diagnostic missing declaration location");
    }
    if std.str_find(diagnostic_text, "compiler/p15_move_source.gst:8:5") == 0 - 1 {
        fail("Phase 15.3 diagnostic missing move site");
    }
    if std.str_find(diagnostic_text, "compiler/p15_move_source.gst:12:5") == 0 - 1 {
        fail("Phase 15.3 diagnostic missing invalid use site");
    }
    if std.str_find(diagnostic_text, "prior_state=moved") == 0 - 1 {
        fail("Phase 15.3 diagnostic missing prior state");
    }
    if std.str_find(diagnostic_text, "attempted_operation=use") == 0 - 1 {
        fail("Phase 15.3 diagnostic missing attempted operation");
    }

    os.LogStr("SUCCESS: Phase 15.3 move-state transitions and diagnostics passed");
}