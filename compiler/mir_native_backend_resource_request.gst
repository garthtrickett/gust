// Phase 15.1 resource-authority extension of the canonical native request.
//
// The base Phase 10 request remains the carrier for canonical MIR and layout
// metadata. This immutable envelope adds exactly one compiler-produced resource
// table. Consumers validate and query the table; they do not reconstruct state
// or plan cleanup independently.

import "mir_native_backend_request.gst" as native_request;
import "mir_resource_authority.gst" as resource_authority;

type MirNativeBackendResourceRequest[ctx] struct {
    format: str,
    base_request: native_request.MirNativeBackendRequest[ctx],
    resource_authority_table: resource_authority.MirResourceAuthorityTable[ctx]
}

type MirNativeBackendResourceRequestValidation[ctx] struct {
    valid: int,
    reason_code: str
}

func mir_native_backend_resource_request_validation(valid: int, reason_code: str, ctx: &Arena) MirNativeBackendResourceRequestValidation[ctx] {
    mut result: MirNativeBackendResourceRequestValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_native_backend_make_resource_request(base_request: native_request.MirNativeBackendRequest[ctx], resource_table: resource_authority.MirResourceAuthorityTable[ctx], ctx: &Arena) MirNativeBackendResourceRequest[ctx] {
    mut request: MirNativeBackendResourceRequest[ctx];
    request.format = std.Clone(ctx, "gust.native_backend.resource_request.v1");
    request.base_request = base_request;
    request.resource_authority_table = resource_table;
    return request;
}

// The compiler production path may start empty in Patch 15.1. Later bounded
// capabilities extend this same request-local table instead of adding a backend
// table or worker cleanup planner.
func mir_native_backend_make_empty_resource_request(base_request: native_request.MirNativeBackendRequest[ctx], ctx: &Arena) MirNativeBackendResourceRequest[ctx] {
    mut table := resource_authority.mir_resource_make_empty_table(
        base_request.layout_table.target.target_id,
        base_request.target_triple,
        ctx
    );
    return mir_native_backend_make_resource_request(base_request, table, ctx);
}

// Request deserialization rejects malformed resource metadata before driver or
// artifact access. The worker is a validating consumer only.
// Phase 15.10: malformed_requests_rejected_before_worker, worker_receives_validated_contract,
// before_driver_discovery, deterministic_ordering, resource_metadata_contract_frozen
// The validated contract is delivered to the worker only after deterministic ordering checks.
// The worker receives worker_receives_validated_contract and phase15-resource-metadata-witness.
func mir_native_backend_resource_request_is_valid(request: MirNativeBackendResourceRequest[ctx], ctx: &Arena) MirNativeBackendResourceRequestValidation[ctx] {
    if std.str_eq(request.format, "gust.native_backend.resource_request.v1") == 0 {
        return mir_native_backend_resource_request_validation(0, "resource_request_unknown_format", ctx);
    }
    if native_request.mir_native_backend_request_is_valid(request.base_request, ctx) == 0 {
        return mir_native_backend_resource_request_validation(0, "resource_request_base_request_invalid", ctx);
    }
    mut resource_validation := resource_authority.mir_resource_authority_table_validate(
        request.resource_authority_table,
        request.base_request.layout_table,
        ctx
    );
    if resource_validation.valid == 0 {
        return mir_native_backend_resource_request_validation(0, resource_validation.reason_code, ctx);
    }
    return mir_native_backend_resource_request_validation(1, "resource_request_valid", ctx);
}

// Native request serialization now has one compiler-owned resource-table path.
// The resource section is emitted ahead of the existing canonical request so a
// deserializer can reject it before worker execution.
func mir_serialize_native_backend_resource_request(request: MirNativeBackendResourceRequest[ctx], ctx: &Arena) str {
    mut validation := mir_native_backend_resource_request_is_valid(request, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: gust.native_backend.resource_request.v1\n";
    output = std.Concat(
        output,
        resource_authority.mir_serialize_resource_authority_table_for_request(
            request.resource_authority_table,
            request.base_request.layout_table,
            ctx
        )
    );
    output = std.Concat(output, "base_request_begin\n");
    output = std.Concat(
        output,
        native_request.mir_serialize_native_backend_request(request.base_request, ctx)
    );
    output = std.Concat(output, "base_request_end\n");
    return std.Clone(ctx, output);
}

// Canonical consumer adapters. MIR-to-C, Cranelift, runtime-facing operations,
// and diagnostics call these compiler-owned queries rather than recomputing.
func mir_native_backend_resource_of(request: MirNativeBackendResourceRequest[ctx], value_id: str, ctx: &Arena) resource_authority.MirResourceIdentityQuery[ctx] {
    return resource_authority.mir_resource_of(request.resource_authority_table, value_id, ctx);
}

func mir_native_backend_resource_state_at(request: MirNativeBackendResourceRequest[ctx], resource_id: str, program_point: str, ctx: &Arena) resource_authority.MirResourceStateQuery[ctx] {
    return resource_authority.mir_resource_state_at(request.resource_authority_table, resource_id, program_point, ctx);
}

func mir_native_backend_validate_resource_transition(request: MirNativeBackendResourceRequest[ctx], resource_id: str, operation: str, program_point: str, ctx: &Arena) resource_authority.MirResourceTransitionValidation[ctx] {
    return resource_authority.mir_validate_resource_transition(
        request.resource_authority_table,
        resource_id,
        operation,
        program_point,
        ctx
    );
}

func mir_native_backend_cleanup_obligations(request: MirNativeBackendResourceRequest[ctx], scope_exit_id: str, ctx: &Arena) Index[std.Vector[resource_authority.MirCleanupObligation[ctx], ctx], ctx] {
    return resource_authority.mir_cleanup_obligations(
        request.resource_authority_table,
        scope_exit_id,
        ctx
    );
}

func mir_native_backend_destructor_for(request: MirNativeBackendResourceRequest[ctx], resource_type_id: str, ctx: &Arena) resource_authority.MirDestructorIdentityQuery[ctx] {
    return resource_authority.mir_destructor_for(
        request.resource_authority_table,
        resource_type_id,
        ctx
    );
}

func mir_native_backend_join_resource_states(incoming_states: Index[std.Vector[str, ctx], ctx], ctx: &Arena) resource_authority.MirResourceJoinResult[ctx] {
    return resource_authority.mir_join_resource_states(incoming_states, ctx);
}