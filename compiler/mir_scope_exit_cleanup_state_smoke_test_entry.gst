import "mir_scope_exit_cleanup.gst" as cleanup;

func fail(message: str) {
    os.LogStr(message);
    os.Exit(1);
}

func expect_reason(state: str, expected: str) {
    mut actual_state_reason := cleanup.mir_scope_exit_cleanup_exclusion_reason(state);
    if std.str_eq(actual_state_reason, expected) == 0 {
        fail(std.Concat("Phase 15.5 exclusion reason mismatch for ", state));
    }
}

func main() {
    expect_reason("moved", "moved_resource");
    expect_reason("manually_closed", "manually_closed_resource");
    expect_reason("destroyed", "already_destroyed_resource");
    expect_reason("cleanup_scheduled", "already_scheduled_resource");
    expect_reason("live", "invalid_non_live_state");

    if cleanup.mir_scope_exit_cleanup_scope_kind_selected("block_scope") != 1 ||
       cleanup.mir_scope_exit_cleanup_scope_kind_selected("function_body") != 1 ||
       cleanup.mir_scope_exit_cleanup_scope_kind_selected("selected_nested_scope") != 1 ||
       cleanup.mir_scope_exit_cleanup_scope_kind_selected("loop_body") != 0
    {
        fail("Phase 15.5 selected scope inventory mismatch");
    }

    os.LogStr("SUCCESS: Phase 15.5 scope-exit cleanup state policy passed");
}