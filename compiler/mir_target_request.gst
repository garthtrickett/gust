// Phase 18.1 target request and MIR-to-C witness.
//
// The request carries the compiler-selected target identity to the worker. The
// worker validates it and never selects, widens, or substitutes a target. The
// witness records how the target was selected, so an explicit request that
// consulted the host is visible as evidence rather than hidden in backend code.

import "mir_target_authority.gst" as target;

func mir_target_request_format() str { return "gust.compiler_target_identity.v1"; }

func mir_target_append(output: str, name: str, value: str, ctx: &Arena) str {
    mut result := std.Concat(output, name);
    result = std.Concat(result, "=");
    result = std.Concat(result, value);
    result = std.Concat(result, ";");
    return std.Clone(ctx, result);
}

func mir_serialize_target_request(table: target.MirTargetAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := target.mir_target_authority_table_validate(table, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, mir_target_request_format());
    output = std.Concat(output, "\nauthority: ");
    output = std.Concat(output, table.semantic_authority);
    output = std.Concat(output, "\n");
    mut identities: std.Vector[target.MirTargetIdentity[ctx], ctx] := ctx[table.identities];
    mut index := 0;
    while index < len(identities) {
        mut row := "target_identity:";
        row = mir_target_append(row, "target_id", identities[index].target_id, ctx);
        row = mir_target_append(row, "triple", identities[index].target_triple, ctx);
        row = mir_target_append(row, "arch", identities[index].architecture, ctx);
        row = mir_target_append(row, "vendor", identities[index].vendor, ctx);
        row = mir_target_append(row, "os", identities[index].operating_system, ctx);
        row = mir_target_append(row, "env", identities[index].environment, ctx);
        row = mir_target_append(row, "ptr_bits", std.FormatInt(identities[index].pointer_width_bits), ctx);
        row = mir_target_append(row, "endian", identities[index].endianness, ctx);
        row = mir_target_append(row, "layout_agreement", identities[index].layout_agreement, ctx);
        row = mir_target_append(row, "selection", identities[index].selection_id, ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    mut selections: std.Vector[target.MirTargetSelection[ctx], ctx] := ctx[table.selections];
    mut selection_index := 0;
    while selection_index < len(selections) {
        mut row := "target_selection:";
        row = mir_target_append(row, "selection_id", selections[selection_index].selection_id, ctx);
        row = mir_target_append(row, "mode", selections[selection_index].selection_mode, ctx);
        row = mir_target_append(row, "requested", selections[selection_index].requested_triple, ctx);
        row = mir_target_append(row, "consulted_host", std.FormatInt(selections[selection_index].consulted_host), ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        selection_index = selection_index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_target_witness_format() str { return "gust.target_identity_witness.v1"; }

// The witness is the request with its format header replaced and the layout
// agreement restated from the authority constant, so a request that merely
// claimed agreement cannot produce a witness asserting it.
func mir_target_mir_to_c_witness(table: target.MirTargetAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := target.mir_target_authority_table_validate(table, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, mir_target_witness_format());
    output = std.Concat(output, "\nauthority: ");
    output = std.Concat(output, table.semantic_authority);
    output = std.Concat(output, "\n");
    mut identities: std.Vector[target.MirTargetIdentity[ctx], ctx] := ctx[table.identities];
    mut index := 0;
    while index < len(identities) {
        mut row := "target_identity:";
        row = mir_target_append(row, "target_id", identities[index].target_id, ctx);
        row = mir_target_append(row, "triple", identities[index].target_triple, ctx);
        row = mir_target_append(row, "arch", identities[index].architecture, ctx);
        row = mir_target_append(row, "vendor", identities[index].vendor, ctx);
        row = mir_target_append(row, "os", identities[index].operating_system, ctx);
        row = mir_target_append(row, "env", identities[index].environment, ctx);
        row = mir_target_append(row, "ptr_bits", std.FormatInt(identities[index].pointer_width_bits), ctx);
        row = mir_target_append(row, "endian", identities[index].endianness, ctx);
        row = mir_target_append(row, "layout_agreement", "agrees_with_phase14_target_layout_authority", ctx);
        row = mir_target_append(row, "selection", identities[index].selection_id, ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    mut selections: std.Vector[target.MirTargetSelection[ctx], ctx] := ctx[table.selections];
    mut selection_index := 0;
    while selection_index < len(selections) {
        mut row := "target_selection:";
        row = mir_target_append(row, "selection_id", selections[selection_index].selection_id, ctx);
        row = mir_target_append(row, "mode", selections[selection_index].selection_mode, ctx);
        row = mir_target_append(row, "requested", selections[selection_index].requested_triple, ctx);
        row = mir_target_append(row, "consulted_host", std.FormatInt(selections[selection_index].consulted_host), ctx);
        output = std.Concat(output, row);
        output = std.Concat(output, "\n");
        selection_index = selection_index + 1;
    }
    return std.Clone(ctx, output);
}
