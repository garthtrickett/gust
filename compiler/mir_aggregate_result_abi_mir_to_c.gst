// MIR-to-C consumer for compiler-owned Phase 16.4 aggregate result plans.

import "mir_layout.gst" as layout;
import "mir_function_abi_authority.gst" as abi;
import "mir_aggregate_result_abi.gst" as aggregate_result;

type MirAggregateResultCEmission[ctx] struct { success: int, c_source: str, reason_code: str }

func mir_aggregate_result_to_c_source(table: aggregate_result.MirAggregateResultTable[ctx], layouts: layout.MirLayoutTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) MirAggregateResultCEmission[ctx] {
    mut result: MirAggregateResultCEmission[ctx];
    mut validation := aggregate_result.mir_aggregate_result_table_validate(table, layouts, authority, ctx);
    result.success = validation.valid; result.reason_code = std.Clone(ctx, validation.reason_code); result.c_source = "";
    if validation.valid == 0 { return result; }
    mut operations: std.Vector[aggregate_result.MirAggregateResultOperation[ctx], ctx] := ctx[table.operations];
    mut output := "/* compiler-owned aggregate result operations */\n";
    mut index := 0;
    while index < len(operations) {
        output = std.Concat(output, "/* aggregate result action="); output = std.Concat(output, operations[index].operation_kind); output = std.Concat(output, " storage="); output = std.Concat(output, operations[index].storage_id); output = std.Concat(output, " */\n"); index = index + 1;
    }
    result.c_source = std.Clone(ctx, output); return result;
}

func mir_aggregate_result_mir_to_c_witness(table: aggregate_result.MirAggregateResultTable[ctx], layouts: layout.MirLayoutTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) str {
    mut witness := aggregate_result.mir_aggregate_result_witness(table, layouts, authority, ctx); return std.Clone(ctx, witness);
}
