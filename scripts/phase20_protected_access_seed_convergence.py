#!/usr/bin/env python3
"""Validate and project Patch 20.16e protected-access seed convergence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
SEED = ROOT / "gust_v4.c"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_PROTECTED_ACCESS_SEED_CONVERGENCE.md"
WORKFLOW = ROOT / ".github/workflows/phase19-seed-convergence.yml"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
GUARD = "guard-cranelift-phase20-protected-access-seed-convergence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase20_post_prerequisite_seed_convergence", {})
    require(predecessor.get("contract_version") ==
            "phase20_post_prerequisite_seed_convergence_v1",
            "predecessor seed authority drifted")
    accounted = registry.get("phase20_protected_access_liveness", {})
    require(accounted.get("contract_version") ==
            "phase20_protected_access_liveness_v1" and
            accounted.get("handoff", {}).get(
                "implementation_authority_landed") is True,
            "accounted protected-access authority drifted")
    record = registry.get("phase20_protected_access_seed_convergence")
    require(isinstance(record, dict), "Patch 20.16e authority is missing")
    expected = {
        "contract_version": "phase20_protected_access_seed_convergence_v1",
        "status": "patch20_16e_complete",
        "next_patch": "20.17",
        "review_view": "compiler/CRANELIFT_PHASE20_PROTECTED_ACCESS_SEED_CONVERGENCE.md",
        "seed_path": "gust_v4.c",
        "predecessor_seed_authority": "phase20_post_prerequisite_seed_convergence_v1",
        "accounted_authority": "phase20_protected_access_liveness_v1",
        "previous_seed_commit": "1588c07944468d7ef68e21b945540203a4d87595",
        "fixed_point_policy": "make_bootstrap_stage2_stage3_byte_identity",
        "seed_only_policy": "generated_seed_and_seed_specific_authority_only",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")
    diff = record.get("generated_seed_diff")
    require(diff == {
        "previous_lines": 59520,
        "current_lines": 59706,
        "insertions": 234,
        "deletions": 48,
        "line_delta": 186,
    }, "generated seed diff accounting drifted")
    require(diff["insertions"] - diff["deletions"] == diff["line_delta"],
            "generated seed line delta is inconsistent")
    accounted = record.get("accounted_patches")
    require(accounted == [
        {"patch": "20.15", "scope": "long_lived_and_concurrent_resource_qualification_fixtures_and_authority"},
        {"patch": "20.16", "scope": "cross_feature_resource_qualification_fixtures_and_authority"},
        {"patch": "20.16a", "scope": "OD_13_decision_projection_without_compiler_semantic_change"},
        {"patch": "20.16b", "scope": "inert_resource_root_carrier_in_the_self_hosted_typechecker"},
        {"patch": "20.16c", "scope": "unsafe_Mutex_inventory_authority_without_compiler_semantic_change"},
        {"patch": "20.16d", "scope": "protected_access_liveness_enforcement_and_fixtures"},
    ], "accounted patch range drifted")
    live_seed_lines = diff["current_lines"]
    successor = registry.get("phase21_tenant_scope_seed_convergence")
    if successor is not None:
        require(successor.get("predecessor_seed_authority") ==
                record["contract_version"],
                "Patch 21.7a seed authority does not name this predecessor")
        successor_diff = successor.get("generated_seed_diff")
        require(isinstance(successor_diff, dict),
                "Patch 21.7a seed authority omits generated diff accounting")
        live_seed_lines = successor_diff.get("current_lines")
        native_feature_seed = registry.get(
            "phase21_native_feature_seed_convergence"
        )
        if native_feature_seed is not None:
            require(native_feature_seed.get("predecessor_seed_authority") ==
                    successor.get("contract_version"),
                    "Patch 21.13a seed authority does not name Patch 21.7a")
            native_feature_diff = native_feature_seed.get("generated_seed_diff")
            require(isinstance(native_feature_diff, dict),
                    "Patch 21.13a seed authority omits generated diff accounting")
            live_seed_lines = native_feature_diff.get("current_lines")
    require(len(SEED.read_text(encoding="utf-8").splitlines()) ==
            live_seed_lines, "committed seed line count drifted")
    require("- [x] Patch 20.16e — Protected-Access Bootstrap Seed Reconvergence — DONE"
            in TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark 20.16e DONE")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    for evidence in (
        "compiler/CRANELIFT_PHASE20_PROTECTED_ACCESS_SEED_CONVERGENCE.md",
        "scripts/phase20_protected_access_seed_convergence.py",
        f"just {GUARD}",
    ):
        require(evidence in workflow,
                f"authoritative seed workflow lacks {evidence}")
    require(f"just {GUARD}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Patch 20.16e Level 1 guard")
    require(f"{GUARD}:" in JUSTFILE.read_text(encoding="utf-8"),
            "Patch 20.16e just guard is missing")
    return record


def render(record: dict) -> str:
    diff = record["generated_seed_diff"]
    return "\n".join([
        "# Cranelift Phase 20 Protected-Access Seed Convergence",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_protected_access_seed_convergence.py project`. Do not edit by hand.",
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
    ] + [
        f"- Patch {row['patch']}: `{row['scope']}`"
        for row in record["accounted_patches"]
    ] + [
        "",
        "This isolated regeneration accounts for every compiler-tree patch",
        "since the Patch 20.14b seed through Patch 20.16d. It changes no new",
        "Gust semantics, Stdlib API, MIR, ABI/layout, runtime symbol, backend,",
        "target, or linker policy.",
        "",
    ])


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
