// Phase 16.12 freezes the serialized projection of the compiler-owned ABI
// authority. This module adds no ABI decisions: it delegates semantic
// validation to mir_native_backend_abi_request_is_valid and names the strict
// worker ingestion boundary used by both native consumers.

import "mir_native_backend_abi_request.gst" as abi_request;

type MirNativeBackendAbiMetadataValidation[ctx] struct {
    valid: int,
    reason_code: str
}

func mir_native_backend_abi_metadata_schema(ctx: &Arena) str {
    return std.Clone(ctx, "gust.compiler_abi_metadata_request.v1");
}

func mir_native_backend_abi_metadata_validation(valid: int, reason_code: str, ctx: &Arena) MirNativeBackendAbiMetadataValidation[ctx] {
    mut result: MirNativeBackendAbiMetadataValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

// abi_metadata_schema_frozen
// abi_metadata_deterministic_ordering_and_deduplication
// abi_metadata_validation_before_worker_driver_and_artifact_access
// worker_validates_but_does_not_invent_abi_classifications_placements_signatures_or_ownership_transfers
func mir_native_backend_abi_metadata_request_is_valid(request: abi_request.MirNativeBackendAbiRequest[ctx], ctx: &Arena) MirNativeBackendAbiMetadataValidation[ctx] {
    mut validation := abi_request.mir_native_backend_abi_request_is_valid(request, ctx);
    if validation.valid == 0 {
        return mir_native_backend_abi_metadata_validation(0, validation.reason_code, ctx);
    }
    return mir_native_backend_abi_metadata_validation(1, "abi_metadata_request_valid", ctx);
}

// Stable malformed-request reasons consumed before worker execution:
// abi_metadata_unknown_abi_id
// abi_metadata_duplicate_conflicting_record
// abi_metadata_unknown_layout_or_resource_id
// abi_metadata_mir_call_missing_metadata
// abi_metadata_without_mir_owner
// abi_metadata_impossible_placement
// abi_metadata_overlapping_stack_areas
// abi_metadata_invalid_hidden_result
// abi_metadata_signature_mismatch
// abi_metadata_target_mismatch
// abi_metadata_invalid_frame_restoration
// abi_metadata_resource_transfer_inconsistent
// abi_metadata_nondeterministic_ordering
