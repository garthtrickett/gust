// Phase 17.14 composition request and MIR-to-C witness.
//
// Records every banned C wrapper class on the native path together with the
// compiler-owned thing that replaced it. The evidence policy is the load-bearing
// field: explicit Cranelift must succeed with the C compiler unavailable, which
// is a demonstration rather than a declaration that the glue is gone.

import "mir_runtime_boundary_authority.gst" as runtime;

func mir_composition_join(values: Index[std.Vector[str, ctx], ctx], ctx: &Arena) str {
    mut items: std.Vector[str, ctx] := ctx[values];
    mut output := "";
    mut index := 0;
    while index < len(items) {
        if index > 0 { output = std.Concat(output, ","); }
        output = std.Concat(output, items[index]);
        index = index + 1;
    }
    if len(output) == 0 { return std.Clone(ctx, "none"); }
    return std.Clone(ctx, output);
}

func mir_composition_request_format() str { return "gust.compiler_composition.v1"; }

func mir_composition_append(output: str, name: str, value: str, ctx: &Arena) str {
    mut result := std.Concat(output, name);
    result = std.Concat(result, "=");
    result = std.Concat(result, value);
    result = std.Concat(result, ";");
    return std.Clone(ctx, result);
}

func mir_serialize_composition_request(table: runtime.MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, mir_composition_request_format());
    output = std.Concat(output, "\ntarget: ");
    output = std.Concat(output, table.target_id);
    output = std.Concat(output, "\ntriple: ");
    output = std.Concat(output, table.target_triple);
    output = std.Concat(output, "\n");
    mut bans: std.Vector[runtime.MirRuntimeCompositionCase[ctx], ctx] := ctx[table.composition_cases];
    mut index := 0;
    while index < len(bans) {
        mut row := "composition_case:";
        row = mir_composition_append(row, "id", bans[index].case_id, ctx);
        row = mir_composition_append(row, "kind", bans[index].composition_kind, ctx);
        row = mir_composition_append(row, "participants", mir_composition_join(bans[index].participating_authorities, ctx), ctx);
        row = mir_composition_append(row, "owner", bans[index].differential_owner, ctx);
        row = mir_composition_append(row, "sentinel", bans[index].sentinel_policy, ctx);
        row = mir_composition_append(row, "target", bans[index].target_id, ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_composition_mir_to_c_witness(table: runtime.MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) str {
    mut output := "witness: gust.composition_witness.v1\ntarget: ";
    output = std.Concat(output, table.target_id);
    output = std.Concat(output, "\n");
    mut bans: std.Vector[runtime.MirRuntimeCompositionCase[ctx], ctx] := ctx[table.composition_cases];
    mut index := 0;
    while index < len(bans) {
        mut row := "case:";
        row = mir_composition_append(row, "kind", bans[index].composition_kind, ctx);
        row = mir_composition_append(row, "participants", mir_composition_join(bans[index].participating_authorities, ctx), ctx);
        row = mir_composition_append(row, "owner", bans[index].differential_owner, ctx);
        row = mir_composition_append(row, "sentinel", bans[index].sentinel_policy, ctx);
        row = mir_composition_append(row, "linkage", "every_migrated_authority_participates_in_at_least_one_composition", ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}
