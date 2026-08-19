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

func mir_target_support_request_format() str { return "gust.compiler_target_support.v1"; }
func mir_target_support_witness_format() str { return "gust.target_support_witness.v1"; }

func mir_target_support_body(table: target.MirTargetAuthorityTable[ctx], tuple: target.MirTargetSupportTuple[ctx], header: str, ctx: &Arena) str {
    mut validation := target.mir_target_tuple_validate(tuple, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, header);
    output = std.Concat(output, "\nauthority: ");
    output = std.Concat(output, table.semantic_authority);
    output = std.Concat(output, "\n");
    mut row := "target_support:";
    row = mir_target_append(row, "tuple_id", tuple.tuple_id, ctx);
    row = mir_target_append(row, "target_id", tuple.target_id, ctx);
    row = mir_target_append(row, "decision", tuple.support_decision, ctx);
    row = mir_target_append(row, "complete", std.FormatInt(target.mir_target_tuple_is_complete(tuple, ctx)), ctx);
    output = std.Concat(output, row);
    output = std.Concat(output, "\n");
    output = std.Concat(output, mir_target_element_row(tuple.compiler_element, ctx));
    output = std.Concat(output, mir_target_element_row(tuple.runtime_package_element, ctx));
    output = std.Concat(output, mir_target_element_row(tuple.linker_element, ctx));
    output = std.Concat(output, mir_target_element_row(tuple.abi_element, ctx));
    return std.Clone(ctx, output);
}

func mir_target_element_row(element: target.MirTargetSupportElement[ctx], ctx: &Arena) str {
    mut row := "support_element:";
    row = mir_target_append(row, "kind", element.element_kind, ctx);
    row = mir_target_append(row, "owner", element.owning_authority, ctx);
    row = mir_target_append(row, "evidence", element.evidence_id, ctx);
    row = mir_target_append(row, "present", std.FormatInt(element.present), ctx);
    row = mir_target_append(row, "compatible", std.FormatInt(element.compatible), ctx);
    row = std.Concat(row, "\n");
    return std.Clone(ctx, row);
}

func mir_serialize_target_support_request(table: target.MirTargetAuthorityTable[ctx], tuple: target.MirTargetSupportTuple[ctx], ctx: &Arena) str {
    return mir_target_support_body(table, tuple, mir_target_support_request_format(), ctx);
}

func mir_target_support_mir_to_c_witness(table: target.MirTargetAuthorityTable[ctx], tuple: target.MirTargetSupportTuple[ctx], ctx: &Arena) str {
    return mir_target_support_body(table, tuple, mir_target_support_witness_format(), ctx);
}

func mir_object_format_request_format() str { return "gust.compiler_object_format.v1"; }
func mir_object_format_witness_format() str { return "gust.object_format_witness.v1"; }

func mir_object_format_body(descriptor: target.MirObjectFormatDescriptor[ctx], operating_system: str, header: str, ctx: &Arena) str {
    mut validation := target.mir_object_format_validate(descriptor, operating_system, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, header);
    output = std.Concat(output, "\nauthority: compiler/mir_target_authority.gst\n");
    mut row := "object_format:";
    row = mir_target_append(row, "target_id", descriptor.target_id, ctx);
    row = mir_target_append(row, "object_format", descriptor.object_format, ctx);
    row = mir_target_append(row, "os", operating_system, ctx);
    row = mir_target_append(row, "derived_from", descriptor.derived_from, ctx);
    row = mir_target_append(row, "max_align", std.FormatInt(descriptor.max_section_alignment), ctx);
    output = std.Concat(output, row);
    output = std.Concat(output, "\n");
    mut sections: std.Vector[target.MirObjectSection[ctx], ctx] := ctx[descriptor.sections];
    mut index := 0;
    while index < len(sections) {
        mut section_row := "object_section:";
        section_row = mir_target_append(section_row, "kind", sections[index].section_kind, ctx);
        section_row = mir_target_append(section_row, "name", sections[index].section_name, ctx);
        section_row = mir_target_append(section_row, "align", std.FormatInt(sections[index].alignment), ctx);
        output = std.Concat(output, section_row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_serialize_object_format_request(descriptor: target.MirObjectFormatDescriptor[ctx], operating_system: str, ctx: &Arena) str {
    return mir_object_format_body(descriptor, operating_system, mir_object_format_request_format(), ctx);
}

func mir_object_format_mir_to_c_witness(descriptor: target.MirObjectFormatDescriptor[ctx], operating_system: str, ctx: &Arena) str {
    return mir_object_format_body(descriptor, operating_system, mir_object_format_witness_format(), ctx);
}
