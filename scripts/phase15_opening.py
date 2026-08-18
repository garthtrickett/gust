#!/usr/bin/env python3
"""Validate and render the Patch 15.0 resource/lifetime opening inventory."""

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
REVIEW = ROOT / "compiler/CRANELIFT_PHASE15_OPENING.md"

OPENING_VERSION = "phase15_opening_inventory_rebased_on_phase14_closure"
INVENTORY_VERSION = "phase15_opening_inventory_v1"
STATUS = "ready_for_patch15_1"
REGISTRY_STATUS = "phase17_opening_native_runtime_boundary_inventory"
PREDECESSOR = "phase14_closed_type_layout_and_memory_model"
REVIEW_PATH = "compiler/CRANELIFT_PHASE15_OPENING.md"
TARGET_POLICY = "all_declared_host_targets_from_phase14_target_authority"
COMPARISON_POLICY = (
    "semantic_opening_fields_parent_traceability_and_residual_rebase_only_"
    "generated_totals_and_markdown_are_derived"
)
BEHAVIOR_POLICY = (
    "registry_projection_guard_and_fixture_inventory_only_no_compiler_"
    "backend_runtime_MIR_request_object_link_package_CLI_or_level2_"
    "level3_workflow_change"
)
CI_DERIVATION = (
    "distinct_ci_family_values_from_phase15_opening_entries_in_first_"
    "occurrence_order"
)
CI_WORKFLOW_POLICY = (
    "planning_projection_only_no_phase15_level2_workflow_rows_until_"
    "capability_migration"
)
IMMUTABLE_FIELDS = (
    "id",
    "parent",
    "feature_family",
    "ci_family",
    "capability_owner",
    "diagnostic_owner",
    "target_applicability",
)
SNAPSHOT_FIELDS = {
    "opening_version",
    "inventory_version",
    "status",
    "predecessor_closure_version",
    "review_view",
    "immutable_fields",
    "entries",
    "residual_rebase",
    "ci_family_projection",
    "comparison_policy",
    "behavior_policy",
    "next_patch",
}
ENTRY_FIELDS = {
    "id",
    "parent",
    "feature_family",
    "ci_family",
    "capability_owner",
    "diagnostic_owner",
    "target_applicability",
    "status",
    "current_failure_stage",
    "positive_future_fixture",
    "negative_current_fixture",
}
REBASE_FIELDS = {
    "source_residual_id",
    "phase15_disposition",
    "selected_phase15_entry_ids",
    "reassigned_destination_phase",
    "reassigned_capability",
    "justification",
}
CI_FIELDS = {"derivation", "family_ids", "workflow_policy"}
OPENING_IDS = (
    "p15_resource_value_representation",
    "p15_move_state_transitions",
    "p15_use_after_move_enforcement",
    "p15_reassignment_cleanup",
    "p15_scope_exit_cleanup",
    "p15_early_return_cleanup",
    "p15_destructor_scheduling",
    "p15_manual_close_interaction",
    "p15_conditional_loop_resource_state",
    "p15_resource_metadata_validation",
    "p15_directory_resources",
    "p15_selected_failure_cleanup",
    "p15_complete_resource_differential",
)
PLANNING_CATEGORIES = (
    "resource_value_representation",
    "move_state_transitions",
    "use_after_move_enforcement",
    "reassignment_cleanup",
    "scope_exit_cleanup",
    "early_return_cleanup",
    "destructor_scheduling",
    "manual_close_interaction",
    "conditional_loop_carried_resource_state",
    "resource_metadata_validation",
    "directory_resources",
    "selected_failure_cleanup",
    "complete_resource_differential_evidence",
)
CI_FAMILIES = (
    "resource-values",
    "move-state",
    "reassignment-cleanup",
    "scope-exit-cleanup",
    "early-return-cleanup",
    "manual-close",
    "resource-cfg",
    "specialized-resources",
    "failure-cleanup",
)
SELECTED_RESIDUALS = {
    "p16_resource_bearing_aggregate_moves",
    "p16_cleanup_destructor_semantics",
}
OUT_OF_SCOPE_DESTINATIONS = {
    "p15_floating_point_layout": "phase18",
    "p15_vector_simd_layout": "phase18",
    "p15_packed_structs": "phase18",
    "p15_bitfields": "phase18",
    "p15_flexible_array_members": "phase18",
    "p15_niche_optimized_enums": "phase18",
    "p15_unsized_types": "phase16",
    "p15_trait_object_fat_pointers": "phase16",
    "p15_multiple_address_spaces": "phase18",
    "p15_arbitrary_pointer_arithmetic": "phase18",
    "p15_unrestricted_pointer_integer_casts": "phase18",
    "p16_atomics": "phase19",
    "p16_volatile_memory": "phase18",
    "p16_dynamic_stack_allocation": "phase16",
    "p16_heap_allocation": "phase17",
    "p16_garbage_collected_references": "phase17",
    "p15_aggregate_parameter_abi": "phase16",
    "p15_aggregate_return_abi": "phase16",
    "p15_target_specific_extension_types": "phase18",
    "p15_cross_endian_serialization": "phase18",
}


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise Error(f"missing required file: {path.relative_to(ROOT)}") from exc
    except json.JSONDecodeError as exc:
        raise Error(
            f"invalid JSON in {path.relative_to(ROOT)}:"
            f"{exc.lineno}:{exc.colno}: {exc.msg}"
        ) from exc
    require(isinstance(value, dict), f"{path.relative_to(ROOT)} must contain an object")
    return value


def nonempty(value: object, context: str) -> str:
    require(isinstance(value, str) and value, f"{context} must be a non-empty string")
    require(value.lower() not in {"unknown", "tbd", "ownerless", "ambiguous"},
            f"{context} is ambiguous")
    return value


def unique_strings(value: object, context: str) -> list[str]:
    require(isinstance(value, list), f"{context} must be an array")
    require(
        all(isinstance(item, str) and item for item in value),
        f"{context} must contain non-empty strings",
    )
    require(len(value) == len(set(value)), f"{context} contains duplicates")
    return value


def require_fixture(value: object, context: str) -> str:
    path = nonempty(value, context)
    require((ROOT / path).is_file(), f"{context} points to missing file: {path}")
    return path


def validate_schema(schema: dict) -> None:
    require(schema.get("additionalProperties") is False,
            "canonical registry schema must reject unknown root fields")
    properties = schema.get("properties", {})
    require(properties.get("registry_version", {}).get("const") == 17,
            "schema registry version must be 17")
    require(properties.get("registry_status", {}).get("const") == REGISTRY_STATUS,
            "schema Phase 15 opening status drifted")
    require(properties.get("current_phase", {}).get("const") == "phase17",
            "schema current phase must be phase17")
    opening = properties.get("opening_snapshots", {})
    require(
        set(opening.get("required", []))
        == {"phase13", "phase14", "phase15", "phase16", "phase17", "phase18"},
        "schema opening snapshot keys drifted",
    )
    require(
        opening.get("properties", {}).get("phase15", {}).get("$ref")
        == "#/$defs/phase15_opening_snapshot",
        "schema does not route opening_snapshots.phase15 to its canonical definition",
    )
    definitions = schema.get("$defs", {})
    snapshot = definitions.get("phase15_opening_snapshot", {})
    entry = definitions.get("phase15_opening_snapshot_entry", {})
    rebase = definitions.get("phase15_residual_rebase", {})
    projection = definitions.get("phase15_ci_family_projection", {})
    require(snapshot.get("additionalProperties") is False
            and set(snapshot.get("required", [])) == SNAPSHOT_FIELDS,
            "Phase 15 opening snapshot schema fields drifted")
    require(entry.get("additionalProperties") is False
            and set(entry.get("required", [])) == ENTRY_FIELDS,
            "Phase 15 opening entry schema fields drifted")
    require(rebase.get("additionalProperties") is False
            and set(rebase.get("required", [])) == REBASE_FIELDS,
            "Phase 15 residual rebase schema fields drifted")
    require(projection.get("additionalProperties") is False
            and set(projection.get("required", [])) == CI_FIELDS,
            "Phase 15 CI-family projection schema fields drifted")


def validate() -> dict:
    registry = read_json(REGISTRY)
    schema = read_json(SCHEMA)
    validate_schema(schema)

    require(registry.get("registry_version") == 17,
            "registry version must be 17")
    require(registry.get("registry_status") == REGISTRY_STATUS,
            "registry status does not record the Phase 15 opening")
    require(registry.get("current_phase") == "phase17",
            "Phase 17 is not the active registry phase")
    require(
        registry.get("closed_phase_versions", {}).get("phase14") == PREDECESSOR,
        "Phase 14 semantic closure is not recorded",
    )
    require(
        registry.get("closure_snapshots", {}).get("phase14", {}).get("closure_version")
        == PREDECESSOR,
        "Phase 14 closure snapshot drifted",
    )

    opening_snapshots = registry.get("opening_snapshots")
    require(isinstance(opening_snapshots, dict)
            and set(opening_snapshots)
            == {"phase13", "phase14", "phase15", "phase16", "phase17", "phase18"},
            "opening snapshots must contain Phase 13 through Phase 17")
    snapshot = opening_snapshots["phase15"]
    require(isinstance(snapshot, dict) and set(snapshot) == SNAPSHOT_FIELDS,
            "Phase 15 opening snapshot fields drifted")
    fixed = {
        "opening_version": OPENING_VERSION,
        "inventory_version": INVENTORY_VERSION,
        "status": STATUS,
        "predecessor_closure_version": PREDECESSOR,
        "review_view": REVIEW_PATH,
        "immutable_fields": list(IMMUTABLE_FIELDS),
        "comparison_policy": COMPARISON_POLICY,
        "behavior_policy": BEHAVIOR_POLICY,
        "next_patch": "15.1",
    }
    for field, expected in fixed.items():
        require(snapshot.get(field) == expected,
                f"Phase 15 opening {field} drifted")

    rows = snapshot.get("entries")
    require(isinstance(rows, list) and rows,
            "Phase 15 opening snapshot must contain rows")
    require(tuple(row.get("id") for row in rows) == OPENING_IDS,
            "Phase 15 opening row order or identity drifted")

    main_rows = {
        entry["id"]: entry
        for entry in registry.get("entries", [])
        if entry.get("origin_phase") == "phase15"
    }
    require(set(main_rows) == set(OPENING_IDS),
            "main registry Phase 15 rows differ from the opening snapshot")

    phase14_entries = {
        entry["id"]: entry
        for entry in registry.get("entries", [])
        if entry.get("origin_phase") == "phase14"
    }
    phase14_residuals = {
        row["id"]: row
        for row in registry.get("residual_snapshots", {})
        .get("phase14", {}).get("rows", [])
    }
    planning = set(registry.get("planning_categories", []))
    require(set(PLANNING_CATEGORIES) <= planning,
            "Phase 15 planning categories are incomplete")

    parent_counts: Counter[str] = Counter()
    feature_counts: Counter[str] = Counter()
    family_counts: Counter[str] = Counter()
    derived_families: list[str] = []
    for index, row in enumerate(rows):
        context = f"opening_snapshots.phase15.entries[{index}]"
        require(isinstance(row, dict) and set(row) == ENTRY_FIELDS,
                f"{context} fields drifted")
        entry_id = nonempty(row.get("id"), f"{context}.id")
        require(re.fullmatch(r"p15_[A-Za-z0-9_]+", entry_id) is not None,
                f"{entry_id}: invalid Phase 15 row ID")
        parent = nonempty(row.get("parent"), f"{entry_id}.parent")
        parent_kind, parent_id = parent.split(":", 1)
        parent_counts[parent_kind] += 1
        if parent_kind == "phase14_entry":
            require(parent_id in phase14_entries,
                    f"{entry_id}: unknown Phase 14 entry parent {parent_id}")
            require(phase14_entries[parent_id].get("status") == "migrated",
                    f"{entry_id}: Phase 14 entry parent is not migrated")
        elif parent_kind == "phase14_residual":
            require(parent_id in phase14_residuals,
                    f"{entry_id}: unknown Phase 14 residual parent {parent_id}")
        elif parent_kind == "phase15_category":
            require(parent_id in PLANNING_CATEGORIES and parent_id in planning,
                    f"{entry_id}: unknown Phase 15 category parent {parent_id}")
        else:
            raise Error(f"{entry_id}: invalid parent kind {parent_kind}")

        for field in (
            "feature_family", "ci_family", "capability_owner",
            "diagnostic_owner", "target_applicability",
            "current_failure_stage",
        ):
            nonempty(row.get(field), f"{entry_id}.{field}")
        require(row.get("target_applicability") == TARGET_POLICY,
                f"{entry_id}: target applicability drifted")
        require(row.get("status") == "candidate_deferred",
                f"{entry_id}: opening status must remain candidate_deferred")
        require(row.get("current_failure_stage") == "before_driver_discovery",
                f"{entry_id}: opening row must stop before driver discovery")
        positive = require_fixture(row.get("positive_future_fixture"),
                                   f"{entry_id}.positive_future_fixture")
        negative = require_fixture(row.get("negative_current_fixture"),
                                   f"{entry_id}.negative_current_fixture")
        require(positive != negative,
                f"{entry_id}: positive and negative fixtures must differ")

        main = main_rows[entry_id]
        mirror_fields = (
            "id", "parent", "feature_family", "ci_family",
            "diagnostic_owner", "target_applicability", "status",
            "current_failure_stage", "positive_future_fixture",
            "negative_current_fixture",
        )
        for field in mirror_fields:
            require(main.get(field) == row.get(field),
                    f"{entry_id}: main registry {field} differs from opening snapshot")
        require(main.get("worker_capability_owner") == row.get("capability_owner"),
                f"{entry_id}: capability owner differs from opening snapshot")
        require(main.get("route_owner") == "deferred"
                and main.get("source_fixture") == negative
                and main.get("canonical_mir_fixture")
                == "none_rejected_before_canonical_MIR"
                and main.get("differential_case_id")
                == f"phase15_opening:{entry_id}"
                and main.get("future_destination_phase") == "phase15"
                and main.get("closure_version") == INVENTORY_VERSION,
                f"{entry_id}: main registry opening state drifted")

        feature_counts[row["feature_family"]] += 1
        family_counts[row["ci_family"]] += 1
        if row["ci_family"] not in derived_families:
            derived_families.append(row["ci_family"])

    require(set(parent_counts)
            == {"phase14_entry", "phase14_residual", "phase15_category"},
            "Phase 15 opening does not preserve all parent traceability kinds")

    rebase_rows = snapshot.get("residual_rebase")
    require(isinstance(rebase_rows, list) and rebase_rows,
            "Phase 15 residual rebase must contain rows")
    require(len(rebase_rows) == len(phase14_residuals),
            "Phase 15 residual rebase must classify every Phase 14 residual")
    rebase_by_id: dict[str, dict] = {}
    selected_refs: set[str] = set()
    disposition_counts: Counter[str] = Counter()
    for index, row in enumerate(rebase_rows):
        context = f"opening_snapshots.phase15.residual_rebase[{index}]"
        require(isinstance(row, dict) and set(row) == REBASE_FIELDS,
                f"{context} fields drifted")
        residual_id = nonempty(row.get("source_residual_id"),
                               f"{context}.source_residual_id")
        require(residual_id in phase14_residuals,
                f"{residual_id}: unknown Phase 14 residual")
        require(residual_id not in rebase_by_id,
                f"duplicate Phase 15 residual rebase row: {residual_id}")
        rebase_by_id[residual_id] = row
        disposition = nonempty(row.get("phase15_disposition"),
                               f"{residual_id}.phase15_disposition")
        require(disposition in {"selected", "split", "reassigned"},
                f"{residual_id}: invalid Phase 15 disposition")
        disposition_counts[disposition] += 1
        selected = unique_strings(row.get("selected_phase15_entry_ids"),
                                  f"{residual_id}.selected_phase15_entry_ids")
        require(set(selected) <= set(OPENING_IDS),
                f"{residual_id}: unknown selected Phase 15 row")
        selected_refs.update(selected)
        destination = nonempty(row.get("reassigned_destination_phase"),
                               f"{residual_id}.reassigned_destination_phase")
        capability = nonempty(row.get("reassigned_capability"),
                              f"{residual_id}.reassigned_capability")
        nonempty(row.get("justification"), f"{residual_id}.justification")
        if disposition == "selected":
            require(selected and destination == capability == "none_selected",
                    f"{residual_id}: selected residual has stale remainder")
        elif disposition == "split":
            require(selected and re.fullmatch(r"phase[0-9]+", destination)
                    and capability != "none_selected",
                    f"{residual_id}: split residual must retain a concrete later remainder")
        else:
            require(not selected and re.fullmatch(r"phase[0-9]+", destination)
                    and capability != "none_selected",
                    f"{residual_id}: reassigned residual must remain outside Phase 15")

    require(set(rebase_by_id) == set(phase14_residuals),
            "Phase 15 residual rebase coverage drifted")
    require(
        {rid for rid, row in rebase_by_id.items()
         if row["phase15_disposition"] == "split"} == SELECTED_RESIDUALS,
        "Phase 15 must select only the two resource/cleanup Phase 14 residuals",
    )
    require(
        {rid for rid, row in rebase_by_id.items()
         if row["phase15_disposition"] == "reassigned"}
        == set(OUT_OF_SCOPE_DESTINATIONS),
        "Phase 15 out-of-scope residual inventory drifted",
    )
    for residual_id, destination in OUT_OF_SCOPE_DESTINATIONS.items():
        require(
            rebase_by_id[residual_id]["reassigned_destination_phase"]
            == destination,
            f"{residual_id}: later destination drifted",
        )

    residual_parent_rows = {
        row["id"] for row in rows
        if row["parent"].startswith("phase14_residual:")
    }
    require(residual_parent_rows <= selected_refs,
            "every Phase 14 residual parent must be selected by the rebase")

    projection = snapshot.get("ci_family_projection")
    require(isinstance(projection, dict) and set(projection) == CI_FIELDS,
            "Phase 15 CI-family projection fields drifted")
    require(projection.get("derivation") == CI_DERIVATION,
            "Phase 15 CI-family derivation drifted")
    require(projection.get("family_ids") == derived_families == list(CI_FAMILIES),
            "Phase 15 CI-family projection is not row-derived")
    require(projection.get("workflow_policy") == CI_WORKFLOW_POLICY,
            "Phase 15 CI-family workflow policy drifted")

    return {
        "snapshot": snapshot,
        "rows": rows,
        "rebase_rows": rebase_rows,
        "parent_counts": parent_counts,
        "feature_counts": feature_counts,
        "family_counts": family_counts,
        "disposition_counts": disposition_counts,
    }


def cell(value: object) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def count_lines(counter: Counter[str]) -> list[str]:
    return [f"- `{key}`: `{counter[key]}`" for key in sorted(counter)]


def render(contract: dict) -> str:
    snapshot = contract["snapshot"]
    lines = [
        "# Cranelift Phase 15 Resource and Lifetime Opening Inventory",
        "",
        "<!-- Generated by scripts/phase15_opening.py; do not edit by hand. -->",
        "",
        "CRANELIFT_PHASE15_OPENING_VIEW_VERSION: 1",
        f"CRANELIFT_PHASE15_OPENING_VERSION: {OPENING_VERSION}",
        f"CRANELIFT_PHASE15_INVENTORY_VERSION: {INVENTORY_VERSION}",
        f"CRANELIFT_PHASE15_OPENING_STATUS: {STATUS}",
        f"CRANELIFT_PHASE15_OPENING_PREDECESSOR: {PREDECESSOR}",
        "CRANELIFT_PHASE15_OPENING_AUTHORITY: scripts/cranelift_feature_registry.json",
        "CRANELIFT_PHASE15_OPENING_GUARD: guard-cranelift-phase15-opening-contract",
        f"CRANELIFT_PHASE15_OPENING_TARGET_POLICY: {TARGET_POLICY}",
        f"CRANELIFT_PHASE15_OPENING_CI_DERIVATION: {CI_DERIVATION}",
        f"CRANELIFT_PHASE15_OPENING_BEHAVIOR_POLICY: {BEHAVIOR_POLICY}",
        "",
        "## Patch 15.0 opening inventory and Phase 14 residual rebase",
        "",
        "This semantic opening snapshot selects only resource identity, move state, cleanup, destruction, manual-close, resource-CFG, metadata, specialized-resource, and bounded failure-cleanup work. It changes no compiler, backend, runtime, canonical MIR, request, object, link, packaging, Level 2, or Level 3 behavior.",
        "",
        "## Derived opening totals",
        "",
        f"- Opening rows: `{len(contract['rows'])}`",
        f"- Frozen Phase 14 residual rows classified: `{len(contract['rebase_rows'])}`",
        f"- Planned CI families: `{len(snapshot['ci_family_projection']['family_ids'])}`",
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
        *count_lines(contract["family_counts"]),
        "",
        "### Phase 14 residual dispositions",
        "",
        *count_lines(contract["disposition_counts"]),
        "",
        "## Opening entries",
        "",
        "| ID | Parent | Feature family | Planned CI family | Capability owner | Diagnostic owner | Target applicability | Status | Failure stage | Future positive | Current negative |",
        "|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    for row in contract["rows"]:
        values = (
            row["id"],
            row["parent"],
            row["feature_family"],
            row["ci_family"],
            row["capability_owner"],
            row["diagnostic_owner"],
            row["target_applicability"],
            row["status"],
            row["current_failure_stage"],
            row["positive_future_fixture"],
            row["negative_current_fixture"],
        )
        lines.append("| " + " | ".join(cell(value) for value in values) + " |")

    lines += [
        "",
        "## Phase 14 residual rebase",
        "",
        "| Phase 14 residual | Phase 15 disposition | Selected Phase 15 rows | Later destination | Later capability | Justification |",
        "|---|---|---|---|---|---|",
    ]
    for row in contract["rebase_rows"]:
        values = (
            row["source_residual_id"],
            row["phase15_disposition"],
            ", ".join(row["selected_phase15_entry_ids"]) or "none",
            row["reassigned_destination_phase"],
            row["reassigned_capability"],
            row["justification"],
        )
        lines.append("| " + " | ".join(cell(value) for value in values) + " |")

    lines += [
        "",
        "## Opening invariants",
        "",
        "- The Phase 14 scoped semantic closure is the immutable predecessor.",
        "- Every Phase 15 row has a stable ID, parent, feature family, planned CI family, capability owner, diagnostic owner, target applicability, failure stage, and fixture pair.",
        "- Parent traceability covers migrated Phase 14 rows, frozen Phase 14 residual capabilities, and explicit Phase 15 planning categories.",
        "- Only resource, ownership, move, cleanup, destruction, lifetime, resource metadata, directory-resource, and selected failure-cleanup work enters Phase 15.",
        "- Aggregate ABI, runtime allocation, garbage collection, concurrency, target layout expansion, volatile memory, and linker work remain explicitly assigned to later phases.",
        "- The planned Phase 15 CI-family projection is row-derived and adds no Level 2 workflow rows.",
        "- MIR-to-C remains the default differential oracle and explicit Cranelift remains no-fallback.",
        "- Phase 9G retains object, link, temporary-artifact cleanup, and atomic publication ownership.",
        "- Generated totals and Markdown are review projections rather than semantic authorities.",
        "- Raw registry, MIR, fixture, or Markdown hashes are forbidden as semantic contracts.",
        "",
        "Patch 15.0 opening inventory is active; Phase 15 may proceed to Patch 15.1.",
        "",
    ]
    rendered = "\n".join(lines)
    for banned in ("SHA256", "SHA-256", "sha256sum"):
        require(banned not in rendered,
                f"Phase 15 opening review contains banned hash token: {banned}")
    return rendered


def check_review(contract: dict) -> None:
    require(REVIEW.is_file(), f"missing generated review: {REVIEW.relative_to(ROOT)}")
    require(
        REVIEW.read_text(encoding="utf-8") == render(contract),
        "Phase 15 opening review is stale; run "
        "`python3 scripts/phase15_opening.py project`",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=("validate", "project", "check-review", "families"),
    )
    command = parser.parse_args().command
    try:
        contract = validate()
        if command == "project":
            REVIEW.parent.mkdir(parents=True, exist_ok=True)
            REVIEW.write_text(render(contract), encoding="utf-8")
        elif command == "check-review":
            check_review(contract)
        elif command == "families":
            print("\n".join(contract["snapshot"]["ci_family_projection"]["family_ids"]))
            return 0
    except Error as exc:
        print(f"Phase 15 opening error: {exc}", file=sys.stderr)
        return 1

    messages = {
        "validate": (
            "✅ Phase 15 opening inventory passed: "
            f"rows={len(contract['rows'])} "
            f"phase14_residuals={len(contract['rebase_rows'])} "
            f"planned_families={len(contract['snapshot']['ci_family_projection']['family_ids'])}."
        ),
        "project": "✅ Phase 15 opening review generated.",
        "check-review": "✅ Phase 15 opening review matches the canonical registry.",
    }
    print(messages[command])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
