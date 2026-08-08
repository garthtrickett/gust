import "mir_resource_authority.gst" as authority;
import "mir_failure_cleanup.gst" as failure;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    mut table := authority.mir_resource_make_empty_table("x86_64-linux-gnu", "x86_64-unknown-linux-gnu", &ctx);

    mut inventory_plan := failure.mir_failure_cleanup_make_plan(&ctx);
    inventory_plan.selected_forms = std.Clone(ctx, "unbounded_unwind");
    mut inventory_result := failure.mir_failure_cleanup_validate(inventory_plan, table, &ctx);
    if inventory_result.valid == 1 || std.str_eq(inventory_result.reason_code, "failure_cleanup_inventory_unfrozen") == 0 { os.Exit(1); }

    mut deferred_plan := failure.mir_failure_cleanup_make_plan(&ctx);
    deferred_plan.deferred_forms = std.Clone(ctx, "none");
    mut deferred_result := failure.mir_failure_cleanup_validate(deferred_plan, table, &ctx);
    if deferred_result.valid == 1 || std.str_eq(deferred_result.reason_code, "failure_cleanup_deferred_boundary_mismatch") == 0 { os.Exit(1); }

    mut backend_plan := failure.mir_failure_cleanup_make_plan(&ctx);
    backend_plan.backend_policy = std.Clone(ctx, "backend_local_cleanup_planner");
    mut backend_result := failure.mir_failure_cleanup_validate(backend_plan, table, &ctx);
    if backend_result.valid == 1 || std.str_eq(backend_result.reason_code, "failure_cleanup_authority_mismatch") == 0 { os.Exit(1); }

    os.LogStr("SUCCESS: Phase 15.12 failure cleanup state policy passed");
}
