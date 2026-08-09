// Immutable compiler-produced Phase 16.3 aggregate parameter request payload.

import "mir_layout.gst" as layout;
import "mir_function_abi_authority.gst" as abi;
import "mir_aggregate_parameter_abi.gst" as aggregate_parameter;

type MirNativeBackendAggregateParameterRequest[ctx] struct {
    target_triple: str,
    layout_table: layout.MirLayoutTable[ctx],
    abi_authority: abi.MirFunctionAbiAuthorityTable[ctx],
    aggregate_parameter_table: aggregate_parameter.MirAggregateParameterTable[ctx]
}

func mir_native_backend_aggregate_parameter_request_is_valid(request: MirNativeBackendAggregateParameterRequest[ctx], ctx: &Arena) int {
    if std.str_eq(request.target_triple, request.layout_table.target.target_triple) == 0 { return 0; }
    mut validation := aggregate_parameter.mir_aggregate_parameter_table_validate(request.aggregate_parameter_table, request.layout_table, request.abi_authority, ctx);
    return validation.valid;
}

func mir_serialize_native_backend_aggregate_parameter_request(request: MirNativeBackendAggregateParameterRequest[ctx], ctx: &Arena) str {
    if mir_native_backend_aggregate_parameter_request_is_valid(request, ctx) == 0 { return "aggregate_parameter_request_invalid"; }
    mut serialized := aggregate_parameter.mir_serialize_aggregate_parameter_for_request(request.aggregate_parameter_table, request.layout_table, request.abi_authority, ctx);
    return std.Clone(ctx, serialized);
}
