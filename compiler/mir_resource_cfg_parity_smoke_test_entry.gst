import "mir_resource_cfg.gst" as cfg;
import "mir_resource_cfg_mir_to_c.gst" as cfg_c;

func fail(message: str) {
    os.LogStr(message);
    os.Exit(1);
}

func make_join(join_id: str, block_id: str, resource_id: str, second_id: str, a: str, b: str, resulting: str, block_params: str, cleanup_id: str, cleanup_live: int, is_backedge: int, nested: int, ctx: &Arena) cfg.MirResourceCfgJoinRecord[ctx] {
    mut record: cfg.MirResourceCfgJoinRecord[ctx];
    record.join_id = std.Clone(ctx, join_id);
    record.block_id = std.Clone(ctx, block_id);
    record.resource_id = std.Clone(ctx, resource_id);
    record.incoming_resource_id_second = std.Clone(ctx, second_id);
    record.incoming_state_a = std.Clone(ctx, a);
    record.incoming_state_b = std.Clone(ctx, b);
    record.resulting_state = std.Clone(ctx, resulting);
    record.valid = 1;
    record.reason_code = std.Clone(ctx, "resource_cfg_join_valid");
    record.block_param_ids = std.Clone(ctx, block_params);
    record.cleanup_obligation_id = std.Clone(ctx, cleanup_id);
    record.cleanup_live = cleanup_live;
    record.is_loop_backedge = is_backedge;
    record.nested_depth = nested;
    return record;
}

func make_loop(loop_id: str, resource_id: str, header: str, backedge: str, exit_state: str, policy: str, cleanup_id: str, is_nested: int, ctx: &Arena) cfg.MirResourceCfgLoopCarry[ctx] {
    mut loop_carry: cfg.MirResourceCfgLoopCarry[ctx];
    loop_carry.loop_id = std.Clone(ctx, loop_id);
    loop_carry.resource_id = std.Clone(ctx, resource_id);
    loop_carry.header_state = std.Clone(ctx, header);
    loop_carry.backedge_state = std.Clone(ctx, backedge);
    loop_carry.exit_state = std.Clone(ctx, exit_state);
    loop_carry.loop_policy = std.Clone(ctx, policy);
    loop_carry.valid = 1;
    loop_carry.reason_code = std.Clone(ctx, "resource_cfg_loop_valid");
    loop_carry.cleanup_obligation_id = std.Clone(ctx, cleanup_id);
    loop_carry.cleanup_live = 1;
    loop_carry.is_nested = is_nested;
    return loop_carry;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    mut plan := cfg.mir_resource_cfg_make_plan(&ctx);
    // Valid conditional joins
    plan = cfg.mir_resource_cfg_with_join(plan, make_join("join:cfg:live_live", "block:join:live", "resource:cfg:join:live", "", "live", "live", "live", "block_param:cfg:live", "cleanup:cfg:live", 1, 0, 1, &ctx), &ctx);
    plan = cfg.mir_resource_cfg_with_join(plan, make_join("join:cfg:moved_moved", "block:join:moved", "resource:cfg:join:moved", "", "moved", "moved", "moved", "block_param:cfg:moved", "cleanup:cfg:moved", 0, 0, 1, &ctx), &ctx);
    plan = cfg.mir_resource_cfg_with_join(plan, make_join("join:cfg:closed_closed", "block:join:closed", "resource:cfg:join:closed", "", "closed", "closed", "closed", "block_param:cfg:closed", "cleanup:cfg:closed", 0, 0, 2, &ctx), &ctx);
    plan = cfg.mir_resource_cfg_with_join(plan, make_join("join:cfg:reinit_reinit", "block:join:reinit", "resource:cfg:join:reinit", "", "reinitialized", "reinitialized", "live", "block_param:cfg:reinit", "cleanup:cfg:reinit", 1, 0, 2, &ctx), &ctx);
    // Nested branch join (depth 2)
    plan = cfg.mir_resource_cfg_with_join(plan, make_join("join:cfg:nested_live", "block:join:nested", "resource:cfg:nested", "", "live", "live", "live", "block_param:cfg:nested", "cleanup:cfg:nested", 1, 0, 2, &ctx), &ctx);
    // Selected loop policies
    plan = cfg.mir_resource_cfg_with_loop(plan, make_loop("loop:cfg:live_across", "resource:cfg:loop:live", "live", "live", "live", "resource_remains_live_across_iterations", "cleanup:cfg:loop:live", 0, &ctx), &ctx);
    plan = cfg.mir_resource_cfg_with_loop(plan, make_loop("loop:cfg:move_once", "resource:cfg:loop:move", "live", "moved", "moved", "resource_moves_exactly_once_before_loop_exit", "cleanup:cfg:loop:move", 0, &ctx), &ctx);
    plan = cfg.mir_resource_cfg_with_loop(plan, make_loop("loop:cfg:replace_each", "resource:cfg:loop:replace", "live", "live", "live", "resource_is_replaced_each_iteration_with_prior_cleanup", "cleanup:cfg:loop:replace", 1, &ctx), &ctx);
    plan = cfg.mir_resource_cfg_with_loop(plan, make_loop("loop:cfg:closed_all", "resource:cfg:loop:closed", "live", "live", "manually_closed", "resource_is_closed_on_all_exiting_paths", "cleanup:cfg:loop:closed", 0, &ctx), &ctx);

    mut validation := cfg.mir_resource_cfg_validate(plan, &ctx);
    if validation.valid == 0 {
        fail(std.Concat("Phase 15.9 plan rejected: ", validation.reason_code));
    }

    // Negative: invalid joins must be rejected
    mut invalid_live_moved: cfg.MirResourceCfgJoinRecord[ctx];
    invalid_live_moved.join_id = std.Clone(ctx, "join:cfg:invalid:live_moved");
    invalid_live_moved.block_id = std.Clone(ctx, "block:join:invalid");
    invalid_live_moved.resource_id = std.Clone(ctx, "resource:cfg:invalid");
    invalid_live_moved.incoming_resource_id_second = std.Clone(ctx, "");
    invalid_live_moved.incoming_state_a = std.Clone(ctx, "live");
    invalid_live_moved.incoming_state_b = std.Clone(ctx, "moved");
    invalid_live_moved.resulting_state = std.Clone(ctx, "live");
    invalid_live_moved.valid = 1;
    invalid_live_moved.reason_code = std.Clone(ctx, "resource_cfg_join_valid");
    invalid_live_moved.block_param_ids = std.Clone(ctx, "block_param:cfg:invalid");
    invalid_live_moved.cleanup_obligation_id = std.Clone(ctx, "cleanup:cfg:invalid");
    invalid_live_moved.cleanup_live = 1;
    invalid_live_moved.is_loop_backedge = 0;
    invalid_live_moved.nested_depth = 1;
    mut invalid_validation := cfg.mir_resource_cfg_validate_join(invalid_live_moved, &ctx);
    if invalid_validation.valid == 1 || std.str_eq(invalid_validation.reason_code, "path_dependent_liveness_without_selected_policy") == 0 {
        fail("Phase 15.9 live/moved must be rejected with path_dependent_liveness_without_selected_policy");
    }

    mut invalid_incompatible: cfg.MirResourceCfgJoinRecord[ctx];
    invalid_incompatible.join_id = std.Clone(ctx, "join:cfg:invalid:incompatible");
    invalid_incompatible.block_id = std.Clone(ctx, "block:join:invalid2");
    invalid_incompatible.resource_id = std.Clone(ctx, "resource:cfg:a");
    invalid_incompatible.incoming_resource_id_second = std.Clone(ctx, "resource:cfg:b");
    invalid_incompatible.incoming_state_a = std.Clone(ctx, "live");
    invalid_incompatible.incoming_state_b = std.Clone(ctx, "live");
    invalid_incompatible.resulting_state = std.Clone(ctx, "live");
    invalid_incompatible.valid = 1;
    invalid_incompatible.reason_code = std.Clone(ctx, "resource_cfg_join_valid");
    invalid_incompatible.block_param_ids = std.Clone(ctx, "block_param:cfg:invalid2");
    invalid_incompatible.cleanup_obligation_id = std.Clone(ctx, "cleanup:cfg:invalid2");
    invalid_incompatible.cleanup_live = 1;
    invalid_incompatible.is_loop_backedge = 0;
    invalid_incompatible.nested_depth = 1;
    mut incompatible_validation := cfg.mir_resource_cfg_validate_join(invalid_incompatible, &ctx);
    if incompatible_validation.valid == 1 || std.str_eq(incompatible_validation.reason_code, "incompatible_resource_identities") == 0 {
        fail("Phase 15.9 incompatible resource identities must be rejected");
    }

    // Negative: loop backedge mismatch
    mut bad_loop: cfg.MirResourceCfgLoopCarry[ctx];
    bad_loop.loop_id = std.Clone(ctx, "loop:cfg:bad");
    bad_loop.resource_id = std.Clone(ctx, "resource:cfg:bad");
    bad_loop.header_state = std.Clone(ctx, "live");
    bad_loop.backedge_state = std.Clone(ctx, "moved");
    bad_loop.exit_state = std.Clone(ctx, "live");
    bad_loop.loop_policy = std.Clone(ctx, "resource_remains_live_across_iterations");
    bad_loop.valid = 1;
    bad_loop.reason_code = std.Clone(ctx, "resource_cfg_loop_valid");
    bad_loop.cleanup_obligation_id = std.Clone(ctx, "cleanup:cfg:bad");
    bad_loop.cleanup_live = 1;
    bad_loop.is_nested = 0;
    mut bad_loop_validation := cfg.mir_resource_cfg_validate_loop(bad_loop, &ctx);
    if bad_loop_validation.valid == 1 || std.str_eq(bad_loop_validation.reason_code, "loop_backedge_state_mismatch") == 0 {
        fail("Phase 15.9 loop backedge mismatch must be rejected");
    }

    // Check use_after_conditionally_moved_state detection
    if cfg.mir_resource_cfg_is_use_after_conditionally_moved("moved", "live") == 0 { fail("use_after_conditionally_moved_state must be detected"); }

    mut request := cfg.mir_resource_cfg_append_to_request("", plan, &ctx);
    mut witness := cfg.mir_resource_cfg_witness(plan, &ctx);
    // Verify witness contains required resource-state witnesses
    if std.str_find(witness, "resource_state_witness_after_join") == 0 - 1 { fail("witness must contain resource_state_witness_after_join"); }
    if std.str_find(witness, "resource_state_witness_after_loop_exit") == 0 - 1 { fail("witness must contain resource_state_witness_after_loop_exit"); }
    if std.str_find(witness, "cleanup_behavior_equivalent=1") == 0 - 1 { fail("witness must assert cleanup_behavior_equivalent"); }
    if std.str_find(witness, "block_params_used=1") == 0 - 1 { fail("witness must assert block_params_used"); }
    if std.str_find(witness, "nested_branches=1") == 0 - 1 { fail("witness must assert nested_branches"); }
    if std.str_find(witness, "selected_loops=1") == 0 - 1 { fail("witness must assert selected_loops"); }

    // MIR-to-C must consume same plan
    mut c_emission := cfg_c.mir_resource_cfg_mir_to_c_lower(plan, &ctx);
    if c_emission.success == 0 { fail(std.Concat("MIR-to-C lower rejected: ", c_emission.reason_code)); }
    if std.str_find(c_emission.c_source, "compiler_owned_join_policy") == 0 - 1 { fail("MIR-to-C must preserve compiler_owned_join_policy"); }

    if os.WriteFile("/tmp/gust-phase15-resource-cfg.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase15-resource-cfg.mir-to-c.witness", witness) == 0
    {
        fail("Phase 15.9 artifacts could not be written");
    }
    os.LogStr("SUCCESS: Phase 15.9 resource CFG parity smoke passed");
}
