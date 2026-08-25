#!/usr/bin/env python3
"""Validate and project Patch 21.7a tenant-scope seed convergence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
SEED = ROOT / "gust_v4.c"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_TENANT_SCOPE_SEED_CONVERGENCE.md"
WORKFLOW = ROOT / ".github/workflows/phase19-seed-convergence.yml"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
GUARD = "guard-cranelift-phase21-tenant-scope-seed-convergence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase20_protected_access_seed_convergence", {})
    require(predecessor.get("contract_version") ==
            "phase20_protected_access_seed_convergence_v1",
            "predecessor seed authority drifted")
    accounted = registry.get("phase21_od8_adversarial_verdict", {})
    require(accounted.get("contract_version") ==
            "phase21_od8_adversarial_verdict_v1" and
            accounted.get("status") == "patch21_7_complete",
            "accounted Phase 21 authority drifted")

    record = registry.get("phase21_tenant_scope_seed_convergence")
    require(isinstance(record, dict), "Patch 21.7a authority is missing")
    expected = {
        "contract_version": "phase21_tenant_scope_seed_convergence_v1",
        "status": "patch21_7a_complete",
        "next_patch": "21.8",
        "review_view": "compiler/CRANELIFT_PHASE21_TENANT_SCOPE_SEED_CONVERGENCE.md",
        "seed_path": "gust_v4.c",
        "predecessor_seed_authority": "phase20_protected_access_seed_convergence_v1",
        "accounted_authority": "phase21_od8_adversarial_verdict_v1",
        "previous_seed_commit": "02fead71a87f0148d4290ee12e84973931c400e8",
        "fixed_point_policy": "make_bootstrap_stage2_stage3_byte_identity",
        "seed_only_policy": "generated_seed_and_seed_specific_authority_only",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")

    diff = record.get("generated_seed_diff")
    require(diff == {
        "previous_lines": 59706,
        "current_lines": 60470,
        "insertions": 841,
        "deletions": 77,
        "line_delta": 764,
    }, "generated seed diff accounting drifted")
    require(diff["current_lines"] - diff["previous_lines"] == diff["line_delta"] and
            diff["insertions"] - diff["deletions"] == diff["line_delta"],
            "generated seed line delta is inconsistent")
    require([row.get("patch") for row in record.get("accounted_patches", [])] == [
        "21.1", "21.2", "21.3", "21.4", "21.5", "21.6", "21.7",
    ], "accounted Phase 21 patch range drifted")
    require(all(set(row) == {"patch", "scope"} and row["scope"]
                for row in record["accounted_patches"]),
            "accounted patch row is incomplete")
    require(record.get("boundary") and
            all(value is False for value in record["boundary"].values()),
            "Patch 21.7a widened beyond seed reconvergence")
    require(len(SEED.read_text(encoding="utf-8").splitlines()) ==
            diff["current_lines"], "committed seed line count drifted")
    require("- [x] Patch 21.7a — Tenant-Scope Bootstrap Seed Reconvergence — DONE"
            in TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 21.7a DONE")

    workflow = WORKFLOW.read_text(encoding="utf-8")
    for evidence in (
        "compiler/CRANELIFT_PHASE21_TENANT_SCOPE_SEED_CONVERGENCE.md",
        "scripts/phase21_tenant_scope_seed_convergence.py",
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
        "compiler/CRANELIFT_PHASE21_TENANT_SCOPE_SEED_CONVERGENCE.md",
        "scripts/phase21_tenant_scope_seed_convergence.py",
    ):
        require(seed_owned_path in selector,
                f"fixed-point scope selector lacks {seed_owned_path}")
    require("compiler/*.gst" not in selector,
            "capability compiler sources must remain deferred on pull requests")
    require(f"just {GUARD}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Patch 21.7a Level 1 guard")
    require(f"{GUARD}:" in JUSTFILE.read_text(encoding="utf-8"),
            "Patch 21.7a just guard is missing")
    return record


def render(record: dict) -> str:
    diff = record["generated_seed_diff"]
    lines = [
        "# Cranelift Phase 21 Tenant-Scope Seed Convergence",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_tenant_scope_seed_convergence.py project`. Do not edit by hand.",
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
        "This isolated regeneration serializes the completed Phase 21 Track A",
        "self-hosted compiler changes through Patch 21.7. Stage 2 and stage 3",
        "must remain byte-identical in the authoritative seed workflow. The",
        "patch adds no Gust semantics, Stdlib API, MIR/backend behavior,",
        "ABI/layout, or runtime symbol.",
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
