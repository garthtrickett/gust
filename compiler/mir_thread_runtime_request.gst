// Phase 17.12 threading runtime request and MIR-to-C witness.
//
// Records every banned C wrapper class on the native path together with the
// compiler-owned thing that replaced it. The evidence policy is the load-bearing
// field: explicit Cranelift must succeed with the C compiler unavailable, which
// is a demonstration rather than a declaration that the glue is gone.

import "mir_runtime_boundary_authority.gst" as runtime;

func mir_thread_request_format() str { return "gust.compiler_thread_runtime.v1"; }

func mir_thread_append(output: str, name: str, value: str, ctx: &Arena) str {
    mut result := std.Concat(output, name);
    result = std.Concat(result, "=");
    result = std.Concat(result, value);
    result = std.Concat(result, ";");
    return std.Clone(ctx, result);
}

func mir_serialize_thread_runtime_request(table: runtime.MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, mir_thread_request_format());
    output = std.Concat(output, "\ntarget: ");
    output = std.Concat(output, table.target_id);
    output = std.Concat(output, "\ntriple: ");
    output = std.Concat(output, table.target_triple);
    output = std.Concat(output, "\n");
    mut bans: std.Vector[runtime.MirRuntimeThreadContract[ctx], ctx] := ctx[table.thread_contracts];
    mut index := 0;
    while index < len(bans) {
        mut row := "thread_contract:";
        row = mir_thread_append(row, "id", bans[index].thread_contract_id, ctx);
        row = mir_thread_append(row, "helper", bans[index].helper_id, ctx);
        row = mir_thread_append(row, "symbol", bans[index].symbol_id, ctx);
        row = mir_thread_append(row, "operation", bans[index].thread_operation, ctx);
        row = mir_thread_append(row, "system_library", bans[index].system_library_dependency, ctx);
        row = mir_thread_append(row, "lifetime", bans[index].lifetime_constraint, ctx);
        row = mir_thread_append(row, "cancellation", bans[index].cancellation_policy, ctx);
        row = mir_thread_append(row, "failure", bans[index].failure_form, ctx);
        row = mir_thread_append(row, "target", bans[index].target_id, ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_thread_runtime_mir_to_c_witness(table: runtime.MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) str {
    mut output := "witness: gust.thread_runtime_witness.v1\ntarget: ";
    output = std.Concat(output, table.target_id);
    output = std.Concat(output, "\n");
    mut bans: std.Vector[runtime.MirRuntimeThreadContract[ctx], ctx] := ctx[table.thread_contracts];
    mut index := 0;
    while index < len(bans) {
        mut row := "contract:";
        row = mir_thread_append(row, "helper", bans[index].helper_id, ctx);
        row = mir_thread_append(row, "operation", bans[index].thread_operation, ctx);
        row = mir_thread_append(row, "system_library", bans[index].system_library_dependency, ctx);
        row = mir_thread_append(row, "lifetime", bans[index].lifetime_constraint, ctx);
        row = mir_thread_append(row, "cancellation", bans[index].cancellation_policy, ctx);
        row = mir_thread_append(row, "failure", bans[index].failure_form, ctx);
        row = mir_thread_append(row, "linkage", "thread_operations_use_their_classified_explicit_runtime_path", ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}
