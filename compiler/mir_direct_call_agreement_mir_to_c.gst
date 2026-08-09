// MIR-to-C consumes the compiler-owned Patch 16.5 agreement witness.
import "mir_direct_call_agreement.gst" as direct;
import "mir_function_abi_authority.gst" as abi;
import "mir_function_call.gst" as calls;

func mir_direct_call_mir_to_c_witness(table: direct.MirDirectCallAgreementTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], call_table: calls.MirFunctionCallTable[ctx], ctx: &Arena) str {
    return std.Clone(ctx, direct.mir_serialize_direct_call_agreement_for_request(table, authority, call_table, ctx));
}
