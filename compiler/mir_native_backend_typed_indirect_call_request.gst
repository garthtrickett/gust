import "mir_native_backend_abi_request.gst" as base;
import "mir_typed_indirect_call.gst" as typed;
type MirNativeBackendTypedIndirectCallRequest[ctx] struct { format: str, base_request: base.MirNativeBackendAbiRequest[ctx], typed_indirect_table: typed.MirTypedIndirectCallTable[ctx] }
func mir_native_backend_typed_indirect_call_request_is_valid(request: MirNativeBackendTypedIndirectCallRequest[ctx], ctx: &Arena) typed.MirTypedIndirectCallValidation[ctx] {
    if std.str_eq(request.format, "gust.native_backend.typed_indirect_call_request.v1") == 0 { return typed.mir_typed_indirect_validation(0, "typed_indirect_request_unknown_format", ctx); }
    mut validation := base.mir_native_backend_abi_request_is_valid(request.base_request, ctx); if validation.valid == 0 { return typed.mir_typed_indirect_validation(0, validation.reason_code, ctx); }
    return typed.mir_typed_indirect_call_table_validate(request.typed_indirect_table, request.base_request.abi_authority_table, ctx);
}
