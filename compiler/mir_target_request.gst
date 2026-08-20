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

func mir_relocation_request_format() str { return "gust.compiler_relocation.v1"; }
func mir_relocation_witness_format() str { return "gust.relocation_witness.v1"; }

func mir_relocation_body(model: target.MirRelocationModel[ctx], relocation: target.MirRelocation[ctx], header: str, ctx: &Arena) str {
    mut validation := target.mir_relocation_validate(model, relocation, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, header);
    output = std.Concat(output, "\nauthority: compiler/mir_target_authority.gst\n");
    mut model_row := "relocation_model:";
    model_row = mir_target_append(model_row, "target_id", model.target_id, ctx);
    model_row = mir_target_append(model_row, "object_format", model.object_format, ctx);
    model_row = mir_target_append(model_row, "arch", model.architecture, ctx);
    model_row = mir_target_append(model_row, "stage", model.validation_stage, ctx);
    output = std.Concat(output, model_row);
    output = std.Concat(output, "\n");
    mut row := "relocation:";
    row = mir_target_append(row, "kind", relocation.relocation_kind, ctx);
    row = mir_target_append(row, "section", relocation.section_kind, ctx);
    row = mir_target_append(row, "offset", std.FormatInt(relocation.offset), ctx);
    row = mir_target_append(row, "addend", std.FormatInt(relocation.addend), ctx);
    row = mir_target_append(row, "symbol", relocation.symbol_identity, ctx);
    row = mir_target_append(row, "absolute", std.FormatInt(target.mir_relocation_kind_is_absolute(relocation.relocation_kind, ctx)), ctx);
    output = std.Concat(output, row);
    output = std.Concat(output, "\n");
    return std.Clone(ctx, output);
}

func mir_serialize_relocation_request(model: target.MirRelocationModel[ctx], relocation: target.MirRelocation[ctx], ctx: &Arena) str {
    return mir_relocation_body(model, relocation, mir_relocation_request_format(), ctx);
}

func mir_relocation_mir_to_c_witness(model: target.MirRelocationModel[ctx], relocation: target.MirRelocation[ctx], ctx: &Arena) str {
    return mir_relocation_body(model, relocation, mir_relocation_witness_format(), ctx);
}

func mir_target_abi_request_format() str { return "gust.compiler_target_abi.v1"; }
func mir_target_abi_witness_format() str { return "gust.target_abi_witness.v1"; }

func mir_target_abi_body(selection: target.MirTargetAbiSelection[ctx], accepted: str, header: str, ctx: &Arena) str {
    mut validation := target.mir_target_abi_selection_validate(selection, accepted, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, header);
    output = std.Concat(output, "\nauthority: compiler/mir_target_authority.gst\n");
    mut row := "target_abi:";
    row = mir_target_append(row, "target_id", selection.target_id, ctx);
    row = mir_target_append(row, "abi_id", selection.selected_abi_id, ctx);
    row = mir_target_append(row, "owner", selection.owning_authority, ctx);
    row = mir_target_append(row, "compatibility", selection.compatibility_decision, ctx);
    row = mir_target_append(row, "platform_convention", selection.platform_convention_status, ctx);
    output = std.Concat(output, row);
    output = std.Concat(output, "\n");
    return std.Clone(ctx, output);
}

func mir_serialize_target_abi_request(selection: target.MirTargetAbiSelection[ctx], accepted: str, ctx: &Arena) str {
    return mir_target_abi_body(selection, accepted, mir_target_abi_request_format(), ctx);
}

func mir_target_abi_mir_to_c_witness(selection: target.MirTargetAbiSelection[ctx], accepted: str, ctx: &Arena) str {
    return mir_target_abi_body(selection, accepted, mir_target_abi_witness_format(), ctx);
}

func mir_target_package_request_format() str { return "gust.compiler_target_package.v1"; }
func mir_target_package_witness_format() str { return "gust.target_package_witness.v1"; }

func mir_target_package_body(selection: target.MirTargetPackageSelection[ctx], descriptor_format: str, header: str, ctx: &Arena) str {
    mut validation := target.mir_target_package_selection_validate(selection, descriptor_format, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, header);
    output = std.Concat(output, "\nauthority: compiler/mir_target_authority.gst\n");
    mut row := "target_package:";
    row = mir_target_append(row, "target_id", selection.target_id, ctx);
    row = mir_target_append(row, "package_version", selection.selected_package_version, ctx);
    row = mir_target_append(row, "form", selection.package_form, ctx);
    row = mir_target_append(row, "owner", selection.owning_authority, ctx);
    row = mir_target_append(row, "object_format", selection.declared_object_format, ctx);
    row = mir_target_append(row, "descriptor_format", descriptor_format, ctx);
    row = mir_target_append(row, "compatibility", selection.compatibility_decision, ctx);
    output = std.Concat(output, row);
    output = std.Concat(output, "\n");
    return std.Clone(ctx, output);
}

func mir_serialize_target_package_request(selection: target.MirTargetPackageSelection[ctx], descriptor_format: str, ctx: &Arena) str {
    return mir_target_package_body(selection, descriptor_format, mir_target_package_request_format(), ctx);
}

func mir_target_package_mir_to_c_witness(selection: target.MirTargetPackageSelection[ctx], descriptor_format: str, ctx: &Arena) str {
    return mir_target_package_body(selection, descriptor_format, mir_target_package_witness_format(), ctx);
}

func mir_linker_request_format() str { return "gust.compiler_linker_policy.v1"; }
func mir_linker_witness_format() str { return "gust.linker_policy_witness.v1"; }

func mir_linker_body(descriptor: target.MirLinkerDescriptor[ctx], target_format: str, header: str, ctx: &Arena) str {
    mut validation := target.mir_linker_descriptor_validate(descriptor, target_format, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, header);
    output = std.Concat(output, "\nauthority: compiler/mir_target_authority.gst\n");
    mut row := "linker:";
    row = mir_target_append(row, "linker_id", descriptor.linker_id, ctx);
    row = mir_target_append(row, "target_id", descriptor.target_id, ctx);
    row = mir_target_append(row, "driver", descriptor.driver_name, ctx);
    row = mir_target_append(row, "discovery", descriptor.discovery_result, ctx);
    row = mir_target_append(row, "object_format", descriptor.supported_object_format, ctx);
    row = mir_target_append(row, "target_format", target_format, ctx);
    row = mir_target_append(row, "invocation_owner", descriptor.invocation_owner, ctx);
    row = mir_target_append(row, "argument", descriptor.probe_argument, ctx);
    output = std.Concat(output, row);
    output = std.Concat(output, "\n");
    return std.Clone(ctx, output);
}

func mir_serialize_linker_request(descriptor: target.MirLinkerDescriptor[ctx], target_format: str, ctx: &Arena) str {
    return mir_linker_body(descriptor, target_format, mir_linker_request_format(), ctx);
}

func mir_linker_mir_to_c_witness(descriptor: target.MirLinkerDescriptor[ctx], target_format: str, ctx: &Arena) str {
    return mir_linker_body(descriptor, target_format, mir_linker_witness_format(), ctx);
}

func mir_link_mode_request_format() str { return "gust.compiler_link_mode.v1"; }
func mir_link_mode_witness_format() str { return "gust.link_mode_witness.v1"; }

func mir_link_mode_body(decision: target.MirLinkModeDecision[ctx], header: str, ctx: &Arena) str {
    mut validation := target.mir_link_mode_validate(decision, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, header);
    output = std.Concat(output, "\nauthority: compiler/mir_target_authority.gst\n");
    mut row := "link_mode:";
    row = mir_target_append(row, "target_id", decision.target_id, ctx);
    row = mir_target_append(row, "package_form", decision.required_package_form, ctx);
    row = mir_target_append(row, "selected_mode", decision.selected_mode, ctx);
    row = mir_target_append(row, "derived_mode", target.mir_link_mode_for_package_form(decision.required_package_form, ctx), ctx);
    output = std.Concat(output, row);
    output = std.Concat(output, "\n");
    return std.Clone(ctx, output);
}

func mir_serialize_link_mode_request(decision: target.MirLinkModeDecision[ctx], ctx: &Arena) str {
    return mir_link_mode_body(decision, mir_link_mode_request_format(), ctx);
}

func mir_link_mode_mir_to_c_witness(decision: target.MirLinkModeDecision[ctx], ctx: &Arena) str {
    return mir_link_mode_body(decision, mir_link_mode_witness_format(), ctx);
}

func mir_cross_pair_request_format() str { return "gust.compiler_cross_pair.v1"; }
func mir_cross_pair_witness_format() str { return "gust.cross_pair_witness.v1"; }

func mir_cross_pair_body(pair: target.MirHostTargetPair[ctx], header: str, ctx: &Arena) str {
    mut validation := target.mir_host_target_pair_validate(pair, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, header);
    output = std.Concat(output, "\nauthority: compiler/mir_target_authority.gst\n");
    mut row := "cross_pair:";
    row = mir_target_append(row, "host", pair.host_triple, ctx);
    row = mir_target_append(row, "target", pair.target_triple, ctx);
    row = mir_target_append(row, "classification", target.mir_cross_classification(pair.host_triple, pair.target_triple, ctx), ctx);
    row = mir_target_append(row, "linker_discovered", std.FormatInt(pair.linker_discovered), ctx);
    row = mir_target_append(row, "declared", std.FormatInt(pair.declared), ctx);
    row = mir_target_append(row, "blocking_reason", pair.blocking_reason, ctx);
    output = std.Concat(output, row);
    output = std.Concat(output, "\n");
    return std.Clone(ctx, output);
}

func mir_serialize_cross_pair_request(pair: target.MirHostTargetPair[ctx], ctx: &Arena) str {
    return mir_cross_pair_body(pair, mir_cross_pair_request_format(), ctx);
}

func mir_cross_pair_mir_to_c_witness(pair: target.MirHostTargetPair[ctx], ctx: &Arena) str {
    return mir_cross_pair_body(pair, mir_cross_pair_witness_format(), ctx);
}

func mir_target_diagnostic_request_format() str { return "gust.compiler_target_diagnostic.v1"; }
func mir_target_diagnostic_witness_format() str { return "gust.target_diagnostic_witness.v1"; }

func mir_target_diagnostic_body(diagnostic: target.MirTargetDiagnostic[ctx], header: str, ctx: &Arena) str {
    mut validation := target.mir_target_diagnostic_validate(diagnostic, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, header);
    output = std.Concat(output, "\nauthority: compiler/mir_target_authority.gst\n");
    mut row := "target_diagnostic:";
    row = mir_target_append(row, "target_id", diagnostic.target_id, ctx);
    row = mir_target_append(row, "decision", diagnostic.support_decision, ctx);
    row = mir_target_append(row, "missing", diagnostic.missing_element, ctx);
    row = mir_target_append(row, "rejection", diagnostic.rejection_class, ctx);
    row = mir_target_append(row, "stage", diagnostic.failure_stage, ctx);
    output = std.Concat(output, row);
    output = std.Concat(output, "\n");
    return std.Clone(ctx, output);
}

func mir_serialize_target_diagnostic_request(diagnostic: target.MirTargetDiagnostic[ctx], ctx: &Arena) str {
    return mir_target_diagnostic_body(diagnostic, mir_target_diagnostic_request_format(), ctx);
}

func mir_target_diagnostic_mir_to_c_witness(diagnostic: target.MirTargetDiagnostic[ctx], ctx: &Arena) str {
    return mir_target_diagnostic_body(diagnostic, mir_target_diagnostic_witness_format(), ctx);
}

func mir_object_inspection_request_format() str { return "gust.compiler_object_inspection.v1"; }
func mir_object_inspection_witness_format() str { return "gust.object_inspection_witness.v1"; }

func mir_object_inspection_body(observation: target.MirObjectObservation[ctx], header: str, ctx: &Arena) str {
    mut validation := target.mir_object_observation_validate(observation, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, header);
    output = std.Concat(output, "\nauthority: compiler/mir_target_authority.gst\n");
    mut row := "observation:";
    row = mir_target_append(row, "symbol", observation.symbol_name, ctx);
    row = mir_target_append(row, "binding", observation.binding, ctx);
    row = mir_target_append(row, "section", observation.section_kind, ctx);
    row = mir_target_append(row, "relocation", observation.relocation_kind, ctx);
    row = mir_target_append(row, "in_plan", std.FormatInt(observation.in_compiler_plan), ctx);
    output = std.Concat(output, row);
    output = std.Concat(output, "\n");
    return std.Clone(ctx, output);
}

func mir_serialize_object_inspection_request(observation: target.MirObjectObservation[ctx], ctx: &Arena) str {
    return mir_object_inspection_body(observation, mir_object_inspection_request_format(), ctx);
}

func mir_object_inspection_mir_to_c_witness(observation: target.MirObjectObservation[ctx], ctx: &Arena) str {
    return mir_object_inspection_body(observation, mir_object_inspection_witness_format(), ctx);
}

func mir_debug_plan_request_format() str { return "gust.compiler_debug_plan.v1"; }
func mir_debug_plan_witness_format() str { return "gust.debug_plan_witness.v1"; }

func mir_debug_plan_body(plan: target.MirDebugPlan[ctx], header: str, ctx: &Arena) str {
    mut validation := target.mir_debug_plan_validate(plan, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, header);
    output = std.Concat(output, "\nauthority: compiler/mir_target_authority.gst\n");
    mut row := "debug_plan:";
    row = mir_target_append(row, "target_id", plan.target_id, ctx);
    row = mir_target_append(row, "debug_format", plan.debug_format, ctx);
    row = mir_target_append(row, "derived_from", plan.derived_from, ctx);
    row = mir_target_append(row, "level", plan.debug_level, ctx);
    row = mir_target_append(row, "included", plan.included_kind, ctx);
    row = mir_target_append(row, "excluded", plan.excluded_kind, ctx);
    output = std.Concat(output, row);
    output = std.Concat(output, "\n");
    return std.Clone(ctx, output);
}

func mir_serialize_debug_plan_request(plan: target.MirDebugPlan[ctx], ctx: &Arena) str {
    return mir_debug_plan_body(plan, mir_debug_plan_request_format(), ctx);
}

func mir_debug_plan_mir_to_c_witness(plan: target.MirDebugPlan[ctx], ctx: &Arena) str {
    return mir_debug_plan_body(plan, mir_debug_plan_witness_format(), ctx);
}

func mir_source_location_request_format() str { return "gust.compiler_source_location.v1"; }
func mir_source_location_witness_format() str { return "gust.source_location_witness.v1"; }

// `include_producer` is 0 for the request and 1 for the witness. The request
// must NOT carry produced_by: that is the field the Cranelift worker has to
// recompute for itself, and handing it the answer would turn a parity check
// into a copy check.
func mir_source_location_body(location: target.MirSourceLocation[ctx], header: str, include_producer: int, ctx: &Arena) str {
    mut validation := target.mir_source_location_validate(location, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: ";
    output = std.Concat(output, header);
    output = std.Concat(output, "\nauthority: compiler/mir_target_authority.gst\n");
    mut row := "source_location:";
    row = mir_target_append(row, "file", location.source_file, ctx);
    row = mir_target_append(row, "span", location.source_span, ctx);
    row = mir_target_append(row, "mir", location.canonical_mir_association, ctx);
    row = mir_target_append(row, "emitted", location.emitted_debug_association, ctx);
    if include_producer == 1 {
        row = mir_target_append(row, "produced_by", "canonical_mir", ctx);
    }
    output = std.Concat(output, row);
    output = std.Concat(output, "\n");
    return std.Clone(ctx, output);
}

func mir_serialize_source_location_request(location: target.MirSourceLocation[ctx], ctx: &Arena) str {
    return mir_source_location_body(location, mir_source_location_request_format(), 0, ctx);
}

func mir_source_location_mir_to_c_witness(location: target.MirSourceLocation[ctx], ctx: &Arena) str {
    return mir_source_location_body(location, mir_source_location_witness_format(), 1, ctx);
}
