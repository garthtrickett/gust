// Phase 16.2 canonical-call extension of the Phase 16 ABI request.

import "mir_native_backend_abi_request.gst" as abi_request;
import "mir_function_call.gst" as call_mir;

type MirNativeBackendCallMirRequest[ctx] struct {
    format: str,
    base_request: abi_request.MirNativeBackendAbiRequest[ctx],
    call_mir_table: call_mir.MirFunctionCallTable[ctx]
}

type MirNativeBackendCallMirRequestValidation[ctx] struct { valid: int, reason_code: str }

func mir_native_backend_call_mir_validation(valid: int, reason_code: str, ctx: &Arena) MirNativeBackendCallMirRequestValidation[ctx] {
    mut result: MirNativeBackendCallMirRequestValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_native_backend_make_call_mir_request(base_request: abi_request.MirNativeBackendAbiRequest[ctx], table: call_mir.MirFunctionCallTable[ctx], ctx: &Arena) MirNativeBackendCallMirRequest[ctx] {
    mut request: MirNativeBackendCallMirRequest[ctx];
    request.format = std.Clone(ctx, "gust.native_backend.call_mir_request.v1");
    request.base_request = base_request;
    request.call_mir_table = table;
    return request;
}

func mir_native_backend_call_mir_request_is_valid(request: MirNativeBackendCallMirRequest[ctx], ctx: &Arena) MirNativeBackendCallMirRequestValidation[ctx] {
    if std.str_eq(request.format, "gust.native_backend.call_mir_request.v1") == 0 {
        return mir_native_backend_call_mir_validation(0, "call_mir_request_unknown_format", ctx);
    }
    mut base_validation := abi_request.mir_native_backend_abi_request_is_valid(request.base_request, ctx);
    if base_validation.valid == 0 {
        return mir_native_backend_call_mir_validation(0, "call_mir_request_base_invalid", ctx);
    }
    mut call_validation := call_mir.mir_function_call_table_validate(
        request.call_mir_table,
        request.base_request.abi_authority_table,
        ctx
    );
    if call_validation.valid == 0 {
        return mir_native_backend_call_mir_validation(0, call_validation.reason_code, ctx);
    }
    return mir_native_backend_call_mir_validation(1, "call_mir_request_valid", ctx);
}

func mir_serialize_native_backend_call_mir_request(request: MirNativeBackendCallMirRequest[ctx], ctx: &Arena) str {
    mut validation := mir_native_backend_call_mir_request_is_valid(request, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: gust.native_backend.call_mir_request.v1\n";
    output = std.Concat(output, call_mir.mir_serialize_function_call_for_request(
        request.call_mir_table,
        request.base_request.abi_authority_table,
        ctx
    ));
    output = std.Concat(output, "abi_request_begin\n");
    output = std.Concat(output, abi_request.mir_serialize_native_backend_abi_request(request.base_request, ctx));
    output = std.Concat(output, "abi_request_end\n");
    return std.Clone(ctx, output);
}
