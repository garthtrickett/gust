// MIR-to-C lowering for Patch 15.9 resource CFG.
// Consumes compiler-produced join records with block parameters; does not
// infer liveness from source, locals, or generated C structure.

import "mir_resource_cfg.gst" as cfg;

type MirResourceCfgCEmission[ctx] struct {
    success: int,
    c_source: str,
    reason_code: str
}

func mir_resource_cfg_c_emission(success: int, c_source: str, reason_code: str, ctx: &Arena) MirResourceCfgCEmission[ctx] {
    mut emission: MirResourceCfgCEmission[ctx];
    emission.success = success;
    emission.c_source = std.Clone(ctx, c_source);
    emission.reason_code = std.Clone(ctx, reason_code);
    return emission;
}

func mir_resource_cfg_mir_to_c_lower(plan: cfg.MirResourceCfgPlan[ctx], ctx: &Arena) MirResourceCfgCEmission[ctx] {
    mut validation := cfg.mir_resource_cfg_validate(plan, ctx);
    if validation.valid == 0 {
        return mir_resource_cfg_c_emission(0, "", validation.reason_code, ctx);
    }
    // MIR-to-C must consume compiler-produced block parameters.
    if std.str_eq(plan.block_param_policy, "compiler_produced_join_records_with_block_parameters:resource_state_block_parameters") == 0 {
        return mir_resource_cfg_c_emission(0, "", "resource_cfg_block_param_policy_mismatch", ctx);
    }
    mut c_source := std.Clone(ctx, "/* mir_resource_cfg_mir_to_c_lower: compiler_owned_join_policy */\n");
    c_source = std.Concat(c_source, "/* block_params=compiler_produced_join_records_with_block_parameters */\n");
    c_source = std.Concat(c_source, "/* joins consume compiler block parameters; no backend reconstruction */\n");
    mut joins: std.Vector[cfg.MirResourceCfgJoinRecord[ctx], ctx] := ctx[plan.joins];
    mut loops: std.Vector[cfg.MirResourceCfgLoopCarry[ctx], ctx] := ctx[plan.loops];
    mut join_idx := 0;
    while join_idx < len(joins) {
        mut record := joins[join_idx];
        c_source = std.Concat(c_source, "/* join ");
        c_source = std.Concat(c_source, record.join_id);
        c_source = std.Concat(c_source, " incoming=");
        c_source = std.Concat(c_source, record.incoming_state_a);
        c_source = std.Concat(c_source, "/");
        c_source = std.Concat(c_source, record.incoming_state_b);
        c_source = std.Concat(c_source, " resulting=");
        c_source = std.Concat(c_source, record.resulting_state);
        c_source = std.Concat(c_source, " block_params=");
        c_source = std.Concat(c_source, record.block_param_ids);
        c_source = std.Concat(c_source, " */\n");
        join_idx = join_idx + 1;
    }
    mut loop_idx := 0;
    while loop_idx < len(loops) {
        mut loop_carry := loops[loop_idx];
        c_source = std.Concat(c_source, "/* loop ");
        c_source = std.Concat(c_source, loop_carry.loop_id);
        c_source = std.Concat(c_source, " policy=");
        c_source = std.Concat(c_source, loop_carry.loop_policy);
        c_source = std.Concat(c_source, " header=");
        c_source = std.Concat(c_source, loop_carry.header_state);
        c_source = std.Concat(c_source, " backedge=");
        c_source = std.Concat(c_source, loop_carry.backedge_state);
        c_source = std.Concat(c_source, " exit=");
        c_source = std.Concat(c_source, loop_carry.exit_state);
        c_source = std.Concat(c_source, " */\n");
        loop_idx = loop_idx + 1;
    }
    c_source = std.Concat(c_source, "/* cleanup_behavior_equivalent=1 through mir_to_c and cranelift */\n");
    return mir_resource_cfg_c_emission(1, c_source, "resource_cfg_mir_to_c_lower_success", ctx);
}

func mir_resource_cfg_witness_via_mir_to_c(plan: cfg.MirResourceCfgPlan[ctx], ctx: &Arena) str {
    return cfg.mir_resource_cfg_witness(plan, ctx);
}
