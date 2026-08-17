// Phase 17.9 shim elimination request and MIR-to-C witness.
//
// Records every banned C wrapper class on the native path together with the
// compiler-owned thing that replaced it. The evidence policy is the load-bearing
// field: explicit Cranelift must succeed with the C compiler unavailable, which
// is a demonstration rather than a declaration that the glue is gone.

import "mir_runtime_boundary_authority.gst" as runtime;

func mir_shim_request_format() str { return "gust.compiler_shim_elimination.v1"; }

func mir_shim_append(output: str, name: str, value: str, ctx: &Arena) str {
    mut result := std.Concat(output, name);
    result = std.Concat(result, "=");
    result = std.Concat(result, value);
    result = std.Concat(result, ";");
    return std.Clone(ctx, result);
}

func mir_serialize_shim_elimination_request(table: runtime.MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, mir_shim_request_format());
    output = std.Concat(output, "\ntarget: ");
    output = std.Concat(output, table.target_id);
    output = std.Concat(output, "\ntriple: ");
    output = std.Concat(output, table.target_triple);
    output = std.Concat(output, "\n");
    mut bans: std.Vector[runtime.MirRuntimeShimBan[ctx], ctx] := ctx[table.shim_bans];
    mut index := 0;
    while index < len(bans) {
        mut row := "shim_ban:";
        row = mir_shim_append(row, "id", bans[index].ban_id, ctx);
        row = mir_shim_append(row, "banned_class", bans[index].banned_class, ctx);
        row = mir_shim_append(row, "obsolete_family", bans[index].obsolete_family, ctx);
        row = mir_shim_append(row, "replacement_kind", bans[index].replacement_kind, ctx);
        row = mir_shim_append(row, "replacement_component", bans[index].replacement_component_id, ctx);
        row = mir_shim_append(row, "target", bans[index].target_id, ctx);
        row = mir_shim_append(row, "evidence", bans[index].evidence_policy, ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_shim_elimination_mir_to_c_witness(table: runtime.MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) str {
    mut output := "witness: gust.shim_elimination_witness.v1\ntarget: ";
    output = std.Concat(output, table.target_id);
    output = std.Concat(output, "\n");
    mut bans: std.Vector[runtime.MirRuntimeShimBan[ctx], ctx] := ctx[table.shim_bans];
    mut index := 0;
    while index < len(bans) {
        mut row := "ban:";
        row = mir_shim_append(row, "banned_class", bans[index].banned_class, ctx);
        row = mir_shim_append(row, "obsolete_family", bans[index].obsolete_family, ctx);
        row = mir_shim_append(row, "replacement_kind", bans[index].replacement_kind, ctx);
        row = mir_shim_append(row, "replacement_component", bans[index].replacement_component_id, ctx);
        row = mir_shim_append(row, "evidence", bans[index].evidence_policy, ctx);
        row = mir_shim_append(row, "linkage", "native_path_emits_no_program_specific_c", ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}
