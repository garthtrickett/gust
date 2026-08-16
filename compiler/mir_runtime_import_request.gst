// Phase 17.5 runtime-import request and MIR-to-C witness.
//
// The request is the compiler-produced description of every stable
// runtime-library import for one target. Cranelift and MIR-to-C both consume it
// and must agree byte for byte on the resulting witness. Neither backend keeps
// its own symbol spelling or signature table.

import "mir_runtime_boundary_authority.gst" as runtime;

func mir_runtime_import_request_format() str { return "gust.compiler_runtime_import.v1"; }

func mir_runtime_import_append(output: str, name: str, value: str, ctx: &Arena) str {
    mut result := std.Concat(output, name);
    result = std.Concat(result, "=");
    result = std.Concat(result, value);
    result = std.Concat(result, ";");
    return std.Clone(ctx, result);
}

// Deterministic row order follows the compiler-owned declaration order, so the
// request never depends on hashing, file order, or linker discovery.
func mir_serialize_runtime_import_request(table: runtime.MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, mir_runtime_import_request_format());
    output = std.Concat(output, "\n");
    output = std.Concat(output, "target: ");
    output = std.Concat(output, table.target_id);
    output = std.Concat(output, "\n");
    output = std.Concat(output, "triple: ");
    output = std.Concat(output, table.target_triple);
    output = std.Concat(output, "\n");
    mut imports: std.Vector[runtime.MirRuntimeImportDeclaration[ctx], ctx] := ctx[table.import_declarations];
    mut index := 0;
    while index < len(imports) {
        mut row := "runtime_import:";
        row = mir_runtime_import_append(row, "id", imports[index].import_id, ctx);
        row = mir_runtime_import_append(row, "helper", imports[index].helper_id, ctx);
        row = mir_runtime_import_append(row, "symbol", imports[index].symbol_id, ctx);
        row = mir_runtime_import_append(row, "spelling", imports[index].external_spelling, ctx);
        row = mir_runtime_import_append(row, "version", imports[index].symbol_version, ctx);
        row = mir_runtime_import_append(row, "function_abi", imports[index].function_abi_id, ctx);
        row = mir_runtime_import_append(row, "component", imports[index].component_id, ctx);
        row = mir_runtime_import_append(row, "package", imports[index].package_id, ctx);
        row = mir_runtime_import_append(row, "target", imports[index].target_id, ctx);
        row = mir_runtime_import_append(row, "applicability", imports[index].target_applicability, ctx);
        row = mir_runtime_import_append(row, "side_effects", imports[index].side_effect_policy, ctx);
        row = mir_runtime_import_append(row, "failure", imports[index].failure_policy, ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

// The MIR-to-C witness. Cranelift must reproduce this exactly; any divergence is
// a backend that has taken ownership of a decision the compiler already made.
func mir_runtime_import_mir_to_c_witness(table: runtime.MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) str {
    mut output := "witness: gust.runtime_import_witness.v1\n";
    output = std.Concat(output, "target: ");
    output = std.Concat(output, table.target_id);
    output = std.Concat(output, "\n");
    mut imports: std.Vector[runtime.MirRuntimeImportDeclaration[ctx], ctx] := ctx[table.import_declarations];
    mut index := 0;
    while index < len(imports) {
        mut row := "import:";
        row = mir_runtime_import_append(row, "spelling", imports[index].external_spelling, ctx);
        row = mir_runtime_import_append(row, "version", imports[index].symbol_version, ctx);
        row = mir_runtime_import_append(row, "function_abi", imports[index].function_abi_id, ctx);
        row = mir_runtime_import_append(row, "component", imports[index].component_id, ctx);
        row = mir_runtime_import_append(row, "package", imports[index].package_id, ctx);
        row = mir_runtime_import_append(row, "side_effects", imports[index].side_effect_policy, ctx);
        row = mir_runtime_import_append(row, "failure", imports[index].failure_policy, ctx);
        row = mir_runtime_import_append(row, "linkage", "direct_external_call_no_generated_c_glue", ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}
