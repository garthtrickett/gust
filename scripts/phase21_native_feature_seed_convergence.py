#!/usr/bin/env python3
"""Validate and project Patch 21.13a native-feature seed convergence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from phase22_default_route_seed_convergence import accepted_live_seed_line_count

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
SEED = ROOT / "gust_v4.c"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_NATIVE_FEATURE_SEED_CONVERGENCE.md"
WORKFLOW = ROOT / ".github/workflows/phase19-seed-convergence.yml"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
GUARD = "guard-cranelift-phase21-native-feature-seed-convergence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase21_tenant_scope_seed_convergence", {})
    require(predecessor.get("contract_version") ==
            "phase21_tenant_scope_seed_convergence_v1",
            "predecessor seed authority drifted")
    accounted = registry.get("phase21_selected_compiler_module_qualification", {})
    require(accounted.get("contract_version") ==
            "phase21_selected_compiler_module_qualification_v1" and
            accounted.get("status") == "patch21_13_complete",
            "accounted Patch 21.13 authority drifted")

    record = registry.get("phase21_native_feature_seed_convergence")
    require(isinstance(record, dict), "Patch 21.13a authority is missing")
    expected = {
        "contract_version": "phase21_native_feature_seed_convergence_v1",
        "status": "patch21_13a_complete",
        "next_patch": "21.14",
        "review_view": "compiler/CRANELIFT_PHASE21_NATIVE_FEATURE_SEED_CONVERGENCE.md",
        "seed_path": "gust_v4.c",
        "predecessor_seed_authority": "phase21_tenant_scope_seed_convergence_v1",
        "accounted_authority": "phase21_selected_compiler_module_qualification_v1",
        "previous_seed_commit": "3c4028e04629a4af1b5010b7b0977b188f0afb6c",
        "fixed_point_policy": "make_bootstrap_stage2_stage3_byte_identity",
        "seed_only_policy": "generated_seed_and_seed_specific_authority_only",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")

    diff = record.get("generated_seed_diff")
    require(diff == {
        "previous_lines": 60470,
        "current_lines": 62917,
        "insertions": 2501,
        "deletions": 54,
        "line_delta": 2447,
    }, "generated seed diff accounting drifted")
    require(diff["current_lines"] - diff["previous_lines"] == diff["line_delta"] and
            diff["insertions"] - diff["deletions"] == diff["line_delta"],
            "generated seed line delta is inconsistent")
    require(record.get("accounted_patches") == [
        {"patch": "21.7b", "scope": "cross_tenant_predicate_validation_reconciliation"},
        {"patch": "21.8", "scope": "phase20_residue_migration_authority_and_compiler_graph_fixtures"},
        {"patch": "21.9", "scope": "collection_string_native_source_migration_and_transport_corrections"},
        {"patch": "21.10", "scope": "filesystem_allocation_native_source_migration_and_arena_access_corrections"},
        {"patch": "21.11", "scope": "resource_synchronization_native_source_migration"},
        {"patch": "21.12", "scope": "compiler_support_library_native_qualification_fixtures_and_authority"},
        {"patch": "21.13", "scope": "selected_compiler_module_native_qualification_and_generic_declaration_admission"},
    ], "accounted patch range drifted")
    require(record.get("boundary") == {
        "adds_semantics": False,
        "changes_MIR_or_backends": False,
        "changes_ABI_layout_or_runtime_symbols": False,
        "changes_default_backend_or_fallback": False,
        "edits_stdlib_or_CR15": False,
        "begins_patch21_14": False,
    }, "Patch 21.13a widened beyond seed reconvergence")
    live_seed_lines = diff["current_lines"]
    successor = registry.get("phase22_default_route_seed_convergence")
    if successor is not None:
        require(successor.get("predecessor_seed_authority") ==
                record["contract_version"],
                "Patch 22.6a seed authority does not name this predecessor")
        successor_diff = successor.get("generated_seed_diff")
        require(isinstance(successor_diff, dict),
                "Patch 22.6a seed authority omits generated diff accounting")
        live_seed_lines = accepted_live_seed_line_count(
            successor,
            len(SEED.read_text(encoding="utf-8").splitlines()))
    require(len(SEED.read_text(encoding="utf-8").splitlines()) ==
            live_seed_lines, "committed seed line count drifted")
    require("- [x] Patch 21.13a — Native-Feature Bootstrap Seed Reconvergence — DONE"
            in TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 21.13a DONE")

    workflow = WORKFLOW.read_text(encoding="utf-8")
    for evidence in (
        "compiler/CRANELIFT_PHASE21_NATIVE_FEATURE_SEED_CONVERGENCE.md",
        "scripts/phase21_native_feature_seed_convergence.py",
        f"just {GUARD}",
    ):
        require(evidence in workflow,
                f"authoritative seed workflow lacks {evidence}")
    for command in (
        "make bootstrap",
        "cmp build/gust_stage2.c build/gust_stage3.c",
        "git diff --exit-code -- gust_v4.c",
    ):
        require(command in workflow,
                f"authoritative fixed-point workflow lacks {command}")
    selector = workflow.split("Select authoritative seed-convergence scope", 1)[1]
    selector = selector.split("Capability PR defers generated seed", 1)[0]
    for seed_owned_path in (
        "gust_v4.c",
        "compiler/CRANELIFT_PHASE21_NATIVE_FEATURE_SEED_CONVERGENCE.md",
        "scripts/phase21_native_feature_seed_convergence.py",
    ):
        require(seed_owned_path in selector,
                f"fixed-point scope selector lacks {seed_owned_path}")
    require("compiler/*.gst" not in selector,
            "capability compiler sources must remain deferred on pull requests")
    require(f"just {GUARD}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Patch 21.13a Level 1 guard")
    require(f"{GUARD}:" in JUSTFILE.read_text(encoding="utf-8"),
            "Patch 21.13a just guard is missing")
    return record


def render(record: dict) -> str:
    diff = record["generated_seed_diff"]
    lines = [
        "# Cranelift Phase 21 Native-Feature Seed Convergence",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_native_feature_seed_convergence.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Accounted authority: `{record['accounted_authority']}`",
        f"- Previous seed commit: `{record['previous_seed_commit']}`",
        f"- Fixed-point policy: `{record['fixed_point_policy']}`",
        f"- Seed-only policy: `{record['seed_only_policy']}`",
        "",
        "## Generated seed diff",
        "",
        f"- Previous lines: {diff['previous_lines']}",
        f"- Current lines: {diff['current_lines']}",
        f"- Insertions: {diff['insertions']}",
        f"- Deletions: {diff['deletions']}",
        f"- Net line delta: {diff['line_delta']}",
        "",
        "## Accounted patch range",
        "",
    ]
    lines += [
        f"- Patch {row['patch']}: `{row['scope']}`"
        for row in record["accounted_patches"]
    ]
    lines += [
        "",
        "This isolated regeneration serializes the self-hosted compiler and",
        "native-feature source changes after Patch 21.7a through Patch 21.13.",
        "Stage 2 and stage 3 remain byte-identical in the authoritative seed",
        "workflow. The patch adds no Gust semantics, Stdlib or CR-15 change,",
        "MIR/backend behavior, ABI/layout/runtime symbol, default-backend or",
        "fallback change, and does not begin Patch 21.14.",
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
                "generated review is stale; run project")
    print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
