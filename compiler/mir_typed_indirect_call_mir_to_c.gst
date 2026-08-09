import "mir_typed_indirect_call.gst" as typed;
import "mir_function_abi_authority.gst" as abi;
func mir_typed_indirect_call_mir_to_c_witness(table: typed.MirTypedIndirectCallTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) str { return std.Clone(ctx, typed.mir_serialize_typed_indirect_call_for_request(table, authority, ctx)); }
