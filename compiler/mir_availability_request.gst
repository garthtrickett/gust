// Phase 17.13 availability request and MIR-to-C witness.
//
// Records every banned C wrapper class on the native path together with the
// compiler-owned thing that replaced it. The evidence policy is the load-bearing
// field: explicit Cranelift must succeed with the C compiler unavailable, which
// is a demonstration rather than a declaration that the glue is gone.

import "mir_runtime_boundary_authority.gst" as runtime;

func mir_availability_request_format() str { return "gust.compiler_availability.v1"; }

func mir_availability_append(output: str, name: str, value: str, ctx: &Arena) str {
    mut result := std.Concat(output, name);
    result = std.Concat(result, "=");
    result = std.Concat(result, value);
    result = std.Concat(result, ";");
    return std.Clone(ctx, result);
}

func mir_serialize_availability_request(table: runtime.MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, mir_availability_request_format());
    output = std.Concat(output, "\ntarget: ");
    output = std.Concat(output, table.target_id);
    output = std.Concat(output, "\ntriple: ");
    output = std.Concat(output, table.target_triple);
    output = std.Concat(output, "\n");
    mut bans: std.Vector[runtime.MirRuntimeAvailabilityDecision[ctx], ctx] := ctx[table.availability_decisions];
    mut index := 0;
    while index < len(bans) {
        mut row := "availability_decision:";
        row = mir_availability_append(row, "id", bans[index].decision_id, ctx);
        row = mir_availability_append(row, "order", std.FormatInt(bans[index].decision_order), ctx);
        row = mir_availability_append(row, "step", bans[index].validation_step, ctx);
        row = mir_availability_append(row, "rejection", bans[index].rejection_class, ctx);
        row = mir_availability_append(row, "stage", bans[index].stage_boundary, ctx);
        row = mir_availability_append(row, "target", bans[index].target_id, ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_availability_mir_to_c_witness(table: runtime.MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) str {
    mut output := "witness: gust.availability_witness.v1\ntarget: ";
    output = std.Concat(output, table.target_id);
    output = std.Concat(output, "\n");
    mut bans: std.Vector[runtime.MirRuntimeAvailabilityDecision[ctx], ctx] := ctx[table.availability_decisions];
    mut index := 0;
    while index < len(bans) {
        mut row := "decision:";
        row = mir_availability_append(row, "order", std.FormatInt(bans[index].decision_order), ctx);
        row = mir_availability_append(row, "step", bans[index].validation_step, ctx);
        row = mir_availability_append(row, "rejection", bans[index].rejection_class, ctx);
        row = mir_availability_append(row, "stage", bans[index].stage_boundary, ctx);
        row = mir_availability_append(row, "linkage", "all_compatibility_decisions_complete_before_any_output_could_exist", ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}
