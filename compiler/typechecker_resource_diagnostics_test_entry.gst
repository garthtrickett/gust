import "typechecker.gst" as typechecker;

func expect_empty_resource_diag(label: str, actual: str) {
    if len(actual) != 0 {
        os.LogStr("Error: expected empty resource diagnostic");
        os.LogStr(label);
        os.LogStr(actual);
        os.Exit(1);
    }
}

func expect_contains_resource_diag(label: str, actual: str, expected: str) {
    if std.str_find(actual, expected) == 0 - 1 {
        os.LogStr("Error: resource diagnostic did not contain expected text");
        os.LogStr(label);
        os.LogStr(actual);
        os.LogStr(expected);
        os.Exit(1);
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_resource_diag := typechecker.env_new(ctx);

    typechecker.env_register_struct_linear_metadata(&env_resource_diag, "main__DiagnosticResource", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_resource_diag, "main__DiagnosticResource", "close_diagnostic_resource", ctx);
    typechecker.env_register_struct_linear_metadata(&env_resource_diag, "main__DiagnosticNoDestructorResource", 1, ctx);

    typechecker.env_register_open_linear_resource(&env_resource_diag, "owned_diag_resource", "main__DiagnosticResource", ctx);
    expect_empty_resource_diag("owned use", typechecker.env_open_linear_resource_use_diagnostic(&env_resource_diag, "owned_diag_resource", ctx));
    expect_empty_resource_diag("owned close", typechecker.env_open_linear_resource_close_diagnostic(&env_resource_diag, "owned_diag_resource", ctx));
    expect_empty_resource_diag("owned move", typechecker.env_open_linear_resource_move_diagnostic(&env_resource_diag, "owned_diag_resource", ctx));
    expect_empty_resource_diag("owned cleanup", typechecker.env_open_linear_resource_cleanup_diagnostic(&env_resource_diag, "owned_diag_resource", ctx));
    expect_empty_resource_diag("owned destructor schedule", typechecker.env_open_linear_resource_destructor_schedule_diagnostic(&env_resource_diag, "owned_diag_resource", ctx));

    typechecker.env_register_open_linear_resource(&env_resource_diag, "borrowed_diag_resource", "main__DiagnosticResource", ctx);
    typechecker.env_mark_open_linear_resource_borrowed(&env_resource_diag, "borrowed_diag_resource", ctx);
    expect_empty_resource_diag("borrowed use", typechecker.env_open_linear_resource_use_diagnostic(&env_resource_diag, "borrowed_diag_resource", ctx));
    expect_contains_resource_diag("borrowed close", typechecker.env_open_linear_resource_close_diagnostic(&env_resource_diag, "borrowed_diag_resource", ctx), "borrowed");
    expect_contains_resource_diag("borrowed move", typechecker.env_open_linear_resource_move_diagnostic(&env_resource_diag, "borrowed_diag_resource", ctx), "borrowed");
    expect_contains_resource_diag("borrowed cleanup", typechecker.env_open_linear_resource_cleanup_diagnostic(&env_resource_diag, "borrowed_diag_resource", ctx), "borrowed");
    expect_contains_resource_diag("borrowed destructor schedule", typechecker.env_open_linear_resource_destructor_schedule_diagnostic(&env_resource_diag, "borrowed_diag_resource", ctx), "borrowed");

    typechecker.env_register_open_linear_resource(&env_resource_diag, "moved_diag_resource", "main__DiagnosticResource", ctx);
    typechecker.env_mark_open_linear_resource_moved(&env_resource_diag, "moved_diag_resource", ctx);
    expect_contains_resource_diag("moved use", typechecker.env_open_linear_resource_use_diagnostic(&env_resource_diag, "moved_diag_resource", ctx), "already been moved");
    expect_contains_resource_diag("moved close", typechecker.env_open_linear_resource_close_diagnostic(&env_resource_diag, "moved_diag_resource", ctx), "already been moved");
    expect_contains_resource_diag("moved move", typechecker.env_open_linear_resource_move_diagnostic(&env_resource_diag, "moved_diag_resource", ctx), "already been moved");
    expect_contains_resource_diag("moved cleanup", typechecker.env_open_linear_resource_cleanup_diagnostic(&env_resource_diag, "moved_diag_resource", ctx), "moved");
    expect_contains_resource_diag("moved destructor schedule", typechecker.env_open_linear_resource_destructor_schedule_diagnostic(&env_resource_diag, "moved_diag_resource", ctx), "already been moved");

    typechecker.env_register_open_linear_resource(&env_resource_diag, "closed_diag_resource", "main__DiagnosticResource", ctx);
    typechecker.env_mark_open_linear_resource_closed(&env_resource_diag, "closed_diag_resource", ctx);
    expect_contains_resource_diag("closed use", typechecker.env_open_linear_resource_use_diagnostic(&env_resource_diag, "closed_diag_resource", ctx), "already been closed");
    expect_contains_resource_diag("closed close", typechecker.env_open_linear_resource_close_diagnostic(&env_resource_diag, "closed_diag_resource", ctx), "already been closed");
    expect_contains_resource_diag("closed move", typechecker.env_open_linear_resource_move_diagnostic(&env_resource_diag, "closed_diag_resource", ctx), "already been closed");
    expect_contains_resource_diag("closed cleanup", typechecker.env_open_linear_resource_cleanup_diagnostic(&env_resource_diag, "closed_diag_resource", ctx), "already been closed");
    expect_contains_resource_diag("closed destructor schedule", typechecker.env_open_linear_resource_destructor_schedule_diagnostic(&env_resource_diag, "closed_diag_resource", ctx), "already been closed");

    typechecker.env_register_open_linear_resource(&env_resource_diag, "scheduled_diag_resource", "main__DiagnosticResource", ctx);
    typechecker.env_mark_open_linear_resource_destructor_scheduled(&env_resource_diag, "scheduled_diag_resource", ctx);
    expect_contains_resource_diag("scheduled use", typechecker.env_open_linear_resource_use_diagnostic(&env_resource_diag, "scheduled_diag_resource", ctx), "destructor scheduled");
    expect_contains_resource_diag("scheduled close", typechecker.env_open_linear_resource_close_diagnostic(&env_resource_diag, "scheduled_diag_resource", ctx), "destructor scheduled");
    expect_contains_resource_diag("scheduled move", typechecker.env_open_linear_resource_move_diagnostic(&env_resource_diag, "scheduled_diag_resource", ctx), "destructor scheduled");
    expect_contains_resource_diag("scheduled cleanup", typechecker.env_open_linear_resource_cleanup_diagnostic(&env_resource_diag, "scheduled_diag_resource", ctx), "destructor scheduled");
    expect_contains_resource_diag("scheduled destructor schedule", typechecker.env_open_linear_resource_destructor_schedule_diagnostic(&env_resource_diag, "scheduled_diag_resource", ctx), "destructor scheduled");

    typechecker.env_register_open_linear_resource(&env_resource_diag, "no_destructor_diag_resource", "main__DiagnosticNoDestructorResource", ctx);
    expect_empty_resource_diag("no destructor use", typechecker.env_open_linear_resource_use_diagnostic(&env_resource_diag, "no_destructor_diag_resource", ctx));
    expect_empty_resource_diag("no destructor close", typechecker.env_open_linear_resource_close_diagnostic(&env_resource_diag, "no_destructor_diag_resource", ctx));
    expect_empty_resource_diag("no destructor move", typechecker.env_open_linear_resource_move_diagnostic(&env_resource_diag, "no_destructor_diag_resource", ctx));
    expect_empty_resource_diag("no destructor cleanup", typechecker.env_open_linear_resource_cleanup_diagnostic(&env_resource_diag, "no_destructor_diag_resource", ctx));
    expect_contains_resource_diag("no destructor schedule", typechecker.env_open_linear_resource_destructor_schedule_diagnostic(&env_resource_diag, "no_destructor_diag_resource", ctx), "no registered destructor");

    expect_contains_resource_diag("missing use", typechecker.env_open_linear_resource_use_diagnostic(&env_resource_diag, "missing_diag_resource", ctx), "not tracked");
    expect_contains_resource_diag("missing close", typechecker.env_open_linear_resource_close_diagnostic(&env_resource_diag, "missing_diag_resource", ctx), "not tracked");
    expect_contains_resource_diag("missing move", typechecker.env_open_linear_resource_move_diagnostic(&env_resource_diag, "missing_diag_resource", ctx), "not tracked");
    expect_contains_resource_diag("missing cleanup", typechecker.env_open_linear_resource_cleanup_diagnostic(&env_resource_diag, "missing_diag_resource", ctx), "not tracked");
    expect_contains_resource_diag("missing destructor schedule", typechecker.env_open_linear_resource_destructor_schedule_diagnostic(&env_resource_diag, "missing_diag_resource", ctx), "not tracked");

    os.LogStr("SUCCESS: inert linear resource diagnostics verified!");
}