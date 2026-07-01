import "typechecker.gst" as typechecker;

func expect_transition_allowed(ok: int, msg: str) {
    if ok != 1 {
        os.LogStr(msg);
        os.Exit(1);
    }
}

func expect_transition_rejected(ok: int, msg: str) {
    if ok != 0 {
        os.LogStr(msg);
        os.Exit(1);
    }
}

func expect_state(env: *typechecker.TypeEnvironment[ctx], name: str, expected: str, ctx: &Arena) {
    mut actual := typechecker.env_open_linear_resource_state_name(env, name, ctx);
    if std.str_eq(actual, expected) == 0 {
        os.LogStr("Error: transfer transition table observed wrong resource state");
        os.LogStr(name);
        os.LogStr(expected);
        os.LogStr(actual);
        os.Exit(1);
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_transition_table := typechecker.env_new(ctx);
    env_transition_table.current_prefix = "main__";
    typechecker.env_register_struct_linear_metadata(&env_transition_table, "main__TransitionTablePayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_transition_table, "main__TransitionTablePayload", "main__close_transition_table_payload", ctx);

    typechecker.env_register_open_linear_resource(&env_transition_table, "owned_transition_resource", "main__TransitionTablePayload", ctx);
    expect_state(&env_transition_table, "owned_transition_resource", "owned", ctx);
    expect_transition_allowed(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "owned_transition_resource", "use", ctx), "Error: owned Resource should allow use transition");
    expect_transition_allowed(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "owned_transition_resource", "move", ctx), "Error: owned Resource should allow move transition");
    expect_transition_allowed(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "owned_transition_resource", "close", ctx), "Error: owned Resource should allow close transition");
    expect_transition_allowed(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "owned_transition_resource", "borrow", ctx), "Error: owned Resource should allow borrow transition");
    expect_transition_allowed(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "owned_transition_resource", "schedule_destructor", ctx), "Error: owned Resource with destructor should allow destructor scheduling transition");
    expect_transition_allowed(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "owned_transition_resource", "cleanup_required", ctx), "Error: owned Resource should require cleanup");

    typechecker.env_register_open_linear_resource(&env_transition_table, "moved_transition_resource", "main__TransitionTablePayload", ctx);
    typechecker.env_mark_open_linear_resource_moved(&env_transition_table, "moved_transition_resource", ctx);
    expect_state(&env_transition_table, "moved_transition_resource", "moved", ctx);
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "moved_transition_resource", "use", ctx), "Error: moved Resource should reject use transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "moved_transition_resource", "move", ctx), "Error: moved Resource should reject move transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "moved_transition_resource", "close", ctx), "Error: moved Resource should reject close transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "moved_transition_resource", "schedule_destructor", ctx), "Error: moved Resource should reject destructor scheduling transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "moved_transition_resource", "borrow", ctx), "Error: moved Resource should reject borrow transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "moved_transition_resource", "cleanup_required", ctx), "Error: moved Resource should not require cleanup");

    typechecker.env_register_open_linear_resource(&env_transition_table, "closed_transition_resource", "main__TransitionTablePayload", ctx);
    typechecker.env_mark_open_linear_resource_closed(&env_transition_table, "closed_transition_resource", ctx);
    expect_state(&env_transition_table, "closed_transition_resource", "closed", ctx);
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "closed_transition_resource", "use", ctx), "Error: closed Resource should reject use transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "closed_transition_resource", "move", ctx), "Error: closed Resource should reject move transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "closed_transition_resource", "close", ctx), "Error: closed Resource should reject close transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "closed_transition_resource", "schedule_destructor", ctx), "Error: closed Resource should reject destructor scheduling transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "closed_transition_resource", "borrow", ctx), "Error: closed Resource should reject borrow transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "closed_transition_resource", "cleanup_required", ctx), "Error: closed Resource should not require cleanup");

    typechecker.env_register_open_linear_resource(&env_transition_table, "scheduled_transition_resource", "main__TransitionTablePayload", ctx);
    typechecker.env_mark_open_linear_resource_destructor_scheduled(&env_transition_table, "scheduled_transition_resource", ctx);
    expect_state(&env_transition_table, "scheduled_transition_resource", "destructor_scheduled", ctx);
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "scheduled_transition_resource", "use", ctx), "Error: destructor-scheduled Resource should reject use transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "scheduled_transition_resource", "move", ctx), "Error: destructor-scheduled Resource should reject move transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "scheduled_transition_resource", "close", ctx), "Error: destructor-scheduled Resource should reject close transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "scheduled_transition_resource", "schedule_destructor", ctx), "Error: destructor-scheduled Resource should reject second destructor scheduling transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "scheduled_transition_resource", "borrow", ctx), "Error: destructor-scheduled Resource should reject borrow transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "scheduled_transition_resource", "cleanup_required", ctx), "Error: destructor-scheduled Resource should not require cleanup");

    typechecker.env_register_open_linear_resource(&env_transition_table, "borrowed_transition_resource", "main__TransitionTablePayload", ctx);
    typechecker.env_mark_open_linear_resource_borrowed(&env_transition_table, "borrowed_transition_resource", ctx);
    expect_state(&env_transition_table, "borrowed_transition_resource", "borrowed", ctx);
    expect_transition_allowed(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "borrowed_transition_resource", "use", ctx), "Error: borrowed Resource should allow use transition under current helper semantics");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "borrowed_transition_resource", "move", ctx), "Error: borrowed Resource should reject move transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "borrowed_transition_resource", "close", ctx), "Error: borrowed Resource should reject close transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "borrowed_transition_resource", "schedule_destructor", ctx), "Error: borrowed Resource should reject destructor scheduling transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "borrowed_transition_resource", "borrow", ctx), "Error: borrowed Resource should reject nested borrow transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "borrowed_transition_resource", "cleanup_required", ctx), "Error: borrowed Resource should not require cleanup under current helper semantics");

    expect_state(&env_transition_table, "missing_transition_resource", "untracked", ctx);
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "missing_transition_resource", "use", ctx), "Error: untracked Resource should reject use transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "missing_transition_resource", "move", ctx), "Error: untracked Resource should reject move transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "missing_transition_resource", "close", ctx), "Error: untracked Resource should reject close transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "missing_transition_resource", "schedule_destructor", ctx), "Error: untracked Resource should reject destructor scheduling transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "missing_transition_resource", "borrow", ctx), "Error: untracked Resource should reject borrow transition");
    expect_transition_rejected(typechecker.env_open_linear_resource_transfer_transition_is_allowed(&env_transition_table, "missing_transition_resource", "cleanup_required", ctx), "Error: untracked Resource should not require cleanup");

    os.LogStr("SUCCESS: helper-level Resource transfer transition table verified!");
}