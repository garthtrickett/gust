// Phase 17.7 retained C runtime component request and MIR-to-C witness.
//
// Describes every retained C component for one target: its owned sources, its
// versioned exports, and the retention reason and removal criterion that make
// the retention temporary by contract rather than open-ended.

import "mir_runtime_boundary_authority.gst" as runtime;

func mir_retained_c_request_format() str { return "gust.compiler_retained_c_runtime.v1"; }

func mir_retained_c_append(output: str, name: str, value: str, ctx: &Arena) str {
    mut result := std.Concat(output, name);
    result = std.Concat(result, "=");
    result = std.Concat(result, value);
    result = std.Concat(result, ";");
    return std.Clone(ctx, result);
}

func mir_retained_c_join(values: Index[std.Vector[str, ctx], ctx], ctx: &Arena) str {
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

func mir_serialize_retained_c_request(table: runtime.MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, mir_retained_c_request_format());
    output = std.Concat(output, "\ntarget: ");
    output = std.Concat(output, table.target_id);
    output = std.Concat(output, "\ntriple: ");
    output = std.Concat(output, table.target_triple);
    output = std.Concat(output, "\n");
    mut components: std.Vector[runtime.MirRuntimeRetainedCComponent[ctx], ctx] := ctx[table.retained_c_components];
    mut index := 0;
    while index < len(components) {
        mut row := "retained_c:";
        row = mir_retained_c_append(row, "id", components[index].retained_component_id, ctx);
        row = mir_retained_c_append(row, "component", components[index].component_id, ctx);
        row = mir_retained_c_append(row, "sources", mir_retained_c_join(components[index].owned_source_paths, ctx), ctx);
        row = mir_retained_c_append(row, "exports", mir_retained_c_join(components[index].exported_symbol_ids, ctx), ctx);
        row = mir_retained_c_append(row, "imports", mir_retained_c_join(components[index].imported_symbol_ids, ctx), ctx);
        row = mir_retained_c_append(row, "abi", components[index].runtime_abi_id, ctx);
        row = mir_retained_c_append(row, "target", components[index].target_id, ctx);
        row = mir_retained_c_append(row, "applicability", components[index].target_applicability, ctx);
        row = mir_retained_c_append(row, "build_inputs", components[index].build_inputs, ctx);
        row = mir_retained_c_append(row, "retention_reason", components[index].retention_reason, ctx);
        row = mir_retained_c_append(row, "removal_criterion", components[index].removal_criterion, ctx);
        row = mir_retained_c_append(row, "destination_phase", components[index].destination_phase, ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_retained_c_mir_to_c_witness(table: runtime.MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) str {
    mut output := "witness: gust.retained_c_runtime_witness.v1\ntarget: ";
    output = std.Concat(output, table.target_id);
    output = std.Concat(output, "\n");
    mut components: std.Vector[runtime.MirRuntimeRetainedCComponent[ctx], ctx] := ctx[table.retained_c_components];
    mut index := 0;
    while index < len(components) {
        mut row := "component:";
        row = mir_retained_c_append(row, "component", components[index].component_id, ctx);
        row = mir_retained_c_append(row, "sources", mir_retained_c_join(components[index].owned_source_paths, ctx), ctx);
        row = mir_retained_c_append(row, "exports", mir_retained_c_join(components[index].exported_symbol_ids, ctx), ctx);
        row = mir_retained_c_append(row, "retention_reason", components[index].retention_reason, ctx);
        row = mir_retained_c_append(row, "removal_criterion", components[index].removal_criterion, ctx);
        row = mir_retained_c_append(row, "destination_phase", components[index].destination_phase, ctx);
        row = mir_retained_c_append(row, "linkage", "separately_compiled_component_no_program_derived_c_source", ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}
