// Phase 16.1 ABI-authority extension of the canonical native request.
//
// The Phase 15 resource request remains the carrier for canonical MIR, layout,
// and resource metadata. This immutable envelope adds exactly one
// compiler-produced ABI table. Consumers validate and query it; they do not
// reconstruct classifications, placements, call plans, or frame plans.

import "mir_native_backend_resource_request.gst" as resource_request;
import "mir_function_abi_authority.gst" as abi;

type MirNativeBackendAbiRequest[ctx] struct {
    format: str,
    base_request: resource_request.MirNativeBackendResourceRequest[ctx],
    abi_authority_table: abi.MirFunctionAbiAuthorityTable[ctx]
}

type MirNativeBackendAbiRequestValidation[ctx] struct {
    valid: int,
    reason_code: str
}

func mir_native_backend_abi_request_validation(valid: int, reason_code: str, ctx: &Arena) MirNativeBackendAbiRequestValidation[ctx] {
    mut result: MirNativeBackendAbiRequestValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_native_backend_make_abi_request(base_request: resource_request.MirNativeBackendResourceRequest[ctx], abi_table: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) MirNativeBackendAbiRequest[ctx] {
    mut request: MirNativeBackendAbiRequest[ctx];
    request.format = std.Clone(ctx, "gust.native_backend.abi_request.v1");
    request.base_request = base_request;
    request.abi_authority_table = abi_table;
    return request;
}

// Patch 16.1 starts with an empty ABI table. Later bounded capabilities extend
// this exact request path instead of adding a backend classifier or worker call
// planner.
func mir_native_backend_make_empty_abi_request(base_request: resource_request.MirNativeBackendResourceRequest[ctx], ctx: &Arena) MirNativeBackendAbiRequest[ctx] {
    mut table := abi.mir_function_abi_make_empty_table(
        base_request.base_request.layout_table.target.target_id,
        base_request.base_request.target_triple,
        ctx
    );
    return mir_native_backend_make_abi_request(base_request, table, ctx);
}

// Malformed ABI metadata is rejected before worker execution, driver
// discovery, request publication, object creation, linking, or output change.
func mir_native_backend_abi_request_is_valid(request: MirNativeBackendAbiRequest[ctx], ctx: &Arena) MirNativeBackendAbiRequestValidation[ctx] {
    if std.str_eq(request.format, "gust.native_backend.abi_request.v1") == 0 {
        return mir_native_backend_abi_request_validation(0, "abi_request_unknown_format", ctx);
    }
    mut base_validation := resource_request.mir_native_backend_resource_request_is_valid(request.base_request, ctx);
    if base_validation.valid == 0 {
        return mir_native_backend_abi_request_validation(0, "abi_request_base_request_invalid", ctx);
    }
    mut abi_validation := abi.mir_function_abi_authority_table_validate(
        request.abi_authority_table,
        request.base_request.base_request.layout_table,
        request.base_request.resource_authority_table,
        ctx
    );
    if abi_validation.valid == 0 {
        return mir_native_backend_abi_request_validation(0, abi_validation.reason_code, ctx);
    }
    return mir_native_backend_abi_request_validation(1, "abi_request_valid", ctx);
}

// ABI metadata serializes before the existing resource and canonical request,
// so a deserializer can reject inconsistent ABI data before worker execution.
func mir_serialize_native_backend_abi_request(request: MirNativeBackendAbiRequest[ctx], ctx: &Arena) str {
    mut validation := mir_native_backend_abi_request_is_valid(request, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: gust.native_backend.abi_request.v1\n";
    output = std.Concat(
        output,
        abi.mir_serialize_function_abi_authority_table_for_request(
            request.abi_authority_table,
            request.base_request.base_request.layout_table,
            request.base_request.resource_authority_table,
            ctx
        )
    );
    output = std.Concat(output, "resource_request_begin\n");
    output = std.Concat(
        output,
        resource_request.mir_serialize_native_backend_resource_request(request.base_request, ctx)
    );
    output = std.Concat(output, "resource_request_end\n");
    return std.Clone(ctx, output);
}

// Canonical consumer adapters. MIR-to-C, Cranelift, runtime-facing calls, and
// diagnostics call these compiler-owned queries rather than recomputing ABI.
func mir_native_backend_function_abi(request: MirNativeBackendAbiRequest[ctx], function_id: str, target_id: str, ctx: &Arena) abi.MirFunctionAbiQuery[ctx] {
    return abi.mir_function_abi(request.abi_authority_table, function_id, target_id, ctx);
}

func mir_native_backend_classify_abi_value(request: MirNativeBackendAbiRequest[ctx], type_id: str, position: str, target_id: str, ctx: &Arena) abi.MirAbiClassificationQuery[ctx] {
    return abi.mir_classify_abi_value(request.abi_authority_table, type_id, position, target_id, ctx);
}

func mir_native_backend_parameter_placements(request: MirNativeBackendAbiRequest[ctx], abi_id: str, ctx: &Arena) Index[std.Vector[abi.MirAbiParameterPlacement[ctx], ctx], ctx] {
    return abi.mir_parameter_placements(request.abi_authority_table, abi_id, ctx);
}

func mir_native_backend_result_placements(request: MirNativeBackendAbiRequest[ctx], abi_id: str, ctx: &Arena) Index[std.Vector[abi.MirAbiResultPlacement[ctx], ctx], ctx] {
    return abi.mir_result_placements(request.abi_authority_table, abi_id, ctx);
}

func mir_native_backend_call_plan(request: MirNativeBackendAbiRequest[ctx], call_site_id: str, expected_abi_id: str, ctx: &Arena) abi.MirAbiCallPlanQuery[ctx] {
    return abi.mir_abi_call_plan(request.abi_authority_table, call_site_id, expected_abi_id, ctx);
}

func mir_native_backend_frame_plan(request: MirNativeBackendAbiRequest[ctx], function_id: str, target_id: str, ctx: &Arena) abi.MirDynamicFramePlanQuery[ctx] {
    return abi.mir_abi_frame_plan(request.abi_authority_table, function_id, target_id, ctx);
}

func mir_native_backend_validate_abi_compatibility(request: MirNativeBackendAbiRequest[ctx], expected_abi_id: str, actual_abi_id: str, ctx: &Arena) abi.MirAbiCompatibilityQuery[ctx] {
    return abi.mir_validate_abi_compatibility(request.abi_authority_table, expected_abi_id, actual_abi_id, ctx);
}
