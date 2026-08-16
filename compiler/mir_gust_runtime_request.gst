// Phase 17.8 pure Gust runtime module request and MIR-to-C witness.
//
// Describes every selected pure Gust runtime module for one target: its source,
// its exports, its allowed dependencies, and the lowering route it was compiled
// through. The route is recorded so a bespoke path cannot pass unnoticed.

import "mir_runtime_boundary_authority.gst" as runtime;

func mir_gust_runtime_request_format() str { return "gust.compiler_gust_runtime.v1"; }

func mir_gust_runtime_append(output: str, name: str, value: str, ctx: &Arena) str {
    mut result := std.Concat(output, name);
    result = std.Concat(result, "=");
    result = std.Concat(result, value);
    result = std.Concat(result, ";");
    return std.Clone(ctx, result);
}

func mir_gust_runtime_join(values: Index[std.Vector[str, ctx], ctx], ctx: &Arena) str {
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

func mir_serialize_gust_runtime_request(table: runtime.MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, mir_gust_runtime_request_format());
    output = std.Concat(output, "\ntarget: ");
    output = std.Concat(output, table.target_id);
    output = std.Concat(output, "\ntriple: ");
    output = std.Concat(output, table.target_triple);
    output = std.Concat(output, "\n");
    mut modules: std.Vector[runtime.MirRuntimeGustModule[ctx], ctx] := ctx[table.gust_modules];
    mut index := 0;
    while index < len(modules) {
        mut row := "gust_module:";
        row = mir_gust_runtime_append(row, "id", modules[index].gust_module_id, ctx);
        row = mir_gust_runtime_append(row, "component", modules[index].component_id, ctx);
        row = mir_gust_runtime_append(row, "source", modules[index].module_source_path, ctx);
        row = mir_gust_runtime_append(row, "exports", mir_gust_runtime_join(modules[index].exported_symbol_ids, ctx), ctx);
        row = mir_gust_runtime_append(row, "imports", mir_gust_runtime_join(modules[index].imported_symbol_ids, ctx), ctx);
        row = mir_gust_runtime_append(row, "dependencies", mir_gust_runtime_join(modules[index].allowed_dependency_ids, ctx), ctx);
        row = mir_gust_runtime_append(row, "abi", modules[index].runtime_abi_id, ctx);
        row = mir_gust_runtime_append(row, "target", modules[index].target_id, ctx);
        row = mir_gust_runtime_append(row, "applicability", modules[index].target_applicability, ctx);
        row = mir_gust_runtime_append(row, "lowering_route", modules[index].lowering_route, ctx);
        row = mir_gust_runtime_append(row, "initialization", modules[index].initialization_policy, ctx);
        row = mir_gust_runtime_append(row, "failure", modules[index].failure_policy, ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_gust_runtime_mir_to_c_witness(table: runtime.MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) str {
    mut output := "witness: gust.gust_runtime_witness.v1\ntarget: ";
    output = std.Concat(output, table.target_id);
    output = std.Concat(output, "\n");
    mut modules: std.Vector[runtime.MirRuntimeGustModule[ctx], ctx] := ctx[table.gust_modules];
    mut index := 0;
    while index < len(modules) {
        mut row := "module:";
        row = mir_gust_runtime_append(row, "component", modules[index].component_id, ctx);
        row = mir_gust_runtime_append(row, "source", modules[index].module_source_path, ctx);
        row = mir_gust_runtime_append(row, "exports", mir_gust_runtime_join(modules[index].exported_symbol_ids, ctx), ctx);
        row = mir_gust_runtime_append(row, "lowering_route", modules[index].lowering_route, ctx);
        row = mir_gust_runtime_append(row, "initialization", modules[index].initialization_policy, ctx);
        row = mir_gust_runtime_append(row, "failure", modules[index].failure_policy, ctx);
        row = mir_gust_runtime_append(row, "linkage", "generic_canonical_mir_route_no_bespoke_recognition", ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}
