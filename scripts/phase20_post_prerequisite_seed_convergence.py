#!/usr/bin/env python3
"""Validate and project Patch 20.14b seed reconvergence evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
SEED = ROOT / "gust_v4.c"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_POST_PREREQUISITE_SEED_CONVERGENCE.md"
WORKFLOW = ROOT / ".github/workflows/phase19-seed-convergence.yml"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
GUARD = "guard-cranelift-phase20-post-prerequisite-seed-convergence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase20_seed_convergence", {})
    require(predecessor.get("contract_version") == "phase20_seed_convergence_v1",
            "predecessor seed authority drifted")
    record = registry.get("phase20_post_prerequisite_seed_convergence")
    require(isinstance(record, dict), "Patch 20.14b authority is missing")
    expected = {
        "contract_version": "phase20_post_prerequisite_seed_convergence_v1",
        "status": "patch20_14b_complete",
        "next_patch": "20.15",
        "review_view": "compiler/CRANELIFT_PHASE20_POST_PREREQUISITE_SEED_CONVERGENCE.md",
        "seed_path": "gust_v4.c",
        "predecessor_authority": "phase20_seed_convergence_v1",
        "previous_seed_commit": "958262bc42e33f83a79d828a629e582528e334e7",
        "fixed_point_policy": "make_bootstrap_stage2_stage3_byte_identity",
        "seed_only_policy": "generated_seed_and_seed_specific_authority_only",
        "accounted_patch": "20.14a",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")
    diff = record.get("generated_seed_diff")
    require(diff == {
        "previous_lines": 59502,
        "current_lines": 59520,
        "insertions": 63,
        "deletions": 45,
        "line_delta": 18,
    }, "generated seed diff accounting drifted")
    require(diff["insertions"] - diff["deletions"] == diff["line_delta"],
            "generated seed line delta is inconsistent")
    live_seed_lines = diff["current_lines"]
    successor = registry.get("phase20_protected_access_seed_convergence")
    if successor is not None:
        require(successor.get("predecessor_seed_authority") ==
                record["contract_version"],
                "Patch 20.16e seed authority does not name this predecessor")
        successor_diff = successor.get("generated_seed_diff")
        require(isinstance(successor_diff, dict),
                "Patch 20.16e seed authority omits generated diff accounting")
        live_seed_lines = successor_diff.get("current_lines")
    require(len(SEED.read_text(encoding="utf-8").splitlines()) ==
            live_seed_lines, "committed seed line count drifted")
    require("- [x] Patch 20.14b — Post-Prerequisite Bootstrap Seed Reconvergence — DONE"
            in TASK.read_text(encoding="utf-8"), "TASK.md does not mark 20.14b DONE")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require("scripts/phase20_post_prerequisite_seed_convergence.py" in workflow and
            "just guard-cranelift-phase20-post-prerequisite-seed-convergence" in workflow,
            "authoritative seed workflow does not own Patch 20.14b")
    require("just guard-cranelift-phase20-post-prerequisite-seed-convergence"
            in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Patch 20.14b Level 1 guard")
    return record


def render(record: dict) -> str:
    diff = record["generated_seed_diff"]
    return "\n".join([
        "# Cranelift Phase 20 Post-Prerequisite Seed Convergence",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_post_prerequisite_seed_convergence.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Accounted patch: `{record['accounted_patch']}`",
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
        "This isolated regeneration accounts only for the self-hosted compiler",
        "correction in Patch 20.14a. It changes no Gust semantics, Stdlib API,",
        "MIR, ABI/layout, runtime symbol, backend, target, or linker policy.",
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
        require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") == render(record),
                "generated review is stale; run project")
    print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
