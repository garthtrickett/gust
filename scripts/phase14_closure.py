#!/usr/bin/env python3
"""Validate and render the scoped Patch 14.14 Phase 14 closure."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
SCHEMA = ROOT / "scripts/cranelift_feature_registry.schema.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE14_CLOSURE.md"
JUSTFILE = ROOT / "justfile"
PR_WORKFLOW = ROOT / ".github/workflows/pr-fast.yml"
HEAVY_WORKFLOW = ROOT / ".github/workflows/heavy-guards.yml"
HISTORICAL_WORKFLOW = ROOT / ".github/workflows/cranelift-historical-full.yml"

VERSION = "phase14_closed_type_layout_and_memory_model"
STATUS = "closed_declared_inventory_only"
SCOPE = "declared_phase14_type_layout_and_memory_model_inventory_only"
OPENING_VERSION = "phase14_opening_inventory_v1"
RESIDUAL_VERSION = "phase14_deferred_residue_v1"
COMPOSITION_VERSION = "phase14_cross_feature_all_target_layout_differential_v1"
REVIEW_PATH = "compiler/CRANELIFT_PHASE14_CLOSURE.md"
TARGET_POLICY = "all_declared_host_targets_from_phase14_target_authority"
CLOSURE_WORDING = (
    "The declared Phase 14 type, layout, and memory-model inventory is complete. "
    "Migrated rows use compiler-owned target and type layouts through generic "
    "canonical MIR, MIR-to-C, and Cranelift, while remaining unsupported "
    "capabilities are represented by narrower, explicitly owned future-phase "
    "deferrals."
)
NON_CLAIMS = (
    "Cranelift_has_full_Gust_type_parity",
    "all_Gust_types_are_supported",
    "all_pointer_operations_are_supported",
    "all_memory_accesses_are_safe",
    "all_aggregate_ABI_forms_are_supported",
    "all_target_ABIs_are_supported",
    "resource_semantics_are_complete",
    "dynamic_allocation_is_complete",
    "the_experimental_backend_is_production_complete",
)
REQUIRED_CONTRACTS = (
    "phase13_semantic_closure_summary",
    "phase14_opening_contract",
    "canonical_registry_schema",
    "canonical_registry_projection",
    "phase14_parent_traceability_contract",
    "compiler_owned_layout_authority_contract",
    "declared_target_projection",
    "primitive_layout_contract",
    "integer_conversion_contract",
    "pointer_and_nullability_contract",
    "stack_slot_contract",
    "typed_memory_access_contract",
    "string_and_string_view_contract",
    "array_and_slice_contract",
    "struct_layout_contract",
    "enum_and_tagged_union_contract",
    "aggregate_basic_block_transport_contract",
    "phase14_deferred_residue_audit",
    "registry_derived_phase14_ci_family_projection",
    "semantic_route_architecture_contract",
    "reduced_manifest_architecture_contract",
    "three_level_test_mapping_and_workflow_ownership",
    "phase14_generated_view_projection",
    "phase14_registry_differential_wiring",
    "separately_runnable_level3_historical_and_all_target_suite",
    "phase9g_artifact_ownership_contract",
    "mir_to_c_default_ownership",
    "explicit_cranelift_no_fallback_policy",
    "worker_request_isolation",
    "early_deferral_and_output_preservation_contracts",
)
CLOSURE_ASSERTIONS = (
    "every_phase14_opening_row_has_a_valid_final_disposition",
    "every_migrated_row_uses_generic_canonical_mir_routing",
    "every_migrated_memory_representable_type_has_compiler_owned_layout",
    "mir_to_c_and_cranelift_consume_the_same_compiler_produced_layout_data",
    "runtime_facing_layout_descriptors_come_from_the_compiler_authority",
    "diagnostics_consume_the_same_layout_decisions",
    "every_remaining_deferral_is_concrete_target_scoped_when_needed_and_owned",
    "no_exact_source_or_exact_layout_output_recognizer_exists",
    "no_backend_local_type_layout_authority_exists",
    "c_sizeof_and_offsetof_are_not_semantic_layout_authorities",
    "cranelift_target_defaults_are_not_semantic_layout_authorities",
    "explicit_cranelift_cannot_fall_back_to_mir_to_c",
    "unsupported_cases_stop_before_driver_and_artifact_access",
    "mir_to_c_remains_the_default_oracle",
    "default_and_explicit_mir_to_c_remain_equivalent",
    "worker_receives_only_request_data_canonical_mir_and_compiler_produced_layout_data",
    "phase9g_owns_object_link_cleanup_and_publication",
    "active_totals_and_targets_are_registry_derived",
    "generated_views_are_current",
    "ci_families_remain_registry_derived",
    "no_raw_registry_layout_or_markdown_hash_contract_exists",
    "no_exact_matrix_total_is_backend_correctness",
    "cranelift_historical_full_remains_separately_runnable_and_owns_all_target_evidence",
    "representative_aggregate_evidence_is_assigned_to_every_declared_host_target",
)
FORBIDDEN_REPLAYS = (
    "every_phase14_differential_family",
    "every_declared_target_runner",
    "full_phase9_through_phase14_historical_suite",
    "every_historical_native_fixture",
    "complete_object_and_link_failure_matrices",
    "release_or_packaging_matrices",
)
SNAPSHOT_FIELDS = (
    "closure_version",
    "status",
    "scope",
    "opening_version",
    "residual_version",
    "composition_version",
    "closure_review_view",
    "closure_guard",
    "ci_owner",
    "closure_wording",
    "non_claims",
    "required_contracts",
    "closure_assertions",
    "forbidden_replays",
    "opening_entry_count",
    "disposition_counts",
    "migrated_entry_ids",
    "replaced_entry_ids",
    "excluded_entry_ids",
    "residual_entry_count",
    "declared_target_count",
    "target_disposition_counts",
    "migrated_route_owner",
    "layout_authority_owner",
    "layout_table_format",
    "default_oracle_owner",
    "explicit_cranelift_fallback_policy",
    "worker_request_boundary",
    "artifact_owner",
    "differential_owner",
    "historical_owner",
    "all_target_owner",
    "evidence_replay_policy",
    "comparison_policy",
)


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise Error(f"missing required file: {path.relative_to(ROOT)}") from exc


def read_json(path: Path) -> dict:
    try:
        value = json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        raise Error(
            f"invalid JSON in {path.relative_to(ROOT)}:"
            f"{exc.lineno}:{exc.colno}: {exc.msg}"
        ) from exc
    require(isinstance(value, dict), f"{path.relative_to(ROOT)} must contain an object")
    return value


def unique_strings(value: object, context: str, *, allow_empty: bool = False) -> list[str]:
    require(isinstance(value, list), f"{context} must be an array")
    if not allow_empty:
        require(value, f"{context} must not be empty")
    require(
        all(isinstance(item, str) and item for item in value),
        f"{context} must contain non-empty strings",
    )
    require(len(value) == len(set(value)), f"{context} contains duplicates")
    return value


def recipe_body(justfile: str, recipe: str, next_recipe: str) -> str:
    pattern = rf"^{re.escape(recipe)}:\n(.*?)^{re.escape(next_recipe)}(?: [^:\n]*)?:\n"
    match = re.search(pattern, justfile, re.MULTILINE | re.DOTALL)
    require(match is not None, f"cannot isolate {recipe}")
    return match.group(1)


def validate_schema(schema: dict) -> None:
    closure = schema.get("properties", {}).get("closure_snapshots", {})
    require(
        set(closure.get("required", [])) == {"phase11", "phase13", "phase14"},
        "schema closure snapshot keys must be phase11, phase13, and phase14",
    )
    require(
        closure.get("properties", {}).get("phase14", {}).get("$ref")
        == "#/$defs/phase14_closure_snapshot",
        "schema does not route closure_snapshots.phase14 to its canonical definition",
    )
    definition = schema.get("$defs", {}).get("phase14_closure_snapshot", {})
    require(
        definition.get("additionalProperties") is False,
        "Phase 14 closure schema must reject unknown fields",
    )
    require(
        list(definition.get("required", [])) == list(SNAPSHOT_FIELDS),
        "Phase 14 closure schema fields drifted",
    )


def validate_static_architecture(registry: dict) -> None:
    authority = registry.get("phase14_layout_authority", {})
    require(
        authority.get("authority_owner") == "compiler/mir_layout.gst",
        "Phase 14 compiler layout authority owner drifted",
    )
    require(
        authority.get("table_format") == "gust.compiler_layout_table.v2",
        "Phase 14 closure requires the v2 compiler layout table",
    )
    consumers = authority.get("consumers")
    require(
        isinstance(consumers, dict)
        and consumers.get("canonical_mir") == "compiler/mir.gst:type_layout_references"
        and consumers.get("mir_to_c") == "compiler/mir_layout_mir_to_c.gst"
        and consumers.get("cranelift_worker")
        == "compiler/experiments/cranelift/src/main.rs:Phase14RequestLayoutTable"
        and consumers.get("runtime_descriptor")
        == "compiler/mir_layout_runtime_descriptor.gst"
        and consumers.get("diagnostics") == "compiler/mir_layout_diagnostics.gst",
        "Phase 14 layout consumers no longer share the compiler authority",
    )
    require(
        set(authority.get("hard_bans", []))
        == {
            "no_mir_to_c_owned_layout_table",
            "no_worker_owned_layout_selection",
            "no_runtime_hard_coded_duplicate_offsets",
            "no_diagnostic_layout_recomputation",
        },
        "Phase 14 layout hard bans drifted",
    )

    authority_source = read_text(ROOT / "compiler/mir_layout.gst")
    mir_source = read_text(ROOT / "compiler/mir.gst")
    request_source = read_text(ROOT / "compiler/mir_native_backend_request.gst")
    mir_to_c_source = read_text(ROOT / "compiler/mir_layout_mir_to_c.gst")
    runtime_source = read_text(ROOT / "compiler/mir_layout_runtime_descriptor.gst")
    diagnostic_source = read_text(ROOT / "compiler/mir_layout_diagnostics.gst")
    worker_source = read_text(ROOT / "compiler/experiments/cranelift/src/main.rs")
    route_source = read_text(ROOT / "compiler/mir_native_backend_source_route.gst")
    capability_source = read_text(ROOT / "compiler/mir_native_backend_capability.gst")
    compiler_entry = read_text(ROOT / "compiler/test_runner_entry.gst")
    differential_harness = read_text(
        ROOT / "scripts/phase13_registry_differential.sh"
    )
    capability_evidence = read_text(
        ROOT / "scripts/phase13_capability_deferral.sh"
    )

    for token in (
        "type MirTargetLayout",
        "type MirTypeLayout",
        "type MirFieldLayout",
        "type MirVariantLayout",
        "func mir_layout_of(",
        "func mir_layout_field_layout(",
        "func mir_layout_variant_layout(",
        "func mir_layout_element_stride(",
        "func mir_layout_validate_memory_access(",
    ):
        require(token in authority_source, f"compiler layout authority is missing {token}")

    require(
        "type_layout_references" in mir_source
        and "mir_program_layout_reference_is_valid" in mir_source,
        "canonical MIR no longer consumes compiler-produced layout references",
    )
    require(
        "layout_table: layout.MirLayoutTable[ctx]" in request_source
        and "mir_serialize_layout_table_for_request" in request_source,
        "native request no longer carries the compiler-produced layout table",
    )
    require(
        not re.search(
            r"^[ \t]*(source_path|source_text|source_bytes|ast_program):",
            request_source,
            re.MULTILINE,
        ),
        "native worker request exposes a forbidden raw-source field",
    )
    for source, label, token in (
        (mir_to_c_source, "MIR-to-C", "mir_layout_for_mir_to_c"),
        (runtime_source, "runtime descriptor", "mir_layout_runtime_descriptor"),
        (diagnostic_source, "diagnostics", "mir_layout_diagnostic"),
    ):
        require(
            'import "mir_layout.gst" as layout;' in source
            and token in source
            and "type MirTypeLayout" not in source,
            f"{label} must consume rather than redefine compiler layout authority",
        )

    semantic_c_authority_pattern = re.compile(r"\b(?:sizeof|offsetof)\s*\(")
    require(
        semantic_c_authority_pattern.search(authority_source) is None
        and semantic_c_authority_pattern.search(mir_to_c_source) is None,
        "C sizeof or offsetof became a semantic layout authority",
    )
    exact_layout_recognizer = re.compile(
        r"std\.str_(?:eq|find)\(\s*(?:source|source_text|fixture|filename|path|"
        r"layout_output|rendered_layout|layout_text|descriptor_text|witness_text)\b",
        re.IGNORECASE,
    )
    for source, label in (
        (authority_source, "layout authority"),
        (mir_to_c_source, "MIR-to-C layout adapter"),
        (runtime_source, "runtime layout descriptor"),
        (diagnostic_source, "layout diagnostics"),
    ):
        require(
            exact_layout_recognizer.search(source) is None,
            f"{label} contains an exact-layout-output recognizer",
        )

    for token in (
        "struct Phase14RequestLayoutTable",
        "fn parse_phase14_request_layout_table(",
        "fn validate_phase14_request_layout_table(",
        "duplicate conflicting layout ID",
        "unknown layout ID",
        "invalid tag or payload offsets",
    ):
        require(token in worker_source, f"Cranelift request layout validation is missing {token}")
    require(
        not re.search(
            r"std::mem::(?:size_of|align_of)|offset_of!|Layout::(?:from_size_align|new|array)",
            worker_source,
        ),
        "Cranelift target defaults or Rust host layout became a semantic authority",
    )

    native_branch_match = re.search(
        r"if invocation\.backend\.tag == 1 \{(.*?)"
        r"Both explicit C spellings",
        compiler_entry,
        re.DOTALL,
    )
    require(native_branch_match is not None, "cannot isolate explicit Cranelift route")
    require(
        "codegen.codegen_generate(" not in native_branch_match.group(1),
        "explicit Cranelift can fall back to MIR-to-C",
    )
    require(
        'os.LogStr("  cranelift  Compile to one native executable (default).");'
        in compiler_entry,
        "Cranelift is not documented as the default backend",
    )
    require(
        "mir_native_backend_deferred_route_decision" in route_source
        and "before_driver_discovery" in capability_source
        and "mir_native_backend_route_decision_is_valid" in capability_source,
        "unsupported native cases no longer stop at the early deferral boundary",
    )
    for token in (
        './gust --backend c "$source_fixture"',
        './gust --backend mir-to-c "$source_fixture"',
        'cmp -s "$case_dir/default.c" "$case_dir/explicit.c"',
    ):
        require(
            token in differential_harness,
            f"MIR-to-C explicit-alias differential witness is missing {token}",
        )
    for token in (
        'assert_preserved_output "$deferred_output" "$deferred_output.expected"',
        'if [ -e "$output_path.phase10.request" ] ||',
        'if [ -e "$deferred_marker" ]; then',
    ):
        require(
            token in capability_evidence,
            f"early deferral or output-preservation witness is missing {token}",
        )


def validate_workflow_and_wiring(registry: dict) -> None:
    justfile = read_text(JUSTFILE)
    pr = read_text(PR_WORKFLOW)
    heavy = read_text(HEAVY_WORKFLOW)
    historical = read_text(HISTORICAL_WORKFLOW)

    require(
        pr.count("just guard-cranelift-phase14-close") == 1,
        "PR Fast must invoke the Phase 14 closure exactly once",
    )
    require(
        "Phase 14 type layout and memory model closure" in pr,
        "PR Fast is missing the scoped Phase 14 closure step",
    )
    require(
        "just guard-cranelift-phase14-deferred-residue-audit" not in pr,
        "PR Fast must delegate the preceding Phase 14 owner to the closure guard",
    )
    require(
        "guard-cranelift-historical-full" not in pr
        and "guard-cranelift-historical-full" not in heavy,
        "Level 3 full history must remain outside PR Fast and Heavy Guards",
    )
    require(
        historical.count("just guard-cranelift-historical-full") == 1
        and historical.count("just guard-cranelift-phase14-all-target-composition") == 1,
        "Cranelift Historical Full must own one historical replay and one all-target entry",
    )
    for token in (
        "schedule:",
        "workflow_dispatch:",
        'matrix=$(python3 scripts/phase14_composition.py target-matrix-json)',
        "target: ${{ fromJSON(needs.inventory.outputs.phase14_targets) }}",
        'PHASE14_TARGET="${{ matrix.target }}"',
        "needs: [historical-shard, phase14-target]",
    ):
        require(token in historical, f"historical workflow is missing {token!r}")

    declared_targets = [
        target["target_triple"]
        for target in registry["phase14_primitive_layout"]["declared_targets"]
    ]
    for target in declared_targets:
        require(
            target not in historical,
            f"historical workflow manually lists declared target {target}",
        )

    closure_body = recipe_body(
        justfile,
        "guard-cranelift-phase14-close",
        "guard-cranelift-phase14-composition-differential",
    )
    required_guard_calls = (
        "just guard-cranelift-phase14-opening-contract",
        "just guard-cranelift-registry-schema",
        "just guard-cranelift-registry-projection",
        "just guard-cranelift-phase14-parent-traceability",
        "just guard-cranelift-phase14-layout-authority-contract",
        "just guard-cranelift-phase14-target-and-primitive-contract",
        "just guard-cranelift-phase14-integer-conversion-contract",
        "just guard-cranelift-phase14-pointer-contract",
        "just guard-cranelift-phase14-stack-slot-contract",
        "just guard-cranelift-phase14-memory-access-contract",
        "just guard-cranelift-phase14-string-view-contract",
        "just guard-cranelift-phase14-array-slice-contract",
        "just guard-cranelift-phase14-struct-contract",
        "just guard-cranelift-phase14-enum-contract",
        "just guard-cranelift-phase14-aggregate-contract",
        "just guard-cranelift-phase14-deferred-residue-audit",
        "just guard-cranelift-ci-family-projection",
        "just guard-cranelift-route-architecture-contract",
        "just guard-cranelift-manifest-architecture-contract",
        "just guard-cranelift-phase9g-ci-surface",
    )
    for call in required_guard_calls:
        direct_call_count = len(
            re.findall(
                r"^[ \\t]+" + re.escape(call) + r"[ \\t]*$",
                closure_body,
                re.MULTILINE,
            )
        )
        require(
            direct_call_count == 1,
            f"Phase 14 closure must require {call!r} exactly once",
        )

    for token in (
        "guard-cranelift-phase9g-close:",
        "allowed_cranelift_phase9g_object_artifact_validation_order: fixture_parse_validation_metadata_and_lowering_complete_before_parent_directory_or_temp_file_creation",
        "fs::rename(&temp_path, output_path)?;",
    ):
        require(
            token in closure_body,
            f"Phase 14 closure is missing static Phase 9G ownership evidence: {token}",
        )

    forbidden_direct_replays = (
        r"^[ \t]+just guard-cranelift-differential-family(?:[ \t]|$)",
        r"^[ \t]+just guard-cranelift-phase14-composition-differential(?:[ \t]|$)",
        r"^[ \t]+just guard-cranelift-phase14-all-target-composition(?:[ \t]|$)",
        r"^[ \t]+just guard-cranelift-historical-full(?:[ \t]|$)",
        r"^[ \t]+bash scripts/phase14_.*differential\.sh(?:[ \t]|$)",
        r"^[ \t]+\./gust(?:[ \t]|$)",
        r"^[ \t]+(?:cargo|cc|gcc|clang|make)(?:[ \t]|$)",
    )
    for pattern in forbidden_direct_replays:
        require(
            re.search(pattern, closure_body, re.MULTILINE) is None,
            f"Phase 14 closure directly replays forbidden evidence: {pattern}",
        )

    count_pattern = re.compile(
        r"EXPECTED_(?:FAMILY|MATRIX|SHARD|TARGET)_COUNT|"
        r"(?:family|matrix|shard|target)_count\s*=\s*[0-9]+"
    )
    for source, label in (
        (read_text(ROOT / "scripts/cranelift_ci_family.py"), "CI family projector"),
        (read_text(ROOT / "scripts/phase14_composition.py"), "Phase 14 composition projector"),
        (pr, "PR Fast"),
        (heavy, "Heavy Guards"),
        (historical, "Cranelift Historical Full"),
    ):
        require(
            count_pattern.search(source) is None,
            f"{label} treats an exact matrix total as backend correctness",
        )


def validate() -> dict:
    registry = read_json(REGISTRY)
    schema = read_json(SCHEMA)
    validate_schema(schema)

    current_phase = registry.get("current_phase")
    current_phase_match = (
        re.fullmatch(r"phase([0-9]+)", current_phase)
        if isinstance(current_phase, str)
        else None
    )
    require(
        current_phase_match is not None
        and int(current_phase_match.group(1)) >= 14,
        "Phase 14 closure requires Phase 14 or a later active phase",
    )
    require(
        registry.get("closed_phase_versions", {}).get("phase14") == VERSION,
        "closed_phase_versions does not record Phase 14",
    )

    snapshots = registry.get("closure_snapshots")
    require(
        isinstance(snapshots, dict)
        and set(snapshots) == {"phase11", "phase13", "phase14"},
        "closure snapshots must contain exactly Phase 11, Phase 13, and Phase 14",
    )
    snapshot = snapshots["phase14"]
    require(
        isinstance(snapshot, dict)
        and list(snapshot) == list(SNAPSHOT_FIELDS),
        "Phase 14 closure snapshot fields or order drifted",
    )
    fixed = {
        "closure_version": VERSION,
        "status": STATUS,
        "scope": SCOPE,
        "opening_version": OPENING_VERSION,
        "residual_version": RESIDUAL_VERSION,
        "composition_version": COMPOSITION_VERSION,
        "closure_review_view": REVIEW_PATH,
        "closure_guard": "guard-cranelift-phase14-close",
        "ci_owner": "PR_Fast_Level1_phase_closure",
        "closure_wording": CLOSURE_WORDING,
        "non_claims": list(NON_CLAIMS),
        "required_contracts": list(REQUIRED_CONTRACTS),
        "closure_assertions": list(CLOSURE_ASSERTIONS),
        "forbidden_replays": list(FORBIDDEN_REPLAYS),
        "migrated_route_owner": "generic_canonical_mir",
        "layout_authority_owner": "compiler/mir_layout.gst",
        "layout_table_format": "gust.compiler_layout_table.v2",
        "default_oracle_owner": "mir_to_c",
        "explicit_cranelift_fallback_policy": "forbidden",
        "worker_request_boundary": (
            "request_data_canonical_mir_and_compiler_produced_layout_only"
        ),
        "artifact_owner": (
            "phase9g_compiler_transactional_object_link_cleanup_and_publication"
        ),
        "differential_owner": "registry_derived_level2_families",
        "historical_owner": "scheduled_or_manual_cranelift_historical_full_level3",
        "all_target_owner": "registry_derived_phase14_declared_target_matrix",
        "evidence_replay_policy": (
            "validate_ownership_and_wiring_without_replaying_level2_or_level3"
        ),
        "comparison_policy": (
            "semantic_registry_layout_and_wiring_only_no_raw_hashes_or_"
            "matrix_correctness_totals"
        ),
    }
    for field, expected in fixed.items():
        require(snapshot[field] == expected, f"Phase 14 closure {field} drifted")

    opening = registry.get("opening_snapshots", {}).get("phase14", {})
    opening_rows = opening.get("entries")
    require(isinstance(opening_rows, list) and opening_rows, "Phase 14 opening rows are missing")
    opening_ids = unique_strings(
        [row.get("id") for row in opening_rows],
        "Phase 14 opening IDs",
    )
    live_rows = [
        entry
        for entry in registry.get("entries", [])
        if entry.get("origin_phase") == "phase14"
    ]
    require(
        [entry["id"] for entry in live_rows] == opening_ids,
        "live Phase 14 rows differ from the opening inventory",
    )

    residue = registry.get("residual_snapshots", {}).get("phase14", {})
    dispositions = residue.get("opening_dispositions")
    require(isinstance(dispositions, list), "Phase 14 opening dispositions are missing")
    disposition_by_id = {
        item["source_phase14_row_id"]: item for item in dispositions
    }
    require(
        list(disposition_by_id) == opening_ids,
        "not every Phase 14 opening row has one ordered final disposition",
    )
    disposition_counts = Counter(
        item["final_disposition"] for item in dispositions
    )
    migrated_ids = [
        entry["id"] for entry in live_rows if entry["status"] == "migrated"
    ]
    replaced_ids = [
        entry["id"] for entry in live_rows if entry["status"] == "replaced"
    ]
    excluded_ids = [
        entry["id"] for entry in live_rows if entry["status"] == "excluded"
    ]
    require(
        snapshot["opening_entry_count"] == len(opening_ids),
        "Phase 14 closure opening total is not registry-derived",
    )
    require(
        snapshot["disposition_counts"]
        == {
            "migrated": disposition_counts["migrated"],
            "replaced": disposition_counts["replaced"],
            "excluded": disposition_counts["excluded"],
        },
        "Phase 14 closure disposition totals differ from the residue audit",
    )
    require(snapshot["migrated_entry_ids"] == migrated_ids, "migrated ID inventory drifted")
    require(snapshot["replaced_entry_ids"] == replaced_ids, "replaced ID inventory drifted")
    require(snapshot["excluded_entry_ids"] == excluded_ids, "excluded ID inventory drifted")

    for entry in live_rows:
        disposition = disposition_by_id[entry["id"]]
        require(
            disposition["final_disposition"] == entry["status"],
            f"{entry['id']}: closure disposition differs from live registry row",
        )
        if entry["status"] == "migrated":
            require(
                entry["route_owner"] == "generic_canonical_mir",
                f"{entry['id']}: migrated row is not generic canonical MIR",
            )
            evidence = entry.get("evidence")
            require(isinstance(evidence, dict), f"{entry['id']}: evidence is missing")
            require(
                evidence.get("phase14_1_authority")
                == "compiler_owned_layout_authority_and_request_transport_available",
                f"{entry['id']}: migrated row lacks compiler-owned layout authority",
            )
            require(
                isinstance(entry.get("closure_version"), str)
                and entry["closure_version"].startswith("phase14_"),
                f"{entry['id']}: migrated row lacks a Phase 14 layout contract",
            )
            require(
                isinstance(evidence.get("individual_evidence_guard"), str)
                and evidence["individual_evidence_guard"].startswith(
                    "guard-cranelift-phase14-"
                ),
                f"{entry['id']}: focused evidence owner is missing",
            )
            require(
                isinstance(evidence.get("composition_case_ids"), list)
                and evidence["composition_case_ids"],
                f"{entry['id']}: composition ownership is missing",
            )
        else:
            require(
                disposition["final_disposition"] in {"replaced", "excluded"},
                f"{entry['id']}: unresolved Phase 14 disposition",
            )

    residual_rows = residue.get("rows")
    require(isinstance(residual_rows, list) and residual_rows, "future residue is missing")
    require(
        snapshot["residual_entry_count"] == len(residual_rows),
        "Phase 14 residual total is not registry-derived",
    )
    for row in residual_rows:
        for field in (
            "id",
            "capability_owner",
            "diagnostic_owner",
            "capability",
            "concrete_reason",
            "destination_phase",
            "prerequisite_capability",
            "current_failure_stage",
            "target_applicability",
            "positive_future_fixture",
            "negative_current_fixture",
            "diagnostic_reason_code",
        ):
            require(
                isinstance(row.get(field), str) and row[field],
                f"{row.get('id', '<unknown>')}: concrete residual field {field} is missing",
            )

    targets = registry.get("phase14_primitive_layout", {}).get("declared_targets")
    target_dispositions = residue.get("target_dispositions")
    require(isinstance(targets, list) and targets, "declared targets are missing")
    require(
        isinstance(target_dispositions, list)
        and [item["target_id"] for item in target_dispositions]
        == [target["target_id"] for target in targets],
        "declared-target dispositions differ from target authority",
    )
    target_counts = Counter(
        item["final_disposition"] for item in target_dispositions
    )
    require(
        snapshot["declared_target_count"] == len(targets),
        "declared target total is not registry-derived",
    )
    require(
        snapshot["target_disposition_counts"]
        == {
            "supported": target_counts["supported"],
            "replaced": target_counts["replaced"],
            "excluded": target_counts["excluded"],
        },
        "target disposition totals differ from target authority",
    )

    migrated_set = set(migrated_ids)
    cross_cases = []
    for entry in live_rows:
        evidence = entry.get("evidence", {})
        for case in evidence.get("phase14_12_composition_cases", []):
            cross_cases.append(case)
    require(cross_cases, "Phase 14 closure has no registry-owned all-feature case")
    require(
        any(
            case.get("closure_version") == COMPOSITION_VERSION
            and set(case.get("covers_entry_ids", [])) == migrated_set
            and case.get("target_applicability") == TARGET_POLICY
            for case in cross_cases
        ),
        "representative aggregate composition is not assigned to all rows and targets",
    )

    validate_static_architecture(registry)
    validate_workflow_and_wiring(registry)

    searchable = "\n".join(
        (
            json.dumps(registry, sort_keys=True),
            read_text(REVIEW) if REVIEW.is_file() else "",
            read_text(ROOT / "compiler/CRANELIFT_PHASE14_FINAL_REVIEW.md"),
        )
    )
    require(
        re.search(r"sha-?256|sha256sum", searchable, re.IGNORECASE) is None,
        "Phase 14 closure contains a forbidden raw registry, layout, or Markdown hash contract",
    )

    return {
        "snapshot": snapshot,
        "opening_count": len(opening_ids),
        "migrated_count": len(migrated_ids),
        "replaced_count": len(replaced_ids),
        "excluded_count": len(excluded_ids),
        "residual_count": len(residual_rows),
        "target_count": len(targets),
        "target_counts": target_counts,
        "family_count": len(
            {
                entry["ci_family"]
                for entry in live_rows
                if entry["status"] == "migrated"
            }
        ),
    }


def render_review() -> str:
    summary = validate()
    snapshot = summary["snapshot"]
    lines = [
        "# Cranelift Phase 14 Closure",
        "",
        "<!-- Generated by scripts/phase14_closure.py; do not edit by hand. -->",
        "",
        "CRANELIFT_PHASE14_CLOSURE_VIEW_VERSION: 1",
        f"CRANELIFT_PHASE14_CLOSURE_VERSION: {snapshot['closure_version']}",
        f"CRANELIFT_PHASE14_CLOSURE_STATUS: {snapshot['status']}",
        f"CRANELIFT_PHASE14_CLOSURE_SCOPE: {snapshot['scope']}",
        f"CRANELIFT_PHASE14_CLOSURE_GUARD: {snapshot['closure_guard']}",
        f"CRANELIFT_PHASE14_CLOSURE_CI_OWNER: {snapshot['ci_owner']}",
        "CRANELIFT_PHASE14_CLOSURE_AUTHORITY: scripts/cranelift_feature_registry.json",
        "CRANELIFT_PHASE14_CLOSURE_LEVEL2_OWNER: registry_derived_level2_families",
        "CRANELIFT_PHASE14_CLOSURE_LEVEL3_OWNER: scheduled_or_manual_cranelift_historical_full_level3",
        "",
        "## Scoped closure",
        "",
        snapshot["closure_wording"],
        "",
        f"- Opening rows closed: `{summary['opening_count']}`",
        f"- Migrated rows: `{summary['migrated_count']}`",
        f"- Replaced rows: `{summary['replaced_count']}`",
        f"- Excluded rows: `{summary['excluded_count']}`",
        f"- Frozen future residual capabilities: `{summary['residual_count']}`",
        f"- Declared host targets: `{summary['target_count']}`",
        f"- Registry-derived Level 2 families: `{summary['family_count']}`",
        "",
        "The numeric totals above are generated observations from the canonical registry. They are not hard-coded matrix correctness thresholds.",
        "",
        "## Required contracts",
        "",
        *[f"- `{item}`" for item in snapshot["required_contracts"]],
        "",
        "## Closure assertions",
        "",
        *[f"- `{item}`" for item in snapshot["closure_assertions"]],
        "",
        "## Explicit non-claims",
        "",
        *[f"- `{item}`" for item in snapshot["non_claims"]],
        "",
        "## Evidence ownership",
        "",
        "- Level 1 validates semantic registry state, generated projections, architecture boundaries, and workflow wiring.",
        "- Registry-derived Level 2 families retain focused primary-host differential evidence.",
        "- Cranelift Historical Full remains the sole scheduled/manual Level 3 historical and all-target owner.",
        "- Phase 9G retains object, link, cleanup, and transactional publication ownership.",
        "",
        "## Replay boundary",
        "",
        "The closure guard does not directly replay:",
        "",
        *[f"- `{item}`" for item in snapshot["forbidden_replays"]],
        "",
        "## Final exit gate",
        "",
        "Every declared Phase 14 row is migrated through generic canonical MIR with compiler-owned layout data, explicitly excluded with justification, or replaced by narrower future-phase residue. Representative aggregate evidence remains assigned to every declared host target through the registry-derived Level 3 matrix.",
        "",
    ]
    return "\n".join(lines)


def check_review() -> None:
    expected = render_review()
    actual = read_text(REVIEW)
    require(actual == expected, "generated Phase 14 closure review is stale")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=("validate", "render", "check-review", "summary-json"),
    )
    args = parser.parse_args()
    try:
        if args.command == "validate":
            summary = validate()
            print(
                "✅ Phase 14 closure passed: "
                f"opening={summary['opening_count']} "
                f"migrated={summary['migrated_count']} "
                f"residual={summary['residual_count']} "
                f"targets={summary['target_count']}."
            )
        elif args.command == "render":
            print(render_review(), end="")
        elif args.command == "check-review":
            check_review()
            print("✅ Phase 14 closure review matches the canonical closure snapshot.")
        else:
            summary = validate()
            print(json.dumps({
                "opening": summary["opening_count"],
                "migrated": summary["migrated_count"],
                "residual": summary["residual_count"],
                "targets": summary["target_count"],
                "families": summary["family_count"],
            }, sort_keys=True))
    except (Error, OSError) as exc:
        print(f"Phase 14 closure error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
