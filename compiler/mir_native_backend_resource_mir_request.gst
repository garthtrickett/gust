// Phase 15.2 canonical resource-MIR extension of the Phase 15.1 request.
//
// The compiler serializes one resource authority table and one canonical
// resource-MIR table. The worker validates both before lowering and never
// reconstructs identity or state from source or backend storage names.

import "mir_native_backend_resource_request.gst" as resource_request;
import "mir_resource_value.gst" as resource_mir;

type MirNativeBackendResourceMirRequest[ctx] struct {
    format: str,
    base_request: resource_request.MirNativeBackendResourceRequest[ctx],
    resource_mir_table: resource_mir.MirResourceMirTable[ctx]
}

type MirNativeBackendResourceMirRequestValidation[ctx] struct {
    valid: int,
    reason_code: str
}

func mir_native_backend_resource_mir_request_validation(valid: int, reason_code: str, ctx: &Arena) MirNativeBackendResourceMirRequestValidation[ctx] {
    mut result: MirNativeBackendResourceMirRequestValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_native_backend_make_resource_mir_request(base_request: resource_request.MirNativeBackendResourceRequest[ctx], resource_mir_table: resource_mir.MirResourceMirTable[ctx], ctx: &Arena) MirNativeBackendResourceMirRequest[ctx] {
    mut request: MirNativeBackendResourceMirRequest[ctx];
    request.format = std.Clone(ctx, "gust.native_backend.resource_mir_request.v1");
    request.base_request = base_request;
    request.resource_mir_table = resource_mir_table;
    return request;
}

func mir_native_backend_resource_mir_request_is_valid(request: MirNativeBackendResourceMirRequest[ctx], ctx: &Arena) MirNativeBackendResourceMirRequestValidation[ctx] {
    if std.str_eq(request.format, "gust.native_backend.resource_mir_request.v1") == 0 {
        return mir_native_backend_resource_mir_request_validation(0, "resource_mir_request_unknown_format", ctx);
    }
    mut base_validation := resource_request.mir_native_backend_resource_request_is_valid(
        request.base_request,
        ctx
    );
    if base_validation.valid == 0 {
        return mir_native_backend_resource_mir_request_validation(0, base_validation.reason_code, ctx);
    }
    // Phase 15.3 move-state validation is compiler-owned and runs before any
    // driver discovery, request publication, object creation, or output access.
    mut move_validation := resource_mir.mir_resource_move_state_validate(
        request.resource_mir_table,
        request.base_request.resource_authority_table,
        ctx
    );
    if move_validation.valid == 0 {
        return mir_native_backend_resource_mir_request_validation(0, move_validation.reason_code, ctx);
    }
    mut resource_validation := resource_mir.mir_resource_mir_table_validate(
        request.resource_mir_table,
        request.base_request.resource_authority_table,
        request.base_request.base_request.layout_table,
        ctx
    );
    if resource_validation.valid == 0 {
        return mir_native_backend_resource_mir_request_validation(0, resource_validation.reason_code, ctx);
    }
    return mir_native_backend_resource_mir_request_validation(1, "resource_mir_request_valid", ctx);
}

func mir_serialize_native_backend_resource_mir_request(request: MirNativeBackendResourceMirRequest[ctx], ctx: &Arena) str {
    mut validation := mir_native_backend_resource_mir_request_is_valid(request, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: gust.native_backend.resource_mir_request.v1\n";
    output = std.Concat(
        output,
        resource_mir.mir_serialize_resource_mir_for_request(
            request.resource_mir_table,
            request.base_request.resource_authority_table,
            request.base_request.base_request.layout_table,
            ctx
        )
    );
    output = std.Concat(output, "resource_authority_request_begin\n");
    output = std.Concat(
        output,
        resource_request.mir_serialize_native_backend_resource_request(
            request.base_request,
            ctx
        )
    );
    output = std.Concat(output, "resource_authority_request_end\n");
    return std.Clone(ctx, output);
}

func mir_native_backend_resource_value_of(request: MirNativeBackendResourceMirRequest[ctx], value_id: str, ctx: &Arena) resource_mir.MirResourceValueQuery[ctx] {
    return resource_mir.mir_resource_value_by_id(request.resource_mir_table, value_id, ctx);
}

func mir_native_backend_resource_carrier_of(request: MirNativeBackendResourceMirRequest[ctx], carrier_id: str, ctx: &Arena) resource_mir.MirResourceCarrierQuery[ctx] {
    return resource_mir.mir_resource_carrier_by_id(request.resource_mir_table, carrier_id, ctx);
}

func mir_native_backend_resource_operation_of(request: MirNativeBackendResourceMirRequest[ctx], operation_id: str, ctx: &Arena) resource_mir.MirResourceOperationQuery[ctx] {
    return resource_mir.mir_resource_operation_by_id(request.resource_mir_table, operation_id, ctx);
}

func mir_native_backend_resource_move_diagnostic(request: MirNativeBackendResourceMirRequest[ctx], ctx: &Arena) str {
    mut validation := resource_mir.mir_resource_move_state_validate(
        request.resource_mir_table,
        request.base_request.resource_authority_table,
        ctx
    );
    return resource_mir.mir_resource_move_diagnostic_text(validation, ctx);
}

