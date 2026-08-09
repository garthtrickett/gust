#!/usr/bin/env python3
"""Validate and render the Patch 16.0 function ABI opening inventory."""

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
REVIEW = ROOT / "compiler/CRANELIFT_PHASE16_OPENING.md"

OPENING_VERSION = "phase16_opening_inventory_rebased_on_phase15_closure"
INVENTORY_VERSION = "phase16_opening_inventory_v1"
STATUS = "ready_for_patch16_1"
REGISTRY_STATUS = "phase16_opening_function_abi_aggregate_call_inventory"
PREDECESSOR = "phase15_closed_resource_and_lifetime_semantics"
REVIEW_PATH = "compiler/CRANELIFT_PHASE16_OPENING.md"
TARGET_POLICY = "all_declared_host_targets_from_phase14_target_authority"
COMPARISON_POLICY = (
    "semantic_opening_fields_parent_traceability_and_residual_rebase_only_"
    "generated_totals_and_markdown_are_derived"
)
BEHAVIOR_POLICY = (
    "registry_projection_guard_and_fixture_inventory_only_no_compiler_"
    "backend_runtime_MIR_request_ABI_object_link_package_CLI_or_level2_"
    "level3_workflow_change"
)
ENTRY_BEHAVIOR_POLICY = (
    "opening_inventory_only_no_compiler_backend_runtime_MIR_request_ABI_"
    "artifact_or_dynamic_CI_change"
)
CI_DERIVATION = (
    "distinct_ci_family_values_from_phase16_opening_entries_in_first_"
    "occurrence_order"
)
CI_WORKFLOW_POLICY = (
    "planning_projection_only_no_phase16_level2_workflow_rows_until_"
    "capability_migration"
)
IMMUTABLE_FIELDS = (
    "id", "parent", "feature_family", "ci_family", "capability_owner",
    "diagnostic_owner", "target_applicability",
)
SNAPSHOT_FIELDS = {
    "opening_version", "inventory_version", "status",
    "predecessor_closure_version", "review_view", "immutable_fields",
    "entries", "residual_rebase", "ci_family_projection",
    "comparison_policy", "behavior_policy", "next_patch",
}
ENTRY_FIELDS = {
    "id", "parent", "feature_family", "ci_family", "capability_owner",
    "diagnostic_owner", "target_applicability", "status",
    "current_failure_stage", "positive_future_fixture",
    "negative_current_fixture",
}
REBASE_FIELDS = {
    "source_residual_id", "phase16_disposition",
    "selected_phase16_entry_ids", "reassigned_destination_phase",
    "reassigned_capability", "justification",
}
CI_FIELDS = {"derivation", "family_ids", "workflow_policy"}
OPENING_IDS = (
    "p16_function_abi_authority",
    "p16_canonical_call_result_mir",
    "p16_aggregate_parameter_abi",
    "p16_aggregate_return_hidden_result_abi",
    "p16_direct_call_agreement",
    "p16_typed_indirect_calls",
    "p16_fat_pointer_trait_object_call_abi",
    "p16_unsized_value_abi",
    "p16_dynamic_stack_storage",
    "p16_resource_aggregate_call_abi",
    "p16_cross_module_aggregate_resource_abi",
    "p16_abi_metadata_validation",
    "p16_complete_abi_differential",
)
PLANNING_CATEGORIES = (
    "function_abi_authority",
    "canonical_call_result_mir",
    "aggregate_parameter_abi",
    "aggregate_return_hidden_result_abi",
    "direct_call_agreement",
    "typed_indirect_calls",
    "fat_pointer_trait_object_call_abi",
    "unsized_value_abi",
    "dynamic_stack_storage",
    "resource_aggregate_call_abi",
    "cross_module_aggregate_resource_abi",
    "abi_metadata_validation",
    "complete_abi_differential_evidence",
)
CI_FAMILIES = (
    "call-mir", "aggregate-parameters", "aggregate-returns",
    "direct-call-agreement", "typed-indirect-calls", "fat-pointer-abi",
    "unsized-abi", "dynamic-stack", "resource-aggregate-abi",
    "cross-module-abi",
)
SELECTED_RESIDUALS = {
    "p15_unsized_types",
    "p15_trait_object_fat_pointers",
    "p16_dynamic_stack_allocation",
    "p15_aggregate_parameter_abi",
    "p15_aggregate_return_abi",
    "p16_resource_bearing_aggregate_moves",
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
    require(isinstance(value, dict), f"{path.relative_to(ROOT)} must be an object")
    return value


def nonempty(value: object, context: str) -> str:
    require(isinstance(value, str) and value, f"{context} must be a non-empty string")
    require(
        value.lower() not in {"unknown", "tbd", "ownerless", "ambiguous"},
        f"{context} is ambiguous",
    )
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
    require(properties.get("registry_version", {}).get("const") == 16,
            "schema registry version must be 16")
    require(properties.get("registry_status", {}).get("const") == REGISTRY_STATUS,
            "schema Phase 16 opening status drifted")
    require(properties.get("current_phase", {}).get("const") == "phase16",
            "schema current phase must be phase16")
    opening = properties.get("opening_snapshots", {})
    require(
        set(opening.get("required", []))
        == {"phase13", "phase14", "phase15", "phase16"},
        "schema opening snapshot keys drifted",
    )
    require(
        opening.get("properties", {}).get("phase16", {}).get("$ref")
        == "#/$defs/phase16_opening_snapshot",
        "schema does not route opening_snapshots.phase16 to its definition",
    )
    definitions = schema.get("$defs", {})
    snapshot = definitions.get("phase16_opening_snapshot", {})
    entry = definitions.get("phase16_opening_snapshot_entry", {})
    rebase = definitions.get("phase16_residual_rebase", {})
    projection = definitions.get("phase16_ci_family_projection", {})
    require(snapshot.get("additionalProperties") is False
            and set(snapshot.get("required", [])) == SNAPSHOT_FIELDS,
            "Phase 16 opening snapshot schema fields drifted")
    require(entry.get("additionalProperties") is False
            and set(entry.get("required", [])) == ENTRY_FIELDS,
            "Phase 16 opening entry schema fields drifted")
    require(rebase.get("additionalProperties") is False
            and set(rebase.get("required", [])) == REBASE_FIELDS,
            "Phase 16 residual rebase schema fields drifted")
    require(projection.get("additionalProperties") is False
            and set(projection.get("required", [])) == CI_FIELDS,
            "Phase 16 CI-family projection schema fields drifted")


def validate() -> dict:
    registry = read_json(REGISTRY)
    validate_schema(read_json(SCHEMA))

    require(registry.get("registry_version") == 16,
            "registry version must be 16")
    require(registry.get("registry_status") == REGISTRY_STATUS,
            "registry status does not record the Phase 16 opening")
    require(registry.get("current_phase") == "phase16",
            "Phase 16 is not the active registry phase")
    require(
        registry.get("closed_phase_versions", {}).get("phase15") == PREDECESSOR,
        "Phase 15 semantic closure is not recorded",
    )
    phase15_closure = registry.get("phase15_closure", {})
    require(
        phase15_closure.get("status") == PREDECESSOR
        and phase15_closure.get("worker_policy")
        == "isolated_worker_consumes_only_validated_request_canonical_mir_layout_and_resource_metadata",
        "Phase 15 semantic closure or worker boundary drifted",
    )

    snapshots = registry.get("opening_snapshots")
    require(
        isinstance(snapshots, dict)
        and set(snapshots) == {"phase13", "phase14", "phase15", "phase16"},
        "opening snapshots must contain Phase 13 through Phase 16",
    )
    snapshot = snapshots["phase16"]
    require(isinstance(snapshot, dict) and set(snapshot) == SNAPSHOT_FIELDS,
            "Phase 16 opening snapshot fields drifted")
    fixed = {
        "opening_version": OPENING_VERSION,
        "inventory_version": INVENTORY_VERSION,
        "status": STATUS,
        "predecessor_closure_version": PREDECESSOR,
        "review_view": REVIEW_PATH,
        "immutable_fields": list(IMMUTABLE_FIELDS),
        "comparison_policy": COMPARISON_POLICY,
        "behavior_policy": BEHAVIOR_POLICY,
        "next_patch": "16.1",
    }
    for field, expected in fixed.items():
        require(snapshot.get(field) == expected,
                f"Phase 16 opening {field} drifted")

    rows = snapshot.get("entries")
    require(isinstance(rows, list) and rows,
            "Phase 16 opening snapshot must contain rows")
    require(tuple(row.get("id") for row in rows) == OPENING_IDS,
            "Phase 16 opening row order or identity drifted")
    main_rows = {
        entry["id"]: entry for entry in registry.get("entries", [])
        if entry.get("origin_phase") == "phase16"
    }
    require(set(main_rows) == set(OPENING_IDS),
            "main registry Phase 16 rows differ from the opening snapshot")

    phase15_entries = {
        entry["id"]: entry for entry in registry.get("entries", [])
        if entry.get("origin_phase") == "phase15"
    }
    migrated_phase15 = {
        row["id"] for row in registry.get("phase15_deferred_residue_audit", {})
        .get("opening_dispositions", [])
        if row.get("disposition") == "migrated"
    }
    phase15_rebase = {
        row["source_residual_id"]: row
        for row in snapshots["phase15"]["residual_rebase"]
    }
    phase16_sources = {
        source_id for source_id, row in phase15_rebase.items()
        if row.get("reassigned_destination_phase") == "phase16"
    }
    require(phase16_sources == SELECTED_RESIDUALS,
            "Phase 15 residuals assigned to Phase 16 drifted")
    out_of_scope = [
        row for source_id, row in phase15_rebase.items()
        if source_id not in SELECTED_RESIDUALS
    ]
    require(out_of_scope and all(
        re.fullmatch(r"phase(17|18|19|2[0-9])",
                     row.get("reassigned_destination_phase", ""))
        for row in out_of_scope
    ), "out-of-scope Phase 15 residuals lost their later-phase assignment")
    narrow_residue = registry.get("phase15_deferred_residue_audit", {}).get(
        "narrow_deferred_rows", []
    )
    require(narrow_residue and all(
        row.get("destination_phase") != "phase16" for row in narrow_residue
    ), "Phase 15 closure residue was silently absorbed into Phase 16")

    planning = set(registry.get("planning_categories", []))
    require(set(PLANNING_CATEGORIES) <= planning,
            "Phase 16 planning categories are incomplete")
    parent_counts: Counter[str] = Counter()
    feature_counts: Counter[str] = Counter()
    family_counts: Counter[str] = Counter()
    derived_families: list[str] = []
    for index, row in enumerate(rows):
        context = f"opening_snapshots.phase16.entries[{index}]"
        require(isinstance(row, dict) and set(row) == ENTRY_FIELDS,
                f"{context} fields drifted")
        entry_id = nonempty(row.get("id"), f"{context}.id")
        require(re.fullmatch(r"p16_[A-Za-z0-9_]+", entry_id) is not None,
                f"{entry_id}: invalid Phase 16 row ID")
        parent = nonempty(row.get("parent"), f"{entry_id}.parent")
        parent_kind, parent_id = parent.split(":", 1)
        parent_counts[parent_kind] += 1
        if parent_kind == "phase15_entry":
            require(parent_id in phase15_entries and parent_id in migrated_phase15,
                    f"{entry_id}: Phase 15 entry parent is not migrated")
        elif parent_kind == "phase15_residual":
            require(parent_id in SELECTED_RESIDUALS,
                    f"{entry_id}: residual parent is not assigned to Phase 16")
        elif parent_kind == "phase16_category":
            require(parent_id in PLANNING_CATEGORIES and parent_id in planning,
                    f"{entry_id}: unknown Phase 16 category parent {parent_id}")
        else:
            raise Error(f"{entry_id}: invalid parent kind {parent_kind}")

        for field in (
            "feature_family", "ci_family", "capability_owner",
            "diagnostic_owner", "target_applicability", "current_failure_stage",
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
            "id", "parent", "feature_family", "ci_family", "diagnostic_owner",
            "target_applicability", "status", "current_failure_stage",
            "positive_future_fixture", "negative_current_fixture",
        )
        for field in mirror_fields:
            require(main.get(field) == row.get(field),
                    f"{entry_id}: main registry {field} differs from snapshot")
        require(main.get("worker_capability_owner") == row.get("capability_owner"),
                f"{entry_id}: capability owner differs from snapshot")
        evidence = main.get("evidence", {})
        require(
            main.get("route_owner") == "deferred"
            and main.get("source_fixture") == negative
            and main.get("canonical_mir_fixture")
            == "none_rejected_before_canonical_MIR"
            and main.get("differential_case_id") == f"phase16_opening:{entry_id}"
            and main.get("deferral_reason")
            == f"phase16_opening_{entry_id}_awaits_compiler_owned_function_abi_authority"
            and main.get("future_destination_phase") == "phase16"
            and main.get("closure_version") == INVENTORY_VERSION
            and evidence.get("opening_record_kind") == "phase16_candidate"
            and evidence.get("planning_category") in PLANNING_CATEGORIES
            and evidence.get("phase15_closure_dependency") == PREDECESSOR
            and evidence.get("behavior_policy") == ENTRY_BEHAVIOR_POLICY
            and evidence.get("phase16_1_boundary")
            == "compiler_owned_function_ABI_authority_not_implemented_by_patch16_0",
            f"{entry_id}: main registry opening state drifted",
        )
        feature_counts[row["feature_family"]] += 1
        family_counts[row["ci_family"]] += 1
        if row["ci_family"] not in derived_families:
            derived_families.append(row["ci_family"])

    require(set(parent_counts)
            == {"phase15_entry", "phase15_residual", "phase16_category"},
            "Phase 16 opening lacks a required parent traceability kind")

    rebase_rows = snapshot.get("residual_rebase")
    require(isinstance(rebase_rows, list) and rebase_rows,
            "Phase 16 residual rebase must contain rows")
    require({row.get("source_residual_id") for row in rebase_rows}
            == SELECTED_RESIDUALS,
            "Phase 16 residual rebase must consume the exact assigned sources")
    selected_refs: set[str] = set()
    for index, row in enumerate(rebase_rows):
        context = f"opening_snapshots.phase16.residual_rebase[{index}]"
        require(isinstance(row, dict) and set(row) == REBASE_FIELDS,
                f"{context} fields drifted")
        source_id = nonempty(row.get("source_residual_id"),
                             f"{context}.source_residual_id")
        require(phase15_rebase[source_id]["reassigned_destination_phase"] == "phase16",
                f"{source_id}: source is not assigned to Phase 16")
        selected = unique_strings(row.get("selected_phase16_entry_ids"),
                                  f"{source_id}.selected_phase16_entry_ids")
        require(selected and set(selected) <= set(OPENING_IDS),
                f"{source_id}: selected rows are missing or unknown")
        selected_refs.update(selected)
        require(
            row.get("phase16_disposition") == "selected"
            and row.get("reassigned_destination_phase") == "none_selected"
            and row.get("reassigned_capability") == "none_selected",
            f"{source_id}: selected source retains stale later-phase data",
        )
        nonempty(row.get("justification"), f"{source_id}.justification")
    residual_parent_rows = {
        row["id"] for row in rows
        if row["parent"].startswith("phase15_residual:")
    }
    require(residual_parent_rows <= selected_refs,
            "every Phase 15 residual parent must be selected by the rebase")

    projection = snapshot.get("ci_family_projection")
    require(isinstance(projection, dict) and set(projection) == CI_FIELDS,
            "Phase 16 CI-family projection fields drifted")
    require(projection.get("derivation") == CI_DERIVATION,
            "Phase 16 CI-family derivation drifted")
    require(projection.get("family_ids") == derived_families == list(CI_FAMILIES),
            "Phase 16 CI-family projection is not row-derived")
    require(projection.get("workflow_policy") == CI_WORKFLOW_POLICY,
            "Phase 16 CI-family workflow policy drifted")

    return {
        "snapshot": snapshot,
        "rows": rows,
        "rebase_rows": rebase_rows,
        "parent_counts": parent_counts,
        "feature_counts": feature_counts,
        "family_counts": family_counts,
    }


def cell(value: object) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def count_lines(counter: Counter[str]) -> list[str]:
    return [f"- `{key}`: `{counter[key]}`" for key in sorted(counter)]


def render(contract: dict) -> str:
    snapshot = contract["snapshot"]
    lines = [
        "# Cranelift Phase 16 Function ABI and Aggregate Call Opening Inventory",
        "",
        "<!-- Generated by scripts/phase16_opening.py; do not edit by hand. -->",
        "",
        "CRANELIFT_PHASE16_OPENING_VIEW_VERSION: 1",
        f"CRANELIFT_PHASE16_OPENING_VERSION: {OPENING_VERSION}",
        f"CRANELIFT_PHASE16_INVENTORY_VERSION: {INVENTORY_VERSION}",
        f"CRANELIFT_PHASE16_OPENING_STATUS: {STATUS}",
        f"CRANELIFT_PHASE16_OPENING_PREDECESSOR: {PREDECESSOR}",
        "CRANELIFT_PHASE16_OPENING_AUTHORITY: scripts/cranelift_feature_registry.json",
        "CRANELIFT_PHASE16_OPENING_GUARD: guard-cranelift-phase16-opening-contract",
        f"CRANELIFT_PHASE16_OPENING_TARGET_POLICY: {TARGET_POLICY}",
        f"CRANELIFT_PHASE16_OPENING_CI_DERIVATION: {CI_DERIVATION}",
        f"CRANELIFT_PHASE16_OPENING_BEHAVIOR_POLICY: {BEHAVIOR_POLICY}",
        "",
        "## Patch 16.0 opening inventory and Phase 15 residual rebase",
        "",
        "This semantic opening snapshot selects only compiler-owned function ABI, canonical call transport, aggregate parameter and return, typed indirect call, fat-pointer, unsized value, bounded dynamic frame, resource-bearing aggregate call, selected cross-module, metadata-validation, and differential-evidence work. It changes no compiler, backend, runtime, canonical MIR, request, ABI lowering, object, link, packaging, Level 2, or Level 3 behavior.",
        "",
        "## Derived opening totals",
        "",
        f"- Opening rows: `{len(contract['rows'])}`",
        f"- Phase 15 residual capabilities selected: `{len(contract['rebase_rows'])}`",
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
        "## Opening entries",
        "",
        "| ID | Parent | Feature family | Planned CI family | Capability owner | Diagnostic owner | Target applicability | Status | Failure stage | Future positive | Current negative |",
        "|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    for row in contract["rows"]:
        values = (
            row["id"], row["parent"], row["feature_family"], row["ci_family"],
            row["capability_owner"], row["diagnostic_owner"],
            row["target_applicability"], row["status"],
            row["current_failure_stage"], row["positive_future_fixture"],
            row["negative_current_fixture"],
        )
        lines.append("| " + " | ".join(cell(value) for value in values) + " |")

    lines += [
        "",
        "## Phase 15 residual rebase",
        "",
        "| Phase 15 residual | Phase 16 disposition | Selected Phase 16 rows | Later destination | Later capability | Justification |",
        "|---|---|---|---|---|---|",
    ]
    for row in contract["rebase_rows"]:
        values = (
            row["source_residual_id"], row["phase16_disposition"],
            ", ".join(row["selected_phase16_entry_ids"]) or "none",
            row["reassigned_destination_phase"], row["reassigned_capability"],
            row["justification"],
        )
        lines.append("| " + " | ".join(cell(value) for value in values) + " |")

    lines += [
        "",
        "## Opening invariants",
        "",
        "- The Phase 15 semantic resource-and-lifetime closure is the immutable predecessor.",
        "- Every Phase 16 row has a stable identity, owner, target, failure stage, and fixture pair.",
        "- Parent traceability covers migrated Phase 15 entries, the six Phase 15 residual capabilities assigned to Phase 16, and explicit Phase 16 planning categories.",
        "- Only function ABI, aggregate transport, typed call, unsized transport, dynamic frame, and resource-bearing call work enters Phase 16.",
        "- Variadics, closures, arbitrary foreign ABI, heap and GC policy, exception handling, concurrency, target extensions, and linker ownership remain outside Phase 16.",
        "- The planned Phase 16 CI-family projection is row-derived and adds no Level 2 workflow rows.",
        "- MIR-to-C remains the default differential oracle and explicit Cranelift remains no-fallback.",
        "- Phase 14 retains layout ownership, Phase 15 retains resource ownership, and Phase 9G retains artifact ownership.",
        "- Generated totals and Markdown are review projections rather than semantic authorities.",
        "- Raw registry, MIR, emitted-signature, object, fixture, or Markdown hashes are forbidden as semantic contracts.",
        "",
        "Patch 16.0 opening inventory is active; Phase 16 may proceed to Patch 16.1.",
        "",
    ]
    rendered = "\n".join(lines)
    for banned in ("SHA256", "SHA-256", "sha256sum"):
        require(banned not in rendered,
                f"Phase 16 opening review contains banned hash token: {banned}")
    return rendered


def check_review(contract: dict) -> None:
    require(REVIEW.is_file(), f"missing generated review: {REVIEW.relative_to(ROOT)}")
    require(
        REVIEW.read_text(encoding="utf-8") == render(contract),
        "Phase 16 opening review is stale; run "
        "`python3 scripts/phase16_opening.py project`",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review", "families"))
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
        print(f"Phase 16 opening error: {exc}", file=sys.stderr)
        return 1

    messages = {
        "validate": (
            "✅ Phase 16 opening inventory passed: "
            f"rows={len(contract['rows'])} "
            f"phase15_residuals={len(contract['rebase_rows'])} "
            f"planned_families={len(contract['snapshot']['ci_family_projection']['family_ids'])}."
        ),
        "project": "✅ Phase 16 opening review generated.",
        "check-review": "✅ Phase 16 opening review matches the canonical registry.",
    }
    print(messages[command])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
