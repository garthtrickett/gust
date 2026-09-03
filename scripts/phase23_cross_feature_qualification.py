#!/usr/bin/env python3
"""Validate, project, and run Patch 23.13 cross-feature qualification."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import signal
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
ISSUES = ROOT / "docs/ISSUE_ROADMAP.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE23_CROSS_FEATURE_QUALIFICATION.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase23-cross-feature-qualification.yml"
GUARD_L1 = "guard-cranelift-phase23-cross-feature-qualification-contract"
GUARD_L2 = "guard-cranelift-phase23-cross-feature-qualification-evidence"

PHASE23_L1_GUARDS = [
    "guard-cranelift-phase23-issue-health-opening-contract",
    "guard-cranelift-phase23-mir-evidence-owner-contract",
    "guard-cranelift-phase23-resource-acquisition-parity-contract",
    "guard-cranelift-phase23-structured-guard-defer-native-admission-contract",
    "guard-cranelift-phase23-assurance-phase-a-contract",
    "guard-cranelift-phase23-assurance-phase-b-contract",
    "guard-cranelift-phase23-same-scope-declaration-contract",
    "guard-cranelift-phase23-mir-to-c-deprecation-opening-contract",
    "guard-cranelift-phase23-mir-to-c-frozen-surface-contract",
    "guard-cranelift-phase23-mir-to-c-focused-live-contract",
    "guard-cranelift-phase23-mir-to-c-archived-corpus-contract",
    "guard-cranelift-phase23-production-release-audit-contract",
]

PHASE23_L2_GUARDS = [
    "guard-cranelift-phase23-issue-health-opening-evidence",
    "guard-cranelift-phase23-structured-guard-defer-native-admission-evidence",
    "guard-cranelift-phase23-same-scope-declaration-evidence",
    "guard-cranelift-phase23-mir-to-c-deprecation-opening-evidence",
    "guard-cranelift-phase23-mir-to-c-frozen-surface-evidence",
    "guard-cranelift-phase23-mir-to-c-focused-live-evidence",
    "guard-cranelift-phase23-mir-to-c-archived-corpus-evidence",
    "guard-cranelift-phase23-production-release-audit-evidence",
]

SUPPLEMENTAL_L2_GUARDS = [
    "guard-cranelift-phase18-target-authority-parity",
    "guard-cranelift-phase18-target-support-parity",
    "guard-cranelift-phase18-target-diagnostic-parity",
    "guard-cranelift-phase20-resource-scope-cleanup-parity",
    "guard-cranelift-phase22-postflip-qualification-evidence",
]

STATIC_COMMANDS = [
    ["python3", "scripts/cranelift_registry.py", "validate"],
    ["python3", "scripts/cranelift_registry.py", "check-projection"],
    ["python3", "scripts/cranelift_test_levels.py", "validate"],
    ["python3", "scripts/cranelift_ci_family.py", "validate"],
    ["python3", "scripts/guard_reachability.py"],
    ["python3", "scripts/fixture_reachability.py"],
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    require(spec is not None and spec.loader is not None,
            f"cannot load {path.relative_to(ROOT)}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def phase23_guard_inventory(levels: dict[str, int], level: int) -> list[str]:
    return [guard for guard, assigned in levels.items()
            if guard.startswith("guard-cranelift-phase23-")
            and guard not in {
                GUARD_L1,
                GUARD_L2,
                "guard-cranelift-phase23-historical-full-qualification-contract",
                "guard-cranelift-phase23-close",
            }
            and assigned == level]


def current_consumer_inventory() -> dict[str, object]:
    module = load_module(
        "phase23_deprecation_opening",
        ROOT / "scripts/phase23_mir_to_c_deprecation_opening.py",
    )
    return module.inventory_summary()


def current_frozen_surface(registry: dict) -> dict[str, object]:
    module = load_module(
        "phase23_frozen_surface",
        ROOT / "scripts/phase23_mir_to_c_frozen_surface.py",
    )
    return module.scan(registry)["live_c_case_surface"]


def validate_transition(record: dict, registry: dict) -> None:
    opening = registry["phase23_mir_to_c_deprecation_opening"][
        "deprecation_contract"]["production_release_inventory_transition"]
    transition = record.get("consumer_inventory_transition", {})
    require(transition.get("contract_version") ==
            "phase23_cross_feature_consumer_inventory_transition_v1" and
            transition.get("status") == "patch23_13_complete" and
            transition.get("authority_base_main") ==
            "9b89296b25d2ab0cf1963ea1d1707139149d0576" and
            transition.get("previous_inventory") == opening["current_inventory"] and
            transition.get("unchanged_fields") == [
                "invocation_count", "invocation_manifest_digest",
                "structural_surface_count", "structural_manifest_digest",
                "classification_counts", "invocation_selection_counts",
                "unclassified_count",
            ] and transition.get("partial_or_unregistered_inventory") == "rejected",
            "Patch 23.13 consumer inventory transition drifted")
    for field in transition["unchanged_fields"]:
        require(transition["current_inventory"].get(field) ==
                transition["previous_inventory"].get(field),
                f"Patch 23.13 changed consumer inventory field: {field}")

    live_inventory = current_consumer_inventory()
    successor = registry.get("phase23_historical_full_qualification", {}).get(
        "consumer_inventory_transition")
    closure_successor = registry.get("phase23_closure", {}).get(
        "consumer_inventory_transition")
    roadmap_successor = registry.get("phase23_closure", {}).get(
        "phase24_opening_preflight_roadmap_transition")
    cr15_roadmap_successor = registry.get("phase23_closure", {}).get(
        "phase24_cr15_roadmap_amendment_transition")
    cr15_opening_successor = registry.get("phase23_closure", {}).get(
        "phase24_cr15_opening_transition")
    cr15_derivation_successor = registry.get(
        "phase24_cr15_derivation", {}).get("consumer_inventory_transition")
    cr15_qualification_successor = registry.get(
        "phase24_cr15_qualification", {}).get("consumer_inventory_transition")
    cr15_seed_successor = registry.get(
        "phase24_cr15_seed_authority_consumer_transition")
    if successor is None:
        require(transition.get("current_inventory") == live_inventory,
                "Patch 23.13 consumer inventory transition drifted")
    else:
        successor_fields = [
            "invocation_count", "invocation_manifest_digest",
            "structural_surface_count", "structural_manifest_digest",
            "invocation_selection_counts", "unclassified_count",
        ]
        added_paths = [
            "compiler/CRANELIFT_PHASE23_HISTORICAL_FULL_QUALIFICATION.md",
            "scripts/phase23_historical_full_qualification.py",
        ]
        require(successor.get("contract_version") ==
                "phase23_historical_consumer_inventory_transition_v1" and
                successor.get("status") == "patch23_14_complete" and
                successor.get("authority_base_main") ==
                "fee6600d86f85f8a0a0da94211ae89895869187e" and
                successor.get("previous_inventory") ==
                transition["current_inventory"] and
                successor.get("registered_added_paths") == added_paths and
                successor.get("unchanged_fields") == successor_fields and
                successor.get("partial_extra_or_substituted_surface") == "rejected",
                "Patch 23.14 consumer inventory successor drifted")
        for field in successor_fields:
            require(successor["current_inventory"].get(field) ==
                    successor["previous_inventory"].get(field),
                    f"Patch 23.14 changed consumer inventory field: {field}")
        require(successor["current_inventory"]["text_surface_count"] ==
                successor["previous_inventory"]["text_surface_count"] + 2,
                "Patch 23.14 did not add exactly two classified text surfaces")
        module = load_module(
            "phase23_deprecation_successor",
            ROOT / "scripts/phase23_mir_to_c_deprecation_opening.py",
        )
        added_rows = [row for row in module.scan_text_surfaces()
                      if row["path"] in added_paths]
        if closure_successor is None:
            require([row["path"] for row in added_rows] == added_paths and
                    successor.get("registered_added_text_surfaces") == added_rows,
                    "Patch 23.14 added surface manifest drifted")
            require(successor.get("current_inventory") == live_inventory,
                    "Patch 23.14 consumer inventory successor drifted")
        else:
            require([row.get("path") for row in successor.get(
                "registered_added_text_surfaces", [])] == added_paths,
                    "Patch 23.14 recorded added surface paths drifted")
            closure_paths = [
                "docs/PHASE23_CLOSURE.md",
                "scripts/phase23_closure.py",
            ]
            require(closure_successor.get("contract_version") ==
                    "phase23_closure_consumer_inventory_transition_v1" and
                    closure_successor.get("status") == "patch23_15_complete" and
                    closure_successor.get("authority_base_main") ==
                    "8985a3d09b1f119accd12cd952940ef019d6a698" and
                    closure_successor.get("previous_inventory") ==
                    successor["current_inventory"] and
                    closure_successor.get("registered_added_paths") == closure_paths and
                    closure_successor.get("unchanged_fields") == successor_fields and
                    closure_successor.get("partial_extra_or_substituted_surface") ==
                    "rejected",
                    "Patch 23.15 consumer inventory successor drifted")
            for field in successor_fields:
                require(closure_successor["current_inventory"].get(field) ==
                        closure_successor["previous_inventory"].get(field),
                        f"Patch 23.15 changed consumer inventory field: {field}")
            require(closure_successor["current_inventory"]["text_surface_count"] ==
                    closure_successor["previous_inventory"]["text_surface_count"] + 2,
                    "Patch 23.15 did not add exactly two classified text surfaces")
            closure_rows = [row for row in module.scan_text_surfaces()
                            if row["path"] in closure_paths]
            require([row.get("path") for row in closure_successor.get(
                        "registered_added_text_surfaces", [])] == closure_paths,
                    "Patch 23.15 recorded added surface paths drifted")
            if roadmap_successor is None:
                require(closure_successor.get(
                            "registered_added_text_surfaces") == closure_rows and
                        closure_successor.get("current_inventory") ==
                        live_inventory,
                        "Patch 23.15 consumer inventory successor drifted")
            else:
                changed_paths = ["TASK.md", "scripts/phase23_closure.py"]
                roadmap_fields = [
                    "text_surface_count", "invocation_count",
                    "invocation_manifest_digest", "structural_surface_count",
                    "structural_manifest_digest", "classification_counts",
                    "invocation_selection_counts", "unclassified_count",
                ]
                require(
                    roadmap_successor.get("contract_version") ==
                    "phase24_opening_preflight_roadmap_transition_v1" and
                    roadmap_successor.get("status") == "patch24_0_complete" and
                    roadmap_successor.get("authority_base_main") ==
                    "1c5e7fe5dee11aa00019bffafe14778a449b96d4" and
                    roadmap_successor.get("previous_inventory") ==
                    closure_successor["current_inventory"] and
                    roadmap_successor.get("current_inventory") ==
                    (live_inventory if cr15_roadmap_successor is None else
                     cr15_roadmap_successor.get("previous_inventory")) and
                    roadmap_successor.get("registered_changed_paths") ==
                    changed_paths and
                    roadmap_successor.get("unchanged_fields") == roadmap_fields and
                    roadmap_successor.get(
                        "partial_extra_or_substituted_surface") == "rejected",
                    "Patch 24.0 consumer inventory successor drifted")
                for field in roadmap_fields:
                    require(roadmap_successor["current_inventory"].get(field) ==
                            roadmap_successor["previous_inventory"].get(field),
                            f"Patch 24.0 changed consumer inventory field: {field}")
                live_rows = module.scan_text_surfaces()
                if cr15_roadmap_successor is None:
                    changed_rows = [row for row in live_rows
                                    if row["path"] in changed_paths]
                    require([row["path"] for row in changed_rows] == changed_paths and
                            roadmap_successor.get(
                                "current_changed_text_surfaces") == changed_rows,
                            "Patch 24.0 changed surface identity drifted")
                    require(module.canonical_digest([
                        row for row in live_rows if row["path"] not in changed_paths
                    ]) == roadmap_successor.get(
                        "unchanged_other_text_surface_manifest_digest"),
                        "Patch 24.0 changed an unregistered text surface")
                else:
                    require(
                        cr15_roadmap_successor.get("contract_version") ==
                        "phase24_cr15_roadmap_amendment_transition_v1" and
                        cr15_roadmap_successor.get("status") ==
                        "patch24_0a_complete" and
                        cr15_roadmap_successor.get("authority_base_main") ==
                        "86d13496fa83c6d3688402f09b77a8dfbb8168fc" and
                        cr15_roadmap_successor.get("previous_inventory") ==
                        roadmap_successor["current_inventory"] and
                        cr15_roadmap_successor.get(
                            "previous_changed_text_surfaces") ==
                        roadmap_successor["current_changed_text_surfaces"] and
                        cr15_roadmap_successor.get("registered_changed_paths") ==
                        changed_paths and
                        cr15_roadmap_successor.get("unchanged_fields") ==
                        roadmap_fields and
                        cr15_roadmap_successor.get(
                            "partial_extra_or_substituted_surface") == "rejected",
                        "Patch 24.0a CR-15 consumer inventory successor drifted")
                    for field in roadmap_fields:
                        require(cr15_roadmap_successor["current_inventory"].get(field) ==
                                roadmap_successor["current_inventory"].get(field),
                                f"Patch 24.0a changed consumer inventory field: {field}")
                    if cr15_opening_successor is None:
                        require(cr15_roadmap_successor["current_inventory"] ==
                                live_inventory,
                                "Patch 24.0a CR-15 inventory successor drifted")
                        changed_rows = [row for row in live_rows
                                        if row["path"] in changed_paths]
                        require([row["path"] for row in changed_rows] == changed_paths and
                                cr15_roadmap_successor.get(
                                    "current_changed_text_surfaces") == changed_rows,
                                "Patch 24.0a changed surface identity drifted")
                        require(module.canonical_digest([
                            row for row in live_rows if row["path"] not in changed_paths
                        ]) == cr15_roadmap_successor.get(
                            "unchanged_other_text_surface_manifest_digest"),
                            "Patch 24.0a changed an unregistered text surface")
                    else:
                        require(
                            cr15_opening_successor.get("contract_version") ==
                            "phase24_cr15_opening_transition_v1" and
                            cr15_opening_successor.get("status") ==
                            "patch24_0b_complete_inert" and
                            cr15_opening_successor.get("authority_base_main") ==
                            "8b84622ddffb88a97bd06d6b87e948d1e7e88545" and
                            cr15_opening_successor.get("previous_inventory") ==
                            cr15_roadmap_successor["current_inventory"] and
                            cr15_opening_successor.get("current_inventory") ==
                            (live_inventory if cr15_derivation_successor is None
                             else cr15_derivation_successor.get(
                                 "previous_inventory")) and
                            cr15_opening_successor.get("registered_changed_paths") ==
                            changed_paths and
                            cr15_opening_successor.get("previous_changed_text_surfaces") ==
                            cr15_roadmap_successor["current_changed_text_surfaces"] and
                            cr15_opening_successor.get("unchanged_fields") ==
                            roadmap_fields and
                            cr15_opening_successor.get(
                                "partial_extra_or_substituted_surface") == "rejected",
                            "Patch 24.0b CR-15 consumer successor drifted")
                        if cr15_derivation_successor is None:
                            changed_rows = [row for row in live_rows
                                            if row["path"] in changed_paths]
                            require([row["path"] for row in changed_rows] == changed_paths and
                                    cr15_opening_successor.get(
                                        "current_changed_text_surfaces") == changed_rows,
                                    "Patch 24.0b changed surface identity drifted")
                            require(module.canonical_digest([
                                row for row in live_rows if row["path"] not in changed_paths
                            ]) == cr15_opening_successor.get(
                                "unchanged_other_text_surface_manifest_digest"),
                                "Patch 24.0b changed an unregistered text surface")
                        else:
                            successor_unchanged = [
                                "invocation_count", "invocation_manifest_digest",
                                "structural_surface_count", "structural_manifest_digest",
                                "invocation_selection_counts", "unclassified_count",
                            ]
                            successor_paths = cr15_derivation_successor.get(
                                "registered_changed_paths", [])
                            successor_rows = (
                                [row for row in live_rows
                                 if row["path"] in successor_paths]
                                if cr15_qualification_successor is None else
                                cr15_derivation_successor.get(
                                    "current_changed_text_surfaces", [])
                            )
                            successor_other_digest = (
                                module.canonical_digest([
                                    row for row in live_rows
                                    if row["path"] not in successor_paths
                                ])
                                if cr15_qualification_successor is None else
                                cr15_derivation_successor.get(
                                    "unchanged_other_text_surface_manifest_digest")
                            )
                            require(
                                cr15_derivation_successor.get("contract_version") ==
                                "phase24_cr15_derivation_consumer_transition_v1" and
                                cr15_derivation_successor.get("status") ==
                                "patch24_0c_complete" and
                                cr15_derivation_successor.get("authority_base_main") ==
                                "c37024afa580d1e03c5ff70150ed0ae7518a9648" and
                                cr15_derivation_successor.get("previous_inventory") ==
                                cr15_opening_successor["current_inventory"] and
                                cr15_derivation_successor.get("current_inventory") ==
                                (live_inventory
                                 if cr15_qualification_successor is None else
                                 cr15_qualification_successor.get(
                                     "previous_inventory")) and
                                cr15_derivation_successor.get("unchanged_fields") ==
                                successor_unchanged and
                                live_inventory.get("text_surface_count") ==
                                cr15_derivation_successor["previous_inventory"].get(
                                    "text_surface_count") + 1 and
                                live_inventory.get("classification_counts", {}).get(
                                    "archive_candidate") ==
                                cr15_derivation_successor["previous_inventory"].get(
                                    "classification_counts", {}).get(
                                        "archive_candidate") + 1 and
                                all(live_inventory.get("classification_counts", {}).get(key) ==
                                    cr15_derivation_successor["previous_inventory"].get(
                                        "classification_counts", {}).get(key)
                                    for key in (
                                        "bootstrap_phase25", "focused_live_oracle",
                                        "historical_only", "production_or_release_migration",
                                    )) and
                                cr15_derivation_successor.get(
                                    "partial_extra_or_substituted_surface") == "rejected" and
                                [row["path"] for row in successor_rows] == successor_paths and
                                cr15_derivation_successor.get(
                                    "current_changed_text_surfaces") == successor_rows and
                                successor_other_digest == cr15_derivation_successor.get(
                                    "unchanged_other_text_surface_manifest_digest"),
                                "Patch 24.0c CR-15 consumer successor drifted")
                            for field in successor_unchanged:
                                require(live_inventory.get(field) ==
                                        cr15_derivation_successor[
                                            "previous_inventory"].get(field),
                                        f"Patch 24.0c changed consumer inventory field: {field}")
                            if cr15_qualification_successor is not None:
                                qualification_unchanged = [
                                    "text_surface_count", "invocation_count",
                                    "invocation_manifest_digest",
                                    "structural_surface_count",
                                    "structural_manifest_digest",
                                    "classification_counts",
                                    "invocation_selection_counts",
                                    "unclassified_count",
                                ]
                                qualification_paths = cr15_qualification_successor.get(
                                    "registered_changed_paths", [])
                                qualification_rows = (
                                    [row for row in live_rows
                                     if row["path"] in qualification_paths]
                                    if cr15_seed_successor is None else
                                    cr15_qualification_successor.get(
                                        "current_changed_text_surfaces", [])
                                )
                                previous_rows = cr15_qualification_successor.get(
                                    "previous_changed_text_surfaces", [])
                                require(
                                    cr15_qualification_successor.get(
                                        "contract_version") ==
                                    "phase24_cr15_qualification_consumer_transition_v1" and
                                    cr15_qualification_successor.get("status") ==
                                    "patch24_0d_complete" and
                                    cr15_qualification_successor.get(
                                        "authority_base_main") ==
                                    "2383096a741c62e8de103a5b79281b9f616eb805" and
                                    cr15_qualification_successor.get(
                                        "previous_inventory") ==
                                    cr15_derivation_successor["current_inventory"] and
                                    cr15_qualification_successor.get(
                                        "current_inventory") ==
                                    (live_inventory if cr15_seed_successor is None else
                                     cr15_seed_successor.get("previous_inventory")) and
                                    cr15_qualification_successor.get(
                                        "unchanged_fields") ==
                                    qualification_unchanged and
                                    cr15_qualification_successor.get(
                                        "partial_extra_or_substituted_surface") ==
                                    "rejected" and
                                    [row["path"] for row in qualification_rows] ==
                                    qualification_paths and
                                    cr15_qualification_successor.get(
                                        "current_changed_text_surfaces") ==
                                    qualification_rows and
                                    [row.get("path") for row in previous_rows] ==
                                    qualification_paths and
                                    all(previous != live for previous, live in
                                        zip(previous_rows, qualification_rows)) and
                                    (module.canonical_digest([
                                        row for row in live_rows
                                        if row["path"] not in qualification_paths
                                    ]) if cr15_seed_successor is None else
                                     cr15_qualification_successor.get(
                                         "unchanged_other_text_surface_manifest_digest")) ==
                                    cr15_qualification_successor.get(
                                        "unchanged_other_text_surface_manifest_digest"),
                                    "Patch 24.0d CR-15 consumer successor drifted")
                                for field in qualification_unchanged:
                                    require(
                                        live_inventory.get(field) ==
                                        cr15_qualification_successor[
                                            "previous_inventory"].get(field),
                                        f"Patch 24.0d changed consumer inventory field: {field}")
                                if cr15_seed_successor is not None:
                                    seed_paths = [
                                        "compiler/CRANELIFT_PHASE22_DEFAULT_ROUTE_SEED_CONVERGENCE.md",
                                        "scripts/cranelift_registry.py",
                                        "scripts/phase22_default_route_seed_convergence.py",
                                        "scripts/phase23_closure.py",
                                    ]
                                    seed_unchanged = qualification_unchanged
                                    seed_rows = [row for row in live_rows
                                                 if row["path"] in seed_paths]
                                    previous_seed_rows = cr15_seed_successor.get(
                                        "previous_changed_text_surfaces", [])
                                    require(
                                        cr15_seed_successor.get("contract_version") ==
                                        "phase24_cr15_seed_authority_consumer_transition_v1" and
                                        cr15_seed_successor.get("status") ==
                                        "ready_for_seed_publication" and
                                        cr15_seed_successor.get("authority_base_main") ==
                                        "10076805b56697304e7b236fff09cdf3689fcc05" and
                                        cr15_seed_successor.get("previous_inventory") ==
                                        cr15_qualification_successor["current_inventory"] and
                                        cr15_seed_successor.get("current_inventory") ==
                                        live_inventory and
                                        cr15_seed_successor.get(
                                            "registered_changed_paths") == seed_paths and
                                        cr15_seed_successor.get("unchanged_fields") ==
                                        seed_unchanged and
                                        cr15_seed_successor.get(
                                            "partial_extra_or_substituted_surface") ==
                                        "rejected" and
                                        [row["path"] for row in seed_rows] == seed_paths and
                                        cr15_seed_successor.get(
                                            "current_changed_text_surfaces") == seed_rows and
                                        [row.get("path") for row in previous_seed_rows] ==
                                        seed_paths and
                                        all(previous != current for previous, current in
                                            zip(previous_seed_rows, seed_rows)) and
                                        module.canonical_digest([
                                            row for row in live_rows
                                            if row["path"] not in seed_paths
                                        ]) == cr15_seed_successor.get(
                                            "unchanged_other_text_surface_manifest_digest"),
                                        "Patch 24.0e CR-15 seed consumer successor drifted")
                                    for field in seed_unchanged:
                                        require(
                                            live_inventory.get(field) ==
                                            cr15_seed_successor[
                                                "previous_inventory"].get(field),
                                            f"Patch 24.0e changed consumer inventory field: {field}")

    frozen = registry["phase23_mir_to_c_frozen_surface"][
        "production_release_transition"]
    surface = record.get("frozen_surface_transition", {})
    closure_frozen = registry.get("phase23_closure", {}).get(
        "frozen_surface_transition")
    derivation_frozen = registry.get("phase24_cr15_derivation", {}).get(
        "frozen_surface_transition")
    require(surface.get("contract_version") ==
            "phase23_cross_feature_frozen_surface_transition_v1" and
            surface.get("status") == "patch23_13_complete" and
            surface.get("authority_base_main") ==
            "9b89296b25d2ab0cf1963ea1d1707139149d0576" and
            surface.get("previous_live_c_case_surface") ==
            frozen["current_live_c_case_surface"] and
            surface.get("unchanged_fields") == [
                "count", "case_id_manifest_digest", "owner_contract_count",
                "owner_counts", "consumer_class_counts", "selection_counts",
            ] and surface.get("partial_or_unregistered_surface") == "rejected",
            "Patch 23.13 frozen surface transition drifted")
    for field in surface["unchanged_fields"]:
        require(surface["current_live_c_case_surface"].get(field) ==
                surface["previous_live_c_case_surface"].get(field),
                f"Patch 23.13 changed frozen C field: {field}")
    if closure_frozen is None:
        require(surface.get("current_live_c_case_surface") ==
                current_frozen_surface(registry),
                "Patch 23.13 frozen surface transition drifted")
    else:
        require(closure_frozen.get("contract_version") ==
                "phase23_closure_frozen_surface_transition_v1" and
                closure_frozen.get("status") == "patch23_15_complete" and
                closure_frozen.get("authority_base_main") ==
                "8985a3d09b1f119accd12cd952940ef019d6a698" and
                closure_frozen.get("previous_live_c_case_surface") ==
                surface["current_live_c_case_surface"] and
                closure_frozen.get("current_live_c_case_surface") ==
                (current_frozen_surface(registry) if derivation_frozen is None
                 else derivation_frozen.get("previous_live_c_case_surface")) and
                closure_frozen.get("unchanged_fields") ==
                surface["unchanged_fields"] and
                closure_frozen.get("partial_or_unregistered_surface") ==
                "rejected",
                "Patch 23.15 frozen surface successor drifted")
        if derivation_frozen is not None:
            live_frozen = current_frozen_surface(registry)
            require(
                derivation_frozen.get("contract_version") ==
                "phase24_cr15_derivation_frozen_surface_transition_v1" and
                derivation_frozen.get("status") == "patch24_0c_complete" and
                derivation_frozen.get("authority_base_main") ==
                "c37024afa580d1e03c5ff70150ed0ae7518a9648" and
                derivation_frozen.get("previous_live_c_case_surface") ==
                closure_frozen["current_live_c_case_surface"] and
                derivation_frozen.get("current_live_c_case_surface") ==
                live_frozen and
                derivation_frozen.get("unchanged_fields") ==
                surface["unchanged_fields"] and
                derivation_frozen.get("change_reason") ==
                "CR15_derivation_preserved_the_frozen_explicit_C_case_population_through_exact_relay_projection" and
                derivation_frozen.get("partial_or_unregistered_surface") ==
                "rejected",
                "Patch 24.0c frozen surface successor drifted")
            for field in surface["unchanged_fields"]:
                require(live_frozen.get(field) ==
                        derivation_frozen["previous_live_c_case_surface"].get(field),
                        f"Patch 24.0c changed frozen C field: {field}")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase23_cross_feature_qualification")
    require(isinstance(record, dict), "Patch 23.13 authority is missing")
    expected = {
        "contract_version": "phase23_cross_feature_qualification_v1",
        "status": "patch23_13_complete",
        "next_patch": "23.14",
        "owner": "cranelift",
        "review_view": REVIEW.relative_to(ROOT).as_posix(),
        "renderer": Path(__file__).relative_to(ROOT).as_posix(),
        "unexplained_differences": [],
        "module_or_fixture_exceptions": [],
        "unclassified_residues": [],
        "execution_model": {
            "prebuild": "make_phase10_native_package_once",
            "guard_runner_build_policy": "GUST_RUNNER_SKIP_BUILD=1_after_prebuild",
            "guard_semantics": "all_registered_commands_execute_unchanged",
            "bootstrap": "make_bootstrap_after_guards_without_skip_build",
        },
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")
    require(registry["phase23_production_release_audit"].get("status") ==
            "patch23_12_complete", "Patch 23.12 predecessor is not complete")

    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(record.get("phase23_level1_guards") == PHASE23_L1_GUARDS and
            set(PHASE23_L1_GUARDS) == set(phase23_guard_inventory(levels, 1)),
            "complete Phase 23 Level 1 inventory drifted")
    require(record.get("phase23_level2_guards") == PHASE23_L2_GUARDS and
            set(PHASE23_L2_GUARDS) == set(phase23_guard_inventory(levels, 2)),
            "complete Phase 23 Level 2 inventory drifted")
    require(record.get("supplemental_level2_guards") == SUPPLEMENTAL_L2_GUARDS,
            "supplemental qualification inventory drifted")
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 23.13 guard levels drifted")

    issue_records = {
        105: registry["phase23_same_scope_declaration"],
        110: registry["phase23_mir_evidence_owner"],
        240: registry["phase23_resource_acquisition_parity"],
    }
    for issue, authority in issue_records.items():
        closure = authority.get("issue_closure", {})
        require(authority.get("issue") == issue and
                authority.get("status") == "closed_on_merged_current_main" and
                closure.get("state") == "closed_after_merged_current_main_validation" and
                closure.get("issue_state") == "closed" and
                closure.get("current_main_validation", {}).get("result") ==
                "completed_success",
                f"issue #{issue} is not closed on registered current-main evidence")
    issue_roadmap = ISSUES.read_text(encoding="utf-8")
    for issue in (105, 110, 240):
        require(f"[#${issue}" not in issue_roadmap and
                f"[#{issue} —" in issue_roadmap,
                f"issue #{issue} is absent from the closed issue ledger")

    require(registry["phase23_assurance_phase_a"].get("status") ==
            "phase23_4_complete_report_only" and
            registry["phase23_assurance_phase_b"].get("status") ==
            "phase23_5_complete_report_only" and
            registry["phase23_assurance_phase_b"].get("boundary", {}).get(
                "executes_candidate_code") is False,
            "Assurance A/B is not complete and report-only")

    audit = registry["phase23_production_release_audit"]["audit"]
    require(record.get("route_inventory") == audit == {
        "supported_surface_count": 6,
        "supported_surface_manifest_digest": audit["supported_surface_manifest_digest"],
        "repository_invocation_count": 318,
        "repository_explicit_c_count": 178,
        "phase25_bootstrap_explicit_c_count": 5,
        "non_bootstrap_retained_test_surface_count": 173,
        "supported_production_or_release_explicit_c_count": 0,
        "active_non_bootstrap_live_c_lane_count": 1,
        "active_non_bootstrap_live_c_owner": "phase23_mir_to_c_focused_live",
        "unknown_downstream_count": 0,
    }, "production, route, or downstream inventory drifted")
    require(registry["phase23_production_release_audit"]["route_contract"].get(
        "fallback") == "forbidden", "no-fallback authority drifted")

    residues = record.get("residues")
    require(isinstance(residues, list) and residues == [
        {
            "id": "nonbootstrap_explicit_c_evidence",
            "count": 173,
            "owner": "cranelift",
            "destination_phase": "24",
            "reason": "deprecated_generated_C_backend_retained_for_the_single_focused_oracle_and_classified_historical_or_archived_evidence",
            "falsifier": "count_or_complete_identity_changes_or_any_supported_production_or_release_route_requires_C",
        },
        {
            "id": "bootstrap_explicit_c_chain",
            "count": 5,
            "owner": "cranelift",
            "destination_phase": "25",
            "reason": "make_gust_make_bootstrap_and_the_committed_C_seed_remain_owned_by_the_separate_bootstrap_retirement_phase",
            "falsifier": "count_or_identity_changes_or_bootstrap_stops_using_the_registered_explicit_C_chain_before_Phase_25",
        },
    ], "complete residue classification drifted")
    require(sum(row["count"] for row in residues) ==
            record["route_inventory"]["repository_explicit_c_count"],
            "residue counts do not partition the explicit-C inventory")

    coverage = record.get("coverage", {})
    require(set(coverage) == {
        "level1_authority", "level2_behaviour", "issue_health",
        "assurance_report_only", "deprecation_and_frozen_surface",
        "focused_live_and_archive", "package_install_and_release",
        "bootstrap", "default_and_explicit_native", "explicit_c_identity",
        "cleanup_and_resources", "side_effects", "diagnostics", "target",
        "no_fallback", "consumer_scanner", "workflow_reachability",
    } and all(isinstance(owners, list) and owners for owners in coverage.values()),
            "qualification coverage is incomplete")
    validate_transition(record, registry)

    require(record.get("boundary") == {
        "changes_accepted_Gust_program_meaning": False,
        "adds_or_changes_MIR_operations": False,
        "changes_ABI_layout_runtime_symbols_target_or_linker": False,
        "changes_backend_route_default_or_fallback": False,
        "changes_bootstrap_route_or_seed": False,
        "edits_stdlib_or_CR15": False,
        "begins_patch23_14": False,
    }, "Patch 23.13 boundary widened")
    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 23.13 — Cross-Feature Qualification and Residue Audit — DONE"
            in task, "TASK does not mark Patch 23.13 DONE")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "Patch 23.13 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Patch 23.13 contract")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    for marker in (
        "pull_request:", "push:", "workflow_dispatch:", "gust_v4.c",
        "compiler/**", "src/runtime.c", "src/runtime/**",
        "tools/normalize_generated_arena_offsets.py", GUARD_L1, GUARD_L2,
    ):
        require(marker in workflow, f"Patch 23.13 workflow is missing {marker}")
    return record


def render(record: dict) -> str:
    lines = [
        "# Cranelift Phase 23.13 — Cross-Feature Qualification",
        "",
        "Generated from `scripts/cranelift_feature_registry.json`; do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Phase 23 Level 1 guards: `{len(record['phase23_level1_guards'])}`",
        f"- Phase 23 Level 2 guards: `{len(record['phase23_level2_guards'])}`",
        f"- Supplemental Level 2 owners: `{len(record['supplemental_level2_guards'])}`",
        f"- Unexplained differences: `{len(record['unexplained_differences'])}`",
        f"- Module or fixture exceptions: `{len(record['module_or_fixture_exceptions'])}`",
        f"- Unclassified residues: `{len(record['unclassified_residues'])}`",
        "",
        "## Execution model",
        "",
        "The aggregate builds the native package once, then executes every",
        "registered guard command unchanged with the runner's existing",
        "`GUST_RUNNER_SKIP_BUILD=1` mode. The final `make bootstrap` runs",
        "without that environment override. This removes redundant compiler",
        "rebuilds without changing the guard population or the 85-minute budget.",
        "",
        "## Coverage",
        "",
    ]
    for name, owners in record["coverage"].items():
        lines.append(f"- `{name}`: `{', '.join(owners)}`")
    lines += ["", "## Residues", ""]
    for row in record["residues"]:
        lines += [
            f"- `{row['id']}`: `{row['count']}` calls; owner `{row['owner']}`; "
            f"destination Phase `{row['destination_phase']}`.",
            f"  - Reason: `{row['reason']}`.",
            f"  - Falsifier: `{row['falsifier']}`.",
        ]
    inventory = record["route_inventory"]
    lines += [
        "",
        "## Route inventory",
        "",
        f"- Repository invocations: `{inventory['repository_invocation_count']}`",
        f"- Explicit C: `{inventory['repository_explicit_c_count']}`",
        f"- Phase 25 bootstrap explicit C: `{inventory['phase25_bootstrap_explicit_c_count']}`",
        f"- Non-bootstrap retained C: `{inventory['non_bootstrap_retained_test_surface_count']}`",
        f"- Supported production/release C requirements: `{inventory['supported_production_or_release_explicit_c_count']}`",
        f"- Unknown downstream consumers: `{inventory['unknown_downstream_count']}`",
        "",
        "Issues #105, #110, and #240 are closed on their registered merged",
        "current-main evidence. Assurance A/B remains report-only. The two",
        "residue rows partition every explicit-C invocation and preserve the",
        "separate Phase 24 generated-C and Phase 25 bootstrap-C boundaries.",
        "This qualification introduces no module, fixture, source-spelling, or",
        "stdlib exception and changes no semantics, MIR, ABI, runtime symbol,",
        "route, fallback, target, linker, bootstrap seed, Stdlib, or CR-15 state.",
        "",
    ]
    return "\n".join(lines)


def run_with_deadline(
    command: list[str], deadline: float, *, env: dict[str, str] | None = None
) -> None:
    remaining = deadline - time.monotonic()
    require(remaining > 0, "qualification elapsed budget was exhausted")
    print("+ " + " ".join(command), flush=True)
    process = subprocess.Popen(
        command, cwd=ROOT, env=env, start_new_session=True
    )
    try:
        status = process.wait(timeout=remaining)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()
        raise SystemExit(
            f"{GUARD_L2}: elapsed budget exhausted during {' '.join(command)}"
        )
    require(status == 0, f"command failed ({status}): {' '.join(command)}")


def evidence(record: dict) -> None:
    deadline = time.monotonic() + record["budgets"]["evidence_elapsed_ms"] / 1000
    for command in STATIC_COMMANDS:
        run_with_deadline(command, deadline)
    run_with_deadline(["make", "phase10-native-package"], deadline)
    guard_env = os.environ.copy()
    guard_env["GUST_RUNNER_SKIP_BUILD"] = "1"
    for guard in PHASE23_L1_GUARDS + PHASE23_L2_GUARDS + SUPPLEMENTAL_L2_GUARDS:
        run_with_deadline(["just", guard], deadline, env=guard_env)
    run_with_deadline(["make", "bootstrap"], deadline)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review", "evidence"))
    args = parser.parse_args()
    record = validate()
    rendered = render(record)
    if args.command == "project":
        REVIEW.write_text(rendered, encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") == rendered,
                "generated review is stale")
    elif args.command == "evidence":
        evidence(record)
    print(f"{GUARD_L1}: {args.command} ok")


if __name__ == "__main__":
    main()
