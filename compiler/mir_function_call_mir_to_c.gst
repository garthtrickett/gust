// MIR-to-C consumer for Phase 16.2 canonical call operations.
//
// Function declarations, argument order, calls, hidden storage, and result
// normalization are selected by the compiler call table and ABI authority.

import "mir_function_abi_authority.gst" as abi;
import "mir_function_call.gst" as call_mir;

type MirFunctionCallCEmission[ctx] struct {
    success: int,
    c_source: str,
    reason_code: str
}

func mir_function_call_c_emission(success: int, c_source: str, reason_code: str, ctx: &Arena) MirFunctionCallCEmission[ctx] {
    mut result: MirFunctionCallCEmission[ctx];
    result.success = success;
    result.c_source = std.Clone(ctx, c_source);
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_function_call_operation_to_c(operation: call_mir.MirCallOperation[ctx], ctx: &Arena) str {
    unsafe {
        if operation.operation_kind.tag == 0 { return "/* compiler ABI declaration */"; }
        if operation.operation_kind.tag == 1 { return "/* materialize ordered argument */"; }
        if operation.operation_kind.tag == 2 {
            mut value := "gust_call_";
            value = std.Concat(value, operation.call_id);
            value = std.Concat(value, "();");
            return std.Clone(ctx, value);
        }
        if operation.operation_kind.tag == 3 { return "/* extract canonical result */"; }
        if operation.operation_kind.tag == 4 { return "/* materialize compiler-selected hidden argument */"; }
        if operation.operation_kind.tag == 5 { return "/* allocate compiler-selected hidden result storage */"; }
        if operation.operation_kind.tag == 6 { return "/* normalize canonical post-call result */"; }
    }
    return "/* invalid call operation */";
}

func mir_function_call_operand_to_c(operand: call_mir.MirCallOperand[ctx], ctx: &Arena) str {
    mut output := "/* canonical argument ";
    output = std.Concat(output, operand.operand_id);
    output = std.Concat(output, " ");
    output = std.Concat(output, operand.materialization);
    output = std.Concat(output, " from ");
    output = std.Concat(output, operand.passing_mode);
    output = std.Concat(output, " */");
    return std.Clone(ctx, output);
}

func mir_function_call_to_c_source(table: call_mir.MirFunctionCallTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) MirFunctionCallCEmission[ctx] {
    mut validation := call_mir.mir_function_call_table_validate(table, authority, ctx);
    if validation.valid == 0 {
        return mir_function_call_c_emission(0, "", validation.reason_code, ctx);
    }
    mut operands: std.Vector[call_mir.MirCallOperand[ctx], ctx] := ctx[table.operands];
    mut operations: std.Vector[call_mir.MirCallOperation[ctx], ctx] := ctx[table.operations];
    mut output := "/* canonical function call MIR */\n";
    mut index := 0;
    while index < len(operands) {
        output = std.Concat(output, mir_function_call_operand_to_c(operands[index], ctx));
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    index = 0;
    while index < len(operations) {
        output = std.Concat(output, mir_function_call_operation_to_c(operations[index], ctx));
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return mir_function_call_c_emission(1, output, "call_mir_c_emitted", ctx);
}

func mir_function_call_mir_to_c_witness(table: call_mir.MirFunctionCallTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) str {
    // The normalized witness deliberately contains no generated C prototype or
    // backend-local signature. Both consumers report the same canonical plan.
    return call_mir.mir_function_call_witness(table, authority, ctx);
}
