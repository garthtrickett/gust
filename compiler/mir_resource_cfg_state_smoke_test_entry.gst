import "mir_resource_cfg.gst" as cfg;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    mut plan := cfg.mir_resource_cfg_make_plan(&ctx);
    if std.str_eq(plan.semantic_authority, "compiler_owned_join_policy") == 0 ||
       std.str_eq(plan.join_policy, "freeze_supported_resource_state_joins") == 0 ||
       std.str_eq(plan.block_param_policy, "compiler_produced_join_records_with_block_parameters:resource_state_block_parameters") == 0
    {
        os.Exit(1);
    }
    if std.str_find(plan.valid_joins, "live/live") == 0 - 1 { os.Exit(1); }
    if std.str_find(plan.valid_joins, "moved/moved") == 0 - 1 { os.Exit(1); }
    if std.str_find(plan.valid_joins, "closed/closed") == 0 - 1 { os.Exit(1); }
    if std.str_find(plan.valid_joins, "reinitialized/reinitialized") == 0 - 1 { os.Exit(1); }
    if std.str_find(plan.invalid_joins, "live/moved") == 0 - 1 { os.Exit(1); }
    if std.str_find(plan.invalid_joins, "live/closed") == 0 - 1 { os.Exit(1); }
    if std.str_find(plan.invalid_joins, "destroyed/live") == 0 - 1 { os.Exit(1); }
    if std.str_find(plan.invalid_joins, "incompatible_resource_identities") == 0 - 1 { os.Exit(1); }
    if std.str_find(plan.loop_policy_set, "resource_remains_live_across_iterations") == 0 - 1 { os.Exit(1); }
    if std.str_find(plan.loop_policy_set, "resource_moves_exactly_once_before_loop_exit") == 0 - 1 { os.Exit(1); }
    if std.str_find(plan.loop_policy_set, "resource_is_replaced_each_iteration_with_prior_cleanup") == 0 - 1 { os.Exit(1); }
    if std.str_find(plan.loop_policy_set, "resource_is_closed_on_all_exiting_paths") == 0 - 1 { os.Exit(1); }
    if std.str_find(plan.boundary_policy, "irreducible_cfg_deferred") == 0 - 1 { os.Exit(1); }
    // Validate loop policy helper
    if cfg.mir_resource_cfg_loop_policy_is_valid("resource_remains_live_across_iterations") == 0 { os.Exit(1); }
    if cfg.mir_resource_cfg_loop_policy_is_valid("unsupported_policy") == 1 { os.Exit(1); }
    // Valid join helper
    if cfg.mir_resource_cfg_is_valid_join_pair("live", "live") == 0 { os.Exit(1); }
    if cfg.mir_resource_cfg_is_valid_join_pair("live", "moved") == 1 { os.Exit(1); }
    // Join validation positives
    mut live_join: cfg.MirResourceCfgJoinRecord[ctx];
    live_join.join_id = std.Clone(ctx, "join:live:live");
    live_join.block_id = std.Clone(ctx, "block:join:live");
    live_join.resource_id = std.Clone(ctx, "resource:cfg:live");
    live_join.incoming_resource_id_second = std.Clone(ctx, "");
    live_join.incoming_state_a = std.Clone(ctx, "live");
    live_join.incoming_state_b = std.Clone(ctx, "live");
    live_join.resulting_state = std.Clone(ctx, "live");
    live_join.valid = 1;
    live_join.reason_code = std.Clone(ctx, "resource_cfg_join_valid");
    live_join.block_param_ids = std.Clone(ctx, "block_param:cfg:live");
    live_join.cleanup_obligation_id = std.Clone(ctx, "cleanup:cfg:live");
    live_join.cleanup_live = 1;
    live_join.is_loop_backedge = 0;
    live_join.nested_depth = 1;
    mut live_validation := cfg.mir_resource_cfg_validate_join(live_join, &ctx);
    if live_validation.valid == 0 { os.Exit(1); }
    os.LogStr("SUCCESS: Phase 15.9 resource CFG state policy passed");
}
