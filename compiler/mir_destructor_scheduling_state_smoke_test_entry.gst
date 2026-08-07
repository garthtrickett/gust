import "mir_destructor_scheduling.gst" as scheduling;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut plan := scheduling.mir_destructor_scheduling_make_plan(&ctx);
    if std.str_eq(plan.semantic_authority, "compiler_owned_destructor_identity_and_schedule") == 0 ||
       std.str_eq(plan.exactly_once_policy, "one_live_schedule_one_execution_deterministic_order") == 0 ||
       std.str_eq(plan.deferred_features, "async_destruction,finalizers,gc,concurrent_cancellation") == 0
    {
        os.Exit(1);
    }
    os.LogStr("SUCCESS: Phase 15.7 destructor scheduling state policy passed");
}
