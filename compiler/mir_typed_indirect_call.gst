// Phase 16.6 compiler-owned typed function values and indirect calls.
import "mir_function_abi_authority.gst" as abi;

type MirTypedIndirectCall[ctx] struct {
    call_id: str,
    function_value_id: str,
    form: str,
    candidate_abi_ids: str,
    selected_function_id: str,
    expected_abi_id: str,
    actual_abi_id: str,
    expected_signature_id: str,
    actual_signature_id: str,
    expected_parameters: str,
    actual_parameters: str,
    expected_results: str,
    actual_results: str,
    operations: str,
    nullability: str,
    is_null: int,
    calling_convention: str,
    variadic: int,
    pointer_policy: str,
    resource_transfers: str,
    target_id: str,
    actual_target_id: str,
    target_triple: str,
    actual_target_triple: str,
    source_location: str
}

type MirTypedIndirectCallTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    authority: str,
    signature_policy: str,
    calls: Index[std.Vector[MirTypedIndirectCall[ctx], ctx], ctx]
}

type MirTypedIndirectCallValidation[ctx] struct { valid: int, reason_code: str }

func mir_typed_indirect_empty_calls(ctx: &Arena) Index[std.Vector[MirTypedIndirectCall[ctx], ctx], ctx] {
    mut values: std.Vector[MirTypedIndirectCall[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirTypedIndirectCall[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index;
}

func mir_typed_indirect_make_empty_table(target_id: str, target_triple: str, ctx: &Arena) MirTypedIndirectCallTable[ctx] {
    mut table: MirTypedIndirectCallTable[ctx]; table.format = std.Clone(ctx, "gust.compiler_typed_indirect_call.v1");
    table.target_id = std.Clone(ctx, target_id); table.target_triple = std.Clone(ctx, target_triple);
    table.authority = std.Clone(ctx, "compiler_owned_typed_function_value_and_indirect_call");
    table.signature_policy = std.Clone(ctx, "complete_canonical_signature_and_function_abi_identity_no_erasure");
    table.calls = mir_typed_indirect_empty_calls(ctx); return table;
}

func mir_typed_indirect_table_with_call(table: MirTypedIndirectCallTable[ctx], value: MirTypedIndirectCall[ctx], ctx: &Arena) MirTypedIndirectCallTable[ctx] {
    mut updated := table; mut values: std.Vector[MirTypedIndirectCall[ctx], ctx] := ctx[updated.calls]; values.Push(value); ctx.Set(updated.calls, values); return updated;
}

func mir_typed_indirect_validation(valid: int, reason_code: str, ctx: &Arena) MirTypedIndirectCallValidation[ctx] {
    mut result: MirTypedIndirectCallValidation[ctx]; result.valid = valid; result.reason_code = std.Clone(ctx, reason_code); return result;
}

func mir_typed_indirect_form_valid(value: str) int {
    if std.str_eq(value, "compatible_function_selection") == 1 { return 1; }
    if std.str_eq(value, "typed_function_value_parameter") == 1 { return 1; }
    return 0;
}

func mir_typed_indirect_call_table_validate(table: MirTypedIndirectCallTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) MirTypedIndirectCallValidation[ctx] {
    if std.str_eq(table.format, "gust.compiler_typed_indirect_call.v1") == 0 { return mir_typed_indirect_validation(0, "typed_indirect_unknown_format", ctx); }
    if std.str_eq(table.authority, "compiler_owned_typed_function_value_and_indirect_call") == 0 || std.str_eq(table.signature_policy, "complete_canonical_signature_and_function_abi_identity_no_erasure") == 0 {
        return mir_typed_indirect_validation(0, "typed_indirect_signature_erasure", ctx);
    }
    if std.str_eq(table.target_id, authority.target_id) == 0 || std.str_eq(table.target_triple, authority.target_triple) == 0 { return mir_typed_indirect_validation(0, "typed_indirect_target_mismatch", ctx); }
    mut values: std.Vector[MirTypedIndirectCall[ctx], ctx] := ctx[table.calls]; mut index := 0;
    while index < len(values) {
        mut value := values[index];
        if len(value.call_id) == 0 || len(value.function_value_id) == 0 || mir_typed_indirect_form_valid(value.form) == 0 { return mir_typed_indirect_validation(0, "typed_indirect_record_invalid", ctx); }
        if len(value.expected_signature_id) == 0 || len(value.actual_signature_id) == 0 { return mir_typed_indirect_validation(0, "typed_indirect_unknown_signature", ctx); }
        mut expected := abi.mir_function_abi_by_id(authority, value.expected_abi_id, ctx); mut actual := abi.mir_function_abi_by_id(authority, value.actual_abi_id, ctx);
        if expected.found == 0 || actual.found == 0 { return mir_typed_indirect_validation(0, "typed_indirect_unknown_signature", ctx); }
        if std.str_eq(value.expected_signature_id, expected.value.signature_id) == 0 || std.str_eq(value.actual_signature_id, actual.value.signature_id) == 0 || std.str_eq(value.expected_signature_id, value.actual_signature_id) == 0 {
            return mir_typed_indirect_validation(0, "typed_indirect_incompatible_function_value", ctx);
        }
        mut compatibility := abi.mir_validate_abi_compatibility(authority, value.expected_abi_id, value.actual_abi_id, ctx);
        if compatibility.compatible == 0 || std.str_eq(value.expected_parameters, value.actual_parameters) == 0 || std.str_eq(value.expected_results, value.actual_results) == 0 {
            return mir_typed_indirect_validation(0, "typed_indirect_incompatible_function_value", ctx);
        }
        if std.str_eq(value.nullability, "non_null") == 0 || value.is_null != 0 { return mir_typed_indirect_validation(0, "typed_indirect_null_call", ctx); }
        if std.str_eq(value.calling_convention, "gust") == 0 { return mir_typed_indirect_validation(0, "typed_indirect_unsupported_calling_convention", ctx); }
        if value.variadic != 0 { return mir_typed_indirect_validation(0, "typed_indirect_variadic_not_selected", ctx); }
        if std.str_eq(value.pointer_policy, "compiler_typed_function_value_no_pointer_cast") == 0 { return mir_typed_indirect_validation(0, "typed_indirect_unvalidated_pointer_cast", ctx); }
        if std.str_find(value.operations, "create_typed_function_value") == 0 - 1 || std.str_find(value.operations, "typed_indirect_call") == 0 - 1 {
            return mir_typed_indirect_validation(0, "typed_indirect_signature_erasure", ctx);
        }
        if std.str_eq(value.resource_transfers, "non_resource_copy") == 0 { return mir_typed_indirect_validation(0, "typed_indirect_resource_transfer_mismatch", ctx); }
        if std.str_eq(value.target_id, table.target_id) == 0 || std.str_eq(value.actual_target_id, table.target_id) == 0 || std.str_eq(value.target_triple, table.target_triple) == 0 || std.str_eq(value.actual_target_triple, table.target_triple) == 0 {
            return mir_typed_indirect_validation(0, "typed_indirect_target_mismatch", ctx);
        }
        mut duplicate := index + 1; while duplicate < len(values) { if std.str_eq(values[duplicate].call_id, value.call_id) == 1 || std.str_eq(values[duplicate].function_value_id, value.function_value_id) == 1 { return mir_typed_indirect_validation(0, "typed_indirect_duplicate_identity", ctx); } duplicate = duplicate + 1; }
        index = index + 1;
    }
    return mir_typed_indirect_validation(1, "typed_indirect_call_valid", ctx);
}

func mir_typed_indirect_append(output: str, key: str, value: str, ctx: &Arena) str { mut result := std.Concat(output, key); result = std.Concat(result, "="); result = std.Concat(result, value); result = std.Concat(result, ";"); return std.Clone(ctx, result); }

func mir_serialize_typed_indirect_call_for_request(table: MirTypedIndirectCallTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_typed_indirect_call_table_validate(table, authority, ctx); if validation.valid == 0 { mut invalid := "typed_indirect_format: invalid\ntyped_indirect_reason: "; invalid = std.Concat(invalid, validation.reason_code); invalid = std.Concat(invalid, "\n"); return std.Clone(ctx, invalid); }
    mut values: std.Vector[MirTypedIndirectCall[ctx], ctx] := ctx[table.calls]; mut output := "typed_indirect_format: gust.compiler_typed_indirect_call.v1\n";
    output = std.Concat(output, "typed_indirect_target_id: "); output = std.Concat(output, table.target_id); output = std.Concat(output, "\n"); output = std.Concat(output, "typed_indirect_target_triple: "); output = std.Concat(output, table.target_triple); output = std.Concat(output, "\n"); output = std.Concat(output, "typed_indirect_call_count: "); output = std.Concat(output, std.FormatInt(len(values))); output = std.Concat(output, "\n");
    mut index := 0; while index < len(values) { mut value := values[index]; mut row := "typed_indirect_call:";
        row = mir_typed_indirect_append(row, "id", value.call_id, ctx); row = mir_typed_indirect_append(row, "function_value", value.function_value_id, ctx); row = mir_typed_indirect_append(row, "form", value.form, ctx); row = mir_typed_indirect_append(row, "candidates", value.candidate_abi_ids, ctx); row = mir_typed_indirect_append(row, "selected", value.selected_function_id, ctx); row = mir_typed_indirect_append(row, "expected_abi", value.expected_abi_id, ctx); row = mir_typed_indirect_append(row, "actual_abi", value.actual_abi_id, ctx); row = mir_typed_indirect_append(row, "expected_signature", value.expected_signature_id, ctx); row = mir_typed_indirect_append(row, "actual_signature", value.actual_signature_id, ctx); row = mir_typed_indirect_append(row, "expected_parameters", value.expected_parameters, ctx); row = mir_typed_indirect_append(row, "actual_parameters", value.actual_parameters, ctx); row = mir_typed_indirect_append(row, "expected_results", value.expected_results, ctx); row = mir_typed_indirect_append(row, "actual_results", value.actual_results, ctx); row = mir_typed_indirect_append(row, "operations", value.operations, ctx); row = mir_typed_indirect_append(row, "nullability", value.nullability, ctx); row = mir_typed_indirect_append(row, "is_null", std.FormatInt(value.is_null), ctx); row = mir_typed_indirect_append(row, "cc", value.calling_convention, ctx); row = mir_typed_indirect_append(row, "variadic", std.FormatInt(value.variadic), ctx); row = mir_typed_indirect_append(row, "pointer_policy", value.pointer_policy, ctx); row = mir_typed_indirect_append(row, "transfers", value.resource_transfers, ctx); row = mir_typed_indirect_append(row, "target", value.target_id, ctx); row = mir_typed_indirect_append(row, "actual_target", value.actual_target_id, ctx); row = mir_typed_indirect_append(row, "triple", value.target_triple, ctx); row = mir_typed_indirect_append(row, "actual_triple", value.actual_target_triple, ctx); row = mir_typed_indirect_append(row, "source", value.source_location, ctx); output = std.Concat(output, row); output = std.Concat(output, "\n"); index = index + 1; }
    return std.Clone(ctx, output);
}
