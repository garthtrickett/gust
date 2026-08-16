// Phase 17.6 Rust runtime component request and MIR-to-C witness.
//
// The request describes every selected Rust runtime component for one target.
// Cranelift and MIR-to-C both consume it and must agree byte for byte. Neither
// backend keeps its own view of which Rust symbols exist or how they are spelled.

import "mir_runtime_boundary_authority.gst" as runtime;

func mir_rust_runtime_request_format() str { return "gust.compiler_rust_runtime.v1"; }

func mir_rust_runtime_append(output: str, name: str, value: str, ctx: &Arena) str {
    mut result := std.Concat(output, name);
    result = std.Concat(result, "=");
    result = std.Concat(result, value);
    result = std.Concat(result, ";");
    return std.Clone(ctx, result);
}

func mir_rust_runtime_join(values: Index[std.Vector[str, ctx], ctx], ctx: &Arena) str {
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

// Row order follows the compiler-owned declaration order, so the request never
// depends on hashing, directory order, or linker discovery.
func mir_serialize_rust_runtime_request(table: runtime.MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, mir_rust_runtime_request_format());
    output = std.Concat(output, "\ntarget: ");
    output = std.Concat(output, table.target_id);
    output = std.Concat(output, "\ntriple: ");
    output = std.Concat(output, table.target_triple);
    output = std.Concat(output, "\n");
    mut components: std.Vector[runtime.MirRuntimeRustComponent[ctx], ctx] := ctx[table.rust_components];
    mut index := 0;
    while index < len(components) {
        mut row := "rust_component:";
        row = mir_rust_runtime_append(row, "id", components[index].rust_component_id, ctx);
        row = mir_rust_runtime_append(row, "component", components[index].component_id, ctx);
        row = mir_rust_runtime_append(row, "ownership", components[index].source_ownership, ctx);
        row = mir_rust_runtime_append(row, "exports", mir_rust_runtime_join(components[index].exported_symbol_ids, ctx), ctx);
        row = mir_rust_runtime_append(row, "imports", mir_rust_runtime_join(components[index].imported_symbol_ids, ctx), ctx);
        row = mir_rust_runtime_append(row, "abi", components[index].runtime_abi_id, ctx);
        row = mir_rust_runtime_append(row, "target", components[index].target_id, ctx);
        row = mir_rust_runtime_append(row, "applicability", components[index].target_applicability, ctx);
        row = mir_rust_runtime_append(row, "object_form", components[index].object_form, ctx);
        row = mir_rust_runtime_append(row, "panic_boundary", components[index].panic_boundary, ctx);
        row = mir_rust_runtime_append(row, "allocation_boundary", components[index].allocation_boundary, ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

// The MIR-to-C witness. Cranelift must reproduce this exactly.
func mir_rust_runtime_mir_to_c_witness(table: runtime.MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) str {
    mut output := "witness: gust.rust_runtime_witness.v1\ntarget: ";
    output = std.Concat(output, table.target_id);
    output = std.Concat(output, "\n");
    mut components: std.Vector[runtime.MirRuntimeRustComponent[ctx], ctx] := ctx[table.rust_components];
    mut index := 0;
    while index < len(components) {
        mut row := "component:";
        row = mir_rust_runtime_append(row, "component", components[index].component_id, ctx);
        row = mir_rust_runtime_append(row, "ownership", components[index].source_ownership, ctx);
        row = mir_rust_runtime_append(row, "exports", mir_rust_runtime_join(components[index].exported_symbol_ids, ctx), ctx);
        row = mir_rust_runtime_append(row, "object_form", components[index].object_form, ctx);
        row = mir_rust_runtime_append(row, "panic_boundary", components[index].panic_boundary, ctx);
        row = mir_rust_runtime_append(row, "allocation_boundary", components[index].allocation_boundary, ctx);
        row = mir_rust_runtime_append(row, "linkage", "independently_compiled_component_no_source_specific_c_generation", ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}
