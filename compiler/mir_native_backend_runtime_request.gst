// Phase 17.1 runtime-authority extension of the canonical native request.
//
// The Phase 16 ABI request remains the carrier for canonical MIR, layout,
// resource, and ABI metadata. This immutable envelope adds exactly one
// compiler-produced runtime table. The worker validates and queries it; it
// never invents helper classifications, requirements, packages, compatibility
// decisions, or link-plan semantics from unresolved native symbols.

import "mir_native_backend_abi_request.gst" as abi_request;
import "mir_runtime_boundary_authority.gst" as runtime;

type MirNativeBackendRuntimeRequest[ctx] struct {
    format: str,
    base_request: abi_request.MirNativeBackendAbiRequest[ctx],
    runtime_authority_table: runtime.MirRuntimeBoundaryAuthorityTable[ctx]
}

type MirNativeBackendRuntimeRequestValidation[ctx] struct {
    valid: int,
    reason_code: str
}

func mir_native_backend_runtime_request_validation(valid: int, reason_code: str, ctx: &Arena) MirNativeBackendRuntimeRequestValidation[ctx] {
    mut result: MirNativeBackendRuntimeRequestValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_native_backend_make_runtime_request(base_request: abi_request.MirNativeBackendAbiRequest[ctx], runtime_table: runtime.MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) MirNativeBackendRuntimeRequest[ctx] {
    mut request: MirNativeBackendRuntimeRequest[ctx];
    request.format = std.Clone(ctx, "gust.native_backend.runtime_request.v1");
    request.base_request = base_request;
    request.runtime_authority_table = runtime_table;
    return request;
}

func mir_native_backend_make_empty_runtime_request(base_request: abi_request.MirNativeBackendAbiRequest[ctx], ctx: &Arena) MirNativeBackendRuntimeRequest[ctx] {
    mut table := runtime.mir_runtime_make_empty_table(
        base_request.abi_authority_table.target_id,
        base_request.abi_authority_table.target_triple,
        ctx
    );
    return mir_native_backend_make_runtime_request(base_request, table, ctx);
}

// Malformed runtime metadata stops before worker execution, driver discovery,
// request publication, object creation, linker access, or output replacement.
func mir_native_backend_runtime_request_is_valid(request: MirNativeBackendRuntimeRequest[ctx], ctx: &Arena) MirNativeBackendRuntimeRequestValidation[ctx] {
    if std.str_eq(request.format, "gust.native_backend.runtime_request.v1") == 0 {
        return mir_native_backend_runtime_request_validation(0, "runtime_request_unknown_format", ctx);
    }
    mut base_validation := abi_request.mir_native_backend_abi_request_is_valid(request.base_request, ctx);
    if base_validation.valid == 0 {
        return mir_native_backend_runtime_request_validation(0, "runtime_request_base_request_invalid", ctx);
    }
    if std.str_eq(request.runtime_authority_table.target_id, request.base_request.abi_authority_table.target_id) == 0 ||
       std.str_eq(request.runtime_authority_table.target_triple, request.base_request.abi_authority_table.target_triple) == 0
    {
        return mir_native_backend_runtime_request_validation(0, "runtime_target_mismatch", ctx);
    }
    mut runtime_validation := runtime.mir_runtime_boundary_authority_table_validate(
        request.runtime_authority_table,
        ctx
    );
    if runtime_validation.valid == 0 {
        return mir_native_backend_runtime_request_validation(0, runtime_validation.reason_code, ctx);
    }
    return mir_native_backend_runtime_request_validation(1, "runtime_request_valid", ctx);
}

// Runtime metadata serializes before the ABI/resource/canonical request, so
// missing or inconsistent ownership data cannot reach the worker or driver.
func mir_serialize_native_backend_runtime_request(request: MirNativeBackendRuntimeRequest[ctx], ctx: &Arena) str {
    mut validation := mir_native_backend_runtime_request_is_valid(request, ctx);
    if validation.valid == 0 {
        mut invalid := "format: invalid\nreason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := "format: gust.native_backend.runtime_request.v1\n";
    output = std.Concat(output, runtime.mir_serialize_runtime_boundary_authority_table_for_request(request.runtime_authority_table, ctx));
    output = std.Concat(output, "abi_request_begin\n");
    output = std.Concat(output, abi_request.mir_serialize_native_backend_abi_request(request.base_request, ctx));
    output = std.Concat(output, "abi_request_end\n");
    return std.Clone(ctx, output);
}

// Shared consumer adapters. Canonical MIR producers, MIR-to-C, Cranelift,
// runtime packaging, diagnostics, and Phase 9G call these compiler queries.
func mir_native_backend_runtime_helper_of(request: MirNativeBackendRuntimeRequest[ctx], operation_id: str, ctx: &Arena) runtime.MirRuntimeHelperQuery[ctx] { return runtime.mir_runtime_helper_of(request.runtime_authority_table, operation_id, ctx); }
func mir_native_backend_classify_runtime_helper(request: MirNativeBackendRuntimeRequest[ctx], helper_id: str, ctx: &Arena) runtime.MirRuntimeClassificationQuery[ctx] { return runtime.mir_classify_runtime_helper(request.runtime_authority_table, helper_id, ctx); }
func mir_native_backend_runtime_abi_for(request: MirNativeBackendRuntimeRequest[ctx], target_id: str, ctx: &Arena) runtime.MirRuntimeAbiQuery[ctx] { return runtime.mir_runtime_abi_for(request.runtime_authority_table, target_id, ctx); }
func mir_native_backend_runtime_symbol_for(request: MirNativeBackendRuntimeRequest[ctx], helper_id: str, target_id: str, ctx: &Arena) runtime.MirRuntimeSymbolQuery[ctx] { return runtime.mir_runtime_symbol_for(request.runtime_authority_table, helper_id, target_id, ctx); }
func mir_native_backend_validate_runtime_symbol_spelling(request: MirNativeBackendRuntimeRequest[ctx], symbol_id: str, proposed_spelling: str, ctx: &Arena) runtime.MirRuntimeAuthorityValidation[ctx] { return runtime.mir_runtime_validate_symbol_spelling(request.runtime_authority_table, symbol_id, proposed_spelling, ctx); }
func mir_native_backend_runtime_requirements(request: MirNativeBackendRuntimeRequest[ctx], program_id: str, ctx: &Arena) Index[std.Vector[runtime.MirRuntimeRequirement[ctx], ctx], ctx] { return runtime.mir_runtime_requirements(request.runtime_authority_table, program_id, ctx); }
// Phase 17.3 deterministic deduplicated requirement table plus the per-operation
// lookups. The worker validates these rows; it never synthesizes a missing one.
func mir_native_backend_runtime_requirement_table(request: MirNativeBackendRuntimeRequest[ctx], program_id: str, ctx: &Arena) Index[std.Vector[runtime.MirRuntimeRequirement[ctx], ctx], ctx] { return runtime.mir_runtime_requirement_table(request.runtime_authority_table, program_id, ctx); }
func mir_native_backend_runtime_requirement_for(request: MirNativeBackendRuntimeRequest[ctx], mir_operation_id: str, ctx: &Arena) runtime.MirRuntimeRequirementQuery[ctx] { return runtime.mir_runtime_requirement_for(request.runtime_authority_table, mir_operation_id, ctx); }
func mir_native_backend_runtime_mir_reference_for(request: MirNativeBackendRuntimeRequest[ctx], mir_operation_id: str, ctx: &Arena) runtime.MirRuntimeMirReferenceQuery[ctx] { return runtime.mir_runtime_mir_reference_for(request.runtime_authority_table, mir_operation_id, ctx); }
func mir_native_backend_runtime_component_for(request: MirNativeBackendRuntimeRequest[ctx], helper_id: str, target_id: str, ctx: &Arena) runtime.MirRuntimeComponentQuery[ctx] { return runtime.mir_runtime_component_for(request.runtime_authority_table, helper_id, target_id, ctx); }
func mir_native_backend_select_runtime_package(request: MirNativeBackendRuntimeRequest[ctx], requirements: Index[std.Vector[runtime.MirRuntimeRequirement[ctx], ctx], ctx], target_id: str, ctx: &Arena) runtime.MirRuntimePackageQuery[ctx] { return runtime.mir_select_runtime_package(request.runtime_authority_table, requirements, target_id, ctx); }
func mir_native_backend_validate_runtime_compatibility(request: MirNativeBackendRuntimeRequest[ctx], requirements: Index[std.Vector[runtime.MirRuntimeRequirement[ctx], ctx], ctx], package_id: str, ctx: &Arena) runtime.MirRuntimeCompatibilityQuery[ctx] { return runtime.mir_validate_runtime_compatibility(request.runtime_authority_table, requirements, package_id, ctx); }
func mir_native_backend_runtime_link_plan(request: MirNativeBackendRuntimeRequest[ctx], program_id: str, package_id: str, ctx: &Arena) runtime.MirRuntimeLinkPlanQuery[ctx] { return runtime.mir_runtime_link_plan(request.runtime_authority_table, program_id, package_id, ctx); }
