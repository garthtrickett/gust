#!/usr/bin/env python3
"""Validate and render the Patch 17.0 native runtime opening inventory."""

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
REVIEW = ROOT / "compiler/CRANELIFT_PHASE17_OPENING.md"

OPENING_VERSION = "phase17_opening_inventory_rebased_on_phase16_closure"
INVENTORY_VERSION = "phase17_opening_inventory_v1"
STATUS = "ready_for_patch17_1"
REGISTRY_STATUS = "phase17_opening_native_runtime_boundary_inventory"
PREDECESSOR = "phase16_closed_function_abi_and_aggregate_call_semantics"
REVIEW_PATH = "compiler/CRANELIFT_PHASE17_OPENING.md"
TARGET_POLICY = "all_declared_host_targets_from_phase14_target_authority"
COMPARISON_POLICY = (
    "semantic_opening_fields_parent_traceability_helper_inventory_and_"
    "residual_rebase_only_generated_totals_and_markdown_are_derived"
)
BEHAVIOR_POLICY = (
    "registry_projection_guard_and_fixture_inventory_only_no_compiler_"
    "backend_runtime_MIR_request_ABI_runtime_package_object_link_CLI_or_"
    "level2_level3_workflow_change"
)
ENTRY_BEHAVIOR_POLICY = (
    "opening_inventory_only_no_compiler_backend_runtime_MIR_request_ABI_"
    "runtime_package_artifact_or_dynamic_CI_change"
)
CI_DERIVATION = (
    "distinct_ci_family_values_from_phase17_opening_entries_in_first_"
    "occurrence_order"
)
CI_WORKFLOW_POLICY = (
    "planning_projection_only_no_phase17_level2_workflow_rows_until_"
    "capability_migration"
)
IMMUTABLE_FIELDS = (
    "id", "parent", "feature_family", "ci_family", "capability_owner",
    "diagnostic_owner", "helper_category", "target_applicability",
)
SNAPSHOT_FIELDS = {
    "opening_version", "inventory_version", "status",
    "predecessor_closure_version", "review_view", "immutable_fields",
    "entries", "residual_rebase", "ci_family_projection",
    "helper_inventory",
    "comparison_policy", "behavior_policy", "next_patch",
}
ENTRY_FIELDS = {
    "id", "parent", "feature_family", "ci_family", "capability_owner",
    "diagnostic_owner", "helper_category", "target_applicability", "status",
    "current_failure_stage", "positive_future_fixture",
    "negative_current_fixture",
}
REBASE_FIELDS = {
    "source_residual_id", "phase17_disposition",
    "selected_phase17_entry_ids", "reassigned_destination_phase",
    "reassigned_capability", "justification",
}
CI_FIELDS = {"derivation", "family_ids", "workflow_policy"}
HELPER_INVENTORY_FIELDS = {
    "id", "symbol_identity", "symbol_kind", "source_path", "reachability",
    "inventory_owner", "diagnostic_owner", "owning_phase17_entry_id",
    "initial_classification", "target_applicability",
}

OPENING_IDS = (
    "p17_runtime_abi_authority",
    "p17_helper_classification_authority",
    "p17_runtime_symbol_versioning",
    "p17_runtime_requirement_transport",
    "p17_target_runtime_packages",
    "p17_stable_runtime_imports",
    "p17_rust_runtime_components",
    "p17_retained_c_runtime_components",
    "p17_gust_runtime_components",
    "p17_obsolete_helper_removal",
    "p17_generated_c_shim_elimination",
    "p17_allocation_string_runtime",
    "p17_io_filesystem_runtime",
    "p17_resource_runtime",
    "p17_threading_runtime",
    "p17_runtime_availability_compatibility",
    "p17_complete_runtime_differential",
)
PLANNING_CATEGORIES = (
    "runtime_abi_authority",
    "helper_classification_authority",
    "runtime_symbol_versioning",
    "runtime_requirement_transport",
    "target_runtime_packages",
    "stable_runtime_imports",
    "rust_runtime_components",
    "retained_c_runtime_components",
    "gust_runtime_components",
    "obsolete_helper_removal",
    "generated_c_shim_elimination",
    "allocation_string_runtime",
    "io_filesystem_runtime",
    "resource_runtime",
    "threading_runtime",
    "runtime_availability_compatibility",
    "complete_runtime_differential_evidence",
)
CI_FAMILIES = (
    "runtime-abi", "runtime-symbols", "runtime-packages",
    "runtime-imports", "runtime-rust-components", "runtime-c-components",
    "runtime-gust-components", "runtime-allocation-strings",
    "runtime-io-filesystem", "runtime-resources", "runtime-threading",
    "runtime-diagnostics",
)
HELPER_CATEGORIES = {
    "classification_pending_patch17_1",
    "stable_runtime_library_function",
    "rust_runtime_component",
    "retained_c_runtime_component",
    "pure_gust_runtime_component",
    "obsolete_helper",
    "cross_category_contract",
}
SELECTED_RESIDUALS = {
    "p17_cross_version_module_abi",
    "p17_dynamic_library_symbol_version_abi",
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
    require(properties.get("registry_version", {}).get("const") == 17,
            "schema registry version must be 17")
    require(properties.get("registry_status", {}).get("const") == REGISTRY_STATUS,
            "schema Phase 17 opening status drifted")
    require(properties.get("current_phase", {}).get("const") == "phase17",
            "schema current phase must be phase17")
    opening = properties.get("opening_snapshots", {})
    require(
        set(opening.get("required", []))
        == {"phase13", "phase14", "phase15", "phase16", "phase17", "phase18", "phase19", "phase20"},
        "schema opening snapshot keys drifted",
    )
    require(
        opening.get("properties", {}).get("phase17", {}).get("$ref")
        == "#/$defs/phase17_opening_snapshot",
        "schema does not route opening_snapshots.phase17 to its definition",
    )
    definitions = schema.get("$defs", {})
    snapshot = definitions.get("phase17_opening_snapshot", {})
    entry = definitions.get("phase17_opening_snapshot_entry", {})
    rebase = definitions.get("phase17_residual_rebase", {})
    projection = definitions.get("phase17_ci_family_projection", {})
    helper_inventory = definitions.get("phase17_helper_inventory_entry", {})
    require(snapshot.get("additionalProperties") is False
            and set(snapshot.get("required", [])) == SNAPSHOT_FIELDS,
            "Phase 17 opening snapshot schema fields drifted")
    require(entry.get("additionalProperties") is False
            and set(entry.get("required", [])) == ENTRY_FIELDS,
            "Phase 17 opening entry schema fields drifted")
    require(rebase.get("additionalProperties") is False
            and set(rebase.get("required", [])) == REBASE_FIELDS,
            "Phase 17 residual rebase schema fields drifted")
    require(projection.get("additionalProperties") is False
            and set(projection.get("required", [])) == CI_FIELDS,
            "Phase 17 CI-family projection schema fields drifted")
    require(helper_inventory.get("additionalProperties") is False
            and set(helper_inventory.get("required", []))
            == HELPER_INVENTORY_FIELDS,
            "Phase 17 helper inventory schema fields drifted")


def validate() -> dict:
    registry = read_json(REGISTRY)
    validate_schema(read_json(SCHEMA))

    require(registry.get("registry_version") == 17,
            "registry version must be 17")
    require(registry.get("registry_status") == REGISTRY_STATUS,
            "registry status does not record the Phase 17 opening")
    require(registry.get("current_phase") == "phase17",
            "Phase 17 is not the active registry phase")
    require(
        registry.get("closed_phase_versions", {}).get("phase16") == PREDECESSOR,
        "Phase 16 semantic closure is not recorded",
    )
    closure = registry.get("phase16_closure", {})
    require(
        closure.get("status") == PREDECESSOR
        and closure.get("worker_policy")
        == "isolated_worker_consumes_only_validated_request_canonical_mir_layout_resource_and_abi_metadata",
        "Phase 16 semantic closure or worker boundary drifted",
    )

    snapshots = registry.get("opening_snapshots")
    require(
        isinstance(snapshots, dict)
        and set(snapshots)
        == {"phase13", "phase14", "phase15", "phase16", "phase17", "phase18", "phase19", "phase20"},
        "opening snapshots must contain Phase 13 through Phase 19",
    )
    snapshot = snapshots["phase17"]
    require(isinstance(snapshot, dict) and set(snapshot) == SNAPSHOT_FIELDS,
            "Phase 17 opening snapshot fields drifted")
    fixed = {
        "opening_version": OPENING_VERSION,
        "inventory_version": INVENTORY_VERSION,
        "status": STATUS,
        "predecessor_closure_version": PREDECESSOR,
        "review_view": REVIEW_PATH,
        "immutable_fields": list(IMMUTABLE_FIELDS),
        "comparison_policy": COMPARISON_POLICY,
        "behavior_policy": BEHAVIOR_POLICY,
        "next_patch": "17.1",
    }
    for field, expected in fixed.items():
        require(snapshot.get(field) == expected,
                f"Phase 17 opening {field} drifted")

    rows = snapshot.get("entries")
    require(isinstance(rows, list) and rows,
            "Phase 17 opening snapshot must contain rows")
    require(tuple(row.get("id") for row in rows) == OPENING_IDS,
            "Phase 17 opening row order or identity drifted")
    main_rows = {
        entry["id"]: entry for entry in registry.get("entries", [])
        if entry.get("origin_phase") == "phase17"
    }
    require(set(main_rows) == set(OPENING_IDS),
            "main registry Phase 17 rows differ from the opening snapshot")

    phase16_entries = {
        entry["id"]: entry for entry in registry.get("entries", [])
        if entry.get("origin_phase") == "phase16"
    }
    migrated_phase16 = {
        row["id"] for row in registry.get("phase16_deferred_residue_audit", {})
        .get("opening_dispositions", [])
        if row.get("disposition") == "migrated"
    }
    source_residue = {
        row["id"]: row
        for row in registry.get("phase16_deferred_residue_audit", {})
        .get("narrow_deferred_rows", [])
        if row.get("destination_phase") == "phase17"
    }
    require(source_residue, "Phase 16 closure has no Phase 17 residual input")

    planning = set(registry.get("planning_categories", []))
    require(set(PLANNING_CATEGORIES) <= planning,
            "Phase 17 planning categories are incomplete")
    parent_counts: Counter[str] = Counter()
    feature_counts: Counter[str] = Counter()
    family_counts: Counter[str] = Counter()
    category_counts: Counter[str] = Counter()
    derived_families: list[str] = []
    for index, row in enumerate(rows):
        context = f"opening_snapshots.phase17.entries[{index}]"
        require(isinstance(row, dict) and set(row) == ENTRY_FIELDS,
                f"{context} fields drifted")
        entry_id = nonempty(row.get("id"), f"{context}.id")
        require(re.fullmatch(r"p17_[A-Za-z0-9_]+", entry_id) is not None,
                f"{entry_id}: invalid Phase 17 row ID")
        parent = nonempty(row.get("parent"), f"{entry_id}.parent")
        parent_kind, parent_id = parent.split(":", 1)
        parent_counts[parent_kind] += 1
        if parent_kind == "phase16_entry":
            require(parent_id in phase16_entries and parent_id in migrated_phase16,
                    f"{entry_id}: Phase 16 entry parent is not migrated")
        elif parent_kind == "phase16_residual":
            require(parent_id in source_residue,
                    f"{entry_id}: residual parent is not assigned to Phase 17")
        elif parent_kind == "phase17_category":
            require(parent_id in PLANNING_CATEGORIES and parent_id in planning,
                    f"{entry_id}: unknown Phase 17 category parent {parent_id}")
        else:
            raise Error(f"{entry_id}: invalid parent kind {parent_kind}")

        for field in (
            "feature_family", "ci_family", "capability_owner",
            "diagnostic_owner", "target_applicability", "current_failure_stage",
        ):
            nonempty(row.get(field), f"{entry_id}.{field}")
        helper_category = nonempty(
            row.get("helper_category"), f"{entry_id}.helper_category"
        )
        require(helper_category in HELPER_CATEGORIES,
                f"{entry_id}: unknown helper category {helper_category}")
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
            and main.get("differential_case_id") == f"phase17_opening:{entry_id}"
            and main.get("deferral_reason")
            == f"phase17_opening_{entry_id}_awaits_compiler_owned_runtime_boundary_authority"
            and main.get("future_destination_phase") == "phase17"
            and main.get("closure_version") == INVENTORY_VERSION
            and evidence.get("opening_record_kind") == "phase17_candidate"
            and evidence.get("planning_category") in PLANNING_CATEGORIES
            and evidence.get("helper_category") == helper_category
            and evidence.get("phase16_closure_dependency") == PREDECESSOR
            and evidence.get("behavior_policy") == ENTRY_BEHAVIOR_POLICY
            and evidence.get("phase17_1_boundary")
            == "compiler_owned_runtime_boundary_and_helper_classification_authority_not_implemented_by_patch17_0",
            f"{entry_id}: main registry opening state drifted",
        )
        feature_counts[row["feature_family"]] += 1
        family_counts[row["ci_family"]] += 1
        category_counts[helper_category] += 1
        if row["ci_family"] not in derived_families:
            derived_families.append(row["ci_family"])

    require(set(parent_counts)
            == {"phase16_entry", "phase16_residual", "phase17_category"},
            "Phase 17 opening lacks a required parent traceability kind")

    helper_rows = snapshot.get("helper_inventory")
    require(isinstance(helper_rows, list) and helper_rows,
            "Phase 17 helper inventory must contain rows")
    helper_ids: set[str] = set()
    symbol_identities: set[str] = set()
    helper_owner_counts: Counter[str] = Counter()
    source_paths: set[str] = set()
    for index, helper in enumerate(helper_rows):
        context = f"opening_snapshots.phase17.helper_inventory[{index}]"
        require(isinstance(helper, dict)
                and set(helper) == HELPER_INVENTORY_FIELDS,
                f"{context} fields drifted")
        helper_id = nonempty(helper.get("id"), f"{context}.id")
        require(re.fullmatch(r"p17_helper_[A-Za-z0-9_]+", helper_id) is not None,
                f"{helper_id}: invalid helper inventory ID")
        require(helper_id not in helper_ids,
                f"duplicate Phase 17 helper inventory ID: {helper_id}")
        helper_ids.add(helper_id)
        symbol = nonempty(helper.get("symbol_identity"),
                          f"{helper_id}.symbol_identity")
        require(symbol not in symbol_identities,
                f"duplicate Phase 17 helper symbol identity: {symbol}")
        symbol_identities.add(symbol)
        require(helper.get("symbol_kind")
                in {"exact_c_symbol", "generated_c_symbol_family"},
                f"{helper_id}: invalid symbol kind")
        require(helper.get("reachability") in {
            "runtime_public_surface", "runtime_component_internal",
            "compiler_generated_c_shim",
        }, f"{helper_id}: invalid reachability")
        source_path = nonempty(helper.get("source_path"),
                               f"{helper_id}.source_path")
        require((ROOT / source_path).is_file(),
                f"{helper_id}: missing helper source path {source_path}")
        source_text = (ROOT / source_path).read_text(encoding="utf-8")
        if helper.get("symbol_kind") == "exact_c_symbol":
            require(re.search(rf"\b{re.escape(symbol)}\s*\(", source_text)
                    is not None,
                    f"{helper_id}: exact symbol is absent from {source_path}")
        else:
            probes = [part.replace("*", "") for part in symbol.split("/")]
            require(all(probe and probe in source_text for probe in probes),
                    f"{helper_id}: generated family probe is absent from {source_path}")
        source_paths.add(source_path)
        owner_id = nonempty(helper.get("owning_phase17_entry_id"),
                            f"{helper_id}.owning_phase17_entry_id")
        require(owner_id in main_rows,
                f"{helper_id}: unknown owning Phase 17 entry {owner_id}")
        owner_row = main_rows[owner_id]
        require(helper.get("inventory_owner")
                == owner_row.get("worker_capability_owner"),
                f"{helper_id}: inventory owner differs from owning row")
        require(helper.get("diagnostic_owner")
                == owner_row.get("diagnostic_owner"),
                f"{helper_id}: diagnostic owner differs from owning row")
        require(helper.get("initial_classification")
                == "classification_pending_patch17_1",
                f"{helper_id}: Patch 17.0 must leave classification to Patch 17.1")
        require(helper.get("target_applicability") == TARGET_POLICY,
                f"{helper_id}: target applicability drifted")
        helper_owner_counts[owner_id] += 1

    required_sources = {
        "src/runtime/arena.c", "src/runtime/scratch.c",
        "src/runtime/collections.c", "src/runtime/core_headers.h",
        "src/runtime/approved_scalar_imports.c", "src/runtime/file_io.c",
        "src/runtime/host_io.c", "src/runtime/strings.c",
        "src/runtime/fiber.c",
        "compiler/codegen.gst",
    }
    require(source_paths == required_sources,
            "Phase 17 helper source-unit inventory drifted")
    require({
        "p17_allocation_string_runtime", "p17_io_filesystem_runtime",
        "p17_resource_runtime", "p17_threading_runtime",
        "p17_stable_runtime_imports", "p17_generated_c_shim_elimination",
    } <= set(helper_owner_counts),
            "Phase 17 selected helper domains do not all own inventory rows")

    rebase_rows = snapshot.get("residual_rebase")
    require(isinstance(rebase_rows, list) and rebase_rows,
            "Phase 17 residual rebase must contain rows")
    require({row.get("source_residual_id") for row in rebase_rows}
            == set(source_residue),
            "Phase 17 residual rebase must classify every assigned source")
    selected_refs: set[str] = set()
    for index, row in enumerate(rebase_rows):
        context = f"opening_snapshots.phase17.residual_rebase[{index}]"
        require(isinstance(row, dict) and set(row) == REBASE_FIELDS,
                f"{context} fields drifted")
        source_id = nonempty(row.get("source_residual_id"),
                             f"{context}.source_residual_id")
        selected = unique_strings(row.get("selected_phase17_entry_ids"),
                                  f"{source_id}.selected_phase17_entry_ids")
        require(set(selected) <= set(OPENING_IDS),
                f"{source_id}: selected rows contain an unknown Phase 17 ID")
        selected_refs.update(selected)
        disposition = row.get("phase17_disposition")
        destination = nonempty(row.get("reassigned_destination_phase"),
                               f"{source_id}.reassigned_destination_phase")
        capability = nonempty(row.get("reassigned_capability"),
                              f"{source_id}.reassigned_capability")
        nonempty(row.get("justification"), f"{source_id}.justification")
        if disposition == "split":
            require(
                source_id in SELECTED_RESIDUALS and selected
                and re.fullmatch(r"phase(18|19|2[0-9])", destination)
                and capability != "none_selected",
                f"{source_id}: split residual lacks a selected runtime slice or concrete remainder",
            )
        elif disposition == "reassigned":
            require(
                source_id not in SELECTED_RESIDUALS and not selected
                and re.fullmatch(r"phase(18|19|2[0-9])", destination)
                and capability != "none_selected",
                f"{source_id}: out-of-scope residual was not concretely reassigned",
            )
        else:
            raise Error(f"{source_id}: invalid Phase 17 disposition {disposition}")
    residual_parent_rows = {
        row["id"] for row in rows
        if row["parent"].startswith("phase16_residual:")
    }
    require(residual_parent_rows <= selected_refs,
            "every Phase 16 residual parent must be selected by the rebase")

    projection = snapshot.get("ci_family_projection")
    require(isinstance(projection, dict) and set(projection) == CI_FIELDS,
            "Phase 17 CI-family projection fields drifted")
    require(projection.get("derivation") == CI_DERIVATION,
            "Phase 17 CI-family derivation drifted")
    require(projection.get("family_ids") == derived_families == list(CI_FAMILIES),
            "Phase 17 CI-family projection is not row-derived")
    require(projection.get("workflow_policy") == CI_WORKFLOW_POLICY,
            "Phase 17 CI-family workflow policy drifted")

    return {
        "snapshot": snapshot,
        "rows": rows,
        "helper_rows": helper_rows,
        "helper_owner_counts": helper_owner_counts,
        "rebase_rows": rebase_rows,
        "parent_counts": parent_counts,
        "feature_counts": feature_counts,
        "family_counts": family_counts,
        "category_counts": category_counts,
    }


def cell(value: object) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def count_lines(counter: Counter[str]) -> list[str]:
    return [f"- `{key}`: `{counter[key]}`" for key in sorted(counter)]


def render(contract: dict) -> str:
    snapshot = contract["snapshot"]
    lines = [
        "# Cranelift Phase 17 Native Runtime Boundary Opening Inventory",
        "",
        "<!-- Generated by scripts/phase17_opening.py; do not edit by hand. -->",
        "",
        "CRANELIFT_PHASE17_OPENING_VIEW_VERSION: 1",
        f"CRANELIFT_PHASE17_OPENING_VERSION: {OPENING_VERSION}",
        f"CRANELIFT_PHASE17_INVENTORY_VERSION: {INVENTORY_VERSION}",
        f"CRANELIFT_PHASE17_OPENING_STATUS: {STATUS}",
        f"CRANELIFT_PHASE17_OPENING_PREDECESSOR: {PREDECESSOR}",
        "CRANELIFT_PHASE17_OPENING_AUTHORITY: scripts/cranelift_feature_registry.json",
        "CRANELIFT_PHASE17_OPENING_GUARD: guard-cranelift-phase17-opening-contract",
        f"CRANELIFT_PHASE17_OPENING_TARGET_POLICY: {TARGET_POLICY}",
        f"CRANELIFT_PHASE17_OPENING_CI_DERIVATION: {CI_DERIVATION}",
        f"CRANELIFT_PHASE17_OPENING_BEHAVIOR_POLICY: {BEHAVIOR_POLICY}",
        "",
        "## Patch 17.0 opening inventory and Phase 16 residual rebase",
        "",
        "This semantic opening snapshot selects only native runtime ABI, helper classification, symbol versioning, runtime requirement, package, implementation-component, generated-shim elimination, helper-domain audit, availability-diagnostic, and differential-evidence work. It changes no compiler, backend, runtime, canonical MIR, request, ABI lowering, package build, object, link, publication, Level 2, or Level 3 behavior.",
        "",
        "## Derived opening totals",
        "",
        f"- Opening rows: `{len(contract['rows'])}`",
        f"- Inventoried C-dependent helpers: `{len(contract['helper_rows'])}`",
        f"- Phase 16 residual capabilities classified: `{len(contract['rebase_rows'])}`",
        f"- Planned CI families: `{len(snapshot['ci_family_projection']['family_ids'])}`",
        "",
        "### Parent kinds", "", *count_lines(contract["parent_counts"]), "",
        "### Feature families", "", *count_lines(contract["feature_counts"]), "",
        "### Helper categories", "", *count_lines(contract["category_counts"]), "",
        "### Planned CI families", "", *count_lines(contract["family_counts"]), "",
        "## Opening entries", "",
        "| ID | Parent | Feature family | Planned CI family | Capability owner | Diagnostic owner | Helper category | Target applicability | Status | Failure stage | Future positive | Current negative |",
        "|---|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    for row in contract["rows"]:
        values = (
            row["id"], row["parent"], row["feature_family"], row["ci_family"],
            row["capability_owner"], row["diagnostic_owner"],
            row["helper_category"], row["target_applicability"], row["status"],
            row["current_failure_stage"], row["positive_future_fixture"],
            row["negative_current_fixture"],
        )
        lines.append("| " + " | ".join(cell(value) for value in values) + " |")

    lines += [
        "", "## C-dependent helper inventory", "",
        "| ID | Symbol or family | Kind | Source | Reachability | Owning row | Inventory owner | Diagnostic owner | Initial classification | Target applicability |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for row in contract["helper_rows"]:
        values = (
            row["id"], row["symbol_identity"], row["symbol_kind"],
            row["source_path"], row["reachability"],
            row["owning_phase17_entry_id"], row["inventory_owner"],
            row["diagnostic_owner"], row["initial_classification"],
            row["target_applicability"],
        )
        lines.append("| " + " | ".join(cell(value) for value in values) + " |")

    lines += [
        "", "## Phase 16 residual rebase", "",
        "| Phase 16 residual | Phase 17 disposition | Selected Phase 17 rows | Later destination | Later capability | Justification |",
        "|---|---|---|---|---|---|",
    ]
    for row in contract["rebase_rows"]:
        values = (
            row["source_residual_id"], row["phase17_disposition"],
            ", ".join(row["selected_phase17_entry_ids"]) or "none",
            row["reassigned_destination_phase"], row["reassigned_capability"],
            row["justification"],
        )
        lines.append("| " + " | ".join(cell(value) for value in values) + " |")

    lines += [
        "", "## Opening invariants", "",
        "- The Phase 16 semantic function ABI and aggregate-call closure is the immutable predecessor.",
        "- Every Phase 17 row has a stable identity, owner, helper category, target, failure stage, and fixture pair.",
        "- Every selected C-dependent runtime symbol or generated-C helper family has one stable inventory identity and one Phase 17 owner; final classification remains owned by Patch 17.1.",
        "- Parent traceability covers migrated Phase 16 entries, selected slices of the Phase 16 residual inventory, and explicit Phase 17 planning categories.",
        "- General variadics, foreign aggregate/resource ABI, complete platform ABI, dynamic loading, tail calls, and unwind personality semantics remain outside Phase 17.",
        "- Retained C means separately compiled explicit runtime components; program-generated C shims are not selected.",
        "- The planned Phase 17 CI-family projection is row-derived and adds no Level 2 workflow rows.",
        "- MIR-to-C remains the default differential oracle and explicit Cranelift remains no-fallback.",
        "- Phases 14–16 retain layout, resource, and function ABI ownership; Phase 9G retains artifact ownership.",
        "- Generated totals and Markdown are review projections rather than semantic authorities.",
        "- Raw registry, MIR, generated-C, object, archive, linker-command, fixture, or Markdown hashes are forbidden as semantic contracts.",
        "", "Patch 17.0 opening inventory is active; Phase 17 may proceed to Patch 17.1.", "",
    ]
    rendered = "\n".join(lines)
    for banned in ("SHA256", "SHA-256", "sha256sum"):
        require(banned not in rendered,
                f"Phase 17 opening review contains banned hash token: {banned}")
    return rendered


def check_review(contract: dict) -> None:
    require(REVIEW.is_file(), f"missing generated review: {REVIEW.relative_to(ROOT)}")
    require(
        REVIEW.read_text(encoding="utf-8") == render(contract),
        "Phase 17 opening review is stale; run "
        "`python3 scripts/phase17_opening.py project`",
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
        print(f"Phase 17 opening error: {exc}", file=sys.stderr)
        return 1

    messages = {
        "validate": (
            "✅ Phase 17 opening inventory passed: "
            f"rows={len(contract['rows'])} "
            f"helpers={len(contract['helper_rows'])} "
            f"phase16_residuals={len(contract['rebase_rows'])} "
            f"planned_families={len(contract['snapshot']['ci_family_projection']['family_ids'])}."
        ),
        "project": "✅ Phase 17 opening review generated.",
        "check-review": "✅ Phase 17 opening review matches the canonical registry.",
    }
    print(messages[command])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
