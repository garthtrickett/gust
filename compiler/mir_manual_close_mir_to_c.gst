// Patch 15.8 MIR-to-C lowering for manual close versus deferred cleanup.
// Consumes compiler-produced MirManualClosePlan and emits close calls,
// cleanup suppression, and witnesses. No backend-local state decision.

import "mir_manual_close.gst" as manual_close;

func mir_manual_close_mir_to_c_lower(plan: manual_close.MirManualClosePlan[ctx], ctx: &Arena) str {
    mut validation := manual_close.mir_manual_close_validate(plan, ctx);
    if validation.valid == 0 {
        return std.Concat("manual_close_mir_to_c_error: reason=", validation.reason_code);
    }
    mut ops: std.Vector[manual_close.MirManualCloseOperation[ctx], ctx] := ctx[plan.operations];
    mut output := std.Clone(ctx, "mir_to_c_manual_close_lowering: authority=compiler close_suppresses_deferred_cleanup=1\n");
    mut index := 0;
    while index < len(ops) {
        mut op := ops[index];
        mut line := std.Clone(ctx, "mir_to_c_manual_close: resource=");
        line = std.Concat(line, op.resource_id);
        line = std.Concat(line, " close_capability=");
        line = std.Concat(line, op.close_capability_id);
        line = std.Concat(line, " source=");
        line = std.Concat(line, op.source_location);
        line = std.Concat(line, " resulting_state=");
        line = std.Concat(line, op.resulting_state);
        line = std.Concat(line, " cleanup_cancellation=");
        line = std.Concat(line, op.cleanup_cancellation_id);
        line = std.Concat(line, "\n");
        output = std.Concat(output, line);
        index = index + 1;
    }
    output = std.Concat(output, manual_close.mir_manual_close_witness(plan, ctx));
    return std.Clone(ctx, output);
}

func mir_manual_close_mir_to_c_witness(plan: manual_close.MirManualClosePlan[ctx], ctx: &Arena) str {
    return std.Clone(ctx, manual_close.mir_manual_close_witness(plan, ctx));
}
