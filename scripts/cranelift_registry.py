#!/usr/bin/env python3
"""Validate and project the canonical Cranelift feature registry."""

import argparse
import json
import sys
import tempfile
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
SCHEMA = ROOT / "scripts/cranelift_feature_registry.schema.json"
DEFERRED = {"deferred", "inherited_deferred", "candidate_deferred"}
AMBIGUOUS = {"", "unknown", "tbd", "ownerless", "ambiguous"}

TOP_FIELDS = {
    "schema", "schema_version", "registry_version", "registry_status",
    "current_phase", "closed_phase_versions", "closure_snapshots",
    "opening_snapshots", "planning_categories", "supported_values",
    "legacy_views", "entries",
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
        isinstance(snapshots, dict) and set(snapshots) == {"phase11"},
        "closure_snapshots must contain exactly phase11",
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
        isinstance(snapshots, dict) and set(snapshots) == {"phase13"},
        "opening_snapshots must contain exactly phase13",
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
        set(opening_schema.get("required", [])) == {"phase13"},
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

    require(registry["schema"] == "scripts/cranelift_feature_registry.schema.json",
            "registry schema path is not canonical")
    require(registry["schema_version"] == 1, "schema_version must be 1")
    require(registry["registry_version"] == 4, "registry_version must be 4")
    require(
        registry["registry_status"]
        == "phase12_5_closed_cranelift_verification_framework_consolidation",
        "registry status is missing or stale",
    )
    require(registry["current_phase"] == "phase13", "current_phase must be phase13")
    require(
        registry["closed_phase_versions"] == {
            "phase11": "phase11_closed_registry_backed_feature_parity_migration",
            "phase12_5_opening": "phase12_5_opened_verification_framework_consolidation",
            "phase12_5": "phase12_5_closed_cranelift_verification_framework_consolidation",
        },
        "closed phase versions drifted",
    )
    validate_phase11_snapshot_structure(registry)
    validate_phase13_opening_snapshot_structure(registry)

    categories = set(unique_strings(registry["planning_categories"], "planning_categories"))
    supported = registry["supported_values"]
    require(isinstance(supported, dict) and set(supported) == SUPPORTED_FIELDS,
            "supported_values fields drifted")
    allowed = {
        key: set(unique_strings(value, f"supported_values.{key}"))
        for key, value in supported.items()
    }
    require(
        set(registry["legacy_views"]) == {"phase11", "phase13", "generated_summary"},
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
    for index, entry in enumerate(entries):
        context = f"entries[{index}]"
        require(isinstance(entry, dict), f"{context} must be an object")
        expected_fields = set(ENTRY_FIELDS)
        if entry.get("origin_phase") == "phase13":
            expected_fields.update(PHASE13_CAPABILITY_FIELDS)
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
        else:
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
                    status in DEFERRED,
                    f"{entry_id}: deferred capability requires deferred status",
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
                in {"inherited_deferred", "migrated", "excluded"},
                f"{entry['id']}: entry parent has invalid current status",
            )
            require(
                entry["source_fixture"] == phase11_by_id[parent_id]["source_fixture"],
                f"{entry['id']}: inherited source fixture differs from Phase 11",
            )
            require(
                entry["canonical_mir_fixture"]
                == phase11_by_id[parent_id]["canonical_mir_fixture"],
                f"{entry['id']}: inherited canonical MIR fixture differs from Phase 11",
            )
        elif parent.startswith("phase11_category:"):
            category = parent.split(":", 1)[1]
            require(category in categories, f"{entry['id']}: unknown category {category}")
            require(
                entry["status"]
                in {"candidate_deferred", "migrated", "excluded"},
                f"{entry['id']}: category parent has invalid current status",
            )
        else:
            raise Error(f"{entry['id']}: invalid parent {parent}")

    require(phase11, "registry must contain Phase 11 rows")
    require(phase13, "registry must contain Phase 13 rows")
    active_ci_families = {entry["ci_family"] for entry in phase11}
    require(active_ci_families, "Phase 11 rows must define active CI families")
    for entry in phase13:
        require(
            entry["ci_family"] in active_ci_families,
            f"{entry['id']}: Phase 13 introduces non-Phase11 CI family "
            f"{entry['ci_family']}",
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
        require(
            entry["differential_case_id"] == f"phase13_opening:{entry_id}",
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
                in {"inherited_deferred", "migrated", "excluded"},
                f"{entry_id}: entry parent has invalid current status",
            )
            require(
                entry["source_fixture"] == parent_entry["source_fixture"],
                f"{entry_id}: inherited source fixture differs from Phase 11",
            )
            require(
                entry["canonical_mir_fixture"]
                == parent_entry["canonical_mir_fixture"],
                f"{entry_id}: inherited canonical MIR fixture differs from Phase 11",
            )
        elif parent.startswith("phase11_category:"):
            parent_kinds["phase11_category"] += 1
            category = parent.split(":", 1)[1]
            require(category in categories, f"{entry_id}: unknown category {category}")
            require(
                entry["status"]
                in {"candidate_deferred", "migrated", "excluded"},
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
    rows = phase_entries(registry, "phase13")
    status_counts = totals["status_counts"]
    current_status_counts = Counter(entry["status"] for entry in rows)
    parent_kinds = totals["parent_kinds"]

    lines = [
        "# Cranelift Phase 13 Opening Inventory",
        "",
        "<!-- Generated by scripts/cranelift_registry.py; do not edit by hand. -->",
        "",
        "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_VERSION: 7",
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
        "CRANELIFT_PHASE13_DEFERRED_PARITY_REGISTRY_NEXT_MILESTONE: patch13_7_direct_call_graphs",
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
        "## Opening entries",
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
        "",
        "Patch 13.5 general-loop and backedge parity is active; Phase 13 may proceed to Patch 13.6.",
        "",
    ]
    rendered = "\n".join(lines)
    for banned in ("SHA256", "SHA-256", "sha256sum"):
        require(
            banned not in rendered,
            f"Phase 13 generated view contains banned raw-hash token: {banned}",
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
        f"- Phase 13 historical view: `{registry['legacy_views']['phase13']}`", "",
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
        "generated Phase 13 opening summary",
    )


def check_projection(registry):
    check_rendered_projection(
        summary_path(registry),
        render(registry),
        "generated canonical registry summary",
    )
    check_phase13_projection(registry)


def summary_path(registry):
    return ROOT / registry["legacy_views"]["generated_summary"]


def phase13_summary_path(registry):
    return ROOT / registry["legacy_views"]["phase13"]


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
            "verify-phase13-opening-rebase",
            "verify-phase13-parent-traceability",
            "verify-phase13-opening-totals",
            "project",
            "check-phase13-projection",
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
        elif command == "verify-phase13-opening-rebase":
            verify_phase13_opening_rebase(registry)
        elif command == "verify-phase13-parent-traceability":
            verify_phase13_parent_traceability(registry)
        elif command == "verify-phase13-opening-totals":
            verify_phase13_opening_totals(registry)
        elif command == "project":
            canonical_path = summary_path(registry)
            phase13_path = phase13_summary_path(registry)
            canonical_path.parent.mkdir(parents=True, exist_ok=True)
            phase13_path.parent.mkdir(parents=True, exist_ok=True)
            canonical_path.write_text(render(registry), encoding="utf-8")
            phase13_path.write_text(render_phase13(registry), encoding="utf-8")
        elif command == "check-phase13-projection":
            check_phase13_projection(registry)
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
        "verify-phase13-opening-rebase": (
            "✅ Phase 13 opening rebase passed: stable IDs and parent "
            "relationships match the semantic snapshot; ready for Patch 13.1."
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
        "project": (
            "✅ Canonical Cranelift registry and Phase 13 Markdown summaries "
            "generated."
        ),
        "check-phase13-projection": (
            "✅ Phase 13 generated opening summary matches the registry."
        ),
        "check-projection": (
            "✅ Canonical Cranelift registry and Phase 13 projections match "
            "their committed review artifacts."
        ),
    }
    print(messages[command])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
