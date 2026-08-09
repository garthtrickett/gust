// Phase 16.2 canonical function-signature, call, and result transport.
//
// This sidecar is produced by the compiler and consumed by MIR-to-C and
// Cranelift. It carries ABI identities and ordered operands explicitly; a
// backend must not reconstruct a signature from source spelling, a symbol, a
// generated C prototype, or its own call instruction.

import "mir_function_abi_authority.gst" as abi;

type MirCallOperationKind enum {
    FunctionAbiDeclaration,
    ArgumentMaterialization,
    DirectCall,
    ResultExtraction,
    HiddenArgument,
    HiddenResultStorage,
    PostCallNormalization
}

type MirFunctionAbiDeclaration[ctx] struct {
    declaration_id: str,
    mir_function_id: str,
    abi_id: str,
    signature_id: str,
    parameter_abi_ids: Index[std.Vector[str, ctx], ctx],
    result_abi_ids: Index[std.Vector[str, ctx], ctx],
    target_id: str,
    target_triple: str,
    calling_convention: str,
    source_location: str
}

type MirCallOperand[ctx] struct {
    operand_id: str,
    call_id: str,
    abi_value_id: str,
    ordinal: int,
    value_id: str,
    value_type_id: str,
    layout_id: str,
    evaluation_order: int,
    hidden: int,
    resource_id: str,
    resource_transition_id: str,
    resource_state_before: str,
    resource_state_after: str,
    source_location: str
}

type MirCallOperation[ctx] struct {
    operation_id: str,
    operation_kind: MirCallOperationKind,
    call_id: str,
    caller_abi_id: str,
    callee_abi_id: str,
    call_plan_id: str,
    argument_abi_ids: Index[std.Vector[str, ctx], ctx],
    result_abi_ids: Index[std.Vector[str, ctx], ctx],
    input_value_id: str,
    output_value_id: str,
    target_id: str,
    target_triple: str,
    calling_convention: str,
    source_location: str
}

type MirFunctionCallTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    semantic_authority: str,
    selected_inventory: str,
    signature_policy: str,
    evaluation_policy: str,
    resource_policy: str,
    declarations: Index[std.Vector[MirFunctionAbiDeclaration[ctx], ctx], ctx],
    operands: Index[std.Vector[MirCallOperand[ctx], ctx], ctx],
    operations: Index[std.Vector[MirCallOperation[ctx], ctx], ctx]
}

type MirFunctionCallValidation[ctx] struct { valid: int, reason_code: str }
type MirFunctionAbiDeclarationQuery[ctx] struct { found: int, value: MirFunctionAbiDeclaration[ctx] }
type MirCallOperandQuery[ctx] struct { found: int, value: MirCallOperand[ctx] }

func mir_call_empty_strings(ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut values: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_call_empty_declarations(ctx: &Arena) Index[std.Vector[MirFunctionAbiDeclaration[ctx], ctx], ctx] {
    mut values: std.Vector[MirFunctionAbiDeclaration[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirFunctionAbiDeclaration[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_call_empty_operands(ctx: &Arena) Index[std.Vector[MirCallOperand[ctx], ctx], ctx] {
    mut values: std.Vector[MirCallOperand[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirCallOperand[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_call_empty_operations(ctx: &Arena) Index[std.Vector[MirCallOperation[ctx], ctx], ctx] {
    mut values: std.Vector[MirCallOperation[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirCallOperation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_call_push_string(values_index: Index[std.Vector[str, ctx], ctx], value: str, ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut values: std.Vector[str, ctx] := ctx[values_index];
    values.Push(std.Clone(ctx, value));
    ctx.Set(values_index, values);
    return values_index;
}

func mir_call_operation_kind_name(kind: MirCallOperationKind) str {
    unsafe {
        if kind.tag == 0 { return "function_abi_declaration"; }
        if kind.tag == 1 { return "argument_materialization"; }
        if kind.tag == 2 { return "direct_call"; }
        if kind.tag == 3 { return "result_extraction"; }
        if kind.tag == 4 { return "hidden_argument"; }
        if kind.tag == 5 { return "hidden_result_storage"; }
        if kind.tag == 6 { return "post_call_normalization"; }
    }
    return "unknown";
}

func mir_function_call_make_empty_table(target_id: str, target_triple: str, ctx: &Arena) MirFunctionCallTable[ctx] {
    mut table: MirFunctionCallTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_function_call_mir.v1");
    table.target_id = std.Clone(ctx, target_id);
    table.target_triple = std.Clone(ctx, target_triple);
    table.semantic_authority = std.Clone(ctx, "compiler_owned_canonical_call_transport");
    table.selected_inventory = std.Clone(ctx, "direct_calls_int_bool_scalar_and_layout_supported_values");
    table.signature_policy = std.Clone(ctx, "explicit_function_abi_and_call_plan_ids");
    table.evaluation_policy = std.Clone(ctx, "source_order_materialization_before_call_then_result_normalization");
    table.resource_policy = std.Clone(ctx, "preserve_compiler_owned_phase15_transition_ids");
    table.declarations = mir_call_empty_declarations(ctx);
    table.operands = mir_call_empty_operands(ctx);
    table.operations = mir_call_empty_operations(ctx);
    return table;
}

func mir_function_call_table_with_declaration(table: MirFunctionCallTable[ctx], value: MirFunctionAbiDeclaration[ctx], ctx: &Arena) MirFunctionCallTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirFunctionAbiDeclaration[ctx], ctx] := ctx[updated.declarations];
    values.Push(value);
    ctx.Set(updated.declarations, values);
    return updated;
}

func mir_function_call_table_with_operand(table: MirFunctionCallTable[ctx], value: MirCallOperand[ctx], ctx: &Arena) MirFunctionCallTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirCallOperand[ctx], ctx] := ctx[updated.operands];
    values.Push(value);
    ctx.Set(updated.operands, values);
    return updated;
}

func mir_function_call_table_with_operation(table: MirFunctionCallTable[ctx], value: MirCallOperation[ctx], ctx: &Arena) MirFunctionCallTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirCallOperation[ctx], ctx] := ctx[updated.operations];
    values.Push(value);
    ctx.Set(updated.operations, values);
    return updated;
}

func mir_function_call_validation(valid: int, reason_code: str, ctx: &Arena) MirFunctionCallValidation[ctx] {
    mut result: MirFunctionCallValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_call_field_safe(value: str, allow_empty: int) int {
    if allow_empty == 0 && len(value) == 0 { return 0; }
    if std.str_find(value, "\n") != 0 - 1 || std.str_find(value, "\r") != 0 - 1 || std.str_find(value, ";") != 0 - 1 {
        return 0;
    }
    return 1;
}

func mir_call_supported_convention(value: str) int {
    if std.str_eq(value, "gust") == 1 { return 1; }
    return 0;
}

func mir_call_strings_equal(left_index: Index[std.Vector[str, ctx], ctx], right_index: Index[std.Vector[str, ctx], ctx], ctx: &Arena) int {
    mut left: std.Vector[str, ctx] := ctx[left_index];
    mut right: std.Vector[str, ctx] := ctx[right_index];
    if len(left) != len(right) { return 0; }
    mut index := 0;
    while index < len(left) {
        if std.str_eq(left[index], right[index]) == 0 { return 0; }
        index = index + 1;
    }
    return 1;
}

func mir_function_call_declaration_by_abi(table: MirFunctionCallTable[ctx], abi_id: str, ctx: &Arena) MirFunctionAbiDeclarationQuery[ctx] {
    mut result: MirFunctionAbiDeclarationQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirFunctionAbiDeclaration[ctx], ctx] := ctx[table.declarations];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].abi_id, abi_id) == 1 {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_function_call_operand_by_id(table: MirFunctionCallTable[ctx], operand_id: str, ctx: &Arena) MirCallOperandQuery[ctx] {
    mut result: MirCallOperandQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirCallOperand[ctx], ctx] := ctx[table.operands];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].operand_id, operand_id) == 1 {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_function_call_table_validate(table: MirFunctionCallTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) MirFunctionCallValidation[ctx] {
    if std.str_eq(table.format, "gust.compiler_function_call_mir.v1") == 0 {
        return mir_function_call_validation(0, "call_mir_unknown_format", ctx);
    }
    if std.str_eq(table.target_id, authority.target_id) == 0 || std.str_eq(table.target_triple, authority.target_triple) == 0 {
        return mir_function_call_validation(0, "call_mir_target_mismatch", ctx);
    }
    if std.str_eq(table.semantic_authority, "compiler_owned_canonical_call_transport") == 0 ||
       std.str_eq(table.signature_policy, "explicit_function_abi_and_call_plan_ids") == 0 ||
       std.str_eq(table.evaluation_policy, "source_order_materialization_before_call_then_result_normalization") == 0 ||
       std.str_eq(table.resource_policy, "preserve_compiler_owned_phase15_transition_ids") == 0
    {
        return mir_function_call_validation(0, "call_mir_authority_policy_mismatch", ctx);
    }

    mut declarations: std.Vector[MirFunctionAbiDeclaration[ctx], ctx] := ctx[table.declarations];
    mut operands: std.Vector[MirCallOperand[ctx], ctx] := ctx[table.operands];
    mut operations: std.Vector[MirCallOperation[ctx], ctx] := ctx[table.operations];
    mut index := 0;
    while index < len(declarations) {
        mut value := declarations[index];
        mut function_query := abi.mir_function_abi_by_id(authority, value.abi_id, ctx);
        if function_query.found == 0 { return mir_function_call_validation(0, "call_mir_missing_abi_metadata", ctx); }
        if mir_call_field_safe(value.declaration_id, 0) == 0 || mir_call_field_safe(value.mir_function_id, 0) == 0 ||
           mir_call_supported_convention(value.calling_convention) == 0
        {
            return mir_function_call_validation(0, "call_mir_unsupported_calling_convention", ctx);
        }
        if std.str_eq(value.target_id, table.target_id) == 0 || std.str_eq(value.target_triple, table.target_triple) == 0 {
            return mir_function_call_validation(0, "call_mir_target_mismatch", ctx);
        }
        if std.str_eq(value.signature_id, function_query.value.signature_id) == 0 ||
           std.str_eq(value.calling_convention, function_query.value.calling_convention) == 0 ||
           mir_call_strings_equal(value.parameter_abi_ids, function_query.value.parameter_placement_ids, ctx) == 0 ||
           mir_call_strings_equal(value.result_abi_ids, function_query.value.result_placement_ids, ctx) == 0
        {
            return mir_function_call_validation(0, "call_mir_signature_disagreement", ctx);
        }
        mut duplicate := index + 1;
        while duplicate < len(declarations) {
            if std.str_eq(declarations[duplicate].declaration_id, value.declaration_id) == 1 ||
               std.str_eq(declarations[duplicate].abi_id, value.abi_id) == 1
            {
                return mir_function_call_validation(0, "call_mir_duplicate_record", ctx);
            }
            duplicate = duplicate + 1;
        }
        index = index + 1;
    }

    index = 0;
    while index < len(operands) {
        mut value := operands[index];
        if mir_call_field_safe(value.operand_id, 0) == 0 || mir_call_field_safe(value.call_id, 0) == 0 ||
           mir_call_field_safe(value.abi_value_id, 0) == 0 || value.ordinal < 0 || value.evaluation_order < 0 ||
           (value.hidden != 0 && value.hidden != 1)
        {
            return mir_function_call_validation(0, "call_mir_unknown_hidden_value", ctx);
        }
        if (len(value.resource_transition_id) == 0 && (len(value.resource_state_before) != 0 || len(value.resource_state_after) != 0)) ||
           (len(value.resource_transition_id) != 0 && (len(value.resource_state_before) == 0 || len(value.resource_state_after) == 0))
        {
            return mir_function_call_validation(0, "call_mir_resource_transition_incomplete", ctx);
        }
        mut duplicate := index + 1;
        while duplicate < len(operands) {
            if std.str_eq(operands[duplicate].operand_id, value.operand_id) == 1 {
                return mir_function_call_validation(0, "call_mir_duplicate_record", ctx);
            }
            duplicate = duplicate + 1;
        }
        index = index + 1;
    }

    index = 0;
    while index < len(operations) {
        mut value := operations[index];
        if mir_call_field_safe(value.operation_id, 0) == 0 || mir_call_supported_convention(value.calling_convention) == 0 {
            return mir_function_call_validation(0, "call_mir_unsupported_calling_convention", ctx);
        }
        if std.str_eq(value.target_id, table.target_id) == 0 || std.str_eq(value.target_triple, table.target_triple) == 0 {
            return mir_function_call_validation(0, "call_mir_target_mismatch", ctx);
        }
        if abi.mir_function_abi_by_id(authority, value.caller_abi_id, ctx).found == 0 ||
           abi.mir_function_abi_by_id(authority, value.callee_abi_id, ctx).found == 0
        {
            return mir_function_call_validation(0, "call_mir_missing_abi_metadata", ctx);
        }
        mut call_query := abi.mir_abi_call_plan(authority, value.call_id, value.callee_abi_id, ctx);
        if call_query.found == 0 || std.str_eq(call_query.value.call_plan_id, value.call_plan_id) == 0 {
            return mir_function_call_validation(0, "call_mir_missing_abi_metadata", ctx);
        }
        if mir_call_strings_equal(value.argument_abi_ids, call_query.value.argument_placement_ids, ctx) == 0 {
            return mir_function_call_validation(0, "call_mir_argument_count_or_order_mismatch", ctx);
        }
        if mir_call_strings_equal(value.result_abi_ids, call_query.value.result_placement_ids, ctx) == 0 {
            return mir_function_call_validation(0, "call_mir_result_count_mismatch", ctx);
        }
        unsafe {
            if (value.operation_kind.tag == 4 || value.operation_kind.tag == 5) &&
               mir_function_call_operand_by_id(table, value.input_value_id, ctx).found == 0
            {
                return mir_function_call_validation(0, "call_mir_unknown_hidden_value", ctx);
            }
        }
        mut duplicate := index + 1;
        while duplicate < len(operations) {
            if std.str_eq(operations[duplicate].operation_id, value.operation_id) == 1 {
                return mir_function_call_validation(0, "call_mir_duplicate_record", ctx);
            }
            duplicate = duplicate + 1;
        }
        index = index + 1;
    }
    return mir_function_call_validation(1, "call_mir_valid", ctx);
}

func mir_call_join(values_index: Index[std.Vector[str, ctx], ctx], ctx: &Arena) str {
    mut values: std.Vector[str, ctx] := ctx[values_index];
    mut output := "";
    mut index := 0;
    while index < len(values) {
        if index != 0 { output = std.Concat(output, ","); }
        output = std.Concat(output, values[index]);
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_call_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut updated := std.Concat(output, key);
    updated = std.Concat(updated, "=");
    updated = std.Concat(updated, value);
    updated = std.Concat(updated, ";");
    return std.Clone(ctx, updated);
}

func mir_serialize_function_call_for_request(table: MirFunctionCallTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_function_call_table_validate(table, authority, ctx);
    if validation.valid == 0 {
        mut invalid := "call_mir_format: invalid\ncall_mir_reason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut declarations: std.Vector[MirFunctionAbiDeclaration[ctx], ctx] := ctx[table.declarations];
    mut operands: std.Vector[MirCallOperand[ctx], ctx] := ctx[table.operands];
    mut operations: std.Vector[MirCallOperation[ctx], ctx] := ctx[table.operations];
    mut output := "call_mir_format: gust.compiler_function_call_mir.v1\n";
    output = std.Concat(output, "call_mir_target_id: "); output = std.Concat(output, table.target_id); output = std.Concat(output, "\n");
    output = std.Concat(output, "call_mir_target_triple: "); output = std.Concat(output, table.target_triple); output = std.Concat(output, "\n");
    output = std.Concat(output, "call_mir_declaration_count: "); output = std.Concat(output, std.FormatInt(len(declarations))); output = std.Concat(output, "\n");
    output = std.Concat(output, "call_mir_operand_count: "); output = std.Concat(output, std.FormatInt(len(operands))); output = std.Concat(output, "\n");
    output = std.Concat(output, "call_mir_operation_count: "); output = std.Concat(output, std.FormatInt(len(operations))); output = std.Concat(output, "\n");
    mut index := 0;
    while index < len(declarations) {
        mut value := declarations[index];
        mut row := "call_declaration:";
        row = mir_call_append_field(row, "id", value.declaration_id, ctx);
        row = mir_call_append_field(row, "function", value.mir_function_id, ctx);
        row = mir_call_append_field(row, "abi", value.abi_id, ctx);
        row = mir_call_append_field(row, "signature", value.signature_id, ctx);
        row = mir_call_append_field(row, "parameters", mir_call_join(value.parameter_abi_ids, ctx), ctx);
        row = mir_call_append_field(row, "results", mir_call_join(value.result_abi_ids, ctx), ctx);
        row = mir_call_append_field(row, "target", value.target_id, ctx);
        row = mir_call_append_field(row, "triple", value.target_triple, ctx);
        row = mir_call_append_field(row, "cc", value.calling_convention, ctx);
        row = mir_call_append_field(row, "source", value.source_location, ctx);
        output = std.Concat(output, row); output = std.Concat(output, "\n");
        index = index + 1;
    }
    index = 0;
    while index < len(operands) {
        mut value := operands[index];
        mut row := "call_operand:";
        row = mir_call_append_field(row, "id", value.operand_id, ctx);
        row = mir_call_append_field(row, "call", value.call_id, ctx);
        row = mir_call_append_field(row, "abi_value", value.abi_value_id, ctx);
        row = mir_call_append_field(row, "ordinal", std.FormatInt(value.ordinal), ctx);
        row = mir_call_append_field(row, "value", value.value_id, ctx);
        row = mir_call_append_field(row, "type", value.value_type_id, ctx);
        row = mir_call_append_field(row, "layout", value.layout_id, ctx);
        row = mir_call_append_field(row, "evaluation", std.FormatInt(value.evaluation_order), ctx);
        row = mir_call_append_field(row, "hidden", std.FormatInt(value.hidden), ctx);
        row = mir_call_append_field(row, "resource", value.resource_id, ctx);
        row = mir_call_append_field(row, "transition", value.resource_transition_id, ctx);
        row = mir_call_append_field(row, "before", value.resource_state_before, ctx);
        row = mir_call_append_field(row, "after", value.resource_state_after, ctx);
        row = mir_call_append_field(row, "source", value.source_location, ctx);
        output = std.Concat(output, row); output = std.Concat(output, "\n");
        index = index + 1;
    }
    index = 0;
    while index < len(operations) {
        mut value := operations[index];
        mut row := "call_operation:";
        row = mir_call_append_field(row, "id", value.operation_id, ctx);
        row = mir_call_append_field(row, "kind", mir_call_operation_kind_name(value.operation_kind), ctx);
        row = mir_call_append_field(row, "call", value.call_id, ctx);
        row = mir_call_append_field(row, "caller_abi", value.caller_abi_id, ctx);
        row = mir_call_append_field(row, "callee_abi", value.callee_abi_id, ctx);
        row = mir_call_append_field(row, "plan", value.call_plan_id, ctx);
        row = mir_call_append_field(row, "arguments", mir_call_join(value.argument_abi_ids, ctx), ctx);
        row = mir_call_append_field(row, "results", mir_call_join(value.result_abi_ids, ctx), ctx);
        row = mir_call_append_field(row, "input", value.input_value_id, ctx);
        row = mir_call_append_field(row, "output", value.output_value_id, ctx);
        row = mir_call_append_field(row, "target", value.target_id, ctx);
        row = mir_call_append_field(row, "triple", value.target_triple, ctx);
        row = mir_call_append_field(row, "cc", value.calling_convention, ctx);
        row = mir_call_append_field(row, "source", value.source_location, ctx);
        output = std.Concat(output, row); output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_function_call_witness(table: MirFunctionCallTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_function_call_table_validate(table, authority, ctx);
    if validation.valid == 0 {
        mut invalid := "call_mir_status: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "call_mir_status: valid\n";
    output = std.Concat(output, "target_id: "); output = std.Concat(output, table.target_id); output = std.Concat(output, "\n");
    output = std.Concat(output, "target_triple: "); output = std.Concat(output, table.target_triple); output = std.Concat(output, "\n");
    mut declarations: std.Vector[MirFunctionAbiDeclaration[ctx], ctx] := ctx[table.declarations];
    mut operations: std.Vector[MirCallOperation[ctx], ctx] := ctx[table.operations];
    mut index := 0;
    while index < len(declarations) {
        mut value := declarations[index];
        mut row := "function_abi: id="; row = std.Concat(row, value.declaration_id);
        row = std.Concat(row, " abi="); row = std.Concat(row, value.abi_id);
        row = std.Concat(row, " signature="); row = std.Concat(row, value.signature_id);
        row = std.Concat(row, " cc="); row = std.Concat(row, value.calling_convention);
        row = std.Concat(row, "\n"); output = std.Concat(output, row);
        index = index + 1;
    }
    index = 0;
    while index < len(operations) {
        mut value := operations[index];
        mut row := "call_lowering: id="; row = std.Concat(row, value.operation_id);
        row = std.Concat(row, " action="); row = std.Concat(row, mir_call_operation_kind_name(value.operation_kind));
        row = std.Concat(row, " call="); row = std.Concat(row, value.call_id);
        row = std.Concat(row, " caller_abi="); row = std.Concat(row, value.caller_abi_id);
        row = std.Concat(row, " callee_abi="); row = std.Concat(row, value.callee_abi_id);
        row = std.Concat(row, " plan="); row = std.Concat(row, value.call_plan_id);
        row = std.Concat(row, " arguments="); row = std.Concat(row, mir_call_join(value.argument_abi_ids, ctx));
        row = std.Concat(row, " results="); row = std.Concat(row, mir_call_join(value.result_abi_ids, ctx));
        row = std.Concat(row, " input="); row = std.Concat(row, value.input_value_id);
        row = std.Concat(row, " output="); row = std.Concat(row, value.output_value_id);
        row = std.Concat(row, "\n"); output = std.Concat(output, row);
        index = index + 1;
    }
    return std.Clone(ctx, output);
}
