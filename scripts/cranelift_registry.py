#!/usr/bin/env python3
"""Validate and project the canonical Cranelift feature registry."""

import argparse
import json
import re
import sys
import tempfile
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
SCHEMA = ROOT / "scripts/cranelift_feature_registry.schema.json"
DEFERRED = {"deferred", "inherited_deferred", "candidate_deferred"}
REPLACED = {"replaced"}
AMBIGUOUS = {"", "unknown", "tbd", "ownerless", "ambiguous"}

TOP_FIELDS = {
    "schema", "schema_version", "registry_version", "registry_status",
    "current_phase", "closed_phase_versions", "closure_snapshots",
    "opening_snapshots", "phase14_layout_authority", "residual_snapshots",
    "planning_categories", "supported_values", "legacy_views", "entries",
}
ENTRY_FIELDS = {
    "id", "origin_phase", "parent", "feature_family", "ci_family", "status",
    "route_owner", "worker_capability_owner", "diagnostic_owner",
    "source_fixture", "canonical_mir_fixture", "differential_case_id",
    "deferral_reason", "future_destination_phase", "closure_version", "evidence",
}
PHASE13_CAPABILITY_FIELDS = {
    "capability_id", "capability_decision_owner", "capability_decision",
    "capability_reason_code", "expected_failure_stage",
}
PHASE13_CAPABILITY_ID = "phase13_generic_source_to_mir"
PHASE13_CAPABILITY_OWNER = "compiler_generic_native_capability_planner"
PHASE13_CAPABILITY_DECISIONS = {
    "supported", "deferred", "source_or_type_failure",
}
PHASE13_SCALAR_EXPRESSION_ENTRY_ID = "p13_scalar_multiply_i32"
PHASE13_SCALAR_EXPRESSION_SELECTED_OPERATIONS = ["MulI32", "SubI32"]
PHASE13_SCALAR_EXPRESSION_COMPOSITION_OPERATIONS = ["AddI32", "SgtI32"]
PHASE13_SCALAR_EXPRESSION_GRAMMAR = (
    "left_associated_non_negative_i32_literal_chain_intermediates_0_to_255"
)
PHASE13_MULTIPLE_LOCALS_ENTRY_ID = (
    "p13_two_local_update_branch_source_route"
)
PHASE13_MULTIPLE_LOCALS_SELECTED_OPERATIONS = [
    "LocalI32Set",
    "LocalI32Read",
    "LocalI32AddI32Literal",
    "LocalI32SubI32Literal",
    "LocalI32MulI32Literal",
]
PHASE13_MULTIPLE_LOCALS_COMPOSITION_FEATURES = [
    "multiple_local_declaration_order",
    "repeated_assignment",
    "multi_local_expression",
    "branch_arm_assignment",
    "post_join_assignment",
    "direct_call_sequence",
    "supported_loop_state",
    "source_location_provenance",
]
PHASE13_MULTIPLE_LOCALS_SEQUENCING_POLICY = (
    "source_order_stable_local_indices_and_definite_assignment_"
    "intersection_at_cfg_joins"
)
PHASE13_NESTED_STRUCTURED_CFG_ENTRY_ID = (
    "p13_nested_local_update_branch_source_route"
)
PHASE13_NESTED_STRUCTURED_CFG_SHAPES = [
    "nested_if_else",
    "branch_inside_branch_arm",
    "sequential_branches",
    "multiple_joins",
    "branch_local_values",
    "early_returns",
    "nested_expression_conditions",
]
PHASE13_NESTED_STRUCTURED_CFG_INVARIANTS = [
    "reachability",
    "explicit_termination",
    "target_existence",
    "edge_argument_arity",
    "edge_argument_type",
    "join_consistency",
    "block_parameter_ownership",
]
PHASE13_NESTED_STRUCTURED_CFG_BLOCK_POLICY = (
    "source_order_cfg_indices_with_origin_and_stable_predecessor_metadata"
)
PHASE13_NESTED_STRUCTURED_CFG_DEFERRED_REASONS = [
    "deferred_p13_structured_cfg_short_circuit",
    "deferred_p13_structured_cfg_condition_operator",
]
PHASE13_GENERAL_LOOP_ENTRY_ID = (
    "p13_general_loop_backedge_source_route"
)
PHASE13_GENERAL_LOOP_SHAPES = [
    "single_loop_carried_scalar",
    "multiple_loop_carried_scalars",
    "conditional_header_exit",
]
PHASE13_GENERAL_LOOP_PARAMETER_POLICY = (
    "one_or_two_i32_block_parameters_in_source_declaration_order"
)
PHASE13_GENERAL_LOOP_INVARIANTS = [
    "loop_header_identity",
    "dominance",
    "reachability",
    "reducibility",
    "reachable_exit",
    "termination_structure",
    "backedge_argument_arity",
    "backedge_argument_type",
]
PHASE13_GENERAL_LOOP_DEFERRED_REASONS = [
    "deferred_p13_general_loop_early_return",
    "deferred_p13_general_loop_nested_loop",
    "deferred_p13_general_loop_body_control_flow",
    "deferred_p13_general_loop_condition_operator",
]
PHASE13_PARAMETER_ARGUMENT_ENTRY_ID = (
    "p13_parameterized_local_call_branch_source_route"
)
PHASE13_PARAMETER_ARGUMENT_SHAPES = [
    "direct_multi_argument_call",
    "imported_multi_argument_call_inherited",
    "repeated_calls",
    "call_result_local_assignment",
    "call_result_larger_expression",
    "call_result_branch_condition",
    "call_result_cfg_join",
    "call_result_loop_carried_state",
]
PHASE13_PARAMETER_ARGUMENT_POLICY = (
    "int_parameters_in_source_declaration_order_with_function_namespace_"
    "and_source_location_provenance"
)
PHASE13_PARAMETER_ARGUMENT_INVARIANTS = [
    "argument_count",
    "argument_order",
    "argument_scalar_type",
    "result_scalar_type",
    "parameter_identity",
    "parameter_declaration_order",
    "function_namespace",
    "source_location",
    "scalar_type",
]
PHASE13_PARAMETER_ARGUMENT_DEFERRED_REASONS = [
    "deferred_p13_parameter_argument_aggregate_parameter",
    "deferred_p13_parameter_argument_aggregate_return",
    "deferred_p13_parameter_argument_target_dependent_abi",
]
PHASE13_DIRECT_CALL_GRAPH_ENTRY_ID = (
    "p13_multi_function_direct_call_graph_source_route"
)
PHASE13_DIRECT_CALL_GRAPH_POLICY_IDS = [
    "p13_recursive_direct_call_policy",
    "p13_mutual_recursive_direct_call_policy",
    "p13_indirect_direct_call_policy",
    "p13_function_value_call_policy",
]
PHASE13_DIRECT_CALL_GRAPH_SHAPES = [
    "forward_calls",
    "several_calls_in_one_function",
    "several_callers_of_one_callee",
    "call_result_as_later_call_argument",
    "call_result_arithmetic_composition",
    "qualified_deterministic_helper_symbols",
    "branch_and_join_composition_inherited",
    "supported_loop_call_composition_inherited",
]
PHASE13_DIRECT_CALL_GRAPH_INVARIANTS = [
    "duplicate_declarations",
    "missing_callees",
    "incompatible_declarations",
    "invalid_scalar_signatures",
    "invalid_call_result_use",
    "direct_recursion",
    "mutual_recursion",
]
PHASE13_DIRECT_CALL_GRAPH_DEFERRED_REASONS = [
    "deferred_p13_recursive_direct_call_policy",
    "deferred_p13_mutual_recursive_direct_call_policy",
]
PHASE13_BROADER_RUNTIME_CALL_ENTRY_ID = (
    "p13_imported_predicate_update_branch_source_route"
)
PHASE13_BROADER_RUNTIME_CALL_POLICY_ID = "p13_unapproved_host_symbol_policy"
PHASE13_BROADER_RUNTIME_APPROVED_SYMBOLS = [
    "abs",
    "toupper",
    "tiny_host_add_one_i32",
    "tiny_host_add_i32",
    "tiny_host_is_positive_i32",
]
PHASE13_BROADER_RUNTIME_APPROVED_SIGNATURES = [
    "abs(int)->int:RuntimeCall",
    "toupper(int)->int:ExternFunction",
    "tiny_host_add_one_i32(int)->int:ExternFunction",
    "tiny_host_add_i32(int,int)->int:ExternFunction",
    "tiny_host_is_positive_i32(int)->int:ExternFunction",
]
PHASE13_BROADER_RUNTIME_SHAPES = [
    "multiple_scalar_arguments",
    "multiple_approved_calls_in_one_function",
    "imported_result_local_assignment",
    "imported_result_expression",
    "imported_result_control_flow",
    "source_module_and_host_call_composition",
]
PHASE13_BROADER_RUNTIME_UNSUPPORTED_FORMS = [
    "unapproved_host_symbol",
    "wrong_argument_count",
    "wrong_scalar_argument_type",
    "unsupported_return_convention",
    "variadic_call",
    "indirect_call",
    "layout_sensitive_call",
    "non_scalar_abi_value",
]

PHASE13_SOURCE_METADATA_ENTRY_IDS = [
    "p13_resource_metadata_source_route",
    "p13_native_boundary_metadata_source_route",
]
PHASE13_SOURCE_METADATA_ROUTES = [
    "compiler/phase13_source_resource_metadata_source.gst",
    "compiler/phase13_scalar_nested_mixed_source.gst",
    "compiler/phase13_nested_structured_cfg_source.gst",
    "compiler/phase13_direct_call_graph_source.gst",
    "compiler/phase13_runtime_multiple_calls_source.gst",
]
PHASE13_SOURCE_METADATA_MALFORMED_FIXTURES = [
    "compiler/fixtures/phase13_source_metadata_missing_owner.mir",
    "compiler/fixtures/phase13_source_metadata_invalid_source_location.mir",
    "compiler/fixtures/phase13_source_metadata_incompatible_class.mir",
    "compiler/fixtures/phase13_source_metadata_invalid_proof_state.mir",
    "compiler/fixtures/phase13_source_metadata_incorrect_codegen_relevance.mir",
    "compiler/fixtures/phase13_source_metadata_inconsistent_serialization.mir",
]
PHASE13_SOURCE_METADATA_DEFERRED_RESOURCE_SEMANTICS = [
    "resource_values",
    "movement",
    "cleanup",
    "destructor_scheduling",
    "destruction_lowering",
]
PHASE13_COMPOSITION_CASE_FIELDS = {
    "id", "owner_entry_id", "ci_family", "source_fixture",
    "positive_expectation", "stderr_policy", "side_effect_policy",
    "failure_fixture", "covers_entry_ids",
}
PHASE13_DIFFERENTIAL_STDERR_POLICIES = {"stable_bytes", "ignored"}
PHASE13_DIFFERENTIAL_SIDE_EFFECT_POLICIES = {"none", "compare_tree"}
SUPPORTED_FIELDS = {
    "statuses", "origin_phases", "feature_families",
    "route_owners", "worker_capability_owners", "diagnostic_owners",
}
PHASE11_SNAPSHOT_FIELDS = {
    "closure_version", "immutable_fields", "entry_count",
    "classification_counts", "deferred_entry_ids", "entries",
    "byte_provenance", "comparison_policy",
}
PHASE11_SNAPSHOT_ENTRY_FIELDS = {
    "id", "classification", "feature_family", "route_owner",
    "source_fixture", "canonical_mir_fixture", "ci_family",
}
PHASE11_IMMUTABLE_FIELDS = (
    "id", "classification", "feature_family", "route_owner",
    "source_fixture", "canonical_mir_fixture", "ci_family",
)
PHASE13_OPENING_SNAPSHOT_FIELDS = {
    "opening_version", "inventory_version", "status",
    "predecessor_closure_version", "immutable_fields", "entries",
    "comparison_policy", "behavior_policy", "next_patch",
}
PHASE13_OPENING_SNAPSHOT_ENTRY_FIELDS = {"id", "parent"}
PHASE13_OPENING_IMMUTABLE_FIELDS = ("id", "parent")
PHASE13_AUDIT_FIELDS = {
    "version", "final_disposition", "replacement_residual_ids",
    "related_residual_ids", "justification",
}
PHASE13_RESIDUAL_SNAPSHOT_FIELDS = {
    "version", "status", "source_opening_version", "immutable_fields",
    "broad_description_bans", "resolution_policy", "freeze_policy", "rows",
}
PHASE13_RESIDUAL_ROW_FIELDS = {
    "id", "feature_family", "ci_family", "capability_owner",
    "diagnostic_owner", "capability", "concrete_reason",
    "destination_phase", "prerequisite_capability",
    "current_failure_stage", "positive_future_fixture",
    "negative_current_fixture", "diagnostic_reason_code",
    "source_phase13_entry_ids",
}
PHASE13_RESIDUAL_VERSION = "phase13_deferred_residue_v1"
PHASE13_RESIDUAL_STATUS = "frozen_for_future_phases"
PHASE13_RESIDUAL_IMMUTABLE_FIELDS = (
    "id", "feature_family", "ci_family", "capability_owner",
    "diagnostic_owner", "capability", "concrete_reason",
    "destination_phase", "prerequisite_capability",
    "current_failure_stage", "positive_future_fixture",
    "negative_current_fixture", "diagnostic_reason_code",
    "source_phase13_entry_ids",
)
PHASE13_RESIDUAL_BROAD_DESCRIPTION_BANS = (
    "broader_calls", "broader_CFG", "more_expressions", "more_imports",
    "unsupported_metadata", "broader_direct_and_imported_calls",
    "broader_scalar_expressions", "multiple_modules_and_source_imports",
)
PHASE13_RESIDUAL_FAILURE_STAGES = {
    "before_driver_discovery",
    "canonical_mir_validation_before_driver_discovery",
    "source_or_type_failure_before_driver_discovery",
}
PHASE13_CLOSURE_SNAPSHOT_FIELDS = {
    "closure_version", "status", "scope", "opening_version",
    "residual_version", "closure_guard", "ci_owner", "closure_wording",
    "non_claims", "required_contracts", "closure_assertions",
    "forbidden_replays", "opening_entry_count", "disposition_counts",
    "migrated_entry_ids", "replaced_entry_ids", "excluded_entry_ids",
    "residual_entry_count", "migrated_route_owner",
    "default_oracle_owner", "explicit_cranelift_fallback_policy",
    "worker_request_boundary", "artifact_owner", "differential_owner",
    "historical_owner", "evidence_replay_policy", "comparison_policy",
}
PHASE13_CLOSURE_VERSION = "phase13_closed_deferred_registry_parity_expansion"
PHASE13_CLOSURE_STATUS = "closed_declared_inventory_only"
PHASE13_CLOSURE_SCOPE = (
    "declared_phase13_deferred_parity_expansion_inventory_only"
)
PHASE13_CLOSURE_WORDING = (
    "The declared Phase 13 deferred-parity expansion inventory is complete. "
    "Migrated rows use the generic canonical-MIR route with focused differential "
    "evidence, while remaining unsupported capabilities are represented by "
    "narrower, explicitly owned future-phase deferrals."
)
PHASE13_CLOSURE_NON_CLAIMS = (
    "Cranelift_has_full_Gust_parity",
    "all_Gust_types_are_supported",
    "all_ABI_forms_are_supported",
    "all_control_flow_forms_are_supported",
    "resource_semantics_are_complete",
    "the_experimental_backend_is_production_complete",
)
PHASE13_CLOSURE_REQUIRED_CONTRACTS = (
    "phase13_opening_contract",
    "canonical_registry_schema",
    "registry_projection",
    "phase11_semantic_closure_summary",
    "phase13_capability_and_deferral_contract",
    "phase13_parent_traceability_contract",
    "phase13_deferred_residue_audit",
    "registry_derived_ci_family_projection",
    "semantic_route_architecture_contract",
    "reduced_manifest_architecture_contract",
    "three_level_test_mapping",
    "pr_fast_workflow_ownership",
    "heavy_guards_workflow_ownership",
    "historical_full_workflow_ownership",
    "phase13_generated_view_projection",
    "phase13_registry_differential_wiring",
    "separately_available_level3_historical_suite",
    "phase9g_artifact_ownership_contract",
    "mir_to_c_default_ownership",
    "explicit_cranelift_no_fallback_policy",
    "worker_request_isolation",
    "early_deferral_and_output_preservation_contracts",
)
PHASE13_CLOSURE_ASSERTIONS = (
    "every_phase13_opening_row_has_a_valid_final_disposition",
    "every_migrated_row_uses_generic_canonical_mir_routing",
    "every_remaining_deferral_is_concrete_and_owned",
    "no_exact_source_recognizer_was_introduced",
    "explicit_cranelift_cannot_fall_back_to_mir_to_c",
    "unsupported_cases_stop_before_driver_and_artifact_access",
    "mir_to_c_remains_the_default_oracle",
    "default_and_explicit_mir_to_c_remain_equivalent",
    "worker_receives_only_request_data_and_canonical_mir",
    "phase9g_owns_object_link_cleanup_and_publication",
    "active_totals_are_registry_derived",
    "generated_views_are_current",
    "ci_families_remain_registry_derived",
    "no_raw_registry_or_markdown_hash_contract_exists",
    "no_exact_matrix_total_is_backend_correctness",
    "full_historical_suite_remains_separately_runnable",
)
PHASE13_CLOSURE_FORBIDDEN_REPLAYS = (
    "every_phase13_differential_family",
    "full_phase9_through_phase13_historical_suite",
    "every_historical_native_fixture",
    "complete_object_and_link_failure_matrices",
    "release_or_packaging_matrices",
)
PHASE13_OPENING_VERSION = (
    "phase13_opening_inventory_rebased_on_phase12_5_framework"
)
PHASE13_INVENTORY_VERSION = "phase13_opening_inventory_v1"
PHASE13_COMPARISON_POLICY = (
    "semantic_ids_and_parent_relationships_only_generated_totals_and_"
    "markdown_are_derived"
)
PHASE13_BEHAVIOR_POLICY = (
    "registry_projection_and_guard_rebase_only_no_compiler_route_worker_"
    "MIR_request_object_link_package_CLI_or_workflow_change"
)

PHASE14_ENTRY_FIELDS = {
    "target_applicability", "current_failure_stage",
    "positive_future_fixture", "negative_current_fixture",
}
PHASE14_OPENING_SNAPSHOT_FIELDS = {
    "opening_version", "inventory_version", "status",
    "predecessor_closure_version", "immutable_fields", "entries",
    "residual_rebase", "ci_family_projection", "comparison_policy",
    "behavior_policy", "next_patch",
}
PHASE14_OPENING_SNAPSHOT_ENTRY_FIELDS = {
    "id", "parent", "feature_family", "ci_family", "capability_owner",
    "diagnostic_owner", "target_applicability", "status",
    "current_failure_stage", "positive_future_fixture",
    "negative_current_fixture",
}
PHASE14_RESIDUAL_REBASE_FIELDS = {
    "source_residual_id", "phase14_disposition",
    "selected_phase14_entry_ids", "reassigned_destination_phase",
    "reassigned_capability", "justification",
}
PHASE14_CI_PROJECTION_FIELDS = {
    "derivation", "family_ids", "workflow_policy",
}
PHASE14_OPENING_VERSION = (
    "phase14_opening_inventory_rebased_on_phase13_closure"
)
PHASE14_INVENTORY_VERSION = "phase14_opening_inventory_v1"
PHASE14_OPENING_STATUS = "ready_for_patch14_1"
PHASE14_TARGET_APPLICABILITY = (
    "all_declared_host_targets_from_phase14_target_authority"
)
PHASE14_COMPARISON_POLICY = (
    "semantic_opening_fields_parent_traceability_and_residual_rebase_only_"
    "generated_totals_and_markdown_are_derived"
)
PHASE14_BEHAVIOR_POLICY = (
    "registry_projection_guard_and_fixture_inventory_only_no_compiler_"
    "backend_runtime_MIR_request_object_link_package_CLI_or_level2_"
    "level3_workflow_change"
)
PHASE14_CI_DERIVATION = (
    "distinct_ci_family_values_from_phase14_opening_entries_in_first_"
    "occurrence_order"
)
PHASE14_CI_WORKFLOW_POLICY = (
    "planning_projection_only_no_phase14_level2_workflow_rows_until_"
    "capability_migration"
)
PHASE14_PLANNING_CATEGORIES = (
    "primitive_scalar_layout", "pointer_sized_integers", "conversions",
    "pointers_and_nullability", "stack_slots", "loads_and_stores",
    "strings_and_string_views", "arrays_and_slices", "structs",
    "enums_and_tagged_unions", "aggregate_basic_block_transport",
    "target_layout", "all_target_evidence",
)
PHASE14_CI_FAMILIES = (
    "primitive-layout", "conversions", "pointer-memory", "strings-views",
    "arrays-slices", "structs-enums", "aggregate-flow",
)
PHASE14_OPENING_ENTRY_IDS = (
    "p14_primitive_scalar_layout",
    "p14_pointer_sized_integer_layout",
    "p14_target_dependent_conversions",
    "p14_pointer_nullability_model",
    "p14_stack_slot_addressable_locals",
    "p14_typed_load_store_memory_access",
    "p14_string_and_string_view_layout",
    "p14_array_and_slice_layout",
    "p14_struct_field_layout",
    "p14_enum_tagged_union_layout",
    "p14_aggregate_basic_block_transport",
    "p14_target_layout_model",
    "p14_all_target_layout_evidence",
)
PHASE14_FAILURE_STAGES = {
    "before_driver_discovery",
    "canonical_mir_validation_before_driver_discovery",
    "source_or_type_failure_before_driver_discovery",
}

PHASE14_LAYOUT_AUTHORITY_FIELDS = {
    "version", "status", "authority_owner", "table_format",
    "semantic_types", "query_functions", "consumers", "identity_policy",
    "request_transport_policy", "rejection_classes", "hard_bans",
    "behavior_policy", "next_patch",
}
PHASE14_LAYOUT_CONSUMER_FIELDS = {
    "canonical_mir", "mir_to_c", "cranelift_worker",
    "runtime_descriptor", "diagnostics",
}
PHASE14_LAYOUT_AUTHORITY_VERSION = (
    "phase14_compiler_owned_layout_authority_v1"
)
PHASE14_LAYOUT_AUTHORITY_STATUS = "ready_for_patch14_2"
PHASE14_LAYOUT_TABLE_FORMAT = "gust.compiler_layout_table.v1"
PHASE14_LAYOUT_TYPES = (
    "MirTargetLayout", "MirTypeLayout", "MirFieldLayout",
    "MirVariantLayout", "MirElementStrideQuery", "MirMemoryAccessLayout",
)
PHASE14_LAYOUT_QUERIES = (
    "mir_layout_of", "mir_layout_field_layout",
    "mir_layout_variant_layout", "mir_layout_element_stride",
    "mir_layout_validate_memory_access",
)
PHASE14_LAYOUT_REJECTION_CLASSES = (
    "unknown_layout_id", "duplicate_conflicting_layout_id",
    "target_mismatch", "impossible_size_or_alignment",
    "invalid_field_offset", "invalid_variant_record",
)
PHASE14_LAYOUT_HARD_BANS = (
    "no_mir_to_c_owned_layout_table",
    "no_worker_owned_layout_selection",
    "no_runtime_hard_coded_duplicate_offsets",
    "no_diagnostic_layout_recomputation",
)
PHASE14_LAYOUT_IDENTITY_POLICY = (
    "deterministic_semantic_components_only_no_raw_file_registry_or_"
    "markdown_hash"
)
PHASE14_LAYOUT_REQUEST_POLICY = (
    "compiler_serializes_request_local_layout_table_worker_validates_"
    "without_selecting_layout"
)
PHASE14_LAYOUT_BEHAVIOR_POLICY = (
    "authority_and_transport_only_no_phase14_capability_migration_or_"
    "level2_level3_workflow_expansion"
)


class Error(RuntimeError):
    pass


def require(condition, message):
    if not condition:
        raise Error(message)


def read_json(path):
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise Error(f"missing file: {path.relative_to(ROOT)}") from exc
    except json.JSONDecodeError as exc:
        raise Error(
            f"invalid JSON in {path.relative_to(ROOT)}:"
            f"{exc.lineno}:{exc.colno}: {exc.msg}"
        ) from exc
    require(isinstance(value, dict), f"{path.relative_to(ROOT)} must be an object")
    return value


def text(value, context):
    require(isinstance(value, str), f"{context} must be a string")
    require(value.strip().lower() not in AMBIGUOUS, f"{context} is blank or ambiguous")
    return value


def unique_strings(value, context):
    require(isinstance(value, list), f"{context} must be an array")
    result = [text(item, f"{context}[{index}]") for index, item in enumerate(value)]
    require(len(result) == len(set(result)), f"{context} contains duplicates")
    return result


def fixture(value, context):
    value = text(value, context)
    if value == "none" or value.startswith("none_"):
        return
    require((ROOT / value).is_file(), f"{context} points to missing file: {value}")


def parse_record(line, prefix):
    fields = {}
    for segment in line[len(prefix):].split("|"):
        if not segment:
            continue
        require("=" in segment, f"invalid legacy segment: {segment}")
        key, value = segment.split("=", 1)
        require(key not in fields, f"legacy record repeats {key}")
        fields[key] = value
    return fields


def legacy_records(path, prefix):
    require(path.is_file(), f"missing legacy view: {path.relative_to(ROOT)}")
    return [
        parse_record(line, prefix)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.startswith(prefix)
    ]


def validate_phase11_snapshot_structure(registry):
    snapshots = registry["closure_snapshots"]
    require(
        isinstance(snapshots, dict)
        and set(snapshots) == {"phase11", "phase13"},
        "closure_snapshots must contain exactly phase11 and phase13",
    )
    snapshot = snapshots["phase11"]
    require(
        isinstance(snapshot, dict) and set(snapshot) == PHASE11_SNAPSHOT_FIELDS,
        "Phase 11 closure snapshot fields drifted",
    )
    require(
        snapshot["closure_version"] == registry["closed_phase_versions"]["phase11"],
        "Phase 11 closure snapshot version differs from closed_phase_versions",
    )
    require(
        snapshot["immutable_fields"] == list(PHASE11_IMMUTABLE_FIELDS),
        "Phase 11 immutable-field set drifted",
    )
    require(
        isinstance(snapshot["entry_count"], int) and snapshot["entry_count"] > 0,
        "Phase 11 closure snapshot entry_count must be positive",
    )
    classification_counts = snapshot["classification_counts"]
    require(
        isinstance(classification_counts, dict)
        and set(classification_counts) == {"migrated", "deferred", "excluded"},
        "Phase 11 closure snapshot classification fields drifted",
    )
    for key, value in classification_counts.items():
        require(
            isinstance(value, int) and value >= 0,
            f"Phase 11 closure snapshot classification {key} must be non-negative",
        )
    require(
        sum(classification_counts.values()) == snapshot["entry_count"],
        "Phase 11 closure snapshot classification totals do not match entry_count",
    )
    deferred_ids = unique_strings(
        snapshot["deferred_entry_ids"],
        "closure_snapshots.phase11.deferred_entry_ids",
    )
    require(
        len(deferred_ids) == classification_counts["deferred"],
        "Phase 11 deferred ID count differs from the deferred classification total",
    )
    require(snapshot["byte_provenance"] == "git_history",
            "Phase 11 byte provenance must be Git history")
    require(
        snapshot["comparison_policy"]
        == "semantic_fields_only_whitespace_prose_field_order_and_generated_layout_are_ignored",
        "Phase 11 semantic comparison policy drifted",
    )

    rows = snapshot["entries"]
    require(
        isinstance(rows, list) and len(rows) == snapshot["entry_count"],
        "Phase 11 closure snapshot rows do not match entry_count",
    )
    ids = set()
    row_classifications = Counter()
    for index, row in enumerate(rows):
        context = f"closure_snapshots.phase11.entries[{index}]"
        require(
            isinstance(row, dict) and set(row) == PHASE11_SNAPSHOT_ENTRY_FIELDS,
            f"{context} fields drifted",
        )
        entry_id = text(row["id"], f"{context}.id")
        require(entry_id not in ids, f"duplicate Phase 11 snapshot ID: {entry_id}")
        ids.add(entry_id)
        require(
            row["classification"] in classification_counts,
            f"{entry_id}: unknown snapshot classification {row['classification']}",
        )
        row_classifications[row["classification"]] += 1
        for field in (
            "feature_family", "route_owner", "source_fixture",
            "canonical_mir_fixture", "ci_family",
        ):
            text(row[field], f"{context}.{field}")
        fixture(row["source_fixture"], f"{context}.source_fixture")
        fixture(row["canonical_mir_fixture"],
                f"{context}.canonical_mir_fixture")

    require(
        dict(row_classifications) == {
            key: value for key, value in classification_counts.items() if value
        },
        "Phase 11 closure snapshot row classifications differ from its totals",
    )
    require(
        [row["id"] for row in rows if row["classification"] == "deferred"]
        == deferred_ids,
        "Phase 11 deferred ID inventory differs from snapshot rows",
    )
    return snapshot


def validate_phase13_opening_snapshot_structure(registry):
    snapshots = registry["opening_snapshots"]
    require(
        isinstance(snapshots, dict)
        and set(snapshots) == {"phase13", "phase14"},
        "opening_snapshots must contain exactly phase13 and phase14",
    )
    snapshot = snapshots["phase13"]
    require(
        isinstance(snapshot, dict)
        and set(snapshot) == PHASE13_OPENING_SNAPSHOT_FIELDS,
        "Phase 13 opening snapshot fields drifted",
    )
    require(
        snapshot["opening_version"] == PHASE13_OPENING_VERSION,
        "Phase 13 opening rebase version drifted",
    )
    require(
        snapshot["inventory_version"] == PHASE13_INVENTORY_VERSION,
        "Phase 13 opening inventory version drifted",
    )
    require(
        snapshot["status"] == "ready_for_patch13_1",
        "Phase 13 opening is not ready for Patch 13.1",
    )
    require(
        snapshot["predecessor_closure_version"]
        == registry["closed_phase_versions"]["phase11"],
        "Phase 13 predecessor differs from the Phase 11 semantic closure",
    )
    require(
        snapshot["immutable_fields"] == list(PHASE13_OPENING_IMMUTABLE_FIELDS),
        "Phase 13 opening immutable-field set drifted",
    )
    require(
        snapshot["comparison_policy"] == PHASE13_COMPARISON_POLICY,
        "Phase 13 opening comparison policy drifted",
    )
    require(
        snapshot["behavior_policy"] == PHASE13_BEHAVIOR_POLICY,
        "Phase 13 opening behavior-freeze policy drifted",
    )
    require(
        snapshot["next_patch"] == "13.1",
        "Phase 13 opening next patch must be 13.1",
    )

    rows = snapshot["entries"]
    require(
        isinstance(rows, list) and rows,
        "Phase 13 opening snapshot must contain rows",
    )
    ids = set()
    for index, row in enumerate(rows):
        context = f"opening_snapshots.phase13.entries[{index}]"
        require(
            isinstance(row, dict)
            and set(row) == PHASE13_OPENING_SNAPSHOT_ENTRY_FIELDS,
            f"{context} fields drifted",
        )
        entry_id = text(row["id"], f"{context}.id")
        require(
            entry_id not in ids,
            f"duplicate Phase 13 opening snapshot ID: {entry_id}",
        )
        ids.add(entry_id)
        parent = text(row["parent"], f"{context}.parent")
        require(
            parent.startswith(("phase11_entry:", "phase11_category:")),
            f"{entry_id}: invalid Phase 13 opening parent {parent}",
        )
    return snapshot


def validate_phase14_opening_snapshot_structure(registry):
    snapshots = registry["opening_snapshots"]
    snapshot = snapshots["phase14"]
    require(
        isinstance(snapshot, dict)
        and set(snapshot) == PHASE14_OPENING_SNAPSHOT_FIELDS,
        "Phase 14 opening snapshot fields drifted",
    )
    require(
        snapshot["opening_version"] == PHASE14_OPENING_VERSION,
        "Phase 14 opening rebase version drifted",
    )
    require(
        snapshot["inventory_version"] == PHASE14_INVENTORY_VERSION,
        "Phase 14 opening inventory version drifted",
    )
    require(
        snapshot["status"] == PHASE14_OPENING_STATUS,
        "Phase 14 opening is not ready for Patch 14.1",
    )
    require(
        snapshot["predecessor_closure_version"]
        == registry["closed_phase_versions"]["phase13"]
        == PHASE13_CLOSURE_VERSION,
        "Phase 14 predecessor differs from the scoped Phase 13 closure",
    )
    require(
        snapshot["immutable_fields"] == [
            "id", "parent", "feature_family", "ci_family",
            "capability_owner", "diagnostic_owner", "target_applicability",
        ],
        "Phase 14 opening immutable-field set drifted",
    )
    require(
        snapshot["comparison_policy"] == PHASE14_COMPARISON_POLICY,
        "Phase 14 opening comparison policy drifted",
    )
    require(
        snapshot["behavior_policy"] == PHASE14_BEHAVIOR_POLICY,
        "Phase 14 opening behavior-freeze policy drifted",
    )
    require(
        snapshot["next_patch"] == "14.1",
        "Phase 14 opening next patch must be 14.1",
    )

    rows = snapshot["entries"]
    require(
        isinstance(rows, list) and rows,
        "Phase 14 opening snapshot must contain rows",
    )
    ids = set()
    derived_families = []
    for index, row in enumerate(rows):
        context = f"opening_snapshots.phase14.entries[{index}]"
        require(
            isinstance(row, dict)
            and set(row) == PHASE14_OPENING_SNAPSHOT_ENTRY_FIELDS,
            f"{context} fields drifted",
        )
        entry_id = text(row["id"], f"{context}.id")
        require(
            re.fullmatch(r"p14_[A-Za-z0-9_]+", entry_id) is not None,
            f"{entry_id}: invalid Phase 14 opening ID",
        )
        require(
            entry_id not in ids,
            f"duplicate Phase 14 opening snapshot ID: {entry_id}",
        )
        ids.add(entry_id)
        parent = text(row["parent"], f"{context}.parent")
        require(
            parent.startswith(
                ("phase13_entry:", "phase13_residual:", "phase14_category:")
            ),
            f"{entry_id}: invalid Phase 14 opening parent {parent}",
        )
        for field in (
            "feature_family", "ci_family", "capability_owner",
            "diagnostic_owner", "target_applicability",
            "current_failure_stage",
        ):
            text(row[field], f"{entry_id}.{field}")
        require(
            row["target_applicability"] == PHASE14_TARGET_APPLICABILITY,
            f"{entry_id}: target applicability drifted",
        )
        require(
            row["status"] == "candidate_deferred",
            f"{entry_id}: opening status must remain candidate_deferred",
        )
        require(
            row["current_failure_stage"] == "before_driver_discovery",
            f"{entry_id}: opening row must stop before driver discovery",
        )
        fixture(row["positive_future_fixture"],
                f"{entry_id}.positive_future_fixture")
        fixture(row["negative_current_fixture"],
                f"{entry_id}.negative_current_fixture")
        require(
            row["positive_future_fixture"] != row["negative_current_fixture"],
            f"{entry_id}: positive and negative fixtures must differ",
        )
        if row["ci_family"] not in derived_families:
            derived_families.append(row["ci_family"])

    rebase_rows = snapshot["residual_rebase"]
    require(
        isinstance(rebase_rows, list) and rebase_rows,
        "Phase 14 residual rebase must contain rows",
    )
    residual_ids = {
        row["id"] for row in registry["residual_snapshots"]["phase13"]["rows"]
    }
    seen_residuals = set()
    for index, row in enumerate(rebase_rows):
        context = f"opening_snapshots.phase14.residual_rebase[{index}]"
        require(
            isinstance(row, dict)
            and set(row) == PHASE14_RESIDUAL_REBASE_FIELDS,
            f"{context} fields drifted",
        )
        residual_id = text(row["source_residual_id"],
                           f"{context}.source_residual_id")
        require(
            residual_id in residual_ids,
            f"{residual_id}: unknown Phase 13 residual source",
        )
        require(
            residual_id not in seen_residuals,
            f"duplicate Phase 14 residual rebase source: {residual_id}",
        )
        seen_residuals.add(residual_id)
        disposition = text(row["phase14_disposition"],
                           f"{residual_id}.phase14_disposition")
        require(
            disposition in {"selected", "split", "reassigned"},
            f"{residual_id}: invalid Phase 14 rebase disposition",
        )
        selected_ids = unique_strings(
            row["selected_phase14_entry_ids"],
            f"{residual_id}.selected_phase14_entry_ids",
        )
        for selected_id in selected_ids:
            require(
                selected_id in ids,
                f"{residual_id}: unknown selected Phase 14 row {selected_id}",
            )
        destination = text(
            row["reassigned_destination_phase"],
            f"{residual_id}.reassigned_destination_phase",
        )
        capability = text(
            row["reassigned_capability"],
            f"{residual_id}.reassigned_capability",
        )
        text(row["justification"], f"{residual_id}.justification")
        if disposition == "selected":
            require(
                selected_ids
                and destination == capability == "none_selected",
                f"{residual_id}: selected residual has stale later-phase data",
            )
        elif disposition == "split":
            require(
                selected_ids
                and re.fullmatch(r"phase[0-9]+", destination) is not None
                and capability != "none_selected",
                f"{residual_id}: split residual must select Phase 14 rows and retain a concrete remainder",
            )
        else:
            require(
                not selected_ids
                and re.fullmatch(r"phase[0-9]+", destination) is not None
                and capability != "none_selected",
                f"{residual_id}: reassigned residual must remain wholly outside Phase 14",
            )
    require(
        seen_residuals == residual_ids,
        "Phase 14 residual rebase must classify every frozen Phase 13 residual",
    )

    projection = snapshot["ci_family_projection"]
    require(
        isinstance(projection, dict)
        and set(projection) == PHASE14_CI_PROJECTION_FIELDS,
        "Phase 14 CI-family projection fields drifted",
    )
    require(
        projection["derivation"] == PHASE14_CI_DERIVATION,
        "Phase 14 CI-family derivation drifted",
    )
    require(
        projection["family_ids"] == derived_families
        == list(PHASE14_CI_FAMILIES),
        "Phase 14 CI-family projection is not derived from opening rows",
    )
    require(
        projection["workflow_policy"] == PHASE14_CI_WORKFLOW_POLICY,
        "Phase 14 CI-family workflow policy drifted",
    )
    return snapshot


def validate_phase14_layout_authority_structure(registry):
    authority = registry["phase14_layout_authority"]
    require(
        isinstance(authority, dict)
        and set(authority) == PHASE14_LAYOUT_AUTHORITY_FIELDS,
        "Phase 14 layout authority fields drifted",
    )
    require(
        authority["version"] == PHASE14_LAYOUT_AUTHORITY_VERSION,
        "Phase 14 layout authority version drifted",
    )
    require(
        authority["status"] == PHASE14_LAYOUT_AUTHORITY_STATUS,
        "Phase 14 layout authority is not ready for Patch 14.2",
    )
    require(
        authority["authority_owner"] == "compiler/mir_layout.gst",
        "Phase 14 layout authority owner drifted",
    )
    require(
        authority["table_format"] == PHASE14_LAYOUT_TABLE_FORMAT,
        "Phase 14 layout table format drifted",
    )
    require(
        authority["semantic_types"] == list(PHASE14_LAYOUT_TYPES),
        "Phase 14 semantic layout type inventory drifted",
    )
    require(
        authority["query_functions"] == list(PHASE14_LAYOUT_QUERIES),
        "Phase 14 layout query inventory drifted",
    )
    consumers = authority["consumers"]
    require(
        isinstance(consumers, dict)
        and set(consumers) == PHASE14_LAYOUT_CONSUMER_FIELDS,
        "Phase 14 layout consumer inventory drifted",
    )
    for consumer, owner in consumers.items():
        text(owner, f"phase14_layout_authority.consumers.{consumer}")
    require(
        authority["identity_policy"] == PHASE14_LAYOUT_IDENTITY_POLICY,
        "Phase 14 layout identity policy drifted",
    )
    require(
        authority["request_transport_policy"] == PHASE14_LAYOUT_REQUEST_POLICY,
        "Phase 14 layout request policy drifted",
    )
    require(
        authority["rejection_classes"]
        == list(PHASE14_LAYOUT_REJECTION_CLASSES),
        "Phase 14 request rejection inventory drifted",
    )
    require(
        authority["hard_bans"] == list(PHASE14_LAYOUT_HARD_BANS),
        "Phase 14 layout hard-ban inventory drifted",
    )
    require(
        authority["behavior_policy"] == PHASE14_LAYOUT_BEHAVIOR_POLICY,
        "Phase 14 layout authority behavior boundary drifted",
    )
    require(
        authority["next_patch"] == "14.2",
        "Phase 14 layout authority next patch must be 14.2",
    )
    return authority


def validate_phase13_residual_snapshot_structure(registry):
    snapshots = registry["residual_snapshots"]
    require(
        isinstance(snapshots, dict) and set(snapshots) == {"phase13"},
        "residual_snapshots must contain exactly phase13",
    )
    snapshot = snapshots["phase13"]
    require(
        isinstance(snapshot, dict)
        and set(snapshot) == PHASE13_RESIDUAL_SNAPSHOT_FIELDS,
        "Phase 13 residual snapshot fields drifted",
    )
    require(
        snapshot["version"] == PHASE13_RESIDUAL_VERSION,
        "Phase 13 residual snapshot version drifted",
    )
    require(
        snapshot["status"] == PHASE13_RESIDUAL_STATUS,
        "Phase 13 residual snapshot is not frozen",
    )
    require(
        snapshot["source_opening_version"] == PHASE13_INVENTORY_VERSION,
        "Phase 13 residual snapshot opening version drifted",
    )
    require(
        snapshot["immutable_fields"]
        == list(PHASE13_RESIDUAL_IMMUTABLE_FIELDS),
        "Phase 13 residual immutable-field set drifted",
    )
    require(
        snapshot["broad_description_bans"]
        == list(PHASE13_RESIDUAL_BROAD_DESCRIPTION_BANS),
        "Phase 13 residual broad-description ban set drifted",
    )
    text(snapshot["resolution_policy"], "residual_snapshots.phase13.resolution_policy")
    text(snapshot["freeze_policy"], "residual_snapshots.phase13.freeze_policy")

    rows = snapshot["rows"]
    require(
        isinstance(rows, list) and rows,
        "Phase 13 residual snapshot must contain actionable rows",
    )
    ids = set()
    reason_codes = set()
    for index, row in enumerate(rows):
        context = f"residual_snapshots.phase13.rows[{index}]"
        require(
            isinstance(row, dict)
            and set(row) == PHASE13_RESIDUAL_ROW_FIELDS,
            f"{context} fields drifted",
        )
        residual_id = text(row["id"], f"{context}.id")
        require(
            re.fullmatch(r"p[0-9]+_[A-Za-z0-9_]+", residual_id) is not None,
            f"{residual_id}: residual ID must identify a destination-phase capability",
        )
        require(residual_id not in ids, f"duplicate residual ID: {residual_id}")
        ids.add(residual_id)
        for field in (
            "feature_family", "ci_family", "capability_owner",
            "diagnostic_owner", "capability", "concrete_reason",
            "destination_phase", "prerequisite_capability",
            "current_failure_stage", "diagnostic_reason_code",
        ):
            text(row[field], f"{residual_id}.{field}")
        require(
            re.fullmatch(r"phase[0-9]+", row["destination_phase"]) is not None,
            f"{residual_id}: destination phase is not concrete",
        )
        require(
            row["current_failure_stage"] in PHASE13_RESIDUAL_FAILURE_STAGES,
            f"{residual_id}: current failure stage is not stable",
        )
        require(
            row["diagnostic_reason_code"] == f"deferred_{residual_id}",
            f"{residual_id}: diagnostic reason code must derive from the stable ID",
        )
        require(
            row["diagnostic_reason_code"] not in reason_codes,
            f"duplicate residual diagnostic reason code: {row['diagnostic_reason_code']}",
        )
        reason_codes.add(row["diagnostic_reason_code"])
        for field in ("positive_future_fixture", "negative_current_fixture"):
            fixture(row[field], f"{residual_id}.{field}")
        require(
            row["positive_future_fixture"] != row["negative_current_fixture"],
            f"{residual_id}: future-positive and current-negative fixtures must differ",
        )
        source_ids = unique_strings(
            row["source_phase13_entry_ids"],
            f"{residual_id}.source_phase13_entry_ids",
        )
        require(source_ids, f"{residual_id}: residual row has no Phase 13 source")
        searchable = "_".join(
            (row["capability"], row["concrete_reason"], row["prerequisite_capability"])
        )
        for banned in PHASE13_RESIDUAL_BROAD_DESCRIPTION_BANS:
            require(
                banned.lower() not in searchable.lower(),
                f"{residual_id}: broad residual description remains: {banned}",
            )
    return snapshot


def validate_phase13_closure_snapshot_structure(registry):
    snapshots = registry["closure_snapshots"]
    require(
        isinstance(snapshots, dict)
        and set(snapshots) == {"phase11", "phase13"},
        "closure_snapshots must contain exactly phase11 and phase13",
    )
    snapshot = snapshots["phase13"]
    require(
        isinstance(snapshot, dict)
        and set(snapshot) == PHASE13_CLOSURE_SNAPSHOT_FIELDS,
        "Phase 13 closure snapshot fields drifted",
    )
    require(
        snapshot["closure_version"] == PHASE13_CLOSURE_VERSION
        == registry["closed_phase_versions"]["phase13"],
        "Phase 13 closure version differs from closed_phase_versions",
    )
    require(
        snapshot["status"] == PHASE13_CLOSURE_STATUS,
        "Phase 13 closure status drifted",
    )
    require(
        snapshot["scope"] == PHASE13_CLOSURE_SCOPE,
        "Phase 13 closure scope must remain limited to the declared inventory",
    )
    require(
        snapshot["opening_version"] == PHASE13_INVENTORY_VERSION,
        "Phase 13 closure opening version drifted",
    )
    require(
        snapshot["residual_version"] == PHASE13_RESIDUAL_VERSION,
        "Phase 13 closure residual version drifted",
    )
    require(
        snapshot["closure_guard"] == "guard-cranelift-phase13-close",
        "Phase 13 closure guard owner drifted",
    )
    require(
        snapshot["ci_owner"] == "PR_Fast_Level1_phase_closure",
        "Phase 13 closure CI owner drifted",
    )
    require(
        snapshot["closure_wording"] == PHASE13_CLOSURE_WORDING,
        "Phase 13 closure wording drifted",
    )
    require(
        snapshot["non_claims"] == list(PHASE13_CLOSURE_NON_CLAIMS),
        "Phase 13 closure non-claim set drifted",
    )
    require(
        snapshot["required_contracts"]
        == list(PHASE13_CLOSURE_REQUIRED_CONTRACTS),
        "Phase 13 closure required-contract set drifted",
    )
    require(
        snapshot["closure_assertions"]
        == list(PHASE13_CLOSURE_ASSERTIONS),
        "Phase 13 closure assertion set drifted",
    )
    require(
        snapshot["forbidden_replays"]
        == list(PHASE13_CLOSURE_FORBIDDEN_REPLAYS),
        "Phase 13 closure replay ban set drifted",
    )
    require(
        isinstance(snapshot["opening_entry_count"], int)
        and snapshot["opening_entry_count"] > 0,
        "Phase 13 closure opening-entry count must be positive",
    )
    disposition_counts = snapshot["disposition_counts"]
    require(
        isinstance(disposition_counts, dict)
        and set(disposition_counts) == {"migrated", "replaced", "excluded"},
        "Phase 13 closure disposition-count fields drifted",
    )
    for label, value in disposition_counts.items():
        require(
            isinstance(value, int) and value >= 0,
            f"Phase 13 closure {label} total must be non-negative",
        )
    require(
        sum(disposition_counts.values()) == snapshot["opening_entry_count"],
        "Phase 13 closure disposition totals do not match opening-entry count",
    )
    for field, label in (
        ("migrated_entry_ids", "migrated"),
        ("replaced_entry_ids", "replaced"),
        ("excluded_entry_ids", "excluded"),
    ):
        ids = unique_strings(snapshot[field], f"closure_snapshots.phase13.{field}")
        require(
            len(ids) == disposition_counts[label],
            f"Phase 13 closure {field} count differs from {label} total",
        )
    require(
        isinstance(snapshot["residual_entry_count"], int)
        and snapshot["residual_entry_count"] > 0,
        "Phase 13 closure residual-entry count must be positive",
    )
    fixed_values = {
        "migrated_route_owner": "generic_canonical_mir",
        "default_oracle_owner": "mir_to_c",
        "explicit_cranelift_fallback_policy": "forbidden",
        "worker_request_boundary": "request_data_and_canonical_mir_only",
        "artifact_owner": (
            "phase9g_compiler_transactional_object_link_cleanup_and_publication"
        ),
        "differential_owner": "registry_derived_level2_families",
        "historical_owner": (
            "scheduled_or_manual_cranelift_historical_full_level3"
        ),
        "evidence_replay_policy": (
            "validate_ownership_and_wiring_without_replaying_level2_or_level3"
        ),
        "comparison_policy": (
            "semantic_registry_fields_and_wiring_only_no_raw_hashes_or_"
            "matrix_correctness_totals"
        ),
    }
    for field, expected in fixed_values.items():
        require(
            snapshot[field] == expected,
            f"Phase 13 closure {field} drifted",
        )
    return snapshot


def validate():
    registry = read_json(REGISTRY)
    schema = read_json(SCHEMA)

    require(set(registry) == TOP_FIELDS, "registry top-level fields drifted")
    require(
        schema.get("$schema") == "https://json-schema.org/draft/2020-12/schema",
        "schema must use JSON Schema draft 2020-12",
    )
    require(schema.get("$id") == registry["schema"], "schema path and $id differ")
    require(set(schema.get("required", [])) == TOP_FIELDS,
            "schema top-level required fields drifted")
    definitions = schema.get("$defs", {})
    entry_schema = definitions.get("entry", {})
    require(set(entry_schema.get("required", [])) == ENTRY_FIELDS,
            "schema entry required fields drifted")
    require(entry_schema.get("additionalProperties") is False,
            "schema entries must reject unknown fields")

    opening_schema = schema.get("properties", {}).get("opening_snapshots", {})
    require(
        set(opening_schema.get("required", [])) == {"phase13", "phase14"},
        "schema opening snapshot keys drifted",
    )
    phase13_snapshot_schema = definitions.get("phase13_opening_snapshot", {})
    require(
        set(phase13_snapshot_schema.get("required", []))
        == PHASE13_OPENING_SNAPSHOT_FIELDS,
        "schema Phase 13 opening snapshot fields drifted",
    )
    require(
        phase13_snapshot_schema.get("additionalProperties") is False,
        "schema Phase 13 opening snapshot must reject unknown fields",
    )
    phase13_snapshot_entry_schema = definitions.get(
        "phase13_opening_snapshot_entry",
        {},
    )
    require(
        set(phase13_snapshot_entry_schema.get("required", []))
        == PHASE13_OPENING_SNAPSHOT_ENTRY_FIELDS,
        "schema Phase 13 opening snapshot entry fields drifted",
    )
    require(
        phase13_snapshot_entry_schema.get("additionalProperties") is False,
        "schema Phase 13 opening snapshot entries must reject unknown fields",
    )
    phase14_snapshot_schema = definitions.get("phase14_opening_snapshot", {})
    require(
        set(phase14_snapshot_schema.get("required", []))
        == PHASE14_OPENING_SNAPSHOT_FIELDS,
        "schema Phase 14 opening snapshot fields drifted",
    )
    require(
        phase14_snapshot_schema.get("additionalProperties") is False,
        "schema Phase 14 opening snapshot must reject unknown fields",
    )
    phase14_snapshot_entry_schema = definitions.get(
        "phase14_opening_snapshot_entry",
        {},
    )
    require(
        set(phase14_snapshot_entry_schema.get("required", []))
        == PHASE14_OPENING_SNAPSHOT_ENTRY_FIELDS,
        "schema Phase 14 opening snapshot entry fields drifted",
    )
    require(
        phase14_snapshot_entry_schema.get("additionalProperties") is False,
        "schema Phase 14 opening snapshot entries must reject unknown fields",
    )
    phase14_rebase_schema = definitions.get("phase14_residual_rebase", {})
    require(
        set(phase14_rebase_schema.get("required", []))
        == PHASE14_RESIDUAL_REBASE_FIELDS,
        "schema Phase 14 residual rebase fields drifted",
    )
    phase14_ci_schema = definitions.get("phase14_ci_family_projection", {})
    require(
        set(phase14_ci_schema.get("required", []))
        == PHASE14_CI_PROJECTION_FIELDS,
        "schema Phase 14 CI-family projection fields drifted",
    )
    phase14_authority_schema = definitions.get(
        "phase14_layout_authority",
        {},
    )
    require(
        set(phase14_authority_schema.get("required", []))
        == PHASE14_LAYOUT_AUTHORITY_FIELDS,
        "schema Phase 14 layout authority fields drifted",
    )
    require(
        phase14_authority_schema.get("additionalProperties") is False,
        "schema Phase 14 layout authority must reject unknown fields",
    )
    residual_schema = schema.get("properties", {}).get("residual_snapshots", {})
    require(
        set(residual_schema.get("required", [])) == {"phase13"},
        "schema residual snapshot keys drifted",
    )
    phase13_residual_schema = definitions.get("phase13_residual_snapshot", {})
    require(
        set(phase13_residual_schema.get("required", []))
        == PHASE13_RESIDUAL_SNAPSHOT_FIELDS,
        "schema Phase 13 residual snapshot fields drifted",
    )
    phase13_residual_row_schema = definitions.get("phase13_residual_row", {})
    require(
        set(phase13_residual_row_schema.get("required", []))
        == PHASE13_RESIDUAL_ROW_FIELDS,
        "schema Phase 13 residual row fields drifted",
    )
    closed_versions_schema = schema.get("properties", {}).get(
        "closed_phase_versions",
        {},
    )
    require(
        set(closed_versions_schema.get("required", []))
        == {"phase11", "phase12_5_opening", "phase12_5", "phase13"},
        "schema closed-phase version keys drifted",
    )
    closure_schema = schema.get("properties", {}).get("closure_snapshots", {})
    require(
        set(closure_schema.get("required", [])) == {"phase11", "phase13"},
        "schema closure snapshot keys drifted",
    )
    phase13_closure_schema = definitions.get("phase13_closure_snapshot", {})
    require(
        set(phase13_closure_schema.get("required", []))
        == PHASE13_CLOSURE_SNAPSHOT_FIELDS,
        "schema Phase 13 closure snapshot fields drifted",
    )
    require(
        phase13_closure_schema.get("additionalProperties") is False,
        "schema Phase 13 closure snapshot must reject unknown fields",
    )

    require(registry["schema"] == "scripts/cranelift_feature_registry.schema.json",
            "registry schema path is not canonical")
    require(registry["schema_version"] == 1, "schema_version must be 1")
    require(registry["registry_version"] == 9, "registry_version must be 9")
    require(
        registry["registry_status"] == "phase14_layout_authority_ready",
        "registry status is missing or stale",
    )
    require(registry["current_phase"] == "phase14", "current_phase must be phase14")
    require(
        registry["closed_phase_versions"] == {
            "phase11": "phase11_closed_registry_backed_feature_parity_migration",
            "phase12_5_opening": "phase12_5_opened_verification_framework_consolidation",
            "phase12_5": "phase12_5_closed_cranelift_verification_framework_consolidation",
            "phase13": PHASE13_CLOSURE_VERSION,
        },
        "closed phase versions drifted",
    )
    validate_phase11_snapshot_structure(registry)
    validate_phase13_opening_snapshot_structure(registry)
    residual_snapshot = validate_phase13_residual_snapshot_structure(registry)
    validate_phase13_closure_snapshot_structure(registry)
    validate_phase14_opening_snapshot_structure(registry)
    validate_phase14_layout_authority_structure(registry)

    categories = set(unique_strings(registry["planning_categories"], "planning_categories"))
    supported = registry["supported_values"]
    require(isinstance(supported, dict) and set(supported) == SUPPORTED_FIELDS,
            "supported_values fields drifted")
    allowed = {
        key: set(unique_strings(value, f"supported_values.{key}"))
        for key, value in supported.items()
    }
    require(
        set(registry["legacy_views"])
        == {"phase11", "phase13", "phase14", "generated_summary"},
        "legacy_views fields drifted",
    )
    for key, value in registry["legacy_views"].items():
        text(value, f"legacy_views.{key}")

    entries = registry["entries"]
    require(isinstance(entries, list) and entries,
            "registry entries must be a non-empty array")

    ids = set()
    phase11 = []
    phase13 = []
    phase14 = []
    for index, entry in enumerate(entries):
        context = f"entries[{index}]"
        require(isinstance(entry, dict), f"{context} must be an object")
        expected_fields = set(ENTRY_FIELDS)
        if entry.get("origin_phase") == "phase13":
            expected_fields.update(PHASE13_CAPABILITY_FIELDS)
        elif entry.get("origin_phase") == "phase14":
            expected_fields.update(PHASE14_ENTRY_FIELDS)
        require(set(entry) == expected_fields, f"{context} fields drifted")
        entry_id = text(entry["id"], f"{context}.id")
        require(all(ch.isalnum() or ch == "_" for ch in entry_id),
                f"{entry_id}: unsupported ID characters")
        require(entry_id not in ids, f"duplicate ID: {entry_id}")
        ids.add(entry_id)

        checks = (
            ("origin_phase", "origin_phases"),
            ("feature_family", "feature_families"),
            ("status", "statuses"),
            ("route_owner", "route_owners"),
            ("worker_capability_owner", "worker_capability_owners"),
            ("diagnostic_owner", "diagnostic_owners"),
        )
        for field, allowed_field in checks:
            value = text(entry[field], f"{entry_id}.{field}")
            require(value in allowed[allowed_field],
                    f"{entry_id}: unknown {field} {value}")
        text(entry["ci_family"], f"{entry_id}.ci_family")

        parent = text(entry["parent"], f"{entry_id}.parent")
        fixture(entry["source_fixture"], f"{entry_id}.source_fixture")
        fixture(entry["canonical_mir_fixture"], f"{entry_id}.canonical_mir_fixture")
        require(text(entry["differential_case_id"], f"{entry_id}.differential_case_id").count(":") == 1,
                f"{entry_id}: differential_case_id must be namespace:id")
        reason = text(entry["deferral_reason"], f"{entry_id}.deferral_reason")
        destination = text(entry["future_destination_phase"],
                           f"{entry_id}.future_destination_phase")
        closure = text(entry["closure_version"], f"{entry_id}.closure_version")
        require(isinstance(entry["evidence"], dict), f"{entry_id}.evidence must be an object")

        status = entry["status"]
        if status in DEFERRED:
            require(entry["route_owner"] == "deferred",
                    f"{entry_id}: deferred status requires route_owner=deferred")
            require(not reason.startswith("none_"),
                    f"{entry_id}: deferred status requires a reason")
            require(not destination.startswith("none_"),
                    f"{entry_id}: deferred status requires a future phase")
        elif status in REPLACED:
            require(entry["origin_phase"] == "phase13",
                    f"{entry_id}: only Phase 13 rows may be replaced")
            require(entry["route_owner"] == "deferred",
                    f"{entry_id}: replaced status requires route_owner=deferred")
            require(reason == "replaced_by_phase13_deferred_residue_snapshot",
                    f"{entry_id}: replaced row reason drifted")
            require(destination == "phase14_or_later_via_residual_snapshot",
                    f"{entry_id}: replaced row destination drifted")
        elif status == "migrated":
            require(entry["route_owner"] == "generic_canonical_mir",
                    f"{entry_id}: migrated status requires generic canonical MIR")
            require(reason == destination == "none_migrated",
                    f"{entry_id}: migrated entry has stale deferral fields")
        elif status == "excluded":
            require(entry["route_owner"] == "excluded",
                    f"{entry_id}: excluded status requires route_owner=excluded")

        if entry["origin_phase"] == "phase11":
            require(parent == "phase11_root:feature_inventory",
                    f"{entry_id}: invalid Phase 11 parent")
            require(closure == registry["closed_phase_versions"]["phase11"],
                    f"{entry_id}: Phase 11 closure version drifted")
            deferred_family = text(
                entry["evidence"].get("deferred_family"),
                f"{entry_id}.evidence.deferred_family",
            )
            require(
                deferred_family in categories,
                f"{entry_id}: unknown deferred planning category {deferred_family}",
            )
            deferred_expectation = text(
                entry["evidence"].get("deferred_expectation"),
                f"{entry_id}.evidence.deferred_expectation",
            )
            require(
                any(
                    marker in deferred_expectation
                    for marker in (
                        "before_driver",
                        "before_object_publication",
                        "before_publication",
                    )
                ),
                f"{entry_id}: deferred expectation must prove pre-driver or pre-publication failure",
            )
            phase11.append(entry)
        elif entry["origin_phase"] == "phase13":
            require(
                closure
                == registry["opening_snapshots"]["phase13"]["inventory_version"],
                f"{entry_id}: Phase 13 closure version drifted",
            )
            capability_id = text(
                entry["capability_id"],
                f"{entry_id}.capability_id",
            )
            capability_owner = text(
                entry["capability_decision_owner"],
                f"{entry_id}.capability_decision_owner",
            )
            capability_decision = text(
                entry["capability_decision"],
                f"{entry_id}.capability_decision",
            )
            capability_reason = text(
                entry["capability_reason_code"],
                f"{entry_id}.capability_reason_code",
            )
            expected_failure_stage = text(
                entry["expected_failure_stage"],
                f"{entry_id}.expected_failure_stage",
            )
            require(
                capability_id == PHASE13_CAPABILITY_ID,
                f"{entry_id}: capability ID drifted",
            )
            require(
                capability_owner == PHASE13_CAPABILITY_OWNER,
                f"{entry_id}: capability decision owner drifted",
            )
            require(
                capability_decision in PHASE13_CAPABILITY_DECISIONS,
                f"{entry_id}: unknown capability decision "
                f"{capability_decision}",
            )
            require(
                capability_reason
                == f"{capability_decision}_{entry_id}",
                f"{entry_id}: capability reason code must be derived from "
                "the decision and stable row ID",
            )
            if capability_decision == "supported":
                require(
                    status == "migrated",
                    f"{entry_id}: supported capability requires migrated status",
                )
                require(
                    expected_failure_stage == "none_supported",
                    f"{entry_id}: supported capability has a failure stage",
                )
            elif capability_decision == "deferred":
                require(
                    status in DEFERRED | REPLACED,
                    f"{entry_id}: deferred capability requires deferred or replaced status",
                )
                require(
                    expected_failure_stage == "before_driver_discovery",
                    f"{entry_id}: deferred capability must stop before discovery",
                )
            else:
                require(
                    status == "excluded",
                    f"{entry_id}: source/type failure requires excluded status",
                )
                require(
                    expected_failure_stage == "before_driver_discovery",
                    f"{entry_id}: source/type failure must stop before discovery",
                )
            phase13.append(entry)
        elif entry["origin_phase"] == "phase14":
            require(
                closure == PHASE14_LAYOUT_AUTHORITY_VERSION,
                f"{entry_id}: Phase 14 layout authority version drifted",
            )
            require(
                status == "candidate_deferred"
                and entry["route_owner"] == "deferred",
                f"{entry_id}: Phase 14 rows must remain candidate deferred",
            )
            require(
                reason
                == f"phase14_authority_{entry_id}_awaits_bounded_capability_migration",
                f"{entry_id}: Phase 14 post-authority deferral reason drifted",
            )
            require(
                destination == "phase14",
                f"{entry_id}: Phase 14 opening destination must remain phase14",
            )
            require(
                entry["target_applicability"] == PHASE14_TARGET_APPLICABILITY,
                f"{entry_id}: Phase 14 target applicability drifted",
            )
            require(
                entry["current_failure_stage"] in PHASE14_FAILURE_STAGES
                and entry["current_failure_stage"] == "before_driver_discovery",
                f"{entry_id}: Phase 14 opening must stop before driver discovery",
            )
            for field in ("positive_future_fixture", "negative_current_fixture"):
                fixture(entry[field], f"{entry_id}.{field}")
            require(
                entry["positive_future_fixture"]
                != entry["negative_current_fixture"],
                f"{entry_id}: Phase 14 fixture pair must differ",
            )
            require(
                entry["source_fixture"] == entry["negative_current_fixture"],
                f"{entry_id}: opening source fixture must be the current negative fixture",
            )
            require(
                entry["canonical_mir_fixture"]
                == "none_rejected_before_canonical_MIR",
                f"{entry_id}: opening row must not claim canonical MIR",
            )
            require(
                entry["differential_case_id"] == f"phase14_opening:{entry_id}",
                f"{entry_id}: Phase 14 opening differential identity drifted",
            )
            evidence = entry["evidence"]
            require(
                evidence.get("opening_record_kind") == "phase14_candidate"
                and evidence.get("phase13_closure_dependency")
                == PHASE13_CLOSURE_VERSION
                and evidence.get("phase14_1_authority")
                == "compiler_owned_layout_authority_and_request_transport_available"
                and evidence.get("behavior_policy")
                == "authority_and_transport_only_no_capability_migration",
                f"{entry_id}: Phase 14 authority evidence drifted",
            )
            text(evidence.get("declared_capability"),
                 f"{entry_id}.evidence.declared_capability")
            category = text(evidence.get("planning_category"),
                            f"{entry_id}.evidence.planning_category")
            require(
                category in PHASE14_PLANNING_CATEGORIES,
                f"{entry_id}: unknown Phase 14 planning category {category}",
            )
            phase14.append(entry)
        else:
            raise Error(f"{entry_id}: unsupported origin phase {entry['origin_phase']}")

    phase11_by_id = {entry["id"]: entry for entry in phase11}
    for entry in phase13:
        parent = entry["parent"]
        if parent.startswith("phase11_entry:"):
            parent_id = parent.split(":", 1)[1]
            require(parent_id in phase11_by_id, f"{entry['id']}: missing parent {parent_id}")
            require(phase11_by_id[parent_id]["status"] == "deferred",
                    f"{entry['id']}: inherited parent is not deferred")
            require(
                entry["status"]
                in {"inherited_deferred", "migrated", "excluded", "replaced"},
                f"{entry['id']}: entry parent has invalid current status",
            )
            if entry["status"] == "inherited_deferred":
                require(
                    entry["source_fixture"] == phase11_by_id[parent_id]["source_fixture"],
                    f"{entry['id']}: still-deferred inherited source fixture differs from Phase 11",
                )
                require(
                    entry["canonical_mir_fixture"]
                    == phase11_by_id[parent_id]["canonical_mir_fixture"],
                    f"{entry['id']}: still-deferred inherited canonical MIR fixture differs from Phase 11",
                )
        elif parent.startswith("phase11_category:"):
            category = parent.split(":", 1)[1]
            require(category in categories, f"{entry['id']}: unknown category {category}")
            require(
                entry["status"]
                in {"candidate_deferred", "migrated", "excluded", "replaced"},
                f"{entry['id']}: category parent has invalid current status",
            )
        else:
            raise Error(f"{entry['id']}: invalid parent {parent}")

    phase13_by_id_for_parent = {entry["id"]: entry for entry in phase13}
    residual_ids_for_parent = {
        row["id"] for row in residual_snapshot["rows"]
    }
    planning_categories = set(registry["planning_categories"])
    for entry in phase14:
        parent = entry["parent"]
        if parent.startswith("phase13_entry:"):
            parent_id = parent.split(":", 1)[1]
            require(
                parent_id in phase13_by_id_for_parent,
                f"{entry['id']}: missing Phase 13 parent {parent_id}",
            )
            require(
                phase13_by_id_for_parent[parent_id]["status"] == "migrated",
                f"{entry['id']}: Phase 13 entry parent is not migrated",
            )
        elif parent.startswith("phase13_residual:"):
            residual_id = parent.split(":", 1)[1]
            require(
                residual_id in residual_ids_for_parent,
                f"{entry['id']}: missing Phase 13 residual parent {residual_id}",
            )
        elif parent.startswith("phase14_category:"):
            category = parent.split(":", 1)[1]
            require(
                category in planning_categories
                and category in PHASE14_PLANNING_CATEGORIES,
                f"{entry['id']}: unknown Phase 14 category {category}",
            )
        else:
            raise Error(f"{entry['id']}: invalid Phase 14 parent {parent}")

    require(phase11, "registry must contain Phase 11 rows")
    require(phase13, "registry must contain Phase 13 rows")
    require(phase14, "registry must contain Phase 14 rows")
    active_ci_families = {entry["ci_family"] for entry in phase11}
    require(active_ci_families, "Phase 11 rows must define active CI families")
    for entry in phase13:
        require(
            entry["ci_family"] in active_ci_families,
            f"{entry['id']}: Phase 13 introduces non-Phase11 CI family "
            f"{entry['ci_family']}",
        )
    phase14_families = []
    for entry in phase14:
        if entry["ci_family"] not in phase14_families:
            phase14_families.append(entry["ci_family"])
    require(
        phase14_families == list(PHASE14_CI_FAMILIES),
        "Phase 14 opening CI-family projection drifted",
    )

    phase13_by_id = {entry["id"]: entry for entry in phase13}
    residual_by_id = {row["id"]: row for row in residual_snapshot["rows"]}
    residual_source_ids = set()
    for residual_id, row in residual_by_id.items():
        require(
            row["feature_family"] in allowed["feature_families"],
            f"{residual_id}: unknown residual feature family",
        )
        require(
            row["ci_family"] in active_ci_families,
            f"{residual_id}: residual row uses inactive CI family",
        )
        require(
            row["capability_owner"] in allowed["worker_capability_owners"],
            f"{residual_id}: unknown residual capability owner",
        )
        require(
            row["diagnostic_owner"] in allowed["diagnostic_owners"],
            f"{residual_id}: unknown residual diagnostic owner",
        )
        for source_id in row["source_phase13_entry_ids"]:
            require(
                source_id in phase13_by_id,
                f"{residual_id}: unknown Phase 13 source row {source_id}",
            )
            residual_source_ids.add(source_id)

    disposition_counts = Counter()
    for entry in phase13:
        entry_id = entry["id"]
        audit = entry["evidence"].get("phase13_12_audit")
        require(
            isinstance(audit, dict) and set(audit) == PHASE13_AUDIT_FIELDS,
            f"{entry_id}: Phase 13.12 audit fields drifted",
        )
        require(
            audit["version"] == PHASE13_RESIDUAL_VERSION,
            f"{entry_id}: Phase 13.12 audit version drifted",
        )
        disposition = text(
            audit["final_disposition"],
            f"{entry_id}.evidence.phase13_12_audit.final_disposition",
        )
        require(
            disposition in {"migrated", "excluded", "replaced"},
            f"{entry_id}: invalid final disposition {disposition}",
        )
        require(
            entry["status"] == disposition,
            f"{entry_id}: status differs from final disposition",
        )
        replacements = unique_strings(
            audit["replacement_residual_ids"],
            f"{entry_id}.evidence.phase13_12_audit.replacement_residual_ids",
        )
        related = unique_strings(
            audit["related_residual_ids"],
            f"{entry_id}.evidence.phase13_12_audit.related_residual_ids",
        )
        require(
            set(replacements).isdisjoint(related),
            f"{entry_id}: residual IDs appear as both replacement and related",
        )
        for residual_id in replacements + related:
            require(
                residual_id in residual_by_id,
                f"{entry_id}: unknown residual reference {residual_id}",
            )
            require(
                entry_id in residual_by_id[residual_id]["source_phase13_entry_ids"],
                f"{entry_id}: residual {residual_id} does not trace back to the row",
            )
        if disposition == "replaced":
            require(replacements, f"{entry_id}: replaced row has no narrower residual")
            require(not related, f"{entry_id}: replaced row must use replacement links")
        else:
            require(not replacements, f"{entry_id}: non-replaced row has replacement links")
        text(audit["justification"], f"{entry_id}.evidence.phase13_12_audit.justification")
        disposition_counts[disposition] += 1

    require(
        not any(entry["status"] in DEFERRED for entry in phase13),
        "Phase 13 retains unchanged active deferred rows after the residue audit",
    )
    require(
        residual_source_ids == set(phase13_by_id),
        "Residual snapshot traceability does not cover every Phase 13 row",
    )
    inherited_children = {
        entry["parent"].split(":", 1)[1]: entry
        for entry in phase13
        if entry["parent"].startswith("phase11_entry:")
    }
    for deferred_parent_id in registry["closure_snapshots"]["phase11"]["deferred_entry_ids"]:
        require(
            deferred_parent_id in inherited_children,
            f"Phase 11 deferred parent lacks a Phase 13 resolution: {deferred_parent_id}",
        )
        require(
            inherited_children[deferred_parent_id]["status"]
            in {"migrated", "excluded", "replaced"},
            f"Phase 11 deferred parent remains ambiguous: {deferred_parent_id}",
        )
    return registry


def verify_legacy_import(registry):
    views = registry["legacy_views"]
    p11 = legacy_records(ROOT / views["phase11"], "parity_entry: ")
    entries = {entry["id"]: entry for entry in registry["entries"]}

    json_p11 = {
        entry["id"]
        for entry in registry["entries"]
        if entry["origin_phase"] == "phase11"
    }
    require(
        {row["id"] for row in p11} == json_p11,
        "Phase 11 stable IDs differ from the historical view",
    )
    for row in p11:
        entry = entries[row["id"]]
        expected = {
            "feature_family": row["family"],
            "source_fixture": row["source_fixture"],
            "canonical_mir_fixture": row["mir_fixture"],
            "route_owner": row["route_owner"],
            "ci_family": row["ci_family"],
            "status": (
                "deferred"
                if row["migration_status"] == "deferred"
                else "migrated"
            ),
        }
        for field, value in expected.items():
            require(
                entry[field] == value,
                f"Phase 11 {row['id']} {field} differs from historical view",
            )

    verify_phase13_opening_rebase(registry)


def verify_phase11_closure(registry):
    snapshot = validate_phase11_snapshot_structure(registry)
    current = [
        entry for entry in registry["entries"]
        if entry["origin_phase"] == "phase11"
    ]
    current_by_id = {entry["id"]: entry for entry in current}
    snapshot_by_id = {entry["id"]: entry for entry in snapshot["entries"]}

    require(
        len(current) == snapshot["entry_count"],
        "Phase 11 current row count differs from the semantic snapshot",
    )
    require(set(current_by_id) == set(snapshot_by_id),
            "Phase 11 stable ID inventory differs from the semantic snapshot")

    field_map = {
        "id": "id",
        "classification": "status",
        "feature_family": "feature_family",
        "route_owner": "route_owner",
        "source_fixture": "source_fixture",
        "canonical_mir_fixture": "canonical_mir_fixture",
        "ci_family": "ci_family",
    }
    for entry_id, frozen in snapshot_by_id.items():
        live = current_by_id[entry_id]
        for frozen_field, live_field in field_map.items():
            require(
                frozen[frozen_field] == live[live_field],
                f"Phase 11 {entry_id} changed immutable field "
                f"{frozen_field}: frozen={frozen[frozen_field]!r} "
                f"current={live[live_field]!r}",
            )
        require(
            live["closure_version"] == snapshot["closure_version"],
            f"Phase 11 {entry_id} closure version drifted",
        )

    counts = Counter(entry["status"] for entry in current)
    actual_counts = {
        key: counts[key] for key in ("migrated", "deferred", "excluded")
    }
    require(
        actual_counts == snapshot["classification_counts"],
        "Phase 11 classification inventory differs from the semantic snapshot",
    )
    actual_deferred = [
        entry["id"] for entry in current if entry["status"] == "deferred"
    ]
    require(
        actual_deferred == snapshot["deferred_entry_ids"],
        "Phase 11 deferred parent ID inventory differs from the semantic snapshot",
    )
    return snapshot


def phase_entries(registry, origin_phase):
    rows = [
        entry for entry in registry["entries"]
        if entry["origin_phase"] == origin_phase
    ]
    require(rows, f"registry must contain {origin_phase} rows")
    return rows


def verify_phase14_opening_contract(registry):
    snapshot = validate_phase14_opening_snapshot_structure(registry)
    rows = phase_entries(registry, "phase14")
    require(
        [entry["id"] for entry in rows] == list(PHASE14_OPENING_ENTRY_IDS),
        "Phase 14 opening row ID inventory drifted",
    )

    opening_fields = (
        "id", "parent", "feature_family", "ci_family",
        "worker_capability_owner", "diagnostic_owner",
        "target_applicability", "status", "current_failure_stage",
        "positive_future_fixture", "negative_current_fixture",
    )
    snapshot_fields = (
        "id", "parent", "feature_family", "ci_family",
        "capability_owner", "diagnostic_owner",
        "target_applicability", "status", "current_failure_stage",
        "positive_future_fixture", "negative_current_fixture",
    )
    projected_rows = []
    for entry in rows:
        projected = {}
        for live_field, frozen_field in zip(opening_fields, snapshot_fields):
            projected[frozen_field] = entry[live_field]
        projected_rows.append(projected)
    require(
        projected_rows == snapshot["entries"],
        "Phase 14 live rows differ from the semantic opening snapshot",
    )

    phase13_rows = {
        entry["id"]: entry for entry in phase_entries(registry, "phase13")
    }
    residual_rows = {
        row["id"]: row
        for row in registry["residual_snapshots"]["phase13"]["rows"]
    }
    parent_counts = Counter()
    for entry in rows:
        parent_kind, parent_id = entry["parent"].split(":", 1)
        parent_counts[parent_kind] += 1
        if parent_kind == "phase13_entry":
            require(
                parent_id in phase13_rows
                and phase13_rows[parent_id]["status"] == "migrated",
                f"{entry['id']}: Phase 13 entry parent is missing or not migrated",
            )
        elif parent_kind == "phase13_residual":
            require(
                parent_id in residual_rows,
                f"{entry['id']}: Phase 13 residual parent is missing",
            )
        else:
            require(
                parent_kind == "phase14_category"
                and parent_id in PHASE14_PLANNING_CATEGORIES,
                f"{entry['id']}: invalid Phase 14 category parent",
            )

    rebase_rows = {
        row["source_residual_id"]: row
        for row in snapshot["residual_rebase"]
    }
    require(
        set(rebase_rows) == set(residual_rows),
        "Phase 14 residual rebase does not cover the frozen Phase 13 residue",
    )
    selected_by_rebase = {
        entry_id
        for row in rebase_rows.values()
        for entry_id in row["selected_phase14_entry_ids"]
    }
    require(
        selected_by_rebase
        == {
            "p14_target_dependent_conversions",
            "p14_stack_slot_addressable_locals",
            "p14_aggregate_basic_block_transport",
            "p14_struct_field_layout",
            "p14_array_and_slice_layout",
            "p14_enum_tagged_union_layout",
        },
        "Phase 14 selected or split residual mapping drifted",
    )
    require(
        rebase_rows["p14_target_dependent_conversions"]["phase14_disposition"]
        == "selected",
        "Phase 14 conversion residual must be selected",
    )
    require(
        rebase_rows["p14_aggregate_locals"]["phase14_disposition"] == "split"
        and rebase_rows["p14_aggregate_locals"][
            "reassigned_destination_phase"
        ] == "phase16",
        "Phase 14 aggregate-local residual split drifted",
    )
    require(
        rebase_rows["p14_aggregate_abi"]["phase14_disposition"] == "split"
        and rebase_rows["p14_aggregate_abi"][
            "reassigned_destination_phase"
        ] == "phase15",
        "Phase 14 aggregate ABI split drifted",
    )
    require(
        rebase_rows["p14_resource_cleanup_semantics"][
            "reassigned_destination_phase"
        ] == "phase16",
        "Resource cleanup semantics must remain outside Phase 14",
    )
    for residual_id, row in rebase_rows.items():
        if residual_id not in {
            "p14_target_dependent_conversions",
            "p14_aggregate_locals",
            "p14_aggregate_abi",
        }:
            require(
                row["phase14_disposition"] == "reassigned"
                and not row["selected_phase14_entry_ids"],
                f"{residual_id}: non-layout residual entered the Phase 14 inventory",
            )

    family_counts = Counter(entry["ci_family"] for entry in rows)
    require(
        list(family_counts) == list(PHASE14_CI_FAMILIES),
        "Phase 14 CI-family order drifted",
    )
    feature_counts = Counter(entry["feature_family"] for entry in rows)
    residual_dispositions = Counter(
        row["phase14_disposition"]
        for row in snapshot["residual_rebase"]
    )
    return {
        "snapshot": snapshot,
        "row_count": len(rows),
        "parent_counts": parent_counts,
        "feature_counts": feature_counts,
        "ci_counts": family_counts,
        "residual_disposition_counts": residual_dispositions,
        "selected_residual_entry_ids": sorted(selected_by_rebase),
    }


def verify_phase14_layout_authority(registry):
    opening = verify_phase14_opening_contract(registry)
    authority = validate_phase14_layout_authority_structure(registry)
    require(
        registry["registry_status"] == "phase14_layout_authority_ready",
        "Phase 14 registry is not at the layout-authority checkpoint",
    )

    rows = phase_entries(registry, "phase14")
    require(
        len(rows) == opening["row_count"],
        "Phase 14 authority changed the opening-row inventory",
    )
    for entry in rows:
        entry_id = entry["id"]
        require(
            entry["status"] == "candidate_deferred"
            and entry["route_owner"] == "deferred",
            f"{entry_id}: Patch 14.1 must not migrate a capability",
        )
        require(
            entry["closure_version"] == PHASE14_LAYOUT_AUTHORITY_VERSION,
            f"{entry_id}: authority checkpoint version drifted",
        )
        require(
            entry["deferral_reason"]
            == f"phase14_authority_{entry_id}_awaits_bounded_capability_migration",
            f"{entry_id}: post-authority deferral reason drifted",
        )

    source_paths = {
        "authority": ROOT / "compiler/mir_layout.gst",
        "mir": ROOT / "compiler/mir.gst",
        "request": ROOT / "compiler/mir_native_backend_request.gst",
        "mir_to_c": ROOT / "compiler/mir_layout_mir_to_c.gst",
        "runtime": ROOT / "compiler/mir_layout_runtime_descriptor.gst",
        "diagnostics": ROOT / "compiler/mir_layout_diagnostics.gst",
        "worker": ROOT / "compiler/experiments/cranelift/src/main.rs",
        "smoke": ROOT / "compiler/mir_layout_authority_smoke_test_entry.gst",
    }
    for owner, path in source_paths.items():
        require(
            path.is_file() and not path.is_symlink(),
            f"missing regular Phase 14 layout {owner} source: {path.relative_to(ROOT)}",
        )

    authority_source = source_paths["authority"].read_text(encoding="utf-8")
    for semantic_type in PHASE14_LAYOUT_TYPES:
        require(
            f"type {semantic_type}" in authority_source,
            f"Phase 14 authority is missing semantic type {semantic_type}",
        )
    for query in PHASE14_LAYOUT_QUERIES:
        require(
            f"func {query}(" in authority_source,
            f"Phase 14 authority is missing query {query}",
        )
    require(
        PHASE14_LAYOUT_TABLE_FORMAT in authority_source,
        "compiler layout table format is missing from the authority",
    )
    require(
        "layout:v1:type=" in authority_source
        and "sha" not in authority_source.lower(),
        "layout identity must use semantic components without raw hashes",
    )

    mir_source = source_paths["mir"].read_text(encoding="utf-8")
    require(
        "type_layout_references" in mir_source
        and "mir_program_layout_reference_is_valid" in mir_source,
        "canonical MIR does not expose compiler-owned type/layout references",
    )
    request_source = source_paths["request"].read_text(encoding="utf-8")
    require(
        "layout_table: layout.MirLayoutTable[ctx]" in request_source
        and "mir_serialize_layout_table_for_request" in request_source,
        "native request does not carry the compiler-owned layout table",
    )
    worker_source = source_paths["worker"].read_text(encoding="utf-8")
    for token in (
        "struct Phase14RequestLayoutTable",
        "fn parse_phase14_request_layout_table(",
        "fn validate_phase14_request_layout_table(",
        "duplicate conflicting layout ID",
        "unknown layout ID",
        "invalid tag or payload offsets",
    ):
        require(token in worker_source, f"worker layout validation missing: {token}")

    adapter_tokens = {
        "mir_to_c": "mir_layout_for_mir_to_c",
        "runtime": "mir_layout_runtime_descriptor",
        "diagnostics": "mir_layout_diagnostic",
    }
    for owner, token in adapter_tokens.items():
        source = source_paths[owner].read_text(encoding="utf-8")
        require(
            'import "mir_layout.gst" as layout;' in source
            and token in source
            and "type MirTypeLayout" not in source,
            f"{owner} must consume rather than redefine layout authority",
        )

    return {
        "version": authority["version"],
        "status": authority["status"],
        "opening_row_count": len(rows),
        "semantic_type_count": len(authority["semantic_types"]),
        "query_count": len(authority["query_functions"]),
        "rejection_count": len(authority["rejection_classes"]),
        "consumer_count": len(authority["consumers"]),
    }


def verify_phase13_opening_rebase(registry):
    snapshot = validate_phase13_opening_snapshot_structure(registry)
    rows = phase_entries(registry, "phase13")
    current = [
        {"id": entry["id"], "parent": entry["parent"]}
        for entry in rows
    ]
    require(
        current == snapshot["entries"],
        "Phase 13 stable IDs or parent relationships differ from the "
        "semantic opening snapshot",
    )
    return snapshot


def verify_phase13_registry_schema(registry):
    snapshot = verify_phase13_opening_rebase(registry)
    rows = phase_entries(registry, "phase13")
    allowed_statuses = {
        "inherited_deferred", "candidate_deferred", "migrated", "excluded",
        "replaced",
    }
    required_owners = (
        "route_owner",
        "worker_capability_owner",
        "diagnostic_owner",
        "ci_family",
        "capability_id",
        "capability_decision_owner",
        "capability_reason_code",
        "expected_failure_stage",
    )

    for entry in rows:
        entry_id = entry["id"]
        require(
            entry["closure_version"] == snapshot["inventory_version"],
            f"{entry_id}: Phase 13 opening version drifted",
        )
        require(
            entry["status"] in allowed_statuses,
            f"{entry_id}: unsupported Phase 13 current status "
            f"{entry['status']}",
        )
        expected_differential_case_id = (
            f"phase13_registry_differential:{entry_id}"
            if entry["status"] == "migrated"
            and entry["route_owner"] == "generic_canonical_mir"
            else f"phase13_opening:{entry_id}"
        )
        require(
            entry["differential_case_id"] == expected_differential_case_id,
            f"{entry_id}: Phase 13 differential identity drifted",
        )
        for field in required_owners:
            text(entry[field], f"{entry_id}.{field}")

        evidence = entry["evidence"]
        expected_kind = (
            "inherited"
            if entry["parent"].startswith("phase11_entry:")
            else "candidate"
        )
        require(
            evidence.get("opening_record_kind") == expected_kind,
            f"{entry_id}: Phase 13 opening record kind drifted",
        )
    return rows


def verify_phase13_capability_contract(registry):
    rows = verify_phase13_registry_schema(registry)
    decisions = Counter()
    reason_codes = set()

    for entry in rows:
        entry_id = entry["id"]
        decisions[entry["capability_decision"]] += 1
        reason_code = entry["capability_reason_code"]
        require(
            reason_code not in reason_codes,
            f"duplicate Phase 13 capability reason code: {reason_code}",
        )
        reason_codes.add(reason_code)
        require(
            entry["capability_id"] == PHASE13_CAPABILITY_ID,
            f"{entry_id}: Phase 13 capability ID drifted",
        )
        require(
            entry["capability_decision_owner"] == PHASE13_CAPABILITY_OWNER,
            f"{entry_id}: Phase 13 capability owner drifted",
        )

    require(
        sum(decisions.values()) == len(rows),
        "Phase 13 capability decisions do not cover every registry row",
    )
    return {
        "row_count": len(rows),
        "capability_id": PHASE13_CAPABILITY_ID,
        "decision_owner": PHASE13_CAPABILITY_OWNER,
        "decision_counts": decisions,
    }


def verify_phase13_scalar_expression_contract(registry):
    verify_phase13_capability_contract(registry)
    rows = {
        entry["id"]: entry
        for entry in phase_entries(registry, "phase13")
    }
    require(
        PHASE13_SCALAR_EXPRESSION_ENTRY_ID in rows,
        "Phase 13 scalar-expression registry row is missing",
    )
    entry = rows[PHASE13_SCALAR_EXPRESSION_ENTRY_ID]
    require(
        entry["status"] == "migrated",
        "Phase 13 scalar-expression row must be migrated",
    )
    require(
        entry["route_owner"] == "generic_canonical_mir",
        "Phase 13 scalar-expression row must use the generic canonical-MIR route",
    )
    require(
        entry["worker_capability_owner"]
        == "worker_scalar_expression_lowering",
        "Phase 13 scalar-expression worker owner drifted",
    )
    require(
        entry["diagnostic_owner"] == "canonical_mir_scalar_verifier",
        "Phase 13 scalar-expression diagnostic owner drifted",
    )
    require(
        entry["capability_decision"] == "supported",
        "Phase 13 scalar-expression capability decision must be supported",
    )
    require(
        entry["capability_reason_code"]
        == "supported_p13_scalar_multiply_i32",
        "Phase 13 scalar-expression capability reason code drifted",
    )
    require(
        entry["expected_failure_stage"] == "none_supported",
        "Phase 13 scalar-expression supported row has a failure stage",
    )
    require(
        entry["canonical_mir_fixture"]
        == "compiler/fixtures/native_backend_phase13_scalar_expression_ingestion.mir",
        "Phase 13 scalar-expression canonical MIR fixture drifted",
    )
    require(
        entry["deferral_reason"] == "none_migrated"
        and entry["future_destination_phase"] == "none_migrated",
        "Migrated Phase 13 scalar-expression row must use canonical migrated fields",
    )

    evidence = entry["evidence"]
    require(
        evidence.get("selected_operations")
        == PHASE13_SCALAR_EXPRESSION_SELECTED_OPERATIONS,
        "Phase 13 scalar-expression selected operation inventory drifted",
    )
    require(
        evidence.get("retained_composition_operations")
        == PHASE13_SCALAR_EXPRESSION_COMPOSITION_OPERATIONS,
        "Phase 13 scalar-expression composition operation inventory drifted",
    )
    require(
        evidence.get("bounded_expression_grammar")
        == PHASE13_SCALAR_EXPRESSION_GRAMMAR,
        "Phase 13 scalar-expression bounded grammar drifted",
    )
    focused = evidence.get("focused_source_fixtures")
    negatives = evidence.get("negative_source_fixtures")
    require(
        isinstance(focused, list) and len(focused) == 4,
        "Phase 13 scalar-expression focused source inventory must contain four fixtures",
    )
    require(
        isinstance(negatives, list) and len(negatives) == 4,
        "Phase 13 scalar-expression negative source inventory must contain four fixtures",
    )
    for index, path in enumerate(focused):
        fixture(path, f"{entry['id']}.evidence.focused_source_fixtures[{index}]")
    for index, path in enumerate(negatives):
        fixture(path, f"{entry['id']}.evidence.negative_source_fixtures[{index}]")
    fixture(
        evidence.get("malformed_canonical_mir_fixture"),
        f"{entry['id']}.evidence.malformed_canonical_mir_fixture",
    )
    fixture(
        evidence.get("deferred_fixture"),
        f"{entry['id']}.evidence.deferred_fixture",
    )
    require(
        evidence.get("positive_expectation")
        == "exit_12_phase13_scalar_multiply",
        "Phase 13 scalar-expression differential expectation drifted",
    )

    other_supported = [
        row["id"]
        for row in rows.values()
        if row["id"] not in {
            PHASE13_SCALAR_EXPRESSION_ENTRY_ID,
            PHASE13_MULTIPLE_LOCALS_ENTRY_ID,
            PHASE13_NESTED_STRUCTURED_CFG_ENTRY_ID,
            PHASE13_GENERAL_LOOP_ENTRY_ID,
            PHASE13_PARAMETER_ARGUMENT_ENTRY_ID,
            PHASE13_DIRECT_CALL_GRAPH_ENTRY_ID,
            PHASE13_BROADER_RUNTIME_CALL_ENTRY_ID,
            *PHASE13_SOURCE_METADATA_ENTRY_IDS,
        }
        and row["capability_decision"] == "supported"
    ]
    require(
        not other_supported,
        "Phase 13 selected capability contract must not migrate unrelated rows: "
        f"{sorted(other_supported)}",
    )
    return {
        "entry_id": entry["id"],
        "selected_operations": evidence["selected_operations"],
        "composition_operations": evidence["retained_composition_operations"],
        "focused_fixture_count": len(focused),
        "negative_fixture_count": len(negatives),
    }


def verify_phase13_multiple_locals_contract(registry):
    verify_phase13_scalar_expression_contract(registry)
    rows = {
        entry["id"]: entry
        for entry in phase_entries(registry, "phase13")
    }
    require(
        PHASE13_MULTIPLE_LOCALS_ENTRY_ID in rows,
        "Phase 13 multiple-locals registry row is missing",
    )
    entry = rows[PHASE13_MULTIPLE_LOCALS_ENTRY_ID]
    require(
        entry["status"] == "migrated",
        "Phase 13 multiple-locals row must be migrated",
    )
    require(
        entry["route_owner"] == "generic_canonical_mir",
        "Phase 13 multiple-locals row must use generic canonical MIR",
    )
    require(
        entry["worker_capability_owner"] == "worker_local_state_lowering",
        "Phase 13 multiple-locals worker owner drifted",
    )
    require(
        entry["diagnostic_owner"] == "canonical_mir_scalar_verifier",
        "Phase 13 multiple-locals diagnostic owner drifted",
    )
    require(
        entry["capability_decision"] == "supported",
        "Phase 13 multiple-locals capability decision must be supported",
    )
    require(
        entry["capability_reason_code"]
        == "supported_p13_two_local_update_branch_source_route",
        "Phase 13 multiple-locals capability reason code drifted",
    )
    require(
        entry["expected_failure_stage"] == "none_supported",
        "Phase 13 multiple-locals supported row has a failure stage",
    )
    require(
        entry["source_fixture"]
        == "compiler/phase13_multiple_locals_assignments_source.gst",
        "Phase 13 multiple-locals source fixture drifted",
    )
    require(
        entry["canonical_mir_fixture"]
        == "compiler/fixtures/native_backend_phase13_multiple_locals_assignments_ingestion.mir",
        "Phase 13 multiple-locals canonical MIR fixture drifted",
    )
    require(
        entry["deferral_reason"] == "none_migrated"
        and entry["future_destination_phase"] == "none_migrated",
        "Migrated Phase 13 multiple-locals row must use canonical migrated fields",
    )

    evidence = entry["evidence"]
    require(
        evidence.get("selected_operations")
        == PHASE13_MULTIPLE_LOCALS_SELECTED_OPERATIONS,
        "Phase 13 multiple-locals selected operation inventory drifted",
    )
    require(
        evidence.get("composition_features")
        == PHASE13_MULTIPLE_LOCALS_COMPOSITION_FEATURES,
        "Phase 13 multiple-locals composition inventory drifted",
    )
    require(
        evidence.get("sequencing_policy")
        == PHASE13_MULTIPLE_LOCALS_SEQUENCING_POLICY,
        "Phase 13 multiple-locals sequencing policy drifted",
    )
    focused = evidence.get("focused_source_fixtures")
    negatives = evidence.get("negative_source_fixtures")
    malformed = evidence.get("malformed_canonical_mir_fixtures")
    require(
        isinstance(focused, list) and len(focused) == 4,
        "Phase 13 multiple-locals focused source inventory must contain four fixtures",
    )
    require(
        isinstance(negatives, list) and len(negatives) == 5,
        "Phase 13 multiple-locals negative source inventory must contain five fixtures",
    )
    require(
        isinstance(malformed, list) and len(malformed) == 3,
        "Phase 13 multiple-locals malformed MIR inventory must contain three fixtures",
    )
    for index, path in enumerate(focused):
        fixture(
            path,
            f"{entry['id']}.evidence.focused_source_fixtures[{index}]",
        )
    for index, path in enumerate(negatives):
        fixture(
            path,
            f"{entry['id']}.evidence.negative_source_fixtures[{index}]",
        )
    for index, path in enumerate(malformed):
        fixture(
            path,
            f"{entry['id']}.evidence.malformed_canonical_mir_fixtures[{index}]",
        )
    fixture(
        evidence.get("deferred_fixture"),
        f"{entry['id']}.evidence.deferred_fixture",
    )
    require(
        evidence.get("positive_expectation")
        == "exit_20_phase13_multiple_locals_assignments",
        "Phase 13 multiple-locals differential expectation drifted",
    )

    other_supported = [
        row["id"]
        for row in rows.values()
        if row["id"] not in {
            PHASE13_SCALAR_EXPRESSION_ENTRY_ID,
            PHASE13_MULTIPLE_LOCALS_ENTRY_ID,
            PHASE13_NESTED_STRUCTURED_CFG_ENTRY_ID,
            PHASE13_GENERAL_LOOP_ENTRY_ID,
            PHASE13_PARAMETER_ARGUMENT_ENTRY_ID,
            PHASE13_DIRECT_CALL_GRAPH_ENTRY_ID,
            PHASE13_BROADER_RUNTIME_CALL_ENTRY_ID,
            *PHASE13_SOURCE_METADATA_ENTRY_IDS,
        }
        and row["capability_decision"] == "supported"
    ]
    require(
        not other_supported,
        "Phase 13 selected capability contract must not migrate unrelated rows: "
        f"{sorted(other_supported)}",
    )
    return {
        "entry_id": entry["id"],
        "selected_operations": evidence["selected_operations"],
        "composition_features": evidence["composition_features"],
        "focused_fixture_count": len(focused),
        "negative_fixture_count": len(negatives),
        "malformed_fixture_count": len(malformed),
    }


def verify_phase13_nested_structured_cfg_contract(registry):
    verify_phase13_multiple_locals_contract(registry)
    rows = {
        entry["id"]: entry
        for entry in phase_entries(registry, "phase13")
    }
    require(
        PHASE13_NESTED_STRUCTURED_CFG_ENTRY_ID in rows,
        "Phase 13 nested structured-CFG registry row is missing",
    )
    entry = rows[PHASE13_NESTED_STRUCTURED_CFG_ENTRY_ID]
    require(
        entry["status"] == "migrated",
        "Phase 13 nested structured-CFG row must be migrated",
    )
    require(
        entry["route_owner"] == "generic_canonical_mir",
        "Phase 13 nested structured-CFG row must use generic canonical MIR",
    )
    require(
        entry["worker_capability_owner"] == "worker_structured_cfg_lowering",
        "Phase 13 nested structured-CFG worker owner drifted",
    )
    require(
        entry["diagnostic_owner"] == "canonical_mir_cfg_verifier",
        "Phase 13 nested structured-CFG diagnostic owner drifted",
    )
    require(
        entry["capability_decision"] == "supported",
        "Phase 13 nested structured-CFG capability decision must be supported",
    )
    require(
        entry["capability_reason_code"]
        == "supported_p13_nested_local_update_branch_source_route",
        "Phase 13 nested structured-CFG capability reason code drifted",
    )
    require(
        entry["expected_failure_stage"] == "none_supported",
        "Phase 13 nested structured-CFG supported row has a failure stage",
    )
    require(
        entry["source_fixture"]
        == "compiler/phase13_nested_structured_cfg_source.gst",
        "Phase 13 nested structured-CFG source fixture drifted",
    )
    require(
        entry["canonical_mir_fixture"]
        == "compiler/fixtures/native_backend_phase13_nested_structured_cfg_ingestion.mir",
        "Phase 13 nested structured-CFG canonical MIR fixture drifted",
    )
    require(
        entry["deferral_reason"] == "none_migrated"
        and entry["future_destination_phase"] == "none_migrated",
        "Migrated Phase 13 nested structured-CFG row must use canonical migrated fields",
    )

    evidence = entry["evidence"]
    require(
        evidence.get("selected_shapes")
        == PHASE13_NESTED_STRUCTURED_CFG_SHAPES,
        "Phase 13 nested structured-CFG shape inventory drifted",
    )
    require(
        evidence.get("validation_invariants")
        == PHASE13_NESTED_STRUCTURED_CFG_INVARIANTS,
        "Phase 13 nested structured-CFG invariant inventory drifted",
    )
    require(
        evidence.get("block_identity_policy")
        == PHASE13_NESTED_STRUCTURED_CFG_BLOCK_POLICY,
        "Phase 13 nested structured-CFG block identity policy drifted",
    )
    focused = evidence.get("focused_source_fixtures")
    malformed = evidence.get("malformed_canonical_mir_fixtures")
    deferred = evidence.get("deferred_source_fixtures")
    require(
        isinstance(focused, list) and len(focused) == 6,
        "Phase 13 nested structured-CFG focused inventory must contain six fixtures",
    )
    require(
        isinstance(malformed, list) and len(malformed) == 6,
        "Phase 13 nested structured-CFG malformed MIR inventory must contain six fixtures",
    )
    require(
        isinstance(deferred, list) and len(deferred) == 2,
        "Phase 13 nested structured-CFG deferred inventory must contain two fixtures",
    )
    for index, path in enumerate(focused):
        fixture(
            path,
            f"{entry['id']}.evidence.focused_source_fixtures[{index}]",
        )
    for index, path in enumerate(malformed):
        fixture(
            path,
            f"{entry['id']}.evidence.malformed_canonical_mir_fixtures[{index}]",
        )
    for index, path in enumerate(deferred):
        fixture(
            path,
            f"{entry['id']}.evidence.deferred_source_fixtures[{index}]",
        )
    require(
        evidence.get("deferral_reason_prefix")
        == "deferred_p13_structured_cfg_",
        "Phase 13 nested structured-CFG deferral reason prefix drifted",
    )
    require(
        evidence.get("deferred_fixture_reason_codes")
        == PHASE13_NESTED_STRUCTURED_CFG_DEFERRED_REASONS,
        "Phase 13 nested structured-CFG deferred reason inventory drifted",
    )
    require(
        evidence.get("positive_expectation")
        == "exit_36_phase13_nested_structured_cfg",
        "Phase 13 nested structured-CFG differential expectation drifted",
    )
    require(
        evidence.get("deferred_fixture")
        == "compiler/phase13_structured_cfg_short_circuit_deferred_source.gst",
        "Phase 13 nested structured-CFG differential deferred fixture drifted",
    )

    other_supported = [
        row["id"]
        for row in rows.values()
        if row["id"] not in {
            PHASE13_SCALAR_EXPRESSION_ENTRY_ID,
            PHASE13_MULTIPLE_LOCALS_ENTRY_ID,
            PHASE13_NESTED_STRUCTURED_CFG_ENTRY_ID,
            PHASE13_GENERAL_LOOP_ENTRY_ID,
            PHASE13_PARAMETER_ARGUMENT_ENTRY_ID,
            PHASE13_DIRECT_CALL_GRAPH_ENTRY_ID,
            PHASE13_BROADER_RUNTIME_CALL_ENTRY_ID,
            *PHASE13_SOURCE_METADATA_ENTRY_IDS,
        }
        and row["capability_decision"] == "supported"
    ]
    require(
        not other_supported,
        "Patch 13.4 must not migrate unrelated Phase 13 rows: "
        f"{sorted(other_supported)}",
    )
    return {
        "entry_id": entry["id"],
        "selected_shapes": evidence["selected_shapes"],
        "validation_invariants": evidence["validation_invariants"],
        "focused_fixture_count": len(focused),
        "malformed_fixture_count": len(malformed),
        "deferred_fixture_count": len(deferred),
        "deferred_reason_codes": evidence["deferred_fixture_reason_codes"],
    }


def verify_phase13_general_loop_contract(registry):
    verify_phase13_nested_structured_cfg_contract(registry)
    rows = {
        entry["id"]: entry
        for entry in phase_entries(registry, "phase13")
    }
    require(
        PHASE13_GENERAL_LOOP_ENTRY_ID in rows,
        "Phase 13 general-loop registry row is missing",
    )
    entry = rows[PHASE13_GENERAL_LOOP_ENTRY_ID]
    require(
        entry["status"] == "migrated",
        "Phase 13 general-loop row must be migrated",
    )
    require(
        entry["route_owner"] == "generic_canonical_mir",
        "Phase 13 general-loop row must use generic canonical MIR",
    )
    require(
        entry["worker_capability_owner"]
        == "worker_block_parameter_loop_lowering",
        "Phase 13 general-loop worker owner drifted",
    )
    require(
        entry["diagnostic_owner"] == "canonical_mir_cfg_verifier",
        "Phase 13 general-loop diagnostic owner drifted",
    )
    require(
        entry["capability_decision"] == "supported",
        "Phase 13 general-loop capability decision must be supported",
    )
    require(
        entry["capability_reason_code"]
        == "supported_p13_general_loop_backedge_source_route",
        "Phase 13 general-loop capability reason code drifted",
    )
    require(
        entry["expected_failure_stage"] == "none_supported",
        "Phase 13 general-loop supported row has a failure stage",
    )
    require(
        entry["source_fixture"]
        == "compiler/phase11_structured_cfg_deferred_loop_source.gst",
        "Phase 13 general-loop source fixture drifted",
    )
    require(
        entry["canonical_mir_fixture"]
        == "compiler/fixtures/native_backend_phase13_general_loop_ingestion.mir",
        "Phase 13 general-loop canonical MIR fixture drifted",
    )
    require(
        entry["deferral_reason"] == "none_migrated"
        and entry["future_destination_phase"] == "none_migrated",
        "Migrated Phase 13 general-loop row must use canonical migrated fields",
    )

    evidence = entry["evidence"]
    require(
        evidence.get("selected_loop_shapes") == PHASE13_GENERAL_LOOP_SHAPES,
        "Phase 13 general-loop selected shape inventory drifted",
    )
    require(
        evidence.get("parameter_arity_policy")
        == PHASE13_GENERAL_LOOP_PARAMETER_POLICY,
        "Phase 13 general-loop parameter policy drifted",
    )
    require(
        evidence.get("validation_invariants")
        == PHASE13_GENERAL_LOOP_INVARIANTS,
        "Phase 13 general-loop validation inventory drifted",
    )
    focused = evidence.get("focused_source_fixtures")
    malformed = evidence.get("malformed_canonical_mir_fixtures")
    invalid = evidence.get("invalid_source_fixtures")
    deferred = evidence.get("deferred_source_fixtures")
    require(
        isinstance(focused, list) and len(focused) == 3,
        "Phase 13 general-loop focused source inventory must contain three fixtures",
    )
    require(
        isinstance(malformed, list) and len(malformed) == 6,
        "Phase 13 general-loop malformed MIR inventory must contain six fixtures",
    )
    require(
        isinstance(invalid, list) and len(invalid) == 1,
        "Phase 13 general-loop invalid source inventory must contain one fixture",
    )
    require(
        isinstance(deferred, list) and len(deferred) == 4,
        "Phase 13 general-loop deferred source inventory must contain four fixtures",
    )
    for group_name, paths in (
        ("focused_source_fixtures", focused),
        ("malformed_canonical_mir_fixtures", malformed),
        ("invalid_source_fixtures", invalid),
        ("deferred_source_fixtures", deferred),
    ):
        for index, path in enumerate(paths):
            fixture(
                path,
                f"{entry['id']}.evidence.{group_name}[{index}]",
            )
    require(
        evidence.get("deferred_fixture_reason_codes")
        == PHASE13_GENERAL_LOOP_DEFERRED_REASONS,
        "Phase 13 general-loop deferred reason inventory drifted",
    )
    require(
        evidence.get("positive_expectation")
        == "exit_0_phase13_single_carried_loop",
        "Phase 13 general-loop differential expectation drifted",
    )
    require(
        evidence.get("deferred_fixture")
        == "compiler/phase13_loop_early_return_deferred_source.gst",
        "Phase 13 general-loop differential deferred fixture drifted",
    )

    other_supported = [
        row["id"]
        for row in rows.values()
        if row["id"] not in {
            PHASE13_SCALAR_EXPRESSION_ENTRY_ID,
            PHASE13_MULTIPLE_LOCALS_ENTRY_ID,
            PHASE13_NESTED_STRUCTURED_CFG_ENTRY_ID,
            PHASE13_GENERAL_LOOP_ENTRY_ID,
            PHASE13_PARAMETER_ARGUMENT_ENTRY_ID,
            PHASE13_DIRECT_CALL_GRAPH_ENTRY_ID,
            PHASE13_BROADER_RUNTIME_CALL_ENTRY_ID,
            *PHASE13_SOURCE_METADATA_ENTRY_IDS,
        }
        and row["capability_decision"] == "supported"
    ]
    require(
        not other_supported,
        "Patch 13.5 must not migrate unrelated Phase 13 rows: "
        f"{sorted(other_supported)}",
    )
    return {
        "entry_id": entry["id"],
        "selected_shapes": evidence["selected_loop_shapes"],
        "validation_invariants": evidence["validation_invariants"],
        "focused_fixture_count": len(focused),
        "malformed_fixture_count": len(malformed),
        "invalid_fixture_count": len(invalid),
        "deferred_fixture_count": len(deferred),
        "deferred_reason_codes": evidence["deferred_fixture_reason_codes"],
    }


def verify_phase13_parameter_argument_contract(registry):
    verify_phase13_general_loop_contract(registry)
    rows = {
        entry["id"]: entry
        for entry in phase_entries(registry, "phase13")
    }
    require(
        PHASE13_PARAMETER_ARGUMENT_ENTRY_ID in rows,
        "Phase 13 parameter/argument registry row is missing",
    )
    entry = rows[PHASE13_PARAMETER_ARGUMENT_ENTRY_ID]
    require(
        entry["status"] == "migrated",
        "Phase 13 parameter/argument row must be migrated",
    )
    require(
        entry["route_owner"] == "generic_canonical_mir",
        "Phase 13 parameter/argument row must use generic canonical MIR",
    )
    require(
        entry["worker_capability_owner"] == "worker_direct_call_lowering",
        "Phase 13 parameter/argument worker owner drifted",
    )
    require(
        entry["diagnostic_owner"]
        == "source_signature_and_call_graph_verifier",
        "Phase 13 parameter/argument diagnostic owner drifted",
    )
    require(
        entry["capability_decision"] == "supported",
        "Phase 13 parameter/argument capability must be supported",
    )
    require(
        entry["capability_reason_code"]
        == "supported_p13_parameterized_local_call_branch_source_route",
        "Phase 13 parameter/argument capability reason drifted",
    )
    require(
        entry["expected_failure_stage"] == "none_supported",
        "Phase 13 parameter/argument supported row has a failure stage",
    )
    require(
        entry["source_fixture"]
        == "compiler/phase13_parameter_argument_branch_source.gst",
        "Phase 13 parameter/argument source fixture drifted",
    )
    require(
        entry["canonical_mir_fixture"]
        == "compiler/fixtures/native_backend_phase13_parameter_argument_ingestion.mir",
        "Phase 13 parameter/argument canonical MIR fixture drifted",
    )
    require(
        entry["deferral_reason"] == "none_migrated"
        and entry["future_destination_phase"] == "none_migrated",
        "Migrated Phase 13 parameter/argument row must use migrated fields",
    )

    evidence = entry["evidence"]
    require(
        evidence.get("selected_shapes") == PHASE13_PARAMETER_ARGUMENT_SHAPES,
        "Phase 13 parameter/argument selected shape inventory drifted",
    )
    require(
        evidence.get("parameter_identity_policy")
        == PHASE13_PARAMETER_ARGUMENT_POLICY,
        "Phase 13 parameter identity policy drifted",
    )
    require(
        evidence.get("validation_invariants")
        == PHASE13_PARAMETER_ARGUMENT_INVARIANTS,
        "Phase 13 parameter/argument validation inventory drifted",
    )
    focused = evidence.get("focused_source_fixtures")
    malformed = evidence.get("malformed_canonical_mir_fixtures")
    invalid = evidence.get("invalid_source_fixtures")
    deferred = evidence.get("deferred_source_fixtures")
    require(
        isinstance(focused, list) and len(focused) == 6,
        "Phase 13 parameter/argument focused inventory must contain six fixtures",
    )
    require(
        isinstance(malformed, list) and len(malformed) == 6,
        "Phase 13 parameter/argument malformed MIR inventory must contain six fixtures",
    )
    require(
        isinstance(invalid, list) and len(invalid) == 2,
        "Phase 13 parameter/argument invalid source inventory must contain two fixtures",
    )
    require(
        isinstance(deferred, list) and len(deferred) == 3,
        "Phase 13 parameter/argument deferred source inventory must contain three fixtures",
    )
    for group_name, paths in (
        ("focused_source_fixtures", focused),
        ("malformed_canonical_mir_fixtures", malformed),
        ("invalid_source_fixtures", invalid),
        ("deferred_source_fixtures", deferred),
    ):
        for index, path in enumerate(paths):
            fixture(
                path,
                f"{entry['id']}.evidence.{group_name}[{index}]",
            )
    require(
        evidence.get("deferred_fixture_reason_codes")
        == PHASE13_PARAMETER_ARGUMENT_DEFERRED_REASONS,
        "Phase 13 parameter/argument deferred reason inventory drifted",
    )
    require(
        evidence.get("positive_expectation")
        == "exit_42_phase13_three_argument_branch",
        "Phase 13 parameter/argument differential expectation drifted",
    )
    require(
        evidence.get("deferred_fixture")
        == "compiler/phase13_parameter_argument_aggregate_parameter_source.gst",
        "Phase 13 parameter/argument deferred fixture drifted",
    )

    other_supported = [
        row["id"]
        for row in rows.values()
        if row["id"] not in {
            PHASE13_SCALAR_EXPRESSION_ENTRY_ID,
            PHASE13_MULTIPLE_LOCALS_ENTRY_ID,
            PHASE13_NESTED_STRUCTURED_CFG_ENTRY_ID,
            PHASE13_GENERAL_LOOP_ENTRY_ID,
            PHASE13_PARAMETER_ARGUMENT_ENTRY_ID,
            PHASE13_DIRECT_CALL_GRAPH_ENTRY_ID,
            PHASE13_BROADER_RUNTIME_CALL_ENTRY_ID,
            *PHASE13_SOURCE_METADATA_ENTRY_IDS,
        }
        and row["capability_decision"] == "supported"
    ]
    require(
        not other_supported,
        "Patch 13.6 must not migrate unrelated Phase 13 rows: "
        f"{sorted(other_supported)}",
    )
    return {
        "entry_id": entry["id"],
        "selected_shapes": evidence["selected_shapes"],
        "validation_invariants": evidence["validation_invariants"],
        "focused_fixture_count": len(focused),
        "malformed_fixture_count": len(malformed),
        "invalid_fixture_count": len(invalid),
        "deferred_fixture_count": len(deferred),
        "deferred_reason_codes": evidence["deferred_fixture_reason_codes"],
    }



def verify_phase13_direct_call_graph_contract(registry):
    verify_phase13_parameter_argument_contract(registry)
    rows = {
        entry["id"]: entry
        for entry in phase_entries(registry, "phase13")
    }
    require(
        PHASE13_DIRECT_CALL_GRAPH_ENTRY_ID in rows,
        "Phase 13 direct-call graph registry row is missing",
    )
    entry = rows[PHASE13_DIRECT_CALL_GRAPH_ENTRY_ID]
    require(
        entry["status"] == "migrated",
        "Phase 13 direct-call graph row must be migrated",
    )
    require(
        entry["route_owner"] == "generic_canonical_mir",
        "Phase 13 direct-call graph row must use generic canonical MIR",
    )
    require(
        entry["worker_capability_owner"] == "worker_direct_call_lowering",
        "Phase 13 direct-call graph worker owner drifted",
    )
    require(
        entry["diagnostic_owner"]
        == "source_signature_and_call_graph_verifier",
        "Phase 13 direct-call graph diagnostic owner drifted",
    )
    require(
        entry["capability_decision"] == "supported"
        and entry["capability_reason_code"]
        == "supported_p13_multi_function_direct_call_graph_source_route"
        and entry["expected_failure_stage"] == "none_supported",
        "Phase 13 direct-call graph capability contract drifted",
    )
    require(
        entry["source_fixture"]
        == "compiler/phase13_direct_call_graph_source.gst",
        "Phase 13 direct-call graph source fixture drifted",
    )
    require(
        entry["canonical_mir_fixture"]
        == "compiler/fixtures/native_backend_phase13_direct_call_graph_ingestion.mir",
        "Phase 13 direct-call graph canonical MIR fixture drifted",
    )
    require(
        entry["deferral_reason"] == "none_migrated"
        and entry["future_destination_phase"] == "none_migrated",
        "Migrated Phase 13 direct-call graph row must use migrated fields",
    )

    evidence = entry["evidence"]
    require(
        evidence.get("selected_shapes") == PHASE13_DIRECT_CALL_GRAPH_SHAPES,
        "Phase 13 direct-call graph selected shape inventory drifted",
    )
    require(
        evidence.get("declaration_policy")
        == "declare_all_scalar_function_signatures_before_lowering_any_function_body",
        "Phase 13 direct-call graph declaration policy drifted",
    )
    require(
        evidence.get("identity_policy")
        == "source_function_identity_preserved_with_phase13_7_module_qualified_backend_symbols",
        "Phase 13 direct-call graph identity policy drifted",
    )
    require(
        evidence.get("recursion_policy")
        == "no_recursive_form_selected_for_phase13_7",
        "Phase 13 direct-call graph recursion policy drifted",
    )
    require(
        evidence.get("validation_invariants")
        == PHASE13_DIRECT_CALL_GRAPH_INVARIANTS,
        "Phase 13 direct-call graph validation inventory drifted",
    )
    focused = evidence.get("focused_source_fixtures")
    malformed = evidence.get("malformed_canonical_mir_fixtures")
    deferred = evidence.get("deferred_source_fixtures")
    require(
        isinstance(focused, list) and len(focused) == 4,
        "Phase 13 direct-call graph focused inventory must contain four fixtures",
    )
    require(
        isinstance(malformed, list) and len(malformed) == 7,
        "Phase 13 direct-call graph malformed MIR inventory must contain seven fixtures",
    )
    require(
        isinstance(deferred, list) and len(deferred) == 2,
        "Phase 13 direct-call graph deferred source inventory must contain two fixtures",
    )
    for group_name, paths in (
        ("focused_source_fixtures", focused),
        ("malformed_canonical_mir_fixtures", malformed),
        ("deferred_source_fixtures", deferred),
    ):
        for index, path in enumerate(paths):
            fixture(
                path,
                f"{entry['id']}.evidence.{group_name}[{index}]",
            )
    require(
        evidence.get("deferred_fixture_reason_codes")
        == PHASE13_DIRECT_CALL_GRAPH_DEFERRED_REASONS,
        "Phase 13 direct-call graph deferred reason inventory drifted",
    )
    require(
        evidence.get("positive_expectation")
        == "exit_14_phase13_multi_function_direct_call_graph",
        "Phase 13 direct-call graph differential expectation drifted",
    )

    policy_expectations = {
        "p13_recursive_direct_call_policy": (
            "direct_recursion",
            "deferred_p13_recursive_direct_call_policy",
        ),
        "p13_mutual_recursive_direct_call_policy": (
            "mutual_recursion",
            "deferred_p13_mutual_recursive_direct_call_policy",
        ),
        "p13_indirect_direct_call_policy": (
            "indirect_calls",
            "deferred_p13_indirect_direct_call_policy",
        ),
        "p13_function_value_call_policy": (
            "function_values",
            "deferred_p13_function_value_call_policy",
        ),
    }
    require(
        list(policy_expectations) == PHASE13_DIRECT_CALL_GRAPH_POLICY_IDS,
        "Phase 13 direct-call graph policy ID inventory drifted",
    )
    for policy_id, (unsupported_form, reason_code) in policy_expectations.items():
        require(
            policy_id in rows,
            f"Phase 13 direct-call graph policy row is missing: {policy_id}",
        )
        policy = rows[policy_id]
        require(
            policy["status"] == "replaced"
            and policy["route_owner"] == "deferred"
            and policy["capability_decision"] == "deferred"
            and policy["capability_reason_code"] == reason_code
            and policy["expected_failure_stage"]
            == "before_driver_discovery",
            f"{policy_id}: direct-call graph deferred policy drifted",
        )
        require(
            policy["evidence"].get("unsupported_form") == unsupported_form
            and policy["evidence"].get("deferred_reason_code")
            == reason_code,
            f"{policy_id}: direct-call graph policy evidence drifted",
        )

    return {
        "entry_id": entry["id"],
        "selected_shapes": evidence["selected_shapes"],
        "validation_invariants": evidence["validation_invariants"],
        "focused_fixture_count": len(focused),
        "malformed_fixture_count": len(malformed),
        "deferred_fixture_count": len(deferred),
        "deferred_reason_codes": evidence["deferred_fixture_reason_codes"],
        "policy_row_count": len(policy_expectations),
    }

def verify_phase13_broader_runtime_call_contract(registry):
    verify_phase13_direct_call_graph_contract(registry)
    rows = {
        entry["id"]: entry
        for entry in phase_entries(registry, "phase13")
    }
    require(
        PHASE13_BROADER_RUNTIME_CALL_ENTRY_ID in rows,
        "Phase 13 broader runtime-call registry row is missing",
    )
    entry = rows[PHASE13_BROADER_RUNTIME_CALL_ENTRY_ID]
    require(
        entry["status"] == "migrated"
        and entry["route_owner"] == "generic_canonical_mir"
        and entry["capability_decision"] == "supported"
        and entry["capability_reason_code"]
        == "supported_p13_imported_predicate_update_branch_source_route"
        and entry["expected_failure_stage"] == "none_supported",
        "Phase 13 broader runtime-call capability contract drifted",
    )
    require(
        entry["worker_capability_owner"] == "worker_module_import_lowering"
        and entry["diagnostic_owner"]
        == "resolver_signature_and_canonical_mir_verifier",
        "Phase 13 broader runtime-call ownership drifted",
    )
    require(
        entry["source_fixture"]
        == "compiler/phase13_runtime_predicate_branch_source.gst",
        "Phase 13 broader runtime-call selected source fixture drifted",
    )
    require(
        entry["deferral_reason"] == "none_migrated"
        and entry["future_destination_phase"] == "none_migrated",
        "Migrated broader runtime-call row must use migrated fields",
    )
    evidence = entry["evidence"]
    require(
        evidence.get("selected_shapes") == PHASE13_BROADER_RUNTIME_SHAPES,
        "Phase 13 broader runtime-call composition inventory drifted",
    )
    require(
        evidence.get("approved_symbols")
        == PHASE13_BROADER_RUNTIME_APPROVED_SYMBOLS,
        "Phase 13 broader runtime-call approved symbol inventory drifted",
    )
    require(
        evidence.get("approved_signatures")
        == PHASE13_BROADER_RUNTIME_APPROVED_SIGNATURES,
        "Phase 13 broader runtime-call approved signature inventory drifted",
    )
    require(
        evidence.get("authority_policy")
        == "approved_host_symbol_and_exact_scalar_signature_registry_is_separate_from_source_module_import_resolution",
        "Phase 13 broader runtime-call authority separation drifted",
    )
    require(
        evidence.get("link_policy")
        == "worker_owned_fixed_host_object_only_no_source_or_environment_linker_expansion",
        "Phase 13 broader runtime-call link policy drifted",
    )
    focused = evidence.get("focused_source_fixtures")
    negative = evidence.get("negative_source_fixtures")
    require(
        isinstance(focused, list) and len(focused) == 7,
        "Phase 13 broader runtime-call focused inventory must contain seven fixtures",
    )
    require(
        isinstance(negative, list) and len(negative) == 4,
        "Phase 13 broader runtime-call negative inventory must contain four fixtures",
    )
    for group_name, paths in (
        ("focused_source_fixtures", focused),
        ("negative_source_fixtures", negative),
    ):
        for index, path in enumerate(paths):
            fixture(path, f"{entry['id']}.evidence.{group_name}[{index}]")

    require(
        PHASE13_BROADER_RUNTIME_CALL_POLICY_ID in rows,
        "Phase 13 unapproved-host policy row is missing",
    )
    policy = rows[PHASE13_BROADER_RUNTIME_CALL_POLICY_ID]
    require(
        policy["status"] == "replaced"
        and policy["route_owner"] == "deferred"
        and policy["capability_decision"] == "deferred"
        and policy["capability_reason_code"]
        == "deferred_p13_unapproved_host_symbol_policy"
        and policy["expected_failure_stage"]
        == "before_driver_discovery",
        "Phase 13 unapproved-host policy must be replaced by narrow residual rows",
    )
    require(
        policy["evidence"].get("unsupported_forms")
        == PHASE13_BROADER_RUNTIME_UNSUPPORTED_FORMS,
        "Phase 13 unapproved-host rejected-form inventory drifted",
    )
    for key in (
        "environment_symbol_approval",
        "dynamic_symbol_lookup",
        "arbitrary_libraries",
        "arbitrary_linker_flags",
    ):
        require(
            policy["evidence"].get(key) == "forbidden",
            f"Phase 13 unapproved-host policy must forbid {key}",
        )

    phase11_import = next(
        row
        for row in phase_entries(registry, "phase11")
        if row["id"] == "imported_runtime_call_i32"
    )
    require(
        phase11_import["evidence"].get("approved_symbols")
        == PHASE13_BROADER_RUNTIME_APPROVED_SYMBOLS,
        "Phase 11 imported-runtime evidence must share the Phase 13.9 symbol authority",
    )
    require(
        phase11_import["evidence"].get("approved_signatures")
        == PHASE13_BROADER_RUNTIME_APPROVED_SIGNATURES,
        "Phase 11 imported-runtime evidence must share the Phase 13.9 ABI authority",
    )

    return {
        "entry_id": entry["id"],
        "approved_symbol_count": len(PHASE13_BROADER_RUNTIME_APPROVED_SYMBOLS),
        "approved_signature_count": len(PHASE13_BROADER_RUNTIME_APPROVED_SIGNATURES),
        "selected_shapes": evidence["selected_shapes"],
        "focused_fixture_count": len(focused),
        "negative_fixture_count": len(negative),
        "unsupported_forms": policy["evidence"]["unsupported_forms"],
    }


def verify_phase13_source_metadata_contract(registry):
    verify_phase13_broader_runtime_call_contract(registry)
    rows = {
        entry["id"]: entry
        for entry in phase_entries(registry, "phase13")
    }
    for entry_id in PHASE13_SOURCE_METADATA_ENTRY_IDS:
        require(entry_id in rows, f"Phase 13 source metadata row is missing: {entry_id}")
        entry = rows[entry_id]
        require(
            entry["status"] == "migrated"
            and entry["route_owner"] == "generic_canonical_mir"
            and entry["capability_decision"] == "supported"
            and entry["expected_failure_stage"] == "none_supported"
            and entry["deferral_reason"] == "none_migrated"
            and entry["future_destination_phase"] == "none_migrated",
            f"Phase 13 source metadata capability contract drifted: {entry_id}",
        )
        evidence = entry["evidence"]
        require(
            evidence.get("metadata_contract_version") == "phase13_10",
            f"Phase 13 source metadata contract version drifted: {entry_id}",
        )
        require(
            evidence.get("source_connected_routes")
            == PHASE13_SOURCE_METADATA_ROUTES,
            f"Phase 13 source metadata route inventory drifted: {entry_id}",
        )
        require(
            evidence.get("malformed_metadata_fixtures")
            == PHASE13_SOURCE_METADATA_MALFORMED_FIXTURES,
            f"Phase 13 malformed metadata inventory drifted: {entry_id}",
        )
        for index, path in enumerate(evidence["source_connected_routes"]):
            fixture(path, f"{entry_id}.evidence.source_connected_routes[{index}]")
        for index, path in enumerate(evidence["malformed_metadata_fixtures"]):
            fixture(path, f"{entry_id}.evidence.malformed_metadata_fixtures[{index}]")

    resource = rows["p13_resource_metadata_source_route"]
    require(
        resource["capability_reason_code"]
        == "supported_p13_resource_metadata_source_route"
        and resource["source_fixture"]
        == "compiler/phase13_source_resource_metadata_source.gst"
        and resource["canonical_mir_fixture"]
        == "compiler/fixtures/phase13_source_metadata_valid_resource.mir",
        "Phase 13 resource metadata source contract drifted",
    )
    require(
        resource["evidence"].get("classification")
        == "validated_preserved"
        and resource["evidence"].get("codegen_semantics") == "preserved"
        and resource["evidence"].get("narrow_resource_deferral_reason_code")
        == "deferred_p13_resource_runtime_semantics"
        and resource["evidence"].get("deferred_resource_semantics")
        == PHASE13_SOURCE_METADATA_DEFERRED_RESOURCE_SEMANTICS,
        "Phase 13 resource metadata classification or narrow deferral drifted",
    )

    boundary = rows["p13_native_boundary_metadata_source_route"]
    require(
        boundary["capability_reason_code"]
        == "supported_p13_native_boundary_metadata_source_route"
        and boundary["source_fixture"]
        == "compiler/phase13_runtime_multiple_calls_source.gst"
        and boundary["evidence"].get("classification")
        == "validated_codegen_relevant"
        and boundary["evidence"].get("codegen_semantics") == "required"
        and boundary["evidence"].get("bounded_codegen_relevance")
        == "approved_import_symbol_signature_and_statement_owner_validation_only",
        "Phase 13 native-boundary metadata classification drifted",
    )

    return {
        "entry_ids": PHASE13_SOURCE_METADATA_ENTRY_IDS,
        "source_route_count": len(PHASE13_SOURCE_METADATA_ROUTES),
        "malformed_fixture_count": len(PHASE13_SOURCE_METADATA_MALFORMED_FIXTURES),
        "deferred_resource_semantics": PHASE13_SOURCE_METADATA_DEFERRED_RESOURCE_SEMANTICS,
    }


def verify_phase13_composition_differential_contract(registry):
    verify_phase13_source_metadata_contract(registry)
    migrated = [
        entry
        for entry in registry["entries"]
        if entry.get("status") == "migrated"
        and entry.get("route_owner") == "generic_canonical_mir"
    ]
    require(migrated, "Registry contains no migrated differential rows")
    migrated_by_id = {entry["id"]: entry for entry in migrated}
    require(
        len(migrated_by_id) == len(migrated),
        "Migrated differential entry IDs are not unique",
    )
    migrated_source_owners = {
        entry["source_fixture"]: entry["id"]
        for entry in migrated
    }
    require(
        len(migrated_source_owners) == len(migrated),
        "Migrated differential source fixtures are not unique",
    )

    active_families = {
        entry["ci_family"]
        for entry in phase_entries(registry, "phase11")
    }
    individual_case_ids = set()
    composition_cases = {}
    composition_owner_ids = set()
    composition_references = {}

    for entry in migrated:
        entry_id = entry["id"]
        case_id = text(
            entry["differential_case_id"],
            f"{entry_id}.differential_case_id",
        )
        require(
            case_id not in individual_case_ids,
            f"duplicate individual differential case ID: {case_id}",
        )
        individual_case_ids.add(case_id)

        evidence = entry["evidence"]
        text(
            evidence.get("individual_evidence_guard"),
            f"{entry_id}.evidence.individual_evidence_guard",
        )
        expectation = text(
            evidence.get("positive_expectation"),
            f"{entry_id}.evidence.positive_expectation",
        )
        require(
            re.fullmatch(r"exit_[0-9]+_.+", expectation) is not None,
            f"{entry_id}: positive expectation must declare an exit status",
        )
        require(
            evidence.get("differential_stderr_policy")
            in PHASE13_DIFFERENTIAL_STDERR_POLICIES,
            f"{entry_id}: invalid differential stderr policy",
        )
        require(
            evidence.get("differential_side_effect_policy")
            in PHASE13_DIFFERENTIAL_SIDE_EFFECT_POLICIES,
            f"{entry_id}: invalid differential side-effect policy",
        )
        failure_fixture = text(
            evidence.get("differential_failure_fixture"),
            f"{entry_id}.evidence.differential_failure_fixture",
        )
        fixture(
            failure_fixture,
            f"{entry_id}.evidence.differential_failure_fixture",
        )
        require(
            failure_fixture not in migrated_source_owners,
            f"{entry_id}: differential failure fixture is the active migrated "
            f"source owned by {migrated_source_owners.get(failure_fixture)}",
        )
        fixture(entry["source_fixture"], f"{entry_id}.source_fixture")

        references = unique_strings(
            evidence.get("composition_case_ids"),
            f"{entry_id}.evidence.composition_case_ids",
        )
        require(
            references,
            f"{entry_id}: migrated row has no composition relationship",
        )
        composition_references[entry_id] = set(references)

        owned_cases = evidence.get("composition_cases", [])
        require(
            isinstance(owned_cases, list),
            f"{entry_id}.evidence.composition_cases must be an array",
        )
        for index, case in enumerate(owned_cases):
            context = f"{entry_id}.evidence.composition_cases[{index}]"
            require(
                isinstance(case, dict)
                and set(case) == PHASE13_COMPOSITION_CASE_FIELDS,
                f"{context} fields drifted",
            )
            case_id = text(case["id"], f"{context}.id")
            require(
                case_id not in composition_cases
                and case_id not in individual_case_ids,
                f"duplicate differential case ID: {case_id}",
            )
            require(
                case["owner_entry_id"] == entry_id,
                f"{case_id}: composition owner does not match containing row",
            )
            require(
                entry["origin_phase"] == "phase13",
                f"{case_id}: composition case owner must be a Phase 13 row",
            )
            family = text(case["ci_family"], f"{context}.ci_family")
            require(
                family in active_families,
                f"{case_id}: composition case uses inactive family {family}",
            )
            fixture(case["source_fixture"], f"{context}.source_fixture")
            failure_fixture = text(
                case["failure_fixture"],
                f"{context}.failure_fixture",
            )
            fixture(failure_fixture, f"{context}.failure_fixture")
            require(
                failure_fixture not in migrated_source_owners,
                f"{case_id}: composition failure fixture is the active migrated "
                f"source owned by {migrated_source_owners.get(failure_fixture)}",
            )
            require(
                re.fullmatch(
                    r"exit_[0-9]+_.+",
                    text(case["positive_expectation"], f"{context}.positive_expectation"),
                )
                is not None,
                f"{case_id}: composition expectation must declare an exit status",
            )
            require(
                case["stderr_policy"] in PHASE13_DIFFERENTIAL_STDERR_POLICIES,
                f"{case_id}: invalid stderr policy",
            )
            require(
                case["side_effect_policy"]
                in PHASE13_DIFFERENTIAL_SIDE_EFFECT_POLICIES,
                f"{case_id}: invalid side-effect policy",
            )
            covers = unique_strings(
                case["covers_entry_ids"],
                f"{context}.covers_entry_ids",
            )
            require(
                len(covers) >= 2,
                f"{case_id}: composition case must cover at least two migrated rows",
            )
            require(
                entry_id in covers,
                f"{case_id}: composition case does not cover its owner",
            )
            for covered_id in covers:
                require(
                    covered_id in migrated_by_id,
                    f"{case_id}: unknown or non-migrated covered row {covered_id}",
                )
            composition_cases[case_id] = case
            composition_owner_ids.add(entry_id)

    require(
        composition_cases,
        "Phase 13 composition differential inventory is empty",
    )
    for entry_id, references in composition_references.items():
        for case_id in references:
            require(
                case_id in composition_cases,
                f"{entry_id}: unknown composition case reference {case_id}",
            )
            require(
                entry_id in composition_cases[case_id]["covers_entry_ids"],
                f"{entry_id}: composition reference {case_id} does not cover the row",
            )

    for case_id, case in composition_cases.items():
        expected_referrers = set(case["covers_entry_ids"])
        actual_referrers = {
            entry_id
            for entry_id, references in composition_references.items()
            if case_id in references
        }
        require(
            actual_referrers == expected_referrers,
            f"{case_id}: registry references differ from covers_entry_ids",
        )

    composition_families = {
        case["ci_family"]
        for case in composition_cases.values()
    }
    require(
        composition_families == active_families,
        "Composition differential family coverage drifted: "
        f"missing={sorted(active_families - composition_families)} "
        f"extra={sorted(composition_families - active_families)}",
    )

    phase13_migrated = [
        entry for entry in migrated if entry["origin_phase"] == "phase13"
    ]
    for entry in phase13_migrated:
        require(
            entry["id"] in composition_references,
            f"{entry['id']}: Phase 13 migrated row lacks composition evidence",
        )

    return {
        "migrated_row_count": len(migrated),
        "phase13_migrated_row_count": len(phase13_migrated),
        "individual_case_count": len(individual_case_ids),
        "composition_case_count": len(composition_cases),
        "composition_owner_count": len(composition_owner_ids),
        "family_count": len(active_families),
        "case_ids": sorted(composition_cases),
    }


def verify_phase13_deferred_residue_audit(registry):
    verify_phase13_composition_differential_contract(registry)
    snapshot = validate_phase13_residual_snapshot_structure(registry)
    rows = phase_entries(registry, "phase13")
    disposition_counts = Counter(entry["status"] for entry in rows)
    residual_rows = snapshot["rows"]
    residual_family_counts = Counter(row["feature_family"] for row in residual_rows)
    destination_counts = Counter(row["destination_phase"] for row in residual_rows)
    inherited = [
        entry for entry in rows
        if entry["parent"].startswith("phase11_entry:")
    ]

    require(
        set(disposition_counts) <= {"migrated", "excluded", "replaced"},
        "Phase 13 final dispositions contain active deferred residue",
    )
    require(
        disposition_counts["migrated"] + disposition_counts["excluded"]
        + disposition_counts["replaced"] == len(rows),
        "Phase 13 final disposition totals do not reconcile",
    )
    require(
        all(entry["status"] in {"migrated", "excluded", "replaced"} for entry in inherited),
        "An inherited Phase 11 deferred row remains unresolved",
    )
    require(
        sum(residual_family_counts.values()) == len(residual_rows),
        "Residual feature-family totals do not reconcile",
    )
    require(
        sum(destination_counts.values()) == len(residual_rows),
        "Residual destination totals do not reconcile",
    )
    return {
        "version": snapshot["version"],
        "status": snapshot["status"],
        "phase13_row_count": len(rows),
        "disposition_counts": disposition_counts,
        "inherited_row_count": len(inherited),
        "residual_row_count": len(residual_rows),
        "residual_family_counts": residual_family_counts,
        "destination_counts": destination_counts,
        "residual_ids": [row["id"] for row in residual_rows],
    }


def verify_phase13_closure(registry):
    residue = verify_phase13_deferred_residue_audit(registry)
    composition = verify_phase13_composition_differential_contract(registry)
    snapshot = validate_phase13_closure_snapshot_structure(registry)
    rows = phase_entries(registry, "phase13")
    residual_rows = registry["residual_snapshots"]["phase13"]["rows"]

    migrated_ids = [
        entry["id"] for entry in rows if entry["status"] == "migrated"
    ]
    replaced_ids = [
        entry["id"] for entry in rows if entry["status"] == "replaced"
    ]
    excluded_ids = [
        entry["id"] for entry in rows if entry["status"] == "excluded"
    ]
    require(
        registry["registry_status"]
        in {
            PHASE13_CLOSURE_VERSION,
            "phase14_opening_inventory_ready",
            "phase14_layout_authority_ready",
        },
        "Phase 13 closure registry status drifted",
    )
    require(
        snapshot["opening_entry_count"] == len(rows)
        == residue["phase13_row_count"],
        "Phase 13 closure opening-row total drifted",
    )
    require(
        snapshot["disposition_counts"] == {
            "migrated": len(migrated_ids),
            "replaced": len(replaced_ids),
            "excluded": len(excluded_ids),
        },
        "Phase 13 closure disposition totals differ from live rows",
    )
    require(
        snapshot["migrated_entry_ids"] == migrated_ids,
        "Phase 13 closure migrated stable-ID inventory drifted",
    )
    require(
        snapshot["replaced_entry_ids"] == replaced_ids,
        "Phase 13 closure replaced stable-ID inventory drifted",
    )
    require(
        snapshot["excluded_entry_ids"] == excluded_ids,
        "Phase 13 closure excluded stable-ID inventory drifted",
    )
    require(
        snapshot["residual_entry_count"] == len(residual_rows)
        == residue["residual_row_count"],
        "Phase 13 closure residual-row total drifted",
    )
    for entry in rows:
        require(
            entry["status"] in {"migrated", "replaced", "excluded"},
            f"{entry['id']}: Phase 13 closure found an unresolved disposition",
        )
        if entry["status"] == "migrated":
            require(
                entry["route_owner"] == snapshot["migrated_route_owner"],
                f"{entry['id']}: migrated closure row is not generic canonical MIR",
            )
            require(
                entry["capability_decision"] == "supported",
                f"{entry['id']}: migrated closure row lacks supported capability",
            )
        else:
            require(
                entry["route_owner"] in {"deferred", "excluded"},
                f"{entry['id']}: non-migrated closure row has an active route",
            )
    for row in residual_rows:
        for field in (
            "capability_owner",
            "diagnostic_owner",
            "concrete_reason",
            "destination_phase",
            "prerequisite_capability",
            "current_failure_stage",
            "positive_future_fixture",
            "negative_current_fixture",
        ):
            text(row[field], f"{row['id']}.{field}")
    require(
        composition["phase13_migrated_row_count"] == len(migrated_ids),
        "Phase 13 closure migrated rows lack complete composition wiring",
    )
    serialized = json.dumps(registry, sort_keys=True)
    for banned in ("SHA256", "SHA-256", "sha256sum"):
        require(
            banned not in serialized,
            f"Phase 13 closure registry contains banned raw-hash token: {banned}",
        )
    return {
        "closure_version": snapshot["closure_version"],
        "status": snapshot["status"],
        "scope": snapshot["scope"],
        "opening_entry_count": len(rows),
        "disposition_counts": snapshot["disposition_counts"],
        "residual_entry_count": len(residual_rows),
        "migrated_entry_count": len(migrated_ids),
        "composition_case_count": composition["composition_case_count"],
        "family_count": composition["family_count"],
        "closure_guard": snapshot["closure_guard"],
        "ci_owner": snapshot["ci_owner"],
        "wording": snapshot["closure_wording"],
    }


def verify_phase13_parent_traceability(registry):
    phase11 = {
        entry["id"]: entry
        for entry in phase_entries(registry, "phase11")
    }
    categories = set(registry["planning_categories"])
    rows = verify_phase13_registry_schema(registry)
    parent_kinds = Counter()

    for entry in rows:
        entry_id = entry["id"]
        parent = entry["parent"]
        if parent.startswith("phase11_entry:"):
            parent_kinds["phase11_entry"] += 1
            parent_id = parent.split(":", 1)[1]
            require(parent_id in phase11, f"{entry_id}: missing parent {parent_id}")
            parent_entry = phase11[parent_id]
            require(
                parent_entry["status"] == "deferred",
                f"{entry_id}: inherited parent is not deferred",
            )
            require(
                entry["status"]
                in {"inherited_deferred", "migrated", "excluded", "replaced"},
                f"{entry_id}: entry parent has invalid current status",
            )
            if entry["status"] == "inherited_deferred":
                require(
                    entry["source_fixture"] == parent_entry["source_fixture"],
                    f"{entry_id}: still-deferred inherited source fixture differs from Phase 11",
                )
                require(
                    entry["canonical_mir_fixture"]
                    == parent_entry["canonical_mir_fixture"],
                    f"{entry_id}: still-deferred inherited canonical MIR fixture differs from Phase 11",
                )
        elif parent.startswith("phase11_category:"):
            parent_kinds["phase11_category"] += 1
            category = parent.split(":", 1)[1]
            require(category in categories, f"{entry_id}: unknown category {category}")
            require(
                entry["status"]
                in {"candidate_deferred", "migrated", "excluded", "replaced"},
                f"{entry_id}: category parent has invalid current status",
            )
        else:
            raise Error(f"{entry_id}: invalid parent {parent}")

    require(
        sum(parent_kinds.values()) == len(rows),
        "Phase 13 parent-kind totals do not cover every opening row",
    )
    return parent_kinds


def verify_phase13_opening_totals(registry):
    rows = verify_phase13_registry_schema(registry)
    parent_kinds = verify_phase13_parent_traceability(registry)
    status_counts = Counter(
        (
            "inherited_deferred"
            if entry["evidence"]["opening_record_kind"] == "inherited"
            else "candidate_deferred"
        )
        for entry in rows
    )
    feature_counts = Counter(entry["feature_family"] for entry in rows)
    ci_counts = Counter(entry["ci_family"] for entry in rows)

    for label, counter in (
        ("status", status_counts),
        ("feature family", feature_counts),
        ("CI family", ci_counts),
        ("parent kind", parent_kinds),
    ):
        require(
            sum(counter.values()) == len(rows),
            f"Phase 13 {label} totals do not reconcile with opening rows",
        )

    require(
        status_counts["inherited_deferred"]
        == parent_kinds["phase11_entry"],
        "Phase 13 inherited status total differs from entry-parent total",
    )
    require(
        status_counts["candidate_deferred"]
        == parent_kinds["phase11_category"],
        "Phase 13 candidate status total differs from category-parent total",
    )
    return {
        "row_count": len(rows),
        "status_counts": status_counts,
        "feature_counts": feature_counts,
        "ci_counts": ci_counts,
        "parent_kinds": parent_kinds,
    }


def derived_totals(registry):
    entries = registry["entries"]
    deferred_entries = [
        entry for entry in entries if entry["status"] in DEFERRED
    ]
    return {
        "total_rows": len(entries),
        "origin_phase": Counter(entry["origin_phase"] for entry in entries),
        "status": Counter(entry["status"] for entry in entries),
        "feature_family": Counter(entry["feature_family"] for entry in entries),
        "ci_family": Counter(entry["ci_family"] for entry in entries),
        "route_owner": Counter(entry["route_owner"] for entry in entries),
        "deferred_destination": Counter(
            entry["future_destination_phase"] for entry in deferred_entries
        ),
    }


def count_lines(counter):
    return [f"- `{key}`: `{counter[key]}`" for key in sorted(counter)]


def closure_summary_lines(registry):
    snapshot = verify_phase11_closure(registry)
    counts = snapshot["classification_counts"]
    return [
        "## Phase 11 semantic closure summary",
        "",
        f"- Closure version: `{snapshot['closure_version']}`",
        f"- Closed rows: `{snapshot['entry_count']}`",
        f"- Migrated: `{counts['migrated']}`",
        f"- Deferred: `{counts['deferred']}`",
        f"- Excluded: `{counts['excluded']}`",
        "- Deferred parent IDs:",
        *[f"  - `{entry_id}`" for entry_id in snapshot["deferred_entry_ids"]],
        "",
        "This text is generated from the semantic closure snapshot in the JSON registry.",
        "",
    ]


def phase13_closure_summary_lines(registry):
    snapshot = verify_phase13_closure(registry)
    counts = snapshot["disposition_counts"]
    return [
        "## Phase 13 scoped closure summary",
        "",
        f"- Closure version: `{snapshot['closure_version']}`",
        f"- Closure scope: `{snapshot['scope']}`",
        f"- Opening rows closed: `{snapshot['opening_entry_count']}`",
        f"- Migrated: `{counts['migrated']}`",
        f"- Replaced by narrower residuals: `{counts['replaced']}`",
        f"- Excluded: `{counts['excluded']}`",
        f"- Frozen residual capabilities: `{snapshot['residual_entry_count']}`",
        f"- Level 1 closure guard: `{snapshot['closure_guard']}`",
        f"- CI owner: `{snapshot['ci_owner']}`",
        "",
        snapshot["wording"],
        "",
        "This closure is scoped to the declared Phase 13 deferred-parity expansion inventory and is not a claim of complete Gust language parity.",
        "",
    ]


def cell(value):
    return str(value).replace("|", r"\|").replace("\n", " ")


PHASE13_VIEW_FIELDS = (
    "id", "parent", "feature_family", "source_fixture",
    "canonical_mir_fixture", "route_owner", "worker_capability_owner",
    "diagnostic_owner", "capability_id", "capability_decision_owner",
    "capability_decision", "capability_reason_code",
    "expected_failure_stage", "ci_family", "status", "deferral_reason",
)


def phase13_record(entry):
    fields = [
        f"{field}={entry[field]}"
        for field in PHASE13_VIEW_FIELDS
    ]
    return "phase13_entry: " + "|".join(fields) + "|"


def render_phase13(registry):
    snapshot = verify_phase13_opening_rebase(registry)
    totals = verify_phase13_opening_totals(registry)
    capability_contract = verify_phase13_capability_contract(registry)
    scalar_contract = verify_phase13_scalar_expression_contract(registry)
    local_state_contract = verify_phase13_multiple_locals_contract(registry)
    cfg_contract = verify_phase13_nested_structured_cfg_contract(registry)
    loop_contract = verify_phase13_general_loop_contract(registry)
    parameter_contract = verify_phase13_parameter_argument_contract(registry)
    graph_contract = verify_phase13_direct_call_graph_contract(registry)
    runtime_contract = verify_phase13_broader_runtime_call_contract(registry)
    metadata_contract = verify_phase13_source_metadata_contract(registry)
    composition_contract = verify_phase13_composition_differential_contract(registry)
    residue_contract = verify_phase13_deferred_residue_audit(registry)
    closure_contract = verify_phase13_closure(registry)
    rows = phase_entries(registry, "phase13")
    status_counts = totals["status_counts"]
    current_status_counts = Counter(entry["status"] for entry in rows)
    parent_kinds = totals["parent_kinds"]

    lines = [
        "# Cranelift Phase 13 Final Review and Deferred Residue",
        "",
        "<!-- Generated by scripts/cranelift_registry.py; do not edit by hand. -->",
        "",
        "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_VERSION: 11",
        "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_AUTHORITY: generated_review_view",
        "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_CANONICAL_SOURCE: scripts/cranelift_feature_registry.json",
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_OPENING_VERSION: "
            f"{snapshot['opening_version']}"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_INVENTORY_VERSION: "
            f"{snapshot['inventory_version']}"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_STATUS: "
            f"{closure_contract['status']}"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_OPENING_STATUS: "
            f"{snapshot['status']}"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_PREDECESSOR_VERSION: "
            f"{snapshot['predecessor_closure_version']}"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_FRAMEWORK_CLOSURE_VERSION: "
            f"{registry['closed_phase_versions']['phase12_5']}"
        ),
        "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_DERIVED_SUMMARY: docs/CRANELIFT_FEATURE_REGISTRY.md",
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_CAPABILITY_ID: "
            f"{capability_contract['capability_id']}"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_CAPABILITY_DECISION_OWNER: "
            f"{capability_contract['decision_owner']}"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_CAPABILITY_CONTRACT_STATUS: "
            "patch13_1_capability_deferral_contract_active"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_SCALAR_EXPRESSION_STATUS: "
            "patch13_2_bounded_mul_sub_literal_chain_migrated"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_SCALAR_EXPRESSION_OPERATIONS: "
            + ",".join(scalar_contract["selected_operations"])
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_MULTIPLE_LOCALS_STATUS: "
            "patch13_3_multiple_locals_and_assignments_migrated"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_MULTIPLE_LOCALS_OPERATIONS: "
            + ",".join(local_state_contract["selected_operations"])
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_OPENING_POLICY: "
            f"{snapshot['behavior_policy']}"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_STRUCTURED_CFG_STATUS: "
            "patch13_4_nested_structured_cfg_migrated"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_STRUCTURED_CFG_SHAPES: "
            + ",".join(cfg_contract["selected_shapes"])
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_GENERAL_LOOP_STATUS: "
            "patch13_5_general_loop_backedge_migrated"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_GENERAL_LOOP_SHAPES: "
            + ",".join(loop_contract["selected_shapes"])
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_PARAMETER_ARGUMENT_STATUS: "
            "patch13_6_parameters_and_arguments_migrated"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_PARAMETER_ARGUMENT_SHAPES: "
            + ",".join(parameter_contract["selected_shapes"])
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_DIRECT_CALL_GRAPH_STATUS: "
            "patch13_7_multi_function_direct_call_graph_migrated"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_DIRECT_CALL_GRAPH_SHAPES: "
            + ",".join(graph_contract["selected_shapes"])
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_BROADER_RUNTIME_CALL_STATUS: "
            "patch13_9_broader_imported_runtime_calls_migrated"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_SOURCE_METADATA_STATUS: "
            "patch13_10_source_produced_metadata_integrated"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_SOURCE_METADATA_ROWS: "
            + ",".join(metadata_contract["entry_ids"])
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_COMPOSITION_STATUS: "
            "patch13_11_registry_derived_cross_feature_differential_active"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_COMPOSITION_CASES: "
            f"{composition_contract['composition_case_count']}"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_COMPOSITION_FAMILIES: "
            f"{composition_contract['family_count']}"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_RESIDUE_STATUS: "
            f"{residue_contract['status']}"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_RESIDUE_VERSION: "
            f"{residue_contract['version']}"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_RESIDUE_ROWS: "
            f"{residue_contract['residual_row_count']}"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_CLOSURE_STATUS: "
            f"{closure_contract['status']}"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_CLOSURE_VERSION: "
            f"{closure_contract['closure_version']}"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_CLOSURE_SCOPE: "
            f"{closure_contract['scope']}"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_CLOSURE_GUARD: "
            f"{closure_contract['closure_guard']}"
        ),
        (
            "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_CLOSURE_CI_OWNER: "
            f"{closure_contract['ci_owner']}"
        ),
        "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_NEXT_MILESTONE: later_phase_residual_capabilities",
        "",
        "This review artifact is generated from the structured registry. Phase 12.5",
        "is closed under the recorded framework closure version. Stable Phase 13 IDs",
        "and parent relationships are frozen semantically by `opening_snapshots.phase13`;",
        "totals and Markdown layout are derived.",
        "",
        "## Derived opening totals",
        "",
        f"- Opening rows: `{totals['row_count']}`",
        f"- Inherited deferred rows: `{status_counts['inherited_deferred']}`",
        f"- Candidate deferred rows: `{status_counts['candidate_deferred']}`",
        f"- Phase 11 entry parents: `{parent_kinds['phase11_entry']}`",
        f"- Phase 11 category parents: `{parent_kinds['phase11_category']}`",
        "",
        "### Feature families",
        "",
        *count_lines(totals["feature_counts"]),
        "",
        "### CI families",
        "",
        *count_lines(totals["ci_counts"]),
        "",
        "### Current capability decisions",
        "",
        *count_lines(capability_contract["decision_counts"]),
        "",
        "### Current Phase 13 dispositions",
        "",
        *count_lines(current_status_counts),
        "",
        "### Patch 13.2 scalar-expression selection",
        "",
        (
            "- Migrated row: "
            f"`{scalar_contract['entry_id']}`"
        ),
        (
            "- Selected operations: "
            + ", ".join(
                f"`{operation}`"
                for operation in scalar_contract["selected_operations"]
            )
        ),
        (
            "- Composition operations: "
            + ", ".join(
                f"`{operation}`"
                for operation in scalar_contract["composition_operations"]
            )
        ),
        (
            "- Focused source fixtures: "
            f"`{scalar_contract['focused_fixture_count']}`"
        ),
        (
            "- Negative fixtures: "
            f"`{scalar_contract['negative_fixture_count']}`"
        ),
        "",
        "### Patch 13.3 multiple-locals and assignments selection",
        "",
        (
            "- Migrated row: "
            f"`{local_state_contract['entry_id']}`"
        ),
        (
            "- Selected operations: "
            + ", ".join(
                f"`{operation}`"
                for operation in local_state_contract["selected_operations"]
            )
        ),
        (
            "- Composition features: "
            + ", ".join(
                f"`{feature}`"
                for feature in local_state_contract["composition_features"]
            )
        ),
        (
            "- Focused source fixtures: "
            f"`{local_state_contract['focused_fixture_count']}`"
        ),
        (
            "- Negative source fixtures: "
            f"`{local_state_contract['negative_fixture_count']}`"
        ),
        (
            "- Malformed MIR fixtures: "
            f"`{local_state_contract['malformed_fixture_count']}`"
        ),
        "",
        "### Patch 13.4 nested structured-control-flow selection",
        "",
        (
            "- Migrated row: "
            f"`{cfg_contract['entry_id']}`"
        ),
        (
            "- Selected shapes: "
            + ", ".join(
                f"`{shape}`"
                for shape in cfg_contract["selected_shapes"]
            )
        ),
        (
            "- Validation invariants: "
            + ", ".join(
                f"`{invariant}`"
                for invariant in cfg_contract["validation_invariants"]
            )
        ),
        (
            "- Focused source fixtures: "
            f"`{cfg_contract['focused_fixture_count']}`"
        ),
        (
            "- Malformed MIR fixtures: "
            f"`{cfg_contract['malformed_fixture_count']}`"
        ),
        (
            "- Deferred source fixtures: "
            f"`{cfg_contract['deferred_fixture_count']}`"
        ),
        (
            "- Deferred reason codes: "
            + ", ".join(
                f"`{reason}`"
                for reason in cfg_contract["deferred_reason_codes"]
            )
        ),
        "",
        "### Patch 13.5 general-loop and backedge selection",
        "",
        (
            "- Migrated row: "
            f"`{loop_contract['entry_id']}`"
        ),
        (
            "- Selected shapes: "
            + ", ".join(
                f"`{shape}`"
                for shape in loop_contract["selected_shapes"]
            )
        ),
        (
            "- Validation invariants: "
            + ", ".join(
                f"`{invariant}`"
                for invariant in loop_contract["validation_invariants"]
            )
        ),
        (
            "- Focused source fixtures: "
            f"`{loop_contract['focused_fixture_count']}`"
        ),
        (
            "- Malformed MIR fixtures: "
            f"`{loop_contract['malformed_fixture_count']}`"
        ),
        (
            "- Invalid source fixtures: "
            f"`{loop_contract['invalid_fixture_count']}`"
        ),
        (
            "- Deferred source fixtures: "
            f"`{loop_contract['deferred_fixture_count']}`"
        ),
        (
            "- Deferred reason codes: "
            + ", ".join(
                f"`{reason}`"
                for reason in loop_contract["deferred_reason_codes"]
            )
        ),
        "",
        "### Patch 13.11 cross-feature composition differential",
        "",
        (
            "- Migrated differential rows: "
            f"`{composition_contract['migrated_row_count']}`"
        ),
        (
            "- Phase 13 migrated rows: "
            f"`{composition_contract['phase13_migrated_row_count']}`"
        ),
        (
            "- Individual registry-owned cases: "
            f"`{composition_contract['individual_case_count']}`"
        ),
        (
            "- Composition cases: "
            f"`{composition_contract['composition_case_count']}`"
        ),
        (
            "- Active CI families: "
            f"`{composition_contract['family_count']}`"
        ),
        "- Composition case IDs:",
        *[
            f"  - `{case_id}`"
            for case_id in composition_contract["case_ids"]
        ],
        "",
        "## Patch 13.12 deferred residue audit",
        "",
        f"- Audited Phase 13 rows: `{residue_contract['phase13_row_count']}`",
        f"- Migrated dispositions: `{residue_contract['disposition_counts']['migrated']}`",
        f"- Replaced dispositions: `{residue_contract['disposition_counts']['replaced']}`",
        f"- Excluded dispositions: `{residue_contract['disposition_counts']['excluded']}`",
        f"- Inherited Phase 11 rows resolved: `{residue_contract['inherited_row_count']}`",
        f"- Frozen residual rows: `{residue_contract['residual_row_count']}`",
        "",
        "### Residual destinations",
        "",
        *count_lines(residue_contract["destination_counts"]),
        "",
        "### Residual feature families",
        "",
        *count_lines(residue_contract["residual_family_counts"]),
        "",
        "### Frozen residual capabilities",
        "",
        *[
            (
                f"- `{row['id']}`: `{row['capability']}`; owner "
                f"`{row['capability_owner']}`; diagnostic "
                f"`{row['diagnostic_owner']}`; destination "
                f"`{row['destination_phase']}`; prerequisite "
                f"`{row['prerequisite_capability']}`; current failure "
                f"`{row['current_failure_stage']}`; future fixture "
                f"`{row['positive_future_fixture']}`; current fixture "
                f"`{row['negative_current_fixture']}`."
            )
            for row in registry["residual_snapshots"]["phase13"]["rows"]
        ],
        "",
        "## Patch 13.13 scoped Phase 13 closure",
        "",
        f"- Closure version: `{closure_contract['closure_version']}`",
        f"- Closure status: `{closure_contract['status']}`",
        f"- Closure scope: `{closure_contract['scope']}`",
        f"- Closed opening rows: `{closure_contract['opening_entry_count']}`",
        f"- Migrated rows: `{closure_contract['migrated_entry_count']}`",
        f"- Frozen residual capabilities: `{closure_contract['residual_entry_count']}`",
        f"- Registry-owned composition cases: `{closure_contract['composition_case_count']}`",
        f"- Registry-derived CI families: `{closure_contract['family_count']}`",
        f"- Level 1 closure guard: `{closure_contract['closure_guard']}`",
        f"- CI owner: `{closure_contract['ci_owner']}`",
        "",
        closure_contract["wording"],
        "",
        "The closure validates Level 2 and Level 3 ownership and wiring without replaying those suites.",
        "",
        "### Explicit non-claims",
        "",
        *[
            f"- `{claim}`"
            for claim in registry["closure_snapshots"]["phase13"]["non_claims"]
        ],
        "",
        "## Opening entries with final dispositions",
        "",
        *[phase13_record(entry) for entry in rows],
        "",
        "## Opening invariants",
        "",
        "- The Phase 11 semantic closure summary is the opening predecessor.",
        "- Every opening row is JSON-registry owned and has one validated capability decision.",
        "- Stable IDs and parent relationships must match the semantic opening snapshot.",
        "- Parent traceability and totals are validated from registry rows.",
        "- Phase 12.5 framework consolidation is formally closed before capability work resumes.",
        "- Full historical replay remains owned by the explicit Level 3 suite.",
        "- Patch 13.2 changes only the bounded scalar-expression capability selected in the registry.",
        "- Patch 13.3 migrates the selected multiple-local row without changing stable IDs or parent relationships.",
        "- Patch 13.4 migrates the selected nested-CFG row with deterministic blocks, origins, predecessors, and explicit termination.",
        "- Patch 13.5 migrates the selected single-header loop row with block-parameter-carried state and precise residual deferrals.",
        "- Unsupported early-return, nested-loop, body-control-flow, and condition-operator loop shapes remain deferred before driver discovery.",
        "- Patch 13.11 differential cases are generated from registry ownership rather than a separate Phase 13 feature list.",
        "- Patch 13.12 leaves no active inherited_deferred or candidate_deferred Phase 13 row.",
        "- Broad rows are marked replaced and point to smaller residual capabilities in the frozen semantic snapshot.",
        "- Every residual capability has a stable owner, diagnostic owner, destination phase, prerequisite, failure stage, future-positive fixture, and current-negative fixture.",
        "- Every migrated row has individual evidence, a composition relationship, and a differential case owner.",
        "- The existing registry-derived CI families own all composition cases without a patch-specific workflow matrix.",
        "- Patch 13.13 closes only the declared deferred-parity expansion inventory.",
        "- The closure guard owns Level 1 summary and wiring validation without replaying Level 2 families or Level 3 history.",
        "- MIR-to-C remains the default oracle and explicit Cranelift remains a no-fallback experimental route.",
        "- Phase 9G retains object, link, cleanup, and atomic publication ownership.",
        "- The separately scheduled or manually dispatched Cranelift Historical Full workflow remains the sole Level 3 owner.",
        "- No complete Gust language, type, ABI, control-flow, resource-semantics, or production-readiness parity claim is made.",
        "",
        closure_contract["wording"],
        "",
    ]
    rendered = "\n".join(lines)
    for banned in ("SHA256", "SHA-256", "sha256sum"):
        require(
            banned not in rendered,
            f"Phase 13 generated view contains banned raw-hash token: {banned}",
        )
    return rendered


PHASE14_VIEW_FIELDS = (
    "id", "parent", "feature_family", "ci_family",
    "worker_capability_owner", "diagnostic_owner",
    "target_applicability", "status", "current_failure_stage",
    "positive_future_fixture", "negative_current_fixture",
)


def phase14_record(entry):
    return "phase14_entry: " + "|".join(
        f"{field}={entry[field]}" for field in PHASE14_VIEW_FIELDS
    ) + "|"


def phase14_opening_summary_lines(registry):
    contract = verify_phase14_opening_contract(registry)
    snapshot = contract["snapshot"]
    residual_counts = contract["residual_disposition_counts"]
    return [
        "## Phase 14 opening inventory summary",
        "",
        f"- Opening version: `{snapshot['opening_version']}`",
        f"- Inventory version: `{snapshot['inventory_version']}`",
        f"- Status: `{snapshot['status']}`",
        f"- Predecessor closure: `{snapshot['predecessor_closure_version']}`",
        f"- Opening rows: `{contract['row_count']}`",
        f"- Registry-derived planned CI families: `{len(contract['ci_counts'])}`",
        f"- Phase 13 residuals selected: `{residual_counts['selected']}`",
        f"- Phase 13 residuals split: `{residual_counts['split']}`",
        f"- Phase 13 residuals reassigned: `{residual_counts['reassigned']}`",
        "",
        "The frozen Patch 14.0 opening snapshot is inventory-only. Patch 14.1 adds the compiler-owned layout authority and request transport without migrating a capability or expanding Level 2 or Level 3.",
        "",
    ]


def render_phase14(registry):
    contract = verify_phase14_opening_contract(registry)
    snapshot = contract["snapshot"]
    rows = phase_entries(registry, "phase14")
    residual_rows = snapshot["residual_rebase"]
    lines = [
        "# Cranelift Phase 14 Type, Layout, and Memory Opening Inventory",
        "",
        "<!-- Generated by scripts/cranelift_registry.py; do not edit by hand. -->",
        "",
        "CRANELIFT_PHASE14_TYPE_LAYOUT_MEMORY_REGISTRY_VERSION: 1",
        "CRANELIFT_PHASE14_TYPE_LAYOUT_MEMORY_REGISTRY_AUTHORITY: generated_review_view",
        "CRANELIFT_PHASE14_TYPE_LAYOUT_MEMORY_REGISTRY_CANONICAL_SOURCE: scripts/cranelift_feature_registry.json",
        (
            "CRANELIFT_PHASE14_TYPE_LAYOUT_MEMORY_REGISTRY_OPENING_VERSION: "
            f"{snapshot['opening_version']}"
        ),
        (
            "CRANELIFT_PHASE14_TYPE_LAYOUT_MEMORY_REGISTRY_INVENTORY_VERSION: "
            f"{snapshot['inventory_version']}"
        ),
        (
            "CRANELIFT_PHASE14_TYPE_LAYOUT_MEMORY_REGISTRY_STATUS: "
            f"{snapshot['status']}"
        ),
        (
            "CRANELIFT_PHASE14_TYPE_LAYOUT_MEMORY_REGISTRY_PREDECESSOR_VERSION: "
            f"{snapshot['predecessor_closure_version']}"
        ),
        (
            "CRANELIFT_PHASE14_TYPE_LAYOUT_MEMORY_REGISTRY_TARGET_APPLICABILITY: "
            f"{PHASE14_TARGET_APPLICABILITY}"
        ),
        (
            "CRANELIFT_PHASE14_TYPE_LAYOUT_MEMORY_REGISTRY_CI_DERIVATION: "
            f"{snapshot['ci_family_projection']['derivation']}"
        ),
        (
            "CRANELIFT_PHASE14_TYPE_LAYOUT_MEMORY_REGISTRY_BEHAVIOR_POLICY: "
            f"{snapshot['behavior_policy']}"
        ),
        "",
        "## Patch 14.0 opening inventory and Phase 13 residual rebase",
        "",
        "This opening snapshot establishes only the declared Phase 14 type, layout, and memory-model inventory. It consumes the scoped Phase 13 semantic closure and does not replay Phase 13 evidence or change compiler, backend, runtime, MIR, request, object, link, packaging, Level 2, or Level 3 behavior.",
        "",
        "## Derived opening totals",
        "",
        f"- Opening rows: `{contract['row_count']}`",
        "",
        "### Parent kinds",
        "",
        *count_lines(contract["parent_counts"]),
        "",
        "### Feature families",
        "",
        *count_lines(contract["feature_counts"]),
        "",
        "### Planned CI families",
        "",
        *count_lines(contract["ci_counts"]),
        "",
        "The planned Phase 14 CI-family projection is derived from opening rows. Patch 14.0 adds no Phase 14 Level 2 workflow matrix rows.",
        "",
        "## Opening entries",
        "",
        *[phase14_record(entry) for entry in rows],
        "",
        "## Phase 13 residual rebase",
        "",
        "| Phase 13 residual | Phase 14 disposition | Selected Phase 14 rows | Later destination | Later capability | Justification |",
        "|---|---|---|---|---|---|",
    ]
    for row in residual_rows:
        selected = ", ".join(row["selected_phase14_entry_ids"]) or "none"
        lines.append(
            "| "
            + " | ".join(
                cell(value)
                for value in (
                    row["source_residual_id"],
                    row["phase14_disposition"],
                    selected,
                    row["reassigned_destination_phase"],
                    row["reassigned_capability"],
                    row["justification"],
                )
            )
            + " |"
        )
    lines += [
        "",
        "## Opening invariants",
        "",
        "- The Phase 13 scoped semantic closure is the opening predecessor.",
        "- Phase 13 closure and residual snapshots remain immutable.",
        "- Every Phase 14 row has a stable ID, parent, feature family, planned CI family, capability owner, diagnostic owner, target applicability, status, failure stage, positive future fixture, and negative current fixture.",
        "- Parent traceability may target a migrated Phase 13 entry, a frozen Phase 13 residual capability, or an explicit Phase 14 planning category.",
        "- Only type, layout, and memory-model work enters the Phase 14 inventory.",
        "- Aggregate ABI, resource cleanup, CFG expansion, call-graph policy, module linkage, variadics, closures, and dynamic symbol loading remain explicitly assigned to later phases.",
        "- Target applicability is semantic and refers to the future compiler-owned target authority; no manually maintained target list or total is introduced.",
        "- Generated totals and Markdown layout are review projections rather than semantic authorities.",
        "- Raw registry hashes and Markdown hashes are forbidden.",
        "- Patch 14.0 changes no compiler, backend, runtime, MIR, request, artifact, Level 2, or Level 3 behavior.",
        "",
        "Patch 14.0 opening inventory is active; Phase 14 may proceed to Patch 14.1.",
        "",
    ]
    rendered = "\n".join(lines)
    for banned in ("SHA256", "SHA-256", "sha256sum"):
        require(
            banned not in rendered,
            f"Phase 14 generated view contains banned raw-hash token: {banned}",
        )
    return rendered


def phase14_layout_authority_summary_lines(registry):
    contract = verify_phase14_layout_authority(registry)
    authority = registry["phase14_layout_authority"]
    return [
        "## Phase 14 compiler-owned layout authority",
        "",
        f"- Authority version: `{contract['version']}`",
        f"- Status: `{contract['status']}`",
        f"- Authority owner: `{authority['authority_owner']}`",
        f"- Request table format: `{authority['table_format']}`",
        f"- Semantic layout records: `{contract['semantic_type_count']}`",
        f"- Compiler-owned queries: `{contract['query_count']}`",
        f"- Registered consumers: `{contract['consumer_count']}`",
        f"- Request rejection classes: `{contract['rejection_count']}`",
        f"- Phase 14 opening rows still deferred: `{contract['opening_row_count']}`",
        "",
        "Patch 14.1 establishes authority and transport only. It does not migrate a Phase 14 capability or activate a Phase 14 Level 2 family.",
        "",
    ]


def render_phase14_layout_authority(registry):
    contract = verify_phase14_layout_authority(registry)
    authority = registry["phase14_layout_authority"]
    consumers = authority["consumers"]
    lines = [
        "# Cranelift Phase 14 Compiler-Owned Layout Authority",
        "",
        "<!-- Generated by scripts/cranelift_registry.py; do not edit by hand. -->",
        "",
        "CRANELIFT_PHASE14_LAYOUT_AUTHORITY_VIEW_VERSION: 1",
        f"CRANELIFT_PHASE14_LAYOUT_AUTHORITY_VERSION: {contract['version']}",
        f"CRANELIFT_PHASE14_LAYOUT_AUTHORITY_STATUS: {contract['status']}",
        f"CRANELIFT_PHASE14_LAYOUT_AUTHORITY_OWNER: {authority['authority_owner']}",
        f"CRANELIFT_PHASE14_LAYOUT_AUTHORITY_TABLE_FORMAT: {authority['table_format']}",
        f"CRANELIFT_PHASE14_LAYOUT_AUTHORITY_IDENTITY_POLICY: {authority['identity_policy']}",
        f"CRANELIFT_PHASE14_LAYOUT_AUTHORITY_REQUEST_POLICY: {authority['request_transport_policy']}",
        f"CRANELIFT_PHASE14_LAYOUT_AUTHORITY_BEHAVIOR_POLICY: {authority['behavior_policy']}",
        f"CRANELIFT_PHASE14_LAYOUT_AUTHORITY_NEXT_PATCH: {authority['next_patch']}",
        "",
        "## Semantic layout records",
        "",
        *[f"- `{name}`" for name in authority["semantic_types"]],
        "",
        "## Compiler-owned queries",
        "",
        *[f"- `{name}`" for name in authority["query_functions"]],
        "",
        "## Consumers",
        "",
        *[f"- `{name}`: `{path}`" for name, path in consumers.items()],
        "",
        "## Request rejection classes",
        "",
        *[f"- `{name}`" for name in authority["rejection_classes"]],
        "",
        "## Hard bans",
        "",
        *[f"- `{name}`" for name in authority["hard_bans"]],
        "",
        "## Boundary",
        "",
        "The compiler owns target, type, field, variant, stride, and memory-access layout decisions. Canonical MIR carries layout references, the compiler serializes a request-local layout table, and the worker validates that table without selecting a competing layout.",
        "",
        "Patch 14.1 does not migrate primitive, pointer, memory, string, array, struct, enum, or aggregate-flow capabilities. Those rows remain deferred for bounded later patches.",
        "",
    ]
    rendered = "\n".join(lines)
    for banned in ("SHA256", "SHA-256", "sha256sum"):
        require(
            banned not in rendered,
            f"Phase 14 layout authority view contains banned raw-hash token: {banned}",
        )
    return rendered


def render(registry):
    entries = registry["entries"]
    totals = derived_totals(registry)
    lines = [
        "# Canonical Cranelift Feature Registry", "",
        "<!-- Generated by scripts/cranelift_registry.py; do not edit by hand. -->", "",
        f"- Schema version: `{registry['schema_version']}`",
        f"- Registry version: `{registry['registry_version']}`",
        f"- Registry status: `{registry['registry_status']}`",
        f"- Current phase: `{registry['current_phase']}`",
        f"- Phase 12.5 closure: `{registry['closed_phase_versions']['phase12_5']}`",
        f"- Phase 13 closure: `{registry['closed_phase_versions']['phase13']}`",
        f"- Total rows: `{totals['total_rows']}`",
        "",
        "## Derived origin-phase totals", "",
        *count_lines(totals["origin_phase"]),
        "",
        "## Derived status totals", "",
        *count_lines(totals["status"]),
        "",
        "## Derived feature-family totals", "",
        *count_lines(totals["feature_family"]),
        "",
        "## Derived CI-family totals", "",
        *count_lines(totals["ci_family"]),
        "",
        "## Derived route-owner totals", "",
        *count_lines(totals["route_owner"]),
        "",
        "## Derived deferred-destination totals", "",
        *count_lines(totals["deferred_destination"]),
        "",
        *closure_summary_lines(registry),
        *phase13_closure_summary_lines(registry),
        *phase14_opening_summary_lines(registry),
        *phase14_layout_authority_summary_lines(registry),
        "## Registry entries", "",
        "| ID | Origin | Parent | Feature family | CI family | Status | Route owner | Worker owner | Diagnostic owner | Source fixture | Canonical MIR fixture | Differential case | Future phase | Deferral reason | Closure version |",
        "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    fields = (
        "id", "origin_phase", "parent", "feature_family", "ci_family", "status",
        "route_owner", "worker_capability_owner", "diagnostic_owner",
        "source_fixture", "canonical_mir_fixture", "differential_case_id",
        "future_destination_phase", "deferral_reason", "closure_version",
    )
    for entry in entries:
        lines.append("| " + " | ".join(cell(entry[field]) for field in fields) + " |")
    lines += [
        "", "## Legacy views", "",
        f"- Phase 11 historical view: `{registry['legacy_views']['phase11']}`",
        f"- Phase 13 historical view: `{registry['legacy_views']['phase13']}`",
        f"- Phase 14 opening review: `{registry['legacy_views']['phase14']}`",
        f"- Phase 14 layout authority review: `{phase14_layout_authority_summary_path(registry).relative_to(ROOT)}`", "",
        "The JSON registry is authoritative. Generated Markdown is a review artifact, and the legacy Markdown documents remain historical views only.", "",
    ]
    return "\n".join(lines)


def check_rendered_projection(path, rendered, label):
    require(path.is_file(), f"missing {label}: {path.relative_to(ROOT)}")
    with tempfile.TemporaryDirectory(
        prefix="cranelift-registry-projection-"
    ) as temp_dir:
        candidate = Path(temp_dir) / path.name
        candidate.write_text(rendered, encoding="utf-8")
        require(
            path.read_text(encoding="utf-8")
            == candidate.read_text(encoding="utf-8"),
            f"{label} is stale; run "
            "`python3 scripts/cranelift_registry.py project`",
        )


def check_phase13_projection(registry):
    check_rendered_projection(
        phase13_summary_path(registry),
        render_phase13(registry),
        "generated Phase 13 final review",
    )


def check_phase14_projection(registry):
    check_rendered_projection(
        phase14_summary_path(registry),
        render_phase14(registry),
        "generated Phase 14 opening review",
    )


def check_phase14_layout_authority_projection(registry):
    check_rendered_projection(
        phase14_layout_authority_summary_path(registry),
        render_phase14_layout_authority(registry),
        "generated Phase 14 layout authority review",
    )


def check_projection(registry):
    check_rendered_projection(
        summary_path(registry),
        render(registry),
        "generated canonical registry summary",
    )
    check_phase13_projection(registry)
    check_phase14_projection(registry)
    check_phase14_layout_authority_projection(registry)


def summary_path(registry):
    return ROOT / registry["legacy_views"]["generated_summary"]


def phase13_summary_path(registry):
    return ROOT / registry["legacy_views"]["phase13"]


def phase14_summary_path(registry):
    return ROOT / registry["legacy_views"]["phase14"]


def phase14_layout_authority_summary_path(registry):
    return ROOT / "compiler/CRANELIFT_PHASE14_LAYOUT_AUTHORITY.md"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=(
            "validate",
            "verify-legacy-import",
            "verify-phase11-closure",
            "verify-phase13-schema",
            "verify-phase13-capability-contract",
            "verify-phase13-scalar-expression-contract",
            "verify-phase13-multiple-locals-contract",
            "verify-phase13-nested-structured-cfg-contract",
            "verify-phase13-general-loop-contract",
            "verify-phase13-parameter-argument-contract",
            "verify-phase13-direct-call-graph-contract",
            "verify-phase13-broader-runtime-call-contract",
            "verify-phase13-source-metadata-contract",
            "verify-phase13-composition-differential-contract",
            "verify-phase13-deferred-residue-audit",
            "verify-phase13-closure",
            "verify-phase13-opening-rebase",
            "verify-phase13-parent-traceability",
            "verify-phase13-opening-totals",
            "verify-phase14-opening-contract",
            "verify-phase14-layout-authority",
            "project",
            "check-phase13-projection",
            "check-phase14-projection",
            "check-phase14-layout-authority-projection",
            "check-projection",
        ),
    )
    command = parser.parse_args().command
    try:
        registry = validate()
        if command == "verify-legacy-import":
            verify_legacy_import(registry)
        elif command == "verify-phase11-closure":
            verify_phase11_closure(registry)
        elif command == "verify-phase13-schema":
            verify_phase13_registry_schema(registry)
        elif command == "verify-phase13-capability-contract":
            verify_phase13_capability_contract(registry)
        elif command == "verify-phase13-scalar-expression-contract":
            verify_phase13_scalar_expression_contract(registry)
        elif command == "verify-phase13-multiple-locals-contract":
            verify_phase13_multiple_locals_contract(registry)
        elif command == "verify-phase13-nested-structured-cfg-contract":
            verify_phase13_nested_structured_cfg_contract(registry)
        elif command == "verify-phase13-general-loop-contract":
            verify_phase13_general_loop_contract(registry)
        elif command == "verify-phase13-parameter-argument-contract":
            verify_phase13_parameter_argument_contract(registry)
        elif command == "verify-phase13-direct-call-graph-contract":
            verify_phase13_direct_call_graph_contract(registry)
        elif command == "verify-phase13-broader-runtime-call-contract":
            verify_phase13_broader_runtime_call_contract(registry)
        elif command == "verify-phase13-source-metadata-contract":
            verify_phase13_source_metadata_contract(registry)
        elif command == "verify-phase13-composition-differential-contract":
            verify_phase13_composition_differential_contract(registry)
        elif command == "verify-phase13-deferred-residue-audit":
            verify_phase13_deferred_residue_audit(registry)
        elif command == "verify-phase13-closure":
            verify_phase13_closure(registry)
        elif command == "verify-phase13-opening-rebase":
            verify_phase13_opening_rebase(registry)
        elif command == "verify-phase13-parent-traceability":
            verify_phase13_parent_traceability(registry)
        elif command == "verify-phase13-opening-totals":
            verify_phase13_opening_totals(registry)
        elif command == "verify-phase14-opening-contract":
            verify_phase14_opening_contract(registry)
        elif command == "verify-phase14-layout-authority":
            verify_phase14_layout_authority(registry)
        elif command == "project":
            canonical_path = summary_path(registry)
            phase13_path = phase13_summary_path(registry)
            phase14_path = phase14_summary_path(registry)
            phase14_layout_path = phase14_layout_authority_summary_path(registry)
            canonical_path.parent.mkdir(parents=True, exist_ok=True)
            phase13_path.parent.mkdir(parents=True, exist_ok=True)
            phase14_path.parent.mkdir(parents=True, exist_ok=True)
            phase14_layout_path.parent.mkdir(parents=True, exist_ok=True)
            canonical_path.write_text(render(registry), encoding="utf-8")
            phase13_path.write_text(render_phase13(registry), encoding="utf-8")
            phase14_path.write_text(render_phase14(registry), encoding="utf-8")
            phase14_layout_path.write_text(render_phase14_layout_authority(registry), encoding="utf-8")
        elif command == "check-phase13-projection":
            check_phase13_projection(registry)
        elif command == "check-phase14-projection":
            check_phase14_projection(registry)
        elif command == "check-phase14-layout-authority-projection":
            check_phase14_layout_authority_projection(registry)
        elif command == "check-projection":
            check_projection(registry)
    except Error as exc:
        print(f"cranelift registry error: {exc}", file=sys.stderr)
        return 1

    totals = derived_totals(registry)
    snapshot = registry["closure_snapshots"]["phase11"]
    classifications = snapshot["classification_counts"]
    phase13_totals = verify_phase13_opening_totals(registry)
    phase13_contract = verify_phase13_capability_contract(registry)
    scalar_contract = verify_phase13_scalar_expression_contract(registry)
    local_state_contract = verify_phase13_multiple_locals_contract(registry)
    cfg_contract = verify_phase13_nested_structured_cfg_contract(registry)
    loop_contract = verify_phase13_general_loop_contract(registry)
    parameter_contract = verify_phase13_parameter_argument_contract(registry)
    graph_contract = verify_phase13_direct_call_graph_contract(registry)
    runtime_contract = verify_phase13_broader_runtime_call_contract(registry)
    metadata_contract = verify_phase13_source_metadata_contract(registry)
    composition_contract = verify_phase13_composition_differential_contract(registry)
    residue_contract = verify_phase13_deferred_residue_audit(registry)
    closure_contract = verify_phase13_closure(registry)
    phase14_contract = verify_phase14_opening_contract(registry)
    phase14_layout_contract = verify_phase14_layout_authority(registry)
    phase13_statuses = phase13_totals["status_counts"]
    phase13_parents = phase13_totals["parent_kinds"]
    messages = {
        "validate": (
            "✅ Canonical Cranelift registry schema passed: "
            f"{totals['total_rows']} unique entries."
        ),
        "verify-legacy-import": (
            "✅ Canonical registry preserves the historical Phase 11 import; "
            "Phase 13 is registry-owned and generated."
        ),
        "verify-phase11-closure": (
            "✅ Phase 11 semantic closure snapshot passed: "
            f"{snapshot['entry_count']} rows, "
            f"{classifications['migrated']} migrated, "
            f"{classifications['deferred']} deferred, "
            f"{classifications['excluded']} excluded."
        ),
        "verify-phase13-schema": (
            "✅ Phase 13 opening registry schema passed: "
            f"{phase13_totals['row_count']} structurally owned rows."
        ),
        "verify-phase13-capability-contract": (
            "✅ Phase 13 capability contract passed: "
            f"{phase13_contract['row_count']} rows use "
            f"{phase13_contract['capability_id']} with decisions "
            f"supported={phase13_contract['decision_counts']['supported']}, "
            f"deferred={phase13_contract['decision_counts']['deferred']}, "
            "source_or_type_failure="
            f"{phase13_contract['decision_counts']['source_or_type_failure']}."
        ),
        "verify-phase13-scalar-expression-contract": (
            "✅ Phase 13 scalar-expression registry contract passed: "
            f"{scalar_contract['entry_id']} owns "
            f"{','.join(scalar_contract['selected_operations'])} with "
            f"{scalar_contract['focused_fixture_count']} focused and "
            f"{scalar_contract['negative_fixture_count']} negative fixtures."
        ),
        "verify-phase13-multiple-locals-contract": (
            "✅ Phase 13 multiple-locals registry contract passed: "
            f"{local_state_contract['entry_id']} owns "
            f"{','.join(local_state_contract['selected_operations'])} with "
            f"{local_state_contract['focused_fixture_count']} focused, "
            f"{local_state_contract['negative_fixture_count']} source-negative, "
            f"and {local_state_contract['malformed_fixture_count']} malformed MIR fixtures."
        ),
        "verify-phase13-nested-structured-cfg-contract": (
            "✅ Phase 13 nested structured-CFG registry contract passed: "
            f"{cfg_contract['entry_id']} owns "
            f"{','.join(cfg_contract['selected_shapes'])} with "
            f"{cfg_contract['focused_fixture_count']} focused, "
            f"{cfg_contract['malformed_fixture_count']} malformed MIR, and "
            f"{cfg_contract['deferred_fixture_count']} deferred fixtures."
        ),
        "verify-phase13-general-loop-contract": (
            "✅ Phase 13 general-loop registry contract passed: "
            f"{loop_contract['entry_id']} owns "
            f"{','.join(loop_contract['selected_shapes'])} with "
            f"{loop_contract['focused_fixture_count']} focused, "
            f"{loop_contract['malformed_fixture_count']} malformed MIR, "
            f"{loop_contract['invalid_fixture_count']} invalid source, and "
            f"{loop_contract['deferred_fixture_count']} deferred fixtures."
        ),
        "verify-phase13-parameter-argument-contract": (
            "✅ Phase 13 parameter/argument registry contract passed: "
            f"{parameter_contract['entry_id']} owns "
            f"{','.join(parameter_contract['selected_shapes'])} with "
            f"{parameter_contract['focused_fixture_count']} focused, "
            f"{parameter_contract['malformed_fixture_count']} malformed MIR, "
            f"{parameter_contract['invalid_fixture_count']} invalid source, and "
            f"{parameter_contract['deferred_fixture_count']} deferred fixtures."
        ),
        "verify-phase13-direct-call-graph-contract": (
            "✅ Phase 13 direct-call graph registry contract passed: "
            f"{graph_contract['entry_id']} owns "
            f"{','.join(graph_contract['selected_shapes'])} with "
            f"{graph_contract['focused_fixture_count']} focused, "
            f"{graph_contract['malformed_fixture_count']} malformed MIR, "
            f"{graph_contract['deferred_fixture_count']} runtime-deferred fixtures, and "
            f"{graph_contract['policy_row_count']} explicit unsupported-form policy rows."
        ),
        "verify-phase13-broader-runtime-call-contract": (
            "✅ Phase 13 broader imported/runtime-call registry contract passed: "
            f"{runtime_contract['entry_id']} owns "
            f"{runtime_contract['approved_symbol_count']} approved symbols, "
            f"{runtime_contract['focused_fixture_count']} focused fixtures, "
            f"{runtime_contract['negative_fixture_count']} negative fixtures, and "
            f"{len(runtime_contract['unsupported_forms'])} narrowly deferred ABI forms."
        ),
        "verify-phase13-source-metadata-contract": (
            "✅ Phase 13 source metadata registry contract passed: "
            f"{len(metadata_contract['entry_ids'])} metadata rows cover "
            f"{metadata_contract['source_route_count']} generic source routes and "
            f"{metadata_contract['malformed_fixture_count']} malformed fixtures."
        ),
        "verify-phase13-composition-differential-contract": (
            "✅ Phase 13 composition differential registry contract passed: "
            f"{composition_contract['individual_case_count']} individual and "
            f"{composition_contract['composition_case_count']} composition cases "
            f"cover {composition_contract['family_count']} registry-derived families."
        ),
        "verify-phase13-deferred-residue-audit": (
            "✅ Phase 13 deferred residue audit passed: "
            f"{residue_contract['phase13_row_count']} audited rows finish as "
            f"{residue_contract['disposition_counts']['migrated']} migrated, "
            f"{residue_contract['disposition_counts']['replaced']} replaced, and "
            f"{residue_contract['disposition_counts']['excluded']} excluded; "
            f"{residue_contract['residual_row_count']} concrete future capabilities are frozen."
        ),
        "verify-phase13-closure": (
            "✅ Phase 13 scoped closure passed: "
            f"{closure_contract['opening_entry_count']} opening rows close as "
            f"{closure_contract['disposition_counts']['migrated']} migrated, "
            f"{closure_contract['disposition_counts']['replaced']} replaced, and "
            f"{closure_contract['disposition_counts']['excluded']} excluded; "
            f"{closure_contract['residual_entry_count']} concrete residual capabilities remain."
        ),
        "verify-phase13-opening-rebase": (
            "✅ Phase 13 opening rebase passed: stable IDs and parent "
            "relationships still match the semantic opening snapshot."
        ),
        "verify-phase13-parent-traceability": (
            "✅ Phase 13 parent traceability passed: "
            f"{phase13_parents['phase11_entry']} entry parents and "
            f"{phase13_parents['phase11_category']} category parents."
        ),
        "verify-phase13-opening-totals": (
            "✅ Phase 13 opening totals reconcile from registry rows: "
            f"{phase13_totals['row_count']} total, "
            f"{phase13_statuses['inherited_deferred']} inherited, "
            f"{phase13_statuses['candidate_deferred']} candidate."
        ),
        "verify-phase14-layout-authority": (
            "✅ Phase 14 compiler-owned layout authority passed: "
            f"{phase14_layout_contract['semantic_type_count']} semantic records, "
            f"{phase14_layout_contract['query_count']} queries, "
            f"{phase14_layout_contract['consumer_count']} consumers, and "
            f"{phase14_layout_contract['rejection_count']} request rejection classes; "
            f"all {phase14_layout_contract['opening_row_count']} opening rows remain deferred."
        ),
        "verify-phase14-opening-contract": (
            "✅ Phase 14 opening contract passed: "
            f"{phase14_contract['row_count']} rows across "
            f"{len(phase14_contract['ci_counts'])} registry-derived planned "
            "CI families; every frozen Phase 13 residual is selected, split, "
            "or explicitly reassigned."
        ),
        "project": (
            "✅ Canonical Cranelift registry, Phase 13 final review, Phase 14 "
            "opening review, and Phase 14 layout authority review generated."
        ),
        "check-phase13-projection": (
            "✅ Phase 13 generated final review matches the registry."
        ),
        "check-phase14-projection": (
            "✅ Phase 14 generated opening review matches the registry."
        ),
        "check-phase14-layout-authority-projection": (
            "✅ Phase 14 generated layout authority review matches the registry."
        ),
        "check-projection": (
            "✅ Canonical Cranelift registry, Phase 13 final review, Phase 14 "
            "opening review, and Phase 14 layout authority review match their committed artifacts."
        ),
    }
    print(messages[command])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
