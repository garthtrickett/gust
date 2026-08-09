// Native request extension for the compiler-owned Patch 16.5 agreement table.
import "mir_native_backend_call_mir_request.gst" as base;
import "mir_direct_call_agreement.gst" as direct;

type MirNativeBackendDirectCallAgreementRequest[ctx] struct {
    format: str,
    base_request: base.MirNativeBackendCallMirRequest[ctx],
    direct_call_table: direct.MirDirectCallAgreementTable[ctx]
}

func mir_native_backend_direct_call_agreement_request_is_valid(request: MirNativeBackendDirectCallAgreementRequest[ctx], ctx: &Arena) direct.MirDirectCallAgreementValidation[ctx] {
    if std.str_eq(request.format, "gust.native_backend.direct_call_agreement_request.v1") == 0 {
        return direct.mir_direct_call_validation(0, "direct_call_request_unknown_format", ctx);
    }
    mut base_validation := base.mir_native_backend_call_mir_request_is_valid(request.base_request, ctx);
    if base_validation.valid == 0 { return direct.mir_direct_call_validation(0, base_validation.reason_code, ctx); }
    return direct.mir_direct_call_agreement_table_validate(request.direct_call_table, request.base_request.base_request.abi_authority_table, request.base_request.call_mir_table, ctx);
}
