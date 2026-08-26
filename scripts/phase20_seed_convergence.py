#!/usr/bin/env python3
"""Validate and project Patch 20.11 bootstrap seed convergence evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
SEED = ROOT / "gust_v4.c"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_SEED_CONVERGENCE.md"
WORKFLOW = ROOT / ".github/workflows/phase19-seed-convergence.yml"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
GUARD = "guard-cranelift-phase20-seed-convergence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def load_registry() -> dict:
    return json.loads(REGISTRY.read_text(encoding="utf-8"))


def validate() -> dict:
    registry = load_registry()
    predecessor = registry.get("phase19_seed_convergence")
    require(isinstance(predecessor, dict), "Phase 19 predecessor authority missing")
    require(predecessor.get("contract_version") == "phase19_seed_convergence_v3",
            "Phase 19 predecessor authority drifted")

    record = registry.get("phase20_seed_convergence")
    require(isinstance(record, dict), "registry record missing")
    expected = {
        "contract_version": "phase20_seed_convergence_v1",
        "status": "patch20_11_complete",
        "next_patch": "20.12",
        "review_view": "compiler/CRANELIFT_PHASE20_SEED_CONVERGENCE.md",
        "seed_path": "gust_v4.c",
        "seed_pull_request": 188,
        "preflight_pull_request": 187,
        "fixed_point_policy": "make_bootstrap_stage2_stage3_byte_identity",
        "seed_only_policy": "generated_gust_v4_c_only_on_seed_pull_request",
        "predecessor_authority": "phase19_seed_convergence_v3",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")

    diff = record.get("generated_seed_diff")
    expected_diff = {
        "previous_lines": 57360,
        "current_lines": 59502,
        "insertions": 2410,
        "deletions": 268,
        "line_delta": 2142,
    }
    require(diff == expected_diff, "generated seed diff accounting drifted")
    require(diff["current_lines"] - diff["previous_lines"] == diff["line_delta"],
            "recorded seed line delta is inconsistent")
    require(diff["insertions"] - diff["deletions"] == diff["line_delta"],
            "recorded insertion/deletion delta is inconsistent")

    accounted = record.get("accounted_patches")
    require(isinstance(accounted, list), "accounted patch list is missing")
    require([row.get("patch") for row in accounted] == [
        "20.0", "20.1", "20.2", "20.3", "20.3a", "20.4", "20.5",
        "20.6", "20.7", "20.8", "20.9", "20.9a", "20.10", "20.11",
    ], "seed changes are not accounted through Patch 20.11")
    require(all(set(row) == {"patch", "scope"} and row["scope"] for row in accounted),
            "seed accounting row shape drifted")

    live_seed_lines = diff["current_lines"]
    successor = registry.get("phase20_post_prerequisite_seed_convergence")
    if successor is not None:
        require(successor.get("predecessor_authority") == record["contract_version"],
                "Patch 20.14b seed authority does not name this predecessor")
        successor_diff = successor.get("generated_seed_diff")
        require(isinstance(successor_diff, dict),
                "Patch 20.14b seed authority omits generated diff accounting")
        live_seed_lines = successor_diff.get("current_lines")
        protected_access = registry.get("phase20_protected_access_seed_convergence")
        if protected_access is not None:
            require(protected_access.get("predecessor_seed_authority") ==
                    successor.get("contract_version"),
                    "Patch 20.16e seed authority does not name Patch 20.14b predecessor")
            protected_diff = protected_access.get("generated_seed_diff")
            require(isinstance(protected_diff, dict),
                    "Patch 20.16e seed authority omits generated diff accounting")
            live_seed_lines = protected_diff.get("current_lines")
            phase21_seed = registry.get("phase21_tenant_scope_seed_convergence")
            if phase21_seed is not None:
                require(phase21_seed.get("predecessor_seed_authority") ==
                        protected_access.get("contract_version"),
                        "Patch 21.7a seed authority does not name Patch 20.16e")
                phase21_diff = phase21_seed.get("generated_seed_diff")
                require(isinstance(phase21_diff, dict),
                        "Patch 21.7a seed authority omits generated diff accounting")
                live_seed_lines = phase21_diff.get("current_lines")
                native_feature_seed = registry.get(
                    "phase21_native_feature_seed_convergence"
                )
                if native_feature_seed is not None:
                    require(native_feature_seed.get("predecessor_seed_authority") ==
                            phase21_seed.get("contract_version"),
                            "Patch 21.13a seed authority does not name Patch 21.7a")
                    native_feature_diff = native_feature_seed.get("generated_seed_diff")
                    require(isinstance(native_feature_diff, dict),
                            "Patch 21.13a seed authority omits generated diff accounting")
                    live_seed_lines = native_feature_diff.get("current_lines")
    seed_text = SEED.read_text(encoding="utf-8")
    require(len(seed_text.splitlines()) == live_seed_lines,
            "committed seed line count drifted")

    workflow = WORKFLOW.read_text(encoding="utf-8")
    for token in (
        "compiler/CRANELIFT_PHASE20_SEED_CONVERGENCE.md",
        "scripts/phase20_seed_convergence.py",
        "just guard-cranelift-phase20-seed-convergence",
    ):
        require(token in workflow, f"seed workflow omits {token!r}")
    require("just guard-cranelift-phase20-seed-convergence"
            in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Level 1 Phase 20 seed contract")
    require("- [x] Patch 20.11 — Bootstrap Seed Regeneration and Fixed-Point Convergence — DONE"
            in TASK.read_text(encoding="utf-8"), "TASK.md does not mark Patch 20.11 DONE")
    return record


def render(record: dict) -> str:
    diff = record["generated_seed_diff"]
    lines = [
        "# Cranelift Phase 20 Seed Convergence",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_seed_convergence.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Seed: `{record['seed_path']}`",
        f"- Seed-only pull request: `#{record['seed_pull_request']}`",
        f"- Preflight pull request: `#{record['preflight_pull_request']}`",
        f"- Predecessor authority: `{record['predecessor_authority']}`",
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
        "Every compiler-source change since the preceding seed belongs to:",
        "",
    ]
    lines += [f"- Patch {row['patch']} — {row['scope']}" for row in record["accounted_patches"]]
    lines += [
        "",
        "The Phase 19 record remains immutable; this successor owns the live seed.",
        "No unrelated compiler-source commit is included in this regeneration.",
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
        require(REVIEW.is_file(), "generated review view missing")
        require(REVIEW.read_text(encoding="utf-8") == render(record),
                "generated review view is stale; run phase20_seed_convergence.py project")
    print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
