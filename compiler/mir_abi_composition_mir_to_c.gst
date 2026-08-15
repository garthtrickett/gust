import "mir_function_abi_authority.gst" as abi;
import "mir_abi_composition.gst" as composition;
func mir_abi_composition_mir_to_c_witness(plan: composition.MirAbiCompositionPlan[ctx], table: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) str { return std.Clone(ctx, composition.mir_abi_composition_witness(plan, table, ctx)); }
