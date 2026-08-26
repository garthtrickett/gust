#!/usr/bin/env python3
"""Validate and project Patch 21.8 residue migration authority."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_RESIDUE_MIGRATION_AUTHORITY.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase21-residue-migration-authority.yml"
JUSTFILE = ROOT / "justfile"
GUARD_L1 = "guard-cranelift-phase21-residue-migration-authority-contract"
GUARD_L2 = "guard-cranelift-phase21-residue-migration-authority-evidence"

RESIDUE_DESTINATIONS = {
    "collections": "21.9",
    "strings": "21.9",
    "filesystem": "21.10",
    "allocation": "21.10",
    "resources": "21.11",
    "threading_synchronization": "21.11",
}

CAPABILITY_IDS = [
    "scheduled_defer_call_edges",
    "call_result_condition_cfg",
    "generic_receiver_and_aggregate_result_calls",
    "enum_match_payload_cfg",
    "string_view_byte_and_cast_operations",
    "approved_filesystem_runtime_calls",
    "branded_arena_allocation_write_and_index",
    "resource_declaration_module_inventory",
    "resource_terminal_state_cleanup_edges",
    "function_reference_parameter_call_abi",
    "synchronization_protected_access_and_runtime_calls",
]

COMPILER_SLICE_IDS = [
    "lexical_ast_foundations",
    "parser_type_resolver",
    "canonical_mir_authorities",
    "code_generation",
    "native_source_lowering",
    "native_request_route_and_entry",
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def compiler_import_graph(root_name: str) -> tuple[set[str], dict[str, list[str]]]:
    seen: set[str] = set()
    edges: dict[str, list[str]] = {}

    def visit(name: str) -> None:
        if name in seen:
            return
        seen.add(name)
        path = ROOT / "compiler" / name
        require(path.is_file(), f"compiler graph module is missing: {name}")
        imports = re.findall(
            r'^import "([^"]+)" as ', path.read_text(encoding="utf-8"), re.MULTILINE
        )
        edges[name] = imports
        for dependency in imports:
            visit(dependency)

    visit(root_name)
    return seen, edges


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase21_tenant_scope_seed_convergence", {})
    require(predecessor.get("status") == "patch21_7a_complete" and
            predecessor.get("next_patch") == "21.8",
            "Patch 21.7a predecessor authority drifted")
    record = registry.get("phase21_residue_migration_authority")
    require(isinstance(record, dict), "Patch 21.8 authority is missing")
    require(record.get("contract_version") ==
            "phase21_residue_migration_authority_v1",
            "contract version drifted")
    require(record.get("status") == "patch21_8_complete" and
            record.get("next_patch") == "21.9",
            "status or successor drifted")
    require(record.get("observed_main_sha") ==
            "59ae01923a157b7b6e7a74c1b50499ef9c597f36",
            "observed main drifted")
    require(record.get("predecessor_authority") ==
            predecessor.get("contract_version") and
            record.get("opening_authority") ==
            registry.get("phase21_opening", {}).get("contract_version"),
            "predecessor or opening authority link drifted")
    require(record.get("early_rejection_policy") ==
            "every_unimplemented_residue_and_the_full_compiler_reject_before_driver_discovery_without_an_artifact",
            "early rejection policy drifted")

    opening_rows = {
        row["category"]: row for row in
        registry["phase21_opening"]["inherited_residues"]
    }
    residues = record.get("residue_rows", [])
    require([row.get("category") for row in residues] ==
            list(RESIDUE_DESTINATIONS),
            "residue population is missing, duplicated, or reordered")
    for row in residues:
        opening = opening_rows.get(row["category"])
        require(opening is not None, f"unknown residue: {row['category']}")
        for field in ("source_fixture", "current_decision", "reason_code",
                      "failure_stage"):
            require(row.get(field) == opening.get(field),
                    f"{row['category']} changed opening {field}")
        require(row.get("destination_patch") ==
                RESIDUE_DESTINATIONS[row["category"]],
                f"{row['category']} destination drifted")
        require(row.get("capabilities") and
                all(item in CAPABILITY_IDS for item in row["capabilities"]),
                f"{row['category']} has an unknown capability")
        require((ROOT / row["source_fixture"]).is_file(),
                f"missing residue fixture: {row['source_fixture']}")

    capabilities = record.get("capability_slices", [])
    require([row.get("id") for row in capabilities] == CAPABILITY_IDS and
            [row.get("order") for row in capabilities] ==
            list(range(1, len(CAPABILITY_IDS) + 1)),
            "capability slices are missing, duplicated, or reordered")
    seen_capabilities: set[str] = set()
    destination_order = {"21.9": 1, "21.10": 2, "21.11": 3}
    previous_destination = 0
    for row in capabilities:
        destination = row.get("destination_patch")
        require(destination in destination_order and
                destination_order[destination] >= previous_destination,
                f"capability patch order regressed: {row['id']}")
        previous_destination = destination_order[destination]
        require(all(dependency in seen_capabilities
                    for dependency in row.get("depends_on", [])),
                f"capability dependency is absent or forward: {row['id']}")
        require(row.get("surface") and row.get("implementation_state", "").startswith(
            "planned_"), f"capability is implemented or unbounded: {row['id']}")
        require(all((ROOT / "compiler" / consumer).is_file()
                    for consumer in row.get("first_compiler_consumers", [])),
                f"capability consumer is missing: {row['id']}")
        seen_capabilities.add(row["id"])
    require({capability for row in residues for capability in row["capabilities"]}
            == set(CAPABILITY_IDS),
            "a capability slice is not owned by an inherited residue")

    graph = record.get("compiler_graph", {})
    slices = graph.get("slices", [])
    require([row.get("id") for row in slices] == COMPILER_SLICE_IDS and
            [row.get("order") for row in slices] ==
            list(range(1, len(COMPILER_SLICE_IDS) + 1)),
            "compiler qualification slices drifted")
    declared_modules = [module for row in slices for module in row["modules"]]
    require(len(declared_modules) == len(set(declared_modules)),
            "compiler module appears in multiple slices")
    reachable, edges = compiler_import_graph(graph.get("root", ""))
    successor_modules: set[str] = set()
    successor = registry.get("phase21_collection_string_native_source", {})
    if successor.get("status") == "patch21_9_complete":
        successor_modules.add("mir_native_backend_collection_string_source.gst")
    filesystem_allocation_successor = registry.get(
        "phase21_filesystem_allocation_native_source", {})
    if filesystem_allocation_successor.get("status") == "patch21_10_complete":
        successor_modules.add(
            "mir_native_backend_filesystem_allocation_source.gst")
    historical_reachable = reachable - successor_modules
    historical_edge_count = sum(
        1 for module, imports in edges.items()
        if module in historical_reachable
        for dependency in imports if dependency in historical_reachable
    )
    require(set(declared_modules) == historical_reachable and
            graph.get("module_count") == len(historical_reachable) == 38,
            "compiler graph leaves a module unclassified")
    require(graph.get("import_edge_count") ==
            historical_edge_count == 116,
            "compiler graph leaves an import edge unclassified")
    module_slice = {
        module: row["order"] for row in slices for module in row["modules"]
    }
    for module, imports in edges.items():
        if module not in historical_reachable:
            continue
        for dependency in imports:
            if dependency not in historical_reachable:
                continue
            require(module_slice[dependency] <= module_slice[module],
                    f"compiler slice orders {module} before {dependency}")
    seen_slices: set[str] = set()
    for row in slices:
        require(all(dependency in seen_slices
                    for dependency in row.get("depends_on", [])),
                f"compiler slice dependency is absent or forward: {row['id']}")
        seen_slices.add(row["id"])

    opening_baseline = registry["phase21_opening"]["full_compiler_baseline"]
    baseline = record.get("full_compiler_baseline", {})
    for field in ("source_fixture", "compile_exit", "decision", "reason_code",
                  "diagnostic", "failure_stage", "artifact"):
        require(baseline.get(field) == opening_baseline.get(field),
                f"full compiler baseline changed {field}")
    require(record.get("unclassified_residues") == [] and
            record.get("unclassified_modules") == [] and
            record.get("unclassified_import_edges") == [],
            "Patch 21.8 leaves an unclassified item")
    boundary = record.get("boundary", {})
    require(boundary and all(value is False for value in boundary.values()),
            "Patch 21.8 widened into implementation")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 21.8 — Phase 20 Residue Migration Authority — DONE"
            in task and "**Exit Gate:** all six inherited fixtures" in task,
            "TASK.md does not close the Patch 21.8 authority boundary")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 21.8 guard levels drifted")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile and f"{GUARD_L2}:" in justfile,
            "Patch 21.8 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own Patch 21.8 Level 1")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "dedicated Patch 21.8 workflow does not own both guards")
    return record


def render(record: dict) -> str:
    lines = [
        "# Cranelift Phase 21 Residue Migration Authority", "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_residue_migration_authority.py project`. Do not edit by hand.",
        "", f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Observed main: `{record['observed_main_sha']}`",
        f"- Early rejection: `{record['early_rejection_policy']}`",
        "", "## Residue ownership", "",
    ]
    for row in record["residue_rows"]:
        lines += [
            f"- `{row['category']}` → Patch `{row['destination_patch']}`",
            f"  - Fixture: `{row['source_fixture']}`",
            f"  - Current: `{row['current_decision']}` / `{row['reason_code']}` at `{row['failure_stage']}`",
            f"  - Capabilities: `{', '.join(row['capabilities'])}`",
        ]
    lines += ["", "## Generic capability order", ""]
    for row in record["capability_slices"]:
        dependencies = ", ".join(row["depends_on"]) or "none"
        consumers = ", ".join(row["first_compiler_consumers"]) or "qualification tail"
        lines += [
            f"{row['order']}. `{row['id']}` — Patch `{row['destination_patch']}`",
            f"   - Surface: `{row['surface']}`",
            f"   - Depends on: `{dependencies}`",
            f"   - First compiler consumers: `{consumers}`",
            f"   - State: `{row['implementation_state']}`",
        ]
    graph = record["compiler_graph"]
    lines += [
        "", "## Compiler qualification order", "",
        f"The live transitive graph rooted at `{graph['root']}` contains",
        f"`{graph['module_count']}` modules and `{graph['import_edge_count']}` import edges.",
        "",
    ]
    for row in graph["slices"]:
        dependencies = ", ".join(row["depends_on"]) or "none"
        lines += [
            f"{row['order']}. `{row['id']}`",
            f"   - Depends on: `{dependencies}`",
            f"   - Modules: `{', '.join(row['modules'])}`",
        ]
    baseline = record["full_compiler_baseline"]
    lines += [
        "", "## Preserved full-compiler baseline", "",
        f"- Fixture: `{baseline['source_fixture']}`",
        f"- Current: exit `{baseline['compile_exit']}`, `{baseline['decision']}` / `{baseline['reason_code']}`",
        f"- Diagnostic: `{baseline['diagnostic']}`",
        f"- Failure stage: `{baseline['failure_stage']}`; artifact: `{baseline['artifact']}`",
        "",
        "Patch 21.8 classifies and orders work only. It changes no accepted",
        "program meaning, MIR/backend behavior, ABI/layout, runtime symbol,",
        "bootstrap seed, or Stdlib surface, and implements no Patch 21.9+ row.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and
                REVIEW.read_text(encoding="utf-8") == render(record),
                "generated Patch 21.8 review is stale; run project")
    print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
