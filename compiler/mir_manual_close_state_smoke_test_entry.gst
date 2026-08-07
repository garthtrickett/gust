import "mir_manual_close.gst" as manual_close;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    mut plan := manual_close.mir_manual_close_make_plan(&ctx);
    if std.str_eq(plan.semantic_authority, "compiler_owned_manual_close_and_deferred_cleanup_state_machine") == 0 ||
       std.str_eq(plan.selected_close_kinds, "Phase15SelectedResource,os_Dir_ctx") == 0 ||
       std.str_eq(plan.close_semantics, "manual_close_succeeds_and_suppresses_deferred_cleanup_transitions_to_manually_closed") == 0 ||
       std.str_eq(plan.cleanup_interaction, "scope_exit_cleanup_does_not_close_already_closed_resource_twice_final_destructor_only_if_explicitly_required") == 0 ||
       std.str_eq(plan.repeated_close_policy, "reject") == 0
    {
        os.Exit(1);
    }
    if manual_close.mir_manual_close_selected_kind_is_closeable("Phase15SelectedResource") == 0 { os.Exit(1); }
    if manual_close.mir_manual_close_selected_kind_is_closeable("os_Dir_ctx") == 0 { os.Exit(1); }
    if manual_close.mir_manual_close_selected_kind_is_closeable("i32") == 1 { os.Exit(1); }
    os.LogStr("SUCCESS: Phase 15.8 manual close versus deferred cleanup state policy passed");
}
