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
    "opening_snapshots", "phase14_layout_authority",
    "phase14_primitive_layout", "phase14_integer_conversions",
    "phase14_pointers", "phase14_stack_slots", "phase14_memory_accesses",
    "phase14_string_views", "residual_snapshots",
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
    "none_supported",
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
PHASE14_LAYOUT_AUTHORITY_STATUS = "consumed_by_patch14_7"
PHASE14_LAYOUT_TABLE_FORMAT = "gust.compiler_layout_table.v2"
PHASE14_LAYOUT_TYPES = (
    "MirTargetLayout", "MirTypeLayout", "MirFieldLayout",
    "MirVariantLayout", "MirElementStrideQuery", "MirMemoryAccessLayout",
    "MirScalarValueValidation",
)
PHASE14_LAYOUT_QUERIES = (
    "mir_layout_of", "mir_layout_field_layout",
    "mir_layout_variant_layout", "mir_layout_element_stride",
    "mir_layout_validate_memory_access", "mir_layout_validate_scalar_value",
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
    "authority_transport_primitive_layout_integer_conversion_bounded_pointer_"
    "stack_slot_typed_memory_access_and_literal_backed_string_view_consumption_"
    "no_dynamic_owning_string_array_struct_enum_or_aggregate_abi_migration"
)

PHASE14_PRIMITIVE_FIELDS = {
    "version", "status", "authority_owner", "layout_table_format",
    "normalization_policy", "primary_level2_target", "declared_targets",
    "primitive_types", "canonical_boolean_values", "migrated_entry_ids",
    "focused_ci_family", "level1_guard", "level2_guard",
    "witness_policy", "negative_classes", "boundary_policy", "next_patch",
}
PHASE14_DECLARED_TARGET_FIELDS = {
    "target_id", "target_triple", "aliases", "object_format",
    "endianness", "pointer_size", "pointer_alignment", "i32_alignment",
    "i64_alignment", "max_aggregate_alignment",
}
PHASE14_PRIMITIVE_TYPE_FIELDS = {
    "type_id", "source_name", "representation_kind", "size_policy",
    "alignment_policy", "bit_width_policy", "signedness", "validity_kind",
}
PHASE14_PRIMITIVE_VERSION = "phase14_declared_targets_and_primitive_layout_v1"
PHASE14_PRIMITIVE_STATUS = "consumed_by_patch14_4"
PHASE14_PRIMITIVE_MIGRATED_IDS = (
    "p14_primitive_scalar_layout",
    "p14_pointer_sized_integer_layout",
    "p14_target_layout_model",
    "p14_all_target_layout_evidence",
)
PHASE14_PRIMITIVE_TYPE_IDS = (
    "type:gust:bool", "type:gust:i32", "type:gust:u32",
    "type:gust:i64", "type:gust:u64", "type:gust:isize", "type:gust:usize",
)
PHASE14_PRIMITIVE_NEGATIVE_CLASSES = (
    "unknown_target", "unsupported_target", "width_mismatch",
    "alignment_mismatch", "invalid_boolean_value",
    "request_target_layout_disagreement",
)

PHASE14_CONVERSION_FIELDS = {
    "version", "status", "authority_owner", "conversion_table_format",
    "source_conversion_forms", "conversion_kinds", "selected_rules",
    "constant_folding_policy", "runtime_policy", "out_of_range_policy",
    "negative_to_unsigned_policy", "unsigned_to_signed_policy",
    "pointer_sized_policy", "diagnostic_fields", "migrated_entry_ids",
    "focused_ci_family", "level1_guard", "level2_guard",
    "composition_contexts", "negative_classes", "boundary_policy",
    "next_patch",
}
PHASE14_CONVERSION_RULE_FIELDS = {
    "rule_name", "conversion_kind", "source_type_id",
    "destination_type_id", "source_width_policy",
    "destination_width_policy", "source_signedness",
    "destination_signedness", "policy", "success_reason_code",
    "failure_reason_code", "target_applicability",
}
PHASE14_CONVERSION_VERSION = (
    "phase14_signed_unsigned_width_conversion_rules_v1"
)
PHASE14_CONVERSION_STATUS = "consumed_by_patch14_4"
PHASE14_CONVERSION_TABLE_FORMAT = (
    "gust.compiler_integer_conversion_table.v1"
)
PHASE14_CONVERSION_MIGRATED_IDS = (
    "p14_target_dependent_conversions",
)
PHASE14_CONVERSION_SOURCE_FORMS = (
    "explicit_checked_numeric_conversion",
    "explicit_wrapping_numeric_conversion",
    "explicit_truncate_low_bits",
    "explicit_same_width_bit_reinterpretation",
    "explicit_boolean_numeric_conversion",
    "implicit_numeric_conversion_rejected",
)
PHASE14_CONVERSION_KINDS = (
    "sign_extend", "zero_extend", "truncate", "checked_numeric",
    "wrapping_numeric", "bit_reinterpret", "bool_to_integer",
    "integer_to_bool",
)
PHASE14_CONVERSION_RULE_NAMES = (
    "sign_extend_i32_i64", "zero_extend_u32_u64",
    "truncate_i64_i32", "truncate_u64_u32",
    "checked_i64_i32", "checked_u64_u32",
    "checked_i32_u32", "checked_u32_i32",
    "wrapping_i32_u32", "wrapping_u32_i32",
    "reinterpret_i32_u32", "reinterpret_u32_i32",
    "bool_to_i32", "i32_to_bool", "i32_to_isize",
    "u32_to_usize", "isize_to_i32", "usize_to_u32",
)
PHASE14_CONVERSION_TARGET_SELECTED_KINDS = {
    "target_selected_sign_or_checked",
    "target_selected_zero_or_checked",
}
PHASE14_CONVERSION_DIAGNOSTIC_FIELDS = (
    "source_type", "destination_type", "target", "source_width",
    "destination_width", "conversion_kind", "policy", "reason_code",
)
PHASE14_CONVERSION_CONTEXTS = (
    "comparisons", "locals", "branches", "aggregate_fields",
)
PHASE14_CONVERSION_NEGATIVE_CLASSES = (
    "unsupported_implicit_conversion", "invalid_boolean_conversion",
    "narrowing_without_allowed_policy",
    "pointer_integer_conversion_deferred",
    "target_dependent_conversion_without_declared_target",
    "request_target_conversion_disagreement",
    "conversion_width_mismatch",
)

PHASE14_POINTER_FIELDS = {
    "version", "status", "authority_owner", "pointer_table_format",
    "primary_level2_target", "default_address_space",
    "selected_pointee_type_ids", "mutability_kinds", "nullability_kinds",
    "pointer_type_count_per_target", "operation_kinds",
    "operation_count_per_target", "provenance_fields",
    "known_null_dereference_policy", "nullable_access_policy",
    "worker_layout_policy", "migrated_entry_ids", "focused_ci_family",
    "level1_guard", "level2_guard", "composition_contexts",
    "negative_classes", "boundary_policy", "next_patch",
}
PHASE14_POINTER_VERSION = (
    "phase14_bounded_typed_pointers_and_nullability_v1"
)
PHASE14_POINTER_STATUS = "consumed_by_patch14_7"
PHASE14_POINTER_TABLE_FORMAT = "gust.compiler_pointer_table.v1"
PHASE14_POINTER_MIGRATED_IDS = ("p14_pointer_nullability_model",)
PHASE14_POINTER_OPERATION_KINDS = (
    "address_of_local", "null_pointer", "pointer_equal",
    "pointer_not_equal", "pointer_null_test", "pointer_non_null_test",
    "non_null_to_nullable", "nullable_to_non_null_checked",
)
PHASE14_POINTER_PROVENANCE_FIELDS = (
    "origin_kind", "origin_local_id", "provenance_id",
)
PHASE14_POINTER_CONTEXTS = (
    "locals", "comparisons", "nullable_branches", "aggregate_fields",
)
PHASE14_POINTER_NEGATIVE_CLASSES = (
    "pointer_width_mismatch", "invalid_pointee_layout",
    "invalid_nullability_conversion", "unsupported_address_space",
    "unsupported_pointer_arithmetic", "unrestricted_integer_pointer_cast",
    "unsized_or_unsupported_pointee",
    "dereference_before_load_store_contract", "target_required",
)

PHASE14_STACK_SLOT_FIELDS = {
    "version", "status", "authority_owner", "stack_slot_table_format",
    "primary_level2_target", "storage_classes",
    "selected_slot_count_per_target", "operation_kinds",
    "operation_count_per_target", "metadata_fields", "lifetime_policy",
    "address_escape_policy", "worker_layout_policy", "migrated_entry_ids",
    "focused_ci_family", "level1_guard", "level2_guard",
    "composition_contexts", "negative_classes", "boundary_policy",
    "next_patch",
}
PHASE14_STACK_SLOT_VERSION = (
    "phase14_deterministic_stack_slots_and_addressable_locals_v1"
)
PHASE14_STACK_SLOT_STATUS = "consumed_by_patch14_7"
PHASE14_STACK_SLOT_TABLE_FORMAT = "gust.compiler_stack_slot_table.v1"
PHASE14_STACK_SLOT_MIGRATED_IDS = ("p14_stack_slot_addressable_locals",)
PHASE14_STACK_SLOT_STORAGE_CLASSES = (
    "ssa_only", "addressable_local", "compiler_temporary",
)
PHASE14_STACK_SLOT_OPERATION_KINDS = (
    "declare", "address_of", "initialize", "assign", "read",
    "bounded_aggregate_copy",
)
PHASE14_STACK_SLOT_METADATA_FIELDS = (
    "size", "alignment", "contained_type_id", "contained_layout_id",
    "initialization_state", "source_origin", "lifetime_region",
    "mutability", "address_escape_policy",
)
PHASE14_STACK_SLOT_CONTEXTS = (
    "addressable_scalars", "initial_aggregates", "branches",
    "supported_loops",
)
PHASE14_STACK_SLOT_NEGATIVE_CLASSES = (
    "uninitialized_read", "duplicate_slot", "wrong_slot_type",
    "under_aligned_slot", "invalid_lifetime", "escaping_address",
    "layout_id_mismatch", "dynamic_stack_allocation",
    "variable_sized_slot", "resource_bearing_local",
    "unsupported_aliasing",
)

PHASE14_MEMORY_ACCESS_FIELDS = {
    "version", "status", "authority_owner", "memory_access_table_format",
    "primary_level2_target", "selected_type_ids", "operation_kinds",
    "operation_count_per_target", "metadata_fields",
    "natural_alignment_policy", "unaligned_policy", "zero_sized_policy",
    "known_null_policy", "initialization_policy", "overlap_policy",
    "worker_lowering_policy", "migrated_entry_ids", "focused_ci_family",
    "level1_guard", "level2_guard", "composition_contexts",
    "negative_classes", "poisoned_driver_policy",
    "output_preservation_policy", "boundary_policy", "next_patch",
}
PHASE14_MEMORY_ACCESS_VERSION = "phase14_typed_load_store_memory_access_v1"
PHASE14_MEMORY_ACCESS_STATUS = "consumed_by_patch14_7"
PHASE14_MEMORY_ACCESS_TABLE_FORMAT = "gust.compiler_memory_access_table.v1"
PHASE14_MEMORY_ACCESS_MIGRATED_IDS = ("p14_typed_load_store_memory_access",)
PHASE14_MEMORY_ACCESS_TYPE_IDS = ("type:gust:i32",)
PHASE14_MEMORY_ACCESS_OPERATION_KINDS = (
    "load", "store", "aggregate_copy", "layout_offset",
)
PHASE14_MEMORY_ACCESS_METADATA_FIELDS = (
    "accessed_type_id", "accessed_layout_id", "byte_width",
    "required_alignment", "origin_kind", "origin_id", "origin_slot_id",
    "origin_mutability", "origin_nullability", "lifetime_region",
    "source_file", "source_line", "source_column", "offset_kind",
    "offset_layout_id", "element_index", "source_offset",
    "destination_offset",
)
PHASE14_MEMORY_ACCESS_CONTEXTS = (
    "stack_slot_load_store", "non_null_pointer_load_store",
    "compiler_element_offset", "bounded_nonoverlap_copy",
)
PHASE14_MEMORY_ACCESS_NEGATIVE_CLASSES = (
    "wrong_width", "wrong_alignment", "wrong_pointee_type",
    "immutable_store", "invalid_layout_id", "out_of_lifetime",
    "unsupported_overlap", "known_null", "read_before_write",
    "unaligned", "zero_sized",
)

PHASE14_STRING_VIEW_FIELDS = {
    "version", "status", "authority_owner", "string_view_table_format",
    "primary_level2_target", "source_encoding", "literal_encoding",
    "embedded_nul_policy", "empty_string_policy",
    "semantic_length_authority", "owning_string_policy",
    "view_representation", "view_layout_fields", "lifetime_policy",
    "mutation_policy", "concatenation_policy", "allocation_policy",
    "literal_count_per_target", "view_count_per_target",
    "operation_kinds", "operation_count_per_target", "migrated_entry_ids",
    "focused_ci_family", "level1_guard", "level2_guard",
    "composition_contexts", "negative_classes", "poisoned_driver_policy",
    "output_preservation_policy", "boundary_policy", "next_patch",
}
PHASE14_STRING_VIEW_VERSION = "phase14_string_literals_and_borrowed_views_v1"
PHASE14_STRING_VIEW_STATUS = "ready_for_patch14_8"
PHASE14_STRING_VIEW_TABLE_FORMAT = "gust.compiler_string_view_table.v1"
PHASE14_STRING_VIEW_MIGRATED_IDS = ("p14_string_and_string_view_layout",)
PHASE14_ARRAY_SLICE_VERSION = "phase14_fixed_arrays_and_bounded_slices_v1"
PHASE14_ARRAY_SLICE_MIGRATED_IDS = ("p14_array_and_slice_layout",)
PHASE14_ARRAY_SLICE_OPERATION_KINDS = (
    "array_init", "element_address", "element_load", "element_store",
    "array_to_slice", "slice_length", "bounded_index", "subslice",
)
PHASE14_AGGREGATE_VERSION = "phase14_aggregate_basic_block_transport_v1"
PHASE14_AGGREGATE_MIGRATED_IDS = ("p14_aggregate_basic_block_transport",)
PHASE14_AGGREGATE_CLASSES = (
    "string_view", "slice", "fixed_array", "struct", "enum", "nested",
)
PHASE14_AGGREGATE_OPERATION_KINDS = (
    "block_param_declare", "edge_argument_pass", "join_observe", "loop_carry",
    "early_return",
)
PHASE14_AGGREGATE_NEGATIVE_CLASSES = (
    "join_layout_mismatch", "field_count_mismatch", "variant_mismatch",
    "invalid_lifetime", "use_after_move", "resource_bearing_copy",
)
PHASE14_STRUCT_VERSION = "phase14_declaration_order_struct_layout_v1"
PHASE14_STRUCT_MIGRATED_IDS = ("p14_struct_field_layout",)
PHASE14_STRUCT_OPERATION_KINDS = (
    "construct", "field_address", "field_load", "field_store",
)
PHASE14_STRUCT_NEGATIVE_CLASSES = (
    "duplicate_field", "misaligned_field", "overlapping_fields",
    "wrong_field_type", "size_alignment_mismatch", "unknown_field_path",
)
PHASE14_ENUM_VERSION = "phase14_enums_and_tagged_unions_v1"
PHASE14_ENUM_MIGRATED_IDS = ("p14_enum_tagged_union_layout",)
PHASE14_ENUM_OPERATION_KINDS = (
    "variant_construct", "tag_read", "variant_test", "payload_project",
    "match_branch",
)
PHASE14_ENUM_NEGATIVE_CLASSES = (
    "duplicate_discriminant", "discriminant_out_of_range", "invalid_tag_value",
    "wrong_payload_type", "invalid_payload_projection",
    "inconsistent_variant_layout",
)
PHASE14_STRING_VIEW_LAYOUT_FIELDS = ("data_pointer", "byte_length")
PHASE14_STRING_VIEW_OPERATION_KINDS = (
    "literal_create", "view_create", "length", "is_empty", "byte_at",
    "slice", "byte_equal",
)
PHASE14_STRING_VIEW_CONTEXTS = (
    "static_literal_identity", "pointer_sized_view_layout",
    "embedded_nul_length", "bounded_slice", "byte_comparison",
)
PHASE14_STRING_VIEW_NEGATIVE_CLASSES = (
    "invalid_pointer_length_pair", "lifetime_escape",
    "unsupported_mutation", "unsupported_allocation",
    "unsupported_concatenation", "invalid_encoding",
    "out_of_bounds_view", "null_empty_view", "literal_identity_mismatch",
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
        "Phase 14 layout authority consumption checkpoint drifted",
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
        authority["next_patch"] == "14.8",
        "Phase 14 layout authority next patch must be 14.8",
    )
    return authority


def validate_phase14_primitive_layout_structure(registry):
    contract = registry["phase14_primitive_layout"]
    require(
        isinstance(contract, dict) and set(contract) == PHASE14_PRIMITIVE_FIELDS,
        "Phase 14 primitive layout fields drifted",
    )
    require(
        contract["version"] == PHASE14_PRIMITIVE_VERSION
        and contract["status"] == PHASE14_PRIMITIVE_STATUS,
        "Phase 14 primitive layout checkpoint drifted",
    )
    require(
        contract["authority_owner"] == "compiler/mir_primitive_layout.gst"
        and contract["layout_table_format"] == PHASE14_LAYOUT_TABLE_FORMAT,
        "Phase 14 primitive layout authority or table format drifted",
    )
    require(
        contract["normalization_policy"]
        == "compiler_normalizes_declared_aliases_before_layout_selection_unknown_targets_reject_before_driver_discovery",
        "Phase 14 target normalization policy drifted",
    )
    targets = contract["declared_targets"]
    require(isinstance(targets, list) and targets, "declared targets must be non-empty")
    triples = []
    target_ids = []
    aliases = set()
    for index, target in enumerate(targets):
        context = f"phase14_primitive_layout.declared_targets[{index}]"
        require(
            isinstance(target, dict) and set(target) == PHASE14_DECLARED_TARGET_FIELDS,
            f"{context} fields drifted",
        )
        triple = text(target["target_triple"], f"{context}.target_triple")
        target_id = text(target["target_id"], f"{context}.target_id")
        require(triple not in triples and target_id not in target_ids,
                f"{context}: duplicate target identity")
        triples.append(triple)
        target_ids.append(target_id)
        target_aliases = unique_strings(target["aliases"], f"{context}.aliases")
        require(not (set(target_aliases) & aliases), f"{context}: duplicate target alias")
        aliases.update(target_aliases)
        require(target["endianness"] in {"little", "big"}, f"{context}: invalid endianness")
        for field in (
            "pointer_size", "pointer_alignment", "i32_alignment",
            "i64_alignment", "max_aggregate_alignment",
        ):
            value = target[field]
            require(isinstance(value, int) and value > 0 and value & (value - 1) == 0,
                    f"{context}.{field} must be a positive power of two")
        require(target["object_format"] in {"Elf", "MachO"},
                f"{context}: unsupported object format")
        expected_id = (
            f"target:v1:triple={triple}:endian={target['endianness']}:"
            f"ptr_size={target['pointer_size']}:ptr_align={target['pointer_alignment']}:"
            f"i32_align={target['i32_alignment']}:i64_align={target['i64_alignment']}:"
            f"max_align={target['max_aggregate_alignment']}"
        )
        require(target_id == expected_id, f"{context}: target identity is not semantic")
    require(contract["primary_level2_target"] in triples,
            "primary Level 2 target is not declared")

    primitive_types = contract["primitive_types"]
    require(isinstance(primitive_types, list), "primitive type inventory must be an array")
    require(len(primitive_types) == len(PHASE14_PRIMITIVE_TYPE_IDS),
            "primitive type inventory count drifted")
    type_ids = []
    source_names = []
    for index, primitive in enumerate(primitive_types):
        context = f"phase14_primitive_layout.primitive_types[{index}]"
        require(
            isinstance(primitive, dict)
            and set(primitive) == PHASE14_PRIMITIVE_TYPE_FIELDS,
            f"{context} fields drifted",
        )
        type_id = text(primitive["type_id"], f"{context}.type_id")
        source_name = text(primitive["source_name"], f"{context}.source_name")
        require(type_id not in type_ids and source_name not in source_names,
                f"{context}: duplicate primitive type")
        type_ids.append(type_id)
        source_names.append(source_name)
        require(primitive["signedness"] in {"not_applicable", "signed", "unsigned"},
                f"{context}: invalid signedness")
        require(primitive["validity_kind"] in {"canonical_bool_0_or_1", "any_bit_pattern"},
                f"{context}: invalid validity kind")
    require(tuple(type_ids) == PHASE14_PRIMITIVE_TYPE_IDS,
            "primitive type identity order drifted")
    require(contract["canonical_boolean_values"] == [0, 1],
            "canonical boolean values must be exactly 0 and 1")
    require(tuple(contract["migrated_entry_ids"]) == PHASE14_PRIMITIVE_MIGRATED_IDS,
            "Phase 14 primitive migrated row inventory drifted")
    require(contract["focused_ci_family"] == "primitive-layout",
            "Phase 14 primitive CI family drifted")
    require(contract["level1_guard"] == "guard-cranelift-phase14-target-and-primitive-contract",
            "Phase 14 primitive Level 1 guard drifted")
    require(contract["level2_guard"] == "guard-cranelift-phase14-primitive-layout-parity",
            "Phase 14 primitive Level 2 guard drifted")
    require(contract["negative_classes"] == list(PHASE14_PRIMITIVE_NEGATIVE_CLASSES),
            "Phase 14 primitive negative inventory drifted")
    require(
        contract["boundary_policy"]
        == "primitive_representation_integer_conversion_and_bounded_pointer_metadata_active_no_load_store_string_array_struct_enum_or_aggregate_abi_migration",
        "Phase 14 primitive boundary policy drifted",
    )
    require(contract["next_patch"] == "14.5",
            "Phase 14 primitive next patch must be 14.5")
    return contract


def validate_phase14_integer_conversion_structure(registry):
    contract = registry["phase14_integer_conversions"]
    require(
        isinstance(contract, dict) and set(contract) == PHASE14_CONVERSION_FIELDS,
        "Phase 14 integer conversion fields drifted",
    )
    require(
        contract["version"] == PHASE14_CONVERSION_VERSION
        and contract["status"] == PHASE14_CONVERSION_STATUS,
        "Phase 14 integer conversion checkpoint drifted",
    )
    require(
        contract["authority_owner"] == "compiler/mir_integer_conversion.gst"
        and contract["conversion_table_format"] == PHASE14_CONVERSION_TABLE_FORMAT,
        "Phase 14 integer conversion authority or table format drifted",
    )
    require(
        tuple(contract["source_conversion_forms"])
        == PHASE14_CONVERSION_SOURCE_FORMS,
        "Phase 14 source conversion form inventory drifted",
    )
    require(
        tuple(contract["conversion_kinds"]) == PHASE14_CONVERSION_KINDS,
        "Phase 14 canonical conversion kind inventory drifted",
    )
    rules = contract["selected_rules"]
    require(
        isinstance(rules, list) and len(rules) == len(PHASE14_CONVERSION_RULE_NAMES),
        "Phase 14 selected conversion rule count drifted",
    )
    names = []
    semantic_pairs = set()
    for index, rule in enumerate(rules):
        context = f"phase14_integer_conversions.selected_rules[{index}]"
        require(
            isinstance(rule, dict)
            and set(rule) == PHASE14_CONVERSION_RULE_FIELDS,
            f"{context} fields drifted",
        )
        name = text(rule["rule_name"], f"{context}.rule_name")
        require(name not in names, f"{context}: duplicate rule name")
        names.append(name)
        source_type = text(rule["source_type_id"], f"{context}.source_type_id")
        destination_type = text(
            rule["destination_type_id"], f"{context}.destination_type_id"
        )
        require(
            source_type in PHASE14_PRIMITIVE_TYPE_IDS
            and destination_type in PHASE14_PRIMITIVE_TYPE_IDS,
            f"{context}: conversion rule references an undeclared primitive type",
        )
        key = (name, source_type, destination_type)
        require(key not in semantic_pairs, f"{context}: duplicate semantic rule")
        semantic_pairs.add(key)
        kind = text(rule["conversion_kind"], f"{context}.conversion_kind")
        require(
            kind in PHASE14_CONVERSION_KINDS
            or kind in PHASE14_CONVERSION_TARGET_SELECTED_KINDS,
            f"{context}: unsupported conversion kind {kind}",
        )
        require(
            rule["source_signedness"] in {"signed", "unsigned", "not_applicable"}
            and rule["destination_signedness"]
            in {"signed", "unsigned", "not_applicable"},
            f"{context}: invalid signedness",
        )
        for field in (
            "source_width_policy", "destination_width_policy", "policy",
            "success_reason_code", "failure_reason_code",
            "target_applicability",
        ):
            text(rule[field], f"{context}.{field}")
    require(
        tuple(names) == PHASE14_CONVERSION_RULE_NAMES,
        "Phase 14 selected conversion rule identity order drifted",
    )
    for field in (
        "constant_folding_policy", "runtime_policy", "out_of_range_policy",
        "negative_to_unsigned_policy", "unsigned_to_signed_policy",
        "pointer_sized_policy", "boundary_policy",
    ):
        text(contract[field], f"phase14_integer_conversions.{field}")
    require(
        tuple(contract["diagnostic_fields"])
        == PHASE14_CONVERSION_DIAGNOSTIC_FIELDS,
        "Phase 14 integer conversion diagnostic fields drifted",
    )
    require(
        tuple(contract["migrated_entry_ids"])
        == PHASE14_CONVERSION_MIGRATED_IDS,
        "Phase 14 integer conversion migrated-row inventory drifted",
    )
    require(
        contract["focused_ci_family"] == "conversions"
        and contract["level1_guard"]
        == "guard-cranelift-phase14-integer-conversion-contract"
        and contract["level2_guard"]
        == "guard-cranelift-phase14-integer-conversion-parity",
        "Phase 14 integer conversion CI ownership drifted",
    )
    require(
        tuple(contract["composition_contexts"]) == PHASE14_CONVERSION_CONTEXTS,
        "Phase 14 integer conversion composition context inventory drifted",
    )
    require(
        tuple(contract["negative_classes"])
        == PHASE14_CONVERSION_NEGATIVE_CLASSES,
        "Phase 14 integer conversion negative inventory drifted",
    )
    require(
        contract["boundary_policy"]
        == "bounded_pointer_policy_is_active_but_unrestricted_pointer_integer_conversion_and_floating_point_conversion_remain_outside_patch",
        "Phase 14 integer conversion boundary drifted",
    )
    require(contract["next_patch"] == "14.5",
            "Phase 14 integer conversion next patch must be 14.5")
    return contract


def validate_phase14_pointer_structure(registry):
    contract = registry["phase14_pointers"]
    require(
        isinstance(contract, dict) and set(contract) == PHASE14_POINTER_FIELDS,
        "Phase 14 pointer contract fields drifted",
    )
    require(
        contract["version"] == PHASE14_POINTER_VERSION
        and contract["status"] == PHASE14_POINTER_STATUS,
        "Phase 14 pointer checkpoint drifted",
    )
    require(
        contract["authority_owner"] == "compiler/mir_pointer.gst"
        and contract["pointer_table_format"] == PHASE14_POINTER_TABLE_FORMAT,
        "Phase 14 pointer authority or table format drifted",
    )
    require(
        contract["primary_level2_target"] == "x86_64-unknown-linux-gnu"
        and contract["default_address_space"] == "default",
        "Phase 14 pointer target or address-space policy drifted",
    )
    require(
        contract["selected_pointee_type_ids"] == ["type:gust:i32"]
        and contract["mutability_kinds"] == ["const", "mutable"]
        and contract["nullability_kinds"] == ["non_null", "nullable"]
        and contract["pointer_type_count_per_target"] == 4,
        "Phase 14 pointer type inventory drifted",
    )
    require(
        tuple(contract["operation_kinds"]) == PHASE14_POINTER_OPERATION_KINDS
        and contract["operation_count_per_target"] == 11,
        "Phase 14 pointer operation inventory drifted",
    )
    require(
        tuple(contract["provenance_fields"]) == PHASE14_POINTER_PROVENANCE_FIELDS,
        "Phase 14 pointer provenance fields drifted",
    )
    for field in (
        "known_null_dereference_policy", "nullable_access_policy",
        "worker_layout_policy", "boundary_policy",
    ):
        text(contract[field], f"phase14_pointers.{field}")
    require(
        tuple(contract["migrated_entry_ids"]) == PHASE14_POINTER_MIGRATED_IDS,
        "Phase 14 pointer migrated-row inventory drifted",
    )
    require(
        contract["focused_ci_family"] == "pointer-memory"
        and contract["level1_guard"] == "guard-cranelift-phase14-pointer-contract"
        and contract["level2_guard"] == "guard-cranelift-phase14-pointer-parity",
        "Phase 14 pointer CI ownership drifted",
    )
    require(
        tuple(contract["composition_contexts"]) == PHASE14_POINTER_CONTEXTS,
        "Phase 14 pointer composition context inventory drifted",
    )
    require(
        tuple(contract["negative_classes"]) == PHASE14_POINTER_NEGATIVE_CLASSES,
        "Phase 14 pointer negative inventory drifted",
    )
    require(contract["next_patch"] == "14.8",
            "Phase 14 pointer next patch must be 14.8")
    return contract


def validate_phase14_stack_slot_structure(registry):
    contract = registry["phase14_stack_slots"]
    require(
        isinstance(contract, dict) and set(contract) == PHASE14_STACK_SLOT_FIELDS,
        "Phase 14 stack-slot contract fields drifted",
    )
    require(
        contract["version"] == PHASE14_STACK_SLOT_VERSION
        and contract["status"] == PHASE14_STACK_SLOT_STATUS,
        "Phase 14 stack-slot checkpoint drifted",
    )
    require(
        contract["authority_owner"] == "compiler/mir_stack_slot.gst"
        and contract["stack_slot_table_format"] == PHASE14_STACK_SLOT_TABLE_FORMAT,
        "Phase 14 stack-slot authority or table format drifted",
    )
    require(
        contract["primary_level2_target"] == "x86_64-unknown-linux-gnu"
        and tuple(contract["storage_classes"]) == PHASE14_STACK_SLOT_STORAGE_CLASSES
        and contract["selected_slot_count_per_target"] == 4,
        "Phase 14 stack-slot storage inventory drifted",
    )
    require(
        tuple(contract["operation_kinds"]) == PHASE14_STACK_SLOT_OPERATION_KINDS
        and contract["operation_count_per_target"] == 11,
        "Phase 14 stack-slot operation inventory drifted",
    )
    require(
        tuple(contract["metadata_fields"]) == PHASE14_STACK_SLOT_METADATA_FIELDS,
        "Phase 14 stack-slot metadata inventory drifted",
    )
    require(
        contract["lifetime_policy"] == "lexical_function_region"
        and contract["address_escape_policy"]
        == "no_escape_outside_declared_lifetime",
        "Phase 14 stack-slot lifetime or escape policy drifted",
    )
    text(contract["worker_layout_policy"], "phase14_stack_slots.worker_layout_policy")
    require(
        tuple(contract["migrated_entry_ids"]) == PHASE14_STACK_SLOT_MIGRATED_IDS,
        "Phase 14 stack-slot migrated-row inventory drifted",
    )
    require(
        contract["focused_ci_family"] == "pointer-memory"
        and contract["level1_guard"] == "guard-cranelift-phase14-stack-slot-contract"
        and contract["level2_guard"] == "guard-cranelift-phase14-stack-slot-parity",
        "Phase 14 stack-slot CI ownership drifted",
    )
    require(
        tuple(contract["composition_contexts"]) == PHASE14_STACK_SLOT_CONTEXTS
        and tuple(contract["negative_classes"]) == PHASE14_STACK_SLOT_NEGATIVE_CLASSES,
        "Phase 14 stack-slot composition or negative inventory drifted",
    )
    text(contract["boundary_policy"], "phase14_stack_slots.boundary_policy")
    require(contract["next_patch"] == "14.8",
            "Phase 14 stack-slot next patch must be 14.8")
    return contract


def validate_phase14_memory_access_structure(registry):
    contract = registry["phase14_memory_accesses"]
    require(
        isinstance(contract, dict) and set(contract) == PHASE14_MEMORY_ACCESS_FIELDS,
        "Phase 14 memory-access contract fields drifted",
    )
    require(
        contract["version"] == PHASE14_MEMORY_ACCESS_VERSION
        and contract["status"] == PHASE14_MEMORY_ACCESS_STATUS,
        "Phase 14 memory-access checkpoint drifted",
    )
    require(
        contract["authority_owner"] == "compiler/mir_memory_access.gst"
        and contract["memory_access_table_format"]
        == PHASE14_MEMORY_ACCESS_TABLE_FORMAT,
        "Phase 14 memory-access authority or table format drifted",
    )
    require(
        contract["primary_level2_target"] == "x86_64-unknown-linux-gnu"
        and tuple(contract["selected_type_ids"])
        == PHASE14_MEMORY_ACCESS_TYPE_IDS,
        "Phase 14 memory-access target or type inventory drifted",
    )
    require(
        tuple(contract["operation_kinds"])
        == PHASE14_MEMORY_ACCESS_OPERATION_KINDS
        and contract["operation_count_per_target"] == 6,
        "Phase 14 memory-access operation inventory drifted",
    )
    require(
        tuple(contract["metadata_fields"])
        == PHASE14_MEMORY_ACCESS_METADATA_FIELDS,
        "Phase 14 memory-access metadata inventory drifted",
    )
    for field in (
        "natural_alignment_policy", "unaligned_policy",
        "zero_sized_policy", "known_null_policy",
        "initialization_policy", "overlap_policy",
        "worker_lowering_policy", "poisoned_driver_policy",
        "output_preservation_policy", "boundary_policy",
    ):
        text(contract[field], f"phase14_memory_accesses.{field}")
    require(
        tuple(contract["migrated_entry_ids"])
        == PHASE14_MEMORY_ACCESS_MIGRATED_IDS,
        "Phase 14 memory-access migrated-row inventory drifted",
    )
    require(
        contract["focused_ci_family"] == "pointer-memory"
        and contract["level1_guard"]
        == "guard-cranelift-phase14-memory-access-contract"
        and contract["level2_guard"]
        == "guard-cranelift-phase14-memory-access-parity",
        "Phase 14 memory-access CI ownership drifted",
    )
    require(
        tuple(contract["composition_contexts"])
        == PHASE14_MEMORY_ACCESS_CONTEXTS
        and tuple(contract["negative_classes"])
        == PHASE14_MEMORY_ACCESS_NEGATIVE_CLASSES,
        "Phase 14 memory-access composition or negative inventory drifted",
    )
    require(contract["next_patch"] == "14.8",
            "Phase 14 memory-access next patch must be 14.8")
    return contract


def validate_phase14_string_view_structure(registry):
    contract = registry["phase14_string_views"]
    require(
        isinstance(contract, dict) and set(contract) == PHASE14_STRING_VIEW_FIELDS,
        "Phase 14 string-view contract fields drifted",
    )
    require(
        contract["version"] == PHASE14_STRING_VIEW_VERSION
        and contract["status"] == PHASE14_STRING_VIEW_STATUS,
        "Phase 14 string-view checkpoint drifted",
    )
    require(
        contract["authority_owner"] == "compiler/mir_string_view.gst"
        and contract["string_view_table_format"]
        == PHASE14_STRING_VIEW_TABLE_FORMAT,
        "Phase 14 string-view authority or table format drifted",
    )
    require(
        contract["primary_level2_target"] == "x86_64-unknown-linux-gnu"
        and contract["source_encoding"] == "utf8"
        and contract["literal_encoding"] == "utf8",
        "Phase 14 string encoding or primary target drifted",
    )
    require(
        contract["embedded_nul_policy"] == "valid_data_byte_not_terminator"
        and contract["empty_string_policy"]
        == "non_null_static_empty_storage_with_zero_length"
        and contract["semantic_length_authority"]
        == "explicit_byte_length_not_nul_termination",
        "Phase 14 string length or embedded-NUL policy drifted",
    )
    require(
        contract["owning_string_policy"]
        == "deferred_no_heap_allocation_authority"
        and contract["view_representation"]
        == "data_pointer_and_usize_length"
        and tuple(contract["view_layout_fields"])
        == PHASE14_STRING_VIEW_LAYOUT_FIELDS,
        "Phase 14 string owning/view representation drifted",
    )
    for field in (
        "lifetime_policy", "mutation_policy", "concatenation_policy",
        "allocation_policy", "poisoned_driver_policy",
        "output_preservation_policy", "boundary_policy",
    ):
        text(contract[field], f"phase14_string_views.{field}")
    require(
        contract["literal_count_per_target"] == 4
        and contract["view_count_per_target"] == 4
        and tuple(contract["operation_kinds"])
        == PHASE14_STRING_VIEW_OPERATION_KINDS
        and contract["operation_count_per_target"] == 13,
        "Phase 14 string-view selected inventory drifted",
    )
    require(
        tuple(contract["migrated_entry_ids"])
        == PHASE14_STRING_VIEW_MIGRATED_IDS,
        "Phase 14 string-view migrated-row inventory drifted",
    )
    require(
        contract["focused_ci_family"] == "strings-views"
        and contract["level1_guard"]
        == "guard-cranelift-phase14-string-view-contract"
        and contract["level2_guard"]
        == "guard-cranelift-phase14-string-view-parity",
        "Phase 14 string-view CI ownership drifted",
    )
    require(
        tuple(contract["composition_contexts"])
        == PHASE14_STRING_VIEW_CONTEXTS
        and tuple(contract["negative_classes"])
        == PHASE14_STRING_VIEW_NEGATIVE_CLASSES,
        "Phase 14 string-view composition or negative inventory drifted",
    )
    require(contract["next_patch"] == "14.8",
            "Phase 14 string-view next patch must be 14.8")
    return contract


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
    phase14_primitive_schema = definitions.get(
        "phase14_primitive_layout",
        {},
    )
    require(
        set(phase14_primitive_schema.get("required", []))
        == PHASE14_PRIMITIVE_FIELDS,
        "schema Phase 14 primitive layout fields drifted",
    )
    require(
        phase14_primitive_schema.get("additionalProperties") is False,
        "schema Phase 14 primitive layout must reject unknown fields",
    )
    target_schema = definitions.get("phase14_declared_target", {})
    require(
        set(target_schema.get("required", [])) == PHASE14_DECLARED_TARGET_FIELDS,
        "schema Phase 14 declared target fields drifted",
    )
    primitive_type_schema = definitions.get("phase14_primitive_type", {})
    require(
        set(primitive_type_schema.get("required", []))
        == PHASE14_PRIMITIVE_TYPE_FIELDS,
        "schema Phase 14 primitive type fields drifted",
    )
    phase14_conversion_schema = definitions.get(
        "phase14_integer_conversions", {}
    )
    require(
        set(phase14_conversion_schema.get("required", []))
        == PHASE14_CONVERSION_FIELDS,
        "schema Phase 14 integer conversion fields drifted",
    )
    require(
        phase14_conversion_schema.get("additionalProperties") is False,
        "schema Phase 14 integer conversions must reject unknown fields",
    )
    phase14_conversion_rule_schema = definitions.get(
        "phase14_integer_conversion_rule", {}
    )
    require(
        set(phase14_conversion_rule_schema.get("required", []))
        == PHASE14_CONVERSION_RULE_FIELDS,
        "schema Phase 14 integer conversion rule fields drifted",
    )
    require(
        phase14_conversion_rule_schema.get("additionalProperties") is False,
        "schema Phase 14 integer conversion rules must reject unknown fields",
    )
    phase14_pointer_schema = definitions.get("phase14_pointers", {})
    require(
        set(phase14_pointer_schema.get("required", []))
        == PHASE14_POINTER_FIELDS,
        "schema Phase 14 pointer fields drifted",
    )
    require(
        phase14_pointer_schema.get("additionalProperties") is False,
        "schema Phase 14 pointers must reject unknown fields",
    )
    phase14_stack_slot_schema = definitions.get("phase14_stack_slots", {})
    require(
        set(phase14_stack_slot_schema.get("required", []))
        == PHASE14_STACK_SLOT_FIELDS,
        "schema Phase 14 stack-slot fields drifted",
    )
    require(
        phase14_stack_slot_schema.get("additionalProperties") is False,
        "schema Phase 14 stack slots must reject unknown fields",
    )
    phase14_memory_access_schema = definitions.get(
        "phase14_memory_accesses", {}
    )
    require(
        set(phase14_memory_access_schema.get("required", []))
        == PHASE14_MEMORY_ACCESS_FIELDS,
        "schema Phase 14 memory-access fields drifted",
    )
    require(
        phase14_memory_access_schema.get("additionalProperties") is False,
        "schema Phase 14 memory accesses must reject unknown fields",
    )
    phase14_string_view_schema = definitions.get("phase14_string_views", {})
    require(
        set(phase14_string_view_schema.get("required", []))
        == PHASE14_STRING_VIEW_FIELDS,
        "schema Phase 14 string-view fields drifted",
    )
    require(
        phase14_string_view_schema.get("additionalProperties") is False,
        "schema Phase 14 string views must reject unknown fields",
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
    require(registry["registry_version"] == 14, "registry_version must be 14")
    require(
        registry["registry_status"] == "phase14_string_views_ready",
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
    validate_phase14_primitive_layout_structure(registry)
    validate_phase14_integer_conversion_structure(registry)
    validate_phase14_pointer_structure(registry)
    validate_phase14_stack_slot_structure(registry)
    validate_phase14_memory_access_structure(registry)
    validate_phase14_string_view_structure(registry)

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
                entry["target_applicability"] == PHASE14_TARGET_APPLICABILITY,
                f"{entry_id}: Phase 14 target applicability drifted",
            )
            require(
                entry["current_failure_stage"] in PHASE14_FAILURE_STAGES,
                f"{entry_id}: unsupported Phase 14 failure stage",
            )
            for field in ("positive_future_fixture", "negative_current_fixture"):
                fixture(entry[field], f"{entry_id}.{field}")
            require(
                entry["positive_future_fixture"] != entry["negative_current_fixture"],
                f"{entry_id}: Phase 14 fixture pair must differ",
            )
            evidence = entry["evidence"]
            require(
                evidence.get("opening_record_kind") == "phase14_candidate"
                and evidence.get("phase13_closure_dependency")
                == PHASE13_CLOSURE_VERSION
                and evidence.get("phase14_1_authority")
                == "compiler_owned_layout_authority_and_request_transport_available",
                f"{entry_id}: Phase 14 inherited authority evidence drifted",
            )
            text(evidence.get("declared_capability"),
                 f"{entry_id}.evidence.declared_capability")
            category = text(evidence.get("planning_category"),
                            f"{entry_id}.evidence.planning_category")
            require(
                category in PHASE14_PLANNING_CATEGORIES,
                f"{entry_id}: unknown Phase 14 planning category {category}",
            )
            if entry_id in PHASE14_PRIMITIVE_MIGRATED_IDS:
                require(
                    closure == PHASE14_PRIMITIVE_VERSION,
                    f"{entry_id}: primitive layout checkpoint version drifted",
                )
                require(
                    status == "migrated"
                    and entry["route_owner"] == "generic_canonical_mir",
                    f"{entry_id}: selected primitive row must be migrated through canonical MIR",
                )
                require(reason == destination == "none_migrated",
                        f"{entry_id}: migrated primitive row has stale deferral fields")
                require(entry["current_failure_stage"] == "none_supported",
                        f"{entry_id}: migrated primitive row has a failure stage")
                fixture(entry["source_fixture"], f"{entry_id}.source_fixture")
                fixture(entry["canonical_mir_fixture"],
                        f"{entry_id}.canonical_mir_fixture")
                require(
                    entry["differential_case_id"]
                    == f"phase14_registry_differential:{entry_id}",
                    f"{entry_id}: primitive differential identity drifted",
                )
                require(
                    evidence.get("behavior_policy")
                    == "declared_target_and_primitive_layout_migrated_through_compiler_owned_v2_layout_table"
                    and evidence.get("phase14_2_contract")
                    == PHASE14_PRIMITIVE_VERSION
                    and evidence.get("selected_primitive_type_ids")
                    == list(PHASE14_PRIMITIVE_TYPE_IDS)
                    and evidence.get("canonical_boolean_values") == [0, 1],
                    f"{entry_id}: primitive layout evidence drifted",
                )
            elif entry_id in PHASE14_CONVERSION_MIGRATED_IDS:
                require(
                    closure == PHASE14_CONVERSION_VERSION,
                    f"{entry_id}: integer conversion checkpoint version drifted",
                )
                require(
                    status == "migrated"
                    and entry["route_owner"] == "generic_canonical_mir",
                    f"{entry_id}: selected conversion row must be migrated through canonical MIR",
                )
                require(reason == destination == "none_migrated",
                        f"{entry_id}: migrated conversion row has stale deferral fields")
                require(entry["current_failure_stage"] == "none_supported",
                        f"{entry_id}: migrated conversion row has a failure stage")
                fixture(entry["source_fixture"], f"{entry_id}.source_fixture")
                fixture(entry["canonical_mir_fixture"],
                        f"{entry_id}.canonical_mir_fixture")
                require(
                    entry["differential_case_id"]
                    == f"phase14_registry_differential:{entry_id}",
                    f"{entry_id}: conversion differential identity drifted",
                )
                require(
                    evidence.get("behavior_policy")
                    == "signed_unsigned_and_width_conversions_migrated_through_compiler_owned_conversion_table"
                    and evidence.get("phase14_2_contract")
                    == PHASE14_PRIMITIVE_VERSION
                    and evidence.get("phase14_3_contract")
                    == PHASE14_CONVERSION_VERSION
                    and evidence.get("selected_conversion_kinds")
                    == list(PHASE14_CONVERSION_KINDS)
                    and evidence.get("selected_rule_names")
                    == list(PHASE14_CONVERSION_RULE_NAMES)
                    and evidence.get("diagnostic_fields")
                    == list(PHASE14_CONVERSION_DIAGNOSTIC_FIELDS),
                    f"{entry_id}: integer conversion evidence drifted",
                )
            elif entry_id in PHASE14_POINTER_MIGRATED_IDS:
                require(
                    closure == PHASE14_POINTER_VERSION,
                    f"{entry_id}: pointer checkpoint version drifted",
                )
                require(
                    status == "migrated"
                    and entry["route_owner"] == "generic_canonical_mir",
                    f"{entry_id}: selected pointer row must be migrated through canonical MIR",
                )
                require(reason == destination == "none_migrated",
                        f"{entry_id}: migrated pointer row has stale deferral fields")
                require(entry["current_failure_stage"] == "none_supported",
                        f"{entry_id}: migrated pointer row has a failure stage")
                fixture(entry["source_fixture"], f"{entry_id}.source_fixture")
                fixture(entry["canonical_mir_fixture"],
                        f"{entry_id}.canonical_mir_fixture")
                require(
                    entry["differential_case_id"]
                    == f"phase14_registry_differential:{entry_id}",
                    f"{entry_id}: pointer differential identity drifted",
                )
                require(
                    evidence.get("behavior_policy")
                    == "bounded_typed_pointer_and_nullability_model_migrated_through_compiler_owned_pointer_table"
                    and evidence.get("phase14_2_contract")
                    == PHASE14_PRIMITIVE_VERSION
                    and evidence.get("phase14_3_contract")
                    == PHASE14_CONVERSION_VERSION
                    and evidence.get("phase14_4_contract")
                    == PHASE14_POINTER_VERSION
                    and evidence.get("selected_pointer_operation_kinds")
                    == list(PHASE14_POINTER_OPERATION_KINDS)
                    and evidence.get("default_address_space") == "default",
                    f"{entry_id}: pointer evidence drifted",
                )
            elif entry_id in PHASE14_STACK_SLOT_MIGRATED_IDS:
                require(
                    closure == PHASE14_STACK_SLOT_VERSION,
                    f"{entry_id}: stack-slot checkpoint version drifted",
                )
                require(
                    status == "migrated"
                    and entry["route_owner"] == "generic_canonical_mir",
                    f"{entry_id}: selected stack-slot row must be migrated through canonical MIR",
                )
                require(reason == destination == "none_migrated",
                        f"{entry_id}: migrated stack-slot row has stale deferral fields")
                require(entry["current_failure_stage"] == "none_supported",
                        f"{entry_id}: migrated stack-slot row has a failure stage")
                fixture(entry["source_fixture"], f"{entry_id}.source_fixture")
                fixture(entry["canonical_mir_fixture"],
                        f"{entry_id}.canonical_mir_fixture")
                require(
                    entry["differential_case_id"]
                    == f"phase14_registry_differential:{entry_id}",
                    f"{entry_id}: stack-slot differential identity drifted",
                )
                require(
                    evidence.get("behavior_policy")
                    == "deterministic_compiler_owned_stack_slots_migrated_through_canonical_MIR_and_native_request_transport"
                    and evidence.get("phase14_4_contract")
                    == PHASE14_POINTER_VERSION
                    and evidence.get("phase14_5_contract")
                    == PHASE14_STACK_SLOT_VERSION
                    and evidence.get("storage_classes")
                    == list(PHASE14_STACK_SLOT_STORAGE_CLASSES)
                    and evidence.get("selected_operation_kinds")
                    == list(PHASE14_STACK_SLOT_OPERATION_KINDS),
                    f"{entry_id}: stack-slot evidence drifted",
                )
            elif entry_id in PHASE14_MEMORY_ACCESS_MIGRATED_IDS:
                require(
                    closure == PHASE14_MEMORY_ACCESS_VERSION,
                    f"{entry_id}: memory-access checkpoint version drifted",
                )
                require(
                    status == "migrated"
                    and entry["route_owner"] == "generic_canonical_mir",
                    f"{entry_id}: selected memory-access row must be migrated through canonical MIR",
                )
                require(reason == destination == "none_migrated",
                        f"{entry_id}: migrated memory-access row has stale deferral fields")
                require(entry["current_failure_stage"] == "none_supported",
                        f"{entry_id}: migrated memory-access row has a failure stage")
                fixture(entry["source_fixture"], f"{entry_id}.source_fixture")
                fixture(entry["canonical_mir_fixture"],
                        f"{entry_id}.canonical_mir_fixture")
                require(
                    entry["differential_case_id"]
                    == f"phase14_registry_differential:{entry_id}",
                    f"{entry_id}: memory-access differential identity drifted",
                )
                require(
                    evidence.get("behavior_policy")
                    == "typed_target_aware_layout_backed_memory_access_migrated_through_canonical_MIR_and_native_request_transport"
                    and evidence.get("phase14_4_contract")
                    == PHASE14_POINTER_VERSION
                    and evidence.get("phase14_5_contract")
                    == PHASE14_STACK_SLOT_VERSION
                    and evidence.get("phase14_6_contract")
                    == PHASE14_MEMORY_ACCESS_VERSION
                    and evidence.get("selected_type_ids")
                    == list(PHASE14_MEMORY_ACCESS_TYPE_IDS)
                    and evidence.get("selected_operation_kinds")
                    == list(PHASE14_MEMORY_ACCESS_OPERATION_KINDS),
                    f"{entry_id}: memory-access evidence drifted",
                )
            elif entry_id in PHASE14_STRING_VIEW_MIGRATED_IDS:
                require(
                    closure == PHASE14_STRING_VIEW_VERSION,
                    f"{entry_id}: string-view checkpoint version drifted",
                )
                require(
                    status == "migrated"
                    and entry["route_owner"] == "generic_canonical_mir",
                    f"{entry_id}: selected string-view row must be migrated through canonical MIR",
                )
                require(reason == destination == "none_migrated",
                        f"{entry_id}: migrated string-view row has stale deferral fields")
                require(entry["current_failure_stage"] == "none_supported",
                        f"{entry_id}: migrated string-view row has a failure stage")
                fixture(entry["source_fixture"], f"{entry_id}.source_fixture")
                fixture(entry["canonical_mir_fixture"],
                        f"{entry_id}.canonical_mir_fixture")
                require(
                    entry["differential_case_id"]
                    == f"phase14_registry_differential:{entry_id}",
                    f"{entry_id}: string-view differential identity drifted",
                )
                require(
                    evidence.get("behavior_policy")
                    == "immutable_utf8_literal_storage_and_borrowed_explicit_length_views_migrated_through_compiler_owned_string_view_table"
                    and evidence.get("phase14_7_contract")
                    == PHASE14_STRING_VIEW_VERSION
                    and evidence.get("selected_source_encoding") == "utf8"
                    and evidence.get("selected_literal_encoding") == "utf8"
                    and evidence.get("selected_operation_kinds")
                    == list(PHASE14_STRING_VIEW_OPERATION_KINDS),
                    f"{entry_id}: string-view evidence drifted",
                )
            elif entry_id in PHASE14_ARRAY_SLICE_MIGRATED_IDS:
                require(
                    closure == PHASE14_ARRAY_SLICE_VERSION,
                    f"{entry_id}: array/slice checkpoint version drifted",
                )
                require(
                    status == "migrated"
                    and entry["route_owner"] == "generic_canonical_mir",
                    f"{entry_id}: selected array/slice row must be migrated through canonical MIR",
                )
                require(reason == destination == "none_migrated",
                        f"{entry_id}: migrated array/slice row has stale deferral fields")
                require(entry["current_failure_stage"] == "none_supported",
                        f"{entry_id}: migrated array/slice row has a failure stage")
                fixture(entry["source_fixture"], f"{entry_id}.source_fixture")
                fixture(entry["canonical_mir_fixture"],
                        f"{entry_id}.canonical_mir_fixture")
                require(
                    entry["differential_case_id"]
                    == f"phase14_registry_differential:{entry_id}",
                    f"{entry_id}: array/slice differential identity drifted",
                )
                require(
                    evidence.get("behavior_policy")
                    == "fixed_arrays_and_bounded_slices_migrated_through_compiler_owned_count_stride_size_alignment_bounds_and_lifetime_rules"
                    and evidence.get("phase14_8_contract")
                    == PHASE14_ARRAY_SLICE_VERSION
                    and evidence.get("selected_operation_kinds")
                    == list(PHASE14_ARRAY_SLICE_OPERATION_KINDS),
                    f"{entry_id}: array/slice evidence drifted",
                )
            elif entry_id in PHASE14_AGGREGATE_MIGRATED_IDS:
                require(
                    closure == PHASE14_AGGREGATE_VERSION,
                    f"{entry_id}: aggregate transport checkpoint version drifted",
                )
                require(
                    status == "migrated"
                    and entry["route_owner"] == "generic_canonical_mir",
                    f"{entry_id}: selected aggregate row must be migrated through canonical MIR",
                )
                require(reason == destination == "none_migrated",
                        f"{entry_id}: migrated aggregate row has stale deferral fields")
                require(entry["current_failure_stage"] == "none_supported",
                        f"{entry_id}: migrated aggregate row has a failure stage")
                fixture(entry["source_fixture"], f"{entry_id}.source_fixture")
                fixture(entry["canonical_mir_fixture"],
                        f"{entry_id}.canonical_mir_fixture")
                require(
                    entry["differential_case_id"]
                    == f"phase14_registry_differential:{entry_id}",
                    f"{entry_id}: aggregate differential identity drifted",
                )
                require(
                    evidence.get("behavior_policy")
                    == "non_resource_aggregates_cross_basic_block_boundaries_through_one_compiler_owned_transport_plan_per_class"
                    and evidence.get("phase14_11_contract") == PHASE14_AGGREGATE_VERSION
                    and evidence.get("selected_aggregate_classes")
                    == list(PHASE14_AGGREGATE_CLASSES)
                    and evidence.get("selected_operation_kinds")
                    == list(PHASE14_AGGREGATE_OPERATION_KINDS)
                    and evidence.get("selected_negative_classes")
                    == list(PHASE14_AGGREGATE_NEGATIVE_CLASSES)
                    and evidence.get("transport_authority")
                    == "compiler_owned_transport_plan_no_backend_flattening"
                    and evidence.get("copy_policy")
                    == "explicit_non_resource_copy_only"
                    and evidence.get("resource_policy")
                    == "deferred_resource_bearing_aggregate_movement_and_destruction"
                    and evidence.get("abi_policy")
                    == "deferred_aggregate_parameter_and_return_abi",
                    f"{entry_id}: aggregate transport evidence drifted",
                )
            elif entry_id in PHASE14_STRUCT_MIGRATED_IDS:
                require(
                    closure == PHASE14_STRUCT_VERSION,
                    f"{entry_id}: struct checkpoint version drifted",
                )
                require(
                    status == "migrated"
                    and entry["route_owner"] == "generic_canonical_mir",
                    f"{entry_id}: selected struct row must be migrated through canonical MIR",
                )
                require(reason == destination == "none_migrated",
                        f"{entry_id}: migrated struct row has stale deferral fields")
                require(entry["current_failure_stage"] == "none_supported",
                        f"{entry_id}: migrated struct row has a failure stage")
                fixture(entry["source_fixture"], f"{entry_id}.source_fixture")
                fixture(entry["canonical_mir_fixture"],
                        f"{entry_id}.canonical_mir_fixture")
                require(
                    entry["differential_case_id"]
                    == f"phase14_registry_differential:{entry_id}",
                    f"{entry_id}: struct differential identity drifted",
                )
                require(
                    evidence.get("behavior_policy")
                    == "declaration_order_structs_migrated_through_compiler_owned_field_offset_padding_size_and_alignment_rules"
                    and evidence.get("phase14_9_contract") == PHASE14_STRUCT_VERSION
                    and evidence.get("selected_operation_kinds")
                    == list(PHASE14_STRUCT_OPERATION_KINDS)
                    and evidence.get("selected_negative_classes")
                    == list(PHASE14_STRUCT_NEGATIVE_CLASSES)
                    and evidence.get("field_order_policy")
                    == "declaration_order_preserved"
                    and evidence.get("offset_authority")
                    == "compiler_owned_offsets_no_backend_relayout"
                    and evidence.get("padding_policy")
                    == "natural_alignment_with_tail_padding"
                    and evidence.get("aggregate_abi_policy")
                    == "deferred_aggregate_parameter_and_return_abi"
                    and evidence.get("packed_struct_policy")
                    == "deferred_packed_structs_and_bitfields",
                    f"{entry_id}: struct evidence drifted",
                )
            elif entry_id in PHASE14_ENUM_MIGRATED_IDS:
                require(
                    closure == PHASE14_ENUM_VERSION,
                    f"{entry_id}: enum checkpoint version drifted",
                )
                require(
                    status == "migrated"
                    and entry["route_owner"] == "generic_canonical_mir",
                    f"{entry_id}: selected enum row must be migrated through canonical MIR",
                )
                require(reason == destination == "none_migrated",
                        f"{entry_id}: migrated enum row has stale deferral fields")
                require(entry["current_failure_stage"] == "none_supported",
                        f"{entry_id}: migrated enum row has a failure stage")
                fixture(entry["source_fixture"], f"{entry_id}.source_fixture")
                fixture(entry["canonical_mir_fixture"],
                        f"{entry_id}.canonical_mir_fixture")
                require(
                    entry["differential_case_id"]
                    == f"phase14_registry_differential:{entry_id}",
                    f"{entry_id}: enum differential identity drifted",
                )
                require(
                    evidence.get("behavior_policy")
                    == "enums_and_tagged_unions_migrated_through_compiler_owned_tag_selection_discriminant_payload_offset_size_and_alignment_rules"
                    and evidence.get("phase14_10_contract") == PHASE14_ENUM_VERSION
                    and evidence.get("selected_operation_kinds")
                    == list(PHASE14_ENUM_OPERATION_KINDS)
                    and evidence.get("selected_negative_classes")
                    == list(PHASE14_ENUM_NEGATIVE_CLASSES)
                    and evidence.get("niche_optimization_policy")
                    == "deferred_niche_optimization"
                    and evidence.get("struct_payload_policy")
                    == "deferred_struct_payloads_not_selected_by_patch14_10",
                    f"{entry_id}: enum evidence drifted",
                )
            else:
                require(
                    closure == PHASE14_LAYOUT_AUTHORITY_VERSION,
                    f"{entry_id}: deferred Phase 14 authority version drifted",
                )
                require(
                    status == "candidate_deferred"
                    and entry["route_owner"] == "deferred",
                    f"{entry_id}: unselected Phase 14 rows must remain deferred",
                )
                require(
                    reason
                    == f"phase14_authority_{entry_id}_awaits_bounded_capability_migration",
                    f"{entry_id}: Phase 14 post-authority deferral reason drifted",
                )
                require(destination == "phase14",
                        f"{entry_id}: deferred Phase 14 destination drifted")
                require(entry["current_failure_stage"] == "before_driver_discovery",
                        f"{entry_id}: deferred Phase 14 row must stop before discovery")
                require(entry["source_fixture"] == entry["negative_current_fixture"],
                        f"{entry_id}: deferred source fixture must be the negative fixture")
                require(entry["canonical_mir_fixture"] == "none_rejected_before_canonical_MIR",
                        f"{entry_id}: deferred row must not claim canonical MIR")
                require(entry["differential_case_id"] == f"phase14_opening:{entry_id}",
                        f"{entry_id}: deferred differential identity drifted")
                require(
                    evidence.get("behavior_policy")
                    == "primitive_layout_and_integer_conversion_only_other_phase14_capabilities_remain_deferred"
                    and evidence.get("phase14_3_boundary")
                    == "not_selected_by_signed_unsigned_width_conversion_patch",
                    f"{entry_id}: Patch 14.3 boundary evidence drifted",
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
        "target_applicability",
    )
    snapshot_fields = tuple(snapshot["immutable_fields"])
    projected_rows = []
    for entry in rows:
        projected = {}
        for live_field, frozen_field in zip(opening_fields, snapshot_fields):
            projected[frozen_field] = entry[live_field]
        projected_rows.append(projected)
    frozen_rows = [
        {field: row[field] for field in snapshot_fields}
        for row in snapshot["entries"]
    ]
    require(
        projected_rows == frozen_rows,
        "Phase 14 immutable live fields differ from the semantic opening snapshot",
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
        registry["current_phase"] == "phase14",
        "Phase 14 registry is not active",
    )

    rows = phase_entries(registry, "phase14")
    require(
        len(rows) == opening["row_count"],
        "Phase 14 authority changed the opening-row inventory",
    )
    for entry in rows:
        entry_id = entry["id"]
        if entry_id in PHASE14_PRIMITIVE_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_PRIMITIVE_VERSION,
                f"{entry_id}: primitive migration no longer consumes the layout authority",
            )
        elif entry_id in PHASE14_CONVERSION_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_CONVERSION_VERSION,
                f"{entry_id}: conversion migration no longer consumes the layout authority",
            )
        elif entry_id in PHASE14_POINTER_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_POINTER_VERSION,
                f"{entry_id}: pointer migration no longer consumes the layout authority",
            )
        elif entry_id in PHASE14_STACK_SLOT_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_STACK_SLOT_VERSION,
                f"{entry_id}: stack-slot migration no longer consumes the layout authority",
            )
        elif entry_id in PHASE14_MEMORY_ACCESS_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_MEMORY_ACCESS_VERSION,
                f"{entry_id}: memory-access migration no longer consumes the layout authority",
            )
        elif entry_id in PHASE14_STRING_VIEW_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_STRING_VIEW_VERSION,
                f"{entry_id}: string-view migration no longer consumes the layout authority",
            )
        elif entry_id in PHASE14_ARRAY_SLICE_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_ARRAY_SLICE_VERSION,
                f"{entry_id}: array/slice migration no longer consumes the layout authority",
            )
        elif entry_id in PHASE14_AGGREGATE_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_AGGREGATE_VERSION,
                f"{entry_id}: aggregate migration no longer consumes the layout authority",
            )
        elif entry_id in PHASE14_STRUCT_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_STRUCT_VERSION,
                f"{entry_id}: struct migration no longer consumes the layout authority",
            )
        elif entry_id in PHASE14_ENUM_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_ENUM_VERSION,
                f"{entry_id}: enum migration no longer consumes the layout authority",
            )
        else:
            require(
                entry["status"] == "candidate_deferred"
                and entry["route_owner"] == "deferred",
                f"{entry_id}: unselected capability must remain deferred",
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
        "deferred_row_count": sum(
            1 for entry in rows if entry["status"] == "candidate_deferred"
        ),
        "semantic_type_count": len(authority["semantic_types"]),
        "query_count": len(authority["query_functions"]),
        "rejection_count": len(authority["rejection_classes"]),
        "consumer_count": len(authority["consumers"]),
    }


def verify_phase14_primitive_layout(registry):
    verify_phase14_layout_authority(registry)
    contract = validate_phase14_primitive_layout_structure(registry)
    require(
        registry["registry_status"] == "phase14_string_views_ready",
        "Phase 14 registry is not at or beyond the primitive-layout checkpoint",
    )
    rows = {entry["id"]: entry for entry in phase_entries(registry, "phase14")}
    for entry_id in PHASE14_PRIMITIVE_MIGRATED_IDS:
        entry = rows[entry_id]
        require(
            entry["status"] == "migrated"
            and entry["route_owner"] == "generic_canonical_mir"
            and entry["closure_version"] == PHASE14_PRIMITIVE_VERSION,
            f"{entry_id}: primitive layout row is not migrated",
        )
        require(
            entry["ci_family"] == contract["focused_ci_family"],
            f"{entry_id}: primitive layout CI ownership drifted",
        )
    for entry_id, entry in rows.items():
        if entry_id in PHASE14_PRIMITIVE_MIGRATED_IDS:
            continue
        if entry_id in PHASE14_CONVERSION_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_CONVERSION_VERSION,
                f"{entry_id}: later conversion checkpoint drifted",
            )
            continue
        if entry_id in PHASE14_POINTER_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_POINTER_VERSION,
                f"{entry_id}: later pointer checkpoint drifted",
            )
            continue
        if entry_id in PHASE14_STACK_SLOT_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_STACK_SLOT_VERSION,
                f"{entry_id}: later stack-slot checkpoint drifted",
            )
            continue
        if entry_id in PHASE14_MEMORY_ACCESS_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_MEMORY_ACCESS_VERSION,
                f"{entry_id}: later memory-access checkpoint drifted",
            )
            continue
        if entry_id in PHASE14_STRING_VIEW_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_STRING_VIEW_VERSION,
                f"{entry_id}: later string-view checkpoint drifted",
            )
            continue
        if entry_id in PHASE14_ARRAY_SLICE_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_ARRAY_SLICE_VERSION,
                f"{entry_id}: later array/slice checkpoint drifted",
            )
            continue
        if entry_id in PHASE14_AGGREGATE_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_AGGREGATE_VERSION,
                f"{entry_id}: later aggregate checkpoint drifted",
            )
            continue
        if entry_id in PHASE14_STRUCT_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_STRUCT_VERSION,
                f"{entry_id}: later struct checkpoint drifted",
            )
            continue
        if entry_id in PHASE14_ENUM_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_ENUM_VERSION,
                f"{entry_id}: later enum checkpoint drifted",
            )
            continue
        require(
            entry["status"] == "candidate_deferred"
            and entry["route_owner"] == "deferred"
            and entry["current_failure_stage"] == "before_driver_discovery",
            f"{entry_id}: Patch 14.2 migrated an out-of-scope capability",
        )

    sources = {
        "primitive": ROOT / "compiler/mir_primitive_layout.gst",
        "layout": ROOT / "compiler/mir_layout.gst",
        "mir": ROOT / "compiler/mir.gst",
        "request": ROOT / "compiler/mir_native_backend_request.gst",
        "mir_to_c": ROOT / "compiler/mir_layout_mir_to_c.gst",
        "worker": ROOT / "compiler/experiments/cranelift/src/main.rs",
        "smoke": ROOT / "compiler/mir_primitive_layout_smoke_test_entry.gst",
        "differential": ROOT / "scripts/phase14_primitive_layout_differential.sh",
    }
    for owner, path in sources.items():
        require(path.is_file() and not path.is_symlink(),
                f"missing regular Phase 14 primitive {owner} source: {path.relative_to(ROOT)}")

    primitive_source = sources["primitive"].read_text(encoding="utf-8")
    for target in contract["declared_targets"]:
        triple = target["target_triple"]
        require(triple in primitive_source,
                f"declared target {triple} is missing from compiler authority")
        for alias in target["aliases"]:
            require(alias in primitive_source,
                    f"declared target alias {alias} is missing from normalization")
    for primitive in contract["primitive_types"]:
        require(primitive["type_id"] in primitive_source,
                f"primitive type {primitive['type_id']} is missing from compiler authority")
    for token in (
        "func mir_primitive_layout_normalize_target_triple(",
        "func mir_primitive_layout_target(",
        "func mir_primitive_layout_table_for_target(",
        "func mir_primitive_layout_witness(",
        "canonical_bool_0_or_1",
    ):
        require(token in primitive_source, f"primitive authority is missing: {token}")

    layout_source = sources["layout"].read_text(encoding="utf-8")
    for token in (
        "gust.compiler_layout_table.v2",
        "type MirScalarValueValidation",
        "func mir_layout_make_target_v2(",
        "func mir_layout_make_scalar_type_layout(",
        "func mir_layout_validate_scalar_value(",
        "invalid_boolean_memory_value",
    ):
        require(token in layout_source, f"layout authority is missing: {token}")

    mir_source = sources["mir"].read_text(encoding="utf-8")
    require(
        "type MirPrimitiveScalarReference" in mir_source
        and "primitive_scalar_references" in mir_source
        and "mir_program_primitive_scalar_references_are_valid" in mir_source,
        "canonical MIR does not preserve primitive width and signedness identity",
    )
    request_source = sources["request"].read_text(encoding="utf-8")
    require(
        'import "mir_primitive_layout.gst" as primitive_layout;' in request_source
        and "mir_primitive_layout_table_for_target" in request_source,
        "native requests do not serialize the compiler-selected primitive table",
    )
    mir_to_c_source = sources["mir_to_c"].read_text(encoding="utf-8")
    require(
        "mir_layout_primitive_witness_c_source" in mir_to_c_source
        and "_Static_assert" not in mir_to_c_source,
        "MIR-to-C primitive adapter must consume rather than select layout",
    )
    worker_source = sources["worker"].read_text(encoding="utf-8")
    for token in (
        "PHASE14_LAYOUT_TABLE_FORMAT_V2",
        "fn phase14_cranelift_scalar_type(",
        "phase14-primitive-layout-witness",
        "phase14-primitive-validate-value",
    ):
        require(token in worker_source, f"Cranelift primitive consumption is missing: {token}")

    return {
        "version": contract["version"],
        "status": contract["status"],
        "target_count": len(contract["declared_targets"]),
        "primitive_count": len(contract["primitive_types"]),
        "migrated_count": len(contract["migrated_entry_ids"]),
        "deferred_count": sum(
            1 for entry in rows.values()
            if entry["status"] == "candidate_deferred"
        ),
        "primary_target": contract["primary_level2_target"],
        "family": contract["focused_ci_family"],
    }


def verify_phase14_integer_conversions(registry):
    verify_phase14_primitive_layout(registry)
    contract = validate_phase14_integer_conversion_structure(registry)
    require(
        registry["registry_status"] == "phase14_string_views_ready",
        "Phase 14 registry is not at or beyond the integer-conversion checkpoint",
    )
    rows = {entry["id"]: entry for entry in phase_entries(registry, "phase14")}
    for entry_id in PHASE14_CONVERSION_MIGRATED_IDS:
        entry = rows[entry_id]
        require(
            entry["status"] == "migrated"
            and entry["route_owner"] == "generic_canonical_mir"
            and entry["closure_version"] == PHASE14_CONVERSION_VERSION,
            f"{entry_id}: integer conversion row is not migrated",
        )
        require(
            entry["ci_family"] == contract["focused_ci_family"],
            f"{entry_id}: integer conversion CI ownership drifted",
        )
    for entry_id, entry in rows.items():
        if entry_id in PHASE14_PRIMITIVE_MIGRATED_IDS + PHASE14_CONVERSION_MIGRATED_IDS:
            continue
        if entry_id in PHASE14_POINTER_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_POINTER_VERSION,
                f"{entry_id}: later pointer checkpoint drifted",
            )
            continue
        if entry_id in PHASE14_STACK_SLOT_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_STACK_SLOT_VERSION,
                f"{entry_id}: later stack-slot checkpoint drifted",
            )
            continue
        if entry_id in PHASE14_MEMORY_ACCESS_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_MEMORY_ACCESS_VERSION,
                f"{entry_id}: later memory-access checkpoint drifted",
            )
            continue
        if entry_id in PHASE14_STRING_VIEW_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_STRING_VIEW_VERSION,
                f"{entry_id}: later string-view checkpoint drifted",
            )
            continue
        if entry_id in PHASE14_ARRAY_SLICE_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_ARRAY_SLICE_VERSION,
                f"{entry_id}: later array/slice checkpoint drifted",
            )
            continue
        if entry_id in PHASE14_AGGREGATE_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_AGGREGATE_VERSION,
                f"{entry_id}: later aggregate checkpoint drifted",
            )
            continue
        if entry_id in PHASE14_STRUCT_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_STRUCT_VERSION,
                f"{entry_id}: later struct checkpoint drifted",
            )
            continue
        if entry_id in PHASE14_ENUM_MIGRATED_IDS:
            require(
                entry["status"] == "migrated"
                and entry["route_owner"] == "generic_canonical_mir"
                and entry["closure_version"] == PHASE14_ENUM_VERSION,
                f"{entry_id}: later enum checkpoint drifted",
            )
            continue
        require(
            entry["status"] == "candidate_deferred"
            and entry["route_owner"] == "deferred"
            and entry["current_failure_stage"] == "before_driver_discovery",
            f"{entry_id}: Patch 14.3 migrated an out-of-scope capability",
        )

    sources = {
        "authority": ROOT / "compiler/mir_integer_conversion.gst",
        "mir": ROOT / "compiler/mir.gst",
        "request": ROOT / "compiler/mir_native_backend_request.gst",
        "mir_to_c": ROOT / "compiler/mir_integer_conversion_mir_to_c.gst",
        "diagnostics": ROOT / "compiler/mir_integer_conversion_diagnostics.gst",
        "worker": ROOT / "compiler/experiments/cranelift/src/main.rs",
        "smoke": ROOT / "compiler/mir_integer_conversion_smoke_test_entry.gst",
        "differential": ROOT / "scripts/phase14_integer_conversion_differential.sh",
    }
    for owner, path in sources.items():
        require(
            path.is_file() and not path.is_symlink(),
            f"missing regular Phase 14 conversion {owner} source: {path.relative_to(ROOT)}",
        )

    authority_source = sources["authority"].read_text(encoding="utf-8")
    for token in (
        "type MirIntegerConversionRule",
        "type MirIntegerConversionSample",
        "input_value: str",
        "expected_value: str",
        "func mir_integer_conversion_decimal_is_canonical(",
        "type MirIntegerConversionTable",
        "func mir_integer_conversion_table_for_layout(",
        "func mir_integer_conversion_select(",
        "func mir_integer_conversion_evaluate(",
        "func mir_integer_conversion_table_is_valid(",
        "func mir_serialize_integer_conversion_table_for_request(",
        PHASE14_CONVERSION_TABLE_FORMAT,
        "conversion:v1:target=",
    ):
        require(token in authority_source, f"conversion authority is missing: {token}")
    for kind in PHASE14_CONVERSION_KINDS:
        require(kind in authority_source,
                f"conversion authority is missing canonical kind {kind}")
    for rule_name in PHASE14_CONVERSION_RULE_NAMES:
        require(rule_name in authority_source,
                f"conversion authority is missing selected rule {rule_name}")

    mir_source = sources["mir"].read_text(encoding="utf-8")
    for token in (
        "type MirIntegerConversionKind enum",
        "type MirIntegerConversionReference",
        "integer_conversion_references",
        "IntegerConvert",
        "func mir_make_value_integer_convert(",
        "func mir_program_integer_conversion_references_are_valid(",
    ):
        require(token in mir_source, f"canonical MIR conversion model is missing: {token}")

    request_source = sources["request"].read_text(encoding="utf-8")
    require(
        "integer_conversion_table: integer_conversion.MirIntegerConversionTable[ctx]"
        in request_source
        and "mir_serialize_integer_conversion_table_for_request" in request_source,
        "native request does not carry the compiler-owned conversion table",
    )

    c_source = sources["mir_to_c"].read_text(encoding="utf-8")
    for token in (
        "mir_integer_conversion_c_source",
        "gust_convert",
        "gust_wrap_u32",
        "gust_fits",
    ):
        require(token in c_source, f"MIR-to-C conversion lowering is missing: {token}")
    require(
        "(int32_t)" not in c_source and "(uint32_t)" not in c_source,
        "MIR-to-C must not use host casts as conversion semantic authority",
    )

    diagnostic_source = sources["diagnostics"].read_text(encoding="utf-8")
    for field in PHASE14_CONVERSION_DIAGNOSTIC_FIELDS:
        require(f"{field}=" in diagnostic_source,
                f"conversion diagnostics are missing field {field}")

    worker_source = sources["worker"].read_text(encoding="utf-8")
    for token in (
        "struct Phase14RequestIntegerConversionTable",
        "fn parse_phase14_request_integer_conversion_table(",
        "fn validate_phase14_request_integer_conversion_table(",
        "fn phase14_cranelift_integer_conversion_op(",
        "phase14-integer-conversion-witness",
        "sextend", "uextend", "ireduce",
    ):
        require(token in worker_source, f"Cranelift conversion consumption is missing: {token}")

    smoke_source = sources["smoke"].read_text(encoding="utf-8")
    context_tokens = {
        "comparisons": '"comparison"',
        "locals": '"local"',
        "branches": '"branch"',
        "aggregate_fields": '"aggregate_field"',
    }
    for context in PHASE14_CONVERSION_CONTEXTS:
        require(context_tokens[context] in authority_source,
                f"conversion authority is missing composition context {context}")
    negative_tokens = {
        "unsupported_implicit_conversion": "conversion_unsupported_implicit",
        "invalid_boolean_conversion": "conversion_invalid_boolean_value",
        "narrowing_without_allowed_policy": "conversion_narrowing_policy_required",
        "pointer_integer_conversion_deferred": "conversion_pointer_integer_deferred",
        "target_dependent_conversion_without_declared_target": "conversion_target_required",
        "request_target_conversion_disagreement": "request target/conversion disagreement",
        "conversion_width_mismatch": "conversion_width_mismatch",
    }
    differential_source = sources["differential"].read_text(encoding="utf-8")
    for negative in PHASE14_CONVERSION_NEGATIVE_CLASSES:
        token = negative_tokens[negative]
        require(
            token in smoke_source or token in authority_source
            or token in differential_source or token in worker_source,
            f"conversion negative evidence is missing: {negative}",
        )

    return {
        "version": contract["version"],
        "status": contract["status"],
        "rule_count": len(contract["selected_rules"]),
        "kind_count": len(contract["conversion_kinds"]),
        "migrated_count": len(contract["migrated_entry_ids"]),
        "deferred_count": sum(
            1 for entry in rows.values()
            if entry["status"] == "candidate_deferred"
        ),
        "target_count": len(
            registry["phase14_primitive_layout"]["declared_targets"]
        ),
        "family": contract["focused_ci_family"],
    }



def verify_phase14_pointers(registry):
    verify_phase14_integer_conversions(registry)
    contract = validate_phase14_pointer_structure(registry)
    require(
        registry["registry_status"] == "phase14_string_views_ready",
        "Phase 14 registry is not at the pointer/nullability checkpoint",
    )
    rows = {entry["id"]: entry for entry in phase_entries(registry, "phase14")}
    for entry_id in PHASE14_POINTER_MIGRATED_IDS:
        entry = rows[entry_id]
        require(
            entry["status"] == "migrated"
            and entry["route_owner"] == "generic_canonical_mir"
            and entry["closure_version"] == PHASE14_POINTER_VERSION,
            f"{entry_id}: pointer/nullability row is not migrated",
        )
        require(
            entry["ci_family"] == contract["focused_ci_family"],
            f"{entry_id}: pointer CI ownership drifted",
        )
    selected_ids = (
        PHASE14_PRIMITIVE_MIGRATED_IDS
        + PHASE14_CONVERSION_MIGRATED_IDS
        + PHASE14_POINTER_MIGRATED_IDS
        + PHASE14_STACK_SLOT_MIGRATED_IDS
        + PHASE14_MEMORY_ACCESS_MIGRATED_IDS
        + PHASE14_STRING_VIEW_MIGRATED_IDS
        + PHASE14_ARRAY_SLICE_MIGRATED_IDS
        + PHASE14_STRUCT_MIGRATED_IDS
        + PHASE14_ENUM_MIGRATED_IDS
        + PHASE14_AGGREGATE_MIGRATED_IDS
    )
    for entry_id, entry in rows.items():
        if entry_id in selected_ids:
            continue
        require(
            entry["status"] == "candidate_deferred"
            and entry["route_owner"] == "deferred"
            and entry["current_failure_stage"] == "before_driver_discovery",
            f"{entry_id}: capability outside the pointer/stack checkpoints migrated unexpectedly",
        )

    sources = {
        "authority": ROOT / "compiler/mir_pointer.gst",
        "mir": ROOT / "compiler/mir.gst",
        "request": ROOT / "compiler/mir_native_backend_request.gst",
        "mir_to_c": ROOT / "compiler/mir_pointer_mir_to_c.gst",
        "diagnostics": ROOT / "compiler/mir_pointer_diagnostics.gst",
        "worker": ROOT / "compiler/experiments/cranelift/src/main.rs",
        "smoke": ROOT / "compiler/mir_pointer_smoke_test_entry.gst",
        "differential": ROOT / "scripts/phase14_pointer_differential.sh",
        "positive": ROOT / "compiler/phase14_pointer_nullability_source.gst",
        "composition": ROOT / "compiler/phase14_pointer_composition_source.gst",
        "fixture": ROOT / "compiler/fixtures/native_backend_phase14_pointer_ingestion.mir",
        "malformed": ROOT / "compiler/fixtures/native_backend_phase14_pointer_malformed.mir",
    }
    for owner, path in sources.items():
        require(
            path.is_file() and not path.is_symlink(),
            f"missing regular Phase 14 pointer {owner} source: {path.relative_to(ROOT)}",
        )

    authority_source = sources["authority"].read_text(encoding="utf-8")
    for token in (
        "type MirPointerType[ctx] struct",
        "type MirPointerOperation[ctx] struct",
        "type MirPointerTable[ctx] struct",
        "func mir_pointer_table_for_layout(",
        "func mir_pointer_select_type(",
        "func mir_pointer_operation_request_is_supported(",
        "func mir_pointer_table_is_valid(",
        "func mir_serialize_pointer_table_for_request(",
        "func mir_pointer_witness(",
        PHASE14_POINTER_TABLE_FORMAT,
        "pointer:v1:target=",
    ):
        require(token in authority_source, f"pointer authority is missing: {token}")
    for kind in PHASE14_POINTER_OPERATION_KINDS:
        require(kind in authority_source,
                f"pointer authority is missing canonical kind {kind}")
    for field in PHASE14_POINTER_PROVENANCE_FIELDS:
        require(field in authority_source,
                f"pointer authority is missing provenance field {field}")
    for token in (
        "pointer_arithmetic_unsupported",
        "pointer_integer_cast_unsupported",
        "pointer_load_store_contract_deferred",
        "pointer_pointee_unsized_or_unsupported",
        "pointer_address_space_unsupported",
        "pointer_target_required",
    ):
        require(token in authority_source,
                f"pointer authority is missing rejection reason {token}")

    mir_source = sources["mir"].read_text(encoding="utf-8")
    for token in (
        "type MirPointerOperationKind enum",
        "type MirPointerTypeReference",
        "type MirPointerOperationReference",
        "pointer_type_references",
        "pointer_operation_references",
        "PointerOperation",
        "func mir_make_value_pointer_operation(",
        "func mir_program_pointer_references_are_valid(",
    ):
        require(token in mir_source, f"canonical MIR pointer model is missing: {token}")
    require(
        "operation: Index[MirPointerOperationReference[ctx], ctx]" in mir_source,
        "canonical MIR pointer operation must arena-index its reference payload",
    )

    request_source = sources["request"].read_text(encoding="utf-8")
    require(
        "pointer_table: pointer.MirPointerTable[ctx]" in request_source
        and "mir_serialize_pointer_table_for_request" in request_source
        and "mir_pointer_table_for_layout" in request_source,
        "native request does not carry the compiler-owned pointer table",
    )

    c_source = sources["mir_to_c"].read_text(encoding="utf-8")
    for token in (
        "mir_pointer_c_source",
        "const int *nonnull = &local0",
        "const int *nullable = NULL",
        "struct GustPointerHolder",
    ):
        require(token in c_source, f"MIR-to-C pointer witness is missing: {token}")
    for banned in (
        "return *nonnull", "return *nullable", "pointer +", "pointer -",
        "uintptr_t", "intptr_t",
    ):
        require(banned not in c_source,
                f"MIR-to-C pointer witness opened unsupported behavior: {banned}")

    diagnostic_source = sources["diagnostics"].read_text(encoding="utf-8")
    for field in (
        "pointer_type", "pointee_type", "pointee_layout", "mutability",
        "nullability", "address_space", "pointer_width", "operation",
        "reason_code",
    ):
        require(f"{field}=" in diagnostic_source,
                f"pointer diagnostics are missing field {field}")

    worker_source = sources["worker"].read_text(encoding="utf-8")
    for token in (
        "struct Phase14RequestPointerTable",
        "fn parse_phase14_request_pointer_table(",
        "fn validate_phase14_request_pointer_table(",
        "fn phase14_cranelift_pointer_type(",
        "phase14-pointer-witness",
        "pointee_layout_id",
    ):
        require(token in worker_source, f"Cranelift pointer consumption is missing: {token}")
    for banned in (
        "size_of::<", "align_of::<", "Layout::", "offset_of!",
    ):
        require(banned not in worker_source,
                f"worker must not infer pointer or pointee layout through {banned}")
    require(
        "pointer_type.pointee_layout_id" in worker_source
        and "layout.layout_id == pointer_type.pointee_layout_id" in worker_source,
        "worker must resolve the compiler-serialized pointee layout ID",
    )

    smoke_source = sources["smoke"].read_text(encoding="utf-8")
    differential_source = sources["differential"].read_text(encoding="utf-8")
    context_tokens = {
        "locals": '"local"',
        "comparisons": '"comparison"',
        "nullable_branches": '"branch"',
        "aggregate_fields": '"aggregate_field"',
    }
    for context in PHASE14_POINTER_CONTEXTS:
        require(
            context_tokens[context] in authority_source
            or context_tokens[context] in smoke_source,
            f"pointer authority is missing composition context {context}",
        )
    negative_tokens = {
        "pointer_width_mismatch": "pointer width mismatch",
        "invalid_pointee_layout": "pointee layout",
        "invalid_nullability_conversion": "pointer_nullability_check_failed",
        "unsupported_address_space": "pointer_address_space_unsupported",
        "unsupported_pointer_arithmetic": "pointer_arithmetic_unsupported",
        "unrestricted_integer_pointer_cast": "pointer_integer_cast_unsupported",
        "unsized_or_unsupported_pointee": "pointer_pointee_unsized_or_unsupported",
        "dereference_before_load_store_contract": "pointer_load_store_contract_deferred",
        "target_required": "pointer_target_required",
    }
    for negative in PHASE14_POINTER_NEGATIVE_CLASSES:
        token = negative_tokens[negative]
        require(
            token in authority_source or token in smoke_source
            or token in differential_source or token in worker_source,
            f"pointer negative evidence is missing: {negative}",
        )

    return {
        "version": contract["version"],
        "status": contract["status"],
        "target_count": len(
            registry["phase14_primitive_layout"]["declared_targets"]
        ),
        "pointer_type_count": contract["pointer_type_count_per_target"],
        "operation_kind_count": len(contract["operation_kinds"]),
        "operation_count": contract["operation_count_per_target"],
        "migrated_count": len(contract["migrated_entry_ids"]),
        "deferred_count": sum(
            1 for entry in rows.values()
            if entry["status"] == "candidate_deferred"
        ),
        "primary_target": contract["primary_level2_target"],
        "family": contract["focused_ci_family"],
    }


def verify_phase14_stack_slots(registry):
    verify_phase14_pointers(registry)
    contract = validate_phase14_stack_slot_structure(registry)
    require(
        registry["registry_status"] == "phase14_string_views_ready",
        "Phase 14 registry is not at the stack-slot checkpoint",
    )
    rows = {entry["id"]: entry for entry in phase_entries(registry, "phase14")}
    for entry_id in PHASE14_STACK_SLOT_MIGRATED_IDS:
        entry = rows[entry_id]
        require(
            entry["status"] == "migrated"
            and entry["route_owner"] == "generic_canonical_mir"
            and entry["closure_version"] == PHASE14_STACK_SLOT_VERSION,
            f"{entry_id}: stack-slot row is not migrated",
        )
        require(
            entry["ci_family"] == contract["focused_ci_family"],
            f"{entry_id}: stack-slot CI ownership drifted",
        )
    selected_ids = (
        PHASE14_PRIMITIVE_MIGRATED_IDS
        + PHASE14_CONVERSION_MIGRATED_IDS
        + PHASE14_POINTER_MIGRATED_IDS
        + PHASE14_STACK_SLOT_MIGRATED_IDS
        + PHASE14_MEMORY_ACCESS_MIGRATED_IDS
        + PHASE14_STRING_VIEW_MIGRATED_IDS
        + PHASE14_ARRAY_SLICE_MIGRATED_IDS
        + PHASE14_STRUCT_MIGRATED_IDS
        + PHASE14_ENUM_MIGRATED_IDS
        + PHASE14_AGGREGATE_MIGRATED_IDS
    )
    for entry_id, entry in rows.items():
        if entry_id in selected_ids:
            continue
        require(
            entry["status"] == "candidate_deferred"
            and entry["route_owner"] == "deferred"
            and entry["current_failure_stage"] == "before_driver_discovery",
            f"{entry_id}: Patch 14.5 migrated an out-of-scope capability",
        )

    sources = {
        "authority": ROOT / "compiler/mir_stack_slot.gst",
        "mir": ROOT / "compiler/mir.gst",
        "request": ROOT / "compiler/mir_native_backend_request.gst",
        "mir_to_c": ROOT / "compiler/mir_stack_slot_mir_to_c.gst",
        "diagnostics": ROOT / "compiler/mir_stack_slot_diagnostics.gst",
        "worker": ROOT / "compiler/experiments/cranelift/src/main.rs",
        "smoke": ROOT / "compiler/mir_stack_slot_smoke_test_entry.gst",
        "differential": ROOT / "scripts/phase14_stack_slot_differential.sh",
        "positive": ROOT / "compiler/phase14_stack_slot_addressable_source.gst",
        "aggregate": ROOT / "compiler/phase14_stack_slot_aggregate_source.gst",
        "composition": ROOT / "compiler/phase14_stack_slot_composition_source.gst",
        "fixture": ROOT / "compiler/fixtures/native_backend_phase14_stack_slot_ingestion.mir",
        "malformed": ROOT / "compiler/fixtures/native_backend_phase14_stack_slot_malformed.mir",
    }
    for owner, path in sources.items():
        require(
            path.is_file() and not path.is_symlink(),
            f"missing regular Phase 14 stack-slot {owner} source: {path.relative_to(ROOT)}",
        )

    authority_source = sources["authority"].read_text(encoding="utf-8")
    for token in (
        "type MirStackSlot[ctx] struct",
        "type MirStackSlotOperation[ctx] struct",
        "func mir_stack_slot_local_storage_class(",
        "type MirStackSlotTable[ctx] struct",
        "func mir_stack_slot_table_for_layout(",
        "func mir_stack_slot_table_is_valid(",
        "func mir_stack_slot_rejection(",
        "func mir_serialize_stack_slot_table_for_request(",
        "func mir_stack_slot_witness(",
        PHASE14_STACK_SLOT_TABLE_FORMAT,
        "stack_slot:v1:target=",
    ):
        require(token in authority_source,
                f"stack-slot authority is missing: {token}")
    for storage_class in PHASE14_STACK_SLOT_STORAGE_CLASSES[1:]:
        require(storage_class in authority_source,
                f"stack-slot authority is missing storage class {storage_class}")
    for kind in PHASE14_STACK_SLOT_OPERATION_KINDS:
        require(kind in authority_source,
                f"stack-slot authority is missing canonical kind {kind}")
    for field in PHASE14_STACK_SLOT_METADATA_FIELDS:
        require(field in authority_source,
                f"stack-slot authority is missing metadata field {field}")
    for negative in PHASE14_STACK_SLOT_NEGATIVE_CLASSES:
        token = {
            "under_aligned_slot": "stack_slot_under_aligned",
            "invalid_lifetime": "stack_slot_lifetime_invalid",
            "escaping_address": "stack_slot_address_escape_unsupported",
            "layout_id_mismatch": "stack_slot_layout_id_mismatch",
            "dynamic_stack_allocation": "stack_slot_dynamic_allocation_unsupported",
            "variable_sized_slot": "stack_slot_variable_size_unsupported",
            "resource_bearing_local": "stack_slot_resource_destructor_deferred",
            "unsupported_aliasing": "stack_slot_aliasing_unsupported",
            "uninitialized_read": "stack_slot_uninitialized_read",
            "duplicate_slot": "stack_slot_duplicate_identity",
            "wrong_slot_type": "stack_slot_type_mismatch",
        }[negative]
        require(token in authority_source,
                f"stack-slot negative evidence is missing: {negative}")

    mir_source = sources["mir"].read_text(encoding="utf-8")
    for token in (
        "type MirStackSlotOperationKind enum",
        "type MirStackSlotReference",
        "type MirStackSlotOperationReference",
        "stack_slot_references",
        "stack_slot_operation_references",
        "StackSlotOperation",
        "func mir_make_stmt_stack_slot_operation(",
        "func mir_program_stack_slot_references_are_valid(",
    ):
        require(token in mir_source,
                f"canonical MIR stack-slot model is missing: {token}")
    require(
        "operation: Index[MirStackSlotOperationReference[ctx], ctx]" in mir_source,
        "canonical MIR stack-slot operation must arena-index its reference payload",
    )

    request_source = sources["request"].read_text(encoding="utf-8")
    require(
        "stack_slot_table: stack_slot.MirStackSlotTable[ctx]" in request_source
        and "mir_serialize_stack_slot_table_for_request" in request_source
        and "mir_stack_slot_table_for_layout" in request_source,
        "native request does not carry the compiler-owned stack-slot table",
    )

    c_source = sources["mir_to_c"].read_text(encoding="utf-8")
    for token in (
        "mir_stack_slot_c_source",
        "int *address = &addressable",
        "struct GustPairI32",
        "aggregate_copy = aggregate",
        "for (int i = 0; i < 5; ++i)",
    ):
        require(token in c_source,
                f"MIR-to-C stack-slot witness is missing: {token}")
    for banned in ("alloca(", "malloc(", "realloc(", "longjmp("):
        require(banned not in c_source,
                f"MIR-to-C stack-slot witness opened unsupported behavior: {banned}")

    diagnostic_source = sources["diagnostics"].read_text(encoding="utf-8")
    for token in (
        "gust_stack_slot_diagnostic:",
        "taxonomy=gust.stack_slot.diagnostic.v1",
        "reason_code=",
        "source=",
        "line=",
        "column=",
    ):
        require(token in diagnostic_source,
                f"stack-slot diagnostics are missing: {token}")

    worker_source = sources["worker"].read_text(encoding="utf-8")
    for token in (
        "struct Phase14RequestStackSlotTable",
        "fn parse_phase14_request_stack_slot_table(",
        "fn validate_phase14_request_stack_slot_table(",
        "phase14-stack-slot-witness",
        "slot.contained_layout_id",
        "layout.layout_id == slot.contained_layout_id",
    ):
        require(token in worker_source,
                f"Cranelift stack-slot consumption is missing: {token}")
    for banned in (
        "source_origin.contains(", "lifetime_region.contains(",
        "contained_type_id.contains(\"i32\")",
    ):
        require(banned not in worker_source,
                f"worker must not infer stack-slot layout from source text or names: {banned}")

    smoke_source = sources["smoke"].read_text(encoding="utf-8")
    differential_source = sources["differential"].read_text(encoding="utf-8")
    for context in PHASE14_STACK_SLOT_CONTEXTS:
        token = {
            "addressable_scalars": "addressable",
            "initial_aggregates": "aggregate",
            "branches": "branch",
            "supported_loops": "loop",
        }[context]
        require(token in authority_source or token in smoke_source
                or token in differential_source,
                f"stack-slot composition evidence is missing: {context}")

    return {
        "version": contract["version"],
        "status": contract["status"],
        "target_count": len(
            registry["phase14_primitive_layout"]["declared_targets"]
        ),
        "slot_count": contract["selected_slot_count_per_target"],
        "operation_kind_count": len(contract["operation_kinds"]),
        "operation_count": contract["operation_count_per_target"],
        "migrated_count": len(contract["migrated_entry_ids"]),
        "deferred_count": sum(
            1 for entry in rows.values()
            if entry["status"] == "candidate_deferred"
        ),
        "primary_target": contract["primary_level2_target"],
        "family": contract["focused_ci_family"],
    }


def verify_phase14_memory_accesses(registry):
    verify_phase14_stack_slots(registry)
    contract = validate_phase14_memory_access_structure(registry)
    require(
        registry["registry_status"] == "phase14_string_views_ready",
        "Phase 14 registry is not at the typed memory-access checkpoint",
    )
    rows = {entry["id"]: entry for entry in phase_entries(registry, "phase14")}
    for entry_id in PHASE14_MEMORY_ACCESS_MIGRATED_IDS:
        entry = rows[entry_id]
        require(
            entry["status"] == "migrated"
            and entry["route_owner"] == "generic_canonical_mir"
            and entry["closure_version"] == PHASE14_MEMORY_ACCESS_VERSION,
            f"{entry_id}: memory-access row is not migrated",
        )
        require(
            entry["ci_family"] == contract["focused_ci_family"],
            f"{entry_id}: memory-access CI ownership drifted",
        )

    sources = {
        "authority": ROOT / "compiler/mir_memory_access.gst",
        "mir": ROOT / "compiler/mir.gst",
        "request": ROOT / "compiler/mir_native_backend_request.gst",
        "mir_to_c": ROOT / "compiler/mir_memory_access_mir_to_c.gst",
        "diagnostics": ROOT / "compiler/mir_memory_access_diagnostics.gst",
        "worker": ROOT / "compiler/experiments/cranelift/src/main.rs",
        "smoke": ROOT / "compiler/mir_memory_access_smoke_test_entry.gst",
        "differential": ROOT / "scripts/phase14_memory_access_differential.sh",
        "positive": ROOT / "compiler/phase14_typed_memory_access_source.gst",
        "composition": ROOT / "compiler/phase14_typed_memory_access_composition_source.gst",
        "fixture": ROOT / "compiler/fixtures/native_backend_phase14_memory_access_ingestion.mir",
        "malformed": ROOT / "compiler/fixtures/native_backend_phase14_memory_access_malformed.mir",
        "review": ROOT / "compiler/CRANELIFT_PHASE14_MEMORY_ACCESS.md",
    }
    for negative in PHASE14_MEMORY_ACCESS_NEGATIVE_CLASSES:
        sources[f"negative_{negative}"] = (
            ROOT / f"compiler/p14_memory_access_{negative}_source.gst"
        )
    for owner, path in sources.items():
        require(
            path.is_file() and not path.is_symlink(),
            f"missing regular Phase 14 memory-access {owner} source: {path.relative_to(ROOT)}",
        )

    authority_source = sources["authority"].read_text(encoding="utf-8")
    for token in (
        "type MirMemoryAccessOperation[ctx] struct",
        "type MirMemoryAccessTable[ctx] struct",
        "func mir_memory_access_table_for_memory_tables(",
        "func mir_memory_access_table_is_valid(",
        "func mir_memory_access_rejection(",
        "func mir_serialize_memory_access_table_for_request(",
        "func mir_memory_access_witness(",
        PHASE14_MEMORY_ACCESS_TABLE_FORMAT,
    ):
        require(token in authority_source,
                f"memory-access authority is missing: {token}")
    for kind in PHASE14_MEMORY_ACCESS_OPERATION_KINDS:
        require(kind in authority_source,
                f"memory-access authority is missing canonical kind {kind}")
    for field in PHASE14_MEMORY_ACCESS_METADATA_FIELDS:
        require(field in authority_source,
                f"memory-access authority is missing metadata field {field}")
    negative_tokens = {
        "wrong_width": "memory_access_width_mismatch",
        "wrong_alignment": "memory_access_alignment_mismatch",
        "wrong_pointee_type": "memory_access_pointee_type_mismatch",
        "immutable_store": "memory_access_store_immutable",
        "invalid_layout_id": "memory_access_layout_id_mismatch",
        "out_of_lifetime": "memory_access_out_of_lifetime",
        "unsupported_overlap": "memory_access_overlap_unsupported",
        "known_null": "memory_access_known_null",
        "read_before_write": "memory_access_read_before_write",
        "unaligned": "memory_access_unaligned_unsupported",
        "zero_sized": "memory_access_zero_sized_unsupported",
    }
    for negative, token in negative_tokens.items():
        require(token in authority_source or token in sources["worker"].read_text(encoding="utf-8"),
                f"memory-access negative evidence is missing: {negative}")

    mir_source = sources["mir"].read_text(encoding="utf-8")
    for token in (
        "type MirMemoryAccessOperationKind enum",
        "type MirMemoryAccessReference",
        "memory_access_references",
        "MemoryAccess",
        "func mir_make_stmt_memory_access(",
        "func mir_program_memory_access_references_are_valid(",
    ):
        require(token in mir_source,
                f"canonical MIR memory-access model is missing: {token}")

    request_source = sources["request"].read_text(encoding="utf-8")
    require(
        "memory_access_table: memory_access.MirMemoryAccessTable[ctx]" in request_source
        and "func mir_native_backend_make_request_with_typed_memory_tables(" in request_source
        and "request.memory_access_table = memory_access_table;" in request_source
        and "mir_serialize_memory_access_table_for_request" in request_source,
        "native request does not carry the compiler-owned memory-access table",
    )

    c_source = sources["mir_to_c"].read_text(encoding="utf-8")
    for token in (
        "mir_memory_access_c_source",
        "memcpy",
        "int32_t",
        "mir_memory_access_witness",
    ):
        require(token in c_source,
                f"MIR-to-C memory-access witness is missing: {token}")

    diagnostic_source = sources["diagnostics"].read_text(encoding="utf-8")
    for token in (
        "gust_memory_access_diagnostic:",
        "taxonomy=gust.memory_access.diagnostic.v1",
        "reason_code=", "source=", "line=", "column=",
    ):
        require(token in diagnostic_source,
                f"memory-access diagnostics are missing: {token}")

    worker_source = sources["worker"].read_text(encoding="utf-8")
    for token in (
        "struct Phase14RequestMemoryAccessTable",
        "fn parse_phase14_request_memory_access_table(",
        "fn validate_phase14_request_memory_access_table(",
        "fn phase14_cranelift_memory_access_type(",
        "phase14-memory-access-witness",
    ):
        require(token in worker_source,
                f"Cranelift memory-access consumption is missing: {token}")
    for banned in (
        "std::mem::size_of", "std::mem::align_of", "offset_of!",
        "Layout::from_size_align",
    ):
        require(banned not in worker_source,
                f"worker must consume compiler-selected memory layout: {banned}")

    differential_source = sources["differential"].read_text(encoding="utf-8")
    for token in (
        "GUST_PHASE14_MEMORY_ACCESS_POISON_MARKER", "sentinel",
        "phase14-memory-access-witness",
        "Cranelift memory-access witness differs",
        "MIR-to-C memory-access witness differs",
    ):
        require(token in differential_source,
                f"memory-access differential evidence is missing: {token}")

    return {
        "version": contract["version"],
        "status": contract["status"],
        "target_count": len(registry["phase14_primitive_layout"]["declared_targets"]),
        "type_count": len(contract["selected_type_ids"]),
        "operation_kind_count": len(contract["operation_kinds"]),
        "operation_count": contract["operation_count_per_target"],
        "migrated_count": len(contract["migrated_entry_ids"]),
        "deferred_count": sum(
            1 for entry in rows.values()
            if entry["status"] == "candidate_deferred"
        ),
        "primary_target": contract["primary_level2_target"],
        "family": contract["focused_ci_family"],
    }



def verify_phase14_string_views(registry):
    verify_phase14_memory_accesses(registry)
    contract = validate_phase14_string_view_structure(registry)
    require(
        registry["registry_status"] == "phase14_string_views_ready",
        "Phase 14 registry is not at the string-view checkpoint",
    )
    rows = {entry["id"]: entry for entry in phase_entries(registry, "phase14")}
    for entry_id in PHASE14_STRING_VIEW_MIGRATED_IDS:
        entry = rows[entry_id]
        require(
            entry["status"] == "migrated"
            and entry["route_owner"] == "generic_canonical_mir"
            and entry["closure_version"] == PHASE14_STRING_VIEW_VERSION,
            f"{entry_id}: string-view row is not migrated",
        )
        require(entry["ci_family"] == contract["focused_ci_family"],
                f"{entry_id}: string-view CI ownership drifted")

    sources = {
        "authority": ROOT / "compiler/mir_string_view.gst",
        "mir": ROOT / "compiler/mir.gst",
        "request": ROOT / "compiler/mir_native_backend_request.gst",
        "mir_to_c": ROOT / "compiler/mir_string_view_mir_to_c.gst",
        "diagnostics": ROOT / "compiler/mir_string_view_diagnostics.gst",
        "worker": ROOT / "compiler/experiments/cranelift/src/main.rs",
        "smoke": ROOT / "compiler/mir_string_view_smoke_test_entry.gst",
        "differential": ROOT / "scripts/phase14_string_view_differential.sh",
        "positive": ROOT / "compiler/phase14_string_view_source.gst",
        "composition": ROOT / "compiler/phase14_string_view_composition_source.gst",
        "fixture": ROOT / "compiler/fixtures/native_backend_phase14_string_view_ingestion.mir",
        "malformed": ROOT / "compiler/fixtures/native_backend_phase14_string_view_malformed.mir",
        "review": ROOT / "compiler/CRANELIFT_PHASE14_STRING_VIEWS.md",
    }
    negative_paths = {
        "invalid_pointer_length_pair": "p14_string_view_invalid_pointer_length_source.gst",
        "lifetime_escape": "p14_string_view_lifetime_escape_source.gst",
        "unsupported_mutation": "p14_string_mutation_unsupported_source.gst",
        "unsupported_allocation": "p14_string_allocation_unsupported_source.gst",
        "unsupported_concatenation": "p14_string_concatenation_unsupported_source.gst",
        "invalid_encoding": "p14_string_invalid_encoding_source.gst",
        "out_of_bounds_view": "p14_string_view_out_of_bounds_source.gst",
        "null_empty_view": "p14_string_view_null_empty_source.gst",
        "literal_identity_mismatch": "p14_string_literal_identity_mismatch_source.gst",
    }
    for name, filename in negative_paths.items():
        sources[f"negative_{name}"] = ROOT / "compiler" / filename
    for owner, path in sources.items():
        require(path.is_file() and not path.is_symlink(),
                f"missing regular Phase 14 string-view {owner} source: {path.relative_to(ROOT)}")

    authority_source = sources["authority"].read_text(encoding="utf-8")
    for token in (
        "type MirStringLiteralStorage[ctx] struct",
        "type MirStringViewLayout[ctx] struct",
        "type MirStringView[ctx] struct",
        "type MirStringViewOperation[ctx] struct",
        "type MirStringViewTable[ctx] struct",
        "func mir_string_view_table_for_layout(",
        "func mir_string_view_table_is_valid(",
        "func mir_string_view_rejection(",
        "func mir_serialize_string_view_table_for_request(",
        "func mir_string_view_witness(",
        PHASE14_STRING_VIEW_TABLE_FORMAT,
        "explicit_byte_length_not_nul_termination",
        "valid_data_byte_not_terminator",
    ):
        require(token in authority_source,
                f"string-view authority is missing: {token}")
    for kind in PHASE14_STRING_VIEW_OPERATION_KINDS:
        require(kind in authority_source,
                f"string-view authority is missing canonical kind {kind}")
    negative_tokens = {
        "invalid_pointer_length_pair": "string_view_null_nonempty",
        "lifetime_escape": "string_view_lifetime_escape",
        "unsupported_mutation": "string_mutation_unsupported",
        "unsupported_allocation": "string_allocation_unsupported",
        "unsupported_concatenation": "string_concatenation_unsupported",
        "invalid_encoding": "string_encoding_invalid",
        "out_of_bounds_view": "string_view_out_of_bounds",
        "null_empty_view": "string_view_empty_pointer_must_be_non_null",
        "literal_identity_mismatch": "string_literal_identity_mismatch",
    }
    worker_source = sources["worker"].read_text(encoding="utf-8")
    for negative, token in negative_tokens.items():
        require(token in authority_source or token in worker_source,
                f"string-view negative evidence is missing: {negative}")

    mir_source = sources["mir"].read_text(encoding="utf-8")
    for token in (
        "type MirStringViewOperationKind enum",
        "type MirStringLiteralReference",
        "type MirStringViewReference",
        "type MirStringViewOperationReference",
        "string_literal_references", "string_view_references",
        "StringViewOperation",
        "func mir_program_string_view_references_are_valid(",
    ):
        require(token in mir_source,
                f"canonical MIR string-view model is missing: {token}")

    request_source = sources["request"].read_text(encoding="utf-8")
    require(
        "string_view_table: string_view.MirStringViewTable[ctx]" in request_source
        and "func mir_native_backend_make_request_with_string_view_table(" in request_source
        and "request.string_view_table = string_view_table;" in request_source
        and "mir_serialize_string_view_table_for_request" in request_source,
        "native request does not carry the compiler-owned string-view table",
    )

    c_source = sources["mir_to_c"].read_text(encoding="utf-8")
    for token in (
        "mir_string_view_c_source", "GustStringView", "size_t length",
        "memcmp", "mir_string_view_table_is_valid",
    ):
        require(token in c_source,
                f"MIR-to-C string-view witness is missing: {token}")

    diagnostic_source = sources["diagnostics"].read_text(encoding="utf-8")
    for token in (
        "gust_string_view_diagnostic:",
        "taxonomy=gust.string_view.diagnostic.v1",
        "reason_code=", "source=", "line=", "column=",
    ):
        require(token in diagnostic_source,
                f"string-view diagnostics are missing: {token}")

    for token in (
        "struct Phase14RequestStringViewTable",
        "fn parse_phase14_request_string_view_table(",
        "fn validate_phase14_request_string_view_table(",
        "fn phase14_string_view_witness_text(",
        "phase14-string-view-witness",
    ):
        require(token in worker_source,
                f"Cranelift string-view consumption is missing: {token}")
    for banned in ("CStr", "CString", "strlen("):
        require(banned not in worker_source,
                f"worker must not use accidental C-string authority: {banned}")

    differential_source = sources["differential"].read_text(encoding="utf-8")
    for token in (
        "GUST_PHASE14_STRING_VIEW_POISON_MARKER", "sentinel",
        "phase14-string-view-witness",
        "Cranelift string-view witness differs",
        "MIR-to-C string-view witness differs",
        "610062",
    ):
        require(token in differential_source,
                f"string-view differential evidence is missing: {token}")

    return {
        "version": contract["version"],
        "status": contract["status"],
        "target_count": len(registry["phase14_primitive_layout"]["declared_targets"]),
        "literal_count": contract["literal_count_per_target"],
        "view_count": contract["view_count_per_target"],
        "operation_kind_count": len(contract["operation_kinds"]),
        "operation_count": contract["operation_count_per_target"],
        "migrated_count": len(contract["migrated_entry_ids"]),
        "deferred_count": sum(1 for entry in rows.values()
                              if entry["status"] == "candidate_deferred"),
        "primary_target": contract["primary_level2_target"],
        "family": contract["focused_ci_family"],
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
        and entry.get("origin_phase") in {"phase11", "phase13"}
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
        entry["ci_family"] for entry in phase_entries(registry, "phase11")
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
                f"{case_id}: composition case owner must be a migrated Phase 13 row",
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
            "phase14_primitive_layout_ready",
            "phase14_integer_conversion_ready",
            "phase14_stack_slot_ready",
            "phase14_string_views_ready",
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
        f"- Phase 14 opening rows still deferred: `{contract['deferred_row_count']}`",
        "",
        "Patch 14.1 established authority and transport. Patches 14.2 through 14.6 consume that authority for declared targets, primitives, conversions, pointers, stack slots, and bounded typed memory access.",
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
        "Patch 14.6 consumes this authority for bounded typed i32 loads, stores, compiler-derived element offsets, and non-overlapping copies. Strings, arrays, structs, enums, broader aggregates, and unsupported memory forms remain deferred for bounded later patches.",
        "",
    ]
    rendered = "\n".join(lines)
    for banned in ("SHA256", "SHA-256", "sha256sum"):
        require(
            banned not in rendered,
            f"Phase 14 layout authority view contains banned raw-hash token: {banned}",
        )
    return rendered


def phase14_primitive_layout_summary_lines(registry):
    contract = verify_phase14_primitive_layout(registry)
    return [
        "## Phase 14 declared targets and primitive scalar layouts",
        "",
        f"- Contract version: `{contract['version']}`",
        f"- Status: `{contract['status']}`",
        f"- Declared host targets: `{contract['target_count']}`",
        f"- Primitive scalar types: `{contract['primitive_count']}`",
        f"- Migrated opening rows: `{contract['migrated_count']}`",
        f"- Remaining deferred opening rows: `{contract['deferred_count']}`",
        f"- Primary Level 2 target: `{contract['primary_target']}`",
        f"- Registry-derived focused family: `{contract['family']}`",
        "",
        "Patch 14.2 freezes target-aware primitive representation. Patch 14.3 consumes those layouts for explicit signed, unsigned, and width-conversion semantics.",
        "",
    ]


def render_phase14_primitive_layout(registry):
    summary = verify_phase14_primitive_layout(registry)
    contract = registry["phase14_primitive_layout"]
    lines = [
        "# Cranelift Phase 14 Declared Targets and Primitive Scalar Layouts",
        "",
        "<!-- Generated by scripts/cranelift_registry.py; do not edit by hand. -->",
        "",
        "CRANELIFT_PHASE14_PRIMITIVE_LAYOUT_VIEW_VERSION: 1",
        f"CRANELIFT_PHASE14_PRIMITIVE_LAYOUT_VERSION: {summary['version']}",
        f"CRANELIFT_PHASE14_PRIMITIVE_LAYOUT_STATUS: {summary['status']}",
        f"CRANELIFT_PHASE14_PRIMITIVE_LAYOUT_OWNER: {contract['authority_owner']}",
        f"CRANELIFT_PHASE14_PRIMITIVE_LAYOUT_TABLE_FORMAT: {contract['layout_table_format']}",
        f"CRANELIFT_PHASE14_PRIMITIVE_LAYOUT_PRIMARY_TARGET: {summary['primary_target']}",
        f"CRANELIFT_PHASE14_PRIMITIVE_LAYOUT_LEVEL1_GUARD: {contract['level1_guard']}",
        f"CRANELIFT_PHASE14_PRIMITIVE_LAYOUT_LEVEL2_GUARD: {contract['level2_guard']}",
        f"CRANELIFT_PHASE14_PRIMITIVE_LAYOUT_NEXT_PATCH: {contract['next_patch']}",
        "",
        "## Declared host targets",
        "",
        "| Target | Object format | Endian | Pointer size/alignment | i32 alignment | i64 alignment | Maximum aggregate alignment | Aliases |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for target in contract["declared_targets"]:
        lines.append(
            "| " + " | ".join(
                cell(value)
                for value in (
                    target["target_triple"],
                    target["object_format"],
                    target["endianness"],
                    f"{target['pointer_size']}/{target['pointer_alignment']}",
                    target["i32_alignment"],
                    target["i64_alignment"],
                    target["max_aggregate_alignment"],
                    ", ".join(target["aliases"]),
                )
            ) + " |"
        )
    lines += [
        "",
        "## Primitive scalar inventory",
        "",
        "| Type | Identity | Representation | Size | Alignment | Width | Signedness | Validity |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for primitive in contract["primitive_types"]:
        lines.append(
            "| " + " | ".join(
                cell(primitive[field])
                for field in (
                    "source_name", "type_id", "representation_kind",
                    "size_policy", "alignment_policy", "bit_width_policy",
                    "signedness", "validity_kind",
                )
            ) + " |"
        )
    lines += [
        "",
        "## Migrated opening rows",
        "",
        *[f"- `{entry_id}`" for entry_id in contract["migrated_entry_ids"]],
        "",
        "## Negative classes",
        "",
        *[f"- `{name}`" for name in contract["negative_classes"]],
        "",
        "## Boundary",
        "",
        contract["witness_policy"],
        "",
        contract["boundary_policy"],
        "",
        "Canonical boolean memory values are exactly `0` and `1`. Patch 14.6 now owns bounded typed i32 memory access over compiler-owned pointers and stack slots; strings, arrays, structs, enums, broader aggregates, and unsupported memory forms remain deferred.",
        "",
    ]
    rendered = "\n".join(lines)
    for banned in ("SHA256", "SHA-256", "sha256sum"):
        require(banned not in rendered,
                f"Phase 14 primitive layout view contains banned raw-hash token: {banned}")
    return rendered


def phase14_integer_conversion_summary_lines(registry):
    contract = verify_phase14_integer_conversions(registry)
    return [
        "## Phase 14 signed, unsigned, and width-conversion rules",
        "",
        f"- Contract version: `{contract['version']}`",
        f"- Status: `{contract['status']}`",
        f"- Declared target count: `{contract['target_count']}`",
        f"- Canonical conversion kinds: `{contract['kind_count']}`",
        f"- Selected conversion rules per target: `{contract['rule_count']}`",
        f"- Migrated opening rows: `{contract['migrated_count']}`",
        f"- Remaining deferred opening rows: `{contract['deferred_count']}`",
        f"- Registry-derived focused family: `{contract['family']}`",
        "",
        "Patch 14.3 freezes explicit integer conversion operations for constant folding and runtime lowering. Patch 14.4 consumes that authority for bounded typed pointers while unrestricted pointer/integer and floating-point conversions remain deferred.",
        "",
    ]


def render_phase14_integer_conversions(registry):
    summary = verify_phase14_integer_conversions(registry)
    contract = registry["phase14_integer_conversions"]
    lines = [
        "# Cranelift Phase 14 Signed, Unsigned, and Width-Conversion Rules",
        "",
        "<!-- Generated by scripts/cranelift_registry.py; do not edit by hand. -->",
        "",
        "CRANELIFT_PHASE14_INTEGER_CONVERSION_VIEW_VERSION: 1",
        f"CRANELIFT_PHASE14_INTEGER_CONVERSION_VERSION: {summary['version']}",
        f"CRANELIFT_PHASE14_INTEGER_CONVERSION_STATUS: {summary['status']}",
        f"CRANELIFT_PHASE14_INTEGER_CONVERSION_OWNER: {contract['authority_owner']}",
        f"CRANELIFT_PHASE14_INTEGER_CONVERSION_TABLE_FORMAT: {contract['conversion_table_format']}",
        f"CRANELIFT_PHASE14_INTEGER_CONVERSION_LEVEL1_GUARD: {contract['level1_guard']}",
        f"CRANELIFT_PHASE14_INTEGER_CONVERSION_LEVEL2_GUARD: {contract['level2_guard']}",
        f"CRANELIFT_PHASE14_INTEGER_CONVERSION_NEXT_PATCH: {contract['next_patch']}",
        "",
        "## Declared source forms",
        "",
        *[f"- `{name}`" for name in contract["source_conversion_forms"]],
        "",
        "## Canonical conversion kinds",
        "",
        *[f"- `{name}`" for name in contract["conversion_kinds"]],
        "",
        "## Selected target-aware rules",
        "",
        "| Rule | Kind | Source | Destination | Source width | Destination width | Policy | Failure reason | Target applicability |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for rule in contract["selected_rules"]:
        lines.append(
            "| " + " | ".join(
                cell(rule[field])
                for field in (
                    "rule_name", "conversion_kind", "source_type_id",
                    "destination_type_id", "source_width_policy",
                    "destination_width_policy", "policy",
                    "failure_reason_code", "target_applicability",
                )
            ) + " |"
        )
    lines += [
        "",
        "## Diagnostic fields",
        "",
        *[f"- `{field}`" for field in contract["diagnostic_fields"]],
        "",
        "## Composition contexts",
        "",
        *[f"- `{context}`" for context in contract["composition_contexts"]],
        "",
        "## Negative classes",
        "",
        *[f"- `{name}`" for name in contract["negative_classes"]],
        "",
        "## Semantic policies",
        "",
        f"- Constant folding: `{contract['constant_folding_policy']}`",
        f"- Runtime lowering: `{contract['runtime_policy']}`",
        f"- Out of range: `{contract['out_of_range_policy']}`",
        f"- Negative to unsigned: `{contract['negative_to_unsigned_policy']}`",
        f"- Unsigned to signed: `{contract['unsigned_to_signed_policy']}`",
        f"- Pointer-sized widths: `{contract['pointer_sized_policy']}`",
        "",
        "## Boundary",
        "",
        contract["boundary_policy"],
        "",
        "MIR-to-C and Cranelift consume the same compiler-selected conversion kind, widths, signedness, policy, target identity, and stable reason codes. Neither backend is the semantic authority.",
        "",
    ]
    rendered = "\n".join(lines)
    for banned in ("SHA256", "SHA-256", "sha256sum"):
        require(
            banned not in rendered,
            f"Phase 14 integer conversion view contains banned raw-hash token: {banned}",
        )
    return rendered



def phase14_pointer_summary_lines(registry):
    contract = verify_phase14_pointers(registry)
    return [
        "## Phase 14 bounded typed pointers and nullability",
        "",
        f"- Contract version: `{contract['version']}`",
        f"- Status: `{contract['status']}`",
        f"- Declared target count: `{contract['target_count']}`",
        f"- Pointer types per target: `{contract['pointer_type_count']}`",
        f"- Canonical pointer operation kinds: `{contract['operation_kind_count']}`",
        f"- Selected pointer operations per target: `{contract['operation_count']}`",
        f"- Migrated opening rows: `{contract['migrated_count']}`",
        f"- Remaining deferred opening rows: `{contract['deferred_count']}`",
        f"- Registry-derived focused family: `{contract['family']}`",
        "",
        "Patch 14.4 freezes bounded typed pointer identity, default-address-space metadata, provenance, nullability checks, comparisons, and safe aggregate storage. Patch 14.6 selects naturally aligned non-null i32 loads and stores; broader dereference, pointer arithmetic, unrestricted integer/pointer casts, non-default address spaces, and unsupported pointees remain rejected or deferred before worker access.",
        "",
    ]


def phase14_stack_slot_summary_lines(registry):
    contract = verify_phase14_stack_slots(registry)
    return [
        "## Phase 14 deterministic stack slots and addressable locals",
        "",
        f"- Contract version: `{contract['version']}`",
        f"- Status: `{contract['status']}`",
        f"- Declared target count: `{contract['target_count']}`",
        f"- Selected slots per target: `{contract['slot_count']}`",
        f"- Canonical operation kinds: `{contract['operation_kind_count']}`",
        f"- Selected operations per target: `{contract['operation_count']}`",
        f"- Migrated opening rows: `{contract['migrated_count']}`",
        f"- Remaining deferred opening rows: `{contract['deferred_count']}`",
        f"- Registry-derived focused family: `{contract['family']}`",
        "",
        "Patch 14.5 freezes deterministic compiler-owned stack-slot identities, layout-derived size and alignment, initialization and lifetime validation, address acquisition, assignment, and bounded aggregate copies. Patch 14.6 consumes those slots for selected typed memory operations; dynamic allocation, variable-sized slots, escaping addresses, destructor-bearing resources, and unsupported aliasing remain rejected or deferred before driver access.",
        "",
    ]


def render_phase14_stack_slots(registry):
    summary = verify_phase14_stack_slots(registry)
    contract = registry["phase14_stack_slots"]
    lines = [
        "# Cranelift Phase 14 Deterministic Stack Slots and Addressable Locals",
        "",
        "<!-- Generated by scripts/cranelift_registry.py; do not edit by hand. -->",
        "",
        "CRANELIFT_PHASE14_STACK_SLOT_VIEW_VERSION: 1",
        f"CRANELIFT_PHASE14_STACK_SLOT_VERSION: {summary['version']}",
        f"CRANELIFT_PHASE14_STACK_SLOT_STATUS: {summary['status']}",
        f"CRANELIFT_PHASE14_STACK_SLOT_OWNER: {contract['authority_owner']}",
        f"CRANELIFT_PHASE14_STACK_SLOT_TABLE_FORMAT: {contract['stack_slot_table_format']}",
        f"CRANELIFT_PHASE14_STACK_SLOT_PRIMARY_TARGET: {summary['primary_target']}",
        f"CRANELIFT_PHASE14_STACK_SLOT_LEVEL1_GUARD: {contract['level1_guard']}",
        f"CRANELIFT_PHASE14_STACK_SLOT_LEVEL2_GUARD: {contract['level2_guard']}",
        f"CRANELIFT_PHASE14_STACK_SLOT_NEXT_PATCH: {contract['next_patch']}",
        "",
        "## Storage classes",
        "",
        *[f"- `{name}`" for name in contract["storage_classes"]],
        "",
        f"Selected compiler-owned slots per target: `{contract['selected_slot_count_per_target']}`.",
        "",
        "## Canonical stack-slot operations",
        "",
        *[f"- `{kind}`" for kind in contract["operation_kinds"]],
        "",
        f"Selected operations per target: `{contract['operation_count_per_target']}`.",
        "",
        "## Compiler-owned metadata",
        "",
        *[f"- `{field}`" for field in contract["metadata_fields"]],
        "",
        "## Composition contexts",
        "",
        *[f"- `{context}`" for context in contract["composition_contexts"]],
        "",
        "## Negative classes",
        "",
        *[f"- `{name}`" for name in contract["negative_classes"]],
        "",
        "## Semantic policies",
        "",
        f"- Lifetime: `{contract['lifetime_policy']}`",
        f"- Address escape: `{contract['address_escape_policy']}`",
        f"- Worker layout consumption: `{contract['worker_layout_policy']}`",
        "",
        "## Boundary",
        "",
        contract["boundary_policy"],
        "",
        "MIR-to-C and Cranelift consume identical deterministic slot IDs, compiler-owned layout IDs, initialization states, lifetime regions, and mutability. Neither backend may infer slot layout from source text or local names.",
        "",
    ]
    rendered = "\n".join(lines)
    for banned in ("SHA256", "SHA-256", "sha256sum"):
        require(
            banned not in rendered,
            f"Phase 14 stack-slot view contains banned raw-hash token: {banned}",
        )
    return rendered


def phase14_memory_access_summary_lines(registry):
    contract = verify_phase14_memory_accesses(registry)
    return [
        "## Phase 14 typed loads, stores, and memory-access validation",
        "",
        f"- Contract version: `{contract['version']}`",
        f"- Status: `{contract['status']}`",
        f"- Declared target count: `{contract['target_count']}`",
        f"- Selected memory types: `{contract['type_count']}`",
        f"- Canonical operation kinds: `{contract['operation_kind_count']}`",
        f"- Selected operations per target: `{contract['operation_count']}`",
        f"- Migrated opening rows: `{contract['migrated_count']}`",
        f"- Remaining deferred opening rows: `{contract['deferred_count']}`",
        f"- Registry-derived focused family: `{contract['family']}`",
        "",
        "Patch 14.6 freezes bounded naturally aligned i32 loads, stores, compiler-derived element offsets, and non-overlapping copies. Unaligned, zero-sized, known-null, overlapping, atomic, volatile, and unrestricted pointer accesses remain rejected or deferred.",
        "",
    ]


def render_phase14_memory_accesses(registry):
    summary = verify_phase14_memory_accesses(registry)
    contract = registry["phase14_memory_accesses"]
    lines = [
        "# Cranelift Phase 14 Typed Loads, Stores, and Memory-Access Validation",
        "",
        "<!-- Generated by scripts/cranelift_registry.py; do not edit by hand. -->",
        "",
        "CRANELIFT_PHASE14_MEMORY_ACCESS_VIEW_VERSION: 1",
        f"CRANELIFT_PHASE14_MEMORY_ACCESS_VERSION: {summary['version']}",
        f"CRANELIFT_PHASE14_MEMORY_ACCESS_STATUS: {summary['status']}",
        f"CRANELIFT_PHASE14_MEMORY_ACCESS_OWNER: {contract['authority_owner']}",
        f"CRANELIFT_PHASE14_MEMORY_ACCESS_TABLE_FORMAT: {contract['memory_access_table_format']}",
        f"CRANELIFT_PHASE14_MEMORY_ACCESS_PRIMARY_TARGET: {summary['primary_target']}",
        f"CRANELIFT_PHASE14_MEMORY_ACCESS_LEVEL1_GUARD: {contract['level1_guard']}",
        f"CRANELIFT_PHASE14_MEMORY_ACCESS_LEVEL2_GUARD: {contract['level2_guard']}",
        f"CRANELIFT_PHASE14_MEMORY_ACCESS_NEXT_PATCH: {contract['next_patch']}",
        "",
        "## Selected types",
        "",
        *[f"- `{name}`" for name in contract["selected_type_ids"]],
        "",
        "## Canonical memory operations",
        "",
        *[f"- `{kind}`" for kind in contract["operation_kinds"]],
        "",
        f"Selected operations per target: `{contract['operation_count_per_target']}`.",
        "",
        "## Compiler-owned access metadata",
        "",
        *[f"- `{field}`" for field in contract["metadata_fields"]],
        "",
        "## Composition contexts",
        "",
        *[f"- `{context}`" for context in contract["composition_contexts"]],
        "",
        "## Negative classes",
        "",
        *[f"- `{name}`" for name in contract["negative_classes"]],
        "",
        "## Semantic policies",
        "",
        f"- Natural alignment: `{contract['natural_alignment_policy']}`",
        f"- Unaligned access: `{contract['unaligned_policy']}`",
        f"- Zero-sized values: `{contract['zero_sized_policy']}`",
        f"- Known-null access: `{contract['known_null_policy']}`",
        f"- Initialization: `{contract['initialization_policy']}`",
        f"- Overlap: `{contract['overlap_policy']}`",
        f"- Worker lowering: `{contract['worker_lowering_policy']}`",
        f"- Poisoned driver: `{contract['poisoned_driver_policy']}`",
        f"- Output preservation: `{contract['output_preservation_policy']}`",
        "",
        "## Boundary",
        "",
        contract["boundary_policy"],
        "",
        "MIR-to-C and Cranelift consume the same compiler-serialized type, layout, width, alignment, origin, lifetime, source location, and offset records. Invalid accesses are rejected before object or output publication.",
        "",
    ]
    rendered = "\n".join(lines)
    for banned in ("SHA256", "SHA-256", "sha256sum"):
        require(
            banned not in rendered,
            f"Phase 14 memory-access view contains banned raw-hash token: {banned}",
        )
    return rendered



def phase14_string_view_summary_lines(registry):
    contract = verify_phase14_string_views(registry)
    return [
        "## Phase 14 string literals and borrowed views", "",
        f"- Contract version: `{contract['version']}`",
        f"- Status: `{contract['status']}`",
        f"- Declared target count: `{contract['target_count']}`",
        f"- Literal records per target: `{contract['literal_count']}`",
        f"- Borrowed views per target: `{contract['view_count']}`",
        f"- Canonical operation kinds: `{contract['operation_kind_count']}`",
        f"- Selected operations per target: `{contract['operation_count']}`",
        f"- Migrated opening rows: `{contract['migrated_count']}`",
        f"- Remaining deferred opening rows: `{contract['deferred_count']}`",
        f"- Registry-derived focused family: `{contract['family']}`", "",
        "Patch 14.7 selects immutable UTF-8 literal storage and borrowed explicit-byte-length views, including embedded NUL data. Dynamic owning allocation, mutation, and concatenation remain narrowly deferred.", "",
    ]


def render_phase14_string_views(registry):
    summary = verify_phase14_string_views(registry)
    contract = registry["phase14_string_views"]
    lines = [
        "# Cranelift Phase 14 Strings and String Views", "",
        "<!-- Generated by scripts/cranelift_registry.py; do not edit by hand. -->", "",
        "CRANELIFT_PHASE14_STRING_VIEW_VIEW_VERSION: 1",
        f"CRANELIFT_PHASE14_STRING_VIEW_VERSION: {summary['version']}",
        f"CRANELIFT_PHASE14_STRING_VIEW_STATUS: {summary['status']}",
        f"CRANELIFT_PHASE14_STRING_VIEW_OWNER: {contract['authority_owner']}",
        f"CRANELIFT_PHASE14_STRING_VIEW_TABLE_FORMAT: {contract['string_view_table_format']}",
        f"CRANELIFT_PHASE14_STRING_VIEW_PRIMARY_TARGET: {summary['primary_target']}",
        f"CRANELIFT_PHASE14_STRING_VIEW_LEVEL1_GUARD: {contract['level1_guard']}",
        f"CRANELIFT_PHASE14_STRING_VIEW_LEVEL2_GUARD: {contract['level2_guard']}",
        f"CRANELIFT_PHASE14_STRING_VIEW_NEXT_PATCH: {contract['next_patch']}", "",
        "## Frozen inventory", "",
        f"- Source encoding: `{contract['source_encoding']}`",
        f"- Literal encoding: `{contract['literal_encoding']}`",
        f"- Embedded NUL: `{contract['embedded_nul_policy']}`",
        f"- Empty string: `{contract['empty_string_policy']}`",
        f"- Semantic length: `{contract['semantic_length_authority']}`",
        f"- Owning strings: `{contract['owning_string_policy']}`", "",
        "## Borrowed view representation", "",
        f"- Representation: `{contract['view_representation']}`",
        *[f"- Field: `{field}`" for field in contract["view_layout_fields"]], "",
        "## Canonical operations", "",
        *[f"- `{kind}`" for kind in contract["operation_kinds"]], "",
        f"Selected operations per target: `{contract['operation_count_per_target']}`.", "",
        "## Composition contexts", "",
        *[f"- `{context}`" for context in contract["composition_contexts"]], "",
        "## Negative classes", "",
        *[f"- `{name}`" for name in contract["negative_classes"]], "",
        "## Semantic policies", "",
        f"- Lifetime: `{contract['lifetime_policy']}`",
        f"- Mutation: `{contract['mutation_policy']}`",
        f"- Concatenation: `{contract['concatenation_policy']}`",
        f"- Allocation: `{contract['allocation_policy']}`",
        f"- Poisoned driver: `{contract['poisoned_driver_policy']}`",
        f"- Output preservation: `{contract['output_preservation_policy']}`", "",
        "## Boundary", "", contract["boundary_policy"], "",
        "MIR-to-C and Cranelift consume the same compiler-serialized literal bytes, static identities, pointer-sized view layout, explicit byte lengths, lifetimes, bounds, and operation records. NUL termination is never the semantic length authority.", "",
    ]
    rendered = "\n".join(lines)
    for banned in ("SHA256", "SHA-256", "sha256sum"):
        require(banned not in rendered,
                f"Phase 14 string-view view contains banned raw-hash token: {banned}")
    return rendered

def render_phase14_pointers(registry):
    summary = verify_phase14_pointers(registry)
    contract = registry["phase14_pointers"]
    lines = [
        "# Cranelift Phase 14 Bounded Typed Pointers and Nullability",
        "",
        "<!-- Generated by scripts/cranelift_registry.py; do not edit by hand. -->",
        "",
        "CRANELIFT_PHASE14_POINTER_VIEW_VERSION: 1",
        f"CRANELIFT_PHASE14_POINTER_VERSION: {summary['version']}",
        f"CRANELIFT_PHASE14_POINTER_STATUS: {summary['status']}",
        f"CRANELIFT_PHASE14_POINTER_OWNER: {contract['authority_owner']}",
        f"CRANELIFT_PHASE14_POINTER_TABLE_FORMAT: {contract['pointer_table_format']}",
        f"CRANELIFT_PHASE14_POINTER_PRIMARY_TARGET: {summary['primary_target']}",
        f"CRANELIFT_PHASE14_POINTER_LEVEL1_GUARD: {contract['level1_guard']}",
        f"CRANELIFT_PHASE14_POINTER_LEVEL2_GUARD: {contract['level2_guard']}",
        f"CRANELIFT_PHASE14_POINTER_NEXT_PATCH: {contract['next_patch']}",
        "",
        "## Pointer type metadata",
        "",
        f"- Default address space: `{contract['default_address_space']}`",
        f"- Selected pointee type IDs: `{', '.join(contract['selected_pointee_type_ids'])}`",
        f"- Mutability kinds: `{', '.join(contract['mutability_kinds'])}`",
        f"- Nullability kinds: `{', '.join(contract['nullability_kinds'])}`",
        f"- Pointer types per target: `{contract['pointer_type_count_per_target']}`",
        "- Target pointer size and alignment are copied from the compiler-owned target layout table.",
        "",
        "## Canonical pointer operations",
        "",
        *[f"- `{kind}`" for kind in contract["operation_kinds"]],
        "",
        f"Selected operations per target: `{contract['operation_count_per_target']}`.",
        "",
        "## Provenance fields",
        "",
        *[f"- `{field}`" for field in contract["provenance_fields"]],
        "",
        "## Composition contexts",
        "",
        *[f"- `{context}`" for context in contract["composition_contexts"]],
        "",
        "## Negative classes",
        "",
        *[f"- `{name}`" for name in contract["negative_classes"]],
        "",
        "## Semantic policies",
        "",
        f"- Known-null dereference: `{contract['known_null_dereference_policy']}`",
        f"- Nullable access: `{contract['nullable_access_policy']}`",
        f"- Worker layout consumption: `{contract['worker_layout_policy']}`",
        "",
        "## Boundary",
        "",
        contract["boundary_policy"],
        "",
        "The worker consumes compiler-serialized pointer and pointee layout identities. It does not infer layout from source spelling, type names, host pointer APIs, or backend defaults.",
        "",
    ]
    rendered = "\n".join(lines)
    for banned in ("SHA256", "SHA-256", "sha256sum"):
        require(
            banned not in rendered,
            f"Phase 14 pointer view contains banned raw-hash token: {banned}",
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
        *phase14_primitive_layout_summary_lines(registry),
        *phase14_integer_conversion_summary_lines(registry),
        *phase14_pointer_summary_lines(registry),
        *phase14_stack_slot_summary_lines(registry),
        *phase14_memory_access_summary_lines(registry),
        *phase14_string_view_summary_lines(registry),
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
        f"- Phase 14 layout authority review: `{phase14_layout_authority_summary_path(registry).relative_to(ROOT)}`",
        f"- Phase 14 primitive layout review: `{phase14_primitive_layout_summary_path(registry).relative_to(ROOT)}`",
        f"- Phase 14 integer conversion review: `{phase14_integer_conversion_summary_path(registry).relative_to(ROOT)}`",
        f"- Phase 14 pointer review: `{phase14_pointer_summary_path(registry).relative_to(ROOT)}`",
        f"- Phase 14 stack-slot review: `{phase14_stack_slot_summary_path(registry).relative_to(ROOT)}`",
        f"- Phase 14 memory-access review: `{phase14_memory_access_summary_path(registry).relative_to(ROOT)}`",
        f"- Phase 14 string-view review: `{phase14_string_view_summary_path(registry).relative_to(ROOT)}`", "",
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


def check_phase14_primitive_layout_projection(registry):
    check_rendered_projection(
        phase14_primitive_layout_summary_path(registry),
        render_phase14_primitive_layout(registry),
        "generated Phase 14 primitive layout review",
    )


def check_phase14_integer_conversion_projection(registry):
    check_rendered_projection(
        phase14_integer_conversion_summary_path(registry),
        render_phase14_integer_conversions(registry),
        "generated Phase 14 integer conversion review",
    )


def check_phase14_pointer_projection(registry):
    check_rendered_projection(
        phase14_pointer_summary_path(registry),
        render_phase14_pointers(registry),
        "generated Phase 14 pointer review",
    )


def check_phase14_stack_slot_projection(registry):
    check_rendered_projection(
        phase14_stack_slot_summary_path(registry),
        render_phase14_stack_slots(registry),
        "generated Phase 14 stack-slot review",
    )


def check_phase14_memory_access_projection(registry):
    check_rendered_projection(
        phase14_memory_access_summary_path(registry),
        render_phase14_memory_accesses(registry),
        "generated Phase 14 memory-access review",
    )


def check_phase14_string_view_projection(registry):
    check_rendered_projection(
        phase14_string_view_summary_path(registry),
        render_phase14_string_views(registry),
        "generated Phase 14 string-view review",
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
    check_phase14_primitive_layout_projection(registry)
    check_phase14_integer_conversion_projection(registry)
    check_phase14_pointer_projection(registry)
    check_phase14_stack_slot_projection(registry)
    check_phase14_memory_access_projection(registry)
    check_phase14_string_view_projection(registry)


def summary_path(registry):
    return ROOT / registry["legacy_views"]["generated_summary"]


def phase13_summary_path(registry):
    return ROOT / registry["legacy_views"]["phase13"]


def phase14_summary_path(registry):
    return ROOT / registry["legacy_views"]["phase14"]


def phase14_layout_authority_summary_path(registry):
    return ROOT / "compiler/CRANELIFT_PHASE14_LAYOUT_AUTHORITY.md"


def phase14_primitive_layout_summary_path(registry):
    return ROOT / "compiler/CRANELIFT_PHASE14_PRIMITIVE_LAYOUT.md"


def phase14_integer_conversion_summary_path(registry):
    return ROOT / "compiler/CRANELIFT_PHASE14_INTEGER_CONVERSIONS.md"


def phase14_pointer_summary_path(registry):
    return ROOT / "compiler/CRANELIFT_PHASE14_POINTERS.md"


def phase14_stack_slot_summary_path(registry):
    return ROOT / "compiler/CRANELIFT_PHASE14_STACK_SLOTS.md"


def phase14_memory_access_summary_path(registry):
    return ROOT / "compiler/CRANELIFT_PHASE14_MEMORY_ACCESS.md"


def phase14_string_view_summary_path(registry):
    return ROOT / "compiler/CRANELIFT_PHASE14_STRING_VIEWS.md"


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
            "verify-phase14-primitive-layout",
            "verify-phase14-integer-conversions",
            "verify-phase14-pointers",
            "verify-phase14-stack-slots",
            "verify-phase14-memory-accesses",
            "verify-phase14-string-views",
            "phase14-primitive-targets",
            "phase14-conversion-targets",
            "phase14-pointer-targets",
            "phase14-stack-slot-targets",
            "phase14-memory-access-targets",
            "phase14-string-view-targets",
            "phase14-array-slice-targets",
            "phase14-enum-targets",
            "phase14-struct-targets",
            "phase14-aggregate-targets",
            "phase14-primitive-primary-target",
            "phase14-conversion-primary-target",
            "phase14-pointer-primary-target",
            "phase14-stack-slot-primary-target",
            "phase14-memory-access-primary-target",
            "phase14-string-view-primary-target",
            "phase14-array-slice-primary-target",
            "phase14-enum-primary-target",
            "phase14-struct-primary-target",
            "phase14-aggregate-primary-target",
            "project",
            "check-phase13-projection",
            "check-phase14-projection",
            "check-phase14-layout-authority-projection",
            "check-phase14-primitive-layout-projection",
            "check-phase14-integer-conversion-projection",
            "check-phase14-pointer-projection",
            "check-phase14-stack-slot-projection",
            "check-phase14-memory-access-projection",
            "check-phase14-string-view-projection",
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
        elif command == "verify-phase14-primitive-layout":
            verify_phase14_primitive_layout(registry)
        elif command == "verify-phase14-integer-conversions":
            verify_phase14_integer_conversions(registry)
        elif command == "verify-phase14-pointers":
            verify_phase14_pointers(registry)
        elif command == "verify-phase14-stack-slots":
            verify_phase14_stack_slots(registry)
        elif command == "verify-phase14-memory-accesses":
            verify_phase14_memory_accesses(registry)
        elif command == "verify-phase14-string-views":
            verify_phase14_string_views(registry)
        elif command in {
            "phase14-primitive-targets",
            "phase14-conversion-targets",
            "phase14-pointer-targets",
            "phase14-stack-slot-targets",
            "phase14-memory-access-targets",
            "phase14-string-view-targets",
            "phase14-array-slice-targets",
            "phase14-enum-targets",
            "phase14-struct-targets",
            "phase14-aggregate-targets",
        }:
            contract = validate_phase14_primitive_layout_structure(registry)
            print("\n".join(
                target["target_triple"] for target in contract["declared_targets"]
            ))
            return 0
        elif command in {
            "phase14-primitive-primary-target",
            "phase14-conversion-primary-target",
            "phase14-pointer-primary-target",
            "phase14-stack-slot-primary-target",
            "phase14-memory-access-primary-target",
            "phase14-string-view-primary-target",
            "phase14-array-slice-primary-target",
            "phase14-enum-primary-target",
            "phase14-struct-primary-target",
            "phase14-aggregate-primary-target",
        }:
            contract = validate_phase14_primitive_layout_structure(registry)
            print(contract["primary_level2_target"])
            return 0
        elif command == "project":
            canonical_path = summary_path(registry)
            phase13_path = phase13_summary_path(registry)
            phase14_path = phase14_summary_path(registry)
            phase14_layout_path = phase14_layout_authority_summary_path(registry)
            phase14_primitive_path = phase14_primitive_layout_summary_path(registry)
            phase14_conversion_path = phase14_integer_conversion_summary_path(registry)
            phase14_pointer_path = phase14_pointer_summary_path(registry)
            phase14_stack_slot_path = phase14_stack_slot_summary_path(registry)
            phase14_memory_access_path = phase14_memory_access_summary_path(registry)
            phase14_string_view_path = phase14_string_view_summary_path(registry)
            canonical_path.parent.mkdir(parents=True, exist_ok=True)
            phase13_path.parent.mkdir(parents=True, exist_ok=True)
            phase14_path.parent.mkdir(parents=True, exist_ok=True)
            phase14_layout_path.parent.mkdir(parents=True, exist_ok=True)
            phase14_primitive_path.parent.mkdir(parents=True, exist_ok=True)
            phase14_conversion_path.parent.mkdir(parents=True, exist_ok=True)
            phase14_pointer_path.parent.mkdir(parents=True, exist_ok=True)
            phase14_stack_slot_path.parent.mkdir(parents=True, exist_ok=True)
            phase14_memory_access_path.parent.mkdir(parents=True, exist_ok=True)
            phase14_string_view_path.parent.mkdir(parents=True, exist_ok=True)
            canonical_path.write_text(render(registry), encoding="utf-8")
            phase13_path.write_text(render_phase13(registry), encoding="utf-8")
            phase14_path.write_text(render_phase14(registry), encoding="utf-8")
            phase14_layout_path.write_text(render_phase14_layout_authority(registry), encoding="utf-8")
            phase14_primitive_path.write_text(
                render_phase14_primitive_layout(registry), encoding="utf-8"
            )
            phase14_conversion_path.write_text(
                render_phase14_integer_conversions(registry), encoding="utf-8"
            )
            phase14_pointer_path.write_text(
                render_phase14_pointers(registry), encoding="utf-8"
            )
            phase14_stack_slot_path.write_text(
                render_phase14_stack_slots(registry), encoding="utf-8"
            )
            phase14_memory_access_path.write_text(
                render_phase14_memory_accesses(registry), encoding="utf-8"
            )
            phase14_string_view_path.write_text(
                render_phase14_string_views(registry), encoding="utf-8"
            )
        elif command == "check-phase13-projection":
            check_phase13_projection(registry)
        elif command == "check-phase14-projection":
            check_phase14_projection(registry)
        elif command == "check-phase14-layout-authority-projection":
            check_phase14_layout_authority_projection(registry)
        elif command == "check-phase14-primitive-layout-projection":
            check_phase14_primitive_layout_projection(registry)
        elif command == "check-phase14-integer-conversion-projection":
            check_phase14_integer_conversion_projection(registry)
        elif command == "check-phase14-pointer-projection":
            check_phase14_pointer_projection(registry)
        elif command == "check-phase14-stack-slot-projection":
            check_phase14_stack_slot_projection(registry)
        elif command == "check-phase14-memory-access-projection":
            check_phase14_memory_access_projection(registry)
        elif command == "check-phase14-string-view-projection":
            check_phase14_string_view_projection(registry)
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
    phase14_primitive_contract = verify_phase14_primitive_layout(registry)
    phase14_conversion_contract = verify_phase14_integer_conversions(registry)
    phase14_pointer_contract = verify_phase14_pointers(registry)
    phase14_stack_slot_contract = verify_phase14_stack_slots(registry)
    phase14_memory_access_contract = verify_phase14_memory_accesses(registry)
    phase14_string_view_contract = verify_phase14_string_views(registry)
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
            f"{phase14_layout_contract['deferred_row_count']} opening rows remain deferred."
        ),
        "verify-phase14-primitive-layout": (
            "✅ Phase 14 declared targets and primitive scalar layouts passed: "
            f"{phase14_primitive_contract['target_count']} targets, "
            f"{phase14_primitive_contract['primitive_count']} primitive types, "
            f"{phase14_primitive_contract['migrated_count']} migrated rows, and "
            f"{phase14_primitive_contract['deferred_count']} deferred rows."
        ),
        "verify-phase14-integer-conversions": (
            "✅ Phase 14 integer conversion contract passed: "
            f"{phase14_conversion_contract['kind_count']} canonical kinds, "
            f"{phase14_conversion_contract['rule_count']} selected rules per target, "
            f"{phase14_conversion_contract['target_count']} declared targets, and "
            f"{phase14_conversion_contract['deferred_count']} rows remain deferred."
        ),
        "verify-phase14-pointers": (
            "✅ Phase 14 bounded pointer and nullability contract passed: "
            f"{phase14_pointer_contract['pointer_type_count']} pointer types and "
            f"{phase14_pointer_contract['operation_count']} operations per target across "
            f"{phase14_pointer_contract['target_count']} declared targets; "
            f"{phase14_pointer_contract['deferred_count']} rows remain deferred."
        ),
        "verify-phase14-stack-slots": (
            "✅ Phase 14 deterministic stack-slot contract passed: "
            f"{phase14_stack_slot_contract['slot_count']} slots and "
            f"{phase14_stack_slot_contract['operation_count']} operations per target across "
            f"{phase14_stack_slot_contract['target_count']} declared targets; "
            f"{phase14_stack_slot_contract['deferred_count']} rows remain deferred."
        ),
        "verify-phase14-memory-accesses": (
            "✅ Phase 14 typed memory-access contract passed: "
            f"{phase14_memory_access_contract['type_count']} selected types and "
            f"{phase14_memory_access_contract['operation_count']} operations per target across "
            f"{phase14_memory_access_contract['target_count']} declared targets; "
            f"{phase14_memory_access_contract['deferred_count']} rows remain deferred."
        ),
        "verify-phase14-string-views": (
            "✅ Phase 14 string literal and borrowed-view contract passed: "
            f"{phase14_string_view_contract['literal_count']} literals, "
            f"{phase14_string_view_contract['view_count']} views, and "
            f"{phase14_string_view_contract['operation_count']} operations per target across "
            f"{phase14_string_view_contract['target_count']} declared targets; "
            f"{phase14_string_view_contract['deferred_count']} rows remain deferred."
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
            "opening review, Phase 14 layout authority review, Phase 14 primitive layout review, "
            "Phase 14 integer conversion review, Phase 14 pointer review, Phase 14 stack-slot review, Phase 14 memory-access review, and Phase 14 string-view review generated."
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
        "check-phase14-primitive-layout-projection": (
            "✅ Phase 14 generated primitive layout review matches the registry."
        ),
        "check-phase14-integer-conversion-projection": (
            "✅ Phase 14 generated integer conversion review matches the registry."
        ),
        "check-phase14-pointer-projection": (
            "✅ Phase 14 generated pointer review matches the registry."
        ),
        "check-phase14-stack-slot-projection": (
            "✅ Phase 14 generated stack-slot review matches the registry."
        ),
        "check-phase14-memory-access-projection": (
            "✅ Phase 14 generated memory-access review matches the registry."
        ),
        "check-phase14-string-view-projection": (
            "✅ Phase 14 generated string-view review matches the registry."
        ),
        "check-projection": (
            "✅ Canonical Cranelift registry, Phase 13 final review, Phase 14 "
            "opening review, Phase 14 layout authority review, Phase 14 primitive layout review, "
            "Phase 14 integer conversion review, Phase 14 pointer review, Phase 14 stack-slot review, Phase 14 memory-access review, and Phase 14 string-view review match their committed artifacts."
        ),
    }
    print(messages[command])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
