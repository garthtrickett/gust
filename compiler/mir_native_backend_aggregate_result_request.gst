// Immutable compiler-produced Phase 16.4 aggregate result request payload.

import "mir_layout.gst" as layout;
import "mir_function_abi_authority.gst" as abi;
import "mir_aggregate_result_abi.gst" as aggregate_result;

type MirNativeBackendAggregateResultRequest[ctx] struct {
    target_triple: str,
    layout_table: layout.MirLayoutTable[ctx],
    abi_authority: abi.MirFunctionAbiAuthorityTable[ctx],
    aggregate_result_table: aggregate_result.MirAggregateResultTable[ctx]
}

func mir_native_backend_aggregate_result_request_is_valid(request: MirNativeBackendAggregateResultRequest[ctx], ctx: &Arena) int {
    if std.str_eq(request.target_triple, request.layout_table.target.target_triple) == 0 { return 0; }
    mut validation := aggregate_result.mir_aggregate_result_table_validate(request.aggregate_result_table, request.layout_table, request.abi_authority, ctx); return validation.valid;
}

func mir_serialize_native_backend_aggregate_result_request(request: MirNativeBackendAggregateResultRequest[ctx], ctx: &Arena) str {
    if mir_native_backend_aggregate_result_request_is_valid(request, ctx) == 0 { return "aggregate_result_request_invalid"; }
    mut serialized := aggregate_result.mir_serialize_aggregate_result_for_request(request.aggregate_result_table, request.layout_table, request.abi_authority, ctx); return std.Clone(ctx, serialized);
}
