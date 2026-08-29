#!/usr/bin/env python3
"""Validate and project the Patch 22.8 Historical route correction."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
JUSTFILE = ROOT / "justfile"
HANDOFF = ROOT / "scripts/phase22_historical_route_successor.sh"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE22_HISTORICAL_ROUTE_SUCCESSOR.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase22-historical-route-successor.yml"
HISTORICAL = ROOT / ".github/workflows/cranelift-historical-full.yml"
GUARD_L1 = "guard-cranelift-phase22-historical-route-successor-contract"
GUARD_L2 = "guard-cranelift-phase22-historical-route-successor-evidence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase22_postflip_qualification", {})
    require(predecessor.get("contract_version") ==
            "phase22_postflip_qualification_v1",
            "Patch 22.7 predecessor authority drifted")
    record = registry.get("phase22_historical_route_successor")
    require(isinstance(record, dict), "Historical successor authority is missing")
    require(record.get("contract_version") ==
            "phase22_historical_route_successor_v1" and
            record.get("status") == "corrective_prerequisite_complete" and
            record.get("next_action") ==
            "replacement_exact_main_historical_full_for_patch22_8" and
            record.get("predecessor_authority") ==
            predecessor.get("contract_version"),
            "Historical successor identity or handoff drifted")

    require(record.get("failed_qualification") == {
        "workflow": "Cranelift Historical Full",
        "run_id": 33274538693,
        "event": "workflow_dispatch",
        "head_branch": "main",
        "head_sha": "e995b2a1eef5895c05858d8adfe359e77d24ee21",
        "status": "completed",
        "conclusion": "failure",
        "successful_jobs": 16,
        "total_jobs": 18,
        "owning_failure": "Level 3 history / phase10",
        "dependent_non_success": "Level 3 declared-target completion:skipped",
    }, "failed Historical evidence drifted")
    require(record.get("root_cause") ==
            "phase10_route_and_output_guards_did_not_follow_registered_phase22_default_successor",
            "root-cause classification drifted")
    require(record.get("successor_replay") == [
        "guard-cranelift-phase22-default-route-flip-contract",
        "guard-cranelift-phase22-native-implicit-output-contract",
        "guard-cranelift-phase22-default-route-flip-evidence",
        "guard-cranelift-phase22-postflip-qualification-evidence",
    ], "successor replay inventory drifted")

    just = JUSTFILE.read_text(encoding="utf-8")
    for marker in (
        "the live route is owned by Phase 22.6",
        "the live output is owned by the Phase 22 successor",
        "bash scripts/phase22_historical_route_successor.sh",
        f"{GUARD_L1}:",
        f"{GUARD_L2}:",
    ):
        require(marker in just, f"Historical successor marker missing: {marker}")
    handoff = HANDOFF.read_text(encoding="utf-8")
    for guard in record["successor_replay"][2:]:
        require(f"just {guard}" in handoff,
                f"Historical dynamic replay omits {guard}")
    require("just guard-cranelift-phase10-packaging-help-ci" in handoff,
            "Historical package/help predecessor was skipped")
    require("CRANELIFT_HISTORICAL_SHARD: phase10" in
            WORKFLOW.read_text(encoding="utf-8"),
            "focused workflow does not execute the corrected Phase 10 shard")
    require("guard-cranelift-historical-full" in
            HISTORICAL.read_text(encoding="utf-8"),
            "Historical owner no longer executes the registered shard guard")

    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Historical successor guard levels drifted")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the correction contract")
    task = TASK.read_text(encoding="utf-8")
    require("Historical Full run `33274538693` is retained as failed diagnostic evidence" in task and
            "- [ ] Patch 22.8 — One-Time Default-Native Stability Qualification" in task,
            "TASK.md correction record or pending 22.8 boundary drifted")
    boundary = record.get("boundary", {})
    require(boundary.get("changes_historical_successor_routing") is True and
            all(value is False for key, value in boundary.items()
                if key != "changes_historical_successor_routing"),
            "Historical successor correction widened")
    return record


def render(record: dict) -> str:
    failed = record["failed_qualification"]
    lines = [
        "# Cranelift Phase 22.8 — Historical Route Successor Correction",
        "",
        "Generated from `scripts/cranelift_feature_registry.json`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next action: `{record['next_action']}`",
        f"- Predecessor: `{record['predecessor_authority']}`",
        "",
        "## Failed qualification retained as diagnosis",
        "",
        f"- Workflow/run: `{failed['workflow']}` / `{failed['run_id']}`",
        f"- Event: `{failed['event']}`",
        f"- Exact head: `{failed['head_sha']}`",
        f"- Conclusion: `{failed['conclusion']}`",
        f"- Successful jobs: `{failed['successful_jobs']}/{failed['total_jobs']}`",
        f"- Owning failure: `{failed['owning_failure']}`",
        f"- Dependent non-success: `{failed['dependent_non_success']}`",
        "",
        "## Successor replay",
        "",
    ]
    lines += [f"- `{guard}`" for guard in record["successor_replay"]]
    lines += [
        "",
        "The retired Phase 10 selection and output records remain historical.",
        "Their live assertions follow the registered Phase 22 route/output",
        "successors, and the Historical shard replays default-native, package,",
        "explicit-C oracle/rollback, and no-fallback evidence. The failed run is",
        "not stability evidence; Patch 22.8 remains pending a successful",
        "replacement run on exact corrected main.",
        "",
    ]
    return "\n".join(lines)


def evidence() -> None:
    env = os.environ.copy()
    env["CRANELIFT_HISTORICAL_SHARD"] = "phase10"
    env["PHASE14_HISTORICAL_EXTERNAL_MATRIX"] = "1"
    subprocess.run(["just", "guard-cranelift-historical-full"], cwd=ROOT,
                   env=env, check=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review", "evidence"))
    args = parser.parse_args()
    record = validate()
    rendered = render(record)
    if args.command == "project":
        REVIEW.write_text(rendered, encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.exists() and REVIEW.read_text(encoding="utf-8") == rendered,
                "generated review view is stale")
    elif args.command == "evidence":
        evidence()
    print(f"{GUARD_L1}: {args.command} ok")


if __name__ == "__main__":
    main()
