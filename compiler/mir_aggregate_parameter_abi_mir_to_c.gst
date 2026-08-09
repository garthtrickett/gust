// MIR-to-C consumes the compiler-owned Phase 16.3 aggregate parameter plan.

import "mir_layout.gst" as layout;
import "mir_function_abi_authority.gst" as abi;
import "mir_aggregate_parameter_abi.gst" as aggregate_parameter;

type MirAggregateParameterCEmission[ctx] struct { success: int, c_source: str, reason_code: str }

func mir_aggregate_parameter_to_c_source(table: aggregate_parameter.MirAggregateParameterTable[ctx], layouts: layout.MirLayoutTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) MirAggregateParameterCEmission[ctx] {
    mut result: MirAggregateParameterCEmission[ctx];
    mut validation := aggregate_parameter.mir_aggregate_parameter_table_validate(table, layouts, authority, ctx);
    result.success = validation.valid;
    result.reason_code = std.Clone(ctx, validation.reason_code);
    result.c_source = "";
    if validation.valid == 0 { return result; }
    mut plans: std.Vector[aggregate_parameter.MirAggregateParameterPlan[ctx], ctx] := ctx[table.plans];
    mut output := "/* compiler-owned aggregate parameter plans */\n";
    mut index := 0;
    while index < len(plans) {
        output = std.Concat(output, "/* aggregate parameter mode=");
        output = std.Concat(output, plans[index].passing_mode);
        output = std.Concat(output, " caller=");
        output = std.Concat(output, plans[index].caller_materialization);
        output = std.Concat(output, " callee=");
        output = std.Concat(output, plans[index].callee_materialization);
        output = std.Concat(output, " */\n");
        index = index + 1;
    }
    result.c_source = std.Clone(ctx, output);
    return result;
}

func mir_aggregate_parameter_mir_to_c_witness(table: aggregate_parameter.MirAggregateParameterTable[ctx], layouts: layout.MirLayoutTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) str {
    mut witness := aggregate_parameter.mir_aggregate_parameter_witness(table, layouts, authority, ctx);
    return std.Clone(ctx, witness);
}
