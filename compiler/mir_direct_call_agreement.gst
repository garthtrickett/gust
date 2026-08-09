// Phase 16.5 compiler-owned caller/callee agreement for selected direct calls.
//
// The compiler records both sides of every compatibility comparison. Backends
// consume the accepted decision and must not rebuild it from a C prototype,
// host ABI, emitted block shape, symbol spelling, or source text.

import "mir_function_abi_authority.gst" as abi;
import "mir_function_call.gst" as call_mir;

type MirDirectCallAgreement[ctx] struct {
    agreement_id: str,
    call_id: str,
    composition_kind: str,
    caller_function_id: str,
    callee_function_id: str,
    call_plan_id: str,
    declaration_abi_id: str,
    definition_abi_id: str,
    expected_abi_id: str,
    actual_abi_id: str,
    expected_signature_id: str,
    actual_signature_id: str,
    expected_calling_convention: str,
    actual_calling_convention: str,
    expected_parameters: str,
    actual_parameters: str,
    expected_results: str,
    actual_results: str,
    expected_layouts: str,
    actual_layouts: str,
    expected_classes: str,
    actual_classes: str,
    expected_extensions: str,
    actual_extensions: str,
    expected_hidden_result: str,
    actual_hidden_result: str,
    expected_resource_transfers: str,
    actual_resource_transfers: str,
    result_flow: str,
    freshness: str,
    compatible: int,
    target_id: str,
    actual_target_id: str,
    target_triple: str,
    actual_target_triple: str,
    source_location: str
}

type MirDirectCallAgreementTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    authority: str,
    inventory: str,
    agreements: Index[std.Vector[MirDirectCallAgreement[ctx], ctx], ctx]
}

type MirDirectCallAgreementValidation[ctx] struct { valid: int, reason_code: str }

func mir_direct_call_empty_agreements(ctx: &Arena) Index[std.Vector[MirDirectCallAgreement[ctx], ctx], ctx] {
    mut values: std.Vector[MirDirectCallAgreement[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirDirectCallAgreement[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_direct_call_make_empty_table(target_id: str, target_triple: str, ctx: &Arena) MirDirectCallAgreementTable[ctx] {
    mut table: MirDirectCallAgreementTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_direct_call_agreement.v1");
    table.target_id = std.Clone(ctx, target_id);
    table.target_triple = std.Clone(ctx, target_triple);
    table.authority = std.Clone(ctx, "compiler_owned_direct_call_compatibility_decision");
    table.inventory = std.Clone(ctx, "same_module_nested_recursive_mixed_aggregate_and_aggregate_result_chain");
    table.agreements = mir_direct_call_empty_agreements(ctx);
    return table;
}

func mir_direct_call_table_with_agreement(table: MirDirectCallAgreementTable[ctx], value: MirDirectCallAgreement[ctx], ctx: &Arena) MirDirectCallAgreementTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirDirectCallAgreement[ctx], ctx] := ctx[updated.agreements];
    values.Push(value);
    ctx.Set(updated.agreements, values);
    return updated;
}

func mir_direct_call_validation(valid: int, reason_code: str, ctx: &Arena) MirDirectCallAgreementValidation[ctx] {
    mut result: MirDirectCallAgreementValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_direct_call_kind_supported(value: str) int {
    if std.str_eq(value, "nested_direct") == 1 { return 1; }
    if std.str_eq(value, "direct_recursion") == 1 { return 1; }
    if std.str_eq(value, "mixed_scalar_aggregate") == 1 { return 1; }
    if std.str_eq(value, "aggregate_result_chain") == 1 { return 1; }
    return 0;
}

func mir_direct_call_agreement_table_validate(table: MirDirectCallAgreementTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], calls: call_mir.MirFunctionCallTable[ctx], ctx: &Arena) MirDirectCallAgreementValidation[ctx] {
    if std.str_eq(table.format, "gust.compiler_direct_call_agreement.v1") == 0 {
        return mir_direct_call_validation(0, "direct_call_unknown_format", ctx);
    }
    if std.str_eq(table.authority, "compiler_owned_direct_call_compatibility_decision") == 0 {
        return mir_direct_call_validation(0, "direct_call_authority_mismatch", ctx);
    }
    if std.str_eq(table.target_id, authority.target_id) == 0 || std.str_eq(table.target_triple, authority.target_triple) == 0 ||
       std.str_eq(table.target_id, calls.target_id) == 0 || std.str_eq(table.target_triple, calls.target_triple) == 0
    {
        return mir_direct_call_validation(0, "direct_call_target_mismatch", ctx);
    }
    mut values: std.Vector[MirDirectCallAgreement[ctx], ctx] := ctx[table.agreements];
    mut index := 0;
    while index < len(values) {
        mut value := values[index];
        if len(value.agreement_id) == 0 || len(value.call_id) == 0 || mir_direct_call_kind_supported(value.composition_kind) == 0 {
            return mir_direct_call_validation(0, "direct_call_record_invalid", ctx);
        }
        if std.str_eq(value.target_id, table.target_id) == 0 || std.str_eq(value.actual_target_id, table.target_id) == 0 ||
           std.str_eq(value.target_triple, table.target_triple) == 0 || std.str_eq(value.actual_target_triple, table.target_triple) == 0
        {
            return mir_direct_call_validation(0, "direct_call_target_mismatch", ctx);
        }
        mut expected := abi.mir_function_abi_by_id(authority, value.expected_abi_id, ctx);
        mut actual := abi.mir_function_abi_by_id(authority, value.actual_abi_id, ctx);
        if expected.found == 0 || actual.found == 0 {
            return mir_direct_call_validation(0, "direct_call_signature_drift", ctx);
        }
        mut plan := abi.mir_abi_call_plan(authority, value.call_id, value.expected_abi_id, ctx);
        if plan.found == 0 || std.str_eq(plan.value.call_plan_id, value.call_plan_id) == 0 ||
           std.str_eq(value.freshness, "current_compiler_plan") == 0
        {
            return mir_direct_call_validation(0, "direct_call_stale_plan", ctx);
        }
        mut declaration := call_mir.mir_function_call_declaration_by_abi(calls, value.declaration_abi_id, ctx);
        if declaration.found == 0 || std.str_eq(value.declaration_abi_id, value.definition_abi_id) == 0 ||
           std.str_eq(value.declaration_abi_id, value.expected_abi_id) == 0 ||
           std.str_eq(value.definition_abi_id, value.actual_abi_id) == 0
        {
            return mir_direct_call_validation(0, "direct_call_signature_drift", ctx);
        }
        if std.str_eq(value.expected_signature_id, value.actual_signature_id) == 0 ||
           std.str_eq(value.expected_signature_id, expected.value.signature_id) == 0 ||
           std.str_eq(value.actual_signature_id, actual.value.signature_id) == 0 ||
           std.str_eq(declaration.value.signature_id, value.expected_signature_id) == 0
        {
            return mir_direct_call_validation(0, "direct_call_signature_drift", ctx);
        }
        if std.str_eq(value.expected_calling_convention, value.actual_calling_convention) == 0 ||
           std.str_eq(value.expected_calling_convention, expected.value.calling_convention) == 0 ||
           std.str_eq(value.actual_calling_convention, actual.value.calling_convention) == 0
        {
            return mir_direct_call_validation(0, "direct_call_calling_convention_mismatch", ctx);
        }
        if std.str_eq(value.expected_parameters, value.actual_parameters) == 0 ||
           std.str_eq(value.expected_parameters, call_mir.mir_call_join(plan.value.argument_placement_ids, ctx)) == 0
        {
            return mir_direct_call_validation(0, "direct_call_parameter_permutation", ctx);
        }
        if std.str_eq(value.expected_results, value.actual_results) == 0 ||
           std.str_eq(value.expected_results, call_mir.mir_call_join(plan.value.result_placement_ids, ctx)) == 0
        {
            return mir_direct_call_validation(0, "direct_call_result_permutation", ctx);
        }
        if std.str_eq(value.expected_layouts, value.actual_layouts) == 0 || len(value.expected_layouts) == 0 {
            return mir_direct_call_validation(0, "direct_call_layout_mismatch", ctx);
        }
        if std.str_eq(value.expected_classes, value.actual_classes) == 0 ||
           std.str_eq(value.expected_extensions, value.actual_extensions) == 0
        {
            return mir_direct_call_validation(0, "direct_call_placement_class_mismatch", ctx);
        }
        if std.str_eq(value.expected_hidden_result, value.actual_hidden_result) == 0 {
            return mir_direct_call_validation(0, "direct_call_hidden_result_mismatch", ctx);
        }
        if std.str_eq(value.expected_resource_transfers, value.actual_resource_transfers) == 0 {
            return mir_direct_call_validation(0, "direct_call_resource_transfer_mismatch", ctx);
        }
        if value.compatible != 1 || std.str_eq(plan.value.expected_abi_id, plan.value.actual_abi_id) == 0 ||
           std.str_eq(value.caller_function_id, plan.value.caller_function_id) == 0 ||
           std.str_eq(value.callee_function_id, plan.value.callee_function_id) == 0
        {
            return mir_direct_call_validation(0, "direct_call_caller_callee_disagreement", ctx);
        }
        mut duplicate := index + 1;
        while duplicate < len(values) {
            if std.str_eq(values[duplicate].agreement_id, value.agreement_id) == 1 ||
               std.str_eq(values[duplicate].call_id, value.call_id) == 1
            {
                return mir_direct_call_validation(0, "direct_call_duplicate_identity", ctx);
            }
            duplicate = duplicate + 1;
        }
        index = index + 1;
    }
    return mir_direct_call_validation(1, "direct_call_agreement_valid", ctx);
}

func mir_direct_call_append(output: str, key: str, value: str, ctx: &Arena) str {
    mut result := std.Concat(output, key); result = std.Concat(result, "=");
    result = std.Concat(result, value); result = std.Concat(result, ";"); return std.Clone(ctx, result);
}

func mir_serialize_direct_call_agreement_for_request(table: MirDirectCallAgreementTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], calls: call_mir.MirFunctionCallTable[ctx], ctx: &Arena) str {
    mut validation := mir_direct_call_agreement_table_validate(table, authority, calls, ctx);
    if validation.valid == 0 {
        mut invalid := "direct_call_format: invalid\ndirect_call_reason: ";
        invalid = std.Concat(invalid, validation.reason_code); invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut values: std.Vector[MirDirectCallAgreement[ctx], ctx] := ctx[table.agreements];
    mut output := "direct_call_format: gust.compiler_direct_call_agreement.v1\n";
    output = std.Concat(output, "direct_call_target_id: "); output = std.Concat(output, table.target_id); output = std.Concat(output, "\n");
    output = std.Concat(output, "direct_call_target_triple: "); output = std.Concat(output, table.target_triple); output = std.Concat(output, "\n");
    output = std.Concat(output, "direct_call_agreement_count: "); output = std.Concat(output, std.FormatInt(len(values))); output = std.Concat(output, "\n");
    mut index := 0;
    while index < len(values) {
        mut value := values[index]; mut row := "direct_call_agreement:";
        row = mir_direct_call_append(row, "id", value.agreement_id, ctx); row = mir_direct_call_append(row, "call", value.call_id, ctx);
        row = mir_direct_call_append(row, "kind", value.composition_kind, ctx); row = mir_direct_call_append(row, "caller", value.caller_function_id, ctx);
        row = mir_direct_call_append(row, "callee", value.callee_function_id, ctx); row = mir_direct_call_append(row, "plan", value.call_plan_id, ctx);
        row = mir_direct_call_append(row, "declaration_abi", value.declaration_abi_id, ctx); row = mir_direct_call_append(row, "definition_abi", value.definition_abi_id, ctx);
        row = mir_direct_call_append(row, "expected_abi", value.expected_abi_id, ctx); row = mir_direct_call_append(row, "actual_abi", value.actual_abi_id, ctx);
        row = mir_direct_call_append(row, "expected_signature", value.expected_signature_id, ctx); row = mir_direct_call_append(row, "actual_signature", value.actual_signature_id, ctx);
        row = mir_direct_call_append(row, "expected_cc", value.expected_calling_convention, ctx); row = mir_direct_call_append(row, "actual_cc", value.actual_calling_convention, ctx);
        row = mir_direct_call_append(row, "expected_parameters", value.expected_parameters, ctx); row = mir_direct_call_append(row, "actual_parameters", value.actual_parameters, ctx);
        row = mir_direct_call_append(row, "expected_results", value.expected_results, ctx); row = mir_direct_call_append(row, "actual_results", value.actual_results, ctx);
        row = mir_direct_call_append(row, "expected_layouts", value.expected_layouts, ctx); row = mir_direct_call_append(row, "actual_layouts", value.actual_layouts, ctx);
        row = mir_direct_call_append(row, "expected_classes", value.expected_classes, ctx); row = mir_direct_call_append(row, "actual_classes", value.actual_classes, ctx);
        row = mir_direct_call_append(row, "expected_extensions", value.expected_extensions, ctx); row = mir_direct_call_append(row, "actual_extensions", value.actual_extensions, ctx);
        row = mir_direct_call_append(row, "expected_hidden", value.expected_hidden_result, ctx); row = mir_direct_call_append(row, "actual_hidden", value.actual_hidden_result, ctx);
        row = mir_direct_call_append(row, "expected_transfers", value.expected_resource_transfers, ctx); row = mir_direct_call_append(row, "actual_transfers", value.actual_resource_transfers, ctx);
        row = mir_direct_call_append(row, "flow", value.result_flow, ctx); row = mir_direct_call_append(row, "freshness", value.freshness, ctx);
        row = mir_direct_call_append(row, "compatible", std.FormatInt(value.compatible), ctx); row = mir_direct_call_append(row, "target", value.target_id, ctx);
        row = mir_direct_call_append(row, "actual_target", value.actual_target_id, ctx); row = mir_direct_call_append(row, "triple", value.target_triple, ctx);
        row = mir_direct_call_append(row, "actual_triple", value.actual_target_triple, ctx); row = mir_direct_call_append(row, "source", value.source_location, ctx);
        output = std.Concat(output, row); output = std.Concat(output, "\n"); index = index + 1;
    }
    return std.Clone(ctx, output);
}
